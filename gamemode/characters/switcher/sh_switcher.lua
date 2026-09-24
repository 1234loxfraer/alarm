-- Switcher (Aoi Todo). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does.

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

-- A clap on a target within 60 studs swaps places and orientation with them. Costs 6% awakening.
-- TODO variants: item swap, fakeout (M1/block before the clap), perfect swap (M1 right after), target swap (two targets).
local BOOGIE = K.Target{ "Boogie Woogie", cooldown = 6, range = 60, teleport = false, noHit = true, startup = 0.15, endlag = 0.1,
	awakenCost = 0.06, color = "orange", onEnd = Swap }

K.Character( "switcher", {
	name = "Switcher",
	category = "complete",
	hp = 100,
	model = K.Model( "switcher", "models/player/odessa.mdl" ),
	color = Color( 255, 170, 60 ),

	abilities = {
		-- Spins twice into a powerful kick (9, can't kill) forcing the target up in stun, then grabs and tosses them (1 + 5).
		-- TODO variant "Slide Kick": during Blazing Star or a roll.
		[ 1 ] = K.Grab{ "Swift Kick", cooldown = 15, startup = 0.5, damage = 15, hits = 3, interval = 0.35, type = "melee", blockDamage = 7.5,
			bypassRagdoll = true, ragdoll = { h = 55, v = 25 } },
		-- A charged punch hurling opponents away; out of reach, the shockwave hits instead (6, evadable).
		-- TODO variant "Brutal Impact" (during Blazing Star) and its Black Flash (24).
		[ 2 ] = K.Melee{ "Brute Force", cooldown = 17, startup = 0.7, damage = 17.5, reach = 9, type = "melee", block = "none",
			bypassRagdoll = true, trueRag = true, ragdoll = { h = 90, v = 25 } },
		-- Kicks up a pebble imbued with cursed energy and sends it 45 studs; a hit stuns for half a second.
		-- TODO special variants: "Gut Punch" (swap with the pebble after it hits) and "Blazing Star" (glide on a missed pebble).
		[ 3 ] = K.Projectile{ "Pebble Throw", cooldown = 12, startup = 0.4, damage = 4, range = 45, speed = 160, radius = 1.5, type = "bullet",
			stun = 0.5, color = "white", tip = "SPECIAL" },
		-- A charged uppercut launching the target with true ragdoll (5), then a dive crushing them (7).
		[ 4 ] = K.Melee{ "Elbow Drop", cooldown = 16, startup = 0.45, damage = 12, hits = 2, interval = 0.7, type = "melee", block = "none",
			trueRag = true, ragdoll = { h = 10, v = -30 }, crater = 900 },
	},
	special = BOOGIE,

	awakening = {
		name = "False Memories",
		duration = 60,
		heal = 20,
		-- The locket opens on their brother and idol; the idol appears beside them (only in their imagination).
		abilities = {
			-- A large step with an upward swipe; a launched enemy is kicked down by the idol (15 + 15).
			[ 1 ] = K.Melee{ "Idol's Debut", cooldown = 17, startup = 0.4, damage = 30, hits = 2, interval = 0.7, type = "melee", block = "none",
				iframes = 1, ragdoll = { h = 10, v = -30 } },
			-- Lunges ~40 studs with total i-frames; anyone met is pummelled by the user and idol (27.4) then uptilted (15).
			[ 2 ] = K.Grab{ "Climax Jumping", cooldown = 22, startup = 0.4, damage = 42.4, hits = 8, interval = 0.2, lunge = 40, iframes = 0.8,
				type = "melee", block = "none", trueRag = true, ragdoll = { h = 10, v = 60 } },
			-- Three heavy forward punches (7 each); the last ragdolls away.
			[ 3 ] = K.Melee{ "Dreams", cooldown = 10, startup = 0.35, damage = 21, hits = 3, interval = 0.3, type = "melee", block = "none",
				bypassRagdoll = true, trueRag = true, ragdoll = { h = 60, v = 20 }, color = "pink" },
			-- High-five stance: a melee attacker is swapped with Yuji, who lands a devastating Black Flash (80).
			-- TODO variant: with nothing countered, Yuji lunges forward anyway (70).
			[ 4 ] = K.Counter{ "Brothers", cooldown = 45, window = 1.1, counters = { melee = "counter" }, riposte = 80, color = "black" },
		},
		special = BOOGIE,
	},
} )
