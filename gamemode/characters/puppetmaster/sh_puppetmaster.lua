-- Puppet Master (Kokichi Muta / Mechamaru). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does.
-- Awakened, the user pilots the giant Mode: Absolute mech (~117 HP).

local K = JJS.Kit

K.Character( "puppetmaster", {
	name = "Puppet Master",
	category = "complete",
	hp = 85,
	model = K.Model( "puppetmaster", "models/player/combine_soldier.mdl" ),
	color = Color( 140, 170, 190 ),

	passives = {
		{ "Ultimate Proxy", "Cosmetic: a metal forearm guard that sparks on hit." },
		{ "Energy Reserves", "A second awakening bar keeps filling once the first is full (+50% speed) and extends Absolute. (TODO)" },
	},

	abilities = {
		-- The forearm spins with claws out; lunges forward, drills through the torso (9.5) and slams them up with AoE damage (4).
		[ 1 ] = K.Grab{ "Ultra Spin", cooldown = 15, startup = 0.35, damage = 13.5, hits = 4, interval = 0.25, lunge = 15, type = "melee",
			ragdoll = { h = 10, v = 50 }, tip = "SPECIAL" },
		-- Stands on its hands to grab with its legs (4), boosts into the sky and fires a point-blank Ultra Cannon (6).
		[ 2 ] = K.Grab{ "Boost On", cooldown = 16, startup = 0.35, damage = 10, hits = 2, interval = 0.6, type = "melee", block = "none",
			bypassRagdoll = true, ragdoll = { h = 40, v = 45 } },
		-- A long energy blast from the palm (can be delayed a second by holding).
		-- Hold 1.3s "Ultimate Cannon": Mode Albatross, a small ragdolling explosion then a continuous fiery beam for 17 ticks (16.15).
		[ 3 ] = K.Beam{ "Ultra Cannon", cooldown = 17, startup = 0.8, damage = 10, range = 60, radius = 3, type = "explosion", block = "all",
			bypassRagdoll = true, color = "cyan", ragdoll = { h = 50, v = 20 },
			hold = { time = 1.3, damage = 16.15, duration = 1.1, tick = 0.066, block = "none", radius = 5, color = "orange" } },
		-- Boost On ejects the puppet forward, then its boosters unleash scorching flames that knock the opponent upward.
		-- Follow-up: used again after the hop, ends early with a smaller blast (9, 360 blockable).
		[ 4 ] = K.Melee{ "Heat Emission", cooldown = 16, startup = 0.45, damage = 13, lunge = 15, reach = 10, width = 10, type = "explosion",
			block = "none", bypassRagdoll = true, color = "orange", ragdoll = { h = 10, v = 55 }, tip = "USE TWICE",
			again = K.AoE{ "Heat Emission: Early", window = 0.5, startup = 0.1, damage = 9, radius = 8, offset = 5, type = "explosion", block = "all",
				bypassRagdoll = true, color = "orange", ragdoll = { h = 20, v = 35 } } },
	},
	-- The puppet's next move is done by an expendable copy that self destructs (3), keeping the move off cooldown.
	-- TODO: Übercharge (used on cooldown), Puppet Barrage (14) and the per-move Offload variants.
	special = K.Buff{ "Offload", cooldown = 10, startup = 0.2, duration = 0.2, color = "cyan" },

	awakening = {
		name = "Absolute",
		duration = 90,
		hp = 117,
		scale = 3, -- the wiki mech is 5x bigger; 3x keeps it playable on normal maps
		-- The giant mech climbs out of the ground, powers up and roars. Duration depends on energy reserves (8s to 180s).
		-- TODO passives "Mode: Absolute": limbs take ~47% damage, no ragdoll/stun (stagger instead), M1s 6 each,
		-- forward dash becomes a kick on stunned targets (10), aerial dropkick (12), 2s jump cooldown.
		-- TODO passive "Last Chance": at 0 HP a puppet jumps out for a last drill (15) that restores its health if it lands.
		abilities = {
			-- One year of stored energy: an arm blasts the area in front with fire (20).
			-- TODO special variant: Energy Output 2+ charges a massive exploding sphere (35).
			[ 1 ] = K.Beam{ "Miracle Cannon", cooldown = 8, startup = 0.7, damage = 20, range = 50, radius = 10, pierce = true, type = "explosion",
				block = "none", bypassRagdoll = true, uninterruptible = true, color = "orange", ragdoll = { h = 50, v = 25 }, tip = "SPECIAL" },
			-- Aiming at a target within 250 studs, three rainbow beams home in and chase them (5 each, +1 per output level).
			[ 2 ] = K.Target{ "Pigeon Viola", cooldown = 8, teleport = false, range = 250, cone = 0.9, startup = 0.6, damage = 15, hits = 3,
				interval = 0.2, type = "bullet", block = "none", bypassRagdoll = true, uninterruptible = true, color = "pink" },
			-- Rampages with 3 stomps (4 each, swarm) then leaps into a crushing slam (20). Air variant: straight to the slam.
			[ 3 ] = K.AoE{ "Absolute Destruction", cooldown = 8, startup = 0.4, damage = 32, hits = 4, interval = 0.4, radius = 22, offset = 8,
				type = "explosion", block = "none", bypassRagdoll = true, uninterruptible = true, crater = 2000, color = "orange",
				ragdoll = { h = 30, v = 40 }, air = { damage = 20, hits = 1 } },
			-- Aiming within 100 studs, locks on for ~2s and fires a technique-imbued shot (20, +1 per level).
			-- At output level 5 it carries a Simple Domain that shatters the target's domain.
			[ 4 ] = K.Target{ "Technique Charge", cooldown = 8, teleport = false, range = 100, startup = 1.8, damage = 20, type = "explosion",
				block = "none", bypassRagdoll = true, uninterruptible = true, color = "cyan", ragdoll = { h = 10, v = 55 },
				onHit = function( ply, victim )
					for _, d in ipairs( JJS.Domain.All() ) do
						if d:GetCaster() == victim then JJS.Domain.Collapse( d ) end
					end
				end },
		},
		-- Each press raises the cursed energy output level (0-5): stronger next move, higher cost. (Levels are a TODO.)
		special = K.Modes{ "Energy Output", cooldown = 0.3, modes = { "LV 0", "LV 1", "LV 2", "LV 3", "LV 4", "LV 5" }, color = "cyan" },
	},
} )
