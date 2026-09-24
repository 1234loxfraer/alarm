-- Domain Expansion (see the wiki "Domain Expansion" page).
-- Casting takes ~1.25s (kit Domain moves), can't be done airborne or inside/near another domain,
-- and is cancelled if hit. Everyone within the radius is caught: members can't leave and
-- outsiders can't enter. The domain applies its sure-hit to members other than the caster:
--   "damage"  damage over time (dps), reduced to 25% while blocking
--   "stun"    members can't act (Infinite Void)
--   "drain"   a meter drains near the caster; when empty the target is destroyed
--   "motion"  moving hurts: damage by the member's (and the caster's) speed, blocking cuts it (Time Cell Moon Palace)
--   "none"    no sure-hit (placeholder for domains with their own rules)
-- Domains cast within ClashWindow of each other clash: sure-hits stop and each caster fills a
-- bar by landing hits on the other casters; the winner keeps their domain, the rest break.

local U = JJS.Util
local K = JJS.Kit
local cfg = JJS.Config.Domain

JJS.Domain = JJS.Domain or {}
local D = JJS.Domain

local ENT = {}
ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "JJS Domain"
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT
ENT.Spawnable = false

function ENT:SetupDataTables()
	self:NetworkVar( "Float", 0, "Radius" )
	self:NetworkVar( "Float", 1, "EndTime" )
	self:NetworkVar( "Float", 2, "ClashEnd" )
	self:NetworkVar( "Float", 3, "Born" )
	self:NetworkVar( "Int", 0, "ColorId" )
	self:NetworkVar( "String", 0, "DomainName" )
	self:NetworkVar( "Entity", 0, "Caster" )
end

function ENT:Initialize()
	self:DrawShadow( false )
	if SERVER then
		-- the engine skips entities without a model; the dome is drawn in DrawTranslucent
		self:SetModel( "models/hunter/blocks/cube025x025x025.mdl" )
		self:SetMoveType( MOVETYPE_NONE )
		self:SetSolid( SOLID_NONE )
		self:SetNotSolid( true )
	end
end

function ENT:InClash() return self:GetClashEnd() > CurTime() end

if CLIENT then
	function ENT:Draw() end

	-- keep the render bounds as big as the dome so it isn't culled
	function ENT:Think()
		local r = math.max( self:GetRadius(), 1 )
		if self.jjs_bounds ~= r then
			self.jjs_bounds = r
			self:SetRenderBounds( Vector( -r, -r, -r ), Vector( r, r, r ) )
		end
	end

	function ENT:DrawTranslucent()
		local r = self:GetRadius()
		if r <= 0 then return end
		local pos = self:GetPos()

		local grow = math.Clamp( ( CurTime() - self:GetBorn() ) / 0.4, 0, 1 )
		local rr = r * U.Ease.OutCubic( grow )
		local col = K.COLOR_BY_ID[ self:GetColorId() ] or color_white
		local inside = EyePos():Distance( pos ) < rr

		render.SetColorMaterial()
		if inside then
			render.DrawSphere( pos, -rr, 40, 40, Color( col.r * 0.25, col.g * 0.25, col.b * 0.25, 170 ) )
		else
			render.DrawSphere( pos, rr, 40, 40, Color( 10, 10, 12, 235 ) )
		end
		render.DrawWireframeSphere( pos, rr, 24, 24, ColorAlpha( col, self:InClash() and 200 or 60 ), true )
	end
end

scripted_ents.Register( ENT, "jjs_domain" )

function D.All()
	return ents.FindByClass( "jjs_domain" )
end

-- The domain a player is caught in (NULL if none)
function D.Of( ply )
	local d = ply:GetNW2Entity( "JJSDomain" )
	if IsValid( d ) then return d end
	return NULL
end

function D.CanCast( ply )
	if not ply:IsOnGround() then return false end
	local pos = ply:GetPos()
	for _, d in ipairs( D.All() ) do
		if d:GetCaster() == ply then return false end
		if pos:Distance( d:GetPos() ) < d:GetRadius() + cfg.BorderMargin and not D.JustCast( d ) then return false end
	end
	return true
end

-- Domains cast within the clash window don't block each other (they clash instead)
function D.JustCast( d )
	return CurTime() - d:GetBorn() <= cfg.ClashWindow
end

-- Domain barrier (called from FinishMove): members stay in, outsiders stay out
function D.Barrier( ply, mv )
	if ply:GetJRagdolled() then return end
	local mine = D.Of( ply )
	local pos = mv:GetOrigin()
	for _, d in ipairs( D.All() ) do
		local c, r = d:GetPos(), d:GetRadius()
		if r <= 0 or d:InClash() then continue end
		local off = pos - c
		local dist = off:Length()
		if d == mine then
			if dist > r - 24 then
				off:Normalize()
				mv:SetOrigin( c + off * ( r - 24 ) )
				local vel = mv:GetVelocity()
				local out = vel:Dot( off )
				if out > 0 then mv:SetVelocity( vel - off * out ) end
			end
		elseif dist < r + 24 and dist > 1 and not D.JustCast( d ) then
			off:Normalize()
			mv:SetOrigin( c + off * ( r + 24 ) )
			local vel = mv:GetVelocity()
			local into = vel:Dot( off )
			if into < 0 then mv:SetVelocity( vel - off * into ) end
		end
	end
end

if SERVER then
	local function Members( d )
		local list = {}
		for _, v in ipairs( player.GetAll() ) do
			if v:GetNW2Entity( "JJSDomain" ) == d then list[ #list + 1 ] = v end
		end
		return list
	end
	D.Members = Members

	function D.Collapse( d )
		if not IsValid( d ) then return end
		for _, v in ipairs( Members( d ) ) do
			v:SetNW2Entity( "JJSDomain", NULL )
			v.jjs_domainMeter = nil
		end
		d.jjs_clash = nil
		hook.Run( "JJS_DomainEnd", d )
		d:Remove()
	end

	-- p: kit params of the Domain move
	function D.Expand( ply, p )
		if not ply:Alive() then return end
		local now = CurTime()
		local radius = p.radius or cfg.Radius
		local d = ents.Create( "jjs_domain" )
		d:SetPos( ply:GetPos() )
		d:Spawn()
		d:SetRadius( radius )
		d:SetBorn( now )
		d:SetEndTime( now + ( p.duration or cfg.DefaultDuration ) )
		d:SetColorId( p.colorId or 1 )
		d:SetDomainName( p.name or "Domain Expansion" )
		d:SetCaster( ply )
		d.jjs = p

		for _, v in ipairs( player.GetAll() ) do
			if v:Alive() and v:GetPos():Distance( d:GetPos() ) <= radius and not IsValid( D.Of( v ) ) then
				v:SetNW2Entity( "JJSDomain", d )
			end
		end
		ply:SetNW2Entity( "JJSDomain", d )

		-- clash with domains cast at nearly the same time
		local clash = { d }
		for _, o in ipairs( D.All() ) do
			if o ~= d and D.JustCast( o ) and o:GetPos():Distance( d:GetPos() ) < radius + o:GetRadius() then
				clash[ #clash + 1 ] = o
			end
		end
		if #clash > 1 then D.StartClash( clash ) end
		hook.Run( "JJS_DomainExpanded", ply, d )
		return d
	end

	function D.StartClash( list )
		local now = CurTime()
		for _, d in ipairs( list ) do
			d:SetClashEnd( now + cfg.ClashTime )
			d:SetEndTime( d:GetEndTime() + cfg.ClashTime ) -- domains don't run out while clashing
			d.jjs_clash = list
			local c = d:GetCaster()
			if IsValid( c ) then c:SetNW2Float( "JJSDomClash", 0 ) end
			-- members of the other domains join the merged one
			for _, v in ipairs( Members( d ) ) do v:SetNW2Entity( "JJSDomain", list[ 1 ] ) end
		end
		hook.Run( "JJS_DomainClash", list )
	end

	local function ResolveClash( list, winner )
		for _, d in ipairs( list ) do
			if not IsValid( d ) then continue end
			d:SetClashEnd( 0 )
			d.jjs_clash = nil
			local c = d:GetCaster()
			if IsValid( c ) then c:SetNW2Float( "JJSDomClash", 0 ) end
			if d ~= winner then D.Collapse( d ) end
		end
		if IsValid( winner ) then
			winner:SetEndTime( CurTime() + ( winner.jjs.duration or cfg.DefaultDuration ) )
			-- everyone still caught belongs to the winning domain now
			for _, v in ipairs( player.GetAll() ) do
				if v:Alive() and v:GetPos():Distance( winner:GetPos() ) <= winner:GetRadius() then
					v:SetNW2Entity( "JJSDomain", winner )
				end
			end
		end
	end

	-- landing hits on an opposing caster fills the clash bar
	hook.Add( "JJS_Hit", "JJS_DomainClash", function( victim, hit, res )
		local a = hit.attacker
		if not IsValid( a ) or not a:IsPlayer() or res ~= "hit" then return end
		for _, d in ipairs( D.All() ) do
			if d:GetCaster() == a and d.jjs_clash then
				for _, o in ipairs( d.jjs_clash ) do
					if IsValid( o ) and o ~= d and o:GetCaster() == victim then
						local v = math.min( 1, a:GetNW2Float( "JJSDomClash" ) + cfg.ClashPerHit )
						a:SetNW2Float( "JJSDomClash", v )
						if v >= 1 then ResolveClash( d.jjs_clash, d ) end
						return
					end
				end
			end
		end
	end )

	local SURE = {}

	SURE.damage = function( d, p, v, dt )
		local dmg = ( p.dps or 2 ) * dt
		if JJS.IsBlocking( v ) then dmg = dmg * ( p.blockMult or 0.25 ) end
		JJS.ApplyDamage( v, d:GetCaster(), dmg, { type = JJS.DMG.DOMAIN } )
	end

	SURE.motion = function( d, p, v, dt )
		local c = d:GetCaster()
		local speed = v:GetVelocity():Length() + ( IsValid( c ) and c:GetVelocity():Length() * 0.5 or 0 )
		local dmg = ( p.dps or 2 ) * dt * math.Clamp( speed / 250, 0, 3 )
		if JJS.IsBlocking( v ) then dmg = dmg * ( p.blockMult or 0.25 ) end
		if dmg > 0 then JJS.ApplyDamage( v, c, dmg, { type = JJS.DMG.DOMAIN } ) end
	end

	SURE.stun = function( d, p, v )
		JJS.Stun( v, 0.35 )
	end

	SURE.drain = function( d, p, v, dt )
		local c = d:GetCaster()
		local near = IsValid( c ) and v:GetPos():Distance( c:GetPos() ) < ( p.drainRange or 20 * JJS.STUD )
		v.jjs_domainMeter = ( v.jjs_domainMeter or 1 ) - ( near and dt / ( p.drainTime or 6 ) or 0 )
		v:SetNW2Float( "JJSDomMeter", math.max( v.jjs_domainMeter, 0 ) )
		if v.jjs_domainMeter <= 0 then
			JJS.ApplyDamage( v, c, 300 * dt / 0.5, { type = JJS.DMG.DOMAIN } )
		end
	end

	SURE.none = function() end

	local nextTick = 0
	hook.Add( "Tick", "JJS_Domains", function()
		local now = CurTime()
		if now < nextTick then return end
		local dt = 0.25
		nextTick = now + dt

		for _, d in ipairs( D.All() ) do
			local caster = d:GetCaster()
			if not IsValid( caster ) or not caster:Alive() or now >= d:GetEndTime() then
				if d.jjs_clash then
					local winner
					for _, o in ipairs( d.jjs_clash ) do if o ~= d and IsValid( o ) then winner = o end end
					ResolveClash( d.jjs_clash, #d.jjs_clash == 2 and winner or nil )
				end
				D.Collapse( d )
				continue
			end

			if d.jjs_clash then
				if now >= d:GetClashEnd() then
					local best, bestV, tie = nil, -1, false
					for _, o in ipairs( d.jjs_clash ) do
						local c = IsValid( o ) and o:GetCaster()
						local v = IsValid( c ) and c:GetNW2Float( "JJSDomClash" ) or -1
						if v > bestV then best, bestV, tie = o, v, false elseif v == bestV then tie = true end
					end
					ResolveClash( d.jjs_clash, not tie and best or nil )
				end
				continue
			end

			local p = d.jjs or {}
			local fn = SURE[ p.sureHit or "damage" ] or SURE.none
			for _, v in ipairs( Members( d ) ) do
				if v == caster or not v:Alive() then continue end
				if hook.Run( "JJS_DomainImmune", v, d ) then continue end
				fn( d, p, v, dt )
			end
		end
	end )

	hook.Add( "JJS_PlayerDied", "JJS_DomainMember", function( ply )
		ply:SetNW2Entity( "JJSDomain", NULL )
	end )
end

if SERVER then return end

------------------------------------------------------------------------------------------
-- Client: the dome, the expansion pop-up and the clash bar
------------------------------------------------------------------------------------------


local popup = { text = nil, hideAt = 0 }

hook.Add( "Think", "JJS_DomainPopup", function()
	local me = LocalPlayer()
	if not IsValid( me ) then return end
	local d = D.Of( me )
	if d ~= popup.ent then
		popup.ent = d
		if IsValid( d ) then
			popup.text = d:GetDomainName()
			popup.hideAt = CurTime() + 2.5
		end
	end
end )

hook.Add( "JJS_HUDPaint", "JJS_Domain", function( ply, now, S )
	if popup.text and now < popup.hideAt then
		local a = math.Clamp( ( popup.hideAt - now ) / 0.5, 0, 1 ) * 255
		draw.SimpleTextOutlined( "DOMAIN EXPANSION", "JJS_Awaken", ScrW() / 2, ScrH() * 0.28, Color( 255, 255, 255, a ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color( 0, 0, 0, a ) )
		draw.SimpleTextOutlined( string.upper( popup.text ), "JJS_CD", ScrW() / 2, ScrH() * 0.28 + S( 34 ), Color( 255, 255, 255, a ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color( 0, 0, 0, a ) )
	end

	local d = D.Of( ply )
	if IsValid( d ) and d:InClash() then
		local w, h = S( 300 ), S( 12 )
		local x, y = ScrW() / 2 - w / 2, S( 90 )
		local v = ply:GetNW2Float( "JJSDomClash" )
		surface.SetDrawColor( 20, 20, 22, 220 )
		surface.DrawRect( x, y, w, h )
		surface.SetDrawColor( 255, 255, 255 )
		surface.DrawRect( x, y, w * v, h )
		draw.SimpleText( string.format( "DOMAIN CLASH  %.0fs", d:GetClashEnd() - now ), "JJS_Small", ScrW() / 2, y - S( 4 ), color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM )
	end

	local meter = ply:GetNW2Float( "JJSDomMeter", -1 )
	if IsValid( d ) and meter >= 0 then
		local w, h = S( 8 ), S( 90 )
		local x, y = ScrW() / 2 + S( 120 ), ScrH() / 2 - h / 2
		surface.SetDrawColor( 20, 20, 22, 200 )
		surface.DrawRect( x, y, w, h )
		surface.SetDrawColor( 200, 120, 255 )
		surface.DrawRect( x, y + h * ( 1 - meter ), w, h * meter )
	end
end )
