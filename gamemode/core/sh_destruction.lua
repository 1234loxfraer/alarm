-- Destruction effects. Uses ChloeImpact's ground crack when it is installed, otherwise our
-- own fallback. ChloeImpact's automatic craters (and the damage they deal) are removed:
-- dashes and knockback would constantly trigger them.

JJS.Destruction = JJS.Destruction or {}
local D = JJS.Destruction

local function DisableChloeAuto()
	hook.Remove( "SetupMove", "ChloeImpact_Crater" )
	hook.Remove( "EntityFireBullets", "DoChloeImpactEffect" )
end
hook.Add( "Initialize", "JJS_ChloeCompat", DisableChloeAuto )
hook.Add( "InitPostEntity", "JJS_ChloeCompat", DisableChloeAuto )

function D.HasChloe()
	return ChloeImpact ~= nil
end

if CLIENT then return end

-- pos: point on/near the surface, normal: surface normal, scale: ~600 small .. 3000 huge
function D.Crater( pos, normal, scale, attackDir, surfaceProp )
	if D.HasChloe() then
		local ed = EffectData()
		ed:SetOrigin( pos )
		ed:SetNormal( normal )
		ed:SetStart( ( attackDir or -normal ) * scale * 0.05 )
		ed:SetScale( scale )
		ed:SetSurfaceProp( surfaceProp or 0 )
		util.Effect( "chloeimpact_groundcrack", ed, true, true )
	else
		JJS.Util.Effect( "jjs_crater", pos, normal, nil, scale / 1000 )
	end
end

-- Finds the floor under `pos` and cracks it
function D.GroundImpact( pos, scale, attackDir )
	local tr = util.TraceLine( {
		start = pos,
		endpos = pos - Vector( 0, 0, 160 ),
		mask = MASK_SOLID_BRUSHONLY,
	} )
	if not tr.Hit or tr.HitSky then return end
	D.Crater( tr.HitPos, tr.HitNormal, scale, attackDir, tr.SurfaceProps )
end

-- Cracks the first surface along a direction (walls hit by knockback, beams...)
function D.SurfaceImpact( start, dir, dist, scale )
	local tr = util.TraceLine( {
		start = start,
		endpos = start + dir * dist,
		mask = MASK_SOLID_BRUSHONLY,
	} )
	if not tr.Hit or tr.HitSky then return end
	D.Crater( tr.HitPos, tr.HitNormal, scale, dir, tr.SurfaceProps )
	return tr
end
