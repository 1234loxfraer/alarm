-- Perfection (Mahito). Moves are JJS.Kit placeholders built from the JJS fandom wiki and the dogslamloop frame data
-- wiki; comments describe what the real move does.
-- The special cycles Self-Transfiguration modes (Normal, Blade, Club), changing the M1s, the front dash and Focus
-- Strike (Body Disfigure while awakened). Front dashing or Focus Strike locks the special for about a second.
-- Awakened, G performs the Awakening Black Flash; landing it twice unlocks the Super Awakening (Instant Spirit Body of
-- Distorted Killing), kept as the awakening's alternate moveset.
-- TODO: Soul Reserves (eating held Transfigured Humans/Flesh, pulled out with M1 while blocking) needs items.

local K = JJS.Kit
local S = JJS.STUD

local MODES = { "Normal", "Blade", "Club" }
local TRANSFIG = K.Modes{ "Self-Transfiguration", cooldown = 1, modes = MODES }

-- the special is locked for ~1s after a front dash or Focus Strike
local function LockSpecial( ply ) JJS.SetCooldown( ply, 5, math.max( 1, JJS.GetCooldown( ply, 5 ) - CurTime() ) ) end

-- Mode front dashes: Blade, a crouch then a long teleporting slice (6.5; stuns, ragdolls the already stunned; 8s);
-- Club, a wide unblockable spin knocking down (8.5; 10s); Super Awakening, "Distorted Dash": a crouch, then a launch
-- with circular slices stunning in place (12, never ragdolls)
local BLADE_DASH = K.Build( "perfection", "bladedash", K.Mobility{ "Blade Dash", startup = 0.3, travel = 48, time = 0.12, damage = 6.5,
	type = "melee", block = "normal", bypassRagdoll = true, stun = 1.2, stunRag = { h = 40, v = 15 }, reach = 10, width = 8 } )
local CLUB_DASH = K.Build( "perfection", "clubdash", K.AoE{ "Club Dash", startup = 0.3, damage = 8.5, radius = 11, offset = 4, type = "melee",
	block = "none", ragdoll = { h = 20, v = -20 } } )
local DISTORTED_DASH = K.Build( "perfection", "distorteddash", K.Mobility{ "Distorted Dash", startup = 0.6, travel = 30, time = 0.25, damage = 12,
	type = "melee", block = "normal", stun = 1.5, reach = 12, width = 12, color = "cyan" } )

local PERF = K.Character( "perfection", {
	name = "Perfection",
	category = "complete",
	hp = 100,
	model = K.Model( "perfection", "models/player/zombie_classic.mdl" ),
	color = Color( 140, 200, 230 ),

	-- per-hit M1 frames { startup, recovery, block endlag } (dogslamloop: safe on block, 13-15f)
	m1 = { Frames = { { 12, 7, 13 }, { 12, 7, 15 }, { 12, 7, 15 } } },
	-- Blade: slightly faster, weaker (2 + 2 + 3 + 3; unsafe on block). Club: much slower, stronger (4 + 4 + 5 + 5), the first
	-- two deal half through block, the last two are unblockable. Super Awakening (Sinister Spurs): faster, 4 + 4 + 5 + 5,
	-- pulling the user in from further.
	m1Alts = {
		blade = { Damage = { 2, 2, 3, 3 }, Frames = { { 10, 8, 15 }, { 10, 9, 21 }, { 10, 9, 19 } } },
		club = { Damage = { 4, 4, 5, 5 }, Frames = { { 18, 9, 26 }, { 18, 9, 25 }, { 18, 9, 25 } }, BlockDamage = { [ 1 ] = 0.5, [ 2 ] = 0.5 },
			UnblockableHits = { [ 3 ] = true, [ 4 ] = true } },
		spurs = { Damage = { 4, 4, 5, 5 }, Frames = { { 10, 6, 13 }, { 10, 6, 13 }, { 10, 6, 13 } }, Pull = 30 * S },
	},
	M1Alt = function( ply )
		if ply:GetJAwakened() and ply:GetJKitSet() == 1 then return "spurs" end
		local m = ply:GetJMode()
		return m == 1 and "blade" or m == 2 and "club" or nil
	end,

	FrontDash = function( ply, mv )
		local now = CurTime()
		if ply:GetJAwakened() and ply:GetJKitSet() == 1 then
			ply:SetJDashFrontCD( now + JJS.Config.Dash.FrontCooldown )
			DISTORTED_DASH.Use( ply, mv, 0 )
		elseif ply:GetJMode() == 1 then
			ply:SetJDashFrontCD( now + 8 )
			BLADE_DASH.Use( ply, mv, 0 )
		elseif ply:GetJMode() == 2 then
			ply:SetJDashFrontCD( now + 10 )
			CLUB_DASH.Use( ply, mv, 0 )
		else
			LockSpecial( ply )
			return false
		end
		LockSpecial( ply )
		return true
	end,

	passives = {
		{ "Blade Mode", "Faster, weaker M1s (2 + 2 + 3 + 3); the front dash becomes a long slice (6.5, 8s)." },
		{ "Club Mode", "Slower, stronger M1s (4 + 4 + 5 + 5), last two unblockable; the front dash becomes an unblockable spin (8.5, 10s)." },
	},

	abilities = {
		-- Two transfigured hammers batter the opponent twice (6 each); only the second swing breaks block and hits grounded
		-- ragdolls, and it's guaranteed if the first lands. Fast startup, high endlag on a miss.
		-- Air variant: hops and slams down with a purple hammer (10, unblockable) launching high enough for an air M1.
		[ 1 ] = K.Melee{ "Stockpile", cooldown = 12, startup = 0.3, damage = 12, hits = 2, interval = 0.35, hitBlock = { "normal", "none" },
			hitBypass = { false, true }, type = "melee", whiffEndlag = 0.7, ragdoll = { h = 60, v = 25 },
			air = { damage = 10, hits = 1, hitBlock = false, hitBypass = false, block = "none", bypassRagdoll = true, ragdoll = { h = 10, v = 55 } } },
		-- Idle Transfiguration on themselves: an arm firing three transfigured humans as bullets (4 each, 100 studs; hits
		-- ragdolls); the first two stun, the last ragdolls, and a miss extends the endlag.
		-- TODO hold variant: shoots stored Transfigured Humans/Flesh (missed humans turn into minions).
		[ 2 ] = K.Projectile{ "Soul Fire", cooldown = 12, startup = 0.35, damage = 4, count = 3, volley = 0.2, range = 100, speed = 150, radius = 3,
			type = "bullet", bypassRagdoll = true, stun = 0.9, color = "green", whiffEndlag = 0.6,
			onHit = function( ply, v )
				-- the third human ragdolls
				v.jjs_soulFire = ( ( v.jjs_soulFireT or 0 ) > CurTime() and v.jjs_soulFire or 0 ) + 1
				v.jjs_soulFireT = CurTime() + 1
				if v.jjs_soulFire >= 3 then JJS.Ragdoll.Apply( v, { time = 0.9, vel = K.Fwd( ply ) * 40 * S + Vector( 0, 0, 15 * S ) }, ply ) end
			end },
		-- Mode dependent
		[ 3 ] = K.ByMode{
			-- Normal: a cursed-energy fist to the torso that pushes back with stun (doesn't hit grounded ragdolls). It keeps
			-- the M1 string and sets it to the 4th M1 when it lands.
			-- Follow-up (timed): pressed again with the arm wound back, a Black Flash (12, breaks block, hits ragdolls,
			-- always ragdolls; slightly punishable on hit).
			K.Melee{ "Focus Strike", cooldown = 15, startup = 0.4, damage = 10, reach = 9, type = "melee", stun = 1, tip = "USE TWICE",
				onUse = LockSpecial,
				onHit = function( ply )
					ply:SetJM1Index( JJS.GetChar( ply ).m1.Count - 1 )
					ply:SetJM1LastEnd( CurTime() )
					ply:SetJM1CD( 0 )
				end,
				again = K.Melee{ "Focus Strike: Black Flash", window = 0.6, startup = 0.15, endlag = 0.5, damage = 12, reach = 9, type = "melee",
					block = "none", bypassRagdoll = true, color = "black", ragdoll = { h = 70, v = 25 } } },
			-- Blade: the arm becomes a chainwhip swinging up, pulling anyone caught toward the user with heavy stun
			-- (360 blockable, hits ragdolls, resets the M1 string).
			K.Melee{ "Chainwhip", cooldown = 15, startup = 0.35, damage = 3, reach = 16, width = 5, type = "melee", block = "all",
				bypassRagdoll = true, stun = 1.6, ragdoll = { h = -30, v = 25, time = 0.5 },
				onHit = function( ply ) ply:SetJM1Index( 0 ) ply:SetJM1CD( 0 ) end },
			-- Club: the arm drastically enlarged swings forward, uppercutting targets away (18, unblockable); one who blocked
			-- right before the hit loses their ragdoll cancel.
			K.Melee{ "Homerun", cooldown = 15, startup = 0.55, damage = 18, reach = 9, width = 10, type = "melee", block = "none",
				bypassRagdoll = true, ragdoll = { h = 40, v = 60 }, onUse = LockSpecial,
				onContact = function( ply, v, p, r ) if r == "hit" and v:GetJBlockStart() > CurTime() - 0.5 and v:GetJRagdolled() then v:SetJTrueRagdoll( true ) end end },
		},
		-- Four transfigured humans combine into an amalgamation ramming everything in front for 70 studs where the user faces
		-- (14, unblockable, hits ragdolls). Focus Strike during the windup: the user rides inside it, without steering (Focus
		-- Strike neither needs nor goes on cooldown).
		[ 4 ] = K.Summon{ "Body Repel", cooldown = 20, startup = 0.5, damage = 14, speed = 70, range = 70, radius = 8, pierce = true,
			block = "none", bypassRagdoll = true, crater = 900, ragdoll = { h = 50, v = 25 }, color = "green",
			combo = { [ 3 ] = { kind = "mobility", free = true, startup = 0.1, travel = 70, time = 1, dir = "forward", damage = 14, type = "swarm",
				reach = 10, width = 10 } } },
	},
	special = TRANSFIG,

	awakening = {
		name = "Essence of the Soul",
		duration = 60,
		heal = 45,
		-- "LET'S KICK IT UP A NOTCH!": a slam releases a swarm of worm-like souls around the user (15, launches upward).
		abilities = {
			-- Rushes to transfigure the first target touched: fails the first time (15) unless they're under 15 HP;
			-- the second catch blows their head up.
			[ 1 ] = K.Melee{ "Idle Transfiguration", cooldown = 15, startup = 0.4, damage = 15, lunge = 20, type = "melee", block = "none",
				bypassRagdoll = true, ragdoll = { h = 40, v = 20 },
				onHit = function( ply, victim )
					victim.jjs_idleTouched = victim.jjs_idleTouched or {}
					if victim.jjs_idleTouched[ ply ] or victim:GetJHP() < 15 then
						JJS.Kill( victim, ply, { type = JJS.DMG.SPECIAL } )
						-- a kill keeps the move off cooldown
						JJS.SetCooldown( ply, 1, 0 )
					end
					victim.jjs_idleTouched[ ply ] = true
				end },
			-- Mode dependent Body Disfigure
			[ 2 ] = K.ByMode{
				-- Normal "Drill Splitter": hoof dropkick (10), then a drill digs into the opponent (25).
				K.Melee{ "Body Disfigure: Drill Splitter", cooldown = 15, startup = 0.4, damage = 35, hits = 2, interval = 0.45, lunge = 15,
					type = "melee", block = "none", bypassRagdoll = true, ragdoll = { h = 20, v = 10 } },
				-- Blade "Heart Piercer": rides tendrils leaving destruction; enemies are grabbed underneath (2.5 per hit, 45 max).
				K.Grab{ "Body Disfigure: Heart Piercer", cooldown = 15, startup = 0.35, damage = 45, hits = 10, interval = 0.15, lunge = 25,
					type = "melee", block = "none", bypassRagdoll = true, trueRag = true, crater = 800 },
				-- Club "Force Grab": an enlarged hand grabs anyone aimed within 40 studs (5), slams (8 each) and tosses (4).
				K.Target{ "Body Disfigure: Force Grab", cooldown = 15, teleport = false, range = 40, startup = 0.45, damage = 25, hits = 4,
					interval = 0.4, type = "bullet", block = "none", bypassRagdoll = true, crater = 900, ragdoll = { h = 45, v = 25 } },
			},
			-- Morphs into a blob sending spikes to latch onto targets within 25 studs, then slams the caught ones into the ground
			-- (25, blockable). Once formed: faster walk speed, melee and bullet i-frames.
			[ 3 ] = K.AoE{ "Spike Wrath", cooldown = 25, startup = 0.9, damage = 25, radius = 25, type = "swarm", bypassRagdoll = true, moveMult = 1.3,
				parry = { window = 1.2, counters = { melee = true, bullet = true }, dodge = true }, crater = 1000, ragdoll = { h = 10, v = -30 },
				color = "green" },
			-- Domain Expansion: a transfiguration meter drains near the caster; once empty the target is destroyed.
			[ 4 ] = K.Domain{ "Embodiment of Self Perfection", cooldown = 120, duration = 14, sureHit = "drain", drainTime = 6, color = "cyan" },
		},
		special = TRANSFIG,

		-- Super Awakening: unlocked by landing the Awakening Black Flash twice (+50s, heals 10)
		alt = {
			name = "Instant Spirit Body of Distorted Killing",
			-- TODO passives: "Sinister Spurs" (M1s pull from further, 4 + 4 + 5 + 5) and "Distorted Dash" (front dash: 12, circular slices).
			abilities = {
				-- Circles a point with eight afterimages (total i-frames) and after 3s shreds whoever stands in the centre.
				[ 1 ] = K.AoE{ "Widespread Strikes", cooldown = 20, startup = 1.5, damage = 56.55, hits = 10, interval = 0.12, radius = 12,
					offset = 8, type = "melee", block = "none", bypassRagdoll = true, iframes = 1.5, color = "cyan", ragdoll = { h = 40, v = 30 } },
				-- Dashes to grab a face, bounces around 3 times holding them (10) and slams them into the ground (17.5).
				[ 2 ] = K.Grab{ "Face Blitz", cooldown = 10, startup = 0.3, damage = 27.5, hits = 4, interval = 0.35, lunge = 30, type = "melee",
					block = "none", bypassRagdoll = true, crater = 1200, ragdoll = { h = 10, v = -40 } },
				-- Aiming within 70 studs, tendrils pull the target in (3), push them around (6.15) and toss them up (7.5).
				-- TODO: anyone crashed into while pushing is launched away (15).
				[ 3 ] = K.Target{ "Crushing Rushdown", cooldown = 15, range = 70, startup = 0.4, damage = 16.65, hits = 3, interval = 0.35,
					type = "melee", block = "all", bypassRagdoll = true, ragdoll = { h = 10, v = 60 } },
				-- A slow block-like stance: struck, the user jolts behind the attacker and slices their head off.
				[ 4 ] = K.Counter{ "Head Splitter", cooldown = 40, window = 0.85, counters = { melee = "counter", bullet = "counter" },
					riposte = 100, teleport = true },
			},
			special = K.Stub{ "N/A" },
		},
	},
} )

-- G while awakened: the Awakening Black Flash (shares Idle Transfiguration's cooldown, costs 10% of the awakening)
local BLACK_FLASH = K.Build( "perfection", "abf", K.Melee{ "Awakening Black Flash", startup = 0.5, damage = 10, lunge = 35, iframes = 0.6,
	type = "melee", block = "none", bypassRagdoll = true, trueRag = true, uninterruptible = true, color = "black", ragdoll = { h = 80, v = 25 },
	onHit = function( ply )
		ply.jjs_superBF = ( ply.jjs_superBF or 0 ) + 1
		if ply.jjs_superBF >= 2 and ply:GetJKitSet() == 0 then
			-- Super Awakening
			ply:SetJKitSet( 1 )
			ply:SetJAwakenEnd( CurTime() + 50 )
			ply.jjs_awakenDur = 50
			JJS.Heal( ply, 10 )
		end
	end } )

function PERF.AwakenPress( ply, mv )
	if not ply:GetJAwakened() then return end
	-- pressed again during the lunge: it ends early
	local act = JJS.GetAction( ply )
	if act and act.kitParams and act.kitParams.name == "Awakening Black Flash" then
		JJS.StopAction( ply, true )
		return true
	end
	if JJS.GetCooldown( ply, 1 ) <= CurTime() and BLACK_FLASH.CanUse( ply, 1, mv ) then
		JJS.SetCooldown( ply, 1, 15 )
		JJS.AddAwakeningTime( ply, -0.1 )
		BLACK_FLASH.Use( ply, mv, 0 )
	end
	return true
end

hook.Add( "JJS_Awakened", "JJS_PerfectionSuper", function( ply ) ply.jjs_superBF = 0 end )
