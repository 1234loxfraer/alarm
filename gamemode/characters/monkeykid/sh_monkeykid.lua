-- Monkey Kid (overpowered). Moves are JJS.Kit placeholders built from the JJS fandom wiki; comments describe what the
-- real move does.

local K = JJS.Kit

local function Suspend( ply ) if not ply:IsOnGround() then JJS.Hover( ply, 1 ) end end

-- the Flying Nimbus: an airborne front dash flies along the aim for a while
local NIMBUS = K.Build( "monkeykid", "nimbus", K.Mobility{ "Flying Nimbus", startup = 0.05, travel = 70, time = 1.8, dir = "aim", m1Cancel = true,
	moveMult = 0.5 } )
-- Oozaru's front dash: a long hop ending in a slam through block and ragdolls (20)
local OOZARU_SLAM = K.Build( "monkeykid", "oozaruslam", K.Mobility{ "Oozaru Slam", startup = 0.15, travel = 35, time = 0.6, arc = 0.7, damage = 20,
	type = "melee", block = "none", bypassRagdoll = true, reach = 14, width = 14, height = 14, crater = 1800, ragdoll = { h = 20, v = -30 } } )

K.Character( "monkeykid", {
	name = "Monkey Kid",
	category = "op",
	hp = 100,
	scale = 0.8,
	model = K.Model( "monkeykid", "models/player/group01/male_06.mdl" ),
	color = Color( 255, 160, 40 ),

	passives = {
		{ "Child Of The Clouds", "0.8x size, a staff and a tail, longer front dashes; an airborne front dash rides the Flying Nimbus." },
	},

	abilities = {
		-- Concentrates Ki in the hands and releases a massive focused beam (20, unblockable; 360 aim). Airborne, the user
		-- stays suspended for the whole move.
		[ 1 ] = K.Beam{ "Kamehameha", cooldown = 10, startup = 0.9, damage = 20, duration = 0.8, tick = 0.2, range = 110, radius = 5, pierce = true,
			maxPitch = 1, type = "special", block = "none", bypassRagdoll = true, color = "blue", ragdoll = { h = 60, v = 25 },
			onUse = function( ply ) if not ply:IsOnGround() then JJS.Hover( ply, 1.9 ) end end },
		-- The Power Pole uptilts the enemy so hard they fly into the sky (10, blockable); no ragdoll cancel.
		-- Special right after launching them: the user appears before them for a quick hit and a slam to the ground (4 + 4,
		-- unblockable); both go on cooldown.
		[ 2 ] = K.Melee{ "Staff Uppercut", cooldown = 12, startup = 0.35, damage = 10, reach = 9, type = "melee", bypassRagdoll = true, trueRag = true,
			ragdoll = { h = 5, v = 80 }, tip = "SPECIAL",
			specialAfter = K.Target{ "Staff Uppercut: Slam", window = 1.2, cooldown = 6, range = 60, cone = 0.7, startup = 0.35, hits = 2,
				interval = 0.3, hitDamage = { 4, 4 }, type = "melee", block = "none", bypassRagdoll = true, trueRag = true, ragdoll = { h = 5, v = -60 } } },
		-- Extends the staff forward, smacking the enemy so they slide away (15, unblockable, can't hit ragdolls).
		-- Airborne: slams the staff vertically into the floor with anyone near it (15, hits ragdolls); keeping the key held,
		-- the user latches onto the staff and extends it upward, possibly to extreme heights.
		[ 3 ] = K.Melee{ "Staff Extend", cooldown = 15, startup = 0.4, damage = 15, reach = 22, width = 4, type = "melee", block = "none",
			ragdoll = { h = 70, v = 8 },
			air = { kind = "aoe", radius = 8, offset = 0, up = -30, bypassRagdoll = true, crater = 1200, ragdoll = { h = 10, v = 40 },
				onEnd = function( ply )
					if ply:KeyDown( JJS.AbilityKeys[ 3 ] ) then ply:SetLocalVelocity( Vector( 0, 0, 1100 ) ) end
				end } },
		-- Two ki blasts, each ragdolling (1 each, unblockable). Holding lengthens the barrage up to 49 blasts, less accurate
		-- the longer it goes. Airborne: suspended with a better aim.
		[ 4 ] = K.Projectile{ "Ki Spam", cooldown = 12, startup = 0.25, damage = 1, count = 2, volley = 0.12, spread = 3, range = 80, speed = 220,
			radius = 2.5, type = "special", block = "none", bypassRagdoll = true, ragdoll = { h = 20, v = 10, time = 0.4 }, color = "gold",
			onUse = Suspend, tip = "HOLD",
			hold = {
				{ time = 0.4, count = 24, volley = 0.07, spread = 6 },
				{ time = 1.2, count = 49, volley = 0.06, spread = 11 },
			} },
	},
	-- Phases forward so fast the user vanishes: no stun or endlag; attacking cancels it early.
	special = K.Mobility{ "Instant Transmission", cooldown = 1, startup = 0, travel = 25, time = 0.15, endlag = 0, iframes = 0.15, dir = "aim",
		m1Cancel = true },

	FrontDash = function( ply, mv )
		if ply:GetJAwakened() then
			ply:SetJDashFrontCD( CurTime() + JJS.Config.Dash.FrontCooldown )
			OOZARU_SLAM.Use( ply, mv, 0 )
			return true
		end
		if ply:IsOnGround() then return false end
		ply:SetJDashFrontCD( CurTime() + JJS.Config.Dash.FrontCooldown )
		NIMBUS.Use( ply, mv, 0 )
		return true
	end,

	awakening = {
		name = "Monkey",
		duration = 60,
		heal = 15,
		scale = 3, -- 5x in the game; kept at 3x for normal maps
		-- The Power Pole slips off the back as the small frame expands into an Oozaru that roars (10x power level).
		-- Every M1 deals 10, is unblockable and hits ragdolls: the 1st and last fling away, the middle two slam into the
		-- ground. The front dash is a long hop into a slam through block and ragdolls (20). No throwables, items, wall
		-- bounces or parkour (TODO).
		m1 = { Damage = { 10, 10, 10, 10 }, Unblockable = true, BypassRagdoll = true,
			HitRagdoll = { [ 1 ] = { h = 55, v = 20 }, [ 2 ] = { h = 5, v = -40 }, [ 3 ] = { h = 5, v = -40 } } },
	},
} )
