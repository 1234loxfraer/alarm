-- Character registry.
--
-- A character table may define:
--   name, model, color (Color used by HUD), hp (max health, default 100), scale (model size)
--   category ("complete", "early", "baseonly", "op", "other"; used by the menu)
--   m1 = { overrides of JJS.Config.M1 }
--   abilities = { [1..4] = ability }, special = ability
--   alt = { name, abilities, special } -- second moveset toggled by the character (ply:GetJKitSet() == 1)
--   awakening = { name, duration, heal, abilities, special, alt, m1 = { M1 overrides while awakened } }
--   awakenMove = ability -- base-only characters: G performs this move instead of a moveset
--   passives = { { name, desc }, ... } -- listed in the menu
--   hooks: Awaken(ply, mv), AwakenPress(ply, mv) (G while awakened), OnM1Final(ply, variant, cfg) -> true if
--          handled, OnSpawn(ply), NoRegen(ply) -> bool, Think(ply) (server tick), HUDPaint(ply) (client),
--          SpeedMult(ply) -> number
--
-- An ability:
--   name, tip ("HOLD", "USE AGAIN"... or function(ply, slot) -> tip), cooldown
--   CanUse(ply, slot, mv) -> bool, Use(ply, mv, slot)
--   Again(ply, mv, slot) -> true when a follow-up was triggered (checked before the cooldown)
--   Pick(ply, slot) -> ability; resolves to another ability (mode dependent moves, rotations..)
-- Abilities built with JJS.Kit (sh_kit.lua) fill all of these in.

JJS.Characters = JJS.Characters or {}
JJS.CharacterOrder = JJS.CharacterOrder or {}

function JJS.RegisterCharacter( id, def )
	def.id = id
	local m1 = table.Copy( JJS.Config.M1 )
	for k, v in pairs( def.m1 or {} ) do m1[ k ] = v end
	def.m1 = m1
	-- m1Alt = { overrides } used while char.M1Alt(ply) is true; m1Alts = { name = { overrides } } when it returns a name
	if def.m1Alt then
		local alt = table.Copy( m1 )
		for k, v in pairs( def.m1Alt ) do alt[ k ] = v end
		def.m1altcfg = alt
	end
	if def.m1Alts then
		def.m1altcfgs = {}
		for name, over in pairs( def.m1Alts ) do
			local alt = table.Copy( m1 )
			for k, v in pairs( over ) do alt[ k ] = v end
			def.m1altcfgs[ name ] = alt
		end
	end
	-- awakening.m1 = { overrides of the base M1 } used while awakened
	if def.awakening and def.awakening.m1 then
		local am1 = table.Copy( m1 )
		for k, v in pairs( def.awakening.m1 ) do am1[ k ] = v end
		def.awakening.m1cfg = am1
	end
	def.color = def.color or Color( 120, 200, 255 )
	def.hp = def.hp or JJS.Config.MaxHealth
	def.category = def.category or "complete"
	if not JJS.Characters[ id ] then JJS.CharacterOrder[ #JJS.CharacterOrder + 1 ] = id end
	JJS.Characters[ id ] = def
	return def
end

function JJS.GetChar( ply )
	return JJS.Characters[ ply:GetJChar() ] or JJS.Characters[ JJS.Config.DefaultCharacter ]
end

-- The moveset table currently in use (base, awakening, or one of their alternate sets)
function JJS.GetKit( ply )
	local char = JJS.GetChar( ply )
	if not char then return end
	local set = char
	if ply:GetJAwakened() and char.awakening and char.awakening.abilities then set = char.awakening end
	if ply:GetJKitSet() == 1 and set.alt then set = set.alt end
	return set, char
end

local function Resolve( ab, ply, slot )
	for _ = 1, 4 do
		if not ab or not ab.Pick then break end
		ab = ab.Pick( ply, slot )
	end
	return ab
end

-- slot 1..4 = moves, 5 = special
function JJS.GetAbility( ply, slot )
	local set = JJS.GetKit( ply )
	if not set then return end
	local ab
	if slot == 5 then
		ab = set.special
	else
		ab = set.abilities and set.abilities[ slot ]
	end
	return Resolve( ab, ply, slot )
end

function JJS.TryAbility( ply, mv, slot )
	if JJS.IsImpaired( ply ) then return end
	if slot == 5 and JJS.Kit.TrySpecialVariant( ply, mv ) then return end
	if slot ~= 5 and JJS.Kit.TryCombo( ply, mv, slot ) then return end
	local ab = JJS.GetAbility( ply, slot )
	if not ab then return end
	if ab.Again and ab.Again( ply, mv, slot ) then return end
	if not ab.Use then return end
	if JJS.GetCooldown( ply, slot ) > CurTime() then return end
	if ab.CanUse then
		if not ab.CanUse( ply, slot, mv ) then return end
	elseif not JJS.CanAct( ply ) or JJS.IsBlocking( ply ) or JJS.IsBusy( ply ) or JJS.IsDashing( ply ) then
		return
	end
	ab.Use( ply, mv, slot )
end
