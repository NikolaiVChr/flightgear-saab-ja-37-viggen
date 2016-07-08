inputAP = {
  apLockAlt:        "autopilot/locks/altitude",
  apLockHead:       "autopilot/locks/heading",
  apLockSpeed:      "autopilot/locks/speed",  
  indAA:            "ja37/avionics/auto-altitude-on",
  indAH:            "ja37/avionics/auto-attitude-on",
  indAT:            "ja37/avionics/auto-throttle-on",
};

# setup property nodes for the loop
foreach(var name; keys(inputAP)) {
    inputAP[name] = props.globals.getNode(inputAP[name], 1);
}

var follow = func () {
  setprop("/autopilot/target-tracking-ja37/enable", FALSE);
  if(radar_logic.selection != nil and radar_logic.selection.getNode() != nil) {
    var target = radar_logic.selection.getNode();
    setprop("/autopilot/target-tracking-ja37/target-root", target.getPath());
    #this is done in -set file: /autopilot/target-tracking-ja37/min-speed-kt
    setprop("/autopilot/target-tracking-ja37/enable", TRUE);
    var range = 0.075;
    setprop("/autopilot/target-tracking-ja37/goal-range-nm", range);
    popupTip("A/P follow: ON");

    setprop("autopilot/settings/target-altitude-ft", 10000);# set some default values until the follow script sets them.
    setprop("autopilot/settings/heading-bug-deg", 0);
    setprop("autopilot/settings/target-speed-kt", 200);

    setprop("/autopilot/locks/speed", "speed-with-throttle");
    setprop("/autopilot/locks/altitude", "altitude-hold");
    setprop("/autopilot/locks/heading", "dg-heading-hold");
  } else {
    setprop("/autopilot/target-tracking-ja37/enable", FALSE);
    popupTip("A/P follow: no valid target.");
    setprop("/autopilot/locks/speed", "");
    setprop("/autopilot/locks/altitude", "");
    setprop("/autopilot/locks/heading", "");
  }
}

var hydr1Lost = func {
  #if hydraulic system1 loses pressure or too low voltage then disengage A/P.
  if (input.hydr1On.getValue() == 0 or input.dcVolt.getValue() < 23) {
    setprop("ja37/avionics/autopilot", FALSE);
    #stopAP();
  } else {
    setprop("ja37/avionics/autopilot", TRUE);
  }
  settimer(hydr1Lost, 1);
}

var unfollow = func () {
  popupTip("A/P follow: OFF");
  stopAP();
}

var stopAP = func {
  setprop("/autopilot/target-tracking-ja37/enable", FALSE);
  setprop("/autopilot/locks/speed", "");
  setprop("/autopilot/locks/altitude", "");
  setprop("/autopilot/locks/heading", "");
}

var lostfollow = func () {
  popupTip("A/P follow: lost target.");
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

var apContAtt = func {
  setprop("/autopilot/target-tracking-ja37/enable", FALSE);

  if (!(getprop("/autopilot/locks/heading") == "" or getprop("/autopilot/locks/heading") == nil)) {
    setprop("/autopilot/locks/heading", "");
  } else {
    if(getprop("orientation/pitch-deg") < 60) {
      if((getprop("orientation/roll-deg") < -7 and getprop("orientation/roll-deg") > -66) or (getprop("orientation/roll-deg") > 7 and getprop("orientation/roll-deg") < 66) or getprop("gear/gear/position-norm") == 1) {
        # roll lock
        setprop("/autopilot/locks/heading", "");
        setprop("autopilot/internal/target-roll-deg", getprop("orientation/roll-deg"));
        setprop("/autopilot/locks/heading", "dg-roll-hold");
      } else {
        # heading lock
        setprop("autopilot/settings/heading-bug-deg", getprop("orientation/heading-magnetic-deg"));
        setprop("/autopilot/locks/heading", "dg-heading-hold");
      }
    }
  }
}

var apContAlt = func {
  if (!(getprop("/autopilot/locks/altitude") == "" or getprop("/autopilot/locks/altitude") == nil)) {
    setprop("/autopilot/locks/altitude", "");
  } else {
    setprop("/autopilot/target-tracking-ja37/enable", FALSE);
    setprop("autopilot/settings/target-altitude-ft", getprop("instrumentation/altimeter/indicated-altitude-ft"));
    setprop("/autopilot/locks/altitude", "altitude-hold");
  }
}

var apContSpeed = func {
  if (!(getprop("/autopilot/locks/speed") == "" or getprop("/autopilot/locks/speed") == nil)) {
    setprop("/autopilot/locks/speed", "");
  } else {
    setprop("/autopilot/target-tracking-ja37/enable", FALSE);
    setprop("autopilot/settings/target-speed-kt", getprop("instrumentation/airspeed-indicator/indicated-speed-kt"));
    setprop("/autopilot/locks/speed", "speed-with-throttle");
  }
}

var apStopAT = func {
  # stop auto throttle
  setprop("/autopilot/locks/speed", "");
}

var lock = "";
var lockP = "";
var usedStick = 0;

var apLoop = func {

    # auto-pilot engaged

    if (size(input.apLockSpeed.getValue()) == 0) {
      input.indAT.setBoolValue(FALSE);
    } else {
      input.indAT.setBoolValue(TRUE);
    }

    if (input.apLockHead.getValue() == "") {
      input.indAH.setBoolValue(FALSE);
    } else {
      input.indAH.setBoolValue(TRUE);
    }

    if (input.apLockAlt.getValue() == "") {
      input.indAA.setBoolValue(FALSE);
    } else {
      input.indAA.setBoolValue(TRUE);
    }

  if(getprop("gear/gear[2]/wow") == 1) {
    apStopAT();
  } elsif (getprop("/autopilot/locks/speed") == "speed-with-throttle") {
    if(getprop("fdm/jsbsim/autopilot/AoA-hold") == 1) {
      setprop("/autopilot/locks/speed", "constant-AoA");
    } elsif (getprop("/autopilot/settings/target-speed-kt") < 297) {
      setprop("/autopilot/settings/target-speed-kt", 297);
    }
  } elsif (getprop("/autopilot/locks/speed") == "constant-AoA") {
    if(getprop("fdm/jsbsim/autopilot/AoA-hold") == 0) {
      setprop("autopilot/settings/target-speed-kt", getprop("instrumentation/airspeed-indicator/indicated-speed-kt"));
      setprop("/autopilot/locks/speed", "speed-with-throttle");
    } elsif (getprop("ja37/avionics/high-alpha") == 1) {
      setprop("/autopilot/settings/target-aoa", 15.5);
    } else {
      var weight = getprop("fdm/jsbsim/inertia/weight-lbs");
      var aoa = 9 + ((weight - 28000) / (38000 - 28000)) * (12 - 9);
      aoa = clamp(aoa, 9, 12);
      setprop("/autopilot/settings/target-aoa", aoa);#is 9-12 depending on weight
    }
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
  if (getprop("/autopilot/locks/altitude") != "" and getprop("/autopilot/locks/altitude") != nil and pitchCmd != 0) {
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