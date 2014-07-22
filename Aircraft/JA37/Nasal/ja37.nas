# $Id$

var UPDATE_PERIOD = 0.1;

var g_curr 	= props.globals.getNode("accelerations/pilot-gdamped", 1);
var auto_gen=0;

var prevGear0 = 1;
var prevGear1 = 1;
var prevGear2 = 1;
var touchdown1 = 0;
var touchdown2 = 0;

############### Main loop ###############
var cnt = 0;

var update_loop = func {
  # set the full-init property
  if(getprop("sim/time/elapsed-sec") > getprop("sim/time/elapsed-at-init-sec") + 5) {
    setprop("sim/time/full-init", 1);
  } else {
    setprop("sim/time/full-init", 0);
  }

	 ## Sets fuel gauge needles rotation ##
	 
   setprop("/instrumentation/fuel/needleB_rot", getprop("/consumables/fuel/tank[8]/level-norm")*230);

   var total = getprop("/consumables/fuel/tank[0]/capacity-gal_us")
              + getprop("/consumables/fuel/tank[1]/capacity-gal_us")
              + getprop("/consumables/fuel/tank[2]/capacity-gal_us")
              + getprop("/consumables/fuel/tank[3]/capacity-gal_us")
              + getprop("/consumables/fuel/tank[4]/capacity-gal_us")
              + getprop("/consumables/fuel/tank[5]/capacity-gal_us")
              + getprop("/consumables/fuel/tank[6]/capacity-gal_us")
              + getprop("/consumables/fuel/tank[7]/capacity-gal_us");

  var current = getprop("/consumables/fuel/tank[0]/level-gal_us")
              + getprop("/consumables/fuel/tank[1]/level-gal_us")
              + getprop("/consumables/fuel/tank[2]/level-gal_us")
              + getprop("/consumables/fuel/tank[3]/level-gal_us")
              + getprop("/consumables/fuel/tank[4]/level-gal_us")
              + getprop("/consumables/fuel/tank[5]/level-gal_us")
              + getprop("/consumables/fuel/tank[6]/level-gal_us")
              + getprop("/consumables/fuel/tank[7]/level-gal_us");


   setprop("/instrumentation/fuel/needleF_rot", (current / total) *230);
   
   ## control augmented thrust ##
     
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
   
   ## control flaps ##

   var flapsCommand = 0;
   var gear = getprop("/fdm/jsbsim/gear/gear-cmd-norm");
   var battery = getprop("systems/electrical/outputs/battery");
   
   if ((battery < 25) or (gear == nil))
   {
     flapsCommand = 0.11765;
   }
   else
  {
    flapsCommand = gear;
  }
  setprop("/fdm/jsbsim/fcs/flap-pos-cmd", flapsCommand);
  
  if (getprop("systems/electrical/serviceable") < 1) {
    setprop("/fdm/jsbsim/fcs/canopy/has-power", 0);
  } else {
    setprop("/fdm/jsbsim/fcs/canopy/has-power", 1);
  }

  #if(getprop("/sim/failure-manager/controls/flight/rudder/serviceable") == 1) {
  #  setprop("fdm/jsbsim/fcs/rudder/serviceable", 1);
  #} elsif (getprop("fdm/jsbsim/fcs/rudder/serviceable") == 1) {
  #  setprop("fdm/jsbsim/fcs/rudder-sum-stuck", getprop("fdm/jsbsim/fcs/rudder-sum"));
  #  setprop("fdm/jsbsim/fcs/rudder-serviceable", 0);
  #}

  ## set groundspeed property used for crashcode ##
  
  var horz_speed = getprop("/fdm/jsbsim/velocities/vg-fps");
  var vert_speed = getprop("/velocities/down-relground-fps");
     
  var real_speed = math.sqrt((horz_speed * horz_speed) + (vert_speed * vert_speed));
  
  real_speed = real_speed * 0.5924838;
  
  setprop("/velocities/groundspeed-3D-kt", real_speed); 
  
  setprop("fdm/jsbsim/fcs/flaps-serviceable", getprop("/sim/failure-manager/controls/flight/flaps/serviceable"));
  setprop("fdm/jsbsim/fcs/aileron-serviceable", getprop("/sim/failure-manager/controls/flight/aileron/serviceable"));
  setprop("fdm/jsbsim/fcs/elevator-serviceable", getprop("/sim/failure-manager/controls/flight/elevator/serviceable"));
  setprop("fdm/jsbsim/gear/serviceable", getprop("/gear/serviceable"));

  #setprop("systems/electrical/outputs/battery", getprop("/systems/electrical/volts"));
  setprop("/instrumentation/switches/inst-light-knob/pos", getprop("/instrumentation/instrumentation-light/serviceable"));
  #setprop("controls/lighting/instruments-norm", getprop("/systems/electrical/battery"));
  
  # Animating engine fire

  var n1 = getprop("engines/engine/n1");

  if (n1 > 100) n1 = 100;

  var flame = 100 / (100-n1);

  setprop("engines/engine/flame", flame);


  # indicators
  var joystick = 0;
  var attitude = 0;
  var altitude = 0;

  # joystick indicator
  if(getprop("/systems/electrical/generator_on") == 1) {
    if (((getprop("/autopilot/locks/heading") != '' and getprop("/autopilot/locks/heading") != nil) and (getprop("/autopilot/locks/altitude") != '' and getprop("/autopilot/locks/altitude") != nil)) or getprop("/autopilot/locks/passive-mode") == 1) {
      joystick = 0;
    } else {
      joystick = 1;
    }
  } else {
    joystick = 0;
  }

  # attitude indicator
  if(getprop("/autopilot/locks/passive-mode") == 1 or (getprop("/autopilot/locks/heading") != '' and getprop("/autopilot/locks/heading") != nil)) {
    if (getprop("/instrumentation/attitude-indicator/indicated-roll-deg") > 70 or getprop("/instrumentation/attitude-indicator/indicated-roll-deg") < -70) {
      attitude = getprop("sim/model/lighting/beacon/state");
    } else {
      attitude = 1;
    }
  } else {
    attitude = 0;
  }

  # altitude indicator
  if(getprop("/autopilot/locks/passive-mode") == 1 or (getprop("/autopilot/locks/altitude") != '' and getprop("/autopilot/locks/altitude") != nil)) {
    if (getprop("/instrumentation/airspeed-indicator/indicated-mach") > 0.8 and getprop("/instrumentation/airspeed-indicator/indicated-mach") < 1.2) {
      altitude = getprop("sim/model/lighting/beacon/state");
    } else {
      altitude = 1;
    }
  } else {
    altitude = 0;
  }

  setprop("/instrumentation/joystick-indicator", joystick);
  setprop("/instrumentation/attitude-indicator", attitude);
  setprop("/instrumentation/altitude-indicator", altitude);

  # payload
  for(var i=1; i<5; i=i+1) {
    if(getprop("payload/weight["~ (i-1) ~"]/selected") != "none" and getprop("payload/weight["~ (i-1) ~"]/weight-lb") == 0) {
      # payload was loaded manually through payload/fuel dialog
      
      setprop("controls/armament/station["~i~"]/released", 0);
    }
  }

  var trigger = getprop("controls/armament/trigger");
  var armSelect = getprop("controls/armament/station-select");

  if(trigger == 1) {
    if(armSelect != 0 and getprop("payload/weight["~ (armSelect-1) ~"]/selected") != "none") { 
      # fire missile
      setprop("payload/weight["~ (armSelect-1) ~"]/selected", "none");
      setprop("controls/armament/station["~armSelect~"]/released", 1);
    }
  }

  if (armSelect == 0) { # cannon
    setprop("/controls/armament/station[0]/trigger", trigger);
  } else {
    setprop("/controls/armament/station[0]/trigger", 0);
  }
  
  var selected = getprop("payload/weight[0]/selected");
  if(selected == "none") {
    setprop("fdm/jsbsim/inertia/pointmass-weight-lbs[1]", 0);
  } elsif (selected == "RB 24J") {
    setprop("fdm/jsbsim/inertia/pointmass-weight-lbs[1]", 188);
  }
  selected = getprop("payload/weight[1]/selected");
  if(selected == "none") {
    setprop("fdm/jsbsim/inertia/pointmass-weight-lbs[2]", 0);
  } elsif (selected == "RB 24J") {
    setprop("fdm/jsbsim/inertia/pointmass-weight-lbs[2]", 188);
  }
  selected = getprop("payload/weight[2]/selected");
  if(selected == "none") {
    setprop("fdm/jsbsim/inertia/pointmass-weight-lbs[3]", 0);
  } elsif (selected == "RB 24J") {
    setprop("fdm/jsbsim/inertia/pointmass-weight-lbs[3]", 188);
  }
  selected = getprop("payload/weight[3]/selected");
  if(selected == "none") {
    setprop("fdm/jsbsim/inertia/pointmass-weight-lbs[4]", 0);
  } elsif (selected == "RB 24J") {
    setprop("fdm/jsbsim/inertia/pointmass-weight-lbs[4]", 188);
  }


  # automatic reverse thrust enabler

  var gear0 = getprop("/gear/gear[0]/wow");
  var gear1 = getprop("/gear/gear[1]/wow");
  var gear2 = getprop("/gear/gear[2]/wow");

  if(getprop("processes/aircraft-break/autoReverseThrust") == 1 and reversed == 0) {
    if(gear1 == 1) {
      #left boogie touching
      if(prevGear1 == 0) {
        touchdown1 = 1;
      }
    } else {
      touchdown1 = 0;
    }
    if(gear2 == 1) {
      #right boogie touching
      if(prevGear2 == 0) {
        touchdown2 = 1;
      }
    } else {
      touchdown2 = 0;
    }
    if(touchdown1 == 1 and touchdown2 == 1) {
      if(gear0 == 1) {
        #print("Auto-reversing the thrust");
        reversethrust.togglereverser();
      }
    }
  }

  prevGear0 = gear0;
  prevGear1 = gear1;
  prevGear2 = gear2;

  # Make sure have engine sound at reverse thrust

  var thrust = getprop("engines/engine/thrust_lb");
   
  if(thrust != nil) {
    setprop("engines/engine/thrust_lb-absolute", abs(thrust));
  } else {
    setprop("engines/engine/thrust_lb-absolute", 0);
  }


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
    if (getprop("systems/electrical/battery_voltage") > 24) {
      setprop("/systems/electrical/battery-full", 1);
    } else {
      setprop("/systems/electrical/battery-full", 0);
    }
}
settimer(func { signal_loop() }, 0.1);


############################# main init ###############


var main_init = func {
	print("Initializing JA-37 Viggen systems");

  setprop("sim/time/elapsed-at-init-sec", getprop("sim/time/elapsed-sec"));

	setprop("/consumables/fuel/tank[8]/jettisoned", 0);
  # Load exterior at startup to avoid stale sim at first external view selection. ( taken from TU-154B )
  
  print("Loading exterior, wait...");
  # return to cabin to next cycle
  settimer( load_interior, 0 );
  setprop("/sim/current-view/view-number", 1);
  setprop("/sim/gui/tooltips-enabled", 1);
  
  # random failure code:

  var fail = { SERVICEABLE : 1, JAM : 2, ENGINE: 3};
  var type = { MTBF : 1, MCBF: 2 };
  var failure_root = "/sim/failure-manager";
  var prop = "/instrumentation/head-up-display";

  failures.breakHash[prop] = {
    type: type.MTBF, failure: fail.SERVICEABLE, desc: "Head up display"};

  var o = failures.breakHash[prop];
  var t = "/mtbf";
  props.globals.initNode(failure_root ~ prop ~ t, 0);
  props.globals.initNode(prop ~ "/serviceable", 1, "BOOL");

  prop = "/instrumentation/instrumentation-light";

  failures.breakHash[prop] = {
    type: type.MTBF, failure: fail.SERVICEABLE, desc: "Instrumentation light"};

  props.globals.initNode(failure_root ~ prop ~ t, 0);
  props.globals.initNode(prop ~ "/serviceable", 1, "BOOL");

  prop = "/fdm/jsbsim/fcs/canopy";

  failures.breakHash[prop] = {
    type: type.MTBF, failure: fail.SERVICEABLE, desc: "Canopy"};

  props.globals.initNode(failure_root ~ prop ~ t, 0);
  props.globals.initNode(prop ~ "/serviceable", 1, "BOOL");

  prop = "/instrumentation/radar";

  failures.breakHash[prop] = {
    type: type.MTBF, failure: fail.SERVICEABLE, desc: "Radar"};

  props.globals.initNode(failure_root ~ prop ~ t, 0);
  props.globals.initNode(prop ~ "/serviceable", 1, "BOOL");

  setprop("/sim/failure-manager/display-on-screen", 1);
  #setprop("/sim/failure-manager/global-mcbf-0", 0);
  #setprop("/sim/failure-manager/global-mcbf-500", 1);
  #setprop("/sim/failure-manager/global-mcbf", 500);
  #setprop("/sim/failure-manager/global-mtbf-0", 0);
  #setprop("/sim/failure-manager/global-mtbf-86400", 1);
  #setprop("/sim/failure-manager/global-mtbf", 86400);

  #failures.setAllMCBF(500);
  #failures.setAllMTBF(86400);

  
  

  # inst. light

  setprop("/instrumentation/instrumentation-light/r", 1.0);
  setprop("/instrumentation/instrumentation-light/g", 1.0);
  setprop("/instrumentation/instrumentation-light/b", 0.3);

  screen.log.write("Welcome to Saab JA-37 Viggen, version "~getprop("sim/aircraft-version"), 1.0, 0.0, 0.0);

  # start the main loop
	settimer(func { update_loop() }, 0.1);
}

# re init
var re_init = func {
  print("Re-initializing JA-37 Viggen systems");

  setprop("sim/time/elapsed-at-init-sec", getprop("sim/time/elapsed-sec"));
}

var load_interior = func{
    setprop("/sim/current-view/view-number", 0);
    print("..Done!");
  }

var main_init_listener = setlistener("sim/signals/fdm-initialized", func {
	main_init();
	removelistener(main_init_listener);
 }, 0, 0);

var re_init_listener = setlistener("sim/signals/fdm-initialized", func {
  re_init();
 }, 0, 0);

############ droptank #####################

var drop = func {
    if (getprop("/consumables/fuel/tank[8]/jettisoned") == 1) {
       gui.popupTip("Drop tank already jettisoned.");
       return;
    }  
    if (getprop("/gear/gear[0]/wow") > 0.05) {
       gui.popupTip("Can not eject drop tank while on ground!"); 
       return;
    }  
    setprop("/consumables/fuel/tank[8]/level-norm", 0);
    setprop("fdm/jsbsim/propulsion/tank[8]/external-flow-rate-pps", -1500);
    setprop("/consumables/fuel/tank[8]/selected", 0);
    setprop("/consumables/fuel/tank[8]/jettisoned", 1);
    gui.popupTip("Drop tank shut off and ejected. Using internal fuel.");
 }

############ strobes #####################

var strobe_switch = props.globals.getNode("controls/lighting/ext-lighting-panel/anti-collision", 1);
setprop("controls/lighting/ext-lighting-panel/anti-collision", 1);
aircraft.light.new("sim/model/lighting/strobe", [0.03, 1.9+rand()/5], strobe_switch);


var beacon_switch = props.globals.getNode("controls/switches/beacon", 2);
setprop("controls/switches/beacon", 1);
setprop("fdm/jsbsim/fcs/yaw-damper-enable", 1);
var beacon = aircraft.light.new( "sim/model/lighting/beacon", [0, 1], beacon_switch );

############# workaround for removing default HUD   ##############

setlistener("/sim/current-view/view-number", func(n) {
        setprop("/sim/hud/visibility[1]", !n.getValue());
}, 1);

###################### autostart ########################

 # Opens fuel valve in autostart
 var waiting_n1 = func {
  if (getprop("/engines/engine[0]/n1") > 5.0) {
    if (getprop("/engines/engine[0]/n1") < 20) {
      if (getprop("/controls/engines/engine[0]/cutoff") == 1) {
        setprop("/controls/engines/engine[0]/cutoff", 0);
        if (getprop("/controls/engines/engine[0]/cutoff") == 0) {
          gui.popupTip("Engine igniting.");
          settimer(waiting_n1, 1);
        } else {
          setprop("/controls/engines/engine[0]/starter", 0);
          gui.popupTip("Engine not igniting. Aborting engine start.");
          auto_gen=0;
        }
      } else {
        settimer(waiting_n1, 1);
      }
    }  elsif (getprop("/engines/engine[0]/n1") > 15) {
      setprop("controls/electric/engine[0]/generator", 1);
      gui.popupTip("Generator on.");
      auto_gen=0;
    } else {
      settimer(waiting_n1, 1);
    }
   } else {
    settimer(waiting_n1, 1);
  }
 }



#Simulating autostart function
var autostart = func {
  setprop("/controls/electric/engine[0]/generator", 0);
  if (getprop("controls/electric/engine[0]/generator") == 0) #getprop("/velocities/groundspeed-kt") < 1e-3 and
  {
    gui.popupTip("Starting engine.");
    setprop("/controls/engines/engine[0]/cutoff", 1);
    setprop("/controls/engines/engine[0]/starter", 1);
    auto_gen=1;
    settimer(waiting_n1, 1);
  } else {
    gui.popupTip("Generator switch turned on. Engine restart aborted.");
  }
}

#Default 's' button will set starter to false, so will start delayed.
var autostarttimer = func {
  if (auto_gen==0) {
    if (getprop("/engines/engine[0]/running") > 0) {
     gui.popupTip("Stopping engine. Turning off battery.");
     setprop("/controls/engines/engine[0]/cutoff", 1);
  	 setprop("/controls/engines/engine[0]/starter", 0);
     setprop("/controls/electric/engine[0]/generator", 0);
  	 setprop("/controls/electric/battery-switch", 0);
    } else {
      if (getprop("/fdm/jsbsim/simulation/crashed") < 1) {
        setprop("/controls/electric/battery-switch", 1);
        setprop("/systems/electrical/batterysignal", 1);
        gui.popupTip("Battery switch on. Check.");
    	  settimer(autostart, 3);
      } else {
        gui.popupTip("Engine not reacting. Consider ejecting yourself.");
      }
    }
  }
}
