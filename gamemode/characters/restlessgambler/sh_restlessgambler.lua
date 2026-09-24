-- Restless Gambler (Kinji Hakari). Moves are JJS.Kit placeholders built from the JJS fandom wiki
-- and the dogslamloop frame data wiki; comments describe what the real move does.
--
-- Awakening: G casts Idle Death Gamble (80s, 15 HP; breaks after 4 scenarios). Everyone caught is frozen for a
-- neutral stage. Visual moves (Reserve Balls, Shutter Doors, the Pachinko Combo counting 2, a landed Fever Breaker
-- dropkick or Fever Crush, a successful Door Guard) each take a colour (green, red, gold); every 2 roll a Richii
-- scenario whose jackpot odds depend on the scenario and those colours. A jackpot shatters the domain and grants the
-- awakened moves for 100s (50s for the pity jackpot guaranteed on the 4th roll when someone was caught). An odd
-- jackpot (777) raises the odds of the next Idle Death Gamble, an even one (666) makes its scenarios twice as fast;
-- death takes these away. The exact odds aren't documented: the numbers below are approximations.
-- Jackpot passive: greatly increased healing (reverse cursed technique); hits drain the awakening bar (333 damage
-- empties it). Surviving until the end refunds 40% awakening, +25% per consecutive jackpot (reset by a failed
-- gamble or death).
-- Renewal: in the domain, pressing Reserve Balls again within 8s of the ball landing rewinds everyone to their
-- positions at that moment and undoes the damage the user took since.

local K = JJS.Kit
local U = JJS.Util

local SCENARIOS = {
	{ name = "TRANSIT CARD RICHII", stars = "*", chance = 0.2 },
	{ name = "TRAVEL EMERGENCY RICHII", stars = "**", chance = 0.35 },
}
-- visual move colours: { name, jackpot odds bonus, palette id }
local COLORS = {
	{ "GREEN", 0, K.COLOR_ID.green },
	{ "RED", 0.08, K.COLOR_ID.red },
	{ "GOLD", 0.2, K.COLOR_ID.gold },
}
local ROLL_TIME = 5

local function Gamble( ply ) return ply:GetNW2Entity( "JJSGamble" ) end
local function InGamble( ply ) return IsValid( Gamble( ply ) ) end

local Visual, Resolve

K.Character( "restlessgambler", {
	name = "Restless Gambler",
	category = "complete",
	hp = 100,
	model = K.Model( "restlessgambler", "models/player/group03/male_06.mdl" ),
	color = Color( 120, 255, 170 ),

	abilities = {
		-- Flicks a steel ball 65 studs forward: stuns, or ragdolls away if it travelled 15 studs or less. It ricochets off
		-- surfaces (within its usual distance, endlessly inside a domain). Blockable, hits ragdolls.
		-- Combo "Pachinko Combo" (Shutter Doors during the windup): the doors appear where the ball lands and bounce the
		-- stunned enemy (7.5 + 3 + 2 per bounce, 3 bounces); both moves go on cooldown.
		[ 1 ] = K.Projectile{ "Reserve Balls", cooldown = 12, startup = 0.3, damage = 7.5, range = 65, speed = 200, radius = 2, type = "bullet",
			bypassRagdoll = true, stun = 0.9, color = "white", near = { dist = 15, ragdoll = { h = 40, v = 15 } },
			onUse = function( ply ) Visual( ply, 1 ) end,
			-- Renewal: where everyone stood when the ball landed
			onExplode = function( ply )
				if not InGamble( ply ) then return end
				local pos = {}
				for _, v in ipairs( player.GetAll() ) do
					if v:Alive() then pos[ v ] = v:GetPos() end
				end
				ply.jjs_renewal = { t = CurTime() + 8, hp = ply:GetJHP(), pos = pos }
			end,
			combo = { [ 2 ] = { damage = 13.5, hitDamage = false, explode = 5, stun = 1.4, ragdoll = { h = 5, v = 35 }, color = "green" } } },
		-- Pachinko shutter doors close on the enemy's torso (up to 25 studs away if aimed) and stun them in place; sets the
		-- user to their 3rd M1. Hits airborne ragdolls only.
		-- Miss variant: the doors linger for 7s; jumping on them bounces the user high, a ragdolled enemy falling on them
		-- bounces 3 times (2 each).
		[ 2 ] = K.Target{ "Shutter Doors", cooldown = 15, teleport = false, range = 25, cone = 0.85, damage = 8, type = "bullet", stun = 1.4,
			color = "green", onUse = function( ply ) Visual( ply, 1 ) end,
			onHit = function( ply ) ply:SetJM1Index( 2 ) ply:SetJM1LastEnd( CurTime() ) end },
		-- A long windup punch with sharp cursed energy sending the enemy flying (unblockable, long windup and endlag).
		-- Air variant: hovers then stomps, a shockwave launches targets upward (8, 360 blockable).
		-- High air variant (above jump height, e.g. after bouncing on the doors): unblockable and doubled (16).
		[ 3 ] = K.Melee{ "Rough Energy", cooldown = 14, startup = 0.65, endlag = 0.6, damage = 12.5, type = "melee", block = "none",
			bypassRagdoll = true, ragdoll = { h = 70, v = 25 },
			air = { kind = "aoe", damage = 8, block = "all", radius = 10, up = -12, ragdoll = { h = 6, v = 55 }, color = "green" },
			highAir = { kind = "aoe", damage = 16, block = "none", radius = 12, up = -12, ragdoll = { h = 6, v = 60 }, color = "green",
				crater = 1200 } },
		-- A ranged kick suspends the opponent in front of two shutter doors (5), then a dropkick launches them in the
		-- direction faced before the follow-up (10).
		-- Combo "Fever Crush" (Shutter Doors during the windup): the doors hold the target (8) for an unblockable axe
		-- kick (12; 24 on a ragdolled target).
		[ 4 ] = K.Melee{ "Fever Breaker", cooldown = 23, startup = 0.35, hits = 2, interval = 0.5, hitDamage = { 5, 10 }, reach = 10, type = "melee",
			ragdoll = { h = 55, v = 25 }, onHit = function( ply ) Visual( ply, 1 ) end,
			combo = { [ 2 ] = { hitDamage = { 8, 12 }, hitBlock = { "normal", "none" }, interval = 0.55, bypassRagdoll = true, crater = 1000,
				ragdoll = { h = 5, v = -30 } } } },
	},
	-- Two shutter doors: melee attackers get punched through them (5), bullets just shatter them. 0.6s window.
	special = K.Counter{ "Door Guard", cooldown = 16, window = 0.6, counters = { melee = "counter", bullet = "evade" }, riposte = 5,
		onCounter = function( ply ) Visual( ply, 1 ) end },

	awakening = {
		name = "Jackpot",
		duration = 100,
		abilities = {
			-- A flurry of punches the user can move during (20.7), ending in an unblockable swipe that launches away (8).
			[ 1 ] = K.Melee{ "Lucky Volley", cooldown = 10, startup = 0.3, damage = 28.7, hits = 10, interval = 0.12, moveMult = 0.8, type = "melee",
				hitDamage = { 2.3, 2.3, 2.3, 2.3, 2.3, 2.3, 2.3, 2.3, 2.3, 8 }, hitBlock = { "normal", "normal", "normal", "normal", "normal",
				"normal", "normal", "normal", "normal", "none" }, blockDamage = 10.35, bypassRagdoll = true, ragdoll = { h = 55, v = 20 } },
			-- A long forward run; an enemy met is grabbed by the leg (14), dragged across the floor and thrown forward (10).
			[ 2 ] = K.Rush{ "Lucky Rushdown", cooldown = 15, startup = 0.3, travel = 45, time = 0.8, hits = 3, interval = 0.4, hitDamage = { 7, 7, 10 },
				type = "melee", block = "none", bypassRagdoll = true, ragdoll = { h = 60, v = 20 } },
			-- Charges, rushes into a devastating strike tossing the target away (10), sprints after them for more hits and a
			-- final punch (30). Bullet armor; can hit several people.
			[ 3 ] = K.Rush{ "Overwhelming Luck", cooldown = 20, startup = 0.8, travel = 25, time = 0.35, hits = 4, interval = 0.35,
				hitDamage = { 10, 8, 8, 14 }, type = "melee", block = "none", bypassRagdoll = true, armor = "bullet", ragdoll = { h = 80, v = 30 } },
			-- Dashes a short distance into a heavy punch propelling the target skywards (10), then appears above for a kick (10).
			[ 4 ] = K.Rush{ "Energy Surge", cooldown = 25, startup = 0.2, travel = 12, time = 0.2, hits = 2, interval = 0.45, hitDamage = { 10, 10 },
				type = "melee", block = "none", bypassRagdoll = true, ragdoll = { h = 20, v = -40 } },
		},
		-- Dancing to the rhythm: a stackable speed boost and 0.6s off every running cooldown (lost if interrupted);
		-- also clears Execution stacks.
		special = K.Buff{ "Rhythm", cooldown = 8, duration = 1.2, speed = 1.15, speedTime = 30,
			onUse = function( ply )
				ply.jjs_execution = nil
				for i = 1, 4 do
					local cd = JJS.GetCooldown( ply, i )
					if cd > CurTime() then ply[ "SetJCD" .. i ]( ply, cd - 0.6 ) end
				end
			end },
	},

	-- G casts the domain (the awakened moves only come with the jackpot)
	Awaken = function( ply )
		if not JJS.Domain.CanCast( ply ) then return end
		ply:SetJAwaken( 0 )
		JJS.StartAction( ply, "restlessgambler.cast" )
	end,

	Think = function( ply, now )
		local g = ply.jjs_gamble
		if g then
			if not InGamble( ply ) then
				-- the domain ran out or broke without a jackpot
				ply.jjs_gamble = nil
				ply.jjs_jackpotStreak = 0
			elseif g.roll and now >= g.roll.t then
				Resolve( ply )
			end
		end
		-- Jackpot: the reverse cursed technique keeps healing the user
		if ply:GetNW2Bool( "JJSJackpot" ) and ply:GetJAwakened() then JJS.Heal( ply, 5 * FrameTime() ) end
	end,

	-- the gamble's state, top left
	HUDPaint = function( ply, now, S2 )
		if not InGamble( ply ) then return end
		local x, y = S2( 24 ), S2( 150 )
		local rainbow = K.COLOR_BY_ID[ 1 + math.floor( now * 6 ) % #K.COLOR_BY_ID ] or color_white
		draw.SimpleText( "IDLE DEATH GAMBLE", "JJS_Small", x, y, rainbow )
		draw.SimpleText( string.format( "VISUAL %d/2   ROLL %d/4", ply:GetNW2Int( "JJSGambleVis", 0 ), ply:GetNW2Int( "JJSGambleTry", 0 ) ),
			"JJS_Small", x, y + S2( 18 ), color_white )
		local sc = SCENARIOS[ ply:GetNW2Int( "JJSGambleScen", 0 ) ]
		if sc and ply:GetNW2Float( "JJSGambleRoll", 0 ) > now then
			draw.SimpleText( sc.name .. " (" .. sc.stars .. ")", "JJS_Small", x, y + S2( 36 ), rainbow )
		end
		draw.SimpleText( ply:GetNW2String( "JJSGambleNums", "" ), "JJS_Small", x, y + S2( 54 ), color_white )
	end,
} )

------------------------------------------------------------------------------------------
-- Idle Death Gamble
------------------------------------------------------------------------------------------

local function OpenDomain( ply )
	local d = JJS.Domain.Expand( ply, { name = "Idle Death Gamble", duration = 80, sureHit = "none", colorId = K.COLOR_ID.green } )
	if not IsValid( d ) then return end
	JJS.Heal( ply, 15 )
	local caught = false
	-- everyone caught is frozen in place for the neutral stage
	for _, v in ipairs( JJS.Domain.Members( d ) ) do
		if v ~= ply then caught = true end
		JJS.Stun( v, 2.5 )
		v:SetLocalVelocity( vector_origin )
	end
	ply:SetNW2Entity( "JJSGamble", d )
	ply:SetNW2Int( "JJSGambleVis", 0 )
	ply:SetNW2Int( "JJSGambleTry", 0 )
	ply:SetNW2Float( "JJSGambleRoll", 0 )
	ply:SetNW2String( "JJSGambleNums", "" )
	-- last jackpot's bonus (odd: better odds, even: faster scenarios) applies to this one
	ply.jjs_gamble = { caught = caught, colors = {}, tries = 0, bonus = ply.jjs_gambleBonus }
	ply.jjs_gambleBonus = nil
end

JJS.RegisterAction( "restlessgambler.cast", {
	dur = JJS.Config.Domain.CastTime + 0.2,
	moveMult = 0,
	noJump = true,
	uninterruptible = true,
	armor = { all = true },
	gesture = "gesture_item_place",
	start = function( ply ) JJS.IFrames( ply, JJS.Config.Domain.CastTime + 0.2 ) end,
	events = { { JJS.Config.Domain.CastTime, function( ply ) if SERVER then OpenDomain( ply ) end end } },
} )

-- Two queued visual moves start a Richii scenario
local function TryRoll( ply )
	local g = ply.jjs_gamble
	if not g or g.roll or #g.colors < 2 or g.tries >= 4 then return end
	local sc = math.random() < 0.6 and 1 or 2
	local chance = SCENARIOS[ sc ].chance + COLORS[ table.remove( g.colors, 1 ) ][ 2 ] + COLORS[ table.remove( g.colors, 1 ) ][ 2 ]
	if g.bonus == "odd" then chance = chance + 0.15 end
	local t = g.bonus == "even" and ROLL_TIME / 2 or ROLL_TIME
	g.roll = { t = CurTime() + t, chance = chance }
	-- two numbered symbols; the third appears at the end
	g.num = math.random( 1, 9 )
	ply:SetNW2Int( "JJSGambleScen", sc )
	ply:SetNW2Float( "JJSGambleRoll", CurTime() + t )
	ply:SetNW2Int( "JJSGambleVis", #g.colors )
	ply:SetNW2String( "JJSGambleNums", g.num .. " ? " .. g.num )
end

function Visual( ply, n )
	local g = ply.jjs_gamble
	if not g or not InGamble( ply ) then return end
	for _ = 1, n do
		local r = math.random()
		local c = r < 0.6 and 1 or ( r < 0.9 and 2 or 3 )
		g.colors[ #g.colors + 1 ] = c
		U.Effect( "jjs_kit_cast", U.BodyCenter( ply ), nil, ply, 0.8, COLORS[ c ][ 3 ] )
	end
	ply:SetNW2Int( "JJSGambleVis", math.min( #g.colors, 2 ) )
	TryRoll( ply )
end

local function Jackpot( ply, duration, num )
	local d = Gamble( ply )
	ply.jjs_gamble = nil
	ply:SetNW2Entity( "JJSGamble", NULL )
	ply:SetNW2Float( "JJSGambleRoll", 0 )
	-- the domain shatters as the music starts
	if IsValid( d ) then JJS.Domain.Collapse( d ) end
	ply.jjs_gambleBonus = num % 2 == 1 and "odd" or "even"
	ply:SetNW2Bool( "JJSJackpot", true )
	JJS.EnterAwakening( ply, duration, 0 )
	U.Effect( "jjs_kit_cast", U.BodyCenter( ply ), nil, ply, 3, K.COLOR_ID.green )
end

-- The scenario plays out: a jackpot, a retry, or the domain breaking after the 4th
function Resolve( ply )
	local g = ply.jjs_gamble
	g.tries = g.tries + 1
	ply:SetNW2Int( "JJSGambleTry", g.tries )
	local win = math.random() < g.roll.chance
	local pity = not win and g.tries >= 4 and g.caught
	g.roll = nil
	ply:SetNW2Float( "JJSGambleRoll", 0 )
	if win or pity then
		ply:SetNW2String( "JJSGambleNums", g.num .. " " .. g.num .. " " .. g.num )
		Jackpot( ply, pity and 50 or 100, g.num )
		return
	end
	ply:SetNW2String( "JJSGambleNums", g.num .. " " .. ( g.num % 9 + 1 ) .. " " .. g.num )
	if g.tries >= 4 then
		local d = Gamble( ply )
		ply.jjs_gamble = nil
		ply.jjs_jackpotStreak = 0
		ply:SetNW2Entity( "JJSGamble", NULL )
		if IsValid( d ) then JJS.Domain.Collapse( d ) end
		return
	end
	TryRoll( ply )
end

-- Renewal: Reserve Balls again within 8s of the ball landing (checked before its cooldown)
local rb = JJS.Characters.restlessgambler.abilities[ 1 ]
rb.Again = function( ply )
	local r = ply.jjs_renewal
	-- (a ready Reserve Balls is thrown instead: only Rhythm can bring it back that soon)
	if not r or CurTime() > r.t or not InGamble( ply ) or not ply:Alive() or JJS.GetCooldown( ply, 1 ) <= CurTime() then return false end
	ply.jjs_renewal = nil
	if SERVER then
		for v, pos in pairs( r.pos ) do
			if IsValid( v ) and v:Alive() then
				if v:GetJRagdolled() then JJS.Ragdoll.Stop( v, "renewal" ) end
				JJS.Teleport( v, pos )
				v:SetLocalVelocity( vector_origin )
			end
		end
		if ply:GetJHP() < r.hp then
			ply:SetJHP( r.hp )
			ply:SetHealth( math.ceil( r.hp ) )
		end
		U.Effect( "jjs_kit_cast", U.BodyCenter( ply ), nil, ply, 2, K.COLOR_ID.gold )
	end
	return true
end

if SERVER then
	-- Jackpot: hits drain the awakening bar (333 damage empties it)
	hook.Add( "JJS_Hit", "JJS_Jackpot", function( victim, hit, res )
		if res ~= "hit" or not victim:GetNW2Bool( "JJSJackpot" ) or not victim:GetJAwakened() then return end
		local dur = victim.jjs_awakenDur or 100
		victim:SetJAwakenEnd( victim:GetJAwakenEnd() - ( hit.damage or 0 ) / 333 * dur )
	end )

	-- surviving the jackpot refunds awakening: 40%, +25% per consecutive jackpot
	hook.Add( "JJS_AwakeningEnd", "JJS_Jackpot", function( ply )
		if not ply:GetNW2Bool( "JJSJackpot" ) then return end
		ply:SetNW2Bool( "JJSJackpot", false )
		if not ply:Alive() then return end
		local streak = ply.jjs_jackpotStreak or 0
		ply:SetJAwaken( math.min( 1, 0.4 + 0.25 * streak ) )
		ply.jjs_jackpotStreak = streak + 1
	end )

	-- death takes the bonuses away
	hook.Add( "JJS_PlayerDied", "JJS_Jackpot", function( ply )
		if ply:GetJChar() ~= "restlessgambler" then return end
		ply:SetNW2Bool( "JJSJackpot", false )
		ply.jjs_jackpotStreak = 0
		ply.jjs_gambleBonus = nil
		ply.jjs_renewal = nil
		local d = Gamble( ply )
		ply.jjs_gamble = nil
		ply:SetNW2Entity( "JJSGamble", NULL )
		if IsValid( d ) then JJS.Domain.Collapse( d ) end
	end )
end
