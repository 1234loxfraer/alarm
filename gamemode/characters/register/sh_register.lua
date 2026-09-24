-- Register (early access). Moves are JJS.Kit placeholders built from the JJS fandom wiki and the
-- dogslamloop frame data wiki; comments describe what the real move does.
--
-- Contractual Re-Creation: 12 skills rotate through the 4 slots. A used skill is replaced by the NEXT one (a fifth slot
-- on the toolbar) and goes to the back of the queue; a new skill takes the cooldown of the one it replaced. The start:
-- Gushing Wound, Homerun, Littering, Pole Vault, NEXT Coupon, then Piano Drop, Garage Sale, Blunt Trauma, Drone
-- Strike, Fleche, Extra Coupon and Speed Crash.
-- Seals: Coupon / Extra Coupon then a slot key adds a red seal to that skill (its own key: the NEXT skill); a sealed
-- skill is improved, and the seal goes when it's used or discarded. A red-sealed Coupon gives a rainbow seal
-- instead: using a rainbow-sealed skill puts that skill's item in its slot (Crowbar, Jet Black, ...).
-- Discard (special): the next slot key replaces that skill with NEXT, keeping the slot's cooldown (and dropping its
-- seal); a second press cancels. 25s, -5s per landed uppercut or final neutral M1.
-- Con Artistry (awakening): G then slot 1 or 3 (unsealed) swaps it for a gold skill (Mayhem, Big Moves) for 6%.

local K = JJS.Kit
local ID = "register"
local S = JJS.STUD

-- seal of a skill id: "r" red, "b" rainbow
local function Seal( ply, id )
	for sid, seal in string.gmatch( ply:GetNW2String( "JJSRegSeals", "" ), "(%d+)=(%a)" ) do
		if tonumber( sid ) == id then return seal end
	end
end
-- state writes happen once per prediction
local function Once() return SERVER or IsFirstTimePredicted() end
local function SetSeal( ply, id, seal )
	if not Once() then return end
	local out = {}
	for sid, s in string.gmatch( ply:GetNW2String( "JJSRegSeals", "" ), "(%d+)=(%a)" ) do
		if tonumber( sid ) ~= id then out[ #out + 1 ] = sid .. "=" .. s end
	end
	if seal then out[ #out + 1 ] = id .. "=" .. seal end
	ply:SetNW2String( "JJSRegSeals", table.concat( out, "," ) )
end
local function Red( id ) return function( ply ) return Seal( ply, id ) == "r" end end

-- the concussion of Blunt Trauma: no dashing, running or jumping
local function Concuss( seconds )
	return function( ply, v )
		JJS.StaggerLeg( v, seconds )
		v:SetJBuffMult( 0.6 )
		v:SetJBuffEnd( CurTime() + seconds )
	end
end

local function Bleed( ply, v )
	if v:IsPlayer() then v:SetNW2Int( "JJSBleed", math.min( 3, v:GetNW2Int( "JJSBleed", 0 ) + 1 ) ) end
end

local SKILLS = {
	-- 1: Throws a kitchen knife 95 studs while walking (9, unblockable): ragdolls unless blocked and adds a Bleed stack
	-- (3; it can't turn into Hemorrhage). Red: 6 knives spread diagonally (+1.5 per extra knife landed, one stack).
	K.Projectile{ "Gushing Wound", cooldown = 12, startup = 0.25, damage = 9, range = 95, speed = 220, radius = 2, type = "bullet", block = "none",
		moveMult = 0.8, ragdoll = { h = 30, v = 12, time = 0.6 }, color = "white", onHit = Bleed,
		cond = { test = Red( 1 ), count = 6, spread = 8, damage = 3 } },
	-- 2: A baseball bat launches targets (or throwables, 15) up and away (10, unblockable, can't hit ragdolls). An
	-- airborne target takes 17 and can't ragdoll cancel. Red: the bat also hits a baseball that ricochets off surfaces
	-- (6, 10 after ~20 studs, up to 233 studs); against a blocker it goes through the guard and disables the cancel.
	K.Melee{ "Homerun", cooldown = 14, startup = 0.4, damage = 10, reach = 9, type = "melee", block = "none", ragdoll = { h = 45, v = 45 },
		airTarget = { damage = 17, trueRag = true },
		cond = { test = Red( 2 ), onUse = function( ply )
			timer.Simple( 0.4, function()
				if IsValid( ply ) and ply:Alive() then K.SpawnProjectile( ply, K.REG_BALL, K.Muzzle( ply ), K.AimDir( ply, 0.3 ) ) end
			end )
		end } },
	-- 3: Spreads 8 receipts that stick to surfaces; after 12s or pressing it again (even stunned) they turn into giant
	-- yoga balls bouncing up and pulling along anyone near (8; the user isn't harmed). It only goes on cooldown after
	-- the second use. Red: 8 more receipts, a second wave of smaller balls after a delay (5, no evasive).
	K.Stub{ "Littering", cooldown = 15, startup = 0.4, endlag = 0.2, color = "white", tip = "USE AGAIN" },
	-- 4: A vaulting pole lifts the user 55 studs, hitting anyone in the way (5, unblockable). Near a ragdolled target
	-- ("Leverage"): slammed down on them instead, bouncing them up. Red: a second receipt keeps the move (only the seal
	-- goes) and off cooldown.
	K.Mobility{ "Pole Vault", cooldown = 14, startup = 0.2, travel = 55, time = 0.7, dir = "forward", arc = 0.5, damage = 5, type = "melee",
		block = "none", bypassRagdoll = true, ragdoll = { h = 20, v = 35 },
		ragdolled = { kind = "melee", startup = 0.35, damage = 5, reach = 10, arc = false, ragdoll = { h = 5, v = 45 } } },
	-- 5: Coupon: the next slot key puts a red seal on that skill (Coupon's own key: the NEXT one).
	K.Stub{ "Coupon", cooldown = 5, startup = 0.2, endlag = 0.1, color = "red" },
	-- 6: A piano falls from the sky on a 7x7 circle (14, unblockable; lower under a roof). Holding aims it within 50 studs
	-- (TODO). Red: 3 bricks on top: 14x14 with a shockwave (19 in the centre, 5 around).
	K.AoE{ "Piano Drop", cooldown = 13, startup = 0.8, damage = 14, radius = 3.5, offset = 12, type = "explosion", block = "none",
		bypassRagdoll = true, crater = 900, ragdoll = { h = 5, v = -25 }, color = "brown",
		cond = { test = Red( 6 ), damage = 19, radius = 7, crater = 1300 } },
	-- 7: Shoots 10 appliances 70 studs forward like artillery while walking (1.2 each, blockable). Red: a fridge after a
	-- slight delay (5, semi blockable).
	K.Projectile{ "Garage Sale", cooldown = 16, startup = 0.4, damage = 1.2, count = 10, volley = 0.12, spread = 3, range = 70, speed = 150,
		radius = 3, type = "bullet", bypassRagdoll = true, moveMult = 0.8, color = "brown",
		cond = { test = Red( 7 ), onUse = function( ply )
			timer.Simple( 1.8, function()
				if IsValid( ply ) and ply:Alive() then K.SpawnProjectile( ply, K.REG_FRIDGE, K.Muzzle( ply ), K.AimDir( ply, 0.4 ) ) end
			end )
		end } },
	-- 8: Dashes 25 studs swinging a statue; landed, 2 more swings and a crush on the head (3 + 3 + 3 + 6): a concussion
	-- disables dashing, running and jumping for 4s (evading right after the last hit cancels it). Red: a long hop into an
	-- overhead slam (6, ragdolls again) and an 8s concussion.
	K.Grab{ "Blunt Trauma", cooldown = 14, startup = 0.3, hits = 4, interval = 0.3, hitDamage = { 3, 3, 3, 6 }, lunge = 25, type = "melee",
		bypassRagdoll = true, ragdoll = { h = 10, v = -20, time = 0.6 }, onHit = Concuss( 4 ),
		cond = { test = Red( 8 ), hits = 5, hitDamage = { 3, 3, 3, 6, 6 }, onHit = Concuss( 8 ) } },
	-- 9: A phone and two drones hovering beside the user, facing a red dot ahead that moves with them; pressing it again
	-- crashes them into each other at the dot (12, unblockable). The user walks freely meanwhile. Red: a third drone (18).
	K.Stub{ "Drone Strike", cooldown = 10, startup = 0.3, endlag = 0.1, color = "orange", tip = "USE AGAIN" },
	-- 10: A black umbrella: dashes 20 studs like an arrow, stabs (8) and pulls the enemy back with a short ragdoll.
	-- USE TWICE: opens it, a small shockwave reflecting projectiles and knocking down a bit longer (5, unblockable with the
	-- stab, 13 total, no pull). Red: melee attacks landing once the umbrella is out are deflected, stunning the attacker
	-- so the stab lands (+3).
	K.Melee{ "Fleche", cooldown = 14, startup = 0.35, damage = 8, lunge = 20, type = "melee", ragdoll = { h = -25, v = 12, time = 0.5 },
		tip = "USE TWICE",
		again = K.AoE{ "Fleche: Umbrella", window = 0.8, startup = 0.1, damage = 5, radius = 8, type = "melee", block = "none", bypassRagdoll = true,
			ragdoll = { h = 30, v = 10, time = 1.2 } },
		cond = { test = Red( 10 ), damage = 11, parry = { window = 0.35, counters = { melee = true }, iframes = 0.3 } } },
	-- 11: Extra Coupon: the same as Coupon.
	K.Stub{ "Extra Coupon", cooldown = 8, startup = 0.2, endlag = 0.1, color = "gold" },
	-- 12: Rides a scooter 55 studs; meeting an enemy early drags them along until it explodes (12), later it blows up on
	-- contact; crashing into a wall hurts the user. Red: boosters (steerable, faster, 100 studs, 14); it blows up on the
	-- rider if it goes the whole way without meeting anyone.
	K.Mobility{ "Speed Crash", cooldown = 16, startup = 0.2, travel = 55, time = 0.8, dir = "forward", damage = 12, type = "explosion", block = "none",
		bypassRagdoll = true, crater = 900, ragdoll = { h = 60, v = 30 },
		cond = { test = Red( 12 ), travel = 100, time = 1, dir = "aim", damage = 14,
			onEnd = function( ply ) if not ply.jjs_kitLanded then JJS.ApplyDamage( ply, nil, 14, { type = JJS.DMG.EXPLOSION } ) end end } },

	-- Gold skills (Con Artistry)
	-- 13: Jumps up throwing down bomb receipts exploding on the ground (24) and a spa ticket that heals 12.5 if reached in
	-- time; floats down with an umbrella (pressing again cancels the float).
	K.AoE{ "Mayhem", cooldown = 18, startup = 0.6, damage = 24, hits = 3, interval = 0.25, radius = 16, type = "explosion", block = "none",
		bypassRagdoll = true, heal = 12.5, crater = 1200, ragdoll = { h = 40, v = 35 }, color = "gold",
		onUse = function( ply ) ply:SetLocalVelocity( Vector( 0, 0, 420 ) ) end },
	-- 14: Two trucks appear behind the user and speed ~110 studs ahead, sending anyone in the way flying (30); a tiny gap
	-- between them is safe.
	K.Projectile{ "Big Moves", cooldown = 21, startup = 0.7, damage = 30, speed = 160, range = 110, radius = 10, pierce = true, type = "explosion",
		block = "none", bypassRagdoll = true, ragdoll = { h = 80, v = 30 }, color = "gold" },

	-- Items from rainbow seals (single use; TODO: exact item stats)
	K.Melee{ "Crowbar", cooldown = 1, startup = 0.25, damage = 8, reach = 10, type = "melee", ragdoll = { h = 35, v = 15 }, tip = "ITEM" }, -- 15
	K.Melee{ "Jet Black", cooldown = 1, startup = 0.3, hits = 2, interval = 0.2, damage = 10, reach = 11, type = "melee", tip = "ITEM",
		ragdoll = { h = 40, v = 20 } }, -- 16
	K.Projectile{ "Transfigured Human", cooldown = 1, startup = 0.3, damage = 8, range = 60, speed = 120, radius = 4, type = "bullet",
		ragdoll = { h = 30, v = 15 }, tip = "ITEM" }, -- 17
	K.Melee{ "Naginata", cooldown = 1, startup = 0.35, damage = 10, reach = 15, width = 8, type = "melee", ragdoll = { h = 45, v = 15 }, tip = "ITEM" }, -- 18
	K.Projectile{ "Bowling Ball", cooldown = 1, startup = 0.3, damage = 10, range = 70, speed = 110, radius = 3, gravity = 0, type = "bullet",
		bypassRagdoll = true, ragdoll = { h = 20, v = 30 }, tip = "ITEM" }, -- 19
	K.Projectile{ "Gun", cooldown = 0.5, startup = 0.15, damage = 6, range = 120, speed = 600, radius = 1, type = "bullet", stun = 0.5, tip = "ITEM" }, -- 20
	K.Melee{ "Playful Cloud", cooldown = 1, startup = 0.3, hits = 3, interval = 0.25, damage = 12, reach = 11, type = "melee", block = "none",
		ragdoll = { h = 50, v = 20 }, tip = "ITEM" }, -- 21
	K.Projectile{ "Sniper", cooldown = 1, startup = 0.6, damage = 20, range = 300, speed = 900, radius = 1, type = "bullet", ragdoll = { h = 40, v = 10 },
		tip = "ITEM" }, -- 22
	K.Projectile{ "Coin", cooldown = 1, startup = 0.2, damage = 3, range = 50, speed = 200, radius = 1, type = "bullet", stun = 0.4, tip = "ITEM" }, -- 23
	K.Projectile{ "TNT", cooldown = 1, startup = 0.35, damage = 15, range = 50, speed = 90, radius = 3, explode = 12, gravity = 300, type = "explosion",
		block = "none", bypassRagdoll = true, crater = 1000, ragdoll = { h = 40, v = 35 }, tip = "ITEM" }, -- 24
}

-- rainbow-sealed skill -> its item (coupons: a random item); item uses
local ITEM_OF = { [ 1 ] = 15, [ 2 ] = 16, [ 3 ] = 17, [ 4 ] = 18, [ 6 ] = 19, [ 7 ] = 20, [ 8 ] = 21, [ 9 ] = 22, [ 10 ] = 23, [ 12 ] = 24 }
local ITEM_USES = { [ 20 ] = 2 }
local GOLD = { 13, 14 }
local COUPONS = { [ 5 ] = true, [ 11 ] = true }

K.REG_BALL = K.Params( K.Projectile{ "Baseball", damage = 6, range = 233, speed = 260, radius = 1.5, type = "bullet", block = "none",
	trueRag = true, ragdoll = { h = 30, v = 20 }, near = { dist = 20, ragdoll = { h = 25, v = 15 } }, color = "white" } )
K.REG_FRIDGE = K.Params( K.Projectile{ "Fridge", damage = 5, range = 70, speed = 130, radius = 4, type = "bullet", block = "normal",
	blockDamage = 2.5, ragdoll = { h = 35, v = 20 }, color = "white" } )
local YOGA = K.Params( K.AoE{ "Yoga Balls", damage = 8, radius = 5, type = "swarm", block = "none", bypassRagdoll = true, ragdoll = { h = 5, v = 55 },
	color = "white" } )
local DRONES = K.Params( K.AoE{ "Drone Strike", damage = 12, radius = 9, type = "explosion", block = "none", bypassRagdoll = true, crater = 800,
	ragdoll = { h = 35, v = 30 }, color = "orange" } )

local NAMES, BUILT = {}, {}
for i, spec in ipairs( SKILLS ) do
	NAMES[ i ] = spec[ 1 ]
	BUILT[ i ] = K.Build( ID, "skill" .. i, spec )
end

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
	if not Once() then return end
	ply:SetNW2String( "JJSRegister", table.concat( slots, "," ) .. "|" .. table.concat( queue, "," ) )
end

local function Pick( ply ) return ply:GetNW2String( "JJSRegPick", "" ) end
local function SetPick( ply, p ) if Once() then ply:SetNW2String( "JJSRegPick", p ) end end

-- The skill in `slot` leaves (to the back of the queue, items and gold skills vanish) and NEXT takes its place
local function Rotate( ply, slot, replacement )
	local slots, queue = Read( ply )
	local used = slots[ slot ]
	if not used then return end
	SetSeal( ply, used, nil )
	if replacement then
		slots[ slot ] = replacement
	elseif #queue > 0 then
		slots[ slot ] = table.remove( queue, 1 )
	end
	if used <= 12 then queue[ #queue + 1 ] = used end
	Write( ply, slots, queue )
end

-- Two-press skills (Littering, Drone Strike): the second press (or a timer) triggers them, then they rotate
local function Pending( ply, id ) return ply[ "jjs_reg" .. id ] end

local function Trigger( ply, id, slot )
	local st = ply[ "jjs_reg" .. id ]
	ply[ "jjs_reg" .. id ] = nil
	if not st then return end
	if SERVER then
		if id == 3 then
			-- the receipts become yoga balls pulling people up
			for _, pos in ipairs( st.spots ) do
				for _, v in ipairs( K.SphereTargets( pos + Vector( 0, 0, 36 ), YOGA.radius, ply, true ) ) do JJS.Hit( v, K.MakeHit( ply, YOGA, v, 1, pos ) ) end
				K.Effect( "jjs_kit_burst", pos + Vector( 0, 0, 30 ), Vector( 0, 0, 1 ), ply, YOGA.radius, YOGA )
			end
			if st.red then
				timer.Simple( 0.6, function()
					if not IsValid( ply ) then return end
					for _, pos in ipairs( st.spots ) do
						for _, v in ipairs( K.SphereTargets( pos + Vector( 0, 0, 36 ), YOGA.radius * 0.7, ply, true ) ) do
							local h = K.MakeHit( ply, YOGA, v, 1, pos )
							h.damage = 5
							h.ragdoll.trueRag = true
							JJS.Hit( v, h )
						end
					end
				end )
			end
		elseif id == 9 then
			local pos = ply:GetPos() + K.Fwd( ply ) * 20 * S
			for _, v in ipairs( K.SphereTargets( pos + Vector( 0, 0, 36 ), DRONES.radius, ply, true ) ) do
				local h = K.MakeHit( ply, DRONES, v, 1, pos )
				if st.red then h.damage = 18 end
				JJS.Hit( v, h )
			end
			K.Effect( "jjs_kit_burst", pos + Vector( 0, 0, 30 ), Vector( 0, 0, 1 ), ply, DRONES.radius, DRONES )
			JJS.Destruction.GroundImpact( pos + Vector( 0, 0, 20 ), DRONES.crater )
		end
	end
	-- the move goes on cooldown and rotates only now
	local slots = Read( ply )
	for s, sid in ipairs( slots ) do
		if sid == id then
			JJS.SetCooldown( ply, s, SKILLS[ id ].cooldown )
			Rotate( ply, s )
			break
		end
	end
end

local function Arm( ply, id )
	local st = { t = CurTime() + ( id == 3 and 12 or 10 ), red = Seal( ply, id ) == "r" }
	if id == 3 then
		-- 8 receipts (16 red) scattered around the user
		st.spots = {}
		for i = 1, ( st.red and 16 or 8 ) do
			local a = i / ( st.red and 16 or 8 ) * math.pi * 2
			st.spots[ i ] = ply:GetPos() + Vector( math.cos( a ), math.sin( a ), 0 ) * ( 6 + ( i % 3 ) * 5 ) * S
		end
	end
	ply[ "jjs_reg" .. id ] = st
end

-- Uses the skill in `slot`: seals, items, special skills, then the rotation
local function UseSkill( ply, mv, slot, inner, id )
	local seal = Seal( ply, id )
	-- rainbow: the skill turns into its item
	if seal == "b" then
		local item = ITEM_OF[ id ] or ( COUPONS[ id ] and 15 + math.random( 0, 9 ) )
		SetSeal( ply, id, nil )
		ply.jjs_itemUses = ITEM_USES[ item ] or 1
		Rotate( ply, slot, item )
		JJS.SetCooldown( ply, slot, 0.3 )
		return
	end
	if id == 3 or id == 9 then
		inner.Use( ply, mv, slot )
		JJS.SetCooldown( ply, slot, 0.3 )
		Arm( ply, id )
		return
	end
	if COUPONS[ id ] then
		inner.Use( ply, mv, slot )
		-- a red-sealed coupon hands out a rainbow seal
		SetPick( ply, seal == "r" and "b" or "r" )
		Rotate( ply, slot )
		return
	end
	inner.Use( ply, mv, slot )
	if id == 4 and seal == "r" then
		-- Pole Vault's second receipt: the move stays, off cooldown
		SetSeal( ply, id, nil )
		JJS.SetCooldown( ply, slot, 0.5 )
		return
	end
	if id >= 15 then
		ply.jjs_itemUses = ( ply.jjs_itemUses or 1 ) - 1
		if ply.jjs_itemUses > 0 then return end
	end
	Rotate( ply, slot )
end

-- Each slot shows whatever skill the rotation put there
local function Slot( slot )
	local proxy = { name = "Receipt (rotating skill)" }
	proxy.Pick = function( ply )
		local slots = Read( ply )
		local id = slots[ slot ]
		local inner = BUILT[ id ]
		if not inner then return nil end
		local seal = Seal( ply, id )
		local ab = { name = inner.name .. ( seal == "r" and " [RED]" or seal == "b" and " [RAINBOW]" or "" ), cooldown = inner.cooldown,
			spec = inner.spec }
		ab.tip = function( p, s )
			local pk = Pick( p )
			if pk == "d" then return "DISCARD" end
			if pk == "r" or pk == "b" then return "SEAL" end
			if pk == "g" and ( s == 1 or s == 3 ) then return "GOLD" end
			if Pending( p, id ) then return "USE AGAIN" end
			local t = inner.tip
			if isfunction( t ) then return t( p, s ) end
			return t
		end
		ab.CanUse = function( p, s, mv )
			if Pending( p, id ) then return true end
			return inner.CanUse( p, s, mv )
		end
		-- checked before the cooldown: picks, the second press of two-press skills, follow-ups
		ab.Again = function( p, mv, s )
			local pk = Pick( p )
			if pk == "d" then
				-- Discard: NEXT replaces it, the slot keeps its cooldown
				SetPick( p, "" )
				JJS.SetCooldown( p, 5, 25 )
				p[ "jjs_reg" .. id ] = nil
				Rotate( p, s )
				return true
			end
			if pk == "r" or pk == "b" then
				SetPick( p, "" )
				SetSeal( p, id, pk )
				return true
			end
			if pk == "g" then
				if ( s ~= 1 and s ~= 3 ) or Seal( p, id ) or id > 12 then return true end
				SetPick( p, "" )
				p.jjs_regGold = ( ( p.jjs_regGold or 0 ) % 2 ) + 1
				local slots2, queue = Read( p )
				table.insert( queue, 1, slots2[ s ] )
				slots2[ s ] = GOLD[ p.jjs_regGold ]
				Write( p, slots2, queue )
				JJS.AddAwakeningTime( p, -0.06 )
				return true
			end
			if Pending( p, id ) and p:Alive() and not p:GetJRagdolled() then
				Trigger( p, id, s )
				return true
			end
			return inner.Again and inner.Again( p, mv, s ) or false
		end
		ab.Use = function( p, mv, s ) UseSkill( p, mv, s, inner, id ) end
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
		{ "Seals", "Coupons seal a skill (red: improved; rainbow: turns into an item)." },
	},

	abilities = { Slot( 1 ), Slot( 2 ), Slot( 3 ), Slot( 4 ) },
	special = {
		name = "Discard",
		cooldown = 25,
		tip = function( ply ) if Pick( ply ) == "d" then return "PICK A SLOT" end end,
		CanUse = function( ply ) return ply:Alive() end,
		-- a second press cancels
		Again = function( ply )
			if Pick( ply ) ~= "d" then return false end
			SetPick( ply, "" )
			return true
		end,
		Use = function( ply ) SetPick( ply, "d" ) end,
	},

	awakening = {
		name = "Con Artistry",
		duration = 90,
		heal = 25,
		-- A spa ticket to rejuvenate, then: "A sorcerer... is nothing but a con artist." No new moves: G then slot 1 or 3
		-- (not sealed) swaps that skill for a gold one.
	},

	OnSpawn = function( ply )
		ply:SetNW2String( "JJSRegister", START )
		ply:SetNW2String( "JJSRegSeals", "" )
		SetPick( ply, "" )
		ply.jjs_reg3, ply.jjs_reg9 = nil, nil
	end,

	-- Awakened: G, then slot 1 or 3
	AwakenPress = function( ply )
		if not ply:GetJAwakened() then return end
		SetPick( ply, Pick( ply ) == "g" and "" or "g" )
		return true
	end,
} )

-- Landing an uppercut or a final neutral M1 shaves 5s off Discard
hook.Add( "JJS_M1", "JJS_RegisterDiscard", function( ply, idx, variant, landed )
	if landed and ply:GetJChar() == ID and idx >= JJS.M1.Cfg( ply ).Count and variant ~= JJS.M1.DOWN then
		ply:SetJCD5( math.max( CurTime(), ply:GetJCD5() - 5 ) )
	end
end )

if SERVER then
	-- two-press skills fire on their own when their timer ends
	hook.Add( "Tick", "JJS_Register", function()
		for _, ply in ipairs( player.GetAll() ) do
			for _, id in ipairs( { 3, 9 } ) do
				local st = ply[ "jjs_reg" .. id ]
				if st and ( CurTime() > st.t or not ply:Alive() ) then
					if ply:Alive() then Trigger( ply, id ) else ply[ "jjs_reg" .. id ] = nil end
				end
			end
		end
	end )
end

if SERVER then return end

-- NEXT slot to the right of the special
function REG.HUDPaint( ply, now, S2 )
	local _, queue = Read( ply )
	local nxt = NAMES[ queue[ 1 ] or 0 ]
	if not nxt then return end
	local x, y = ScrW() / 2 + S2( 330 ), ScrH() - S2( 108 )
	draw.SimpleText( "NEXT", "JJS_Tip", x, y, Color( 255, 206, 84 ), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM )
	local seal = Seal( ply, queue[ 1 ] )
	draw.SimpleText( nxt .. ( seal == "r" and " [RED]" or seal == "b" and " [RAINBOW]" or "" ), "JJS_Small", x, y + S2( 2 ), color_white,
		TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP )
end
