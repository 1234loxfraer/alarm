-- Salaryman (Kento Nanami). Moves are JJS.Kit placeholders built from the JJS fandom wiki and the
-- dogslamloop frame data wiki; comments describe what the real move does.
--
-- Ratio Point (special): aimed at a target within 70 studs, a bar split in tenths appears over their head (only the
-- user sees it) and a circle runs across it, faster the lower their health. Pressing the special again with the
-- circle on the red 7:3 line marks a weak point on them for 4.5s. The cooldown (5s) starts once the bar is gone,
-- and is skipped if the marked target gets interrupted by a move. Overtime: no cooldown, several targets.
-- The next Ratio move landed on a marked target is enhanced and removes the mark (moves carry a `ratio` table:
-- mult = damage multiplier (or hitMult per hit), unblockable, arm/leg = stagger seconds, onInterrupt = only when
-- the hit interrupts). A staggered arm lowers the block angle, a staggered leg can't dash.

local K = JJS.Kit

local function Marked( v, by )
	return v:GetNW2Float( "JJSRatio", 0 ) > CurTime() and ( not by or v:GetNW2Entity( "JJSRatioBy" ) == by )
end

local function QTEActive( ply ) return ply:GetNW2Float( "JJSQTEStart", 0 ) > 0 end
-- The circle's position on the bar (0..1)
local function QTEPos( ply )
	return ( CurTime() - ply:GetNW2Float( "JJSQTEStart", 0 ) ) / math.max( ply:GetNW2Float( "JJSQTELen", 1 ), 0.1 )
end

local function EndQTE( ply, cooldown )
	ply:SetNW2Float( "JJSQTEStart", 0 )
	if not ply:GetJAwakened() then JJS.SetCooldown( ply, 5, cooldown ) end
end

-- The special: start the QTE, then press on the 7:3 line
local RATIO = {
	name = "Ratio Point",
	cooldown = 5,
	tip = function( ply ) if QTEActive( ply ) then return "7:3!" end end,
	CanUse = function( ply ) return ply:Alive() and not ply:GetJRagdolled() and IsValid( K.AimTarget( ply, 70 * JJS.STUD, 0.9 ) ) end,
	Again = function( ply )
		if not QTEActive( ply ) then return false end
		local t = ply:GetNW2Entity( "JJSQTETarget" )
		if math.abs( QTEPos( ply ) - 0.7 ) <= 0.07 and IsValid( t ) and t:Alive() then
			t:SetNW2Float( "JJSRatio", CurTime() + 4.5 )
			t:SetNW2Entity( "JJSRatioBy", ply )
			if SERVER then JJS.Util.Effect( "jjs_kit_burst", JJS.Util.BodyCenter( t ), Vector( 0, 0, 1 ), t, 30, K.COLOR_ID.gold ) end
			EndQTE( ply, 4.5 + 5 )
		else
			EndQTE( ply, 5 )
		end
		return true
	end,
	Use = function( ply )
		local t = K.AimTarget( ply, 70 * JJS.STUD, 0.9 )
		if not IsValid( t ) then return end
		local frac = math.Clamp( t:GetJHP() / math.max( t:GetMaxHealth(), 1 ), 0, 1 )
		ply:SetNW2Entity( "JJSQTETarget", t )
		ply:SetNW2Float( "JJSQTELen", 0.5 + 0.9 * frac )
		ply:SetNW2Float( "JJSQTEStart", CurTime() )
		JJS.SetCooldown( ply, 5, 0.2 )
	end,
}

-- Stabilize landed with an interruption or on a marked target: Overtime can rush in with a Black Flash
local function Stabilized( ply ) ply.jjs_stabilized = CurTime() end

-- Awakening variant: a rush and a sudden black flash (12, 16 with Ratio); missed, no awakening and 60% of the bar lost
local OT_FLASH = K.Build( "salaryman", "otflash", K.Rush{ "Overtime: Black Flash", startup = 0.15, travel = 25, time = 0.4, damage = 12,
	type = "melee", block = "none", uninterruptible = true, color = "black", ratio = { mult = 16 / 12 }, ragdoll = { h = 60, v = 20 },
	onHit = function( ply )
		ply.jjs_otLanded = true
		timer.Simple( 0, function()
			if not IsValid( ply ) or not ply:Alive() then return end
			JJS.EnterAwakening( ply, nil, 25 )
			ply:SetNW2Int( "JJSRBStage", 2 )
		end )
	end,
	onFinish = function( ply ) if not ply.jjs_otLanded then ply:SetJAwaken( 0.4 ) end end } )

-- Ratio Breaker: four stages, each has to land on a marked target to go on (else cooldown and back to stage 1)
local function StageStart( ply ) ply.jjs_ratioLanded = nil end
local function Stage( n )
	return function( ply, p, interrupted )
		if n < 4 and ply.jjs_ratioLanded then
			ply:SetNW2Int( "JJSRBStage", n + 1 )
			JJS.SetCooldown( ply, 1, 0 )
		else
			ply:SetNW2Int( "JJSRBStage", 1 )
			JJS.SetCooldown( ply, 1, 19 )
		end
	end
end

local function RatioBreaker()
	local st = {
		-- I: a downward slash waking ragdolled players (5), then a charged right hook with a sparking Black Flash (5);
		-- Ratio on either hit (10 each, up to 20). Skipped when the awakening came from Stabilize.
		K.Melee{ "Ratio Breaker I", cooldown = 0, startup = 0.35, hits = 2, interval = 0.35, hitDamage = { 5, 5 }, type = "melee",
			block = "none", bypassRagdoll = true, trueRag = true, ratio = { mult = 2 }, ragdoll = { h = 40, v = 20 }, tip = "1/4",
			onUse = StageStart, onFinish = Stage( 1 ) },
		-- II: a single straight Black Flash punch with melee i-frames (7, 14 with Ratio); interrupting a marked target
		-- staggers their arm for 12s.
		K.Melee{ "Ratio Breaker II", cooldown = 0, startup = 0.4, damage = 7, type = "melee", block = "none", meleeIFrames = 0.4, lunge = 8,
			ratio = { mult = 2, arm = 12, onInterrupt = true }, ragdoll = { h = 55, v = 15 }, color = "black", tip = "2/4", onUse = StageStart,
			onFinish = Stage( 2 ) },
		-- III: a long hop winding up a heavy slam crushing the area with black sparks (10, 20 with Ratio).
		K.AoE{ "Ratio Breaker III", cooldown = 0, startup = 0.6, damage = 10, radius = 12, offset = 12, type = "explosion", block = "none",
			bypassRagdoll = true, ratio = { mult = 2 }, crater = 1200, ragdoll = { h = 10, v = 45 }, color = "black", tip = "3/4",
			onUse = function( ply )
				StageStart( ply )
				ply:SetLocalVelocity( K.Fwd( ply ) * 20 * JJS.STUD + Vector( 0, 0, 300 ) )
			end, onFinish = Stage( 3 ) },
		-- IV: melee i-frames while twirling the black-sparked cleaver, then a ~60 stud dash with a devastating swipe and a
		-- brief cutscene (35; tripled on a marked target but it can't kill), then the follow-up blows everyone near away
		-- (10, 40 AoE). Marked then low-HP targets first. Always ends the sequence.
		K.Rush{ "Ratio Breaker IV", cooldown = 0, startup = 0.5, travel = 60, time = 0.5, hits = 2, interval = 0.8, hitDamage = { 35, 10 },
			type = "explosion", block = "none", bypassRagdoll = true, meleeIFrames = 0.9, noKillHits = { true }, ratio = { hitMult = { 3, 4 } },
			ragdoll = { h = 90, v = 30 }, color = "black", tip = "4/4", onUse = StageStart, onFinish = Stage( 4 ) },
	}
	local built = {}
	for i, spec in ipairs( st ) do built[ i ] = K.Build( "salaryman", "rb" .. i, spec ) end
	return {
		name = "Ratio Breaker",
		cooldown = 19,
		Pick = function( ply ) return built[ math.Clamp( ply:GetNW2Int( "JJSRBStage", 1 ), 1, 4 ) ] end,
	}
end

-- Collapse's suspended debris (8s): pressing the move again (even stunned) or the timer makes it crash down
local DEBRIS = K.Params( K.AoE{ "Collapse: Debris", damage = 27, radius = 20, type = "explosion", block = "none", bypassRagdoll = true,
	trueRag = true, ragdoll = { h = 10, v = -30 }, color = "brown", crater = 1600 } )
local function DropDebris( ply )
	local d = ply.jjs_debris
	ply.jjs_debris = nil
	if CLIENT or not d then return end
	for _, v in ipairs( K.SphereTargets( d + Vector( 0, 0, 36 ), DEBRIS.radius, ply, true ) ) do
		JJS.Hit( v, K.MakeHit( ply, DEBRIS, v, 1, d ) )
	end
	K.Effect( "jjs_kit_burst", d + Vector( 0, 0, 20 ), Vector( 0, 0, 1 ), ply, DEBRIS.radius, DEBRIS )
	JJS.Destruction.GroundImpact( d + Vector( 0, 0, 20 ), DEBRIS.crater )
end

-- Stabilize's follow-ups out of its stun
local CW_SPEC = { kind = "melee", startup = 0.35, endlag = 0.35, hits = 1, damage = 12, lunge = 25, reach = 9, meleeIFrames = 0.35, stun = 0.75,
	block = "normal", bypassRagdoll = false, interrupt = false, ragdoll = { h = 55, v = 15 }, ratio = { mult = 16 / 12, unblockable = true,
	arm = 7, onInterrupt = true } }
local BC_SPEC = { kind = "melee", startup = 0.2, endlag = 0.4, hits = 1, damage = 9, lunge = 34, reach = 9, stun = 0.75, block = "normal",
	bypassRagdoll = true, interrupt = false, ragdoll = { h = 40, v = 15 }, ratio = { mult = 13 / 9, unblockable = true, leg = 7,
	onInterrupt = true, blockToo = true } }

K.Character( "salaryman", {
	name = "Salaryman",
	category = "complete",
	hp = 100,
	model = K.Model( "salaryman", "models/player/breen.mdl" ),
	color = Color( 240, 200, 120 ),

	-- per-hit M1 frames { startup, recovery, block endlag } (dogslamloop)
	m1 = {
		Frames = { { 14, 5, 11 }, { 14, 6, 13 }, { 14, 6, 13 } },
	},

	passives = {
		{ "Blunt Cleaver", "Cosmetic: a cloth-wrapped cleaver and a dotted tie." },
		{ "Ratio Black Flash", "The final neutral M1 or an uppercut on a Ratio-marked target: double damage and knockback." },
	},

	abilities = {
		-- Charges 25 studs spinning with melee i-frames, ending in a downward slash knocking the target away (12).
		-- Ratio: 16, unblockable; interrupting any action staggers their right arm for 7s (lower block angle).
		[ 1 ] = K.Melee( table.Merge( { "Cleaving Whirlwind", cooldown = 16 }, table.Copy( CW_SPEC ) ) ),
		-- Kicks forward and follows with cursed energy on contact, pushing the target away with evadable stun; blocking
		-- doesn't stop the push (12, semi blockable; 15 through throwables, TODO: arming throwables).
		-- Reverse Kick (walking backward): the left leg swings behind the user, unblockable, unevadable stun, a bit more
		-- windup; interrupting (not a block) stuns them in place. Landing the kick on a standing target lets Blunt Cut
		-- skip its windup within half a second.
		[ 2 ] = K.Melee{ "Severance Kick", cooldown = 14, startup = 0.35, damage = 12, reach = 9, type = "melee", stun = 1.1, knock = 50,
			knockBlock = true, blockDamage = 4, tip = "DIRECTION",
			onHit = function( ply ) ply.jjs_kicked = CurTime() end,
			back = { startup = 0.45, behind = true, block = "none", stun = 1.3, interrupt = { stun = 2, knock = false } } },
		-- A quick swing, then a 34 stud flash step and a strike in the blink of an eye (9). Holding: 15 more studs, 14
		-- damage, longer windup. Right after a landed Severance Kick: straight to the swing (can't be held).
		-- Ratio: 13 (18 held), unblockable; interrupting (blocking included) staggers their left leg for 7s (no dashes).
		-- Airborne: "Cross Cut", a dive with brief melee i-frames (5) then an unblockable slice disabling the ragdoll
		-- cancel (4); ragdolled targets can't evade before the slice. Ratio before the dive: 11 + 4 and a leg stagger;
		-- marked after the dive: 5 + 10, ragdolled upward (cancel allowed) and an arm stagger.
		[ 3 ] = K.Melee( table.Merge( { "Blunt Cut", cooldown = 16, startup = 0.45, tip = "HOLD",
			hold = { time = 0.8, damage = 14, lunge = 49, startup = 0.7 },
			air = { hits = 2, interval = 0.3, hitDamage = { 5, 4 }, hitBlock = { "normal", "none" }, trueRag = true, lunge = 12, height = 18,
				meleeIFrames = 0.25, ragdoll = { h = 10, v = -25 }, ratio = { hitMult = { 11 / 5, 10 / 4 }, leg = 7, onInterrupt = true,
					blockToo = true } },
			cond = { test = function( ply ) return CurTime() - ( ply.jjs_kicked or -9 ) < 0.5 end, startup = 0.1 } }, table.Copy( BC_SPEC ) ) ),
		-- Thrusts the tool into the stomach and twirls it (6): both are stunned briefly, the user can get out of it with
		-- Cleaving Whirlwind or Blunt Cut. Interrupting (10) or hitting a marked target makes them cough up blood: a longer
		-- stun, long enough for either follow-up.
		[ 4 ] = K.Melee{ "Stabilize", cooldown = 12, startup = 0.35, endlag = 0.9, damage = 6, reach = 9, type = "melee", bypassRagdoll = true,
			stun = 1.1, tip = "HIT", comboFrom = 0.4, comboWindow = 1.3,
			interrupt = { damage = 4, stun = 1.8, onInterrupt = Stabilized },
			ratio = { unblockable = true, stun = 1.8, onRatio = Stabilized },
			combo = {
				[ 1 ] = table.Merge( table.Copy( CW_SPEC ), { comboFrom = false, comboWindow = false, endlag = 0.35, tip = false } ),
				[ 3 ] = table.Merge( table.Copy( BC_SPEC ), { comboFrom = false, comboWindow = false, tip = false } ),
			} },
	},
	special = RATIO,

	-- Overtime: right after a Stabilize stagger (even during its stun), the awakening rushes into a black flash first
	AwakenPress = function( ply, mv )
		if ply:GetJAwakened() or ply:GetJAwaken() < 1 or CurTime() - ( ply.jjs_stabilized or -9 ) > 1.5 then return false end
		if not ply:Alive() or ply:GetJRagdolled() then return false end
		ply.jjs_stabilized = nil
		ply.jjs_otLanded = nil
		ply:SetJAwaken( 0 )
		OT_FLASH.Use( ply, mv, 0 )
		return true
	end,

	awakening = {
		name = "Overtime",
		duration = 60,
		heal = 25,
		-- "How unfortunate. I'm now working overtime." The tie wraps the right fist, the cleaver goes to the left hand:
		-- output at 110-120%. Working Overtime: M1s 4 + 4 + 5 + 5 and they break the environment; the ratioed final M1
		-- is also unblockable. Wall of Stone: a custom block. Ratio Point has no cooldown and marks several targets.
		m1 = { Damage = { 4, 4, 5, 5 } },
		abilities = {
			[ 1 ] = RatioBreaker(),
			-- Slides 45 studs dragging the cleaver into a heated trail, then slices upward launching enemies (15, 23 with
			-- Ratio; melee armor). Marked targets can't dash for 7s.
			-- Airborne: "Erosion", floats for a second then slams, grounding anyone in front (15, leg stagger on marked);
			-- it can cancel Ratio Breaker III's leap or Collapse (keeping them off cooldown); an M1 or block during it
			-- feints it (8s). A Ratio bar lets the user aim the slam at the environment's weak point for a bigger area.
			-- TODO: the cancels, the feint and the environment bar.
			[ 2 ] = K.Melee{ "Sharpen", cooldown = 20, startup = 0.3, damage = 15, lunge = 45, type = "explosion", block = "none", bypassRagdoll = true,
				armor = "melee", ratio = { mult = 23 / 15, leg = 7 }, ragdoll = { h = 30, v = 50 },
				air = { startup = 1, lunge = 5, ragdoll = { h = 5, v = -35 }, crater = 1000, ratio = { leg = 7 } } },
			-- Holsters the tool and catches a target by the neck (4): "Where are your allies?", then a gut punch as they
			-- answer "I don't know" (10, can't kill; marked: left leg staggered 7s). Awakening drain stops meanwhile.
			-- Then pursues them at full speed (no endlag): reaching them ("My assistants are dead." "That was you, wasn't
			-- it?"), a cursed-energy blow to the face sends them away (16; marked: arm staggered 7s; bullet armor).
			[ 3 ] = K.Grab{ "Interrogate", cooldown = 20, startup = 0.35, hits = 2, interval = 0.8, hitDamage = { 4, 10 }, type = "melee",
				block = "none", bypassRagdoll = true, armor = "melee", noKillHits = { [ 2 ] = true }, ratio = { leg = 7 }, knock = 30,
				stun = 1.2, onHit = function( ply, v )
					timer.Simple( 0.1, function()
						if IsValid( ply ) and ply:Alive() and IsValid( v ) and v:Alive() then JJS.Kit.PURSUIT.Use( ply, nil, 0 ) end
					end )
				end },
			-- Leaps and slams to mark the environment's weak point (5); debris rises with a second impact (7, 15 and no
			-- evasive on a marked target). Pressed again within 8s (even stunned) or when the timer ends, the debris crashes
			-- down on everything (+9 per debris, up to 40).
			[ 4 ] = K.AoE{ "Collapse", cooldown = 22, startup = 0.5, hits = 2, interval = 0.3, hitDamage = { 5, 7 }, radius = 15, type = "explosion",
				block = "none", bypassRagdoll = true, armor = "melee", crater = 1400, ragdoll = { h = 10, v = 35 }, color = "brown", tip = "USE AGAIN",
				ratio = { hitMult = { 1, 15 / 7 }, trueRag = true },
				onUse = function( ply ) ply:SetLocalVelocity( Vector( 0, 0, 250 ) ) end,
				onEnd = function( ply ) ply.jjs_debris = ply:GetPos() ply.jjs_debrisAt = CurTime() + 8 end },
		},
		special = RATIO,
	},
} )

-- Interrogate's pursuit and second lift
K.PURSUIT = K.Build( "salaryman", "pursuit", K.Rush{ "Interrogate: Pursuit", startup = 0, travel = 35, time = 0.6, endlag = 0, hits = 2,
	interval = 0.9, hitDamage = { 0, 16 }, type = "melee", block = "normal", bypassRagdoll = true, armor = "bullet", ratio = { arm = 7 },
	ragdoll = { h = 70, v = 20 } } )

-- Collapse again: the debris falls
local collapse = JJS.Characters.salaryman.awakening.abilities[ 4 ]
collapse.Again = function( ply )
	if not ply.jjs_debris or not ply:Alive() then return false end
	DropDebris( ply )
	return true
end

if SERVER then
	-- Ratio: marked targets take the enhanced version of Ratio moves (and the M1 Black Flash)
	hook.Add( "JJS_PreHit", "JJS_Ratio", function( victim, hit )
		local a = hit.attacker
		hit.jjs_ratio = nil
		if not IsValid( a ) or not a:IsPlayer() or a:GetJChar() ~= "salaryman" or not Marked( victim, a ) then return end
		local r = hit.kit and hit.kit.ratio
		if hit.isM1 and hit.m1Index and hit.m1Index >= JJS.M1.Cfg( a ).Count and ( hit.m1Variant == 0 or hit.m1Variant == 1 ) then
			r = { mult = 2 }
			if hit.ragdoll then hit.ragdoll.vel = hit.ragdoll.vel * 2 end
			if a:GetJAwakened() then hit.block = "none" end
		end
		if not r then return end
		hit.jjs_ratio = r
		if r.unblockable then hit.block = "none" end
		if r.stun and not hit.ragdoll then hit.stun = r.stun end
		if r.trueRag and hit.ragdoll then hit.ragdoll.trueRag = true end
	end )
	JJS.AddDamageMod( "JJS_Ratio", function( victim, attacker, dmg, hit )
		local r = hit.jjs_ratio
		if not r then return end
		if r.hitMult then
			local idx = 1
			for i, v in ipairs( hit.kit and hit.kit.hitDamage or {} ) do if v == hit.damage then idx = i end end
			return r.hitMult[ idx ] or 1
		end
		return r.mult
	end )
	hook.Add( "JJS_Hit", "JJS_Ratio", function( victim, hit, res )
		local r = hit.jjs_ratio
		if not r or res ~= "hit" then return end
		local a = hit.attacker
		victim:SetNW2Float( "JJSRatio", 0 )
		a.jjs_ratioLanded = true
		local intr = hit.interrupting or ( r.blockToo and hit.guarding )
		if hit.interrupting then JJS.SetCooldown( a, 5, 0 ) end -- the mark interrupted a move: Ratio Point comes back
		if not r.onInterrupt or intr then
			if r.arm then JJS.StaggerArm( victim, r.arm ) end
			if r.leg then JJS.StaggerLeg( victim, r.leg ) end
		end
		if r.onRatio then r.onRatio( a, victim ) end
	end )

	hook.Add( "Tick", "JJS_Ratio", function()
		local now = CurTime()
		for _, ply in ipairs( player.GetAll() ) do
			-- the QTE circle ran off the bar
			if QTEActive( ply ) and QTEPos( ply ) > 1.05 then EndQTE( ply, 5 ) end
			-- Collapse's debris falls on its own after 8s
			if ply.jjs_debris and now >= ( ply.jjs_debrisAt or 0 ) then DropDebris( ply ) end
		end
	end )
end

if CLIENT then
	-- the Ratio bar over the target's head, and the marks
	hook.Add( "HUDPaint", "JJS_Ratio", function()
		local me = LocalPlayer()
		if not IsValid( me ) then return end
		if QTEActive( me ) then
			local t = me:GetNW2Entity( "JJSQTETarget" )
			if IsValid( t ) then
				local sp = ( t:GetPos() + Vector( 0, 0, 90 ) ):ToScreen()
				if sp.visible then
					surface.SetDrawColor( 20, 20, 20, 200 )
					surface.DrawRect( sp.x - 60, sp.y, 120, 10 )
					surface.SetDrawColor( 230, 60, 60, 255 )
					surface.DrawRect( sp.x - 60 + 120 * 0.7 - 1, sp.y - 3, 3, 16 )
					surface.SetDrawColor( 255, 255, 255, 255 )
					surface.DrawRect( sp.x - 60 + 120 * math.Clamp( QTEPos( me ), 0, 1 ) - 3, sp.y - 1, 6, 12 )
				end
			end
		end
		for _, v in ipairs( player.GetAll() ) do
			if v ~= me and Marked( v, me ) then
				local sp = ( v:GetPos() + Vector( 0, 0, 50 ) ):ToScreen()
				if sp.visible then draw.SimpleText( "7:3", "JJS_Small", sp.x, sp.y, Color( 255, 205, 70 ), TEXT_ALIGN_CENTER ) end
			end
		end
	end )
end

hook.Add( "JJS_PlayerSpawned", "JJS_Ratio", function( ply )
	ply:SetNW2Float( "JJSRatio", 0 )
	ply:SetNW2Float( "JJSQTEStart", 0 )
	ply:SetNW2Int( "JJSRBStage", 1 )
	ply:SetNW2Float( "JJSArmStagger", 0 )
	ply:SetNW2Float( "JJSLegStagger", 0 )
	ply.jjs_debris = nil
end )
