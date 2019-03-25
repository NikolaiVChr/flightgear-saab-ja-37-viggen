# Viggen Autoflight
# Copyright (c) 2019 Joshua Davidson (it0uchpods)

var canEngage = props.globals.getNode("/fdm/jsbsim/autoflight/can-engage");
var mode = props.globals.getNode("/fdm/jsbsim/autoflight/mode"); # 0 GSA, 1 STICK, 2 ATT, 3 ALT
var apSoftWarn = props.globals.getNode("/ja37/avionics/autopilot-soft-warn");
var apDowngradeMW = props.globals.getNode("/fdm/jsbsim/systems/indicators/master-warning/ap-downgrade");

var System = {
	engageMode: func(m) {
		if (canEngage.getBoolValue()) {
			me.downgradeCheck(m);
			mode.setValue(m);
		}
	},
	downgradeCheck: func(m) {
		if (m < mode.getValue() and !apDowngradeMW.getBoolValue()) {
			apSoftWarn.setBoolValue(1);
		}
	},
};

setlistener("/fdm/jsbsim/autoflight/can-engage-out", func {
	if (!canEngage.getBoolValue() and mode.getValue() != 0) {
		System.downgradeCheck(0);
		mode.setValue(0); # GSA
	}
}, 0, 0);
