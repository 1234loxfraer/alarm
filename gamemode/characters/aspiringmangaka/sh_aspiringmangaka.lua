-- Aspiring Mangaka. Generated from the JJS wiki; every move is a JJS.Kit placeholder.
-- Comments summarise what the real move does (see the wiki page for details).

local K = JJS.Kit

K.Character( "aspiringmangaka", {
	name = "Aspiring Mangaka",
	category = "baseonly",
	hp = 85,
	model = K.Model( "aspiringmangaka", "models/player/kleiner.mdl" ),
	color = Color( 230, 230, 230 ),

	passives = {
		{ "G-Warstaff", "The user holds a G-Warstaff." },
		{ "Oracle", "When blocking an enemy’s attack within 0.05 seconds of impact, the user will evade the strike while leaving an afterimage behind, regardless of which side the attack landed on." },
	},

	abilities = {
		-- The user sends rapid thrusts of their cursed tool forwards before winding back an unblockable slash to send the enemy flying back.
		[ 1 ] = K.Melee{ "Despair", cooldown = 16, damage = 16.1, hits = 2, type = "melee", blockDamage = 8.05, bypassRagdoll = true },
		-- The user turns their G Warstaff backwards to pierce the torso of whoever is behind them.
		-- TODO melee counter variant: If the user is hit by a melee attack during the windup, then the move will function in a counteresque manner by speeding up the thrust...
		-- Air variant: Using the move while airborne will cause the user to hop upwards while winding up a heavy slam with their G Warstaff, crushing targets...
		-- TODO interruption air variant: If the slam interrupts an enemy’s attack, the target will get slammed face-first into the floor.
		[ 2 ] = K.Counter{ "Shut Up!", cooldown = 16, counters = { melee = "counter" }, riposte = 7, tip = "HIT", air = {} },
		-- The user crosses their arms momentarily, going into their block stance.
		[ 3 ] = K.Counter{ "Eye Catching", cooldown = 14, counters = { melee = "counter", bullet = "counter", swarm = "evade", explosion = "evade" }, window = 0.75, riposte = 9 },
		-- The user twirls their spear before thrusting it and dashing 20 studs forwards.
		[ 4 ] = K.Melee{ "Sacrilege", cooldown = 16, damage = 12, hits = 2, type = "melee", block = "none", bypassRagdoll = true, trueRag = true, ragdoll = { h = -20, v = 16 } },
	},
	-- While hovering their cursor over an opponent within 35 studs, the user can mark their torso with a glowing manga panel for 25 seconds in order to peer into their...
	-- TODO special variant "Clairvoyance: Prediction": While facing a marked enemy, the user can force them to side dash or back dash every 4 seconds by pressing their special.
	special = K.Melee{ "Clairvoyance", cooldown = 25, damage = 25, type = "melee", block = "none", bypassRagdoll = true, ragdoll = { h = 45, v = 18 }, tip = "SPECIAL" },

	-- Base-only: the awakening is a single move
	-- Upon activation, the user will hold their spear vertically in a defensive position.
	awakenMove = K.Counter{ "Foresight", counters = { melee = "counter" }, window = 1, riposte = 40 },
	-- TODO awakening melee counter "Foresight": If the attacker is marked by Clairvoyance or has less than 40 HP, a cutscene will initiate consisting of the user reacting by pushing...
} )
