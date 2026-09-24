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
		-- A long beam from the pompadour: 78.5 studs, stuns the first person met (ragdolls if already stunned). 20% Overheat.
		-- Hold ~1.1s: pierces everything over 100 studs, unblockable, ragdolls back; damage falls off 12 -> 5.5. 40% Overheat.
		-- TODO dash variant: during a front dash, a looping beam and a second front dash.
		[ 1 ] = K.Beam{ "Granite Blast", cooldown = 0.5, startup = 0.35, damage = 5.5, range = 78.5, radius = 2.5, type = "bullet",
			bypassRagdoll = true, stun = 0.9, color = "cyan", CanUse = NotOverheated, onUse = Heat( 0.2 ),
			hold = { time = 1.1, damage = 12, range = 100, pierce = true, block = "none", type = "explosion", trueRag = true,
				ragdoll = { h = 55, v = 15, time = 0.4 }, onUse = Heat( 0.4 ) } },
		-- Three quick blows (3 each), then a Tetsuzanko back clash (3) and a toss (6).
		[ 2 ] = K.Melee{ "Unsatisfied", cooldown = 20, startup = 0.3, damage = 18, hits = 5, interval = 0.22, type = "melee",
			ragdoll = { h = 60, v = 20 } },
		-- Aiming within 70 studs, dashes above a new opponent with melee i-frames and slams them, bouncing them skywards.
		-- TODO air target variant: a punch with delayed impact sending them to the floor (6 + 6), no ragdoll cancel.
		[ 3 ] = K.Target{ "Second Helping", cooldown = 15, range = 70, startup = 0.35, damage = 12, type = "melee", block = "none",
			bypassRagdoll = true, armor = "melee", ragdoll = { h = 5, v = 60 } },
		-- Two quick Granite Blasts (4 each, 80 studs) then a vertical ray ragdolling targets 60 studs ahead toward the user (8).
		-- 10% Overheat per blast; overheated, it skips to the final ray which ragdolls away instead.
		[ 4 ] = K.Beam{ "Appetizer", cooldown = 18, startup = 0.35, damage = 16, hits = 3, interval = 0.4, range = 80, radius = 2.5,
			type = "bullet", bypassRagdoll = true, color = "cyan", ragdoll = { h = -35, v = 25 }, onUse = Heat( 0.3 ) },
	},
	-- "Sweet!": poses to cool down (-60% Overheat); at 100% combs the hair instead (2.75s, -100%).
	special = K.Buff{ "Restyle", cooldown = 17, startup = 0.3, duration = 0.7, color = "cyan",
		onUse = function( ply ) ply:SetJRes1( ply:GetJRes1() >= 1 and 0 or math.max( 0, ply:GetJRes1() - 0.6 ) ) end },

	awakening = {
		name = "Every Last Drop.",
		duration = 90,
		-- Decadence: no passive regen, Overheat locked at 100%.
		-- TODO: at critical health the awakening bar absorbs damage (200); moves can be feinted into each other for 5 HP.
		abilities = {
			-- Slams the floor bouncing the target up (10), then an aimable air lunge; crashing into them trades punches (20) and launches (5).
			[ 1 ] = K.Melee{ "\"What are you after?\"", cooldown = 18, startup = 0.35, damage = 35, hits = 3, interval = 0.4, lunge = 25,
				type = "melee", block = "none", bypassRagdoll = true, selfDamage = 5, ragdoll = { h = 70, v = 25 } },
			-- Winds back a punch; struck meanwhile (melee, bullet, swarm, most explosions) the user clashes back (20; 9 self damage).
			[ 2 ] = K.Counter{ "\"I had no idea...\"", cooldown = 15, window = 0.8, armor = "bullet", riposte = 20, selfDamage = 9,
				counters = { melee = "counter", bullet = "counter", swarm = "counter", explosion = "counter" }, tip = "HIT" },
			-- Runs forward with a stunning kick (7) and a wild swing (3); landed, both exchange blows (20) until pushed apart (6).
			[ 3 ] = K.Grab{ "\"This is what dessert is like!\"", cooldown = 20, startup = 0.35, damage = 36, hits = 6, interval = 0.3, lunge = 25,
				type = "melee", blockDamage = 18, bypassRagdoll = true, armor = "total", selfDamage = 10, ragdoll = { h = 60, v = 20 } },
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
