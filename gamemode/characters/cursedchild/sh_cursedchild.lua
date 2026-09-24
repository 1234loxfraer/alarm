-- Cursed Child ("Others"; 250 HP as a boss). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does.
-- Check marks a target: they take 30% more damage for 15s.

local K = JJS.Kit

-- "Act" -> "Check" on a nearby opponent: *DEF REDUCED (+30% damage taken for 15s)
local CHECK = K.Target{ "Check", cooldown = 25, teleport = false, noHit = true, range = 30, startup = 0.4, endlag = 0.1, color = "red",
	onEnd = function( ply )
		local t = ply:GetJActTarget()
		if IsValid( t ) then t.jjs_checked = CurTime() + 15 end
	end }

K.Character( "cursedchild", {
	name = "Cursed Child",
	category = "other",
	hp = 100,
	model = K.Model( "cursedchild", "models/player/p2_chell.mdl" ),
	color = Color( 200, 60, 90 ),

	-- Real Knife: slower, weaker M1s (2 + 2 + 2 + 4)
	m1 = { Damage = { 2, 2, 2, 4 }, Duration = 0.42 },

	passives = {
		{ "Real Knife", "M1s deal 2 + 2 + 2 + 4 and hits show floating damage numbers. (partly TODO)" },
		{ "Soul Flip", "Longer front and back dashes; back dashes put the front dash on cooldown. (TODO)" },
	},

	abilities = {
		-- A large slash, two stabs, three kicks, two more stabs and a final ragdolling kick (17.2).
		-- Air variant "Feral Takedown": grabs (1.5), slams into the floor (6.5) and jumps off the body (1.5).
		[ 1 ] = K.Melee{ "Onslaught", cooldown = 17, startup = 0.4, damage = 17.2, hits = 8, interval = 0.15, type = "melee", bypassRagdoll = true,
			ragdoll = { h = 55, v = 18 }, air = { kind = "grab", damage = 9.5, hits = 3, interval = 0.3, block = "none", ragdoll = { h = 5, v = -30 } } },
		-- Runs and slides; a collided enemy is pinned for three stabs (3 each) and kicked away.
		[ 2 ] = K.Grab{ "Lethal Wound", cooldown = 18, startup = 0.3, damage = 12, hits = 4, interval = 0.25, lunge = 25, type = "melee", block = "none",
			bypassRagdoll = true, ragdoll = { h = 50, v = 15 } },
		-- A spinning back kick (4) then a forward slash; anyone caught takes a series of blows (12) and is tossed.
		[ 3 ] = K.Grab{ "Bloody Mary", cooldown = 21, startup = 0.35, damage = 21, hits = 5, interval = 0.25, reach = 8, type = "melee", block = "none",
			bypassRagdoll = true, ragdoll = { h = 60, v = 25 } },
		-- A thrust that holds up whoever it catches (2) while an attack bar QTE decides the follow-up slash (10 on success, 2 on fail).
		-- TODO: the QTE (press the move again when the line is centred).
		[ 4 ] = K.Grab{ "Fight", cooldown = 21, startup = 0.35, damage = 12, hits = 2, interval = 1, type = "melee", ragdoll = { h = 45, v = 15 } },
	},
	special = CHECK,

	awakening = {
		name = "SINCE WHEN WERE YOU THE ONE IN CONTROL?",
		duration = 60,
		heal = 35,
		-- Knocked back by an unknown source, DETERMINATION pieces the soul back together: "I'm... Baack!"
		abilities = {
			-- Three zig-zag sidesteps (7 each), then a long knife assault ending in a jumping cleave to the neck (40).
			[ 1 ] = K.Grab{ "Cursed Remedy", cooldown = 16, startup = 0.6, damage = 61, hits = 8, interval = 0.2, lunge = 25, type = "melee", block = "none",
				bypassRagdoll = true, uninterruptible = true, ragdoll = { h = 60, v = 30 } },
			-- Arms behind the back: a melee or bullet attacker is sent to an abyss to face Chara (50-70; 20 to the user).
			[ 2 ] = K.Counter{ "Reset", cooldown = 45, window = 1, riposte = 60, counters = { melee = "counter", bullet = "counter" }, color = "red",
				onCounter = function( ply ) JJS.ApplyDamage( ply, nil, 20, { type = JJS.DMG.SPECIAL } ) end },
			-- Knife toss and catch, a lunging stab, an upward swing and a stab; a hit starts an Undertale-like encounter (100).
			-- TODO: the minigame, and the variant where the enemy endures and turns the knife around (20, 15 to the user).
			[ 3 ] = K.Melee{ "Atonement", cooldown = 30, startup = 0.6, damage = 100, hits = 3, interval = 0.35, lunge = 15, type = "special",
				block = "none", uninterruptible = true, ragdoll = { h = 70, v = 25 } },
			-- A long run with Chara's soul (2.5 per rush hit), a swing (5) and a double assault (20); QTEs can raise it to 45.
			[ 4 ] = K.Grab{ "Seven Souls", cooldown = 44, startup = 0.6, damage = 45, hits = 6, interval = 0.3, lunge = 35, type = "melee",
				block = "none", bypassRagdoll = true, ragdoll = { h = 70, v = 30 } },
		},
		special = CHECK,
	},
} )

if SERVER then
	JJS.AddDamageMod( "check", function( victim )
		if ( victim.jjs_checked or 0 ) > CurTime() then return 1.3 end
	end )
end
