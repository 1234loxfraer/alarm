-- Vessel (Yuji Itadori). Moves are JJS.Kit placeholders built from the JJS fandom wiki and the
-- dogslamloop frame data wiki (frames are 60 fps); comments describe what the real move does.

local K = JJS.Kit
local F = K.F
local S = JJS.STUD

-- Black Flash Chain: a Black Flash on the target's back stuns instead (7, 14 on interruption), keeps Divergent Fist off
-- cooldown and resets the side dash; up to 4 in a row, the 4th a heavy one (15)
local function Chain( ply ) return ply.jjs_bfChain and CurTime() < ply.jjs_bfChain.t and ply.jjs_bfChain.n or 0 end

K.Character( "vessel", {
	name = "Vessel",
	category = "complete",
	hp = 85,
	model = K.Model( "vessel", "models/player/group01/male_03.mdl" ),
	color = Color( 255, 110, 110 ),

	abilities = {
		-- 30f pose, then a 28-32 stud lunge with a 55f hitbox (can't curve). On contact: grab (4), punches (1.75 each)
		-- and a kick (3); the user gets melee + bullet i-frames for the 113f self stun, the target is stunned 161f.
		-- Whiff: 25f endlag. Blocked (360 blockable): 46f endlag.
		-- Air variant: a cursed-energy dropkick toward the ground (14, unblockable, hits ragdolls); can't be feinted
		-- after the downward motion, very punishable on whiff.
		[ 1 ] = K.Rush{ "Cursed Strikes", cooldown = 14, startup = F( 30 ), travel = 30, time = F( 55 ), hits = 8, interval = 0.24,
			hitDamage = { 4, 1.75, 1.75, 1.75, 1.75, 1.75, 1.75, 3 }, type = "melee", block = "all", endlag = 0.1, whiffEndlag = F( 25 ),
			blockEndlag = F( 46 ), iframesOnHit = F( 113 ), ragdoll = { h = 45, v = 18 },
			air = { kind = "melee", damage = 14, hits = 1, hitDamage = false, block = "none", bypassRagdoll = true, startup = 0.35, lunge = 10,
				height = 20, endlag = 0.5, ragdoll = { h = 10, v = -30 } } },
		-- Charges cursed energy and slams the floor twice (6 each) with a shockwave (3). Unblockable, hits ragdolls,
		-- interruptible during the startup, very small hitbox.
		-- Air variant: dashes across the air, grabs and does the same attack; blockable from all sides, can be
		-- feinted during the hop for forward air movement.
		[ 2 ] = K.Melee{ "Crushing Blow", cooldown = 15, startup = 0.45, damage = 15, hits = 3, interval = 0.3, hitDamage = { 6, 6, 3 },
			reach = 5, width = 5, type = "melee", block = "none", bypassRagdoll = true, crater = 900, ragdoll = { h = 6, v = -20 },
			air = { kind = "rush", travel = 20, time = 0.4, startup = 0.25, block = "all" } },
		-- A blow (5, blockable) followed by delayed cursed energy that launches the opponent back (5, unblockable).
		-- Interruption variant: if the delayed energy interrupts an action, it stuns instead of launching.
		-- Follow-up "Black Flash": pressed again as the arm is pulled back and the body flashes white (10, 20 on interruption).
		-- "Black Flash Chain": landed on the target's back, it stuns instead of ragdolling and the move stays available: up
		-- to 4 in a row (7, 14 on interruption; the 4th a heavy "KOKUSEN", 15), each resetting the side dash.
		[ 3 ] = K.Melee{ "Divergent Fist", cooldown = 18, startup = 0.35, hits = 2, interval = 0.35, hitDamage = { 5, 5 }, hitBlock = { "normal", "none" },
			type = "melee", ragdoll = { h = 45, v = 16 }, interrupt = { stun = 1.2 }, tip = "USE TWICE",
			again = K.Melee{ "Black Flash", window = 0.5, startup = 0.15, damage = 10, type = "melee", block = "none", trueRag = true,
				color = "black", interrupt = { damage = 10 }, ragdoll = { h = 60, v = 20 } } },
		-- Counter stance (0.6s window): a melee or bullet attack is evaded and answered with a kick (8.5, unblockable,
		-- true ragdoll, hits ragdolls and anyone else in the way). Can't be feinted.
		[ 4 ] = K.Counter{ "Manji Kick", cooldown = 20, window = 0.6, counters = { melee = "counter", bullet = "counter" }, riposte = 8.5 },
	},
	-- During an M1 or a skill's windup (not Manji Kick): cancels it with no endlag and keeps the move off cooldown.
	-- Costs 3% awakening (not required).
	-- TODO special variant: near a throwable, punches it forward (15, bullet; needs throwables in the gamemode).
	special = K.Feint{ "Combat Instincts", cooldown = 2, awakenCost = 0.03 },

	awakening = {
		name = "King of Curses",
		duration = 60,
		heal = 45,
		-- The user faints as Sukuna takes over: "You're such an annoying brat."
		-- Shrine: M1s become quick slashes reaching 24 studs instead of 8, blockable from all sides; no uppercuts or downslams.
		m1 = { HitSize = Vector( 24, 8, 8 ) * S, HitCenter = 11 * S, BlockAll = true, NoLaunch = true },
		abilities = {
			-- A barrage of Dismantle slashes on the opponent in front (17.5, 10 if blocked, 360 blockable).
			-- Air variant: a flip into a long Dismantle slash (25, explosion, unblockable).
			-- "World Cutting Slash": Rush during Dismantle's windup, then Open, then Cleave, chanting "SCALE OF THE DRAGON",
			-- "RECOIL", "TWIN METEORS": total i-frames and a massive horizontal slash cutting the world itself (80, less the
			-- more it hits). Needs Dismantle and Cleave off cooldown; Open goes on its full cooldown and Dismantle's doubles.
			-- Started airborne, it's done midair with 360 aim.
			[ 1 ] = K.Projectile{ "Dismantle", cooldown = 13, startup = 0.35, damage = 17.5, blockDamage = 10, range = 30, speed = 220, radius = 4,
				type = "bullet", block = "all", bypassRagdoll = true, color = "red",
				air = { damage = 25, blockDamage = false, block = "none", type = "explosion", explode = 10 },
				combo = { [ 3 ] = { kind = "stub", free = true, name = "SCALE OF THE DRAGON", startup = 0.6, endlag = 0.1, iframes = 2.5,
					combo = { [ 2 ] = { kind = "stub", free = true, name = "RECOIL", startup = 0.6, endlag = 0.1, combo = false,
						special = { kind = "beam", name = "World Cutting Slash", specialCooldown = 12, startup = 0.5, damage = 80, range = 150,
							radius = 10, pierce = true, maxPitch = 1, type = "explosion", block = "none", bypassRagdoll = true, color = "red",
							crater = 2200, ragdoll = { h = 70, v = 25 },
							onUse = function( ply )
								JJS.SetCooldown( ply, 2, 40 )
								JJS.SetCooldown( ply, 1, 26 )
							end } } } } } },
			-- Fire gathered into an arrow and shot forward (30).
			[ 2 ] = K.Projectile{ "Open", cooldown = 40, startup = 1.2, damage = 30, range = 110, speed = 170, radius = 5, type = "explosion",
				block = "none", bypassRagdoll = true, uninterruptible = true, explode = 16, color = "orange", crater = 1600,
				ragdoll = { h = 60, v = 30 } },
			-- Rushes forward in a straight line at incredible speed: impact (5), kick (15), slam (5).
			[ 3 ] = K.Rush{ "Rush", cooldown = 15, startup = 0.2, travel = 35, time = 0.35, hits = 3, interval = 0.3, hitDamage = { 5, 15, 5 },
				type = "melee", block = "none", ragdoll = { h = 10, v = -25 }, crater = 900 },
			-- Domain Expansion: constant slashes on everyone inside (2 per slash, 0.5 if blocked) for 18s.
			[ 4 ] = K.Domain{ "Malevolent Shrine", cooldown = 120, duration = 18, sureHit = "damage", dps = 12, color = "red" },
		},
		-- Grabs forward and cleaves: 40% of the target's HP, minimum 10.
		special = K.Grab{ "Cleave", cooldown = 12, damage = 10, hits = 2, interval = 0.3, type = "melee", block = "none", ragdoll = { h = 30, v = 20 },
			onHit = function( ply, victim ) JJS.ApplyDamage( victim, ply, math.max( 0, victim:GetJHP() * 0.4 - 10 ), { type = JJS.DMG.MELEE } ) end },
	},
} )

-- Black Flash Chain
local vs = JJS.Characters.vessel
local df = vs.abilities[ 3 ]
local dfAgain = df.Again
df.Again = function( ply, mv, slot )
	-- mid-chain: straight into the next Black Flash
	if Chain( ply ) > 0 and ply:Alive() and not ply:GetJRagdolled() and not JJS.IsStunned( ply ) then
		if JJS.GetAction( ply ) then JJS.StopAction( ply, true ) end
		-- back on cooldown unless this one lands on the back again
		JJS.SetCooldown( ply, 3, df.cooldown or 18 )
		df.again.Use( ply, mv, 0 )
		return true
	end
	return dfAgain and dfAgain( ply, mv, slot ) or false
end

if SERVER then
	hook.Add( "JJS_PreHit", "JJS_BlackFlashChain", function( victim, hit )
		local a = hit.attacker
		if not hit.kit or hit.kit.name ~= "Black Flash" or not IsValid( a ) or a:GetJChar() ~= "vessel" then return end
		local back = JJS.Util.YawForward( victim:EyeAngles().y ):Dot( JJS.Util.Flat( victim:GetPos() - a:GetPos() ) ) > 0.3
		if not back then a.jjs_bfChain = nil return end
		local n = Chain( a ) + 1
		a.jjs_bfChain = { n = n, t = CurTime() + 1.6 }
		if n >= 4 then
			hit.damage = 15
			a.jjs_bfChain = nil
			return
		end
		hit.damage = hit.interrupted and 14 or 7
		hit.ragdoll = nil
		hit.stun = 1.3
		hit.jjs_bfChain = true
	end )
	hook.Add( "JJS_Hit", "JJS_BlackFlashChain", function( victim, hit, res )
		if not hit.jjs_bfChain or res ~= "hit" then return end
		JJS.SetCooldown( hit.attacker, 3, 0 )
		hit.attacker:SetJDashSideCD( 0 )
	end )
end
