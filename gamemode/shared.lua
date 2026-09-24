GM.Name = "Jujutsu Shenanigans"
GM.Author = "JJS port"
GM.TeamBased = false

DeriveGamemode( "base" )

JJS = JJS or {}

local ROOT = GM.FolderName .. "/gamemode/"

-- sv_ = server only, cl_ = client only, anything else = shared
function JJS.Load( path )
	local prefix = string.sub( string.GetFileFromFilename( path ), 1, 3 )
	local full = ROOT .. path

	if prefix == "sv_" then
		if SERVER then include( full ) end
	elseif prefix == "cl_" then
		if SERVER then AddCSLuaFile( full ) else include( full ) end
	else
		if SERVER then AddCSLuaFile( full ) end
		include( full )
	end
end

-- Order matters: later files use what earlier ones define.
local CORE = {
	"sh_config.lua",
	"sh_util.lua",
	"sh_playerdata.lua",
	"sh_input.lua",
	"sh_states.lua",
	"sh_characters.lua",
	"sh_actions.lua",
	"sh_combat.lua",
	"sh_kit.lua",
	"sh_kit_ents.lua",
	"sh_domain.lua",
	"sh_clash.lua",
	"sv_combat.lua",
	"sv_ragdoll.lua",
	"sh_m1.lua",
	"sh_dash.lua",
	"sh_movement.lua",
	"sh_awakening.lua",
	"sh_anim.lua",
	"sv_player.lua",
	"sh_destruction.lua",
	"sv_dummies.lua",
	"cl_fx.lua",
	"cl_camera.lua",
	"cl_hud.lua",
	"cl_kit_fx.lua",
	"cl_menu.lua",
	"sh_autotest.lua",
}

for _, f in ipairs( CORE ) do
	JJS.Load( "core/" .. f )
end

-- Each character lives in characters/<id>/ ; files load alphabetically.
local _, dirs = file.Find( ROOT .. "characters/*", "LUA" )
table.sort( dirs )
for _, dir in ipairs( dirs ) do
	local files = file.Find( ROOT .. "characters/" .. dir .. "/*.lua", "LUA" )
	table.sort( files )
	for _, f in ipairs( files ) do
		JJS.Load( "characters/" .. dir .. "/" .. f )
	end
end

hook.Run( "JJS_Loaded" )
