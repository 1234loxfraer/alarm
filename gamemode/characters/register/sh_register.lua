-- Register. Generated from the JJS wiki; every move is a JJS.Kit placeholder.
-- Comments summarise what the real move does (see the wiki page for details).

local K = JJS.Kit

K.Character( "register", {
	name = "Register",
	category = "early",
	hp = 100,
	model = K.Model( "register", "models/player/group02/male_04.mdl" ),
	color = Color( 140, 220, 220 ),

	passives = {
		{ "Contractual Re-Creation", "The user's technique is able to recreate whatever was written on a contract into the physical world, which lets them store as many items and tools as they need in the form of receipts." },
	},

	abilities = {
	},
	-- After pressing the special, the user is able to ditch one of their receipts, replacing a chosen move directly with the NEXT skill by pressing the desired keybind to...
	special = K.Buff{ "Discard", cooldown = 25 },

	awakening = {
		name = "Con Artistry",
		duration = 90,
		heal = 25,
		-- The user pulls out a ticket for a day at the spa to rejuvenate, before waving their hair and proclaiming that: "A sorcerer...
		-- TODO awakening ability "Con Artistry": After awakening, the user does not get any new moves.
		abilities = {
		},
		-- Exactly the same as base.
		special = K.Buff{ "Discard", cooldown = 25 },
	},

	-- TODO other entries of the base moveset:
	--   Gushing Wound: The user quickly pulls out a receipt for a kitchen knife which they throws 95 studs forwards.
	--   Homerun: The user conjures a baseball bat then swings it harshly, launching targets or throwables upwards and away.
	--   Littering: The user spreads eight receipts which quickly fall and stick to any surfaces they touch.
	--   Pole Vault: The user pulls out a receipt for a vaulting pole then recreates the item to lift themselves off the ground while...
	--   Coupon: The user pulls out a coupon to get a discount for more items, and thus more receipts.
	--   Piano Drop: The user holds a receipt for a piano above their head, before using it up to conjure the piano from the sky and...
	--   Garage Sale: The user holds out 10 receipts for several appliances in their hand, such as chairs and desks, before shooting them...
	--   Blunt Trauma: The user quickly pulls out a receipt for a statue to swing as a weapon while dashing 25 studs.
	--   Drone Strike: The user pulls out a phone controlling two drones that will hover beside them facing a red dot marking a spot in...
	--   Fleche: The user redeems a receipt for a black umbrella, then prepares to dash 20 studs forwards like a piercing arrow,...
	--   Extra Coupon: Works exactly the same as Coupon.
	--   Speed Crash: The user quickly pulls out a receipt for a scooter which they immediately ride 55 studs forwards before drifting and...
} )
