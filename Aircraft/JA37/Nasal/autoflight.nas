# Viggen Autoflight
# Copyright (c) 2019 Joshua Davidson (Octal450)

var maxMode = props.globals.getNode("/fdm/jsbsim/autoflight/max-mode");
var maxModeTemp = 0;
var athrCanEngage = props.globals.getNode("/fdm/jsbsim/autoflight/athr-can-engage");
var mode = props.globals.getNode("/fdm/jsbsim/autoflight/mode"); # 0 GSA, 1 STICK, 2 ATT, 3 ALT
var athr = props.globals.getNode("/fdm/jsbsim/autoflight/athr"); # 0 OFF, 1 ON
var highAlpha = props.globals.getNode("/fdm/jsbsim/autoflight/high-alpha"); # 0 OFF, 1 ON
var apSoftWarn = props.globals.getNode("/ja37/avionics/autopilot-soft-warn");
var apDowngradeMW = props.globals.getNode("/fdm/jsbsim/systems/indicators/master-warning/ap-downgrade");
var wow = props.globals.getNode("/fdm/jsbsim/position/wow");

var System = {
	engageMode: func(m) {
		if (m <= maxMode.getValue()) {
			me.downgradeCheck(m);
			mode.setValue(m);
		}
	},
	downgradeCheck: func(m) {
		#if (m < mode.getValue() and !apDowngradeMW.getBoolValue()) {
		#	apSoftWarn.setBoolValue(1);
		#}
	},
	trimStickKill: func() {
		if (!wow.getBoolValue() and mode.getValue() == 1) {
			me.engageMode(0); # GSA
		}
	},
	athrToggle: func() {
		if (athrCanEngage.getBoolValue()) {
			highAlpha.setBoolValue(0);
			athr.setBoolValue(!athr.getBoolValue());
		}
	},
	highAlphaToggle: func() {
		if (athrCanEngage.getBoolValue() and athr.getBoolValue()) {
			highAlpha.setBoolValue(!highAlpha.getBoolValue());
		}
	},
};

setlistener("/fdm/jsbsim/autoflight/max-mode-out", func {
	maxModeTemp = maxMode.getValue();
	if (maxModeTemp < mode.getValue()) {
		System.downgradeCheck(maxModeTemp);
		mode.setValue(maxModeTemp);
	} else if (maxModeTemp >= 1 and wow.getBoolValue() and mode.getValue() != 1) {
		System.downgradeCheck(1); # Theoretically, it would always be an upgrade, but lets do this just in case
		mode.setValue(1); # STICK
	}
}, 0, 0);

setlistener("/fdm/jsbsim/autoflight/athr-can-engage-out", func {
	if (!athrCanEngage.getBoolValue() and athr.getBoolValue() != 0) {
		athr.setBoolValue(0); # OFF
	}
}, 0, 0);
