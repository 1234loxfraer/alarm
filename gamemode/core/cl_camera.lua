-- Roblox-style third person camera: orbit at a zoomable distance, shift-lock shifts it over
-- the right shoulder, follows the ragdoll while ragdolled or dead, collides with the world.

local cfg = JJS.Config.Camera
local cvDist = CreateClientConVar( "jjs_cam_dist", tostring( cfg.Distance ), true, true, "Camera distance" )

local dist = cvDist:GetFloat()
local smoothDist = dist
local focusZ
local lastFocus

function JJS.Zoom( dir )
	dist = math.Clamp( dist + dir * cfg.ZoomStep, cfg.MinDistance, cfg.MaxDistance )
	RunConsoleCommand( "jjs_cam_dist", tostring( math.Round( dist ) ) )
end

local function RagdollFocus( ply )
	local rag = ply:GetJRagEnt()
	if not IsValid( rag ) then return end
	local bone = rag:LookupBone( "ValveBiped.Bip01_Pelvis" )
	local pos = bone and rag:GetBonePosition( bone )
	return ( pos or rag:WorldSpaceCenter() ) + Vector( 0, 0, 18 )
end

local function Focus( ply )
	if ply:GetJRagdolled() or not ply:Alive() then
		local f = RagdollFocus( ply )
		if f then return f, true end
	end
	local char = JJS.GetChar( ply )
	return ply:GetPos() + Vector( 0, 0, cfg.FocusHeight * ( char and char.scale or 1 ) ), false
end

function GM:CalcView( ply, origin, angles, fov, znear, zfar )
	if ply:GetViewEntity() ~= ply or ply:InVehicle() then
		return self.BaseClass.CalcView( self, ply, origin, angles, fov, znear, zfar )
	end

	local ft = FrameTime()
	local focus, onRagdoll = Focus( ply )

	-- smooth vertical motion (stairs, landing) but keep horizontal tracking tight
	if onRagdoll then
		lastFocus = lastFocus and LerpVector( math.min( ft * 14, 1 ), lastFocus, focus ) or focus
		focus = lastFocus
		focusZ = focus.z
	else
		lastFocus = nil
		focusZ = focusZ and Lerp( math.min( ft * 18, 1 ), focusZ, focus.z ) or focus.z
		if math.abs( focusZ - focus.z ) > 64 then focusZ = focus.z end
		focus = Vector( focus.x, focus.y, focusZ )
	end

	smoothDist = Lerp( math.min( ft * 12, 1 ), smoothDist, dist )
	local firstPerson = smoothDist <= cfg.FirstPersonDistance and not onRagdoll

	local view = { angles = angles, fov = cfg.FOV, znear = znear, zfar = zfar }
	if firstPerson then
		view.origin = ply:EyePos()
		view.drawviewer = false
		return view
	end

	local pivot = focus
	if ply:GetJShiftLock() and not onRagdoll then
		pivot = focus + angles:Right() * cfg.ShiftLockOffset
	end

	local tr = util.TraceHull( {
		start = focus,
		endpos = pivot - angles:Forward() * smoothDist,
		mins = Vector( -5, -5, -5 ),
		maxs = Vector( 5, 5, 5 ),
		mask = MASK_SOLID_BRUSHONLY,
	} )
	view.origin = tr.HitPos
	view.drawviewer = true
	return view
end

function GM:ShouldDrawLocalPlayer( ply )
	return smoothDist > cfg.FirstPersonDistance
end

-- Aim point under the crosshair (camera ray); the server reproduces it with the same convars
function JJS.CameraTrace( ply, range )
	local ang = ply:EyeAngles()
	local focus = ply:GetPos() + Vector( 0, 0, cfg.FocusHeight )
	local pivot = ply:GetJShiftLock() and focus + ang:Right() * cfg.ShiftLockOffset or focus
	local start = pivot - ang:Forward() * smoothDist
	return util.TraceLine( {
		start = start,
		endpos = start + ang:Forward() * ( range or 4000 ),
		filter = ply,
		mask = MASK_SHOT,
	} )
end
