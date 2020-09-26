var FALSE = 0;
var TRUE = 1;


var input = {
    main:       "/ja37/mode/main",
    fpv_up:     "/instrumentation/fpv/angle-up-stab-deg",
    mach:       "/instrumentation/airspeed-indicator/indicated-mach",
    gear_pos:   "/gear/gear/position-norm",
    wow_nose:   "/fdm/jsbsim/gear/unit[0]/WOW",
    time_sec:   "/sim/time/elapsed-sec",
    landingMode:    "/ja37/hud/landing-mode",
};

foreach (var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}


# Main mode
var TAKEOFF = 0;
var NAV = 1;
var COMBAT = 2;
var LANDING = 3;

var main = TAKEOFF;


# Master arm
var master_arm = FALSE;

var toggle_master_arm = func {
    master_arm = !master_arm;
    setprop("/ja37/hud/combat", master_arm);
};


# Timer: 4 seconds after nose wheel liftoff
var takeoff_time = {
    time: -1,
    reset: func { me.time = -1; },
    start: func { me.time = input.time_sec.getValue(); },
    started: func { return me.time != -1; },
    elapsed: func { return me.started() and input.time_sec.getValue() - me.time > 4; },
};

var update_main_mode = func {
    # from manual:
    #
    # STARTMOD: always at wow0. Switch to other mode when FPI >3degs or gear retract or mach>0.35 (earliest 4s after wow0==0).
    # NAVMOD: Press B or L, or auto switch after STARTMOD.
    # LANDMOD: Press LT or LS on TI. (key 'Y' is same as LS)
    #
    var takeoffForbidden = (input.gear_pos.getValue() != 1
                            or (input.mach.getValue() > 0.1 and input.fpv_up.getValue() > 3) # rotated
                            or (input.mach.getValue() > 0.35 and takeoff_time.elapsed()));

    if (main != TAKEOFF and !takeoffForbidden and input.wow_nose.getBoolValue()) {
        # nosewheel on runway, switch to takeoff
        main = TAKEOFF;
        input.landingMode.setValue(0);
    } elsif (main == TAKEOFF and !input.wow_nose.getBoolValue() and !takeoff_time.started()) {
        # Nosewheel lifted off, so we start the 4 second counter
        takeoff_time.start();
    } elsif (main == TAKEOFF and takeoffForbidden) {
        # time to switch away from TAKEOFF mode.
        if (input.landingMode.getBoolValue()) {
            main = LANDING;
        } else {
            main = (master_arm and input.gear_pos.getValue() == 0) ? COMBAT : NAV;
        }
        takeoff_time.reset();
    } elsif (main == COMBAT or main == NAV or main == LANDING) {
        if (input.landingMode.getBoolValue()) {
            main = LANDING;
        } else {
            main = (master_arm and input.gear_pos.getValue() == 0) ? COMBAT : NAV;
        }
    }
    input.main.setValue(main);
};



var update_modes = func {
    update_main_mode();
};
