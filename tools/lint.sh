#!/bin/bash
# Syntax check (luac5.3) and static analysis (luacheck) of the gamemode. GLua `continue`
# is mapped to a no-op so standard Lua tools can parse the files.
R=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d)
cp -r "$R/gamemode" "$TMP/"
find "$TMP" -name '*.lua' -exec sed -i -E 's/\bcontinue\b/do end/g' {} \;
fail=0
for f in $(find "$TMP" -name '*.lua'); do
  out=$(luac5.3 -p "$f" 2>&1) || { echo "$out"; fail=1; }
done
[ $fail = 0 ] && echo "syntax OK"
G="GM GAMEMODE JJS ENT EFFECT SERVER CLIENT hook util player ents net file timer math string table surface draw render cam vgui gui input engine game physenv scripted_ents effects concommand list team bit os halo
include AddCSLuaFile DeriveGamemode CreateConVar CreateClientConVar GetConVar RunConsoleCommand Vector Angle Color ColorAlpha Material Matrix EffectData DamageInfo ParticleEmitter
CurTime RealTime FrameTime SysTime IsValid IsFirstTimePredicted LocalPlayer ScrW ScrH EyePos EyeAngles Lerp LerpVector LerpAngle OrderVectors VectorRand
isnumber isstring istable isfunction isvector isangle tobool FindMetaTable ClientsideModel NULL vector_origin angle_zero color_white color_black
IN_ATTACK IN_ATTACK2 IN_GRENADE1 IN_GRENADE2 IN_BULLRUSH IN_CANCEL IN_ALT1 IN_ALT2 IN_WEAPON1 IN_WEAPON2 IN_SPEED IN_DUCK IN_WALK IN_ZOOM IN_RELOAD IN_RUN IN_JUMP IN_FORWARD IN_BACK IN_MOVELEFT IN_MOVERIGHT
KEY_F KEY_Q KEY_R KEY_G KEY_1 KEY_2 KEY_3 KEY_4 KEY_LSHIFT KEY_I KEY_O MOUSE_LEFT
ACT_MP_STAND_IDLE ACT_MP_WALK ACT_MP_RUN ACT_MP_CROUCH_IDLE ACT_MP_CROUCHWALK ACT_MP_JUMP ACT_MP_SWIM ACT_LAND ACT_HL2MP_IDLE_FIST ACT_HL2MP_WALK_FIST ACT_HL2MP_RUN_FIST ACT_HL2MP_IDLE_CROUCH_FIST ACT_HL2MP_WALK_CROUCH_FIST ACT_HL2MP_JUMP_FIST ACT_HL2MP_SWIM_FIST
GESTURE_SLOT_ATTACK_AND_RELOAD GESTURE_SLOT_CUSTOM MASK_SOLID_BRUSHONLY MASK_PLAYERSOLID MASK_SHOT COLLISION_GROUP_PLAYER_MOVEMENT COLLISION_GROUP_WEAPON
MOVETYPE_NONE MOVETYPE_WALK SOLID_NONE DMG_GENERIC DMG_DROWN DMG_BURN TEAM_UNASSIGNED RENDERGROUP_TRANSLUCENT
TEXT_ALIGN_CENTER TEXT_ALIGN_LEFT TEXT_ALIGN_RIGHT TEXT_ALIGN_TOP TEXT_ALIGN_BOTTOM FILL LEFT RIGHT TOP BOTTOM FCVAR_ARCHIVE FCVAR_NOTIFY FCVAR_REPLICATED ChloeImpact ErrorNoHalt"
luacheck "$TMP/gamemode" --std lua51 --codes --no-max-line-length --globals $G --ignore 541 212 213 211/_.* 542 431 432 421 423 311 --formatter plain 2>&1 | sed "s#$TMP/##" | grep -v "^Total"
rm -rf "$TMP"
