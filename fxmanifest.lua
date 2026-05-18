--[[
    bd-fakeplate
    Fake license plate system for ESX / QBCore
    Dependencies: ox_lib, ox_inventory
]]

fx_version 'cerulean'
game 'gta5'

name 'bd-fakeplate'
description 'Synced fake license plate system (ESX / QBCore)'
author 'Beast Development'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    'server.lua',
}

dependencies {
    'ox_lib',
    'ox_inventory',
}

-- Optional: oxmysql (only required when Config.SQL.Enabled = true)
