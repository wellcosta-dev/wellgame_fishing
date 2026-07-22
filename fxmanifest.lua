fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'wellcosta-dev | Kostyál Árpád | wellcosta.dev'
description 'Fishing — v4_fishing port for QBCore'
version '1.2.3'

shared_scripts {
    'config.lua',
    'shared/fish.lua',
}

client_scripts {
    'client/audio.lua',
    'client/main.lua',
    'client/fishing.lua',
    'client/sell.lua',
    'client/stand.lua',
    'client/sync.lua',
    'client/baitshop.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
    'server/fishing.lua',
    'server/sell.lua',
    'server/chest.lua',
    'server/sync.lua',
    'server/shop.lua',
}

-- Drop converted v4 YDR/YTD/YCD into stream/ (FiveM auto-streams)

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js',
    'html/img/*.png',
    'sounds/*.mp3',
    'sounds/*.wav',
}

dependency 'qb-core'
dependency 'qb-inventory'
dependency 'oxmysql'
