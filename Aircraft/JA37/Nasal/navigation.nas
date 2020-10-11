######## radio nav initialization

input = {
	radioComNav:	"instrumentation/radio/switches/com-nav",
	radioMhzKhz:	"instrumentation/radio/switches/mhz-khz",
	radioDisplFreq:	"instrumentation/radio/display-freq",
	radioHeadNorm:	"instrumentation/radio/heading-indicator-norm",
	AdfBearing:		"instrumentation/adf/indicated-bearing-deg",
	commSelMhz:		"instrumentation/comm/frequencies/selected-mhz",
	adfSelKhz:		"instrumentation/adf/frequencies/selected-khz",
	navSelMhz:		"instrumentation/nav/frequencies/selected-mhz",
	navNeedle:		"instrumentation/nav/heading-needle-deflection-norm",
	wp_ind_type:	"instrumentation/waypoint-indicator/type",
	wp_ind_num:		"instrumentation/waypoint-indicator/number",
	rm_active:		"autopilot/route-manager/active",
	landing_mode:	"ja37/hud/landing-mode",
};

foreach(var name; keys(input)) {
	input[name] = props.globals.getNode(input[name], 1);
}

input.radioComNav.setBoolValue(0); # 0 is for com, 1 is for nav.
input.radioMhzKhz.setBoolValue(0); # 0 is for mhz, 1 is for khz.
input.radioDisplFreq.setDoubleValue(input.commSelMhz.getValue());# set up the radio panel display
input.radioHeadNorm.setDoubleValue(0); #heading indicator for the left-hand side attitude display
input.AdfBearing.setDoubleValue(0);


######## radio panel display update code

var display_freq = func {
	#print("inside display_freq function");
	#print("com-nav switch = " ~ getprop("instrumentation/radio/switches/com-nav"));
	#print("mhz-khz switch = " ~ getprop("instrumentation/radio/switches/mhz-khz"));
	if ( input.radioComNav.getValue() == 1 ) {
		if ( input.radioMhzKhz.getValue() == 1 ) {
			input.radioDisplFreq.setDoubleValue(input.adfSelKhz.getValue());
		} else {
			input.radioDisplFreq.setDoubleValue(input.navSelMhz.getValue());
		}
	} else {
		input.radioDisplFreq.setDoubleValue(input.commSelMhz.getValue());
	}
}

#i don't like all these listeners, to be honest. but it works and it's not heavy.
setlistener("instrumentation/radio/switches/com-nav",display_freq);
setlistener("instrumentation/radio/switches/mhz-khz",display_freq);
setlistener("instrumentation/adf/frequencies/selected-khz",display_freq);
setlistener("instrumentation/nav/frequencies/selected-mhz",display_freq);
setlistener("instrumentation/comm/frequencies/selected-mhz",display_freq);

######## heading indicator code.

var heading_indicator = func {
	if ( input.radioMhzKhz.getValue() == 1 ) {
		#locate afds - it's +/- 60* from an ndb, and the needle will start moving.
		var adf_bearing = input.AdfBearing.getValue();
		if ( adf_bearing > 360 ) {
			adf_bearing = 0;
		} elsif ( adf_bearing > 60 and adf_bearing < 180 ) {
			adf_bearing = 1;
		} elsif (adf_bearing >= 180 and adf_bearing < 300 ) {
			adf_bearing = -1;
		} elsif (adf_bearing < 360 and adf_bearing > 300 ) {
			adf_bearing = ( adf_bearing - 360 ) / 60;
		} else {
			adf_bearing = adf_bearing / 60;
		}
		input.radioHeadNorm.setDoubleValue(adf_bearing);
	} elsif (input.navNeedle.getValue() != nil) {
		#vor navving
		input.radioHeadNorm.setDoubleValue(input.navNeedle.getValue()); #just use the regular ol' nav heading indicator.
	}

	#settimer(heading_indicator, 0);
}

#heading_indicator();


### Waypoint name display for AJ(S)

# Codes for waypoint type (first character)
var WP_TYPE = {
    OFF: 0,
    LAND: 1,
    LAND_B: 2,
    LAND_F: 3,
    WPT: 4,
    TGT: 5,
    POPUP: 6,
    FIX: 7,
    WPT_RECO: 8,
    TGT_RECO: 9,
    TGT_TRACK: 10,
    WPT_POLY: 11,
};

# Codes for waypoint number (second character)
# Digits 1-9 are displayed as-is.
var WP_NUM = {
    OFF: 0,
    ZERO: 10,
    START: 11,
};

# Test if departure/destination are set in a flightplan.
#
# Departure/destination are only recognised if they are the first/last WP respectively.
# (the WP indicator logic is not designed for this)

var wp_match_airport = func(wp, airport) {
    return airport != nil and wp.id == airport.id;
}

var wp_match_runway = func(wp, airport, runway) {
    return airport != nil and runway != nil and wp.id == airport.id~"-"~runway.id;
}

var departure_set = func(fp) {
    if (fp.getPlanSize() <= 0) return 0;
    var wp = fp.getWP(0);

    return wp.wp_role == "sid" and
        (wp_match_airport(wp, fp.departure) or wp_match_runway(wp, fp.departure, fp.departure_runway));
}

var destination_set = func(fp) {
    if (fp.getPlanSize() <= 0) return 0;
    var wp = fp.getWP(fp.getPlanSize()-1);

    return wp.wp_role == "approach" and
        (wp_match_airport(wp, fp.destination) or wp_match_runway(wp, fp.destination, fp.destination_runway));
}


var set_wp_name = func(type, number) {
    input.wp_ind_type.setValue(type);
    input.wp_ind_num.setValue(number);
}

var update_wp_indicator = func {
    var fp = flightplan();
    var index = fp.current;

    if(!input.rm_active.getBoolValue() or index < 0) {
        set_wp_name(WP_TYPE.OFF, WP_NUM.OFF);
        return;
    }

    if (index == 0 and departure_set(fp)) {
        # takeoff
        set_wp_name(WP_TYPE.LAND, WP_NUM.START);
    } elsif (index == fp.getPlanSize() - 1 and destination_set(fp)) {
        # landing
        if (!input.landing_mode.getBoolValue()) {
            set_wp_name(WP_TYPE.LAND, 1);
        } elsif (land.mode == 1) {
            set_wp_name(WP_TYPE.LAND_B, 1);
        } else {
            set_wp_name(WP_TYPE.LAND_F, 1);
        }
    } else {
        # Normal waypoint
        if (!departure_set(fp)) index += 1; # Is WP 0 displayed as departure base?
        # Can only correctly display waypoint 1-9. After that, display '0'.
        if (index > 9) index = WP_NUM.ZERO;
        set_wp_name(WP_TYPE.WPT, index);
    }
}


### Waypoint selection buttons for AJ(S)

# Select the nth waypoint.
# The first and last waypoints of the flightplan can not be selected through
# this function if they are runways (ls_button and l_button should be used).
# If that is the case, numbering is offset so that '1' corresponds to the
# first waypoint after the starting base.
var nav_button = func(n) {
    var fp = flightplan();
    var last = fp.getPlanSize() - 1;
    if (last < 0) return;

    # Offset if departure base is not set.
    if (!departure_set(fp)) n -= 1;

    if (n < last or (n == last and !destination_set(fp))) {
        fp.current = n;
    }
}

# Select the starting base, which is the first waypoint, provided it is a runway.
var ls_button = func {
    var fp = flightplan();
    if (fp.getPlanSize() > 0 and departure_set(fp)) {
        fp.current = 0;
    }
}

# Select the landing base, which is the last waypoint, provided it is a runway.
var l_button = func {
    var fp = flightplan();
    var last = fp.getPlanSize() - 1;
    if (last >= 1 and destination_set(fp)) {
        fp.current = last;
    }
}
