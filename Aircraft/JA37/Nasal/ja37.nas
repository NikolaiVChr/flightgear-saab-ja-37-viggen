# $Id$

var UPDATE_PERIOD = 0.1;

var g_curr 	= props.globals.getNode("accelerations/pilot-gdamped", 1);

# place the aircraft a little forward on the runways to avoid it standing on the edge.
setprop("/sim/airport/runways/start-offset-m", 20);

############### Main loop ###############
var cnt = 0;

var update_loop = func {
	# Sets fuel gauge needles rotation
    setprop("/instrumentation/fuel/needleF_rot", getprop("/consumables/fuel/total-fuel-norm")*230);
   
   # control augmented thrust
     
   var n1 = getprop("/engines/engine/n1");
   var n2 = getprop("/engines/engine/n2");
   var reversed = getprop("/engines/engine/reversed");
   
   if ( (n1 > 99) and (n2 > 97) and (reversed == 0) )
   {
    setprop("/controls/engines/engine[0]/augmentation", 1);
   }
   else
   {
    setprop("/controls/engines/engine[0]/augmentation", 0);
   }
   
   ############# control flaps #################

   var flapsCommand = 0;
   var gear = getprop("/fdm/jsbsim/gear/gear-cmd-norm");
   var battery = getprop("/systems/electrical/battery");
   
   if ((battery == 0) or (gear == nil))
   {
     flapsCommand = 0.11765;
   }
   else
  {
    flapsCommand = gear;
  }
  setprop("/fdm/jsbsim/fcs/flap-pos-cmd", flapsCommand);
   
    
   
	settimer(update_loop, UPDATE_PERIOD);
}

###########  loop for handling the battery signal for cockpit sound #########
var lastsignal = 0;
var signal_loop = func {
    if (getprop("/systems/electrical/batterysignal") == 1) 
    {
      if (lastsignal == 0)
      {
        lastsignal = 1;
        settimer(signal_loop, 6);
      }
      else
      {
        setprop("/systems/electrical/batterysignal", 0);
        lastsignal = 0;
        settimer(signal_loop, 1);
      }
    }
    else
    {
      lastsignal = 0;
      settimer(signal_loop, 1);
    }
}
settimer(func { signal_loop() }, 0.1);

################### reload sound when config change ##################


var reload_sound = func {
  var sf = getprop('/tmp/sound-xml/path');
  if(sf == nil)
  {
    sf = "d:/programfiles/flightgear/data/Aircraft/JA37/ja37-sound.xml";
    #sf = getprop('/sim/fg-root') ~ folder ~ getprop('/sim/sound/path');
    setprop('/tmp/sound-xml/path', sf);
  }
  var st = io.stat(sf);
  var lm = getprop('/tmp/sound-xml/modified');
  if (st == nil )
  {
  }
  else
  {  
    if(lm == nil)
    {
      lm = st[9];
      setprop('/tmp/sound-xml/modified', lm);
    }
    elsif(lm < st[9])
    {
      setprop('/tmp/sound-xml/modified', st[9]);
      fgcommand('reinit', props.Node.new({ subsystem: "fx" }));
      gui.popupTip("Sound system reinit.");
    }
  }
  settimer(reload_sound, 2);
 }
 settimer(reload_sound, 5);

############################# functions ###############


# main_init #################
var main_init = func {
	print("Initializing JA-37 Viggen systems");

	
  # Load exterior at startup to avoid stale sim at first external view selection. ( taken from TU-154B )
  
  print("Loading exterior, wait...");
  # return to cabin to next cycle
  settimer( load_interior, 0 );
  setprop("/sim/current-view/view-number", 1);
  
	settimer(func { update_loop() }, 0.1);
}

var load_interior = func{
    setprop("/sim/current-view/view-number", 0);
    print("..Done!");
  }

var main_init_listener = setlistener("sim/signals/fdm-initialized", func {
	main_init();
	removelistener(main_init_listener);
 }, 0, 0);

# strobes ===========================================================
var strobe_switch = props.globals.getNode("controls/lighting/ext-lighting-panel/anti-collision", 1);
aircraft.light.new("sim/model/lighting/strobe", [0.03, 1.9+rand()/5], strobe_switch);


var beacon_switch = props.globals.getNode("controls/switches/beacon", 2);
setprop("controls/switches/beacon", 1);
setprop("fdm/jsbsim/fcs/yaw-damper-enable", 1);
var beacon = aircraft.light.new( "sim/model/lighting/beacon", [0, 1], beacon_switch );

setlistener("/sim/current-view/view-number", func(n) {
        setprop("/sim/hud/visibility[1]", !n.getValue());
}, 1);

aircraft_lock = func 
	{
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

		return (1);
	}


aircraft_crash_sound = func
	{
		speed=getprop("velocities/airspeed-kt");
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
		speed=getprop("velocities/airspeed-kt");
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

stop_aircraftbreakprocess = func 
	{
	}

aircraftbreakprocess=func
	{
		# check state
		in_service = getprop("processes/aircraft-break/enabled" );
		if (in_service == nil)
		{
			stop_aircraftbreakprocess();
			return ( settimer(aircraftbreakprocess, 0.1) ); 
		}
		if ( in_service != 1 )
		{
			stop_aircraftbreakprocess();
			return ( settimer(aircraftbreakprocess, 0.1) ); 
		}
		pilot_g=getprop("fdm/jsbsim/accelerations/Nz");
		lat = getprop("position/latitude-deg");
		lon = getprop("position/longitude-deg");
		altitude=getprop("position/altitude-ft");
		elevation=getprop("position/ground-elev-ft");
		exploded=getprop("fdm/jsbsim/simulation/exploded");
		speed=getprop("velocities/airspeed-kt");
		crashed=getprop("fdm/jsbsim/simulation/crashed");
		var wow=[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
		#Gear middle
		wow[0]=getprop("gear/gear[0]/wow");
		#Gear left
		wow[1]=getprop("gear/gear[1]/wow");
		#Gear right
		wow[2]=getprop("gear/gear[2]/wow");

		if (
			(lat==nil)
			or (pilot_g==nil)
			or (lon==nil)
			or (altitude==nil)
			or (elevation==nil)
			or (speed==nil)
			or (crashed==nil)
			or (exploded==nil)
			or (wow[0]==nil)
			or (wow[1]==nil)
			or (wow[2]==nil)
		)
		{
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
			if (real_altitude_m<terrain_lege_height)
			{
				crashed=aircraft_crash("tree hit", pilot_g, info[1].solid);
			}
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
					or (wow[7]==1)
					or (wow[8]==1)
					or (wow[9]==1)
					or (wow[10]==1)
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
	setprop("fdm/jsbsim/simulation/exploded", 0);
	setprop("fdm/jsbsim/simulation/crashed", 0);
	setprop("fdm/jsbsim/accelerations/explode-g", 0);
	setprop("fdm/jsbsim/accelerations/crack", 0);
	setprop("fdm/jsbsim/simulation/crash-type", "");
	setprop("fdm/jsbsim/accelerations/crash-g", 0);
	setprop("fdm/jsbsim/velocities/v-down-previous", 0);
	setprop("processes/aircraft-break/enabled", 1);
}
init_aircraftbreakprocess();

aircraft_explode = func(pilot_g)
	{
		setprop("fdm/jsbsim/simulation/explode-g", pilot_g);
		setprop("fdm/jsbsim/simulation/exploded", 1);
		setprop("sounds/aircraft-explode/on", 1);
		setprop("sim/replay/disable", 1);
		settimer(end_aircraft_explode, 3);
	}

end_aircraft_explode = func
	{
		#Lock swithes
		setprop("instrumentation/panels/left/serviceable", 0);
		setprop("fdm/jsbsim/systems/rightpanel/serviceable", 0);
		setprop("fdm/jsbsim/systems/leftpanel/serviceable", 0);
		setprop("fdm/jsbsim/systems/ignitionbuton/serviceable", 0);
		setprop("fdm/jsbsim/systems/speedbrakescontrol/serviceable", 0);
		setprop("sounds/aircraft-explode/on", 0);
	}

#aircraftbreakprocess();

aircraft_crash_sound = func
	{
		speed=getprop("velocities/airspeed-kt");
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
		speed=getprop("velocities/airspeed-kt");
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

 # Opens fuel valve in autostart
 var waiting_n1 = func {
  if (getprop("/engines/engine[0]/n1") > 5.0) {
    setprop("/controls/engines/engine[0]/cutoff", 0);
    gui.popupTip("Engine igniting.");
  } else settimer(waiting_n1, 1);
 }

#Simulating autostart function
 var autostart = func {
    setprop("/controls/engines/engine[0]/cutoff", 1);
    setprop("/controls/engines/engine[0]/starter", 1);
    settimer(waiting_n1, 1);
    gui.popupTip("Engine starting.");
 }

 #Default 's' button will set starter to false, so will start delayed.
 var autostarttimer = func {
    
    if (getprop("/engines/engine[0]/running") > 0) {
		setprop("/controls/engines/engine[0]/cutoff", 1);
		setprop("/controls/engines/engine[0]/starter", 0);
		gui.popupTip("Stopping engine. Turning off battery.");
		setprop("/systems/electrical/battery", 0);
    } else {
    	settimer(autostart, 3);
    	setprop("/systems/electrical/battery", 1);
    	setprop("/systems/electrical/batterysignal", 1);
    	gui.popupTip("Battery turned on. Beginning startup procedure..");
    }
 }