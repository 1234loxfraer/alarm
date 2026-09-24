-- Networked + predicted player state, stored in the entity's DT slots directly.
-- (Player classes install DT accessors lazily on clients, so remote players could miss them.)
-- Accessors: ply:GetJ<Name>() / ply:SetJ<Name>( v )

local PLY = FindMetaTable( "Player" )

JJS.DataDefaults = {}

local function Def( kind, slot, name, default )
	local get, set = "GetDT" .. kind, "SetDT" .. kind
	PLY[ "GetJ" .. name ] = function( self ) return self[ get ]( self, slot ) end
	PLY[ "SetJ" .. name ] = function( self, v ) self[ set ]( self, slot, v ) end
	JJS.DataDefaults[ #JJS.DataDefaults + 1 ] = { set = "SetJ" .. name, value = default }
end

-- Floats (times are CurTime() values; 0 = inactive)
Def( "Float", 0, "StunEnd", 0 )
Def( "Float", 1, "EndlagEnd", 0 )
Def( "Float", 2, "IFrameEnd", 0 )
Def( "Float", 3, "MeleeImmuneEnd", 0 )
Def( "Float", 4, "BlockStart", 0 )
Def( "Float", 5, "DashStart", 0 )
Def( "Float", 6, "DashFrontCD", 0 )
Def( "Float", 7, "DashSideCD", 0 )
Def( "Float", 8, "M1LastEnd", 0 )
Def( "Float", 9, "M1CD", 0 )
Def( "Float", 10, "ActStart", 0 )
Def( "Float", 11, "ActEnd", 0 )
Def( "Float", 12, "Evasive", 1 ) -- 0..1
Def( "Float", 13, "Awaken", 0 ) -- 0..1 (bar fill, or time left while awakened)
Def( "Float", 14, "AwakenEnd", 0 )
Def( "Float", 15, "LastHurt", 0 )
Def( "Float", 16, "CD1", 0 )
Def( "Float", 17, "CD2", 0 )
Def( "Float", 18, "CD3", 0 )
Def( "Float", 19, "CD4", 0 )
Def( "Float", 20, "CD5", 0 ) -- special
Def( "Float", 21, "Res1", 0 ) -- character resource (True Cannon: overheat 0..1)
Def( "Float", 22, "RagdollEnd", 0 ) -- 0 while waiting to land
Def( "Float", 23, "BurstEnd", 0 )
Def( "Float", 24, "MoveStart", 0 )
Def( "Float", 25, "Res2", 0 )
Def( "Float", 26, "HP", 100 ) -- exact health (Health() is an int)
Def( "Float", 27, "DeathTime", 0 )
Def( "Float", 28, "BuffEnd", 0 ) -- movement speed buff/debuff from moves
Def( "Float", 29, "BuffMult", 1 )

-- Ints
Def( "Int", 0, "ActId", 0 )
Def( "Int", 1, "ActVar", 0 )
Def( "Int", 2, "M1Index", 0 )
Def( "Int", 3, "DashType", 0 ) -- 0 none, 1 front, 2 side
Def( "Int", 4, "WallJumps", 3 )
Def( "Int", 5, "MoveState", 0 ) -- JJS.MOVE_*
Def( "Int", 6, "Dummy", 0 ) -- dummy kind, 0 = real player
Def( "Int", 7, "KitSet", 0 ) -- 0 = main moveset, 1 = alternate set (Rika, Ten Shadows' switch..)
Def( "Int", 8, "Mode", 0 ) -- character mode (Self-Transfiguration, Adaptation Wheel..)

-- Bools
Def( "Bool", 0, "Running", false )
Def( "Bool", 1, "Ragdolled", false )
Def( "Bool", 2, "Awakened", false )
Def( "Bool", 3, "ShiftLock", true )
Def( "Bool", 4, "TrueRagdoll", false )

-- Vectors
Def( "Vector", 0, "DashDir", Vector( 1, 0, 0 ) ) -- local: x forward, y right
Def( "Vector", 1, "MoveA", Vector( 0, 0, 0 ) )
Def( "Vector", 2, "MoveB", Vector( 0, 0, 0 ) )
Def( "Vector", 3, "DashOrigin", Vector( 0, 0, 0 ) )
Def( "Vector", 4, "MoveC", Vector( 0, 0, 0 ) )

-- Entities
Def( "Entity", 0, "RagEnt", NULL )
Def( "Entity", 1, "ActTarget", NULL )

-- Strings
Def( "String", 0, "Char", "" )

JJS.MOVE_NONE = 0
JJS.MOVE_WALLRUN = 1
JJS.MOVE_ROLL = 2
JJS.MOVE_VAULT = 3
JJS.MOVE_CLIMB = 4
JJS.MOVE_SLIDE = 5

-- Resets everything except the character and (optionally) the awakening bar
function JJS.ResetPlayerData( ply, keepAwaken )
	local char, awaken = ply:GetJChar(), ply:GetJAwaken()
	for _, d in ipairs( JJS.DataDefaults ) do
		local v = d.value
		if isvector( v ) then v = Vector( v ) end
		ply[ d.set ]( ply, v )
	end
	ply:SetJChar( char )
	if keepAwaken then ply:SetJAwaken( awaken ) end
end

-- The alternate moveset (Rika, Ten Shadows' switch..) keeps its own cooldowns (networked separately)
function JJS.GetCooldown( ply, slot )
	if ply:GetJKitSet() == 1 then return ply:GetNW2Float( "JJSAltCD" .. slot, 0 ) end
	return ply[ "GetJCD" .. slot ]( ply )
end

function JJS.SetCooldown( ply, slot, seconds )
	if ply:GetJKitSet() == 1 then
		ply:SetNW2Float( "JJSAltCD" .. slot, CurTime() + seconds )
	else
		ply[ "SetJCD" .. slot ]( ply, CurTime() + seconds )
	end
	-- a move going on cooldown (Bleed stacks react to it)
	if seconds > 1.5 then hook.Run( "JJS_Cooldown", ply, slot, seconds ) end
end

function JJS.ClearCooldowns( ply )
	for i = 1, 5 do
		ply[ "SetJCD" .. i ]( ply, 0 )
		ply:SetNW2Float( "JJSAltCD" .. i, 0 )
	end
end
