-- Sky Assassin (early access). Moves are JJS.Kit placeholders built from the JJS fandom wiki and the
-- dogslamloop frame data wiki; comments describe what the real move does. Slot 3 and the special are still TBA in
-- the game.
--
-- Temper (Res1, 0..1): landing damage fills it 4x faster than the awakening bar; after 15s without dealing damage it
-- drains 5% per 0.5s. Full, G makes the user "bad-tempered" for 15s (two distortions behind them: "Are you that
-- afraid?"): every move comes off cooldown and tracks airborne ragdolls, M1s start and extend air combos, the front
-- dash flies ~25 studs where aimed when a ragdolled target is in sight ("Sky Chasing"), Blind Rage and Sky Distortion
-- are enhanced; no awakening or temper builds up meanwhile.

local K = JJS.Kit
local S = JJS.STUD

local function Tempered( ply ) return ply:GetNW2Float( "JJSTemper", 0 ) > CurTime() end

-- an airborne ragdolled enemy under the cursor (bad-tempered moves track them)
local function AirRagdoll( ply, range )
	local t = K.AimTarget( ply, ( range or 40 ) * S, 0.85 )
	if IsValid( t ) and t:GetJRagdolled() then
		local rag = t:GetJRagEnt()
		local pos = IsValid( rag ) and rag:GetPos() or t:GetPos()
		if not util.TraceLine( { start = pos, endpos = pos - Vector( 0, 0, 4 * S ), mask = MASK_SOLID_BRUSHONLY } ).Hit then return t end
	end
end
local function TrackAir( ply ) return Tempered( ply ) and IsValid( AirRagdoll( ply ) ) end

-- Blind Rage's crashes: +3 each (+5 bad-tempered), up to 3
local function Crash( ply, v )
	JJS.ApplyDamage( v, ply, Tempered( ply ) and 5 or 3, { type = JJS.DMG.MELEE } )
	JJS.Destruction.GroundImpact( v:GetPos() + Vector( 0, 0, 30 ), 900 )
end

local SKY_CHASE = K.Build( "skyassassin", "chase", K.Mobility{ "Sky Chasing", startup = 0.05, travel = 25, time = 0.3, dir = "aim" } )

-- the bad-tempered distortion thrown forward (5, +5 with debris; tracks airborne ragdolls)
local DISTORTION = K.Params( K.Projectile{ "Sky Distortion: Thrown", damage = 5, range = 150, speed = 220, radius = 5, type = "bullet",
	block = "none", bypassRagdoll = true, ragdoll = { h = 40, v = 20 }, color = "cyan" } )

K.Character( "skyassassin", {
	name = "Sky Assassin",
	category = "early",
	hp = 100,
	model = K.Model( "skyassassin", "models/player/group03/male_09.mdl" ),
	color = Color( 170, 220, 255 ),

	-- Sky Manipulation: uppercuts knock further. TODO: hovering to an airborne ragdoll for the heavy 2nd M1 (blocked, the
	-- target locks the arm with their legs and crashes the user down, 15).
	m1 = { Final = {
		[ 0 ] = { h = 50 * S, v = 24 * S, ragdoll = 0.8 },
		[ 1 ] = { h = 10 * S, v = 95 * S, ragdoll = 0.9 },
		[ 2 ] = { h = 6 * S, v = -80 * S, ragdoll = 1.0 },
	} },

	passives = {
		{ "Sky Manipulation", "Hovers instead of walking; stronger uppercuts and midair M1 combos." },
		{ "Temper", "Hits fill a Temper bar (4x the awakening rate); full, G: bad-tempered for 15s." },
	},

	abilities = {
		-- Surges forward into a quick grab (5, unblockable), chokes the target and flies 125 studs with them (steered by
		-- the aim) before tossing them away (5); crashing into walls or floors hurts them more (+3 each, up to +9). If they
		-- evade after the hit they retaliate with a punch (TODO).
		-- Bad-tempered: two blockable amplified swings first (3 + 3; skipped straight to the grab on a nearby airborne
		-- ragdoll), a second more of flight after a crash, +5 per crash (up to +15).
		[ 1 ] = K.Grab{ "Blind Rage", cooldown = 15, startup = 0.3, hits = 2, interval = 1.5, hitDamage = { 5, 5 }, lunge = 20, type = "melee",
			block = "none", bypassRagdoll = true, carry = 80, onCrash = Crash, crashes = 3, ragdoll = { h = 60, v = 30 },
			cond = {
				{ test = TrackAir, kind = "target", range = 40, startup = 0.2, carry = 80, hits = 2, interval = 2.5 },
				{ test = Tempered, startup = 0.25, hits = 4, interval = 0.35, hitDamage = { 3, 3, 5, 5 }, hitBlock = { "normal", "normal", "none", "none" },
					carry = false, lunge = 12 },
			} },
		-- Spins holding onto the atmosphere, launching anyone walked into (12, blockable, can't hit ragdolls); blocked, the
		-- user ends face to face with them. Airborne: a sudden 20 stud dash during the spin. Deflectable projectiles are
		-- redirected where the user faces (TODO).
		-- Bad-tempered: 17, unblockable, hits ragdolls, more knockback, then the distortion is hurled 150 studs (5, +5
		-- with debris behind the user, tracking airborne ragdolls).
		[ 2 ] = K.Melee{ "Sky Distortion", cooldown = 12, startup = 0.35, damage = 12, reach = 8, width = 9, type = "melee",
			ragdoll = { h = 10, v = 55 }, air = { lunge = 20 },
			cond = { test = Tempered, damage = 17, block = "none", bypassRagdoll = true, ragdoll = { h = 30, v = 70 },
				onEnd = function( ply ) K.SpawnProjectile( ply, DISTORTION, K.Muzzle( ply ), K.AimDir( ply, 0.8 ) ) end } },
		[ 3 ] = K.Stub{ "TBA" },
		-- Both hands strike the sky's surface layer, shattering it like thin ice into a focused shockwave (5 on contact, 5
		-- for the shatter; unblockable). Tracks airborne ragdolled targets for air combos.
		[ 4 ] = K.Melee{ "Thin Ice Breaker", cooldown = 15, startup = 0.4, hits = 2, interval = 0.25, hitDamage = { 5, 5 }, reach = 5, type = "melee",
			block = "none", bypassRagdoll = true, ragdoll = { h = 60, v = 25 }, color = "cyan",
			cond = { test = TrackAir, kind = "target", range = 40 } },
	},
	special = K.Stub{ "TBA" },

	-- Temper (awakening attack, only while bad-tempered, ending it): flies up, charges a giant distortion covering a huge
	-- area, and strikes it into a shockwave eradicating everything within 50 studs (80, no evasive; heals 25).
	awakenMove = K.AoE{ "Temper", startup = 2, damage = 80, radius = 50, type = "swarm", block = "none", bypassRagdoll = true, trueRag = true,
		uninterruptible = true, iframes = 2, heal = 25, crater = 2500, ragdoll = { h = 60, v = 40 }, color = "cyan",
		onUse = function( ply ) ply:SetNW2Float( "JJSTemper", 0 ) ply:SetLocalVelocity( Vector( 0, 0, 300 ) ) end },

	AwakenPress = function( ply, mv )
		if Tempered( ply ) then
			-- the awakening attack needs a full bar too
			if ply:GetJAwaken() < 1 or not JJS.CanAct( ply ) or JJS.IsBusy( ply ) then return true end
			ply:SetJAwaken( 0 )
			JJS.GetChar( ply ).awakenMove.Use( ply, mv, 0 )
			return true
		end
		if ply:GetJRes1() >= 1 then
			ply:SetJRes1( 0 )
			ply:SetNW2Float( "JJSTemper", CurTime() + 15 )
			ply.jjs_awkLock = ply:GetJAwaken()
			JJS.ClearCooldowns( ply )
			if SERVER then JJS.Util.Effect( "jjs_kit_cast", JJS.Util.BodyCenter( ply ), nil, ply, 1.5, K.COLOR_ID.cyan ) end
			return true
		end
		-- the awakening can't be used outside of the bad-tempered state
		return true
	end,

	-- Sky Chasing: bad-tempered, the front dash flies ~25 studs where aimed with a ragdolled target in sight
	FrontDash = function( ply, mv )
		if not Tempered( ply ) then return false end
		local t = K.AimTarget( ply, 60 * S, 0.8 )
		if not IsValid( t ) or not t:GetJRagdolled() then return false end
		ply:SetJDashFrontCD( CurTime() + JJS.Config.Dash.FrontCooldown )
		SKY_CHASE.Use( ply, mv, 0 )
		return true
	end,

	HUDPaint = function( ply, now, S2 )
		local x, y, w = ScrW() / 2 - S2( 110 ), ScrH() - S2( 150 ), S2( 220 )
		surface.SetDrawColor( 20, 20, 24, 200 )
		surface.DrawRect( x, y, w, S2( 6 ) )
		surface.SetDrawColor( 140, 210, 255, 230 )
		local frac = Tempered( ply ) and ( ply:GetNW2Float( "JJSTemper", 0 ) - now ) / 15 or ply:GetJRes1()
		surface.DrawRect( x, y, w * math.Clamp( frac, 0, 1 ), S2( 6 ) )
	end,
} )

if SERVER then
	-- landing damage fills the temper bar (4x the awakening rate)
	hook.Add( "JJS_Hit", "JJS_Temper", function( victim, hit, res )
		local a = hit.attacker
		if res ~= "hit" or not IsValid( a ) or not a:IsPlayer() or a == victim or a:GetJChar() ~= "skyassassin" or Tempered( a ) then return end
		a:SetJRes1( math.min( 1, a:GetJRes1() + ( hit.damage or 0 ) * 4 / JJS.Config.Awakening.FullDamage ) )
		a.jjs_lastDealt = CurTime()
	end )
	hook.Add( "Tick", "JJS_Temper", function()
		for _, ply in ipairs( player.GetAll() ) do
			if ply:GetJChar() == "skyassassin" then
				-- drain after 15s without damage
				if ply:GetJRes1() > 0 and CurTime() - ( ply.jjs_lastDealt or 0 ) > 15 then
					ply:SetJRes1( math.max( 0, ply:GetJRes1() - FrameTime() * 0.1 ) )
				end
				-- no awakening progress while bad-tempered
				if Tempered( ply ) and ply.jjs_awkLock and ply:GetJAwaken() > ply.jjs_awkLock then ply:SetJAwaken( ply.jjs_awkLock ) end
			end
		end
	end )
end

hook.Add( "JJS_PlayerSpawned", "JJS_SkyAssassin", function( ply )
	ply:SetNW2Float( "JJSTemper", 0 )
	if ply:GetJChar() == "skyassassin" then ply:SetJRes1( 0 ) end
end )
