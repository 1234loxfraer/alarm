-- Salaryman. Generated from the JJS wiki; every move is a JJS.Kit placeholder.
-- Comments summarise what the real move does (see the wiki page for details).

local K = JJS.Kit

K.Character( "salaryman", {
	name = "Salaryman",
	category = "complete",
	hp = 100,
	model = K.Model( "salaryman", "models/player/breen.mdl" ),
	color = Color( 240, 200, 120 ),

	passives = {
		{ "Blunt Cleaver", "The user wields a cleaver with a blade wrapped in white black-dotted cloth, while also wearing a yellow tie with black dots." },
		{ "Ratio Black Flash", "Landing the final neutral M1 or an uppercut on a marked enemy will enhance it with a precise Black Flash, increasing its damage and knockback." },
	},

	abilities = {
		-- The user charges 25 studs forwards while spinning while gaining melee i-frames, finishing the charge with a downwards slash across the opponent, knocking them away.
		-- TODO special variant: The swing will get enhanced on a Ratio-marked target, dealing more damage and gaining the ability to lower their block angle for 7...
		[ 1 ] = K.Melee{ "Cleaving Whirlwind", cooldown = 16, damage = 12, type = "melee", tip = "SPECIAL" },
		-- The user extends their right foot to kick forwards, following up with cursed energy on contact with a target to push them away with evadable stun (or ragdoll).
		-- TODO direction: backward variant "Reverse Kick": By walking backwards before using the move, the user will instead swing their left leg in the opposite direction to hit enemies behind...
		-- TODO variant "Reverse Kick": When using Reverse Kick, interrupting any opponent's action except blocking will stun the target in place.
		[ 2 ] = K.Melee{ "Severance Kick", cooldown = 14, damage = 12, type = "melee", blockDamage = 6, ragdoll = { h = 45, v = 18 }, tip = "DIRECTION" },
		-- The user charges up a quick swing before flash-stepping 34 studs forwards and swinging their tool in the blink of an eye.
		-- TODO special variant: The user's attack will get enhanced on a Ratio-marked target, dealing more damage and gaining the ability to disable the target's dashes...
		-- Air variant "Cross Cut": If the user was instead airborne while using this move, they will perform a downwards dive with their weapon while momentarily gaining...
		-- TODO air special variant "Cross Cut": The user's dive will get enhanced on a Ratio-marked target, dealing more damage and gaining the ability to disable the target's dashes...
		-- TODO air special variant "Cross Cut": If the enemy was Ratio-marked by after the dive hits, then the slash will get enhanced instead, dealing more damage, ragdolling the...
		[ 3 ] = K.Melee{ "Blunt Cut", cooldown = 16, damage = 9, type = "melee", bypassRagdoll = true, tip = "SPECIAL", air = { hits = 2, blockDamage = 4.5, trueRag = true, ragdoll = true } },
		-- Pulling their arm back, the user thrusts their tool forwards to hit the opponent's stomach before twirling it.
		-- TODO interruption/special variant: Interrupting an enemy or hitting a Ratio-marked target with this move will cause them to cough up blood, stunning the user and enemy...
		[ 4 ] = K.Melee{ "Stabilize", cooldown = 12, damage = 6, type = "melee", bypassRagdoll = true, tip = "HIT" },
	},
	-- When aiming at a target within 70 studs, the user is able to activate their Ratio technique and mark the target with a bar divided into tenths, starting a quick-time...
	special = K.Mobility{ "Ratio Point", cooldown = 5, block = "none", bypassRagdoll = true, uninterruptible = true, travel = 70 },

	awakening = {
		name = "Overtime",
		duration = 60,
		heal = 25,
		-- The user sighs, putting their cursed tool on their back and grabbing their tie and wrapping it tightly around their right fist as they state: "How unfortunate.
		-- TODO cosmetic "Wall of Stone": When blocking, the user will hold back from using their cursed tool to defend themselves, remaining wide open.
		-- TODO passive "Working Overtime": Due to their binding vow, the user is able to output more cursed energy into their blows.
		-- TODO passive "Ratio Black Flash": Same as base, except the final M1 will be strengthened in general, and will even become unblockable.
		abilities = {
			-- To set the record of the most consecutive uses of Black Flash, this move progresses through four distinct stages before going on cooldown, each stage needing to hit a...
			[ 1 ] = K.Melee{ "Ratio Breaker I", cooldown = 19, damage = 10, hits = 2, type = "melee", block = "none", trueRag = true, ragdoll = { h = 45, v = 18 } },
			-- The user slides forwards by 45 studs while dragging their cursed tool on the ground to sharpen it, creating a heated trail from its tip before slicing upwards to...
			-- Air variant "Erosion": If the user was airborne, they will float in the air for a second to prepare a overhead slam with their cleaver, grounding anyone...
			-- TODO air variant "Erosion": While preparing their slam, a long Ratio bar will appear before the user, reminiscent of Ratio Point's bar but with a circle following...
			[ 2 ] = K.AoE{ "Sharpen", cooldown = 20, damage = 15, type = "explosion", block = "none", bypassRagdoll = true, armor = "melee", radius = 45, color = "orange", air = {} },
			-- The user holsters their tool then attempts to catch a target in front of them.
			[ 3 ] = K.Melee{ "Interrogate", cooldown = 20, damage = 4, type = "melee", block = "none", bypassRagdoll = true, armor = "melee" },
			-- The user, planning on using an extension of their cursed technique, instantly leaps into the air while winding up a heavy slam to mark the environment itself with a...
			-- Follow-up: Pressing the move again, even during stun, will force the cursed debris to fall downwards and crush everything in the area.
			[ 4 ] = K.AoE{ "Collapse", cooldown = 22, damage = 5, type = "explosion", block = "none", bypassRagdoll = true, armor = "melee", ragdoll = { h = 8, v = 60 }, color = "orange", tip = "USE AGAIN", again = K.AoE{ "Collapse", damage = 9, type = "explosion", block = "none", bypassRagdoll = true, trueRag = true, uninterruptible = true, color = "orange" } },
		},
		-- Same as base, but has no cooldown and can be used to mark more than one target.
		special = K.Buff{ "Ratio Point", block = "none", bypassRagdoll = true, uninterruptible = true },
	},
} )
