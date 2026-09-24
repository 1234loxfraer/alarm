-- True Cannon (Ryu Ishigori).
-- Cursed Energy Discharge: a 3-hit M1 string whose final neutral hit fires a 24 stud ray for
-- 8 damage while Overheat < 90%. Overheat (Res1, 0..1) grows with the cannon moves: Granite Blast
-- and Every Last Drop. are disabled at 100%, Restyle cools down. The other moves are JJS.Kit
-- placeholders built from the wiki numbers; comments describe what the real move does.

local S = JJS.STUD
local U = JJS.Util
local K = JJS.Kit

-- The patched copy includes the JJS animation library; the workshop original is the fallback
local MODEL = "models/jjs/ryu.mdl"
if not util.IsValidModel( MODEL ) and not file.Exists( MODEL, "GAME" ) then
	MODEL = "models/reiko/jujutsu/characters/ryu.mdl"
end

local function Overheat( ply ) return ply:GetJRes1() end
local function AddOverheat( ply, amount )
	-- Decadence: awakened, the meter is locked at 100%
	if ply:GetJAwakened() then ply:SetJRes1( 1 ) return end
	ply:SetJRes1( math.Clamp( ply:GetJRes1() + amount, 0, 1 ) )
end
local function Heat( amount ) return function( ply ) AddOverheat( ply, amount ) end end
local function NotOverheated( ply ) return Overheat( ply ) < 1 end
local function Overheated( ply ) return Overheat( ply ) >= 1 end

-- Restyle's cooldown shortened by landed hits (Unsatisfied's jabs 0.5s each, Second Helping 3s)
local function ShaveSpecial( ply, seconds )
	local left = JJS.GetCooldown( ply, 5 ) - CurTime()
	if left > 0 then JJS.SetCooldown( ply, 5, math.max( 0, left - seconds ) ) end
end

-- "Want a Go?": Granite Blast during a front dash
local WANT_A_GO = K.Params( K.AoE{ "Want a Go?", damage = 4, radius = 8, type = "melee", block = "normal", stun = 0.8, color = "cyan" } )

local TC = {
	name = "True Cannon",
	category = "complete",
	hp = 100,
	model = MODEL,
	color = Color( 120, 220, 255 ),
	idle = "jjs_tc_idle",

	passives = {
		{ "Cursed Energy Discharge", "3 hit M1 string (3 + 3 + 4); the final neutral M1 fires a 24 stud ray (8) under 90% Overheat." },
		{ "Overheat", "Cannon moves heat up the meter; at 100% they're disabled and the head smokes." },
	},

	m1 = {
		-- per-hit M1 frames { startup, recovery, block endlag } (dogslamloop)
		Frames = { { 12, 8, 17 }, { 11, 9, 19 } },
		Count = 3,
		Damage = { 3, 3, 4 },
		RayDamage = 8,
		RayRange = 24 * S,
		RayRadius = 2.5 * S,
		RayOverheat = 0.1,
		-- full-body sequences from the animation library (missing ones fall back to gestures)
		-- alternate final: overheated (>= 90%) neutral finisher has no ray
		Alt = function( ply, idx, variant ) return idx >= 3 and variant == 0 and ply:GetJRes1() >= 0.9 end,
		Seq = function( ply, idx, variant, alt )
			if idx < 3 then return "jjs_tc_m1_" .. idx end
			if variant == 1 then return "jjs_tc_m1_up" end
			if variant == 2 then return "jjs_tc_m1_down" end
			return alt and "jjs_tc_m1_3b" or "jjs_tc_m1_3"
		end,
	},

	abilities = {
		-- A long beam from the pompadour (usable airborne for a better aim): 78.5 studs, stuns the first person met, or
		-- ragdolls them if they were already stunned (5.5). 20% Overheat.
		-- Held ~1.1s: pierces everything over 100 studs, unblockable and uncounterable, ragdolls back with instant wakeup;
		-- damage falls from 12 to 5.5 with range. 40% Overheat.
		-- During a front dash: "Want a Go?", the user stops, a beam loops around them (4, blockable) and they front dash
		-- again (20% Overheat; the front dash goes on 6s).
		[ 1 ] = K.Beam{ "Granite Blast", cooldown = 0.5, startup = 0.35, damage = 5.5, range = 78.5, radius = 2.5, type = "bullet",
			bypassRagdoll = true, stun = 0.9, stunRag = { h = 30, v = 12 }, color = "cyan", CanUse = NotOverheated, onUse = Heat( 0.2 ),
			hold = { time = 1.1, damage = 12, falloff = 5.5, range = 100, pierce = true, block = "none", type = "explosion", trueRag = true,
				stunRag = false, ragdoll = { h = 55, v = 15, time = 0.4 }, onUse = Heat( 0.4 ) } },
		-- Three quick blows (3 each; they can't hit grounded ragdolls but end an airborne ragdoll for the rest), a
		-- Tetsuzanko back clash (3) and a toss (6). Each of the 3 blows landed takes 0.5s off Restyle.
		[ 2 ] = K.Melee{ "Unsatisfied", cooldown = 20, startup = 0.3, hits = 5, interval = 0.22, hitDamage = { 3, 3, 3, 3, 6 }, type = "melee",
			hitBypass = { false, false, false, true, true }, ragdoll = { h = 60, v = 20 },
			onUse = function( ply ) ply.jjs_jabs = 0 end,
			onContact = function( ply, v, p, r )
				if r ~= "hit" or ( ply.jjs_jabs or 0 ) >= 3 then return end
				ply.jjs_jabs = ( ply.jjs_jabs or 0 ) + 1
				ShaveSpecial( ply, 0.5 )
			end },
		-- Aiming within 70 studs, treats themselves to a new opponent: dashes above them with melee i-frames and slams them,
		-- bouncing them skyward (12, unblockable). Landed: 3s off Restyle. An airborne target loses their ragdoll cancel
		-- and gets a punch with a delayed impact sending them to the floor (6 + 6).
		[ 3 ] = K.Target{ "Second Helping", cooldown = 15, range = 70, startup = 0.35, damage = 12, type = "melee", block = "none",
			bypassRagdoll = true, meleeIFrames = 0.4, ragdoll = { h = 5, v = 60 },
			onHit = function( ply ) ShaveSpecial( ply, 3 ) end,
			airTarget = { hits = 2, interval = 0.4, hitDamage = { 6, 6 }, trueRag = true, ragdoll = { h = 5, v = -60 } } },
		-- Two quick Granite Blasts from the forehead (4 each, 80 studs, stun), then the hair is caressed to release a vertical
		-- ray ragdolling anyone 60 studs ahead upward and toward the user (8). 10% Overheat per blast.
		-- Overheated: no blasts (the animation stays), only the final ray, which ragdolls away instead.
		[ 4 ] = K.Beam{ "Appetizer", cooldown = 18, startup = 0.35, hits = 3, interval = 0.4, hitDamage = { 4, 4, 8 }, range = 80, radius = 2.5,
			type = "bullet", bypassRagdoll = true, color = "cyan", ragdoll = { h = -35, v = 25 }, onUse = Heat( 0.3 ),
			cond = { test = Overheated, startup = 1.15, hits = 1, hitDamage = false, damage = 8, range = 60, ragdoll = { h = 35, v = 25 },
				onUse = false } },
	},
	-- "Sweet!": poses to cool down (1s, -60% Overheat). At 100% the user pulls out a comb and redoes their hair instead
	-- (2.75s, back to 0%).
	special = K.Buff{ "Restyle", cooldown = 17, startup = 0.3, duration = 0.7, color = "cyan",
		onUse = function( ply ) ply:SetJRes1( ply:GetJRes1() >= 1 and 0 or math.max( 0, ply:GetJRes1() - 0.6 ) ) end,
		cond = { test = Overheated, duration = 2.45 } },

	awakening = {
		name = "Every Last Drop.",
		duration = 90,
		-- Decadence: no passive regen, Overheat locked at 100% (the third M1 is a plain one). At critical health the
		-- awakening bar takes the damage instead (200 worth); a fatal hit it can't cover still leaves the user alive, out
		-- of the awakening. The first 3 moves can be cancelled (the same key) or feinted into each other for 5 HP (which
		-- can kill), putting the cancelled one on 6s: "What are you after?" until the lunge connects, "I had no idea..."
		-- any time, "This is what dessert is like!" until the swing.
		-- TODO: negligible endlag on blocked/whiffed final M1s.
		abilities = {
			-- Slams the floor bouncing the target up (10), leaps into an aimable air lunge; crashing into them, both trade a
			-- punch (20) before the user launches them (5; 5 self damage). Airborne: straight to the lunge.
			[ 1 ] = K.Melee{ "\"What are you after?\"", cooldown = 18, startup = 0.35, hits = 3, interval = 0.4, hitDamage = { 10, 20, 5 }, lunge = 25,
				type = "melee", block = "none", bypassRagdoll = true, selfDamage = 5, ragdoll = { h = 70, v = 25 },
				air = { hits = 2, hitDamage = { 20, 5 } } },
			-- Winds an arm back for a punch with bullet armor (other hits only lengthen the windup, except ragdolling swarm
			-- attacks); landed, both clash punches (3 + 7 x 2 + 3 push; 9 self damage).
			[ 2 ] = K.Grab{ "\"I had no idea...\"", cooldown = 15, startup = 0.7, hits = 9, interval = 0.15, hitDamage = { 3, 2, 2, 2, 2, 2, 2, 2, 3 },
				type = "melee", block = "none", armor = { "bullet", "melee", "explosion" }, selfDamage = 9, ragdoll = { h = 35, v = 10 } },
			-- Runs forward with a blockable stunning kick sliding the target back (7; interrupting an action guarantees the
			-- swing), then a wild swing (3); landed, a cutscene of exchanged blows (5 x 4; 2 self damage each) until both
			-- are pushed apart (6). Total armor, awakening drain stops meanwhile.
			[ 3 ] = K.Grab{ "\"This is what dessert is like!\"", cooldown = 20, startup = 0.35, hits = 7, interval = 0.3,
				hitDamage = { 7, 3, 5, 5, 5, 5, 6 }, lunge = 25, type = "melee", hitBlock = { "normal", "none" }, bypassRagdoll = true,
				armor = "total", selfDamage = 10, interrupt = { stun = 1.5 }, ragdoll = { h = 60, v = 20 } },
			-- Winds up a right jab and lunges into the target, sending them flying. Held 1.9s it doubles (40).
			-- TODO variant: against a wall, the debris flies 100 studs (20 per wall).
			[ 4 ] = K.Melee{ "\"You weren't invited.\"", cooldown = 20, startup = 0.55, damage = 20, lunge = 18, type = "explosion", block = "none",
				bypassRagdoll = true, trueRag = true, ragdoll = { h = 90, v = 20 }, crater = 1300,
				hold = { time = 1.9, damage = 40, ragdoll = { h = 130, v = 30 } } },
		},
		-- Wipes the face and cracks the knuckles: +10% health and +10% awakening time.
		special = K.Buff{ "Restyle", cooldown = 17, startup = 0.3, duration = 1.7, heal = 10, color = "cyan",
			onUse = function( ply ) JJS.AddAwakeningTime( ply, 0.1 ) end },
	},
}

function TC.GetOverheat( ply ) return Overheat( ply ) end
TC.AddOverheat = AddOverheat

function TC.NoRegen( ply ) return ply:GetJAwakened() end

-- Decadence feints: the first 3 awakened moves cancel or feint into each other for 5 HP
local FEINTABLE = { [ 1 ] = "landed", [ 2 ] = "always", [ 3 ] = "landed" }
local function Feintable( ply )
	if not ply:GetJAwakened() or ply:GetJChar() ~= "truecannon" then return end
	local act = JJS.GetAction( ply )
	local slot = act and act.kitParams and ply:GetJActVar()
	local rule = slot and FEINTABLE[ slot ]
	if not rule or ( rule == "landed" and ply.jjs_kitLanded ) then return end
	return slot
end
local function Feint( ply, from )
	JJS.StopAction( ply, true )
	JJS.SetCooldown( ply, from, 6 )
	if SERVER then JJS.ApplyDamage( ply, nil, 5, { type = JJS.DMG.SPECIAL } ) end
end

-- Every Last Drop.: the awakening is an ultimate beam (104, beam clash rank 4). The awakening state
-- follows only if the Overheat was at 80% or more (and below 100%) when it was fired.
local LAST_DROP = K.Build( "truecannon", "ultbeam", K.Beam{ "Every Last Drop.", startup = 2, damage = 104, duration = 1.2, tick = 0.2,
	range = 200, radius = 8, pierce = true, clash = 4, type = "explosion", block = "none", bypassRagdoll = true, uninterruptible = true,
	iframes = 2, color = "cyan", crater = 2000, ragdoll = { h = 80, v = 25 },
	onUse = function( ply ) ply.jjs_tcHeatAtCast = Overheat( ply ) end,
	onEnd = function( ply )
		local heat = ply.jjs_tcHeatAtCast or 0
		ply:SetJRes1( 1 )
		if heat >= 0.8 and heat < 1 then JJS.EnterAwakening( ply, nil, 25 ) end
	end } )

function TC.Awaken( ply, mv )
	if Overheat( ply ) >= 1 or not LAST_DROP.CanUse( ply, 0, mv ) then return end
	ply:SetJAwaken( 0 )
	LAST_DROP.Use( ply, mv, 0 )
end

-- Cursed Energy Discharge: the final neutral M1 becomes a ray while not overheated
function TC.OnM1Final( ply, variant, cfg, overheatedAtStart )
	if variant ~= JJS.M1.NEUTRAL or overheatedAtStart or TC.GetOverheat( ply ) >= 0.9 then return false end

	local fwd = ply:GetAimVector()
	fwd.z = math.Clamp( fwd.z, -0.35, 0.35 )
	fwd:Normalize()
	local start = U.BodyCenter( ply ) + Vector( 0, 0, 16 ) + U.Flat( fwd ) * 14

	U.LagComp( ply, true )
	local hits, endPos = U.PlayersOnRay( start, fwd, cfg.RayRange, cfg.RayRadius, { ignore = ply } )
	U.LagComp( ply, false )

	TC.AddOverheat( ply, cfg.RayOverheat )

	local first = hits[ 1 ]
	local stop = endPos
	if first then
		local v = first.ply
		stop = start + fwd * first.dist
		local hit = JJS.M1.BuildHit( ply, v, cfg, cfg.Count, JJS.M1.NEUTRAL )
		hit.damage = cfg.RayDamage
		hit.fxScale = 1.2
		local r = JJS.Hit( v, hit )
		if r == "blocked" then
			JJS.ExtendAction( ply, math.max( ply:GetJActEnd() - CurTime(), 0.1 ) )
		end
	end

	U.Effect( "jjs_tc_ray", start, fwd, ply, ( stop - start ):Length() )
	return true
end

K.Character( "truecannon", TC )

-- Granite Blast during a front dash: "Want a Go?"
TC.abilities[ 1 ].Again = function( ply, mv )
	if ply:GetJDashType() ~= JJS.Dash.FRONT or Overheated( ply ) or ply:GetJAwakened() then return false end
	if CurTime() - ( ply.jjs_wantAGo or -9 ) < 1 then return true end -- once per dash
	ply.jjs_wantAGo = CurTime()
	AddOverheat( ply, 0.2 )
	if SERVER then
		for _, v in ipairs( K.SphereTargets( U.BodyCenter( ply ), WANT_A_GO.radius, ply, false ) ) do
			JJS.Hit( v, K.MakeHit( ply, WANT_A_GO, v, 1, ply:GetPos() ) )
		end
		K.Effect( "jjs_kit_burst", U.BodyCenter( ply ), Vector( 0, 0, 1 ), ply, WANT_A_GO.radius, WANT_A_GO )
	end
	JJS.Dash.Begin( ply, mv, JJS.Dash.FRONT, Vector( 1, 0, 0 ), true )
	ply:SetJDashFrontCD( CurTime() + 6 )
	return true
end

-- Decadence: pressing the running move again cancels it; another of the first 3 feints into it
for slot = 1, 3 do
	local ab = TC.awakening.abilities[ slot ]
	local canUse, use = ab.CanUse, ab.Use
	ab.Again = function( ply )
		local from = Feintable( ply )
		if from ~= slot then return false end
		Feint( ply, from )
		return true
	end
	ab.CanUse = function( ply, s, mv )
		if Feintable( ply ) and ply:Alive() and not ply:GetJRagdolled() and not JJS.IsStunned( ply ) then return true end
		return canUse( ply, s, mv )
	end
	ab.Use = function( ply, mv, s )
		local from = Feintable( ply )
		if from then Feint( ply, from ) end
		if ply:Alive() then use( ply, mv, s ) end
	end
end

if SERVER then
	-- Decadence: at critical health the awakening bar (200 damage worth) takes the hits
	hook.Add( "JJS_ScaleDamage", "JJS_Decadence", function( victim, attacker, dmg, hit )
		if not victim:GetJAwakened() or victim:GetJChar() ~= "truecannon" then return end
		if victim:GetJHP() > 25 then return end -- critical health
		local left = victim:GetJAwakenEnd() - CurTime()
		local cost = dmg / 200 * ( victim.jjs_awakenDur or 90 )
		if cost < left then
			victim:SetJAwakenEnd( victim:GetJAwakenEnd() - cost )
		else
			JJS.ExitAwakening( victim )
		end
		return 0
	end )
end

if SERVER then return end

------------------------------------------------------------------------------------------
-- Client: overheat meter, head smoke, ray effect
------------------------------------------------------------------------------------------

function TC.HUDPaint( ply, now, S )
	if not ply:Alive() then return end
	local heat = TC.GetOverheat( ply )

	local chest = ply:GetPos() + Vector( 0, 0, 44 )
	if ply:GetJRagdolled() and IsValid( ply:GetJRagEnt() ) then chest = ply:GetJRagEnt():WorldSpaceCenter() end
	local sp = chest:ToScreen()
	if not sp.visible then return end

	local w, h = S( 8 ), S( 90 )
	local x, y = sp.x + S( 70 ), sp.y - h / 2
	surface.SetDrawColor( 20, 20, 22, 200 )
	surface.DrawRect( x, y, w, h )

	local col
	if heat >= 1 then
		local p = 0.5 + 0.5 * math.sin( now * 12 )
		col = Color( 255, 60 + 60 * p, 40 )
	elseif heat >= 0.9 then
		col = Color( 255, 110, 40 )
	else
		col = Color( 255, 200 - 90 * heat, 70 )
	end
	surface.SetDrawColor( col )
	surface.DrawRect( x, y + h * ( 1 - heat ), w, h * heat )

	-- 90% mark (M1 ray disabled above it)
	surface.SetDrawColor( 255, 255, 255, 120 )
	surface.DrawRect( x - S( 2 ), y + h * 0.1, w + S( 4 ), 1 )
	surface.SetDrawColor( 255, 255, 255, 30 )
	surface.DrawOutlinedRect( x, y, w, h, 1 )
end

local MAT_GLOW = Material( "sprites/light_glow02_add" )
local MAT_BEAM = Material( "trails/laser" )
local CORE = Color( 255, 255, 255 )
local EDGE = Color( 110, 215, 255 )

local RAY = {}
function RAY:Init( data )
	self.Start = data:GetOrigin()
	self.Dir = data:GetNormal()
	self.Len = math.max( data:GetScale(), 16 )
	self.End = self.Start + self.Dir * self.Len
	self.Born = CurTime()
	self.Life = 0.22
	local mins, maxs = Vector( self.Start ), Vector( self.End )
	OrderVectors( mins, maxs )
	self:SetRenderBoundsWS( mins, maxs, Vector( 40, 40, 40 ) )

	local em = ParticleEmitter( self.End )
	for _ = 1, 10 do
		local p = em:Add( "effects/spark", self.End )
		if p then
			p:SetVelocity( ( VectorRand() - self.Dir * 0.5 ):GetNormalized() * math.Rand( 200, 500 ) )
			p:SetDieTime( math.Rand( 0.12, 0.25 ) )
			p:SetStartAlpha( 255 )
			p:SetEndAlpha( 0 )
			p:SetStartSize( 2 )
			p:SetEndSize( 0 )
			p:SetStartLength( 18 )
			p:SetEndLength( 4 )
			p:SetColor( EDGE.r, EDGE.g, EDGE.b )
		end
	end
	em:Finish()
	util.ScreenShake( self.Start, 2, 30, 0.15, 300 )
end

function RAY:Think()
	return CurTime() - self.Born < self.Life
end

function RAY:Render()
	local u = ( CurTime() - self.Born ) / self.Life
	local fade = 1 - U.Ease.InQuad( u )
	local grow = U.Ease.OutCubic( math.min( u * 4, 1 ) )
	local tip = LerpVector( grow, self.Start, self.End )

	render.SetMaterial( MAT_BEAM )
	render.DrawBeam( self.Start, tip, 26 * fade, 0, 1, ColorAlpha( EDGE, 255 * fade ) )
	render.DrawBeam( self.Start, tip, 9 * fade, 0, 1, ColorAlpha( CORE, 255 * fade ) )
	render.SetMaterial( MAT_GLOW )
	render.DrawSprite( self.Start, 40 * fade, 40 * fade, ColorAlpha( EDGE, 255 * fade ) )
	render.DrawSprite( tip, 60 * fade, 60 * fade, ColorAlpha( CORE, 200 * fade ) )
end
effects.Register( RAY, "jjs_tc_ray" )

-- Overheated: the top of the head smokes
local nextSmoke = 0
local emitter
hook.Add( "Think", "JJS_TC_OverheatSmoke", function()
	local now = CurTime()
	if now < nextSmoke then return end
	nextSmoke = now + 0.07

	for _, ply in ipairs( player.GetAll() ) do
		if not ply:Alive() or ply:GetJChar() ~= "truecannon" or ply:GetJRes1() < 1 or ply:GetJRagdolled() then continue end
		local bone = ply:LookupBone( "ValveBiped.Bip01_Head1" )
		local pos = bone and ply:GetBonePosition( bone )
		if not pos then continue end
		pos = pos + Vector( 0, 0, 9 )

		if not IsValid( emitter ) then emitter = ParticleEmitter( pos ) end
		local p = emitter:Add( "particle/particle_smokegrenade", pos + VectorRand() * 2 )
		if p then
			p:SetVelocity( Vector( math.Rand( -8, 8 ), math.Rand( -8, 8 ), math.Rand( 30, 50 ) ) )
			p:SetDieTime( math.Rand( 0.9, 1.4 ) )
			p:SetStartAlpha( 120 )
			p:SetEndAlpha( 0 )
			p:SetStartSize( 3 )
			p:SetEndSize( 16 )
			p:SetRoll( math.Rand( 0, 360 ) )
			p:SetRollDelta( math.Rand( -1, 1 ) )
			p:SetColor( 220, 220, 225 )
			p:SetAirResistance( 20 )
			p:SetGravity( Vector( 0, 0, 25 ) )
		end
	end
end )
