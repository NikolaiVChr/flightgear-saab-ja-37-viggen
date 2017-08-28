inputAP = {
  apLockAlt:        "autopilot/locks/altitude",
  apLockHead:       "autopilot/locks/heading",
  apLockSpeed:      "autopilot/locks/speed",  
  indAA:            "ja37/avionics/auto-altitude-on",
  indAAH:           "ja37/avionics/auto-altitude-hold-on",
  indAH:            "ja37/avionics/auto-attitude-on",
  indAT:            "ja37/avionics/auto-throttle-on",
  hydr1On:          "fdm/jsbsim/systems/hydraulics/system1/pressure",
  dcVolt:           "systems/electrical/outputs/dc-voltage",
  acMainVolt:       "systems/electrical/outputs/ac-main-voltage",
  elapsed:          "sim/time/elapsed-sec",
};

var FALSE = 0;
var TRUE = 1;

var DEBUG_OUT = FALSE;

var extrapolate = func (x, x1, x2, y1, y2) {
    return y1 + ((x - x1) / (x2 - x1)) * (y2 - y1);
};

# setup property nodes for the loop
foreach(var name; keys(inputAP)) {
    inputAP[name] = props.globals.getNode(inputAP[name], 1);
}

var follow = func () {
  setprop("/autopilot/target-tracking-ja37/enable", FALSE);
  if(radar_logic.selection != nil and radar_logic.selection.getNode() != nil) {
    land.noMode();
    mode = ja37.clamp(mode, 0, 1);
    var target = radar_logic.selection.getNode();
    setprop("/autopilot/target-tracking-ja37/target-root", target.getPath());
    #this is done in -set file: /autopilot/target-tracking-ja37/min-speed-kt
    setprop("/autopilot/target-tracking-ja37/enable", TRUE);
    var range = 0.075;
    setprop("/autopilot/target-tracking-ja37/goal-range-nm", range);
    ja37.popupTip("A/P follow: ON");

    setprop("autopilot/settings/target-altitude-ft", 10000);# set some default values until the follow script sets them.
    setprop("autopilot/settings/heading-bug-deg", 0);
    setprop("autopilot/settings/target-speed-kt", 200);

    setprop("/autopilot/locks/speed", "speed-with-throttle");
    setprop("/autopilot/locks/altitude", "altitude-hold");
    setprop("/autopilot/locks/heading", "dg-heading-hold");
  } else {
    setprop("/autopilot/target-tracking-ja37/enable", FALSE);
    ja37.popupTip("A/P follow: no valid target.");
    setprop("/autopilot/locks/speed", "");
    setprop("/autopilot/locks/altitude", "");
    setprop("/autopilot/locks/heading", "");
  }
}

var lostAC_sec = -1;
var lostAC_time = 0;

var lostDC_sec = -1;
var lostDC_time = 0;

var outside_bounds_sec = -1;
var outside_bounds_time = 0;

var transonic_sec = -1;
var transonic_time = 0;

var hydr1Lost = func {
  #if hydraulic system1 loses pressure or too low voltage then disengage A/P.
  var ap = TRUE;
  if (inputAP.hydr1On.getValue() == 0) {
    ap = FALSE;
  }
  if (inputAP.dcVolt.getValue() < 23) {
    ap = FALSE;
    if (lostDC_sec == -1) {
      lostDC_sec = 0;
      lostDC_time = inputAP.elapsed.getValue();
    } else {
      lostDC_sec = inputAP.elapsed.getValue() - lostDC_time;
    }
  } else {
    lostDC_sec = -1;
  }
  if (lostAC_sec == -1 and inputAP.acMainVolt.getValue() < 150) {
    lostAC_sec = 0;
    lostAC_time = inputAP.elapsed.getValue();
  } elsif (lostAC_sec != -1 and inputAP.acMainVolt.getValue() < 150) {
    lostAC_sec = inputAP.elapsed.getValue() - lostAC_time;
  } else {
    lostAC_sec = -1;
  }
  var outside = getprop("controls/flight/aileron-cmd-ap") == 0 and math.abs(getprop("controls/flight/elevator-cmd-ap")) < 0.075 and (math.abs(getprop("orientation/roll-deg")) > 66 or getprop("orientation/pitch-deg") > 60);
  if (outside_bounds_sec == -1 and outside) {
    outside_bounds_sec = 0;
    outside_bounds_time = inputAP.elapsed.getValue();
  } elsif (outside_bounds_sec != -1 and outside) {
    outside_bounds_sec = inputAP.elapsed.getValue() - outside_bounds_time;
  } else {
    outside_bounds_sec = -1;
  }
  var transonic = getprop("/instrumentation/airspeed-indicator/indicated-mach") > 0.97 and getprop("/instrumentation/airspeed-indicator/indicated-mach") < 1.05;
  if (transonic_sec == -1 and transonic) {
    transonic_sec = 0;
    transonic_time = inputAP.elapsed.getValue();
  } elsif (transonic_sec != -1 and transonic) {
    transonic_sec = inputAP.elapsed.getValue() - transonic_time;
  } else {
    transonic_sec = -1;
  }
  
  setprop("ja37/avionics/autopilot", ap);
  setprop("ja37/avionics/lost-ac-sec", lostAC_sec);
  setprop("ja37/avionics/lost-dc-sec", lostDC_sec);
  setprop("ja37/avionics/transonic-sec", transonic_sec);
  setprop("ja37/avionics/ap-outside-bounds-sec", outside_bounds_sec);
  settimer(hydr1Lost, 0.5);
}

var unfollow = func () {
  ja37.popupTip("A/P follow: OFF");
  stopAP();
}

var unfollowSilent = func () {
  stopAP();
}

var stopAP = func {
  setprop("/autopilot/target-tracking-ja37/enable", FALSE);
  setprop("/autopilot/locks/speed", "");
  setprop("/autopilot/locks/altitude", "");
  setprop("/autopilot/locks/heading", "");
  mode = ja37.clamp(mode, 0,1);
}

var lostfollow = func () {
  ja37.popupTip("A/P follow: lost target.");
  stopAP();
}

var apCont = func {
  unfollow();
  setprop("autopilot/settings/target-altitude-ft", getprop("instrumentation/altimeter/indicated-altitude-ft"));
  setprop("autopilot/settings/heading-bug-deg", getprop("orientation/heading-magnetic-deg"));
  setprop("autopilot/settings/target-speed-kt", getprop("instrumentation/airspeed-indicator/indicated-speed-kt"));

  setprop("/autopilot/locks/speed", "speed-with-throttle");
  setprop("/autopilot/locks/altitude", "altitude-hold");
  setprop("/autopilot/locks/heading", "dg-heading-hold");

  screen.log.write("A/P continuing on current heading, speed and altitude.", 0.0, 1.0, 0.0);
}

var mode = 1;
var modeT = 0;
var prevMode = 1;
var softWarn = FALSE;
setprop("/autopilot/locks/speed", "");
setprop("/autopilot/locks/altitude", "");
setprop("/autopilot/locks/heading", "");
var lockThrottle = getprop("/autopilot/locks/speed");
var lockAtt      = getprop("/autopilot/locks/heading");
var lockPitch    = getprop("/autopilot/locks/altitude");

var menuOff = func {
  lockThrottle = getprop("/autopilot/locks/speed");
  lockAtt      = getprop("/autopilot/locks/heading");
  lockPitch    = getprop("/autopilot/locks/altitude"); 
  menu = FALSE; 
}

var mode1 = func {
  setprop("/autopilot/target-tracking-ja37/enable", FALSE);
  if (mode == 0) {
    apContDamp();
  } elsif (mode > 1) {
    softWarn = TRUE;
  }
  mode = 1;  
  if (DEBUG_OUT) print("button cmd mode "~mode);
  menuOff();
};

var mode2 = func {
  setprop("/autopilot/target-tracking-ja37/enable", FALSE);
  if (mode == 3) {
    softWarn = TRUE;
  } elsif (mode == 0) {
    apContDamp();
  }
  mode = 2;
  if (DEBUG_OUT) print("button cmd mode "~mode);
  menuOff();
};

var mode3 = func {
  setprop("/autopilot/target-tracking-ja37/enable", FALSE);
  if (mode == 0) {
    apContDamp();
  }
  mode = 3;
  if (DEBUG_OUT) print("button cmd mode "~mode);
  menuOff();
};

var apContDamp = func {
  setprop("fdm/jsbsim/fcs/pitch-damper/enable", TRUE);
  setprop("fdm/jsbsim/fcs/roll-damper/enable", TRUE);
  setprop("fdm/jsbsim/fcs/yaw-damper/enable", TRUE);
};

var apStopDamp = func {
  setprop("fdm/jsbsim/fcs/pitch-damper/enable", FALSE);
  setprop("fdm/jsbsim/fcs/roll-damper/enable", FALSE);
  setprop("fdm/jsbsim/fcs/yaw-damper/enable", FALSE);
};

var apContAtt = func {
  setprop("/autopilot/target-tracking-ja37/enable", FALSE);

  if(getprop("orientation/pitch-deg") < 60) {
    if((getprop("orientation/roll-deg") < -7 and getprop("orientation/roll-deg") > -66) or (getprop("orientation/roll-deg") > 7 and getprop("orientation/roll-deg") < 66) or getprop("gear/gear/position-norm") == 1) {
      apContRoll();
    } else {
      apContHead();
    }
    apContPitch();
  }  
}

var apStopAtt = func {
  setprop("/autopilot/locks/heading", "");
  setprop("/autopilot/locks/altitude", "");
  lockAtt   = "";
  lockPitch = "";
}

var apContRoll = func {
  # roll lock
  setprop("/autopilot/locks/heading", "");
  setprop("autopilot/internal/target-roll-deg", getprop("orientation/roll-deg"));
  setprop("/autopilot/locks/heading", "dg-roll-hold");
  lockAtt = "dg-roll-hold";
};

var apContHead = func {
  # heading lock
  setprop("autopilot/settings/heading-bug-deg", getprop("orientation/heading-magnetic-deg"));
  setprop("/autopilot/locks/heading", "dg-heading-hold");
  lockAtt = "dg-heading-hold";
};

var apContPitch = func {
  # pitch lock
  setprop("/autopilot/locks/altitude", "pitch-hold");
  setprop("/autopilot/settings/target-pitch-deg", getprop("/orientation/pitch-deg"));
  lockPitch = "pitch-hold";
};

var apStopPitch = func {
  # pitch lock
  setprop("/autopilot/locks/altitude", "");
  lockPitch = "";
};

var apContAlt = func {
  # alt lock
  setprop("/autopilot/target-tracking-ja37/enable", FALSE);
  setprop("autopilot/settings/target-altitude-ft", getprop("instrumentation/altimeter/indicated-altitude-ft"));
  setprop("/autopilot/locks/altitude", "altitude-hold");
  lockPitch = "altitude-hold";
}

var apStopAlt = func {
  # alt lock
  setprop("/autopilot/locks/altitude", "");
  lockPitch = "";
}

var apContSpeed = func {
  # a/t lock
  if (!(getprop("/autopilot/locks/speed") == "" or getprop("/autopilot/locks/speed") == nil)) {
    apStopAT();
  } else {
    setprop("/autopilot/target-tracking-ja37/enable", FALSE);
    setprop("autopilot/settings/target-speed-kt", getprop("instrumentation/airspeed-indicator/indicated-speed-kt"));
    setprop("/autopilot/locks/speed", "speed-with-throttle");
    modeT = 1;
    lockThrottle = "speed-with-throttle";
  }
}

var apStopAT = func {
  # stop auto throttle
  setprop("/autopilot/locks/speed", "");
  modeT = 0;
}

var lock = "";
var lockP = "";
var usedStick = 0;
var menu = FALSE;

var apLoop = func {
    if (DEBUG_OUT) print("looping:");
    if (getprop("fdm/jsbsim/systems/indicators/master-warning/ap-downgrade") == 1) {
      # downgrade warning has been clicked away, remove it:
      setprop("/ja37/avionics/autopilot-soft-warn", FALSE);
    }
    if (mode > 0 and (getprop("fdm/jsbsim/fcs/pitch-damper/enable") == FALSE   or getprop("fdm/jsbsim/fcs/pitch-damper/serviceable") == FALSE 
                      or getprop("fdm/jsbsim/fcs/roll-damper/enable") == FALSE or getprop("fdm/jsbsim/fcs/roll-damper/serviceable") == FALSE
                      or getprop("fdm/jsbsim/fcs/yaw-damper/enable") == FALSE  or getprop("fdm/jsbsim/fcs/yaw-damper/serviceable") == FALSE)) {
      softWarn = TRUE;
      mode = 0;
      if (DEBUG_OUT) print("lack of dampers cmd mode "~mode);
    }
    if (mode == 0 and getprop("fdm/jsbsim/fcs/pitch-damper/enable") == TRUE and getprop("fdm/jsbsim/fcs/pitch-damper/serviceable") == TRUE
                  and getprop("fdm/jsbsim/fcs/roll-damper/enable")  == TRUE and getprop("fdm/jsbsim/fcs/roll-damper/serviceable") == TRUE
                  and getprop("fdm/jsbsim/fcs/yaw-damper/enable")   == TRUE and getprop("fdm/jsbsim/fcs/yaw-damper/serviceable") == TRUE) {
      mode = 1;
      if (DEBUG_OUT) print("dampers cmd mode "~mode);
    }
    if (lostDC_sec > 6) {
      # if dc lost then A/P wont function, it will resume at dc unless 6 secs has passed:
      mode = mode == 0?0:1;
      if (DEBUG_OUT) print("loss of DC cmd mode "~mode);
    }
    if (getprop("fdm/jsbsim/systems/indicators/auto-altitude-primary") == 1) {
      # 
      mode = ja37.clamp(mode, 0, 2);
      if (DEBUG_OUT) print("alt indicator cmd mode "~mode);
    }
    if (getprop("fdm/jsbsim/systems/indicators/auto-attitude-primary") == 1) {
      # 
      mode = ja37.clamp(mode, 0, 1);
      if (DEBUG_OUT) print("att indicator cmd mode "~mode);
    }
    if (getprop("fdm/jsbsim/systems/indicators/flightstick-primary") == 1) {
      # 
      #mode = 0;
      #apStopDamp();
    }
    if (inputAP.hydr1On.getValue() == 0) {
      # 
      mode = ja37.clamp(mode, 0, 1);
      if (DEBUG_OUT) print("hydr cmd mode "~mode);
    }

    # auto-pilot engaged

    if (size(inputAP.apLockSpeed.getValue()) == 0) {
      inputAP.indAT.setBoolValue(FALSE);
    } else {
      inputAP.indAT.setBoolValue(TRUE);
    }

    if (inputAP.apLockHead.getValue() == "") {
      inputAP.indAH.setBoolValue(FALSE);
    } else {
      inputAP.indAH.setBoolValue(TRUE);
    }

    if (inputAP.apLockAlt.getValue() == "") {
      inputAP.indAA.setBoolValue(FALSE);
      inputAP.indAAH.setBoolValue(FALSE);
    } else {
      inputAP.indAA.setBoolValue(TRUE);
      if (inputAP.apLockAlt.getValue() == "altitude-hold") {
        inputAP.indAAH.setBoolValue(TRUE);
      } else {
        inputAP.indAAH.setBoolValue(FALSE);
      }
    }

  #
  # menu intervention
  #
  if (inputAP.apLockSpeed.getValue() != lockThrottle) {
    modeT = 0;
  }
  if (inputAP.apLockHead.getValue() != lockAtt) {
    mode = mode==0?0:1;
    menu = TRUE;
    if (DEBUG_OUT) print("menu head cmd mode "~mode);
  }
  if (inputAP.apLockAlt.getValue() != lockPitch) {
    mode = mode==0?0:1;
    menu = TRUE;
    if (DEBUG_OUT) print("menu pitch cmd mode "~mode~" "~inputAP.apLockAlt.getValue()~" != "~lockPitch);
  }

  #
  # modes
  #
  if (prevMode != mode and menu == FALSE) {
    if (mode < 3) {
      apStopAlt();
    }
    if (mode < 2) {
      apStopAtt();
    }
    if (mode < 1) {
      #apStopDamp();  don't have any controls for this yet.
    }
    if (mode == 3) {
      apContDamp();
      apContAtt();
      apStopPitch();
      apContAlt();
    }
    if (mode == 2) {
      apContDamp();
      apContAtt();
    }
    if (mode == 1) {
      apContDamp();
    }
  }
  setprop("/ja37/avionics/autopilot-mode", mode);
  prevMode = mode;
  if (softWarn == TRUE) {
    setprop("/ja37/avionics/autopilot-soft-warn", TRUE);
    softWarn = FALSE;
  }

  #
  # Auto-throttle
  #
  if(getprop("gear/gear[2]/wow") == 1 or (getprop("/autopilot/locks/speed") == "speed-with-throttle" and lostAC_sec > 6) or (getprop("/autopilot/locks/speed") == "constant-AoA" and lostAC_sec > 2)) {
    apStopAT();
  } elsif (getprop("/autopilot/locks/speed") == "speed-with-throttle") {
    if(getprop("fdm/jsbsim/autopilot/AoA-hold") == 1) {
      setprop("/autopilot/locks/speed", "constant-AoA");
      lockThrottle = "constant-AoA";
    } elsif (getprop("/autopilot/settings/target-speed-kt") < 297) {
      setprop("/autopilot/settings/target-speed-kt", 297);
    }
  } elsif (getprop("/autopilot/locks/speed") == "constant-AoA") {
    if(getprop("fdm/jsbsim/autopilot/AoA-hold") == 0) {
      setprop("autopilot/settings/target-speed-kt", getprop("instrumentation/airspeed-indicator/indicated-speed-kt"));
      setprop("/autopilot/locks/speed", "speed-with-throttle");
      lockThrottle = "speed-with-throttle";
      modeT = 1;
    } elsif (getprop("ja37/avionics/high-alpha") == 1) {
      setprop("/autopilot/settings/target-aoa", 15.5);
      modeT = 3;
    } else {
      var weight = getprop("fdm/jsbsim/inertia/weight-lbs")*LB2KG;
      var aoa = extrapolate(weight, 15000, 16500, 15.5, 9.0);
      aoa = ja37.clamp(aoa, 9, 12);
      setprop("/autopilot/settings/target-aoa", aoa);#is 9-12 depending on weight
      modeT = 2;
    }
  }

  #
  # Auto-roll
  #
  if (mode > 1 and getprop("/autopilot/locks/heading") == "dg-heading-hold" and getprop("gear/gear/position-norm") == 1) {
    # we no longer have conditions for heading hold in mode 2/3, we switch to roll hold.
    apContRoll();
    if (DEBUG_OUT) print("switched to roll hold due to gears got extended");
  }
  var trimCmd = getprop("controls/flight/trim-yaw");
  var rollCmd = getprop("controls/flight/aileron-cmd-ap");
  if (trimCmd == nil) {
    trimCmd = 0;
  }
  if (getprop("/autopilot/locks/heading") != "" and getprop("/autopilot/locks/heading") != nil and trimCmd != 0) {
    # Pilot is using yaw trim to adjust attitude A/P
    lock = getprop("/autopilot/locks/heading");
    # stop A/P from controlling roll:
    setprop("ja37/avionics/temp-halt-ap-roll", 0);
    # increase roll
    setprop("autopilot/internal/target-roll-deg", getprop("orientation/roll-deg") + trimCmd * 1);
  } elsif (getprop("/autopilot/locks/heading") != "" and getprop("/autopilot/locks/heading") != nil and rollCmd != 0) {
    # Pilot is using stick lateral motion to adjust attitude A/P
    lock = getprop("/autopilot/locks/heading");
    # stop A/P from controlling pitch:
    setprop("ja37/avionics/temp-halt-ap-roll2", 0);
    usedStick = 1;
  } elsif (lock != "") {
    # keep new heading/roll
    lock = "";
    if (getprop("/autopilot/locks/heading") == "dg-heading-hold") {
      setprop("autopilot/settings/heading-bug-deg", getprop("orientation/heading-magnetic-deg"));
    } elsif (getprop("/autopilot/locks/heading") == "true-heading-hold") {
      setprop("autopilot/settings/true-heading-deg", getprop("orientation/heading-deg"));
    } elsif (getprop("/autopilot/locks/heading") == "nav1-hold") {
      # nop
    }
    setprop("ja37/avionics/temp-halt-ap-roll", 1);
    setprop("ja37/avionics/temp-halt-ap-roll2", 1);
    if (usedStick == 1) {
      setprop("autopilot/internal/target-roll-deg", getprop("orientation/roll-deg"));
      usedStick = 0;
    }
  } else {
    if(trimCmd != 0) {
      setprop("/controls/flight/rudder-trim", getprop("/controls/flight/rudder-trim") + trimCmd * 0.01);
    }
  }

  var pitchCmd = getprop("controls/flight/elevator-cmd-ap");
  if (getprop("/autopilot/locks/altitude") != "" and getprop("/autopilot/locks/altitude") != nil and math.abs(pitchCmd) > 0.075) {
    # Pilot is using stick to adjust altitude A/P
    lockP = getprop("/autopilot/locks/altitude");
    # stop A/P from controlling pitch:
    setprop("ja37/avionics/temp-halt-ap-pitch", 0);
  } elsif (lockP != "") {
    # keep new altitude/pitch/AoA/vertical-speed
    lockP = "";
    if (getprop("/autopilot/locks/altitude") == "altitude-hold") {
      setprop("autopilot/settings/target-altitude-ft", getprop("instrumentation/altimeter/indicated-altitude-ft"));
    } elsif (getprop("/autopilot/locks/altitude") == "pitch-hold") {
      setprop("/autopilot/settings/target-pitch-deg", getprop("/orientation/pitch-deg"));
    } elsif (getprop("/autopilot/locks/altitude") == "vertical-speed-hold") {
      setprop("/autopilot/settings/vertical-speed-fpm", getprop("/velocities/vertical-speed-fps")*60);
    } elsif (getprop("/autopilot/locks/altitude") == "aoa-hold") {
      setprop("/autopilot/settings/target-aoa-deg", getprop("/orientation/alpha-deg"));
    } elsif (getprop("/autopilot/locks/altitude") == "agl-hold") {
      setprop("autopilot/settings/target-agl-ft", getprop("position/altitude-agl-ft"));
    }
    setprop("ja37/avionics/temp-halt-ap-pitch", 1);
  }

  settimer(apLoop, 0.1);
}

var ap_init_listener = setlistener("sim/signals/fdm-initialized", func {
  apLoop();
  hydr1Lost();
  removelistener(ap_init_listener);
}, 0, 0);

var apLoop2 = func {
  setprop("controls/flight/trim-yaw", 0);
  settimer(apLoop2, 0.5);
}

#apLoop2();