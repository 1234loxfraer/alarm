-- Cursed Partners. Generated from the JJS wiki; every move is a JJS.Kit placeholder.
-- Comments summarise what the real move does (see the wiki page for details).

local K = JJS.Kit

K.Character( "cursedpartners", {
	name = "Cursed Partners",
	category = "complete",
	hp = 90,
	model = K.Model( "cursedpartners", "models/player/group01/male_05.mdl" ),
	color = Color( 255, 120, 200 ),

	passives = {
		{ "Swordsmanship", "The user is equipped with a holster for their katana and a necklace tied to a cursed ring." },
	},

	abilities = {
		-- The user slides 18 studs forwards while sweeping the floor with their blade and imbuing it with cursed energy.
		-- TODO direction: backward variant "Veilstep": Walking backwards while using Severing Path will prompt the user to retreat with a back roll, traveling about 27 studs while gaining...
		[ 1 ] = K.Melee{ "Severing Path", cooldown = 15, damage = 10.9, hits = 2, type = "melee", bypassRagdoll = true, tip = "DIRECTION" },
		-- By aiming at a spot within 25 studs, the user vanishes while winding up a long swing of their tool, before reappearing to finish the attack with a slash aiming for...
		-- Follow-up "Resolute Black Flash": Using the move again right as the user reappears will allow them to vanish a second time then reappear with a heavy blow wound up and...
		[ 2 ] = K.Melee{ "Resolute Slash", cooldown = 15, damage = 12, type = "melee", block = "none", tip = "USE AGAIN", again = K.Melee{ "Resolute Black Flash", damage = 12, type = "melee", block = "none", bypassRagdoll = true } },
		-- The user holds their holstered katana by the handle to apply cursed energy to their incoming swing, triggering a giant mostly uncounterable burst that deals damage...
		[ 3 ] = K.Counter{ "Outburst", cooldown = 16, counters = { melee = "evade", bullet = "evade" }, riposte = 2 },
		-- The user rushes 20 studs forward while gaining melee i-frames by boosting their feet with cursed energy.
		-- TODO variant: Using Severing Path right as the user collides with a defenseless standing target will switch their strategy from attempting to grab...
		[ 4 ] = K.Grab{ "Second Wind", cooldown = 16, damage = 10, hits = 2, type = "melee", block = "all", armor = "melee" },
	},
	-- Upon using the special, Rika, the Queen of Curses, will partially manifest to the user’s right and stay by their side, functioning as a separate, intangible,...
	special = K.Mobility{ "Rika", uninterruptible = true, travel = 100 },

	awakening = {
		name = "True Love",
		duration = 60,
		heal = 25,
		-- The user calls out to their cursed spirit companion to make a binding vow: "Come, Rika.
		-- TODO awakening ability "Copy Wheel": The user's own technique allows them to copy and use the cursed technique of any enemy Rika has attacked (via Rika Downslam, Rika Slam, or Elbow...
		-- TODO cometic/passive "Steel Arm": After equipping their new weapon, the player utilizes their steel casing to empower their attacks, adding a quick jab that follows each of the...
		abilities = {
			-- The user dashes forwards, traveling about 38.5 studs while swinging their right arm to land an elbow strike that sends the opponent spinning away, before quickly...
			[ 1 ] = K.Melee{ "Elbow Rush", cooldown = 15, damage = 4, hits = 2, type = "melee", block = "none", lunge = 38.5 },
			-- By default, the user possesses the Cursed Speech technique which, by bearing the Snake Eyes and Fangs mark around their mouth, allows them to command to all players...
			[ 2 ] = K.Buff{ "Copy", cooldown = 15, block = "all" },
			-- The user pulls out their cursed tool and drives it into the floor while imbuing it with cursed energy to create a field around them that will push all enemies within...
			-- Follow-up "Fakeout": Using the move once again before the katana hits the ground will cancel it with a sudden swing that will transfer its imbued cursed...
			[ 3 ] = K.AoE{ "Energy Ripple", cooldown = 18, damage = 19, type = "explosion", block = "none", bypassRagdoll = true, uninterruptible = true, radius = 27, ragdoll = { h = -20, v = 16 }, color = "orange", tip = "USE AGAIN", again = K.Melee{ "Fakeout", damage = 19, hits = 2, type = "melee", block = "none", bypassRagdoll = true, uninterruptible = true } },
			-- The user casts their Domain Expansion, conjuring a stone platform with several structures rising from the ground, and knots symbolizing their love circling the sky.
			-- Follow-up "Jacob's Ladder": After landing 4 direct swings using their domain's katanas, the user can conjure a divine ray from the sky by using their domain again...
			[ 4 ] = K.Domain{ "Authentic Mutual Love", cooldown = 120, duration = 45, sureHit = "none", color = "white", tip = "USE AGAIN", again = K.Beam{ "Jacob's Ladder", damage = 62.5, block = "none", bypassRagdoll = true, trueRag = true, armor = "total", color = "white" } },
		},
		-- Despite being fully manifested, Rika still functions similarly in base.
		special = K.Buff{ "Rika", uninterruptible = true },
	},

	-- TODO tab "Awakened Rika" from the wiki:
	--   Rika Downslam: The user motions for Rika to slam the target arm into the floor by applying pressure on them with one arm.
	--   Rika Slam: Rika hovers over to a target before grabbing them by their leg, and slamming them five times on the ground in anger.
	--   True Love Beam: Using their combined cursed energy, Rika and the user conjure a small pink orb, before Rika takes over as she grows...
	--   Rika Throw: The user crosses their arms for Rika to pick them up, she wind back her arm and throw them with force.

	-- TODO tab "Authentic Mutual Love" from the wiki:
	--   Shrine: If the katana hits an enemy, the user will activate the secondary blade of Shrine, Cleave, slashing them 4 times,...
	--   Thin Ice Breaker: The user strengthens their katana blow using an extension technique of "Sky Manipulation", and breaks the sky like a...
	--   Clairvoyance: Once in contact with an opponent, the user slashes them with their katana and draws blood to mark them with a manga...
	--   Cursed Speech: Once in contact with an opponent, the user strikes them with their katana and commands to them: "落ちれ!" (pronounced:...
	--   Shikigami: Once in contact with an opponent, the user sends 3 flying shikigamis resembling Rika's head with wings, to swarm the...

	-- TODO tab "Base Rika" from the wiki:
	--   Rika Smash: Rika's fist will grow in size as it is raised above the target, before slamming down on them and causing them to...
	--   Rika Launch: The user quickly motions for Rika to move behind and quickly give them a boost, launching them slightly forward.
	--   Rika Haymaker: Rika hovers over to the targeted enemy if they are within 10 studs of her, then slowly winds up a heavy blow that...

	-- TODO other entries of the base moveset:
	--   Outburst [bullet counter]: If the user is hit within 0.25 seconds of Outburst, their swing will parry the incoming attack.
} )
