-- Mokou ("Others", staff/event only). The wiki has no damage numbers yet (??), so the values here are guesses.
-- Moves are JJS.Kit placeholders; comments describe what the real move does.
-- Restoration: the user revives after every death.

local K = JJS.Kit

K.Character( "mokou", {
	name = "Mokou",
	category = "other",
	hp = 100,
	model = K.Model( "mokou", "models/player/mossman_arctic.mdl" ),
	color = Color( 255, 120, 60 ),

	passives = {
		{ "Restoration", "Revives in flames after every death: \"the legendary phoenix that grows stronger each time it's reborn.\"" },
	},

	abilities = {
		-- Two fiery claw slashes and an uptilting kick lifting both into the air for an air combo.
		[ 1 ] = K.Melee{ "Phoenix Maelstrom", cooldown = 5, startup = 0.3, damage = 12, hits = 3, interval = 0.25, type = "melee",
			ragdoll = { h = 5, v = 55 }, color = "orange" },
		-- Hops up and crashes down with a heavy dropkick that sets the impact area on fire; the user always takes damage first.
		[ 2 ] = K.Melee{ "Aetherflare Talon", cooldown = 3, startup = 0.45, damage = 12, lunge = 12, type = "special", block = "none", bypassRagdoll = true,
			selfDamage = 3, crater = 900, ragdoll = { h = 10, v = -30 }, color = "orange" },
		-- A pillar of flame: the user turns into a flying orb of energy with total immunity, then reforms.
		[ 3 ] = K.AoE{ "Scorchrise", cooldown = 8, startup = 0.3, damage = 12, radius = 10, type = "special", block = "none", bypassRagdoll = true,
			iframes = 2.5, ragdoll = { h = 10, v = 60 }, color = "orange" },
		-- Several flame bullets sent barreling forward (360 aim, even on the ground).
		[ 4 ] = K.Projectile{ "Hexflare Charm", cooldown = 5, startup = 0.25, damage = 3, count = 5, volley = 0.08, spread = 6, range = 90, speed = 200,
			radius = 2.5, type = "special", bypassRagdoll = true, color = "orange" },
	},
	-- Blazing Soar: fiery wings propel the user upward, pulling enemies along for an air combo.
	special = K.Mobility{ "Blazing Soar", cooldown = 8, startup = 0.2, travel = 25, time = 0.45, dir = "up", damage = 4, type = "special",
		stun = 1.2, color = "orange" },

	awakening = {
		name = "Immortal Blaze",
		duration = 60,
		heal = 25,
		-- Plays both of Honored One's awakening sequences.
		-- TODO passive "Danmaku": M1s fire a barrage of pink bullets that delete opponents; special "Flight": toggled free flight.
	},
} )

if SERVER then
	hook.Add( "JJS_PreventDeath", "JJS_MokouRestoration", function( victim )
		if victim:GetJChar() ~= "mokou" then return end
		victim:SetJHP( victim:GetMaxHealth() )
		victim:SetHealth( victim:GetMaxHealth() )
		JJS.IFrames( victim, 2 )
		JJS.Util.Effect( "jjs_kit_burst", JJS.Util.BodyCenter( victim ), Vector( 0, 0, 1 ), victim, 200, JJS.Kit.COLOR_ID.orange )
		return true
	end )
end
