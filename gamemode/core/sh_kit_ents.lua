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
		self:SetMoveType( MOVETYPE_NONE )
		self:SetSolid( SOLID_NONE )
		self:SetNotSolid( true )
	end
end

if SERVER then
	-- p: kit params (units); owner: player
	function K.SpawnProjectile( owner, p, pos, dir )
		local e = ents.Create( "jjs_projectile" )
		if not IsValid( e ) then return end
		e:SetPos( pos )
		e:SetAngles( dir:Angle() )
		e:SetOwner( owner )
		e:Spawn()
		e:SetColorId( p.colorId )
		e:SetRadius( p.radius )
		e.jjs = {
			owner = owner,
			p = p,
			vel = dir * p.speed,
			left = p.range,
			last = CurTime(),
			hit = {},
		}
		return e
	end

	function ENT:Explode( pos )
		local st = self.jjs
		local p = st.p
		if p.explode then
			for _, v in ipairs( K.SphereTargets( pos, p.explode, st.owner, p.bypassRagdoll ) ) do
				if not st.hit[ v ] then K.Apply( st.owner, p, v, nil, pos ) end
			end
			K.Effect( "jjs_kit_burst", pos, Vector( 0, 0, 1 ), nil, p.explode, p )
		else
			K.Effect( "jjs_kit_burst", pos, Vector( 0, 0, 1 ), nil, p.radius * 3, p )
		end
		if p.crater then JJS.Destruction.GroundImpact( pos + Vector( 0, 0, 20 ), p.crater ) end
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
		local from = self:GetPos()
		local step = st.vel * dt
		local len = step:Length()
		if len <= 0 then self:NextThink( now ) return true end
		local dir = step / len

		local tr = util.TraceLine( { start = from, endpos = from + step, mask = MASK_SOLID_BRUSHONLY } )
		local hits = U.PlayersOnRay( from, dir, len, p.radius, { ignore = st.owner, ragdolled = p.bypassRagdoll } )
		for _, h in ipairs( hits ) do
			local v = h.ply
			if st.hit[ v ] then continue end
			st.hit[ v ] = true
			K.Apply( st.owner, p, v, nil, from )
			if not p.pierce then
				self:Explode( from + dir * h.dist )
				return
			end
		end

		st.left = st.left - len
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
		self.Trail = {}
	end

	function ENT:Draw() end

	function ENT:DrawTranslucent()
		local col = K.COLOR_BY_ID[ self:GetColorId() ] or color_white
		local r = math.max( self:GetRadius(), 12 )
		local pos = self:GetPos()
		self:SetRenderBoundsWS( pos - Vector( 300, 300, 300 ), pos + Vector( 300, 300, 300 ) )

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
