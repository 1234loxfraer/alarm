-- Defense Attorney (Hiromi Higuruma). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does.
-- Awakening expands Deadly Sentencing, then grants the Executioner's Sword (Death Penalty).
-- Execution stacks: a second stack on the same target executes them.

local K = JJS.Kit

-- Adds an Execution stack; the second one kills
local function Execute( ply, victim )
	victim.jjs_execution = ( victim.jjs_execution or 0 ) + 1
	if victim.jjs_execution >= 2 then JJS.Kill( victim, ply, { type = JJS.DMG.SPECIAL } ) end
end

K.Character( "defenseattorney", {
	name = "Defense Attorney",
	category = "complete",
	hp = 90,
	model = K.Model( "defenseattorney", "models/player/magnusson.mdl" ),
	color = Color( 230, 210, 120 ),

	passives = {
		{ "Judge Gavel", "The 2nd M1 hits twice (2 + (2 + 2) + 4 + 4); block breaks set the string to it. (TODO)" },
	},

	abilities = {
		-- The gavel becomes a sledgehammer: 3 swings (2 each) and a slam knocking the target down (9).
		-- TODO special variant: unarmed, a quick sweep with melee i-frames that pushes the target away.
		[ 1 ] = K.Melee{ "Extended Swings", cooldown = 15, startup = 0.35, damage = 15, hits = 4, interval = 0.3, reach = 9, type = "melee",
			ragdoll = { h = 10, v = -25 }, crater = 800 },
		-- Lifts the gavel and slams it at a comedic size, bouncing the target high.
		-- TODO block break variant (9): a blocking target is crushed and block broken for a few seconds.
		[ 2 ] = K.Melee{ "Justice Served", cooldown = 18, startup = 0.75, damage = 12, reach = 9, width = 10, type = "melee", block = "none",
			bypassRagdoll = true, crater = 1300, ragdoll = { h = 5, v = 60 } },
		-- Extends the gavel's handle to hit from a distance with knockback and slight stun (pushes even through block).
		-- Follow-up: pressed twice in the windup, a mostly uncounterable slam grounds the target (6).
		-- TODO variants: unarmed (skips to the slam), special in the windup (ejects 35 studs forward), Grapple on airborne targets (11).
		[ 3 ] = K.Melee{ "Judgement's Reach", cooldown = 13, startup = 0.4, damage = 7, reach = 22, width = 4, type = "bullet",
			bypassRagdoll = true, stun = 0.6, tip = "USE TWICE",
			again = K.Melee{ "Judgement's Reach: Slam", window = 0.6, startup = 0.3, damage = 6, reach = 22, width = 5, type = "swarm",
				blockDamage = 3, bypassRagdoll = true, ragdoll = { h = 5, v = -30 } } },
		-- Kicks the target away regardless of block (4), then rushes in with a gavel swing as they recover (3.5, +11 on 14.5 HP).
		-- TODO variants: Extended Swings / Justice Served right after the kick; unarmed kick only.
		[ 4 ] = K.Melee{ "Pressing Charges", cooldown = 16, startup = 0.3, damage = 7.5, hits = 2, interval = 0.8, reach = 9, type = "melee",
			block = "none", bypassRagdoll = true, ragdoll = { h = 45, v = 15 } },
	},
	-- Throws the gavel 50 studs (3); it comes back after 0.75s. Costs 3% awakening.
	-- TODO special variant: once it hit, pressing again hops toward the target; recalling with a move or M1.
	special = K.Projectile{ "No Escape", cooldown = 5, startup = 0.2, damage = 3, range = 50, speed = 200, radius = 2.5, type = "bullet",
		block = "all", bypassRagdoll = true, awakenCost = 0.03, color = "gold" },

	awakening = {
		name = "Death Penalty",
		duration = 90,
		heal = 40,
		-- Deadly Sentencing: a trial where the defendant confesses, stays silent or denies; the verdict decides the outcome
		-- (Innocence, Confiscation, Death Penalty). Death Penalty reveals the Executioner's Sword: any cut kills.
		-- TODO: the trial (Judgment Bar, 3 choices, 6 wrong guesses break it) and Confiscation of abilities.
		-- TODO passive "Executioner's Sword": M1s reach 12 studs, 6 hits (2 + 2 + (3 x 1) + 1), front dash doesn't ragdoll.
		domain = K.Domain{ "Deadly Sentencing", duration = 15, sureHit = "none", color = "gold" },
		abilities = {
			-- A quick forward dash with the sword (10) impaling a limb, applying an Execution stack, then a toss (15).
			[ 1 ] = K.Melee{ "Execution", cooldown = 12, startup = 0.35, damage = 25, hits = 2, interval = 0.5, lunge = 20, type = "special",
				block = "none", ragdoll = { h = 55, v = 20 }, color = "gold", onHit = Execute },
			-- Runs forward then spins with a swipe (10); landed, a quick-time event decides between a stab (300) and a kick (25).
			-- TODO: the QTE. Follow-up: pressing again during the lunge feints it (17s cooldown).
			[ 2 ] = K.Grab{ "Final Judgement", cooldown = 21, startup = 0.45, damage = 35, hits = 2, interval = 1.2, lunge = 25, uninterruptible = true,
				type = "special", block = "none", bypassRagdoll = true, trueRag = true, ragdoll = { h = 60, v = 25 } },
			-- Hilt knock (5), then a dash with the edge (5): unblocked, it executes like Execution.
			-- Follow-up: pressed again before the edge swing, the hilt swings again (10, 50 if blocked).
			[ 3 ] = K.Melee{ "Verdict", cooldown = 18, startup = 0.35, damage = 10, hits = 2, interval = 0.55, type = "melee", blockDamage = 5,
				bypassRagdoll = true, trueRag = true, ragdoll = { h = 45, v = 15 }, onHit = Execute, tip = "USE TWICE",
				again = K.Melee{ "Verdict: Hilt", window = 0.5, startup = 0.2, damage = 10, type = "melee", block = "none", bypassRagdoll = true,
					ragdoll = { h = 55, v = 20 } } },
			-- Throws the sword forward to sever a limb (8, Execution stack) and recalls it; up to three throws. Perfect-blockable.
			[ 4 ] = K.Projectile{ "Triple Sentence", cooldown = 12, charges = 3, chargeDelay = 0.4, startup = 0.3, damage = 8, range = 60,
				speed = 220, radius = 2.5, type = "bullet", block = "pre", bypassRagdoll = true, color = "gold", onHit = Execute },
		},
		-- A thin veil of their domain negates the next attack (about 0.5s of i-frames) and blocks domain sure-hits. Costs 5%.
		special = K.Buff{ "Domain Amplification", cooldown = 8, startup = 0.2, duration = 0.2, color = "gold",
			onUse = function( ply ) ply.jjs_amplified = true end },
	},
} )

hook.Add( "JJS_PreHit", "JJS_DomainAmplification", function( victim, hit )
	if not victim.jjs_amplified or hit.attacker == victim then return end
	victim.jjs_amplified = nil
	JJS.IFrames( victim, 0.5 )
	return "evaded"
end )

hook.Add( "JJS_DomainImmune", "JJS_DomainAmplification", function( ply )
	if ply.jjs_amplified then return true end
end )

hook.Add( "JJS_PlayerSpawned", "JJS_ExecutionStacks", function( ply )
	ply.jjs_execution = nil
	ply.jjs_amplified = nil
end )
