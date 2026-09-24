-- Mahoraga (Eight-Handled Sword Divergent Sila Divine General). Moves are JJS.Kit placeholders built from the JJS
-- fandom wiki; comments describe what the real move does.
-- Obtained through Ten Shadows' "Mahoraga" ritual (also selectable directly here).
--
-- Ritual (replaces the awakening bar): starts at the summoner's awakening (40% at least), drains over 25s, and while
-- empty the health drains quickly. Landing any ability refills it (not Ground Pitch or World Slash).
-- Adaptation Wheel: G cycles the selected mode (JJSWheelSel), the special confirms it (JMode) or, if already
-- confirmed, quick-swaps to the next. Modes change the M1s and the 4th move: Attack (red sword), Defense (green
-- shield), Special (blue star).

local K = JJS.Kit
local S = JJS.STUD

local MODES = { "Attack", "Defense", "Special" }
local ATTACK, DEFENSE, SPECIAL = 0, 1, 2

local DMG_NAMES = { [ JJS.DMG.MELEE ] = "Melee", [ JJS.DMG.BULLET ] = "Bullet", [ JJS.DMG.EXPLOSION ] = "Explosion",
	[ JJS.DMG.SWARM ] = "Swarm", [ JJS.DMG.DOMAIN ] = "Domain" }

-- Adaptation: resistance to the damage type it was struck by (10%, +20% for the same type again, 70% max; a new type
-- replaces the old one at 10%). Adapting inside Infinite Void or Shining Sea of Growing Branches makes it immune to
-- that domain's sure-hit instead (for its duration, the resistance kept).
local function Adapt( ply, attacker, hit )
	JJS.Heal( ply, 15 )
	ply:SetJAwaken( 1 )
	JJS.SetCooldown( ply, 4, 2 )
	local t = hit.type
	if not DMG_NAMES[ t ] then return end
	local pct = ply:GetNW2Int( "JJSAdaptType", 0 ) == t and math.min( 0.7, ply:GetNW2Float( "JJSAdaptPct", 0 ) + 0.2 ) or 0.1
	ply:SetNW2Int( "JJSAdaptType", t )
	ply:SetNW2Float( "JJSAdaptPct", pct )
end

local SPECIAL_DOMAINS = { [ "Infinite Void" ] = true, [ "Shining Sea of Growing Branches" ] = true }

-- Defense mode M1: a swift 0.35s block stance; struck, the arms swing outward (15) while withstanding the hit
local PARRY = K.Build( "mahoraga", "parry", K.Counter{ "Parry", window = 0.35, endlag = 0.25, riposte = 15, counters = { melee = "counter",
	bullet = "evade", explosion = "counter", swarm = "counter" } } )

local MAHO = K.Character( "mahoraga", {
	name = "Mahoraga",
	category = "complete",
	hp = 150,
	scale = 2,
	model = K.Model( "mahoraga", "models/player/combine_super_soldier.mdl" ),
	color = Color( 235, 235, 235 ),
	barName = "Ritual",

	-- 1.5x regular M1 range, destruction on each M1, stronger uppercuts (Sword of Extermination)
	m1 = { HitSize = Vector( 12, 12, 12 ) * S, HitCenter = 5 * S, Final = {
		[ 0 ] = { h = 50 * S, v = 24 * S, ragdoll = 0.8 },
		[ 1 ] = { h = 8 * S, v = 95 * S, ragdoll = 0.9 },
		[ 2 ] = { h = 6 * S, v = -80 * S, ragdoll = 1.0 },
	} },
	-- Attack mode: a much shorter M1 windup
	m1Alt = { Startup = 0.1, Frames = { { 6, 8, 17 }, { 6, 8, 17 }, { 6, 8, 17 } } },
	M1Alt = function( ply ) return ply:GetJMode() == ATTACK end,

	passives = {
		{ "Eight-Handled Divergent Sila Divine General", "2x size, 1.5x M1 range, destruction on every M1, stronger uppercuts." },
		{ "Ritual", "Replaces the awakening: drains for 25s, then drains HP. Landing abilities refills it." },
		{ "Attack Mode: Sword of Extermination", "Much shorter M1 windup." },
		{ "Defense Mode: Parry", "M1 becomes a 0.35s counter stance dealing 15." },
		{ "Special Mode: Sword of Extermination", "The last two M1s are unblockable." },
	},

	abilities = {
		-- Swings an arm to grab forward; the caught opponent is slammed on the ground twice then punched away
		-- (3 + 4 + 4 + 4, unblockable).
		[ 1 ] = K.Grab{ "Divine Pummel", cooldown = 12, hits = 4, interval = 0.35, hitDamage = { 3, 4, 4, 4 }, reach = 8, width = 10, type = "melee",
			block = "none", bypassRagdoll = true, crater = 1000, ragdoll = { h = 55, v = 20 } },
		-- Grabs a chunk of debris (a target close enough is picked up and trapped inside, 5) and throws it at the nearest
		-- target in view (20, the hitbox scaling with the debris). Nothing picked up: cancelled (TODO).
		[ 2 ] = K.Projectile{ "Ground Pitch", cooldown = 20, startup = 0.7, damage = 20, speed = 120, range = 90, radius = 8, type = "bullet",
			block = "none", bypassRagdoll = true, explode = 10, crater = 1200, ragdoll = { h = 55, v = 25 }, color = "brown",
			onUse = function( ply )
				for _, v in ipairs( K.SphereTargets( JJS.Util.BodyCenter( ply ) + K.Fwd( ply ) * 5 * S, 6 * S, ply, true ) ) do
					JJS.Hit( v, { attacker = ply, damage = 5, type = JJS.DMG.MELEE, block = "none", bypassRagdoll = true,
						ragdoll = { time = 1, vel = K.Fwd( ply ) * 55 * S + Vector( 0, 0, 25 * S ) } } )
				end
			end },
		-- Slams a fist into the floor, smashing anyone in front (12.5, blockable). Held and released after 0.8-0.9s: a
		-- second larger shockwave lifts enemies (12.5 more, unblockable).
		[ 3 ] = K.AoE{ "Earthquake", cooldown = 15, startup = 0.5, damage = 12.5, radius = 14, offset = 12, type = "melee", bypassRagdoll = true,
			crater = 1400, color = "brown", ragdoll = { h = 20, v = 20 },
			hold = { time = 0.85, damage = 25, hits = 2, interval = 0.35, radius = 20, block = "none", ragdoll = { h = 10, v = 60 } } },
		-- Mode dependent (Adaptation Wheel)
		[ 4 ] = K.ByMode{
			-- Attack: aiming within 70 studs, crouches and dashes to the target in a split second, swinging upward (12.5;
			-- 7s if it lands, 15s on a miss).
			K.Target{ "Takedown", cooldown = 15, range = 70, startup = 0.35, damage = 12.5, type = "melee", block = "none", bypassRagdoll = true,
				ragdoll = { h = 10, v = 60 }, onHit = function( ply ) JJS.SetCooldown( ply, 4, 7 ) end },
			-- Defense: lowers its guard as the wheel glows (0.4s): struck, the wheel turns: heals 15, a full Ritual, 2s cooldown
			-- (5s on a miss, 15s against the special domains) and a lasting resistance (see Adapt).
			K.Counter{ "Adaptation", cooldown = 5, window = 0.4, uninterruptible = true,
				counters = { melee = "evade", bullet = "evade", explosion = "evade", swarm = "evade", domain = "evade", special = "evade" },
				onUse = function( ply )
					for _, d in ipairs( JJS.Domain.All() ) do
						if d:GetCaster() ~= ply and ply:GetNW2Entity( "JJSDomain" ) == d and SPECIAL_DOMAINS[ d:GetDomainName() ] then
							ply.jjs_adaptedDomain = d
							JJS.SetCooldown( ply, 4, 15 )
						end
					end
				end,
				onCounter = function( ply, attacker, hit ) Adapt( ply, attacker, hit ) end },
			-- Special: winds up a swing of the Sword of Extermination and fires a slash cutting through space, traveling in a
			-- straight line through targets (40; a deceptively small hitbox).
			K.Beam{ "World Slash", cooldown = 30, startup = 0.9, damage = 40, range = 120, radius = 2, pierce = true, type = "special",
				block = "none", bypassRagdoll = true, color = "white", ragdoll = { h = 50, v = 20 } },
		},
	},
	-- Confirms the selected wheel mode, or quick-swaps to the next when it's already confirmed
	special = {
		name = "Adaptation Wheel",
		cooldown = 1,
		tip = function( ply )
			local sel = ply:GetNW2Int( "JJSWheelSel", 0 )
			local mode = MODES[ ply:GetJMode() + 1 ]
			return sel ~= ply:GetJMode() and ( ">" .. string.upper( MODES[ sel + 1 ] ) ) or string.upper( mode )
		end,
		CanUse = function( ply ) return ply:Alive() end,
		Use = function( ply )
			JJS.SetCooldown( ply, 5, 1 )
			local sel = ply:GetNW2Int( "JJSWheelSel", 0 )
			if sel == ply:GetJMode() then sel = ( sel + 1 ) % #MODES end
			ply:SetJMode( sel )
			ply:SetNW2Int( "JJSWheelSel", sel )
		end,
	},

	OnSpawn = function( ply )
		-- the Ritual starts from the summoner's awakening (at least 40%)
		ply:SetJAwaken( math.max( 0.4, ply:GetJAwaken() ) )
		ply:SetNW2Int( "JJSAdaptType", 0 )
		ply:SetNW2Float( "JJSAdaptPct", 0 )
		ply:SetNW2Int( "JJSWheelSel", ply:GetJMode() )
	end,

	-- G cycles the selected wheel mode; Mahoraga never awakens
	AwakenPress = function( ply )
		ply:SetNW2Int( "JJSWheelSel", ( ply:GetNW2Int( "JJSWheelSel", 0 ) + 1 ) % #MODES )
		return true
	end,

	-- Defense mode: M1 is the parry stance
	M1Override = function( ply, mv )
		if ply:GetJMode() ~= DEFENSE then return false end
		if JJS.IsBusy( ply ) or not JJS.CanAct( ply ) or JJS.IsBlocking( ply ) then return true end
		if ( ply.jjs_parryCD or 0 ) > CurTime() then return true end
		ply.jjs_parryCD = CurTime() + 0.6
		PARRY.Use( ply, mv, 0 )
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

	-- landing abilities refills the Ritual (not Ground Pitch or World Slash)
	hook.Add( "JJS_Hit", "JJS_MahoragaRitual", function( victim, hit, res )
		local a = hit.attacker
		if res ~= "hit" or not IsValid( a ) or not a:IsPlayer() or a:GetJChar() ~= "mahoraga" or not hit.kit then return end
		local n = hit.kit.name
		if n == "Ground Pitch" or n == "World Slash" then return end
		a:SetJAwaken( math.min( 1, a:GetJAwaken() + 0.1 ) )
	end )

	-- the adapted damage type
	JJS.AddDamageMod( "JJS_Adaptation", function( victim, attacker, dmg, hit )
		if victim:GetJChar() ~= "mahoraga" then return end
		if victim:GetNW2Int( "JJSAdaptType", 0 ) == hit.type then return 1 - victim:GetNW2Float( "JJSAdaptPct", 0 ) end
	end )

	-- Special mode: the 3rd and 4th M1s are unblockable
	hook.Add( "JJS_PreHit", "JJS_MahoragaSpecial", function( victim, hit )
		local a = hit.attacker
		if hit.isM1 and IsValid( a ) and a:IsPlayer() and a:GetJChar() == "mahoraga" and a:GetJMode() == SPECIAL and ( hit.m1Index or 0 ) >= 3 then
			hit.block = "none"
		end
	end )
end

-- adapted to a special domain: immune to its sure-hit while it lasts
hook.Add( "JJS_DomainImmune", "JJS_Adaptation", function( ply, d )
	if IsValid( ply.jjs_adaptedDomain ) and ( not d or ply.jjs_adaptedDomain == d ) then return true end
end )
