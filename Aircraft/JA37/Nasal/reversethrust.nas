var jsbEngine = props.globals.getNode("/fdm/jsbsim/propulsion/engine[0]");
var controlsEngine = props.globals.getNode("/controls/engines/engine[0]");
var reverserPos = props.globals.getNode("/engines/engine[0]/reverser-pos-norm");
var reversed = props.globals.getNode("/engines/engine[0]/is-reversed");
var reverserServ = props.globals.getNode("/controls/engines/engine[0]/reverse-system/serviceable");
var dcVolt = props.globals.getNode("systems/electrical/outputs/dc-voltage");
var hydr1  = props.globals.getNode("fdm/jsbsim/systems/hydraulics/system1/pressure");

togglereverser = func () {
  var current = controlsEngine.getChild("reverser-cmd").getValue();
  var command = !current;
  controlsEngine.getChild("reverser-cmd").setBoolValue(command);
  ja37.click();
}

reverse_loop = func () {
  var command = controlsEngine.getChild("reverser-cmd").getValue();
  if (hydr1.getValue() == nil or dcVolt.getValue() == nil
      or hydr1.getValue() == 0 or dcVolt.getValue() < 23) {
    #Its important to tell people why the reversing fails, or they will think its a bug.
    #ja37.popupTip("Thrust reverser lacks electricity or hydraulic pressure.");
  } elsif (reverserServ.getValue() == 1) {
    var reverserPosValue = reverserPos.getValue();
    if ((reverserPosValue == 0 or reverserPosValue == nil) and command == 1) {
      #reverse thrust      
      ja37.popupTip("Thrust: Reverse");
      interpolate(reverserPos.getPath(), 1.0, 1.5);  #reversing takes 1.5s per manual
      interpolate(jsbEngine.getChild("reverser-angle-rad"), 2.0669551, 1.5);# Max 7716.18lbs thrust. So acos(-34323.27876347009N / 72100N).
    } elsif (command == 0) {
      if (reverserPosValue == 1.0) {
        #forward thrust
        ja37.popupTip("Thrust: Forward");
        interpolate(reverserPos.getPath(), 0.0, 1.5); #reversing takes 1.5s per manual
        interpolate(jsbEngine.getChild("reverser-angle-rad"), 0, 1.5);
      }  else {
        #print(reverserPosValue);
      }
    }
  }
  if (reverserPos.getValue() == 1) {
    reversed.setBoolValue(1);
  } else {
    reversed.setBoolValue(0);
  }
  settimer(reverse_loop, 0.5);
}

reverse_loop();

var re_init_listener = setlistener("/sim/signals/reinit", func {
  #at reinit set thrust forward
  reverserPos.setValue(0.0);
  jsbEngine.getChild("reverser-angle-rad").setValue(0.0);
  controlsEngine.getChild("reverser").setBoolValue(0);
}, 0, 0);