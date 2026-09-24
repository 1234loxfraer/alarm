-- Cursed Partners (Yuta Okkotsu). Moves are JJS.Kit placeholders built from the JJS fandom wiki and the
-- dogslamloop frame data wiki; comments describe what the real move does.
--
-- Rika: the first press of the special summons her at the user's side (an intangible, invisible entity); the
-- next press switches to her moveset (the ring glows), pressing it again goes back (twice in a row dismisses her).
-- Using one of her moves recalls her and puts her whole moveset on that move's cooldown. Her moves are performed
-- by her: the user only motions and stays free to act (detached moves), which is what makes Rika Launch feints and
-- Rika Smash / Haymaker combo extensions work.
-- TODO: Rika following the movement inputs while her set is toggled (100 studs max, even during stun), held special.

local K = JJS.Kit

local function RikaOut( ply ) return ply:GetNW2Bool( "JJSRika", false ) or ply:GetJAwakened() end

-- The special: summon, switch to Rika's moves, switch back (twice in a row: dismiss)
local RIKA = {
	name = "Rika",
	cooldown = 0.3,
	tip = function( ply )
		if not RikaOut( ply ) then return "SUMMON" end
		return ply:GetJKitSet() == 1 and "BACK" or "SWITCH"
	end,
	-- usable in the middle of the user's moves (feints with Rika Launch)
	CanUse = function( ply ) return ply:Alive() and not ply:GetJRagdolled() end,
	Use = function( ply )
		JJS.SetCooldown( ply, 5, 0.3 )
		if not RikaOut( ply ) then
			ply:SetNW2Bool( "JJSRika", true )
			if SERVER then JJS.Util.Effect( "jjs_kit_cast", JJS.Util.BodyCenter( ply ), nil, ply, 1.2, K.COLOR_ID.pink ) end
			return
		end
		if ply:GetJKitSet() == 1 then
			ply:SetJKitSet( 0 )
			if CurTime() - ( ply.jjs_rikaSwitch or 0 ) < 0.6 and not ply:GetJAwakened() then ply:SetNW2Bool( "JJSRika", false ) end
		else
			ply:SetJKitSet( 1 )
			ply.jjs_rikaSwitch = CurTime()
		end
	end,
}

-- A Rika move: she goes back to the user's side and (outside the awakening) her whole set shares the cooldown
local function RikaMove( shared )
	return function( ab )
		local use = ab.Use
		ab.Use = function( ply, mv, slot )
			use( ply, mv, slot )
			if shared then
				-- every Rika move registers as going on cooldown (each strips a Bleed stack)
				local cd = JJS.GetCooldown( ply, slot )
				for i = 1, 3 do
					ply:SetNW2Float( "JJSAltCD" .. i, cd )
					if i ~= slot and cd - CurTime() > 1.5 then hook.Run( "JJS_Cooldown", ply, i, cd - CurTime() ) end
				end
			end
			ply:SetJKitSet( 0 )
		end
		return ab
	end
end

-- Outburst parry: melee parries push back and stun the attacker, grant i-frames, put Outburst on 4s and take 2s
-- off Rika's cooldowns; bullet parries reflect the projectile and keep Outburst off cooldown.
local function OutburstParry( ply, attacker, hit )
	if hit.type == JJS.DMG.MELEE then
		JJS.SetCooldown( ply, 3, 4 )
		for i = 1, 3 do
			local k = "JJSAltCD" .. i
			ply:SetNW2Float( k, math.max( CurTime(), ply:GetNW2Float( k, 0 ) - 2 ) )
		end
	else
		JJS.SetCooldown( ply, 3, 0 ) -- TODO: send the projectile back
	end
end

------------------------------------------------------------------------------------------
-- Copy Wheel (awakening): techniques of enemies Rika attacked (Downslam, Slam, Elbow Rush) or killed (Smash,
-- Haymaker) are stored (8 max, the newest replaces the oldest, Cursed Speech first; lost on death). G cycles the
-- wheel; the chosen technique becomes the 2nd skill, Copy. Each technique keeps its own cooldown
-- (15s for Cursed Speech and base copies, 25s for awakening copies).
------------------------------------------------------------------------------------------
local COPY = {
	honoredone = { "Limitless", "Reversal Red MAX", awk = true },
	vessel = { "Shrine", "Dismantle", awk = true },
	restlessgambler = { "Doors", "Shutter Doors" },
	tenshadows = { "10 Shadows", "Nue" },
	mahoraga = { "Adaptation", "Adaptation" },
	perfection = { "Transfiguration", "Idle Transfiguration", awk = true },
	bloodmanipulator = { "Blood", "Piercing Blood" }, -- the charged version
	switcher = { "Boogie Woogie", "Brothers", awk = true },
	defenseattorney = { "Execution", "Final Judgement", awk = true },
	puppetmaster = { "Puppets", "Puppet Barrage" },
	headofthehei = { "Projection", "Flash Freezing", awk = true },
	salaryman = { "Ratio", "Sharpen", awk = true },
	disasterplants = { "Disaster Plants", "Root Swarm" },
	truecannon = { "Granite Blast", "Granite Blast" },
	locustguy = { "Black Mucus", "Black Mucus" },
	starrage = { "Mass", "Mass Breaker" },
	aspiringmangaka = { "Clairvoyance", "Eye Catching" },
	luckycoward = { "Handsword", "Ambush" },
	crowcharmer = { "Bird Control", "Bird Control" },
	blackdeath = { "Roaches", "Roach Swarm" },
	skyassassin = { "Thin Ice Breaker", "Thin Ice Breaker" },
	strongestofhistory = { "Dismantle", "Strong Dismantle", awk = true },
	monkeykid = { "Kamehameha", "Kamehameha" },
}

-- Finds a character's move by name in any of its movesets (mode lists included)
local function FindMove( id, name )
	local c = JJS.Characters[ id ]
	if not c then return end
	local function Check( ab )
		if not ab then return end
		if ab.name == name and ab.Use then return ab end
		for _, m in pairs( ab.modes or {} ) do
			if m.name == name and m.Use then return m end
		end
	end
	local sets = { c, c.alt or false, c.awakening or false, c.awakening and c.awakening.alt or false }
	for _, set in ipairs( sets ) do
		if set then
			for slot = 1, 4 do
				local f = Check( set.abilities and set.abilities[ slot ] )
				if f then return f end
			end
			local f = Check( set.special )
			if f then return f end
		end
	end
end

local copyCache = {}
local function CopyOf( id )
	if copyCache[ id ] ~= nil then return copyCache[ id ] or nil end
	local def = COPY[ id ]
	local src = def and FindMove( id, def[ 2 ] )
	if not src then copyCache[ id ] = false return end
	local w = setmetatable( { name = "Copy: " .. src.name, cooldown = def.awk and 25 or 15, tip = def[ 1 ], Pick = false }, { __index = src } )
	w.Use = function( ply, mv, slot )
		src.Use( ply, mv, slot )
		JJS.SetCooldown( ply, slot, w.cooldown )
	end
	copyCache[ id ] = w
	return w
end

local function Copies( ply )
	local s = ply:GetNW2String( "JJSCopies", "" )
	local out = {}
	for id in string.gmatch( s, "[^,]+" ) do out[ #out + 1 ] = id end
	return out
end

local function AddCopy( ply, victim )
	if not ply:GetJAwakened() or not IsValid( victim ) or not victim:IsPlayer() then return end
	local id = victim:GetJChar()
	if not CopyOf( id ) then return end
	local list = Copies( ply )
	for _, v in ipairs( list ) do if v == id then return end end
	list[ #list + 1 ] = id
	if #list > 8 then table.remove( list, 1 ) end
	ply:SetNW2String( "JJSCopies", table.concat( list, "," ) )
end

-- G while awakened: the next technique on the wheel (0 = Cursed Speech); each keeps its own cooldown on slot 2
local function CycleCopy( ply )
	if not ply:GetJAwakened() or JJS.GetChar( ply ).id ~= "cursedpartners" then return false end
	local list = Copies( ply )
	local sel = ply:GetNW2Int( "JJSCopySel", 0 )
	ply.jjs_copyCD = ply.jjs_copyCD or {}
	ply.jjs_copyCD[ sel == 0 and "speech" or list[ sel ] or "?" ] = ply:GetJCD2()
	sel = ( sel + 1 ) % ( #list + 1 )
	ply:SetNW2Int( "JJSCopySel", sel )
	ply:SetJCD2( ply.jjs_copyCD[ sel == 0 and "speech" or list[ sel ] ] or 0 )
	return true
end

K.Character( "cursedpartners", {
	name = "Cursed Partners",
	category = "complete",
	hp = 90,
	model = K.Model( "cursedpartners", "models/player/group01/male_05.mdl" ),
	color = Color( 255, 120, 200 ),

	-- per-hit M1 frames { startup, recovery, block endlag } (dogslamloop): very unsafe on block (17f)
	m1 = {
		Frames = { { 12, 8, 17 }, { 12, 8, 17 }, { 12, 8, 17 } },
	},

	passives = {
		{ "Swordsmanship", "Cosmetic: necklace, katana holster and a custom block animation (katana put away after 8s)." },
		{ "Rika", "Her moves are done by her: the user stays free to act. They share one cooldown." },
	},

	abilities = {
		-- Slides 18 studs sweeping the floor with a cursed-energy blade (4); landed, locks the enemy in front for 3 quick
		-- swings (2.3 each), the last launching them (10.9, grab). Slow startup, long recovery: a combo extender.
		-- Veilstep (walking backward): a ~27 stud back roll with melee i-frames, a lingering hitbox launching anyone in the
		-- way (9, 360 blockable); the user's M1s can't hit air ragdolls for a moment after it (TODO).
		[ 1 ] = K.Grab{ "Severing Path", cooldown = 15, startup = 0.35, hits = 4, interval = 0.2, hitDamage = { 4, 2.3, 2.3, 2.3 }, lunge = 18,
			type = "melee", bypassRagdoll = true, whiffEndlag = 0.7, ragdoll = { h = 10, v = 55 }, tip = "DIRECTION",
			back = { kind = "mobility", dir = "back", startup = 0.12, travel = 27, time = 0.45, endlag = 0.2, damage = 9, hitDamage = false, hits = 1,
				type = "melee", block = "all", meleeIFrames = 0.55, ragdoll = { h = -5, v = 55 } } },
		-- Aiming at a spot within 25 studs, vanishes while winding up a long swing and reappears slashing at the neck
		-- (12, unblockable, can't hit ragdolls, keeps the target ragdolled longer: extends into 1 or 3).
		-- USE AGAIN as they reappear: "Resolute Black Flash", vanishes again for a heavy black flash (12, hits ragdolls),
		-- melee i-frames until the hitbox comes out. Both can be feinted with Rika Launch to remove the endlag.
		[ 2 ] = K.Target{ "Resolute Slash", cooldown = 15, range = 25, startup = 0.45, endlag = 0.5, damage = 12, type = "melee", block = "none",
			ragdoll = { time = 1.4, h = 40, v = 15 }, tip = "USE AGAIN",
			again = K.Target{ "Resolute Black Flash", window = 0.8, range = 25, startup = 0.3, endlag = 0.55, damage = 12, meleeIFrames = 0.3,
				type = "melee", block = "none", bypassRagdoll = true, color = "black", ragdoll = { h = 60, v = 25 } } },
		-- A cursed-energy swing (2, hits grounded ragdolls) triggering a 13x13 stud burst ragdolling upward. Holding it
		-- charges 3 stages (+2 damage and ~2 studs each: 8 / 10 / 12 / 14); the burst deals damage through block (it
		-- can't kill through it), and the full charge is unblockable unless the user is hit first.
		-- Parry: hit within the first 0.2s (0.25 on fandom), the swing parries melee and bullets (see OutburstParry).
		[ 3 ] = K.AoE{ "Outburst", cooldown = 16, startup = 0.45, endlag = 0.4, hits = 2, interval = 0.15, hitDamage = { 2, 6 },
			hitBlock = { "normal", "normal" }, blockDamage = 12, radius = 6.5, offset = 5, type = "explosion", bypassRagdoll = true,
			ragdoll = { h = 10, v = 50 }, color = "pink", tip = "HOLD",
			parry = { window = 0.2, counters = { melee = true, bullet = true }, iframes = 0.6, onParry = OutburstParry },
			hold = {
				{ time = 0.4, hitDamage = { 2, 8 }, radius = 8.5, blockDamage = 16 },
				{ time = 0.8, hitDamage = { 2, 10 }, radius = 10.5, blockDamage = 20 },
				{ time = 1.2, hitDamage = { 2, 12 }, radius = 12.5, hitBlock = { "normal", "none" }, blockDamage = false, crater = 900 },
			} },
		-- Rushes 20 studs with melee i-frames on cursed-energy boosted feet; grabs a met enemy by the face (2) and slams
		-- them into the floor (5; ragdolls airborne targets only). 360 blockable, much more endlag on block. A miss can be
		-- retried once before the cooldown. Great vertical hitbox: jump + 4 stuffs air moves.
		-- Pressing 1 as they collide with a defenseless standing target: "Combo Wind", a pummel of several blows
		-- throwing them away (15; with the katana out, swings into a spinning axe kick). Severing Path goes on 15s.
		[ 4 ] = K.Rush{ "Second Wind", cooldown = 16, charges = 2, chargeDelay = 0.5, startup = 0.15, travel = 20, time = 0.4, hits = 2,
			interval = 0.45, hitDamage = { 2, 5 }, type = "melee", block = "all", meleeIFrames = 0.55, blockEndlag = 1.1,
			ragdoll = { h = 5, v = -30 }, crater = 800, comboWindow = 0.6,
			onHit = function( ply ) JJS.SetCooldown( ply, 4, 16 ) ply.jjs_charges = nil end,
			combo = { [ 1 ] = { kind = "grab", startup = 0.1, lunge = 6, hits = 5, interval = 0.18, hitDamage = { 3, 3, 3, 3, 3 },
				block = "normal", meleeIFrames = false, bypassRagdoll = true, ragdoll = { h = 60, v = 20 }, crater = false } } },
	},
	special = RIKA,

	-- Rika's moves (one shared cooldown)
	alt = {
		name = "Rika",
		abilities = {
			-- Rika's fist grows above the target and slams down, bouncing them upward (10, 360 blockable). Near instant,
			-- extends ragdolls (Outburst's full charge). Airborne target: she dunks them into the ground (8, no evasive,
			-- ragdolled longer; evading it slows them down substantially).
			[ 1 ] = RikaMove( true )( K.Build( "cursedpartners", "rika1", K.Target{ "Rika Smash", cooldown = 10, teleport = false, range = 45,
				startup = 0.35, damage = 10, type = "bullet", block = "all", bypassRagdoll = true, detached = true, ragdoll = { h = 5, v = 45 },
				color = "pink", onContact = function( ply, v, p, r ) if r == "killed" then AddCopy( ply, v ) end end,
				airTarget = { damage = 8, block = "none", trueRag = true, ragdoll = { time = 1.4, h = 5, v = -50 }, slow = { 0.5, 2 } } } ) ),
			-- Rika boosts the user slightly forward (upward while airborne, which also happens during the user's moves).
			-- Used during a move it feints it into the pose: 6s instead of 10s.
			[ 2 ] = RikaMove( true )( K.Build( "cursedpartners", "rika2", K.Mobility{ "Rika Launch", cooldown = 10, startup = 0.05, travel = 22,
				time = 0.3, arc = 0.15, dir = "forward", feints = true, feintCooldown = 6, air = { dir = "up", travel = 18, arc = false } } ) ),
			-- Rika hovers to a target within 10 studs of her and slowly winds up a heavy blow knocking them far (12). Blocked:
			-- no ragdoll but the same knockback and 1.5x damage (18). Safe; she follows targets who evade during the windup.
			[ 3 ] = RikaMove( true )( K.Build( "cursedpartners", "rika3", K.Target{ "Rika Haymaker", cooldown = 10, teleport = false, range = 20,
				startup = 0.8, damage = 12, blockDamage = 18, knock = 60, knockBlock = true, type = "bullet", bypassRagdoll = true,
				detached = true, ragdoll = { h = 80, v = 25 }, color = "pink",
				onContact = function( ply, v, p, r ) if r == "killed" then AddCopy( ply, v ) end end } ) ),
		},
		special = RIKA,
	},

	awakening = {
		name = "True Love",
		duration = 60,
		heal = 25,
		-- "Come, Rika. Give me everything." Rika fully manifests and wraps a steel casing around the user's arm.
		-- Steel Arm: the first 3 M1s add a quick jab ((4 + 0.5) + (4 + 0.5) + (0.5 + 0.5) + 4), twice as slow if the first
		-- punch was blocked; back to the katana after Energy Ripple. TODO: the jab hitboxes.
		m1 = { Damage = { 4.5, 4.5, 1, 4 } },
		abilities = {
			-- Dashes ~38.5 studs into an elbow strike sending the target spinning (4), appears behind them with Rika for a
			-- barrage from both sides (5, 8 with Rika) and a final blow launching them far (6). Unblockable, awakening
			-- drain stops meanwhile; a missed elbow has tremendous endlag. Copies the target's technique.
			[ 1 ] = K.Rush{ "Elbow Rush", cooldown = 15, startup = 0.2, travel = 38.5, time = 0.45, hits = 3, interval = 0.4,
				hitDamage = { 4, 8, 6 }, type = "melee", block = "none", whiffEndlag = 1.4, ragdoll = { h = 80, v = 25 },
				onContact = function( ply, v ) AddCopy( ply, v ) end },
			-- Copy: the technique selected on the wheel. Default, Cursed Speech: "Don't move!" stuns everyone within 35 studs
			-- for 2.5s (360 blockable).
			[ 2 ] = K.AoE{ "Copy: Cursed Speech", cooldown = 15, startup = 0.5, damage = 0, radius = 35, stun = 2.5, type = "special",
				block = "all", color = "purple", tip = "G: WHEEL" },
			-- Drives the katana into the floor: a field pushing every enemy within 27 studs away (19, unblockable,
			-- uninterruptible). The stab directly on a knocked enemy only extends their ragdoll.
			-- USE AGAIN before the katana lands: "Fakeout", a sudden swing (7) transferring the burst (12) into the target,
			-- knocking them toward where the user faces.
			[ 3 ] = K.AoE{ "Energy Ripple", cooldown = 18, startup = 0.6, damage = 19, radius = 27, type = "explosion", block = "none",
				bypassRagdoll = true, uninterruptible = true, ragdoll = { h = 60, v = 20 }, color = "pink", tip = "USE AGAIN",
				again = K.Melee{ "Fakeout", window = 0.55, startup = 0.15, hits = 2, interval = 0.25, hitDamage = { 7, 12 }, type = "melee",
					block = "none", bypassRagdoll = true, uninterruptible = true, ragdoll = { h = 60, v = 20 } } },
			-- Domain Expansion (longer windup, breaks with no enemy inside): a stone platform, love knots in the sky and blades
			-- raining down; four land within reach, each with a random technique (Shrine, Thin Ice Breaker, Clairvoyance,
			-- Cursed Speech, Shikigami). Standing near one equips it: a ~55 stud run then the swing (8) and the technique.
			-- After 4 direct katana hits, using it again with a target in sight: "Jacob's Ladder" (62.5 over the lift,
			-- drains 35% awakening / 50% if awakened; total armor and i-frames in the windup; shatters the domain).
			-- TODO: the katanas and Jacob's Ladder.
			[ 4 ] = K.Domain{ "Authentic Mutual Love", cooldown = 120, duration = 45, sureHit = "none", color = "pink" },
		},
		special = RIKA,

		-- Awakened Rika: four new moves, separate cooldowns; she stays until the awakening ends
		alt = {
			name = "Rika (Awakened)",
			abilities = {
				-- Rika pins the target to the floor with one arm (8) then a second impact (4). Airborne target: both arms send
				-- them to the floor (8). Copies the target's technique.
				[ 1 ] = RikaMove( false )( K.Build( "cursedpartners", "arika1", K.Target{ "Rika Downslam", cooldown = 13, teleport = false,
					range = 45, startup = 0.4, hits = 2, interval = 0.4, hitDamage = { 8, 4 }, type = "melee", block = "none", bypassRagdoll = true,
					detached = true, ragdoll = { h = 5, v = -30 }, color = "pink", onContact = function( ply, v ) AddCopy( ply, v ) end,
					airTarget = { hits = 1, hitDamage = false, damage = 8, ragdoll = { h = 5, v = -60 } } } ) ),
				-- Rika hovers to the target, grabs a leg and slams them five times (1 + 2 x 4 + 3). They can evade out early.
				[ 2 ] = RikaMove( false )( K.Build( "cursedpartners", "arika2", K.Target{ "Rika Slam", cooldown = 13, teleport = false, range = 45,
					startup = 0.4, hits = 6, interval = 0.3, hitDamage = { 1, 2, 2, 2, 2, 3 }, type = "melee", block = "none", bypassRagdoll = true,
					detached = true, ragdoll = { h = 30, v = 30 }, color = "pink", onContact = function( ply, v ) AddCopy( ply, v ) end } ) ),
				-- A pink orb, then Rika grows in front of it and fires an overwhelming beam (100, less the more players it hits and
				-- the farther they are). Once she's in position the user can move again. Beam clash rank 3.
				-- USE AGAIN in the windup (automatic when Rika is busy): a smaller, faster beam (22.4, 15s).
				[ 3 ] = RikaMove( false )( K.Build( "cursedpartners", "arika3", K.Beam{ "True Love Beam", cooldown = 40, startup = 1.8,
					damage = 100, duration = 1.5, tick = 0.25, range = 160, radius = 7, pierce = true, clash = 3, type = "explosion", block = "none",
					bypassRagdoll = true, color = "pink", crater = 1800, ragdoll = { h = 60, v = 25 }, tip = "USE AGAIN",
					again = K.Beam{ "True Love Beam: Quick", window = 1.5, startup = 0.2, damage = 22.4, range = 120, radius = 4, pierce = true,
						type = "explosion", block = "none", bypassRagdoll = true, color = "pink",
						onUse = function( ply ) JJS.SetCooldown( ply, 3, 15 ) end } } ) ),
				-- Rika picks the user up and throws them: crashing into an enemy ragdolls them (8 to 18 by airtime); hitting
				-- no one hurts the user (0.5 to 22) with true ragdoll. TODO: airtime scaling.
				[ 4 ] = RikaMove( false )( K.Build( "cursedpartners", "arika4", K.Mobility{ "Rika Throw", cooldown = 13, startup = 0.5,
					travel = 45, time = 0.5, dir = "aim", damage = 13, type = "melee", bypassRagdoll = true, ragdoll = { h = 55, v = 25 },
					onEnd = function( ply ) if not ply.jjs_kitLanded then JJS.ApplyDamage( ply, nil, 8, { type = JJS.DMG.SPECIAL } ) end end } ) ),
			},
			special = RIKA,
		},
	},

	AwakenPress = CycleCopy,
} )

-- Copy (awakened slot 2) resolves to the technique selected on the wheel
local cp = JJS.Characters.cursedpartners
local speech = cp.awakening.abilities[ 2 ]
cp.awakening.abilities[ 2 ] = setmetatable( {
	Pick = function( ply )
		local sel = ply:GetNW2Int( "JJSCopySel", 0 )
		local id = sel > 0 and Copies( ply )[ sel ]
		return id and CopyOf( id ) or speech
	end,
}, { __index = speech } )

hook.Add( "JJS_PlayerSpawned", "JJS_CursedPartners", function( ply )
	ply:SetNW2Bool( "JJSRika", false )
	ply:SetNW2String( "JJSCopies", "" )
	ply:SetNW2Int( "JJSCopySel", 0 )
	ply.jjs_copyCD = nil
end )
