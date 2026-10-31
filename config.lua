Config = {}

-- Days to keep logs. Anything older is deleted once a day.
Config.keepDays = 30

-- Shorter for kinds that pile up fast.
Config.keep = {
    damage = 7,
    chat = 14,
}

-- What gets logged. Set one to false to stop recording it.
Config.record = {
    joins = true,
    chat = true,
    deaths = true,
    damage = true,
    money = true,
    items = true,
    vehicles = true,
    resources = true,
}

-- Where each kind is posted on Discord.
--   false               not posted, only kept in the database
--   'https://...'       a Discord webhook
--   any other name      a channel from fivecord's Config.logs. Names fivecord
--                       doesn't have go to its default channel.
-- fivecord already posts joins, deaths, chat and resources, so they're off here.
-- Without fivecord, give them a webhook if you want them on Discord.
Config.discord = {
    joins = false,
    deaths = false,
    chat = false,
    resources = false,
    damage = false,
    money = 'money',
    items = 'items',
    vehicles = 'vehicles',
}

-- Money changes smaller than this are kept but not posted.
Config.moneyPostMin = 10000

-- Seconds between Discord posts. Lines in between are sent together.
Config.postEvery = 5

-- Hits from the same player with the same weapon within this many seconds are
-- folded into one damage log.
Config.damageWindow = 4

-- How many recent lines are kept in memory per player, for the anticheat and
-- other resources (exports.fivelog:recent).
Config.recent = 25
