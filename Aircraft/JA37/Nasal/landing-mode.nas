var FALSE = 0;
var TRUE = 1;


input = {
	rmActive:             "autopilot/route-manager/active",
	rmDist:               "autopilot/route-manager/wp/dist",
	rmId:                 "autopilot/route-manager/wp/id",
	rmTrueBearing:        "autopilot/route-manager/wp/true-bearing-deg",
	rmCurrWaypoint:       "autopilot/route-manager/current-wp",
	heading:              "instrumentation/heading-indicator/indicated-heading-deg",
	headTrue:             "orientation/heading-deg",
    headMagn:             "orientation/heading-magnetic-deg",
    nav0GSInRange:    	  "instrumentation/nav[0]/gs-in-range",
    nav0HasGS:        	  "instrumentation/nav[0]/has-gs",
    nav0InRange:       	  "instrumentation/nav[0]/in-range",
    rad_alt:            "instrumentation/radar-altimeter/radar-altitude-ft",
    rad_alt_ready:      "instrumentation/radar-altimeter/ready",
    alt_ft:             "instrumentation/altimeter/indicated-altitude-ft",
};

# setup property nodes for the loop
foreach(var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
};

#
#-1 = off
# 0 = waypoint
# 1 = before touching tangent (500m commanded)
# 2 = till 10Km away from touchdown
# 3 = descent towards touchdown
# 4 = optical touchdown
#
var mode = 0;

# 
# 20 Km = normal
# 10 Km = short
#
var line = 20;

var show_waypoint_circle = FALSE;
var show_approach_circle = FALSE;
var show_runway_line     = FALSE;

var runway_bug  = 0;#true degs
var runway_dist = 0;#NM

var head = 0;#true degs

var approach_circle = nil;#Coord

var runway = "";
var icao = "";
var runway_rw = nil;
var showActiveSteer = FALSE;#if TI should show steerpoint
var ils = 0;

#
# -1: no plan started
#  0: plan running, steerpoint not active
#  1: plan running, next steerpoint is not runway
#  2: plan running, next steerpoint is runway
#
var has_waypoint = 0;

var mode_B_active = FALSE;
var mode_LA_active = FALSE;
var mode_L_active = FALSE;
var mode_LB_active = FALSE;
var mode_LF_active = FALSE;
var mode_OPT_active = FALSE;

var debugAll = FALSE;

var printDA = func (str) {
    if (debugAll) print (str);
}

var B = func {
    setprop("ja37/hud/landing-mode", FALSE);
    if (route.Polygon.flyMiss.isPrimary() == FALSE) {
        route.Polygon.flyMiss.setAsPrimary();
        printDA(route.Polygon.flyMiss.name~" set as primary.");
    }

    if (route.Polygon.isPrimaryActive() == FALSE and route.Polygon.primary.getSize() > 0) {
        printDA("B: activate");
        route.Polygon.startPrimary();
        mode_B_active = TRUE;
        mode_LA_active = FALSE;
        mode_L_active = FALSE;
        mode_LB_active = FALSE;
        mode_LF_active = FALSE;
        mode_OPT_active = FALSE;
        showActiveSteer = TRUE;
        mode = 0;
    } elsif (route.Polygon.isPrimaryActive() == FALSE) {
        printDA("B: empty, not activate");
        mode_B_active = FALSE;
        mode_LA_active = FALSE;
        mode_L_active = FALSE;
        mode_LB_active = FALSE;
        mode_LF_active = FALSE;
        mode_OPT_active = FALSE;
        showActiveSteer = TRUE;
        mode = -1;
    } elsif (mode_B_active == TRUE) {
        printDA("B: cycle");
        # next steerpoint
        route.Polygon.primary.cycle();
        mode_B_active = TRUE;
        mode_LA_active = FALSE;
        mode_L_active = FALSE;
        mode_LB_active = FALSE;
        mode_LF_active = FALSE;
        mode_OPT_active = FALSE;
        showActiveSteer = TRUE;
        mode = 0;
    } else {
        printDA("B: already activated, setting B");
        mode_B_active = TRUE;
        mode_LA_active = FALSE;
        mode_L_active = FALSE;
        mode_LB_active = FALSE;
        mode_LF_active = FALSE;
        mode_OPT_active = FALSE;
        showActiveSteer = TRUE;
        mode = 0;
    }
    radar_logic.disableSteerOrder();
};

var LA = func {
    setprop("ja37/hud/landing-mode", FALSE);
    if (route.Polygon.flyRTB.isPrimary() == FALSE) {
        route.Polygon.flyRTB.setAsPrimary();
        printDA(route.Polygon.flyRTB.name~" set as primary.");
    }

    if (route.Polygon.isPrimaryActive() == FALSE and route.Polygon.primary.getSize() > 0) {
        printDA("LA: activate");
        route.Polygon.startPrimary();
        mode_LA_active = TRUE;
        mode_B_active = FALSE;
        mode_L_active = FALSE;
        mode_LB_active = FALSE;
        mode_LF_active = FALSE;
        mode_OPT_active = FALSE;
        showActiveSteer = TRUE;
        mode = 0;
    } elsif (route.Polygon.isPrimaryActive() == FALSE) {
        printDA("LA: empty, not activate");
        mode_B_active = FALSE;
        mode_L_active = FALSE;
        mode_LB_active = FALSE;
        mode_LF_active = FALSE;
        mode_OPT_active = FALSE;
        mode_LA_active = FALSE;
        showActiveSteer = TRUE;
        mode = -1;
    } elsif (mode_LA_active == TRUE) {
        printDA("LA: cycle");
        # next steerpoint
        
        mode_LA_active = TRUE;
        mode_B_active = FALSE;
        mode_L_active = FALSE;
        mode_LB_active = FALSE;
        mode_LF_active = FALSE;
        mode_OPT_active = FALSE;
        showActiveSteer = TRUE;
        mode = 0;
        route.Polygon.primary.cycle();#delicate: this call might trigger a listener which will switch to L, so we do this last.
    } else {
        printDA("LA: already activated, setting LA");
        mode_LA_active = TRUE;
        mode_B_active = FALSE;
        mode_L_active = FALSE;
        mode_LB_active = FALSE;
        mode_LF_active = FALSE;
        mode_OPT_active = FALSE;
        showActiveSteer = TRUE;
        mode = 0;
    }
    radar_logic.disableSteerOrder();
};

var L = func {
    setprop("ja37/hud/landing-mode", FALSE);
    setprop("ja37/avionics/approach", FALSE);#long

    if (route.Polygon.isLandingBaseRunwayActive() == TRUE and mode_L_active == TRUE) {
        printDA("L: calling cycle runway");
        route.Polygon.primary.cycleDestinationRunway();
        mode_L_active = TRUE;
        mode_B_active = FALSE;
        mode = 0;
    } else {
        if (route.Polygon.activateLandingBase()) {
            printDA("L: base activated");
            mode_L_active = TRUE;
            mode_B_active = FALSE;
            mode = 0;
        } else {
            printDA("L: plan deactivated");
            route.Polygon.stopPrimary();
            mode_B_active = FALSE;
            mode_L_active = FALSE;
            mode = -1;
        }
    }
    mode_LA_active = FALSE;
    mode_LB_active = FALSE;
    mode_LF_active = FALSE;
    mode_OPT_active = FALSE;
    showActiveSteer = TRUE;
    radar_logic.disableSteerOrder();
};

var LB = func {
    setprop("ja37/hud/landing-mode", TRUE);
    setprop("ja37/avionics/approach", FALSE);#long
    mode_B_active = FALSE;
    mode_LA_active = FALSE;
    mode_L_active = FALSE;
    mode_LF_active = FALSE;
    mode_OPT_active = FALSE;
    showActiveSteer = FALSE;
    if (route.Polygon.activateLandingBase()) {
        printDA("LB: base activated");
        mode = 1;
        mode_LB_active = TRUE;
    } else {
        printDA("LB: plan deactivated");
        route.Polygon.stopPrimary();
        mode_LB_active = FALSE;
    }
    radar_logic.disableSteerOrder();
};

var LF = func {
    setprop("ja37/hud/landing-mode", TRUE);
    setprop("ja37/avionics/approach", TRUE);#short
    mode_B_active = FALSE;
    mode_LA_active = FALSE;
    mode_L_active = FALSE;
    mode_LB_active = FALSE;
    mode_OPT_active = FALSE;
    showActiveSteer = FALSE;
    if (route.Polygon.activateLandingBase()) {
        printDA("LF: base activated");
        mode = 2;
        mode_LF_active = TRUE;
    } else {
        printDA("LF: plan deactivated");
        route.Polygon.stopPrimary();
        mode_LF_active = FALSE;
    }
    radar_logic.disableSteerOrder();
};

var OPT = func {
    if (getprop("gear/gear/position-norm") > 0 or getprop("ja37/hud/landing-mode") == TRUE) {
        printDA("OPT: activated");
        mode = 4;
        mode_LA_active = FALSE;
        mode_B_active = FALSE;
        mode_L_active = FALSE;
        mode_LB_active = FALSE;
        mode_LF_active = FALSE;
        mode_OPT_active = TRUE;
        showActiveSteer = FALSE;
        radar_logic.disableSteerOrder();
    }
};

var RR = func {
    # radar steer order enabled
    noMode();
    route.Polygon.stopPrimary();
};

var noMode = func {
    setprop("ja37/hud/landing-mode", FALSE);
    setprop("ja37/avionics/approach", FALSE);#long
    mode = -1;
    mode_B_active = FALSE;
    mode_L_active = FALSE;
    mode_LB_active = FALSE;
    mode_LA_active = FALSE;
    mode_LF_active = FALSE;
    mode_OPT_active = FALSE;
    showActiveSteer = TRUE;
};

#
# tangent circle: 4100 m radius
#
# mode 1: (LB)
# if A/P mode 3 active then 500m is commanded only after that mode disengage
# 550 Km/h is ref. in hud fin with gear up
#
# mode 2: (LF)
# starts when distance to tangent point is less than 100m and increasing
# approach cicle goes away
#
# mode 3:
# starts when tils is captured
# stops and mode 2 if TILS is lost for more than 5 secs
#
# mode 4: (OPT)
# 2.8m/s sinkrate max for non flare landing.

var Landing = {
    new: func {
        var l = {parents: [Landing]};
        return l;
    },
    
    loop: func {
    	show_runway_line = FALSE;
    	show_waypoint_circle = FALSE;
    	show_approach_circle = FALSE;
    	runway = "";
        icao = "";
    	me.bearing = 0;
        has_waypoint = -1;
        runway_rw = nil;
        ils = 0;
    	if (route.Polygon.isPrimaryActive() == TRUE) {
            has_waypoint = 0;
            runway_dist = input.rmDist.getValue();        
            me.heading = input.heading.getValue();#true
            me.bearing = input.rmTrueBearing.getValue();#true
            if (runway_dist != nil and me.bearing != nil and me.heading != nil and route.Polygon.primary.getSteerpoint()[0] != nil) {
                has_waypoint = 1;
              	runway_bug = me.bearing - me.heading;
                me.wp = route.Polygon.primary.getSteerpoint();
                #print("current: "~ghosttype(wp[0]));
              	me.name = me.wp[0].id;
                if (route.Polygon.primary.type == route.TYPE_RTB or route.Polygon.primary.type == route.TYPE_MIX) {
                    if (ghosttype(me.wp[0]) == "airport") {
                        ils = 0;
                        icao   = me.wp[0].id;
                        #has_waypoint = 1;
                    }
                    if (ghosttype(me.wp[0]) == "runway") {
                        ils = 0;
                        icao   = me.wp[1].id;
                        runway = me.wp[0].id;
                        runway_rw = me.wp[0];
                        if (!radar_logic.steerOrder) {
                            me.mag_offset = getprop("/orientation/heading-magnetic-deg") - getprop("/orientation/heading-deg");
                            setprop("ja37/avionics/heading-indicator-target", geo.normdeg(getprop("orientation/heading-magnetic-deg")-(runway_rw.heading + me.mag_offset)));
                        }
                        if (getprop("ja37/hud/TILS") == TRUE and getprop("ja37/hud/landing-mode")==TRUE and runway_rw.ils != nil) {
                            ils = runway_rw.ils.frequency/100;
                        }
                        head = me.wp[0].heading;
                        has_waypoint = 2;
                    }
                }
            } elsif (runway_dist != nil and me.bearing != nil and me.heading != nil) {
                #print("failed ghost: "~ghosttype(route.Polygon.primary.getSteerpoint()[0]));
            }
        }
        if (has_waypoint != 2) {
            if (!radar_logic.steerOrder) {
                setprop("ja37/avionics/heading-indicator-target", getprop("orientation/heading-magnetic-deg"));
            }
        }
        me.alt             = input.alt_ft.getValue()*FT2M;
        me.alt_rad_enabled = input.rad_alt_ready.getBoolValue();
        me.alt_rad         = me.alt_rad_enabled ? input.rad_alt.getValue()*FT2M:100000;
        if (getprop("ja37/hud/landing-mode")==TRUE and mode_OPT_active==FALSE and ((me.alt < 35) or (me.alt_rad_enabled and me.alt>60 and me.alt_rad<15))) {
            printDA("OPT: auto activated");
            mode = 4;
            mode_LA_active = FALSE;
            mode_B_active = FALSE;
            mode_L_active = FALSE;
            mode_LB_active = FALSE;
            mode_LF_active = FALSE;
            mode_OPT_active = TRUE;
            showActiveSteer = FALSE;
            radar_logic.disableSteerOrder();
        } elsif (getprop("ja37/hud/landing-mode")==FALSE) {
            printDA("OPT: deactivated due to not in landing mode.");
            mode_OPT_active = FALSE;
        }
        if (has_waypoint > 0) {
        	if (has_waypoint > 1) {
                #showActiveSteer = FALSE;
        		show_runway_line = TRUE;
        		me.short = getprop("ja37/avionics/approach");

        		line = me.short == TRUE?10:20;

        		#me.ILS = input.nav0InRange.getValue() == TRUE and input.nav0HasGS.getValue() == TRUE and input.nav0GSInRange.getValue() == TRUE;

        		# find approach circle
        		me.curr = input.rmCurrWaypoint.getValue();

        		me.lat = getprop("autopilot/route-manager/route/wp["~me.curr~"]/latitude-deg");
        		me.lon = getprop("autopilot/route-manager/route/wp["~me.curr~"]/longitude-deg");
        		me.runwayCoord = geo.Coord.new();
        		me.runwayCoord.set_latlon(me.lat,me.lon, geo.aircraft_position().alt()-500);
        		me.runwayCoord.apply_course_distance(geo.normdeg(head+180), line*1000);

        		me.diff = me.bearing - head;#positive for pos
        		me.diff = geo.normdeg180(me.diff);	
        		me.rect = (me.diff>0?90:-90);           
    			me.rectAngle = head+180+me.rect;

        		me.runwayCoord.apply_course_distance(geo.normdeg(me.rectAngle), 4100);
        		me.distCenter = geo.aircraft_position().distance_to(me.runwayCoord);
        		approach_circle = me.runwayCoord;
                if (getprop("ja37/hud/landing-mode")==FALSE and mode_OPT_active==FALSE and mode_B_active == FALSE and mode_L_active == FALSE and mode_LB_active == FALSE and mode_LF_active == FALSE and mode_LA_active == FALSE) {
                    # seems route manager was activated through FG menu.
                    if (route.Polygon.primary == route.Polygon.flyMiss) {
                        mode_B_active = TRUE;
                    } else {
                        mode_LA_active = TRUE;
                    }
                    mode = 0;
                    printDA("menu activation");
                }
                if (mode_OPT_active==TRUE and getprop("ja37/hud/landing-mode")==TRUE) {
                    # mode OPT
                    mode = 4;
                    mode_B_active = FALSE;
                    mode_L_active = FALSE;
                    mode_LA_active = FALSE;
                    mode_LB_active = FALSE;
                    mode_LF_active = FALSE;
                    mode_OPT_active = TRUE;
                    showActiveSteer = FALSE;
                    show_waypoint_circle = TRUE;
                    printDA("OPT activate");
        		} elsif (((mode == 2 or mode == 3) and runway_dist*NM2M < 10000)) {# or ILS == TRUE test if glideslope/ILS or less than 10 Km
                    # switch to mode 3 (descent)
        			show_waypoint_circle = TRUE;
                    mode_B_active = FALSE;
                    mode_LA_active = FALSE;
                    mode_L_active = FALSE;
                    mode_LB_active = FALSE;
                    mode_LF_active = TRUE;
                    mode_OPT_active = FALSE;
                    showActiveSteer = FALSE;
        			mode = 3;
                    printDA("descent mode 3");
        		} elsif (mode == 1 and me.distCenter < (4100+100)) {#test inside/on approach circle
                    # touch approach circle, switch to mode 2
        			show_approach_circle = TRUE;
                    mode_B_active = FALSE;
                    mode_LA_active = FALSE;
                    mode_L_active = FALSE;
                    mode_LB_active = FALSE;
                    mode_LF_active = TRUE;
                    mode_OPT_active = FALSE;
                    showActiveSteer = FALSE;
                    printDA("on circle");
        			mode = 2;
        		} elsif (mode == 2 and me.distCenter < (4100+250)) {
                    # keep mode 2
        			show_approach_circle = TRUE;
                    mode_B_active = FALSE;
                    mode_LA_active = FALSE;
                    mode_L_active = FALSE;
                    mode_LB_active = FALSE;
                    mode_LF_active = TRUE;
                    mode_OPT_active = FALSE;
                    showActiveSteer = FALSE;
        			mode = 2;
                    printDA("keeping mode 2 with circle");
        		} elsif (mode == 2 and (runway_dist*NM2M > (line*1000+4100) or me.distCenter > 11000)) {
                    # we are far away in mode 2
                    show_approach_circle = TRUE;
                    mode_B_active = FALSE;
                    mode_LA_active = FALSE;
                    mode_L_active = FALSE;
                    if (me.short==TRUE)  {
                        mode_LB_active = FALSE;
                        mode_LF_active = TRUE;
                        showActiveSteer = FALSE;
                        mode = 2;
                        printDA("short mode 2");
                    } else {
                        mode_LB_active = TRUE;
                        mode_LF_active = FALSE;
                        showActiveSteer = TRUE;
                        mode = 1;
                        printDA("long mode 1");
                    }
                    mode_OPT_active = FALSE;
                } elsif (mode == 2 and runway_dist*NM2M < (line*1000+4100)) {
                    # we are close in mode 2
        			show_waypoint_circle = TRUE;
                    mode_B_active = FALSE;
                    mode_LA_active = FALSE;
                    mode_L_active = FALSE;
                    mode_LB_active = FALSE;
                    mode_LF_active = TRUE;
                    mode_OPT_active = FALSE;
                    showActiveSteer = FALSE;
        			mode = 2;
                    printDA("approach mode 2");
        		} elsif (getprop("ja37/hud/landing-mode")==TRUE and me.short == FALSE) {
                    # default for mode 1
        			mode = 1;
                    mode_B_active = FALSE;
                    mode_LA_active = FALSE;
                    mode_L_active = FALSE;
                    mode_LB_active = TRUE;
                    mode_LF_active = FALSE;
                    mode_OPT_active = FALSE;
                    showActiveSteer = FALSE;
        			show_approach_circle = TRUE;
                    printDA("default mode 1");
        		} else {
                    # 
                    mode = 0;
                    showActiveSteer = TRUE;
                    show_waypoint_circle = TRUE;
                    printDA("steer active");
                }
                if (ils != 0 and getprop("ja37/hud/landing-mode")==TRUE and getprop("ja37/hud/TILS") == TRUE) {
                    setprop("instrumentation/nav[0]/frequencies/selected-mhz", ils);
                    if (mode > 1) {
                        setprop("ja37/hud/TILS-on", TRUE);
                    } else {
                        setprop("ja37/hud/TILS-on", FALSE);
                    }
                } else {
                    setprop("ja37/hud/TILS-on", FALSE);
                }
    		} else {
                # Following waypoint
                setprop("ja37/hud/TILS-on", FALSE);
    			show_waypoint_circle = TRUE;
                showActiveSteer = TRUE;
                mode_LB_active = FALSE;
                mode_LF_active = FALSE;
                if (mode_OPT_active == TRUE) {
                    mode = 4;
                    mode_B_active = FALSE;
                    mode_L_active = FALSE;
                    mode_LA_active = FALSE;
                    printDA("mode 4");
                } else {
                    mode = 0;
                    if (route.Polygon.primary.type == route.TYPE_MISS) {
                        mode_B_active = TRUE;
                        mode_L_active = FALSE;
                        mode_LA_active = FALSE;
                    } elsif (route.Polygon.primary.type == route.TYPE_RTB and mode_L_active == FALSE) {
                        mode_B_active = FALSE;
                        mode_LA_active = TRUE;
                    }
                    printDA("something something mode 0");
                }
    		}
        } else {
            # route-manager not active
            setprop("ja37/hud/TILS-on", FALSE);
            showActiveSteer = TRUE;
            mode_B_active = FALSE;
            mode_L_active = FALSE;
            mode_LA_active = FALSE;
            mode_LB_active = FALSE;
            mode_LF_active = FALSE;
            if (mode_OPT_active == TRUE) {
                mode = 4;
                printDA("last mode 0");
            } else {
                mode = -1;
                printDA("last mode -1");
            }
        }
        #settimer(func me.loop(), 0.25);
    },
};

var land_start = func {
    removelistener(lsnr);
    lander.loop();
};
var lander = Landing.new();
#var lsnr = setlistener("ja37/supported/initialized", land_start);

var window = screen.window.new(nil, 325, 2, 10);
#window.fg = [1, 1, 1, 1];
window.align = "left";

var askTower = func () {
    var runway_alt = nil;
    if (runway_rw != nil) {
        var lat = runway_rw.lat;
        var lon = runway_rw.lon;
        runway_alt = geo.elevation(lat, lon);
    }
    if (icao != "" and runway != "" and runway_alt != nil) {
        window.write(icao~" tower; how is the weather at "~runway~"?", 0.0, 1.0, 0.0);
        
        var pressure = getprop("environment/pressure-inhg");
        var qnh = getprop("environment/pressure-sea-level-inhg");
        var lvl  = getprop("position/altitude-ft");
        var rlvl = runway_alt * M2FT;
        var qfe = extrapolate(rlvl, 0, lvl, qnh, pressure);
        var qfe2 = qfe * 33.863887;
        var ilsFreq = " No ILS.";

        if (runway_rw != nil) {
            var runway_ils = nil;
            var vec = findNavaidsWithinRange(runway_rw, 10, "ils");
            if (vec != nil and size(vec) > 0) {
                runway_ils = vec[0];
            } else {
                runway_ils = nil;
            }
            if (runway_ils != nil) {
                ilsFreq = " ILS is "~roundFreq(runway_ils.frequency)~" MHz.";
            }
        }
        window.write(sprintf("Saab 37; QFE at runway %s is %.2f inHg or %4d hPa. %s", runway, qfe, qfe2, ilsFreq), 0.0, 0.6, 0.6);
    } else {
        window.write("To ask tower you must have a airport and runway active in route-manager, and fly near the tower!", 1.0, 0.0, 0.0);
    }
};

var extrapolate = func (x, x1, x2, y1, y2) {
    return y1 + ((x - x1) / (x2 - x1)) * (y2 - y1);
};

var roundFreq = func(x) {
  var y = ""~x;
  var a = substr(y, 0, 3)~"."~substr(y, -2);
  return a;
};
