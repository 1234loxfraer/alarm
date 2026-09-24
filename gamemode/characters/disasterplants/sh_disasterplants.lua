-- Disaster Plants (Hanami). Moves are JJS.Kit placeholders built from the JJS fandom wiki and the
-- dogslamloop frame data wiki; comments describe what the real move does.
--
-- Spikes: Root Swarm, Plant Guidance's Sprout, the aerial Defense Response, Unwrap and Flower Field leave spikes that
-- persist for 5 minutes; a ragdolled enemy thrown into one bounces to another spike, or back to the user (7).
-- Plant Guidance (special): marks a spot within 65 studs (0.5s, usable during other actions; pressing again moves
-- it). Root Swarm, Surging Thorns or Defense Response used while airborne or during an action (blocking included)
-- then trigger a special attack on the mark instead; the move stays off cooldown (it doesn't even need to be off
-- cooldown) and the special goes on 12s.
-- Buds (Bud Shot, Cursed Buds) latch onto the torso and drain cursed energy until the target uses a skill; each one
-- then takes 7s off the special's cooldown.

local K = JJS.Kit
local S = JJS.STUD

local function Marked( ply ) return ply:GetNW2Float( "JJSMarkT", 0 ) > 0 end
local function Mark( ply ) return Marked( ply ) and ply:GetNW2Vector( "JJSMark" ) or nil end
local function Empowered( ply ) return ply:GetNW2Bool( "JJSEmpowered", false ) end

------------------------------------------------------------------------------------------
-- Spikes
------------------------------------------------------------------------------------------
local function AddSpike( ply, pos, bounce )
	if CLIENT then return end
	ply.jjs_spikes = ply.jjs_spikes or {}
	table.insert( ply.jjs_spikes, { pos = pos, t = CurTime() + 300, bounce = bounce or 7 } )
	if #ply.jjs_spikes > 12 then table.remove( ply.jjs_spikes, 1 ) end
	JJS.Util.Effect( "jjs_kit_burst", pos + Vector( 0, 0, 20 ), Vector( 0, 0, 1 ), ply, 6 * S, K.COLOR_ID.brown )
end

local function NearestSpike( ply, pos, maxDist, skip )
	local best, bd = nil, ( maxDist or math.huge ) ^ 2
	for _, s in ipairs( ply.jjs_spikes or {} ) do
		local d = s.pos:DistToSqr( pos )
		if s ~= skip and d < bd then best, bd = s, d end
	end
	return best
end

-- A ragdolled target flung at a position
local function Fling( v, to, ply )
	local rag = v:GetJRagEnt()
	local from = IsValid( rag ) and rag:GetPos() or v:GetPos()
	local dir = JJS.Util.Flat( to - from )
	local vel = dir * math.Clamp( from:Distance( to ) * 2, 30 * S, 80 * S ) + Vector( 0, 0, 25 * S )
	if v:GetJRagdolled() and IsValid( rag ) then
		JJS.Ragdoll.SetVelocity( rag, vel )
	else
		JJS.Ragdoll.Apply( v, { time = 1, vel = vel }, ply )
	end
end

------------------------------------------------------------------------------------------
-- Plant Guidance and its special attacks
------------------------------------------------------------------------------------------
local GUIDANCE = {
	name = "Plant Guidance",
	cooldown = 0.5,
	tip = function( ply ) if Marked( ply ) then return "MARKED" end end,
	CanUse = function( ply ) return ply:Alive() and not ply:GetJRagdolled() end,
	Use = function( ply )
		local start = ply:EyePos()
		local tr = util.TraceLine( { start = start, endpos = start + ply:GetAimVector() * 65 * S, mask = MASK_SOLID_BRUSHONLY } )
		local down = util.TraceLine( { start = tr.HitPos + Vector( 0, 0, 10 ), endpos = tr.HitPos - Vector( 0, 0, 200 * S ), mask = MASK_SOLID_BRUSHONLY } )
		ply:SetNW2Vector( "JJSMark", down.HitPos )
		ply:SetNW2Float( "JJSMarkT", CurTime() )
		JJS.SetCooldown( ply, 5, 0.5 )
	end,
}

local function AtMark( ply ) return Mark( ply ) end

local GUIDED = {
	-- Sprout: a small bundle of intangible spikes (bounces ragdolled enemies thrown at it, 4)
	[ 1 ] = function( ply ) AddSpike( ply, Mark( ply ), 4 ) end,
	-- Thorn Impale: a long thorn pokes whoever stands over the mark (9, breaks blocks for 12); interrupting an action
	-- knocks them face-first into the floor with a stun instead
	[ 2 ] = K.Build( "disasterplants", "guided2", K.AoE{ "Thorn Impale", startup = 0.25, damage = 9, radius = 4, center = AtMark, detached = true,
		type = "swarm", block = "none", bypassRagdoll = true, color = "brown", ragdoll = { h = -20, v = 45 },
		interrupt = { damage = 3, stun = 1.6 }, guardBreak = { damage = 12, stun = 1.5 } } ),
	-- Flower Patch: an 8x8 stud bed of flowers for 6s; anyone acting in it (not blocking or side dashing) is interrupted
	-- and stunned (6), once per field; it can't kill. Takes priority over the aerial Defense Response.
	[ 4 ] = K.Build( "disasterplants", "guided4", K.Zone{ "Flower Patch", startup = 0.1, radius = 4, duration = 6, tick = 0.1, damage = 6,
		center = AtMark, detached = true, acting = true, once = true, noKill = true, stun = 1, type = "swarm", block = "none",
		bypassRagdoll = true, color = "pink" } ),
}

-- A move pressed airborne or during an action with a mark down: its special attack on the mark
local function Guided( slot )
	return function( ply )
		if not Marked( ply ) or ply:GetJAwakened() or not ply:Alive() or ply:GetJRagdolled() then return false end
		if ply:IsOnGround() and not JJS.IsBusy( ply ) and not JJS.IsBlocking( ply ) then return false end
		if JJS.GetCooldown( ply, 5 ) > CurTime() then return false end
		local g = GUIDED[ slot ]
		if isfunction( g ) then
			if SERVER then g( ply ) end
		else
			K.Trigger( ply, g )
		end
		JJS.SetCooldown( ply, 5, 12 )
		return true
	end
end

------------------------------------------------------------------------------------------
-- Buds
------------------------------------------------------------------------------------------
local function Latch( ply, v )
	if not v:IsPlayer() then return end
	v:SetNW2Int( "JJSBuds", v:GetNW2Int( "JJSBuds", 0 ) + 1 )
	v.jjs_budOwner = ply
end

-- Lasso (replaces the front dash): a long root grabs a target within 50 studs and sets them in front (4, true
-- ragdoll, can't kill; 10s)
local LASSO = K.Build( "disasterplants", "lasso", K.Target{ "Lasso", range = 50, cone = 0.85, teleport = false, pullIn = true, startup = 0.3,
	endlag = 0.3, damage = 4, type = "swarm", block = "normal", bypassRagdoll = true, trueRag = true, noKill = true, color = "brown",
	ragdoll = { time = 0.7, h = 0, v = 5 } } )
-- Unwrap's front dash: Defense Response's smack
local SMACK = K.Build( "disasterplants", "smack", K.Melee{ "Defense Response", startup = 0.35, damage = 12, lunge = 12, type = "melee",
	block = "none", meleeIFrames = 0.35, stun = 1.2, knock = 45 } )

-- Energy Absorb's Flower Beam (20s): 35.6, or 104 and bigger right after the domain
local FLOWER_BEAM = K.Build( "disasterplants", "flowerbeam", K.Beam{ "Flower Beam", startup = 1, damage = 35.6, duration = 1, tick = 0.25,
	range = 120, radius = 6, pierce = true, clash = 2, type = "explosion", block = "none", bypassRagdoll = true, color = "gold",
	ragdoll = { h = 60, v = 25 },
	cond = { test = function( ply ) return ply.jjs_domainBeam end, damage = 104, radius = 10, clash = 3,
		onUse = function( ply ) ply.jjs_domainBeam = nil end } } )

-- Moves 1-3 in Unwrap use the empowered state up (not during the domain)
local function UseEmpower( ply )
	if not ply.jjs_inDomain then ply:SetNW2Bool( "JJSEmpowered", false ) end
end

K.Character( "disasterplants", {
	name = "Disaster Plants",
	category = "complete",
	hp = 100,
	scale = 1.25,
	model = K.Model( "disasterplants", "models/player/charple.mdl" ),
	color = Color( 120, 220, 90 ),

	-- Arm Wrap: the string is a single 4 damage hit that loses its stun/ragdoll on targets mid-action (TODO). Neutral: a
	-- gut punch with unevadable stun. Uppercut: 14 studs of range, then a giant thorn surges (hits ragdolls, blockable
	-- from all sides). Downslam: 10 studs, bounces them up and away instead of grounding (blockable, no evasion bonus).
	m1 = { Count = 1, Damage = { 4 }, Variants = {
		[ 0 ] = { stun = 1.2, knock = 30 },
		[ 1 ] = { reach = 14, bypassRagdoll = true, block = "all", h = 8, v = 75 },
		[ 2 ] = { reach = 10, block = "normal", bypassRagdoll = false, h = 30, v = 40 },
	} },

	passives = {
		{ "Arm Wrap", "1.25x taller; the M1 string is a single 4 damage hit (longer uppercuts and downslams)." },
		{ "Lasso", "The front dash becomes a 50 stud root grab (4, 10s cooldown)." },
		{ "Spikes", "Spikes bounce ragdolled enemies thrown at them to other spikes or back to the user (7)." },
	},

	abilities = {
		-- A line of roots grows 50 studs along the ground over 2s, lifting anyone in the way off the ground and away (10,
		-- unblockable). Hit from 25 to 50 studs, the enemy is knocked back to the user as a bundle of spikes emerges.
		-- Facing a gap or jumping: the roots are a tangible bridge for 4s (semi blockable; TODO).
		-- Special attack (Plant Guidance): Sprout.
		[ 1 ] = K.Beam{ "Root Swarm", cooldown = 15, startup = 0.5, damage = 10, range = 50, radius = 4, pierce = true, maxPitch = 0.05,
			type = "swarm", block = "none", bypassRagdoll = true, color = "brown", ragdoll = { h = 30, v = 45 }, tip = "SPECIAL",
			far = { dist = 25, ragdoll = { h = -45, v = 20 },
				onHit = function( ply ) AddSpike( ply, ply:GetPos() + K.Fwd( ply ) * 5 * S ) end } },
		-- Two wooden balls sprout branches pushing targets within 35 studs back (5; through block, can't hit ragdolls) onto
		-- 3 thorns tossing them further (5 + 5, blockable from all sides). Special attack: Thorn Impale.
		[ 2 ] = K.Target{ "Surging Thorns", cooldown = 16, teleport = false, range = 35, cone = 0.8, startup = 0.4, hits = 3, interval = 0.3,
			hitDamage = { 5, 5, 5 }, hitBlock = { "normal", "all", "all" }, hitBypass = { false, true, true }, hitKnock = { 40, 0, 0 },
			knockBlock = true, type = "bullet", color = "green", ragdoll = { h = 50, v = 30 }, tip = "SPECIAL" },
		-- Chucks two cursed buds 70 studs (4 each): targets within 35 studs are pushed away, further ones pulled in. They
		-- latch on (see Buds).
		[ 3 ] = K.Projectile{ "Bud Shot", cooldown = 15, startup = 0.35, damage = 4, count = 2, volley = 0.15, spread = 6, range = 70, speed = 150,
			radius = 2.5, type = "bullet", bypassRagdoll = true, color = "green", ragdoll = { time = 0.6, h = -30, v = 12 },
			near = { dist = 35, ragdoll = { time = 0.6, h = 35, v = 12 } }, onHit = Latch },
		-- Reclines, then surges forward with melee i-frames into a heavy smack (12, unblockable) knocking the target with
		-- evadable stun; it doesn't cancel a ragdoll. With a spike within 60 studs, a root seizes the victim and flings
		-- them at the nearest one. Airborne: a spike rises 25 studs away launching anyone above it (8, then it stays
		-- as a spike). Special attack: Flower Patch.
		[ 4 ] = K.Melee{ "Defense Response", cooldown = 15, startup = 0.5, damage = 12, lunge = 12, type = "melee", block = "none",
			meleeIFrames = 0.5, stun = 1.2, knock = 45,
			onHit = function( ply, v )
				local s = NearestSpike( ply, v:GetPos(), 60 * S )
				if s then Fling( v, s.pos, ply ) end
			end,
			air = { kind = "aoe", damage = 8, radius = 6, offset = 25, up = -10, type = "swarm", bypassRagdoll = true, knock = false, stun = false,
				ragdoll = { h = 5, v = 60 }, color = "brown", meleeIFrames = false, onHit = false,
				onUse = function( ply ) AddSpike( ply, ply:GetPos() + K.Fwd( ply ) * 25 * S - Vector( 0, 0, 10 ) ) end } },
	},
	special = GUIDANCE,

	-- Lasso / Unwrap's smack
	FrontDash = function( ply, mv )
		if ply:GetJAwakened() then
			ply:SetJDashFrontCD( CurTime() + JJS.Config.Dash.FrontCooldown )
			SMACK.Use( ply, mv, 0 )
			return true
		end
		ply:SetJDashFrontCD( CurTime() + 10 )
		if IsValid( K.AimTarget( ply, 50 * S, 0.85 ) ) then LASSO.Use( ply, mv, 0 ) end
		return true
	end,

	awakening = {
		name = "Unwrap",
		duration = 60,
		heal = 25,
		-- "It would seem that... I should take you somewhat seriously." The wrap comes off, a flower bud on the shoulder,
		-- and five spikes rise behind them. Both hands again: the normal 4 hit string (3 + 3 + 4 + 4); the front dash
		-- becomes Defense Response's smack.
		m1 = { Count = 4, Damage = { 3, 3, 4, 4 }, Variants = false },
		abilities = {
			-- Kneels and sends a line of tangible roots for 7s wherever the user points (even upward), crashing into anyone in
			-- the path (5 per hit, perfect blockable); they persist 30s, up to 385 studs. Pressing again guides another
			-- root (15% awakening each), the special ends it; a perfect block turns the roots aside.
			-- Empowered: another root on top of the first. Airborne: "Thorn Rampage", roots carry the user up onto a wooden
			-- ball that fires a thorn at every enemy under it (25; up to 50 studs around, none from over 75 studs up).
			-- TODO: extra roots, persistence.
			[ 1 ] = K.Beam{ "Root Rampage", cooldown = 16, startup = 0.6, damage = 30, duration = 3, tick = 0.5, range = 90, radius = 4, pierce = true,
				maxPitch = 0.9, type = "bullet", block = "pre", bypassRagdoll = true, color = "brown", ragdoll = { h = 40, v = 25 }, onUse = UseEmpower,
				cond = { test = Empowered, damage = 60, duration = 6 },
				air = { kind = "aoe", damage = 25, radius = 25, offset = 0, up = -30, type = "bullet", block = "none", duration = false,
					ragdoll = { h = 5, v = 50 } } },
			-- Aims a 20x20 stud field of flowers (pressing again sooner places it closer): anyone acting in it or where the
			-- user aims is stunned in place (6). Once placed, a giant bundle of thorns emerges in the middle launching
			-- enemies up (12) and stays as a spike. Empowered: a living spike with a gaping mouth (bounces 4 targets; the
			-- move again near it hurls a target at it, 4). TODO: aiming, the amalgamation.
			[ 2 ] = K.Zone{ "Flower Field", cooldown = 16, startup = 0.5, radius = 10, offset = 20, duration = 6, tick = 0.2, damage = 6, stun = 1,
				acting = true, once = true, type = "swarm", block = "none", bypassRagdoll = true, color = "pink", onUse = UseEmpower,
				onPlace = function( ply, pos )
					for _, v in ipairs( K.SphereTargets( pos + Vector( 0, 0, 36 ), 5 * S, ply, true ) ) do
						JJS.Hit( v, { attacker = ply, damage = 12, type = JJS.DMG.SWARM, block = "none", bypassRagdoll = true,
							ragdoll = { time = 1, vel = Vector( 0, 0, 60 * S ) } } )
					end
					AddSpike( ply, pos )
				end },
			-- A handsign summons a massive flower that ragdolls everyone nearby away (8), then shoots 15 cursed buds like a
			-- turret wherever the cursor aims (1.7 each, semi blockable; they latch like Bud Shot's). Empowered: a bigger
			-- flower with twice the buds, unblockable.
			[ 3 ] = K.Projectile{ "Cursed Buds", cooldown = 16, startup = 0.8, damage = 1.7, count = 15, volley = 0.1, spread = 3, range = 90,
				speed = 170, radius = 2.5, type = "bullet", blockDamage = 0.85, bypassRagdoll = true, color = "green", onHit = Latch,
				onUse = function( ply )
					UseEmpower( ply )
					for _, v in ipairs( K.SphereTargets( JJS.Util.BodyCenter( ply ), 12 * S, ply, true ) ) do
						JJS.Hit( v, { attacker = ply, damage = 8, type = JJS.DMG.SWARM, block = "none", bypassRagdoll = true,
							ragdoll = { time = 1, vel = JJS.Util.Flat( v:GetPos() - ply:GetPos() ) * 45 * S + Vector( 0, 0, 20 * S ) } } )
					end
				end,
				cond = { test = Empowered, count = 30, block = "none", blockDamage = false } },
			-- Domain Expansion: kneels to sap energy from the foliage; inside, any action other than running, side dashing
			-- or blocking is interrupted and punished (4, stun). The user stays empowered for the whole domain and Flower
			-- Beam comes off cooldown, bigger (104).
			[ 4 ] = K.Domain{ "Shining Sea of Growing Branches", cooldown = 120, duration = 15, sureHit = "acting", dps = 4, color = "green",
				onUse = function( ply )
					ply.jjs_inDomain = CurTime() + 16
					ply.jjs_domainBeam = true
					ply:SetNW2Bool( "JJSEmpowered", true )
					ply:SetNW2Float( "JJSBeamCD", 0 )
				end },
		},
		-- Energy Absorb: stores cursed energy in the flower arm (5% awakening; 12s): empowered, with a golden aura, until
		-- one of the first 3 moves uses it or the awakening ends. Pressed again while empowered: Flower Beam, the flower's
		-- eye fires a devastating beam (35.6; beam clash rank 2; 20s, 12s on the special).
		special = {
			name = "Energy Absorb",
			cooldown = 12,
			tip = function( ply ) if Empowered( ply ) then return "FLOWER BEAM" end end,
			Again = function( ply, mv )
				if not Empowered( ply ) or not ply:Alive() or ply:GetJRagdolled() or JJS.IsStunned( ply ) or JJS.IsBusy( ply ) then return false end
				if ply:GetNW2Float( "JJSBeamCD", 0 ) > CurTime() then return true end
				ply:SetNW2Float( "JJSBeamCD", CurTime() + 20 )
				JJS.SetCooldown( ply, 5, 12 )
				FLOWER_BEAM.Use( ply, mv, 0 )
				return true
			end,
			Use = function( ply )
				JJS.SetCooldown( ply, 5, 12 )
				JJS.AddAwakeningTime( ply, -0.05 )
				ply:SetNW2Bool( "JJSEmpowered", true )
				if SERVER then JJS.Util.Effect( "jjs_kit_cast", JJS.Util.BodyCenter( ply ), nil, ply, 1.2, K.COLOR_ID.gold ) end
			end,
		},
	},
} )

-- the special attacks on the mark are checked before the moves' cooldowns
local dp = JJS.Characters.disasterplants
for _, slot in ipairs( { 1, 2, 4 } ) do dp.abilities[ slot ].Again = Guided( slot ) end

if SERVER then
	hook.Add( "Tick", "JJS_DisasterPlants", function()
		local now = CurTime()
		for _, ply in ipairs( player.GetAll() ) do
			-- spikes bounce ragdolled enemies to another spike or back to their owner
			if ply.jjs_spikes then
				for i = #ply.jjs_spikes, 1, -1 do
					local s = ply.jjs_spikes[ i ]
					if now > s.t or not ply:Alive() then
						table.remove( ply.jjs_spikes, i )
					else
						for _, v in ipairs( player.GetAll() ) do
							if v ~= ply and v:Alive() and v:GetJRagdolled() and ( v.jjs_bounceCD or 0 ) < now then
								local rag = v:GetJRagEnt()
								local pos = IsValid( rag ) and rag:GetPos() or v:GetPos()
								if pos:DistToSqr( s.pos ) < ( 5 * S ) ^ 2 then
									v.jjs_bounceCD = now + 0.6
									local nxt = NearestSpike( ply, s.pos, 80 * S, s )
									Fling( v, nxt and nxt.pos or ply:GetPos(), ply )
									JJS.ApplyDamage( v, ply, s.bounce, { type = JJS.DMG.SWARM } )
								end
							end
						end
					end
				end
			end
			-- latched buds drain cursed energy (awakening progress)
			local buds = ply:GetNW2Int( "JJSBuds", 0 )
			if buds > 0 and not ply:GetJAwakened() then
				ply:SetJAwaken( math.max( 0, ply:GetJAwaken() - FrameTime() * 0.004 * buds ) )
			end
			-- the domain's empowerment ends with it
			if ply.jjs_inDomain and now > ply.jjs_inDomain then ply.jjs_inDomain = nil end
		end
	end )

	-- a skill going on cooldown sheds the buds: 7s off their owner's special each
	hook.Add( "JJS_Cooldown", "JJS_Buds", function( ply )
		local buds = ply:GetNW2Int( "JJSBuds", 0 )
		if buds <= 0 then return end
		ply:SetNW2Int( "JJSBuds", 0 )
		local o = ply.jjs_budOwner
		if IsValid( o ) and o:GetJChar() == "disasterplants" then
			local kit = o:GetJKitSet()
			o:SetJKitSet( 0 )
			JJS.SetCooldown( o, 5, math.max( 0, JJS.GetCooldown( o, 5 ) - CurTime() - 7 * buds ) )
			o:SetJKitSet( kit )
		end
	end )

	-- Unwrap: five spikes rise behind the user
	hook.Add( "JJS_Awakened", "JJS_Unwrap", function( ply )
		if ply:GetJChar() ~= "disasterplants" then return end
		local back = -K.Fwd( ply )
		local right = ply:EyeAngles():Right()
		for i = -2, 2 do AddSpike( ply, ply:GetPos() + back * 8 * S + right * i * 5 * S ) end
	end )
	hook.Add( "JJS_AwakeningEnd", "JJS_Unwrap", function( ply )
		ply:SetNW2Bool( "JJSEmpowered", false )
		ply.jjs_domainBeam = nil
		ply.jjs_inDomain = nil
	end )
end

hook.Add( "JJS_PlayerSpawned", "JJS_DisasterPlants", function( ply )
	ply:SetNW2Float( "JJSMarkT", 0 )
	ply:SetNW2Int( "JJSBuds", 0 )
	ply:SetNW2Bool( "JJSEmpowered", false )
	ply:SetNW2Float( "JJSBeamCD", 0 )
	ply.jjs_spikes = nil
end )
