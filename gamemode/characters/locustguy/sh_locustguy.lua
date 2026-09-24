-- Locust Guy (base-only). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does.

local K = JJS.Kit

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
		{ "Naturally Selected", "Cosmetic: an extra pair of arms, antennas and wings." },
	},

	abilities = {
		-- Crouches, then charges forward into a barrage of punches that ragdolls then leaves the target stunned (14.2).
		[ 1 ] = K.Melee{ "Clever", cooldown = 15, startup = 0.4, damage = 14.2, hits = 6, interval = 0.15, lunge = 15, type = "melee", stun = 1.2 },
		-- Spits a ball of dark mucus up to 60 studs, ragdolling and weakening the target's attacks by 15% for ~13s (stacks).
		[ 2 ] = K.Projectile{ "Black Mucus", cooldown = 17, startup = 0.5, damage = 8, range = 60, speed = 110, radius = 3, type = "bullet", block = "none",
			bypassRagdoll = true, ragdoll = { h = 35, v = 15 }, color = "black",
			onHit = function( ply, victim ) victim.jjs_mucus = { t = CurTime() + 13, n = ( victim.jjs_mucus and victim.jjs_mucus.t > CurTime() and victim.jjs_mucus.n or 0 ) + 1 } end },
		-- Three biting head swings (4 each); if the third connects, drags the target, throws them up and slams their head down (4).
		[ 3 ] = K.Melee{ "Crushing Jaws", cooldown = 17, startup = 0.3, damage = 16, hits = 4, interval = 0.3, type = "melee", blockDamage = 8,
			armor = "melee", ragdoll = { h = 10, v = -30 }, crater = 900 },
		-- Reaches forward to grab (3) with free flight and melee i-frames, then tosses the target away (5).
		[ 4 ] = K.Grab{ "Wing Throw", cooldown = 15, startup = 0.35, damage = 8, hits = 2, interval = 0.6, type = "melee", bypassRagdoll = true,
			iframes = 0.6, ragdoll = { h = 70, v = 30 } },
	},
	-- Spreads the wings and flies ~25 studs in the facing direction, keeping momentum. An M1 cancels it.
	-- TODO special variant: aiming at an airborne ragdolled enemy within 80 studs starts an air combo (6% awakening).
	special = K.Mobility{ "Fluttering Pounce", cooldown = 16, startup = 0.1, travel = 25, time = 0.45, dir = "aim" },

	-- "I win!" A sting from the insect abdomen that poisons the target (9/s for 10s). Heals 25 if landed.
	awakenMove = K.Melee{ "Directed Poison", startup = 0.8, damage = 0, lunge = 10, type = "explosion", block = "none", bypassRagdoll = true,
		uninterruptible = true, heal = 25, stun = 1, color = "green",
		onHit = function( ply, victim ) victim.jjs_poison = { by = ply, left = 10, dps = 9 } end },
} )

if SERVER then
	-- Black Mucus: each stack weakens the afflicted player's attacks by 15%
	JJS.AddDamageMod( "blackmucus", function( victim, attacker )
		local m = IsValid( attacker ) and attacker.jjs_mucus
		if m and m.t > CurTime() then return math.max( 0.4, 1 - 0.15 * m.n ) end
	end )

	hook.Add( "Tick", "JJS_DirectedPoison", function()
		local dt = engine.TickInterval()
		for _, ply in ipairs( player.GetAll() ) do
			local p = ply.jjs_poison
			if not p then continue end
			if not ply:Alive() or p.left <= 0 then
				ply.jjs_poison = nil
				continue
			end
			p.left = p.left - dt
			JJS.ApplyDamage( ply, IsValid( p.by ) and p.by or nil, p.dps * dt, { type = JJS.DMG.EXPLOSION } )
		end
	end )
end
