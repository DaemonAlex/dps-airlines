fx_version 'cerulean'
game 'gta5'

name 'dps-airlines'
author 'DPS Scripts'
description 'Full airline job system with multi-framework support'
version '3.0.0'

lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'bridge/loader.lua',
    'shared/constants.lua',
    'shared/config.lua',
    'shared/locations.lua',
}

client_scripts {
    'client/main.lua',
    'client/ui/nui.lua',
    'client/utils/*.lua',
    'client/roles/*.lua',
    'client/systems/*.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/utils/cache.lua',
    'server/validation.lua',
    'server/payments.lua',
    'server/main.lua',
    'server/roles/*.lua',
    'server/systems/*.lua',
}

ui_page 'web/dist/index.html'

files {
    'web/dist/**/*',
}
