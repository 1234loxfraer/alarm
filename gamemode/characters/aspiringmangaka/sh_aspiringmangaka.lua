-- Aspiring Mangaka (Charles Bernard, base-only). Moves are JJS.Kit placeholders built from the JJS fandom wiki and
-- the dogslamloop frame data wiki; comments describe what the real move does.
--
-- Oracle: a 360 degree perfect block. Blocking within 0.05s of an impact (up to 0.15s with a full awakening bar,
-- +0.1s against a Clairvoyance-marked attacker, 0.25s max) evades the blockable attack with an afterimage; against a
-- marked attacker it also gives 5% awakening.
-- Clairvoyance marks an enemy for 25s: the user sees their future (see the special).

local K = JJS.Kit
local S = JJS.STUD

local function Marked( victim, by )
	return ( victim.jjs_clairvoyance or 0 ) > CurTime() and ( not by or victim.jjs_clairvoyanceBy == by )
end

local function Mark( ply, t )
	t.jjs_clairvoyance = CurTime() + 25
	t.jjs_clairvoyanceBy = ply
	t:SetNW2Float( "JJSPanel", CurTime() + 25 )
end

local MARK = K.Build( "aspiringmangaka", "mark", K.Target{ "Clairvoyance", teleport = false, noHit = true, range = 35, startup = 0.2, endlag = 0.1,
	awakenCost = 0.05, color = "white", onEnd = function( ply )
		local t = ply:GetJActTarget()
		if IsValid( t ) then Mark( ply, t ) end
	end } )

-- Despair's slowed flurry: the thrusts left after a whiff or a block by an unmarked target
local DESPAIR_SLOW = K.Build( "aspiringmangaka", "despairslow", K.Melee{ "Despair", startup = 0.22, hits = 5, interval = 0.26,
	hitDamage = { 3, 3, 3, 3, 1.1 }, hitBlock = { "normal", "normal", "normal", "normal", "none" }, reach = 10, width = 5, type = "melee",
	bypassRagdoll = true, ragdoll = { h = 60, v = 18 } } )

-- Prediction: a marked enemy in front, not ragdolled or mid-move, is forced into a side/back dash toward the user
local function Predict( ply )
	local t = K.AimTarget( ply, 60 * S, 0.8 )
	if not IsValid( t ) or not Marked( t, ply ) or t:GetJRagdolled() or JJS.IsBusy( t ) then return false end
	if SERVER then
		-- toward the user without going forward (from their point of view): left, right or back
		local to = JJS.Util.Flat( ply:GetPos() - t:GetPos() )
		local yaw = t:EyeAngles().y
		local side = JJS.Util.YawRight( yaw ):Dot( to )
		local dir = Vector( 0, side > 0 and 1 or -1, 0 )
		if JJS.Util.YawForward( yaw ):Dot( to ) < -0.5 then dir = Vector( -1, 0, 0 ) end
		t:GetTable().jjs_forceDash = dir
		t:SetJDashSideCD( CurTime() + JJS.Config.Dash.SideCooldown )
		JJS.Stun( t, 0.35 )
		JJS.Stun( ply, 0.25 )
		JJS.Util.Effect( "jjs_kit_cast", JJS.Util.BodyCenter( t ), nil, t, 0.8, K.COLOR_ID.white )
	end
	ply.jjs_predictCD = CurTime() + 4
	return true
end

K.Character( "aspiringmangaka", {
	name = "Aspiring Mangaka",
	category = "baseonly",
	hp = 85,
	model = K.Model( "aspiringmangaka", "models/player/kleiner.mdl" ),
	color = Color( 230, 230, 230 ),

	-- per-hit M1 frames { startup, recovery, block endlag } (dogslamloop)
	m1 = {
		Frames = { { 12, 8, 17 }, { 11, 9, 19 }, { 12, 8, 17 } },
	},

	passives = {
		{ "G-Warstaff", "Cosmetic: a staff whose trail reddens as the awakening bar fills." },
		{ "Oracle", "360 perfect block: blocking within 0.05-0.25s of impact evades with an afterimage." },
	},

	abilities = {
		-- Rapid thrusts of the staff (5 x 3) then an unblockable slash sending the enemy flying (1.1). Semi blockable; the
		-- thrusts slow down after a whiff or when blocked by an unmarked target (a marked one keeps them fast).
		[ 1 ] = K.Melee{ "Despair", cooldown = 16, startup = 0.3, hits = 6, interval = 0.14, hitDamage = { 3, 3, 3, 3, 3, 1.1 },
			hitBlock = { "normal", "normal", "normal", "normal", "normal", "none" }, reach = 10, width = 5, type = "melee", bypassRagdoll = true,
			ragdoll = { h = 60, v = 18 },
			onUse = function( ply ) ply.jjs_despairKeep = nil end,
			onContact = function( ply, v, p, r ) if r == "blocked" and Marked( v, ply ) then ply.jjs_despairKeep = true end end },
		-- Turns the staff backward to pierce whoever is behind (3), stares them down with i-frames, then spins them to the
		-- front and kicks them away with a long stun (4); the front dash comes off cooldown. Hit by melee during the
		-- windup, it counters: the thrust speeds up and loses its endlag on a miss.
		-- Airborne: hops up and slams the staff down, crushing targets beneath (12, unblockable); interrupting an attack
		-- slams them face-first (only visually ragdolled: stunned).
		[ 2 ] = K.Melee{ "Shut Up!", cooldown = 16, startup = 0.4, hits = 2, interval = 0.5, hitDamage = { 3, 4 }, reach = 9, behind = true,
			type = "melee", stun = 2, parry = { window = 0.4, counters = { melee = true }, stun = 0.8, iframes = 0.4 },
			onContact = function( ply, v, p, r ) if r == "hit" then JJS.IFrames( ply, 0.5 ) end end,
			onHit = function( ply ) ply:SetJDashFrontCD( 0 ) end,
			air = { kind = "aoe", hits = 1, hitDamage = false, damage = 12, radius = 9, behind = false, parry = false, type = "melee", block = "none",
				bypassRagdoll = true, ragdoll = { h = 5, v = -30 }, interrupt = { stun = 1.6 }, onHit = false,
				onUse = function( ply ) ply:SetLocalVelocity( Vector( 0, 0, 260 ) ) end } },
		-- Crosses the arms in a block stance (0.75s): a melee or bullet attacker is dodged with a spin and knocked down
		-- (9), keeping the move off cooldown; blockable explosions and swarms are only kept at bay.
		[ 3 ] = K.Counter{ "Eye Catching", cooldown = 14, window = 0.75, riposte = 9,
			counters = { melee = "counter", bullet = "counter", swarm = "evade", explosion = "evade" },
			onCounter = function( ply, attacker, hit, mode ) if mode == "counter" then JJS.SetCooldown( ply, 3, 0 ) end end },
		-- Twirls the spear, thrusts and dashes 20 studs; connecting: "Stop desecrating this work!" "Did you even read the
		-- original properly?!", pulls the staff out, punches, spins and kicks them away (6 + 6; unblockable, no evasive).
		-- A marked ragdolled target stays ragdolled 0.5s longer; a missed dash has 0.85s of endlag.
		[ 4 ] = K.Grab{ "Sacrilege", cooldown = 16, startup = 0.35, hits = 2, interval = 0.5, hitDamage = { 6, 6 }, lunge = 20, type = "melee",
			block = "none", bypassRagdoll = true, trueRag = true, whiffEndlag = 0.85, ragdoll = { h = 60, v = 20 },
			onHit = function( ply, v )
				if Marked( v, ply ) and v:GetJRagdolled() then JJS.Ragdoll.Apply( v, { time = 1.5, vel = K.Fwd( ply ) * 60 * S + Vector( 0, 0, 20 * S ) }, ply ) end
			end },
	},
	-- Hovering the cursor over an opponent within 35 studs marks their torso with a glowing manga panel for 25s (5%
	-- awakening, not required): forced dashes (below), +0.1s parry window against them (+5% awakening per parry),
	-- Despair keeps its speed on their block, Sacrilege ragdolls them longer, Foresight plays its cutscene.
	-- Prediction: while facing a marked enemy (not ragdolled or using a skill), the special forces them into a side or
	-- back dash toward the user every 4s: their camera locks, their side dash goes on cooldown, both are briefly
	-- stunned (the user 0.1s less).
	special = {
		name = "Clairvoyance",
		cooldown = 25,
		tip = function( ply )
			local t = K.AimTarget( ply, 60 * S, 0.8 )
			if IsValid( t ) and Marked( t, ply ) then return ( ply.jjs_predictCD or 0 ) > CurTime() and "PREDICTION..." or "PREDICTION" end
		end,
		Again = function( ply )
			if not ply:Alive() or ply:GetJRagdolled() or JJS.IsStunned( ply ) or JJS.IsBusy( ply ) then return false end
			local t = K.AimTarget( ply, 60 * S, 0.8 )
			if not IsValid( t ) or not Marked( t, ply ) then return false end
			if ( ply.jjs_predictCD or 0 ) > CurTime() then return true end
			Predict( ply )
			return true
		end,
		CanUse = function( ply, slot, mv ) return MARK.CanUse( ply, slot, mv ) end,
		Use = function( ply, mv, slot )
			JJS.SetCooldown( ply, slot, 25 )
			MARK.Use( ply, mv, 0 )
		end,
	},

	-- Despair: right after the first thrust, a whiff or an unmarked block slows the rest down
	Think = function( ply )
		local act = JJS.GetAction( ply )
		local ab = JJS.GetChar( ply ).abilities[ 1 ]
		if not act or act.kitParams ~= ab.move.p or ply.jjs_despairAt == ply:GetJActStart() then return end
		if JJS.ActionTime( ply ) < act.kitParams.startup + 0.02 then return end
		ply.jjs_despairAt = ply:GetJActStart()
		if ply.jjs_kitLanded or ply.jjs_despairKeep then return end
		JJS.StopAction( ply, true )
		DESPAIR_SLOW.Use( ply, nil, 0 )
	end,

	-- Foresight: holds the spear defensively for 1s. A melee attacker is blocked and smacked up and away with the handle
	-- (40; only them). A Clairvoyance-marked attacker, or one at 40 HP or less: a cutscene, the user pushes the staff
	-- against them, glimpses the future, chuckles, blocks every punch and pierces them (115, heals 21.25).
	-- 40% of the bar comes back on a hit or a miss, 80% if interrupted.
	awakenMove = K.Counter{ "Foresight", window = 1, riposte = 40, counters = { melee = "counter" },
		onUse = function( ply ) ply.jjs_fsCountered = nil end,
		onCounter = function( ply, attacker )
			ply.jjs_fsCountered = true
			if Marked( attacker ) or attacker:GetJHP() <= 40 then
				JJS.ApplyDamage( attacker, ply, 75, { type = JJS.DMG.SPECIAL } )
				JJS.Heal( ply, 21.25 )
			end
		end,
		onFinish = function( ply, p, interrupted )
			ply:SetJAwaken( ( interrupted and not ply.jjs_fsCountered ) and 0.8 or 0.4 )
		end },
} )

if SERVER then
	-- Oracle: 360 perfect block
	hook.Add( "JJS_PreHit", "JJS_Oracle", function( victim, hit )
		if victim:GetJChar() ~= "aspiringmangaka" or hit.block == "none" or not JJS.IsBlocking( victim ) then return end
		local a = hit.attacker
		local window = 0.05 + 0.1 * victim:GetJAwaken()
		local marked = IsValid( a ) and a:IsPlayer() and Marked( a, victim )
		if marked then window = window + 0.1 end
		if CurTime() - victim:GetJBlockStart() > math.min( window, 0.25 ) then return end
		JJS.IFrames( victim, 0.3 )
		JJS.Util.Effect( "jjs_kit_cast", JJS.Util.BodyCenter( victim ), nil, victim, 0.8, K.COLOR_ID.white )
		if marked then victim:SetJAwaken( math.min( 1, victim:GetJAwaken() + 0.05 ) ) end
		return "evaded"
	end )
end

hook.Add( "JJS_PlayerSpawned", "JJS_Clairvoyance", function( ply )
	ply.jjs_clairvoyance = nil
	ply:SetNW2Float( "JJSPanel", 0 )
end )
