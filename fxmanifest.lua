fx_version 'cerulean'
game 'gta5'

description 'QBX_TaxiJob'
repository 'https://github.com/Qbox-project/qbx_taxijob'
version '1.0.0'

shared_scripts {
	'@ox_lib/init.lua',
	'@qbx_core/modules/lib.lua'	
}

client_scripts {
	'@qbx_core/modules/playerdata.lua',
	 'client/main.lua',
}

server_scripts {
	'server/db.lua',
	'server/main.lua'
}

-- NUI page now built with React (Vite) into html/dist
ui_page 'html/dist/index.html'

files {
	-- React build output
	'html/dist/index.html',
	'html/dist/assets/*',
	'config/client.lua',
	'config/shared.lua',
	'locales/*.json',
	-- Ensure client modules are downloadable for ox_lib require() without executing them twice
	'client/*.lua'
}

provide 'qb-taxijob'
lua54 'yes'
use_experimental_fxv2_oal 'yes'
ox_lib 'locale'
dependency 'qbx_core'
