togglereverser = func
{
  r1 = props.globals.getNode("/fdm/jsbsim/propulsion/engine[0]");
  r3 = props.globals.getNode("/controls/engines/engine[0]");
  r5 = props.globals.getNode("/sim/input/selected");
  rv1 = props.globals.getNode("/engines/engine[0]/reverser-pos-norm");

  val = rv1.getValue();
  if (val == 0 or val == nil) {
    ja37.click();
    gui.popupTip("Thrust: Reversed");
    interpolate(rv1.getPath(), 1.0, 1.0);  
    r1.getChild("reverser-angle-rad").setValue(2.0671);# Max 7716.18lbs thrust. So acos(-7716.18/16203.98).
    r3.getChild("reverser").setBoolValue(1);
    r5.getChild("engine").setBoolValue(1);
  } else {
    if (val == 1.0) {
      ja37.click();
      gui.popupTip("Thrust: Forward");
      interpolate(rv1.getPath(), 0.0, 1.0); 
      r1.getChild("reverser-angle-rad").setValue(0);
      r3.getChild("reverser").setBoolValue(0);
      r5.getChild("engine").setBoolValue(1);
    }  
  }
}