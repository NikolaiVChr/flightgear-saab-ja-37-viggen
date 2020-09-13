#
# Methods that is used across multiple displays (HUD, CI, MI, TI)
#
var TAKEOFF = 0;
var NAV = 1;
var COMBAT =2;
var LANDING = 3;

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
			speed_d:          "velocities/speed-down-fps",
	        speed_e:          "velocities/speed-east-fps",
	        speed_n:          "velocities/speed-north-fps",
	        mach:             "instrumentation/airspeed-indicator/indicated-mach",
	        gearsPos:         "gear/gear/position-norm",
	        wow0:             "fdm/jsbsim/gear/unit[0]/WOW",
	        wow1:             "fdm/jsbsim/gear/unit[1]/WOW",
	        wow2:             "fdm/jsbsim/gear/unit[2]/WOW",
	        dev:              "dev",
	        combat:           "ja37/hud/combat",
	        landingMode:      "ja37/hud/landing-mode",
	        currentMode:      "ja37/hud/current-mode",
	        elapsedSec:       "sim/time/elapsed-sec",
	        nav0InRange:      "instrumentation/nav[0]/in-range",
	        qfeActive:        "ja37/displays/qfe-active",
	        qfeShown:		  "ja37/displays/qfe-shown",
	        altCalibrated:    "ja37/avionics/altimeters-calibrated",
	        alt_ft:           "instrumentation/altimeter/indicated-altitude-ft",
	        units:            "ja37/hud/units-metric",
	        fiveHz:           "ja37/blink/two-Hz/state",
	        rad_alt:          "instrumentation/radar-altimeter/radar-altitude-ft",
	        rad_alt_ready:    "instrumentation/radar-altimeter/ready",
	        dme:              "instrumentation/dme/KDI572-574/nm",
        dmeDist:          "instrumentation/dme/indicated-distance-nm",
        RMActive:         "autopilot/route-manager/active",
        rmDist:           "autopilot/route-manager/wp/dist",
units:                "ja37/hud/units-metric",
	        station:          "controls/armament/station-select-custom",
      	};
   
      	foreach(var name; keys(co.input)) {
        	co.input[name] = props.globals.getNode(co.input[name], 1);
      	}

      	co.mode = TAKEOFF;
      	co.modeTimeTakeoff = -1;
      	co.currArmName = "None";
      	co.currArmNameMedium = "";
      	co.currArmNameSh = "--";
      	co.distance_m = -1;
      	co.distance_name = "";
		co.distance_model = "";
      	co.error = FALSE;
      	co.cursor = MI;

      	co.wowPrev = 0;
      	co.timeGround = 0;
      	co.timeLand = 0;
      	co.ftime = 0;

      	return co;
	},

	loop: func {#todo: make slower loop
		me.displayMode();
		me.armName();
		me.armNameShort();
		me.armNameMedium();
		me.distance();
		me.errors();
		me.flighttime();
		#me.rate = getprop("sim/frame-rate-worst");
		#settimer(func me.loop(), me.rate!=nil?clamp(2.15/(me.rate+0.001), 0.05, 0.5):0.5);#0.001 is to prevent divide by zero
	},

	loopFast: func {
		me.QFE();
		#settimer(func me.loopFast(), 0.05);
	},

	flighttime: func {
		# works as JA manual says
		me.elapsed = getprop("sim/time/elapsed-sec");
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
		  me.armSelect = me.input.station.getValue();
		  if (me.armSelect == -1) {
		  	me.currArmName = getprop("ja37/hud/units-metric")==1?"RENS":"CLR";
		  	return;
		  }
	      if (me.armSelect > 0) {
	        me.armament = getprop("payload/weight["~ (me.armSelect-1) ~"]/selected");
	      } else {
	        me.armament = "";
	      }
	      if(me.armSelect == 0) {
	        me.currArmName = "AKAN";	        
	      } elsif(me.armament == "RB 24 Sidewinder") {
	        me.currArmName = "RB-24";	        
	      } elsif(me.armament == "RB 24J Sidewinder") {
	        me.currArmName = "RB-24J";	        
	      } elsif(me.armament == "RB 74 Sidewinder") {
	        me.currArmName = "RB-74";	        
	      } elsif(me.armament == "M70 ARAK") {
	        me.currArmName = "M70 ARAK";	        
	      } elsif(me.armament == "RB 71 Skyflash") {
	        me.currArmName = "RB-71";	        
	      } elsif(me.armament == "RB 99 Amraam") {
	        me.currArmName = "RB-99";	        
	      } elsif(me.armament == "RB 15F Attackrobot") {
	        me.currArmName = "RB-15F";	        
	      } elsif(me.armament == "RB 04E Attackrobot") {
	        me.currArmName = "RB-04E";	        
	      } elsif(me.armament == "RB 05A Attackrobot") {
	        me.currArmName = "RB-05A";	        
	      } elsif(me.armament == "RB 75 Maverick") {
	        me.currArmName = "RB-75";	        
	      } elsif(me.armament == "M71 Bomblavett") {
	        me.currArmName = "M71";	        
	      } elsif(me.armament == "M71 Bomblavett (Retarded)") {
	        me.currArmName = "M71R";	        
	      } elsif(me.armament == "M90 Bombkapsel") {
	        me.currArmName = "M90";	        
	      } elsif(me.armament == "M55 AKAN") {
	        me.currArmName = "M55 AKAN";	        
	      } elsif(me.armament == "TEST") {
	        me.currArmName = "TEST";	        
	      } else {
	        me.currArmName = getprop("ja37/hud/units-metric")==1?"TOM":"NONE";
	      }
	},

	armNameMedium: func {
		  me.armSelect = me.input.station.getValue();
		  if (me.armSelect == -1) {
		  	me.currArmNameMedium = getprop("ja37/hud/units-metric")==1?"RENS":"CLR";
		  	return;
		  }
	      if (me.armSelect > 0) {
	        me.armament = getprop("payload/weight["~ (me.armSelect-1) ~"]/selected");
	      } else {
	        me.armament = "";
	      }
	      if(me.armSelect == 0) {
	        me.currArmNameMedium = "AK";	        
	      } elsif(me.armament == "RB 24 Sidewinder") {
	        me.currArmNameMedium = "24";	        
	      } elsif(me.armament == "RB 24J Sidewinder") {
	        me.currArmNameMedium = "24J";	        
	      } elsif(me.armament == "RB 74 Sidewinder") {
	        me.currArmNameMedium = "74";	        
	      } elsif(me.armament == "M70 ARAK") {
	        me.currArmNameMedium = "70";	        
	      } elsif(me.armament == "RB 71 Skyflash") {
	        me.currArmNameMedium = "71";	        
	      } elsif(me.armament == "RB 99 Amraam") {
	        me.currArmNameMedium = "99";	        
	      } elsif(me.armament == "RB 15F Attackrobot") {
	        me.currArmNameMedium = "15";	        
	      } elsif(me.armament == "RB 04E Attackrobot") {
	        me.currArmNameMedium = "04";	        
	      } elsif(me.armament == "RB 05A Attackrobot") {
	        me.currArmNameMedium = "05";	        
	      } elsif(me.armament == "RB 75 Maverick") {
	        me.currArmNameMedium = "75";	        
	      } elsif(me.armament == "M71 Bomblavett") {
	        me.currArmNameMedium = "71";	        
	      } elsif(me.armament == "M71 Bomblavett (Retarded)") {
	        me.currArmNameMedium = "71R";	        
	      } elsif(me.armament == "M90 Bombkapsel") {
	        me.currArmNameMedium = "90";	        
	      } elsif(me.armament == "M55 AKAN") {
	        me.currArmNameMedium = "55";	        
	      } elsif(me.armament == "TEST") {
	        me.currArmNameMedium = "TEST";	        
	      } else {
	        me.currArmNameMedium = getprop("ja37/hud/units-metric")==1?"TOM":"NONE";
	      }
	},

	armActive: func {
		me.armSelect = me.input.station.getValue();
	    if (me.armSelect > 0) {
	        me.aim = armament.AIM.active[me.armSelect-1];
	        return me.aim;
	    }
	    return nil;
	},

	sidewinders: func {
		me.snakes = [];
		for(var x=0; x<7; x+=1) {
			if (armament.AIM.active[x] != nil and armament.AIM.active[x].guidance=="heat") {
				append(me.snakes, armament.AIM.active[x]);
			}
		}
		return me.snakes;
	},

	armNameShort: func {
		  me.armSelect = me.input.station.getValue();
		  if (me.armSelect == -1) {
		  	me.currArmNameSh = "";
		  	return;
		  }
	      if (me.armSelect > 0) {
	        me.armament = getprop("payload/weight["~ (me.armSelect-1) ~"]/selected");
	      } else {
	        me.armament = "";
	      }
	      if(me.armSelect == 0) {
	        me.currArmNameSh = "AK";
	      } elsif(me.armament == "RB 24J Sidewinder") {
	        me.currArmNameSh = "24";	        
	      } elsif(me.armament == "RB 74 Sidewinder") {
	        me.currArmNameSh = "74";	        
	      } elsif(me.armament == "M70 ARAK") {
	        me.currArmNameSh = "70";	        
	      } elsif(me.armament == "RB 71 Skyflash") {
	        me.currArmNameSh = "71";	        
	      } elsif(me.armament == "RB 99 Amraam") {
	        me.currArmNameSh = "99";	        
	      } elsif(me.armament == "TEST") {
	        me.currArmNameSh = "TS";	        
	      } elsif(me.armament == "") {
	        me.currArmNameSh = "";
	      } else {
	        me.currArmNameSh = "--";	        
	      }
	},

	armNamePylon: func (station) {
		  me.armSelect = station;
	      if (me.armSelect > 0) {
	        me.armamentp = getprop("payload/weight["~ (me.armSelect-1) ~"]/selected");
	      } else {
	        me.armamentp = "";
	      }
	      if(me.armSelect == 0) {
	        return "AK";
	      } elsif(me.armamentp == "RB 24J Sidewinder") {
	        return "24";	        
	      } elsif(me.armamentp == "RB 74 Sidewinder") {
	        return "74";	        
	      } elsif(me.armamentp == "M70 ARAK") {
	        return "70";	        
	      } elsif(me.armamentp == "RB 71 Skyflash") {
	        return "71";	        
	      } elsif(me.armamentp == "RB 99 Amraam") {
	        return "99";	        
	      } elsif(me.armamentp == "TEST") {
	        return "TS";	        
	      } else {
	        return nil;
	      }
	},

	displayMode: func {
		# from manual:
		#
		# STARTMOD: always at wow0. Switch to other mode when FPI >3degs or gear retract or mach>0.35 (earliest 4s after wow0==0).
		# NAVMOD: Press B or L, or auto switch after STARTMOD.
		# LANDMOD: Press LT or LS on TI. (key 'Y' is same as LS)
		#
		if (me.input.mach.getValue() != nil) {
		    me.hasRotated = FALSE;
		    if (me.input.mach.getValue() > 0.1) {
		      # we are moving, calc the flight path angle
		      me.vel_gh = math.sqrt(me.input.speed_n.getValue()*me.input.speed_n.getValue()+me.input.speed_e.getValue()*me.input.speed_e.getValue());
		      me.vel_gv = -me.input.speed_d.getValue();
		      me.hasRotated = math.atan2(me.vel_gv, me.vel_gh)*R2D > 3;
		    }
		    me.takeoffForbidden = me.hasRotated or me.input.gearsPos.getValue() != 1;# takeoff no longer allowed
		    me.takeoffForbidden2 = me.input.mach.getValue() > 0.35 and me.modeTimeTakeoff != -1 and me.input.elapsedSec.getValue() - me.modeTimeTakeoff > 4;
		    me.takeoffForbidden = me.takeoffForbidden or me.takeoffForbidden2;
		    if(me.mode!= TAKEOFF and !me.takeoffForbidden and me.input.wow0.getValue() == TRUE and me.input.dev.getValue() != TRUE) {
		      # nosewheel touch runway, so we switch to TAKEOFF
		      me.mode= TAKEOFF;
		      me.input.landingMode.setValue(0);
		      me.modeTimeTakeoff = -1;
		    } elsif (me.input.dev.getValue() == TRUE and me.input.combat.getValue() == 1) {
		      # developer mode is active with tactical request, so we switch to COMBAT
		      me.mode= COMBAT;
		      me.modeTimeTakeoff = -1;
		    } elsif (me.mode== TAKEOFF and me.modeTimeTakeoff == -1 and me.input.wow0.getValue() == FALSE) {
		      # Nosewheel lifted off, so we start the 4 second counter
		      me.modeTimeTakeoff = me.input.elapsedSec.getValue();
		    } elsif (me.mode== TAKEOFF and me.takeoffForbidden == TRUE) {
		        # time to switch away from TAKEOFF mode.
		        if (me.input.landingMode.getValue() == TRUE) {
		          me.mode = LANDING;
		        } else {
		          me.mode = (me.input.combat.getValue() == 1 and me.input.gearsPos.getValue() == 0)? COMBAT : NAV;
		        }
		        me.modeTimeTakeoff = -1;
		    } elsif ((me.mode== COMBAT or me.mode== NAV) and (me.input.landingMode.getValue() == TRUE)) {
		      # Switch to LANDING
		      me.mode= LANDING;
		      me.modeTimeTakeoff = -1;
		    } elsif (me.mode== COMBAT or me.mode== NAV) {
		      # determine if we should have COMBAT or NAV
		      me.mode= (me.input.combat.getValue() == 1 and me.input.gearsPos.getValue() == 0)? COMBAT : NAV;
		      me.modeTimeTakeoff = -1;
		    } elsif (me.mode== LANDING and me.input.landingMode.getValue() == FALSE) {
		      # switch from LANDING to COMBAT/NAV
		      me.mode= (me.input.combat.getValue() == 1 and me.input.gearsPos.getValue() == 0) ? COMBAT : NAV;
		      me.modeTimeTakeoff = -1;
		    }
		    me.input.currentMode.setIntValue(me.mode);
		}
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
};

var common = Common.new();

var init = func {
	removelistener(idl); # only call once
	common.loop();
	common.loopFast();
}	

#idl = setlistener("ja37/supported/initialized", init, 0, 0);
