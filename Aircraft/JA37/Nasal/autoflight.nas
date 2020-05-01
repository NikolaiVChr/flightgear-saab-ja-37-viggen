# Viggen Autoflight
# Copyright (c) 2020 Josh Davidson (Octal450)

var maxMode = props.globals.getNode("/fdm/jsbsim/autoflight/max-mode-out"); # Because something is weird going on with tied properties
var maxModeTemp = 0;
var mode = props.globals.getNode("/fdm/jsbsim/autoflight/mode"); # 0 GSA, 1 STICK, 2 ATT, 3 ALT
var highAlpha = props.globals.getNode("/fdm/jsbsim/autoflight/high-alpha"); # 0 OFF, 1 ON
var highAlphaAllowed = props.globals.getNode("/fdm/jsbsim/autoflight/high-alpha-can-engage-out");
var apSoftWarn = props.globals.getNode("/ja37/avionics/autopilot-soft-warn");
var wow = props.globals.getNode("/fdm/jsbsim/position/wow");
var downgradeWarning = [
    props.globals.getNode("/fdm/jsbsim/systems/indicators/flightstick-level"),
    props.globals.getNode("/fdm/jsbsim/systems/indicators/auto-attitude-level"),
    props.globals.getNode("/fdm/jsbsim/systems/indicators/auto-altitude-level"),
];

var System = {
	engageMode: func(m) {
		if (m <= maxMode.getValue()) {
			mode.setValue(m);
		}
	},
	trimStickKill: func() {
		if (!wow.getBoolValue() and mode.getValue() == 1) {
			me.engageMode(0); # GSA
		}
	},
	highAlphaToggle: func() {
		if (highAlphaAllowed.getBoolValue()) {
			highAlpha.setBoolValue(!highAlpha.getBoolValue());
		}
	},
};

setlistener("/fdm/jsbsim/autoflight/max-mode-out", func {
	maxModeTemp = maxMode.getValue();
	var modeTemp = mode.getValue();
	if (maxModeTemp < modeTemp) {
		mode.setValue(maxModeTemp);
		for(var i=maxModeTemp; i<modeTemp; i+=1) {
			downgradeWarning[i].setValue(2);
		}
	} else if (maxModeTemp >= 1 and wow.getBoolValue() and mode.getValue() != 1) {
		mode.setValue(1); # STICK
	}
}, 0, 0);

setlistener(highAlphaAllowed, func (node) {
	if(!node.getBoolValue()) {
		highAlpha.setBoolValue(0);
	}
}, 0, 0);
