var jsbEngine = props.globals.getNode("/fdm/jsbsim/propulsion/engine[0]");
var controlsEngine = props.globals.getNode("/controls/engines/engine[0]");
var reverserPos = props.globals.getNode("/engines/engine[0]/reverser-pos-norm");

var re_init_listener = setlistener("/sim/signals/reinit", func {
  #at reinit set thrust forward
  reverserPos.setValue(0.0);
  jsbEngine.getChild("reverser-angle-rad").setValue(0.0);
  controlsEngine.getChild("reverser").setBoolValue(0);
}, 0, 0);