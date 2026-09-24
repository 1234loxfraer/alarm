-- Register (early access). Moves are JJS.Kit placeholders built from the wiki numbers;
-- comments describe what the real move does.
-- Contractual Re-Creation: 12 skills rotate through the 4 slots. A used skill is replaced by the
-- NEXT one and goes to the back of the queue. Discard (special) makes the next pressed slot skip
-- to NEXT without using it. Awakened, G swaps slot 1 or 3 for a gold-sealed skill (6% awakening).

local K = JJS.Kit
local ID = "register"

local SKILLS = {
	-- Throws a kitchen knife 95 studs; ragdolls unless blocked and applies a Bleed stack (3).
	-- TODO red seal: 6 knives spread diagonally (+1.5 per extra hit).
	K.Projectile{ "Gushing Wound", cooldown = 12, startup = 0.25, damage = 9, range = 95, speed = 220, radius = 2, type = "bullet", block = "none",
		moveMult = 0.8, ragdoll = { h = 30, v = 12, time = 0.6 }, color = "white" },
	-- Swings a baseball bat, launching targets or throwables up and away. Airborne targets: 17, no ragdoll cancel.
	-- TODO red seal: also bats a ricocheting baseball (6, 10 from range).
	K.Melee{ "Homerun", cooldown = 14, startup = 0.4, damage = 10, reach = 9, type = "melee", block = "none", ragdoll = { h = 45, v = 45 } },
	-- Spreads 8 receipts that stick to surfaces; after 12s (or a second use) giant yoga balls bounce up pulling people along (8).
	-- TODO red seal: a second wave of smaller balls (5).
	K.Zone{ "Littering", cooldown = 15, startup = 0.4, radius = 18, offset = 10, duration = 3, tick = 1, damage = 2.7, type = "swarm", block = "all",
		bypassRagdoll = true, ragdoll = { h = 5, v = 40, time = 0.6 }, color = "white" },
	-- A vaulting pole lifts the user 55 studs, damaging anyone in the way (5). Near a ragdolled target, slams it on them instead.
	K.Mobility{ "Pole Vault", cooldown = 14, startup = 0.2, travel = 55, time = 0.7, dir = "forward", damage = 5, type = "melee", block = "none",
		bypassRagdoll = true, ragdoll = { h = 20, v = 35 } },
	-- A coupon: picking another skill adds a red seal (improved version) to it.
	-- TODO: seals (red, and rainbow with Extra Coupon which grants items).
	K.Buff{ "Coupon", cooldown = 5, startup = 0.2, duration = 0.3, color = "red" },
	-- A piano falls from the sky in a 7x7 circle (hold to aim it within 50 studs).
	-- TODO red seal: bricks, 14x14 with a shockwave (19 in the centre).
	K.AoE{ "Piano Drop", cooldown = 13, startup = 0.8, damage = 14, radius = 4, offset = 12, type = "explosion", block = "none", bypassRagdoll = true,
		crater = 900, ragdoll = { h = 5, v = -25 }, color = "brown" },
	-- Shoots 10 appliances 70 studs forward like artillery (1.2 each) while walking.
	-- TODO red seal: a fridge after a delay (5).
	K.Projectile{ "Garage Sale", cooldown = 16, startup = 0.4, damage = 1.2, count = 10, volley = 0.12, spread = 3, range = 70, speed = 150, radius = 3,
		type = "bullet", bypassRagdoll = true, moveMult = 0.8, color = "brown" },
	-- Dashes 25 studs swinging a statue; landed, 2 more swings and a crush on the head (3 + 3 + 3 + 6) that disables dashing,
	-- running and jumping for 4s.
	K.Grab{ "Blunt Trauma", cooldown = 14, startup = 0.3, damage = 15, hits = 4, interval = 0.3, lunge = 25, type = "melee", bypassRagdoll = true,
		slow = { 0.6, 4 }, ragdoll = { h = 10, v = -20, time = 0.6 } },
	-- Two drones hover beside the user facing a red dot; pressed again they crash into each other at the dot (12).
	K.AoE{ "Drone Strike", cooldown = 10, startup = 0.9, damage = 12, radius = 9, offset = 20, type = "explosion", block = "none", bypassRagdoll = true,
		moveMult = 0.9, crater = 800, ragdoll = { h = 35, v = 30 }, color = "orange" },
	-- A black umbrella: dashes 20 studs like an arrow, stabs (8) and pulls the enemy back with short ragdoll.
	-- Follow-up: opening the umbrella releases a shockwave that reflects projectiles (5, unblockable with the stab).
	K.Melee{ "Fleche", cooldown = 14, startup = 0.35, damage = 8, lunge = 20, type = "melee", ragdoll = { h = -25, v = 12, time = 0.5 }, tip = "USE TWICE",
		again = K.AoE{ "Fleche: Umbrella", window = 0.8, startup = 0.1, damage = 5, radius = 8, type = "melee", block = "none", bypassRagdoll = true,
			ragdoll = { h = 30, v = 10 } } },
	-- Works exactly the same as Coupon.
	K.Buff{ "Extra Coupon", cooldown = 8, startup = 0.2, duration = 0.3, color = "gold" },
	-- Rides a scooter 55 studs; an enemy met is dragged along until it explodes (12).
	K.Mobility{ "Speed Crash", cooldown = 16, startup = 0.2, travel = 55, time = 0.8, dir = "forward", damage = 12, type = "explosion", block = "none",
		bypassRagdoll = true, crater = 900, ragdoll = { h = 60, v = 30 } },

	-- Gold-sealed skills (awakened)
	-- Jumps up throwing down bomb receipts (24) and a spa ticket that heals 12.5 if picked up; floats down with an umbrella.
	K.AoE{ "Mayhem", cooldown = 18, startup = 0.6, damage = 24, hits = 3, interval = 0.25, radius = 16, type = "explosion", block = "none",
		bypassRagdoll = true, heal = 12.5, crater = 1200, ragdoll = { h = 40, v = 35 }, color = "gold" },
	-- Two trucks appear behind the user and speed ahead ~110 studs, sending anyone in the way flying (a small gap between them).
	K.Projectile{ "Big Moves", cooldown = 21, startup = 0.7, damage = 30, speed = 160, range = 110, radius = 10, pierce = true, type = "explosion",
		block = "none", bypassRagdoll = true, ragdoll = { h = 80, v = 30 }, color = "gold" },
}

local NAMES = {}
local BUILT = {}
for i, spec in ipairs( SKILLS ) do
	NAMES[ i ] = spec[ 1 ]
	BUILT[ i ] = K.Build( ID, "skill" .. i, spec )
end
local GOLD = { 13, 14 }

------------------------------------------------------------------------------------------
-- Rotation state: "a,b,c,d|q1,q2,..." (slot skills | queue), networked on the player
------------------------------------------------------------------------------------------

local START = "1,2,3,4|5,6,7,8,9,10,11,12"

local function Read( ply )
	local str = ply:GetNW2String( "JJSRegister", START )
	local a, b = string.match( str, "^([^|]*)|(.*)$" )
	local slots, queue = {}, {}
	for n in string.gmatch( a or "", "%d+" ) do slots[ #slots + 1 ] = tonumber( n ) end
	for n in string.gmatch( b or "", "%d+" ) do queue[ #queue + 1 ] = tonumber( n ) end
	if #slots ~= 4 then return Read( { GetNW2String = function() return START end } ) end
	return slots, queue
end

local function Write( ply, slots, queue )
	ply:SetNW2String( "JJSRegister", table.concat( slots, "," ) .. "|" .. table.concat( queue, "," ) )
end

-- The skill in `slot` goes to the back of the queue and NEXT takes its place
local function Rotate( ply, slot )
	if CLIENT and not IsFirstTimePredicted() then return end
	local slots, queue = Read( ply )
	local used = slots[ slot ]
	if not used or #queue == 0 then return end
	slots[ slot ] = table.remove( queue, 1 )
	-- gold skills are single use
	if used ~= GOLD[ 1 ] and used ~= GOLD[ 2 ] then queue[ #queue + 1 ] = used end
	Write( ply, slots, queue )
end

local function Discarding( ply ) return ply:GetNW2Bool( "JJSDiscard" ) end

-- Each slot shows whatever skill the rotation put there
local function Slot( slot )
	local proxy = { name = "Receipt" }
	proxy.Pick = function( ply )
		local slots = Read( ply )
		local inner = BUILT[ slots[ slot ] ]
		if not inner then return nil end
		local ab = { name = inner.name, cooldown = inner.cooldown, CanUse = inner.CanUse, spec = inner.spec }
		ab.tip = function( p, s )
			if Discarding( p ) then return "DISCARD" end
			local t = inner.tip
			if isfunction( t ) then return t( p, s ) end
			return t
		end
		ab.Again = function( p, mv, s )
			if Discarding( p ) then
				p:SetNW2Bool( "JJSDiscard", false )
				Rotate( p, s )
				return true
			end
			return inner.Again and inner.Again( p, mv, s )
		end
		ab.Use = function( p, mv, s )
			inner.Use( p, mv, s )
			Rotate( p, s )
		end
		return ab
	end
	return proxy
end

local REG = K.Character( ID, {
	name = "Register",
	category = "early",
	hp = 100,
	model = K.Model( ID, "models/player/group02/male_04.mdl" ),
	color = Color( 140, 220, 220 ),

	passives = {
		{ "Contractual Re-Creation", "12 skills rotate through the 4 slots; a used skill is replaced by the NEXT one." },
	},

	abilities = { Slot( 1 ), Slot( 2 ), Slot( 3 ), Slot( 4 ) },
	-- The next pressed slot skips to the NEXT skill, keeping its cooldown. Landing an uppercut or final neutral M1: -5s.
	special = K.Buff{ "Discard", cooldown = 25, startup = 0.05, duration = 0.05, endlag = 0, color = "cyan",
		onUse = function( ply ) ply:SetNW2Bool( "JJSDiscard", true ) end },

	awakening = {
		name = "Con Artistry",
		duration = 90,
		heal = 25,
		-- "A sorcerer... is nothing but a con artist." No new moves: G replaces a skill with a gold-sealed one.
	},

	OnSpawn = function( ply )
		ply:SetNW2String( "JJSRegister", START )
		ply:SetNW2Bool( "JJSDiscard", false )
	end,

	-- Awakened: G puts a gold skill (Mayhem / Big Moves) in slot 1 (or 3 if slot 1 already holds one)
	AwakenPress = function( ply )
		if not ply:GetJAwakened() then return end
		if CLIENT and not IsFirstTimePredicted() then return true end
		local slots, queue = Read( ply )
		local slot = ( slots[ 1 ] == GOLD[ 1 ] or slots[ 1 ] == GOLD[ 2 ] ) and 3 or 1
		if slots[ slot ] == GOLD[ 1 ] or slots[ slot ] == GOLD[ 2 ] then return true end
		ply.jjs_regGold = ( ( ply.jjs_regGold or 0 ) % 2 ) + 1
		table.insert( queue, 1, slots[ slot ] )
		slots[ slot ] = GOLD[ ply.jjs_regGold ]
		Write( ply, slots, queue )
		JJS.AddAwakeningTime( ply, -0.06 )
		return true
	end,
} )

-- Landing an uppercut or a final neutral M1 shaves 5s off Discard
hook.Add( "JJS_M1", "JJS_RegisterDiscard", function( ply, idx, variant, landed )
	if landed and ply:GetJChar() == ID and idx >= JJS.GetChar( ply ).m1.Count and variant ~= JJS.M1.DOWN then
		ply:SetJCD5( math.max( CurTime(), ply:GetJCD5() - 5 ) )
	end
end )

if SERVER then return end

-- NEXT slot to the right of the special
function REG.HUDPaint( ply, now, S )
	local _, queue = Read( ply )
	local nxt = NAMES[ queue[ 1 ] or 0 ]
	if not nxt then return end
	local x, y = ScrW() / 2 + S( 330 ), ScrH() - S( 108 )
	draw.SimpleText( "NEXT", "JJS_Tip", x, y, Color( 255, 206, 84 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM )
	draw.SimpleText( nxt, "JJS_Small", x, y + S( 2 ), color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )
end
