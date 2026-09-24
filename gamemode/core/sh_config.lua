-- All gameplay numbers live here. Values from the JJS wiki are written in studs and
-- converted with JJS.STUD (a Roblox R6 character is ~5 studs tall, a GMod player 72 units).

JJS.STUD = 14
local S = JJS.STUD

JJS.DMG = {
	MELEE = 1,
	BULLET = 2,
	EXPLOSION = 3,
	SWARM = 4,
	DOMAIN = 5,
	SPECIAL = 6, -- neither adaptable nor counterable
}

JJS.Config = {
	DefaultCharacter = "truecannon",

	-- Roblox default workspace gravity; applied to players (sv_gravity) and physics (ragdolls)
	Gravity = 196.2 * S,

	MaxHealth = 100,
	WalkSpeed = 16 * S,
	RunSpeed = 26 * S,
	JumpPower = 50 * S,
	HealthSpeedMin = 0.8, -- speed multiplier near 0 HP ("slightly proportional to health")
	BlockSpeedMult = 0.4,
	EndlagSpeedMult = 0.2,
	RunTapWindow = 0.3, -- double tap W

	RegenDelay = 1,
	RegenPerSecond = 1,
	RespawnTime = 4,

	Camera = {
		Distance = 12.5 * S,
		MinDistance = 0.5 * S,
		MaxDistance = 28 * S,
		ZoomStep = 1.5 * S,
		ShiftLockOffset = 1.75 * S,
		FocusHeight = 62,
		FirstPersonDistance = 1.2 * S,
		FOV = 70,
	},

	M1 = {
		Count = 4,
		Damage = { 3, 3, 4, 4 },
		Startup = 0.2, -- 12f at 60 fps (dogslamloop frame data); wiki: 0.16 - 0.23s
		Duration = 0.35, -- 12f startup + 1f active + 8f recovery; blocked: 17f endlag instead of 8f
		FinalDuration = 0.62, -- the last hit has more recovery
		ChainWindow = 0.45, -- continue the string within this time after the previous hit ended
		Downtime = 2, -- after the full string
		Stun = 0.75,
		HitSize = Vector( 8, 8, 8 ) * S,
		HitCenter = 3.5 * S, -- forward offset of the box centre
		Pull = 12 * S, -- attacker pull speed toward the target (~1 stud)
		MoveMult = 0.35,
		Final = {
			[ 0 ] = { h = 50 * S, v = 24 * S, ragdoll = 0.8 }, -- neutral: knocked back, shortest ragdoll
			[ 1 ] = { h = 8 * S, v = 70 * S, ragdoll = 0.8 }, -- uppercut: launched, airtime extends it
			[ 2 ] = { h = 6 * S, v = -80 * S, ragdoll = 1.0 }, -- downslam: grounded, unblockable
		},
		CraterScale = 640, -- ChloeImpact starts spawning rock chunks above ~600
	},

	Dash = {
		FrontDistance = 25 * S,
		FrontTime = 0.5,
		FrontCooldown = 6,
		FrontDamage = 4,
		FrontStun = 0.75,
		FrontHitSize = Vector( 6, 7, 7 ) * S,
		FrontHitCenter = 2.5 * S,
		FrontRagdoll = { h = 40 * S, v = 18 * S, time = 0.8 },
		FrontHitLock = 0.28,
		FrontWhiffEndlag = 0.35,
		FrontBlockedEndlag = 0.55,
		SideDistance = 17.5 * S,
		SideTime = 0.3,
		SideCooldown = 2,
		AntiRunRange = 80 * S,
	},

	Ragdoll = {
		WakeMeleeImmunity = 0.75,
		InfluenceAccel = 10 * S, -- ~5 studs of drift over an uppercut
		EvasiveIFrames = 1,
		MaxTime = 12,
		ImpactSpeed = 34 * S, -- ragdolls hitting the world faster than this leave a crater
		ImpactScalePerStud = 13,
	},

	Evasive = {
		LowHealth = 50,
		TakenHigh = 77, -- damage taken to fill above 50 HP
		TakenLow = 62.5,
		DealtHigh = 200,
		DealtLow = 100,
		ComboBonus = 0.2,
	},

	Burst = {
		Window = 1.75,
		Heal = 10,
		IFrames = 0.5,
	},

	Awakening = {
		FullDamage = 2000 / 7, -- ~286 damage dealt
		DefaultDuration = 60,
		DefaultHeal = 25,
		SequenceTime = 1.6, -- invulnerable activation sequence
	},

	Domain = {
		CastTime = 1.25,
		Radius = 37.5 * S,
		DefaultDuration = 14,
		ClashWindow = 1, -- domains cast this close together clash
		ClashTime = 15,
		ClashPerHit = 0.0625, -- 16 hits fill the bar
		BorderMargin = 4 * S, -- can't cast this close to another domain's border
	},

	BeamClash = {
		Time = 4,
		Range = 120 * S,
		HeadStart = 2, -- presses per strength rank of difference
		Keys = { IN_FORWARD, IN_MOVELEFT, IN_MOVERIGHT }, -- W, A, D
	},

	Slide = {
		Time = 0.55,
		GapMin = 30, -- clearance under the obstacle needed to slide
		ProbeDistance = 40,
	},

	WallJump = {
		Reach = 30,
		RunTime = 0.26,
		RunSpeed = 22 * S,
		RunLift = 8 * S,
		KickOut = 22 * S,
		KickUp = 46 * S,
		KickAlong = 12 * S,
		Cooldown = 0.15,
		-- HP fraction -> number of wall jumps
		Tiers = { { 0.66, 3 }, { 0.33, 2 }, { 0, 1 } },
	},

	Roll = {
		Window = 0.25, -- jump pressed this long before touching the floor
		Time = 0.45,
		Base = 6 * S,
		PerStud = 0.3 * S, -- extra distance per stud fallen
		Max = 22 * S,
	},

	Parkour = {
		ProbeDistance = 30,
		VaultMaxHeight = 46,
		ClimbMaxHeight = 118,
		VaultTime = 0.36,
		ClimbTime = 0.5,
	},
}

if SERVER then
	CreateConVar( "jjs_respawn_time", tostring( JJS.Config.RespawnTime ), FCVAR_ARCHIVE + FCVAR_NOTIFY, "Seconds before a dead player respawns" )
end
CreateConVar( "jjs_player_collide", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED + FCVAR_NOTIFY, "Players collide with each other" )
