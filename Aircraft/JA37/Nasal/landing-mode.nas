var FALSE = 0;
var TRUE = 1;


var input = utils.property_map({
    rmActive:           variant.AJS ? "instrumentation/waypoint-indicator/active" : "autopilot/route-manager/active",
    rmDist:             variant.AJS ? "instrumentation/waypoint-indicator/dist-km" : "autopilot/route-manager/wp/dist",
    rmBearing:          variant.AJS ? "instrumentation/waypoint-indicator/true-bearing-deg" : "autopilot/route-manager/wp/true-bearing-deg",
    rmCurrWaypoint:     "autopilot/route-manager/current-wp",
    nav0GSInRange:      "instrumentation/nav[0]/gs-in-range",
    nav0HasGS:          "instrumentation/nav[0]/has-gs",
    nav0InRange:        "instrumentation/nav[0]/in-range",
    rad_alt:            "instrumentation/radar-altimeter/radar-altitude-m",
    rad_alt_ready:      "instrumentation/radar-altimeter/ready",
    alt_aal:            "instrumentation/altimeter/indicated-altitude-aal-meter",
});


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

var runway_dist = 0;#NM

var approach_circle = nil;#Coord

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
    	show_waypoint_circle = FALSE;
    	show_approach_circle = FALSE;
    	me.bearing = 0;

        if (input.rmActive.getBoolValue()) {
            runway_dist = input.rmDist.getValue();
            if (variant.AJS) runway_dist *= 1000*M2NM;
            me.bearing = input.rmBearing.getValue();#true
        }
        me.alt             = input.alt_aal.getValue();
        me.alt_rad_enabled = input.rad_alt_ready.getBoolValue();
        me.alt_rad         = me.alt_rad_enabled ? input.rad_alt.getValue():100000;
        if (modes.landing and mode != 4 and ((me.alt < 35) or (me.alt_rad_enabled and me.alt<60 and me.alt_rad<15))) {
            printDA("OPT: auto activated");
            mode = 4;
        }
        if (navigation.has_wpt) {
        	if (navigation.has_rwy) {
                #showActiveSteer = FALSE;
        		me.short = getprop("ja37/avionics/approach");

        		line = me.short == TRUE?10:20;

        		# find approach circle
                me.runwayCoord = geo.Coord.new(navigation.rwy_coord);
                me.runwayCoord.apply_course_distance(geo.normdeg(navigation.rwy_heading+180), line*1000);

        		me.diff = me.bearing - navigation.rwy_heading;#positive for pos
        		me.diff = geo.normdeg180(me.diff);	
        		me.rect = (me.diff>0?90:-90);           
    			me.rectAngle = navigation.rwy_heading+180+me.rect;

        		me.runwayCoord.apply_course_distance(geo.normdeg(me.rectAngle), 4100);
        		me.distCenter = geo.aircraft_position().distance_to(me.runwayCoord);
        		approach_circle = me.runwayCoord;
                if (!modes.landing) {
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
                if (navigation.ils and modes.landing) {
                    setprop("instrumentation/nav[0]/frequencies/selected-mhz", navigation.ils);
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
                if (modes.landing) {
                    mode = 4;
                } else {
                    mode = 0;
                }
            }
        } else {
            # route-manager not active
            setprop("ja37/hud/TILS-on", FALSE);
            if (modes.landing) {
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
