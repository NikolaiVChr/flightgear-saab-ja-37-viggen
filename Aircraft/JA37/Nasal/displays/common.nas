#
# Methods that is used across multiple displays (HUD, CI, MI, TI)
#

var FALSE = 0;
var TRUE = 1;

var metric = 0;
setlistener("ja37/hud/units-metric", func (node) { metric = node.getBoolValue(); }, 1, 0);

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

var TI_SEL_RADAR = 1;
var TI_SEL_DL = 2;

### Numbers formatting functions.

# Print in decimal with a _comma_, 'places' is the number of decimal places.
# Applies rounding.
var sprintdec = func(x, places) {
    if (places == 0) {
        return sprintf("%d", math.round(x));
    } else {
        factor = math.pow(10, places);
        x *= factor;
        x = math.round(x);
        return sprintf("%d,%."~places~"d", math.floor(x/factor), math.mod(x, factor));
    }
}

# 'Standard' formatting of distances: 1 decimal place below 10, 0 above 10.
# Prefix 'NM' in interoperability mode.
# Input is km, it is converted to NM if in interoperability mode, unless no_convert is set.
var sprintdist = func(dist, no_convert=0) {
    if (!metric and !no_convert) dist *= 1000*M2NM;
    return (metric ? "" : "NM ") ~ sprintdec(dist, (dist >= 9.95) ? 0 : 1);
}

# Print an altitude in 'standard format':
# - below 1000, 3 digits rounded to 10
# - above 1000, divide by 1000, one decimal place
# Input is m, it is converted to ft if in interoperablity mode, unless no_convert is set.
var sprintalt = func(alt, no_convert=0) {
    if (!metric and !no_convert) alt *= M2FT;
    if (alt <= 995) {
        alt = math.round(alt, 10);
        return sprintdec(alt, 0);
    } else {
        alt = math.round(alt, 100)/1000;
        return sprintdec(alt, 1);
    }
}


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
			qfeWarning:       "ja37/displays/qfe-warning",
			alt_m:            "instrumentation/altimeter/displays-altitude-meter",
			alt_bar_m:        "instrumentation/altimeter/indicated-altitude-meter",
			altimeter_std:    "instrumentation/altimeter/setting-std",
			alt_airbase_m:    "instrumentation/altimeter/airbase-altitude-meter",
			alt_aal_m:        "instrumentation/altimeter/indicated-altitude-aal-meter",
			qnh_mode:         "ja37/hud/qnh-mode",
			ref_alt:          "ja37/displays/reference-altitude-m",
			switch_hojd:      "ja37/hud/switch-hojd",
			rhm_functional:   "instrumentation/radar-altimeter/functional",
			APmode:           "fdm/jsbsim/autoflight/mode",
			AP_alt_ft:        "fdm/jsbsim/autoflight/pitch/alt/target",
			units:            "ja37/hud/units-metric",
			RMActive:         "autopilot/route-manager/active",
			rmDist:           "autopilot/route-manager/wp/dist",
			rmBearing:        "autopilot/route-manager/wp/true-bearing-deg",
			rpm:              "fdm/jsbsim/propulsion/engine/n2",
			ext_power_used:   "fdm/jsbsim/systems/electrical/external/supplying",
			displays_on:      "ja37/displays/on",
			displays_serv:    "instrumentation/displays/serviceable",
			land_warn_on:     "ja37/avionics/landing-warnings-enable",
			launch_alt_warn:  "fdm/jsbsim/systems/mkv/ajs-launch-altitude-enable",
			launch_alt_min:   "fdm/jsbsim/systems/mkv/ajs-launch-altitude-min",
			launch_alt_max:   "fdm/jsbsim/systems/mkv/ajs-launch-altitude-max",
			ja_head_bug:      "instrumentation/waypoint-indicator/ja-bearing-deg",
			ja_head_tgt:      "instrumentation/waypoint-indicator/ja-tgt-heading-deg",
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
		co.radar_on = FALSE;

		# Starting with all systems on.
		if (getprop("/ja37/avionics/init-done")) {
			co.power_time = -180;
			co.displays_on_time = -40;
			co.ep12_on = TRUE;
		}

      	co.currArmName = "None";
      	co.currArmNameMedium = "";
      	co.currArmNameSh = "--";
      	co.distance_m = -1;
      	co.distance_name = "";
		co.distance_model = "";
      	co.error = FALSE;
      	co.cursor = MI;
		co.ref_alt = 500;
      	co._ref_alt = 500; # internal value, used as memory in some conditions
      	co.ref_alt_ldg_override = FALSE;

      	co.wowPrev = 0;
      	co.timeGround = 0;
      	co.timeLand = 0;
      	co.ftime = 0;

		# QFE warning triggers
		co.qfe_warn_climb_armed = FALSE;
		co.qfe_warn_land_armed = FALSE;
		co.qfe_warn_descent_armed = FALSE;
		co.qfe_warn_takeoff_time = nil;
		co.qfe_warn_time = nil;

		co.ti_selection = nil;

      	return co;
	},

	loop: func {#todo: make slower loop
		if (variant.JA) me.powerJA();
		else me.powerAJS();
		me.armName();
		me.armNameShort();
		me.armNameMedium();
		me.errors();
		me.flighttime();
		me.referenceAlt();
		if (variant.JA) {
			me.ja_nav();
			me.landWarningsCondition();
			me.airbaseAlt();
		} else {
			me.hojd_switch();
			me.launch_altitude();
		}
	},

	loopFast: func {
		if (variant.JA) me.QFE();
	},

	powerJA: func {
		var time = me.input.time.getValue();

		# Remeber last time that power/displays were off, to know since how long they have been on.
		if (!power.prop.acSecond.getBoolValue() or !me.input.displays_serv.getBoolValue()) {
			me.power_time = time;
			me.ep12_on = FALSE;
		}
		# Display turn on automatically at 90% RPM, if on internal power
		if (power.prop.acSecond.getBoolValue() and me.input.displays_serv.getBoolValue()
			and !me.input.ext_power_used.getBoolValue() and me.input.rpm.getValue() >= 90) {
			me.ep12_on = TRUE;
		}
		if (!me.ep12_on or testing.ongoing) {
			me.displays_on_time = time;
		}

		# SI is on 40s after power and 'within 2s' of EP12 on.
		me.hud_on = (time - me.power_time >= 40) and (time - me.displays_on_time >= 1);
		# MI/TI are on 'within 2s' of EP12 on.
		me.mi_ti_on = (time - me.displays_on_time >= 1);
		# made up value
		me.radar_on = (time - me.power_time >= 100);

		# This property is used for checklists.
		me.input.displays_on.setValue(me.hud_on);
	},

	powerAJS: func {
		var time = me.input.time.getValue();

		# Remeber last time that power/displays were off, to know since how long they have been on.
		if (!power.prop.acSecond.getBoolValue() or !me.input.displays_serv.getBoolValue()) {
			me.power_time = time;
		}
		if (modes.selector_ajs <= modes.STBY or testing.ongoing) {
			me.displays_on_time = time;
		}

		# SI is on 30s after power and 'within 2s' of switching to NAV.
		me.hud_on = (time - me.power_time >= 30) and (time - me.displays_on_time >= 1);
		# CI is on 30s after power + switching to NAV.
		me.ci_on = (time - me.power_time >= 30) and (time - me.displays_on_time >= 30);
		# Radar is on 3min after power (AJS SFI part 3 chap 6 sec 5.6 page 20)
		me.radar_on = (time - me.power_time >= 180);
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

	ja_nav: func {
		# Information displayed on various waypoint range / bearing indicators.
		me.distance_m = nil;
		me.heading = nil;
		me.tgt_heading = nil;

		if (me.ti_selection != nil) {
			if (me.ti_sel_type == TI_SEL_RADAR and (var info = me.ti_selection.getLastBlep()) != nil) {
				me.distance_m = info.getRangeNow();
				me.heading = info.getBearing();
				me.tgt_heading = info.getHeading();
			} elsif (me.ti_sel_type == TI_SEL_DL) {
				me.distance_m = me.ti_selection.getRange();
				me.heading = me.ti_selection.getBearing();
				me.tgt_heading = me.ti_selection.getHeading();
			}
		} elsif (me.input.RMActive.getValue() == TRUE and getprop("autopilot/route-manager/current-wp") != -1) {
			# next steerpoint
			me.distance_m = me.input.rmDist.getValue();
			if (me.distance_m != nil) me.distance_m *= NM2M;
			me.heading = me.input.rmBearing.getValue();

			if (land.show_runway_line) {
				me.tgt_heading = land.head;
			}
		}

		me.input.ja_head_bug.setValue(me.heading or 0);
		me.input.ja_head_tgt.setValue(me.tgt_heading or 0);
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
		"RB-74": "74",
		"RB-71": "71",
		"RB-99": "99",
		"M75": "AKAN",
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
		"RB-74": "74",
		"RB-71": "71",
		"RB-99": "99",
		"M75": "AK",
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

	armNamePylon: func (station) {
		me.armamentp = pylons.get_pylon_load(station);
		if (!contains(me.arm_name_short, me.armamentp)) return nil;
		else return me.arm_name_short[me.armamentp];
	},

	landWarningsCondition: func {
		# Condition: landing mode LB, LF, or (L and within 40km of destination)
		# Used by MKV and QFE warnings
		var res = 0;
		if (modes.nav_ja == modes.LB or modes.nav_ja == modes.LF) res = 1;
		if (modes.nav_ja == modes.L
			and (var airbase = route.Polygon.flyRTB.plan.destination) != nil) {
			res = (geo.Coord.new().set_latlon(airbase.lat, airbase.lon, 0)
				.distance_to(geo.aircraft_position()) < 40000);
		}
		me.input.land_warn_on.setBoolValue(res);
	},

	QFE: func {
		var time = me.input.time.getValue();
		var alt = me.input.alt_aal_m.getValue();
		var std = me.input.altimeter_std.getBoolValue();
		var high = (alt > 1500);    # STD should be selected.

		if (me.input.wow1.getBoolValue()) {
			# At takeoff, warning if in STD mode or altitude error is more than 10m
			if (!std and math.abs(alt) <= 10) {
				# Correctly set
				me.qfe_warn_takeoff_time = nil;
			} elsif (me.input.rpm.getValue() > 90) {
				# Trigger warning.
				# Note: unlike other warnings, takeoff warning remains on for all the takeoff roll, +10s.
				me.qfe_warn_takeoff_time = time;
			}
			# Reset/prepare warnings for next phase.
			me.qfe_warn_climb_armed = TRUE;
			me.qfe_warn_time = nil;
		} else {
			# Otherwise, warning if not in STD mode above 1500m, or vice versa, under certain conditions.

			# Stop warning if correctly set
			if (std == high) me.qfe_warn_time = nil;
			# Note: still run the logic below even if (std == high), to update the triggers.

			# When passing 1500m, warning if not in STD mode.
			# TODO: disable when outside of 40km
			# if ("distance_to_departure" > 40km) me.qfe_warn_climb_armed = FALSE;
			if (me.qfe_warn_climb_armed and high) {
				me.qfe_warn_climb_armed = FALSE;
				if (!std) me.qfe_warn_time = time;
			}

			# In landing mode (LB, LF, or (L and within 40km of destination))
			if (me.input.land_warn_on.getBoolValue()) {
				if (me.qfe_warn_land_armed) {
					me.qfe_warn_land_armed = FALSE;
					# First warning when entering land mode if STD is not set properly.
					if (std != high) me.qfe_warn_time = time;
					# If above 1500m, arm second warning for when passing 1500m.
					if (high) me.qfe_warn_descent_armed = TRUE;
				}

				# Second warning when passing 1500m if in STD mode.
				if (me.qfe_warn_descent_armed and !high) {
					me.qfe_warn_descent_armed = FALSE;
					if (std) me.qfe_warn_time = time;
				}
			} else {
				me.qfe_warn_land_armed = TRUE;
			}
		}

		me.qfe_warn = (me.qfe_warn_takeoff_time != nil and time - me.qfe_warn_takeoff_time <= 10)
			or (me.qfe_warn_time != nil and time - me.qfe_warn_time <= 10);
		me.input.qfeWarning.setValue(me.qfe_warn);
	},

	airbaseAlt: func {
		var airbase = route.Polygon.flyRTB.plan.destination;
		if (airbase != nil) {
			me.input.alt_airbase_m.setValue(airbase.elevation);
		} else {
			me.input.alt_airbase_m.setValue(0);
		}
	},

	referenceAlt: func {
		# Reference (target) altitude displayed on HUD and other displays.
		# TAKEOFF mode: fixed, 500m
		# NAV: can be modified with reference alt button, or ALT hold autopilot
		# LANDING: defaults to 500m, but can be overriden as in NAV

		var reset_ref_alt_ldg_override = TRUE;

		if (modes.takeoff) {
			me._ref_alt = 500 + me.input.alt_airbase_m.getValue();
		} elsif (me.input.APmode.getValue() == 3) {
			me._ref_alt = me.input.AP_alt_ft.getValue() * FT2M;
			if (!variant.JA) {
				# For AJS, autopilot uses barometric altitude, but displays use ground corrected altitude.
				me._ref_alt += me.input.alt_m.getValue() - me.input.alt_bar_m.getValue();
			}
		} elsif (modes.landing) {
			# me.ref_alt_ldg_override indicates that the altitude was manually selected
			# with the reference altitude button while in LANDING mode.
			# This flag is cleared in every other mode, which resets the altitude to 500 when switching to LANDING.
			reset_ref_alt_ldg_override = FALSE;
			if (!me.ref_alt_ldg_override) me._ref_alt = 500 + me.input.alt_airbase_m.getValue();
		}

		me.ref_alt = me._ref_alt;

		# Rb 04 aiming mode sets reference altitude = 240m, but remember previous setting (with _ref_alt)
		if (variant.AJS and hud.HUD.aiming_mode_condition() and fire_control.get_type() == "RB-04E") {
			me.ref_alt = 240;
		}

		if (reset_ref_alt_ldg_override) me.ref_alt_ldg_override = FALSE;
		me.input.ref_alt.setValue(me.ref_alt);
	},

	refAltButton: func {
		# For AJS, different functionality in LOW NAV (declutter) mode
		if (!variant.JA and hud.hud.mode == hud.hud.MODE_NAV_DECLUTTER) {
			hud.hud.declutter_heading_toggle();
			return;
		}

		# For JA, also used for IR seeker reference.
		if (variant.JA and fire_control.selected != nil and fire_control.selected["is_IR"]) {
			fire_control.selected.toggle_IR_boresight();
			return;
		}

		# Manual reference altitude setting is not available at takeoff,
		# with ALT HOLD autopilot, and during the landing final phase.
		if (modes.takeoff or me.input.APmode.getValue() == 3
			or (modes.landing and land.mode != 1 and land.mode != 2)
			or (variant.AJS and hud.HUD.aiming_mode_condition() and fire_control.get_type() == "RB-04E"))
			return;

		me._ref_alt = me.input.alt_m.getValue();
		if (me._ref_alt < 20) me._ref_alt = 20;
		me.referenceAlt();

		# Set flag if manually setting reference altitude during landing.
		if (modes.landing) {
			me.ref_alt_ldg_override = TRUE;
		}
	},

	hojd_switch: func {
		# Move switch HÖJD CI/SI to LD (barometric) if necessary.

		if (!me.input.switch_hojd.getBoolValue()) return;
		# Guess: the switch stays in place without electrical power.
		if (!power.prop.dcMainBool.getBoolValue()) return;

		# Disengagement conditions
		if (!me.input.rhm_functional.getBoolValue()
			# Should be standard pressure altitude, but it would make it unusable in high terrain.
			or me.input.alt_bar_m.getValue() > 2450
			or (modes.landing and land.mode >= 2 and land.mode <= 3))
		{
			me.input.switch_hojd.setValue(FALSE);
			ja37.click();
		}
	},

	launch_altitude: func {
		if (!fire_control.is_armed()) {
			me.input.launch_alt_warn.setBoolValue(FALSE);
			return;
		}
		var type = fire_control.get_type();
		if (type == "RB-04E") {
			# manual: 240 +-190m
			me.input.launch_alt_min.setValue(50);
			me.input.launch_alt_max.setValue(330);
			me.input.launch_alt_warn.setBoolValue(TRUE);
		} elsif (type == "RB-15F") {
			# manual: 50m-2000m
			me.input.launch_alt_min.setValue(50);
			me.input.launch_alt_max.setValue(2000);
			me.input.launch_alt_warn.setBoolValue(TRUE);
		} else {
			me.input.launch_alt_warn.setBoolValue(FALSE);
		}
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

	unsetTISelection: func {
		me.setTISelection(nil, 0);
	},

	setTISelection: func(s, type) {
		me.ti_sel_type = type;
		me.ti_selection = s;
		if (s != nil) modes.buttons.RR();
	},
};

var common = Common.new();
