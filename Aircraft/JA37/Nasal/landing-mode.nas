var FALSE = 0;
var TRUE = 1;


input = {
	rmActive:             "autopilot/route-manager/active",
	rmDist:               "autopilot/route-manager/wp/dist",
	rmBearing:        "autopilot/route-manager/wp/true-bearing-deg",
	rmCurrWaypoint:       "autopilot/route-manager/current-wp",
    nav0GSInRange:    	  "instrumentation/nav[0]/gs-in-range",
    nav0HasGS:        	  "instrumentation/nav[0]/has-gs",
    nav0InRange:       	  "instrumentation/nav[0]/in-range",
    rad_alt:            "instrumentation/radar-altimeter/radar-altitude-m",
    rad_alt_ready:      "instrumentation/radar-altimeter/ready",
    alt_aal:            "instrumentation/altimeter/indicated-altitude-aal-meter",
};

if (variant.AJS) {
    input.rmActive =    "instrumentation/waypoint-indicator/active";
    input.rmDist =      "instrumentation/waypoint-indicator/dist-km";
    input.rmBearing =   "instrumentation/waypoint-indicator/true-bearing-deg";
}

# setup property nodes for the loop
foreach(var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
};

#
# 0 = off
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

var runway_dist = 0;#NM

var head = 0;#true degs

var approach_circle = nil;#Coord

var runway = "";
var icao = "";
var runway_rw = nil;
var runway_coord = nil;
var ils = 0;

#
# -1: no plan started
#  0: plan running, steerpoint not active
#  1: plan running, next steerpoint is not runway
#  2: plan running, next steerpoint is runway
#
var has_waypoint = 0;

var debugAll = FALSE;

var printDA = func (str) {
    if (debugAll) logprint(LOG_INFO, str);
}

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
        runway_coord = nil;
        ils = 0;

        if (input.rmActive.getBoolValue()) {
            has_waypoint = 0;
            runway_dist = input.rmDist.getValue();
            if (variant.AJS) runway_dist *= 1000*M2NM;
            me.bearing = input.rmBearing.getValue();#true

            if (variant.JA)
            {
                me.wp = route.Polygon.primary.getSteerpoint();
                if (runway_dist != nil and me.bearing != nil and me.wp[0] != nil) {
                    has_waypoint = 1;
                    #print("current: "~ghosttype(wp[0]));
                    if (route.Polygon.primary.type == route.TYPE_RTB) {
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
                            if (getprop("ja37/hud/landing-mode")==TRUE and runway_rw.ils != nil) {
                                ils = runway_rw.ils.frequency/100;
                            }
                            head = me.wp[0].heading;
                            has_waypoint = 2;
                        }
                    }
                }
            }
            else
            {
                var idx = route.get_current_idx();
                me.wp = route.get_current_wpt();

                if (runway_dist != nil and me.bearing != nil and me.wp != nil) {
                    has_waypoint = 1;
                    if ((idx & route.WPT.type_mask) == route.WPT.L) {
                        icao = route.as_airbase(me.wp).name;
                        if (me.wp.type == route.TYPE.RUNWAY) {
                            has_waypoint = 2;
                            runway = me.wp.name;
                            runway_coord = me.wp.coord;
                            head = me.wp.heading;
                            if (getprop("ja37/hud/landing-mode")==TRUE and me.wp.freq != nil) {
                                ils = me.wp.freq;
                            }
                        }
                    }
                }
            }

        }
        me.alt             = input.alt_aal.getValue();
        me.alt_rad_enabled = input.rad_alt_ready.getBoolValue();
        me.alt_rad         = me.alt_rad_enabled ? input.rad_alt.getValue():100000;
        if (getprop("ja37/hud/landing-mode")==TRUE and mode != 4 and ((me.alt < 35) or (me.alt_rad_enabled and me.alt<60 and me.alt_rad<15))) {
            printDA("OPT: auto activated");
            mode = 4;
        }
        if (has_waypoint > 0) {
        	if (has_waypoint > 1) {
                #showActiveSteer = FALSE;
        		show_runway_line = TRUE;
        		me.short = getprop("ja37/avionics/approach");

        		line = me.short == TRUE?10:20;

        		#me.ILS = input.nav0InRange.getValue() == TRUE and input.nav0HasGS.getValue() == TRUE and input.nav0GSInRange.getValue() == TRUE;

        		# find approach circle
                if (variant.JA) {
                    me.curr = input.rmCurrWaypoint.getValue();

                    me.lat = getprop("autopilot/route-manager/route/wp["~me.curr~"]/latitude-deg");
                    me.lon = getprop("autopilot/route-manager/route/wp["~me.curr~"]/longitude-deg");
                    me.runwayCoord = geo.Coord.new();
                    me.runwayCoord.set_latlon(me.lat,me.lon, geo.aircraft_position().alt()-500);
                } else {
                    me.runwayCoord = geo.Coord.new(runway_coord);
                }

                me.runwayCoord.apply_course_distance(geo.normdeg(head+180), line*1000);

        		me.diff = me.bearing - head;#positive for pos
        		me.diff = geo.normdeg180(me.diff);	
        		me.rect = (me.diff>0?90:-90);           
    			me.rectAngle = head+180+me.rect;

        		me.runwayCoord.apply_course_distance(geo.normdeg(me.rectAngle), 4100);
        		me.distCenter = geo.aircraft_position().distance_to(me.runwayCoord);
        		approach_circle = me.runwayCoord;
                if (getprop("ja37/hud/landing-mode")==FALSE) {
                    mode = 0;
                    show_waypoint_circle = TRUE;
                } elsif (mode == 4) {
                    show_waypoint_circle = TRUE;
                    printDA("OPT activate");
                } elsif ((mode == 2 or mode == 3) and runway_dist*NM2M < 10000) {# or ILS == TRUE test if glideslope/ILS or less than 10 Km
                    mode = 3;
                    show_waypoint_circle = TRUE;
                    printDA("descent mode 3");
                } elsif (mode == 1 and me.distCenter < (4100+100)) {#test inside/on approach circle
                    # touch approach circle, switch to mode 2
                    mode = 2;
                    show_approach_circle = TRUE;
                    printDA("on circle");
                } elsif (mode == 2 and me.distCenter < (4100+250)) {
                    # keep mode 2
                    show_approach_circle = TRUE;
                    printDA("keeping mode 2 with circle");
                } elsif (mode == 2 and (runway_dist*NM2M > (line*1000+4100) or me.distCenter > 11000)) {
                    # we are far away in mode 2
                    show_approach_circle = TRUE;
                    if (me.short==TRUE)  {
                        mode = 2;
                        printDA("short mode 2");
                    } else {
                        mode = 1;
                        printDA("long mode 1");
                    }
                } elsif (mode == 2 and runway_dist*NM2M < (line*1000+4100)) {
                    # we are close in mode 2
                    show_waypoint_circle = TRUE;
                    printDA("approach mode 2");
                } elsif (me.short == FALSE) {
                    # default for mode 1
                    mode = 1;
                    show_approach_circle = TRUE;
                    printDA("default mode 1");
                }
                if (ils != 0 and getprop("ja37/hud/landing-mode")==TRUE) {
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
                if (getprop("ja37/hud/landing-mode")) {
                    mode = 4;
                } else {
                    mode = 0;
                }
            }
        } else {
            # route-manager not active
            setprop("ja37/hud/TILS-on", FALSE);
            if (getprop("ja37/hud/landing-mode")) {
                mode = 4;
            } else {
                mode = 0;
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
        runway_alt = geo.elevation(runway_rw.lat, runway_rw.lon);
    } elsif (runway_coord != nil) {
        runway_alt = geo.elevation(runway_coord.lat(), runway_coord.lon());
    }
    if (icao != "" and runway != "" and runway_alt != nil) {
        window.write(icao~" tower; how is the weather at "~runway~"?", 0.0, 1.0, 0.0);
        
        var pressure = getprop("environment/pressure-inhg");
        var qnh = getprop("environment/pressure-sea-level-inhg");
        var lvl  = getprop("position/altitude-ft");
        var rlvl = runway_alt * M2FT;
        var qfe = extrapolate(rlvl, 0, lvl, qnh, pressure);
        var qfe2 = qfe * 33.863887;
        window.write(sprintf("Saab 37; QFE at runway %s is %.2f inHg or %4d hPa.", runway, qfe, qfe2), 0.0, 0.6, 0.6);
    } else {
        window.write("To ask tower you must have a airport and runway active in route-manager, and fly near the tower!", 1.0, 0.0, 0.0);
    }
};

var extrapolate = func (x, x1, x2, y1, y2) {
    return y1 + ((x - x1) / (x2 - x1)) * (y2 - y1);
};

var roundFreq = func(x) {
  var y = str(x);
  var a = substr(y, 0, 3)~"."~substr(y, -2);
  return a;
};
