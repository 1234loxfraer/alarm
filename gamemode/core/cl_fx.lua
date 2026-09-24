-- Core combat effects (hits, block, dashes, evasive, burst). They use stock materials for
-- now; character effects get their own textures.

JJS.FX = JJS.FX or {}
local FX = JJS.FX

local MAT_GLOW = Material( "sprites/light_glow02_add" )
local MAT_RING = Material( "effects/select_ring" )
local SPARK = "effects/spark"
local SMOKE = "particle/particle_smokegrenade"
local FLECKS = { "effects/fleck_cement1", "effects/fleck_cement2" }

local WHITE = Color( 255, 255, 255 )

-- Shake only for the local view, scaled by distance
function FX.Shake( pos, amp, dur, radius )
	util.ScreenShake( pos, amp, 30, dur, radius or 600 )
end

-- Random unit vector perpendicular to `dir`
local function Perp( dir )
	local v = VectorRand()
	v = v - dir * v:Dot( dir )
	v:Normalize()
	return v
end

local function Streaks( em, pos, dir, count, speed, len, life, color, spread )
	for _ = 1, count do
		local d = spread and ( Perp( dir ) + dir * math.Rand( -spread, spread ) ) or Perp( dir )
		d:Normalize()
		local p = em:Add( SPARK, pos )
		if p then
			p:SetVelocity( d * speed * math.Rand( 0.6, 1.2 ) )
			p:SetDieTime( life * math.Rand( 0.7, 1.2 ) )
			p:SetStartAlpha( 255 )
			p:SetEndAlpha( 0 )
			p:SetStartSize( math.Rand( 1.5, 3 ) )
			p:SetEndSize( 0 )
			p:SetStartLength( len )
			p:SetEndLength( len * 0.3 )
			p:SetAirResistance( speed * 1.5 )
			p:SetColor( color.r, color.g, color.b )
		end
	end
end

local function Dust( em, pos, count, size, speed, life, gravity )
	for _ = 1, count do
		local p = em:Add( SMOKE, pos + VectorRand() * 4 )
		if p then
			local v = VectorRand()
			v.z = math.abs( v.z ) * 0.4
			p:SetVelocity( v * speed )
			p:SetDieTime( life * math.Rand( 0.7, 1.3 ) )
			p:SetStartAlpha( 90 )
			p:SetEndAlpha( 0 )
			p:SetStartSize( size * 0.4 )
			p:SetEndSize( size )
			p:SetRoll( math.Rand( 0, 360 ) )
			p:SetRollDelta( math.Rand( -1, 1 ) )
			p:SetAirResistance( 120 )
			p:SetGravity( Vector( 0, 0, gravity or 20 ) )
			p:SetColor( 200, 195, 185 )
			p:SetLighting( true )
		end
	end
end

-- Base for effects that draw an expanding ring + flash in Render
local function RingEffect( name, setup )
	local EFFECT = {}

	function EFFECT:Init( data )
		self.Pos = data:GetOrigin()
		self.Normal = data:GetNormal()
		if self.Normal:LengthSqr() < 0.01 then self.Normal = Vector( 0, 0, 1 ) end
		self.Scale = data:GetScale() > 0 and data:GetScale() or 1
		self.Flags = data:GetFlags()
		self.Ent = data:GetEntity()
		self.Born = CurTime()
		self.Life = 0.3
		self.Rings = {}
		self.Flash = nil
		setup( self, data )
		local r = 200 * self.Scale
		self:SetRenderBoundsWS( self.Pos - Vector( r, r, r ), self.Pos + Vector( r, r, r ) )
	end

	function EFFECT:Think()
		return CurTime() - self.Born < self.Life
	end

	function EFFECT:Render()
		local t = CurTime() - self.Born
		for _, ring in ipairs( self.Rings ) do
			local u = ( t - ( ring.delay or 0 ) ) / ring.life
			if u >= 0 and u <= 1 then
				local e = 1 - ( 1 - u ) ^ 3
				local size = Lerp( e, ring.from, ring.to )
				render.SetMaterial( MAT_RING )
				render.DrawQuadEasy( self.Pos, ring.normal or self.Normal, size, size,
					ColorAlpha( ring.color or WHITE, 255 * ( 1 - u ) ), ring.rot or 0 )
				render.DrawQuadEasy( self.Pos, -( ring.normal or self.Normal ), size, size,
					ColorAlpha( ring.color or WHITE, 255 * ( 1 - u ) ), ring.rot or 0 )
			end
		end
		local f = self.Flash
		if f then
			local u = t / f.life
			if u <= 1 then
				render.SetMaterial( MAT_GLOW )
				local s = f.size * ( 1 + u * 0.5 )
				render.DrawSprite( self.Pos, s, s, ColorAlpha( f.color or WHITE, 255 * ( 1 - u ) ^ 2 ) )
			end
		end
	end

	effects.Register( EFFECT, name )
end

-- jjs_hit: flags 1 = heavy (final M1, launches)
RingEffect( "jjs_hit", function( self )
	local heavy = self.Flags == 1
	local s = self.Scale
	local dir = self.Normal
	self.Flash = { size = ( heavy and 52 or 30 ) * s, life = heavy and 0.14 or 0.09 }
	self.Rings = { { from = 6 * s, to = ( heavy and 46 or 26 ) * s, life = heavy and 0.2 or 0.14, normal = dir } }
	if heavy then
		self.Rings[ 2 ] = { from = 4 * s, to = 34 * s, life = 0.26, delay = 0.04, normal = dir }
		self.Life = 0.32
	end

	local em = ParticleEmitter( self.Pos )
	Streaks( em, self.Pos, dir, heavy and 12 or 7, ( heavy and 800 or 520 ) * s, heavy and 28 or 18, 0.13, WHITE )
	if heavy then Dust( em, self.Pos, 6, 40 * s, 140, 0.6 ) end
	em:Finish()

	FX.Shake( self.Pos, heavy and 6 or 2.5, heavy and 0.3 or 0.15, heavy and 500 or 300 )
end )

-- jjs_block: blue-white guard spark
RingEffect( "jjs_block", function( self )
	local s = self.Scale
	local blue = Color( 170, 215, 255 )
	self.Flash = { size = 56 * s, life = 0.12, color = blue }
	self.Rings = { { from = 20 * s, to = 50 * s, life = 0.18, color = blue } }
	local em = ParticleEmitter( self.Pos )
	for _ = 1, 10 do
		local p = em:Add( SPARK, self.Pos )
		if p then
			local v = ( self.Normal + VectorRand() * 0.8 ):GetNormalized()
			p:SetVelocity( v * math.Rand( 200, 420 ) )
			p:SetDieTime( math.Rand( 0.2, 0.4 ) )
			p:SetStartAlpha( 255 )
			p:SetEndAlpha( 0 )
			p:SetStartSize( 2 )
			p:SetEndSize( 0 )
			p:SetStartLength( 10 )
			p:SetEndLength( 2 )
			p:SetGravity( Vector( 0, 0, -600 ) )
			p:SetCollide( true )
			p:SetBounce( 0.3 )
			p:SetColor( blue.r, blue.g, blue.b )
		end
	end
	em:Finish()
	FX.Shake( self.Pos, 1.5, 0.12, 250 )
end )

-- jjs_dash: flags 1 = front dash, 2 = side quickstep
RingEffect( "jjs_dash", function( self )
	local front = self.Flags == 1
	local dir = self.Normal
	local feet = self.Pos + Vector( 0, 0, 4 )
	self.Rings = { { from = 10, to = front and 70 or 50, life = 0.22, normal = Vector( 0, 0, 1 ) } }
	self.Pos = feet
	local em = ParticleEmitter( feet )
	Dust( em, feet - dir * 12, front and 8 or 5, 34, 160, 0.5 )
	for _ = 1, front and 8 or 5 do
		local p = em:Add( SPARK, feet + Vector( 0, 0, math.Rand( 10, 60 ) ) + VectorRand() * 10 )
		if p then
			p:SetVelocity( -dir * math.Rand( 300, 600 ) )
			p:SetDieTime( math.Rand( 0.15, 0.25 ) )
			p:SetStartAlpha( 200 )
			p:SetEndAlpha( 0 )
			p:SetStartSize( 1.5 )
			p:SetEndSize( 0 )
			p:SetStartLength( 40 )
			p:SetEndLength( 10 )
		end
	end
	em:Finish()
end )

-- jjs_walljump: dust kicked off the wall
RingEffect( "jjs_walljump", function( self )
	self.Rings = { { from = 8, to = 44, life = 0.2 } }
	local em = ParticleEmitter( self.Pos )
	Dust( em, self.Pos, 5, 26, 120, 0.45, 0 )
	em:Finish()
end )

-- jjs_evasive: gust of wind when cancelling a ragdoll
RingEffect( "jjs_evasive", function( self )
	self.Life = 0.45
	self.Flash = { size = 70, life = 0.15 }
	self.Rings = {
		{ from = 20, to = 150, life = 0.35, normal = Vector( 0, 0, 1 ) },
		{ from = 10, to = 110, life = 0.3, delay = 0.05, normal = Vector( 0, 0, 1 ) },
	}
	local em = ParticleEmitter( self.Pos )
	for _ = 1, 16 do
		local a = math.Rand( 0, math.pi * 2 )
		local d = Vector( math.cos( a ), math.sin( a ), math.Rand( -0.15, 0.3 ) )
		local p = em:Add( SPARK, self.Pos + d * 20 )
		if p then
			p:SetVelocity( d * math.Rand( 500, 800 ) )
			p:SetDieTime( math.Rand( 0.2, 0.3 ) )
			p:SetStartAlpha( 220 )
			p:SetEndAlpha( 0 )
			p:SetStartSize( 2 )
			p:SetEndSize( 0 )
			p:SetStartLength( 50 )
			p:SetEndLength( 10 )
			p:SetAirResistance( 600 )
		end
	end
	Dust( em, self.Pos - Vector( 0, 0, 30 ), 8, 40, 260, 0.6 )
	em:Finish()
end )

-- jjs_burst: anti-team burst
RingEffect( "jjs_burst", function( self )
	self.Life = 0.5
	self.Flash = { size = 160, life = 0.25 }
	self.Rings = {
		{ from = 30, to = 220, life = 0.4, normal = Vector( 0, 0, 1 ) },
		{ from = 20, to = 160, life = 0.35, delay = 0.05 },
	}
	FX.Shake( self.Pos, 4, 0.25, 500 )
end )

-- jjs_crater: fallback when ChloeImpact isn't installed
RingEffect( "jjs_crater", function( self )
	local s = math.Clamp( self.Scale, 0.3, 4 )
	self.Life = 0.4
	self.Rings = { { from = 10 * s, to = 120 * s, life = 0.35 } }
	local em = ParticleEmitter( self.Pos )
	Dust( em, self.Pos + self.Normal * 6, math.floor( 8 * s ), 60 * s, 220 * s, 1.1, 30 )
	for _ = 1, math.floor( 10 * s ) do
		local p = em:Add( FLECKS[ math.random( #FLECKS ) ], self.Pos + self.Normal * 4 )
		if p then
			local v = ( self.Normal * 1.5 + VectorRand() ):GetNormalized()
			p:SetVelocity( v * math.Rand( 200, 450 ) * s )
			p:SetDieTime( math.Rand( 0.8, 1.4 ) )
			p:SetStartAlpha( 255 )
			p:SetEndAlpha( 255 )
			p:SetStartSize( math.Rand( 2, 5 ) )
			p:SetEndSize( 1 )
			p:SetRoll( math.Rand( 0, 360 ) )
			p:SetRollDelta( math.Rand( -8, 8 ) )
			p:SetGravity( Vector( 0, 0, -JJS.Config.Gravity * 0.5 ) )
			p:SetCollide( true )
			p:SetBounce( 0.25 )
			p:SetLighting( true )
		end
	end
	em:Finish()
	FX.Shake( self.Pos, 5 * s, 0.35, 600 )
end )

------------------------------------------------------------------------------------------
-- Persistent state visuals: burst outline, i-frame shimmer
------------------------------------------------------------------------------------------

hook.Add( "PreDrawHalos", "JJS_BurstHalo", function()
	local list
	local now = CurTime()
	for _, ply in ipairs( player.GetAll() ) do
		if ply:Alive() and ply:GetJBurstEnd() > now and not ply:GetJRagdolled() then
			list = list or {}
			list[ #list + 1 ] = ply
		end
	end
	if list then halo.Add( list, WHITE, 2, 2, 1, true, false ) end
end )

hook.Add( "PostPlayerDraw", "JJS_BurstOrb", function( ply )
	if ply:GetJBurstEnd() <= CurTime() then return end
	local bone = ply:LookupBone( "ValveBiped.Bip01_Spine2" )
	local pos = bone and ply:GetBonePosition( bone )
	if not pos then return end
	local pulse = 18 + math.sin( CurTime() * 12 ) * 4
	render.SetMaterial( MAT_GLOW )
	render.DrawSprite( pos, pulse, pulse, WHITE )
end )
