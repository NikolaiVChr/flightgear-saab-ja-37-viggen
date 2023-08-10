#### Landing phase and submodes

var MODE = {
    OFF: 0,
    # Phase 1: waypoint LB
    BEFORE_DESCENT: 1,      # AJS only, hold altitude before descent
    DESCENT: 2,             # AJS only, 4deg descent when starting >600m
    LB: 3,                  # normal phase 1
    LB_SHORT: 4,            # short approach variant
    # Phase 2: localizer intercept
    CIRCLE: 5,              # 'flying the circle', at a constant turning speed
    CENTERLINE: 6,          # follow centerline on INS (no TILS)
    INTERCEPT: 7,           # 45deg TILS intercept
    LINEAR: 8,              # linear localizer signal
    # Phase 3: final
    FINAL: 9,               # TILS final
    OPTICAL: 10,            # visual final
    MAX: 11,
};

var mode = MODE.OFF;


### Modes state machine

var mode_update = [];
setsize(mode_update, MODE.MAX);

# Shared function testing if tangent point LB is passed,
# to test when to exit phase 1.
var passed_tangent = func {
    if (circle_dist <= 0)
        # We are _in_ the circle! Phase 1 flight director doesn't handle that well, switch phase.
        return TRUE;

    # JA37C SFI 4.4.3.2: distance to LB is less than 4100m and increasing.
    if (tangent_dist <= 4100 and tangent_dist >= last_tangent_dist)
        return TRUE;

    return FALSE;
}

mode_update[MODE.BEFORE_DESCENT] = func {
    if (passed_tangent())
        mode = MODE.CIRCLE;
    elsif (altitude < 600)
        mode = MODE.LB;
    elsif (descent_angle() >= DESCENT_ANGLE)
        mode = MODE.DESCENT;
}

mode_update[MODE.DESCENT] = func {
    if (passed_tangent())
        mode = MODE.CIRCLE;
    elsif (altitude < 600)
        mode = MODE.LB;
}

mode_update[MODE.LB] = func {
    if (passed_tangent())
        mode = MODE.CIRCLE;
}

mode_update[MODE.LB_SHORT] = func {
    if (passed_tangent())
        mode = MODE.CIRCLE;
}

mode_update[MODE.CIRCLE] = func {
    # AJS37 SFI 5.10.4.1.1
    if (abs_angle(heading - appch_heading) <= 5)
        mode = MODE.CENTERLINE;
}

mode_update[MODE.CENTERLINE] = func {}; # nothing to do

mode_update[MODE.FINAL] = func {
    var rad_alt = input.rad_alt_ready.getBoolValue() ? input.rad_alt.getValue() : nil;

    if (altitude < 35 or (altitude < 60 and rad_alt != nil and rad_alt < 15))
        mode = MODE.OPTICAL;
}

mode_update[MODE.OPTICAL] = func {};    # nothing to do


var update_mode = func {
    if (!mode) return;
    mode_update[mode]();
}


### External mode selection

# If a runway is selected as destination, set mode to 'm', and return TRUE.
# Otherwise, select optical mode and return FALSE.
var try_activate_mode = func(m) {
    if (!load_runway()) {
        # no runway, still activate optical mode
        mode = MODE.OPTICAL;
        return FALSE;
    }

    mode = m;
    return TRUE;
}

var deactivate = func {
    mode = MODE.OFF;
}

var short_approach_mode = func {
    set_short_final(TRUE);

    if (!load_runway()) {
        # no runway, still activate optical mode
        mode = MODE.OPTICAL;
        return FALSE;
    }

    var heading_to_rwy = ac_pos.course_to(appch_pos);
    # When within 20deg cone from runway and heading <90deg from runway, straight to centerline mode.
    if (abs_angle(heading_to_rwy - appch_heading) <= 20 and abs_angle(heading - appch_heading) <= 90)
        return try_activate_mode(MODE.CENTERLINE);
    else
        return try_activate_mode(MODE.LB_SHORT);
}
