-- Placeholder effects for kit moves. Colours come from JJS.Kit.PALETTE (effect flags = colour id).
--   jjs_kit_beam   origin = start, normal = direction, scale = length, magnitude = width multiplier
--   jjs_kit_burst  origin = centre, scale = radius (units)
--   jjs_kit_cast   origin = body centre, entity = user, scale = size

local K = JJS.Kit
local U = JJS.Util

local MAT_GLOW = Material( "sprites/light_glow02_add" )
local MAT_BEAM = Material( "trails/laser" )
local MAT_RING = Material( "effects/select_ring" )

local function Col( data )
	return K.COLOR_BY_ID[ data:GetFlags() ] or color_white
end

local BEAM = {}
function BEAM:Init( data )
	self.Start = data:GetOrigin()
	self.Dir = data:GetNormal()
	self.Len = math.max( data:GetScale(), 16 )
	self.End = self.Start + self.Dir * self.Len
	self.Width = math.max( data:GetMagnitude(), 1 )
	self.Col = Col( data )
	self.Born = CurTime()
	self.Life = 0.25
	local mins, maxs = Vector( self.Start ), Vector( self.End )
	OrderVectors( mins, maxs )
	self:SetRenderBoundsWS( mins, maxs, Vector( 60, 60, 60 ) )
	util.ScreenShake( self.Start, 2, 30, 0.15, 300 )
end

function BEAM:Think()
	return CurTime() - self.Born < self.Life
end

function BEAM:Render()
	local u = ( CurTime() - self.Born ) / self.Life
	local fade = 1 - U.Ease.InQuad( u )
	local grow = U.Ease.OutCubic( math.min( u * 4, 1 ) )
	local tip = LerpVector( grow, self.Start, self.End )
	local w = self.Width

	render.SetMaterial( MAT_BEAM )
	render.DrawBeam( self.Start, tip, 30 * w * fade, 0, 1, ColorAlpha( self.Col, 255 * fade ) )
	render.DrawBeam( self.Start, tip, 10 * w * fade, 0, 1, Color( 255, 255, 255, 255 * fade ) )
	render.SetMaterial( MAT_GLOW )
	render.DrawSprite( self.Start, 40 * w * fade, 40 * w * fade, ColorAlpha( self.Col, 255 * fade ) )
	render.DrawSprite( tip, 60 * w * fade, 60 * w * fade, Color( 255, 255, 255, 200 * fade ) )
end
effects.Register( BEAM, "jjs_kit_beam" )

local BURST = {}
function BURST:Init( data )
	self.Pos = data:GetOrigin()
	self.Radius = math.max( data:GetScale(), 20 )
	self.Col = Col( data )
	self.Born = CurTime()
	self.Life = 0.35
	local r = self.Radius * 1.2
	self:SetRenderBoundsWS( self.Pos - Vector( r, r, r ), self.Pos + Vector( r, r, r ) )

	local em = ParticleEmitter( self.Pos )
	for _ = 1, 14 do
		local p = em:Add( "effects/spark", self.Pos )
		if p then
			p:SetVelocity( VectorRand():GetNormalized() * math.Rand( 0.8, 1.6 ) * self.Radius * 2 )
			p:SetDieTime( math.Rand( 0.15, 0.3 ) )
			p:SetStartAlpha( 255 )
			p:SetEndAlpha( 0 )
			p:SetStartSize( 3 )
			p:SetEndSize( 0 )
			p:SetStartLength( 20 )
			p:SetEndLength( 4 )
			p:SetColor( self.Col.r, self.Col.g, self.Col.b )
		end
	end
	em:Finish()
	util.ScreenShake( self.Pos, 4, 30, 0.25, self.Radius * 3 )
end

function BURST:Think()
	return CurTime() - self.Born < self.Life
end

function BURST:Render()
	local u = ( CurTime() - self.Born ) / self.Life
	local e = U.Ease.OutCubic( u )
	local a = 255 * ( 1 - u )
	render.SetColorMaterial()
	render.DrawSphere( self.Pos, self.Radius * e, 16, 16, ColorAlpha( self.Col, 70 * ( 1 - u ) ) )
	render.SetMaterial( MAT_RING )
	local size = self.Radius * 2.2 * e
	render.DrawQuadEasy( self.Pos + Vector( 0, 0, 2 ), Vector( 0, 0, 1 ), size, size, ColorAlpha( self.Col, a ), 0 )
	render.SetMaterial( MAT_GLOW )
	render.DrawSprite( self.Pos, self.Radius * ( 1 - u ), self.Radius * ( 1 - u ), ColorAlpha( self.Col, a ) )
end
effects.Register( BURST, "jjs_kit_burst" )

local CAST = {}
function CAST:Init( data )
	self.Ent = data:GetEntity()
	self.Pos = data:GetOrigin()
	self.Scale = math.max( data:GetScale(), 0.5 )
	self.Col = Col( data )
	self.Born = CurTime()
	self.Life = 0.45
	self:SetRenderBoundsWS( self.Pos - Vector( 120, 120, 120 ), self.Pos + Vector( 120, 120, 120 ) )
end

function CAST:Think()
	if IsValid( self.Ent ) then self.Pos = U.BodyCenter( self.Ent ) end
	return CurTime() - self.Born < self.Life
end

function CAST:Render()
	local u = ( CurTime() - self.Born ) / self.Life
	local a = 255 * ( 1 - u ) ^ 2
	local s = 50 * self.Scale * ( 0.6 + u )
	render.SetMaterial( MAT_GLOW )
	render.DrawSprite( self.Pos, s * 2, s * 2, ColorAlpha( self.Col, a ) )
	render.SetMaterial( MAT_RING )
	render.DrawQuadEasy( self.Pos - Vector( 0, 0, 34 ), Vector( 0, 0, 1 ), s * 2.4, s * 2.4, ColorAlpha( self.Col, a ), CurTime() * 90 )
end
effects.Register( CAST, "jjs_kit_cast" )
