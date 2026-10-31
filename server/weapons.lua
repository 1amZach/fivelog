-- Weapon and damage type names, looked up by hash.

local names = {
    WEAPON_UNARMED = 'Fists', WEAPON_KNIFE = 'Knife', WEAPON_NIGHTSTICK = 'Nightstick', WEAPON_HAMMER = 'Hammer',
    WEAPON_BAT = 'Bat', WEAPON_GOLFCLUB = 'Golf club', WEAPON_CROWBAR = 'Crowbar', WEAPON_BOTTLE = 'Bottle',
    WEAPON_DAGGER = 'Dagger', WEAPON_HATCHET = 'Hatchet', WEAPON_KNUCKLE = 'Knuckle duster', WEAPON_MACHETE = 'Machete',
    WEAPON_FLASHLIGHT = 'Flashlight', WEAPON_SWITCHBLADE = 'Switchblade', WEAPON_POOLCUE = 'Pool cue',
    WEAPON_WRENCH = 'Wrench', WEAPON_BATTLEAXE = 'Battle axe', WEAPON_STONE_HATCHET = 'Stone hatchet',

    WEAPON_PISTOL = 'Pistol', WEAPON_PISTOL_MK2 = 'Pistol Mk II', WEAPON_COMBATPISTOL = 'Combat pistol',
    WEAPON_APPISTOL = 'AP pistol', WEAPON_STUNGUN = 'Taser', WEAPON_PISTOL50 = 'Pistol .50',
    WEAPON_SNSPISTOL = 'SNS pistol', WEAPON_SNSPISTOL_MK2 = 'SNS pistol Mk II', WEAPON_HEAVYPISTOL = 'Heavy pistol',
    WEAPON_VINTAGEPISTOL = 'Vintage pistol', WEAPON_FLAREGUN = 'Flare gun', WEAPON_MARKSMANPISTOL = 'Marksman pistol',
    WEAPON_REVOLVER = 'Revolver', WEAPON_REVOLVER_MK2 = 'Revolver Mk II', WEAPON_DOUBLEACTION = 'Double action revolver',
    WEAPON_CERAMICPISTOL = 'Ceramic pistol', WEAPON_NAVYREVOLVER = 'Navy revolver', WEAPON_GADGETPISTOL = 'Perico pistol',
    WEAPON_PISTOLXM3 = 'WM 29 pistol',

    WEAPON_MICROSMG = 'Micro SMG', WEAPON_SMG = 'SMG', WEAPON_SMG_MK2 = 'SMG Mk II', WEAPON_ASSAULTSMG = 'Assault SMG',
    WEAPON_COMBATPDW = 'Combat PDW', WEAPON_MACHINEPISTOL = 'Machine pistol', WEAPON_MINISMG = 'Mini SMG',
    WEAPON_TECPISTOL = 'Tactical SMG', WEAPON_MG = 'MG', WEAPON_COMBATMG = 'Combat MG', WEAPON_COMBATMG_MK2 = 'Combat MG Mk II',
    WEAPON_GUSENBERG = 'Gusenberg',

    WEAPON_PUMPSHOTGUN = 'Pump shotgun', WEAPON_PUMPSHOTGUN_MK2 = 'Pump shotgun Mk II', WEAPON_SAWNOFFSHOTGUN = 'Sawed-off shotgun',
    WEAPON_ASSAULTSHOTGUN = 'Assault shotgun', WEAPON_BULLPUPSHOTGUN = 'Bullpup shotgun', WEAPON_MUSKET = 'Musket',
    WEAPON_HEAVYSHOTGUN = 'Heavy shotgun', WEAPON_DBSHOTGUN = 'Double barrel shotgun', WEAPON_AUTOSHOTGUN = 'Sweeper shotgun',
    WEAPON_COMBATSHOTGUN = 'Combat shotgun',

    WEAPON_ASSAULTRIFLE = 'Assault rifle', WEAPON_ASSAULTRIFLE_MK2 = 'Assault rifle Mk II', WEAPON_CARBINERIFLE = 'Carbine rifle',
    WEAPON_CARBINERIFLE_MK2 = 'Carbine rifle Mk II', WEAPON_ADVANCEDRIFLE = 'Advanced rifle', WEAPON_SPECIALCARBINE = 'Special carbine',
    WEAPON_SPECIALCARBINE_MK2 = 'Special carbine Mk II', WEAPON_BULLPUPRIFLE = 'Bullpup rifle', WEAPON_BULLPUPRIFLE_MK2 = 'Bullpup rifle Mk II',
    WEAPON_COMPACTRIFLE = 'Compact rifle', WEAPON_MILITARYRIFLE = 'Military rifle', WEAPON_HEAVYRIFLE = 'Heavy rifle',
    WEAPON_TACTICALRIFLE = 'Service carbine', WEAPON_BATTLERIFLE = 'Battle rifle',

    WEAPON_SNIPERRIFLE = 'Sniper rifle', WEAPON_HEAVYSNIPER = 'Heavy sniper', WEAPON_HEAVYSNIPER_MK2 = 'Heavy sniper Mk II',
    WEAPON_MARKSMANRIFLE = 'Marksman rifle', WEAPON_MARKSMANRIFLE_MK2 = 'Marksman rifle Mk II', WEAPON_PRECISIONRIFLE = 'Precision rifle',

    WEAPON_RPG = 'RPG', WEAPON_GRENADELAUNCHER = 'Grenade launcher', WEAPON_MINIGUN = 'Minigun', WEAPON_FIREWORK = 'Firework launcher',
    WEAPON_RAILGUN = 'Railgun', WEAPON_HOMINGLAUNCHER = 'Homing launcher', WEAPON_COMPACTLAUNCHER = 'Compact launcher',
    WEAPON_GRENADE = 'Grenade', WEAPON_STICKYBOMB = 'Sticky bomb', WEAPON_PROXMINE = 'Proximity mine', WEAPON_PIPEBOMB = 'Pipe bomb',
    WEAPON_MOLOTOV = 'Molotov', WEAPON_BZGAS = 'BZ gas', WEAPON_SMOKEGRENADE = 'Tear gas', WEAPON_SNOWBALL = 'Snowball',
    WEAPON_PETROLCAN = 'Jerry can', WEAPON_FIREEXTINGUISHER = 'Fire extinguisher',

    WEAPON_FALL = 'a fall', WEAPON_DROWNING = 'drowning', WEAPON_DROWNING_IN_VEHICLE = 'drowning',
    WEAPON_RUN_OVER_BY_CAR = 'a car', WEAPON_RAMMED_BY_CAR = 'a car', WEAPON_EXPLOSION = 'an explosion',
    WEAPON_FIRE = 'fire', WEAPON_BLEEDING = 'bleeding', WEAPON_ANIMAL = 'an animal', WEAPON_COUGAR = 'a cougar',
    WEAPON_BARBED_WIRE = 'barbed wire', WEAPON_ELECTRIC_FENCE = 'an electric fence', WEAPON_EXHAUSTION = 'exhaustion',
    WEAPON_HIT_BY_WATER_CANNON = 'a water cannon', WEAPON_HELI_CRASH = 'a helicopter crash',
    VEHICLE_WEAPON_ROTORS = 'rotor blades',
}

-- Not weapons a person holds, so a death by one of these has no killer.
local causes = {
    WEAPON_FALL = true, WEAPON_DROWNING = true, WEAPON_DROWNING_IN_VEHICLE = true, WEAPON_EXPLOSION = true,
    WEAPON_FIRE = true, WEAPON_BLEEDING = true, WEAPON_ANIMAL = true, WEAPON_COUGAR = true, WEAPON_BARBED_WIRE = true,
    WEAPON_ELECTRIC_FENCE = true, WEAPON_EXHAUSTION = true, WEAPON_HIT_BY_WATER_CANNON = true, WEAPON_HELI_CRASH = true,
}

Weapons = { byHash = {}, cause = {} }

local function u32(n) return (math.tointeger(n) or 0) & 0xFFFFFFFF end
Weapons.u32 = u32

for name, label in pairs(names) do
    local h = u32(GetHashKey(name))
    Weapons.byHash[h] = label
    if causes[name] then Weapons.cause[h] = true end
end

function Weapons.name(hash)
    hash = u32(tonumber(hash))
    return Weapons.byHash[hash] or ('weapon %d'):format(hash)
end
