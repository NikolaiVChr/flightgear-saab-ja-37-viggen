var ongoing = 0;
var ready   = 0;
var state   = 0;
var button  = 0;
var program = 1;
var iteration = 0;

var B_YM    = 1;
var B_START = 2;
var B_REP   = 3;
var B_IPK   = 4;
var B_FK    = 5;
var B_FEL   = 6;


var press = func (btn) {
	button = btn;
	main();
}

var main = func {
	if (ongoing) {
		#print("ongoing");
		if (button == B_FK) {
			stopTest();
		} elsif (state == 1) {
			if (button == B_START) {
				# starting
				doTest();
			}
		} elsif (state == 2) {
			if (button == B_START) {
				# stop and go to next program
				program += 1;
				doTest();
			}
		} elsif (state == 3) {
			# start flashing (green)
			if (button == B_START) {
				# continue
				program += 1;
				doTest();
			}
		} elsif (state == 4) {
			# start and fel flashing (red)
			if (button == B_START) {
				# continue
				program += 1;
				doTest();
			} elsif (button == B_FEL) {
				# continue
				program += 1;
				doTest();
			} elsif (button == B_REP) {
				# repeat
				doTest();
			}
		}
	} elsif (ready) {
		if (button == B_FK) {
			#print("test mode");
			setprop("ja37/test/fk-steady", 1);
			state = 1;
			ongoing = 1;
			MI.mi.off = 1;
			TI.ti.off = 1;
		}
	} else {
		# nop
	}
	button = 0;
}

var doTest = func {
	setprop("ja37/test/start-steady", 1);
	setprop("ja37/test/start-flash", 0);
	setprop("ja37/test/fel-flash", 0);
	setprop("ja37/test/red", 0);
	setprop("ja37/test/green", 0);
	state = 2;# do tests
	iteration = 0;
}

var loop = func {
	if (ongoing) {
		# check if should abort
		if (getprop("ja37/avionics/ins-init") == 0 and getprop("fdm/jsbsim/gear/unit[1]/WOW") == 1 and getprop("/controls/engines/engine[0]/starter-cmd") == 0 and (getprop("fdm/jsbsim/systems/electrical/external/supplying") == 1 or (power.prop.acSecondBool.getValue() and getprop("fdm/jsbsim/fcs/throttle-pos-deg") > 0 and getprop("fdm/jsbsim/fcs/throttle-pos-norm-scale") < 0.9))) {
			# test can continue
			if (state == 1) {
				dap.testDisplay = sprintf("%02d0000",program);
				dap.testMinus = 0;
			} elsif (state == 2) {
				# we are testing
				if (program > 20) {
					#completed tests, now stop testing.
					stopTest();
				} elsif (iteration < rand()*125) {
					# test in progress and not finished yet.
					iteration += 1;
					dap.testDisplay = sprintf("%02d----",program);
					dap.testMinus = 1;
				} else {
					# program test finished
					if (rand() > 0.95 or programTest() == 0) {
						# report error
						state = 4;
						dap.testDisplay = sprintf("%02d%04d",program,rand()*10000);
						dap.testMinus = 0;
						setprop("ja37/test/red", 1);
						setprop("ja37/test/start-steady", 0);
						setprop("ja37/test/start-flash", 1);
						setprop("ja37/test/fel-flash", 1);
					} else {
						# report pass
						state = 3;
						dap.testDisplay = sprintf("%02d%04d",program,rand()*10000);
						dap.testMinus = 0;
						setprop("ja37/test/green", 1);
						setprop("ja37/test/start-steady", 0);
						setprop("ja37/test/start-flash", 1);
					}
				}
			} 
		} else {
			stopTest();
		}
	} else {
		# check if ready for testing
		if (getprop("ja37/avionics/ins-init") == 0 and getprop("fdm/jsbsim/gear/unit[1]/WOW") == 1 and (getprop("fdm/jsbsim/systems/electrical/external/supplying") > 0.9
		    or (power.prop.acSecondBool.getValue()
		        and getprop("fdm/jsbsim/fcs/throttle-pos-deg") > 0
		        and getprop("fdm/jsbsim/fcs/throttle-pos-norm-scale") < 0.9))) {
			# test can be started
			ready = 1;
			#print("ready");
		} else {
			ready = 0;
			#print("not ready");
		}		
	}
}


var stopTest = func {
	#print("quit testing");
	dap.testDisplay = "";
	ready     = 0;
	ongoing   = 0;
	state     = 0;
	program   = 1;
	iteration = 0;
	#stop button lights
	setprop("ja37/test/ym-steady", 0);
	setprop("ja37/test/start-steady", 0);
	setprop("ja37/test/ipk-steady", 0);
	setprop("ja37/test/fel-steady", 0);
	setprop("ja37/test/rep-steady", 0);
	setprop("ja37/test/fk-steady", 0);
	setprop("ja37/test/ym-flash", 0);
	setprop("ja37/test/start-flash", 0);
	setprop("ja37/test/ipk-flash", 0);
	setprop("ja37/test/fel-flash", 0);
	setprop("ja37/test/rep-flash", 0);
	setprop("ja37/test/fk-flash", 0);
	#stop indicator lights
	setprop("ja37/test/green", 0);
	setprop("ja37/test/red", 0);
	MI.mi.off = 0;
	TI.ti.off = 0;
}

# 1 CD - CPU
# 2 ANP - Adaptation unit?

# 3 LD - Airdata
# 4 TN - Inertial navigation

# 5 SA - Autopilot
# 6 GSA - Basic flight control system

# 7 PRES - Presentation
# 8 EP - Electronic presentation system

# 9 PN
# 10 MIS - Target aquisition system

# 11 RRS - Radar (beam?)
# 12 BES - RB71 Illuminator

# 13 
# 14 TILS - Tactical landing system

# 15 SD - Combat control data
# 16 RHM - Radar altimeter

# 17 A73
# 18 BEV - Armament??

var programTest = func {
	if (program == 3) {
		if (   getprop("instrumentation/altimeter/serviceable") == 0
			or getprop("instrumentation/airspeed-indicator/serviceable") == 0
			or getprop("systems/pitot/serviceable") == 0
			or getprop("systems/vacuum/serviceable") == 0
			or getprop("systems/static/serviceable") == 0) {
			return 0;#fail
		}		
	} elsif (program == 6) {
		if (   getprop("fdm/jsbsim/fcs/roll-limiter/serviceable") == 0
			or getprop("fdm/jsbsim/fcs/roll-damper/serviceable") == 0
			or getprop("fdm/jsbsim/fcs/yaw-damper/serviceable") == 0
			or getprop("fdm/jsbsim/fcs/pitch-damper/serviceable") == 0) {
			return 0;#fail
		}		
	} elsif (program == 7) {
		if (   getprop("instrumentation/head-up-display/serviceable") == 0) {
			return 0;#fail
		}		
	} elsif (program == 11) {
		if (   getprop("instrumentation/radar/serviceable") == 0) {
			return 0;#fail
		}		
	}
	return 1;#pass
}