-- Salaryman (Kento Nanami). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does.
-- Ratio Point marks a target for 8s; marked targets take 1.5x damage from the user's moves
-- (placeholder for the per-move Ratio enhancements).

local K = JJS.Kit

local function Marked( victim ) return ( victim.jjs_ratio or 0 ) > CurTime() end

-- Aiming at a target within 70 studs, marks them with a 7:3 ratio bar (a QTE finds the weak point).
-- TODO: the quick-time event; in Overtime there's no cooldown and several targets can be marked.
local RATIO = K.Target{ "Ratio Point", cooldown = 5, teleport = false, range = 70, noHit = true, startup = 0.15, endlag = 0.1, color = "gold",
	onEnd = function( ply )
		local t = ply:GetJActTarget()
		if IsValid( t ) then t.jjs_ratio = CurTime() + 8 end
	end }

K.Character( "salaryman", {
	name = "Salaryman",
	category = "complete",
	hp = 100,
	model = K.Model( "salaryman", "models/player/breen.mdl" ),
	color = Color( 240, 200, 120 ),

	passives = {
		{ "Blunt Cleaver", "Cosmetic: a cloth-wrapped cleaver and a dotted tie." },
		{ "Ratio Black Flash", "Uppercuts and final neutral M1s on a Ratio-marked target deal double damage and knockback. (TODO)" },
	},

	abilities = {
		-- Charges 25 studs forward spinning with melee i-frames, ending in a downward slash that knocks away.
		-- TODO special variant: on a Ratio-marked target (16) staggers their arm (lower block angle for 7s).
		[ 1 ] = K.Melee{ "Cleaving Whirlwind", cooldown = 16, startup = 0.35, damage = 12, lunge = 25, type = "melee", armor = "melee",
			ragdoll = { h = 55, v = 15 } },
		-- Kicks forward and follows with cursed energy pushing the target away with evadable stun (through block).
		-- TODO direction variant "Reverse Kick": walking backward, hits behind with unevadable stun.
		[ 2 ] = K.Melee{ "Severance Kick", cooldown = 14, startup = 0.35, damage = 12, reach = 9, type = "melee", blockDamage = 6,
			ragdoll = { h = 55, v = 12 }, tip = "DIRECTION" },
		-- A quick swing then a 34 stud flash step and a strike in the blink of an eye.
		-- Hold: 15 more studs and 14 damage. Air variant "Cross Cut": a dive (5) then an unblockable slice (4).
		[ 3 ] = K.Melee{ "Blunt Cut", cooldown = 16, startup = 0.45, damage = 9, lunge = 34, type = "melee", bypassRagdoll = true,
			ragdoll = { h = 40, v = 15 },
			hold = { time = 0.8, damage = 14, lunge = 49 },
			air = { damage = 9, hits = 2, interval = 0.3, block = "none", trueRag = true, lunge = 12, height = 18, ragdoll = { h = 10, v = -25 } } },
		-- Thrusts the tool into the opponent's stomach; both are stunned briefly, the user can cancel into Cleaving Whirlwind or Blunt Cut.
		-- TODO interruption/special variant: coughing up blood, longer stun (10 on interruption).
		[ 4 ] = K.Melee{ "Stabilize", cooldown = 12, startup = 0.35, damage = 6, reach = 9, type = "melee", bypassRagdoll = true, stun = 1.5, tip = "HIT" },
	},
	special = RATIO,

	awakening = {
		name = "Overtime",
		duration = 60,
		heal = 25,
		-- "How unfortunate. I'm now working overtime." Output boosted to 110-120%.
		-- TODO awakening variant: right after staggering with Stabilize, awakening rushes into a Black Flash (12, 16 with Ratio).
		-- TODO passive "Working Overtime": M1s 4 + 4 + 5 + 5 with destruction; ratioed final M1s are unblockable.
		abilities = {
			-- Four stages (each must hit a marked target to proceed): slash, Black Flash punch, hop slam, 60 stud swipe (35, x3 with Ratio).
			-- TODO: stages II-IV.
			[ 1 ] = K.Melee{ "Ratio Breaker", cooldown = 19, startup = 0.35, damage = 10, hits = 2, interval = 0.3, type = "melee", block = "none",
				trueRag = true, ragdoll = { h = 40, v = 20 }, tip = "1/4" },
			-- Slides 45 studs dragging the cleaver into a heated trail, then slices upward launching enemies (15, 23 with Ratio).
			-- Air variant "Erosion": floats then slams, grounding anyone in front (15).
			[ 2 ] = K.Melee{ "Sharpen", cooldown = 20, startup = 0.3, damage = 15, lunge = 45, type = "explosion", block = "none", bypassRagdoll = true,
				armor = "melee", ragdoll = { h = 30, v = 50 },
				air = { lunge = 5, ragdoll = { h = 5, v = -35 }, crater = 1000 } },
			-- Holsters the tool and catches a target by the neck (4): "Where are your allies?" then a gut punch (10).
			-- TODO: a pursuit and second lift (16).
			[ 3 ] = K.Grab{ "Interrogate", cooldown = 20, startup = 0.35, damage = 14, hits = 2, interval = 0.8, type = "melee", block = "none",
				bypassRagdoll = true, armor = "melee", ragdoll = { h = 65, v = 15 } },
			-- Leaps and slams to mark the environment's weak point (5), debris rises (7, 15 with Ratio).
			-- Follow-up: pressed again (within 8s), the debris crashes down on everything (+9 per debris, up to 40).
			[ 4 ] = K.AoE{ "Collapse", cooldown = 22, startup = 0.5, damage = 12, hits = 2, interval = 0.3, radius = 15, type = "explosion", block = "none",
				bypassRagdoll = true, armor = "melee", crater = 1400, ragdoll = { h = 10, v = 35 }, color = "brown", tip = "USE AGAIN",
				again = K.AoE{ "Collapse: Debris", window = 8, startup = 0.3, damage = 27, radius = 20, type = "explosion", block = "none",
					bypassRagdoll = true, trueRag = true, uninterruptible = true, crater = 1600, ragdoll = { h = 10, v = -30 }, color = "brown" } },
		},
		special = RATIO,
	},
} )

if SERVER then
	JJS.AddDamageMod( "ratio", function( victim, attacker, dmg, hit )
		if IsValid( attacker ) and attacker:IsPlayer() and attacker:GetJChar() == "salaryman" and hit.kit and Marked( victim ) then
			return 1.5
		end
	end )
end
