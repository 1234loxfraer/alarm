-- Puppet Master (Kokichi Muta / Mechamaru). Moves are JJS.Kit placeholders built from the JJS fandom wiki and the
-- dogslamloop frame data wiki; comments describe what the real move does.
--
-- Offload (special): the puppet's next move (Boost On excluded) is done by an expendable copy that self destructs
-- when done or hit (3, no stun); the move stays off cooldown and the user is free meanwhile. Lasts 15s, can be
-- turned on during a skill (not while stunned). Used on cooldown it becomes Übercharge (red, 10% awakening): the
-- move then goes on cooldown and pressing the special again cancels it. With a plain Offload on, the special
-- aimed at a target within 100 studs calls Puppet Barrage instead.
-- Energy Reserves: once the awakening bar is full, a second bar fills 50% faster; it's the mech's fuel, in years
-- (1 year = 10s of Absolute, 8s to 180s). Absolute's moves burn years.

local K = JJS.Kit

local YEAR = 10 -- seconds of Absolute per year of stored energy

local function Offloaded( ply ) return ply:GetNW2Float( "JJSOffload", 0 ) > CurTime() end
local function Uber( ply ) return Offloaded( ply ) and ply:GetNW2Bool( "JJSUber", false ) end

-- An offloaded move uses the copy up: no cooldown (`cd` seconds) unless it was an Übercharge
local function Consume( cd )
	return function( ply )
		local uber = Uber( ply )
		ply:SetNW2Float( "JJSOffload", 0 )
		ply:SetNW2Bool( "JJSUber", false )
		if not uber then JJS.SetCooldown( ply, ply:GetJActVar(), cd ) end
	end
end

-- The copy self destructs: a small explosion with no stun, knockback or ragdoll
local BLOWUP = K.Params( K.AoE{ "Puppet Explosion", damage = 3, radius = 6, type = "explosion", block = "all", stun = 0, color = "cyan" } )
local function SelfDestruct( ply, target )
	if CLIENT then return end
	local pos = IsValid( target ) and target:GetPos() or ply:GetPos() + K.Fwd( ply ) * 60
	for _, v in ipairs( K.SphereTargets( pos + Vector( 0, 0, 36 ), BLOWUP.radius, ply, false ) ) do
		local hit = K.MakeHit( ply, BLOWUP, v, 1, pos )
		hit.stun = nil
		JJS.Hit( v, hit )
	end
	K.Effect( "jjs_kit_burst", pos + Vector( 0, 0, 30 ), Vector( 0, 0, 1 ), ply, BLOWUP.radius, BLOWUP )
end

-- Offloaded Ultra Cannon: the copy keeps the cannon wound up, aimed at the cursor, until the user blocks
local HELD = K.Params( K.Projectile{ "Offloaded Ultra Cannon", damage = 7, speed = 320, range = 90, radius = 3, type = "explosion",
	block = "all", bypassRagdoll = true, color = "cyan", ragdoll = { h = 40, v = 20 } } )

-- Awakened moves burn years of stored energy (shortening Absolute) and reset Energy Output
local function Years( n )
	return function( ply )
		ply:SetJAwakenEnd( ply:GetJAwakenEnd() - n * YEAR )
		ply:SetJMode( 0 )
	end
end

local BARRAGE = K.Build( "puppetmaster", "barrage", K.Target{ "Puppet Barrage", range = 100, cone = 0.9, startup = 0.5, endlag = 0.4, hits = 2,
	interval = 0.6, hitDamage = { 6, 8 }, type = "melee", block = "all", bypassRagdoll = true, ragdoll = { h = 5, v = -40 }, color = "cyan" } )

-- The special: Offload, Übercharge, Puppet Barrage
local OFFLOAD = {
	name = "Offload",
	cooldown = 10,
	tip = function( ply )
		if Uber( ply ) then return "ÜBERCHARGE" end
		if Offloaded( ply ) then return "BARRAGE" end
		if JJS.GetCooldown( ply, 5 ) > CurTime() then return "ÜBER 10%" end
	end,
	CanUse = function( ply ) return ply:Alive() and not ply:GetJRagdolled() and not JJS.IsStunned( ply ) end,
	-- checked before the cooldown: the special variants
	Again = function( ply, mv, slot )
		if not ply:Alive() or ply:GetJRagdolled() or JJS.IsStunned( ply ) then return false end
		if Uber( ply ) then
			ply:SetNW2Float( "JJSOffload", 0 )
			ply:SetNW2Bool( "JJSUber", false )
			return true
		end
		if Offloaded( ply ) then
			if not JJS.IsBusy( ply ) and IsValid( K.AimTarget( ply, 100 * JJS.STUD, 0.9 ) ) then
				ply:SetNW2Float( "JJSOffload", 0 )
				BARRAGE.Use( ply, mv, 0 )
			end
			return true
		end
		if JJS.GetCooldown( ply, slot ) > CurTime() and ply:GetJAwaken() >= 0.1 then
			ply:SetJAwaken( ply:GetJAwaken() - 0.1 )
			ply:SetNW2Float( "JJSOffload", CurTime() + 15 )
			ply:SetNW2Bool( "JJSUber", true )
			JJS.SetCooldown( ply, slot, 10 )
			if SERVER then JJS.Util.Effect( "jjs_kit_cast", JJS.Util.BodyCenter( ply ), nil, ply, 1.2, K.COLOR_ID.red ) end
			return true
		end
		return false
	end,
	Use = function( ply, mv, slot )
		JJS.SetCooldown( ply, slot, 10 )
		ply:SetNW2Float( "JJSOffload", CurTime() + 15 )
		ply:SetNW2Bool( "JJSUber", false )
		if SERVER then JJS.Util.Effect( "jjs_kit_cast", JJS.Util.BodyCenter( ply ), nil, ply, 1.2, K.COLOR_ID.cyan ) end
	end,
}

-- Absolute moves for each Energy Output level (0-5)
local function Levels( make )
	local list = {}
	for lv = 0, 5 do list[ lv + 1 ] = make( lv ) end
	return K.ByMode( list )
end

K.Character( "puppetmaster", {
	name = "Puppet Master",
	category = "complete",
	hp = 85,
	model = K.Model( "puppetmaster", "models/player/combine_soldier.mdl" ),
	color = Color( 140, 170, 190 ),

	-- per-hit M1 frames { startup, recovery, block endlag } (dogslamloop)
	m1 = {
		Frames = { { 14, 5, 11 }, { 11, 9, 19 }, { 11, 9, 19 } },
	},

	passives = {
		{ "Ultimate Proxy", "Cosmetic: a metal forearm guard that sparks on hit (spikes out on Ultra Shield blocks)." },
		{ "Energy Reserves", "Once the awakening bar is full a second one fills 50% faster: years of fuel for Absolute." },
		{ "Offload", "An expendable copy does the next move: no cooldown, the puppet stays free." },
	},

	abilities = {
		-- The right forearm spins with claws out; lunges a medium distance, drills through the torso (9.5) and slams them
		-- into the ground, sending them up with AoE damage (4). Blockable, can't hit grounded ragdolls.
		-- Offloaded: the copy lands in front facing the puppet and does a weaker drill (4.5 + 4, hits grounded ragdolls).
		[ 1 ] = K.Grab{ "Ultra Spin", cooldown = 15, startup = 0.35, hits = 4, interval = 0.25, hitDamage = { 3.5, 3, 3, 4 }, lunge = 15,
			type = "melee", ragdoll = { h = 10, v = 50 },
			cond = { test = Offloaded, onUse = Consume( 0 ), kind = "melee", detached = true, startup = 0.4, lunge = false, hits = 2,
				interval = 0.35, hitDamage = { 4.5, 4 }, reach = 12, bypassRagdoll = true, onDone = SelfDestruct } },
		-- Stands on its hands to grab with its legs (4, unblockable, hits ragdolls), boosts both into the sky and spins
		-- back into a point-blank Ultra Cannon to the gut (6). Can't be offloaded.
		[ 2 ] = K.Grab{ "Boost On", cooldown = 16, startup = 0.35, hits = 2, interval = 0.6, hitDamage = { 4, 6 }, type = "melee", block = "none",
			bypassRagdoll = true, ragdoll = { h = 40, v = 45 } },
		-- Points the left palm and winds up a long blast (10, 360 blockable); holding delays the shot up to a second.
		-- Held 1.3s: "Ultimate Cannon", Mode: Albatross (a cannon out of the mouth, both hands forward): a small explosion
		-- ragdolls everyone around, then a continuous fiery beam for 17 ticks (0.95 each, 16.15, unblockable).
		-- Offloaded: a copy lands to the left and keeps the cannon wound up on the cursor until the user blocks (7; 2s).
		[ 3 ] = K.Beam{ "Ultra Cannon", cooldown = 17, startup = 0.8, damage = 10, range = 60, radius = 3, type = "explosion", block = "all",
			bypassRagdoll = true, color = "cyan", ragdoll = { h = 50, v = 20 }, tip = "HOLD",
			hold = { time = 1.3, damage = 16.15, duration = 1.1, tick = 0.066, block = "none", radius = 5, color = "orange",
				onUse = function( ply )
					for _, v in ipairs( K.SphereTargets( JJS.Util.BodyCenter( ply ), 10 * JJS.STUD, ply, true ) ) do
						JJS.Hit( v, { attacker = ply, damage = 0, type = JJS.DMG.EXPLOSION, block = "none", bypassRagdoll = true,
							ragdoll = { time = 0.8, vel = JJS.Util.Flat( v:GetPos() - ply:GetPos() ) * 30 * JJS.STUD + Vector( 0, 0, 200 ) } } )
					end
				end },
			cond = { test = Offloaded, kind = "stub", startup = 0.1, endlag = 0.1, hold = false,
				onUse = function( ply )
					Consume( 2 )( ply )
					ply.jjs_heldCannon = CurTime() + 12
				end } },
		-- Ejects itself forward with Boost On, then its boosters unleash scorching flames knocking the target up (13,
		-- unblockable). USE TWICE after the hop: "Steam Emission", Boost On turns off early with a smaller blast (9, 360).
		-- Offloaded: a replacement boosts forward in a straight line; colliding with someone it grabs them, spins up and
		-- launches them back at the puppet before exploding (8 + 8, semi blockable); with no one met it ends with a jab
		-- (12, unblockable). TODO: the jab.
		[ 4 ] = K.Melee{ "Heat Emission", cooldown = 16, startup = 0.45, damage = 13, lunge = 15, reach = 10, width = 10, type = "explosion",
			block = "none", bypassRagdoll = true, color = "orange", ragdoll = { h = 10, v = 55 }, tip = "USE TWICE",
			again = K.AoE{ "Steam Emission", window = 0.5, startup = 0.1, damage = 9, radius = 8, offset = 5, type = "explosion", block = "all",
				bypassRagdoll = true, color = "orange", ragdoll = { h = 20, v = 35 } },
			cond = { test = Offloaded, onUse = Consume( 0 ), detached = true, startup = 0.5, lunge = false, reach = 30, width = 6, hits = 2,
				interval = 0.5, hitDamage = { 8, 8 }, type = "melee", block = "normal", ragdoll = { h = -45, v = 20 }, onDone = SelfDestruct } },
	},
	special = OFFLOAD,

	awakening = {
		name = "Absolute",
		duration = 8, -- plus the energy reserves (see JJS_Awakened below)
		hp = 117,
		scale = 3, -- the wiki mech is 5x bigger; 3x keeps it playable on normal maps
		-- Mode: Absolute: the giant mech climbs out of the ground, powers up and roars. Each part is a separate target:
		-- limbs take ~47% damage (averaged here). No ragdoll or stun: hits only force it to walk; every ~17 damage it
		-- kneels (stagger), and a melee hit on a staggered mech is a head stomp (10, -3 years). M1s deal 6 each, the last
		-- two unblockable; no downslam. Front dash: a heavy kick on stunned/ragdolled targets only (10); airborne, an AoE
		-- dropkick (12); jumping has a 2s cooldown. TODO: the dash kicks, jump cooldown, unblockable last M1s.
		-- Last Chance: at 0 HP a puppet hops out for a last drill (15); landing it restores its health, missing kills.
		m1 = { Damage = { 6, 6, 6, 6 } },
		abilities = {
			-- 1 year: an arm blasts the area in front with fire, setting targets ablaze (20). Energy Output 2+: 2 years for a
			-- massive sphere detonating on contact (35); at level 5 the camera tilts its trajectory.
			[ 1 ] = Levels( function( lv )
				if lv >= 2 then
					return K.Projectile{ "Miracle Cannon", cooldown = 8, startup = 0.9, damage = 35, range = 90, speed = 110, radius = 6, explode = 14,
						type = "explosion", block = "none", bypassRagdoll = true, uninterruptible = true, color = "red", crater = 1600,
						ragdoll = { h = 50, v = 30 }, tip = "SPHERE", onUse = Years( 2 ) }
				end
				return K.Beam{ "Miracle Cannon", cooldown = 8, startup = 0.7, damage = 20, range = 50, radius = 10, pierce = true, type = "explosion",
					block = "none", bypassRagdoll = true, uninterruptible = true, color = "orange", ragdoll = { h = 50, v = 25 }, onUse = Years( 1 ) }
			end ),
			-- Aiming at a target within 250 studs: three rainbow beams home in and chase them (5 each). Each Energy Output
			-- level adds a beam and a year (up to 7 beams for 7 years).
			[ 2 ] = Levels( function( lv )
				return K.Target{ "Pigeon Viola", cooldown = 8, teleport = false, range = 250, cone = 0.9, startup = 0.6, hits = 3 + lv,
					interval = 0.2, damage = 5 * ( 3 + lv ), type = "bullet", block = "none", bypassRagdoll = true, uninterruptible = true,
					color = "pink", tip = lv > 0 and ( "LV " .. lv ) or nil, onUse = Years( 3 + lv ) }
			end ),
			-- 1 year: rampages with 3 swarm stomps (4 each), a quick leap (5) and a crushing slam (20). Each level adds a stomp
			-- and a year (level 5: 4 extra, 10 stomps); from level 3 it walks through destructible walls. Airborne: straight
			-- to the slam, thrown forward (20).
			[ 3 ] = Levels( function( lv )
				local stomps = lv == 5 and 10 or 3 + lv
				local dmg = {}
				for i = 1, stomps do dmg[ i ] = 4 end
				dmg[ #dmg + 1 ] = 5
				dmg[ #dmg + 1 ] = 20
				return K.AoE{ "Absolute Destruction", cooldown = 8, startup = 0.4, hits = #dmg, interval = 0.35, hitDamage = dmg, radius = 22,
					offset = 8, type = "explosion", block = "none", bypassRagdoll = true, uninterruptible = true, crater = 2000, color = "orange",
					ragdoll = { h = 30, v = 40 }, tip = lv > 0 and ( "LV " .. lv ) or nil, onUse = Years( 1 + lv ),
					air = { hits = 1, hitDamage = false, damage = 20, onUse = Years( 1 ) } }
			end ),
			-- Aiming within 100 studs, the index finger's compartment locks on for ~2s (it can fire early, less accurately) and
			-- fires a technique-imbued shot (20, +1 and a year per level, more wall penetration). Level 5 adds a Simple
			-- Domain charge (5) that shatters the target's domain.
			[ 4 ] = Levels( function( lv )
				return K.Target{ "Technique Charge", cooldown = 8, teleport = false, range = 100, startup = 1.8 - lv * 0.15, damage = 20 + lv +
					( lv == 5 and 5 or 0 ), type = "explosion", block = "none", bypassRagdoll = true, uninterruptible = true, color = "cyan",
					ragdoll = { h = 10, v = 55 }, tip = lv > 0 and ( "LV " .. lv ) or nil, onUse = Years( 1 + lv ),
					onHit = lv == 5 and function( ply, victim )
						for _, d in ipairs( JJS.Domain.All() ) do
							if d:GetCaster() == victim then JJS.Domain.Collapse( d ) end
						end
					end or nil }
			end ),
		},
		-- Each press raises the cursed energy output (5-segment bar): the next move is stronger and costs more years.
		-- It resets after a move, or when pressed at level 5.
		special = K.Modes{ "Energy Output", cooldown = 0.2, modes = { "LV 0", "LV 1", "LV 2", "LV 3", "LV 4", "LV 5" }, color = "cyan" },
	},
} )

-- Last Chance: the puppet's final drill
local LAST = K.Build( "puppetmaster", "lastchance", K.Rush{ "Last Chance", startup = 0.3, travel = 30, time = 0.5, damage = 15, type = "melee",
	block = "none", bypassRagdoll = true, uninterruptible = true, ragdoll = { h = 30, v = 30 }, color = "cyan",
	onHit = function( ply ) JJS.Heal( ply, 200 ) ply.jjs_lastLanded = true end,
	onEnd = function( ply ) if not ply.jjs_lastLanded then JJS.Kill( ply, nil, { type = JJS.DMG.SPECIAL } ) end end } )

if SERVER then
	-- Energy Reserves: hits landed with a full awakening bar fill the second bar 50% faster (1 = 17.2 years)
	hook.Add( "JJS_Hit", "JJS_EnergyReserves", function( victim, hit )
		local a = hit.attacker
		if not IsValid( a ) or not a:IsPlayer() or a == victim or a:GetJChar() ~= "puppetmaster" then return end
		if a:GetJAwakened() or a:GetJAwaken() < 1 then return end
		local r = a:GetNW2Float( "JJSReserve", 0 )
		a:SetNW2Float( "JJSReserve", math.min( 1, r + ( hit.damage or 0 ) / JJS.Config.Awakening.FullDamage * 1.5 ) )
	end )

	-- Absolute lasts 8s plus 10s per stored year
	hook.Add( "JJS_Awakened", "JJS_EnergyReserves", function( ply )
		if ply:GetJChar() ~= "puppetmaster" then return end
		local extra = ply:GetNW2Float( "JJSReserve", 0 ) * 172
		ply:SetJAwakenEnd( ply:GetJAwakenEnd() + extra )
		ply.jjs_awakenDur = 8 + extra
		ply:SetNW2Float( "JJSReserve", 0 )
		ply.jjs_lastChance = nil
	end )

	-- Mode: Absolute: limbs take about half (averaged to 75%), no ragdoll or stun, staggers every ~17 damage
	JJS.AddDamageMod( "JJS_ModeAbsolute", function( victim )
		if victim:GetJAwakened() and victim:GetJChar() == "puppetmaster" then return 0.75 end
	end )
	hook.Add( "JJS_PreHit", "JJS_ModeAbsolute", function( victim, hit )
		if not victim:GetJAwakened() or victim:GetJChar() ~= "puppetmaster" then return end
		hit.ragdoll = nil
		hit.stun = nil
		hit.knock = nil
	end )
	hook.Add( "JJS_Hit", "JJS_ModeAbsolute", function( victim, hit, res )
		if res ~= "hit" or not victim:GetJAwakened() or victim:GetJChar() ~= "puppetmaster" then return end
		local now = CurTime()
		-- a melee hit on the kneeling mech: head stomp
		if ( victim.jjs_staggerEnd or 0 ) > now and hit.type == JJS.DMG.MELEE and not victim.jjs_stomped then
			victim.jjs_stomped = true
			JJS.ApplyDamage( victim, hit.attacker, 10, { type = JJS.DMG.MELEE } )
			victim:SetJAwakenEnd( victim:GetJAwakenEnd() - 3 * YEAR )
			return
		end
		victim.jjs_stagger = ( victim.jjs_stagger or 0 ) + ( hit.damage or 0 )
		if victim.jjs_stagger >= 17 then
			victim.jjs_stagger = 0
			victim.jjs_staggerEnd = now + 1.7
			victim.jjs_stomped = nil
			JJS.StopAction( victim, true )
			JJS.Stun( victim, 1.7 )
		end
	end )

	-- Last Chance: the mech's HP runs out, a puppet hops out for one last drill
	hook.Add( "JJS_PreventDeath", "JJS_LastChance", function( victim )
		if victim:GetJChar() ~= "puppetmaster" or not victim:GetJAwakened() or victim.jjs_lastChance then return end
		victim.jjs_lastChance = true
		victim.jjs_lastLanded = nil
		JJS.ExitAwakening( victim )
		victim:SetJHP( 1 )
		victim:SetHealth( 1 )
		LAST.Use( victim, nil, 0 )
		return true
	end )

	-- Offloaded Ultra Cannon: blocking fires the copy's held cannon
	hook.Add( "Tick", "JJS_HeldCannon", function()
		for _, ply in ipairs( player.GetAll() ) do
			local t = ply.jjs_heldCannon
			if t then
				if CurTime() > t or not ply:Alive() then
					ply.jjs_heldCannon = nil
				elseif JJS.IsBlocking( ply ) then
					ply.jjs_heldCannon = nil
					local right = ply:EyeAngles():Right()
					K.SpawnProjectile( ply, HELD, JJS.Util.BodyCenter( ply ) - right * 40, ply:GetAimVector() )
				end
			end
		end
	end )
end

hook.Add( "JJS_PlayerSpawned", "JJS_PuppetMaster", function( ply )
	ply:SetNW2Float( "JJSOffload", 0 )
	ply:SetNW2Bool( "JJSUber", false )
	ply:SetNW2Float( "JJSReserve", 0 )
	ply.jjs_heldCannon = nil
	ply.jjs_stagger = nil
end )
