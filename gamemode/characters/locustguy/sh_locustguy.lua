-- Locust Guy (base-only). Moves are JJS.Kit placeholders built from the JJS fandom wiki and the
-- dogslamloop frame data wiki; comments describe what the real move does.
--
-- Air combos: Fluttering Pounce aimed at an airborne ragdolled enemy within 80 studs flies to them and suspends both
-- in the air, waking the enemy up with stun; the M1 string goes to the 3rd M1 and the user attacks freely. The air
-- combo ends if the user doesn't act within a second, or once the enemy is ragdolled.

local K = JJS.Kit
local S = JJS.STUD

-- an airborne ragdolled enemy under the cursor within 80 studs
local function AirTarget( ply )
	local t = K.AimTarget( ply, 80 * S, 0.85 )
	if not IsValid( t ) or not t:GetJRagdolled() then return end
	local rag = t:GetJRagEnt()
	local pos = IsValid( rag ) and rag:GetPos() or t:GetPos()
	local tr = util.TraceLine( { start = pos, endpos = pos - Vector( 0, 0, 4 * S ), mask = MASK_SOLID_BRUSHONLY } )
	if tr.Hit then return end
	return t
end

-- Fluttering Pounce's air combo: fly to them, both hover, they wake up stunned
local AIR_COMBO = K.Build( "locustguy", "aircombo", K.Target{ "Fluttering Pounce: Air Combo", range = 80, cone = 0.85, noHit = true, startup = 0.15,
	endlag = 0.05, awakenCost = 0.06, color = "pink",
	onEnd = function( ply )
		local t = ply:GetJActTarget()
		if not IsValid( t ) or not t:Alive() then return end
		if t:GetJRagdolled() then JJS.Ragdoll.Stop( t, "aircombo" ) end
		JJS.Stun( t, 1 )
		JJS.Hover( ply, 1 )
		JJS.Hover( t, 1 )
		ply.jjs_airCombo = t
		ply:SetJM1Index( 2 )
		ply:SetJM1LastEnd( CurTime() )
	end } )

local FLIGHT = K.Build( "locustguy", "flight", K.Mobility{ "Fluttering Pounce", cooldown = 16, startup = 0.1, travel = 27.5, time = 0.45, dir = "aim",
	m1Cancel = true } )

-- Crushing Jaws / Wing Throw let the air combo start with the special on cooldown
local function FreePounce( ply ) ply.jjs_lgFree = CurTime() end

K.Character( "locustguy", {
	name = "Locust Guy",
	category = "baseonly",
	hp = 90,
	model = K.Model( "locustguy", "models/player/zombie_fast.mdl" ),
	color = Color( 150, 190, 60 ),

	-- per-hit M1 frames { startup, recovery, block endlag } (dogslamloop)
	m1 = {
		Frames = { { 14, 5, 11 }, { 14, 5, 11 }, { 14, 5, 11 } },
	},

	passives = {
		{ "Naturally Selected", "Cosmetic: an extra pair of arms, antennas and wings (flapping in moves and front dashes)." },
		{ "Air Combo", "Fluttering Pounce on an airborne ragdolled enemy suspends both in the air for a combo." },
	},

	abilities = {
		-- Crouches, then charges into a barrage of punches that ragdolls the target (airborne ragdolls only) then leaves
		-- them stunned in place (14.2 if all land). Keeps the M1 count; doesn't move the user during air combos or once
		-- the barrage is blocked.
		[ 1 ] = K.Melee{ "Clever", cooldown = 15, startup = 0.4, damage = 14.2, hits = 6, interval = 0.15, lunge = 15, type = "melee", stun = 1.2 },
		-- Winds the head back and spits a ball of dark mucus up to 60 studs (8, unblockable): ragdolls, and the target's
		-- attacks deal 15% less for ~13s (stacking).
		[ 2 ] = K.Projectile{ "Black Mucus", cooldown = 17, startup = 0.5, damage = 8, range = 60, speed = 110, radius = 3, type = "bullet", block = "none",
			bypassRagdoll = true, ragdoll = { h = 35, v = 15 }, color = "black",
			onHit = function( ply, victim )
				local m = victim.jjs_mucus
				victim.jjs_mucus = { t = CurTime() + 13, n = ( m and m.t > CurTime() and m.n or 0 ) + 1 }
			end },
		-- Three biting head swings (4 each; only the first is blockable; missing it slows the rest of the windup by 40%),
		-- melee armor. If the third connects: melee then total i-frames, the target is dragged, thrown up (the throw hits
		-- anyone close, 3 with true ragdoll) and slammed head first, the shockwave bouncing them up and away (4).
		[ 3 ] = K.Melee{ "Crushing Jaws", cooldown = 17, startup = 0.3, hits = 4, interval = 0.3, hitDamage = { 4, 4, 4, 4 },
			hitBlock = { "normal", "none", "none", "none" }, type = "melee", armor = "melee", ragdoll = { h = 35, v = 40 }, crater = 900,
			onContact = function( ply, v, p, r ) if r == "hit" then JJS.IFrames( ply, 0.7 ) end end,
			onFinish = FreePounce },
		-- Winds an arm back and grabs (3), gaining free flight and melee i-frames, then tosses the target away (5). The grab
		-- holds even if they cancel the ragdoll; blocked, the user doesn't move.
		[ 4 ] = K.Grab{ "Wing Throw", cooldown = 15, startup = 0.35, hits = 2, interval = 0.6, hitDamage = { 3, 5 }, type = "melee", bypassRagdoll = true,
			meleeIFrames = 0.95, ragdoll = { h = 70, v = 30 }, onFinish = FreePounce },
	},
	-- Spreads the wings and flies ~27.5 studs where the user faces, carrying momentum; an M1 cancels the flight.
	-- Aimed at an airborne ragdolled enemy within 80 studs: the air combo (6% awakening; right after Crushing Jaws or
	-- Wing Throw it doesn't need the special off cooldown, but always puts it on cooldown).
	special = {
		name = "Fluttering Pounce",
		cooldown = 16,
		tip = function( ply ) if IsValid( AirTarget( ply ) ) then return "AIR COMBO" end end,
		Again = function( ply, mv )
			if not IsValid( AirTarget( ply ) ) or not ply:Alive() or ply:GetJRagdolled() or JJS.IsStunned( ply ) then return false end
			local free = CurTime() - ( ply.jjs_lgFree or -9 ) < 2.5
			if JJS.GetCooldown( ply, 5 ) > CurTime() and not free then return false end
			if JJS.IsBusy( ply ) and not free then return false end
			if JJS.IsBusy( ply ) then JJS.StopAction( ply, true ) end
			ply.jjs_lgFree = nil
			JJS.SetCooldown( ply, 5, 16 )
			AIR_COMBO.Use( ply, mv, 0 )
			return true
		end,
		CanUse = function( ply, slot, mv ) return FLIGHT.CanUse( ply, slot, mv ) end,
		Use = function( ply, mv, slot ) FLIGHT.Use( ply, mv, slot ) end,
	},

	-- "I win!" The insect abdomen stings the area in front (uncounterable, total i-frames): poison drains 9/s for 10s
	-- (90). Landed, heals 25; missed, half the awakening bar comes back.
	awakenMove = K.Melee{ "Directed Poison", startup = 0.8, damage = 0, lunge = 10, type = "special", block = "none", bypassRagdoll = true,
		uninterruptible = true, iframes = 1.1, heal = 25, stun = 1, color = "green",
		onHit = function( ply, victim ) victim.jjs_poison = { by = ply, left = 10, dps = 9 } end,
		onFinish = function( ply ) if not ply.jjs_kitLanded then ply:SetJAwaken( 0.5 ) end end },
} )

if SERVER then
	-- Black Mucus: each stack weakens the afflicted player's attacks by 15%
	JJS.AddDamageMod( "blackmucus", function( victim, attacker )
		local m = IsValid( attacker ) and attacker.jjs_mucus
		if m and m.t > CurTime() then return math.max( 0.4, 1 - 0.15 * m.n ) end
	end )

	-- air combos: every action keeps both in the air for another second; a ragdoll ends it
	local function Extend( ply )
		local t = ply.jjs_airCombo
		if not IsValid( t ) then return end
		JJS.Hover( ply, 1 )
		JJS.Hover( t, 1 )
	end
	hook.Add( "JJS_M1", "JJS_AirCombo", function( ply ) Extend( ply ) end )
	hook.Add( "JJS_Cooldown", "JJS_AirCombo", function( ply ) Extend( ply ) end )

	hook.Add( "Tick", "JJS_LocustGuy", function()
		local dt = engine.TickInterval()
		for _, ply in ipairs( player.GetAll() ) do
			local t = ply.jjs_airCombo
			if t and ( not IsValid( t ) or not t:Alive() or t:GetJRagdolled() or not JJS.IsHovering( ply ) ) then
				ply.jjs_airCombo = nil
				JJS.Hover( ply, 0 )
				if IsValid( t ) then JJS.Hover( t, 0 ) end
			end
			-- Directed Poison
			local p = ply.jjs_poison
			if p then
				if not ply:Alive() or p.left <= 0 then
					ply.jjs_poison = nil
				else
					p.left = p.left - dt
					JJS.ApplyDamage( ply, IsValid( p.by ) and p.by or nil, p.dps * dt, { type = JJS.DMG.EXPLOSION } )
				end
			end
		end
	end )
end

hook.Add( "JJS_PlayerSpawned", "JJS_LocustGuy", function( ply )
	ply.jjs_poison = nil
	ply.jjs_mucus = nil
	ply.jjs_airCombo = nil
	JJS.Hover( ply, 0 )
end )
