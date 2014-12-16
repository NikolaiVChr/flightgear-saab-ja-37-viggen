jsbEngine = props.globals.getNode("/fdm/jsbsim/propulsion/engine[0]");
controlsEngine = props.globals.getNode("/controls/engines/engine[0]");
#inputSelected = props.globals.getNode("/sim/input/selected");
reverserPos = props.globals.getNode("/engines/engine[0]/reverser-pos-norm");

togglereverser = func
{
  reverserPosValue = reverserPos.getValue();
  if (reverserPosValue == 0 or reverserPosValue == nil) {
    #reverse thrust
    ja37.click();
    ja37.popupTip("Thrust: Reverse");
    interpolate(reverserPos.getPath(), 1.0, 1.0);  
    jsbEngine.getChild("reverser-angle-rad").setValue(2.0671);# Max 7716.18lbs thrust. So acos(-7716.18/16203.98).
    controlsEngine.getChild("reverser").setBoolValue(1);
    #inputSelected.getChild("engine").setBoolValue(1);
  } else {
    if (reverserPosValue == 1.0) {
      #forward thrust
      ja37.click();
      ja37.popupTip("Thrust: Forward");
      interpolate(reverserPos.getPath(), 0.0, 1.0); 
      jsbEngine.getChild("reverser-angle-rad").setValue(0);
      controlsEngine.getChild("reverser").setBoolValue(0);
      #inputSelected.getChild("engine").setBoolValue(1);
    }  
  }
}

var re_init_listener = setlistener("/sim/signals/reinit", func {
  #at reinit set thrust forward
  reverserPos.setValue(0.0);
  jsbEngine.getChild("reverser-angle-rad").setValue(0.0);
  controlsEngine.getChild("reverser").setBoolValue(0);
#  inputSelected.getChild("engine").setBoolValue(1);
 }, 0, 0);