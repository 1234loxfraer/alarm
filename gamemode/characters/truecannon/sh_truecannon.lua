-- True Cannon (Ryu Ishigori).
-- Core stage: Cursed Energy Discharge (3-hit M1 string, final neutral hit fires a 24 stud
-- ray for 8 damage while Overheat < 90%) and the Overheat meter. The moves are registered
-- with their JJS names/cooldowns; their logic comes in the next stage.

local S = JJS.STUD
local U = JJS.Util

-- The patched copy includes the JJS animation library; the workshop original is the fallback
local MODEL = "models/jjs/ryu.mdl"
if not util.IsValidModel( MODEL ) and not file.Exists( MODEL, "GAME" ) then
	MODEL = "models/reiko/jujutsu/characters/ryu.mdl"
end

local TC = {
	name = "True Cannon",
	model = MODEL,
	color = Color( 120, 220, 255 ),
	idle = "jjs_tc_idle",

	m1 = {
		Count = 3,
		Damage = { 3, 3, 4 },
		RayDamage = 8,
		RayRange = 24 * S,
		RayRadius = 2.5 * S,
		RayOverheat = 0.1,
		-- full-body sequences from the animation library (missing ones fall back to gestures)
		-- alternate final: overheated (>= 90%) neutral finisher has no ray
		Alt = function( ply, idx, variant ) return idx >= 3 and variant == 0 and ply:GetJRes1() >= 0.9 end,
		Seq = function( ply, idx, variant, alt )
			if idx < 3 then return "jjs_tc_m1_" .. idx end
			if variant == 1 then return "jjs_tc_m1_up" end
			if variant == 2 then return "jjs_tc_m1_down" end
			return alt and "jjs_tc_m1_3b" or "jjs_tc_m1_3"
		end,
	},

	abilities = {
		[ 1 ] = { name = "Granite Blast", tip = "HOLD", cooldown = 0.5 },
		[ 2 ] = { name = "Unsatisfied", cooldown = 20 },
		[ 3 ] = { name = "Second Helping", tip = "TARGET", cooldown = 15 },
		[ 4 ] = { name = "Appetizer", cooldown = 18 },
	},
	special = { name = "Restyle", cooldown = 17 },

	awakening = {
		name = "Every Last Drop.",
		duration = 90,
		abilities = {
			[ 1 ] = { name = "\"What are you after?\"", cooldown = 18 },
			[ 2 ] = { name = "\"I had no idea..\"", tip = "HIT", cooldown = 15 },
			[ 3 ] = { name = "\"This is what dessert is like!\"", cooldown = 20 },
			[ 4 ] = { name = "\"You weren't invited.\"", tip = "HOLD", cooldown = 20 },
		},
		special = { name = "Restyle", cooldown = 17 },
	},
}

-- Overheat lives in Res1 (0..1)
function TC.GetOverheat( ply ) return ply:GetJRes1() end

function TC.AddOverheat( ply, amount )
	ply:SetJRes1( math.Clamp( ply:GetJRes1() + amount, 0, 1 ) )
end

-- The awakening (Every Last Drop.) comes with the move set
function TC.Awaken( ply, mv ) end

-- Cursed Energy Discharge: the final neutral M1 becomes a ray while not overheated
function TC.OnM1Final( ply, variant, cfg, overheatedAtStart )
	if variant ~= JJS.M1.NEUTRAL or overheatedAtStart or TC.GetOverheat( ply ) >= 0.9 then return false end

	local fwd = ply:GetAimVector()
	fwd.z = math.Clamp( fwd.z, -0.35, 0.35 )
	fwd:Normalize()
	local start = U.BodyCenter( ply ) + Vector( 0, 0, 16 ) + U.Flat( fwd ) * 14

	U.LagComp( ply, true )
	local hits, endPos = U.PlayersOnRay( start, fwd, cfg.RayRange, cfg.RayRadius, { ignore = ply } )
	U.LagComp( ply, false )

	TC.AddOverheat( ply, cfg.RayOverheat )

	local first = hits[ 1 ]
	local stop = endPos
	if first then
		local v = first.ply
		stop = start + fwd * first.dist
		local hit = JJS.M1.BuildHit( ply, v, cfg, cfg.Count, JJS.M1.NEUTRAL )
		hit.damage = cfg.RayDamage
		hit.fxScale = 1.2
		local r = JJS.Hit( v, hit )
		if r == "blocked" then
			JJS.ExtendAction( ply, math.max( ply:GetJActEnd() - CurTime(), 0.1 ) )
		end
	end

	U.Effect( "jjs_tc_ray", start, fwd, ply, ( stop - start ):Length() )
	return true
end

JJS.RegisterCharacter( "truecannon", TC )

if SERVER then return end

------------------------------------------------------------------------------------------
-- Client: overheat meter, head smoke, ray effect
------------------------------------------------------------------------------------------

function TC.HUDPaint( ply, now, S )
	if not ply:Alive() then return end
	local heat = TC.GetOverheat( ply )

	local chest = ply:GetPos() + Vector( 0, 0, 44 )
	if ply:GetJRagdolled() and IsValid( ply:GetJRagEnt() ) then chest = ply:GetJRagEnt():WorldSpaceCenter() end
	local sp = chest:ToScreen()
	if not sp.visible then return end

	local w, h = S( 8 ), S( 90 )
	local x, y = sp.x + S( 70 ), sp.y - h / 2
	surface.SetDrawColor( 20, 20, 22, 200 )
	surface.DrawRect( x, y, w, h )

	local col
	if heat >= 1 then
		local p = 0.5 + 0.5 * math.sin( now * 12 )
		col = Color( 255, 60 + 60 * p, 40 )
	elseif heat >= 0.9 then
		col = Color( 255, 110, 40 )
	else
		col = Color( 255, 200 - 90 * heat, 70 )
	end
	surface.SetDrawColor( col )
	surface.DrawRect( x, y + h * ( 1 - heat ), w, h * heat )

	-- 90% mark (M1 ray disabled above it)
	surface.SetDrawColor( 255, 255, 255, 120 )
	surface.DrawRect( x - S( 2 ), y + h * 0.1, w + S( 4 ), 1 )
	surface.SetDrawColor( 255, 255, 255, 30 )
	surface.DrawOutlinedRect( x, y, w, h, 1 )
end

local MAT_GLOW = Material( "sprites/light_glow02_add" )
local MAT_BEAM = Material( "trails/laser" )
local CORE = Color( 255, 255, 255 )
local EDGE = Color( 110, 215, 255 )

local RAY = {}
function RAY:Init( data )
	self.Start = data:GetOrigin()
	self.Dir = data:GetNormal()
	self.Len = math.max( data:GetScale(), 16 )
	self.End = self.Start + self.Dir * self.Len
	self.Born = CurTime()
	self.Life = 0.22
	local mins, maxs = Vector( self.Start ), Vector( self.End )
	OrderVectors( mins, maxs )
	self:SetRenderBoundsWS( mins, maxs, Vector( 40, 40, 40 ) )

	local em = ParticleEmitter( self.End )
	for _ = 1, 10 do
		local p = em:Add( "effects/spark", self.End )
		if p then
			p:SetVelocity( ( VectorRand() - self.Dir * 0.5 ):GetNormalized() * math.Rand( 200, 500 ) )
			p:SetDieTime( math.Rand( 0.12, 0.25 ) )
			p:SetStartAlpha( 255 )
			p:SetEndAlpha( 0 )
			p:SetStartSize( 2 )
			p:SetEndSize( 0 )
			p:SetStartLength( 18 )
			p:SetEndLength( 4 )
			p:SetColor( EDGE.r, EDGE.g, EDGE.b )
		end
	end
	em:Finish()
	util.ScreenShake( self.Start, 2, 30, 0.15, 300 )
end

function RAY:Think()
	return CurTime() - self.Born < self.Life
end

function RAY:Render()
	local u = ( CurTime() - self.Born ) / self.Life
	local fade = 1 - U.Ease.InQuad( u )
	local grow = U.Ease.OutCubic( math.min( u * 4, 1 ) )
	local tip = LerpVector( grow, self.Start, self.End )

	render.SetMaterial( MAT_BEAM )
	render.DrawBeam( self.Start, tip, 26 * fade, 0, 1, ColorAlpha( EDGE, 255 * fade ) )
	render.DrawBeam( self.Start, tip, 9 * fade, 0, 1, ColorAlpha( CORE, 255 * fade ) )
	render.SetMaterial( MAT_GLOW )
	render.DrawSprite( self.Start, 40 * fade, 40 * fade, ColorAlpha( EDGE, 255 * fade ) )
	render.DrawSprite( tip, 60 * fade, 60 * fade, ColorAlpha( CORE, 200 * fade ) )
end
effects.Register( RAY, "jjs_tc_ray" )

-- Overheated: the top of the head smokes
local nextSmoke = 0
local emitter
hook.Add( "Think", "JJS_TC_OverheatSmoke", function()
	local now = CurTime()
	if now < nextSmoke then return end
	nextSmoke = now + 0.07

	for _, ply in ipairs( player.GetAll() ) do
		if not ply:Alive() or ply:GetJChar() ~= "truecannon" or ply:GetJRes1() < 1 or ply:GetJRagdolled() then continue end
		local bone = ply:LookupBone( "ValveBiped.Bip01_Head1" )
		local pos = bone and ply:GetBonePosition( bone )
		if not pos then continue end
		pos = pos + Vector( 0, 0, 9 )

		if not IsValid( emitter ) then emitter = ParticleEmitter( pos ) end
		local p = emitter:Add( "particle/particle_smokegrenade", pos + VectorRand() * 2 )
		if p then
			p:SetVelocity( Vector( math.Rand( -8, 8 ), math.Rand( -8, 8 ), math.Rand( 30, 50 ) ) )
			p:SetDieTime( math.Rand( 0.9, 1.4 ) )
			p:SetStartAlpha( 120 )
			p:SetEndAlpha( 0 )
			p:SetStartSize( 3 )
			p:SetEndSize( 16 )
			p:SetRoll( math.Rand( 0, 360 ) )
			p:SetRollDelta( math.Rand( -1, 1 ) )
			p:SetColor( 220, 220, 225 )
			p:SetAirResistance( 20 )
			p:SetGravity( Vector( 0, 0, 25 ) )
		end
	end
end )
