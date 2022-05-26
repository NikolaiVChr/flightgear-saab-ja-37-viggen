### Mode selection logic for AJS 37 PS-37/A radar and CI display
#
# This is a big old dirty state machine which controls the operating modes
# used by the radar (radar/ps37.nas) and display (displays/ci.nas).
#
# Reference: AJS37 SFI part III chap. 2, sec 7.

var TRUE = 1;
var FALSE = 0;

var input = {
    nose_wow:           "fdm/jsbsim/gear/unit[0]/WOW",
    radar_mode:         "instrumentation/radar/mode",
    wpn_knob:           "/controls/armament/weapon-panel/selector-knob",
    passive_mode:       "ja37/radar/panel/passive",
};

foreach(var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
};


## Radar / CI operation mode.

var RADAR_MODE = {
    STBY: 0,    # RX
    PASSIVE: 1, # RBX
    GND_RNG: 2, # RFX / RF MARK (ground ranging, implemented separately)
    NORMAL: 3,  # RBK/RSK
    TERRAIN: 4, # RBH/RSH
    RB04: 5,    # RB04/RS04
    AIR: 6,     # RBJR/RSJR
    AIR_RNG: 7, # RFJR
};
var radar_mode = RADAR_MODE.STBY;

var CI_MODE = {
    # TODO
    STBY: 0,     # CU
    NORMAL: 1,
    MEMORY: 2,
};
var ci_mode = CI_MODE.STBY;

var SCAN_MODE = {
    OTHER: 0,
    WIDE: 1,    # Wide scan / PPI
    NARROW: 2,  # Narrow scan / B-scope
};
var scan_mode = SCAN_MODE.OTHER;


## Internal state

var STATE = {
    OFF: 0,
    SILENT: 1,
    PASSIVE: 2,
    NORMAL: 3,
    TERRAIN: 4,
    ATTACK: 5,
    RB04: 6,
    AIR: 7,
    GND_RNG: 8,
    AIR_RNG: 9,
};

# Internal state to output conversion table.
# Indexed by state, result is array [radar mode, CI mode]
# Does not include memory mode
#
var state_to_mode = [
    [RADAR_MODE.STBY, CI_MODE.STBY],        # OFF
    [RADAR_MODE.STBY, CI_MODE.NORMAL],      # SILENT
    [RADAR_MODE.PASSIVE, CI_MODE.NORMAL],   # PASSIVE
    [RADAR_MODE.NORMAL, CI_MODE.NORMAL],    # NORMAL
    [RADAR_MODE.TERRAIN, CI_MODE.NORMAL],   # TERRAIN
    [RADAR_MODE.NORMAL, CI_MODE.NORMAL],    # ATTACK
    [RADAR_MODE.RB04, CI_MODE.NORMAL],      # RB04
    [RADAR_MODE.AIR, CI_MODE.NORMAL],       # AIR
    [RADAR_MODE.GND_RNG, CI_MODE.STBY],     # GND_RNG
    [RADAR_MODE.AIR_RNG, CI_MODE.STBY],     # AIR_RNG
];


var current_state = STATE.OFF;

var memory = FALSE;

var ci_tmp_on = FALSE;
var CI_TMP_ON_TIME = 45;
var ci_tmp_on_timer = maketimer(CI_TMP_ON_TIME, func { ci_tmp_on = FALSE; });
ci_tmp_on_timer.singleShot = TRUE;
ci_tmp_on_timer.simulatedTime = TRUE;


# Update CI/radar mode output
var update_radar_ci_mode = func {
    if (memory) {
        radar_mode = RADAR_MODE.STBY;
        ci_mode = CI_MODE.MEMORY;
    } else {
        radar_mode = state_to_mode[current_state][0];
        ci_mode = state_to_mode[current_state][1];
    }
}


# Return (but does not update) next state
var decide_state = func(click) {
    var type = nil;
    var wpn_knob = nil;

    # Standby conditions
    if (modes.selector_ajs <= modes.STBY)
        return STATE.OFF;

    if (input.nose_wow.getBoolValue())
        return (modes.selector_ajs >= modes.LND_NAV or ci_tmp_on) ? STATE.SILENT : STATE.OFF;

    # Careful with order: ranging for ground attack ignores radar switch A0
    if (modes.selector_ajs == modes.COMBAT) {
        type = fire_control.get_type();
        wpn_knob = input.wpn_knob.getValue();

        if (type == "M70" or type == "RB-75"
            or (type == "RB-05A" and wpn_knob == fire_control.WPN_SEL.DYK_MARK_RB75)
            or (type == "M55" and wpn_knob == fire_control.WPN_SEL.ATTACK)
            or (type == "M71" and wpn_knob != fire_control.WPN_SEL.RR_LUFT))
            return STATE.GND_RNG;
        # Other cases are handled after A0 switch
    }

    # Radar switch off
    if (input.radar_mode.getValue() == 0) {
        if (input.passive_mode.getBoolValue())
            return STATE.PASSIVE;
        elsif (modes.selector_ajs >= modes.LND_NAV or ci_tmp_on)
            return STATE.SILENT;
        else
            return STATE.OFF;
    }

    # All the combat specific modes
    if (modes.selector_ajs == modes.COMBAT) {
        # Remark: type and wpn_knob set in the earlier if.

        if (type == "IR-RB"
            or (type == "M55" and wpn_knob == fire_control.WPN_SEL.AKAN_JAKT)
            or (type == "RB-05A" and wpn_knob == fire_control.WPN_SEL.RR_LUFT))
        {
            return (current_state == STATE.AIR_RNG or click) ? STATE.AIR_RNG : STATE.AIR;
        }
        elsif (type == "RB-04E" or type == "RB-15F" or type == "M90")
        {
            return STATE.RB04;
        }
        elsif ((type == "RB-05A" and wpn_knob == fire_control.WPN_SEL.PLAN_SJO)
               or (type == "M71" and wpn_knob == fire_control.WPN_SEL.RR_LUFT))
        {
            return STATE.ATTACK;
        }
    }

    # Normal mode
    return (current_state == STATE.TERRAIN) ? STATE.TERRAIN : STATE.NORMAL;
}

# Update current state
var update_state = func {
    # In AIR mode, this controller reads radar cursor controls
    var click = (current_state == STATE.AIR and displays.common.getCursorDelta()[2]);

    var new_state = decide_state(click);

    if (new_state >= STATE.NORMAL and new_state <= STATE.AIR)
        var new_scan_mode = input.radar_mode.getValue();
    else
        var new_scan_mode = SCAN_MODE.OTHER;


    if (new_state == current_state and new_scan_mode == scan_mode)
        # Nothing changed
        return;

    current_state = new_state;
    scan_mode = new_scan_mode;

    # Reset temporary modes
    memory = FALSE;
    if (ci_tmp_on and current_state != STATE.SILENT) {
        ci_tmp_on = FALSE;
        ci_tmp_on_timer.stop();
    }

    if (current_state == STATE.AIR) displays.common.resetCursorDelta();

    update_radar_ci_mode();
}


## Pushbuttons

var terrain_mode = func {
    if (current_state == STATE.OFF) {
        # Temporarily turn on CI
        ci_tmp_on = TRUE;
        ci_tmp_on_timer.restart(CI_TMP_ON_TIME);
    } elsif (current_state == STATE.NORMAL) {
        # Terrain mode
        current_state = STATE.TERRAIN;
        memory = FALSE;
        update_radar_ci_mode();
    }
}

var memory_mode = func {
    if (scan_mode != SCAN_MODE.WIDE) return;
    if (current_state != STATE.NORMAL and current_state != STATE.ATTACK and current_state != STATE.RB04) return;

    memory = TRUE;
    update_radar_ci_mode();
}