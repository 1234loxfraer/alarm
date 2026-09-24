-- Character list (F1 or "jjs_menu"). Characters are grouped like on the wiki; the right side
-- shows the selected character's moves. Picking one runs "jjs_char <id>".

local CATEGORIES = {
	{ id = "complete", name = "Complete", color = Color( 240, 240, 240 ) },
	{ id = "early", name = "Early Access", color = Color( 120, 200, 255 ) },
	{ id = "baseonly", name = "Base-Only", color = Color( 160, 160, 165 ) },
	{ id = "op", name = "Overpowered", color = Color( 255, 215, 70 ) },
	{ id = "other", name = "Others", color = Color( 220, 120, 255 ) },
}

local menu

local function MoveLines( set, lines, header )
	if not set then return end
	lines[ #lines + 1 ] = { header, true }
	for slot = 1, 4 do
		local ab = set.abilities and set.abilities[ slot ]
		if ab then
			local name = ab.name
			if ab.Pick and not ab.Use then name = "(mode dependent)" end
			lines[ #lines + 1 ] = { string.format( "  %d  %s", slot, name or "?" ) }
		end
	end
	if set.special then lines[ #lines + 1 ] = { "  R  " .. ( set.special.name or "?" ) } end
	if set.alt then MoveLines( set.alt, lines, "  " .. ( set.alt.name or "Alternate set" ) ) end
end

local function Details( panel, char )
	panel:Clear()
	local lines = {}
	lines[ #lines + 1 ] = { string.upper( char.name ), true, char.color }
	lines[ #lines + 1 ] = { string.format( "HP %d%s", char.hp, char.scale and char.scale ~= 1 and ( "   size x" .. char.scale ) or "" ) }
	MoveLines( char, lines, "Base" )
	if char.awakening then
		MoveLines( char.awakening, lines, "Awakening: " .. ( char.awakening.name or "?" ) )
	end
	if char.awakenMove then
		lines[ #lines + 1 ] = { "Awakening move", true }
		lines[ #lines + 1 ] = { "  G  " .. ( char.awakenMove.name or "?" ) }
	end
	if char.passives then
		lines[ #lines + 1 ] = { "Passives", true }
		for _, p in ipairs( char.passives ) do lines[ #lines + 1 ] = { "  " .. p[ 1 ] } end
	end

	for _, l in ipairs( lines ) do
		local lbl = panel:Add( "DLabel" )
		lbl:Dock( TOP )
		lbl:SetFont( l[ 2 ] and "JJS_Move" or "JJS_Small" )
		lbl:SetTextColor( l[ 3 ] or ( l[ 2 ] and color_white or Color( 200, 200, 205 ) ) )
		lbl:SetText( l[ 1 ] )
		lbl:SizeToContentsY( 4 )
	end

	local play = panel:Add( "DButton" )
	play:Dock( BOTTOM )
	play:SetTall( 36 )
	play:SetText( "PLAY " .. string.upper( char.name ) )
	play:SetFont( "JJS_Move" )
	play.DoClick = function()
		RunConsoleCommand( "jjs_char", char.id )
		if IsValid( menu ) then menu:Close() end
	end
end

function JJS.OpenCharacterMenu()
	if IsValid( menu ) then menu:Close() return end

	menu = vgui.Create( "DFrame" )
	menu:SetSize( math.min( ScrW() - 40, 900 ), math.min( ScrH() - 40, 640 ) )
	menu:Center()
	menu:SetTitle( "Characters" )
	menu:MakePopup()

	local right = menu:Add( "DScrollPanel" )
	right:Dock( RIGHT )
	right:SetWide( menu:GetWide() * 0.45 )
	right:DockMargin( 8, 0, 0, 0 )

	local left = menu:Add( "DScrollPanel" )
	left:Dock( FILL )

	local current = LocalPlayer():GetJChar()
	for _, cat in ipairs( CATEGORIES ) do
		local header
		for _, id in ipairs( JJS.CharacterOrder ) do
			local char = JJS.Characters[ id ]
			if char.category ~= cat.id then continue end
			if not header then
				header = left:Add( "DLabel" )
				header:Dock( TOP )
				header:DockMargin( 0, 8, 0, 2 )
				header:SetFont( "JJS_Awaken" )
				header:SetText( cat.name )
				header:SetTextColor( cat.color )
				header:SizeToContentsY( 4 )
			end
			local b = left:Add( "DButton" )
			b:Dock( TOP )
			b:DockMargin( 0, 0, 0, 2 )
			b:SetTall( 28 )
			b:SetText( char.name .. ( id == current and "   (current)" or "" ) )
			b.DoClick = function() Details( right, char ) end
			b.DoDoubleClick = function()
				RunConsoleCommand( "jjs_char", id )
				menu:Close()
			end
		end
	end

	local sel = JJS.Characters[ current ] or JJS.Characters[ JJS.Config.DefaultCharacter ]
	if sel then Details( right, sel ) end
end

concommand.Add( "jjs_menu", JJS.OpenCharacterMenu )

hook.Add( "PlayerBindPress", "JJS_Menu", function( ply, bind, pressed )
	if bind == "gm_showhelp" then
		if pressed then JJS.OpenCharacterMenu() end
		return true
	end
end )
