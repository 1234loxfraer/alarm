-- Restless Gambler (Kinji Hakari). Moves are JJS.Kit placeholders built from the JJS fandom wiki
-- and the dogslamloop frame data wiki; comments describe what the real move does.

local K = JJS.Kit

K.Character( "restlessgambler", {
	name = "Restless Gambler",
	category = "complete",
	hp = 100,
	model = K.Model( "restlessgambler", "models/player/group03/male_06.mdl" ),
	color = Color( 120, 255, 170 ),

	abilities = {
		-- Flicks a steel ball 65 studs forward: stuns, or ragdolls away if it travelled 15 studs or less. It ricochets off
		-- surfaces (within its usual distance, endlessly inside a domain). Blockable, hits ragdolls.
		-- Combo "Pachinko Combo" (Shutter Doors during the windup): the doors appear where the ball lands and bounce the
		-- stunned enemy (7.5 + 3 + 2 per bounce, 3 bounces); both moves go on cooldown.
		[ 1 ] = K.Projectile{ "Reserve Balls", cooldown = 12, startup = 0.3, damage = 7.5, range = 65, speed = 200, radius = 2, type = "bullet",
			bypassRagdoll = true, stun = 0.9, color = "white", near = { dist = 15, ragdoll = { h = 40, v = 15 } },
			combo = { [ 2 ] = { damage = 13.5, hitDamage = false, explode = 5, stun = 1.4, ragdoll = { h = 5, v = 35 }, color = "green" } } },
		-- Pachinko shutter doors close on the enemy's torso (up to 25 studs away if aimed) and stun them in place; sets the
		-- user to their 3rd M1. Hits airborne ragdolls only.
		-- Miss variant: the doors linger for 7s; jumping on them bounces the user high, a ragdolled enemy falling on them
		-- bounces 3 times (2 each).
		[ 2 ] = K.Target{ "Shutter Doors", cooldown = 15, teleport = false, range = 25, cone = 0.85, damage = 8, type = "bullet", stun = 1.4,
			color = "green", onHit = function( ply ) ply:SetJM1Index( 2 ) ply:SetJM1LastEnd( CurTime() ) end },
		-- A long windup punch with sharp cursed energy sending the enemy flying (unblockable, long windup and endlag).
		-- Air variant: hovers then stomps, a shockwave launches targets upward (8, 360 blockable).
		-- High air variant (above jump height, e.g. after bouncing on the doors): unblockable and doubled (16).
		[ 3 ] = K.Melee{ "Rough Energy", cooldown = 14, startup = 0.65, endlag = 0.6, damage = 12.5, type = "melee", block = "none",
			bypassRagdoll = true, ragdoll = { h = 70, v = 25 },
			air = { kind = "aoe", damage = 8, block = "all", radius = 10, up = -12, ragdoll = { h = 6, v = 55 }, color = "green" },
			highAir = { kind = "aoe", damage = 16, block = "none", radius = 12, up = -12, ragdoll = { h = 6, v = 60 }, color = "green",
				crater = 1200 } },
		-- A ranged kick suspends the opponent in front of two shutter doors (5), then a dropkick launches them in the
		-- direction faced before the follow-up (10).
		-- Combo "Fever Crush" (Shutter Doors during the windup): the doors hold the target (8) for an unblockable axe
		-- kick (12; 24 on a ragdolled target).
		[ 4 ] = K.Melee{ "Fever Breaker", cooldown = 23, startup = 0.35, hits = 2, interval = 0.5, hitDamage = { 5, 10 }, reach = 10, type = "melee",
			ragdoll = { h = 55, v = 25 },
			combo = { [ 2 ] = { hitDamage = { 8, 12 }, hitBlock = { "normal", "none" }, interval = 0.55, bypassRagdoll = true, crater = 1000,
				ragdoll = { h = 5, v = -30 } } } },
	},
	-- Two shutter doors: melee attackers get punched through them (5), bullets just shatter them. 0.6s window.
	special = K.Counter{ "Door Guard", cooldown = 16, window = 0.6, counters = { melee = "counter", bullet = "evade" }, riposte = 5 },

	awakening = {
		name = "Idle Death Gamble",
		duration = 100,
		heal = 15,
		-- The awakening casts Idle Death Gamble (80s, breaks after 4 scenarios); hitting the Jackpot grants infinite
		-- cursed energy for 100s (50s for the pity jackpot on the 4th try).
		-- TODO domain: freezes everyone inside while the caster rolls Richii scenarios; visual moves (Reserve Balls,
		-- Shutter Doors, Fever Breaker's dropkick, Door Guard) progress the rolls.
		-- TODO "Renewal": inside the domain, pressing Reserve Balls again within 8s rewinds to when the ball landed.
		-- TODO passive "Jackpot": greatly increased healing; the awakening bar drains when hit (333 damage empties it).
		domain = K.Domain{ "Idle Death Gamble", duration = 20, sureHit = "none", color = "green" },
		abilities = {
			-- A flurry of punches the user can move during (20.7), ending in an unblockable swipe that launches away (8).
			[ 1 ] = K.Melee{ "Lucky Volley", cooldown = 10, startup = 0.3, damage = 28.7, hits = 10, interval = 0.12, moveMult = 0.8, type = "melee",
				hitDamage = { 2.3, 2.3, 2.3, 2.3, 2.3, 2.3, 2.3, 2.3, 2.3, 8 }, hitBlock = { "normal", "normal", "normal", "normal", "normal",
				"normal", "normal", "normal", "normal", "none" }, blockDamage = 10.35, bypassRagdoll = true, ragdoll = { h = 55, v = 20 } },
			-- A long forward run; an enemy met is grabbed by the leg (14), dragged across the floor and thrown forward (10).
			[ 2 ] = K.Rush{ "Lucky Rushdown", cooldown = 15, startup = 0.3, travel = 45, time = 0.8, hits = 3, interval = 0.4, hitDamage = { 7, 7, 10 },
				type = "melee", block = "none", bypassRagdoll = true, ragdoll = { h = 60, v = 20 } },
			-- Charges, rushes into a devastating strike tossing the target away (10), sprints after them for more hits and a
			-- final punch (30). Bullet armor; can hit several people.
			[ 3 ] = K.Rush{ "Overwhelming Luck", cooldown = 20, startup = 0.8, travel = 25, time = 0.35, hits = 4, interval = 0.35,
				hitDamage = { 10, 8, 8, 14 }, type = "melee", block = "none", bypassRagdoll = true, armor = "bullet", ragdoll = { h = 80, v = 30 } },
			-- Dashes a short distance into a heavy punch propelling the target skywards (10), then appears above for a kick (10).
			[ 4 ] = K.Rush{ "Energy Surge", cooldown = 25, startup = 0.2, travel = 12, time = 0.2, hits = 2, interval = 0.45, hitDamage = { 10, 10 },
				type = "melee", block = "none", bypassRagdoll = true, ragdoll = { h = 20, v = -40 } },
		},
		-- Dancing to the rhythm: a stackable speed boost and 0.6s off every running cooldown (lost if interrupted);
		-- also clears Execution stacks.
		special = K.Buff{ "Rhythm", cooldown = 8, duration = 1.2, speed = 1.15, speedTime = 30,
			onUse = function( ply )
				ply.jjs_execution = nil
				for i = 1, 4 do
					local cd = JJS.GetCooldown( ply, i )
					if cd > CurTime() then ply[ "SetJCD" .. i ]( ply, cd - 0.6 ) end
				end
			end },
	},
} )
