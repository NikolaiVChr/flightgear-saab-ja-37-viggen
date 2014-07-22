# $Id$

var UPDATE_PERIOD = 0.1;

var g_curr 	= props.globals.getNode("accelerations/pilot-gdamped", 1);



############### Main loop ###############
var cnt = 0;

var update_loop = func {
	 ## Sets fuel gauge needles rotation ##
	 
   setprop("/instrumentation/fuel/needleF_rot", getprop("/consumables/fuel/total-fuel-norm")*230);
   
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
   
  ## set groundspeed property used for crashcode ##
  
  var horz_speed = getprop("/fdm/jsbsim/velocities/vg-fps");
  var vert_speed = getprop("/velocities/down-relground-fps");
     
  var real_speed = math.sqrt((horz_speed * horz_speed) + (vert_speed * vert_speed));
  
  real_speed = real_speed * 0.5924838;
  
  setprop("/velocities/groundspeed-3D-kt", real_speed); 
   
  
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


############################# main init ###############


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

############ strobes #####################

var strobe_switch = props.globals.getNode("controls/lighting/ext-lighting-panel/anti-collision", 1);
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
      if (getprop("fdm/jsbsim/simulation/crashed") < 1) {
      	settimer(autostart, 3);
      	setprop("/systems/electrical/battery", 1);
      	setprop("/systems/electrical/batterysignal", 1);
      	gui.popupTip("Battery turned on. Beginning startup procedure..");
      }
    }
 }