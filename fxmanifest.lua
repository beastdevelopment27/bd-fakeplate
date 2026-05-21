fx_version 'cerulean'
game 'gta5'

name 'bd-fakeplate'
description 'Synced fake license plate system (ESX / QBCore / ox_lib)'
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
    'shared/integrations/core.lua',
    'shared/integrations/notify.lua',
    'shared/integrations/inventory.lua',
    'shared/integrations/progressbar.lua',
    'shared/integrations/dialogue.lua',
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
}
