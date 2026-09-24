-- Puppet Master. Generated from the JJS wiki; every move is a JJS.Kit placeholder.
-- Comments summarise what the real move does (see the wiki page for details).

local K = JJS.Kit

K.Character( "puppetmaster", {
	name = "Puppet Master",
	category = "complete",
	hp = 85,
	model = K.Model( "puppetmaster", "models/player/combine_soldier.mdl" ),
	color = Color( 140, 170, 190 ),

	passives = {
		{ "Ultimate Proxy", "Due to their Heavenly Restriction making their body frail and fragile." },
		{ "Energy Reserves", "A benefit of the user's Heavenly Restriction is their ability to exceed the natural limits of cursed energy that they can gain at a time." },
	},

	abilities = {
		-- The puppet's right hand reveals several sharp claws as their forearm starts spinning rapidly.
		-- TODO special variant: If Offload is toggled on, the puppet will land in front of the original puppet while facing them to perform the same Ultra Drill with...
		[ 1 ] = K.Melee{ "Ultra Spin", cooldown = 15, damage = 13.5, hits = 2, type = "melee", lunge = 15, tip = "SPECIAL" },
		-- The puppet will spin around to stand on its hands and grab with its legs.
		[ 2 ] = K.Grab{ "Boost On", cooldown = 16, damage = 10, hits = 2, type = "melee", block = "none", bypassRagdoll = true },
		-- The puppet points forwards with their left arm as they wind up a long blast of energy from the palm of their hand to blast their opponent with.
		-- Hold variant "Ultimate Cannon": By holding this move's input for 1.3 seconds, the puppet switches to Mode: Albatross, protuding a cannon from their mouth and placing...
		-- TODO special variant: If Offload is toggled on, an expendable copy will land to the left of the original and keep Ultra Cannon wound up while aiming on its...
		[ 3 ] = K.AoE{ "Ultra Cannon", cooldown = 17, damage = 10, type = "explosion", block = "all", bypassRagdoll = true, color = "orange", tip = "HOLD", hold = { time = 1.3, damage = 16.15, block = "none", ragdoll = true } },
		-- The puppet activates Boost On to eject itself forwards, before using their boosters to unleash a cloud of scorching flames that will fry the opponent and knock them...
		-- Follow-up: If used once again after their hop, the puppet will turn off Boost On and end its attack early by releasing a significantly smaller...
		-- TODO special variant: If Offload is toggled on, the puppet will bring in a replacement that will launch itself forwards with Boost On a straight line and end...
		[ 4 ] = K.AoE{ "Heat Emission", cooldown = 16, damage = 13, type = "explosion", block = "none", bypassRagdoll = true, color = "orange", tip = "USE TWICE", again = K.AoE{ "Heat Emission", damage = 9, type = "explosion", block = "all", bypassRagdoll = true, color = "orange" } },
	},
	-- Activating the special will envelop the puppet in cursed energy, indicating that its next move (Boost On excluded) will stay off cooldown while an expendable puppet...
	-- TODO special variant "Übercharge": If Offload is used while on cooldown, the cursed energy around the puppet will be red.
	-- TODO special variant "Puppet Barrage": Using the special while a non-Übercharge Offload is activated target within 100 studs will call down for two cursed corpses to surround...
	special = K.Melee{ "Offload", cooldown = 10, damage = 3, type = "melee", block = "none", uninterruptible = true, ragdoll = { h = 45, v = 18 }, tip = "SPECIAL" },

	awakening = {
		name = "Absolute",
		duration = 8,
		heal = 117,
		-- The user activates Mode: Absolute, dismissing their original puppet to pilot a giant mech 5 times bigger than normal, which will climb out of the ground, power up,...
		-- TODO passive "Mode: Absolute": Due to the mechanisms of their robot, the user will have to engage in combat while taking in many factors: *Each part of the robot counts as a...
		-- TODO passive "Mode: Absolute": Rather than performing a regular forward dash, the mech will wind up a heavy kick that can only target stunned/ragdolled enemies.
		-- TODO passive "Mode: Absolute": If the mech itself is airborne, the front dash will become a powerful AoE dropkick, flinging enemies upwards.
		-- TODO passive "Last Chance": If the mech's HP reaches 0, a puppet will hop out of it and rush downwards with a final last-ditch attack: a drill that will allow the puppet to...
		abilities = {
			-- Using one year of the user's stored cursed energy, the mech holds one arm in front of it and blasts the area in front of it with fiery energy that sets any targets...
			-- TODO special variant: If Energy Output was set to the second level or higher, then the mech will consume 2 years of the user's stored cursed energy to charge...
			[ 1 ] = K.AoE{ "Miracle Cannon", cooldown = 8, damage = 20, type = "explosion", block = "none", bypassRagdoll = true, uninterruptible = true, color = "orange", tip = "SPECIAL" },
			-- After aiming at a target within 250 studs, the mech unleashes three rainbow beams forwards and directs them to home in and chase down the enemy, at the cost of 3...
			[ 2 ] = K.Projectile{ "Pigeon Viola", cooldown = 8, damage = 15, type = "bullet", block = "none", bypassRagdoll = true, uninterruptible = true, range = 250, color = "blue" },
			-- The giant mech utilizes one year worth of cursed energy to begin rampaging through the environment, stomping around 3 times with swarm damage before finishing with a...
			-- Air variant: If the mech is airborne, then it will immediately skip to the final slam, directing itself forwards to use its weight and crush anything...
			[ 3 ] = K.Summon{ "Absolute Destruction", cooldown = 8, damage = 4, type = "explosion", block = "none", bypassRagdoll = true, uninterruptible = true, color = "orange", air = { damage = 20 } },
			-- While aiming at a target within 100 studs, the mechanized puppet consumes one year of cursed energy to deploy a technique-imbued projectile from a compartment in its...
			[ 4 ] = K.Target{ "Technique Charge", cooldown = 8, damage = 20, hits = 2, type = "explosion", block = "none", bypassRagdoll = true, uninterruptible = true, range = 100 },
		},
		-- The user employs a bonus of their Heavenly Restriction that allows them to amplify the mech's attacks by increasing their cursed energy output level.
		special = K.Buff{ "Energy Output", uninterruptible = true },
	},
} )
