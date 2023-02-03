var FALSE = 0;
var TRUE = 1;


var input = {
    selector_ajs:   "/ja37/mode/selector-ajs",
    landing:        "/ja37/hud/landing-mode",
    approach:       "/ja37/avionics/approach",
    takeoff:        "/ja37/mode/takeoff",
    fpv_pitch:      "/instrumentation/fpv/pitch-deg",
    mach:           "/instrumentation/airspeed-indicator/indicated-mach",
    gear_pos:       "/gear/gear/position-norm",
    wow_nose:       "/fdm/jsbsim/gear/unit[0]/WOW",
    time_sec:       "/sim/time/elapsed-sec",
    rm_active:      "/autopilot/route-manager/active",
};

foreach (var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}


## Main modes

var TEST = 0;
var STBY = 1;
var NAV = 2;
var COMBAT = 3;
var RECO = 4;
var LND_NAV = 5;
var LND_OPT = 6;

var selector_ajs = STBY;


# Variables shared with JA for shared systems
var takeoff = TRUE;
var landing = FALSE;


## Takeoff mode selection (shared with JA)

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
                       and (input.fpv_pitch.getValue() < 3 or input.mach.getValue() < 0.1) # rotated
                       and (input.mach.getValue() < 0.35 or !takeoff_timer.elapsed()));

    if (takeoff and !input.wow_nose.getBoolValue()) {
        if (!takeoff_timer.started()) takeoff_timer.start();
    } else {
        takeoff_timer.reset();
    }
};


## Mode update

# This function handles submodes (i.e. anything that does not only depend on the selector position).
# The rest is done in the mode selector listener below.
var update_mode = func {
    # Update takeoff submode
    if (selector_ajs < NAV or selector_ajs > RECO) {
        takeoff = FALSE;
    } elsif (input.wow_nose.getBoolValue()) {
        takeoff = TRUE;
    } elsif (takeoff and !takeoff_allowed) {
        # Takeoff complete
        takeoff = FALSE;
        route.callback_takeoff();
    }
    input.takeoff.setValue(takeoff);
};

var selector_callback = func (node) {
    selector_ajs = node.getValue();

    # Update landing mode
    if (selector_ajs == LND_NAV) {
        landing = TRUE;
        land.mode = input.approach.getBoolValue() ? 2 : 1;
    } elsif (selector_ajs == LND_OPT) {
        landing = TRUE;
        input.approach.setBoolValue(TRUE);
        land.mode = 4;
    } else {
        landing = FALSE;
        input.approach.setBoolValue(FALSE);
    }
    input.landing.setBoolValue(landing);

    update_mode();
}


var update = func {
    update_takeoff_allowed();
    update_mode();
};

var initialize = func {
    setlistener(input.selector_ajs, selector_callback, 1, 0);
};


## Initialization when starting the simulator in the air.
var nav_init = func {
    takeoff = FALSE;
}

var landing_init = func {
    takeoff = FALSE;
    landing = TRUE;
    input.approach.setBoolValue(TRUE);
    land.mode = 4;
}
