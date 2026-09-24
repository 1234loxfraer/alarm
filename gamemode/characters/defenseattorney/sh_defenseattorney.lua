-- Defense Attorney (Hiromi Higuruma). Moves are JJS.Kit placeholders built from the JJS fandom wiki and the
-- dogslamloop frame data wiki; comments describe what the real move does.
--
-- The gavel: No Escape throws it and the user is UNARMED until it comes back (0.75s, three times longer once it
-- touched someone). Every move used while unarmed recalls it and turns into its special variant (R > move on
-- dogslamloop), except Pressing Charges which kicks without recalling. An M1 or pressing the special again also
-- recalls it; a recall before it touched anyone keeps No Escape off cooldown and refunds its awakening cost.
-- Block breaks by Extended Swings, Justice Served and Pressing Charges set the M1 string to the 2nd M1 (Judge Gavel).
-- Awakening expands Deadly Sentencing, then grants the Executioner's Sword (Death Penalty).
-- Execution stacks: a second stack on the same target executes them.

local K = JJS.Kit

local GAVEL_BACK = 0.75 -- seconds for the gavel to come back after being thrown
local GAVEL_BACK_HIT = 2.25 -- after touching someone (hit or blocked)

local function Unarmed( ply ) return ply:GetNW2Float( "JJSGavelBack", 0 ) > CurTime() end

-- Brings the gavel back to the user's hand
local function Recall( ply )
	if CLIENT or not Unarmed( ply ) then return end
	ply:SetNW2Float( "JJSGavelBack", 0 )
	for _, e in ipairs( ents.FindByClass( "jjs_projectile" ) ) do
		if e.jjs and e.jjs.owner == ply and e.jjs.p.gavel then e:Remove() end
	end
	if not ply.jjs_gavelHit then
		JJS.SetCooldown( ply, 5, 0 )
		if not ply:GetJAwakened() then ply:SetJAwaken( math.min( 1, ply:GetJAwaken() + 0.03 ) ) end
	end
	JJS.Util.Effect( "jjs_kit_cast", JJS.Util.BodyCenter( ply ), nil, ply, 0.6, JJS.Kit.COLOR_ID.gold )
end

-- Judge Gavel: the M1 string continues from the 2nd M1
local function SecondM1( ply )
	ply:SetJM1Index( 1 )
	ply:SetJM1LastEnd( CurTime() )
end

-- Justice Served's block break also puts the user's front dash on cooldown
local function CrushBreak( ply )
	SecondM1( ply )
	ply:SetJDashFrontCD( CurTime() + JJS.Config.Dash.FrontCooldown )
end

-- Adds an Execution stack; the second one kills
local function Execute( ply, victim )
	victim.jjs_execution = ( victim.jjs_execution or 0 ) + 1
	if victim.jjs_execution >= 2 then JJS.Kill( victim, ply, { type = JJS.DMG.SPECIAL } ) end
end

-- Extended Swings' special variant (also Pressing Charges > Extended Swings): a quick sweep of the extended handle with
-- melee i-frames. Pushes the target away with momentary true ragdoll (no damage, no stun), crushes a block, and if it
-- interrupts any action the target gets a long stun on wakeup while the user's front dash goes off cooldown.
local SWEEP = { kind = "melee", startup = 0.2, endlag = 0.35, hits = 1, damage = 0, hitDamage = false, reach = 13, width = 12,
	type = "melee", block = "none", meleeIFrames = 0.45, trueRag = true, ragdoll = { time = 0.35, h = 45, v = 10 }, crater = false,
	guardBreak = { damage = 0, stun = 2.2, onBreak = SecondM1 },
	interrupt = { stun = 2.5, onInterrupt = function( ply ) ply:SetJDashFrontCD( 0 ) end } }

K.Character( "defenseattorney", {
	name = "Defense Attorney",
	category = "complete",
	hp = 90,
	model = K.Model( "defenseattorney", "models/player/magnusson.mdl" ),
	color = Color( 230, 210, 120 ),

	-- per-hit M1 frames { startup, recovery, block endlag } (dogslamloop). The 2nd M1 hits twice (2 + 2, 10f apart).
	-- TODO: two hitboxes on the 2nd M1.
	m1 = {
		Damage = { 2, 4, 4, 4 }, -- Judge Gavel: 2 + (2 + 2) + 4 + 4
		Frames = { { 14, 5, 11 }, { 25, 6, 13 }, { 19, 6, 13 } },
	},

	passives = {
		{ "Judge Gavel", "The 2nd M1 hits twice (2 + (2 + 2) + 4 + 4); block breaks set the string to it." },
		{ "Unarmed", "After No Escape the gavel is away: moves recall it and use their special variant." },
	},

	abilities = {
		-- The gavel becomes a sledgehammer: 3 swings (2 each) and a slam knocking the target down (9). True combo off 3 M1s.
		-- The swings can't hit grounded ragdolls, but one landing cancels the ragdoll, speeds the move up by 20% and
		-- enlarges the slam's hitbox (TODO: the speed up).
		[ 1 ] = K.Melee{ "Extended Swings", cooldown = 15, startup = 0.35, hits = 4, interval = 0.3, hitDamage = { 2, 2, 2, 9 }, reach = 11,
			type = "melee", hitBypass = { false, false, false, true }, ragdoll = { h = 10, v = -25 }, crater = 800,
			cond = table.Merge( { test = Unarmed, onUse = Recall }, table.Copy( SWEEP ) ) },
		-- Lifts the gavel and slams it at a comedic size, bouncing the target high (12, unblockable, bypasses ragdoll).
		-- A blocking target is crushed and block broken on the floor for a few seconds instead (9; the ragdoll is only
		-- visual, M1s still hit) and the user's front dash goes on cooldown. Unarmed: the windup is 25% faster.
		-- TODO: freezes before the slam when there is no ground to hit.
		[ 2 ] = K.Melee{ "Justice Served", cooldown = 18, startup = 0.6, endlag = 0.5, damage = 12, reach = 10, width = 11, type = "melee",
			block = "none", bypassRagdoll = true, crater = 1300, ragdoll = { h = 5, v = 60 },
			guardBreak = { damage = 9, stun = 2.5, onBreak = CrushBreak },
			cond = { test = Unarmed, onUse = Recall, startup = 0.45 } },
		-- Holds the gavel forward and extends its handle (7): knockback with slight stun, blocking doesn't stop the push.
		-- Interrupting an action (not a block) stuns much longer: a front dash converts. Safe on hit.
		-- USE TWICE in the windup: a mostly uncounterable slam follows (6, total 13); the two only link on an interrupt.
		-- Special in the windup (free): extends the handle backwards, ejecting the user 35 studs forward and slightly up
		-- (half cooldown, the special stays ready). Unarmed: recalls the gavel and skips straight to the slam.
		-- Grapple (aimed at an airborne target, ragdolled or not): hooks them and smacks them into the ground (11, true
		-- ragdoll); a blocking target takes no damage but is still stunned.
		[ 3 ] = K.Melee{ "Judgement's Reach", cooldown = 13, startup = 0.45, endlag = 0.35, damage = 7, reach = 22, width = 4, type = "bullet",
			bypassRagdoll = true, stun = 0.6, knock = 30, knockBlock = true, interrupt = { stun = 1.6 }, tip = "USE TWICE",
			combo = { [ 3 ] = { free = true, hits = 2, interval = 0.5, hitDamage = { 7, 6 }, endlag = 0.6,
				ragdoll = { h = 5, v = -30 } } },
			special = { kind = "mobility", free = true, cooldown = 6.5, travel = 35, time = 0.35, arc = 0.25, endlag = 0.05, damage = 0 },
			cond = { test = Unarmed, onUse = Recall, startup = 0.3, damage = 6, reach = 16, width = 6, type = "swarm", block = "none",
				stun = false, knock = false, interrupt = false, ragdoll = { h = 5, v = -30 } },
			airTarget = { damage = 11, reach = 22, height = 24, type = "melee", knock = false, interrupt = false, trueRag = true,
				ragdoll = { h = 5, v = -60 } } },
		-- Kicks the target away regardless of block (4), then runs at them to swing the gavel as they recover (3.5).
		-- A target at 15 HP is kick-stunned longer, at 14.5 HP or less the swing deals 11 more (an execution).
		-- During the run: 1 = "Extension Trip" (the sweep; Extended Swings on 7s), 2 = "Justice Swipe" (a giant left
		-- swing, 5, block breaking; Justice Served on 7s, can be countered or hit out of), 4 again = swing right away.
		-- Unarmed: only the kick, half a second more stun, the M1 string set to the 2nd M1 (the gavel isn't recalled).
		[ 4 ] = K.Melee{ "Pressing Charges", cooldown = 16, startup = 0.3, endlag = 0.35, hits = 2, interval = 0.9, hitDamage = { 4, 3.5 },
			reach = 9, type = "melee", bypassRagdoll = true, stun = 1.0, knock = 38, knockBlock = true, chase = 70, comboFrom = 0.35,
			comboWindow = 1.1, lowHp = { hp = 14.5, damage = 11 }, ragdoll = { h = 45, v = 15 }, tip = "USE AGAIN",
			again = K.Melee{ "Pressing Charges: Swing", window = 1.1, startup = 0.12, damage = 3.5, reach = 11, lunge = 10, type = "melee",
				bypassRagdoll = true, lowHp = { hp = 14.5, damage = 11 }, ragdoll = { h = 45, v = 15 } },
			combo = {
				[ 1 ] = table.Merge( table.Copy( SWEEP ), { comboCooldown = 7, chase = false, knock = false, lowHp = false, comboFrom = false } ),
				[ 2 ] = { comboCooldown = 7, startup = 0.35, hits = 1, hitDamage = false, damage = 5, reach = 13, width = 12, lunge = 10, block = "none",
					chase = false, knock = false, lowHp = false, bypassRagdoll = true, ragdoll = { h = 55, v = 15 },
					guardBreak = { damage = 5, stun = 2.5, onBreak = CrushBreak } },
			},
			cond = { test = Unarmed, hits = 1, hitDamage = false, damage = 4, stun = 1.5, chase = false, lowHp = false, ragdoll = false,
				onHit = SecondM1 } },
	},
	-- Throws the gavel 50 studs (3, 360 blockable, bypasses ragdoll); it's back in hand after 0.75s. Costs 3% awakening.
	-- Once it touched someone (even blocked) it takes three times as long and pressing the special again does
	-- "Rushdown": a quick short hop at the target (steer it: W/jump for further and higher, S for a short hop) with
	-- No Escape reset to 8s. A move (not Pressing Charges), an M1 or a third press recalls the gavel.
	special = K.Projectile{ "No Escape", cooldown = 5, startup = 0.2, endlag = 0.15, damage = 3, range = 50, speed = 200, radius = 2.5,
		type = "bullet", block = "all", bypassRagdoll = true, awakenCost = 0.03, color = "gold", gavel = true,
		onUse = function( ply )
			ply.jjs_gavelHit = nil
			ply:SetNW2Float( "JJSGavelBack", CurTime() + 0.2 + GAVEL_BACK )
		end,
		onContact = function( ply )
			ply.jjs_gavelHit = true
			ply.jjs_kitLanded = true
			ply:SetNW2Float( "JJSGavelBack", CurTime() + GAVEL_BACK_HIT )
		end,
		specialAfter = K.Mobility{ "Rushdown", window = 2.4, free = true, cooldown = 8, startup = 0.05, travel = 28, time = 0.35,
			dir = "target", steer = true, endlag = 0.1 } },

	awakening = {
		name = "Death Penalty",
		duration = 90,
		heal = 40,
		-- Deadly Sentencing: a platform with two podiums under suspended guillotines, Judgeman beside the caster. Awakening
		-- drain and regeneration stop and everyone is invulnerable. An accusation and a Judgment Bar (3 segments) appear:
		-- the defendant confesses, stays silent or denies; the verdict is Innocence (no heal), Confiscation (the target's
		-- moves are locked; Death Penalty then lasts 60s) or Death Penalty. 6 wrong guesses break the domain.
		-- TODO: the trial UI, verdicts and Confiscation. Invulnerable startup.
		domain = K.Domain{ "Deadly Sentencing", duration = 15, sureHit = "none", color = "gold" },
		-- Executioner's Sword: M1s reach 12 studs instead of 8 and the string is 6 hits (2 + 2 + (3 x 1) + 1); front dashes
		-- knock back with moderate stun instead of ragdolling. Targets only visibly dodge the M1s (golden afterimages).
		m1 = {
			Count = 6,
			Damage = { 2, 2, 1, 1, 1, 1 },
			HitSize = Vector( 12, 8, 8 ) * JJS.STUD,
			HitCenter = 5.5 * JJS.STUD,
			FrontDashStun = 1.0,
		},
		abilities = {
			-- A quick charged dash with the sword (10) impaling a limb, applying an Execution stack, then a toss (15).
			-- Unblockable; a target already carrying a stack is executed (300).
			[ 1 ] = K.Melee{ "Execution", cooldown = 12, startup = 0.35, hits = 2, interval = 0.5, hitDamage = { 10, 15 }, lunge = 20,
				type = "special", block = "none", ragdoll = { h = 55, v = 20 }, color = "gold", onHit = Execute },
			-- Runs forward then spins with a swipe (10, uninterruptible, unblockable, bypasses ragdoll). Landed, a close fight
			-- starts with a quick-time event (awakening drain stops): won, a stab (300); lost, the target jumps over the
			-- stab and is kicked away (25). Pressing 2 again during the run feints it with no endlag (17s cooldown).
			-- TODO: the QTE itself (a coin flip for now).
			[ 2 ] = K.Rush{ "Final Judgement", cooldown = 21, startup = 0.2, travel = 25, time = 0.45, hits = 2, interval = 1.2,
				hitDamage = { 10, 25 }, uninterruptible = true, type = "special", block = "none", bypassRagdoll = true, trueRag = true,
				ragdoll = { h = 60, v = 25 }, color = "gold", tip = "USE AGAIN",
				onHit = function( ply, victim )
					if math.random() < 0.5 then JJS.Kill( victim, ply, { type = JJS.DMG.SPECIAL } ) end
				end,
				again = K.Stub{ "Final Judgement: Feint", window = 0.6, startup = 0, endlag = 0.05,
					onUse = function( ply ) JJS.SetCooldown( ply, 2, 17 ) end } },
			-- Knocks the target away with the hilt (5), then flips the sword and dashes in with the edge (5). The first hit
			-- doesn't stun properly: unblocked, the edge executes like Execution (a stack or death); blocked, nothing.
			-- USE TWICE before the edge (automatic against a low target): the hilt swings again (10; blocked, the sword
			-- cuts through for 50).
			[ 3 ] = K.Melee{ "Verdict", cooldown = 18, startup = 0.35, hits = 2, interval = 0.55, hitDamage = { 5, 5 }, type = "melee",
				bypassRagdoll = true, trueRag = true, ragdoll = { h = 45, v = 15 }, onHit = Execute, tip = "USE TWICE",
				again = K.Melee{ "Verdict: Hilt", window = 0.5, startup = 0.2, damage = 10, type = "melee", blockDamage = 50,
					bypassRagdoll = true, ragdoll = { h = 55, v = 20 } } },
			-- Throws the sword forward to sever a limb (8, an Execution stack; 310 on execution) and recalls it. Pressing it
			-- two or three times throws that many times (+6s cooldown per extra throw). Perfect-blockable; the first two
			-- throws are always dodged by a target with two stacks but still deal damage.
			[ 4 ] = K.Projectile{ "Triple Sentence", cooldown = 12, startup = 0.3, damage = 8, range = 60, speed = 220, radius = 2.5,
				type = "bullet", block = "pre", bypassRagdoll = true, color = "gold", onHit = Execute, tip = "USE AGAIN",
				again = K.Projectile{ "Triple Sentence: 2nd", window = 0.9, startup = 0.2, damage = 8, range = 60, speed = 220, radius = 2.5,
					type = "bullet", block = "pre", bypassRagdoll = true, color = "gold", onHit = Execute,
					onUse = function( ply ) JJS.SetCooldown( ply, 4, 18 ) end,
					again = K.Projectile{ "Triple Sentence: 3rd", window = 0.9, startup = 0.2, damage = 8, range = 60, speed = 220,
						radius = 2.5, type = "bullet", block = "pre", bypassRagdoll = true, color = "gold", onHit = Execute,
						onUse = function( ply ) JJS.SetCooldown( ply, 4, 24 ) end } } },
		},
		-- A thin veil of their domain: the next attack is negated with about half a second of i-frames, and domain sure-hits
		-- don't affect them (without using the veil up). 8s cooldown once dispelled.
		special = K.Buff{ "Domain Amplification", cooldown = 1, startup = 0.2, duration = 0.2, color = "gold",
			onUse = function( ply ) ply.jjs_amplified = true end },
	},
} )

-- the veil can't be stacked
local amp = JJS.Characters.defenseattorney.awakening.special
local ampCanUse = amp.CanUse
amp.CanUse = function( ply, slot, mv )
	if ply.jjs_amplified then return false end
	return ampCanUse( ply, slot, mv )
end

-- pressing the special while the gavel is away (and no hop is available) recalls it
JJS.Characters.defenseattorney.special.Again = function( ply )
	if not Unarmed( ply ) or ply:GetJAwakened() then return false end
	Recall( ply )
	return true
end

-- the gavel's own moves resolve before recalls: Pressing Charges' unarmed kick doesn't bring it back
hook.Add( "JJS_M1", "JJS_GavelRecall", function( ply )
	if ply:GetJChar() == "defenseattorney" then Recall( ply ) end
end )

hook.Add( "JJS_PreHit", "JJS_DomainAmplification", function( victim, hit )
	if not victim.jjs_amplified or hit.attacker == victim then return end
	victim.jjs_amplified = nil
	JJS.IFrames( victim, 0.5 )
	JJS.SetCooldown( victim, 5, 8 )
	return "evaded"
end )

hook.Add( "JJS_DomainImmune", "JJS_DomainAmplification", function( ply )
	if ply.jjs_amplified then return true end
end )

hook.Add( "JJS_PlayerSpawned", "JJS_ExecutionStacks", function( ply )
	ply.jjs_execution = nil
	ply.jjs_amplified = nil
	ply.jjs_gavelHit = nil
	ply:SetNW2Float( "JJSGavelBack", 0 )
end )
