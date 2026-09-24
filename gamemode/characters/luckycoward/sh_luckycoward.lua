-- Lucky Coward (base-only). Moves are JJS.Kit placeholders built from the JJS fandom wiki and the
-- dogslamloop frame data wiki; comments describe what the real move does.
--
-- The Hand Sword: in hand (armed) or away (unarmed) after Helping Hand (following a target 5 studs behind their back)
-- or Cheap Shot (chasing the last enemy it hit, or standing still). Unarmed, the moves turn into the sword's own
-- attacks (usable even stunned or ragdolled), block becomes a 360 dodge and M1 a taunt.
-- Miracles (Res1, 0..6, starting at 3): 3 are spent to survive death at 12.5 HP (within a second after, a fatal hit
-- costs only 1); 1 pays for a ragdoll cancel without evasive (the meter is drained). Gained by an unarmed dodge, a
-- full taunt, interrupting an action with the first 3 M1s, Ambush, Backstab or Trip, and a Jawbreaker landing.

local K = JJS.Kit
local S = JJS.STUD

local function Armed( ply ) return ply:GetNW2Int( "JJSSword", 0 ) == 0 end
local function Unarmed( ply ) return not Armed( ply ) end
local function SwordTarget( ply ) return ply:GetNW2Entity( "JJSSwordTarget" ) end

-- where the sword is: behind its target, or where it stopped
local function SwordPos( ply )
	local t = SwordTarget( ply )
	if IsValid( t ) and t:Alive() then
		return t:GetPos() - JJS.Util.YawForward( t:EyeAngles().y ) * 5 * S
	end
	return ply:GetNW2Vector( "JJSSwordPos", ply:GetPos() )
end

local function Miracle( ply, n )
	ply:SetJRes1( math.Clamp( ply:GetJRes1() + ( n or 1 ), 0, 6 ) )
end

local function Detach( ply, target, pos )
	ply:SetNW2Int( "JJSSword", target and 1 or 2 )
	ply:SetNW2Entity( "JJSSwordTarget", target or NULL )
	ply:SetNW2Vector( "JJSSwordPos", pos or ply:GetPos() )
end
local function Return( ply )
	ply:SetNW2Int( "JJSSword", 0 )
	ply:SetNW2Entity( "JJSSwordTarget", NULL )
end

-- The sword's attacks at its position (Ankle Cutter, High Time); usable in stun and ragdoll
local ANKLE = K.Build( "luckycoward", "ankle", K.AoE{ "Ankle Cutter", startup = 0.25, damage = 10, radius = 6, center = SwordPos, detached = true,
	type = "melee", block = "all", bypassRagdoll = true, ragdoll = { time = 1.5, h = 10, v = 8 } } )
local HIGHTIME = K.Build( "luckycoward", "hightime", K.AoE{ "High Time", startup = 0.3, damage = 12, radius = 6, center = SwordPos, detached = true,
	type = "melee", block = "all", bypassRagdoll = true, ragdoll = { time = 1.8, h = 0, v = 55 } } )
-- Dirty Play: the sword flies back through everyone between it and the user
local DIRTY = K.Params( K.Melee{ "Dirty Play", damage = 8, type = "bullet", block = "normal", bypassRagdoll = true, ragdoll = { h = 30, v = 15 } } )

-- Unarmed slot presses (checked before the cooldown): the sword's own moves
local function SwordMove( slot )
	return function( ply, mv, s )
		if Armed( ply ) or not ply:Alive() then return false end
		if ( ply.jjs_dodgeLock or 0 ) > CurTime() and ( slot == 1 or slot == 2 ) then return true end
		if slot == 1 or slot == 2 then
			if JJS.GetCooldown( ply, slot ) > CurTime() then return true end
			JJS.SetCooldown( ply, slot, slot == 1 and 15 or 12 )
			K.Trigger( ply, slot == 1 and ANKLE or HIGHTIME )
			return true
		end
		if slot == 4 then
			-- Dirty Play (its own cooldown; not while stunned or ragdolled)
			if ply:GetNW2Float( "JJSDirtyCD", 0 ) > CurTime() or JJS.IsStunned( ply ) or ply:GetJRagdolled() then return true end
			ply:SetNW2Float( "JJSDirtyCD", CurTime() + 15 )
			if SERVER then
				local from, to = SwordPos( ply ) + Vector( 0, 0, 36 ), JJS.Util.BodyCenter( ply )
				local dir = ( to - from ):GetNormalized()
				for _, h in ipairs( JJS.Util.PlayersOnRay( from, dir, from:Distance( to ), 3 * S, { ignore = ply, ragdolled = true } ) ) do
					K.Apply( ply, DIRTY, h.ply, 1, from )
				end
				K.Effect( "jjs_kit_beam", from, dir, ply, from:Distance( to ), DIRTY )
			end
			Return( ply )
			return true
		end
		return false
	end
end

local function Behind( ply, v )
	return JJS.Util.YawForward( v:EyeAngles().y ):Dot( JJS.Util.Flat( v:GetPos() - ply:GetPos() ) ) > 0.3
end

-- Taunt (unarmed M1): 2s facing an enemy within 35 studs, a miracle after 1.5s unless they got ragdolled
JJS.RegisterAction( "luckycoward.taunt", {
	dur = 2,
	moveMult = 0,
	gesture = "gesture_wave",
	events = { { 1.5, function( ply )
		if CLIENT then return end
		local t = ply:GetJActTarget()
		if IsValid( t ) and t:Alive() and not t:GetJRagdolled() then Miracle( ply ) end
	end } },
} )

local LC = K.Character( "luckycoward", {
	name = "Lucky Coward",
	category = "baseonly",
	hp = 65,
	model = K.Model( "luckycoward", "models/player/group02/male_02.mdl" ),
	color = Color( 250, 230, 110 ),

	-- Shoot!: the final M1 punctures (+1 damage; not uppercuts/downslams), front dashes kick grounded ragdolls away.
	-- per-hit M1 frames { startup, recovery, block endlag } (dogslamloop)
	m1 = { Frames = { { 12, 7, 15 }, { 13, 6, 13 }, { 13, 6, 13 }, { 12, 0, 0 } }, Damage = { 3, 3, 4, 5 }, FrontDashBypass = true },

	passives = {
		{ "Shoot!", "The final M1 deals 1 extra damage; front dashes kick grounded ragdolls." },
		{ "Miracles", "Up to 6: 3 survive a death at 12.5 HP, 1 pays for a ragdoll cancel." },
		{ "Miracle", "Unarmed, block becomes a 360 melee/bullet dodge (0.25s; +1 miracle)." },
		{ "Taunt", "Unarmed, M1 is a 2s taunt that stores a miracle." },
	},

	abilities = {
		-- A forward slash ragdolling anyone hit backward (12, perfect blockable: a perfect block just dodges the blade;
		-- airborne ragdolls only). Airborne: a 15-20 stud lunge first.
		-- "Stinger" (a grounded ragdoll nearby): the sword driven down, greatly extending their ragdoll (10, no evasive).
		-- "Million Stab" (again right after a Stinger): 3 maniacal thrusts (2 each, unblockable), then they get up
		-- after ~0.31s. Unarmed: "Ankle Cutter", the sword blitzes and slices their legs, knocking them down for 1.5s
		-- (10, 360 blockable; usable in stun and ragdoll; shared cooldown).
		[ 1 ] = K.Melee{ "Ambush", cooldown = 15, startup = 0.3, damage = 12, reach = 9, type = "melee", block = "pre", ragdoll = { h = 45, v = 15 },
			air = { lunge = 17 },
			ragdolled = { damage = 10, block = "normal", bypassRagdoll = true, trueRag = true, ragdoll = { time = 2.2, h = 0, v = -10 },
				onHit = function( ply ) ply.jjs_stinger = CurTime() end } },
		-- A quick stab with a momentary stun (8, unblockable); from behind the stun lasts much longer and the M1 string is
		-- kept. Unarmed: "High Time", the sword rises spinning, slicing upward and pulling targets up (12, 360 blockable;
		-- they get up 1.8s after the fall; usable in stun and ragdoll).
		[ 2 ] = K.Melee{ "Backstab", cooldown = 12, startup = 0.25, damage = 8, reach = 8, type = "melee", block = "none", stun = 0.8,
			onHit = function( ply, victim )
				if Behind( ply, victim ) then
					JJS.Stun( victim, 2.2 )
					ply:SetJM1LastEnd( CurTime() + 2 )
				end
			end },
		-- A kick (7) and the target falls face-first (4; blockable, hits ragdolls): moving enemies lose their ragdoll
		-- cancel; ragdolled ones fly further but take no fall damage. No cooldown on a kill or a corpse. Both modes.
		[ 3 ] = K.Melee{ "Trip", cooldown = 14, startup = 0.3, hits = 2, interval = 0.3, hitDamage = { 7, 4 }, type = "melee", bypassRagdoll = true,
			ragdoll = { h = 10, v = -15 },
			onContact = function( ply, v, p, r )
				if r == "killed" then JJS.SetCooldown( ply, 3, 0 ) end
			end },
		-- Throws the sword through enemies up to 60 studs (7, blockable, hits ragdolls), leaving the user unarmed; it then
		-- chases the last enemy it hit, or stands still if blocked. Unarmed: "Dirty Play", the sword is called back,
		-- slicing through everyone in its way (8; its own cooldown, not while stunned or ragdolled).
		[ 4 ] = K.Projectile{ "Cheap Shot", cooldown = 15, startup = 0.3, damage = 7, range = 60, speed = 200, radius = 2.5, pierce = true, type = "bullet",
			bypassRagdoll = true, color = "gold",
			onUse = function( ply ) Detach( ply, nil, ply:GetPos() + K.Fwd( ply ) * 60 * S ) end,
			onContact = function( ply, v, p, r ) if r ~= "blocked" then Detach( ply, v ) end end },
	},
	-- Aiming at a target within 150 studs, the Hand Sword latches off and follows them, trying to stay 5 studs behind
	-- their back (highlighted through walls; it can't be hit unless over 100 studs from the user, when it comes back).
	-- Aimed at another enemy it retargets; with nobody in sight it runs back to the user.
	special = {
		name = "Helping Hand",
		cooldown = 0.5,
		tip = function( ply ) if Unarmed( ply ) then return "UNARMED" end end,
		CanUse = function( ply ) return ply:Alive() and not ply:GetJRagdolled() end,
		Use = function( ply )
			JJS.SetCooldown( ply, 5, 0.5 )
			local t = K.AimTarget( ply, 150 * S, 0.9 )
			if IsValid( t ) then Detach( ply, t ) else Return( ply ) end
			JJS.Stun( ply, 0.15 )
		end,
	},

	-- Jawbreaker (unarmed only, even stunned): the Hand Sword slides back and hurls itself handle-first into the jaw of
	-- its target, curled into a fist (25, heals 25): impaired for 8s (blurred vision, only walking and awakening).
	-- A miss refunds 65% of the bar.
	awakenMove = K.AoE{ "Jawbreaker", startup = 0.5, damage = 25, radius = 7, center = SwordPos, detached = true, type = "explosion", block = "none",
		uninterruptible = true, heal = 25, stun = 1, color = "gold",
		onHit = function( ply, v )
			JJS.Impair( v, 8 )
			Miracle( ply )
			ply.jjs_jawLanded = true
		end,
		onDone = function( ply ) if not ply.jjs_jawLanded then ply:SetJAwaken( 0.65 ) end end },

	-- G: only unarmed, even in stun
	AwakenPress = function( ply )
		if ply:GetJAwaken() < 1 then return false end
		if Armed( ply ) then return true end
		ply.jjs_jawLanded = nil
		ply:SetJAwaken( 0 )
		K.Trigger( ply, JJS.GetChar( ply ).awakenMove, SwordTarget( ply ) )
		return true
	end,

	-- unarmed: M1 is the taunt
	M1Override = function( ply, mv )
		if Armed( ply ) then return false end
		if JJS.IsBusy( ply ) or not JJS.CanAct( ply ) then return true end
		local t = K.AimTarget( ply, 35 * S, 0.7 )
		if IsValid( t ) then JJS.StartAction( ply, "luckycoward.taunt", 0, t ) end
		return true
	end,

	-- miracles pay for a ragdoll cancel
	PayEvasive = function( ply )
		if ply:GetJRes1() < 1 then return false end
		Miracle( ply, -1 )
		ply:SetJEvasive( 0 )
		return true
	end,

	OnSpawn = function( ply )
		ply:SetJRes1( 3 )
		Return( ply )
	end,
} )

-- the unarmed variants of 1, 2 and 4
for _, slot in ipairs( { 1, 2, 4 } ) do
	local ab = LC.abilities[ slot ]
	local again = ab.Again
	local sword = SwordMove( slot )
	ab.Again = function( ply, mv, s )
		if sword( ply, mv, s ) then return true end
		-- Million Stab right after a Stinger
		if slot == 1 and CurTime() - ( ply.jjs_stinger or -9 ) < 1 and ply:Alive() and not JJS.IsStunned( ply ) then
			ply.jjs_stinger = nil
			JJS.Kit.MILLION.Use( ply, mv, 0 )
			return true
		end
		return again and again( ply, mv, s ) or false
	end
end

K.MILLION = K.Build( "luckycoward", "million", K.Melee{ "Million Stab", startup = 0.15, hits = 3, interval = 0.15, damage = 6, type = "melee",
	block = "none", bypassRagdoll = true, trueRag = true, ragdoll = { time = 0.31, h = 5, v = -5 } } )

if SERVER then
	hook.Add( "JJS_PreventDeath", "JJS_Miracles", function( victim )
		if victim:GetJChar() ~= "luckycoward" then return end
		-- within a second of a miracle save, one more costs a single miracle
		local cost = CurTime() - ( victim.jjs_miracleSave or -9 ) < 1 and 1 or 3
		if victim:GetJRes1() < cost then return end
		Miracle( victim, -cost )
		victim.jjs_miracleSave = CurTime()
		victim:SetJHP( 12.5 )
		victim:SetHealth( 13 )
		JJS.IFrames( victim, 1 )
		JJS.Util.Effect( "jjs_kit_cast", JJS.Util.BodyCenter( victim ), nil, victim, 2, JJS.Kit.COLOR_ID.gold )
		return true
	end )

	-- unarmed block: a 360 dodge of melee and bullets within 0.25s; otherwise there's no guard at all
	hook.Add( "JJS_PreHit", "JJS_LuckyCoward", function( victim, hit )
		-- interruptions with the first 3 M1s, Ambush, Backstab or Trip give a miracle
		local a = hit.attacker
		if IsValid( a ) and a:IsPlayer() and a:GetJChar() == "luckycoward" and JJS.IsBusy( victim ) and not JJS.IsBlocking( victim ) then
			local n = hit.kit and hit.kit.name
			if ( hit.isM1 and ( hit.m1Index or 9 ) <= 3 ) or n == "Ambush" or n == "Backstab" or n == "Trip" then hit.jjs_lcMiracle = true end
		end
		if victim:GetJChar() ~= "luckycoward" or Armed( victim ) or not JJS.IsBlocking( victim ) then return end
		local dodgeable = hit.type == JJS.DMG.MELEE or hit.type == JJS.DMG.BULLET
		if dodgeable and CurTime() - victim:GetJBlockStart() <= 0.25 and ( victim.jjs_dodgeCD or 0 ) < CurTime() then
			victim.jjs_dodgeCD = CurTime() + 0.15
			victim.jjs_dodgeLock = CurTime() + 0.3
			Miracle( victim )
			JJS.IFrames( victim, 0.3 )
			JJS.Util.Effect( "jjs_kit_cast", JJS.Util.BodyCenter( victim ), nil, victim, 0.8, JJS.Kit.COLOR_ID.gold )
			return "evaded"
		end
		if CurTime() - victim:GetJBlockStart() > 0.25 then victim.jjs_dodgeCD = math.max( victim.jjs_dodgeCD or 0, CurTime() + 1 ) end
		hit.block = "none"
	end )
	hook.Add( "JJS_Hit", "JJS_LuckyCoward", function( victim, hit, res )
		if hit.jjs_lcMiracle and res == "hit" then Miracle( hit.attacker ) end
	end )

	-- the sword comes back when its target is gone or more than 100 studs from the user
	hook.Add( "Tick", "JJS_LuckyCoward", function()
		for _, ply in ipairs( player.GetAll() ) do
			if ply:GetJChar() == "luckycoward" and Unarmed( ply ) then
				local t = SwordTarget( ply )
				if ply:GetNW2Int( "JJSSword", 0 ) == 1 and ( not IsValid( t ) or not t:Alive() ) then Return( ply )
				elseif SwordPos( ply ):Distance( ply:GetPos() ) > 100 * S then Return( ply ) end
			end
		end
	end )
	return
end

function LC.HUDPaint( ply, now, S2 )
	local n = math.floor( ply:GetJRes1() + 0.5 )
	local x, y = ScrW() / 2 - S2( 60 ), ScrH() - S2( 160 )
	for i = 1, 6 do
		if i <= n then surface.SetDrawColor( 255, 220, 80 ) else surface.SetDrawColor( 60, 60, 60, 200 ) end
		surface.DrawRect( x + ( i - 1 ) * S2( 20 ), y, S2( 14 ), S2( 14 ) )
	end
end
