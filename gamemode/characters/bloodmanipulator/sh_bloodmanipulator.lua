-- Blood Manipulator (Choso). Moves are JJS.Kit placeholders built from the JJS fandom wiki and the dogslamloop frame
-- data wiki; comments describe what the real move does.
--
-- Convergence orbs live in Res1 (0..4). Bombs (the aerial Flowing Red Scale's static mine, Supernova's following bomb)
-- are detonated by the special in the order they were placed, before Convergence. After Wing King, the orbs left form
-- a halo: the special sends them homing at a target within 75 studs.

local K = JJS.Kit
local S = JJS.STUD

local function Orbs( ply ) return math.floor( ply:GetJRes1() + 0.5 ) end
local function HasOrb( ply ) return Orbs( ply ) > 0 end
local function UseOrb( ply )
	if Orbs( ply ) <= 0 then return false end
	ply:SetJRes1( Orbs( ply ) - 1 )
	return true
end

------------------------------------------------------------------------------------------
-- Bombs
------------------------------------------------------------------------------------------
local MINE = K.Params( K.AoE{ "Blood Mine", damage = 10, radius = 10, type = "explosion", block = "normal", bypassRagdoll = true,
	ragdoll = { h = 45, v = 25 }, color = "blood" } )
local BOMB = K.Params( K.AoE{ "Killer Queen", damage = 8, radius = 5, type = "explosion", block = "normal", bypassRagdoll = true,
	ragdoll = { h = 40, v = 25 }, color = "blood" } )

local function Bombs( ply ) return ply.jjs_bombs or {} end
local function SyncBombs( ply ) ply:SetNW2Int( "JJSBombs", #Bombs( ply ) ) end

local function AddBomb( ply, b )
	ply.jjs_bombs = ply.jjs_bombs or {}
	table.insert( ply.jjs_bombs, b )
	SyncBombs( ply )
end

local function BombPos( ply, b )
	if b.kind == "follow" then return ply:GetPos() + b.offset end
	return b.pos
end

-- the oldest bomb goes off
local function Detonate( ply )
	local b = table.remove( Bombs( ply ), 1 )
	SyncBombs( ply )
	if not b or CLIENT then return end
	local pos = BombPos( ply, b )
	local p = b.kind == "mine" and MINE or BOMB
	for _, v in ipairs( K.SphereTargets( pos + Vector( 0, 0, 36 ), p.radius, ply, true ) ) do
		JJS.Hit( v, K.MakeHit( ply, p, v, 1, pos ) )
	end
	-- the mine hurts the user too (15), but can't kill or ragdoll them
	if b.kind == "mine" and ply:GetPos():Distance( pos ) < p.radius then
		JJS.ApplyDamage( ply, nil, math.min( 15, ply:GetJHP() - 1 ), { type = JJS.DMG.EXPLOSION } )
		ply:SetLocalVelocity( ( ply:GetPos() - pos ):GetNormalized() * 300 + Vector( 0, 0, 350 ) )
	end
	K.Effect( "jjs_kit_burst", pos + Vector( 0, 0, 20 ), Vector( 0, 0, 1 ), ply, p.radius, p )
end

-- Wing King's halo: the orbs present before it
local HALO_ORB = K.Params( K.Projectile{ "Halo Orb", damage = 5, speed = 110, range = 120, radius = 3, homing = true, type = "bullet",
	block = "normal", bypassRagdoll = true, stun = 1, color = "blood" } )

-- Slicing Exorcism by orbs: 3 per tick, +12 per orb up to 39; +3.25s cooldown per orb (at least one, conjured free)
local function Exorcism()
	local built = {}
	for n = 1, 4 do
		built[ n ] = K.Build( "bloodmanipulator", "exorcism" .. n, K.Beam{ "Slicing Exorcism", cooldown = 3.25 * n, startup = 0.5,
			damage = math.min( 39, 3 + 12 * n ), duration = 0.2 + 0.2 * 4 * ( n - 1 ), tick = 0.2, range = 66, radius = 2, maxPitch = 0.3,
			type = "bullet", block = "none", bypassRagdoll = true, trueRag = true, color = "blood", ragdoll = { h = 10, v = -30 }, tip = n .. " ORB",
			onUse = function( ply ) ply:SetJRes1( 0 ) end,
			-- special in the windup: a ricocheting blood chakram (17.5) that grants an orb
			special = { kind = "projectile", free = true, damage = 17.5, duration = false, range = 90, speed = 140, radius = 3, pierce = true,
				maxPitch = 1, onUse = false, onEnd = function( ply ) ply:SetJRes1( math.min( 4, Orbs( ply ) + 1 ) ) end } } )
	end
	return {
		name = "Slicing Exorcism",
		cooldown = 13,
		Pick = function( ply ) return built[ math.Clamp( Orbs( ply ), 1, 4 ) ] end,
	}
end

-- Conjures 4 blood orbs condensed to their limit (0.65s; only with no orb left; 10% awakening). Pressed with bombs out,
-- it detonates the oldest instead; after Wing King, it sends a halo orb at the aimed target.
local CONVERGENCE_AB = K.Build( "bloodmanipulator", "convergence", K.Buff{ "Convergence", cooldown = 20, startup = 0.2, duration = 0.45,
	awakenCost = 0.1, color = "blood", onUse = function( ply ) ply:SetJRes1( 4 ) end } )
local CONVERGENCE = {
	name = "Convergence",
	cooldown = 20,
	tip = function( ply )
		if ply:GetNW2Int( "JJSBombs", 0 ) > 0 then return "DETONATE" end
		if ply:GetNW2Int( "JJSHalo", 0 ) > 0 then return "HALO x" .. ply:GetNW2Int( "JJSHalo", 0 ) end
	end,
	-- checked before the cooldown, usable in stun and ragdoll
	Again = function( ply )
		if not ply:Alive() then return false end
		if #Bombs( ply ) > 0 then Detonate( ply ) return true end
		local halo = ply:GetNW2Int( "JJSHalo", 0 )
		if halo > 0 then
			local t = K.AimTarget( ply, 75 * S, 0.85 )
			if not IsValid( t ) then return true end
			ply:SetNW2Int( "JJSHalo", halo - 1 )
			if SERVER then K.SpawnProjectile( ply, HALO_ORB, JJS.Util.BodyCenter( ply ) + Vector( 0, 0, 30 ), ( JJS.Util.BodyCenter( t ) - ply:EyePos() ):GetNormalized(), t ) end
			return true
		end
		return false
	end,
	CanUse = function( ply, slot, mv ) return Orbs( ply ) <= 0 and CONVERGENCE_AB.CanUse( ply, slot, mv ) end,
	Use = function( ply, mv, slot ) CONVERGENCE_AB.Use( ply, mv, slot ) end,
}

local BM = K.Character( "bloodmanipulator", {
	name = "Blood Manipulator",
	category = "complete",
	hp = 100,
	model = K.Model( "bloodmanipulator", "models/player/group03/male_04.mdl" ),
	color = Color( 200, 30, 50 ),

	-- per-hit M1 frames { startup, recovery, block endlag } (dogslamloop)
	m1 = {
		Frames = { { 12, 7, 15 }, { 12, 8, 17 }, { 12, 8, 17 } },
	},

	passives = {
		{ "Convergence", "4 orbs strengthen the moves; the special also detonates bombs, then fires the Wing King halo." },
	},

	abilities = {
		-- Claps to trap blood and fires it as an uncounterable thin beam 30 studs long (12, hits ragdolls).
		-- Holding it 1.35s with an orb (red flash, steam between the palms): the orb doubles the range and knockback (20,
		-- unblockable, no evasive); it fires on its own after ~7s.
		[ 1 ] = K.Beam{ "Piercing Blood", cooldown = 15, startup = 0.45, damage = 12, range = 30, radius = 1.5, type = "explosion",
			bypassRagdoll = true, color = "blood", ragdoll = { h = 35, v = 12 }, tip = "HOLD",
			hold = { time = 1.35, need = HasOrb, damage = 20, range = 60, block = "none", trueRag = true, ragdoll = { h = 70, v = 20 },
				onUse = function( ply ) UseOrb( ply ) end } },
		-- A performance-boosted dash; connecting, the rush (3), two kicks (3 each) and a last kick ragdolling away (4).
		-- With an orb ("Stack"): the last kick explodes with blood (8, 17 total).
		-- Airborne: a downward axe kick ragdolling upward (6, unblockable); falling a whole second with it, a blood mine
		-- bursts under the user, springing them up (5 to them, an orb consumed if any). Airborne with an orb: a static
		-- blood mine is placed underneath instead, detonated by the special (10 in 10 studs, even while stunned or
		-- ragdolled; the user takes 15 if in it, can't be killed or ragdolled by it).
		[ 2 ] = K.Rush{ "Flowing Red Scale", cooldown = 12, startup = 0.2, travel = 18, time = 0.3, hits = 4, interval = 0.22, hitDamage = { 3, 3, 3, 4 },
			type = "melee", block = "all", bypassRagdoll = true, ragdoll = { h = 50, v = 20 },
			cond = {
				{ test = function( ply ) return HasOrb( ply ) and not ply:IsOnGround() end, kind = "melee", damage = 6, hits = 1, hitDamage = false,
					block = "normal", ragdoll = { h = 5, v = 50 }, height = 16, startup = 0.3,
					onUse = function( ply ) UseOrb( ply ) AddBomb( ply, { kind = "mine", pos = ply:GetPos() } ) end },
				{ test = HasOrb, hitDamage = { 3, 3, 3, 8 }, color = "blood", onUse = function( ply ) UseOrb( ply ) end },
			},
			air = { kind = "melee", damage = 6, hits = 1, hitDamage = false, block = "none", ragdoll = { h = 5, v = 50 }, height = 16, startup = 0.3,
				onUse = function( ply )
					timer.Simple( 1, function()
						if not IsValid( ply ) or not ply:Alive() or ply:IsOnGround() then return end
						-- the blood spring
						JJS.ApplyDamage( ply, nil, 5, { type = JJS.DMG.EXPLOSION } )
						UseOrb( ply )
						ply:SetLocalVelocity( Vector( 0, 0, 520 ) )
					end )
				end } },
		-- Without orbs: a cross-armed guard (0.6s); a melee hit is hardened with blood (a metallic clang) and answered by a
		-- cut to the shoulder and a punch (7 + 7). Landed, it stays off cooldown and grants 4 orbs for free.
		-- With orbs ("Killer Queen"): tosses an orb that turns into a blood bomb mimicking the user's movement 20 studs
		-- ahead; the special detonates it (8, 10x10 studs). Getting stunned dissipates it; not usable with 4 bombs out.
		[ 3 ] = K.Counter{ "Supernova", cooldown = 15, window = 0.6, counters = { melee = "counter" }, riposte = 14, color = "blood",
			onCounter = function( ply )
				timer.Simple( 0, function() if IsValid( ply ) then JJS.SetCooldown( ply, 3, 0 ) ply:SetJRes1( 4 ) end end )
			end,
			cond = { test = function( ply ) return HasOrb( ply ) and #Bombs( ply ) < 4 end, kind = "stub", cooldown = 4, startup = 0.3, endlag = 0.2,
				onUse = function( ply )
					UseOrb( ply )
					AddBomb( ply, { kind = "follow", offset = K.Fwd( ply ) * 20 * S } )
				end } },
		-- Two blood blades: a thrusting jab with the left one (5, blockable, not on grounded ragdolls), then a front flip
		-- slamming the floor with the right one, sending them away (6, unblockable, hits ragdolls). Missing the stab doesn't
		-- cancel the slam.
		[ 4 ] = K.Melee{ "Blood Edge", cooldown = 13, startup = 0.3, hits = 2, interval = 0.45, hitDamage = { 5, 6 }, hitBlock = { "normal", "none" },
			hitBypass = { false, true }, type = "melee", ragdoll = { h = 40, v = 15 } },
	},
	special = CONVERGENCE,

	awakening = {
		name = "Duty As A Brother",
		duration = 60,
		heal = 20,
		-- "Brothers, lend me your strength!" Three faint red figures lay their hands on the user's back: "I WILL FULFILL MY
		-- DUTY AS THE ELDEST BROTHER!" The orbs vanish when the awakening ends.
		abilities = {
			-- The orbs become a pressurized stream ragdolling to the floor (66 studs; see Exorcism). The camera locks while
			-- it fires, unless the user jumped first (more airtime, 360 aim). Special in the windup: the blood spins into a
			-- chakram thrown three spins later, ricocheting between surfaces and targets (17.5), granting an orb.
			[ 1 ] = Exorcism(),
			-- Melee and bullet i-frames, a lunge into a flurry of kicks and punches (28.75), then the hand shoots out on a blood
			-- rope, pulls the target into a punch to the face and slams them (15; the rope is blockable, bullet damage). No
			-- endlag. The orbs left form a halo for the special.
			[ 2 ] = K.Grab{ "Wing King", cooldown = 16, startup = 0.3, damage = 43.75, hits = 8, interval = 0.18, lunge = 25, type = "melee",
				blockDamage = 21.9, bypassRagdoll = true, armor = "bullet", meleeIFrames = 0.4, endlag = 0, ragdoll = { h = 10, v = -35 },
				onUse = function( ply ) ply:SetNW2Int( "JJSHalo", Orbs( ply ) ) end },
			-- A giant blood sphere erupts upward, raining pellets on everything within 35 studs (2 per tick; the user acts freely
			-- after the windup; a ragdoll stops it). The awakening drains 5x faster meanwhile, orbs are spent first.
			-- TODO: toggling it off and on once.
			[ 3 ] = K.Zone{ "Blood Rain", cooldown = 35, startup = 0.8, radius = 35, duration = 8, tick = 0.5, damage = 2, stun = 0.2,
				follow = true, type = "swarm", block = "all", bypassRagdoll = true, color = "blood",
				onUse = function( ply ) ply.jjs_rainUntil = CurTime() + 8.8 end },
			-- Spins up 14 blood orbs and fires a massive 120 stud cone, aimable during the windup, stronger up close (95 at
			-- minimum range); i-frames once the spin ends. Beam clash: the weakest.
			[ 4 ] = K.Beam{ "Plasma Wave", cooldown = 45, startup = 1.6, damage = 95, falloff = 25, duration = 1, tick = 0.2, range = 120, radius = 7,
				pierce = true, clash = 1, type = "explosion", block = "none", bypassRagdoll = true, iframes = 1.6, uninterruptible = true,
				color = "blood", ragdoll = { h = 70, v = 25 }, crater = 1400 },
		},
		special = CONVERGENCE,
	},
} )

hook.Add( "JJS_AwakeningEnd", "JJS_BloodOrbs", function( ply )
	if ply:GetJChar() ~= "bloodmanipulator" then return end
	ply:SetJRes1( 0 )
	ply:SetNW2Int( "JJSHalo", 0 )
end )

if SERVER then
	hook.Add( "Tick", "JJS_BloodManipulator", function()
		local now = CurTime()
		for _, ply in ipairs( player.GetAll() ) do
			if ply:GetJChar() == "bloodmanipulator" then
				-- a stun dissipates the following bombs
				if JJS.IsStunned( ply ) and ply.jjs_bombs then
					for i = #ply.jjs_bombs, 1, -1 do
						if ply.jjs_bombs[ i ].kind == "follow" then table.remove( ply.jjs_bombs, i ) end
					end
					SyncBombs( ply )
				end
				-- Blood Rain: the awakening drains 5x faster, an orb every 2s instead while there are some
				if ( ply.jjs_rainUntil or 0 ) > now and ply:GetJAwakened() then
					if HasOrb( ply ) then
						if ( ply.jjs_rainOrb or 0 ) < now then ply.jjs_rainOrb = now + 2 UseOrb( ply ) end
					else
						ply:SetJAwakenEnd( ply:GetJAwakenEnd() - FrameTime() * 4 )
					end
				end
			end
		end
	end )
end

hook.Add( "JJS_PlayerSpawned", "JJS_BloodManipulator", function( ply )
	ply.jjs_bombs = nil
	ply:SetNW2Int( "JJSBombs", 0 )
	ply:SetNW2Int( "JJSHalo", 0 )
end )

if SERVER then return end

function BM.HUDPaint( ply, now, S2 )
	local n = Orbs( ply )
	if n <= 0 then return end
	local x, y = ScrW() / 2, ScrH() - S2( 170 )
	for i = 1, n do
		surface.SetDrawColor( 200, 20, 40 )
		surface.DrawRect( x + ( i - ( n + 1 ) / 2 ) * S2( 18 ) - S2( 6 ), y, S2( 12 ), S2( 12 ) )
	end
end
