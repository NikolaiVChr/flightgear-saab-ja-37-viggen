var jsbEngine = props.globals.getNode("/fdm/jsbsim/propulsion/engine[0]");
var controlsEngine = props.globals.getNode("/controls/engines/engine[0]");
var reverserPos = props.globals.getNode("/engines/engine[0]/reverser-pos-norm");
var reverserServ = props.globals.getNode("/controls/engines/engine[0]/reverse-system/serviceable");

togglereverser = func () {
  if (getprop("fdm/jsbsim/systems/hydraulics/system1/pressure") == nil or getprop("systems/electrical/outputs/dc-voltage") == nil
      or getprop("fdm/jsbsim/systems/hydraulics/system1/pressure") == 0 or getprop("systems/electrical/outputs/dc-voltage") < 23) {
    #Its important to tell people why the reversing fails, or they will think its a bug.
    ja37.popupTip("Thrust reverser lacks electricity or hydraulic pressure.");
  } elsif (reverserServ.getValue() == 1) {
    var reverserPosValue = reverserPos.getValue();
    if (reverserPosValue == 0 or reverserPosValue == nil) {
      #reverse thrust
      ja37.click();
      ja37.popupTip("Thrust: Reverse");
      interpolate(reverserPos.getPath(), 1.0, 1.5);  #reversing takes 1.5s per manual
      interpolate(jsbEngine.getChild("reverser-angle-rad"), 2.11223, 1.5);# Max 7716.18lbs thrust. So acos(-34323.27876347009N / 66600N).
      controlsEngine.getChild("reverser").setBoolValue(1);
    } else {
      if (reverserPosValue == 1.0) {
        #forward thrust
        ja37.click();
        ja37.popupTip("Thrust: Forward");
        interpolate(reverserPos.getPath(), 0.0, 1.5); #reversing takes 1.5s per manual
        interpolate(jsbEngine.getChild("reverser-angle-rad"), 0, 1.5);
        controlsEngine.getChild("reverser").setBoolValue(0);
      }  else {
        #print(reverserPosValue);
      }
    }
  }
}

var re_init_listener = setlistener("/sim/signals/reinit", func {
  #at reinit set thrust forward
  reverserPos.setValue(0.0);
  jsbEngine.getChild("reverser-angle-rad").setValue(0.0);
  controlsEngine.getChild("reverser").setBoolValue(0);
}, 0, 0);