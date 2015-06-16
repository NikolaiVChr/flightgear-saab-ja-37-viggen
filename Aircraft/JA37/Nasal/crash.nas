var didMsg = 0;
var repairing = 0;

#-----------------------------------------------------------------------
#Aircraft break

input = {
	replay: "sim/replay/replay-state",
	service: "sim/ja37/damage/enabled",
	Nz: "fdm/jsbsim/accelerations/Nz",
	lat: "position/latitude-deg",
	lon: "position/longitude-deg",
	alt: "position/altitude-ft",
	elev: "position/ground-elev-ft",
	g3d:     "/velocities/groundspeed-3D-kt",
	exploded: "sim/ja37/damage/exploded",
    crashed: "sim/ja37/damage/crashed",
    wow0:    "/gear/gear[0]/wow",
    wow1:  "/gear/gear[1]/wow",
    wow2:  "/gear/gear[2]/wow",
    wow3:  "/gear/gear[3]/wow",
    wow4:  "/gear/gear[4]/wow",
    wow5:  "/gear/gear[5]/wow",
    wow6:  "/gear/gear[6]/wow",
    wow7:  "/gear/gear[7]/wow",
    wow8:  "/gear/gear[8]/wow",
    wow9:  "/gear/gear[9]/wow",
    wow10:  "/gear/gear[10]/wow",
    wow11:  "/gear/gear[11]/wow",
};
   
foreach(var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}

var timerDelay = 0.2;

crashLoop=func {
	#print("crashLoop");
	# check state
	if ((input.replay.getValue() != nil) and (input.replay.getValue() == 1) or getprop("sim/time/full-init") == 0) {
		stop_crashLoop();
		return ( settimer(crashLoop, timerDelay) ); 
	}
	in_service = input.service.getValue();
	if (in_service == nil) {
		print("not in service: nil");
		stop_crashLoop();
		return ( settimer(crashLoop, timerDelay) ); 
	}
	if ( in_service != 1 ) {
	#print("In service: false");
		stop_crashLoop();
		return ( settimer(crashLoop, timerDelay) ); 
	}
	#print("In service: true");
	pilot_g=input.Nz.getValue();
	maximum_g=14;#the real ja37 can handle 12G
	lat = input.lat.getValue();
	lon = input.lon.getValue();
	#check altitude positions
	altitude=input.alt.getValue();
	elevation=input.elev.getValue();
	speed=input.g3d.getValue();
	exploded=input.exploded.getValue();
	crashed=input.crashed.getValue();
	var wow=[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
	wow[0]=input.wow0.getValue();
	wow[1]=input.wow1.getValue();
	wow[2]=input.wow2.getValue();
	wow[3]=input.wow3.getValue();
	wow[4]=input.wow4.getValue();
	wow[5]=input.wow5.getValue();
	wow[6]=input.wow6.getValue();
	wow[7]=input.wow7.getValue();
	wow[8]=input.wow8.getValue();
	wow[9]=input.wow9.getValue();
	wow[10]=input.wow10.getValue();
	wow[11]=input.wow11.getValue();
	if (
		(pilot_g==nil)
		or (maximum_g==nil)
		or (lat==nil)
		or (lon==nil)
		or (altitude==nil)
		or (elevation==nil)
		or (speed==nil)
		or (exploded==nil)
		or (crashed==nil)
		or (wow[0]==nil)
		or (wow[1]==nil)
		or (wow[2]==nil)
		or (wow[3]==nil)
		or (wow[4]==nil)
		or (wow[5]==nil)
		or (wow[6]==nil)
		or (wow[7]==nil)
		or (wow[8]==nil)
		or (wow[9]==nil)
		or (wow[10]==nil)
		or (wow[11]==nil)
	) {
		#print("Something nil");
		stop_crashLoop();
		return ( settimer(crashLoop, timerDelay) ); 
	}
	speed_km=speed*1.852;
	info = geodinfo(lat, lon);
	if (info == nil) {
		stop_crashLoop();
		return ( settimer(crashLoop, timerDelay) ); 
	}
	if ((info[0] == nil) or (info[1] == nil)) {
		stop_crashLoop();
		return ( settimer(crashLoop, timerDelay) ); 
	}
	real_altitude_m = (0.3048*(altitude-elevation));
	
	if ((real_altitude_m<=25) and (speed_km>10)	) {
		terrain_lege_height=0;
		i=0;
		var hit_what = "hit something";
		foreach(terrain_name; info[1].names) {
			if ((terrain_lege_height<25)
				and
				(
					(terrain_name=="EvergreenForest")
					or (terrain_name=="DeciduousForest")
					or (terrain_name=="MixedForest")
					or (terrain_name=="RainForest")
				)
			) {
				terrain_lege_height=25;
				hit_what = "hit tree in "~terrain_name;
			}
			if ((terrain_lege_height<25)
				and
				(
					(terrain_name=="Urban")
					or (terrain_name=="SubUrban")
					or (terrain_name=="Town")
				)
			) {
				terrain_lege_height=25;
				hit_what = "hit building in "~terrain_name;
			}

			if ((terrain_lege_height<20)
				and
				(
					(terrain_name=="Orchard")
					or (terrain_name=="CropWood")

				)
			) {
				terrain_lege_height=20;
				hit_what = "hit tree in "~terrain_name;
			}
			if ((terrain_lege_height<1)
				and
				(
					(terrain_name=="Ocean")
					or (terrain_name=="Lake")
				)
			)
			{
				terrain_lege_height=1;
				hit_what = "hit water wave in "~terrain_name;
			}
			if ((terrain_lege_height<0.25)
				and
				(
					(terrain_name=="Heath")
				)
			) {
				terrain_lege_height=.25;
				hit_what = "hit bush in "~terrain_name;
			}
			if ((terrain_lege_height<.1)
				and
				(
					(terrain_name=="Pond")
					or (terrain_name=="Resevoir")
					or (terrain_name=="Steam")
					or (terrain_name=="Canal")
					or (terrain_name=="Lagoon")
					or (terrain_name=="Estuary")
					or (terrain_name=="Watercourse")
					or (terrain_name=="Saline")
				)
			) {
				terrain_lege_height=.1;
				hit_what = "hit water wave in "~terrain_name;
			}

		}
		#print(real_altitude_m - terrain_lege_height);
		if (real_altitude_m<terrain_lege_height) {
			crashed=aircraft_crash(hit_what, pilot_g, info[1].solid);
			#print(terrain_name);
		}
	}
	if (pilot_g>(maximum_g*0.5)) {
		if (pilot_g>maximum_g) {
			setprop("sim/ja37/damage/sounds/crack-volume", 1);
			setprop("sim/ja37/damage/sounds/creaking-volume", 1);
			setprop("sim/ja37/damage/g-tremble-max", 1);
		} else {
			tremble_max=math.sqrt((pilot_g-(maximum_g*0.5))/(maximum_g*0.5));
			setprop("sim/ja37/damage/sounds/crack-volume", tremble_max);
			setprop("sim/ja37/damage/g-tremble-max", 1);
			if (pilot_g>(maximum_g*0.75)) {
				tremble_max=math.sqrt((pilot_g-(maximum_g*0.5))/(maximum_g*0.5));
				setprop("sim/ja37/damage/sounds/creaking-volume", tremble_max);
				setprop("sim/ja37/damage/sounds/creaking-on", 1);
			} else {
				setprop("sim/ja37/damage/sounds/creaking-on", 0);
			}
		}
		if (pilot_g>(maximum_g*0.90)) {
			setprop("sim/ja37/damage/sounds/crack-on", 1);
		} else {
			setprop("sim/ja37/damage/sounds/crack-on", 0);
		}
		setprop("sim/ja37/damage/g-tremble-on", 1);
	} else {
		setprop("sim/ja37/damage/sounds/crack-on", 0);
		setprop("sim/ja37/damage/sounds/creaking-on", 0);
		setprop("sim/ja37/damage/g-tremble-on", 0);
	}
	if (exploded !=1 and abs(pilot_g) > maximum_g) {
		print("Aircraft crashed: Wing broke off, due to G forces.");
		setprop("/sim/messages/atc", "Aircraft crashed: Wing broke off, due to G forces.");
		exploded=1;
		damageOnWingsBreak();
		aircraft_explode(pilot_g);
	}
	if ((
			(wow[3]==1)
			or (wow[4]==1)
			or (wow[5]==1)
			or (wow[6]==1)
			or (wow[7]==1)
			or (wow[8]==1)
			or (wow[9]==1)
			or (wow[10]==1)
			or (wow[11]==1)
		) and ((speed_km>275) or (pilot_g>2.5) or ((speed_km>250) and (
		        	(info[1].solid!=1)
					or (info[1].bumpiness>0.1)
					or (info[1].rolling_friction>0.05)
					or (info[1].friction_factor<0.7)
				)
			)
		)
	) {
		crashed=aircraft_crash("slide", pilot_g, info[1].solid);
	}
	if (crashed==1)	{
		if (exploded==0) {
			exploded=1;
			aircraft_explode(pilot_g);
		}
		if (
			(
				(wow[3]==1)
				or (wow[4]==1)
				or (wow[5]==1)
				or (wow[6]==1)
				or (wow[7]==1)
				or (wow[8]==1)
				or (wow[9]==1)
				or (wow[10]==1)
				or (wow[11]==1)
			)
			and (speed_km>10)
		) {
			var pos = geo.Coord.new().set_latlon(lat, lon);
			setprop("fdm/jsbsim/simulation/wildfire-ignited", 1);
			wildfire.ignite(pos, 1);
		}
	}
	settimer(
		#func debug.benchmark("crs loop", 
			crashLoop
			#)
	, timerDelay);
}

stop_crashLoop = func {
}

aircraft_crash = func(crashtype, crashg, solid) {
  	print("Aircraft crashed: "~ crashtype);
  	if (didMsg == 0) {
  		setprop("/sim/messages/atc", "Aircraft crashed: "~ crashtype);
  		didMsg = 1;
  	}
	crashed=getprop("sim/ja37/damage/crashed");
	if (crashed==nil) {
		return (0);
	}
	if (crashed==0)	{
		setprop("sim/ja37/damage/crash-type", crashtype);
		setprop("sim/ja37/damage/crash-g", crashg);
		setprop("sim/ja37/damage/crashed", 1);
		damageOnHit();
	}

	if (solid==1) {
		aircraft_crash_sound();
	} else {
		aircraft_water_crash_sound();
	}	

	#setprop("sim/replay/disable", 1);
	#setprop("sim/menubar/default/menu[1]/item[8]/enabled", 0);
	return (1);
}

aircraft_crash_sound = func	{
	speed=getprop("/velocities/groundspeed-3D-kt");
	sounded=getprop("sim/ja37/damage/sounds/crash-on");
	if ((speed!=nil) and (sounded!=nil))
	{
		speed_km=speed*1.852;
		if ((speed_km>10) and (sounded==0))
		{
			setprop("sim/ja37/damage/sounds/crash-on", 1);
			settimer(end_aircraft_crash, 3);
		}
	}
}

end_aircraft_crash = func {
	setprop("sim/ja37/damage/sounds/crash-on", 0);
}

aircraft_water_crash_sound = func {
	speed=getprop("velocities/groundspeed-3D-kt");
	sounded=getprop("sim/ja37/damage/sounds/water-crash-on");
	if ((speed!=nil) and (sounded!=nil))
	{
		speed_km=speed*1.852;
		if ((speed_km>10) and (sounded==0))
		{
			setprop("sim/ja37/damage/sounds/water-crash-on", 1);
			settimer(end_aircraft_water_crash, 3);
		}
	}
}

end_aircraft_water_crash = func	{
	setprop("sim/ja37/damage/sounds/water-crash-on", 0);
}

repair = func {
	setprop("sim/ja37/damage/exploded", 0);
	setprop("sim/ja37/damage/crashed", 0);
	setprop("sim/ja37/damage/explode-g", 0);
	setprop("sim/ja37/damage/sounds/crack-on", 0);
	setprop("sim/ja37/damage/crash-type", "");
	setprop("sim/ja37/damage/crash-g", 0);
	setprop("fdm/jsbsim/velocities/v-down-previous", 0);
	setprop("sim/ja37/damage/enabled", 1);
	#setprop("fdm/jsbsim/propulsion/tank[4]/external-flow-rate-pps", 0);
	#setprop("fdm/jsbsim/propulsion/tank[5]/external-flow-rate-pps", 0);
	#setprop("fdm/jsbsim/propulsion/tank[6]/external-flow-rate-pps", 0);
	#setprop("fdm/jsbsim/propulsion/tank[7]/external-flow-rate-pps", 0);

	if(getprop("sim/ja37/failures/installed") == 1) {
		unfailAll();
	} else {
		setServiceable();
	}
	didMsg = 0;
	repairing = 1;
	settimer(doRepair, 6);
}

doRepair = func {
	#allow for landing gear to extend before crashing again
	repairing = 0;
}

unfailAll = func {
	var failure_modes = FailureMgr._failmgr.failure_modes; # hash with the failure modes
	var mode_list = keys(failure_modes);#values()?

	foreach(var failure_mode_id; mode_list) {
			FailureMgr.set_failure_level(failure_mode_id, 0);
	}
	if(FailureMgr.get_trigger("controls/gear0") == nil) {
		print("JA-37: Failed to reset trigger for gear0, it seems to be removed don't know why!");
	} else {
		FailureMgr.get_trigger("controls/gear0").reset();
	}
	if(FailureMgr.get_trigger("controls/gear1") == nil) {
		print("JA-37: Failed to reset trigger for gear2, it seems to be removed don't know why!");
	} else {
		FailureMgr.get_trigger("controls/gear1").reset();
	}
	if(FailureMgr.get_trigger("controls/gear2") == nil) {
		print("JA-37: Failed to reset trigger for gear2, it seems to be removed don't know why!");
	} else {
		FailureMgr.get_trigger("controls/gear2").reset();
	}
	if(FailureMgr.get_trigger("/fdm/jsbsim/fcs/canopy") == nil) {
		print("JA-37: Failed to reset trigger for canopy motor, it seems to be removed don't know why!");
	} else {
		FailureMgr.get_trigger("/fdm/jsbsim/fcs/canopy").reset();
	}
	if(FailureMgr.get_trigger("/fdm/jsbsim/fcs/canopy/hinges") == nil) {
		print("JA-37: Failed to reset trigger for canopy hinges, it seems to be removed don't know why!");
	} else {
		FailureMgr.get_trigger("/fdm/jsbsim/fcs/canopy/hinges").reset();
	}
}

initCrash=func {
	if(getprop("sim/time/full-init") == 0) {
		settimer(initCrash, 1);
	} else {
		repair();
	}
}

setServiceable = func {
	#print("initCrash");

	#Start instruments
	setprop("instrumentation/clock/serviceable", 1);
	setprop("instrumentation/manometer/serviceable", 1);
	setprop("instrumentation/gear-indicator/serviceable", 1);
	setprop("instrumentation/flaps-lamp/serviceable", 1);
	setprop("instrumentation/fuelometer/serviceable", 1);
	setprop("instrumentation/altimeter-lamp/serviceable", 1);
	setprop("instrumentation/gear-lamp/serviceable", 1);
	setprop("instrumentation/oxygen-pressure-meter/serviceable", 1);
	setprop("instrumentation/brake-pressure-meter/serviceable", 1);
	setprop("instrumentation/ignition-lamp/serviceable", 1);
	setprop("instrumentation/gastermometer/serviceable", 1);
	setprop("instrumentation/motormeter/serviceable", 1);
	setprop("instrumentation/machometer/serviceable", 1);
	setprop("instrumentation/turnometer/serviceable", 1);
	setprop("instrumentation/vertspeedometer/serviceable", 1);
	setprop("instrumentation/gear-pressure-indicator/serviceable", 1);
	setprop("instrumentation/flaps-pressure-indicator/serviceable", 1);
	setprop("instrumentation/marker-beacon/serviceable", 1);
	setprop("/instrumentation/head-up-display/serviceable", 1);
	setprop("/instrumentation/instrumentation-light/serviceable", 1);
	setprop("/instrumentation/radar/serviceable", 1);
	setprop("/fdm/jsbsim/fcs/canopy/serviceable", 1);

	#JSB instruments and controls
	setprop("fdm/jsbsim/systems/airspeedometer/serviceable", 1);
	setprop("fdm/jsbsim/systems/vertspeedometer/serviceable", 1);
	setprop("fdm/jsbsim/systems/arthorizon/serviceable", 1);
	setprop("fdm/jsbsim/systems/tachometer/serviceable", 1);
	setprop("fdm/jsbsim/systems/headsight/serviceable", 1);
	setprop("fdm/jsbsim/systems/gascontrol/serviceable", 1);
	setprop("fdm/jsbsim/systems/flapscontrol/serviceable", 1);
	setprop("fdm/jsbsim/systems/rightpanel/serviceable", 1);
	setprop("fdm/jsbsim/systems/stopcontrol/serviceable", 1);
	setprop("fdm/jsbsim/systems/leftpanel/serviceable", 1);
	setprop("fdm/jsbsim/systems/ignitionbuton/serviceable", 1);
	setprop("fdm/jsbsim/systems/speedbrakescontrol/serviceable", 1);
	setprop("fdm/jsbsim/systems/radioaltimeter/serviceable", 1);
	setprop("fdm/jsbsim/systems/stick/serviceable", 1);
	setprop("fdm/jsbsim/systems/pedals/serviceable", 1);
	setprop("fdm/jsbsim/systems/gearvalve/serviceable", 1);
	setprop("fdm/jsbsim/systems/flapsvalve/serviceable", 1);
	setprop("fdm/jsbsim/systems/boostercontrol/serviceable", 1);
	setprop("fdm/jsbsim/systems/gyrocompass/serviceable", 1);
	setprop("fdm/jsbsim/systems/altimeter/serviceable", 1);

	#Unlock controls
	setprop("instrumentation/gear-control/serviceable", 1);
	setprop("fdm/jsbsim/gear/unit[0]/z-position", -82.67716548);
	setprop("fdm/jsbsim/gear/unit[1]/z-position", -82.67716548);
	setprop("fdm/jsbsim/gear/unit[2]/z-position", -82.67716548);

	setprop("instrumentation/flaps-control/serviceable", 1);
	setprop("instrumentation/speed-brake-control/serviceable", 1);
	setprop("instrumentation/ignition-button/serviceable", 1);
	setprop("instrumentation/cannon/serviceable", 1);
	setprop("instrumentation/trimmer/serviceable", 1);
	setprop("fdm/jsbsim/systems/radiocompass/serviceable", 1);
	setprop("instrumentation/photo/serviceable", 1);
	setprop("instrumentation/drop-tank/serviceable", 1);
	setprop("instrumentation/pedals/serviceable", 1);
	setprop("fdm/jsbsim/structural/wings/serviceable", 1);
	setprop("controls/flight/aileron/serviceable", 1);
	setprop("controls/flight/elevator/serviceable", 1);

	#Switch on engine
	setprop("controls/engines/engine/cutoff", 0);
	setprop("sim/ja37/damage/cutoff-reason", "aircraft break");
}

damageOnHit = func {
	if(getprop("sim/ja37/failures/installed") == 1) {
		failAll();
	} else {
		aircraft_lock_all();
	}
}

damageOnWingsBreak = func {
	if(getprop("sim/ja37/failures/installed") == 1) {
		failWings();
	} else {
		aircraft_lock_wings();
	}
	#setprop("fdm/jsbsim/propulsion/tank[4]/external-flow-rate-pps", -75);
	#setprop("fdm/jsbsim/propulsion/tank[5]/external-flow-rate-pps", -75);
	#setprop("fdm/jsbsim/propulsion/tank[6]/external-flow-rate-pps", -75);
	#setprop("fdm/jsbsim/propulsion/tank[7]/external-flow-rate-pps", -75);
}

failWings = func {
	FailureMgr.set_failure_level("fdm/jsbsim/structural/wings", 1);
#	FailureMgr.set_failure_level("controls/flight/aileron", 1);
#	FailureMgr.set_failure_level("controls/flight/elevator", 1);
#	FailureMgr.set_failure_level("controls/gear1", 1);
#	FailureMgr.set_failure_level("controls/gear2", 1);
}

failAll = func {# fail randomly systems depending on speed
	var failure_modes = FailureMgr._failmgr.failure_modes; # hash with the failure modes
    var mode_list = keys(failure_modes);#values()?
    var probability = input.g3d.getValue()/200;#200kt will fail everything, 0kt will fail nothing.
    foreach(var failure_mode_id; mode_list) {
    	if(rand() < probability) {
      		FailureMgr.set_failure_level(failure_mode_id, 1);
      	}
    }
}

aircraft_lock_wings = func {
	setprop("controls/flight/aileron/serviceable", 0);
	setprop("controls/flight/elevator/serviceable", 0);
	setprop("fdm/jsbsim/structural/wings/serviceable", 0);
	setprop("fdm/jsbsim/gear/unit[0]/z-position", 0.001);
	setprop("fdm/jsbsim/gear/unit[1]/z-position", 0.001);
	setprop("fdm/jsbsim/gear/unit[2]/z-position", 0.001);
}

aircraft_lock_all = func {
	#print("aircraft_lock");
	aircraft_lock_wings();
	#Stop instruments
	setprop("instrumentation/clock/serviceable", 0);
	setprop("instrumentation/manometer/serviceable", 0);
	setprop("instrumentation/gear-indicator/serviceable", 0);
	setprop("instrumentation/flaps-lamp/serviceable", 0);
	setprop("instrumentation/fuelometer/serviceable", 0);
	setprop("instrumentation/altimeter-lamp/serviceable", 0);
	setprop("instrumentation/gear-lamp/serviceable", 0);
	setprop("instrumentation/oxygen-pressure-meter/serviceable", 0);
	setprop("instrumentation/brake-pressure-meter/serviceable", 0);
	setprop("instrumentation/ignition-lamp/serviceable", 0);
	setprop("instrumentation/gastermometer/serviceable", 0);
	setprop("instrumentation/motormeter/serviceable", 0);
	setprop("instrumentation/machometer/serviceable", 0);
	setprop("instrumentation/turnometer/serviceable", 0);
	setprop("instrumentation/vertspeedometer/serviceable", 0);
	setprop("instrumentation/gear-pressure-indicator/serviceable", 0);
	setprop("instrumentation/flaps-pressure-indicator/serviceable", 0);
	setprop("instrumentation/marker-beacon/serviceable", 0);

	#JSB instruments and controls
	setprop("fdm/jsbsim/systems/airspeedometer/serviceable", 0);
	setprop("fdm/jsbsim/systems/vertspeedometer/serviceable", 0);
	setprop("fdm/jsbsim/systems/arthorizon/serviceable", 0);
	setprop("fdm/jsbsim/systems/tachometer/serviceable", 0);
	setprop("fdm/jsbsim/systems/headsight/serviceable", 0);
	setprop("fdm/jsbsim/systems/gascontrol/serviceable", 0);
	setprop("fdm/jsbsim/systems/flapscontrol/serviceable", 0);
	setprop("fdm/jsbsim/systems/rightpanel/serviceable", 0);
	setprop("fdm/jsbsim/systems/stopcontrol/serviceable", 0);
	setprop("fdm/jsbsim/systems/leftpanel/serviceable", 0);
	setprop("fdm/jsbsim/systems/ignitionbuton/serviceable", 0);
	setprop("fdm/jsbsim/systems/speedbrakescontrol/serviceable", 0);
	setprop("fdm/jsbsim/systems/radioaltimeter/serviceable", 0);
	setprop("fdm/jsbsim/systems/stick/serviceable", 0);
	setprop("fdm/jsbsim/systems/pedals/serviceable", 0);
	setprop("fdm/jsbsim/systems/gearvalve/serviceable", 0);
	setprop("fdm/jsbsim/systems/flapsvalve/serviceable", 0);
	setprop("fdm/jsbsim/systems/boostercontrol/serviceable", 0);
	setprop("fdm/jsbsim/systems/gyrocompass/serviceable", 0);
	setprop("fdm/jsbsim/systems/altimeter/serviceable", 0);
	setprop("/instrumentation/head-up-display/serviceable", 0);
	setprop("/instrumentation/instrumentation-light/serviceable", 0);
	setprop("/instrumentation/radar/serviceable", 0);

	#Lock controls
	setprop("instrumentation/gear-control/serviceable", 0);
	setprop("instrumentation/flaps-control/serviceable", 0);
	setprop("instrumentation/speed-brake-control/serviceable", 0);
	setprop("instrumentation/ignition-button/serviceable", 0);
	setprop("instrumentation/cannon/serviceable", 0);
	setprop("instrumentation/trimmer/serviceable", 0);
	setprop("fdm/jsbsim/systems/radiocompass/serviceable", 0);
	setprop("instrumentation/photo/serviceable", 0);
	setprop("instrumentation/drop-tank/serviceable", 0);
	setprop("instrumentation/pedals/serviceable", 0);

	#Switch off engine
	setprop("controls/engines/engine/cutoff", 1);
	setprop("sim/ja37/damage/cutoff-reason", "unknown");
}

aircraft_explode = func(pilot_g) {
	#print("aircraft_explode");
	setprop("sim/ja37/damage/explode-g", pilot_g);
	setprop("sim/ja37/damage/exploded", 1);
	setprop("sim/ja37/damage/sounds/explode-on", 1);
	#setprop("sim/replay/disable", 1);
	#setprop("sim/menubar/default/menu[1]/item[8]/enabled", 0);
	settimer(end_aircraft_explode, 3);
}

end_aircraft_explode = func	{
	#print("end_aircraft_explode");
	setprop("sim/ja37/damage/sounds/explode-on", 0);
}



#--------------------------------------------------------------------
# Aircraft breaks listener

# helper 
stop_crashListener = func {
}

crashListener = func {
	# check state
	in_service = input.service.getValue();
	if (in_service == nil or repairing == 1) {
		return ( stop_crashListener );
	}
	if ( in_service != 1 ) {
		return ( stop_crashListener );
	}

	pilot_g=input.Nz.getValue();
	lat = input.lat.getValue();
	lon = input.lon.getValue();
	exploded=input.exploded.getValue();
	crashed=input.crashed.getValue();
	var wow=[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
	wow[0]=input.wow0.getValue();
	wow[1]=input.wow1.getValue();
	wow[2]=input.wow2.getValue();
	wow[3]=input.wow3.getValue();
	wow[4]=input.wow4.getValue();
	wow[5]=input.wow5.getValue();
	wow[6]=input.wow6.getValue();
	wow[7]=input.wow7.getValue();
	wow[8]=input.wow8.getValue();
	wow[9]=input.wow9.getValue();
	wow[10]=input.wow10.getValue();
	wow[11]=input.wow11.getValue();

	gear_started=getprop("fdm/jsbsim/simulation/sim-time-sec") != nil and getprop("fdm/jsbsim/simulation/sim-time-sec") > 1;
	if (
		(pilot_g==nil)
		or (lat==nil)
		or (lon==nil)
		or (exploded==nil)
		or (crashed==nil)
		or (wow[0]==nil)
		or (wow[1]==nil)
		or (wow[2]==nil)
		or (wow[3]==nil)
		or (wow[4]==nil)
		or (wow[5]==nil)
		or (wow[6]==nil)
		or (wow[7]==nil)
		or (wow[8]==nil)
		or (wow[9]==nil)
		or (wow[10]==nil)
		or (wow[11]==nil)
		or (gear_started==nil)
	)
	{
		return ( stop_crashListener ); 
	}
	if (gear_started==0)
	{
		return ( stop_crashListener ); 
	}
	if (
		(
			(wow[3]==1)
			or (wow[4]==1)
			or (wow[5]==1)
			or (wow[6]==1)
			or (wow[7]==1)
			or (wow[8]==1)
			or (wow[9]==1)
			or (wow[10]==1)
			or (wow[11]==1)
		)
#			or
#			(
#				(
#					(wow[3]==1)
#					or (wow[4]==1)
#					or (wow[5]==1)
#				)
#				and (pilot_g>3)
#			)
	#	or (
	#		(tanks_fastened==1)
	#		and (pilot_g>1.5)
	#		and 
	#		(
	#			((wow[3]==1) and (wow[7]==1))    ja37: adapt this for droptank later
	#			or
	#			((wow[4]==1) and (wow[7]==1))
	#		)
	#	)
	)
	{
		info = geodinfo(lat, lon);
		if (info == nil)
		{
			return ( stop_crashListener ); 
		}
		if (info[1]==nil)
		{
			return ( stop_crashListener ); 
		}
		crashed=aircraft_crash("Ground hit", pilot_g, info[1].solid);
		if (exploded==0)
		{
			exploded=1;
			aircraft_explode(pilot_g);
		}
	}
}

init_crashListener = func {
#print("init_crashListener");
	setprop("sim/ja37/damage/sounds/crash-on", 0);
	setprop("sim/ja37/damage/sounds/water-crash-on", 0);
	#setprop("sim/ja37/damage/break-listener", 1);
}


var crash_start = func {
	removelistener(lsnr);
	if (getprop("sim/ja37/supported/crash-system") == 0) {

		#Start
		initCrash();
		crashLoop();

		init_crashListener();

		setlistener("gear/gear[3]/wow", crashListener, 0, 0);
		setlistener("gear/gear[4]/wow", crashListener, 0, 0);
		setlistener("gear/gear[5]/wow", crashListener, 0, 0);
		setlistener("gear/gear[6]/wow", crashListener, 0, 0);
		setlistener("gear/gear[7]/wow", crashListener, 0, 0);
		setlistener("gear/gear[8]/wow", crashListener, 0, 0);
		setlistener("gear/gear[9]/wow", crashListener, 0, 0);
		setlistener("gear/gear[10]/wow", crashListener, 0, 0);
		setlistener("gear/gear[11]/wow", crashListener, 0, 0);

	}
}
var lsnr = setlistener("sim/ja37/supported/initialized", crash_start);

