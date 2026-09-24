-- Disaster Plants. Generated from the JJS wiki; every move is a JJS.Kit placeholder.
-- Comments summarise what the real move does (see the wiki page for details).

local K = JJS.Kit

K.Character( "disasterplants", {
	name = "Disaster Plants",
	category = "complete",
	hp = 100,
	model = K.Model( "disasterplants", "models/player/charple.mdl" ),
	color = Color( 120, 220, 90 ),

	passives = {
		{ "Arm Wrap", "As the user stands 1.25 times taller than others, their left arm is wrapped in white clothing which forces them to solely rely on their right one to attack." },
		{ "Lasso", "When initiating a front dash, the user will place their hand on the ground to manifest a long root that will sweep in and grab a target from 50 studs away or less, pulling them and setting them..." },
	},

	abilities = {
		-- The user activates their technique by plunging their arm in the ground to unleash a line of tree roots that will grow for 2 seconds in a straight line, reaching 50...
		-- TODO variant: If the player is facing a gap or was jumping before using this move, the roots will become tangible to act as a bridge before...
		-- TODO special variant: If the user was airborne or performing an action while the ground is marked with Plant Guidance, a small bundle of spikes will sprout...
		[ 1 ] = K.Summon{ "Root Swarm", cooldown = 15, damage = 10, type = "swarm", block = "none", bypassRagdoll = true, range = 50, ragdoll = { h = 45, v = 18 }, color = "shadow", tip = "SPECIAL" },
		-- The user conjures two wooden balls which will quickly protrude sharp branches to push any target in their 35 stud range back towards 3 deadly thorns rising from the...
		-- TODO special variant: During an action or while in the air, using this move while the ground is marked with Plant Guidance causes a long sharp thorn to...
		[ 2 ] = K.Projectile{ "Surging Thorns", cooldown = 16, damage = 15, type = "bullet", range = 35, ragdoll = { h = 45, v = 18 }, color = "blue", tip = "SPECIAL" },
		-- The user chucks two cursed buds 70 studs forwards, which will push targets within 35 studs away and pull those at further range.
		[ 3 ] = K.Projectile{ "Bud Shot", cooldown = 15, damage = 8, type = "bullet", bypassRagdoll = true, range = 70, color = "blue" },
		-- The user reclines back then gains melee i-frames as they surge forwards and swing their arm violently, locking themselves in a short sequence where they deliver a...
		-- Air variant: If Defense Response was used in the air, the user will instead motions for a spike to rise up from 25 studs away and launch anyone under...
		-- TODO special variant "Flower Patch": During an action or while in the air, using this move while the ground is marked with Plant Guidance causes a bed of flowers to sudden...
		[ 4 ] = K.Melee{ "Defense Response", cooldown = 15, damage = 12, type = "melee", block = "none", ragdoll = { h = 45, v = 18 }, tip = "SPECIAL", air = { damage = 15, hits = 2, bypassRagdoll = true, type = "swarm", ragdoll = { h = 8, v = 60 } } },
	},
	-- By aiming the special anywhere within 65 studs, the user can mark the ground to set up for a special attack, with a constant glowing circle indicating the marked zone...
	special = K.Buff{ "Plant Guidance", cooldown = 0.5, uninterruptible = true },

	awakening = {
		name = "Unwrap",
		duration = 60,
		heal = 25,
		-- The user grips the white cloth covering their arm while saying "It would seem that..." before ripping the wrap off, revealing their arm with a flower bud on the...
		-- TODO passive "Unwrap": Now unrestricted, the user begins fighting again with both hands, able to perform 3 regular basic attacks before reaching their default M1.
		abilities = {
			-- This time taking their opponent seriously, the user kneels to the floor and creates a line of tangible roots that will stretch for 7 seconds towards any direction the...
			-- TODO special variant: If the user was empowered, they will gain the ability to steer another root on top of the one they were already controlling.
			-- Air variant "Thorn Rampage": If the user was airborne, the line of roots will appear beneath them to carry them in the air, before dissipating as the user creates a...
			[ 1 ] = K.Projectile{ "Root Rampage", cooldown = 16, damage = 5, type = "bullet", block = "pre", bypassRagdoll = true, range = 385, color = "blue", tip = "SPECIAL", air = { damage = 25, block = "none", range = 50 } },
			-- The user raises their hand as they aim for an area in front of them to spread a 20x20 stud field of blooming flowers on.
			-- TODO special variant: If the user was empowered, they will conjure a living spike with a gaping mouth and lingering roots.
			[ 2 ] = K.Summon{ "Flower Field", cooldown = 16, damage = 6, type = "swarm", block = "none", bypassRagdoll = true, range = 20, ragdoll = { h = 8, v = 60 }, color = "shadow", tip = "SPECIAL" },
			-- The user performs a handsign by raising their hands in the air to summon a massive flower in front of them, ragdolling away all nearby opponents as it prepares to...
			-- TODO special variant: If the user was empowered, then their cursed energy will increase the size of the flower turret, consequently doubling the amount of...
			[ 3 ] = K.Summon{ "Cursed Buds", cooldown = 16, damage = 33.5, type = "bullet", blockDamage = 16.75, bypassRagdoll = true, ragdoll = { h = 45, v = 18 }, color = "blue", tip = "SPECIAL" },
			-- The user casts their domain expansion while kneeling on the ground to sap energy from nearby foliage.
			[ 4 ] = K.Domain{ "Shining Sea of Growing Branches", cooldown = 120, duration = 15, sureHit = "damage", dps = 3, color = "white" },
		},
		-- The user draws their own cursed energy to store it in their flower arm, going into a empowered state indicated through a flowing golden aura enveloping them.
		-- TODO special variant "Flower Beam": If the user reactivates their special while empowered, they will lean forwards and aim the eye of their flower to shoot a devastating...
		-- TODO special variant "Flower Beam": After Shining Sea of Growing Branches is expanded, Flower Beam will immediately go off cooldown due to the immense boost of cursed...
		special = K.Buff{ "Energy Absorb", cooldown = 12, tip = "SPECIAL" },
	},
} )
