-- Switcher (Aoi Todo). Moves are JJS.Kit placeholders built from the JJS fandom wiki and the
-- dogslamloop frame data wiki; comments describe what the real move does.

local K = JJS.Kit

-- Swap places and facing with the move's target
local function Swap( ply )
	local t = ply:GetJActTarget()
	if not IsValid( t ) or not t:Alive() then return end
	local a, b = ply:GetPos(), t:GetPos()
	local ya, yb = ply:EyeAngles().y, t:EyeAngles().y
	if t:GetJRagdolled() then
		local rag = t:GetJRagEnt()
		if IsValid( rag ) then JJS.Ragdoll.SetVelocity( rag, vector_origin ) end
	end
	ply:SetPos( b )
	t:SetPos( a )
	ply:SetEyeAngles( Angle( 0, yb, 0 ) )
	t:SetEyeAngles( Angle( 0, ya, 0 ) )
	JJS.Util.Effect( "jjs_kit_cast", JJS.Util.BodyCenter( ply ), nil, ply, 1, JJS.Kit.COLOR_ID.orange )
end

-- A clap on a target within 60 studs swaps places and orientation with them (6s, 3s if blocked). Costs 6% awakening.
-- Feint swap: clapping during one of the user's moves cancels it and halves that move's cooldown.
-- TODO: fakeout (M1/block before the clap refunds everything), perfect swap (M1 right after: 1-2s cooldown and no cost),
-- item swaps (half cooldown), target swaps (two targets under the cursor), blockable at long range.
local BOOGIE = K.Build( "switcher", "boogie", K.Target{ "Boogie Woogie", cooldown = 6, range = 60, teleport = false, noHit = true, startup = 0.15,
	endlag = 0.1, awakenCost = 0.06, color = "orange", onEnd = Swap } )
local canSwap = BOOGIE.CanUse
BOOGIE.CanUse = function( ply, slot, mv )
	local act = JJS.GetAction( ply )
	if act and act.kitParams and JJS.ActionTime( ply ) < act.kitParams.startup and not ply:GetJRagdolled() and not JJS.IsStunned( ply )
		and IsValid( K.AimTarget( ply, 60 * JJS.STUD ) ) then
		return true
	end
	return canSwap( ply, slot, mv )
end
local useSwap = BOOGIE.Use
BOOGIE.Use = function( ply, mv, slot )
	local act = JJS.GetAction( ply )
	if act and act.kitParams then
		local from = ply:GetJActVar()
		JJS.StopAction( ply, true )
		if from >= 1 and from <= 4 then
			local cd = JJS.GetCooldown( ply, from ) - CurTime()
			if cd > 0 then JJS.SetCooldown( ply, from, cd / 2 ) end
		end
	end
	useSwap( ply, mv, slot )
end

K.Character( "switcher", {
	name = "Switcher",
	category = "complete",
	hp = 100,
	model = K.Model( "switcher", "models/player/odessa.mdl" ),
	color = Color( 255, 170, 60 ),

	-- per-hit M1 frames { startup, recovery, block endlag } (dogslamloop)
	m1 = {
		Frames = { { 14, 5, 11 }, { 14, 5, 11 }, { 14, 5, 11 } },
	},

	abilities = {
		-- Spins twice into a kick (9, blockable, can't kill) forcing the target up in stun, then an unblockable grab (1)
		-- spinning them and tossing them where the user aims (5). 7.5s cooldown if feinted early.
		-- TODO variant "Slide Kick" (during Blazing Star or a roll): a feet-first slide knocking enemies up (7.5 + 7.5).
		[ 1 ] = K.Melee{ "Swift Kick", cooldown = 15, startup = 0.5, hits = 3, interval = 0.35, hitDamage = { 9, 1, 5 },
			hitBlock = { "normal", "none", "none" }, type = "melee", bypassRagdoll = true, ragdoll = { h = 55, v = 25 } },
		-- A charged punch hurling opponents away with true ragdoll (17.5, unblockable). Out of reach, the wind gust hits instead
		-- (6, weaker knockback, evadable). 8.5s cooldown if feinted early.
		-- TODO variant "Brutal Impact" (during Blazing Star): a roundhouse kick; pressed again, a Black Flash (24).
		[ 2 ] = K.Melee{ "Brute Force", cooldown = 17, startup = 0.7, damage = 17.5, reach = 9, type = "melee", block = "none",
			bypassRagdoll = true, trueRag = true, ragdoll = { h = 90, v = 25 },
			miss = K.AoE{ "Brute Force: Wind Gust", startup = 0, endlag = 0.3, damage = 6, radius = 8, offset = 16, type = "melee", block = "none",
				bypassRagdoll = true, ragdoll = { h = 40, v = 12 } } },
		-- Kicks up a pebble imbued with cursed energy and sends it 45 studs (4): half a second of stun, wakes ragdolled targets up.
		-- Can't hit ragdolls within 20 studs; a miss lingers on the floor (12s cooldown instead of 8).
		-- Special within 1.5s of a hit: "Gut Punch", swaps with the pebble and punches the stunned enemy (4 + 7.25, blockable;
		-- sets the 3rd M1; Boogie Woogie goes on 6s). TODO "Blazing Star" (special after a miss): glide on the pebble.
		[ 3 ] = K.Projectile{ "Pebble Throw", cooldown = 8, startup = 0.35, damage = 4, range = 45, speed = 160, radius = 1.5, type = "bullet",
			bypassRagdoll = true, stun = 0.5, color = "white", tip = "SPECIAL",
			specialAfter = K.Target{ "Gut Punch", window = 1.5, cooldown = 6, range = 50, cone = 0.5, startup = 0.1, hits = 3, interval = 0.2,
				hitDamage = { 4, 4, 3.25 }, type = "melee", stun = 1.2,
				onHit = function( ply ) ply:SetJM1Index( 2 ) ply:SetJM1LastEnd( CurTime() ) end } },
		-- A charged uppercut launching the target with true ragdoll (5), then a dive crushing them into the floor (7, bounces).
		-- Unblockable, can't hit ragdolls. 8s cooldown if feinted early.
		[ 4 ] = K.Melee{ "Elbow Drop", cooldown = 16, startup = 0.45, hits = 2, interval = 0.7, hitDamage = { 5, 7 }, type = "melee", block = "none",
			trueRag = true, ragdoll = { h = 10, v = -30 }, crater = 900 },
	},
	special = BOOGIE,

	awakening = {
		name = "False Memories",
		duration = 60,
		heal = 20,
		-- The locket opens on their brother and idol; the idol appears beside them (only in their imagination; others see a nosebleed).
		abilities = {
			-- A large step with an upward swipe (15); a launched enemy is kicked down by the idol (15), total i-frames meanwhile.
			[ 1 ] = K.Melee{ "Idol's Debut", cooldown = 17, startup = 0.4, hits = 2, interval = 0.7, hitDamage = { 15, 15 }, type = "melee", block = "none",
				iframes = 1, ragdoll = { h = 10, v = -30 } },
			-- Lunges ~40 studs with total i-frames; anyone met is pummelled by the user and idol (1 + 27.4) then uptilted (15).
			[ 2 ] = K.Rush{ "Climax Jumping", cooldown = 22, startup = 0.4, travel = 40, time = 0.45, iframes = 0.85, hits = 8, interval = 0.2,
				hitDamage = { 1, 4.57, 4.57, 4.57, 4.57, 4.57, 4.55, 15 }, type = "melee", block = "none", trueRag = true, ragdoll = { h = 10, v = 60 } },
			-- Three heavy forward punches (7 each); the first two knock back slightly, the last ragdolls away.
			[ 3 ] = K.Melee{ "Dreams", cooldown = 10, startup = 0.35, damage = 21, hits = 3, interval = 0.3, type = "melee", block = "none",
				bypassRagdoll = true, trueRag = true, ragdoll = { h = 60, v = 20 }, color = "pink" },
			-- High-five stance (1.1s): a melee attacker is swapped with Yuji, who lands a devastating Black Flash (80, less with more
			-- people). Total i-frames after the swap.
			-- TODO variant: with nothing countered, Yuji lunges forward anyway (70).
			[ 4 ] = K.Counter{ "Brothers", cooldown = 45, window = 1.1, counters = { melee = "counter" }, riposte = 80, color = "black" },
		},
		special = BOOGIE,
	},
} )
