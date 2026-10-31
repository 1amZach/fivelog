-- lua5.4 test/run.lua
-- Runs the server side of fivelog against a fake FiveM server and database.

local passed, failed = 0, 0
local function check(name, cond)
    if cond then passed = passed + 1 else failed = failed + 1; io.write('FAIL ' .. name .. '\n') end
end

-- Events, timers ----------------------------------------------------------------

local handlers = {}
function AddEventHandler(name, fn) handlers[name] = handlers[name] or {}; table.insert(handlers[name], fn) end
function RegisterNetEvent(name, fn) if fn then AddEventHandler(name, fn) end end
local triggered = {}
function TriggerEvent(name, ...)
    triggered[#triggered + 1] = { name = name, args = { ... } }
    if name == 'fivelog:query' then for _, fn in ipairs(handlers[name] or {}) do fn(...) end end
end
local function fire(name, src, ...)
    source = src
    for _, fn in ipairs(handlers[name] or {}) do fn(...) end
end
local function lastEvent(name)
    for i = #triggered, 1, -1 do if triggered[i].name == name then return triggered[i] end end
end

local timers = {}
function SetTimeout(_, fn) timers[#timers + 1] = fn end
local function runTimers() local t = timers; timers = {}; for _, fn in ipairs(t) do fn() end end
function CreateThread() end
function Wait() end

local toClient = {}
function TriggerClientEvent(name, target, ...) toClient[#toClient + 1] = { name = name, target = target, args = { ... } } end

local stored, n = {}, 0
json = {
    encode = function(t) n = n + 1; local k = 'json#' .. n; stored[k] = t; return k end,
    decode = function(s) return assert(stored[s], 'bad json') end,
}

function GetHashKey(s)
    local h = 0
    for c in s:lower():gmatch('.') do
        h = (h + c:byte()) & 0xFFFFFFFF
        h = (h + (h << 10)) & 0xFFFFFFFF
        h = h ~ (h >> 6)
    end
    h = (h + (h << 3)) & 0xFFFFFFFF
    h = h ~ (h >> 11)
    h = (h + (h << 15)) & 0xFFFFFFFF
    return h >= 0x80000000 and h - 0x100000000 or h
end

-- Players, entities ---------------------------------------------------------------

local players, entities = {}, {}
local started = { fivelog = 'started', oxmysql = 'started' }

local function addPlayer(src, name, pos)
    players[src] = { name = name, ids = { 'license:' .. name:lower(), 'discord:1' .. src, 'ip:1.2.3.4' }, pos = pos or { x = 0, y = 0, z = 0 } }
    fire('playerJoining', src)
end
local function ped(src) return src + 1000 end

function GetPlayerName(src) local p = players[tonumber(src)]; return p and p.name end
function GetNumPlayerIdentifiers(src) return #players[tonumber(src)].ids end
function GetPlayerIdentifier(src, i) return players[tonumber(src)].ids[i + 1] end
function GetPlayerPed(src) return players[tonumber(src)] and ped(tonumber(src)) or 0 end
function GetEntityCoords(e) local p = players[e - 1000]; return p and p.pos or entities[e].pos end
function DoesEntityExist(e) return entities[e] ~= nil end
function GetEntityType(e) return entities[e].type end
function GetEntityPopulationType(e) return entities[e].pop end
function NetworkGetFirstEntityOwner(e) return entities[e].owner end
function GetEntityModel(e) return entities[e].model end
function GetVehicleNumberPlateText(e) return entities[e].plate end
function GetResourceState(name) return started[name] or 'missing' end
function GetCurrentResourceName() return 'fivelog' end
local http = {}
function PerformHttpRequest(url, _, _, body) http[#http + 1] = { url = url, body = body } end

-- Database -------------------------------------------------------------------------

local db = { inserts = {}, queries = {}, answer = {} }
MySQL = {
    insert = function(sql, params) db.inserts[#db.inserts + 1] = { sql = sql, params = params } end,
    query = function(sql, params, cb)
        db.queries[#db.queries + 1] = { sql = sql, params = params }
        if cb then cb(db.answer) end
    end,
}

local registered, fivecordLogs, hooks = {}, {}, {}
exports = setmetatable({}, {
    __call = function(_, name, fn) registered[name] = fn end,
    __index = function(_, res)
        if res == 'fivecord' then
            return { log = function(_, kind, title, desc) fivecordLogs[#fivecordLogs + 1] = { kind = kind, title = title, desc = desc } end }
        end
        if res == 'ox_inventory' then
            return {
                Items = function(_, name) return name == 'water' and { label = 'Water' } or nil end,
                registerHook = function(_, name, fn) hooks[name] = fn end,
            }
        end
    end,
})

for _, f in ipairs({ 'config.lua', 'server/weapons.lua', 'server/core.lua', 'server/discord.lua', 'server/sources.lua', 'server/combat.lua' }) do
    dofile(f)
end

local function entries(kind)
    local out = {}
    for _, t in ipairs(triggered) do
        if t.name == 'fivelog:entry' and (not kind or t.args[1].kind == kind) then out[#out + 1] = t.args[1] end
    end
    return out
end
local function last(kind) local e = entries(kind); return e[#e] end

-- Tests ----------------------------------------------------------------------------

do -- joins: identity kept, ip left out
    addPlayer(1, 'Bob', { x = 10, y = 0, z = 0 })
    local e = last('joins')
    check('join logged', e and e.text == 'Bob joined' and e.license == 'license:bob' and e.src == 1)
    check('ip not kept', not table.concat(e.data.identifiers, ' '):find('ip:'))
    check('position rounded', e.x == 10)
end

do -- chat, but not commands
    fire('chatMessage', 1, 1, 'Bob', 'hello there')
    check('chat logged', last('chat').text == 'Bob: hello there')
    local before = #entries('chat')
    fire('chatMessage', 1, 1, 'Bob', '/me waves')
    check('commands skipped', #entries('chat') == before)
end

do -- a kill with distance and headshot
    addPlayer(2, 'Al', { x = 40, y = 0, z = 0 })
    fire('fivelog:hurt', 1, 2, GetHashKey('WEAPON_PISTOL'), 0, 31086, true)
    local e = last('deaths')
    check('kill text', e and e.text == 'Al killed Bob with a Pistol from 30m, headshot')
    check('kill filed under killer, victim as target', e.src == 2 and e.target == 'license:bob')
    check('kill data', e.data.headshot == true and e.data.distance == 30)
end

do -- deaths without a killer, and causes never credit a player
    fire('fivelog:hurt', 1, 2, GetHashKey('WEAPON_FALL'), 0, 0, true)
    check('fall ignores the attacker sent', last('deaths').text == 'Bob died from a fall')
    fire('fivelog:hurt', 1, 0, GetHashKey('WEAPON_DROWNING'), 0, 0, true)
    check('drowning wording', last('deaths').text == 'Bob died from drowning')
    fire('fivelog:hurt', 1, 1, GetHashKey('WEAPON_PISTOL'), 0, 0, true)
    check('own weapon', last('deaths').text == 'Bob killed themselves with a Pistol')
    fire('fivelog:hurt', 1, 99, GetHashKey('WEAPON_PISTOL'), 0, 0, true)
    check('unknown attacker dropped', last('deaths').text == 'Bob died from a Pistol')
end

do -- damage folds hits together
    local before = #entries('damage')
    for _, b in ipairs({ 31086, 0, 0 }) do fire('fivelog:hurt', 1, 2, GetHashKey('WEAPON_CARBINERIFLE'), 25, b, false) end
    check('nothing until the window ends', #entries('damage') == before)
    runTimers()
    local e = last('damage')
    check('damage folded', e and e.text == 'Al hit Bob 3 times with a Carbine rifle for 75 damage, 1 to the head, 30m away')
    check('damage filed under attacker', e.src == 2 and e.target == 'license:bob')

    fire('fivelog:hurt', 1, 0, GetHashKey('WEAPON_FALL'), 12, 0, false)
    runTimers()
    check('environment damage', last('damage').text == 'Bob took 12 damage from a fall')

    before = #entries('damage')
    fire('fivelog:hurt', 1, 2, GetHashKey('WEAPON_PISTOL'), 0, 0, false)
    runTimers()
    check('zero damage skipped', #entries('damage') == before)

    fire('fivelog:hurt', 1, 2, GetHashKey('WEAPON_UNARMED'), 5, 0, false)
    runTimers()
    check('fists wording', last('damage').text:find('with fists for 5') ~= nil)
end

do -- a flood of hurt events is capped
    local count = 0
    for _ = 1, 60 do fire('fivelog:hurt', 1, 0, GetHashKey('WEAPON_PISTOL'), 0, 0, true); count = count + 1 end
    local deaths = 0
    for _, e in ipairs(entries('deaths')) do if e.text == 'Bob died from a Pistol' then deaths = deaths + 1 end end
    check('rate limited', deaths <= 41)
end

do -- money from QBCore and ESX, posting only big changes
    Discord.flush(); fivecordLogs = {}
    started.fivecord = 'started'
    fire('QBCore:Server:OnMoneyChange', nil, 1, 'bank', 500, 'add', 'paycheck')
    check('qb add', last('money').text == 'Bob got $500 bank (paycheck)')
    fire('QBCore:Server:OnMoneyChange', nil, 1, 'cash', 25000, 'remove', '')
    check('qb remove with commas', last('money').text == 'Bob lost $25,000 cash' and last('money').data.change == -25000)
    fire('QBCore:Server:OnMoneyChange', nil, 1, 'cash', 3, 'set')
    check('qb set', last('money').text == 'Bob cash set to $3')
    fire('esx:addAccountMoney', nil, 1, 'money', 1234567, 'Sold car')
    check('esx add', last('money').text == 'Bob got $1,234,567 money (Sold car)')
    fire('esx:setAccountMoney', nil, { name = 'bank' })
    check('client form of esx event ignored', last('money').text == 'Bob got $1,234,567 money (Sold car)')

    Discord.flush()
    check('one post for the batch', #fivecordLogs == 1 and fivecordLogs[1].kind == 'money')
    local d = fivecordLogs[1].desc
    check('big ones posted', d:find('25,000') and d:find('1,234,567'))
    check('small ones not posted', not d:find('paycheck'))
    check('discord markdown escaped and timestamp', d:find('<t:%d+:T> `1` Bob') ~= nil)
end

do -- items through ox_inventory hooks
    fire('onResourceStart', nil, 'fivelog')
    started.ox_inventory = 'started'
    runTimers()
    check('hooks registered', hooks.swapItems and hooks.buyItem)

    hooks.swapItems({ source = 1, action = 'give', fromInventory = 1, toInventory = 2, fromType = 'player', toType = 'player', fromSlot = { name = 'water', count = 5 }, count = 2 })
    check('give', last('items').text == 'Bob gave 2x Water to Al' and last('items').target == 'license:al')
    hooks.swapItems({ source = 1, fromInventory = 1, toInventory = 'newdrop', fromType = 'player', toType = 'drop', fromSlot = { name = 'phone', count = 1 }, count = 1 })
    check('drop', last('items').text == 'Bob dropped 1x phone')
    hooks.swapItems({ source = 1, fromInventory = 'police_locker', toInventory = 1, fromType = 'stash', toType = 'player', fromSlot = { name = 'water', count = 1 }, count = 1 })
    check('take from stash', last('items').text == 'Bob took 1x Water from stash police_locker')
    hooks.swapItems({ source = 1, fromInventory = 1, toInventory = 'trunkAB12CD', fromType = 'player', toType = 'trunk', fromSlot = { name = 'water', count = 1 }, count = 1 })
    check('put in trunk', last('items').text == 'Bob put 1x Water in trunk AB12CD')
    local before = #entries('items')
    hooks.swapItems({ source = 1, fromInventory = 1, toInventory = 1, fromType = 'player', toType = 'player', fromSlot = { name = 'water', count = 1 }, count = 1 })
    check('moves inside own inventory skipped', #entries('items') == before)
    hooks.buyItem({ source = 1, itemName = 'water', count = 3, totalPrice = 15, shopType = 'General' })
    check('buy', last('items').text == 'Bob bought 3x Water for $15 at General')
end

do -- vehicles: named by the spawner's client, cached after
    entities[500] = { type = 2, pop = 7, owner = 2, model = GetHashKey('adder'), plate = ' AB12 ' }
    fire('entityCreated', nil, 500)
    local ask = toClient[#toClient]
    check('asks the owner for the name', ask.name == 'fivelog:model' and ask.target == 2)
    fire('fivelog:model', 2, ask.args[1], 'Adder')
    check('vehicle logged with name and plate', last('vehicles').text == 'Al spawned an Adder (AB12)')

    local asked = #toClient
    entities[501] = { type = 2, pop = 7, owner = 1, model = GetHashKey('adder'), plate = 'X' }
    fire('entityCreated', nil, 501)
    check('cached name used', #toClient == asked and last('vehicles').text == 'Bob spawned an Adder (X)')

    entities[502] = { type = 2, pop = 5, owner = 1, model = 1, plate = 'AMB' }
    local before = #entries('vehicles')
    fire('entityCreated', nil, 502)
    check('ambient traffic skipped', #entries('vehicles') == before)

    entities[503] = { type = 2, pop = 7, owner = 1, model = GetHashKey('t20'), plate = 'NO' }
    fire('entityCreated', nil, 503)
    runTimers()
    check('falls back to hash when nobody answers', last('vehicles').text:find('^Bob spawned a model %d+') ~= nil)
    fire('fivelog:model', 1, GetHashKey('t20'), 'T20')
    check('late answer does nothing', last('vehicles').text:find('model') ~= nil)
end

do -- database: batched insert, and search
    db.inserts = {}
    Log.flush()
    local ins = db.inserts[1]
    check('batched insert', ins and ins.sql:find('^INSERT INTO fivelog') and #ins.params % 12 == 0 and #ins.params > 12)
    Log.flush()
    check('nothing twice', #db.inserts == 1)

    db.answer = { { id = 9, kind = 'items', text = 'x', data = json.encode({ item = 'water' }) } }
    local rows
    Log.query({ kind = { 'items', 'money' }, player = '@1', q = '50%', before = 100, limit = 9999 }, function(r) rows = r end)
    local q = db.queries[#db.queries]
    check('filters in sql', q.sql:find('kind IN %(%?, %?%)') and q.sql:find('license = %? OR target = %?') and q.sql:find('text LIKE %?') and q.sql:find('id < %?'))
    check('online id becomes license', q.params[3] == 'license:bob')
    check('like escaped', q.params[5] == '%50\\%%')
    check('limit capped', q.sql:find('LIMIT 500$'))
    check('data decoded', rows[1].data.item == 'water')

    Log.query({ player = '@77' }, function(r) rows = r end)
    check('unknown online id gives nothing', #rows == 0)

    fire('fivelog:query', nil, 7, { kind = 'chat' })
    local done = lastEvent('fivelog:query:done')
    check('query over events', done and done.args[1] == 7 and done.args[2] == true)
end

do -- prune: per kind, then everything else
    db.queries = {}
    Log.prune()
    local general = db.queries[#db.queries]
    check('per kind deletes', #db.queries == 3)
    check('general delete skips special kinds', general.sql:find('NOT IN %(%?, %?%)') and #general.params == 3)
end

do -- exports
    check('recent export', #registered.recent(1, 3) == 3 and registered.recent(1, 3)[3].src ~= nil)
    check('recent for target too', #registered.recent(2) > 0)
    check('custom log', registered.add('custom', 1, 'did a thing', { a = 1 }) and last('custom').text == 'did a thing')
    check('custom needs a kind', registered.add(nil, 1, 'x') == nil)
end

do -- webhooks for kinds set to a url
    Config.discord.joins = 'https://discord.test/hook'
    addPlayer(3, 'Cy')
    Discord.flush()
    check('webhook post', http[#http] and http[#http].url == 'https://discord.test/hook' and json.decode(http[#http].body).embeds[1].title == 'Joins')
end

do -- leaving
    fire('playerDropped', 3, 'Exiting')
    check('leave logged', last('joins').text:find('^Cy left after %d+s: Exiting') ~= nil)
    check('forgotten', Log.people[3] == nil and Log.recent[3] == nil)
end

do -- resources
    fire('onResourceStart', nil, 'qbx_core')
    check('resource start', last('resources').text == 'qbx_core started' and last('resources').src == nil)
end

io.write(('%d passed, %d failed\n'):format(passed, failed))
os.exit(failed == 0 and 0 or 1)
