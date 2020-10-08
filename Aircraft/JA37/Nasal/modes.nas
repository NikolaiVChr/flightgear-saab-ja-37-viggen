var FALSE = 0;
var TRUE = 1;


var input = {
    selector_ajs:   "/ja37/mode/selector-ajs",
    combat:         "/ja37/mode/combat",
    landing:        "/ja37/hud/landing-mode",
    approach:       "/ja37/avionics/approach",
    takeoff:        "/ja37/mode/takeoff",
    fpv_up:         "/instrumentation/fpv/angle-up-stab-deg",
    mach:           "/instrumentation/airspeed-indicator/indicated-mach",
    gear_pos:       "/gear/gear/position-norm",
    wow_nose:       "/fdm/jsbsim/gear/unit[0]/WOW",
    master_arm:     "/ja37/armament/master-arm",
    time_sec:       "/sim/time/elapsed-sec",
    rm_active:      "/autopilot/route-manager/active",
};

foreach (var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}


### Main modes

# Note: I would prefer if this 'main' mode was JA-only,
# with the mode selector serving a similar role for the AJS.
# The variables 'combat' 'takeoff' 'landing' can be used for shared systems.
# The main blocking point currently is the HUD.
var TAKEOFF = 0;
var NAV = 1;
var COMBAT = 2;
var LANDING = 3;

var main = TAKEOFF;


### These variables summarize common JA/AJS modes to support shared systems.
var combat = FALSE;
var takeoff = TRUE;
var landing = FALSE;
var displays = TRUE;



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
var update_mode_ja = func {
    # from manual:
    #
    # STARTMOD: always at wow0. Switch to other mode when FPI >3degs or gear retract or mach>0.35 (earliest 4s after wow0==0).
    # NAVMOD: Press B or L, or auto switch after STARTMOD.
    # LANDMOD: Press LT or LS on TI. (key 'Y' is same as LS)
    #

    if (main != TAKEOFF and input.wow_nose.getBoolValue()) {
        # nosewheel on runway, switch to takeoff
        main = TAKEOFF;
        input.landing.setValue(0);
    } elsif (main == TAKEOFF and !takeoff_allowed) {
        # time to switch away from TAKEOFF mode.
        main = NAV; # Can be changed to COMBAT or LANDING below.

        # If current waypoint is the starting base, select the next one.
        if (input.rm_active.getBoolValue()) {
            var fp = flightplan();
            if (fp.current == 0 and fp.getPlanSize() >= 2 and navigation.departure_set(fp)) {
                fp.current = 1;
            }
        }
    }

    if (main == COMBAT or main == NAV or main == LANDING) {
        if (input.landing.getBoolValue()) {
            main = LANDING;
        } else {
            main = (input.master_arm.getBoolValue() and input.gear_pos.getValue() == 0) ? COMBAT : NAV;
        }
    }

    combat = (main == COMBAT);
    takeoff = (main == TAKEOFF);
    landing = (main == LANDING);

    input.main.setValue(main);
    input.combat.setValue(combat);
    input.takeoff.setValue(takeoff);
};


# AJS

# Selector knob positions
var SELECTOR = {
    TEST: 0,
    STBY: 1,
    NAV: 2,
    COMBAT: 3,
    RECO: 4,
    LND_NAV: 5,
    LND_OPT: 6,
};

var selector_ajs = SELECTOR.STBY;

# This function handles submodes (i.e. anything that does not only depend on the selector position).
# The rest is done in the mode selector listener below.
var update_mode_ajs = func {
    # Update combat mode
    combat = (selector_ajs == SELECTOR.COMBAT) and input.gear_pos.getValue() == 0;

    # Update takeoff submode
    if (selector_ajs != SELECTOR.NAV) {
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

    input.combat.setValue(combat);
    input.takeoff.setValue(takeoff);

    # Update 'main' mode. A bit silly...
    if (takeoff) main = TAKEOFF;
    elsif (combat) main = COMBAT;
    elsif (landing) main = LANDING;
    else main = NAV;
};

var selector_callback = func (node) {
    selector_ajs = node.getValue();

    # Update landing mode
    if (selector_ajs == SELECTOR.LND_NAV) {
        input.landing.setBoolValue(TRUE);
        landing = TRUE;
    } elsif (selector_ajs == SELECTOR.LND_OPT) {
        input.landing.setBoolValue(TRUE);
        input.approach.setBoolValue(TRUE);
        landing = TRUE;
        land.OPT();
    } else {
        input.landing.setBoolValue(FALSE);
        input.approach.setBoolValue(FALSE);
        landing = FALSE;
    }

    # Displays disabled in STBY mode (and TEST mode, because it is not implemented).
    displays = (selector_ajs > SELECTOR.STBY);

    update_mode_ajs();
}
if (getprop("/ja37/systems/variant") != 0) setlistener(input.selector_ajs, selector_callback, 1, 0);


###  Main update function
var update_mode = getprop("/ja37/systems/variant") == 0 ? update_mode_ja : update_mode_ajs;

var update = func {
    update_takeoff_allowed();
    update_mode();
};
