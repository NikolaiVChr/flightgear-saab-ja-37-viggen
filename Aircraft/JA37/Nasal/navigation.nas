######## radio nav initialization

input = {
	radioComNav:	"instrumentation/radio/switches/com-nav",
	radioMhzKhz:	"instrumentation/radio/switches/mhz-khz",
	radioDisplFreq: "instrumentation/radio/display-freq",
	radioHeadNorm:	"instrumentation/radio/heading-indicator-norm",
	AdfBearing:		"instrumentation/adf/indicated-bearing-deg",
	commSelMhz:  	"instrumentation/comm/frequencies/selected-mhz",
	adfSelKhz:		"instrumentation/adf/frequencies/selected-khz",
	navSelMhz:		"instrumentation/nav/frequencies/selected-mhz",
	navNeedle:		"instrumentation/nav/heading-needle-deflection-norm",
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


# Waypoint selection buttons for AJ(S)
var nav_button = func(n) {
	var fp = flightplan();
	# Last waypoint is selected with landing base button
	if (n < fp.getPlanSize() - 1) fp.current = n;
}

var ls_button = func () {
	var fp = flightplan();
	if (fp.getPlanSize() > 0) fp.current = 0;
}

var l_button = func() {
	var fp = flightplan();
	fp.current = fp.getPlanSize() - 1;
}
