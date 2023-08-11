var FALSE = 0;
var TRUE = 1;


var input = utils.property_map({
    landing:        "/ja37/mode/landing",
    approach:       "/ja37/avionics/approach",
    takeoff:        "/ja37/mode/takeoff",
    fpv_pitch:      "/instrumentation/fpv/pitch-deg",
    mach:           "/instrumentation/airspeed-indicator/indicated-mach",
    gear_pos:       "/gear/gear/position-norm",
    wow_nose:       "/fdm/jsbsim/gear/unit[0]/WOW",
    time_sec:       "/sim/time/elapsed-sec",
    rm_active:      "/autopilot/route-manager/active",
    ground_warning: "/fdm/jsbsim/systems/mkv/ja-warning",
});


var debugAll = FALSE;
var printDA = func (str) {
    if (debugAll) logprint(LOG_INFO, str);
}

## Main modes

var TAKEOFF = 0;
var NAV = 1;
var AIMING = 2;
var LANDING = 3;

var main_ja = TAKEOFF;

## Navigation modes
var NONE = 0;
var B = 1;
var LA = 2;
var L = 3;
var LB = 4;
var LF = 5;
var OPT = 6;

var nav_ja = B;

var TI_show_wp = FALSE;


# Variables shared with AJS for shared systems
var takeoff = TRUE;
var landing = FALSE;


## Takeoff mode selection (shared with AJS)

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

# Some HUD functions are inhibited until 30s after leaving takeoff mode.
var takeoff_30s_inhibit = TRUE;
var takeoff_30s_timer = maketimer(30, func { takeoff_30s_inhibit = FALSE; });
takeoff_30s_timer.simulatedTime = TRUE;
takeoff_30s_timer.singleShot = TRUE;

var update_mode = func {
    # from manual:
    #
    # STARTMOD: always at wow0. Switch to other mode when FPI >3degs or gear retract or mach>0.35 (earliest 4s after wow0==0).
    # NAVMOD: Press B or L, or auto switch after STARTMOD.
    # LANDMOD: Press LT or LS on TI. (key 'Y' is same as LS)
    #

    if (main_ja != TAKEOFF and input.wow_nose.getBoolValue()) {
        # nosewheel on runway, switch to takeoff
        main_ja = TAKEOFF;
        landing = FALSE;

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

    # 'landing' flag may be switched by the TI buttons. Check it.
    if (landing) {
        main_ja = LANDING;
    } else {
        if (main_ja == LANDING) main_ja = NAV;
    }

    if (main_ja == AIMING and (input.gear_pos.getValue() > 0 or input.ground_warning.getBoolValue()))
        main_ja = NAV;

    # Update landing/takeoff flags to match actual mode.
    takeoff = (main_ja == TAKEOFF);
    landing = (main_ja == LANDING);
    input.takeoff.setValue(takeoff);
    input.landing.setValue(landing);
};

var toggle_aiming_mode = func {
    if (main_ja == AIMING) {
        main_ja = NAV;
    } elsif (main_ja == NAV and input.gear_pos.getValue() == 0) {
        main_ja = AIMING;
    } elsif (main_ja == LANDING or main_ja == NAV) {
        # Optical landing mode
        buttons.OPT();
    }
};


## Nav mode update

var update_nav = func {
    # Landing: reflect landing submode
    if (landing) {
        if (land.mode <= 0)     landing = FALSE;
        elsif (land.mode == 1)  nav_ja = LB;
        elsif (land.mode == 4)  nav_ja = OPT;
        else                    nav_ja = LF;
    }

    # Not landing: reflect selected route
    if (!landing) {
        if (!input.rm_active.getBoolValue()) {
            nav_ja = NONE;
        } elsif (route.Polygon.primary.type == route.TYPE_MISS) {
            nav_ja = B;
        } elsif (route.Polygon.primary.type == route.TYPE_RTB and nav_ja != L) {
            nav_ja = LA;
        }
    }

    TI_show_wp = !landing;
}


## TI buttons

var buttons = {
    B: func {
        landing = FALSE;
        if (!route.Polygon.flyMiss.isPrimary()) {
            route.Polygon.flyMiss.setAsPrimary();
            printDA(route.Polygon.flyMiss.name~" set as primary.");
        }

        if (!route.Polygon.isPrimaryActive()) {
            if (route.Polygon.primary.getSize() > 0) {
                printDA("B: activate");
                route.Polygon.startPrimary();
                nav_ja = B;
            } else {
                printDA("B: empty, not activate");
                nav_ja = NONE;
            }
        } elsif (nav_ja == B) {
            printDA("B: cycle");
            route.Polygon.primary.cycle();
        } else {
            printDA("B: already activated, setting B");
            nav_ja = B;
        }
        TI_show_wp = TRUE;
        displays.common.unsetTISelection();
    },

    LA: func {
        landing = FALSE;
        if (!route.Polygon.flyRTB.isPrimary()) {
            route.Polygon.flyRTB.setAsPrimary();
            printDA(route.Polygon.flyRTB.name~" set as primary.");
        }

        if (!route.Polygon.isPrimaryActive()) {
            if (route.Polygon.primary.getSize() > 0) {
                printDA("LA: activate");
                route.Polygon.startPrimary();
                nav_ja = LA;
            } else {
                printDA("LA: empty, not activate");
                nav_ja = NONE;
            }
        } elsif (nav_ja == LA) {
            printDA("LA: cycle");
            route.Polygon.primary.cycle();
        } else {
            printDA("LA: already activated, setting LA");
            nav_ja = LA;
        }
        TI_show_wp = TRUE;
        displays.common.unsetTISelection();
    },

    L: func {
        landing = FALSE;
        input.approach.setBoolValue(FALSE); # long approach

        if (route.Polygon.isLandingBaseRunwayActive() and nav_ja == L) {
            printDA("L: calling cycle runway");
            route.Polygon.primary.cycleDestinationRunway();
        } else {
            if (route.Polygon.activateLandingBase()) {
                printDA("L: base activated");
                nav_ja = L;
            } else {
                printDA("L: plan deactivated");
                route.Polygon.stopPrimary();
                nav_ja = NONE;
            }
        }
        TI_show_wp = TRUE;
        displays.common.unsetTISelection();
    },

    LB: func {
        landing = TRUE;
        input.approach.setBoolValue(FALSE); # long approach

        if (route.Polygon.activateLandingBase()) {
            printDA("LB: base activated");
            nav_ja = LB;
            land.mode = 1;
        } else {
            printDA("LB: plan deactivated");
            route.Polygon.stopPrimary();
            buttons.OPT();
        }
        TI_show_wp = FALSE;
        displays.common.unsetTISelection();
    },

    LF: func {
        landing = TRUE;
        input.approach.setBoolValue(TRUE); # short approach

        if (route.Polygon.activateLandingBase()) {
            printDA("LF: base activated");
            nav_ja = LF;
            land.mode = 2;
        } else {
            printDA("LF: plan deactivated");
            route.Polygon.stopPrimary();
            buttons.OPT();
        }
        TI_show_wp = FALSE;
        displays.common.unsetTISelection();
    },

    OPT: func {
        landing = TRUE;
        printDA("OPT: activated");
        nav_ja = OPT;
        land.mode = 4;
        TI_show_wp = FALSE;
        displays.common.unsetTISelection();
    },

    RR: func {
        landing = FALSE;
        route.Polygon.stopPrimary();
        nav_ja = NONE;
        TI_show_wp = TRUE;
    },
};


var update = func {
    update_takeoff_allowed();
    update_mode();
    update_nav();
}


var initialize = func {};


## Initialization when starting the simulator in the air.
var nav_init = func {
    main_ja = NAV;
    takeoff_30s_inhibit = FALSE;
}

var landing_init = func {
    takeoff_30s_inhibit = FALSE;
    main_ja = LANDING;
    buttons.LF();
}
