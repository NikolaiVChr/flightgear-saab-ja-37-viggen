var FALSE = 0;
var TRUE = 1;


var input = {
    selector_ajs:   "/ja37/mode/selector-ajs",
    landing:        "/ja37/hud/landing-mode",
    approach:       "/ja37/avionics/approach",
    takeoff:        "/ja37/mode/takeoff",
    fpv_up:         "/instrumentation/fpv/angle-up-deg",
    mach:           "/instrumentation/airspeed-indicator/indicated-mach",
    gear_pos:       "/gear/gear/position-norm",
    wow_nose:       "/fdm/jsbsim/gear/unit[0]/WOW",
    time_sec:       "/sim/time/elapsed-sec",
    rm_active:      "/autopilot/route-manager/active",
};

foreach (var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}


### Main modes

if (getprop("/ja37/systems/variant") == 0) {
    # JA
    var TAKEOFF = 0;
    var NAV = 1;
    var AIMING = 2;
    var LANDING = 3;

    var main_ja = TAKEOFF;
} else {
    # AJS
    var TEST = 0;
    var STBY = 1;
    var NAV = 2;
    var COMBAT = 3;
    var RECO = 4;
    var LND_NAV = 5;
    var LND_OPT = 6;

    var selector_ajs = STBY;
}


### These variables summarize common JA/AJS modes to support shared systems.
var takeoff = TRUE;
var landing = FALSE;



### Takeoff mode selection (shared)

# Timer: 4 seconds after nose wheel liftoff
var takeoff_timer = {
    time: -1,
    reset: func { me.time = -1; },
    start: func { me.time = input.time_sec.getValue(); },
    started: func { return me.time != -1; },
    elapsed: func { return me.started() and input.time_sec.getValue() - me.time > 4; },
};

var takeoff_allowed = TRUE;

var update_takeoff_allowed = func {
    takeoff_allowed = (input.gear_pos.getValue() == 1
                       and (input.fpv_up.getValue() < 3 or input.mach.getValue() < 0.1) # rotated
                       and (input.mach.getValue() < 0.35 or !takeoff_timer.elapsed()));

    if (takeoff and !input.wow_nose.getBoolValue()) {
        if (!takeoff_timer.started()) takeoff_timer.start();
    } else {
        takeoff_timer.reset();
    }
};


### Mode update
# JA

# Some HUD functions are inhibited until 30s after leaving takeoff mode.
var takeoff_30s_inhibit = TRUE;
var takeoff_30s_timer = maketimer(30, func { takeoff_30s_inhibit = FALSE; });
takeoff_30s_timer.simulatedTime = TRUE;
takeoff_30s_timer.singleShot = TRUE;

var update_mode_ja = func {
    # from manual:
    #
    # STARTMOD: always at wow0. Switch to other mode when FPI >3degs or gear retract or mach>0.35 (earliest 4s after wow0==0).
    # NAVMOD: Press B or L, or auto switch after STARTMOD.
    # LANDMOD: Press LT or LS on TI. (key 'Y' is same as LS)
    #

    if (main_ja != TAKEOFF and input.wow_nose.getBoolValue()) {
        # nosewheel on runway, switch to takeoff
        main_ja = TAKEOFF;
        input.landing.setValue(0);

        takeoff_30s_timer.stop();
        takeoff_30s_inhibit = TRUE;
    } elsif (main_ja == TAKEOFF and !takeoff_allowed) {
        # time to switch away from TAKEOFF mode.
        main_ja = NAV; # Can be changed to LANDING below.

        # If current waypoint is the starting base, select the next one.
        if (input.rm_active.getBoolValue()) {
            var fp = flightplan();
            if (fp.current == 0 and fp.getPlanSize() >= 2 and navigation.departure_set(fp)) {
                fp.current = 1;
            }
        }

        # Start 30s timer before enabling some of the HUD functions.
        takeoff_30s_timer.start();
    }

    # Switch to/from LANDING mode
    if (input.landing.getBoolValue()) {
        main_ja = LANDING;
    } else {
        if (main_ja == LANDING) main_ja = NAV;
    }

    if (main_ja == AIMING and !fire_control.firing_enabled()) main_ja = NAV;

    takeoff = (main_ja == TAKEOFF);
    landing = (main_ja == LANDING);
    input.takeoff.setValue(takeoff);
};

var set_aiming_mode = func(aim) {
    if (aim) {
        if (main_ja == NAV and fire_control.firing_enabled()) main_ja = AIMING;
    } else {
        if (main_ja == AIMING) main_ja = NAV;
    }
};

var toggle_aiming_mode = func {
    set_aiming_mode(main_ja != AIMING);
};


# AJS

# This function handles submodes (i.e. anything that does not only depend on the selector position).
# The rest is done in the mode selector listener below.
var update_mode_ajs = func {
    # Update takeoff submode
    if (selector_ajs < NAV or selector_ajs > RECO) {
        takeoff = FALSE;
    } elsif (input.wow_nose.getBoolValue()) {
        takeoff = TRUE;
    } elsif (!takeoff_allowed) {
        # Takeoff complete
        takeoff = FALSE;
        # If current waypoint is the starting base, select the next one.
        if (input.rm_active.getBoolValue()) {
            var fp = flightplan();
            if (fp.current == 0 and fp.getPlanSize() >= 2 and navigation.departure_set(fp)) {
                fp.current = 1;
            }
        }
    }

    input.takeoff.setValue(takeoff);
};

var selector_callback = func (node) {
    selector_ajs = node.getValue();

    # Update landing mode
    if (selector_ajs == LND_NAV) {
        land.LND_NAV();
        landing = TRUE;
    } elsif (selector_ajs == LND_OPT) {
        land.LND_PO();
        landing = TRUE;
    } else {
        land.noMode();
        landing = FALSE;
    }

    update_mode_ajs();
}


###  Main update function
var update_mode = variant.JA ? update_mode_ja : update_mode_ajs;

var update = func {
    update_takeoff_allowed();
    update_mode();
};


var initialize = func {
    if (!variant.JA) {
        setlistener(input.selector_ajs, selector_callback, 1, 0);
    }
};

# Initialization when starting the simulator in the air.
var nav_init = func {
    if (variant.JA) {
        main_ja = NAV;
        takeoff_30s_inhibit = FALSE;
    } else {
        takeoff = FALSE;
    }
}

var landing_init = func {
    if (variant.JA) {
        takeoff_30s_inhibit = FALSE;
        main_ja = LANDING;
        land.LF();
    } else {
        takeoff = FALSE;
        landing = TRUE;
        land.LND_PO();
    }
}
