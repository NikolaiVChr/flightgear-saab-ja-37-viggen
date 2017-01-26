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

var last_runway = "";
var last_icao = "";
var icao = "";

var has_waypoint = 0;

#
# tangent circle: 4100 m radius
#
# mode 1:
# if A/P mode 3 active then 500m is commanded only after that mode disengage
# 550 Km/h is ref. in hud fin with gear up
#
# mode 2:
# starts when distance to tangent point is less than 100m and increasing
# appoach cicle goes away
#
# mode 3:
# starts when tils is captured
# stops and mode 2 if TILS is lost for more than 5 secs
#
# mode 4:
# 2.8m/s sinkrate max for non flare landing.

var landing_loop = func {

	show_runway_line = FALSE;
	show_waypoint_circle = FALSE;
	show_approach_circle = FALSE;
	
	var bearing = 0;
	if (input.rmActive.getValue() == TRUE) {
        runway_dist = input.rmDist.getValue();        
        var heading = input.heading.getValue();#true
        bearing = input.rmTrueBearing.getValue();#true
        if (runway_dist != nil and bearing != nil and heading != nil) {
          	runway_bug = bearing - heading;
          	var name = input.rmId.getValue();
          	if (name != nil and size(split("-", name))>1) {
	            #print(name~"="~dist~" "~me.strokeHeight~" "~(me.radarRange * M2NM));
	            name = split("-", name);
	            icao = name[0];
	            var runway = name[1];
                if (icao != last_icao or runway != last_runway) {
                    var hd = -1000;
                    var info = airportinfo(icao);
                    if (info != nil) {
                        var rw = info.runways[runway];
                        if (rw != nil) {
                            hd = rw.heading;
                        }
                    }
                    if (hd == -1000) {
        	            var number = split("C", split("L", split("R", runway)[0])[0])[0];
        	            number = num(number);
        	            if (number != nil and size(icao) >= 3 and size(icao) < 5) {
        					head = 10 * number;#magnetic
        					var magDiff = input.headTrue.getValue() - input.headMagn.getValue();
        					head += magDiff;#true
        					has_waypoint = 2;
        				} else {
                            has_waypoint = 1;
                        }
                    } else {
                        head = hd;
                        has_waypoint = 2;
                    }
                    last_runway = runway;
                }
	        } else {
                has_waypoint = 1;
            }
	    } else {
            has_waypoint = 0;
        }
    } else {
        has_waypoint = 0;
    }
    if (icao != last_icao) {
    	mode = -1;
    	last_icao = icao;
    }
    if (has_waypoint > 0) {
    	if (has_waypoint > 1) {
    		show_runway_line = TRUE;
    		var highAlpha = getprop("ja37/avionics/high-alpha");

    		line = highAlpha==TRUE?10:20;

    		var ILS = input.nav0InRange.getValue() == TRUE and input.nav0HasGS.getValue() == TRUE and input.nav0GSInRange.getValue() == TRUE;

    		# find approach circle
    		var curr = input.rmCurrWaypoint.getValue();

    		var lat = getprop("autopilot/route-manager/route/wp["~curr~"]/latitude-deg");
    		var lon = getprop("autopilot/route-manager/route/wp["~curr~"]/longitude-deg");
    		var runway = geo.Coord.new();
    		runway.set_latlon(lat,lon, geo.aircraft_position().alt()-500);
    		runway.apply_course_distance(geo.normdeg(head+180), line*1000);

    		var diff = bearing - head;#positive for pos
    		diff = geo.normdeg180(diff);	
    		var rect = (diff>0?90:-90);           #setprop("AA-rect", rect);
			var rectAngle = head+180+rect;

    		runway.apply_course_distance(geo.normdeg(rectAngle), 4100);
    		var distCenter = geo.aircraft_position().distance_to(runway);
    		approach_circle = runway;

    		if (((mode == 2 or mode == 3) and runway_dist*NM2M < 10000) or ILS == TRUE) {#test if glideslope/ILS or less than 10 Km
    			show_waypoint_circle = TRUE;
    			mode = 3;
    		} elsif (mode == 1 and distCenter < (4100+100)) {#test inside/on approach circle
    			show_approach_circle = TRUE;
    			mode = 2;
    		} elsif (mode == 2 and distCenter < (4100+250)) {
    			show_approach_circle = TRUE;
    			mode = 2;
    		} elsif (mode == 2 and runway_dist*NM2M < (line*2000)) {
    			show_waypoint_circle = TRUE;
    			mode = 2;
    		} else {
    			mode = 1;
    			show_approach_circle = TRUE;
    		}
		} else {
			show_waypoint_circle = TRUE;
			mode = 0;
		}    	
    } else {
    	mode = -1;
    }
    #setprop("AA-mode", mode);
    #setprop("AA-line", line);
    settimer(landing_loop, 0.05);
}

landing_loop();