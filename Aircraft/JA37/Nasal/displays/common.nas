#
# Methods that is used across multiple displays (HUD, CI, MI, TI)
#

var FALSE = 0;
var TRUE = 1;

var METRIC = 1;
var IMPERIAL = 0;

var MI = 0;
var TI = 1;

var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }

var containsVector = func (vec, item) {
	foreach(test; vec) {
		if (test == item) {
			return TRUE;
		}
	}
	return FALSE;
}

# -100 - 0 : not blinking
# 1 - 10   : blinking
# 11 - 125 : steady on
var countQFE = 0;

var Common = {

	new: func {
		var co = { parents: [Common] };
		co.input = {
			cursor_dx:        "controls/displays/cursor-slew-x-delta",
			cursor_dy:        "controls/displays/cursor-slew-y-delta",
			cursor_clicked:   "controls/displays/cursor-was-clicked",
			time:             "sim/time/elapsed-sec",
			wow1:             "fdm/jsbsim/gear/unit[1]/WOW",
			nav0InRange:      "instrumentation/nav[0]/in-range",
			qfeActive:        "ja37/displays/qfe-active",
			qfeShown:         "ja37/displays/qfe-shown",
			altCalibrated:    "ja37/avionics/altimeters-calibrated",
			alt_ft:           "instrumentation/altimeter/indicated-altitude-ft",
			alt_m:            "instrumentation/altimeter/indicated-altitude-meter",
			ref_alt:          "ja37/displays/reference-altitude-m",
			APmode:           "fdm/jsbsim/autoflight/mode",
			AP_alt_ft:        "fdm/jsbsim/autoflight/pitch/alt/target",
			units:            "ja37/hud/units-metric",
			fiveHz:           "ja37/blink/two-Hz/state",
			rad_alt:          "instrumentation/radar-altimeter/radar-altitude-ft",
			rad_alt_ready:    "instrumentation/radar-altimeter/ready",
			vid:              "ja37/avionics/vid",
			dme:              "instrumentation/dme/KDI572-574/nm",
			dmeDist:          "instrumentation/dme/indicated-distance-nm",
			RMActive:         "autopilot/route-manager/active",
			rmDist:           "autopilot/route-manager/wp/dist",
			rpm:              "fdm/jsbsim/propulsion/engine/n2",
			ext_power_used:   "fdm/jsbsim/systems/electrical/external/supplying",
      	};
   
      	foreach(var name; keys(co.input)) {
        	co.input[name] = props.globals.getNode(co.input[name], 1);
      	}

		# Displays power and on/off logic.
		co.power_time = 0;       # time at which AC secondary is on
		co.displays_on_time = 0; # time at which displays are turned on
		co.ep12_on = FALSE;
		co.hud_on = FALSE;
		co.ci_on = FALSE;
		co.mi_ti_on = FALSE;

      	co.currArmName = "None";
      	co.currArmNameMedium = "";
      	co.currArmNameSh = "--";
      	co.distance_m = -1;
      	co.distance_name = "";
		co.distance_model = "";
      	co.error = FALSE;
      	co.cursor = MI;
      	co.ref_alt = 500;
      	co.ref_alt_ldg_override = FALSE;

      	co.wowPrev = 0;
      	co.timeGround = 0;
      	co.timeLand = 0;
      	co.ftime = 0;

      	return co;
	},

	loop: func {#todo: make slower loop
		if (variant.JA) me.powerJA();
		else me.powerAJS();
		me.armName();
		me.armNameShort();
		me.armNameMedium();
		me.distance();
		me.errors();
		me.flighttime();
		me.referenceAlt();
		me.EP13();
		#me.rate = getprop("sim/frame-rate-worst");
		#settimer(func me.loop(), me.rate!=nil?clamp(2.15/(me.rate+0.001), 0.05, 0.5):0.5);#0.001 is to prevent divide by zero
	},

	loopFast: func {
		me.QFE();
		#settimer(func me.loopFast(), 0.05);
	},

	powerJA: func {
		var time = me.input.time.getValue();

		# Remeber last time that power/displays were off, to know since how long they have on.
		if (!power.prop.acSecond.getBoolValue()) {
			me.power_time = time;
			me.ep12_on = FALSE;
		}
		# Display turn on automatically at 90% RPM, if on internal power
		if (power.prop.acSecond.getBoolValue() and !me.input.ext_power_used.getBoolValue()
			and me.input.rpm.getValue() >= 90) {
			me.ep12_on = TRUE;
		}
		if (!me.ep12_on or testing.ongoing) {
			me.displays_on_time = time;
		}

		# SI is on 40s after power and 'within 2s' of EP12 on.
		me.hud_on = (time - me.power_time >= 40) and (time - me.displays_on_time >= 1);
		# MI/TI are on 'within 2s' of EP12 on.
		me.mi_ti_on = (time - me.displays_on_time >= 1);
	},

	powerAJS: func {
		var time = me.input.time.getValue();

		# Remeber last time that power/displays were off, to know since how long they have on.
		if (!power.prop.acSecond.getBoolValue()) {
			me.power_time = time;
		}
		if (modes.selector_ajs <= modes.STBY or testing.ongoing) {
			me.displays_on_time = time;
		}

		# SI is on 30s after power and 'within 2s' of switching to NAV.
		me.hud_on = (time - me.power_time >= 30) and (time - me.displays_on_time >= 1);
		# CI is on 30s after power + switching to NAV.
		me.ci_on = (time - me.power_time >= 30) and (time - me.displays_on_time >= 30);
	},

	toggleJAdisplays: func(on=nil) {
		if (on == nil) on = !me.ep12_on;

		if (on) {
			# Turn on if power is available
			if (power.prop.acSecond.getBoolValue() and !testing.ongoing) me.ep12_on = TRUE;
		} else {
			# Turn off only with <90% RPM.
			if (me.input.rpm.getValue() < 90) me.ep12_on = FALSE;
		}
	},

	flighttime: func {
		# works as JA manual says
		me.elapsed = me.input.time.getValue();
		me.wow     = me.input.wow1.getValue();
		
		if (me.wow) {
			me.timeGround = me.elapsed;
			if (!me.wowPrev) {
				me.timeLand = me.elapsed;
			}
			if (me.timeGround - me.timeLand > 3*60) {
				me.ftime = 0;
			}
		} else {
			me.ftime = me.elapsed - me.timeGround + 30;
		}
		me.wowPrev = me.wow;
	},

	errors: func {
		var failure_modes = FailureMgr._failmgr.failure_modes;
		var mode_list = keys(failure_modes);

		foreach(var failure_mode_id; mode_list) {
			var lvl = FailureMgr.get_failure_level(failure_mode_id);
			if (lvl) {
				me.error = TRUE;
				return;
			}
		}
		me.error = FALSE;
	},

	distance: func {
		if (radar_logic.steerOrder == TRUE and radar_logic.selection != nil and (containsVector(radar_logic.tracks, radar_logic.selection) or radar_logic.selection.parents[0] == radar_logic.ContactGPS)) {
			# radar steer order
			me.distance_m = radar_logic.selection.get_range()*NM2M;
	    } elsif (me.input.RMActive.getValue() == TRUE and me.input.rmDist.getValue() != nil and getprop("autopilot/route-manager/current-wp") != -1) {
	    	# next steerpoint
	    	me.distance_m = me.input.rmDist.getValue()*NM2M;
		} else {
	  		# nothing
	  		me.distance_m = -1;
	  	}
	  	
	  	if (radar_logic.selection != nil and (containsVector(radar_logic.tracks, radar_logic.selection) or radar_logic.selection.parents[0] == radar_logic.ContactGPS)) {
			# IFF
			me.distance_name = radar_logic.selection.get_Callsign();
			me.distance_model = radar_logic.selection.get_model();
	    } else {
	  		# nothing
	  		me.distance_name = "";
			me.distance_model = "";
	  	}
	},

	armName: func {
		var weapon = fire_control.selected;
		if (weapon == nil) {
			me.currArmName = me.input.units.getBoolValue()?"RENS":"CLR";
		} elsif (!weapon.weapon_ready()) {
			me.currArmName = me.input.units.getBoolValue()?"TOM":"NONE";
		} else {
			me.currArmName = weapon.type;
		}
	},

	arm_name_medium: {
		"RB-24": "24",
		"RB-24J": "24J",
		"RB-74": "74",
		"RB-71": "71",
		"RB-99": "99",
		"RB-04E": "04",
		"RB-15F": "15",
		"RB-05A": "05",
		"RB-75": "75",
		"M70 ARAK": "ARAK",
		"M55 AKAN": "AKAN",
		"M75 AKAN": "AKAN",
		"M71": "71",
		"M71R": "71R",
		"M90": "90",
	},

	armNameMedium: func {
		var weapon = fire_control.selected;
		if (weapon == nil) {
			me.currArmNameMedium = me.input.units.getBoolValue()?"RENS":"CLR";
		} elsif (!weapon.weapon_ready()) {
			me.currArmNameMedium = me.input.units.getBoolValue()?"TOM":"NONE";
		} else {
			me.currArmNameMedium = me.arm_name_medium[weapon.type];
		}
	},

	arm_name_short: {
		"RB-24J": "24",
		"RB-74": "74",
		"RB-71": "71",
		"RB-99": "99",
		"M70 ARAK": "70",
		"M75 AKAN": "AK",
	},

	armNameShort: func {
		var weapon = fire_control.selected;
		if (weapon == nil) {
			me.currArmNameSh = "";
		} elsif (!weapon.weapon_ready()) {
			me.currArmNameSh = "--";
		} else {
			me.currArmNameSh = me.arm_name_short[weapon.type];
		}
	},

	armActive: func {
		return fire_control.get_weapon();
	},

	sidewinders: func {
		me.snakes = [];
		for(var x=1; x<=6; x+=1) {
			if (armament.AIM.active[100*x] != nil and armament.AIM.active[100*x].guidance=="heat") {
				append(me.snakes, armament.AIM.active[100*x]);
			}
		}
		return me.snakes;
	},

	armNamePylon: func (station) {
		me.armamentp = pylons.station_by_id(station).singleName;
		if (!contains(me.arm_name_short, me.armamentp)) return nil;
		else return me.arm_name_short[me.armamentp];
	},

    QFE: func {
    	if (me.input.alt_ft.getValue() != nil) {
	    	me.metric = me.input.units.getValue();
	    	var alt = me.metric == METRIC ? me.input.alt_ft.getValue() * FT2M : me.input.alt_ft.getValue();
	    	var radAlt = me.input.rad_alt_ready.getBoolValue() ? (me.metric == METRIC ? me.input.rad_alt.getValue() * FT2M : me.input.rad_alt.getValue()):nil;

	    	me.radar_clamp = me.metric == METRIC ? 100 : 100/FT2M;
		    me.alt_diff = me.metric == METRIC ? 7 : 7/FT2M;
		    me.INT = FALSE;

		    if (radAlt != nil and radAlt < me.radar_clamp) {
		      # check for QFE warning
		      me.diff = radAlt - alt;
		      if (countQFE == 0 and (me.diff > me.alt_diff or me.diff < -me.alt_diff)) {
		        #print("QFE warning " ~ countQFE);
		        # is not calibrated, and is not blinking
		        me.input.altCalibrated.setBoolValue(FALSE);
		        countQFE = 1;     
		        #print("QFE not calibrated, and is not blinking");     
		      } elsif (me.diff > -me.alt_diff and me.diff < me.alt_diff) {
		          #is calibrated
		        if (me.input.altCalibrated.getValue() == FALSE and countQFE < 11) {
		          # was not calibrated before, is now.
		          #print("QFE was not calibrated before, is now. "~countQFE);
		          countQFE = 11;
		        }
		        me.input.altCalibrated.setBoolValue(TRUE);
		      } elsif (me.input.altCalibrated.getValue() == 1 and (me.diff > me.alt_diff or me.diff < -me.alt_diff)) {
		        # was calibrated before, is not anymore.
		        #print("QFE was calibrated before, is not anymore. "~countQFE);
		        countQFE = 1;
		        me.input.altCalibrated.setBoolValue(FALSE);
		      }
		    } else {
		      # is above height for checking for calibration
		      countQFE = 0;
		      #QFE = 0;
		      me.input.altCalibrated.setBoolValue(TRUE);
		      #print("QFE not calibrated, and is not blinking");
		    }

		    if (countQFE > 0) {
				# QFE is shown
				me.input.qfeActive.setBoolValue(TRUE);
				if(countQFE == 1) {
					countQFE = 2;
				}
				if(countQFE < 10) {
					# blink the QFE
					if(me.input.fiveHz.getValue() == TRUE) {
					  me.input.qfeShown.setBoolValue(TRUE);
					} else {
					  me.input.qfeShown.setBoolValue(FALSE);
					}
				} elsif (countQFE == 10) {
					#if(me.input.ias.getValue() < 10) {
					  # adjust the altimeter (commented out after placing altimeter in plane)
					  # var inhg = getprop("systems/static/pressure-inhg");
					  #setprop("instrumentation/altimeter/setting-inhg", inhg);
					 # countQFE = 11;
					  #print("QFE adjusted " ~ inhg);
					#} else {
					  countQFE = -100;
					#}
				} elsif (countQFE < 125) {
					# QFE is steady
					countQFE = countQFE + 1;
					me.input.qfeShown.setBoolValue(TRUE);
					#print("steady on");
				} else {
					countQFE = -100;
					me.input.altCalibrated.setBoolValue(TRUE);
					#print("off");
				}
		    } else {
		      me.input.qfeActive.setBoolValue(FALSE);
		      countQFE = clamp(countQFE+1, -101, 0);
		      #print("hide  off");
		    }
		    #print("QFE count " ~ countQFE);
		}
    },

	referenceAlt: func {
		# Reference (target) altitude displayed on HUD and other displays.
		# TAKEOFF mode: fixed, 500m
		# NAV/COMBAT: can be modified with reference alt button, or ALT hold autopilot
		# LANDING: defaults to 500m, but can be overriden as in NAV/COMBAT
		if (modes.takeoff) {
			me.ref_alt = 500;
			me.ref_alt_ldg_override = FALSE;
		} elsif (modes.landing) {
			# me.ref_alt_ldg_override indicates that the altitude was manually selected
			# with the reference altitude button while in LANDING mode.
			# This flag is cleared in every other mode, which resets the altitude to 500 when switching to LANDING.
			if (me.input.APmode.getValue() == 3) {
				me.ref_alt_ldg_override = FALSE;
				me.ref_alt = me.input.AP_alt_ft.getValue() * FT2M;
			} elsif (!me.ref_alt_ldg_override) {
				me.ref_alt = 500;
			}
		} else {
			if (me.input.APmode.getValue() == 3) {
				me.ref_alt = me.input.AP_alt_ft.getValue() * FT2M;
			}
			me.ref_alt_ldg_override = FALSE;
		}
		me.input.ref_alt.setValue(me.ref_alt);
	},

	refAltButton: func {
		# For AJS, different functionality in LOW NAV (declutter) mode
		if (getprop("/ja37/systems/variant") != 0 and hud.hud.mode == hud.hud.MODE_NAV_DECLUTTER) {
			hud.hud.declutter_heading_toggle();
			return;
		}

		# Manual reference altitude setting is not available at takeoff,
		# with ALT HOLD autopilot, and during the landing final phase.
		if (modes.takeoff or me.input.APmode.getValue() == 3
			or (modes.landing and land.mode != 1 and land.mode != 2)) return;

		me.ref_alt = me.input.alt_m.getValue();
		if (me.ref_alt < 20) me.ref_alt = 20;
		me.input.ref_alt.setValue(me.ref_alt);

		# Set flag if manually setting reference altitude during landing.
		if (modes.landing) {
			me.ref_alt_ldg_override = TRUE;
		}
	},

	EP13: func {
		# Rb 75 screen
		me.input.vid.setBoolValue(
			modes.combat and fire_control.get_weapon() != nil and fire_control.get_weapon().type == "RB-75"
		);
	},

	setCursorDisplay: func (display) {
		me.cursor = display;
		me.resetCursorDelta();
	},

	toggleCursorDisplay: func {
		me.setCursorDisplay(!me.cursor);
	},

	# Cursor position low level updates are in JSBSim to not suffer from low refresh rate.
	# These functions are the interface with this JSBSim system.
	getCursorDelta: func {
		return [me.input.cursor_dx.getValue(), me.input.cursor_dy.getValue(), me.input.cursor_clicked.getBoolValue()];
	},

	resetCursorDelta: func {
		me.input.cursor_dx.setValue(0);
		me.input.cursor_dy.setValue(0);
		me.input.cursor_clicked.setBoolValue(0);
	},
};

var common = Common.new();



var init = func {
	removelistener(idl); # only call once
	common.loop();
	common.loopFast();
}	

#idl = setlistener("ja37/supported/initialized", init, 0, 0);
