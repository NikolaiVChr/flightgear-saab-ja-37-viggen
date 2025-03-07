###################################################################################
##                                                                               ##
## Improved redout/blackout system for Flightgear                                ##
##                                                                               ##
## Author: Nikolai V. Chr.                                                       ##
##                                                                               ##
## Version 1.04            License: GPL 2.0                                      ##
##                                                                               ##
###################################################################################


var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }

var invert = func (acc) {
	var g_inv = -1 * (acc - 5);
	return g_inv;
}


#
# Customize the values according to the quality of the G-suit the pilot is wearing. The times are in seconds.
#
# According to NASA (1979), this should be the blackout values for F-16:
#
# blackout_onset      =   5;
# blackout_fast       =   9;
# blackout_onset_time = 300;
# blackout_fast_time  =  10;
#
# That means at 9G it will take 10 seconds to blackout completely.
# At 5G it will take 300 seconds.
#

var blackout_onset      =    5;
var blackout_fast       =    8;
var redout_onset        =   -2;
var redout_fast         =   -4;

var blackout_onset_time =  300;
var blackout_fast_time  =   30;
var redout_onset_time   =   45;
var redout_fast_time    =  3.5;

var fast_time_recover   =    7;
var slow_time_recover   =   15;






## Do not modify anything below this line ##

var fdm = "jsb";
var g1_log = math.log10(1);
var blackout_onset_log = math.log10(blackout_onset);
var blackout_fast_log = math.log10(blackout_fast);
var redout_onset_log = math.log10(invert(redout_onset));
var redout_fast_log = math.log10(invert(redout_fast));

var blackout = 0;
var redout   = 0;

var suit = -1;

var init_suit = func {
	blackout_onset_log = math.log10(blackout_onset);
	blackout_fast_log = math.log10(blackout_fast);
	redout_onset_log = math.log10(invert(redout_onset));
	redout_fast_log = math.log10(invert(redout_fast));
}

var changeSuit = func {
	if (suit == 1) {
		#1971
		blackout_onset      =  4.5;
		blackout_fast       =    7;
		blackout_onset_time =  300;
		blackout_fast_time  =   10;
	} elsif (suit == 2) {
		#1979
		blackout_onset      = 4.75;
		blackout_fast       =    8;
		blackout_onset_time =  300;
		blackout_fast_time  =   10;
	} else {
		#1997
		blackout_onset      =    5;
		blackout_fast       =    8;
		blackout_onset_time =  300;
		blackout_fast_time  =   30;
	}
	init_suit();
}

var redout_loop = func { 
	
	if (suit != getprop("ja37/effect/g-suit")) {
		suit = getprop("ja37/effect/g-suit");
		changeSuit();
		setprop("sim/rendering/redout/parameters/blackout-onset-g", blackout_onset);
		setprop("sim/rendering/redout/parameters/blackout-complete-g", blackout_fast);
		setprop("sim/rendering/redout/parameters/redout-onset-g", redout_onset);
		setprop("sim/rendering/redout/parameters/redout-complete-g", redout_fast);
		setprop("sim/rendering/redout/parameters/onset-blackout-sec", blackout_onset_time);
		setprop("sim/rendering/redout/parameters/fast-blackout-sec", blackout_fast_time);
		setprop("sim/rendering/redout/parameters/onset-redout-sec", redout_onset_time);
		setprop("sim/rendering/redout/parameters/fast-redout-sec", redout_fast_time);
		setprop("sim/rendering/redout/parameters/recover-fast-sec", fast_time_recover);
		setprop("sim/rendering/redout/parameters/recover-slow-sec", slow_time_recover);
	}
	
	if (getprop("payload/armament/msg") == 0) {
		settimer(redout_loop, 0.5);
		return;
	}
	setprop("sim/rendering/redout/enabled", 1);# enable the Fg default redout/blackout system.

	changeSuit();

	setprop("sim/rendering/redout/parameters/blackout-onset-g", blackout_onset);
	setprop("sim/rendering/redout/parameters/blackout-complete-g", blackout_fast);
	setprop("sim/rendering/redout/parameters/redout-onset-g", redout_onset);
	setprop("sim/rendering/redout/parameters/redout-complete-g", redout_fast);
	setprop("sim/rendering/redout/parameters/onset-blackout-sec", blackout_onset_time);
	setprop("sim/rendering/redout/parameters/fast-blackout-sec", blackout_fast_time);
	setprop("sim/rendering/redout/parameters/onset-redout-sec", redout_onset_time);
	setprop("sim/rendering/redout/parameters/fast-redout-sec", redout_fast_time);
	setprop("sim/rendering/redout/parameters/recover-fast-sec", fast_time_recover);
	setprop("sim/rendering/redout/parameters/recover-slow-sec", slow_time_recover);
	
    settimer(redout_loop, 0.5);
}

var blackout_loop = func {
	if (suit != getprop("ja37/effect/g-suit")) {
		suit = getprop("ja37/effect/g-suit");
		changeSuit();
	}
	setprop("/sim/rendering/redout/enabled", 0);# disable the Fg default redout/blackout system.
	var dt = getprop("sim/time/delta-sec");
	var g = 0;
	if (fdm == "jsb") {
		# JSBSim
		g = -getprop("accelerations/pilot/z-accel-fps_sec")/32.174;
	} else {
		# Yasim
		g = getprop("/accelerations/pilot-g[0]");
	}
	if (g == nil) {
		g = 1;
	}
	setprop("/accelerations/pilot-gdamped", g);

	var g_log = g <= 1?0:math.log10(g);
	if (g < blackout_onset) {
		# reduce blackout

		var curr_time = fast_time_recover + ((g_log - g1_log) / (blackout_onset_log - g1_log)) * (slow_time_recover - fast_time_recover);

		curr_time = clamp(curr_time, 0, 1000);

		blackout -= (1/curr_time)*dt;

		blackout = clamp(blackout, 0, 1);

	} elsif (g >= blackout_onset) {
		# increase blackout

		var curr_time = math.log10(blackout_onset_time) + ((g_log - blackout_onset_log) / (blackout_fast_log - blackout_onset_log)) * (math.log10(blackout_fast_time) - math.log10(blackout_onset_time));

		curr_time = math.pow(10, curr_time);

		curr_time = clamp(curr_time, 0, 1000);

		blackout += (1/curr_time)*dt;

		blackout = clamp(blackout, 0, 1);

	}

	var g_inv = invert (g);
	var g_inv_log = g_inv <= 1?0:math.log10(g_inv);
	if (g > redout_onset) {
		# reduce redout

		var curr_time = fast_time_recover + ((g_inv_log - g1_log) / (redout_onset_log - g1_log)) * (slow_time_recover - fast_time_recover);

		curr_time = clamp(curr_time, 0, 1000);

		redout -= (1/curr_time)*dt;

		redout = clamp(redout, 0, 1);

	} elsif (g <= redout_onset) {
		# increase redout

		var curr_time = math.log10(redout_onset_time) + ((g_inv_log - redout_onset_log) / (redout_fast_log - redout_onset_log)) * (math.log10(redout_fast_time) - math.log10(redout_onset_time));

		curr_time = math.pow(10, curr_time);

		curr_time = clamp(curr_time, 0, 1000);

		redout += (1/curr_time)*dt;

		redout = clamp(redout, 0, 1);

	}

	var sum = blackout - redout;

	if (getprop("/sim/current-view/internal") == 0) {
		# not inside aircraft
		setprop("/sim/rendering/redout/red", 0);
    	setprop("/sim/rendering/redout/alpha", 0);
	} elsif (sum < 0) {
		setprop("/sim/rendering/redout/red", 1);
    	setprop("/sim/rendering/redout/alpha", -1 * sum);
    } else {
    	setprop("/sim/rendering/redout/red", 0);
    	setprop("/sim/rendering/redout/alpha", sum);
    }

    settimer(blackout_loop, 0);
}


var blackout_init = func {
	fdm = getprop("/sim/flight-model");

	if (getprop("sim/rendering/redout/internal/log/g-force") == nil) {
		blackout_loop();
	} else {
		redout_loop();
	}
}



var blackout_init_listener = setlistener("sim/signals/fdm-initialized", func {
	blackout_init();
	removelistener(blackout_init_listener);
}, 0, 0);


var test = func (blackout_onset, blackout_fast, blackout_onset_time, blackout_fast_time) {
	var blackout_onset_log = math.log10(blackout_onset);
	var blackout_fast_log = math.log10(blackout_fast);

	var g = 5;
	print();
	while(g <= 20) {

		var g_log = g <= 1?0:math.log10(g);

		var curr_time = math.log10(blackout_onset_time) + ((g_log - blackout_onset_log) / (blackout_fast_log - blackout_onset_log)) * (math.log10(blackout_fast_time) - math.log10(blackout_onset_time));

		curr_time = math.pow(10, curr_time);

		curr_time = clamp(curr_time, 0, 1000);

		printf("%0.1f, %0.2f", g, curr_time);

		g += .5;
	}
	print();
}
