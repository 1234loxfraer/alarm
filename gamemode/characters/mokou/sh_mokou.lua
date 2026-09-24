-- Mokou ("Others", staff/event only). The wiki has no damage numbers yet (??), so the values here are guesses.
-- Moves are JJS.Kit placeholders; comments describe what the real move does.
-- Restoration: the user revives after every death (not from the void).

local K = JJS.Kit
local S = JJS.STUD

-- Air combos: the user and the target hang in the air for a moment
local function AirCombo( ply, v )
	if not IsValid( v ) or not v:Alive() then return end
	JJS.Hover( ply, 1 )
	JJS.Hover( v, 1 )
	JJS.Stun( v, 1 )
end

-- Aetherflare Talon's burning ground
local FIRE = K.Build( "mokou", "fire", K.Zone{ "Aetherflare Fire", startup = 0, radius = 6, duration = 1.5, tick = 0.3, damage = 1, stun = 0.2,
	detached = true, center = function( ply ) return ply:GetPos() end, type = "special", block = "none", bypassRagdoll = true, color = "orange" } )

-- Danmaku: the awakened M1, a barrage of pink round bullets deleting whoever they touch
local DANMAKU = K.Build( "mokou", "danmaku", K.Projectile{ "Danmaku", startup = 0.1, endlag = 0.15, damage = 999, count = 5, volley = 0.05,
	spread = 7, range = 120, speed = 180, radius = 2, maxPitch = 1, type = "special", block = "none", bypassRagdoll = true, color = "pink" } )

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
		-- Two fiery claw slashes, then an uptilting kick lifting both the user and the opponent into the air: an air combo
		-- with M1s follows (blockable, can't hit ragdolls).
		[ 1 ] = K.Melee{ "Phoenix Maelstrom", cooldown = 5, startup = 0.3, hits = 3, interval = 0.25, hitDamage = { 4, 4, 4 }, type = "melee",
			stun = 1, color = "orange",
			onHit = function( ply, v )
				ply:SetLocalVelocity( Vector( 0, 0, 320 ) )
				v:SetLocalVelocity( Vector( 0, 0, 340 ) )
				timer.Simple( 0.35, function() if IsValid( ply ) then AirCombo( ply, v ) end end )
			end },
		-- Hops up and crashes down with a heavy dropkick, the impact area briefly on fire (unblockable, hits ragdolls); the
		-- user always takes damage first. Airborne: no hop.
		[ 2 ] = K.Melee{ "Aetherflare Talon", cooldown = 3, startup = 0.45, damage = 12, lunge = 12, type = "special", block = "none", bypassRagdoll = true,
			selfDamage = 3, crater = 900, ragdoll = { h = 10, v = -30 }, color = "orange",
			onUse = function( ply ) if ply:IsOnGround() then ply:SetLocalVelocity( Vector( 0, 0, 280 ) ) end end,
			onEnd = function( ply ) K.Trigger( ply, FIRE ) end },
		-- A pillar of flame burns the user away into a flying orb of energy: total immunity and free flight, then the body
		-- reforms within seconds.
		[ 3 ] = K.AoE{ "Scorchrise", cooldown = 8, startup = 0.3, damage = 12, radius = 10, type = "special", block = "none", bypassRagdoll = true,
			iframes = 2.5, ragdoll = { h = 10, v = 60 }, color = "orange",
			onEnd = function( ply ) JJS.Fly( ply, 2.2 ) JJS.IFrames( ply, 2.2 ) end },
		-- Several flame bullets sent barreling forward (360 aim, even on the ground).
		[ 4 ] = K.Projectile{ "Hexflare Charm", cooldown = 5, startup = 0.25, damage = 3, count = 5, volley = 0.08, spread = 6, range = 90, speed = 200,
			radius = 2.5, maxPitch = 1, type = "special", bypassRagdoll = true, color = "orange" },
	},
	-- Blazing Soar: fiery wings propel the user upward, pulling stunned enemies along into an air combo.
	special = K.Mobility{ "Blazing Soar", cooldown = 8, startup = 0.2, travel = 25, time = 0.45, dir = "up", damage = 4, type = "special",
		stun = 1.2, color = "orange",
		onContact = function( ply, v ) v:SetLocalVelocity( Vector( 0, 0, 25 * S / 0.45 ) ) ply.jjs_soared = v end,
		onEnd = function( ply ) AirCombo( ply, ply.jjs_soared ) ply.jjs_soared = nil end },

	awakening = {
		name = "Immortal Blaze",
		duration = 60,
		heal = 25,
		-- Plays both of Honored One's awakening sequences (TODO: the sequences).
		-- Danmaku: M1 fires a barrage of pink round bullets that delete opponents on contact.
		-- Flight (special): toggles unrestricted free flight, no endlag or cost.
		special = {
			name = "Flight",
			cooldown = 0.3,
			tip = function( ply ) return JJS.IsFlying( ply ) and "LAND" or "FLY" end,
			CanUse = function( ply ) return ply:Alive() and not ply:GetJRagdolled() end,
			Use = function( ply )
				JJS.SetCooldown( ply, 5, 0.3 )
				JJS.Fly( ply, JJS.IsFlying( ply ) and 0 or 3600 )
			end,
		},
	},

	M1Override = function( ply, mv )
		if not ply:GetJAwakened() then return false end
		if JJS.IsBusy( ply ) or not JJS.CanAct( ply ) or ( ply.jjs_danmakuCD or 0 ) > CurTime() then return true end
		ply.jjs_danmakuCD = CurTime() + 0.45
		DANMAKU.Use( ply, mv, 0 )
		return true
	end,
} )

-- the awakening keeps the base moves (only the special and the M1s change)
JJS.Characters.mokou.awakening.abilities = JJS.Characters.mokou.abilities

if SERVER then
	hook.Add( "JJS_PreventDeath", "JJS_MokouRestoration", function( victim )
		if victim:GetJChar() ~= "mokou" then return end
		victim:SetJHP( victim:GetMaxHealth() )
		victim:SetHealth( victim:GetMaxHealth() )
		JJS.IFrames( victim, 2 )
		JJS.Util.Effect( "jjs_kit_burst", JJS.Util.BodyCenter( victim ), Vector( 0, 0, 1 ), victim, 200, JJS.Kit.COLOR_ID.orange )
		return true
	end )
	hook.Add( "JJS_AwakeningEnd", "JJS_MokouFlight", function( ply ) if ply:GetJChar() == "mokou" then JJS.Fly( ply, 0 ) end end )
end
