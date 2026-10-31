-- Damage and deaths. The player who got hurt reports it, since their game is
-- the one that knows how much health they lost. Distance is worked out here.

local R = Config.record
local HEAD = 31086

local hits, rate = {}, {}

local function distance(a, b)
    local pa, pb = GetPlayerPed(a), GetPlayerPed(b)
    if pa == 0 or pb == 0 then return end
    local x, y = GetEntityCoords(pa), GetEntityCoords(pb)
    return math.floor(math.sqrt((x.x - y.x) ^ 2 + (x.y - y.y) ^ 2 + (x.z - y.z) ^ 2) + 0.5)
end

local article = Log.article

local function flushHits(key)
    local h = hits[key]
    hits[key] = nil
    if not h then return end
    local victim, attacker = Log.person(h.victim), Log.person(h.attacker)
    if not victim then return end

    local text
    if attacker then
        text = ('%s hit %s %d %s with %s for %d damage'):format(attacker.name, victim.name, h.count, h.count == 1 and 'time' or 'times',
            article(h.weapon), h.amount)
        if h.head > 0 then text = ('%s, %d to the head'):format(text, h.head) end
        if h.distance then text = ('%s, %dm away'):format(text, h.distance) end
    else
        text = ('%s took %d damage from %s'):format(victim.name, h.amount, article(h.weapon))
    end
    -- logged under the attacker, so searching a player shows what they did first
    Log.add('damage', attacker and attacker.src or victim.src, text, {
        target = attacker and victim.src or nil,
        data = { weapon = h.weapon, hits = h.count, damage = h.amount, head = h.head, distance = h.distance },
    })
end

local function death(src, attacker, weapon, headshot)
    local victim = Log.person(src)
    if not victim then return end
    local killer = attacker and Log.person(attacker)
    local label = Weapons.name(weapon)

    local text, dist
    if killer and killer ~= victim then
        dist = distance(src, killer.src)
        text = ('%s killed %s with %s'):format(killer.name, victim.name, article(label))
        if dist then text = ('%s from %dm'):format(text, dist) end
        if headshot then text = text .. ', headshot' end
    elseif killer then
        text = ('%s killed themselves with %s'):format(victim.name, article(label))
    else
        text = ('%s died from %s'):format(victim.name, article(label))
    end

    Log.add('deaths', killer and killer.src or src, text, {
        target = killer and killer ~= victim and src or nil,
        data = { weapon = label, distance = dist, headshot = headshot or nil },
        pos = GetEntityCoords(GetPlayerPed(src)),
    })
end

RegisterNetEvent('fivelog:hurt', function(attacker, weapon, amount, bone, fatal)
    local src = tonumber(source)
    if not Log.person(src) then return end

    -- a client can only send so many of these
    local t = os.time()
    local r = rate[src]
    if not r or r.at ~= t then
        r = { at = t, n = 0 }
        rate[src] = r
    end
    r.n = r.n + 1
    if r.n > 40 then return end

    attacker = tonumber(attacker)
    if attacker and (attacker <= 0 or not GetPlayerName(attacker)) then attacker = nil end
    weapon = Weapons.u32(tonumber(weapon))
    if Weapons.cause[weapon] then attacker = nil end
    amount = math.max(0, math.min(1000, math.floor(tonumber(amount) or 0)))
    local head = tonumber(bone) == HEAD

    if fatal == true then
        if R.deaths then death(src, attacker, weapon, head) end
    end

    if not R.damage or amount == 0 then return end
    local key = ('%d:%d:%d'):format(src, attacker or 0, weapon)
    local h = hits[key]
    if not h then
        h = { victim = src, attacker = attacker, weapon = Weapons.name(weapon), count = 0, amount = 0, head = 0 }
        h.distance = attacker and distance(src, attacker)
        hits[key] = h
        SetTimeout(Config.damageWindow * 1000, function() flushHits(key) end)
    end
    h.count = h.count + 1
    h.amount = h.amount + amount
    if head then h.head = h.head + 1 end
end)

AddEventHandler('playerDropped', function()
    rate[tonumber(source)] = nil
end)

Log.flushHits = flushHits
