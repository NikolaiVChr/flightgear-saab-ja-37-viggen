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
  if(getprop("sim/replay/replay-state") == 1) {
    # replay is active, skip rest of loop.
    settimer(update_loop, UPDATE_PERIOD);
  } else {


    # set the full-init property
    if(getprop("sim/time/elapsed-sec") > getprop("sim/time/elapsed-at-init-sec") + 5) {
      setprop("sim/time/full-init", 1);
    } else {
      setprop("sim/time/full-init", 0);
    }

  	 ## Sets fuel gauge needles rotation ##
  	 
     if(getprop("/consumables/fuel/tank[8]/level-norm") != nil) {
       setprop("/instrumentation/fuel/needleB_rot", getprop("/consumables/fuel/tank[8]/level-norm")*230);
     }
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
     
     if ( (n1 > 102) and (n2 > 99) and (reversed == 0) ) #was 99 and 97
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
    
    if(getprop("sim/signals/fdm-initialized") == 1) {
      setprop("fdm/jsbsim/fcs/flaps-serviceable", getprop("/sim/failure-manager/controls/flight/flaps/serviceable"));
      setprop("fdm/jsbsim/fcs/aileron-serviceable", getprop("/sim/failure-manager/controls/flight/aileron/serviceable"));
      setprop("fdm/jsbsim/fcs/elevator-serviceable", getprop("/sim/failure-manager/controls/flight/elevator/serviceable"));
      setprop("fdm/jsbsim/gear/serviceable", getprop("/gear/serviceable"));
    }

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
    var transonic = 0;
    var rev = 0;

    # joystick indicator
    if(getprop("/systems/electrical/generator_on") == 1) {
      if (((getprop("/autopilot/locks/heading") != '' and getprop("/autopilot/locks/heading") != nil) and (getprop("/autopilot/locks/altitude") != ''
       and getprop("/autopilot/locks/altitude") != nil)) or getprop("/autopilot/locks/passive-mode") == 1 and getprop("/systems/electrical/outputs/inst_ac") > 40) {
        joystick = 0;
      } else {
        joystick = 1;
      }
    } else {
      joystick = 0;
    }

    # attitude indicator
    if(getprop("/autopilot/locks/passive-mode") == 1 or (getprop("/autopilot/locks/heading") != '' and getprop("/autopilot/locks/heading") != nil)
     and getprop("/systems/electrical/outputs/inst_ac") > 40) {
      if (getprop("/instrumentation/attitude-indicator/indicated-roll-deg") > 70 or getprop("/instrumentation/attitude-indicator/indicated-roll-deg") < -70) {
        attitude = getprop("sim/ja37/blink/five-Hz");
      } else {
        attitude = 1;
      }
    } else {
      attitude = 0;
    }

    # altitude indicator
    if(getprop("/autopilot/locks/passive-mode") == 1 or (getprop("/autopilot/locks/altitude") != '' and getprop("/autopilot/locks/altitude") != nil)
     and getprop("/systems/electrical/outputs/inst_ac") > 40) {
      if (getprop("/instrumentation/airspeed-indicator/indicated-mach") > 0.97 and getprop("/instrumentation/airspeed-indicator/indicated-mach") < 1.05) {
        altitude = getprop("sim/ja37/blink/five-Hz");
      } else {
        altitude = 1;
      }
    } else {
      altitude = 0;
    }

    #transonic indicator
    if (getprop("/instrumentation/airspeed-indicator/indicated-mach") > 0.97 and getprop("/instrumentation/airspeed-indicator/indicated-mach") < 1.05
     and getprop("/systems/electrical/outputs/inst_ac") > 40) {
      transonic = 1;
    } else {
      if(getprop("/engines/engine/reversed") and getprop("/instrumentation/airspeed-indicator/indicated-speed-kt") < 64.8 and getprop("/systems/electrical/outputs/inst_ac") > 40) {
        # warning that speed is so low that its risky to continue reverse thrust
          transonic = 1;
        } else {
          transonic = 0;
        }
    }

    # reverse indicator
    if(getprop("engines/engine/reversed") == 1
     and getprop("/systems/electrical/outputs/inst_ac") > 40) {
      rev = 1;
    } else {
      rev = 0;
    }

    setprop("/instrumentation/joystick-indicator", joystick);
    setprop("/instrumentation/attitude-indicator", attitude);
    setprop("/instrumentation/altitude-indicator", altitude);
    setprop("/instrumentation/transonic-indicator", transonic);
    setprop("/instrumentation/reverse-indicator", rev);

    # pylon payloads

    for(var i=0; i<=4; i=i+1) {
      if(getprop("payload/weight["~ (i) ~"]/selected") != "none" and getprop("payload/weight["~ (i) ~"]/weight-lb") == 0) {
        # missile was loaded manually through payload/fuel dialog, so setting the pylon to not released
        setprop("controls/armament/station["~(i+1)~"]/released", 0);
        #print("adding "~i);
        if(i != 4) {
          #not drop tank
          armament.AIM9.new(i);#print("new "~(i-1));
        }
      }
      #if(i!=0 and getprop("payload/weight["~ (i-1) ~"]/selected") == "none" and getprop("payload/weight["~ (i-1) ~"]/weight-lb") != 0) {
      #  if(armament.AIM9.active[i-1] != nil) {
          # pylon emptied through menu, so remove the logic
          #print("removing "~i);
      #    armament.AIM9.active[i-1].del();
      #  } 
      #}
    }

    #activate searcher on selected pylon if missile mounted
    var armSelect = getprop("controls/armament/station-select");
    for(i=0;i<=3;i+=1) {
      if(armament.AIM9.active[i] != nil) {
        #missile is mounted on pylon
        if(armSelect != i+1) {
          #pylon not selected, missile off
          armament.AIM9.active[i].status = -1;#print("not sel "~(i));
        } elsif (armament.AIM9.active[i].status != -1 and armament.AIM9.active[i].status != 2 and getprop("payload/weight["~ (i) ~"]/selected") == "none") {
          #pylon is selected but missile not mounted and not flying
          armament.AIM9.active[i].status = -1;#print("empty "~(i));
        } elsif (armament.AIM9.active[i].status == -1 and getprop("payload/weight["~ (i) ~"]/selected") != "none") {
          #pylon selected, activate if not already
          armament.AIM9.active[i].status = 0;#print("active "~(i));
          armament.AIM9.active[i].search();
        }
      }
    }

    var selected = nil;
    for(var i=0; i<=4; i=i+1) { # set JSBSim mass
      selected = getprop("payload/weight["~i~"]/selected");
      if(selected == "none") {
        # the pylon is empty, set its pointmass to zero
        setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 0);
        if(i==4) {
          # no drop tank attached
          setprop("fdm/jsbsim/propulsion/tank[8]/external-flow-rate-pps", -1500);
          setprop("/consumables/fuel/tank[8]/selected", 0);
          setprop("/consumables/fuel/tank[8]/jettisoned", 1);
          setprop("/consumables/fuel/tank[8]/level-norm", 0);
        }
      } elsif (selected == "RB 24J") {
        # the pylon has a sidewinder, give it a pointmass
        setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 188);
      } elsif (selected == "Drop tank") {
        # the pylon has a drop tank, give it a pointmass
        setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 400);
        setprop("fdm/jsbsim/propulsion/tank[8]/external-flow-rate-pps", 0);
        setprop("/consumables/fuel/tank[8]/selected", 1);
        setprop("/consumables/fuel/tank[8]/jettisoned", 0);
      }
    }

    # for aerodynamic response to asymmetric wing loading
    if(getprop("fdm/jsbsim/inertia/pointmass-weight-lbs[1]") == getprop("fdm/jsbsim/inertia/pointmass-weight-lbs[3]")) {
      # wing pylons symmetric loaded
      setprop("fdm/jsbsim/inertia/asymmetric-wing-load", 0);
    } elsif(getprop("fdm/jsbsim/inertia/pointmass-weight-lbs[1]") < getprop("fdm/jsbsim/inertia/pointmass-weight-lbs[3]")) {
      # right wing pylon has more load than left
      setprop("fdm/jsbsim/inertia/asymmetric-wing-load", -1);
    } else {
      # left wing pylon has more load than right
      setprop("fdm/jsbsim/inertia/asymmetric-wing-load", 1);
    }


    # automatic reverse thrust enabler

    var gear0 = getprop("/gear/gear[0]/wow");
    var gear1 = getprop("/gear/gear[1]/wow");
    var gear2 = getprop("/gear/gear[2]/wow");

    if(getprop("sim/ja37/autoReverseThrust") == 1 and reversed == 0) {
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

    # meter altitude property

    setprop("instrumentation/altimeter/indicated-altitude-meter", getprop("instrumentation/altimeter/indicated-altitude-ft")*0.3048);

    # front gear compression calc for spinning of wheel
    # setprop("gear/gear/compression-wheel", (getprop("gear/gear/compression-ft")*0.3048-1.84812));

    settimer(update_loop, UPDATE_PERIOD);
  }
}


###########  listener for handling the trigger #########
    
var trigger_listener = func {
    var trigger = getprop("controls/armament/trigger");
    var armSelect = getprop("controls/armament/station-select");

    if(trigger == 1) {
      if(armSelect != 0 and getprop("payload/weight["~ (armSelect-1) ~"]/selected") != "none") { 
        # trigger is pulled, a pylon is selected, the pylon has a missile: fire missile
        if (armament.AIM9.active[armSelect-1] != nil and  armament.AIM9.active[armSelect-1].status == 1 ) {
          setprop("payload/weight["~ (armSelect-1) ~"]/selected", "none");# empty the pylon
          setprop("controls/armament/station["~armSelect~"]/released", 1);# setting the pylon as fired
          #print("firing missile: "~armSelect~" "~getprop("controls/armament/station["~armSelect~"]/released"));
        
          armament.AIM9.active[armSelect-1].release();#print("release "~(armSelect-1));
          #armament.AIM9_instance.del();
          #armament.AIM9_instance = armament.AIM9.new(0);
        }
      }
    }

    setprop("/controls/armament/station["~armSelect~"]/trigger", trigger);
    if (armSelect == 0) { # cannon
      # cannon is selected, set the cannons trigger to match the joystick trigger
      
    } else {
      # cannon is not selected, the cannon trigger is off
      setprop("/controls/armament/station[0]/trigger", 0);
    }
}
setlistener("controls/armament/trigger", trigger_listener, 0, 0);

var cycle_weapons = func {
  var sel = getprop("controls/armament/station-select");
  sel += 1;
  if(sel > 4) {
    sel = 0;
  }
  setprop("controls/armament/station-select", sel)
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

###############  Test which system the flightgear version support.  ###########

var test_support = func {
 
  var versionString = getprop("sim/version/flightgear");
  var version = split(".", versionString);
  if (version[0] == "0" or version[0] == "1") {
    gui.popupTip("JA-37 is only supported in Flightgear version 2.8 and upwards. Sorry.");
      setprop("sim/ja37/supported/radar", 0);
      setprop("sim/ja37/supported/hud", 0);
      setprop("sim/ja37/supported/options", 0);
      setprop("sim/ja37/supported/old-custom-fails", 0);
  } elsif (version[0] == "2") {
    if(version[1] == "0" or version[1] == "2" or version[1] == "4" or version[1] == "6") {
      gui.popupTip("JA-37 is only supported in Flightgear version 2.8 and upwards. Sorry.");
      setprop("sim/ja37/supported/radar", 0);
      setprop("sim/ja37/supported/hud", 0);
      setprop("sim/ja37/supported/options", 0);
      setprop("sim/ja37/supported/old-custom-fails", 1);
    } elsif(version[1] == "8") {
      gui.popupTip("JA-37 Canvas Radar and HUD is only supported in Flightgear version 2.10 and upwards. They have been disabled.");
      setprop("sim/ja37/supported/radar", 0);
      setprop("sim/ja37/supported/hud", 0);
      setprop("sim/ja37/supported/options", 0);
      setprop("sim/ja37/supported/old-custom-fails", 1);
      setprop("sim/ja37/hud/mode", 0);
    } else {
      setprop("sim/ja37/supported/radar", 1);
      setprop("sim/ja37/supported/hud", 1);
      setprop("sim/ja37/supported/options", 0);
      setprop("sim/ja37/supported/old-custom-fails", 1);
    }
  } elsif (version[0] == "3") {
    setprop("sim/ja37/supported/options", 1);
    setprop("sim/ja37/supported/radar", 1);
    setprop("sim/ja37/supported/hud", 1);
    if (version[1] == "1" or version[1] == "2") {
      setprop("sim/ja37/supported/old-custom-fails", 0);
    } else {
      setprop("sim/ja37/supported/old-custom-fails", 1);
    }
  }
  setprop("sim/ja37/supported/initialized", 1);

  print("********************************************************************************");
  print("**  Initializing Saab JA-37 Viggen systems. Version "~getprop("sim/aircraft-version")~" on Flightgear "~version[0]~"."~version[1]~"."~version[2]~"  **");
  print("********************************************************************************");

}

############################# main init ###############


var main_init = func {
  setprop("sim/time/elapsed-at-init-sec", getprop("sim/time/elapsed-sec"));

  test_support();


  setprop("/consumables/fuel/tank[8]/jettisoned", 0);
  # Load exterior at startup to avoid stale sim at first external view selection. ( taken from TU-154B )
  
  print("Loading exterior, wait...");
  # return to cabin to next cycle
  settimer( load_interior, 0 );
  setprop("/sim/current-view/view-number", 1);
  setprop("/sim/gui/tooltips-enabled", 1);
  
  # inst. light

  setprop("/instrumentation/instrumentation-light/r", 1.0);
  setprop("/instrumentation/instrumentation-light/g", 1.0);
  setprop("/instrumentation/instrumentation-light/b", 0.3);

  screen.log.write("Welcome to Saab JA-37 Viggen, version "~getprop("sim/aircraft-version"), 1.0, 0.0, 0.0);

  # start chronometer loop
  chrono_loop();

  # start the main loop
	settimer(func { update_loop() }, 0.1);
}

# re init
var re_init = func {
  print("Re-initializing JA-37 Viggen systems");
  
  setprop("sim/time/elapsed-at-init-sec", getprop("sim/time/elapsed-sec"));

  test_support();
}

var load_interior = func{
    setprop("/sim/current-view/view-number", 0);
    print("..Done!");
  }

var main_init_listener = setlistener("sim/signals/fdm-initialized", func {
	main_init();
	removelistener(main_init_listener);
 }, 0, 0);

var re_init_listener = setlistener("/sim/signals/reinit", func {
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
    setprop("payload/weight[4]/selected", "none");# empty the pylon
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
      if (getprop("sim/ja37/damage/crashed") < 1) {
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
