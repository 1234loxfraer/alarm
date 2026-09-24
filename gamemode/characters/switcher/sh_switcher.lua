-- Switcher. Generated from the JJS wiki; every move is a JJS.Kit placeholder.
-- Comments summarise what the real move does (see the wiki page for details).

local K = JJS.Kit

K.Character( "switcher", {
	name = "Switcher",
	category = "complete",
	hp = 100,
	model = K.Model( "switcher", "models/player/odessa.mdl" ),
	color = Color( 255, 170, 60 ),

	abilities = {
		-- The user spins twice to unleash a powerful kick that cannot kill and forces targets to stand up in stun, helpless against the incoming charge before they're grabbed...
		-- TODO variant "Slide Kick": During Blazing Star or while rolling, using Swift Kick will cause the user to slide on the ground feet forwards, attempting to knock up...
		[ 1 ] = K.Grab{ "Swift Kick", cooldown = 15, damage = 15, hits = 3, type = "melee", blockDamage = 7.5, bypassRagdoll = true },
		-- The user leans their arm back to charge up a powerful punch, hurling opponents away.
		-- TODO variant "Brutal Impact": During Blazing Star, using Brute Force will instead let the user spin with menacing red glowing eyes, winding up a devastating...
		-- Follow-up "Brutal Impact": If Brute Force is pressed again as the kick is about to be unleashed, the user will imbue the blow with cursed energy at the trillionth...
		[ 2 ] = K.Melee{ "Brute Force", cooldown = 17, damage = 17.5, type = "melee", block = "none", bypassRagdoll = true, trueRag = true, ragdoll = { h = 45, v = 18 }, tip = "USE TWICE", again = K.Melee{ "Brutal Impact", damage = 24, type = "melee", block = "none", bypassRagdoll = true, trueRag = true } },
		-- The user slams their foot into the ground to knock up a pebble while imbuing it with cursed energy, before sending it 45 studs in a straight line.
		-- TODO special variant "Gut Punch": By swapping within 1.5 seconds after the pebble makes contact with a target (regardless of block), the user can swap with it and...
		-- TODO special variant "Blazing Star": As long as the pebble did not hit an enemy, the user can swap with it and transfer its momentum to themselves to glide at a fast pace...
		[ 3 ] = K.Projectile{ "Pebble Throw", cooldown = 12, damage = 4, type = "bullet", range = 45, ragdoll = true, color = "blue", tip = "SPECIAL" },
		-- The user performs a charged uppercut and sends the target flying upwards with true ragdoll, before following them with a dive to crush them with their weight, making...
		[ 4 ] = K.Melee{ "Elbow Drop", cooldown = 16, damage = 12, hits = 2, type = "melee", block = "none", ragdoll = { h = 8, v = 60 } },
	},
	-- When using the special on a target within 60 studs, the user claps their hands to activate their cursed technique and instantly swap places and orientations with the...
	-- TODO special variant "Boogie Woogie: Item Swap": On top of being able to swap with people, Boogie Woogie is able to target objects with cursed energy as well.
	-- TODO special variant "Boogie Woogie: Fakeout": Using an M1 or blocking before a clap will cancel the swap while refunding the awakening used.
	-- TODO special variant "Boogie Woogie: Perfect Swap": Timing an M1 right after a clap triggers a "Perfect Swap", refunding the Awakening lost back to the user while putting the special on a...
	-- TODO special variant "Boogie Woogie: Target Swap": The user can also apply their technique to switch between others with a clap.
	special = K.Target{ "Boogie Woogie", cooldown = 6, bypassRagdoll = true, range = 60, ragdoll = true },

	awakening = {
		name = "False Memories",
		duration = 60,
		heal = 20,
		-- Upon initiating the awakening sequence, a cutscene is triggered where the user's locket necklace drops open to reveal their motivation: their brother and their idol.
		-- TODO cosmetic "False Memories": From another player's point of view, the awakened player starts bleeding profusely from their nose.
		abilities = {
			-- The player takes a large step while swiping their arm upwards.
			[ 1 ] = K.Melee{ "Idol's Debut", cooldown = 17, damage = 30, hits = 2, type = "melee", block = "none" },
			-- The user readies up before lunging forwards roughly 40 studs with total i-frames.
			[ 2 ] = K.Melee{ "Climax Jumping", cooldown = 22, damage = 42.4, hits = 3, type = "melee", block = "none", trueRag = true },
			-- The user spreads their arms out before unleashing 3 heavy forward punches, each emitting pink heart effects when landed, while the idol gangnam styles.
			[ 3 ] = K.Melee{ "Dreams", cooldown = 10, damage = 21, hits = 3, type = "melee", block = "none", bypassRagdoll = true, trueRag = true, ragdoll = { h = 45, v = 18 } },
			-- The user gets into a "high five" pose which allows them to interrupt the attacker's melee attack by using their hand to activate Boogie Woogie and swap with their...
			-- TODO variant: If no attack was countered, the user will swap on their own, allowing Yuji to lunge forward and do the same Black Flash, albeit with...
			[ 4 ] = K.Counter{ "Brothers", cooldown = 45, counters = { melee = "counter" }, window = 1.1, riposte = 80 },
		},
		-- Same as base, however swaps cannot feint any moves and are faster in general.
		special = K.Buff{ "Boogie Woogie", block = "all", bypassRagdoll = true },
	},
} )
