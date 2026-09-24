-- Beam clash: two ultimate beams (kit Beam moves with a `clash` strength) fired at each other
-- lock both users in a 4s quick-time event. Each correct W/A/D press moves the meter; the
-- stronger beam gets a head start (Plasma Wave < Flower Beam < True Love Beam < Every Last
-- Drop. < Flower Beam (DOMAIN)). The winner's beam then fires at full power, the loser's fizzles.

local U = JJS.Util
local cfg = JJS.Config.BeamClash

JJS.Clash = JJS.Clash or {}
local C = JJS.Clash

function C.Foe( ply )
	local f = ply:GetNW2Entity( "JJSClashFoe" )
	if IsValid( f ) and ply:GetNW2Float( "JJSClashEnd" ) > CurTime() then return f end
end

JJS.RegisterAction( "beam_clash", {
	dur = cfg.Time + 0.1,
	moveMult = 0,
	noJump = true,
	uninterruptible = true,
	armor = { all = true },
	gesture = "gesture_bow",
} )

if SERVER then
	local function Begin( ply, foe, p, headStart )
		ply.jjs_clash = { p = p, foe = foe }
		ply:SetNW2Entity( "JJSClashFoe", foe )
		ply:SetNW2Float( "JJSClashEnd", CurTime() + cfg.Time )
		ply:SetNW2Int( "JJSClashScore", headStart )
		ply:SetNW2Int( "JJSClashKey", math.random( #cfg.Keys ) )
		ply:SetEyeAngles( ( U.BodyCenter( foe ) - ply:EyePos() ):Angle() )
		JJS.StartAction( ply, "beam_clash" )
		JJS.IFrames( ply, cfg.Time )
	end

	local function ClashBeam( ply )
		local act = JJS.GetAction( ply )
		return act and act.kitParams and act.kitParams.clash and act.kitParams
	end

	-- Called when a clash beam fires; returns true if a clash started
	function C.TryStart( ply, p )
		if C.Foe( ply ) then return true end
		local best, bestD
		for _, o in ipairs( player.GetAll() ) do
			if o == ply or not o:Alive() or C.Foe( o ) then continue end
			local op = ClashBeam( o )
			if not op then continue end
			local d = o:GetPos():Distance( ply:GetPos() )
			if d < cfg.Range and ( not bestD or d < bestD ) then best, bestD = o, d end
		end
		if not best then return false end

		local op = ClashBeam( best )
		local diff = ( p.clash or 1 ) - ( op.clash or 1 )
		Begin( ply, best, p, math.max( diff, 0 ) * cfg.HeadStart )
		Begin( best, ply, op, math.max( -diff, 0 ) * cfg.HeadStart )
		hook.Run( "JJS_BeamClash", ply, best )
		return true
	end

	local function Finish( ply, won )
		local st = ply.jjs_clash
		ply.jjs_clash = nil
		ply:SetNW2Entity( "JJSClashFoe", NULL )
		ply:SetNW2Float( "JJSClashEnd", 0 )
		if not st or not ply:Alive() then return end
		JJS.StopAction( ply, false )
		if won then
			local p = table.Copy( st.p )
			p.hits = 1
			p.pierce = true
			if IsValid( st.foe ) then ply:SetEyeAngles( ( U.BodyCenter( st.foe ) - ply:EyePos() ):Angle() ) end
			JJS.Kit.FireRay( ply, p, 1 )
		else
			ply:SetJIFrameEnd( 0 ) -- the loser is left open
		end
	end

	hook.Add( "SetupMove", "JJS_BeamClashInput", function( ply, mv )
		if not ply.jjs_clash then return end
		local key = cfg.Keys[ ply:GetNW2Int( "JJSClashKey" ) ]
		for i, k in ipairs( cfg.Keys ) do
			if mv:KeyPressed( k ) then
				if k == key then
					ply:SetNW2Int( "JJSClashScore", ply:GetNW2Int( "JJSClashScore" ) + 1 )
					ply:SetNW2Int( "JJSClashKey", math.random( #cfg.Keys ) )
				end
				break
			end
		end
	end )

	hook.Add( "Tick", "JJS_BeamClash", function()
		local now = CurTime()
		for _, ply in ipairs( player.GetAll() ) do
			local st = ply.jjs_clash
			if not st or ply:GetNW2Float( "JJSClashEnd" ) > now then continue end
			local foe = st.foe
			local mine = ply:GetNW2Int( "JJSClashScore" )
			local theirs = IsValid( foe ) and foe:GetNW2Int( "JJSClashScore" ) or -1
			local won = mine >= theirs -- the one resolving first wins ties
			Finish( ply, won )
			if IsValid( foe ) and foe.jjs_clash then Finish( foe, not won ) end
		end
	end )
end

if SERVER then return end

local KEY_NAMES = { "W", "A", "D" }

hook.Add( "JJS_HUDPaint", "JJS_BeamClash", function( ply, now, S )
	local foe = C.Foe( ply )
	if not foe then return end
	local mine, theirs = ply:GetNW2Int( "JJSClashScore" ), foe:GetNW2Int( "JJSClashScore" )
	local total = math.max( mine + theirs, 1 )
	local w, h = S( 460 ), S( 14 )
	local x, y = ScrW() / 2 - w / 2, ScrH() - S( 190 )
	surface.SetDrawColor( 255, 90, 90 )
	surface.DrawRect( x, y, w, h )
	surface.SetDrawColor( 120, 200, 255 )
	surface.DrawRect( x, y, w * ( mine / total ), h )
	surface.SetDrawColor( 255, 255, 255, 60 )
	surface.DrawOutlinedRect( x, y, w, h, 1 )

	local key = KEY_NAMES[ ply:GetNW2Int( "JJSClashKey" ) ] or "?"
	draw.SimpleTextOutlined( "[" .. key .. "]", "JJS_CD", ScrW() / 2, y - S( 10 ), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, color_black )
	draw.SimpleText( string.format( "BEAM CLASH  %.1f", ply:GetNW2Float( "JJSClashEnd" ) - now ), "JJS_Small", ScrW() / 2, y + h + S( 4 ), color_white, TEXT_ALIGN_CENTER )
end )
