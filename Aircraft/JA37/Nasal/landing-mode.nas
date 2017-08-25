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
    ctrlRadar:            "controls/altimeter-radar",
    rad_alt:              "position/altitude-agl-ft",
    alt_ft:               "instrumentation/altimeter/indicated-altitude-ft",
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
var last_runway = "";
var last_icao = "";
var icao = "";
var runway_rw = nil;
var showActiveSteer = FALSE;#if TI should show steerpoint

var has_waypoint = 0;

var mode_B_active = FALSE;
var mode_L_active = FALSE;
var mode_LB_active = FALSE;
var mode_LF_active = FALSE;
var mode_OPT_active = FALSE;

var B = func {
    setprop("ja37/hud/landing-mode", FALSE);
    if (getprop("autopilot/route-manager/active") == FALSE and getprop("autopilot/route-manager/route/num") > 0) {
        fgcommand("activate-flightplan", props.Node.new({"activate": 1}));
        mode_B_active = TRUE;
        mode_L_active = FALSE;
        mode_LB_active = FALSE;
        mode_LF_active = FALSE;
        mode_OPT_active = FALSE;
        showActiveSteer = TRUE;
        mode = 0;
    } elsif (getprop("autopilot/route-manager/active") == FALSE) {
        mode_B_active = FALSE;
        mode_L_active = FALSE;
        mode_LB_active = FALSE;
        mode_LF_active = FALSE;
        mode_OPT_active = FALSE;
        showActiveSteer = TRUE;
        mode = -1;
    } elsif (mode_B_active == TRUE) {
        # next steerpoint
        var curr = getprop("autopilot/route-manager/current-wp");
        var max = getprop("autopilot/route-manager/route/num") - 1;
        if (curr == max) {
            curr = 0;
        } else {
            curr += 1;
        }
        setprop("autopilot/route-manager/current-wp", curr);
        mode_B_active = TRUE;
        mode_L_active = FALSE;
        mode_LB_active = FALSE;
        mode_LF_active = FALSE;
        mode_OPT_active = FALSE;
        showActiveSteer = TRUE;
        mode = 0;
    } else {
        mode_B_active = TRUE;
        mode_L_active = FALSE;
        mode_LB_active = FALSE;
        mode_LF_active = FALSE;
        mode_OPT_active = FALSE;
        showActiveSteer = TRUE;
        mode = 0;
    }
};

var activateRunway = func {
    # select runway (airport must be active in RM)
    var numb = getprop("autopilot/route-manager/route/num");
    var curr = getprop("autopilot/route-manager/current-wp");
    var name = getprop("autopilot/route-manager/route/wp["~curr~"]/id");
    var rwy  = "";
    if (name != nil and size(split("-", name))>1) {
        name = split("-", name);
        if (name[0] != nil and name[0] != "APP" and name[0] != "DEP" and size(findAirportsByICAO(name[0])) != 0) {
            rwy = name[1];
            name = name[0];
            return TRUE;
        }
    }
    var airpList = findAirportsByICAO(name);
    var airp = nil;
    foreach (var airport ; airpList) {
        if (airport.id == name) {
            airp = airport;
            break;
        }
    }
    if (airp == nil) {
        return FALSE;
    }
    var runways = airp.runways;
    var runwaysVector = [];
    foreach (var runwayKey ; keys(runways)) {
        append(runwaysVector, runways[runwayKey]);
    }
    var currRWY = -1;
    for (var i = 0; i<size(runwaysVector);i+=1) {
        if (runwaysVector[i].id == rwy) {
            currRWY = i;
            break;
        }
    }
    currRWY += 1;
    if (currRWY >= size(runwaysVector)) {
        currRWY = 0;
    }
    var nextRW = name~"-"~runwaysVector[currRWY].id;
    fgcommand("delete-waypt", props.Node.new({"index": curr}));
    #print("deleted in cycle");
    #setprop("autopilot/route-manager/input", "@insert" ~ curr ~ ":" ~ nextRW);
    #print("inserted in cycle: "~"@insert" ~ curr ~ ":" ~ nextRW);
    #gui.dialog_update("route-manager");
    setprop("autopilot/route-manager/destination/airport", name);
    setprop("autopilot/route-manager/destination/runway", runwaysVector[currRWY].id);
    if (numb > getprop("autopilot/route-manager/route/num")) {
        #something went wrong, the steerpoint was deleted, but new wasn't created
        return FALSE;
        #print("failed to insert runway");
    } else {
        if (getprop("autopilot/route-manager/active") == FALSE) {
            fgcommand("activate-flightplan", props.Node.new({"activate": 1}));
        }
        setprop("autopilot/route-manager/current-wp", getprop("autopilot/route-manager/route/num")-1);
        mode = 0;
        #print("selected runway");
        return TRUE;
    }
};

var L = func {
    setprop("ja37/hud/landing-mode", FALSE);
    setprop("ja37/avionics/approach", FALSE);#long
    if (getprop("autopilot/route-manager/active") == TRUE and isSteerPointAirport(getprop("autopilot/route-manager/current-wp")) == TRUE and mode_L_active == TRUE) {
        # cycle runways
        var numb = getprop("autopilot/route-manager/route/num");
        var curr = getprop("autopilot/route-manager/current-wp");
        var name = getprop("autopilot/route-manager/route/wp["~curr~"]/id");
        var rwy  = "";
        if (name != nil and size(split("-", name))>1) {
            name = split("-", name);
            if (name[0] != nil and name[0] != "APP" and name[0] != "DEP" and size(findAirportsByICAO(name[0])) != 0) {
                rwy = name[1];
                name = name[0];
            }
        }
        var airpList = findAirportsByICAO(name);
        var airp = nil;
        foreach (var airport ; airpList) {
            if (airport.id == name) {
                airp = airport;
                break;
            }
        }
        if (airp == nil) {
            mode_LB_active = FALSE;
            mode_LF_active = FALSE;
            mode_B_active = FALSE;
            mode_L_active = FALSE;
            mode_OPT_active = FALSE;
            showActiveSteer = TRUE;
            return;
        }
        var runways = airp.runways;
        var runwaysVector = [];
        foreach (var runwayKey ; keys(runways)) {
            append(runwaysVector, runways[runwayKey]);
        }
        var currRWY = -1;
        for (var i = 0; i<size(runwaysVector);i+=1) {
            if (runwaysVector[i].id == rwy) {
                currRWY = i;
                break;
            }
        }
        currRWY += 1;
        if (currRWY >= size(runwaysVector)) {
            currRWY = 0;
        }
        var nextRW = name~"-"~runwaysVector[currRWY].id;
        fgcommand("delete-waypt", props.Node.new({"index": curr}));
        #print("deleted in cycle");
        #setprop("autopilot/route-manager/input", "@insert" ~ curr ~ ":" ~ nextRW);
        #print("inserted in cycle: "~"@insert" ~ curr ~ ":" ~ nextRW);
        #gui.dialog_update("route-manager");
        setprop("autopilot/route-manager/destination/airport", name);
        setprop("autopilot/route-manager/destination/runway", runwaysVector[currRWY].id);
        if (numb > getprop("autopilot/route-manager/route/num")) {
            #something went wrong, the steerpoint was deleted, but new wasn't created
            mode_L_active = FALSE;
            mode_B_active = FALSE;
            mode = -1;
            #print("failed to insert runway");
        } else {
            if (getprop("autopilot/route-manager/active") == FALSE) {
                fgcommand("activate-flightplan", props.Node.new({"activate": 1}));
            }
            setprop("autopilot/route-manager/current-wp", getprop("autopilot/route-manager/route/num")-1);
            mode = 0;
            #print("cycled runway");
            mode_L_active = TRUE;
            mode_B_active = FALSE;
        }
    } else {
        if (selectDestination() == TRUE) {
            mode_L_active = TRUE;
            mode_B_active = FALSE;
            mode = 0;
        } else {
            stopRM();
            mode_B_active = FALSE;
            mode_L_active = FALSE;
        }
    }
    mode_LB_active = FALSE;
    mode_LF_active = FALSE;
    mode_OPT_active = FALSE;
    showActiveSteer = TRUE;
};

var LB = func {
    setprop("ja37/hud/landing-mode", TRUE);
    setprop("ja37/avionics/approach", FALSE);#long
    mode_B_active = FALSE;
    mode_L_active = FALSE;
    mode_LF_active = FALSE;
    mode_OPT_active = FALSE;
    showActiveSteer = FALSE;
    if (selectDestination() == TRUE and activateRunway() == TRUE) {
        mode = 1;
        mode_LB_active = TRUE;
    } else {
        stopRM();
        mode_LB_active = FALSE;
    }
};

var LF = func {
    setprop("ja37/hud/landing-mode", TRUE);
    setprop("ja37/avionics/approach", TRUE);#short
    mode_B_active = FALSE;
    mode_L_active = FALSE;
    mode_LB_active = FALSE;
    mode_OPT_active = FALSE;
    showActiveSteer = FALSE;
    if (selectDestination() == TRUE and activateRunway() == TRUE) {
        mode = 2;
        mode_LF_active = TRUE;
    } else {
        stopRM();
        mode_LF_active = FALSE;
    }
};

var OPT = func {
    if (getprop("gear/gear/position-norm") > 0 or getprop("ja37/hud/landing-mode") == TRUE) {
        mode = 4;
        mode_B_active = FALSE;
        mode_L_active = FALSE;
        mode_LB_active = FALSE;
        mode_LF_active = FALSE;
        mode_OPT_active = TRUE;
        showActiveSteer = FALSE;
    }
};

var selectDestinationOld = func {
    var max = getprop("autopilot/route-manager/route/num") - 1;
    for (var i = max; i > -1 ; i-=1) {
        if (isSteerPointAirport(i) == TRUE) {
            if (getprop("autopilot/route-manager/active") == FALSE) {
                fgcommand("activate-flightplan", props.Node.new({"activate": 1}));
            }
            setprop("autopilot/route-manager/current-wp", i);
            #print("selected last airport in route.");
            return TRUE;
        }
    }
    return FALSE;
};

var selectDestination = func {
    if (getprop("autopilot/route-manager/destination/airport") != nil and getprop("autopilot/route-manager/destination/airport") != "") {
        var max = getprop("autopilot/route-manager/route/num") - 1;
        if (isSteerPointAirport(getprop("autopilot/route-manager/route/num")-1) == TRUE) {
            if (getprop("autopilot/route-manager/active") == FALSE) {
                fgcommand("activate-flightplan", props.Node.new({"activate": 1}));
            }
            setprop("autopilot/route-manager/current-wp", getprop("autopilot/route-manager/route/num")-1);
            #print("selected destination airport in route.");
            return TRUE;
        }
    } else {
        return selectDestinationOld();
    }
    return FALSE;
};

var stopRM =  func {
    setprop("autopilot/route-manager/active", FALSE);
    mode = -1;
    #print("stop rm");
};

var isSteerPointAirport = func (wp) {
    var name = getprop("autopilot/route-manager/route/wp["~wp~"]/id");
    if (name != nil and size(split("-", name))>1) {
        name = split("-", name);
        if (name[0] != nil and name[0] != "APP" and name[0] != "DEP" and size(findAirportsByICAO(name[0])) != 0) {
            return TRUE;
        }
    } else {
        # TODO: select a runway here?
        if (name != nil and name != "APP" and name != "DEP" and size(findAirportsByICAO(name)) != 0) {
            return TRUE;
        }
    }
    return FALSE;
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

var landing_loop = func {

	show_runway_line = FALSE;
	show_waypoint_circle = FALSE;
	show_approach_circle = FALSE;
	runway = "";
    icao = "";
	var bearing = 0;
	if (input.rmActive.getValue() == TRUE) {
        runway_dist = input.rmDist.getValue();        
        var heading = input.heading.getValue();#true
        bearing = input.rmTrueBearing.getValue();#true
        if (runway_dist != nil and bearing != nil and heading != nil) {
          	runway_bug = bearing - heading;
          	var name = input.rmId.getValue();
          	if (name != nil and size(split("-", name))>1) {
	            name = split("-", name);
                
                if (name[0] != "APP" and name[0] != "DEP" and size(findAirportsByICAO(name[0])) != 0) {#check for steerpoints if its icao or just a steerpoint name
    	            icao = name[0];
    	            runway = name[1];

                    if (icao != last_icao or runway != last_runway) {
                        runway_rw = nil;
                        var hd = -1000;
                        var info = airportinfo(icao);
                        if (info != nil) {
                            var rw = info.runways[runway];
                            if (rw != nil) {
                                hd = rw.heading;
                                runway_rw = rw;
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
                    }
                } else{
                    has_waypoint = 1;
                    runway_rw = nil;
                }
	        } else {
                has_waypoint = 1;
                runway_rw = nil;
            }
	    } else {
            has_waypoint = 0;
            runway_rw = nil;
        }
    } else {
        has_waypoint = 0;
        runway_rw = nil;
    }
    if (icao != last_icao or last_runway != runway) {
    	mode = -1;
    	last_icao = icao;
        last_runway = runway;
    }
    if (has_waypoint > 0) {
    	if (has_waypoint > 1) {
            #showActiveSteer = FALSE;
    		show_runway_line = TRUE;
    		var short = getprop("ja37/avionics/approach");

    		line = short == TRUE?10:20;

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
    		var rect = (diff>0?90:-90);           
			var rectAngle = head+180+rect;

    		runway.apply_course_distance(geo.normdeg(rectAngle), 4100);
    		var distCenter = geo.aircraft_position().distance_to(runway);
    		approach_circle = runway;
            if (getprop("ja37/hud/landing-mode")==FALSE and mode_OPT_active==FALSE and mode_B_active == FALSE and mode_L_active == FALSE and mode_LB_active == FALSE and mode_LF_active == FALSE) {
                # seems route manager was activated through FG menu.
                mode_B_active = TRUE;
                mode = 0;
            }
            if (mode_OPT_active==TRUE or ((input.ctrlRadar.getValue() == 1? (input.rad_alt.getValue() * FT2M) < 15 : (input.alt_ft.getValue() * FT2M) < 35) and mode_B_active == FALSE and mode_L_active == FALSE)) {
                mode = 4;
                mode_B_active = FALSE;
                mode_L_active = FALSE;
                mode_LB_active = FALSE;
                mode_LF_active = FALSE;
                mode_OPT_active = TRUE;
                showActiveSteer = FALSE;
                show_waypoint_circle = TRUE;
    		} elsif (((mode == 2 or mode == 3) and runway_dist*NM2M < 10000)) {# or ILS == TRUE test if glideslope/ILS or less than 10 Km
    			show_waypoint_circle = TRUE;
                mode_B_active = FALSE;
                mode_L_active = FALSE;
                mode_LB_active = FALSE;
                mode_LF_active = TRUE;
                mode_OPT_active = FALSE;
                showActiveSteer = FALSE;
    			mode = 3;
                #print("descent mode 3");
    		} elsif (mode == 1 and distCenter < (4100+100)) {#test inside/on approach circle
    			show_approach_circle = TRUE;
                mode_B_active = FALSE;
                mode_L_active = FALSE;
                mode_LB_active = FALSE;
                mode_LF_active = TRUE;
                mode_OPT_active = FALSE;
                showActiveSteer = FALSE;
    			mode = 2;
    		} elsif (mode == 2 and distCenter < (4100+250)) {
    			show_approach_circle = TRUE;
                mode_B_active = FALSE;
                mode_L_active = FALSE;
                mode_LB_active = FALSE;
                mode_LF_active = TRUE;
                mode_OPT_active = FALSE;
                showActiveSteer = FALSE;
    			mode = 2;
                #print("keeping mode 2 with circle");
    		} elsif (mode == 2 and (runway_dist*NM2M > (line*1000+4100) or distCenter > 11000)) {
                show_approach_circle = TRUE;
                mode_B_active = FALSE;
                mode_L_active = FALSE;
                if (short==TRUE)  {
                    mode_LB_active = FALSE;
                    mode_LF_active = TRUE;
                    showActiveSteer = FALSE;
                    mode = 2;
                    #print("short mode 2");
                } else {
                    mode_LB_active = TRUE;
                    mode_LF_active = FALSE;
                    showActiveSteer = TRUE;
                    mode = 1;
                    #print("long mode 1");
                }
                mode_OPT_active = FALSE;
            } elsif (mode == 2 and runway_dist*NM2M < (line*1000+4100)) {
    			show_waypoint_circle = TRUE;
                mode_B_active = FALSE;
                mode_L_active = FALSE;
                mode_LB_active = FALSE;
                mode_LF_active = TRUE;
                mode_OPT_active = FALSE;
                showActiveSteer = FALSE;
    			mode = 2;
                #print("approach mode 2");
    		} elsif (getprop("ja37/hud/landing-mode")==TRUE and short == FALSE) {
    			mode = 1;
                mode_B_active = FALSE;
                mode_L_active = FALSE;
                mode_LB_active = TRUE;
                mode_LF_active = FALSE;
                mode_OPT_active = FALSE;
                showActiveSteer = FALSE;
    			show_approach_circle = TRUE;
                #print("default mode 1");
    		} else {
                mode = 0;
                showActiveSteer = TRUE;
                show_waypoint_circle = TRUE;
            }
		} else {
			show_waypoint_circle = TRUE;
            showActiveSteer = TRUE;
            mode_LB_active = FALSE;
            mode_LF_active = FALSE;
            if (mode_OPT_active == TRUE) {
                mode = 4;
                mode_B_active = FALSE;
                mode_L_active = FALSE;
            } else {
                mode = 0;
            }
		}    	
    } else {
        showActiveSteer = TRUE;
        mode_B_active = FALSE;
        mode_L_active = FALSE;
        mode_LB_active = FALSE;
        mode_LF_active = FALSE;
        if (mode_OPT_active == TRUE) {
            mode = 4;
        } else {
            mode = -1;
        }
    }
    settimer(landing_loop, 0.05);
}

landing_loop();

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
        var ils = " No ILS.";

        if (runway_rw != nil) {
            var runway_ils = nil;
            var vec = findNavaidsWithinRange(runway_rw, 10, "ils");
            if (vec != nil and size(vec) > 0) {
                runway_ils = vec[0];
            } else {
                runway_ils = nil;
            }
            if (runway_ils != nil) {
                ils = " ILS is "~roundFreq(runway_ils.frequency)~" MHz.";
            }
        }
        window.write(sprintf("Saab 37; QFE at runway %s is %.2f inHg or %4d hPa. %s", runway, qfe, qfe2, ils), 0.0, 0.6, 0.6);
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