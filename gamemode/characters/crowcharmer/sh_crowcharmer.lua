-- Crow Charmer (Mei Mei, base-only). Moves are JJS.Kit placeholders built from the JJS fandom wiki and the
-- dogslamloop frame data wiki; comments describe what the real move does.
--
-- Spatial Transference comes off cooldown when Impetus Updraft, Air Updraft, Circling's second swing, Dive Bomb,
-- Murmurate, Free Fall, Bird Control's forward crow or Flock hit someone.

local K = JJS.Kit
local S = JJS.STUD

local function Refresh( ply ) JJS.SetCooldown( ply, 5, 0 ) end
local function RefreshOn( ply, v, p, r ) if r == "hit" then Refresh( ply ) end end

-- height above the ground below the user
local function Height( ply )
	local pos = ply:GetPos()
	local tr = util.TraceLine( { start = pos, endpos = pos - Vector( 0, 0, 200 * S ), mask = MASK_SOLID_BRUSHONLY } )
	return ( pos.z - tr.HitPos.z ) / S, tr.HitPos
end

-- Flock / Bounding (the aerial front dash)
local FLOCK = K.Build( "crowcharmer", "flock", K.Mobility{ "Flock", startup = 0.1, travel = 18, time = 0.35, arc = 0.6, damage = 5, type = "melee",
	block = "normal", ragdoll = { h = 10, v = 45 }, onContact = RefreshOn } )
local BOUNDING = K.Build( "crowcharmer", "bounding", K.Mobility{ "Bounding", startup = 0.05, dir = "up", travel = 5, time = 0.2, damage = 3,
	type = "melee", bypassRagdoll = true, reach = 8, height = 10,
	onContact = function( ply, v ) JJS.Hover( v, 0.4 ) end } )

-- Bird Strike: a guided crow; its binding vow (M1, G or 20s) makes it rush forward and detonate
local CROW = K.Params( K.Projectile{ "Crow", damage = 0, speed = 60, range = 2000, radius = 2, ghost = true, guided = true, color = "black",
	onExplode = function( ply ) if IsValid( ply ) then ply.jjs_crow = nil end end } )
local VOW = K.Params( K.Projectile{ "Crow: Binding Vow", damage = 120, speed = 220, range = 400, radius = 4, explode = 14, explodeDamage = 75,
	directOnly = true, type = "explosion", block = "none", bypassRagdoll = true, heal = 25, crater = 2000, ragdoll = { h = 60, v = 40 }, color = "black",
	onExplode = function( ply, pos, hit )
		if not IsValid( ply ) then return end
		ply.jjs_crow = nil
		if hit then JJS.Heal( ply, 25 ) end
		ply:SetJAwaken( hit and 0.25 or 0.4 )
	end } )

local function Vow( ply )
	local e = ply.jjs_crow
	if not IsValid( e ) or ply.jjs_vowed then return end
	ply.jjs_vowed = true
	ply:SetJAwaken( 0 )
	e.jjs.p = VOW
	e.jjs.left = VOW.range
	e.jjs.vel = e.jjs.vel:GetNormalized() * VOW.speed
	JJS.Util.Effect( "jjs_kit_cast", e:GetPos(), nil, ply, 1.5, K.COLOR_ID.black )
end

-- the user stays frozen while guiding the crow
JJS.RegisterAction( "crowcharmer.guide", {
	dur = 30,
	moveMult = 0,
	noJump = true,
	uninterruptible = true,
	gesture = "gesture_bow",
	think = function( ply, t, mv )
		if CLIENT then return end
		if not IsValid( ply.jjs_crow ) then JJS.StopAction( ply, true ) return end
		if not ply.jjs_vowed then
			-- 5% awakening per second; an M1 or 20s forces the binding vow
			ply:SetJAwaken( math.max( 0, ply:GetJAwaken() - FrameTime() * 0.05 ) )
			if t >= 20 or ( mv and mv:KeyDown( JJS.IN.M1 ) ) then Vow( ply ) end
		end
	end,
	finish = function( ply ) if SERVER and IsValid( ply.jjs_crow ) and not ply.jjs_vowed then ply.jjs_crow:Remove() end end,
} )

-- Spatial Transference: 20 studs toward the walking direction; standing still 15 up; high up, down to the ground
local function Transfer( ply, mv )
	local yaw = ply:EyeAngles().y
	local f, s = 0, 0
	if mv then f, s = JJS.Util.InputDir( mv ) end
	local pos = ply:GetPos()
	local to
	local h, ground = Height( ply )
	if f == 0 and s == 0 then
		to = h >= 15 and ground + Vector( 0, 0, 2 ) or pos + Vector( 0, 0, 15 * S )
	else
		local dir = JJS.Util.YawForward( yaw ) * f + JJS.Util.YawRight( yaw ) * s
		dir:Normalize()
		local tr = util.TraceLine( { start = pos + Vector( 0, 0, 36 ), endpos = pos + Vector( 0, 0, 36 ) + dir * 20 * S, mask = MASK_PLAYERSOLID, filter = ply } )
		to = tr.HitPos - dir * 16 - Vector( 0, 0, 36 )
	end
	if mv then mv:SetOrigin( to ) mv:SetVelocity( vector_origin ) else ply:SetPos( to ) end
	if to.z <= ground.z + 4 then JJS.Endlag( ply, 0.25 ) end
	if SERVER then
		JJS.Util.Effect( "jjs_kit_cast", pos + Vector( 0, 0, 36 ), nil, ply, 1, K.COLOR_ID.white )
		JJS.Util.Effect( "jjs_kit_cast", to + Vector( 0, 0, 36 ), nil, ply, 1, K.COLOR_ID.white )
	end
end

local NO_FEINT = { Flock = true, Bounding = true }

K.Character( "crowcharmer", {
	name = "Crow Charmer",
	category = "baseonly",
	hp = 100,
	model = K.Model( "crowcharmer", "models/player/alyx.mdl" ),
	color = Color( 90, 90, 120 ),

	-- Fly High: the battle axe's uppercuts send targets nearly twice as high, but no M1 can hit an airborne ragdoll
	-- (TODO: the airborne ragdoll exclusion)
	m1 = {
		-- per-hit M1 frames { startup, recovery, block endlag } (dogslamloop)
		Frames = { { 14, 5, 11 }, { 14, 5, 11 }, { 14, 5, 11 } },
		Final = {
			[ 0 ] = { h = 50 * S, v = 24 * S, ragdoll = 0.8 },
			[ 1 ] = { h = 8 * S, v = 130 * S, ragdoll = 0.8 },
			[ 2 ] = { h = 6 * S, v = -80 * S, ragdoll = 1.0 },
		},
	},

	passives = {
		{ "Fly High", "Battle axe: uppercuts launch nearly twice as high, but M1s can't hit airborne ragdolls." },
		{ "Flock", "The aerial front dash: a hop kicking the opponent up (5, 10s cooldown)." },
		{ "Bounding", "Front dashing next to an airborne ragdoll uses them as footing (3, 2s cooldown)." },
	},

	abilities = {
		-- A vertical axe swing knocking the target up (11); a miss has major endlag.
		-- USE TWICE before it lands: two extra swings toss them away instead (3 + 3; they can ragdoll cancel meanwhile).
		-- Above jump height: "Air Updraft", suspended midair for a long sweep launching targets away (14).
		[ 1 ] = K.Melee{ "Impetus Updraft", cooldown = 16, startup = 0.35, endlag = 0.35, whiffEndlag = 1, damage = 11, reach = 9, type = "melee",
			bypassRagdoll = true, ragdoll = { h = 5, v = 60 }, tip = "USE TWICE", onContact = RefreshOn,
			highAir = { damage = 14, width = 12, ragdoll = { h = 60, v = 20 }, onUse = function( ply ) JJS.Hover( ply, 0.7 ) end },
			again = K.Melee{ "Impetus Updraft: Extra Swings", window = 0.8, startup = 0.2, hits = 2, interval = 0.25, hitDamage = { 3, 3 }, reach = 9,
				type = "melee", bypassRagdoll = true, ragdoll = { h = 55, v = 20 } } },
		-- After a short windup, two long spinning forward swings (6, then 8 launching afar); a blocked swing keeps the user
		-- in place. Held 0.3s (yellow): the second swing is unblockable; 0.8s (red): both are. An unblockable second swing
		-- sends them much higher. At least 10 studs up: "Dive Bomb", the axe spins around to grab someone (6) while the
		-- user shoots ~20 studs up, then a crushing slam bouncing them (4, +4 to +8 with airtime).
		[ 2 ] = K.Melee{ "Circling", cooldown = 18, startup = 0.4, hits = 2, interval = 0.35, hitDamage = { 6, 8 }, reach = 11, width = 12, type = "melee",
			bypassRagdoll = true, ragdoll = { h = 70, v = 20 }, tip = "HOLD",
			onContact = function( ply, v, p, r ) if r == "hit" and ply.jjs_circ2 then Refresh( ply ) end ply.jjs_circ2 = true end,
			onUse = function( ply ) ply.jjs_circ2 = nil end,
			hold = {
				{ time = 0.3, hitBlock = { "normal", "none" }, ragdoll = { h = 40, v = 70 } },
				{ time = 0.8, block = "none", ragdoll = { h = 40, v = 70 } },
			},
			highAir = { kind = "grab", hits = 2, interval = 0.7, hitDamage = { 6, 8 }, ragdoll = { h = 5, v = 40 }, onContact = RefreshOn,
				onUse = function( ply ) ply:SetLocalVelocity( Vector( 0, 0, 380 ) ) end } },
		-- Throws the axe twirling around the user like a disk before it comes back (the user steers it by moving): anyone in
		-- its way is launched up, and can be hit twice (9, then 5; no evasive the first time). Slightly slows a fall.
		-- 30 studs up: "Free Fall", the fall stops for a heavy overhead smash grounding the enemy to bounce back up (12,
		-- unblockable).
		[ 3 ] = K.Zone{ "Murmurate", cooldown = 16, startup = 0.3, radius = 14, duration = 1.6, tick = 0.2, damage = 9, zoneHits = { 9, 5 },
			follow = true, type = "melee", bypassRagdoll = true, trueRag = true, ragdoll = { h = 10, v = 45 }, color = "white",
			onUse = function( ply ) Refresh( ply ) end,
			highAir = { kind = "melee", startup = 0.45, damage = 12, reach = 10, block = "none", zoneHits = false, ragdoll = { h = 5, v = -50 },
				onContact = RefreshOn, onUse = function( ply ) JJS.Hover( ply, 0.45 ) end } },
		-- Calls a crow. Standing still or walking sideways: the user hangs onto it and glides for 2.5s (an M1, a move or the
		-- special ends it). Walking forward at a target within 35 studs: it crashes into them and lifts them (6, 360
		-- blockable, can't hit ragdolls). Walking backward: it slams them down where they stand (8, longer ragdoll, hits
		-- ragdolls; doesn't reset Spatial Transference). The crow vanishes if the user is ragdolled.
		[ 4 ] = K.Mobility{ "Bird Control", cooldown = 18, startup = 0.2, travel = 25, time = 2.5, dir = "forward", arc = -0.08, m1Cancel = true,
			feints = false, tip = "DIRECTION",
			cond = { test = function( ply ) return ply:KeyDown( IN_FORWARD ) and IsValid( K.AimTarget( ply, 35 * S, 0.85 ) ) end, kind = "target",
				teleport = false, range = 35, cone = 0.85, detached = true, startup = 0.4, damage = 6, type = "bullet", block = "all",
				ragdoll = { h = 5, v = 40 }, color = "black", onContact = RefreshOn },
			back = { kind = "target", teleport = false, range = 35, cone = 0.85, detached = true, startup = 0.45, damage = 8, type = "bullet",
				block = "all", bypassRagdoll = true, ragdoll = { time = 1.6, h = 0, v = -40 }, color = "black" } },
	},
	-- The younger sibling appears with a white sheet and transfers the user 20 studs toward the walking direction (15 up
	-- when standing still, down to the ground when already that high; slight endlag after a grounded teleport). Usable
	-- in any move except Flock, Bounding and Dive Bomb, feinting it.
	special = {
		name = "Spatial Transference",
		cooldown = 18,
		CanUse = function( ply )
			if not ply:Alive() or ply:GetJRagdolled() or JJS.IsStunned( ply ) then return false end
			local act = JJS.GetAction( ply )
			return not ( act and act.kitParams and NO_FEINT[ act.kitParams.name ] )
		end,
		Use = function( ply, mv, slot )
			JJS.SetCooldown( ply, slot, 18 )
			if JJS.GetAction( ply ) then JJS.StopAction( ply, true ) end
			Transfer( ply, mv )
		end,
	},

	-- Flock and Bounding replace the front dash in the air
	FrontDash = function( ply, mv )
		if ply:IsOnGround() then return false end
		-- Bounding: an airborne ragdoll right next to the user
		for _, v in ipairs( K.SphereTargets( JJS.Util.BodyCenter( ply ), 10 * S, ply, true ) ) do
			if v:GetJRagdolled() and not v:IsOnGround() and ( ply.jjs_boundCD or 0 ) < CurTime() then
				ply.jjs_boundCD = CurTime() + 2
				BOUNDING.Use( ply, mv, 0 )
				return true
			end
		end
		ply:SetJDashFrontCD( CurTime() + 10 )
		FLOCK.Use( ply, mv, 0 )
		return true
	end,

	-- Bird Strike: the user sees through a crow's eyes, then guides its flight (frozen meanwhile; 5% awakening per
	-- second). Hitting a surface first, it dies and the rest of the bar stays. An M1, G or 20s: its binding vow, the
	-- whole bar spent, a harsh caw, and it rushes forward to detonate on contact, hurling everyone around (75); a
	-- direct hit crashes into the target alone (5 + 115). Heals 25 on a hit; refunds 25% on a hit, 40% on a miss.
	awakenMove = K.Stub{ "Bird Strike", startup = 0.1, endlag = 0 },
	Awaken = function( ply )
		if not JJS.CanAct( ply ) or JJS.IsBusy( ply ) then return end
		ply.jjs_vowed = nil
		JJS.StartAction( ply, "crowcharmer.guide" )
		if SERVER then ply.jjs_crow = K.SpawnProjectile( ply, CROW, K.Muzzle( ply ), ply:GetAimVector() ) end
	end,
	AwakenPress = function( ply )
		if not IsValid( ply.jjs_crow ) then return false end
		Vow( ply )
		return true
	end,
} )
