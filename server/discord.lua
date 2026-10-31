Discord = {}

local titles = {
    joins = 'Joins', chat = 'Chat', deaths = 'Deaths', damage = 'Damage', money = 'Money',
    items = 'Items', vehicles = 'Vehicles', resources = 'Resources',
}
local colors = {
    joins = 0x2BD9CC, deaths = 0xE5484D, damage = 0xF97316, money = 0x46A758,
    items = 0x9C2CF1, vehicles = 0x3E63DD, chat = 0x8B8D98, resources = 0x8B8D98,
}

local pending, order = {}, {}

local function fivecord() return GetResourceState('fivecord') == 'started' end
local function clean(s) return (tostring(s):gsub('[*_`~|>\\]', '\\%0'):gsub('@', '@\u{200B}')) end

function Discord.push(entry, post)
    if post == false then return end
    local dest = Config.discord[entry.kind]
    if not dest or dest == '' then return end
    local key = dest .. '|' .. entry.kind
    local list = pending[key]
    if not list then
        list = { dest = dest, kind = entry.kind, lines = {} }
        pending[key] = list
        order[#order + 1] = key
    end
    local who = entry.src and ('`%d` '):format(entry.src) or ''
    list.lines[#list.lines + 1] = ('<t:%d:T> %s%s'):format(entry.at, who, clean(entry.text))
end

local function send(dest, kind, description)
    local title, color = titles[kind] or kind, colors[kind] or 0x9C2CF1
    if dest:find('^https://') then
        local body = json.encode({
            username = 'fivelog',
            embeds = { { title = title, description = description, color = color, timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ') } },
            allowed_mentions = { parse = {} },
        })
        return PerformHttpRequest(dest, function() end, 'POST', body, { ['Content-Type'] = 'application/json' })
    end
    if fivecord() then
        pcall(function() exports.fivecord:log(dest, title, description, color) end)
    end
end

function Discord.flush()
    local keys = order
    order = {}
    for _, key in ipairs(keys) do
        local list = pending[key]
        pending[key] = nil
        local chunk = ''
        for _, line in ipairs(list.lines) do
            if #chunk + #line > 3900 then
                send(list.dest, list.kind, chunk)
                chunk = ''
            end
            chunk = chunk .. line .. '\n'
        end
        if chunk ~= '' then send(list.dest, list.kind, chunk) end
    end
end

CreateThread(function()
    while true do
        Wait(Config.postEvery * 1000)
        Discord.flush()
    end
end)
