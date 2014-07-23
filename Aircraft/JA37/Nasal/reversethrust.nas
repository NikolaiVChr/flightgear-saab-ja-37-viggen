togglereverser = func
{
  r1 = props.globals.getNode("/fdm/jsbsim/propulsion/engine[0]");
  r3 = props.globals.getNode("/controls/engines/engine[0]");
  r5 = props.globals.getNode("/sim/input/selected");
  rv1 = props.globals.getNode("/engines/engine[0]/reverser-pos-norm");

  val = rv1.getValue();
  if (val == 0 or val == nil) {
    ja37.click();
    gui.popupTip("Reverse Thrust: ON");
    interpolate(rv1.getPath(), 1.0, 1.0);  
    r1.getChild("reverser-angle-rad").setValue(2.1866);# 125 degs. The thrust is in 150 degs, but some thrust is probably lost by pushing back on the outlet.
    r3.getChild("reverser").setBoolValue(1);
    r5.getChild("engine").setBoolValue(1);
  } else {
    if (val == 1.0) {
      ja37.click();
      gui.popupTip("Reverse Thrust: OFF");
      interpolate(rv1.getPath(), 0.0, 1.0); 
      r1.getChild("reverser-angle-rad").setValue(0);
      r3.getChild("reverser").setBoolValue(0);
      r5.getChild("engine").setBoolValue(1);
    }  
  }
}