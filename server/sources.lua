-- Everything logged that isn't combat.

local R = Config.record

local function duration(s)
    s = math.max(0, math.floor(s))
    if s < 60 then return s .. 's' end
    local m = s // 60
    if m < 60 then return m .. 'm' end
    return ('%dh %dm'):format(m // 60, m % 60)
end

local function money(n)
    local s = tostring(math.floor(math.abs(n)))
    s = s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return (n < 0 and '-$' or '$') .. s
end
Log.money = money

-- "a Pistol", "an Adder", and causes that read fine on their own
local bare = { fists = true, fire = true, drowning = true, bleeding = true, exhaustion = true, ['barbed wire'] = true }
function Log.article(label)
    if label == 'Fists' then return 'fists' end
    if bare[label] or label:find('^an? ') then return label end
    return ('%s %s'):format(label:find('^[AEIOUaeiou]') and 'an' or 'a', label)
end

-- ---------------------------------------------------------------------- joins

AddEventHandler('playerJoining', function()
    local src = source
    local p = Log.person(src)
    if not p or not R.joins then return end
    Log.add('joins', src, ('%s joined'):format(p.name), { data = { identifiers = p.identifiers } })
end)

AddEventHandler('playerDropped', function(reason)
    local src = tonumber(source)
    local p = Log.people[src]
    if p and R.joins then
        Log.add('joins', src, ('%s left after %s: %s'):format(p.name, duration(os.time() - p.joined), reason or 'no reason'))
    end
    Log.people[src] = nil
    Log.recent[src] = nil
end)

-- ----------------------------------------------------------------------- chat

AddEventHandler('chatMessage', function(src, author, text)
    if not R.chat or type(text) ~= 'string' or text:sub(1, 1) == '/' then return end
    local p = Log.person(src)
    Log.add('chat', src, ('%s: %s'):format(p and p.name or author, text))
end)

-- ---------------------------------------------------------------------- money
-- Qbox and QBCore send QBCore:Server:OnMoneyChange, ESX sends one event for each.

local function moneyLog(src, account, change, reason, set)
    if not R.money then return end
    change = tonumber(change)
    if not change or (change == 0 and not set) then return end
    local p = Log.person(src)
    if not p then return end

    local text
    if set then
        text = ('%s %s set to %s'):format(p.name, account, money(change))
    elseif change > 0 then
        text = ('%s got %s %s'):format(p.name, money(change), account)
    else
        text = ('%s lost %s %s'):format(p.name, money(-change), account)
    end
    if reason and reason ~= '' then text = ('%s (%s)'):format(text, reason) end

    Log.add('money', src, text, {
        data = { account = account, change = change, set = set or nil, reason = reason },
        post = math.abs(change) >= Config.moneyPostMin,
    })
end

AddEventHandler('QBCore:Server:OnMoneyChange', function(src, account, amount, action, reason)
    if action == 'set' then return moneyLog(src, account, amount, reason, true) end
    moneyLog(src, account, action == 'remove' and -(tonumber(amount) or 0) or amount, reason)
end)

AddEventHandler('esx:addAccountMoney', function(src, account, amount, reason)
    moneyLog(src, account, amount, reason)
end)

AddEventHandler('esx:removeAccountMoney', function(src, account, amount, reason)
    moneyLog(src, account, -(tonumber(amount) or 0), reason)
end)

AddEventHandler('esx:setAccountMoney', function(src, account, amount, reason)
    if type(src) ~= 'number' then return end -- the client version of this event has no player
    moneyLog(src, account, amount, reason, true)
end)

-- ---------------------------------------------------------------------- items
-- ox_inventory only. Moves inside one inventory aren't logged.

local function itemLabel(name)
    local ok, item = pcall(function() return exports.ox_inventory:Items(name) end)
    return ok and item and item.label or name
end

local function place(kind, id)
    if kind == 'player' then
        local p = Log.person(id)
        return p and p.name or ('player ' .. tostring(id))
    end
    if kind == 'trunk' or kind == 'glovebox' then
        return ('%s %s'):format(kind, (tostring(id):gsub('^' .. kind, '')))
    end
    return ('%s %s'):format(kind, tostring(id))
end

function Log.swap(p)
    if not R.items or p.fromInventory == p.toInventory then return end
    local slot = type(p.fromSlot) == 'table' and p.fromSlot
    if not slot then return end

    local src = p.source
    local who = Log.person(src)
    if not who then return end
    local what = ('%dx %s'):format(tonumber(p.count) or slot.count or 1, itemLabel(slot.name))
    local data = { item = slot.name, count = p.count, from = p.fromInventory, to = p.toInventory, fromType = p.fromType, toType = p.toType }

    local text, target
    local toDrop = p.toType == 'drop' or p.toInventory == 'newdrop'
    if p.fromType == 'player' and p.toType == 'player' then
        target = tonumber(p.toInventory)
        if target == src then target = tonumber(p.fromInventory) end
        text = ('%s gave %s to %s'):format(who.name, what, place('player', target))
    elseif toDrop then
        text = ('%s dropped %s'):format(who.name, what)
    elseif p.fromType == 'drop' then
        text = ('%s picked up %s'):format(who.name, what)
    elseif p.fromType == 'player' then
        text = ('%s put %s in %s'):format(who.name, what, place(p.toType, p.toInventory))
    else
        text = ('%s took %s from %s'):format(who.name, what, place(p.fromType, p.fromInventory))
    end
    Log.add('items', src, text, { target = target, data = data })
end

function Log.buy(p)
    if not R.items then return end
    local who = Log.person(p.source)
    if not who then return end
    local price = tonumber(p.totalPrice) or 0
    local text = ('%s bought %dx %s for %s'):format(who.name, tonumber(p.count) or 1, itemLabel(p.itemName), money(price))
    if p.shopType then text = ('%s at %s'):format(text, p.shopType) end
    Log.add('items', p.source, text, { data = { item = p.itemName, count = p.count, price = price, shop = p.shopType } })
end

local hooked = false
local function hookInventory()
    if hooked or GetResourceState('ox_inventory') ~= 'started' then return end
    hooked = true
    exports.ox_inventory:registerHook('swapItems', function(p) Log.swap(p) end, {})
    exports.ox_inventory:registerHook('buyItem', function(p) Log.buy(p) end, {})
end

-- ------------------------------------------------------------------- vehicles
-- Script spawned vehicles only, like garages, admin spawns and cheat menus.
-- The model name comes from the spawner's game, since the server has no list.

local models, waiting = {}, {}

local function vehicleLog(owner, hash, plate)
    local p = Log.person(owner)
    if not p then return end
    local name = models[hash] or ('model %d'):format(hash)
    Log.add('vehicles', owner, ('%s spawned %s (%s)'):format(p.name, Log.article(name), plate), { data = { model = models[hash], hash = hash, plate = plate } })
end

AddEventHandler('entityCreated', function(entity)
    if not R.vehicles or not DoesEntityExist(entity) or GetEntityType(entity) ~= 2 then return end
    if GetEntityPopulationType(entity) ~= 7 then return end
    local owner = NetworkGetFirstEntityOwner(entity)
    if not owner or owner <= 0 then return end

    local hash = Weapons.u32(GetEntityModel(entity))
    local plate = (GetVehicleNumberPlateText(entity) or ''):gsub('^%s+', ''):gsub('%s+$', '')
    if models[hash] then return vehicleLog(owner, hash, plate) end

    local list = waiting[hash]
    if not list then
        list = {}
        waiting[hash] = list
        TriggerClientEvent('fivelog:model', owner, hash)
        SetTimeout(3000, function()
            if waiting[hash] ~= list then return end
            waiting[hash] = nil
            for _, w in ipairs(list) do vehicleLog(w[1], hash, w[2]) end
        end)
    end
    list[#list + 1] = { owner, plate }
end)

RegisterNetEvent('fivelog:model', function(hash, name)
    hash = Weapons.u32(tonumber(hash))
    local list = waiting[hash]
    if not list or type(name) ~= 'string' then return end
    name = name:gsub('[^%w%s%-]', ''):sub(1, 32)
    if name == '' or name == 'CARNOTFOUND' then return end
    models[hash] = name
    waiting[hash] = nil
    for _, w in ipairs(list) do vehicleLog(w[1], hash, w[2]) end
end)

-- ------------------------------------------------------------------ resources

AddEventHandler('onResourceStart', function(name)
    if name == 'ox_inventory' then hooked = false end
    if name == 'ox_inventory' or name == GetCurrentResourceName() then SetTimeout(1000, hookInventory) end
    if R.resources and name ~= GetCurrentResourceName() then Log.add('resources', nil, name .. ' started') end
end)

AddEventHandler('onResourceStop', function(name)
    if R.resources and name ~= GetCurrentResourceName() then Log.add('resources', nil, name .. ' stopped') end
end)
