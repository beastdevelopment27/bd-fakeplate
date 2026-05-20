--[[
    bd-fakeplate
    Fake license plate system for ESX / QBCore
    Dependencies: ox_lib, ox_inventory
]]

fx_version 'cerulean'
game 'gta5'

name 'bd-fakeplate'
description 'Synced fake license plate system (community_bridge / ESX / QBCore)'
author 'Beast Development'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'config/notifications.lua',
    'config/locale.lua',
    'config/gameplay.lua',
    'config/integrations.lua',
    'shared/bridge.lua',
}

client_scripts {
    'client/notifications.lua',
    'client.lua',
}

server_scripts {
    'server.lua',
}

dependencies {
    'ox_lib',
    'community_bridge',
}

-- Optional: oxmysql (Config.SQL.Enabled), ox_inventory (fallback if bridge disabled)
