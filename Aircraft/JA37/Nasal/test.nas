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
		if (getprop("fdm/jsbsim/gear/unit[1]/WOW") == 1 and getprop("/controls/engines/engine[0]/starter-cmd") == 0 and (getprop("fdm/jsbsim/systems/electrical/external/supplying") == 1 or (getprop("systems/electrical/outputs/dc-voltage") > 20 and getprop("systems/electrical/outputs/ac-main-voltage") > 100 and getprop("fdm/jsbsim/fcs/throttle-pos-deg") > 0 and getprop("fdm/jsbsim/fcs/throttle-pos-norm-scale") < 0.9))) {
			# test can continue
			if (state == 1) {
				dap.testDisplay = sprintf("%02d0000",program);
				dap.testMinus = 0;
			} elsif (state == 2) {
				# we are testing
				if (program > 20) {
					stopTest();
				} elsif (iteration < rand()*125) {
					iteration += 1;
					dap.testDisplay = sprintf("%02d----",program);
					dap.testMinus = 1;
				} else {
					if (rand() > 0.95) {
						state = 4;
						dap.testDisplay = sprintf("%02d%04d",program,rand()*10000);
						dap.testMinus = 0;
						setprop("ja37/test/red", 1);
						setprop("ja37/test/start-steady", 0);
						setprop("ja37/test/start-flash", 1);
						setprop("ja37/test/fel-flash", 1);
					} else {
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
		if (getprop("fdm/jsbsim/gear/unit[1]/WOW") == 1 and (getprop("fdm/jsbsim/systems/electrical/external/supplying") > 0.9
		    or (getprop("systems/electrical/outputs/ac-main-voltage") > 100
		    	and getprop("systems/electrical/outputs/dc-voltage") > 100
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

# TODO:
#
# engine starter should be hold in for 30 secs before quiting test.
# TI test
# Shut down during testing: +TI, +MI, +CI, +SI, -indicators, +heater.
# INS must be done or off before testing can start. (clicking TNF on MI can stop it)
# seperate tests wth knob