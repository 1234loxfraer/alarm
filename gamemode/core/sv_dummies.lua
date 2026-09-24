-- Training dummies (see the JJS wiki "Dummy" page). They are bots, so they go through
-- exactly the same code as real players. Needs a multiplayer session (max players >= 2).
--
--   jjs_dummy [normal|lowhp|immortal|attack|block|evasive]   spawns one where you look
--   jjs_dummy_clear                                          removes all dummies

JJS.DUMMY = {
	normal = 1,
	lowhp = 2,
	immortal = 3,
	attack = 4,
	block = 5,
	evasive = 6,
}
local NAMES = {
	[ 1 ] = "Dummy",
	[ 2 ] = "Low HP Dummy",
	[ 3 ] = "Immortal Dummy",
	[ 4 ] = "Attacking Dummy",
	[ 5 ] = "Blocking Dummy",
	[ 6 ] = "Evasive Dummy",
}

local IMMORTAL_HP = 99999

local function Allowed( ply )
	return not IsValid( ply ) or ply:IsAdmin() or ply:IsListenServerHost()
end

local function PlaceDummy( bot )
	local d = bot.jjs_dummy
	if not d then return end
	bot:SetPos( d.pos )
	bot:SetEyeAngles( d.ang )
	bot:SetJDummy( d.kind )
	if d.kind == JJS.DUMMY.lowhp then
		bot:SetJHP( 1 )
		bot:SetHealth( 1 )
	elseif d.kind == JJS.DUMMY.immortal then
		bot:SetMaxHealth( IMMORTAL_HP )
		bot:SetJHP( IMMORTAL_HP )
		bot:SetHealth( IMMORTAL_HP )
	end
	bot:SetJEvasive( 1 )
end

hook.Add( "JJS_PlayerSpawned", "JJS_Dummies", function( ply )
	if ply.jjs_dummy then timer.Simple( 0, function() if IsValid( ply ) then PlaceDummy( ply ) end end ) end
end )

function JJS.SpawnDummy( kind, pos, ang )
	if player.GetCount() >= game.MaxPlayers() then return nil, "Server is full; start a multiplayer game with more slots." end
	local bot = player.CreateNextBot( NAMES[ kind ] or "Dummy" )
	if not IsValid( bot ) then return nil, "Could not create a bot." end
	bot.jjs_dummy = { kind = kind, pos = pos, ang = ang }
	bot:SetJChar( JJS.Config.DefaultCharacter )
	bot:Spawn()
	return bot
end

function JJS.SetDummyKind( bot, kind )
	if not bot.jjs_dummy then return end
	bot.jjs_dummy.kind = kind
	bot:SetJDummy( kind )
end

concommand.Add( "jjs_dummy", function( ply, _, args )
	if not Allowed( ply ) then return end
	local kind = JJS.DUMMY[ args[ 1 ] or "normal" ] or JJS.DUMMY.normal

	local pos, ang = Vector( 0, 0, 0 ), Angle( 0, 0, 0 )
	if IsValid( ply ) then
		local tr = util.TraceLine( {
			start = ply:EyePos(),
			endpos = ply:EyePos() + ply:GetAimVector() * 600,
			filter = ply,
			mask = MASK_PLAYERSOLID,
		} )
		pos = tr.HitPos + tr.HitNormal * 8
		ang = Angle( 0, ( ply:GetPos() - pos ):Angle().y, 0 )
	end

	local bot, err = JJS.SpawnDummy( kind, pos, ang )
	if not bot and IsValid( ply ) then ply:ChatPrint( "[JJS] " .. err ) end
end )

concommand.Add( "jjs_dummy_clear", function( ply )
	if not Allowed( ply ) then return end
	for _, bot in ipairs( player.GetBots() ) do
		if bot.jjs_dummy then bot:Kick( "Dummy removed" ) end
	end
end )

-- Immortal dummies never drop below 1 HP
hook.Add( "JJS_PreventDeath", "JJS_ImmortalDummy", function( victim )
	if victim:GetJDummy() == JJS.DUMMY.immortal then
		victim:SetJHP( IMMORTAL_HP )
		victim:SetHealth( IMMORTAL_HP )
		return true
	end
end )

local function Nearest( bot, range )
	local best, bestD = nil, range * range
	for _, p in ipairs( player.GetAll() ) do
		if p ~= bot and p:Alive() and not p.jjs_dummy then
			local d = p:GetPos():DistToSqr( bot:GetPos() )
			if d < bestD then best, bestD = p, d end
		end
	end
	return best
end

hook.Add( "StartCommand", "JJS_DummyBrain", function( bot, cmd )
	local d = bot.jjs_dummy
	if not d then return end

	cmd:ClearMovement()
	cmd:ClearButtons()
	cmd:SetViewAngles( bot:EyeAngles() )
	if not bot:Alive() then return end

	-- respawned dummies walk back home when idle for a minute; here we just snap back
	if bot:GetPos():DistToSqr( d.pos ) > 1000 * 1000 and CurTime() - bot:GetJLastHurt() > 60 then
		bot:SetPos( d.pos )
	end

	local kind = d.kind
	if kind == JJS.DUMMY.block then
		cmd:AddKey( JJS.IN.BLOCK )
	elseif kind == JJS.DUMMY.attack then
		local t = Nearest( bot, 8 * JJS.STUD )
		if t then
			-- bots don't take their facing from the command's view angles reliably; set both
			local ang = ( JJS.Util.BodyCenter( t ) - bot:EyePos() ):Angle()
			bot:SetEyeAngles( ang )
			cmd:SetViewAngles( ang )
			cmd:AddKey( JJS.IN.M1 )
		end
	elseif kind == JJS.DUMMY.evasive then
		if ( bot:GetJRagdolled() and bot:GetJEvasive() >= 1 ) or bot:GetJBurstEnd() > CurTime() then
			-- alternate the press so KeyPressed fires
			if engine.TickCount() % 2 == 0 then cmd:AddKey( JJS.IN.DASH ) end
			cmd:SetSideMove( math.random( 0, 1 ) == 0 and 400 or -400 )
		end
	end
end )
