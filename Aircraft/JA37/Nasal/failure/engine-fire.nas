
#####################################
####     Engine fire            #####
#####################################


input = {
  elapsed:          "sim/time/elapsed-sec",
  engineRunning:    "engines/engine/running",
  replay:           "sim/replay/replay-state",
  serv:             "engines/engine[0]/fire/serviceable",
  airspeed:         "/velocities/airspeed-kt",
  thrust:           "/engines/engine[0]/thrust_lb",                # negative at reverse thrust
  temp:             "fdm/jsbsim/propulsion/engine/outlet-temperature-degc",
};

############ global variables #####################

var airspeed_safe_reverse_kt = 64.8;
var thrust_reverse_max = -7716.18;# max reverse thrust lbf at sealevel
var temp_safe = 925;
var TRUE = 1;
var FALSE = 0;
var start_time = -1;
var last_serv_status = TRUE;

#
# Cause of fire:
#  + ground impact
#  + missile impact
#  + too high outlet temp
#  + too much reverse thrust at very low speeds
#
# Fire consequenses after some time/probability:
#  + total engine failure
#  - reduced thrust
#  + no afterburner
#  + black smoke
#  + reverser failure
#  - throttle stuck
#  + fire indicators blinking
#  + master warning
#  + fire goes out by itself
#  + generator fail

############ loop #####################

var loop_fire = func {
	if (input.replay.getValue() == TRUE) {
		settimer(loop_fire, 1);
		return;
	}

	var new_fire = FALSE;
    if (input.serv.getValue() == TRUE) {
    	# engine not on fire, lets test if it should catch fire:
    	new_fire = test_for_fire();
    } elsif (last_serv_status == TRUE) {
    	# fire started by missile hit or aircraft impact, lets start it proper:
    	new_fire = TRUE;
    }

    if (new_fire == TRUE) {
    	start_fire();
    }

    if (input.serv.getValue() == FALSE) {
    	# engine on fire, deal with it:
    	fire();
    }

    last_serv_status = input.serv.getValue();
    #settimer(loop_fire, 1);
}

var test_for_fire = func {
	# The engine is not on fire, test if it should catch fire

	# test outlet temp
	var temp = input.temp.getValue();
	if (temp > temp_safe) {
		# temperature is very high, calculate chance that it will make engine catch fire:
		var temp_norm = (temp - temp_safe)/250; # 250 deg over safe temp will be 1, safe temp will be 0
		var probability = temp_norm/(15*60);# 250 deg over safe temp will probably fail 4 times a minute
		#print("engine fire: temp probability = "~probability);
		if ( rand() < probability) {
			# fire!
			print("engine fire: starting due to too high outlet temperature");
			return TRUE;
		}
	}

	# test hot air through inlet
	var speed = input.airspeed.getValue();
	var thrust = input.thrust.getValue();
	#print(thrust~"<"~(thrust_reverse_max/2));
	if (thrust < (thrust_reverse_max/2) and speed < airspeed_safe_reverse_kt) {
		# reverser employed with over ½ max thrust at very low speed, calculate chance that it will make engine catch fire:
		var thrust_norm = ((-thrust)+(thrust_reverse_max/2))/(-thrust_reverse_max/2);# -1500 Newton will be 0, -3000 Newton will be 1
		var speed_norm = -(speed - airspeed_safe_reverse_kt)/airspeed_safe_reverse_kt;# safe speed will be 0, still will be 1
		var probability = thrust_norm*speed_norm/60;# in most unsafe condition (full reverse, no airspeed) it will probably fail once every minute
		#print("engine fire: hot air probability = "~probability);
		if (rand() < probability) {
			# fire!
			print("engine fire: starting due to hot air sucked into inlet");
			return TRUE;
		}
	}

	return FALSE;
}

var start_fire = func {
	# Engine catches fire
	FailureMgr.set_failure_level("engines/engine[0]/fire", 1);
	start_time = input.elapsed.getValue();
}

var fire = func {
	# consequenses of fire

	var time_on_fire = input.elapsed.getValue() - start_time;
	#print("engine fire: still burning");

	if (rand() < 0.01/60) {# 1% chance that fire will go out every minute.
		FailureMgr.set_failure_level("engines/engine[0]/fire", 0);# fire goes out
		return;
	}

	# chance of total engine failure:
	if (rand() < time_on_fire/(1200*60)) {# 0 minutes is 0% chance, 20 minutes is 100% chance every minute
		FailureMgr.set_failure_level("engines/engine", 1);#fail engine
		#print("engine fire: total engine failure");
	} elsif (rand() < time_on_fire/(1200*60)) {
		FailureMgr.set_failure_level("engines/engine/afterburner", 1);# fail afterburner
	} elsif (rand() < time_on_fire/(1200*60)) {
		FailureMgr.set_failure_level("controls/engines/engine/reverse-system", 1);# fail reverser
	} elsif (rand() < time_on_fire/(1200*60)) {
		FailureMgr.set_failure_level("systems/generator", 1);# fail generator
	}
}

############ init function #####################

var init_fire = func {
	# init function

	# setup property nodes for the loop
	foreach(var name; keys(input)) {
	  input[name] = props.globals.getNode(input[name], 1);
	}

	# start the main loop
	#settimer(func { loop_fire() }, 1);
}

# start the init function
#var main_init_listener = setlistener("ja37/supported/initialized", func {
#	init_fire();
#	removelistener(main_init_listener);
#}, 0, 0);
