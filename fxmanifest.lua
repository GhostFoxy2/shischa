---@diagnostic disable: undefined-global

fx_version 'cerulean'
game 'gta5'

name 'shisha_final'
author 'ultimate premium'
version '12.0.0'

dependency 'ox_target'
dependency 'ox_lib'
shared_script '@ox_lib/init.lua'
shared_scripts {'config.lua'}
client_scripts {'client.lua'}
server_scripts {'server.lua'}

ui_page 'html/index.html'

files {
 'html/index.html',
 'html/style.css',
 'html/script.js'
}
