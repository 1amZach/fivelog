fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fivelog'
description 'Logs kills, damage, chat, money, items, vehicles and joins to MariaDB and Discord'
version '1.0.0'
author 'IamZach'
discord 'https://discord.gg/agn'
repository 'https://github.com/1amZach/fivelog'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'config.lua',
    'server/weapons.lua',
    'server/core.lua',
    'server/discord.lua',
    'server/sources.lua',
    'server/combat.lua',
}

client_script 'client/main.lua'

dependency 'oxmysql'
