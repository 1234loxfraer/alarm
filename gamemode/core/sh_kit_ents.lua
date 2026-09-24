-- Projectile entity used by kit moves (JJS.Kit.Projectile / Summon). The server moves it
-- every tick, sweeping players along its path; clients draw a glowing orb with a trail.

local U = JJS.Util
local K = JJS.Kit

local ENT = {}
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "JJS Projectile"
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT
ENT.Spawnable = false

function ENT:SetupDataTables()
	self:NetworkVar( "Int", 0, "ColorId" )
	self:NetworkVar( "Float", 0, "Radius" )
end

function ENT:Initialize()
	self:DrawShadow( false )
	if SERVER then
		-- the engine skips entities without a model; this one is never drawn (see DrawTranslucent)
		self:SetModel( "models/hunter/blocks/cube025x025x025.mdl" )
		self:SetMoveType( MOVETYPE_NONE )
		self:SetSolid( SOLID_NONE )
		self:SetNotSolid( true )
	end
end

if SERVER then
	-- p: kit params (units); owner: player
	function K.SpawnProjectile( owner, p, pos, dir, target )
		local e = ents.Create( "jjs_projectile" )
		if not IsValid( e ) then return end
		e:SetPos( pos )
		e:SetAngles( dir:Angle() )
		e:SetOwner( owner )
		e:Spawn()
		e:SetColorId( p.colorId )
		e:SetRadius( p.radius )
		-- near = { dist (studs), ragdoll = {...} }: hits within `dist` of the muzzle ragdoll instead
		local nearP
		if p.near then
			nearP = table.Copy( p )
			local r = p.near.ragdoll or {}
			nearP.ragdoll = { time = r.time or 1, h = ( r.h or 35 ) * JJS.STUD, v = ( r.v or 15 ) * JJS.STUD }
		end
		e.jjs = {
			owner = owner,
			p = p,
			nearP = nearP,
			vel = dir * p.speed,
			left = p.range,
			last = CurTime(),
			hit = {},
			target = target,
		}
		return e
	end

	function ENT:Explode( pos )
		local st = self.jjs
		local p = st.p
		-- directOnly: a direct hit skips the blast; explodeDamage: the blast's own damage
		if p.explode and not ( p.directOnly and next( st.hit ) ) then
			local ep = p
			if p.explodeDamage then
				ep = table.Copy( p )
				ep.damage, ep.hitDamage, ep.hits = p.explodeDamage, nil, 1
			end
			for _, v in ipairs( K.SphereTargets( pos, p.explode, st.owner, p.bypassRagdoll ) ) do
				if not st.hit[ v ] then K.Apply( st.owner, ep, v, nil, pos ) end
			end
			K.Effect( "jjs_kit_burst", pos, Vector( 0, 0, 1 ), nil, p.explode, p )
		else
			K.Effect( "jjs_kit_burst", pos, Vector( 0, 0, 1 ), nil, p.radius * 3, p )
		end
		if p.crater then JJS.Destruction.GroundImpact( pos + Vector( 0, 0, 20 ), p.crater ) end
		if p.onExplode then p.onExplode( st.owner, pos, next( st.hit ) ~= nil, self ) end
		self:Remove()
	end

	function ENT:Think()
		local st = self.jjs
		if not st or not IsValid( st.owner ) then self:Remove() return end
		local now = CurTime()
		local dt = now - st.last
		st.last = now
		local p = st.p

		if p.gravity then st.vel.z = st.vel.z - p.gravity * dt end
		-- guided: flies where its owner looks (Bird Strike); homing: turns toward its target
		if p.guided then st.vel = st.owner:GetAimVector() * st.vel:Length() end
		if p.homing and IsValid( st.target ) and st.target:Alive() then
			local to = ( U.BodyCenter( st.target ) - self:GetPos() ):GetNormalized()
			st.vel = ( st.vel:GetNormalized() * 0.8 + to * 0.2 ):GetNormalized() * st.vel:Length()
		end
		local from = self:GetPos()
		local step = st.vel * dt
		local len = step:Length()
		if len <= 0 then self:NextThink( now ) return true end
		local dir = step / len

		local tr = util.TraceLine( { start = from, endpos = from + step, mask = MASK_SOLID_BRUSHONLY } )
		-- ghost: passes through players
		local hits = p.ghost and {} or U.PlayersOnRay( from, dir, len, p.radius, { ignore = st.owner, ragdolled = p.bypassRagdoll } )
		for _, h in ipairs( hits ) do
			local v = h.ply
			if st.hit[ v ] then continue end
			st.hit[ v ] = true
			local travelled = p.range - st.left + h.dist
			local hp = ( st.nearP and travelled <= p.near.dist * JJS.STUD ) and st.nearP or p
			K.Apply( st.owner, hp, v, nil, from )
			if not p.pierce then
				self:Explode( from + dir * h.dist )
				return
			end
		end

		st.left = st.left - len
		if p.onFly and p.onFly( st.owner, from + step, self ) then
			self:Explode( from + step )
			return
		end
		if tr.Hit or st.left <= 0 then
			self:Explode( tr.HitPos )
			return
		end
		self:SetPos( from + step )
		self:NextThink( now )
		return true
	end
end

if CLIENT then
	local MAT_GLOW = Material( "sprites/light_glow02_add" )
	local MAT_TRAIL = Material( "trails/laser" )

	function ENT:Initialize()
		self:DrawShadow( false )
		self:SetRenderBounds( Vector( -300, -300, -300 ), Vector( 300, 300, 300 ) )
		self.Trail = {}
	end

	function ENT:Draw() end

	function ENT:DrawTranslucent()
		local col = K.COLOR_BY_ID[ self:GetColorId() ] or color_white
		local r = math.max( self:GetRadius(), 12 )
		local pos = self:GetPos()
		local trail = self.Trail
		if not trail[ 1 ] or trail[ 1 ]:DistToSqr( pos ) > 16 then table.insert( trail, 1, pos ) end
		if #trail > 10 then trail[ #trail ] = nil end

		render.SetMaterial( MAT_TRAIL )
		for i = 1, #trail - 1 do
			local f = 1 - i / #trail
			render.DrawBeam( trail[ i ], trail[ i + 1 ], r * 1.4 * f, 0, 1, ColorAlpha( col, 200 * f ) )
		end
		render.SetMaterial( MAT_GLOW )
		render.DrawSprite( pos, r * 4, r * 4, col )
		render.DrawSprite( pos, r * 1.6, r * 1.6, color_white )
	end
end

scripted_ents.Register( ENT, "jjs_projectile" )
