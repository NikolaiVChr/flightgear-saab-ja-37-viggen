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
    # TODO: LB_SHORT or CENTERLINE depending on position when engaging.
    return try_activate_mode(MODE.LB_SHORT);
}
