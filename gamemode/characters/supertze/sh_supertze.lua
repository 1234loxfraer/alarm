-- Super TZE. Generated from the JJS wiki; every move is a JJS.Kit placeholder.
-- Comments summarise what the real move does (see the wiki page for details).

local K = JJS.Kit

K.Character( "supertze", {
	name = "Super TZE",
	category = "other",
	hp = 100,
	model = K.Model( "supertze", "models/player/group01/male_01.mdl" ),
	color = Color( 255, 255, 120 ),

	passives = {
		{ "Sonic Boom", "Tze gains the ability to fly after transforming, allowing him to hover in the air and quickly move by dashing." },
		{ "Super Punch", "Tze's basic melee attack combo has been replaced with a rapid lunge into any locked-on target with his fist wound up, followed up by a devastating strike that ragdolls them away." },
		{ "Energy Volley", "By using his melee and dash at the same time, Tze will start rapidly firing a volley of bright yellow blasts that will home in on a target, before detonating on contact." },
	},

	abilities = {
	},
	-- In his Super form, Tze possesses a customized lock-on that allows him to select any target he wishes, even through walls.
	special = K.Buff{ "Lock-On" },

	-- TODO other entries of the base moveset:
	--   Going Super [awakening]: Tze begins floating upwards while the seven Chaos Emeralds circle around him before he absorbs them, his hair...
} )
