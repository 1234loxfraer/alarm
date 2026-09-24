-- Cursed Partners (Yuta Okkotsu). Moves are JJS.Kit placeholders built from the JJS fandom wiki and the
-- dogslamloop frame data wiki; comments describe what the real move does.
--
-- Rika: the first press of the special summons her at the user's side (an intangible, invisible entity); the
-- next press switches to her moveset (the ring glows), pressing it again goes back (twice in a row dismisses her).
-- Using one of her moves recalls her and puts her whole moveset on that move's cooldown. Her moves are performed
-- by her: the user only motions and stays free to act (detached moves), which is what makes Rika Launch feints and
-- Rika Smash / Haymaker combo extensions work.
-- Rika stays by the user's right side. While her set is toggled she follows the movement inputs at high speed, even
-- during stun, up to 100 studs away; switching back or using one of her moves recalls her, unless the special was held
-- or the user is inside a foreign domain she isn't in. She acts from where she is, on the target under the cursor, the
-- last one the user attacked or the closest one to her.

local K = JJS.Kit
local S = JJS.STUD
local U = JJS.Util

local function RikaOut( ply ) return ply:GetNW2Bool( "JJSRika", false ) or ply:GetJAwakened() end

local function RikaFree( ply ) return ply:GetNW2Bool( "JJSRikaFree", false ) end
local function RikaPos( ply )
	if RikaFree( ply ) then return ply:GetNW2Vector( "JJSRikaPos", ply:GetPos() ) end
	return ply:GetPos() + U.YawRight( ply:EyeAngles().y ) * 4 * S
end
local function Recall( ply ) ply:SetNW2Bool( "JJSRikaFree", false ) end

-- Rika's target: under the cursor, the last one the user attacked, or the closest one to her (within the move's range
-- of her)
local function RikaTarget( ply, p )
	local from = RikaPos( ply )
	local function Near( t ) return IsValid( t ) and t:Alive() and t ~= ply and t:GetPos():Distance( from ) <= p.range + 3 * S end
	local t = K.AimTarget( ply, p.range + from:Distance( ply:GetPos() ), p.cone )
	if Near( t ) then return t end
	t = ply:GetNW2Entity( "JJSRikaTarget" )
	if Near( t ) then return t end
	local best, bestD
	for _, v in ipairs( player.GetAll() ) do
		if v ~= ply and v:Alive() then
			local d = v:GetPos():Distance( from )
			if d <= p.range and ( not bestD or d < bestD ) then best, bestD = v, d end
		end
	end
	return best
end
-- where her move comes from (where she was when it was used)
local function RikaOrigin( ply ) return ply.jjs_rikaFrom or RikaPos( ply ) end

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
		-- pressed with the cursor on someone: Rika faces them
		local aimed = K.AimTarget( ply, 100 * S )
		if IsValid( aimed ) then ply:SetNW2Entity( "JJSRikaTarget", aimed ) end
		if not RikaOut( ply ) then
			ply:SetNW2Bool( "JJSRika", true )
			if SERVER then JJS.Util.Effect( "jjs_kit_cast", JJS.Util.BodyCenter( ply ), nil, ply, 1.2, K.COLOR_ID.pink ) end
			return
		end
		if ply:GetJKitSet() == 1 then
			ply:SetJKitSet( 0 )
			-- recalled unless the special stays held (checked shortly after)
			ply.jjs_rikaRecall = CurTime() + 0.3
			if CurTime() - ( ply.jjs_rikaSwitch or 0 ) < 0.6 and not ply:GetJAwakened() then
				ply:SetNW2Bool( "JJSRika", false )
				Recall( ply )
			end
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
			ply.jjs_rikaFrom = RikaPos( ply )
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
			ply.jjs_rikaRecall = CurTime()
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
		-- the projectile is sent back at its owner
		JJS.SetCooldown( ply, 3, 0 )
		local p = hit.kit
		if SERVER and p and p.kind == "projectile" and IsValid( attacker ) then
			local from = U.BodyCenter( ply )
			K.SpawnProjectile( ply, p, from + ( U.BodyCenter( attacker ) - from ):GetNormalized() * 30, ( U.BodyCenter( attacker ) - from ):GetNormalized() )
		end
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
		-- way (9, 360 blockable); the user's M1s can't hit air ragdolls for a moment after it.
		[ 1 ] = K.Grab{ "Severing Path", cooldown = 15, startup = 0.35, hits = 4, interval = 0.2, hitDamage = { 4, 2.3, 2.3, 2.3 }, lunge = 18,
			type = "melee", bypassRagdoll = true, whiffEndlag = 0.7, ragdoll = { h = 10, v = 55 }, tip = "DIRECTION",
			back = { kind = "mobility", dir = "back", startup = 0.12, travel = 27, time = 0.45, endlag = 0.2, damage = 9, hitDamage = false, hits = 1,
				type = "melee", block = "all", meleeIFrames = 0.55, ragdoll = { h = -5, v = 55 },
				onUse = function( ply ) ply.jjs_noAirRag = CurTime() + 1.6 end } },
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
				pickTarget = RikaTarget, origin = RikaOrigin, startup = 0.35, damage = 10, type = "bullet", block = "all", bypassRagdoll = true, detached = true, ragdoll = { h = 5, v = 45 },
				color = "pink", onContact = function( ply, v, p, r ) if r == "killed" then AddCopy( ply, v ) end end,
				airTarget = { damage = 8, block = "none", trueRag = true, ragdoll = { time = 1.4, h = 5, v = -50 }, slow = { 0.5, 2 } } } ) ),
			-- Rika boosts the user slightly forward (upward while airborne, which also happens during the user's moves).
			-- Used during a move it feints it into the pose: 6s instead of 10s.
			[ 2 ] = RikaMove( true )( K.Build( "cursedpartners", "rika2", K.Mobility{ "Rika Launch", cooldown = 10, startup = 0.05, travel = 22,
				time = 0.3, arc = 0.15, dir = "forward", feints = true, feintCooldown = 6, air = { dir = "up", travel = 18, arc = false } } ) ),
			-- Rika hovers to a target within 10 studs of her and slowly winds up a heavy blow knocking them far (12). Blocked:
			-- no ragdoll but the same knockback and 1.5x damage (18). Safe; she follows targets who evade during the windup.
			[ 3 ] = RikaMove( true )( K.Build( "cursedpartners", "rika3", K.Target{ "Rika Haymaker", cooldown = 10, teleport = false, range = 10,
				pickTarget = RikaTarget, origin = RikaOrigin,
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
		-- punch was blocked; back to the katana after Energy Ripple (until it's holstered 8s later, Elbow Rush or a domain
		-- katana).
		m1 = { Damage = { 4, 4, 0.5, 4 } },
		abilities = {
			-- Dashes ~38.5 studs into an elbow strike sending the target spinning (4), appears behind them with Rika for a
			-- barrage from both sides (5, 8 with Rika) and a final blow launching them far (6). Unblockable, awakening
			-- drain stops meanwhile; a missed elbow has tremendous endlag. Copies the target's technique.
			[ 1 ] = K.Rush{ "Elbow Rush", cooldown = 15, startup = 0.2, travel = 38.5, time = 0.45, hits = 3, interval = 0.4,
				hitDamage = { 4, 8, 6 }, type = "melee", block = "none", whiffEndlag = 1.4, ragdoll = { h = 80, v = 25 },
				onUse = function( ply ) ply.jjs_cpKatana = nil end,
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
				onUse = function( ply ) ply.jjs_cpKatana = CurTime() + 8 end,
				again = K.Melee{ "Fakeout", window = 0.55, startup = 0.15, hits = 2, interval = 0.25, hitDamage = { 7, 12 }, type = "melee",
					block = "none", bypassRagdoll = true, uninterruptible = true, ragdoll = { h = 60, v = 20 } } },
			-- Domain Expansion (longer windup, breaks with no enemy inside): a stone platform, love knots in the sky and blades
			-- raining down; four land within reach, each with a random technique (Shrine, Thin Ice Breaker, Clairvoyance,
			-- Cursed Speech, Shikigami). Standing near one equips it: a ~55 stud run then the swing (8) and the technique.
			-- After 4 direct katana hits, using it again with a target in sight: "Jacob's Ladder" (62.5 over the lift,
			-- drains 35% awakening / 50% if awakened; total armor and i-frames in the windup; shatters the domain).
			-- Each katana then another falls; they give no awakening. The domain breaks at once with no enemy inside.
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
					range = 45, pickTarget = RikaTarget, origin = RikaOrigin, startup = 0.4, hits = 2, interval = 0.4, hitDamage = { 8, 4 }, type = "melee", block = "none", bypassRagdoll = true,
					detached = true, ragdoll = { h = 5, v = -30 }, color = "pink", onContact = function( ply, v ) AddCopy( ply, v ) end,
					airTarget = { hits = 1, hitDamage = false, damage = 8, ragdoll = { h = 5, v = -60 } } } ) ),
				-- Rika hovers to the target, grabs a leg and slams them five times (1 + 2 x 4 + 3). They can evade out early.
				[ 2 ] = RikaMove( false )( K.Build( "cursedpartners", "arika2", K.Target{ "Rika Slam", cooldown = 13, teleport = false, range = 45, pickTarget = RikaTarget, origin = RikaOrigin,
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
				-- no one hurts the user (0.5 to 22 by airtime, the full amount at the end of the flight) with true ragdoll.
				[ 4 ] = RikaMove( false )( K.Build( "cursedpartners", "arika4", K.Mobility{ "Rika Throw", cooldown = 13, startup = 0.5,
					travel = 45, time = 0.5, dir = "aim", damage = 13, type = "melee", bypassRagdoll = true, ragdoll = { h = 55, v = 25 },
					onEnd = function( ply )
						if ply.jjs_kitLanded then return end
						JJS.ApplyDamage( ply, nil, 22, { type = JJS.DMG.SPECIAL } )
						if ply:Alive() then JJS.Ragdoll.Apply( ply, { time = 1.2, trueRag = true, vel = K.Fwd( ply ) * 20 * S + Vector( 0, 0, 10 * S ) } ) end
					end } ) ),
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

------------------------------------------------------------------------------------------
-- Rika's movement
------------------------------------------------------------------------------------------

-- While her set is toggled she follows the movement inputs (even during stun), 100 studs from the user at most
hook.Add( "SetupMove", "JJS_RikaFollow", function( ply, mv )
	if ply:GetJChar() ~= "cursedpartners" or ply:GetJKitSet() ~= 1 or not RikaOut( ply ) or not ply:Alive() then return end
	local f, side = U.InputDir( mv )
	if f == 0 and side == 0 then return end
	local yaw = mv:GetMoveAngles().y
	local dir = U.YawForward( yaw ) * f + U.YawRight( yaw ) * side
	dir:Normalize()
	local pos = RikaPos( ply ) + dir * 70 * S * FrameTime()
	local off = pos - ply:GetPos()
	if off:Length() > 100 * S then pos = ply:GetPos() + off:GetNormalized() * 100 * S end
	ply:SetNW2Vector( "JJSRikaPos", pos )
	ply:SetNW2Bool( "JJSRikaFree", true )
end )

------------------------------------------------------------------------------------------
-- Authentic Mutual Love: the katanas and Jacob's Ladder
------------------------------------------------------------------------------------------

local TECHS = { "Shrine", "Thin Ice Breaker", "Clairvoyance", "Cursed Speech", "Shikigami" }

local function OwnDomain( ply )
	local d = JJS.Domain.Of( ply )
	if IsValid( d ) and d:GetCaster() == ply and d:GetDomainName() == "Authentic Mutual Love" then return d end
end

local TECH = {
	cleave = K.Params( K.Melee{ "Shrine: Cleave", hits = 4, interval = 0.15, damage = 20, type = "melee", block = "none", bypassRagdoll = true,
		stun = 1.2, knock = 25 } ),
	dismantle = K.Params( K.Melee{ "Shrine: Dismantle", damage = 20, type = "explosion", block = "none", bypassRagdoll = true,
		ragdoll = { h = 50, v = 15 } } ),
	thinIce = K.Params( K.Melee{ "Thin Ice Breaker", damage = 20, type = "melee", block = "none", bypassRagdoll = true, trueRag = true,
		ragdoll = { h = 60, v = 30 } } ),
	thinIceMiss = K.Params( K.Melee{ "Thin Ice Breaker", damage = 15, type = "melee", block = "none", bypassRagdoll = true, ragdoll = { h = 50, v = 20 } } ),
	plummet = K.Params( K.Melee{ "Cursed Speech: Plummet", damage = 15, type = "swarm", block = "none", bypassRagdoll = true,
		ragdoll = { time = 1.5, h = 0, v = -40 } } ),
	shiki = K.Params( K.Melee{ "Shikigami", hits = 9, damage = 27, type = "swarm", block = "none", bypassRagdoll = true, stun = 0.4 } ),
	shikiMiss = K.Params( K.Melee{ "Shikigami", hits = 9, damage = 27, blockDamage = 13.5, type = "swarm", block = "normal", bypassRagdoll = true,
		stun = 0.4, noKill = true } ),
}

-- The closest enemy inside the domain
local function DomainEnemy( ply, d )
	local best, bestD
	for _, v in ipairs( JJS.Domain.Members( d ) ) do
		if v ~= ply and v:Alive() then
			local dist = v:GetPos():Distance( ply:GetPos() )
			if not bestD or dist < bestD then best, bestD = v, dist end
		end
	end
	return best
end

local function Swarm( ply, p, v )
	for i = 1, p.hits do
		timer.Simple( i / 3, function() if IsValid( ply ) and IsValid( v ) and v:Alive() then K.Apply( ply, p, v, i ) end end )
	end
end

-- The technique a katana holds, after its swing landed on `v` (or missed)
local function Technique( ply, tech, v )
	local d = JJS.Domain.Of( ply )
	if tech == "Shrine" then
		if v then
			for i = 1, 4 do timer.Simple( i * 0.15, function() if IsValid( v ) and v:Alive() then K.Apply( ply, TECH.cleave, v, i ) end end ) end
		else
			-- a large horizontal Dismantle slash
			local from, dir = U.BodyCenter( ply ), K.Fwd( ply )
			for _, h in ipairs( U.PlayersOnRay( from, dir, 60 * S, 8 * S, { ignore = ply, ragdolled = true } ) ) do K.Apply( ply, TECH.dismantle, h.ply, 1, from ) end
			K.Effect( "jjs_kit_beam", from, dir, ply, 60 * S, TECH.dismantle )
		end
	elseif tech == "Thin Ice Breaker" then
		if v then
			K.Apply( ply, TECH.thinIce, v, 1 )
		else
			local from, dir = U.BodyCenter( ply ), K.Fwd( ply )
			for _, h in ipairs( U.PlayersOnRay( from, dir, 20 * S, 6 * S, { ignore = ply, ragdolled = true } ) ) do K.Apply( ply, TECH.thinIceMiss, h.ply, 1, from ) end
		end
	elseif tech == "Clairvoyance" then
		-- a manga panel: their attacks are dodged effortlessly (10s; 5s from afar)
		local t = v or ( IsValid( d ) and DomainEnemy( ply, d ) )
		if IsValid( t ) then
			t.jjs_cpPanel = { by = ply, t = CurTime() + ( v and 10 or 5 ) }
			t:SetNW2Float( "JJSPanel", CurTime() + ( v and 10 or 5 ) )
		end
	elseif tech == "Cursed Speech" then
		if v then
			K.Apply( ply, TECH.plummet, v, 1 )
		elseif IsValid( d ) then
			-- "Stop!": everyone inside freezes
			for _, m in ipairs( JJS.Domain.Members( d ) ) do
				if m ~= ply then JJS.Stun( m, 3 ) m:SetLocalVelocity( vector_origin ) end
			end
		end
	elseif tech == "Shikigami" then
		local t = v or ( IsValid( d ) and DomainEnemy( ply, d ) )
		if IsValid( t ) then Swarm( ply, v and TECH.shiki or TECH.shikiMiss, t ) end
	end
end

-- A picked up katana: a run of about 55 studs, then the swing (8) and its technique
local BLADE = K.Build( "cursedpartners", "blade", K.Rush{ "Katana", startup = 0.15, travel = 55, time = 1, damage = 8, type = "melee", block = "none",
	bypassRagdoll = true, stun = 1, color = "pink",
	onHit = function( ply, v )
		ply:SetNW2Int( "JJSLadder", ply:GetNW2Int( "JJSLadder", 0 ) + 1 )
		Technique( ply, ply.jjs_cpBlade, v )
	end,
	onEnd = function( ply ) if not ply.jjs_kitLanded then Technique( ply, ply.jjs_cpBlade, nil ) end end } )

-- Jacob's Ladder: a divine ray lifting the target (62.5), draining 35% of their awakening (50% if awakened); shatters
-- the domain
local LADDER = K.Build( "cursedpartners", "ladder", K.Target{ "Jacob's Ladder", teleport = false, range = 80, startup = 1, iframes = 1,
	armor = "total", uninterruptible = true, hits = 5, interval = 0.5, damage = 62.5, type = "special", block = "none", bypassRagdoll = true,
	trueRag = true, ragdoll = { time = 1.5, h = 0, v = 20 }, color = "gold",
	onUse = function( ply )
		local d = OwnDomain( ply )
		if d then timer.Simple( 0, function() JJS.Domain.Collapse( d ) end ) end
	end,
	onHit = function( ply, v )
		if v:GetJAwakened() then
			v:SetJAwakenEnd( v:GetJAwakenEnd() - 0.5 * ( v.jjs_awakenDur or JJS.GetAwakeningDuration( v ) ) )
		else
			v:SetJAwaken( math.max( 0, v:GetJAwaken() - 0.35 ) )
		end
	end } )

local dom = cp.awakening.abilities[ 4 ]
dom.tip = function( ply )
	if IsValid( JJS.Domain.Of( ply ) ) and JJS.Domain.Of( ply ):GetCaster() == ply then
		return "LADDER " .. math.min( ply:GetNW2Int( "JJSLadder", 0 ), 4 ) .. "/4"
	end
end
dom.Again = function( ply, mv )
	if not OwnDomain( ply ) then return false end
	if ply:GetNW2Int( "JJSLadder", 0 ) < 4 or JJS.IsBusy( ply ) or not JJS.CanAct( ply ) or not IsValid( K.AimTarget( ply, 80 * S ) ) then return true end
	ply:SetNW2Int( "JJSLadder", 0 )
	LADDER.Use( ply, mv, 0 )
	return true
end

if SERVER then
	-- Rika faces whoever the user attacked
	hook.Add( "JJS_Hit", "JJS_RikaTarget", function( victim, hit, res )
		local a = hit.attacker
		if res == "hit" and IsValid( a ) and a:IsPlayer() and a ~= victim and a:GetJChar() == "cursedpartners" then
			a:SetNW2Entity( "JJSRikaTarget", victim )
		end
	end )

	hook.Add( "Tick", "JJS_CursedPartners", function()
		local now = CurTime()
		for _, ply in ipairs( player.GetAll() ) do
			-- recalled after switching back or one of her moves, unless the special is held or the user is inside a
			-- foreign domain she isn't in
			local t = ply.jjs_rikaRecall
			if t and now >= t then
				ply.jjs_rikaRecall = nil
				local d = JJS.Domain.Of( ply )
				local foreign = IsValid( d ) and d:GetCaster() ~= ply and RikaPos( ply ):Distance( d:GetPos() ) > d:GetRadius()
				if not ply:KeyDown( JJS.IN.SPECIAL ) and not foreign then Recall( ply ) end
			end
		end
		-- the domain's katanas: shown, picked up by standing near one (another one falls)
		for _, d in ipairs( JJS.Domain.All() ) do
			local list, ply = d.jjs_katanas, d:GetCaster()
			if list and IsValid( ply ) and ply:Alive() then
				if ( d.jjs_katanaFx or 0 ) < now then
					d.jjs_katanaFx = now + 0.5
					for _, k in ipairs( list ) do U.Effect( "jjs_kit_cast", k.pos + Vector( 0, 0, 30 ), nil, ply, 0.5, K.COLOR_ID.pink ) end
				end
				if JJS.CanAct( ply ) and not JJS.IsBusy( ply ) then
					for i, k in ipairs( list ) do
						if ply:GetPos():Distance( k.pos ) < 5 * S then
							table.remove( list, i )
							ply.jjs_cpBlade = k.tech
							ply.jjs_cpKatana = nil
							BLADE.Use( ply, nil, 0 )
							d.jjs_drop( d )
							break
						end
					end
				end
			end
		end
	end )

	local function DropKatana( d )
		local c, r = d:GetPos(), d:GetRadius()
		local a = math.random() * math.pi * 2
		local pos = c + Vector( math.cos( a ), math.sin( a ), 0 ) * math.random() * math.min( r * 0.6, 25 * S )
		d.jjs_katanas = d.jjs_katanas or {}
		table.insert( d.jjs_katanas, { pos = pos, tech = TECHS[ math.random( #TECHS ) ] } )
		U.Effect( "jjs_kit_burst", pos + Vector( 0, 0, 10 ), Vector( 0, 0, 1 ), d:GetCaster(), 20, K.COLOR_ID.pink )
	end

	hook.Add( "JJS_DomainExpanded", "JJS_MutualLove", function( ply, d )
		if d:GetDomainName() ~= "Authentic Mutual Love" then return end
		-- no enemy inside: it breaks at once
		local enemy = false
		for _, v in ipairs( JJS.Domain.Members( d ) ) do if v ~= ply then enemy = true end end
		if not enemy then
			timer.Simple( 0, function() if IsValid( d ) then JJS.Domain.Collapse( d ) end end )
			return
		end
		ply:SetNW2Int( "JJSLadder", 0 )
		d.jjs_drop = DropKatana
		for _ = 1, 4 do DropKatana( d ) end
	end )

	-- Clairvoyance (domain katana): the marked enemy's attacks are dodged effortlessly
	hook.Add( "JJS_PreHit", "JJS_MutualLovePanel", function( victim, hit )
		local a = hit.attacker
		local m = IsValid( a ) and a.jjs_cpPanel
		if m and m.by == victim and CurTime() < m.t then
			U.Effect( "jjs_kit_cast", U.BodyCenter( victim ), nil, victim, 0.6, K.COLOR_ID.white )
			return "dodged"
		end
	end )

	-- Steel Arm: a quick jab after each of the first 3 M1s (twice as slow when the punch was blocked); katana M1s
	-- keep it out
	hook.Add( "JJS_M1", "JJS_SteelArm", function( ply, idx, variant, landed, blocked )
		if ply:GetJChar() ~= "cursedpartners" or not ply:GetJAwakened() then return end
		if ( ply.jjs_cpKatana or 0 ) > CurTime() then
			ply.jjs_cpKatana = CurTime() + 8
			return
		end
		if idx > 3 then return end
		timer.Simple( blocked and 0.2 or 0.1, function()
			if not IsValid( ply ) or not ply:Alive() or JJS.IsStunned( ply ) or ply:GetJRagdolled() then return end
			for _, v in ipairs( JJS.M1.FindTargets( ply, JJS.M1.Cfg( ply ), JJS.M1.NEUTRAL ) ) do
				JJS.Hit( v, { attacker = ply, damage = 0.5, type = JJS.DMG.MELEE, stun = 0.6, from = ply:GetPos(), fx = "light" } )
			end
		end )
	end )

	-- Rika Throw: the crash hurts more the longer the flight (8 to 18)
	hook.Add( "JJS_PreHit", "JJS_RikaThrow", function( victim, hit )
		if not hit.kit or hit.kit.name ~= "Rika Throw" then return end
		local a = hit.attacker
		local frac = math.Clamp( ( JJS.ActionTime( a ) - hit.kit.startup ) / hit.kit.time, 0, 1 )
		hit.damage = 8 + 10 * frac
	end )
end

hook.Add( "JJS_PlayerSpawned", "JJS_RikaPos", function( ply )
	ply:SetNW2Bool( "JJSRikaFree", false )
	ply:SetNW2Entity( "JJSRikaTarget", NULL )
	ply:SetNW2Int( "JJSLadder", 0 )
	ply.jjs_cpPanel, ply.jjs_cpKatana, ply.jjs_noAirRag = nil, nil, nil
end )

if CLIENT then
	-- where Rika is when she's away from the user
	cp.HUDPaint = function( ply, now, S2 )
		if not RikaOut( ply ) or not RikaFree( ply ) then return end
		local sp = ( RikaPos( ply ) + Vector( 0, 0, 50 ) ):ToScreen()
		if not sp.visible then return end
		surface.SetDrawColor( 255, 120, 200, 220 )
		surface.DrawOutlinedRect( sp.x - S2( 8 ), sp.y - S2( 8 ), S2( 16 ), S2( 16 ) )
	end
end
