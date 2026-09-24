-- Cursed Partners (Yuta Okkotsu). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does.
-- The special summons Rika and switches to her moveset (the alternate set) and back.

local K = JJS.Kit

local RIKA = K.Toggle{ "Rika", cooldown = 1, color = "pink" }

K.Character( "cursedpartners", {
	name = "Cursed Partners",
	category = "complete",
	hp = 90,
	model = K.Model( "cursedpartners", "models/player/group01/male_05.mdl" ),
	color = Color( 255, 120, 200 ),

	passives = {
		{ "Swordsmanship", "Cosmetic: necklace, katana holster and a custom block animation." },
	},

	abilities = {
		-- Slides 18 studs sweeping the floor (4); on hit, locks the enemy and follows with 3 swings (2.3 each), the last launching.
		-- TODO direction variant "Veilstep": walking backward, a 27 stud back roll with melee i-frames (9).
		[ 1 ] = K.Grab{ "Severing Path", cooldown = 15, startup = 0.25, damage = 10.9, hits = 4, interval = 0.2, lunge = 18, type = "melee",
			bypassRagdoll = true, ragdoll = { h = 10, v = 55 }, tip = "DIRECTION" },
		-- Aiming at a spot within 25 studs, vanishes while winding up and reappears slashing at the neck.
		-- Follow-up "Resolute Black Flash": pressed again as they reappear, vanishes again for a Black Flash (12, melee i-frames).
		[ 2 ] = K.Target{ "Resolute Slash", cooldown = 15, range = 25, startup = 0.45, damage = 12, type = "melee", block = "none",
			ragdoll = { h = 40, v = 15 }, tip = "USE AGAIN",
			again = K.Target{ "Resolute Black Flash", window = 0.8, range = 25, startup = 0.3, damage = 12, iframes = 0.4, type = "melee",
				block = "none", bypassRagdoll = true, color = "black", ragdoll = { h = 60, v = 25 } } },
		-- A cursed-energy swing (2) triggering a 13x13 stud burst (4, +2 per held stage) that damages through block and launches upward.
		-- TODO hold stages (up to +6) and the parry: hit within 0.25s, it parries melee/bullets.
		[ 3 ] = K.AoE{ "Outburst", cooldown = 16, startup = 0.5, damage = 6, hits = 2, interval = 0.15, radius = 7, offset = 5, type = "explosion",
			blockDamage = 3, bypassRagdoll = true, ragdoll = { h = 10, v = 50 }, color = "pink", tip = "HOLD" },
		-- Rushes 20 studs with melee i-frames; grabs a met enemy by the face (2) and slams them (8). Can be retried once if missed.
		-- TODO variant: Severing Path on collision pummels instead (15).
		[ 4 ] = K.Grab{ "Second Wind", cooldown = 16, startup = 0.2, damage = 10, hits = 2, interval = 0.5, lunge = 20, type = "melee",
			block = "all", armor = "melee", ragdoll = { h = 5, v = -30 }, crater = 800 },
	},
	special = RIKA,

	-- Rika's base moves (shared cooldown in the real game)
	alt = {
		name = "Rika",
		abilities = {
			-- Rika's fist grows above the target and slams down, bouncing them upward. Air target: dunks them (8).
			[ 1 ] = K.Target{ "Rika Smash", cooldown = 10, teleport = false, range = 45, startup = 0.6, damage = 10, type = "bullet", block = "all",
				bypassRagdoll = true, uninterruptible = true, ragdoll = { h = 5, v = 45 }, color = "pink" },
			-- Rika boosts the user slightly forward (up while airborne); feints the current move onto a shorter cooldown.
			[ 2 ] = K.Mobility{ "Rika Launch", cooldown = 10, travel = 22, time = 0.3, dir = "forward", air = { dir = "up", travel = 18 } },
			-- Rika hovers to a target within 10 studs of her and winds up a heavy blow (12, 18 if blocked).
			[ 3 ] = K.Target{ "Rika Haymaker", cooldown = 10, teleport = false, range = 20, startup = 0.8, damage = 12, type = "bullet",
				bypassRagdoll = true, uninterruptible = true, ragdoll = { h = 80, v = 25 }, color = "pink" },
		},
		special = RIKA,
	},

	awakening = {
		name = "True Love",
		duration = 60,
		heal = 25,
		-- "Come, Rika. Give me everything." Rika fully manifests and wraps a steel casing around the user's arm.
		-- TODO awakening ability "Copy Wheel": techniques copied from enemies Rika hit, picked with G, used through Copy.
		-- TODO passive "Steel Arm": the first 3 M1s add a quick jab ((4 + 0.5) + (4 + 0.5) + (0.5 + 0.5) + 4).
		abilities = {
			-- Dashes ~38.5 studs into an elbow strike (4), appears behind with Rika for a barrage (5, 8 with Rika) and a final blow (6).
			[ 1 ] = K.Grab{ "Elbow Rush", cooldown = 15, startup = 0.3, damage = 15, hits = 5, interval = 0.25, lunge = 38.5, type = "melee",
				block = "none", ragdoll = { h = 80, v = 25 } },
			-- Cursed Speech by default: "Don't move!" stuns everyone within 35 studs.
			-- TODO: the copied technique selected on the Copy Wheel replaces this.
			[ 2 ] = K.AoE{ "Copy: Cursed Speech", cooldown = 15, startup = 0.5, damage = 0, radius = 35, stun = 1.5, type = "special", block = "all",
				color = "purple" },
			-- Drives the katana into the floor, pushing all enemies within 27 studs away (19).
			-- Follow-up "Fakeout": pressed again before the katana lands, a sudden swing (7) transfers the burst (12).
			[ 3 ] = K.AoE{ "Energy Ripple", cooldown = 18, startup = 0.6, damage = 19, radius = 27, type = "explosion", block = "none",
				bypassRagdoll = true, uninterruptible = true, ragdoll = { h = 60, v = 20 }, color = "pink", tip = "USE AGAIN",
				again = K.Melee{ "Fakeout", window = 0.5, startup = 0.2, damage = 19, hits = 2, interval = 0.25, type = "melee", block = "none",
					bypassRagdoll = true, ragdoll = { h = 60, v = 20 } } },
			-- Domain Expansion: blades rain down imbued with random techniques (Shrine, Thin Ice Breaker, Clairvoyance,
			-- Cursed Speech, Shikigami) that the user picks up and swings. Breaks with no enemy inside.
			-- TODO: the katanas and "Jacob's Ladder" (62.5, after 4 direct katana swings).
			[ 4 ] = K.Domain{ "Authentic Mutual Love", cooldown = 120, duration = 45, sureHit = "none", color = "pink" },
		},
		special = RIKA,

		-- Awakened Rika: separate cooldowns
		alt = {
			name = "Rika (Awakened)",
			abilities = {
				-- Rika slams the target into the floor with one arm (8), then a second impact (4).
				[ 1 ] = K.Target{ "Rika Downslam", cooldown = 13, teleport = false, range = 45, startup = 0.4, damage = 12, hits = 2, interval = 0.4,
					type = "melee", block = "none", bypassRagdoll = true, uninterruptible = true, ragdoll = { h = 5, v = -30 }, color = "pink" },
				-- Rika grabs the target by the leg and slams them five times (1 + 2 x 4 + 3).
				[ 2 ] = K.Target{ "Rika Slam", cooldown = 13, teleport = false, range = 45, startup = 0.4, damage = 12, hits = 6, interval = 0.3,
					type = "melee", block = "none", bypassRagdoll = true, uninterruptible = true, ragdoll = { h = 30, v = 30 }, color = "pink" },
				-- Rika powers a pink orb into an overwhelming beam (100; less the more players hit and the farther). Beam clash rank 3.
				-- Follow-up: pressed again in the windup, a smaller faster beam (22.4).
				[ 3 ] = K.Beam{ "True Love Beam", cooldown = 40, startup = 1.8, damage = 100, duration = 1.5, tick = 0.25, range = 160, radius = 7,
					pierce = true, clash = 3, type = "explosion", block = "none", bypassRagdoll = true, color = "pink", crater = 1800,
					ragdoll = { h = 60, v = 25 }, tip = "USE AGAIN",
					again = K.Beam{ "True Love Beam: Quick", window = 1.5, startup = 0.2, damage = 22.4, range = 120, radius = 4, pierce = true,
						type = "explosion", block = "none", bypassRagdoll = true, color = "pink" } },
				-- Rika throws the user; crashing into an enemy ragdolls them (8-18 by airtime). Missing hurts the user (0.5-22).
				[ 4 ] = K.Mobility{ "Rika Throw", cooldown = 13, startup = 0.5, travel = 45, time = 0.5, dir = "aim", damage = 13, type = "melee",
					bypassRagdoll = true, ragdoll = { h = 55, v = 25 } },
			},
			special = RIKA,
		},
	},
} )
