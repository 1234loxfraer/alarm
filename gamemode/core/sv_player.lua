-- Spawning, death/respawn, health regen and the server tick.

local cfg = JJS.Config

function GM:Initialize()
	RunConsoleCommand( "sv_gravity", tostring( cfg.Gravity ) )
end

-- the physics environment only exists once the map is loaded
function GM:InitPostEntity()
	physenv.SetGravity( Vector( 0, 0, -cfg.Gravity ) )
	local perf = physenv.GetPerformanceSettings()
	if perf then
		perf.MaxVelocity = math.max( perf.MaxVelocity or 0, 6000 )
		physenv.SetPerformanceSettings( perf )
	end
end

function GM:PlayerInitialSpawn( ply )
	ply:SetTeam( TEAM_UNASSIGNED )
	if ply:GetJChar() == "" then ply:SetJChar( cfg.DefaultCharacter ) end
end

function GM:PlayerSpawn( ply, transition )
	ply:UnSpectate()
	JJS.Ragdoll.Remove( ply )
	JJS.ResetPlayerData( ply, true )

	local char = JJS.GetChar( ply )
	ply:SetJChar( char.id )

	util.PrecacheModel( char.model )
	ply:SetModel( char.model )
	ply:SetupHands()
	JJS.ApplyScale( ply )

	ply:SetMaxHealth( char.hp )
	ply:SetHealth( char.hp )
	ply:SetJHP( char.hp )

	ply:SetWalkSpeed( cfg.WalkSpeed )
	ply:SetSlowWalkSpeed( cfg.WalkSpeed )
	ply:SetRunSpeed( cfg.RunSpeed )
	ply:SetJumpPower( cfg.JumpPower )
	ply:SetCrouchedWalkSpeed( 0.5 )
	ply:SetDuckSpeed( 0.1 )
	ply:SetUnDuckSpeed( 0.1 )
	ply:SetAvoidPlayers( false )
	ply:SetCustomCollisionCheck( true )
	ply:AllowFlashlight( false )
	ply:SetCanZoom( false )
	ply:StripWeapons()
	ply:SetMoveType( MOVETYPE_WALK )
	ply:SetNotSolid( false )
	ply:SetNoDraw( false )
	ply:DrawShadow( true )
	ply:SetJWallJumps( JJS.Move.WallJumpTier( ply ) )

	if char.OnSpawn then char.OnSpawn( ply ) end
	hook.Run( "JJS_PlayerSpawned", ply )
end

function GM:PlayerLoadout( ply ) return true end
function GM:PlayerSetModel( ply ) end
function GM:PlayerSwitchFlashlight( ply, on ) return not on end
function GM:PlayerCanPickupWeapon( ply, wep ) return false end
function GM:GetFallDamage( ply, speed ) return 0 end
function GM:PlayerDeathSound() return true end
function GM:CanPlayerSuicide( ply ) return ply:Alive() end

function GM:PlayerNoClip( ply, desired )
	return not desired or ply:IsAdmin()
end

-- Engine damage is blocked; JJS damage goes through JJS.ApplyDamage. Map hazards
-- (trigger_hurt, drowning, world) are converted so the float HP stays in sync.
function GM:EntityTakeDamage( target, dmg )
	if not target:IsPlayer() or target.jjs_allowDamage then return end
	local attacker = dmg:GetAttacker()
	local hazard = not IsValid( attacker ) or attacker:IsWorld() or attacker:GetClass() == "trigger_hurt"
		or dmg:IsDamageType( DMG_DROWN ) or dmg:IsDamageType( DMG_BURN )
	if hazard and dmg:GetDamage() > 0 and target:Alive() then
		JJS.ApplyDamage( target, nil, dmg:GetDamage(), { type = JJS.DMG.EXPLOSION } )
	end
	return true
end

function GM:DoPlayerDeath( ply, attacker, dmg )
	ply:AddDeaths( 1 )
	if IsValid( attacker ) and attacker:IsPlayer() and attacker ~= ply then
		attacker:AddFrags( 1 )
		attacker:SetJEvasive( 1 )
	end

	ply:SetJHP( 0 )
	ply:SetJDeathTime( CurTime() )
	JJS.StopAction( ply, true )

	local hit = ply.jjs_killHit
	ply.jjs_killHit = nil
	if ply:GetJRagdolled() then
		JJS.Ragdoll.MarkDead( ply )
	else
		local vel = hit and hit.ragdoll and hit.ragdoll.vel or ply:GetVelocity()
		JJS.Ragdoll.Apply( ply, { time = math.huge, trueRag = true, dead = true, vel = vel } )
		JJS.Ragdoll.MarkDead( ply )
	end

	ply.jjs_respawnAt = CurTime() + GetConVar( "jjs_respawn_time" ):GetFloat()
	hook.Run( "JJS_PlayerDied", ply, attacker, hit )
end

-- Respawning is timed in the tick below; the engine's death think isn't reliable for bots
function GM:PlayerDeathThink( ply )
	return false
end

function GM:PlayerDisconnected( ply )
	JJS.Ragdoll.Remove( ply )
end

hook.Add( "Tick", "JJS_PlayerTick", function()
	local now = CurTime()
	local dt = engine.TickInterval()

	for _, ply in ipairs( player.GetAll() ) do
		JJS.Ragdoll.Tick( ply, now, dt )
		if not ply:Alive() then
			if ply.jjs_respawnAt and now >= ply.jjs_respawnAt then
				ply.jjs_respawnAt = nil
				ply:Spawn()
			end
			continue
		end

		local char = JJS.GetChar( ply )
		local hp, max = ply:GetJHP(), ply:GetMaxHealth()
		if hp < max and now - ply:GetJLastHurt() >= cfg.RegenDelay and not ( char.NoRegen and char.NoRegen( ply ) ) then
			hp = math.min( max, hp + cfg.RegenPerSecond * dt )
			ply:SetJHP( hp )
			ply:SetHealth( math.ceil( hp ) )
		end

		JJS.AwakeningTick( ply, now )
		if char.Think then char.Think( ply, now ) end
	end
end )

-- Turns a living player into another character on the spot (Ten Shadows' Mahoraga ritual..).
-- The new character keeps the same health fraction; `revert` is restored on death.
function JJS.Transform( ply, id, revert )
	local char = JJS.Characters[ id ]
	if not char or not ply:Alive() then return end
	local frac = JJS.GetHealthFrac( ply )
	if ply:GetJRagdolled() then JJS.Ragdoll.Stop( ply, "transform" ) end
	JJS.StopAction( ply, true )
	if ply:GetJAwakened() then JJS.ExitAwakening( ply ) end
	ply:SetJChar( id )
	ply:SetJKitSet( 0 )
	ply:SetJMode( 0 )
	ply:SetModel( char.model )
	JJS.ApplyScale( ply )
	ply:SetMaxHealth( char.hp )
	local hp = math.max( 1, char.hp * frac )
	ply:SetJHP( hp )
	ply:SetHealth( math.ceil( hp ) )
	JJS.ClearCooldowns( ply )
	ply.jjs_revertChar = revert
	if char.OnSpawn then char.OnSpawn( ply ) end
	hook.Run( "JJS_Transformed", ply, id )
end

hook.Add( "JJS_PlayerDied", "JJS_TransformRevert", function( ply )
	if ply.jjs_revertChar then
		ply:SetJChar( ply.jjs_revertChar )
		ply.jjs_revertChar = nil
	end
end )

-- Character selection (F1 menu or console)
concommand.Add( "jjs_char", function( ply, _, args )
	if not IsValid( ply ) then return end
	local id = args[ 1 ]
	if not id or not JJS.Characters[ id ] then
		local list = {}
		for k, v in pairs( JJS.Characters ) do list[ #list + 1 ] = k .. " (" .. v.name .. ")" end
		ply:ChatPrint( "Characters: " .. table.concat( list, ", " ) )
		return
	end
	if ply:GetJChar() ~= id then
		ply.jjs_revertChar = nil
		ply:SetJChar( id )
		ply:SetJAwaken( 0 ) -- awakening progress is lost when switching characters
		if ply:Alive() then ply:Spawn() end
	end
end )

-- Developer helpers (admins / listen-server host)
local function Dev( ply )
	return not IsValid( ply ) or ply:IsAdmin() or ply:IsListenServerHost()
end

concommand.Add( "jjs_reset", function( ply )
	if not Dev( ply ) then return end
	JJS.ClearCooldowns( ply )
	ply:SetJDashFrontCD( 0 )
	ply:SetJDashSideCD( 0 )
	ply:SetJM1CD( 0 )
	ply:SetJEvasive( 1 )
	JJS.Heal( ply, 1000 )
end )

concommand.Add( "jjs_fill_awakening", function( ply )
	if not Dev( ply ) then return end
	ply:SetJAwaken( 1 )
end )
