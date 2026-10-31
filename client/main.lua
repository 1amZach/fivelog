-- Tells the server when this player is hurt or dies, and names vehicle models.

local health, armour, dead = 0, 0, false

local function serverId(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return 0 end
    if IsEntityAVehicle(entity) then entity = GetPedInVehicleSeat(entity, -1) end
    if entity ~= 0 and IsEntityAPed(entity) and IsPedAPlayer(entity) then
        return GetPlayerServerId(NetworkGetPlayerIndexFromPed(entity))
    end
    return 0
end

local function bone(ped)
    local ok, b = GetPedLastDamageBone(ped)
    return ok and b or 0
end

AddEventHandler('gameEventTriggered', function(name, args)
    if name ~= 'CEventNetworkEntityDamage' then return end
    local ped = PlayerPedId()
    if args[1] ~= ped then return end

    local h, a = GetEntityHealth(ped), GetPedArmour(ped)
    local lost = math.max(0, (health - h) + (armour - a))
    health, armour = h, a

    local fatal = args[6] == 1 and not dead
    if fatal then dead = true end
    if lost == 0 and not fatal then return end

    local attacker = args[2]
    TriggerServerEvent('fivelog:hurt', attacker ~= ped and serverId(attacker) or 0, args[7], lost, bone(ped), fatal)
end)

-- Keeps the last health up to date between hits, and catches deaths that came
-- without a damage event.
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local isDead = IsEntityDead(ped)
        if isDead and not dead then
            dead = true
            TriggerServerEvent('fivelog:hurt', serverId(GetPedSourceOfDeath(ped)), GetPedCauseOfDeath(ped), 0, bone(ped), true)
        elseif not isDead then
            dead = false
            health, armour = GetEntityHealth(ped), GetPedArmour(ped)
        end
        Wait(250)
    end
end)

RegisterNetEvent('fivelog:model', function(hash)
    local name = GetDisplayNameFromVehicleModel(hash)
    local label = GetLabelText(name)
    TriggerServerEvent('fivelog:model', hash, label ~= 'NULL' and label or name)
end)
