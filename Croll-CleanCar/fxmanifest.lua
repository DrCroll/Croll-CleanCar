fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'DrCroll'
version '1.2.0'
description 'PGN-CarCleaner: Vector! That\'s me, because I commit crimes with both direction and magnitude.'

shared_scripts {
    'locales/en.lua',
    'config.lua',
    'bridge/shared.lua',
}

client_scripts {
    'bridge/client.lua',
    'client.lua',
}

server_scripts {
    'bridge/server.lua',
    'server.lua',
}
