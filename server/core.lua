Log = { people = {}, recent = {} }

local queue = {}
local kinds = { 'joins', 'chat', 'deaths', 'damage', 'money', 'items', 'vehicles', 'resources' }

-- Who someone is, kept from when they join so it's still there when they leave.
function Log.person(src)
    src = tonumber(src)
    if not src or src <= 0 then return end
    local p = Log.people[src]
    if p then return p end
    local name = GetPlayerName(src)
    if not name then return end

    p = { src = src, name = name, joined = os.time(), identifiers = {} }
    for i = 0, GetNumPlayerIdentifiers(src) - 1 do
        local id = GetPlayerIdentifier(src, i)
        if id and not id:find('^ip:') then
            p.identifiers[#p.identifiers + 1] = id
            if id:find('^license:') and not p.license then p.license = id end
        end
    end
    p.license = p.license or p.identifiers[1]
    Log.people[src] = p
    return p
end

local function where(src)
    local ped = src and GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local c = GetEntityCoords(ped)
    return c
end

local function remember(src, entry)
    local list = Log.recent[src]
    if not list then
        list = {}
        Log.recent[src] = list
    end
    list[#list + 1] = entry
    if #list > Config.recent then table.remove(list, 1) end
end

-- One log line. `src` is who did it, `opts.target` who it was done to.
--   Log.add('items', 3, 'Bob gave 2x Water to Al', { target = 7, data = { item = 'water', count = 2 } })
function Log.add(kind, src, text, opts)
    opts = opts or {}
    local p, t = Log.person(src), Log.person(opts.target)
    local pos = opts.pos or where(p and p.src)

    local entry = {
        at = os.time(),
        kind = kind,
        src = p and p.src,
        license = p and p.license or opts.license,
        name = p and p.name or opts.name,
        target = t and t.license,
        targetName = t and t.name,
        text = tostring(text):sub(1, 500),
        data = opts.data,
        x = pos and math.floor(pos.x * 10 + 0.5) / 10,
        y = pos and math.floor(pos.y * 10 + 0.5) / 10,
        z = pos and math.floor(pos.z * 10 + 0.5) / 10,
    }

    queue[#queue + 1] = entry
    if p then remember(p.src, entry) end
    if t and t ~= p then remember(t.src, entry) end
    Discord.push(entry, opts.post)
    TriggerEvent('fivelog:entry', entry)
    return entry
end

-- ------------------------------------------------------------------ database

local columns = '(at, kind, src, license, name, target, target_name, text, data, x, y, z)'

function Log.flush()
    if #queue == 0 then return end
    local batch = queue
    queue = {}

    for i = 1, #batch, 200 do
        local rows, params = {}, {}
        for j = i, math.min(i + 199, #batch) do
            local e = batch[j]
            rows[#rows + 1] = '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)'
            local n = #params
            params[n + 1], params[n + 2], params[n + 3], params[n + 4] = e.at, e.kind, e.src, e.license
            params[n + 5], params[n + 6], params[n + 7], params[n + 8] = e.name, e.target, e.targetName, e.text
            params[n + 9] = e.data and json.encode(e.data) or nil
            params[n + 10], params[n + 11], params[n + 12] = e.x, e.y, e.z
        end
        MySQL.insert(('INSERT INTO fivelog %s VALUES %s'):format(columns, table.concat(rows, ', ')), params)
    end
end

local function keepFor(kind) return (Config.keep[kind] or Config.keepDays) * 86400 end

function Log.prune()
    local t = os.time()
    local params = { t - Config.keepDays * 86400 }
    for kind in pairs(Config.keep) do
        MySQL.query('DELETE FROM fivelog WHERE kind = ? AND at < ?', { kind, t - keepFor(kind) })
        params[#params + 1] = kind
    end
    local sql = 'DELETE FROM fivelog WHERE at < ?'
    if #params > 1 then sql = sql .. (' AND kind NOT IN (%s)'):format(('?, '):rep(#params - 1):sub(1, -3)) end
    MySQL.query(sql, params)
end

local schema = [[
CREATE TABLE IF NOT EXISTS `fivelog` (
    `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `at` INT UNSIGNED NOT NULL,
    `kind` VARCHAR(24) NOT NULL,
    `src` SMALLINT UNSIGNED NULL,
    `license` VARCHAR(64) NULL,
    `name` VARCHAR(64) NULL,
    `target` VARCHAR(64) NULL,
    `target_name` VARCHAR(64) NULL,
    `text` VARCHAR(500) NOT NULL,
    `data` TEXT NULL,
    `x` FLOAT NULL,
    `y` FLOAT NULL,
    `z` FLOAT NULL,
    PRIMARY KEY (`id`),
    KEY `at` (`at`),
    KEY `kind_at` (`kind`, `at`),
    KEY `license_at` (`license`, `at`),
    KEY `target_at` (`target`, `at`)
)]]

CreateThread(function()
    MySQL.query(schema, {}, function()
        Log.prune()
    end)
    local last = os.time()
    while true do
        Wait(2000)
        Log.flush()
        if os.time() - last > 86400 then
            last = os.time()
            Log.prune()
        end
    end
end)

-- -------------------------------------------------------------------- search

-- filter: kind (one or a list), player (license, or @id for someone online),
-- q (text contains), before (id, for the next page), from and to (unix
-- seconds), limit (up to 500).
function Log.query(f, cb)
    f = type(f) == 'table' and f or {}
    local clauses, params = {}, {}

    local list = type(f.kind) == 'table' and f.kind or (f.kind and f.kind ~= '' and { f.kind }) or {}
    if #list > 0 then
        clauses[#clauses + 1] = ('kind IN (%s)'):format(('?, '):rep(#list):sub(1, -3))
        for _, k in ipairs(list) do params[#params + 1] = tostring(k) end
    end

    local player = f.player and tostring(f.player)
    if player and player:find('^@') then
        local p = Log.person(player:sub(2))
        player = p and p.license
        if not player then return cb({}) end
    end
    if player and player ~= '' then
        clauses[#clauses + 1] = '(license = ? OR target = ?)'
        params[#params + 1], params[#params + 2] = player, player
    end

    if f.q and f.q ~= '' then
        clauses[#clauses + 1] = 'text LIKE ?'
        params[#params + 1] = '%' .. tostring(f.q):gsub('[%%_\\]', '\\%0') .. '%'
    end
    if tonumber(f.before) then
        clauses[#clauses + 1] = 'id < ?'
        params[#params + 1] = math.floor(tonumber(f.before))
    end
    if tonumber(f.from) then
        clauses[#clauses + 1] = 'at >= ?'
        params[#params + 1] = math.floor(tonumber(f.from))
    end
    if tonumber(f.to) then
        clauses[#clauses + 1] = 'at <= ?'
        params[#params + 1] = math.floor(tonumber(f.to))
    end

    local limit = math.max(1, math.min(500, math.floor(tonumber(f.limit) or 100)))
    local sql = 'SELECT id, at, kind, src, license, name, target, target_name AS targetName, text, data, x, y, z FROM fivelog'
    if #clauses > 0 then sql = sql .. ' WHERE ' .. table.concat(clauses, ' AND ') end
    sql = sql .. ' ORDER BY id DESC LIMIT ' .. limit

    MySQL.query(sql, params, function(rows)
        rows = rows or {}
        for _, r in ipairs(rows) do
            if type(r.data) == 'string' then r.data = json.decode(r.data) end
        end
        cb(rows)
    end)
end

-- For other resources over events, since a database answer can't be returned
-- from an export: TriggerEvent('fivelog:query', id, filter), answered with
-- 'fivelog:query:done' (id, ok, rows).
AddEventHandler('fivelog:query', function(id, filter)
    local ok, err = pcall(Log.query, filter, function(rows)
        TriggerEvent('fivelog:query:done', id, true, rows)
    end)
    if not ok then TriggerEvent('fivelog:query:done', id, false, tostring(err)) end
end)

-- ------------------------------------------------------------------- exports

exports('add', function(kind, src, text, data, target)
    if type(kind) ~= 'string' or text == nil then return end
    return Log.add(kind, src, text, { data = data, target = target }) ~= nil
end)

-- The last `count` lines that involve a player, newest last.
exports('recent', function(src, count)
    local list = Log.recent[tonumber(src)] or {}
    count = math.min(#list, tonumber(count) or #list)
    return { table.unpack(list, #list - count + 1, #list) }
end)

exports('kinds', function() return kinds end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() then Log.flush() end
end)

Log.kinds = kinds
