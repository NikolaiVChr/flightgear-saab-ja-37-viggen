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

reverserOn = func () {
  controlsEngine.getChild("reverser-cmd").setBoolValue(1);
  ja37.click();
}

var re_init_listener = setlistener("/sim/signals/reinit", func {
  #at reinit set thrust forward
  reverserPos.setValue(0.0);
  jsbEngine.getChild("reverser-angle-rad").setValue(0.0);
  controlsEngine.getChild("reverser").setBoolValue(0);
}, 0, 0);