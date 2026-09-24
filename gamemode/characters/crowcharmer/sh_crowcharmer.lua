-- Crow Charmer. Generated from the JJS wiki; every move is a JJS.Kit placeholder.
-- Comments summarise what the real move does (see the wiki page for details).

local K = JJS.Kit

K.Character( "crowcharmer", {
	name = "Crow Charmer",
	category = "baseonly",
	hp = 100,
	model = K.Model( "crowcharmer", "models/player/alyx.mdl" ),
	color = Color( 90, 90, 120 ),

	passives = {
		{ "Fly High", "With their battle axe, the user's uppercuts get nearly double the knockback, sending targets flying higher than normal." },
		{ "Flock", "By front dashing while airborne, the user will hop directly forward rather than swing their tool, aiming to kick up an opponent then meet them by jumping 10 studs into the air." },
		{ "Bounding", "If the user is to front dash near a ragdolled target while both are mid air, they will use the target as footing to eject themselves about 5 studs higher." },
	},

	abilities = {
		-- The user swings their battle axe vertically upwards, knocking whoever is hit into the air.
		-- Follow-up: If the move was pressed twice before landing, then the user will add two extra swings after their attack that will end up tossing the...
		-- Air variant "Air Updraft": If used while above jump height, the user will get suspended midair to perform a long sweep with their cursed tool that will launch...
		[ 1 ] = K.Melee{ "Impetus Updraft", cooldown = 16, damage = 11, type = "melee", bypassRagdoll = true, tip = "USE TWICE", again = K.Melee{ "Impetus Updraft", damage = 3, type = "melee", bypassRagdoll = true, ragdoll = { h = 8, v = 60 } }, air = { damage = 14 } },
		-- After a short windup, the user unleashes two long forward swings of their axe done by madly spinning in a circle, with the second swing launching targets afar.
		-- Hold variant: By holding down the move's input, the user can strengthen their axe swings through 2 stages: *Holding the move for about 0.3 seconds...
		-- Air variant "Dive Bomb": If the user was at least 10 studs in the air, they will spin their axe around them in an attempt to grab nearby enemies with their...
		[ 2 ] = K.Melee{ "Circling", cooldown = 18, damage = 6, type = "melee", bypassRagdoll = true, tip = "HOLD", hold = { time = 0.3, block = "none", ragdoll = true }, air = { hits = 3 } },
		-- The user throws their axe while twirling it to let it spin around them like a disk before it returns to its owner.
		-- Air variant "Free Fall": If used from 30 studs in the air, the user will halt their fall to perform a heavy overhead smash that will send the enemy to the ground...
		-- TODO direction: none variant "Bird Control": The user activates their cursed technique to call for a crow.
		-- TODO direction: forward variant "Bird Control": If the user was aiming at a target within 35 studs while walking forwards, the crow will be directed to the target, aiming to crash into...
		-- TODO direction: backward variant "Bird Control": If the user was instead walking backwards, the crow will put extra force into its attack, slamming the target on the ground where they...
		[ 3 ] = K.Melee{ "Murmurate", cooldown = 16, damage = 14, hits = 2, type = "melee", bypassRagdoll = true, trueRag = true, tip = "DIRECTION", air = { damage = 12, block = "none" } },
		[ 4 ] = K.Stub{ "Bird Control" },
	},
	-- The user's younger sibling appears beside them with a white sheet, using it to activate their own cursed technique and transfer the user 20 studs in the direction...
	special = K.Mobility{ "Spatial Transference", cooldown = 18, travel = 20 },

	-- Base-only: the awakening is a single move
	-- The user activates their cursed technique to command a crow, initially only seeing through its eyes, but after the circle effect appears, they will take total control...
	awakenMove = K.Projectile{ "Bird Strike", damage = 75, heal = 25, type = "explosion", block = "none", bypassRagdoll = true, uninterruptible = true, explode = 10, color = "orange" },
	-- TODO awakening attack "Bird Strike": If the black bird is to directly impact an enemy after making its binding vow, then it shall crash into them and explode itself along...
} )
