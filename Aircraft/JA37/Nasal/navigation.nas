# todo - add these to someplace else.
setprop("instrumentation/radio/switches/com-nav",0); # 0 is for com, 1 is for nav.
setprop("instrumentation/radio/switches/mhz-khz",0); # 0 is for mhz, 1 is for khz.
setprop("instrumentation/radio/display-freq",118.0);

var display_freq = func {
	print("inside display_freq function");
	print("com-nav switch = " ~ getprop("instrumentation/radio/switches/com-nav"));
	print("mhz-khz switch = " ~ getprop("instrumentation/radio/switches/mhz-khz"));
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

setlistener("instrumentation/radio/switches/com-nav",display_freq);
setlistener("instrumentation/radio/switches/mhz-khz",display_freq);
setlistener("instrumentation/adf/frequencies/selected-khz",display_freq);
setlistener("instrumentation/nav/frequencies/selected-mhz",display_freq);
setlistener("instrumentation/comm/frequencies/selected-mhz",display_freq);