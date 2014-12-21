#
# A Flightgear JSBSim crash and stress damage system.
#
# Inspired by the crash system in Mig15 by Slavutinsky Victor. And by Hvengel's formula for wingload stress.
#
# Authors: Slavutinsky Victor, Nikolai V. Chr. (Necolatis)
#
#
# Version 0.1
#
# License:
#   GPL 2.0


var TRUE = 1;
var FALSE = 0;

var JsbsimCrash = {
	# pattern singleton
	_instance: nil,
	# Get the instance
	new: func (gears, stressLimit = nil, wingsFailureModes = nil) {

		var m = nil;
		if(me._instance == nil) {
			me._instance = {};
			me._instance["parents"] = [JsbsimCrash];

			m = me._instance;

			m.inService = FALSE;
			m.repairing = FALSE;

			m.exploded = FALSE;

			m.wingsAttached = TRUE;
			m.loopRunning = FALSE;
			m.wingLoadLimitUpper = nil;
			m.wingLoadLimitLower = nil;
			m.wingFailureModes = nil;

			m.input = {
				replay:     "sim/replay/replay-state",
				Nz:         "fdm/jsbsim/accelerations/Nz",
				lat:        "position/latitude-deg",
				lon:        "position/longitude-deg",
				alt:        "position/altitude-ft",
				altAgl:     "position/altitude-agl-ft",
				elev:       "position/ground-elev-ft",
				g3d:        "velocities/groundspeed-3D-kt",
				simTime:    "fdm/jsbsim/simulation/sim-time-sec",
				vgFps:      "fdm/jsbsim/velocities/vg-fps",
	  			downFps:    "velocities/down-relground-fps",
	  			crackOn:    "damage/sounds/crack-on",
				creakOn:    "damage/sounds/creaking-on",
			#	trembleOn:  "damage/g-tremble-on",
				crackVol:   "damage/sounds/crack-volume",
				creakVol:   "damage/sounds/creaking-volume",
			#	trembleMax: "damage/g-tremble-max",
				wCrashOn:   "damage/sounds/water-crash-on",
				crashOn:    "damage/sounds/crash-on",
				detachOn:   "damage/sounds/detach-on",
				explodeOn:  "damage/sounds/explode-on",
				weight:     "fdm/jsbsim/inertia/weight-lbs",
				fuel:       "fdm/jsbsim/propulsion/total-fuel-lbs",
			};
			foreach(var ident; keys(m.input)) {
			    m.input[ident] = props.globals.getNode(m.input[ident], 1);
			}

			m.wowStructure = [];
			m.wowGear = [];

			m.lastMessageTime = 0;


			m._identifyGears(gears);
			m.setStressLimit(stressLimit);
			m.setWingsFailureModes(wingsFailureModes);

			m._startImpactListeners();
		} else {
			m = me._instance;
		}

		return m;
	},
	# start the system
	start: func () {
		me.inService = TRUE;
	},
	# stop the system
	stop: func () {
		me.inService = FALSE;
	},
	# return TRUE if in progress
	isStarted: func () {
		return me.inService;
	},
	# repair the aircaft
	repair: func () {
		var failure_modes = FailureMgr._failmgr.failure_modes;
		var mode_list = keys(failure_modes);

		foreach(var failure_mode_id; mode_list) {
			FailureMgr.set_failure_level(failure_mode_id, 0);
		}
		me.wingsAttached = TRUE;
		me.exploded = FALSE;
		me.lastMessageTime = 0;
		me.repairing = TRUE;
		settimer(func {call(me._finishRepair, nil, me)}, 10);
	},
	# accepts a vector with failure mode IDs, they will fail when wings break off.
	setWingsFailureModes: func (modes) {
		me.wingFailureModes = modes;
	},
	# set the stresslimit for the main wings
	setStressLimit: func (stressLimit = nil) {
		if (stressLimit != nil) {
			var wingloadMax = stressLimit['wingloadMax'];
			var wingloadMin = stressLimit['wingloadMin'];
			var maxG = stressLimit['maxG'];
			var minG = stressLimit['minG'];
			var weight = stressLimit['weight'];
			if(wingloadMax != nil) {
				me.wingLoadLimitUpper = wingloadMax;
			} elsif (maxG != nil and weight != nil) {
				me.wingLoadLimitUpper = maxG * weight;
			}

			if(wingloadMin != nil) {
				me.wingLoadLimitLower = wingloadMin;
			} elsif (minG != nil and weight != nil) {
				me.wingLoadLimitLower = minG * weight;
			} elsif (me.wingLoadLimitUpper != nil) {
				me.wingLoadLimitLower = -me.wingLoadLimitUpper * 0.4;#estimate for when lower is not specified
			}
			me.loopRunning = TRUE;
			me._loop();			
		} else {
			me.loopRunning = FALSE;
		}
	},
	_identifyGears: func (gears) {
		var contacts = props.globals.getNode("/gear").getChildren("gear");

		foreach(var contact; contacts) {
			var index = contact.getIndex();
			var isGear = me._contains(gears, index);
			var wow = contact.getChild("wow");
			if (isGear == TRUE) {
				append(me.wowGear, wow);
			} else {
				append(me.wowStructure, wow);
			}
		}
	},	
	_finishRepair: func () {
		me.repairing = FALSE;
	},
	_isStructureInContact: func () {
		foreach(var structure; me.wowStructure) {
			if (structure.getBoolValue() == TRUE) {
				return TRUE;
			}
		}
		return FALSE;
	},
	_isGearInContact: func () {
		foreach(var gear; me.wowGear) {
			if (gear.getBoolValue() == TRUE) {
				return TRUE;
			}
		}
		return FALSE;
	},
	_contains: func (vector, content) {
		foreach(var vari; vector) {
			if (vari == content) {
				return TRUE;
			}
		}
		return FALSE;
	},
	_startImpactListeners: func () {
		foreach(var structure; me.wowStructure) {
			setlistener(structure, func {call(me._impactStructureListener, nil, me)},0,0);
		}
	},
	_impactGearListener: func () {
		# TODO: damage gear failure mode at high speed impact
	},
	_impactStructureListener: func () {
		#print("tst: "~me.inService~" "~me.input.replay.getBoolValue()~" "~me._isRunning()~" "~me.repairing);
		if (me.inService == TRUE and me.input.replay.getBoolValue() == FALSE and me._isRunning() == TRUE and me.repairing == FALSE) {
			#print("testing");
			var wow = me._isStructureInContact();
			if (wow == TRUE) {
				me._impactDamage();
			}
		}
	},
	_isRunning: func () {
		var time = me.input.simTime.getValue();
		if (time != nil and time > 1) {
			return TRUE;
		}
		return FALSE;
	},
	_calcGroundSpeed: func () {
		var horzSpeed = me.input.vgFps.getValue();
  		var vertSpeed = me.input.downFps.getValue();
  		var realSpeed = math.sqrt((horzSpeed * horzSpeed) + (vertSpeed * vertSpeed));
  		realSpeed = realSpeed * 0.5924838;#ft/s to kt
  		return realSpeed;
	},
	_impactDamage: func () {
	    var lat = me.input.lat.getValue();
		var lon = me.input.lon.getValue();
		var info = geodinfo(lat, lon);
		var solid = info[1] == nil?TRUE:info[1].solid;
		var speed = me._calcGroundSpeed();

		if (me.exploded == FALSE) {
			var failure_modes = FailureMgr._failmgr.failure_modes;
		    var mode_list = keys(failure_modes);
		    var probability = speed / 200.0;#200kt will fail everything, 0kt will fail nothing.

		    #test for explosion
		    if(probability > 1.0 and me.input.fuel.getValue() > 2500) {
		    	#200kt+ and fuel intanks will explode the aircraft on impact.
		    	me._explodeBegin();
		    	return;
		    }

		    foreach(var failure_mode_id; mode_list) {
		    	if(rand() < probability) {
		      		FailureMgr.set_failure_level(failure_mode_id, 1);
		      	}
		    }
			var str = "Aircraft hit "~info[1].names[size(info[1].names)-1]~".";
			me._output(str);
		} elsif (solid == TRUE) {
			var pos= geo.Coord.new().set_latlon(lat, lon);
			wildfire.ignite(pos, 1);
		}
		if(solid == TRUE) {
			#print("solid");
			me._impactSoundBegin(speed);
		} else {
			#print("water");
			me._impactSoundWaterBegin(speed);
		}
	},
	_impactSoundWaterBegin: func (speed) {
		if (speed > 5) {#check if sound already running?
			me.input.wCrashOn.setValue(1);
			settimer(func {call(me._impactSoundWaterEnd, nil, me)}, 3);
		}
	},
	_impactSoundWaterEnd: func	() {
		me.input.wCrashOn.setValue(0);
	},
	_impactSoundBegin: func (speed) {
		if (speed > 5) {
			me.input.crashOn.setValue(1);
			settimer(func {call(me._impactSoundEnd, nil, me)}, 3);
		}
	},
	_impactSoundEnd: func () {
		me.input.crashOn.setValue(0);
	},
	_explodeBegin: func() {
		me.input.explodeOn.setValue(1);
		me.exploded = TRUE;
		var failure_modes = FailureMgr._failmgr.failure_modes;
	    var mode_list = keys(failure_modes);

	    foreach(var failure_mode_id; mode_list) {
      		FailureMgr.set_failure_level(failure_mode_id, 1);
	    }

	    me._output("Aircraft exploded.", TRUE);

		settimer(func {call(me._explodeEnd, nil, me)}, 3);
	},
	_explodeEnd: func () {
		me.input.explodeOn.setValue(0);
	},
	_stressDamage: func (str) {
		me._output("Aircraft damaged: Wings broke off, due to "~str~" G forces.");
		me.input.detachOn.setValue(1);
		if (me.wingFailureModes != nil) {
			foreach(var failureModeId; me.wingFailureModes) {
	      		FailureMgr.set_failure_level(failureModeId, 1);
		    }
		}

		me.wingsAttached = FALSE;
		settimer(func {call(me._stressDamageEnd, nil, me)}, 3);
	},
	_stressDamageEnd: func () {
		me.input.detachOn.setValue(0);
	},
	_output: func (str, override = FALSE) {
		var time = me.input.simTime.getValue();
		if (override == TRUE or (time - me.lastMessageTime) > 3) {
			me.lastMessageTime = time;
			print(str);
			screen.log.write(str, 0.7098, 0.5372, 0.0);# solarized yellow
		}
	},
	_loop: func () {
		me._testStress();
		me._testWaterImpact();
		if(me.loopRunning == TRUE) {
			settimer(func {call(me._loop, nil, me)}, 0);
		}
	},
	_testWaterImpact: func () {
		if(me.input.altAgl.getValue() < 0) {
			var lat = me.input.lat.getValue();
			var lon = me.input.lon.getValue();
			var info = geodinfo(lat, lon);
			var solid = info[1] == nil?TRUE:info[1].solid;
			if(solid == FALSE) {
				me._impactDamage();
			}
		}
	},
	_testStress: func () {
		if (me.inService == TRUE and me.input.replay.getBoolValue() == FALSE and me._isRunning() == TRUE and me.repairing == FALSE and me.wingsAttached == TRUE) {
			var gForce = me.input.Nz.getValue() == nil?1:me.input.Nz.getValue();
			var weight = me.input.weight.getValue();
			var wingload = gForce * weight;

			#print("wingload: "~wingload~" max: "~me.wingLoadLimitUpper);
			var broken = FALSE;

			if(wingload < 0) {
				broken = me._testWingload(-wingload, -me.wingLoadLimitLower);
				if(broken == TRUE) {
					me._stressDamage("negative");
				}
			} else {
				broken = me._testWingload(wingload, me.wingLoadLimitUpper);
				if(broken == TRUE) {
					me._stressDamage("positive");
				}
			}
		} else {
			me.input.crackOn.setValue(0);
			me.input.creakOn.setValue(0);
			#me.input.trembleOn.setValue(0);
		}
	},
	_testWingload: func (wingload, wingLoadLimit) {
		if (wingload > (wingLoadLimit * 0.5)) {
			#me.input.trembleOn.setValue(1);
			var tremble_max = math.sqrt((wingload - (wingLoadLimit * 0.5)) / (wingLoadLimit * 0.5));
			#me.input.trembleMax.setValue(1);

			if (wingload > (wingLoadLimit * 0.75)) {

				#tremble_max = math.sqrt((wingload - (wingLoadLimit * 0.5)) / (wingLoadLimit * 0.5));
				me.input.creakVol.setValue(tremble_max);
				me.input.creakOn.setValue(1);

				if (wingload > (wingLoadLimit * 0.90)) {
					me.input.crackOn.setValue(1);
					me.input.crackVol.setValue(tremble_max);
					if (wingload > wingLoadLimit) {
						me.input.crackVol.setValue(1);
						me.input.creakVol.setValue(1);
						#me.input.trembleMax.setValue(1);
						return TRUE;
					}
				} else {
					me.input.crackOn.setValue(0);
				}
			} else {
				me.input.creakOn.setValue(0);
			}
		} else {
			me.input.crackOn.setValue(0);
			me.input.creakOn.setValue(0);
			#me.input.trembleOn.setValue(0);
		}
		return FALSE;
	},
};

# TODO:
#
# Loss of inertia if impacting/sliding? Or should the jsb groundcontacts take care of that alone?
# If gears hit something at too high speed the gears should be damaged?
# Make property to control if system active, or method enough?
# Explosion depending on bumpiness and speed when sliding?
# Tie in with damage from Bombable?


# example uses:
#
# var crashCode = JsbsimCrash.new([0,1,2]; 
#
# var crashCode = JsbsimCrash.new([0,1,2], {"weight":30000, "maxG": 12}, ["fdm/jsbsim/fcs/wings"]);
#
# var crashCode = JsbsimCrash.new([0,1,2,3], {"weight":20000, "maxG": 11, "minG": -5});
#
# var crashCode = JsbsimCrash.new([0,1,2], {"wingloadMax": 90000, "wingloadMin": -45000}, ["fdm/jsbsim/fcs/wings"]);
#
# var crashCode = JsbsimCrash.new([0,1,2], {"wingloadMax":90000}, ["controls/flight/aileron", "controls/flight/elevator", "controls/flight/flaps"]);
#
# Gears parameter must be defined.
# Stress parameter is optional. If minimum wing stress is not defined it will be set to -40% of max wingload stress if that is defined.
# The last optional parameter is a list of failure mode IDs that shall fail when wings detach. They must be defined in the FailureMgr.
#
#
# Remember to add sounds and to add the sound properties as custom signals to the replay recorder.


# use:
var crashCode = JsbsimCrash.new([0,1,2], {"weight":30000, "maxG": 12}, ["fdm/jsbsim/fcs/wings"]);
crashCode.start();

# test:
var repair = func {
	crashCode.repair();
};