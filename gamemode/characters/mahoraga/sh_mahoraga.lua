-- Mahoraga (Eight-Handled Sword Divergent Sila Divine General). Moves are JJS.Kit placeholders
-- built from the wiki numbers; comments describe what the real move does.
-- Obtained through Ten Shadows' "Mahoraga" ritual (also selectable directly here).
-- The awakening bar is the Ritual bar: it drains over 25s and HP drains while it is empty;
-- dealing damage refills it. G cycles the Adaptation Wheel mode, the special confirms it.

local K = JJS.Kit

local MODES = { "Attack", "Defense", "Special" }

local MAHO = K.Character( "mahoraga", {
	name = "Mahoraga",
	category = "complete",
	hp = 150,
	scale = 2,
	model = K.Model( "mahoraga", "models/player/combine_super_soldier.mdl" ),
	color = Color( 235, 235, 235 ),
	barName = "Ritual",

	-- 1.5x regular M1 range, destruction on each M1
	m1 = { HitSize = Vector( 12, 12, 12 ) * JJS.STUD, HitCenter = 5 * JJS.STUD },

	passives = {
		{ "Eight-Handled Divergent Sila Divine General", "2x size, 1.5x M1 range and destruction on every M1." },
		{ "Ritual", "Replaces the awakening: drains for 25s, then drains HP. Landing abilities refills it." },
		{ "Attack Mode: Sword of Extermination", "Much shorter M1 windup. (TODO)" },
		{ "Defense Mode: Parry", "M1 becomes a 0.35s counter stance dealing 15. (TODO)" },
		{ "Special Mode: Sword of Extermination", "The last two M1s are unblockable. (TODO)" },
	},

	abilities = {
		-- Swings an arm to grab forward; the caught opponent is slammed twice (4 each) then punched away (4).
		[ 1 ] = K.Grab{ "Divine Pummel", cooldown = 12, damage = 15, hits = 4, interval = 0.35, reach = 8, width = 10, type = "melee",
			block = "none", bypassRagdoll = true, crater = 1000, ragdoll = { h = 55, v = 20 } },
		-- Grabs debris (trapping a close target: 5) and throws it at the nearest target in view (20).
		[ 2 ] = K.Projectile{ "Ground Pitch", cooldown = 20, startup = 0.7, damage = 25, speed = 120, range = 90, radius = 8, type = "bullet",
			block = "none", bypassRagdoll = true, explode = 10, crater = 1200, ragdoll = { h = 55, v = 25 }, color = "brown" },
		-- Slams its fist into the floor, smashing anyone in front.
		-- Hold variant: released after ~0.85s, a second larger shockwave lifts enemies (25 total, unblockable).
		[ 3 ] = K.AoE{ "Earthquake", cooldown = 15, startup = 0.5, damage = 12.5, radius = 14, offset = 12, type = "melee", bypassRagdoll = true,
			crater = 1400, color = "brown", ragdoll = { h = 20, v = 20 },
			hold = { time = 0.85, damage = 25, hits = 2, interval = 0.35, radius = 20, block = "none", ragdoll = { h = 10, v = 60 } } },
		-- Mode dependent (Adaptation Wheel)
		[ 4 ] = K.ByMode{
			-- Attack: aiming within 70 studs, crouches, dashes to the target and swings upward (cooldown halved on hit).
			K.Target{ "Takedown", cooldown = 15, range = 70, startup = 0.35, damage = 12.5, type = "melee", block = "none", bypassRagdoll = true,
				ragdoll = { h = 10, v = 60 } },
			-- Defense: adapts to the attack it is struck by: heals 15, refills the Ritual and gains lasting resistance to that damage type.
			K.Counter{ "Adaptation", cooldown = 5, window = 0.4, riposte = 0, heal = 15,
				counters = { melee = "evade", bullet = "evade", explosion = "evade", swarm = "evade", domain = "evade" } },
			-- Special: a ranged slash that cuts through space, travelling forward and piercing through targets.
			K.Beam{ "World Slash", cooldown = 30, startup = 0.9, damage = 40, range = 120, radius = 2, pierce = true, type = "special",
				block = "none", bypassRagdoll = true, color = "white", ragdoll = { h = 50, v = 20 } },
		},
	},
	-- Confirms the Adaptation Wheel mode (G cycles it): Attack, Defense, Special
	special = K.Modes{ "Adaptation Wheel", cooldown = 1, modes = MODES },

	OnSpawn = function( ply )
		-- the Ritual starts from the summoner's awakening (at least 40%)
		ply:SetJAwaken( math.max( 0.4, ply:GetJAwaken() ) )
	end,

	-- G cycles the wheel; Mahoraga never awakens
	AwakenPress = function( ply )
		ply:SetJMode( ( ply:GetJMode() + 1 ) % #MODES )
		return true
	end,

	NoRegen = function( ply ) return ply:GetJAwaken() <= 0 end,
} )

if SERVER then
	function MAHO.Think( ply, now )
		local dt = engine.TickInterval()
		ply:SetJAwaken( math.max( 0, ply:GetJAwaken() - dt / 25 ) )
		if ply:GetJAwaken() <= 0 then
			JJS.ApplyDamage( ply, nil, 6 * dt, { type = JJS.DMG.SPECIAL } )
		end
	end
end

-- Adaptation (defense mode counter) also refills the Ritual
hook.Add( "JJS_Hit", "JJS_MahoragaRitual", function( victim, hit, res )
	local a = hit.attacker
	if IsValid( a ) and a:IsPlayer() and a:GetJChar() == "mahoraga" and hit.kit then
		a:SetJAwaken( math.min( 1, a:GetJAwaken() + 0.1 ) )
	end
end )
