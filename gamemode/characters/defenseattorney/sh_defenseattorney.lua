-- Defense Attorney. Generated from the JJS wiki; every move is a JJS.Kit placeholder.
-- Comments summarise what the real move does (see the wiki page for details).

local K = JJS.Kit

K.Character( "defenseattorney", {
	name = "Defense Attorney",
	category = "complete",
	hp = 90,
	model = K.Model( "defenseattorney", "models/player/magnusson.mdl" ),
	color = Color( 230, 210, 120 ),

	passives = {
		{ "Judge Gavel", "The user's cursed technique is tied to a gavel, with the second melee attack being split into two hits." },
	},

	abilities = {
		-- The user extends their gavel's handle, turning it into a sledgehammer then swinging it 3 times and finishing off with a devastating slam that will knock the target to...
		-- TODO special variant: If the user was unarmed when using this move, they will instantly recall their tool and gain melee i-frames while performing a quick...
		[ 1 ] = K.Melee{ "Extended Swings", cooldown = 15, damage = 15, hits = 2, type = "melee", ragdoll = true, tip = "SPECIAL" },
		-- The user starts lifting their gavel up to make way a powerful ground slam, as it enlarges to a comedic size, crushing the target under its force and bouncing them...
		-- TODO block break variant: If the target was blocking while the slam occurs, they will instead be crushed under the tool's weight and block broken on the floor for...
		[ 2 ] = K.Melee{ "Justice Served", cooldown = 18, damage = 12, type = "melee", block = "none", bypassRagdoll = true },
		-- The user holds their gavel forwards, before extending its handle to attack from a distance.
		-- Follow-up: If the move was used twice during its windup, the user will follow up their gavel extension with a mostly uncounterable slam, grounding...
		-- TODO special variant: If the user was unarmed before using this move, they will recall their tool and skip straight to the slam.
		-- TODO special variant: By using the special during the move's windup, the user extends their gavel's handle backwards to eject themselves 35 studs forwards.
		-- TODO air target variant "Grapple": If this move was used on an airborne enemy, the user will extend their gavel upwards like a hook to latch onto the target and make way...
		[ 3 ] = K.Projectile{ "Judgement's Reach", cooldown = 13, damage = 7, type = "bullet", bypassRagdoll = true, color = "blue", tip = "USE TWICE", again = K.Summon{ "Judgement's Reach", damage = 6, type = "bullet", blockDamage = 3, bypassRagdoll = true, color = "blue" } },
		-- The user kicks the target away regardless of block, and gets ready to rush into them right as they get unstunned with a swing of their gavel.
		-- TODO variant: Using Extended Swings right after the kick will cancel the rush with a sweep of the gavel's handle.
		-- TODO variant: Using Justice Served right after the kick will increase the gavel's size dramatically, allowing the user to follow up with a left swing...
		-- TODO special variant: If the user was unarmed before using this move, then they will only perform the kick without a second rush.
		[ 4 ] = K.Melee{ "Pressing Charges", cooldown = 16, damage = 4, hits = 2, type = "melee", bypassRagdoll = true, ragdoll = { h = 45, v = 18 }, tip = "SPECIAL" },
	},
	-- The user launches their gavel afar.
	-- TODO special variant: If the gavel makes contact with a target (even if blocked), it will take thrice as long to return.
	special = K.Projectile{ "No Escape", cooldown = 5, damage = 3, type = "bullet", block = "all", bypassRagdoll = true, range = 50, color = "blue", tip = "SPECIAL" },

	awakening = {
		name = "Deadly Sentencing",
		-- TODO cosmetic/passive "Executioner's Sword": While using the Executioner's Sword, the user's basic attacks will reach from 12 studs away rather than the normal 8, at the expense of lower...
		abilities = {
			-- The user charges up a quick forward dash with the Executioner's Sword.
			[ 1 ] = K.Melee{ "Execution", cooldown = 12, damage = 25, hits = 3, type = "melee", block = "none", ragdoll = { h = 45, v = 18 } },
			-- The user begins running forwards before spinning around with a swipe of their cursed tool.
			[ 2 ] = K.Melee{ "Final Judgement", cooldown = 21, damage = 10, type = "melee", block = "none", bypassRagdoll = true, uninterruptible = true },
			-- The user holds their sword by its blade to knock the target away with its hilt.
			-- Follow-up: By pressing the move again before the second swing hit is performed, the user will keep holding their cursed tool by its blade to swing...
			[ 3 ] = K.Melee{ "Verdict", cooldown = 18, damage = 5, type = "melee", blockDamage = 2.5, bypassRagdoll = true, trueRag = true, tip = "USE TWICE", again = K.Melee{ "Verdict", damage = 5, type = "melee", block = "none", bypassRagdoll = true, ragdoll = { h = 45, v = 18 } } },
			-- The user launches their sword forwards to sever the opponent's limb and apply an Execution stack before recalling it.
			[ 4 ] = K.Projectile{ "Triple Sentence", cooldown = 12, damage = 8, type = "bullet", block = "pre", bypassRagdoll = true, color = "blue" },
		},
		-- Activating their special will cover the user with a thin veil of their own domain expansion around them.
		special = K.Buff{ "Domain Amplification", cooldown = 8 },
	},

	-- TODO tab "Domain Awakening" from the wiki:
	--   Deadly Sentencing [domain awakening]: Upon activating their Awakening, the user will expand their domain, Deadly Sentencing, which resembles a platform...
} )
