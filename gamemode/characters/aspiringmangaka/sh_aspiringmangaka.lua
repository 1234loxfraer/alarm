-- Aspiring Mangaka (Charles Bernard, base-only). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does.

local K = JJS.Kit

local function Marked( victim ) return ( victim.jjs_clairvoyance or 0 ) > CurTime() end

K.Character( "aspiringmangaka", {
	name = "Aspiring Mangaka",
	category = "baseonly",
	hp = 85,
	model = K.Model( "aspiringmangaka", "models/player/kleiner.mdl" ),
	color = Color( 230, 230, 230 ),

	passives = {
		{ "G-Warstaff", "Cosmetic: a staff whose trail reddens as the awakening bar fills." },
		{ "Oracle", "360 perfect block: blocking within 0.05-0.25s of impact evades with an afterimage. (TODO)" },
	},

	abilities = {
		-- Rapid thrusts of the staff (15) then an unblockable slash sending the enemy flying (1.1).
		[ 1 ] = K.Melee{ "Despair", cooldown = 16, startup = 0.3, damage = 16.1, hits = 6, interval = 0.14, reach = 10, width = 5, type = "melee",
			blockDamage = 8, bypassRagdoll = true, ragdoll = { h = 60, v = 18 } },
		-- Turns the staff backward to pierce whoever is behind (3), then spins them to the front and kicks them away (4).
		-- Hit by melee during the windup, it acts as a counter.
		-- Air variant: hops up and slams the staff down, crushing targets beneath (12, unblockable).
		[ 2 ] = K.Counter{ "Shut Up!", cooldown = 16, window = 0.5, counters = { melee = "counter" }, riposte = 7, teleport = true,
			air = { kind = "aoe", damage = 12, radius = 9, type = "melee", block = "none", bypassRagdoll = true, ragdoll = { h = 5, v = -30 } } },
		-- Block stance: melee or bullet attackers are dodged and knocked down (9); blockable explosions/swarms are just kept at bay.
		[ 3 ] = K.Counter{ "Eye Catching", cooldown = 14, window = 0.75, riposte = 9,
			counters = { melee = "counter", bullet = "counter", swarm = "evade", explosion = "evade" } },
		-- Twirls the spear, thrusts and dashes 20 studs; on contact: "Stop desecrating this work!" (6 + 6).
		[ 4 ] = K.Grab{ "Sacrilege", cooldown = 16, startup = 0.35, damage = 12, hits = 2, interval = 0.5, lunge = 20, type = "melee", block = "none",
			bypassRagdoll = true, trueRag = true, ragdoll = { h = 60, v = 20 } },
	},
	-- Hovering over an opponent within 35 studs, marks them with a manga panel for 25s (the user sees their future).
	-- TODO: forced side/back dashes every 4s ("Prediction") and the other disadvantages of the mark.
	special = K.Target{ "Clairvoyance", cooldown = 25, teleport = false, noHit = true, range = 35, startup = 0.2, endlag = 0.1, awakenCost = 0.05,
		color = "white", onEnd = function( ply )
			local t = ply:GetJActTarget()
			if IsValid( t ) then t.jjs_clairvoyance = CurTime() + 25 end
		end },

	-- Holds the spear defensively for 1s; a melee attacker is blocked and smacked away (40). On a Clairvoyance-marked
	-- target or one under 40 HP, the user foresees every punch and pierces them (115, heals 21.25).
	awakenMove = K.Counter{ "Foresight", window = 1, riposte = 40, counters = { melee = "counter" },
		onCounter = function( ply, attacker )
			if Marked( attacker ) or attacker:GetJHP() < 40 then
				JJS.ApplyDamage( attacker, ply, 75, { type = JJS.DMG.SPECIAL } )
				JJS.Heal( ply, 21.25 )
			end
		end },
} )
