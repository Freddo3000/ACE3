#include "script_component.hpp"
/*
 * Author: commy2
 * Play random injured sound for a unit. The sound is broadcasted across MP.
 * Will not play if the unit has already played a sound within to close a time frame.
 *
 * Arguments:
 * 0: Unit <OBJECT>
 * 1: Type (optional) ["hit" (default) or "moan"] <STRING>
 * 2: Severity (optional) [0 (default), 1, 2] <NUMBER>
 *
 * Return Value:
 * None
 *
 * Example:
 * [player, "hit", 1] call ace_medical_feedback_fnc_playInjuredSound
 *
 * Public: No
 */
#define TIME_OUT_HIT 1
#define TIME_OUT_MOAN 5

params [["_unit", objNull, [objNull]], ["_type", "hit", [""]], ["_severity", 0, [0]]];
// TRACE_3("",_unit,_type,_severity);

if (!local _unit) exitWith {
    ERROR("Unit not local or null");
};
if !(_unit call EFUNC(common,isAwake)) exitWith {};

// Handle timeout
if (_unit getVariable [QGVAR(soundTimeout) + _type, -1] > CBA_missionTime) exitWith {};
private _timeOut = TIME_OUT_HIT;
if ((_type == "moan") && {(GVAR(painScreamFrequency) == 0) || {_timeOut = TIME_OUT_MOAN / GVAR(painScreamFrequency); false}}) exitWith {};
_unit setVariable [QGVAR(soundTimeout) + _type, CBA_missionTime + _timeOut];

// Get units speaker
private _speaker = speaker _unit;
if (_speaker == "ACE_NoVoice") then {
    _speaker = _unit getVariable "ace_originalSpeaker";
};

// Fallback if speaker has no associated scream/moan sound
if (isNull (configFile >> "CfgSounds" >> format ["ACE_moan_%1_low_1", _speaker])) then {
    _speaker = "Male08ENG";
};

// Select actual sound
private _variation = ["low", "mid", "high"] select _severity;
private _distance = if (_type == "hit") then {
    [50, 60, 70] select _severity;
} else {
    [10, 15, 20] select _severity;
};

private _cfgSounds = configFile >> "CfgSounds";
private _targetClass = format ["ACE_%1_%2_%3_", _type, _speaker, _variation];
private _index = 1;
private _sounds = [];
while {isClass (_cfgSounds >> (_targetClass + str _index))} do {
    _sounds pushBack (_cfgSounds >> (_targetClass + str _index));
    _index = _index + 1;
};
private _sound = configName selectRandom _sounds;
if (isNil "_sound") exitWith { WARNING_1("no sounds for target [%1]",_targetClass); };

// Limit network traffic by only sending the event to players who can potentially hear it
private _targets = _unit nearEntities ["CAManBase", _distance];
[QGVAR(forceSay3D), [_unit, _sound, _distance], _targets] call CBA_fnc_targetEvent;
