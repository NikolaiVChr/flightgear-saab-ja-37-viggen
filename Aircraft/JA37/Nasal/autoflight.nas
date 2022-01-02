# Viggen Autoflight
# Copyright (c) 2020 Josh Davidson (Octal450)

var maxMode = props.globals.getNode("/fdm/jsbsim/autoflight/max-mode-out"); # Because something is weird going on with tied properties
var maxModeTemp = 0;
var mode = props.globals.getNode("/fdm/jsbsim/autoflight/mode"); # 0 GSA, 1 STICK, 2 ATT, 3 ALT
var highAlpha = props.globals.getNode("/fdm/jsbsim/autoflight/high-alpha"); # 0 OFF, 1 ON
var highAlphaAllowed = props.globals.getNode("/fdm/jsbsim/autoflight/high-alpha-can-engage-out");
var athrDisengage = props.globals.getNode("/fdm/jsbsim/autoflight/athr-quick-disengage");
var apSoftWarn = props.globals.getNode("/ja37/avionics/autopilot-soft-warn");
var wow = props.globals.getNode("/fdm/jsbsim/position/wow");

# Warning lights state. Partially controlled by Systems/jsb-indicators.xml
# This files takes care of
# - triggering the warning on anomal autopilot mode downgrade
# - reseting the lights when any autopilot button is pressed
# Values: 0 =off, 2 = acknowledged with master warning button, 4 = warning
var downgradeWarning = [
    props.globals.getNode("/fdm/jsbsim/systems/indicators/flightstick-level"),
    props.globals.getNode("/fdm/jsbsim/systems/indicators/auto-attitude-level"),
    props.globals.getNode("/fdm/jsbsim/systems/indicators/auto-altitude-level"),
];

var System = {
	engageMode: func(m) {
		# Pressing any autopilot button resets all warnings which have been acknowledged
		foreach(var warning; downgradeWarning) {
			if(warning.getValue() == 2) warning.setValue(0);
		}

		max = maxMode.getValue();
		if (m <= max) {
			mode.setValue(m);
		} else {
			for (var i=max; i<m; i+=1) {
				downgradeWarning[i].setValue(4);
			}
		}
	},
	highAlphaToggle: func() {
		if (highAlphaAllowed.getBoolValue()) {
			highAlpha.setBoolValue(!highAlpha.getBoolValue());
		}
	},
	apQuickDisengage: func() {
		me.engageMode(0);
	},
	athrQuickDisengage: func() {
		athrDisengage.setValue(1);
		settimer(func { athrDisengage.setValue(0); }, 0.1);
	},
};

setlistener("/fdm/jsbsim/autoflight/max-mode-out", func {
	maxModeTemp = maxMode.getValue();
	var modeTemp = mode.getValue();
	if (maxModeTemp < modeTemp) {
		mode.setValue(maxModeTemp);
		for(var i=maxModeTemp; i<modeTemp; i+=1) {
			downgradeWarning[i].setValue(4);
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
