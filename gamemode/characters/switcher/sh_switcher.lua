-- Switcher (Aoi Todo). Moves are JJS.Kit placeholders built from the JJS fandom wiki and the
-- dogslamloop frame data wiki; comments describe what the real move does.
--
-- Boogie Woogie (special): a clap swapping places and facing with a target within 60 studs. Blockable from all sides
-- at 35 studs or more; the clap gets faster the closer the target (nearly instant up close, on a ragdoll or when
-- feinting). Swapping during one of the user's moves feints it. Pebble Throw's pebble can be swapped with as well:
-- after a hit (Gut Punch) or a miss (Blazing Star, a glide during which Swift Kick and Brute Force have variants).

local K = JJS.Kit
local S = JJS.STUD
local U = JJS.Util

local RANGE, SAFE = 60, 35

-- Pebble Throw's pebble, while it flies or lingers on the floor (shared so both realms know)
local function PebbleUp( ply ) return ply:GetNW2Float( "JJSPebble", 0 ) > CurTime() end

-- Blazing Star glide or a landing roll: Swift Kick becomes Slide Kick
local function Sliding( ply ) return JJS.IsGliding( ply ) or ply:GetJMoveState() == JJS.MOVE_ROLL end

local function InBrutalImpact( ply )
	local act = JJS.GetAction( ply )
	return act and act.kitParams and act.kitParams.name == "Brutal Impact" or false
end

local function Refund( ply, amount )
	if amount and amount > 0 and not ply:GetJAwakened() then ply:SetJAwaken( math.min( 1, ply:GetJAwaken() + amount ) ) end
end

local function Pay( ply, amount )
	if ply:GetJAwakened() then return 0 end
	local paid = math.min( amount, ply:GetJAwaken() )
	ply:SetJAwaken( ply:GetJAwaken() - paid )
	return paid
end

------------------------------------------------------------------------------------------
-- Boogie Woogie
------------------------------------------------------------------------------------------

-- A ragdolled player is where their ragdoll lies
local function Where( ent )
	local rag = ent:GetJRagdolled() and ent:GetJRagEnt() or nil
	if IsValid( rag ) then return rag:GetPos() - Vector( 0, 0, 36 ), rag end
	return ent:GetPos()
end

local function Place( ent, pos, rag, yaw )
	JJS.Teleport( ent, pos )
	-- a ragdoll keeps its momentum (sliding on toward the user)
	if IsValid( rag ) then rag:SetPos( pos + Vector( 0, 0, 36 ) ) return end
	if yaw then ent:SetEyeAngles( Angle( 0, yaw, 0 ) ) end
end

-- Swaps the places and facing of two players
local function SwapPair( a, b )
	local pa, ra = Where( a )
	local pb, rb = Where( b )
	local ya, yb = a:EyeAngles().y, b:EyeAngles().y
	Place( a, pb, ra, yb )
	Place( b, pa, rb, ya )
	for _, e in ipairs( { a, b } ) do U.Effect( "jjs_kit_cast", U.BodyCenter( e ), nil, e, 1, K.COLOR_ID.orange ) end
end

-- The clap comes out faster the closer the target: nearly instant up close, on a ragdoll or when feinting
local function ClapTime( ply, t, feint )
	local st = 0.05
	if not feint and not t:GetJRagdolled() then
		local d = t:GetPos():Distance( ply:GetPos() ) / S
		if d >= 15 then st = Lerp( math.Clamp( ( d - 15 ) / ( RANGE - 15 ), 0, 1 ), 0.12, 0.4 ) end
	end
	-- awakened swaps are faster in general
	return ply:GetJAwakened() and st * 0.6 or st
end

-- Fakeout: an M1 or block before the clap cancels it, refunding the awakening (6s cooldown when it was feinting a move)
local function Fakeout( ply )
	local st = ply.jjs_bw
	if not st or st.swapped then return false end
	ply.jjs_bw = nil
	Refund( ply, st.cost )
	JJS.SetCooldown( ply, 5, st.feint and 6 or 0 )
	JJS.StopAction( ply, true )
	if SERVER then U.Effect( "jjs_kit_cast", U.BodyCenter( ply ), nil, ply, 0.5, K.COLOR_ID.white ) end
	return true
end

local function InDomain( ply ) return IsValid( JJS.Domain.Of( ply ) ) end

-- The clap (server): swaps with the target, or the target with another one under the cursor (target swap)
local function Clap( ply )
	local st = ply.jjs_bw
	local b = st.t1
	if not IsValid( b ) or not b:Alive() then return end
	local a = ply
	local t2 = K.AimTarget( ply, RANGE * S )
	if IsValid( t2 ) and t2 ~= b then a = t2 end
	-- no swapping during domain expansions
	if InDomain( a ) or InDomain( b ) then return end
	local dist = Where( a ):Distance( Where( b ) ) / S
	if dist > RANGE + 10 then return end
	-- blockable from all sides at 35 studs or more (for a target swap, the distance between both targets)
	local function Guards( v ) return v ~= ply and JJS.IsBlocking( v ) and not v:GetJRagdolled() end
	st.dist, st.rag = dist, b:GetJRagdolled()
	if dist >= SAFE and ( Guards( a ) or Guards( b ) ) then
		st.blocked = true
		JJS.SetCooldown( ply, 5, 3 )
		U.Effect( "jjs_block", U.BodyCenter( b ), nil, b, 1 )
		hook.Run( "JJS_Blocked", b, { attacker = ply, type = JJS.DMG.SPECIAL } )
	else
		SwapPair( a, b )
	end
	-- Perfect Swap: an M1 right after the clap (not when feinting)
	if not st.feint then st.perfect = CurTime() + 0.3 end
end

-- Perfect Swap: refunds the awakening and puts the special on 1s (within 35 studs) or 2s, twice as long if blocked,
-- none against a ragdolled target. The user glows blue.
local function Perfect( ply )
	local st = ply.jjs_bw
	if not st or not st.perfect or CurTime() > st.perfect then return end
	ply.jjs_bw = nil
	Refund( ply, st.cost )
	local cd = st.rag and 0 or ( ( st.dist or 0 ) < SAFE and 1 or 2 )
	if st.blocked then cd = cd * 2 end
	JJS.SetCooldown( ply, 5, cd )
	if SERVER then U.Effect( "jjs_kit_cast", U.BodyCenter( ply ), nil, ply, 1.2, K.COLOR_ID.blue ) end
	-- the clap's recovery gives way to the M1
	local act = JJS.GetAction( ply )
	if act and act.name == "switcher.bw" then JJS.StopAction( ply, true ) end
end

JJS.RegisterAction( "switcher.bw", {
	dur = 0.3,
	moveMult = 0.6,
	gesture = "gesture_becon",
	think = function( ply, t, mv )
		local st = ply.jjs_bw
		if st and not st.swapped and mv and mv:KeyPressed( JJS.IN.BLOCK ) then Fakeout( ply ) end
	end,
	events = { { function( ply ) return ply.jjs_bw and ply.jjs_bw.clap or 0.1 end, function( ply )
		local st = ply.jjs_bw
		if not st or st.swapped then return end
		st.swapped = true
		if SERVER then Clap( ply ) end
	end } },
	finish = function( ply )
		-- interrupted before the clap: nothing to fake out or perfect later
		local st = ply.jjs_bw
		if st and not st.swapped then ply.jjs_bw = nil end
	end,
} )

-- Blazing Star: swapping with a pebble that didn't hit anyone carries its momentum: a fast glide during which any move
-- can be used (Slide Kick, Brutal Impact). Pebble Throw goes on 7s (12s if it lingered), the special stays available.
local function BlazingStar( ply )
	local pos = ply:GetNW2Vector( "JJSPebblePos", ply:GetPos() )
	local vel = ply:GetNW2Vector( "JJSPebbleVel", K.Fwd( ply ) )
	local lingered = ply:GetNW2Bool( "JJSPebbleLinger", false )
	ply:SetNW2Float( "JJSPebble", 0 )
	if SERVER then
		if IsValid( ply.jjs_pebbleEnt ) then ply.jjs_pebbleEnt:Remove() end
		ply.jjs_pebbleEnt = nil
		local to = lingered and pos or pos - Vector( 0, 0, 40 )
		for _, up in ipairs( { 0, 24, 48 } ) do
			local p = to + Vector( 0, 0, up )
			if U.HullFits( ply, p ) then
				U.Effect( "jjs_kit_cast", U.BodyCenter( ply ), nil, ply, 0.8, K.COLOR_ID.cyan )
				JJS.Teleport( ply, p )
				break
			end
		end
	end
	Pay( ply, 0.06 )
	JJS.Glide( ply, U.Flat( vel ) * 55 * S, 1.1 )
	JJS.SetCooldown( ply, 3, lingered and 12 or 7 )
end

local BOOGIE = {
	name = "Boogie Woogie",
	cooldown = 6,
	tip = function( ply ) return PebbleUp( ply ) and "BLAZING STAR" or nil end,
	CanUse = function( ply )
		if not ply:Alive() or ply:GetJRagdolled() or JJS.IsStunned( ply ) or JJS.InEndlag( ply ) or JJS.IsBlocking( ply ) then return false end
		-- during another move: a feint (not while awakened)
		local act = JJS.GetAction( ply )
		if act and ( not act.kitParams or ply:GetJAwakened() ) then return false end
		if PebbleUp( ply ) then return true end
		return IsValid( K.AimTarget( ply, RANGE * S ) )
	end,
	Use = function( ply, mv, slot )
		-- Feint Swap: cancels the move being performed; before its first hit, it goes on half its cooldown (not
		-- Pebble Throw). A feint costs no awakening, can't be perfected and puts the special on 6s even if faked out.
		local act = JJS.GetAction( ply )
		local feint = act and act.kitParams and true or false
		if feint then
			local from, early = ply:GetJActVar(), JJS.ActionTime( ply ) < act.kitParams.startup
			JJS.StopAction( ply, true )
			if early and from >= 1 and from <= 4 and from ~= 3 then
				local cd = JJS.GetCooldown( ply, from ) - CurTime()
				if cd > 0 then JJS.SetCooldown( ply, from, cd / 2 ) end
			end
		end
		if PebbleUp( ply ) then BlazingStar( ply ) return end
		local t1 = K.AimTarget( ply, RANGE * S )
		if not IsValid( t1 ) then return end
		JJS.SetCooldown( ply, slot, 6 )
		-- 6% awakening (not required)
		local cost = feint and 0 or Pay( ply, 0.06 )
		local clap = ClapTime( ply, t1, feint )
		ply.jjs_bw = { t1 = t1, feint = feint, cost = cost, clap = clap }
		JJS.StartAction( ply, "switcher.bw", feint and 1 or 0, t1, clap + 0.12 )
	end,
}

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

	-- Fakeout (an M1 pressed before the clap) and Perfect Swap (right after it); the M1 still comes out
	M1Override = function( ply, mv )
		if not mv:KeyPressed( JJS.IN.M1 ) then return false end
		local act = JJS.GetAction( ply )
		if act and act.name ~= "switcher.bw" then return false end
		if not ( act and Fakeout( ply ) ) then Perfect( ply ) end
		return false
	end,

	abilities = {
		-- Spins twice into a kick (9, blockable, can't kill) forcing the target up in stun, then an unblockable grab (1)
		-- spinning them and tossing them where the user aims (5). 7.5s cooldown if feinted early.
		-- Variant "Slide Kick" (during Blazing Star or a roll): slides feet first, knocking enemies up (7.5), then turns
		-- around to kick them upward (7.5). Unblockable, hits ragdolls.
		[ 1 ] = K.Melee{ "Swift Kick", cooldown = 15, startup = 0.5, hits = 3, interval = 0.35, hitDamage = { 9, 1, 5 },
			hitBlock = { "normal", "none", "none" }, noKillHits = { [ 1 ] = true }, type = "melee", bypassRagdoll = true,
			ragdoll = { h = 55, v = 25 },
			cond = { test = Sliding, name = "Slide Kick", startup = 0.2, hits = 2, interval = 0.3, hitDamage = { 7.5, 7.5 },
				hitBlock = { "none", "none" }, block = "none", noKillHits = {}, lunge = 20, ragdoll = { h = 5, v = 40 },
				onUse = function( ply )
					JJS.Glide( ply, nil, 0 )
					if ply:GetJMoveState() == JJS.MOVE_ROLL then ply:SetJMoveState( JJS.MOVE_NONE ) end
				end } },
		-- A charged punch hurling opponents away with true ragdoll (17.5, unblockable). Out of reach, the wind gust hits instead
		-- (6, weaker knockback, evadable). 8.5s cooldown if feinted early.
		-- Variant "Brutal Impact" (during Blazing Star): a spinning roundhouse kick, red eyes glowing, with the same
		-- properties; pressed again as the kick is about to land, a Black Flash (24) blasting red sparks.
		[ 2 ] = K.Melee{ "Brute Force", cooldown = 17, startup = 0.7, damage = 17.5, reach = 9, type = "melee", block = "none",
			bypassRagdoll = true, trueRag = true, ragdoll = { h = 90, v = 25 },
			miss = K.AoE{ "Brute Force: Wind Gust", startup = 0, endlag = 0.3, damage = 6, radius = 8, offset = 16, type = "melee", block = "none",
				bypassRagdoll = true, ragdoll = { h = 40, v = 12 } },
			cond = { test = JJS.IsGliding, name = "Brutal Impact", startup = 0.55, comboFrom = 0.3, color = "red",
				onUse = function( ply ) JJS.Glide( ply, nil, 0 ) end },
			combo = { [ 2 ] = { free = true, need = InBrutalImpact, name = "Brutal Impact: Black Flash", startup = 0.1, damage = 24,
				color = "black", ragdoll = { h = 110, v = 30 }, crater = 1200 } } },
		-- Kicks up a pebble imbued with cursed energy and sends it 45 studs (4): half a second of stun, wakes ragdolled targets up.
		-- Flies over ragdolls within 20 studs; a miss drops and lingers on the floor for 1.5s (12s cooldown instead of 8).
		-- Special within 1.5s of a hit (blocked too): "Gut Punch", swaps with the pebble and punches the stunned enemy
		-- (7.25, blockable; 12s on Pebble Throw, 6s on Boogie Woogie; sets the 3rd M1). Special while the pebble flies
		-- or lingers without having hit: "Blazing Star" (see above).
		[ 3 ] = K.Projectile{ "Pebble Throw", cooldown = 8, startup = 0.35, damage = 4, range = 45, speed = 160, radius = 1.5, type = "bullet",
			bypassRagdoll = true, ragdollFrom = 20, stun = 0.5, color = "white", tip = "SPECIAL",
			onFly = function( ply, pos, ent )
				ply:SetNW2Float( "JJSPebble", CurTime() + 0.2 )
				ply:SetNW2Bool( "JJSPebbleLinger", false )
				ply:SetNW2Vector( "JJSPebblePos", pos )
				ply:SetNW2Vector( "JJSPebbleVel", ent.jjs.vel )
				ply.jjs_pebbleEnt = ent
			end,
			onExplode = function( ply, pos, hit )
				ply.jjs_pebbleEnt = nil
				if hit then ply:SetNW2Float( "JJSPebble", 0 ) return end
				local tr = util.TraceLine( { start = pos + Vector( 0, 0, 4 ), endpos = pos - Vector( 0, 0, 600 ), mask = MASK_SOLID_BRUSHONLY } )
				ply:SetNW2Float( "JJSPebble", CurTime() + 1.5 )
				ply:SetNW2Bool( "JJSPebbleLinger", true )
				ply:SetNW2Vector( "JJSPebblePos", tr.Hit and tr.HitPos or pos )
				JJS.SetCooldown( ply, 3, 12 )
			end,
			onHit = function( ply, victim )
				if victim:GetJRagdolled() then
					JJS.Ragdoll.Stop( victim, "pebble" )
					JJS.Stun( victim, 0.5 )
				end
			end,
			specialAfter = K.Target{ "Gut Punch", window = 1.5, cooldown = 6, range = 50, cone = 0.5, startup = 0.1, hits = 3, interval = 0.2,
				hitDamage = { 2.5, 2.5, 2.25 }, type = "melee", stun = 1.2,
				onUse = function( ply ) JJS.SetCooldown( ply, 3, 12 ) end,
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
			-- people). Total i-frames after the swap. With nothing countered, Yuji lunges forward anyway (70, unblockable).
			[ 4 ] = K.Counter{ "Brothers", cooldown = 45, window = 1.1, counters = { melee = "counter" }, riposte = 80, color = "black",
				miss = K.Rush{ "Brothers: Yuji's Lunge", startup = 0.15, travel = 30, time = 0.4, iframes = 0.8, damage = 70, type = "explosion",
					block = "none", bypassRagdoll = true, trueRag = true, ragdoll = { h = 90, v = 30 }, color = "black", crater = 1400 } },
		},
		special = BOOGIE,
	},
} )

-- Slide Kick also comes out of a landing roll
local sk = JJS.Characters.switcher.abilities[ 1 ]
local skCanUse = sk.CanUse
sk.CanUse = function( ply, slot, mv )
	if ply:GetJMoveState() == JJS.MOVE_ROLL and ply:Alive() and not ply:GetJRagdolled() and not JJS.IsStunned( ply ) and not JJS.IsBusy( ply ) then
		return true
	end
	return skCanUse( ply, slot, mv )
end
