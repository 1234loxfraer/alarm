-- HUD (JJS layout): 4 move boxes at the bottom centre, awakening bar above them, special
-- cooldown to their right with the evasive bar just left of it, health bar top-right
-- (hidden when full), shift-lock cursor, overhead names/health and the dummy square.

local HIDE = {
	CHudHealth = true, CHudBattery = true, CHudAmmo = true, CHudSecondaryAmmo = true,
	CHudCrosshair = true, CHudDamageIndicator = true, CHudWeaponSelection = true,
	CHudPoisonDamageIndicator = true, CHudSquadStatus = true, CHudZoom = true,
}

function GM:HUDShouldDraw( name )
	if HIDE[ name ] then return false end
	return true
end

function GM:HUDDrawTargetID() end
function GM:DrawDeathNotice( x, y ) end

local C = {
	box = Color( 12, 12, 14, 215 ),
	boxEdge = Color( 255, 255, 255, 28 ),
	text = Color( 240, 240, 240 ),
	dim = Color( 160, 160, 165 ),
	cd = Color( 0, 0, 0, 170 ),
	tip = Color( 255, 206, 84 ),
	hp = Color( 94, 210, 110 ),
	hpLow = Color( 230, 70, 60 ),
	hpBack = Color( 30, 30, 32, 220 ),
	evasive = Color( 235, 235, 235 ),
	awaken = Color( 255, 255, 255 ),
}

local sc = 1
local function S( v ) return math.Round( v * sc ) end

local function MakeFonts()
	sc = math.Clamp( ScrH() / 1080, 0.6, 2 )
	surface.CreateFont( "JJS_Move", { font = "Roboto Cn", size = S( 20 ), weight = 700, antialias = true } )
	surface.CreateFont( "JJS_Key", { font = "Roboto Bk", size = S( 15 ), weight = 700, antialias = true } )
	surface.CreateFont( "JJS_Tip", { font = "Roboto Cn", size = S( 13 ), weight = 700, antialias = true } )
	surface.CreateFont( "JJS_CD", { font = "Roboto Bk", size = S( 30 ), weight = 700, antialias = true } )
	surface.CreateFont( "JJS_Small", { font = "Roboto Cn", size = S( 15 ), weight = 700, antialias = true } )
	surface.CreateFont( "JJS_Awaken", { font = "Roboto Bk", size = S( 18 ), weight = 700, antialias = true } )
	surface.CreateFont( "JJS_HP", { font = "Roboto Bk", size = S( 16 ), weight = 700, antialias = true } )
	surface.CreateFont( "JJS_Over", { font = "Roboto Cn", size = 30, weight = 700, antialias = true } )
end
MakeFonts()
hook.Add( "OnScreenSizeChanged", "JJS_HUDFonts", MakeFonts )

local function Box( x, y, w, h, col )
	surface.SetDrawColor( col or C.box )
	surface.DrawRect( x, y, w, h )
	surface.SetDrawColor( C.boxEdge )
	surface.DrawOutlinedRect( x, y, w, h, 1 )
end

local function KeyName( cv )
	local k = cv and cv:GetInt() or 0
	if k <= 0 then return "" end
	local n = input.GetKeyName( k ) or ""
	return string.upper( n )
end

-- Wraps a move name into up to 3 lines that fit `w`
local wrapCache = {}
local function Wrap( text, w )
	local key = text .. "|" .. w
	if wrapCache[ key ] then return wrapCache[ key ] end
	surface.SetFont( "JJS_Move" )
	local lines, line = {}, ""
	for word in string.gmatch( text, "%S+" ) do
		local try = line == "" and word or line .. " " .. word
		if surface.GetTextSize( try ) > w and line ~= "" then
			lines[ #lines + 1 ] = line
			line = word
		else
			line = try
		end
	end
	if line ~= "" then lines[ #lines + 1 ] = line end
	wrapCache[ key ] = lines
	return lines
end

local function DrawMove( x, y, w, h, ab, key, cdEnd, now, tip )
	Box( x, y, w, h )
	draw.SimpleText( key, "JJS_Key", x + S( 6 ), y + S( 4 ), C.dim )
	if not ab then return end

	local lines = Wrap( ab.name or "?", w - S( 12 ) )
	local lh = draw.GetFontHeight( "JJS_Move" )
	local ty = y + h / 2 - #lines * lh / 2 - S( 2 )
	for i, l in ipairs( lines ) do
		draw.SimpleText( l, "JJS_Move", x + w / 2, ty + ( i - 1 ) * lh, C.text, TEXT_ALIGN_CENTER )
	end
	if tip and tip ~= "" then
		draw.SimpleText( tip, "JJS_Tip", x + w / 2, y + h - S( 4 ), C.tip, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
	end

	local left = cdEnd - now
	if left > 0 then
		local frac = math.Clamp( left / math.max( ab.cooldown or left, 0.01 ), 0, 1 )
		surface.SetDrawColor( C.cd )
		surface.DrawRect( x + 1, y + 1 + ( h - 2 ) * ( 1 - frac ), w - 2, ( h - 2 ) * frac )
		draw.SimpleText( left >= 10 and string.format( "%d", left ) or string.format( "%.1f", left ),
			"JJS_CD", x + w / 2, y + h / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end
end

local function TipOf( ab, ply, slot )
	local tip = ab and ab.tip
	if isfunction( tip ) then tip = tip( ply, slot ) end
	return tip
end

local function DrawBar( x, y, w, h, frac, col, back )
	surface.SetDrawColor( back or C.hpBack )
	surface.DrawRect( x, y, w, h )
	surface.SetDrawColor( col )
	surface.DrawRect( x, y, w * math.Clamp( frac, 0, 1 ), h )
	surface.SetDrawColor( C.boxEdge )
	surface.DrawOutlinedRect( x, y, w, h, 1 )
end

local function DrawHealth( ply )
	local hp, max = ply:GetJHP(), ply:GetMaxHealth()
	if hp >= max or not ply:Alive() then return end
	local w, h = S( 300 ), S( 16 )
	local x, y = ScrW() - w - S( 28 ), S( 28 )
	local frac = hp / max
	DrawBar( x, y, w, h, frac, frac <= 0.3 and C.hpLow or C.hp )
	draw.SimpleText( string.format( "%d / %d", math.ceil( hp ), max ), "JJS_HP", x + w, y + h + S( 3 ), C.text, TEXT_ALIGN_RIGHT )
end

local function DrawKit( ply, now )
	local char = JJS.GetChar( ply )
	if not char then return end

	local bw, bh, gap = S( 108 ), S( 80 ), S( 8 )
	local rowW = bw * 4 + gap * 3
	local x0 = ScrW() / 2 - rowW / 2
	local y0 = ScrH() - bh - S( 28 )
	local B = JJS.Binds

	for slot = 1, 4 do
		local ab = JJS.GetAbility( ply, slot )
		DrawMove( x0 + ( slot - 1 ) * ( bw + gap ), y0, bw, bh, ab, KeyName( B[ "a" .. slot ] ), JJS.GetCooldown( ply, slot ), now, TipOf( ab, ply, slot ) )
	end

	-- alternate moveset (Rika, Ten Shadows' switch..)
	local set = JJS.GetKit( ply )
	if ply:GetJKitSet() == 1 and set and set.name then
		draw.SimpleText( string.upper( set.name ), "JJS_Small", x0, y0 - S( 26 ), char.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM )
	end

	-- special + evasive bar to its left
	local sw = S( 62 )
	local sx = x0 + rowW + gap + S( 14 )
	local sy = y0 + bh - sw
	local special = JJS.GetAbility( ply, 5 )
	DrawMove( sx, sy, sw, sw, special and { name = "", cooldown = special.cooldown } or nil, KeyName( B.special ), JJS.GetCooldown( ply, 5 ), now )
	if special then
		draw.SimpleText( special.name or "", "JJS_Tip", sx + sw / 2, sy + sw / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		local tip = TipOf( special, ply, 5 )
		if tip and tip ~= "" then
			draw.SimpleText( tip, "JJS_Tip", sx + sw / 2, sy - S( 3 ), C.tip, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
		end
	end

	local ev = ply:GetJEvasive()
	local ew = S( 8 )
	local ex = sx - ew - S( 6 )
	surface.SetDrawColor( C.hpBack )
	surface.DrawRect( ex, sy, ew, sw )
	local full = ev >= 1
	local col = full and Color( 255, 255, 255, 200 + 55 * math.sin( now * 8 ) ) or C.evasive
	surface.SetDrawColor( col )
	surface.DrawRect( ex, sy + sw * ( 1 - ev ), ew, sw * ev )

	-- awakening bar
	local ah = S( 10 )
	local ay = y0 - ah - S( 10 )
	local fill = ply:GetJAwaken()
	local awake = ply:GetJAwakened()
	local barCol = awake and char.color or C.awaken
	if not awake and fill >= 1 then
		local pulse = 0.5 + 0.5 * math.sin( now * 10 )
		barCol = Color( 255, 255, 255, 180 + 75 * pulse )
	end
	DrawBar( x0, ay, rowW, ah, fill, barCol )
	local label
	if char.barName then
		label = string.upper( char.barName )
	elseif awake then
		label = string.upper( char.awakening and char.awakening.name or "Awakened" )
	elseif fill >= 1 then
		label = "PRESS [" .. KeyName( B.awaken ) .. "] TO AWAKEN"
		if char.awakenMove then label = label .. ": " .. string.upper( char.awakenMove.name or "" ) end
	end
	if label then
		draw.SimpleText( label, "JJS_Awaken", x0 + rowW / 2, ay - S( 3 ), C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
	end

	-- dash cooldowns (small, under the special)
	local fcd, scd = ply:GetJDashFrontCD() - now, ply:GetJDashSideCD() - now
	if fcd > 0 or scd > 0 then
		local txt = ( fcd > 0 and string.format( "F %.1f", fcd ) or "" ) .. ( scd > 0 and string.format( "  S %.1f", scd ) or "" )
		draw.SimpleText( txt, "JJS_Tip", sx + sw / 2, sy + sw + S( 4 ), C.dim, TEXT_ALIGN_CENTER )
	end
end

local function DrawCursor( ply )
	if not ply:GetJShiftLock() or not ply:Alive() then return end
	local x, y = ScrW() / 2, ScrH() / 2
	local r = S( 7 )
	surface.DrawCircle( x, y, r, 255, 255, 255, 200 )
	surface.SetDrawColor( 255, 255, 255, 230 )
	surface.DrawRect( x - 1, y - 1, 2, 2 )
end

function GM:HUDPaint()
	local ply = LocalPlayer()
	if not IsValid( ply ) then return end
	local now = CurTime()

	-- blinded (Earthen Insects' substance, Jawbreaker's blur)
	local blind = ply:GetNW2Float( "JJSBlind", 0 ) - now
	if blind > 0 then
		surface.SetDrawColor( 10, 8, 6, 235 * math.min( 1, blind / 0.5 ) )
		surface.DrawRect( 0, 0, ScrW(), ScrH() )
	end

	DrawHealth( ply )
	DrawKit( ply, now )
	DrawCursor( ply )

	local char = JJS.GetChar( ply )
	if char and char.HUDPaint then char.HUDPaint( ply, now, S ) end
	hook.Run( "JJS_HUDPaint", ply, now, S )
end

------------------------------------------------------------------------------------------
-- Overhead: name + health bar, dummy status square (green, red while stunned/ragdolled)
------------------------------------------------------------------------------------------

local SQUARE_OK = Color( 40, 220, 60 )
local SQUARE_BAD = Color( 230, 30, 30 )

hook.Add( "PostDrawTranslucentRenderables", "JJS_Overhead", function( depth, sky )
	if sky then return end
	local me = LocalPlayer()
	local eye = EyePos()

	for _, ply in ipairs( player.GetAll() ) do
		if ply == me or not ply:Alive() then continue end
		local base = ply:GetJRagdolled() and IsValid( ply:GetJRagEnt() ) and ply:GetJRagEnt():WorldSpaceCenter() + Vector( 0, 0, 30 )
			or ply:GetPos() + Vector( 0, 0, 84 )
		if eye:DistToSqr( base ) > 3000 * 3000 then continue end

		local ang = ( eye - base ):Angle()
		ang = Angle( 0, ang.y + 90, 90 )

		cam.Start3D2D( base, ang, 0.12 )
			draw.SimpleTextOutlined( ply:Nick(), "JJS_Over", 0, 0, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color( 0, 0, 0, 200 ) )
			local frac = math.Clamp( ply:GetJHP() / math.max( ply:GetMaxHealth(), 1 ), 0, 1 )
			surface.SetDrawColor( 0, 0, 0, 180 )
			surface.DrawRect( -80, 6, 160, 10 )
			surface.SetDrawColor( frac <= 0.3 and C.hpLow or C.hp )
			surface.DrawRect( -79, 7, 158 * frac, 8 )
		cam.End3D2D()

		if ply:GetJDummy() > 0 then
			local col = JJS.IsDisabled( ply ) and SQUARE_BAD or SQUARE_OK
			cam.Start3D2D( base + Vector( 0, 0, 14 ), ang, 0.12 )
				surface.SetDrawColor( col )
				surface.DrawRect( -60, -120, 120, 120 )
			cam.End3D2D()
		end
	end
end )
