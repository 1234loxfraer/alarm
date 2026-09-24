-- Lucky Coward (base-only). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does.
-- Miracles (Res1, 0..6): three are spent to survive a lethal hit at 12.5 HP. The user starts with 3.

local K = JJS.Kit

local LC = K.Character( "luckycoward", {
	name = "Lucky Coward",
	category = "baseonly",
	hp = 65,
	model = K.Model( "luckycoward", "models/player/group02/male_02.mdl" ),
	color = Color( 250, 230, 110 ),

	-- Shoot!: the final M1 punctures (+1 damage)
	m1 = { Damage = { 3, 3, 4, 5 } },

	passives = {
		{ "Shoot!", "The final M1 deals 1 extra damage; front dashes bypass ragdoll. (partly TODO)" },
		{ "Miracles", "Up to 6 miracles: 3 are spent to survive death at 12.5 HP (also usable to ragdoll cancel). (partly TODO)" },
		{ "Miracle", "Unarmed, block becomes a 360 melee/bullet dodge. (TODO)" },
		{ "Taunt", "Unarmed, M1 is a 2s taunt that stores a miracle. (TODO)" },
	},

	abilities = {
		-- A forward slash ragdolling anyone hit backward (perfect-blockable). Airborne: lunges 15-20 studs first.
		-- TODO ragdoll variants "Stinger" (10) and "Million Stab" (use again, 16); special variant "Ankle Cutter".
		[ 1 ] = K.Melee{ "Ambush", cooldown = 15, startup = 0.3, damage = 12, reach = 9, type = "melee", block = "pre", ragdoll = { h = 45, v = 15 },
			air = { lunge = 17 } },
		-- A quick stab that momentarily stuns; from behind the stun lasts much longer.
		-- TODO special variant "High Time": the hand rises spinning, pulling targets up (12).
		[ 2 ] = K.Melee{ "Backstab", cooldown = 12, startup = 0.25, damage = 8, reach = 8, type = "melee", block = "none", stun = 0.8,
			onHit = function( ply, victim )
				if JJS.Util.YawForward( victim:EyeAngles().y ):Dot( JJS.Util.Flat( victim:GetPos() - ply:GetPos() ) ) > 0.3 then
					JJS.Stun( victim, 2 )
				end
			end },
		-- A kick (7) making the target fall face-first (4). Moving enemies lose ragdoll cancel.
		[ 3 ] = K.Melee{ "Trip", cooldown = 14, startup = 0.3, damage = 11, hits = 2, interval = 0.3, type = "melee", bypassRagdoll = true,
			ragdoll = { h = 10, v = -15 } },
		-- Throws the sword to pierce enemies up to 60 studs away, leaving the user unarmed; it then chases the last enemy hit.
		-- TODO special variant "Dirty Play": calls it back, slicing through targets (8).
		[ 4 ] = K.Projectile{ "Cheap Shot", cooldown = 15, startup = 0.3, damage = 7, range = 60, speed = 200, radius = 2.5, pierce = true, type = "bullet",
			bypassRagdoll = true, color = "gold" },
	},
	-- Aiming at a target within 150 studs, the Hand Sword latches off and follows them, keeping 5 studs behind their back.
	special = K.Target{ "Helping Hand", cooldown = 5, teleport = false, noHit = true, range = 150, startup = 0.2, endlag = 0.1, color = "gold" },

	-- Unarmed (even in stun): the Hand Sword slides back and hurls itself handle-first into the target's jaw (25, heals 25),
	-- impairing them for 8s.
	awakenMove = K.Projectile{ "Jawbreaker", startup = 0.5, damage = 25, range = 120, speed = 260, radius = 3, type = "explosion", block = "none",
		uninterruptible = true, heal = 25, slow = { 0.5, 8 }, ragdoll = { h = 60, v = 25 }, color = "gold" },

	OnSpawn = function( ply ) ply:SetJRes1( 3 ) end,
} )

if SERVER then
	hook.Add( "JJS_PreventDeath", "JJS_Miracles", function( victim )
		if victim:GetJChar() ~= "luckycoward" or victim:GetJRes1() < 3 then return end
		victim:SetJRes1( victim:GetJRes1() - 3 )
		victim:SetJHP( 12.5 )
		victim:SetHealth( 13 )
		JJS.IFrames( victim, 1 )
		JJS.Util.Effect( "jjs_kit_cast", JJS.Util.BodyCenter( victim ), nil, victim, 2, JJS.Kit.COLOR_ID.gold )
		return true
	end )
	return
end

function LC.HUDPaint( ply, now, S )
	local n = math.floor( ply:GetJRes1() + 0.5 )
	local x, y = ScrW() / 2 - S( 60 ), ScrH() - S( 160 )
	for i = 1, 6 do
		if i <= n then surface.SetDrawColor( 255, 220, 80 ) else surface.SetDrawColor( 60, 60, 60, 200 ) end
		surface.DrawRect( x + ( i - 1 ) * S( 20 ), y, S( 14 ), S( 14 ) )
	end
end
