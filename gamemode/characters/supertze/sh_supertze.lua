-- Super TZE ("Others", event only). Always in his "Going Super" form. The real kit replaces the M1, dash and
-- special; here those abilities sit on the move keys as JJS.Kit placeholders (the wiki has no numbers yet).

local K = JJS.Kit

K.Character( "supertze", {
	name = "Super TZE",
	category = "other",
	hp = 100,
	model = K.Model( "supertze", "models/player/group01/male_01.mdl" ),
	color = Color( 255, 255, 120 ),

	passives = {
		{ "Going Super", "Absorbs the seven Chaos Emeralds: golden hair, flight and a bright aura." },
		{ "Sonic Boom", "Can fly; dashing forward dives head first with shockwaves. (TODO: replaces the dash)" },
	},

	abilities = {
		-- Super Punch (replaces the M1s): a rapid lunge into the locked-on target and a devastating strike (no endlag, infinite range).
		[ 1 ] = K.Target{ "Super Punch", cooldown = 0.8, range = 250, startup = 0.2, endlag = 0, damage = 10, type = "melee", bypassRagdoll = true,
			ragdoll = { h = 70, v = 20 }, color = "gold" },
		-- Energy Volley (M1 + dash): rapid homing yellow blasts detonating on contact.
		[ 2 ] = K.Target{ "Energy Volley", cooldown = 3, teleport = false, range = 150, cone = 0.8, startup = 0.2, damage = 12, hits = 6, interval = 0.12,
			type = "special", bypassRagdoll = true, color = "gold" },
		-- Sonic Boom: dives head first through the air.
		[ 3 ] = K.Mobility{ "Sonic Boom", cooldown = 1, startup = 0, travel = 60, time = 0.4, endlag = 0, dir = "aim", color = "gold" },
	},
	-- Lock-On: selects any target, even through walls (yellow circle).
	special = K.Target{ "Lock-On", cooldown = 0.5, teleport = false, noHit = true, range = 400, cone = 0.9, startup = 0, endlag = 0, color = "gold" },
} )
