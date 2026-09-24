-- Blood Manipulator (Choso). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does.
-- Convergence orbs live in Res1 (0..4); the special conjures 4 when none are left.

local K = JJS.Kit

local function Orbs( ply ) return math.floor( ply:GetJRes1() + 0.5 ) end
local function UseOrb( ply )
	if Orbs( ply ) <= 0 then return false end
	ply:SetJRes1( Orbs( ply ) - 1 )
	return true
end

-- Conjures 4 blood orbs condensed to their limit (0.65s; only when none remain). Costs 10% awakening.
local CONVERGENCE = K.Buff{ "Convergence", cooldown = 20, startup = 0.2, duration = 0.45, awakenCost = 0.1, color = "blood",
	CanUse = function( ply ) return Orbs( ply ) <= 0 end,
	onUse = function( ply ) ply:SetJRes1( 4 ) end }

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

	abilities = {
		-- Claps to trap blood and fires it as an uncounterable thin beam with 30 studs of range.
		-- Hold (with an orb): after 1.35s the beam doubles its range and knockback (20, unblockable).
		[ 1 ] = K.Beam{ "Piercing Blood", cooldown = 15, startup = 0.45, damage = 12, range = 30, radius = 1.5, type = "special",
			bypassRagdoll = true, color = "blood", ragdoll = { h = 35, v = 12 },
			hold = { time = 1.35, damage = 20, range = 60, block = "none", trueRag = true, ragdoll = { h = 70, v = 20 },
				onUse = function( ply ) UseOrb( ply ) end } },
		-- Dashes forward; on contact, the rush (3), two kicks (3 each) and a ragdolling last kick (4). 360 blockable, hits ragdolls.
		-- With an orb ("Stack"): the last kick is amplified by a blood explosion (8, 17 total).
		-- Air variant: a downward axe kick that ragdolls upward (6, unblockable; its evasive-bait use is the main one);
		-- falling 1s triggers a blood spring (5 self damage). TODO air orb variant: a static blood mine (10, 15 to the user).
		[ 2 ] = K.Rush{ "Flowing Red Scale", cooldown = 12, startup = 0.2, travel = 18, time = 0.3, hits = 4, interval = 0.22, hitDamage = { 3, 3, 3, 4 },
			type = "melee", block = "all", bypassRagdoll = true, ragdoll = { h = 50, v = 20 },
			cond = { test = function( ply ) return Orbs( ply ) > 0 end, hitDamage = { 3, 3, 3, 8 }, color = "blood",
				onUse = function( ply ) UseOrb( ply ) end },
			air = { kind = "melee", damage = 6, hits = 1, hitDamage = false, block = "none", ragdoll = { h = 5, v = 50 }, height = 16, startup = 0.3 } },
		-- Without orbs: a cross-armed guard (0.6s); a melee hit is hardened with blood and answered with a cut and a punch
		-- (7 + 7). Stays off cooldown when it lands.
		-- With orbs ("Killer Queen"): tosses an orb that becomes a blood bomb mimicking the user's movement 20 studs away;
		-- the special detonates it in a 10x10 area (8, 4s cooldown; the real bomb waits for the special).
		[ 3 ] = K.Counter{ "Supernova", cooldown = 15, window = 0.6, counters = { melee = "counter" }, riposte = 14, color = "blood",
			onCounter = function( ply ) timer.Simple( 0, function() if IsValid( ply ) then ply:SetJCD3( 0 ) end end ) end,
			cond = { test = function( ply ) return Orbs( ply ) > 0 end, kind = "aoe", cooldown = 4, startup = 0.7, damage = 8, radius = 5, offset = 20,
				type = "explosion", block = "normal", bypassRagdoll = true, ragdoll = { h = 40, v = 25 },
				onUse = function( ply ) UseOrb( ply ) end } },
		-- Blood blades: a thrusting jab (5, blockable, not on grounded ragdolls) then a flip slamming the floor (6, unblockable,
		-- hits ragdolls); missing the stab doesn't cancel the slam.
		[ 4 ] = K.Melee{ "Blood Edge", cooldown = 13, startup = 0.3, hits = 2, interval = 0.45, hitDamage = { 5, 6 }, hitBlock = { "normal", "none" },
			hitBypass = { false, true }, type = "melee", ragdoll = { h = 40, v = 15 } },
	},
	special = CONVERGENCE,

	awakening = {
		name = "Duty As A Brother",
		duration = 60,
		heal = 20,
		-- "Brothers, lend me your strength!" ... "I WILL FULFILL MY DUTY AS THE ELDEST BROTHER!"
		abilities = {
			-- Orbs become a pressurized stream (66 studs) that ragdolls to the floor: 3 per tick, +12 per orb, up to 39.
			-- TODO special variant: a ricocheting blood chakram (17.5) that grants an orb.
			[ 1 ] = K.Beam{ "Slicing Exorcism", cooldown = 13, startup = 0.5, damage = 39, duration = 0.8, tick = 0.2, range = 66, radius = 2,
				type = "special", block = "none", bypassRagdoll = true, trueRag = true, color = "blood", ragdoll = { h = 10, v = -30 },
				onUse = function( ply ) ply:SetJRes1( 0 ) end },
			-- With melee and bullet i-frames, lunges into a flurry (28.75), then a blood rope pulls the target into a punch and slam (15).
			-- TODO: afterwards, remaining orbs form a halo; the special fires them as homing orbs (5 each).
			[ 2 ] = K.Grab{ "Wing King", cooldown = 16, startup = 0.3, damage = 43.75, hits = 8, interval = 0.18, lunge = 25, type = "melee",
				blockDamage = 21.9, bypassRagdoll = true, armor = "bullet", iframes = 0.4, ragdoll = { h = 10, v = -35 } },
			-- A blood sphere erupts upward, raining pellets on everything within 35 studs (2 per tick); the user is free meanwhile.
			[ 3 ] = K.Zone{ "Blood Rain", cooldown = 35, startup = 0.8, radius = 35, duration = 8, tick = 0.5, damage = 2, stun = 0.2,
				follow = true, type = "special", block = "all", bypassRagdoll = true, color = "blood" },
			-- 14 blood orbs spin into a massive 120 stud cone; more damage the closer the target (95 at minimum range). Beam clash: weakest.
			[ 4 ] = K.Beam{ "Plasma Wave", cooldown = 45, startup = 1.6, damage = 95, duration = 1, tick = 0.2, range = 120, radius = 7,
				pierce = true, clash = 1, type = "special", block = "none", bypassRagdoll = true, iframes = 1.6, uninterruptible = true,
				color = "blood", ragdoll = { h = 70, v = 25 }, crater = 1400 },
		},
		special = CONVERGENCE,
	},
} )

hook.Add( "JJS_AwakeningEnd", "JJS_BloodOrbs", function( ply )
	if ply:GetJChar() == "bloodmanipulator" then ply:SetJRes1( 0 ) end
end )

if SERVER then return end

function BM.HUDPaint( ply, now, S )
	local n = Orbs( ply )
	if n <= 0 then return end
	local x, y = ScrW() / 2, ScrH() - S( 170 )
	for i = 1, n do
		surface.SetDrawColor( 200, 20, 40 )
		surface.DrawRect( x + ( i - ( n + 1 ) / 2 ) * S( 18 ) - S( 6 ), y, S( 12 ), S( 12 ) )
	end
end
