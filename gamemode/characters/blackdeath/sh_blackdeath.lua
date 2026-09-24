-- Black Death (Kurourushi, base-only). Moves are JJS.Kit placeholders built from the JJS fandom wiki and the
-- dogslamloop frame data wiki; comments describe what the real move does.
--
-- Injury (Festering Life Sword): stacks on the target (a meter at their side); each stack drains 3 HP over 2 ticks
-- (1.5/s, 1/s while stalled by Chokehold). At 7 stacks the sword's barrel implants eggs that hatch at once (14) and
-- empty the meter. Sources: the 1st M1 (2) and 3rd M1 (1), Festering Strikes (1 per swing, through block), Detach (2,
-- 1 blocked), Reattach (2 on the impaled target, 1 if Detach was blocked; 3 on those in its way, 2 blocked),
-- Chokehold armed (2), the Earthen Insects killed by an enemy (1).
-- Unarmed (the sword stuck in someone after Detach): M1s 3 + 3 + 4 + 4 with no injury, Festering Strikes becomes
-- Fierce Strikes and Chokehold a heavy punch.

local K = JJS.Kit
local S = JJS.STUD

local function Injury( v ) return v:GetNW2Int( "JJSInjury", 0 ) end
local function AddInjury( v, n, by )
	if not IsValid( v ) or not v:IsPlayer() or not v:Alive() or n <= 0 then return end
	local x = Injury( v ) + n
	if x >= 7 then
		v:SetNW2Int( "JJSInjury", 0 )
		v.jjs_injDrain = 0
		JJS.ApplyDamage( v, by, 14, { type = JJS.DMG.SPECIAL } )
		JJS.Util.Effect( "jjs_kit_burst", JJS.Util.BodyCenter( v ), Vector( 0, 0, 1 ), v, 30, K.COLOR_ID.brown )
		return
	end
	v:SetNW2Int( "JJSInjury", x )
	v.jjs_injBy = by
end
local function Injure( n, blocked )
	return function( ply, v, p, r ) AddInjury( v, r == "blocked" and ( blocked or n ) or n, ply ) end
end

local function SwordOut( ply ) return ply:GetNW2Bool( "JJSSwordOut", false ) end
local function Unarmed( ply ) return SwordOut( ply ) end

-- Detach landed: the sword stays in the target for 8s; not reattached by then, the move is disabled 6s more
local function Impale( ply, v, blocked )
	ply:SetNW2Bool( "JJSSwordOut", true )
	ply:SetNW2Entity( "JJSSwordIn", v )
	ply.jjs_detachBlocked = blocked
	ply.jjs_detachEnd = CurTime() + 8
	JJS.SetCooldown( ply, 2, 0 )
end
local function Retrieve( ply )
	ply:SetNW2Bool( "JJSSwordOut", false )
	ply:SetNW2Entity( "JJSSwordIn", NULL )
	ply.jjs_detachEnd = nil
end

-- Reattach: pulls the arm back with whoever is impaled (no stun, but no abilities meanwhile); those in the way are
-- hit (2), stunned and dragged along
local REATTACH = K.Params( K.Melee{ "Reattach", damage = 2, type = "bullet", block = "normal", bypassRagdoll = true, stun = 0.8,
	ragdoll = false } )
local function Reattach( ply )
	local v = ply:GetNW2Entity( "JJSSwordIn" )
	if SERVER and IsValid( v ) and v:Alive() then
		local from, to = JJS.Util.BodyCenter( v ), JJS.Util.BodyCenter( ply )
		local dir = ( to - from ):GetNormalized()
		for _, h in ipairs( JJS.Util.PlayersOnRay( from, dir, from:Distance( to ), 3 * S, { ignore = ply, ragdolled = true } ) ) do
			if h.ply ~= v then
				local r = K.Apply( ply, REATTACH, h.ply, 1, from )
				AddInjury( h.ply, r == "blocked" and 2 or 3, ply )
				h.ply:SetLocalVelocity( dir * 40 * S )
			end
		end
		AddInjury( v, ply.jjs_detachBlocked and 1 or 2, ply )
		if v:GetJRagdolled() then JJS.Ragdoll.Stop( v, "reattach" ) end
		v:SetPos( ply:GetPos() + K.Fwd( ply ) * 44 )
		v:SetLocalVelocity( vector_origin )
		JJS.Impair( v, 0.6 )
		K.Effect( "jjs_kit_beam", from, dir, ply, from:Distance( to ), REATTACH )
	end
	Retrieve( ply )
	JJS.SetCooldown( ply, 2, 13 )
end

-- Earthen Insects: behind the user for 15s, then sent to hover around a target within 100 studs. The target's own
-- attacks pop their sacs: blinded for 3s, 4 damage and an injury. They leave if the user gets hit meanwhile.
local function Insects( ply ) return ply:GetNW2Float( "JJSInsects", 0 ) > CurTime() end

K.Character( "blackdeath", {
	name = "Black Death",
	category = "baseonly",
	hp = 100,
	scale = 1.25,
	model = K.Model( "blackdeath", "models/player/zombie_soldier.mdl" ),
	color = Color( 110, 80, 60 ),

	-- Festering Life Sword M1 set (1 + 2 + 2 + 3); unarmed (3 + 3 + 4 + 4, no injury)
	m1 = { Damage = { 1, 2, 2, 3 } },
	m1Alt = { Damage = { 3, 3, 4, 4 } },
	M1Alt = Unarmed,

	passives = {
		{ "Demon of the Modern Era", "1.25x size, extra arms; sword M1s (1 + 2 + 2 + 3), unarmed (3 + 3 + 4 + 4)." },
		{ "Festering Life Sword", "Slashes apply Injury: 3 HP per stack over time, 7 stacks hatch for 14." },
		{ "Iron-Rich", "Downslamming a corpse eats it: all cooldowns reset, next clones +15 HP. (TODO: corpses)" },
	},

	abilities = {
		-- Three careful slashes (1 each, the last through block), each applying an injury through block and cancelling a
		-- ragdoll; every swing parries melee attacks (pushed away, no effects; no i-frames). Special in the windup (or
		-- unarmed): "Fierce Strikes", the sword tossed up, two punches (4 + 4) and an unblockable uppercut hitting
		-- ragdolls (5).
		[ 1 ] = K.Melee{ "Festering Strikes", cooldown = 20, startup = 0.3, hits = 3, interval = 0.3, hitDamage = { 1, 1, 1 },
			hitBlock = { "normal", "normal", "normal" }, blockDamage = 1, reach = 9, type = "melee", bypassRagdoll = true, stun = 0.8,
			parry = { window = 1.0, counters = { melee = true }, stun = 0.4, iframes = 0.1 }, onContact = Injure( 1 ), tip = "SPECIAL",
			special = { free = true, hitDamage = { 4, 4, 5 }, hitBlock = { "normal", "normal", "none" }, hitBypass = { false, false, true }, blockDamage = false,
				parry = false, onContact = false, ragdoll = { h = 10, v = 55 } },
			cond = { test = Unarmed, hitDamage = { 4, 4, 5 }, hitBlock = { "normal", "normal", "none" }, hitBypass = { false, false, true },
				blockDamage = false, parry = false, onContact = false, ragdoll = { h = 10, v = 55 } } },
		-- Detaches the sword arm and launches it on a bridge of cockroaches (1; airborne: 360 aim and a roach platform
		-- slowing the fall). Landed (even blocked), it impales them for 8s: no cooldown, the user is unarmed, and pressing
		-- it again ("Reattach", unblockable) pulls the arm back with them. Traveling 85 studs without a hit, it comes back
		-- and the move goes on 13s. Not reattached within 8s: disabled 6s before the sword returns.
		[ 2 ] = K.Projectile{ "Detach", cooldown = 13, startup = 0.35, damage = 1, range = 85, speed = 170, radius = 2.5, type = "bullet",
			bypassRagdoll = true, stun = 1, color = "brown", tip = "USE AGAIN",
			onContact = function( ply, v, p, r )
				AddInjury( v, r == "blocked" and 1 or 2, ply )
				Impale( ply, v, r == "blocked" )
			end,
			air = { onUse = function( ply ) JJS.Hover( ply, 0.6 ) end } },
		-- The extra arms jolt forward to grab a neck (stalling their injury drain), then a slash tosses them away (2, 2
		-- injuries). No endlag on a miss; usable through the user's own hitstun (block, moves, even the awakening), which
		-- it interrupts once it grabs or is blocked. Unarmed: a heavy punch launching them (12).
		[ 3 ] = K.Grab{ "Chokehold", cooldown = 16, startup = 0.25, hits = 2, interval = 0.6, hitDamage = { 0, 2 }, reach = 8, type = "melee",
			bypassRagdoll = true, whiffEndlag = 0, ragdoll = { h = 50, v = 15 },
			onContact = function( ply, v ) v.jjs_choked = CurTime() + 0.7 end,
			onHit = function( ply, v ) AddInjury( v, 2, ply ) end,
			cond = { test = Unarmed, hitDamage = { 0, 12 }, onHit = false, ragdoll = { h = 75, v = 25 } } },
		-- A horde of roaches rushes 35 studs forward tearing through everything, ragdolling targets away (6, +2 every 1.5
		-- injuries; unblockable; nothing to the user's right). Airborne: rides the wave ~40 studs after a longer windup.
		-- Special in the windup: the swarm twirls up, fully uncounterable, launching anyone caught upward (9 + injuries;
		-- shorter range, longer windup, a tiny safe gap right in front; airborne, it suspends the user).
		[ 4 ] = K.Beam{ "Roach Swarm", cooldown = 17, startup = 0.45, damage = 6, range = 35, radius = 6, pierce = true, maxPitch = 0.1, type = "bullet",
			block = "none", bypassRagdoll = true, ragdoll = { h = 45, v = 20 }, color = "brown", tip = "SPECIAL",
			air = { kind = "mobility", startup = 0.6, travel = 40, time = 0.6, dir = "forward", damage = 6, reach = 10, width = 10 },
			special = { kind = "aoe", free = true, startup = 0.7, damage = 9, radius = 10, offset = 12, type = "explosion", ragdoll = { h = 5, v = 60 },
				onUse = function( ply ) if not ply:IsOnGround() then JJS.Hover( ply, 1 ) end end } },
	},
	-- Two earthen insects with blinding sacs follow the user for 15s; the special again aimed at an enemy within 100
	-- studs sends them to hover around them (see above). 15s once they're gone.
	special = {
		name = "Earthen Insect Trance",
		cooldown = 15,
		tip = function( ply ) if Insects( ply ) and not IsValid( ply:GetNW2Entity( "JJSInsectsOn" ) ) then return "SEND" end end,
		Again = function( ply )
			if not Insects( ply ) then return false end
			local t = K.AimTarget( ply, 100 * S, 0.85 )
			if IsValid( t ) then ply:SetNW2Entity( "JJSInsectsOn", t ) end
			return true
		end,
		Use = function( ply )
			ply:SetNW2Float( "JJSInsects", CurTime() + 15 )
			ply:SetNW2Entity( "JJSInsectsOn", NULL )
			JJS.SetCooldown( ply, 5, 30 )
		end,
	},

	-- Parthenogenesis: splits in two with all the cursed energy (total i-frames once highlighted white): an offspring
	-- (80 max HP, 50 for later ones; up to 8 Black Deaths) follows the user and mirrors their M1s and moves. Heals 25
	-- (both); 50% back if interrupted. TODO: the offspring. Near a domain border: the roaches eat a hole to invade it.
	-- Special in the windup (or with the maximum offspring): "Bugnado", two swirling roach pillars 30-45 studs out merge
	-- into a tornado biting whoever is caught (81.5, no ragdoll cancel until launched; heals 25 on a hit).
	awakenMove = K.Buff{ "Parthenogenesis", startup = 1.2, duration = 0.3, iframes = 1.5, heal = 25, color = "white",
		onFinish = function( ply, p, interrupted ) if interrupted then ply:SetJAwaken( 0.5 ) end end,
		special = { kind = "zone", free = true, startup = 1.25, radius = 18, offset = 12, duration = 4, tick = 0.4, damage = 8, type = "swarm",
			block = "none", bypassRagdoll = true, trueRag = true, stun = 0.4, heal = 25, color = "brown", ragdoll = { time = 0.5, h = 0, v = 10 } } },
} )

-- Detach again: Reattach; Chokehold through the user's own hitstun
local bd = JJS.Characters.blackdeath
bd.abilities[ 2 ].Again = function( ply )
	if not SwordOut( ply ) or not ply:Alive() or ply:GetJRagdolled() or JJS.IsStunned( ply ) then return false end
	if not ply.jjs_detachEnd or CurTime() > ply.jjs_detachEnd then return true end
	if JJS.GetAction( ply ) then JJS.StopAction( ply, true ) end
	Reattach( ply )
	return true
end
local choke = bd.abilities[ 3 ]
local chokeCan, chokeUse = choke.CanUse, choke.Use
choke.CanUse = function( ply, slot, mv )
	if ply:Alive() and not ply:GetJRagdolled() and not JJS.IsStunned( ply ) then return true end
	return chokeCan( ply, slot, mv )
end
choke.Use = function( ply, mv, slot )
	if JJS.GetAction( ply ) then JJS.StopAction( ply, true ) end
	ply:SetJBlockStart( 0 )
	chokeUse( ply, mv, slot )
end

if SERVER then
	-- the M1 injuries (armed): 2 on the 1st, 1 on the 3rd
	hook.Add( "JJS_M1", "JJS_Injury", function( ply, idx, variant, landed )
		if ply:GetJChar() ~= "blackdeath" or not IsValid( landed ) or Unarmed( ply ) then return end
		if idx == 1 then AddInjury( landed, 2, ply ) elseif idx == 3 then AddInjury( landed, 1, ply ) end
	end )

	-- Roach Swarm: +2 damage every 1.5 injuries
	JJS.AddDamageMod( "JJS_RoachSwarm", function( victim, attacker, dmg, hit )
		if not hit.kit or hit.kit.name ~= "Roach Swarm" or dmg <= 0 then return end
		return ( dmg + 2 * math.floor( Injury( victim ) / 1.5 ) ) / dmg
	end )

	-- Earthen Insects: the target's attacks pop them
	local function Pop( t )
		for _, ply in ipairs( player.GetAll() ) do
			if Insects( ply ) and ply:GetNW2Entity( "JJSInsectsOn" ) == t then
				ply:SetNW2Float( "JJSInsects", 0 )
				ply:SetNW2Entity( "JJSInsectsOn", NULL )
				JJS.SetCooldown( ply, 5, 15 )
				JJS.Blind( t, 3 )
				JJS.ApplyDamage( t, ply, 4, { type = JJS.DMG.EXPLOSION } )
				AddInjury( t, 1, ply )
			end
		end
	end
	hook.Add( "JJS_M1", "JJS_EarthenInsects", function( ply ) Pop( ply ) end )
	hook.Add( "JJS_Cooldown", "JJS_EarthenInsects", function( ply ) Pop( ply ) end )
	-- they fly away when the user is hit while they hover around someone
	hook.Add( "JJS_Hit", "JJS_EarthenInsects", function( victim, hit, res )
		if res == "hit" and Insects( victim ) and IsValid( victim:GetNW2Entity( "JJSInsectsOn" ) ) then
			victim:SetNW2Float( "JJSInsects", 0 )
			JJS.SetCooldown( victim, 5, 15 )
		end
	end )

	hook.Add( "Tick", "JJS_BlackDeath", function()
		local now = CurTime()
		local dt = FrameTime()
		for _, ply in ipairs( player.GetAll() ) do
			-- injury drain: 3 per stack over 2 ticks (1.5/s; 1/s while choked)
			local n = Injury( ply )
			if n > 0 and ply:Alive() then
				local rate = ( ply.jjs_choked or 0 ) > now and 1 or 1.5
				local d = rate * dt
				JJS.ApplyDamage( ply, ply.jjs_injBy, d, { type = JJS.DMG.SPECIAL } )
				ply.jjs_injDrain = ( ply.jjs_injDrain or 0 ) + d
				if ply.jjs_injDrain >= 3 then
					ply.jjs_injDrain = ply.jjs_injDrain - 3
					ply:SetNW2Int( "JJSInjury", n - 1 )
				end
			end
			-- the sword comes back 6s after Reattach's window ran out
			if ply.jjs_detachEnd and now > ply.jjs_detachEnd then
				ply.jjs_detachEnd = nil
				JJS.SetCooldown( ply, 2, 6 )
				timer.Simple( 6, function() if IsValid( ply ) then Retrieve( ply ) end end )
			end
			-- the insects expired: the cooldown starts
			if ply:GetNW2Float( "JJSInsects", 0 ) > 0 and ply:GetNW2Float( "JJSInsects", 0 ) < now then
				ply:SetNW2Float( "JJSInsects", 0 )
				JJS.SetCooldown( ply, 5, 15 )
			end
		end
	end )
end

hook.Add( "JJS_PlayerSpawned", "JJS_BlackDeath", function( ply )
	ply:SetNW2Int( "JJSInjury", 0 )
	ply:SetNW2Float( "JJSInsects", 0 )
	ply.jjs_injDrain = 0
	Retrieve( ply )
end )
