-- Character registry.
--
-- A character table may define:
--   name, model, color (Color used by HUD)
--   m1 = { overrides of JJS.Config.M1 }
--   abilities = { [1..4] = ability }, special = ability
--   awakening = { duration = s, abilities = {...}, special = ability }
--   hooks: Awaken(ply, mv), OnM1Final(ply, variant, cfg) -> true if handled, OnSpawn(ply),
--          NoRegen(ply) -> bool, Think(ply) (server tick), HUDPaint(ply) (client)
--
-- An ability:
--   name, tip ("HOLD", "USE AGAIN"...), cooldown
--   CanUse(ply, slot) -> bool, Use(ply, mv, slot)

JJS.Characters = JJS.Characters or {}

function JJS.RegisterCharacter( id, def )
	def.id = id
	local m1 = table.Copy( JJS.Config.M1 )
	for k, v in pairs( def.m1 or {} ) do m1[ k ] = v end
	def.m1 = m1
	def.color = def.color or Color( 120, 200, 255 )
	JJS.Characters[ id ] = def
	return def
end

function JJS.GetChar( ply )
	return JJS.Characters[ ply:GetJChar() ] or JJS.Characters[ JJS.Config.DefaultCharacter ]
end

-- slot 1..4 = moves, 5 = special
function JJS.GetAbility( ply, slot )
	local char = JJS.GetChar( ply )
	if not char then return end
	local set = char
	if ply:GetJAwakened() and char.awakening then set = char.awakening end
	if slot == 5 then return set.special end
	return set.abilities and set.abilities[ slot ]
end

function JJS.TryAbility( ply, mv, slot )
	local ab = JJS.GetAbility( ply, slot )
	if not ab or not ab.Use then return end
	if JJS.GetCooldown( ply, slot ) > CurTime() then return end
	if ab.CanUse then
		if not ab.CanUse( ply, slot, mv ) then return end
	elseif not JJS.CanAct( ply ) or JJS.IsBlocking( ply ) or JJS.IsBusy( ply ) or JJS.IsDashing( ply ) then
		return
	end
	ab.Use( ply, mv, slot )
end
