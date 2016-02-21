######## radio nav initialization
setprop("instrumentation/radio/switches/com-nav",0); # 0 is for com, 1 is for nav.
setprop("instrumentation/radio/switches/mhz-khz",0); # 0 is for mhz, 1 is for khz.
setprop("instrumentation/radio/display-freq",getprop("instrumentation/comm/frequencies/selected-mhz")); # set up the radio panel display
setprop("instrumentation/radio/heading-indicator-norm", 0); #heading indicator for the left-hand side attitude display
setprop("instrumentation/adf/indicated-bearing-deg",0);


######## radio panel display update code

var display_freq = func {
	#print("inside display_freq function");
	#print("com-nav switch = " ~ getprop("instrumentation/radio/switches/com-nav"));
	#print("mhz-khz switch = " ~ getprop("instrumentation/radio/switches/mhz-khz"));
	if ( getprop("instrumentation/radio/switches/com-nav") == 1 ) {
		if ( getprop("instrumentation/radio/switches/mhz-khz") == 1 ) {
			setprop("instrumentation/radio/display-freq",getprop("instrumentation/adf/frequencies/selected-khz"));
		} else {
			setprop("instrumentation/radio/display-freq",getprop("instrumentation/nav/frequencies/selected-mhz"));
		}
	} else {
		setprop("instrumentation/radio/display-freq",getprop("instrumentation/comm/frequencies/selected-mhz"));
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
	if ( getprop("instrumentation/radio/switches/mhz-khz") == 1 ) {
		#locate afds - it's +/- 60* from an ndb, and the needle will start moving.
		var adf_bearing = getprop("instrumentation/adf/indicated-bearing-deg");
		if ( adf_bearing > 360 ) {
			adf_bearing = 0;
		} elsif ( adf_bearing > 60 and adf_bearing < 180 ) {
			adf_bearing = 1;
		} elsif (adf_bearing >= 180 and adf_bearing < 300 ) {
			adf_bearing = -1;
		} elsif (adf_bearing < 360 ) {
			adf_bearing = ( adf_bearing - 360 ) / 60;
		} else {
			adf_bearing = adf_bearing / 60;
		}
		setprop("instrumentation/radio/heading-indicator-norm", adf_bearing);
	} else {
		#vor navving
		setprop("instrumentation/radio/heading-indicator-norm", getprop("instrumentation/nav/heading-needle-deflection-norm")); #just use the regular ol' nav heading indicator.
	}
}

setlistener("instrumentation/nav/heading-needle-deflection-norm", heading_indicator);
setlistener("instrumentation/adf/indicated-bearing-deg", heading_indicator);