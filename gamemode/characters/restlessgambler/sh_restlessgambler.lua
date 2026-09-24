-- Restless Gambler (Kinji Hakari). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does.

local K = JJS.Kit

K.Character( "restlessgambler", {
	name = "Restless Gambler",
	category = "complete",
	hp = 100,
	model = K.Model( "restlessgambler", "models/player/group03/male_06.mdl" ),
	color = Color( 120, 255, 170 ),

	abilities = {
		-- Flicks a steel ball 65 studs forward: stuns, or ragdolls away within 15 studs. It ricochets off surfaces.
		-- TODO variant: Shutter Doors during the windup summons the doors where the ball lands.
		[ 1 ] = K.Projectile{ "Reserve Balls", cooldown = 12, startup = 0.3, damage = 7.5, range = 65, speed = 200, radius = 2,
			type = "bullet", bypassRagdoll = true, stun = 0.9, color = "white" },
		-- Pachinko shutter doors close on the enemy's torso (up to 25 studs away if aimed) and stun them in place.
		-- TODO miss variant: the doors linger for 7s and can be bounced on.
		[ 2 ] = K.Target{ "Shutter Doors", cooldown = 15, teleport = false, range = 25, cone = 0.85, damage = 8, type = "bullet",
			stun = 1.4, color = "green" },
		-- A long windup punch with sharp cursed energy that sends the enemy flying.
		-- Air variant: hovers then stomps, a shockwave launches targets upward (8, 360 blockable; 16 unblockable from high up).
		[ 3 ] = K.Melee{ "Rough Energy", cooldown = 14, startup = 0.65, endlag = 0.6, damage = 12.5, type = "melee", block = "none",
			bypassRagdoll = true, ragdoll = { h = 70, v = 25 },
			air = { kind = "aoe", damage = 8, block = "all", radius = 10, ragdoll = { h = 6, v = 55 }, color = "green" } },
		-- A ranged kick suspends the opponent in front of two shutter doors (5), then a dropkick launches them (10).
		-- TODO variant "Fever Crush": Shutter Doors during the windup (8 + 12, 24 on a ragdolled target).
		[ 4 ] = K.Melee{ "Fever Breaker", cooldown = 23, startup = 0.35, damage = 15, hits = 2, interval = 0.5, reach = 10, type = "melee",
			ragdoll = { h = 55, v = 25 } },
	},
	-- Two shutter doors: melee attackers get punched through them (5), bullets just shatter them.
	special = K.Counter{ "Door Guard", cooldown = 16, window = 0.6, counters = { melee = "counter", bullet = "evade" }, riposte = 5 },

	awakening = {
		name = "Idle Death Gamble",
		duration = 100,
		heal = 15,
		-- The awakening casts the Idle Death Gamble domain; hitting the Jackpot grants infinite cursed energy for 100s.
		-- TODO domain: freezes everyone inside while the caster rolls Richii scenarios (4 attempts, pity jackpot on the 4th);
		-- visual moves (Reserve Balls, Shutter Doors, Fever Breaker, Door Guard) progress the rolls.
		-- TODO "Renewal": inside the domain, pressing Reserve Balls again within 8s rewinds to when the ball landed.
		-- TODO passive "Jackpot": greatly increased healing, awakening drains when hit (333 damage empties it).
		domain = K.Domain{ "Idle Death Gamble", duration = 20, sureHit = "none", color = "green" },
		abilities = {
			-- A flurry of punches the user can move during, ending in an unblockable swipe (20.7 + 8).
			[ 1 ] = K.Melee{ "Lucky Volley", cooldown = 10, damage = 28.7, hits = 8, interval = 0.12, moveMult = 0.8, type = "melee",
				blockDamage = 14.35, bypassRagdoll = true, ragdoll = { h = 55, v = 20 } },
			-- A long forward run; grabs a met enemy by the leg, drags them and throws them forward (14 + 10).
			[ 2 ] = K.Grab{ "Lucky Rushdown", cooldown = 15, startup = 0.5, damage = 24, hits = 3, interval = 0.35, lunge = 35, type = "melee",
				block = "none", bypassRagdoll = true, ragdoll = { h = 60, v = 20 } },
			-- Charges up, rushes forward with a devastating strike, sprints after the target for more hits and a final punch.
			[ 3 ] = K.Melee{ "Overwhelming Luck", cooldown = 20, startup = 0.8, damage = 40, hits = 4, interval = 0.3, lunge = 25, type = "melee",
				block = "none", bypassRagdoll = true, armor = "bullet", ragdoll = { h = 80, v = 30 } },
			-- Dashes a short distance with a heavy punch that propels the target skywards, then a harsh kick (10 + 10).
			[ 4 ] = K.Melee{ "Energy Surge", cooldown = 25, damage = 20, hits = 2, interval = 0.4, lunge = 10, type = "melee", block = "none",
				bypassRagdoll = true, ragdoll = { h = 20, v = -40 } },
		},
		-- Dancing to the rhythm: a stackable speed boost and 0.6s off every running cooldown (lost if interrupted).
		special = K.Buff{ "Rhythm", cooldown = 8, duration = 1.2, speed = 1.15, speedTime = 30,
			onUse = function( ply )
				for i = 1, 4 do
					local cd = JJS.GetCooldown( ply, i )
					if cd > CurTime() then ply[ "SetJCD" .. i ]( ply, cd - 0.6 ) end
				end
			end },
	},
} )
