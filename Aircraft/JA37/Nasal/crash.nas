

#-----------------------------------------------------------------------
#Aircraft break
aircraft_lock = func 
	{
	#print("aircraft_lock");
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
		setprop("engines/engine/cutoff-reason", "aircraft break");
	}

aircraft_crash=func(crashtype, crashg, solid)
	{
	  print("Aircraft crashed: "~ crashtype);
		crashed=getprop("fdm/jsbsim/simulation/crashed");
		if (crashed==nil)
		{
			return (0);
		}
		if (crashed==0)
		{
			setprop("fdm/jsbsim/simulation/crash-type", crashtype);
			setprop("fdm/jsbsim/simulation/crash-g", crashg);
			setprop("fdm/jsbsim/simulation/crashed", 1);
			aircraft_lock();
		}

		gear_pos=getprop("fdm/jsbsim/gear/unit[0]/pos-norm-real");
		if (gear_pos!=nil)
		{
			if (gear_pos>0)
			{
				teargear(0, "crash");
			}
		}

		gear_pos=getprop("fdm/jsbsim/gear/unit[1]/pos-norm-real");
		if (gear_pos!=nil)
		{
			if (gear_pos>0)
			{
				teargear(1, "crash");
			}
		}

		gear_pos=getprop("fdm/jsbsim/gear/unit[2]/pos-norm-real");
		if (gear_pos!=nil)
		{
			if (gear_pos>0)
			{
				teargear(2, "crash");
			}
		}

		if (solid==1)
		{
			aircraft_crash_sound();
		}
		else
		{
			aircraft_water_crash_sound();
		}

		

		#setprop("sim/replay/disable", 1);
		#setprop("sim/menubar/default/menu[1]/item[8]/enabled", 0);
		return (1);
	}

stop_aircraftbreakprocess = func 
	{
	}

aircraftbreakprocess=func
	{
	#print("aircraftbreakprocess");
		# check state
		if ((getprop("sim/replay/replay-state") != nil) and (getprop("sim/replay/replay-state") == 1))
		{
			stop_aircraftbreakprocess();
			return ( settimer(aircraftbreakprocess, 0.1) ); 
		}
		in_service = getprop("processes/aircraft-break/enabled" );
		if (in_service == nil)
		{
		print("not in service: nil");
			stop_aircraftbreakprocess();
			return ( settimer(aircraftbreakprocess, 0.1) ); 
		}
		if ( in_service != 1 )
		{
		print("In service: false");
			stop_aircraftbreakprocess();
			return ( settimer(aircraftbreakprocess, 0.1) ); 
		}
		#print("In service: true");
		pilot_g=getprop("fdm/jsbsim/accelerations/Nz");
		maximum_g=14;
		lat = getprop("position/latitude-deg");
		lon = getprop("position/longitude-deg");
		#check altitude positions
		altitude=getprop("position/altitude-ft");
		elevation=getprop("position/ground-elev-ft");
		speed=getprop("/velocities/groundspeed-3D-kt");
		exploded=getprop("fdm/jsbsim/simulation/exploded");
		crashed=getprop("fdm/jsbsim/simulation/crashed");
		var wow=[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
		#Gear middle
		wow[0]=getprop("gear/gear[0]/wow");
		#Gear left
		wow[1]=getprop("gear/gear[1]/wow");
		#Gear right
		wow[2]=getprop("gear/gear[2]/wow");
		#Wing Left
		wow[3]=getprop("gear/gear[3]/wow");
		#Wing right
		wow[4]=getprop("gear/gear[4]/wow");
		#Fus nose down
		wow[5]=getprop("gear/gear[5]/wow");
		#Fus nose up
		wow[6]=getprop("gear/gear[6]/wow");
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
		)
		{
		#print("Something nil");
			stop_aircraftbreakprocess();
			return ( settimer(aircraftbreakprocess, 0.1) ); 
		}
		speed_km=speed*1.852;
		info = geodinfo(lat, lon);
		if (info == nil)
		{
			stop_aircraftbreakprocess();
			return ( settimer(aircraftbreakprocess, 0.1) ); 
		}
		if (
			(info[0] == nil)
			or (info[1] == nil)
		)
		{
			stop_aircraftbreakprocess();
			return ( settimer(aircraftbreakprocess, 0.1) ); 
		}
		real_altitude_m = (0.3048*(altitude-elevation));
		
		if (
			(real_altitude_m<=25)
			and (speed_km>10)
		)
		{
			terrain_lege_height=0;
			i=0;
			foreach(terrain_name; info[1].names)
			{
				if (
					(terrain_lege_height<25)
					and
					(
						(terrain_name=="EvergreenForest")
						or (terrain_name=="DeciduousForest")
						or (terrain_name=="MixedForest")
						or (terrain_name=="RainForest")
						or (terrain_name=="Urban")
						or (terrain_name=="Town")
					)
				)
				{
					terrain_lege_height=25;
				}
				if (
					(terrain_lege_height<20)
					and
					(
						(terrain_name=="Orchard")
						or (terrain_name=="CropWood")

					)
				)
				{
					terrain_lege_height=20;
				}
			}
			#print(real_altitude_m - terrain_lege_height);
			if (real_altitude_m<terrain_lege_height)
			{
				crashed=aircraft_crash("tree hit", pilot_g, info[1].solid);
			}
		}
		if (pilot_g>(maximum_g*0.5))
		{
			if (pilot_g>maximum_g)
			{
				setprop("sounds/aircraft-crack/volume", 1);
				setprop("sounds/aircraft-creaking/volume", 1);
				setprop("fdm/jsbsim/gtremble/max", 1);
			}
			else
			{
				tremble_max=math.sqrt((pilot_g-(maximum_g*0.5))/(maximum_g*0.5));
				setprop("sounds/aircraft-crack/volume", tremble_max);
				setprop("fdm/jsbsim/gtremble/max", 1);
				if (pilot_g>(maximum_g*0.75))
				{
					tremble_max=math.sqrt((pilot_g-(maximum_g*0.5))/(maximum_g*0.5));
					setprop("sounds/aircraft-creaking/volume", tremble_max);
					setprop("sounds/aircraft-creaking/on", 1);
				}
				else
				{
					setprop("sounds/aircraft-creaking/on", 0);
				}
			}
			if (pilot_g>(maximum_g*0.75))
			{
				setprop("fdm/jsbsim/accelerations/crack", 1);
			}
			setprop("fdm/jsbsim/accelerations/crack", 1);
			setprop("fdm/jsbsim/gtremble/on", 1);
		}
		else
		{
			setprop("fdm/jsbsim/accelerations/crack", 0);
			setprop("sounds/aircraft-creaking/on", 0);
			setprop("fdm/jsbsim/gtremble/on", 0);
		}
		if (
			(exploded!=1)
			and
			(abs(pilot_g)>maximum_g)
		)
		{
			print("Aircraft crashed: Wing broke off, due to G forces.");
			exploded=1;
			setprop("fdm/jsbsim/propulsion/tank[4]/external-flow-rate-pps", -75);
			setprop("fdm/jsbsim/propulsion/tank[5]/external-flow-rate-pps", -75);
			setprop("fdm/jsbsim/propulsion/tank[6]/external-flow-rate-pps", -75);
			setprop("fdm/jsbsim/propulsion/tank[7]/external-flow-rate-pps", -75);
			aircraft_lock();
			aircraft_explode(pilot_g);
		}
		if (
			(
				(wow[3]==1)
				or (wow[4]==1)
				or (wow[5]==1)
				or (wow[6]==1)
			)
			and
			(
				(speed_km>275)
				or (pilot_g>2.5)
				or
				(
					(speed_km>250)
					and
					(
						(info[1].solid!=1)
						or (info[1].bumpiness>0.1)
						or (info[1].rolling_friction>0.05)
						or (info[1].friction_factor<0.7)
					)
				)
			)
		)
		{
			crashed=aircraft_crash("ground slide", pilot_g, info[1].solid);
		}
		if (crashed==1)
		{
			if (exploded==0)
			{
				exploded=1;
				aircraft_explode(pilot_g);
			}
			if (
				(
					(wow[3]==1)
					or (wow[4]==1)
					or (wow[5]==1)
					or (wow[6]==1)
				)
				and (speed_km>10)
			)
			{
				var pos= geo.Coord.new().set_latlon(lat, lon);
				setprop("fdm/jsbsim/simulation/wildfire-ignited", 1);
				wildfire.ignite(pos, 1);
			}
		}
		settimer(aircraftbreakprocess, 0.1);
	}

init_aircraftbreakprocess=func
{
#print("init_aircraftbreakprocess");
setprop("fdm/jsbsim/simulation/exploded", 0);
	setprop("fdm/jsbsim/simulation/crashed", 0);
	setprop("fdm/jsbsim/accelerations/explode-g", 0);
	setprop("fdm/jsbsim/accelerations/crack", 0);
	setprop("fdm/jsbsim/simulation/crash-type", "");
	setprop("fdm/jsbsim/accelerations/crash-g", 0);
	setprop("fdm/jsbsim/velocities/v-down-previous", 0);
	setprop("processes/aircraft-break/enabled", 1);
	setprop("fdm/jsbsim/propulsion/tank[4]/external-flow-rate-pps", 0);
	setprop("fdm/jsbsim/propulsion/tank[5]/external-flow-rate-pps", 0);
	setprop("fdm/jsbsim/propulsion/tank[6]/external-flow-rate-pps", 0);
	setprop("fdm/jsbsim/propulsion/tank[7]/external-flow-rate-pps", 0);

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
	setprop("instrumentation/flaps-control/serviceable", 1);
	setprop("instrumentation/speed-brake-control/serviceable", 1);
	setprop("instrumentation/ignition-button/serviceable", 1);
	setprop("instrumentation/cannon/serviceable", 1);
	setprop("instrumentation/trimmer/serviceable", 1);
	setprop("fdm/jsbsim/systems/radiocompass/serviceable", 1);
	setprop("instrumentation/photo/serviceable", 1);
	setprop("instrumentation/drop-tank/serviceable", 1);
	setprop("instrumentation/pedals/serviceable", 1);

	#Switch on engine
	setprop("controls/engines/engine/cutoff", 0);
	setprop("engines/engine/cutoff-reason", "aircraft break");
}

init_aircraftbreakprocess();

aircraft_explode = func(pilot_g)
	{
	#print("aircraft_explode");
		setprop("fdm/jsbsim/simulation/explode-g", pilot_g);
		setprop("fdm/jsbsim/simulation/exploded", 1);
		setprop("sounds/aircraft-explode/on", 1);
		#setprop("sim/replay/disable", 1);
		#setprop("sim/menubar/default/menu[1]/item[8]/enabled", 0);
		settimer(end_aircraft_explode, 3);
	}

end_aircraft_explode = func
	{
	#print("end_aircraft_explode");
		#Lock swithes
		setprop("instrumentation/panels/left/serviceable", 0);
		setprop("fdm/jsbsim/systems/rightpanel/serviceable", 0);
		setprop("fdm/jsbsim/systems/leftpanel/serviceable", 0);
		setprop("fdm/jsbsim/systems/ignitionbuton/serviceable", 0);
		setprop("fdm/jsbsim/systems/speedbrakescontrol/serviceable", 0);
		setprop("sounds/aircraft-explode/on", 0);
	}

#Start
aircraftbreakprocess();

#--------------------------------------------------------------------
# Aircraft breaks listener

# helper 
stop_aircraftbreaklistener = func 
	{
	}

aircraftbreaklistener = func 
	{
		# check state
		in_service = getprop("listneners/aircraft-break/enabled" );
		if (in_service == nil)
		{
			return ( stop_aircraftbreaklistener );
		}
		if ( in_service != 1 )
		{
			return ( stop_aircraftbreaklistener );
		}
		pilot_g=getprop("fdm/jsbsim/accelerations/Nz");
		lat = getprop("position/latitude-deg");
		lon = getprop("position/longitude-deg");
		exploded=getprop("fdm/jsbsim/simulation/exploded");
		crashed=getprop("fdm/jsbsim/simulation/crashed");
		var wow=[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
		#Gear middle
		wow[0]=getprop("gear/gear[0]/wow");
		#Gear left
		wow[1]=getprop("gear/gear[1]/wow");
		#Gear right
		wow[2]=getprop("gear/gear[2]/wow");
		#Wing Left
		wow[3]=getprop("gear/gear[3]/wow");
		#Wing right
		wow[4]=getprop("gear/gear[4]/wow");
		#Fus nose down
		wow[5]=getprop("gear/gear[5]/wow");
		#Fus nose up
		wow[6]=getprop("gear/gear[6]/wow");
		
		gear_started=getprop("fdm/jsbsim/init/finally-initialized");
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
			or (gear_started==nil)
		)
		{
			return ( stop_aircraftbreaklistener ); 
		}
		if (gear_started==0)
		{
			return ( stop_aircraftbreaklistener ); 
		}
		if (
			(
				(wow[6]==1)
				or (wow[8]==1)
				or (wow[9]==1)
			)
			or
			(
				(
					(wow[3]==1)
					or (wow[4]==1)
					or (wow[5]==1)
				)
				and (pilot_g>3)
			)
			or (
				(tanks_fastened==1)
				and (pilot_g>1.5)
				and 
				(
					((wow[3]==1) and (wow[7]==1))
					or
					((wow[4]==1) and (wow[7]==1))
				)
			)
		)
		{
			info = geodinfo(lat, lon);
			if (info == nil)
			{
				return ( stop_aircraftbreaklistener ); 
			}
			if (info[1]==nil)
			{
				return ( stop_aircraftbreaklistener ); 
			}
			crashed=aircraft_crash("ground hit", pilot_g, info[1].solid);
			if (exploded==0)
			{
				exploded=1;
				aircraft_explode(pilot_g);
			}
		}
	}

init_aircraftbreaklistener = func 
{
#print("init_aircraftbreaklistener");
	setprop("sounds/aircraft-crash/on", 0);
	setprop("sounds/aircraft-water-crash/on", 0);
	setprop("listneners/aircraft-break/enabled", 1);
}

init_aircraftbreaklistener();

aircraft_crash_sound = func
	{
		speed=getprop("/velocities/groundspeed-3D-kt");
		sounded=getprop("sounds/aircraft-crash/on");
		if ((speed!=nil) and (sounded!=nil))
		{
			speed_km=speed*1.852;
			if ((speed_km>10) and (sounded==0))
			{
				setprop("sounds/aircraft-crash/on", 1);
				settimer(end_aircraft_crash, 3);
			}
		}
	}

end_aircraft_crash = func
	{
		setprop("sounds/aircraft-crash/on", 0);
	}

aircraft_water_crash_sound = func
	{
		speed=getprop("velocities/groundspeed-3D-kt");
		sounded=getprop("sounds/aircraft-water-crash/on");
		if ((speed!=nil) and (sounded!=nil))
		{
			speed_km=speed*1.852;
			if ((speed_km>10) and (sounded==0))
			{
				setprop("sounds/aircraft-water-crash/on", 1);
				settimer(end_aircraft_water_crash, 3);
			}
		}
	}

end_aircraft_water_crash = func
	{
		setprop("sounds/aircraft-water-crash/on", 0);
	}

setlistener("gear/gear[3]/wow", aircraftbreaklistener);
setlistener("gear/gear[4]/wow", aircraftbreaklistener);
setlistener("gear/gear[5]/wow", aircraftbreaklistener);
setlistener("gear/gear[6]/wow", aircraftbreaklistener);
setlistener("gear/gear[7]/wow", aircraftbreaklistener);
setlistener("gear/gear[8]/wow", aircraftbreaklistener);
setlistener("gear/gear[9]/wow", aircraftbreaklistener);
setlistener("gear/gear[10]/wow", aircraftbreaklistener);