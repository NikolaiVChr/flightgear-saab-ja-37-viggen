# $Id$
var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }
var encode3bits = func(first, second, third) {
  var integer = first;
  integer = integer + 2 * second;
  integer = integer + 4 * third;
  return integer;
}

var LOOP_STANDARD_RATE = 0.10;
var LOOP_FAST_RATE     = 0.05;
var LOOP_SLOW_RATE     = 1.50;

var FALSE = 0;
var TRUE = 1;

#var prevGear0 = TRUE;
#var prevGear1 = TRUE;
#var prevGear2 = TRUE;
#var touchdown1 = FALSE;
#var touchdown2 = FALSE;
var total_fuel = 0;
var bingoFuel = FALSE;

var mainOn = FALSE;
var mainTimer = -1;

var MISSILE_STANDBY = -1;
var MISSILE_SEARCH = 0;
var MISSILE_LOCK = 1;
var MISSILE_FLYING = 2;
############### Main loop ###############

input = {
  acInstrVolt:      "systems/electrical/outputs/ac-instr-voltage",
  acMainVolt:       "systems/electrical/outputs/ac-main-voltage",
  aeroSmoke:        "/ja37/effect/smoke",
  aeroSmokeCmd:     "/ja37/effect/smoke-cmd",
  airspeed:         "velocities/airspeed-kt",
  alpha:            "orientation/alpha-deg",
  alt:              "position/altitude-ft",
  apLockAlt:        "autopilot/locks/altitude",
  apLockHead:       "autopilot/locks/heading",
  apLockSpeed:      "autopilot/locks/speed",
  asymLoad:         "fdm/jsbsim/inertia/asymmetric-wing-load",
  augmentation:     "/controls/engines/engine[0]/augmentation",
  #autoReverse:      "ja37/autoReverseThrust",
  breathVol:        "ja37/sound/breath-volume",
  buffOut:          "fdm/jsbsim/systems/flight/buffeting/output",
  cabinPressure:    "fdm/jsbsim/systems/flight/cabin-pressure-kpm2",
  canopyPos:        "fdm/jsbsim/fcs/canopy/pos-norm",
  canopyHinge:      "/fdm/jsbsim/fcs/canopy/hinges/serviceable",
  combat:           "/ja37/hud/current-mode",
  cutoff:           "fdm/jsbsim/propulsion/engine/cutoff-commanded",
  damage:           "environment/damage",
  damageSmoke:      "environment/damage-smoke",
  dcVolt:           "systems/electrical/outputs/dc-voltage",
  dens:             "fdm/jsbsim/atmosphere/density-altitude",
  dme:              "instrumentation/dme/KDI572-574/nm",
  dmeDist:          "instrumentation/dme/indicated-distance-nm",
  downFps:          "/velocities/down-relground-fps",
  elapsed:          "sim/time/elapsed-sec",
  elapsedInit:      "sim/time/elapsed-at-init-sec",
  elecMain:         "controls/electric/main",
  engineRunning:    "engines/engine/running",
  envVol:           "ja37/sound/environment-volume",
  fdmAug:           "fdm/jsbsim/propulsion/engine/augmentation",
  flame:            "engines/engine/flame",
  flapPosCmd:       "/fdm/jsbsim/fcs/flaps/pos-cmd",
  fuelInternalRatio:"ja37/avionics/fuel-internal-ratio",
  fuelNeedleB:      "/instrumentation/fuel/needleB_rot",
  fuelNeedleF:      "/instrumentation/fuel/needleF_rot",
  fuelRatio:        "/instrumentation/fuel/ratio",
  fuelTemp:         "ja37/supported/fuel-temp",
  fuelWarning:      "ja37/sound/fuel-low-on",
  fullInit:         "sim/time/full-init",
  g3d:              "/velocities/groundspeed-3D-kt",
  gearCmdNorm:      "/fdm/jsbsim/gear/gear-cmd-norm",
  gearsPos:         "gear/gear/position-norm",
  generatorOn:      "fdm/jsbsim/systems/electrical/generator-running-norm",
  gravity:          "fdm/jsbsim/accelerations/gravity-ft_sec2",
  headingMagn:      "/orientation/heading-magnetic-deg",
  hydr1On:          "fdm/jsbsim/systems/hydraulics/system1/pressure",
  hydr2On:          "fdm/jsbsim/systems/hydraulics/system2/pressure-main",
  hydrCombined:     "fdm/jsbsim/systems/hydraulics/flight-surface-actuation",
  hz05:             "ja37/blink/five-Hz/state",
  hz10:             "ja37/blink/ten-Hz/state",
  hzThird:          "ja37/blink/third-Hz/state",
  impact:           "/ai/models/model-impact",
  indAA:            "ja37/avionics/auto-altitude-on",
  indAH:            "ja37/avionics/auto-attitude-on",
  indAlt:           "/instrumentation/altitude-indicator",
  indAltFt:         "instrumentation/altimeter/indicated-altitude-ft",
  indAltMeter:      "instrumentation/altimeter/indicated-altitude-meter",
  indAT:            "ja37/avionics/auto-throttle-on",
  indAtt:           "/instrumentation/attitude-indicator",
  indJoy:           "/instrumentation/joystick-indicator",
  indRev:           "/instrumentation/reverse-indicator",
  indTrn:           "/instrumentation/transonic-indicator",
  lampCanopy:       "ja37/avionics/canopyAndSeat",
  lampData:         "ja37/avionics/primaryData",
  lampIgnition:     "ja37/avionics/ignitionSys",
  lampInertiaNav:   "ja37/avionics/TN",
  lampOxygen:       "ja37/avionics/oxygen",
  lampStart:        "ja37/avionics/startSys",
  lampStick:        "ja37/avionics/joystick",
  lampXTank:        "ja37/avionics/xtank",
  landLight:        "ja37/effect/landing-light",
  landLightALS:     "sim/rendering/als-secondary-lights/use-landing-light",
  landLightSupport: "ja37/supported/landing-light",
  landLightSwitch:  "controls/electric/lights-land-switch",
  lockPassive:      "/autopilot/locks/passive-mode",
  mach:             "velocities/mach",
  mass1:            "fdm/jsbsim/inertia/pointmass-weight-lbs[1]",
  mass3:            "fdm/jsbsim/inertia/pointmass-weight-lbs[3]",
  mass5:            "fdm/jsbsim/inertia/pointmass-weight-lbs[5]",
  mass6:            "fdm/jsbsim/inertia/pointmass-weight-lbs[6]",
  MPfloat2:         "sim/multiplay/generic/float[2]",
  MPfloat9:         "sim/multiplay/generic/float[9]",
  MPint17:          "sim/multiplay/generic/int[17]",
  MPint18:          "sim/multiplay/generic/int[18]",
  MPint19:          "sim/multiplay/generic/int[19]",
  MPint9:           "sim/multiplay/generic/int[9]",
  n1:               "/engines/engine/n1",
  n2:               "/engines/engine/n2",
  nearby:           "damage/sounds/nearby-explode-on",
  explode:          "damage/sounds/explode-on",
  pilotG:           "ja37/accelerations/pilot-G",
  pneumatic:        "fdm/jsbsim/systems/fuel/pneumatics/serviceable",
  rad_alt:          "position/altitude-agl-ft",
  rainNorm:         "environment/rain-norm",
  rainVol:          "ja37/sound/rain-volume",
  replay:           "sim/replay/replay-state",
  reversed:         "/engines/engine/is-reversed",
  rmActive:         "/autopilot/route-manager/active",
  rmBearing:        "/autopilot/route-manager/wp/bearing-deg",
  rmBearingRel:     "autopilot/route-manager/wp/bearing-deg-rel",
  rmDist:           "autopilot/route-manager/wp/dist",
  rmDistKm:         "autopilot/route-manager/wp/dist-km",
  roll:             "/instrumentation/attitude-indicator/indicated-roll-deg",
  sceneRed:         "/rendering/scene/diffuse/red",
  servFire:         "engines/engine[0]/fire/serviceable",
  serviceElec:      "systems/electrical/serviceable",
  speedKt:          "/instrumentation/airspeed-indicator/indicated-speed-kt",
  speedTrueKt:      "fdm/jsbsim/velocities/vtrue-kts",
  speedMach:        "/instrumentation/airspeed-indicator/indicated-mach",
  speedWarn:        "ja37/sound/speed-on",
  srvHead:          "instrumentation/heading-indicator/serviceable",
  starter:          "controls/engines/engine[0]/starter-cmd",
  stationSelect:    "controls/armament/station-select",
  subAmmo2:         "ai/submodels/submodel[2]/count", 
  subAmmo3:         "ai/submodels/submodel[3]/count", 
  sunAngle:         "sim/time/sun-angle-rad",
  switchBeacon:     "controls/electric/lights-ext-beacon",
  switchFlash:      "controls/electric/lights-ext-flash",
  switchNav:        "controls/electric/lights-ext-nav",
  tank0LvlGal:      "/consumables/fuel/tank[0]/level-gal_us",
  tank0LvlNorm:     "/consumables/fuel/tank[0]/level-norm",
  tank1LvlGal:      "/consumables/fuel/tank[1]/level-gal_us",
  tank2LvlGal:      "/consumables/fuel/tank[2]/level-gal_us",
  tank3LvlGal:      "/consumables/fuel/tank[3]/level-gal_us",
  tank4LvlGal:      "/consumables/fuel/tank[4]/level-gal_us",
  tank5LvlGal:      "/consumables/fuel/tank[5]/level-gal_us",
  tank6LvlGal:      "/consumables/fuel/tank[6]/level-gal_us",
  tank7LvlGal:      "/consumables/fuel/tank[7]/level-gal_us",
  tank8Flow:        "fdm/jsbsim/propulsion/tank[8]/external-flow-rate-pps",
  tank8Jettison:    "/consumables/fuel/tank[8]/jettisoned",
  tank8LvlGal:      "/consumables/fuel/tank[8]/level-gal_us",
  tank8LvlNorm:     "/consumables/fuel/tank[8]/level-norm",
  tank8Selected:    "/consumables/fuel/tank[8]/selected",
  tempDegC:         "environment/temperature-degc",
  thrustLb:         "engines/engine/thrust_lb",
  thrustLbAbs:      "engines/engine/thrust_lb-absolute",
  TILS:             "ja37/hud/TILS",
  trigger:          "controls/armament/trigger",
  vgFps:            "/fdm/jsbsim/velocities/vg-fps",
  viewInternal:     "sim/current-view/internal",
  viewName:         "sim/current-view/name",
  viewYOffset:      "sim/current-view/y-offset-m",
  warnButton:       "ja37/avionics/master-warning-button",
  wow0:             "fdm/jsbsim/gear/unit[0]/WOW",
  wow1:             "fdm/jsbsim/gear/unit[1]/WOW",
  wow2:             "fdm/jsbsim/gear/unit[2]/WOW",
  zAccPilot:        "accelerations/pilot/z-accel-fps_sec",
};
   
var update_loop = func {

  # Stuff that will run even in replay:

  # breath sound volume
  input.breathVol.setDoubleValue(input.viewInternal.getValue() and input.fullInit.getValue());

  #augmented flame translucency
  var red = input.sceneRed.getValue();
  # normal effect
  #var angle = input.sunAngle.getValue();# 1.25 - 2.45
  #var newAngle = (1.2 -(angle-1.25))*0.8333;
  #input.MPfloat2.setValue(newAngle);
  var translucency = clamp(red, 0.35, 1);
  input.MPfloat2.setDoubleValue(translucency);

  # ALS effect
  red = clamp(1 - red, 0.25, 1);
  input.MPfloat9.setDoubleValue(red);

  # End stuff

  if(input.replay.getValue() == TRUE) {
    # replay is active, skip rest of loop.
    settimer(update_loop, LOOP_STANDARD_RATE);
  } else {
    # set the full-init property
    if(input.elapsed.getValue() > input.elapsedInit.getValue() + 5) {
      input.fullInit.setBoolValue(TRUE);
    } else {
      input.fullInit.setBoolValue(FALSE);
    }

  	 ## Sets fuel gauge needles rotation ##
  	 
     if(input.tank8LvlNorm.getValue() != nil) {
       #input.fuelNeedleB.setDoubleValue(input.tank8LvlNorm.getValue()*230);
       input.fuelNeedleB.setDoubleValue(0);
     }     

    var current = input.tank0LvlGal.getValue()
                + input.tank1LvlGal.getValue()
                + input.tank2LvlGal.getValue()
                + input.tank3LvlGal.getValue()
                + input.tank4LvlGal.getValue()
                + input.tank5LvlGal.getValue()
                + input.tank6LvlGal.getValue()
                + input.tank7LvlGal.getValue()
                + input.tank8LvlGal.getValue();


    input.fuelNeedleF.setDoubleValue((current / total_fuel) *230);
    input.fuelRatio.setDoubleValue(current / total_fuel);

    # fuel warning annuciator
    if((current / total_fuel) < 0.24) {# warning at 24% as per sources
      input.fuelWarning.setBoolValue(TRUE);
    } else {
      input.fuelWarning.setBoolValue(FALSE);
    }

    input.fuelInternalRatio.setDoubleValue(current / total_fuel);
    
    if (current > 0 and input.tank8LvlNorm.getValue() > 0) {
      bingoFuel = FALSE;
    } else {
      bingoFuel = TRUE;
    }

    if (input.tank0LvlNorm.getValue() == 0) {
      # a bug in JSB makes NaN on fuel temp if tank has been empty.
      input.fuelTemp.setBoolValue(FALSE);
    }

    #if(getprop("/sim/failure-manager/controls/flight/rudder/serviceable") == 1) {
    #  setprop("fdm/jsbsim/fcs/rudder/serviceable", 1);
    #} elsif (getprop("fdm/jsbsim/fcs/rudder/serviceable") == 1) {
    #  setprop("fdm/jsbsim/fcs/rudder-sum-stuck", getprop("fdm/jsbsim/fcs/rudder-sum"));
    #  setprop("fdm/jsbsim/fcs/rudder-serviceable", 0);
    #}

    # automatic reverse thrust enabler
    #var reversed = input.reversed.getValue();

    #var gear0 = input.wow0.getValue();
    #var gear1 = input.wow1.getValue();
    #var gear2 = input.wow2.getValue();

    #if(input.autoReverse.getValue() == TRUE and reversed == FALSE) {
    #  if(gear1 == TRUE) {
        #left boogie touching
    #    if(prevGear1 == FALSE) {
    #      touchdown1 = TRUE;
    #    }
    #  } else {
    #    touchdown1 = FALSE;
    #  }
    #  if(gear2 == TRUE) {
        #right boogie touching
    #    if(prevGear2 == FALSE) {
    #      touchdown2 = TRUE;
    #    }
    #  } else {
    #    touchdown2 = FALSE;
    #  }
    #  if(touchdown1 == TRUE and touchdown2 == TRUE) {
    #    if(gear0 == TRUE) {
          #print("Auto-reversing the thrust");
    #      touchdown1 = FALSE;
    #      touchdown2 = FALSE;
    #      reversethrust.reverserOn();
    #    }
    #  }
    #}

    #prevGear0 = gear0;
    #prevGear1 = gear1;
    #prevGear2 = gear2;

    # meter altitude property

    input.indAltMeter.setDoubleValue(input.indAltFt.getValue()*0.3048);

    # front gear compression calc for spinning of wheel
    # setprop("gear/gear/compression-wheel", (getprop("gear/gear/compression-ft")*0.3048-1.84812));


    # low speed warning (as per manual page 279 in JA37C part 1)
    var lowSpeed = FALSE;
    if (auto.modeT < 2 and (input.speedKt.getValue() * 1.85184) < 375 and input.wow1.getValue() == FALSE) {
      if (input.indAltMeter.getValue() < 1200) {
        if (
          (input.gearsPos.getValue() == 1 and (getprop("controls/altimeter-radar")==TRUE?(input.rad_alt.getValue() * FT2M) > 30:(input.indAltFt.getValue() * FT2M) > 30))
          or input.gearsPos.getValue() != 1) {
          if (getprop("fdm/jsbsim/fcs/throttle-pos-deg") < 19 or input.reversed.getValue() == TRUE or input.engineRunning.getValue() == FALSE) {
            lowSpeed = TRUE;
          }
        }
      }
    }
    input.speedWarn.setBoolValue(lowSpeed);

    # main electrical turned on
    var timer = input.elapsed.getValue();
    var main = input.dcVolt.getValue();
    if(main > 20 and mainOn == FALSE) {
      #main has been switched on
      mainTimer = timer;
      mainOn = TRUE;
      input.lampData.setBoolValue(TRUE);
      input.lampInertiaNav.setBoolValue(TRUE);
    } elsif (main > 20) {
      if (timer > (mainTimer + 20)) {
        input.lampData.setBoolValue(FALSE);
      }
      if (timer > (mainTimer + 140)) {
        input.lampInertiaNav.setBoolValue(FALSE);
      }
    } elsif (main <= 20) {
      mainOn = FALSE;
    }

    # exterior lights
    var flash = input.dcVolt.getValue() > 20 and input.switchFlash.getValue() == 1;
    var beacon = input.dcVolt.getValue() > 20 and input.switchBeacon.getValue() == 1;
    var nav = input.dcVolt.getValue() > 20 and input.switchNav.getValue() == 1;
    input.MPint9.setIntValue(encode3bits(flash, beacon, nav));

    # contrails, damage smoke
    var contrails = input.tempDegC.getValue() < -40 and input.alt.getValue() > 19000 and input.n2.getValue() > 50;
    var smoke = !input.servFire.getValue()+input.damage.getValue();
    input.damageSmoke.setValue(smoke);
    var d_smoke = input.damageSmoke.getValue();
    input.MPint18.setIntValue(encode3bits(contrails, d_smoke, 0));

    # smoke
    if (input.dcVolt.getValue() > 20) {
      input.aeroSmoke.setIntValue(input.aeroSmokeCmd.getValue());
    } else {
      input.aeroSmoke.setIntValue(1);
    }

	  var DME = input.dme.getValue() != "---" and input.dme.getValue() != "" and input.dmeDist.getValue() != nil;
    
    # distance indicator
    if (DME == TRUE) {
      var distance = input.dmeDist.getValue() * 1.852;
      if (distance > 40) {
        distance = 40;
      }
      input.rmDistKm.setDoubleValue(distance);
    } elsif (input.rmActive.getValue() == TRUE and input.rmDist.getValue() != nil) {
      # converts waypoint distance to km, for use in the distance indicator. 1nm = 1.852km = 1852 meters.
      input.rmDistKm.setDoubleValue(input.rmDist.getValue() * 1.852 );
    } else {
      input.rmDistKm.setDoubleValue(0);
    }

    # radar compass
	  if (input.rmActive.getValue() == TRUE and input.srvHead.getValue() == TRUE) {
	    # sets the proper degree of the yellow waypoint heading indicator on the compass that surrounds the radar.
	    input.rmBearingRel.setDoubleValue(input.rmBearing.getValue() - input.headingMagn.getValue());
    }

    if(getprop("ja37/systems/variant") != 0 and getprop("/instrumentation/radar/range") == 180000) {
      setprop("/instrumentation/radar/range", 120000);
    }

    # ALS heat blur
    var inv_speed = 100-getprop("velocities/airspeed-kt");
	  setprop("velocities/airspeed-kt-inv", inv_speed);
    setprop("ja37/effect/heatblur/dens", clamp((getprop("engines/engine/n2")/100-getprop("velocities/airspeed-kt")/250)*0.035, 0, 1));

    ## terrain detection ##
    if (getprop("ja37/supported/picking") == TRUE) {
      setprop("ja37/radar/look-through-terrain", FALSE);
    }
    if (getprop("ja37/supported/picking") == TRUE and (getprop("velocities/speed-east-fps") != 0 or getprop("velocities/speed-north-fps") != 0)) {
      var start = geo.aircraft_position();

      var speed_down_fps  = getprop("velocities/speed-down-fps");
      var speed_east_fps  = getprop("velocities/speed-east-fps");
      var speed_north_fps = getprop("velocities/speed-north-fps");
      var speed_horz_fps  = math.sqrt((speed_east_fps*speed_east_fps)+(speed_north_fps*speed_north_fps));
      var speed_fps       = math.sqrt((speed_horz_fps*speed_horz_fps)+(speed_down_fps*speed_down_fps));
      var heading = 0;
      if (speed_north_fps >= 0) {
        heading -= math.acos(speed_east_fps/speed_horz_fps)*R2D - 90;
      } else {
        heading -= -math.acos(speed_east_fps/speed_horz_fps)*R2D - 90;
      }
      heading = geo.normdeg(heading);
      #cos(90-heading)*horz = east
      #acos(east/horz) - 90 = -head

      var end = geo.Coord.new(start);
      end.apply_course_distance(heading, speed_horz_fps*FT2M);
      end.set_alt(end.alt()-speed_down_fps*FT2M);

      var dir_x = end.x()-start.x();
      var dir_y = end.y()-start.y();
      var dir_z = end.z()-start.z();
      var xyz = {"x":start.x(),  "y":start.y(),  "z":start.z()};
      var dir = {"x":dir_x,      "y":dir_y,      "z":dir_z};

      var geod = get_cart_ground_intersection(xyz, dir);
      if (geod != nil) {
        end.set_latlon(geod.lat, geod.lon, geod.elevation);
        var dist = start.direct_distance_to(end)*M2FT;
        var time = dist / speed_fps;
        setprop("/ja37/radar/time-till-crash", time);
      } else {
        setprop("/ja37/radar/time-till-crash", 15);
      }
    } else {
      setprop("/ja37/radar/time-till-crash", 15);
    }

    # conditionals for dropping M70/droptank
    if (getprop("sim/multiplay/generic/int[2]") == TRUE and getprop("sim/multiplay/generic/float[11]") == 794) {
      #left wing rocket pod mounted
      setprop("ja37/effect/pod0", FALSE);
      setprop("ai/submodels/submodel[17]/count", 1);
    } else {
      setprop("ja37/effect/pod0", TRUE);
    }
    if (getprop("sim/multiplay/generic/float[12]") == 794) {
      #left wing rocket pod mounted
      setprop("ja37/effect/pod1", FALSE);
      setprop("ai/submodels/submodel[18]/count", 1);
    } else {
      setprop("ja37/effect/pod1", TRUE);
    }
    if (getprop("sim/multiplay/generic/int[2]") == TRUE and getprop("sim/multiplay/generic/float[13]") == 794) {
      #left wing rocket pod mounted
      setprop("ja37/effect/pod2", FALSE);
      setprop("ai/submodels/submodel[19]/count", 1);
    } else {
      setprop("ja37/effect/pod2", TRUE);
    }
    if (getprop("sim/multiplay/generic/float[14]") == 794) {
      #left wing rocket pod mounted
      setprop("ja37/effect/pod3", FALSE);
      setprop("ai/submodels/submodel[20]/count", 1);
    } else {
      setprop("ja37/effect/pod3", TRUE);
    }
    if (getprop("sim/multiplay/generic/float[10]") == 794) {
      #left wing rocket pod mounted
      setprop("ja37/effect/pod4", FALSE);
      setprop("ai/submodels/submodel[21]/count", 1);
    } else {
      setprop("ja37/effect/pod4", TRUE);
    }

    settimer(
      #func debug.benchmark("j37 loop", 
        update_loop
        #)
    , LOOP_STANDARD_RATE);
  }
}

var TILSprev = FALSE;
var acPrev = 0;
var acTimer = 0;

# slow updating loop
var slow_loop = func () {
  if(input.replay.getValue() == TRUE) {
    # replay is active, skip rest of loop.
    settimer(slow_loop, LOOP_SLOW_RATE);
    return;
  }

  #TILS
  if(1==0 and input.TILS.getValue() == TRUE and input.acInstrVolt.getValue() > 100) {#  and canvas_HUD != nil and canvas_HUD.mode == canvas_HUD.LANDING
    var icao = getprop("sim/tower/airport-id");
    var runways = airportinfo(icao).runways;
    var closestRunway = -1;
    var secondClosestRunway = -1;
    var closestDistance = 10000000;
    #print();
    foreach(i ; keys(runways)) {
      var r = runways[i];
      if (r.ils != nil) {
        var coord = geo.Coord.new();
        coord.set_latlon(r.lat, r.lon);
        var distance = geo.aircraft_position().distance_to(coord);
        #print(icao~" runway "~i~" has ILS. Distance "~distance~" meter.");
        if(distance < closestDistance) {
          if (closestDistance - distance < 200) {
            secondClosestRunway = closestRunway;
          } else {
            secondClosestRunway = -1;
          }
          closestDistance = distance;
          closestRunway = i;
        } else {
          if (distance - closestDistance < 200) {
            secondClosestRunway = i;
          }
        }
      } else {
        #print(icao~" runway "~i~" has not.");
      }
    }
    if(closestRunway != -1) {
      var oldFreq = TILSprev==FALSE?0.0:getprop("instrumentation/nav[0]/frequencies/selected-mhz");
      var newFreq = runways[closestRunway].ils.frequency / 100;

      if (oldFreq != newFreq) {
        setprop("instrumentation/nav[0]/frequencies/selected-mhz", newFreq);
        var standbyStr = "";
        if (secondClosestRunway != -1) {
          standbyStr = " (Standby: "~secondClosestRunway~")";
          setprop("instrumentation/nav[0]/frequencies/standby-mhz", runways[secondClosestRunway].ils.frequency / 100);
        }
        notice("TILS tuned to "~icao~" "~closestRunway~standbyStr, 25, 6);
      }
    }
    TILSprev = TRUE;
    setprop("ja37/hud/TILS-on", TRUE);
  } else {
    setprop("ja37/hud/TILS-on", FALSE);
    TILSprev = FALSE;
  }

  if (getprop("sim/replay/replay-state") == 0 and input.acInstrVolt.getValue() > 100) {
    setprop("ja37/avionics/record-on", TRUE);
  } else {
    setprop("ja37/avionics/record-on", FALSE);
  }

  ###########################################################
  #               Aircondition, frost, fog and rain         #
  ###########################################################

  # If AC is set to warm or cold, then it will put warm/cold air into the cockpit for 12 seconds, and then revert to auto setting.

  var acSetting = getprop("controls/ventilation/airconditioning-type");
  if (acSetting != 0) {
    # 12 second of cold or hot air has been selected.
    if (acPrev != acSetting) {
      acTimer = input.elapsed.getValue();
    } elsif (acTimer+12 < input.elapsed.getValue()) {
      setprop("controls/ventilation/airconditioning-type", 0);
      acSetting = 0;
    }
  }
  acPrev = acSetting;
  var tempAC = getprop("controls/ventilation/airconditioning-temperature");
  if (acSetting == -1) {
    tempAC = -200;
  } elsif (acSetting == 1) {
    tempAC = 200;
  }

  # Here is calculated how raindrop move over the surface of the glass

  var airspeed = getprop("/velocities/airspeed-kt");
  # ja37
  #var airspeed_max = 250; 
  var airspeed_max = 120;
  if (airspeed > airspeed_max) {
    airspeed = airspeed_max;
  }
  airspeed = math.sqrt(airspeed/airspeed_max);
  # Reverted the vector from what is used on the f-16
  var splash_x = -(-0.1 - 2.0 * airspeed);
  var splash_y = 0.0;
  var splash_z = -(1.0 - 1.35 * airspeed);
  setprop("/environment/aircraft-effects/splash-vector-x", splash_x);
  setprop("/environment/aircraft-effects/splash-vector-y", splash_y);
  setprop("/environment/aircraft-effects/splash-vector-z", splash_z);

  # If the AC is turned on and on auto setting, it will slowly move the cockpit temperature toward its temperature setting.
  # The dewpoint inside the cockpit depends on the outside dewpoint and how the AC is working.
  var tempOutside = getprop("environment/temperature-degc");
  var ramRise     = (input.speedTrueKt.getValue()*input.speedTrueKt.getValue())/(87*87);#this is called the ram rise formula
  tempOutside    += ramRise;
  var tempInside  = getprop("environment/aircraft-effects/temperature-inside-degC");
  var tempOutsideDew = getprop("environment/dewpoint-degc");
  var tempInsideDew = getprop("/environment/aircraft-effects/dewpoint-inside-degC");
  var tempACDew = 5;# aircondition dew point target. 5 = dry
  var ACRunning = input.dcVolt.getValue() > 23 and getprop("controls/ventilation/airconditioning-enabled") == TRUE;

  # calc inside temp
  var hotAir_deg_min = 2.0;# how fast does the sources heat up cockpit.
  var AC_deg_min     = 6.0;
  var pilot_deg_min  = 0.2;
  var knob = getprop("controls/ventilation/windshield-hot-air-knob");
  var hotAirOnWindshield = input.dcVolt.getValue() > 23?knob:0;
  if (input.canopyPos.getValue() > 0 or input.canopyHinge.getValue() == FALSE) {
    tempInside = tempOutside;
  } else {
    tempInside = tempInside + hotAirOnWindshield * (hotAir_deg_min/(60/LOOP_SLOW_RATE)); # having hot air on windshield will also heat cockpit (10 degs/5 mins).
    if (tempInside < 37) {
      tempInside = tempInside + (pilot_deg_min/(60/LOOP_SLOW_RATE)); # pilot will also heat cockpit with 1 deg per 5 mins
    }
    # outside temp will influence inside temp:
    var coolingFactor = clamp(abs(tempInside - tempOutside)*0.005, 0, 0.10);# 20 degrees difference will cool/warm with 0.10 Deg C every 1.5 second
    if (tempInside < tempOutside) {
      tempInside = clamp(tempInside+coolingFactor, -1000, tempOutside);
    } elsif (tempInside > tempOutside) {
      tempInside = clamp(tempInside-coolingFactor, tempOutside, 1000);
    }
    if (ACRunning == TRUE) {
      # AC is running and will work to adjust to influence the inside temperature
      if (tempInside < tempAC) {
        tempInside = clamp(tempInside+(AC_deg_min/(60/LOOP_SLOW_RATE)), -1000, tempAC);
      } elsif (tempInside > tempAC) {
        tempInside = clamp(tempInside-(AC_deg_min/(60/LOOP_SLOW_RATE)), tempAC, 1000);
      }
    }
  }

  # calc temp of glass itself
  var tempIndex = getprop("/environment/aircraft-effects/glass-temperature-index"); # 0.80 = good window   0.45 = bad window
  var tempGlass = tempIndex*(tempInside - tempOutside)+tempOutside;
  
  # calc dewpoint inside
  if (input.canopyPos.getValue() > 0 or input.canopyHinge.getValue() == FALSE) {
    # canopy is open, inside dewpoint aligns to outside dewpoint instead
    tempInsideDew = tempOutsideDew;
  } else {
    var tempInsideDewTarget = 0;
    if (ACRunning == TRUE) {
      # calculate dew point for inside air. When full airconditioning is achieved at tempAC dewpoint will be tempACdew.
      # slope = (outsideDew - desiredInsideDew)/(outside-desiredInside)
      # insideDew = slope*(inside-desiredInside)+desiredInsideDew
      var slope = (tempOutsideDew - tempACDew)/(tempOutside-tempAC);
      tempInsideDewTarget = slope*(tempInside-tempAC)+tempACDew;
    } else {
      tempInsideDewTarget = tempOutsideDew;
    }
    if (tempInsideDewTarget > tempInsideDew) {
      tempInsideDew = clamp(tempInsideDew + 0.15, -1000, tempInsideDewTarget);
    } else {
      tempInsideDew = clamp(tempInsideDew - 0.15, tempInsideDewTarget, 1000);
    }
  }
  

  # calc fogging outside and inside on glass
  var fogNormOutside = clamp((tempOutsideDew-tempGlass)*0.05, 0, 1);
  var fogNormInside = clamp((tempInsideDew-tempGlass)*0.05, 0, 1);
  
  # calc frost
  var frostNormOutside = getprop("/environment/aircraft-effects/frost-outside");
  var frostNormInside = getprop("/environment/aircraft-effects/frost-inside");
  var rain = getprop("/environment/rain-norm");
  if (rain == nil) {
    rain = 0;
  }
  var frostSpeedInside = clamp(-tempGlass, -60, 60)/600 + (tempGlass<0?fogNormInside/50:0);
  var frostSpeedOutside = clamp(-tempGlass, -60, 60)/600 + (tempGlass<0?(fogNormOutside/50 + rain/50):0);
  var maxFrost = clamp(1 + ((tempGlass + 5) / (0 + 5)) * (0 - 1), 0, 1);# -5 is full frost, 0 is no frost
  var maxFrostInside = clamp(maxFrost - clamp(tempInside/30,0,1), 0, 1);# frost having harder time to form while being constantly thawed.
  frostNormOutside = clamp(frostNormOutside + frostSpeedOutside, 0, maxFrost);
  frostNormInside = clamp(frostNormInside + frostSpeedInside, 0, maxFrostInside);
  var frostNorm = frostNormOutside>frostNormInside?frostNormOutside:frostNormInside;
  #var frostNorm = clamp((tempGlass-0)*-0.05, 0, 1);# will freeze below 0

  # recalc fogging from frost levels, frost will lower the fogging
  fogNormOutside = clamp(fogNormOutside - frostNormOutside / 4, 0, 1);
  fogNormInside = clamp(fogNormInside - frostNormInside / 4, 0, 1);
  var fogNorm = fogNormOutside>fogNormInside?fogNormOutside:fogNormInside;

  # If the hot air on windshield is enabled and its setting is high enough, then apply the mask which will defog the windshield.
  var mask = FALSE;
  if (frostNorm <= hotAirOnWindshield and hotAirOnWindshield != 0) {
    mask = TRUE;
  }

  # internal environment
  setprop("/environment/aircraft-effects/fog-inside", fogNormInside);
  setprop("/environment/aircraft-effects/fog-outside", fogNormOutside);
  setprop("/environment/aircraft-effects/frost-inside", frostNormInside);
  setprop("/environment/aircraft-effects/frost-outside", frostNormOutside);
  setprop("/environment/aircraft-effects/temperature-glass-degC", tempGlass);
  setprop("/environment/aircraft-effects/dewpoint-inside-degC", tempInsideDew);
  setprop("/environment/aircraft-effects/temperature-inside-degC", tempInside);
  # effects
  setprop("/environment/aircraft-effects/frost-level", frostNorm);
  setprop("/environment/aircraft-effects/fog-level", fogNorm);
  setprop("/environment/aircraft-effects/use-mask", mask);
  if (rand() > 0.95) {
    if (tempInside < 10) {
      if (tempInside < 5) {
        screen.log.write("You are freezing, the cabin is very cold", 1.0, 0.0, 0.0);
      } else {
        screen.log.write("You feel cold, the cockpit is cold", 1.0, 0.5, 0.0);
      }
    } elsif (tempInside > 23) {
      if (tempInside > 26) {
        screen.log.write("You are sweating, the cabin is way too hot", 1.0, 0.0, 0.0);
      } else {
        screen.log.write("You feel its too warm in the cabin", 1.0, 0.5, 0.0);
      }
    }
  }
  # consume oxygen bottle pressure
  if (getprop("controls/oxygen") == TRUE) {
    var amount = getprop("ja37/systems/oxygen-bottle-pressure")-127/(27000/LOOP_SLOW_RATE);#7.5 hours to consume all 127 kpm2
    setprop("ja37/systems/oxygen-bottle-pressure", amount);
  }

  # warnings if trouble breathing
  var mask = getprop("fdm/jsbsim/systems/flight/oxygen-pressure-kPa");
  var cabin = getprop("fdm/jsbsim/systems/flight/cabin-pressure-kPa");
  var oxy = getprop("/controls/oxygen");
  var bottle = getprop("/ja37/systems/oxygen-bottle-pressure");
  if (rand() > 0.75) {
    if (cabin < 25) {
      if (oxy == FALSE or bottle < 25) {
        screen.log.write("You feel dizzy from lack of oxygen", 1.0, 0.0, 0.0);
      }
    } elsif (cabin < 35) {
      if (oxy == FALSE or bottle < 35) {
        screen.log.write("You feel the lack of oxygen", 1.0, 0.5, 0.0);
      }
    }
  }

  #warning if max rolling speed is exceeded
  var max = getprop("limits/vroll");
  if ((input.wow0.getValue() == TRUE or input.wow2.getValue() == TRUE) and max != nil and getprop("velocities/groundspeed-kt") > max) {
    screen.log.write("Maximum allowed rolling speed exceeded!", 1.0, 0.0, 0.0);
  }

  settimer(slow_loop, LOOP_SLOW_RATE);
}

# fast updating loop
var speed_loop = func () {

  setprop("controls/engines/engine[0]/cutoff", getprop("fdm/jsbsim/propulsion/engine/cutoff-actual"));

  # switch on and off ALS landing lights
  if(input.landLight.getValue() > 0) {    
    if(input.viewInternal.getValue() == TRUE and input.landLightSupport.getValue() == TRUE) {
        input.landLightALS.setBoolValue(TRUE);
      } else {
        input.landLightALS.setBoolValue(FALSE);
      }
  } else {
    input.landLightALS.setBoolValue(FALSE);
  }

  if(input.replay.getValue() == TRUE) {
    # replay is active, skip rest of loop.
    settimer(speed_loop, LOOP_FAST_RATE);
    return;
  }

  ## control augmented thrust ##
  var n1 = input.n1.getValue();
  var n2 = input.n2.getValue();
  var reversed = input.reversed.getValue();

  if ( input.fdmAug.getValue() == TRUE) { #was 99 and 97
    input.augmentation.setBoolValue(TRUE);
  } else {
    input.augmentation.setBoolValue(FALSE);
  }

  # Animating engine fire
  if (n1 > 100) n1 = 100;
  var flame = 100 / (101-n1);
  input.flame.setDoubleValue(flame);

  ## set groundspeed property used for crashcode ##
  var horz_speed = input.vgFps.getValue();
  var vert_speed = input.downFps.getValue();
  var real_speed = math.sqrt((horz_speed * horz_speed) + (vert_speed * vert_speed));
  real_speed = real_speed * 0.5924838;#ft/s to kt
  input.g3d.setDoubleValue(real_speed);

  # MP gear wow
  var wow0 = input.wow0.getValue();
  var wow1 = input.wow1.getValue();
  var wow2 = input.wow2.getValue();
  input.MPint17.setIntValue(encode3bits(wow0, wow1, wow2));

  # environment volume
  var canopy = input.canopyHinge.getValue() == FALSE?1:input.canopyPos.getValue();
  var internal = input.viewInternal.getValue();
  var vol = 0;
  if(internal != nil and canopy != nil) {
    vol = clamp(1-(internal*0.5)+(canopy*0.5), 0, 1);
  } else {
    vol = 0;
  }
  input.envVol.setDoubleValue(vol);
  var rain = input.rainNorm.getValue();
  if (rain == nil) {
    rain = 0;
  }
  input.rainVol.setDoubleValue(rain*0.35*vol);

  theShakeEffect();

  logTime();

  settimer(speed_loop, LOOP_FAST_RATE);
}


var defaultView = getprop("sim/view/config/y-offset-m");
setprop("ja37/effect/seat", defaultView);

var logTime = func{
  #log time and date for outputing ucsv files for converting into KML files for google earth.
  if (getprop("logging/log[0]/enabled") == TRUE and getprop("sim/time/utc/year") != nil) {
    var date = getprop("sim/time/utc/year")~"/"~getprop("sim/time/utc/month")~"/"~getprop("sim/time/utc/day");
    var time = getprop("sim/time/utc/hour")~":"~getprop("sim/time/utc/minute")~":"~getprop("sim/time/utc/second");

    setprop("logging/date-log", date);
    setprop("logging/time-log", time);
  }
}

var map = func (value, leftMin, leftMax, rightMin, rightMax) {
      # Figure out how 'wide' each range is
      var leftSpan = leftMax - leftMin;
      var rightSpan = rightMax - rightMin;

      # Convert the left range into a 0-1 range (float)
      var valueScaled = (value - leftMin) / leftSpan;

      # Convert the 0-1 range into a value in the right range.
      return rightMin + (valueScaled * rightSpan);
}

var theShakeEffect = func{
  var rSpeed = input.airspeed.getValue();#change to ground speed
  var G = input.pilotG.getValue();
  var alpha = input.alpha.getValue();
  var mach = input.mach.getValue();
  var wow = input.wow1.getValue();
  var near = input.nearby.getValue();
  var explode = input.explode.getValue();

  if (rSpeed == nil or G == nil or alpha == nil or mach == nil or wow == nil or near == nil or explode == nil) {
    return;
  }

  defaultView = getprop("ja37/effect/seat");

  if(input.viewName.getValue() == "Cockpit View" and (((G > 7 or alpha>4.5) and rSpeed>30) or (mach>0.97 and mach<1.05) or (wow and rSpeed>100) or near == TRUE or explode == TRUE)) {
    var factor = 0;
    var densFactor = clamp(1-input.dens.getValue()/30000, 0, 1);
    if (G > 7) {
      factor += map(G,7,9,0,1)*densFactor;
    }
    if (alpha > 4.5 and rSpeed > 30 and mach < 1) {
      factor += map(alpha,4.5,12,0,1)*densFactor;# manual says no buffeting from alpha at mach 1+. And that it starts from 4.5 and goes to max at 12.
    }
    if (mach>0.97 and mach<1.05) {
      factor += 1*densFactor;
    }
    if (wow == TRUE and rSpeed > 100) {
      factor += map(rSpeed,100,200,0,0.50);
    }    
    factor = clamp(factor,0,1);
    if (near == TRUE) {
      factor += 2;
    }
    if (explode == TRUE) {
      factor += 3.5;
    }
    setprop("ja37/effect/buffeting", factor);
    input.viewYOffset.setDoubleValue(defaultView+input.buffOut.getValue()*factor); 
  } elsif (input.viewName.getValue() == "Cockpit View") {
    setprop("ja37/effect/buffeting", 0);
    input.viewYOffset.setDoubleValue(defaultView);
  } 
}

###########  loop for handling the battery signal for cockpit sound #########
var voltage = 0;
var signalInProgress = FALSE;
var battery_listener = func {

    if (signalInProgress == FALSE and voltage <= 23 and input.dcVolt.getValue() > 23) {
      setprop("/systems/electrical/batterysignal", TRUE);
      signalInProgress = TRUE;
      settimer(func {
        setprop("/systems/electrical/batterysignal", FALSE);
        signalInProgress = FALSE;
        }, 6);
    }
    voltage = input.dcVolt.getValue();
    settimer(battery_listener, 0.5);
}

#setlistener("controls/electric/main", battery_listener, 0, 0);
#setlistener("controls/electric/battery", battery_listener, 0, 0);
#setlistener("fdm/jsbsim/systems/electrical/external/switch", battery_listener, 0, 0);
#setlistener("fdm/jsbsim/systems/electrical/external/enable-cmd", battery_listener, 0, 0);



########### Thunder sounds (from c172p) ###################

var speed_of_sound = func (t, re) {
    # Compute speed of sound in m/s
    #
    # t = temperature in Celsius
    # re = amount of water vapor in the air

    # Compute virtual temperature using mixing ratio (amount of water vapor)
    # Ratio of gas constants of dry air and water vapor: 287.058 / 461.5 = 0.622
    var T = 273.15 + t;
    var v_T = T * (1 + re/0.622)/(1 + re);

    # Compute speed of sound using adiabatic index, gas constant of air,
    # and virtual temperature in Kelvin.
    return math.sqrt(1.4 * 287.058 * v_T);
};

var thunder_listener = func {
    var thunderCalls = 0;

    var lightning_pos_x = getprop("/environment/lightning/lightning-pos-x");
    var lightning_pos_y = getprop("/environment/lightning/lightning-pos-y");
    var lightning_distance = math.sqrt(math.pow(lightning_pos_x, 2) + math.pow(lightning_pos_y, 2));

    # On the ground, thunder can be heard up to 16 km. Increase this value
    # a bit because the aircraft is usually in the air.
    if (lightning_distance > 20000)
        return;

    var t = getprop("/environment/temperature-degc");
    var re = getprop("/environment/relative-humidity") / 100;
    var delay_seconds = lightning_distance / speed_of_sound(t, re);

    # Maximum volume at 5000 meter
    var lightning_distance_norm = std.min(1.0, 1 / math.pow(lightning_distance / 5000.0, 2));

    settimer(func {
        var thunder1 = getprop("ja37/sound/thunder1");
        var thunder2 = getprop("ja37/sound/thunder2");
        var thunder3 = getprop("ja37/sound/thunder3");

        if (!thunder1) {
            thunderCalls = 1;
            setprop("ja37/sound/dist-thunder1", lightning_distance_norm * getprop("ja37/sound/environment-volume") * 1.5);
        }
        else if (!thunder2) {
            thunderCalls = 2;
            setprop("ja37/sound/dist-thunder2", lightning_distance_norm * getprop("ja37/sound/environment-volume") * 1.5);
        }
        else if (!thunder3) {
            thunderCalls = 3;
            setprop("ja37/sound/dist-thunder3", lightning_distance_norm * getprop("ja37/sound/environment-volume") * 1.5);
        }
        else
            return;

        # Play the sound (sound files are about 9 seconds)
        play_thunder("thunder" ~ thunderCalls, 9.0, 0);
    }, delay_seconds);
};

var play_thunder = func (name, timeout=0.1, delay=0) {
    var sound_prop = "/ja37/sound/" ~ name;

    settimer(func {
        # Play the sound
        setprop(sound_prop, TRUE);

        # Reset the property after timeout so that the sound can be
        # played again.
        settimer(func {
            setprop(sound_prop, FALSE);
        }, timeout);
    }, delay);
};
                
###############  Test which system the flightgear version support.  ###########

var test_support = func {
 
  var versionString = getprop("sim/version/flightgear");
  var version = split(".", versionString);
  var major = num(version[0]);
  var minor = num(version[1]);
  var detail = num(version[2]);
  if (major < 2) {
    notice("Saab 37 is only supported in Flightgear version 2.8 and upwards. Sorry.");
      setprop("ja37/supported/radar", FALSE);
      setprop("ja37/supported/canvas", FALSE);
      setprop("ja37/supported/options", FALSE);
      setprop("ja37/supported/old-custom-fails", 0);
      setprop("ja37/supported/popuptips", 0);
      setprop("ja37/supported/landing-light", FALSE);
      setprop("ja37/supported/crash-system", 0);
      setprop("ja37/supported/ubershader", FALSE);
      setprop("ja37/supported/lightning", FALSE);
      setprop("ja37/supported/fire", FALSE);
      setprop("ja37/supported/new-marker", FALSE);
      setprop("ja37/supported/picking", FALSE);
      setprop("ja37/supported/failEvents", FALSE);
  } elsif (major == 2) {
    setprop("ja37/supported/landing-light", FALSE);
    setprop("ja37/supported/lightning", FALSE);
    setprop("ja37/supported/fire", FALSE);
    setprop("ja37/supported/new-marker", FALSE);
    setprop("ja37/supported/picking", FALSE);
    setprop("ja37/supported/failEvents", FALSE);
    if(minor < 7) {
      notice("Saab 37 is only supported in Flightgear version 2.8 and upwards. Sorry.");
      setprop("ja37/supported/radar", FALSE);
      setprop("ja37/supported/canvas", FALSE);
      setprop("ja37/supported/options", FALSE);
      setprop("ja37/supported/old-custom-fails", 0);
      setprop("ja37/supported/popuptips", 0);
      setprop("ja37/supported/crash-system", 0);
      setprop("ja37/supported/ubershader", FALSE);
    } elsif(minor < 9) {
      notice("Saab 37 Canvas Radar and HUD is only supported in Flightgear version 2.10 and upwards. They have been disabled.");
      setprop("ja37/supported/radar", FALSE);
      setprop("ja37/supported/canvas", FALSE);
      setprop("ja37/supported/options", FALSE);
      setprop("ja37/supported/old-custom-fails", 0);
      setprop("ja37/hud/mode", 0);
      setprop("ja37/supported/popuptips", 0);
      setprop("ja37/supported/crash-system", 0);
      setprop("ja37/supported/ubershader", FALSE);
    } elsif(minor < 11) {
      setprop("ja37/supported/radar", TRUE);
      setprop("ja37/supported/canvas", TRUE);
      setprop("ja37/supported/options", FALSE);
      setprop("ja37/supported/old-custom-fails", 0);
      setprop("ja37/supported/popuptips", 0);
      setprop("ja37/supported/crash-system", 0);
      setprop("ja37/supported/ubershader", TRUE);
    } else {
      setprop("ja37/supported/radar", TRUE);
      setprop("ja37/supported/canvas", TRUE);
      setprop("ja37/supported/options", FALSE);
      setprop("ja37/supported/old-custom-fails", 0);
      setprop("ja37/supported/popuptips", 1);
      setprop("ja37/supported/crash-system", 0);
      setprop("ja37/supported/ubershader", TRUE);
    }
  } elsif (major == 3) {
    setprop("ja37/supported/options", TRUE);
    setprop("ja37/supported/radar", TRUE);
    setprop("ja37/supported/canvas", TRUE);
    setprop("ja37/supported/old-custom-fails", 2);
    setprop("ja37/supported/landing-light", TRUE);
    setprop("ja37/supported/popuptips", 2);
    setprop("ja37/supported/crash-system", 1);
    setprop("ja37/supported/ubershader", TRUE);
    setprop("ja37/supported/lightning", TRUE);
    setprop("ja37/supported/fire", FALSE);
    setprop("ja37/supported/new-marker", FALSE);
    setprop("ja37/supported/picking", FALSE);
    setprop("ja37/supported/failEvents", FALSE);
    if (minor == 0) {
      setprop("ja37/supported/old-custom-fails", 0);
      setprop("ja37/supported/landing-light", FALSE);
      setprop("ja37/supported/popuptips", 1);
      setprop("ja37/supported/crash-system", 0);
      setprop("ja37/supported/lightning", FALSE);
    } elsif (minor <= 2) {
      setprop("ja37/supported/old-custom-fails", 1);
      setprop("ja37/supported/landing-light", FALSE);
      setprop("ja37/supported/popuptips", 1);
      setprop("ja37/supported/lightning", FALSE);
    } elsif (minor <= 4) {
      setprop("ja37/supported/old-custom-fails", 1);
      setprop("ja37/supported/popuptips", 1);
      setprop("ja37/supported/lightning", FALSE);
      setprop("ja37/supported/fire", TRUE);
      setprop("ja37/supported/failEvents", TRUE);
    } elsif (minor <= 6) {
      setprop("ja37/supported/lightning", FALSE);
      setprop("ja37/supported/fire", TRUE);
      setprop("ja37/supported/failEvents", TRUE);
    }
  } elsif (major == 2016) {
    setprop("ja37/supported/options", TRUE);
    setprop("ja37/supported/radar", TRUE);
    setprop("ja37/supported/canvas", TRUE);
    setprop("ja37/supported/old-custom-fails", 2);
    setprop("ja37/supported/landing-light", TRUE);
    setprop("ja37/supported/popuptips", 2);
    setprop("ja37/supported/crash-system", 1);
    setprop("ja37/supported/ubershader", TRUE);
    setprop("ja37/supported/lightning", TRUE);
    setprop("ja37/supported/fire", TRUE);
    setprop("ja37/supported/new-marker", FALSE);
    setprop("ja37/supported/picking", FALSE);
    setprop("ja37/supported/failEvents", TRUE);
    if (minor >= 2) {
      setprop("ja37/supported/new-marker", TRUE);
    }
  } elsif (major == 2017) {
    setprop("ja37/supported/options", TRUE);
    setprop("ja37/supported/radar", TRUE);
    setprop("ja37/supported/canvas", TRUE);
    setprop("ja37/supported/old-custom-fails", 2);
    setprop("ja37/supported/landing-light", TRUE);
    setprop("ja37/supported/popuptips", 2);
    setprop("ja37/supported/crash-system", 1);
    setprop("ja37/supported/ubershader", TRUE);
    setprop("ja37/supported/lightning", TRUE);
    setprop("ja37/supported/fire", TRUE);
    setprop("ja37/supported/new-marker", FALSE);
    setprop("ja37/supported/picking", FALSE);
    setprop("ja37/supported/failEvents", TRUE);
    if (minor == 2 and detail > 0) {
      setprop("ja37/supported/picking", TRUE);
    }
    if (minor > 2) {
      setprop("ja37/supported/picking", TRUE);
    }
  } else {
    # future proof
    setprop("ja37/supported/options", TRUE);
    setprop("ja37/supported/radar", TRUE);
    setprop("ja37/supported/canvas", TRUE);
    setprop("ja37/supported/old-custom-fails", 2);
    setprop("ja37/supported/landing-light", TRUE);
    setprop("ja37/supported/popuptips", 2);
    setprop("ja37/supported/crash-system", 1);
    setprop("ja37/supported/ubershader", TRUE);
    setprop("ja37/supported/lightning", TRUE);
    setprop("ja37/supported/fire", TRUE);
    setprop("ja37/supported/new-marker", TRUE);
    setprop("ja37/supported/picking", TRUE);
    setprop("ja37/supported/failEvents", TRUE);
  }
  setprop("ja37/supported/initialized", TRUE);

  print();
  print("***************************************************************");
  print("**         Initializing "~getprop("sim/description")~" systems.           **");
  print("**           Version "~getprop("sim/aircraft-version")~" on Flightgear "~version[0]~"."~version[1]~"."~version[2]~"            **");
  print("***************************************************************");
  print();
}

############################# main init ###############


var main_init = func {
  setprop("sim/time/elapsed-at-init-sec", getprop("sim/time/elapsed-sec"));

  test_support();

#  aircraft.data.add("ja37/radar/enabled",
#                    "ja37/hud/units-metric",
#                    "ja37/hud/mode",
#                    "ja37/hud/bank-indicator",
#                    "ja37/autoReverseThrust",
#                    "ja37/hud/stroke-linewidth",
#                    "ai/submodels/submodel[2]/random",
#                    "ai/submodels/submodel[3]/random");
  #aircraft.data.save();
  aircraft.data.save(0.5);#every 30 seconds



  # define the locks since they otherwise start with some undefined value I cannot test on.
  setprop("/autopilot/locks/speed", "");
  setprop("/autopilot/locks/heading", "");
  setprop("/autopilot/locks/altitude", "");

  setprop("/consumables/fuel/tank[8]/jettisoned", FALSE);

  total_fuel = getprop("/consumables/fuel/tank[0]/capacity-gal_us")
                + getprop("/consumables/fuel/tank[1]/capacity-gal_us")
                + getprop("/consumables/fuel/tank[2]/capacity-gal_us")
                + getprop("/consumables/fuel/tank[3]/capacity-gal_us")
                + getprop("/consumables/fuel/tank[4]/capacity-gal_us")
                + getprop("/consumables/fuel/tank[5]/capacity-gal_us")
                + getprop("/consumables/fuel/tank[6]/capacity-gal_us")
                + getprop("/consumables/fuel/tank[7]/capacity-gal_us");

  # Load exterior at startup to avoid stale sim at first external view selection. ( taken from TU-154B )
  print("Loading exterior, wait...");
  # return to cabin to next cycle
  settimer( load_interior, 0 );
  setprop("/sim/current-view/view-number", 1);
  setprop("/sim/gui/tooltips-enabled", TRUE);
  
  # inst. light

  setprop("/instrumentation/instrumentation-light/r", 1.0);
  setprop("/instrumentation/instrumentation-light/g", 0.3);
  setprop("/instrumentation/instrumentation-light/b", 0.0);

  # setup property nodes for the loop
  foreach(var name; keys(input)) {
      input[name] = props.globals.getNode(input[name], 1);
  }

  screen.log.write("Welcome to "~getprop("sim/description")~", version "~getprop("sim/aircraft-version"), 1.0, 0.2, 0.2);

  # init cockpit temperature
  setprop("environment/aircraft-effects/temperature-inside-degC", getprop("environment/temperature-degc"));
  setprop("/environment/aircraft-effects/dewpoint-inside-degC", getprop("environment/dewpoint-degc"));

  # init oxygen bottle pressure
  setprop("ja37/systems/oxygen-bottle-pressure", 127);# 127 kp/cm2 as per manual

  # start minor loops
  speed_loop();
  slow_loop();
  battery_listener();
  code_ct();
  not();

  # start beacon loop
  #beaconTimer.start();
  beaconLoop();

  # asymmetric vortex detachment
  asymVortex();

  # Setup lightning listener
  if (getprop("/ja37/supported/lightning") == TRUE) {
    setlistener("/environment/lightning/lightning-pos-y", thunder_listener);
  }

  if(getprop("dev") != TRUE) {
    setprop("controls/engines/engine/reverser-cmd", rand()>0.5?TRUE:FALSE);
    setprop("controls/gear/brake-parking", rand()>0.5?TRUE:FALSE);
    setprop("controls/electric/reserve", rand()>0.5?TRUE:FALSE);
    setprop("controls/electric/lights-ext-flash", rand()>0.5?TRUE:FALSE);
    setprop("controls/electric/lights-ext-beacon", rand()>0.5?TRUE:FALSE);
    setprop("controls/electric/lights-ext-nav", rand()>0.5?TRUE:FALSE);
    setprop("controls/electric/lights-land-switch", rand()>0.5?TRUE:FALSE);
    setprop("controls/fuel/auto", rand()>0.5?TRUE:FALSE);
  }

  # start weapon systems
  settimer(func { armament.main_weapons() }, 2);

  # start the main loop
	settimer(func { update_loop() }, 0.1);

  changeGuiLoad();
}

# re init
var re_init = func {
  print("Re-initializing Saab 37 Viggen systems");
  
  setprop("sim/time/elapsed-at-init-sec", getprop("sim/time/elapsed-sec"));

  # init oxygen bottle pressure
  setprop("ja37/systems/oxygen-bottle-pressure", 127);# 127 kp/cm2 as per manual

  # asymmetric vortex detachment
  asymVortex();
  repair(FALSE);
  auto.stopAP();
  setprop("/controls/gear/gear-down", 1);
  setprop("/controls/gear/brake-parking", 1);

  #test_support();
}

var asymVortex = func () {
  if(rand() > 0.5) {
    setprop("fdm/jsbsim/aero/function/vortex", 1);
  } else {
    setprop("fdm/jsbsim/aero/function/vortex", -1);
  }
}

var load_interior = func {
    setprop("/sim/current-view/view-number", 0);
    settimer( load_interior_final, 0.5 );
}

var load_interior_final = func {
    setprop("sim/current-view/field-of-view", 90);
    print("..Done!");
    settimer( load_interior_final2, 1.5 );
}

var load_interior_final2 = func {
    setprop("ja37/avionics/welcome", TRUE);
}

var main_init_listener = setlistener("sim/signals/fdm-initialized", func {
	main_init();
	removelistener(main_init_listener);
 }, 0, 0);

var re_init_listener = setlistener("/sim/signals/reinit", func {
  re_init();
 }, 0, 0);


############ strobe #####################

var strobe_switch = props.globals.getNode("controls/lighting/ext-lighting-panel/anti-collision", 1);
setprop("controls/lighting/ext-lighting-panel/anti-collision", 1);
aircraft.light.new("sim/model/lighting/strobe", [0.03, 1.5], strobe_switch);#was 1.9+rand()/5

############ beacons #####################

setprop("controls/switches/beacon", TRUE);

var beacon_switch = props.globals.getNode("sim/model/lighting/beacon/state-rotary", 2);

var beaconLoop = func () {
  if(input.replay.getValue() != TRUE) {
    var time = input.elapsed.getValue()*1.5;
    var timeInt = int(time);
    var value = nil;
    if(2 * int(timeInt / 2) == timeInt) {
      #ascend
      value = (2 * (time - timeInt))-1;
    } else {
      #descent
      value = (2*(1 - (time - timeInt)))-1;
    }
    if (value < 0) value = 0;
    beacon_switch.setDoubleValue(value);
  }
  settimer(beaconLoop, 0.05);
};
#var beaconTimer = maketimer(0, beaconLoop); only usable in 2.11+


#var beacon = aircraft.light.new( "sim/model/lighting/beacon", [0, 1], beacon_switch );

############ blinkers ####################

#var blinker = nil;
#blinker = aircraft.light.new("ja37/blink/five-Hz", [0.2, 0.2]);
#blinker.switch(1);
#blinker = aircraft.light.new("ja37/blink/ten-Hz", [0.1, 0.1]);
#blinker.switch(1);
#blinker = aircraft.light.new("ja37/blink/third-Hz", [2, 1]);
#blinker.switch(1);

############# workaround for removing default HUD   ##############

#setlistener("/sim/current-view/view-number", func(n) {
#        setprop("/sim/hud/visibility[1]", !n.getValue());
#}, 1, 0);

###################### autostart ########################

var autostarting = FALSE;
var start_count = 0;

var autostarttimer = func {
  if (autostarting == FALSE) {
    autostarting = TRUE;
    if (getprop("/engines/engine[0]/running") > 0) {
     notice("Stopping engine. Turning off electrical system.");
     click();
     stopAutostart();
    } else {
      #print("autostarting");
      setprop("fdm/jsbsim/systems/electrical/external/enable-cmd", TRUE);
      notice("Autostarting..");
      setprop("controls/gear/brake-parking", TRUE);
      setprop("fdm/jsbsim/fcs/canopy/engage", FALSE);
      setprop("controls/ventilation/airconditioning-enabled", TRUE);
  	  settimer(startSupply, 1.5, 1);
    }
  }
}

var stopAutostart = func {
  setprop("/controls/electric/main", FALSE);
  setprop("/controls/electric/battery", FALSE);
  settimer(stopFinal, 5, 1);#allow time for ram air and flaps to retract
}

stopFinal = func {
  setprop("fdm/jsbsim/propulsion/engine/cutoff-commanded", TRUE);
  setprop("/controls/engines/engine[0]/starter-cmd", FALSE);
  setprop("/controls/engines/engine[0]/starter-cmd-hold", FALSE);
  setprop("/controls/electric/engine[0]/generator", FALSE);
  setprop("fdm/jsbsim/systems/electrical/external/switch", FALSE);
  setprop("fdm/jsbsim/systems/electrical/external/enable-cmd", FALSE);
  autostarting = FALSE;
}

var startSupply = func {
  setprop("/controls/engines/engine[0]/starter-cmd-hold", TRUE);
  setprop("/controls/engines/engine[0]/starter-cmd", TRUE);
  if (getprop("fdm/jsbsim/systems/electrical/external/available") == TRUE) {
    # using ext. power
    click();
    setprop("fdm/jsbsim/systems/electrical/external/switch", TRUE);
    setprop("/controls/electric/main", TRUE);
    setprop("controls/electric/reserve", FALSE);
    notice("Enabling power using external supply.");
    settimer(endSupply, 1.5, 1);
  } elsif (getprop("fdm/jsbsim/systems/electrical/battery-producing-dc") > 23) {
    # using battery
    click();
    setprop("/controls/electric/battery", TRUE);
    setprop("/controls/electric/main", TRUE);
    setprop("controls/electric/reserve", FALSE);
    notice("Enabling power using battery.");
    settimer(endSupply, 1.5, 1);
  } else {
    # using reserve power, hope for enough speed for hydraulics
    setprop("controls/electric/reserve", TRUE);
    setprop("/controls/electric/main", TRUE);
    setprop("/controls/gear/gear-down", FALSE);
    notice("Enabling power using ram air turbine..gears will retract.");
    settimer(endSupply, 10, 1);
  }
}

var endSupply = func {
  setprop("ja37/radar/enabled", TRUE);
  setprop("controls/engines/engine/reverser-cmd", FALSE);
  setprop("controls/fuel/auto", TRUE);
  setprop("controls/altimeter-radar", TRUE);
  if (getprop("systems/electrical/outputs/dc-voltage") > 23) {
    # have power to start
    settimer(autostart, 1.5, 1);
  } else {
    # not enough power to start
    click();
    stopAutostart();
    notice("Not enough power to autostart, aborting.");
  }
}

#Simulating autostart function
var autostart = func {
  setprop("controls/electric/lights-ext-flash", TRUE);
  setprop("controls/electric/lights-ext-beacon", TRUE);
  setprop("controls/electric/lights-ext-nav", TRUE);
  setprop("controls/electric/lights-land-switch", TRUE);
  setprop("/controls/engines/engine[0]/starter-cmd-hold", FALSE);
  setprop("/controls/electric/engine[0]/generator", FALSE);
  notice("Starting engine..");
  click();
  setprop("fdm/jsbsim/propulsion/engine/cutoff-commanded", TRUE);
  #setprop("/controls/engines/engine[0]/starter-cmd", TRUE);
  start_count = 0;
  settimer(waiting_n1, 0.5, 1);
}

# Opens fuel valve in autostart
var waiting_n1 = func {
  start_count += 1* getprop("sim/speed-up");
  #print(start_count);
  if (start_count > 45) {
    if(bingoFuel == TRUE) {
      notice("Engine start failed. Check fuel.");
    } elsif (getprop("systems/electrical/outputs/dc-voltage") < 23) {
      notice("Engine start failed. Check battery.");
    } else {
      notice("Autostart failed. If engine has not reported failure, report bug to aircraft developer.");
    }
    print("Autostart failed. n1="~getprop("/engines/engine[0]/n1")~" cutoff="~getprop("fdm/jsbsim/propulsion/engine/cutoff-commanded")~" starter="~getprop("/controls/engines/engine[0]/starter")~" generator="~getprop("/controls/electric/engine[0]/generator")~" battery="~getprop("/controls/electric/main")~" fuel="~bingoFuel);
    stopAutostart();
  } elsif (getprop("/engines/engine[0]/n1") > 4.9) {
    if (getprop("/engines/engine[0]/n1") < 20) {
      if (getprop("fdm/jsbsim/propulsion/engine/cutoff-commanded") == TRUE) {
        click();
        setprop("fdm/jsbsim/propulsion/engine/cutoff-commanded", FALSE);
        if (getprop("fdm/jsbsim/propulsion/engine/cutoff-commanded") == FALSE) {
          notice("Engine igniting.");
          settimer(waiting_n1, 0.5, 1);
        } else {
          print("Autostart failed 2. n1="~getprop("/engines/engine[0]/n1")~" cutoff="~getprop("fdm/jsbsim/propulsion/engine/cutoff-commanded")~" starter="~getprop("/controls/engines/engine[0]/starter")~" generator="~getprop("/controls/electric/engine[0]/generator")~" battery="~getprop("/controls/electric/main")~" fuel="~bingoFuel);
          stopAutostart();
          notice("Engine not igniting. Aborting engine start.");
        }
      } else {
        settimer(waiting_n1, 0.5, 1);
      }
    }  elsif (getprop("/engines/engine[0]/n1") > 10 and getprop("fdm/jsbsim/propulsion/engine/cutoff-commanded") == FALSE) {
      #print("Autostart success. n1="~getprop("/engines/engine[0]/n1")~" cutoff="~getprop("fdm/jsbsim/propulsion/engine/cutoff-commanded")~" starter="~getprop("/controls/engines/engine[0]/starter")~" generator="~getprop("/controls/electric/engine[0]/generator")~" battery="~getprop("/controls/electric/main"));
      click();
      setprop("controls/electric/engine[0]/generator", TRUE);
      notice("Generator on.");
      setprop("controls/oxygen", TRUE);
      settimer(final_engine, 0.5, 1);
    } else {
      settimer(waiting_n1, 0.5, 1);
    }
  } else {
    settimer(waiting_n1, 0.5, 1);
  }
}

var final_engine = func () {
  start_count += 1* getprop("sim/speed-up");
  if (start_count > 70) {
    if(bingoFuel == TRUE) {
      notice("Engine start failed. Check fuel.");
    } elsif (getprop("systems/electrical/outputs/dc-voltage") < 23) {
      notice("Engine start failed. Check battery.");
    } else {
      notice("Autostart failed. If engine has not reported failure, report bug to aircraft developer.");
    }    
    print("Autostart failed 3. n1="~getprop("/engines/engine[0]/n1")~" cutoff="~getprop("fdm/jsbsim/propulsion/engine/cutoff-commanded")~" starter="~getprop("/controls/engines/engine[0]/starter")~" generator="~getprop("/controls/electric/engine[0]/generator")~" battery="~getprop("/controls/electric/main")~" fuel="~bingoFuel);
    stopAutostart();  
  } elsif (getprop("/engines/engine[0]/running") > FALSE) {
    notice("Engine ready.");
    setprop("fdm/jsbsim/systems/electrical/external/switch", FALSE);
    setprop("fdm/jsbsim/systems/electrical/external/enable-cmd", FALSE);
    setprop("/controls/electric/battery", TRUE);
    autostarting = FALSE;    
  } else {
    settimer(final_engine, 0.5, 1);
  }
}

var clicking = FALSE;
var click = func {
    if(clicking == FALSE) {
      clicking = TRUE;
      setprop("ja37/sound/click-on", TRUE);
      settimer(clickOff, 0.15, 1);
    }
}

var clickOff = func {
    setprop("ja37/sound/click-on", FALSE);
    clicking = FALSE;
}

var noop = func {
  #does nothing, but important
}

var toggleYawDamper = func {
  ja37.click();
  var enabled = getprop("fdm/jsbsim/fcs/yaw-damper/enable");
  setprop("fdm/jsbsim/fcs/yaw-damper/enable", !enabled);
  if(enabled == FALSE) {
    notice("Yaw damper: ON");
  } else {
    notice("Yaw damper: OFF");
  }
}

var togglePitchDamper = func {
  ja37.click();
  var enabled = getprop("fdm/jsbsim/fcs/pitch-damper/enable");
  setprop("fdm/jsbsim/fcs/pitch-damper/enable", !enabled);
  if(enabled == FALSE) {
    notice("Pitch damper: ON");
  } else {
    notice("Pitch damper: OFF");
  }
}

var toggleRollDamper = func {
  ja37.click();
  var enabled = getprop("fdm/jsbsim/fcs/roll-damper/enable");
  setprop("fdm/jsbsim/fcs/roll-damper/enable", !enabled);
  if(enabled == FALSE) {
    notice("Roll damper: ON");
  } else {
    notice("Roll damper: OFF");
  }
}

var toggleHook = func {
  ja37.click();
  var enabled = getprop("fdm/jsbsim/systems/hook/tailhook-cmd-norm");
  setprop("fdm/jsbsim/systems/hook/tailhook-cmd-norm", !enabled);
  if(enabled == FALSE) {
    notice("Arrester hook: Extended");
  } else {
    notice("Arrester hook: Retracted");
  }
}

var toggleNosewheelSteer = func {
  ja37.click();
  var enabled = getprop("fdm/jsbsim/gear/unit[0]/nose-wheel-steering/enable");
  setprop("fdm/jsbsim/gear/unit[0]/nose-wheel-steering/enable", !enabled);
  if(enabled == FALSE) {
    notice("Nose Wheel Steering: ON", 1.5);
  } else {
    notice("Nose Wheel Steering: OFF", 1.5);
  }
}

var toggleTracks = func {
  ja37.click();
  var enabled = getprop("ja37/hud/tracks-enabled");
  setprop("ja37/hud/tracks-enabled", !enabled);
  if(enabled == FALSE) {
    notice("Radar ON");
  } else {
    notice("Radar OFF");
  }
}

var applyParkingBrake = func(v) {
    controls.applyParkingBrake(v);
    if(!v) return;
    ja37.click();
    if (getprop("/controls/gear/brake-parking") == TRUE) {
      notice("Parking brakes: ON");
    } else {
      notice("Parking brakes: OFF");
    }
}

var cycleSmoke = func() {
    ja37.click();
    if (getprop("/ja37/effect/smoke-cmd") == 1) {
      setprop("/ja37/effect/smoke-cmd", 2);
      notice("Smoke: Yellow");
    } elsif (getprop("/ja37/effect/smoke-cmd") == 2) {
      setprop("/ja37/effect/smoke-cmd", 3);
      notice("Smoke: Blue");
    } else {
      setprop("/ja37/effect/smoke-cmd", 1);#1 for backward compatibility to be off per default
      notice("Smoke: OFF");
    }
}

var popupTip = func(label, y = 25, delay = nil) {
    #var node = props.Node.new({ "label": label, "x": getprop('/sim/startup/xsize')/2, "y": -y+getprop('/sim/startup/ysize'), "tooltip-id": "msg", "reason": "click"});
    #fgcommand("set-tooltip", node);
    #fgcommand("tooltip-timeout", props.Node.new({}));
    #var tooltip = canvas.Tooltip.new([300, 100]);
    #tooltip.createCanvas();
    if(getprop("ja37/supported/popuptips") == 2) {
      gui.popupTip(label, delay, nil, {"y": y});
    } elsif(getprop("ja37/supported/popuptips") == 0) {
      gui.popupTip(label, delay);
    } else {
      call(func _popupTip(label, y, delay), nil, var err = []);
      if(size(err) != 0) {
        # if the tooltip system has changed and my use produce error, revert to basic popup tip.
        print(err[0]);
        gui.popupTip(label, delay);
      }
    }
}

var notice = func (str) {
  screen.log.write(str, 0.0, 0.0, 1.0);
}

var _popupTip = func(label, y, delay) {
    canvas.tooltip.setTooltipId("msg");
    canvas.tooltip.setWidthText(label);
    var x = getprop('/sim/startup/xsize')/2 - canvas.tooltip._measureBB[2]/2; # hack 1
    canvas.tooltip.setLabel(label);
    canvas.tooltip.setPosition(x, y);
    canvas.tooltip.setProperty(nil);
    canvas.tooltip.setMapping(nil);
    canvas.tooltip.show();
    canvas.tooltip._hiding = 1;                                               # hack 2
    canvas.tooltip._hideTimer.restart(delay==nil?4:delay);
    #canvas.tooltip.showMessage(delay);
}

var repair = func (c = 1) {
  var ver = getprop("ja37/supported/crash-system");
  if (ver == 0) {
    crash0.repair();
  } else {
    crash1.repair();
    failureSys.armAllTriggers();
  }
  setprop("environment/damage", FALSE);
  if (c == TRUE) {
    ct("rp");
  }
}
setprop("sim/mul"~"tiplay/gen"~"eric/strin"~"g[14]", "o"~""~"7");
var refuelTest = func () {
  setprop("consumables/fuel/tank[0]/level-norm", 0.5);
  setprop("consumables/fuel/tank[1]/level-norm", 0.5);
  setprop("consumables/fuel/tank[2]/level-norm", 0.5);
  setprop("consumables/fuel/tank[3]/level-norm", 0.5);
  setprop("consumables/fuel/tank[4]/level-norm", 0.5);
  setprop("consumables/fuel/tank[5]/level-norm", 0.5);
  setprop("consumables/fuel/tank[6]/level-norm", 0.5);
  setprop("consumables/fuel/tank[7]/level-norm", 0.5);
  setprop("consumables/fuel/tank[8]/level-norm", 0.0);

  screen.log.write("Fuel configured for flight testing.", 1.0, 0.0, 0.0);
}

var refuelNorm = func () {
  setprop("consumables/fuel/tank[0]/level-norm", 1.0);
  setprop("consumables/fuel/tank[1]/level-norm", 1.0);
  setprop("consumables/fuel/tank[2]/level-norm", 1.0);
  setprop("consumables/fuel/tank[3]/level-norm", 1.0);
  setprop("consumables/fuel/tank[4]/level-norm", 1.0);
  setprop("consumables/fuel/tank[5]/level-norm", 1.0);
  setprop("consumables/fuel/tank[6]/level-norm", 1.0);
  setprop("consumables/fuel/tank[7]/level-norm", 1.0);
  setprop("consumables/fuel/tank[8]/level-norm", 0.0);

  screen.log.write("Fuel configured for standard flight.", 0.0, 1.0, 0.0);
}

var refuelRange = func () {
  setprop("consumables/fuel/tank[0]/level-norm", 1.0);
  setprop("consumables/fuel/tank[1]/level-norm", 1.0);
  setprop("consumables/fuel/tank[2]/level-norm", 1.0);
  setprop("consumables/fuel/tank[3]/level-norm", 1.0);
  setprop("consumables/fuel/tank[4]/level-norm", 1.0);
  setprop("consumables/fuel/tank[5]/level-norm", 1.0);
  setprop("consumables/fuel/tank[6]/level-norm", 1.0);
  setprop("consumables/fuel/tank[7]/level-norm", 1.0);

  # Mount drop tank and fill it up.
  setprop("payload/weight[6]/selected", "Drop tank");
  input.tank8Selected.setBoolValue(TRUE);
  input.tank8Jettison.setBoolValue(FALSE);
  setprop("consumables/fuel/tank[8]/level-norm", 1.0);

  screen.log.write("Fuel configured for long range flight.", 0.0, 1.0, 0.0);
}

var ct = func (type) {
  if (type == "c-u") {
    setprop("sim/ct/c-u", 1);
  }
  if (type == "rl" and input.wow0.getValue() != 1) {
    setprop("sim/ct/rl", 1);
  }
  if (type == "rp" and input.wow0.getValue() != 1) {
    setprop("sim/ct/rp", 1);
  }
  if (type == "a") {
    setprop("sim/ct/a", 1);
  }
  if (type == "lst") {
    setprop("sim/ct/list", 1);
  }
  if (type == "ifa" and input.wow0.getValue() != 1) {
    setprop("sim/ct/ifa", 1);
  }
  if (type == "sf" and input.wow0.getValue() != 1) {
    setprop("sim/ct/sf", 1);
  }
}

var lf = 0;
var ll = 0;

var code_ct = func () {
  var cu = getprop("sim/ct/c-u");
  if (cu == nil or cu != 1) {
    cu = 0;
  }
  var a = getprop("sim/ct/a");
  if (a == nil or a != 1) {
    a = 0;
  }
  var ff = getprop("sim/freeze/fuel");
  if (ff == nil) {
    ff = 0;
  } elsif (ff == 1) {
    setprop("sim/ct/ff", 1);
  }
  ff = getprop("sim/ct/ff");
  if (ff == nil or ff != 1) {
    ff = 0;
  }
  var cl = getprop("payload/weight[0]/weight-lb")+getprop("payload/weight[1]/weight-lb")+getprop("payload/weight[2]/weight-lb")+getprop("payload/weight[3]/weight-lb")+getprop("payload/weight[4]/weight-lb")+getprop("payload/weight[5]/weight-lb");
  if (cl > (ll*1.05) and input.wow0.getValue() != 1) {
    setprop("sim/ct/rl", 1);
  }
  ll = cl;
  var rl = getprop("sim/ct/rl");
  if (rl == nil or rl != 1) {
    rl = 0;
  }
  var rp = getprop("sim/ct/rp");
  if (rp == nil or rp != 1) {
    rp = 0;
  }
  var cf = input.fuelRatio.getValue();
  if (cf != nil and cf > (lf*1.1) and input.wow0.getValue() != 1) {
    setprop("sim/ct/rf", 1);
  }
  var rf = getprop("sim/ct/rf");
  if (rf == nil or rf != 1) {
    rf = 0;
  }
  lf = cf == nil?0:cf;
  var dm = !getprop("payload/armament/damage");
  if (dm == nil or dm != 1) {
    dm = 0;
  }
  var tm = getprop("ja37/radar/look-through-terrain");
  if (getprop("ja37/supported/picking") == 1 or tm == nil or tm != 1) {
    tm = 0;
  }
  var rd = !getprop("ja37/radar/doppler-enabled");
  if (rd == nil or rd != 1) {
    rd = 0;
  }  
  var ml = getprop("sim/ct/list");
  if (ml == nil or ml != 1) {
    ml = 0;
  }
  var sf = getprop("sim/ct/sf");
  if (sf == nil or sf != 1) {
    sf = 0;
  }
  var ifa = getprop("sim/ct/ifa");
  if (ifa == nil or ifa != 1) {
    ifa = 0;
  }
  var final = "ct"~cu~ff~rl~rf~rp~a~dm~tm~rd~ml~sf~ifa;
  setprop("sim/multiplay/generic/string[15]", final);
  settimer(code_ct, 2);
}

var not = func {
  if (getprop("payload/armament/msg") == TRUE and input.wow0.getValue() != TRUE) {
    var ct = getprop("sim/multiplay/generic/string[15]") ;
    var msg = "I might be chea"~"ting..";
    if (ct != nil) {
      msg = "I might be chea"~"ting.."~ct;
      var spl = split("ct", ct);
      if (size(spl) > 1) {
        var bits = spl[1];
        msg = "I ";
        if (bits == "000000000000") {
          settimer(not, 60);
          return;
        }
        if (substr(bits,0,1) == "1") {
          msg = msg~"Used CT"~"RL-U..";
        }
        if (substr(bits,1,1) == "1") {
          msg = msg~"Use fuelf"~"reeze..";
        }
        if (substr(bits,2,1) == "1") {
          msg = msg~"Relo"~"aded in air..";
        }
        if (substr(bits,3,1) == "1") {
          msg = msg~"Refue"~"led in air..";
        }
        if (substr(bits,4,1) == "1") {
          msg = msg~"Repa"~"ired not on ground..";
        }
        if (substr(bits,5,1) == "1") {
          msg = msg~"Used time"~"warp..";
        }
        if (substr(bits,6,1) == "1") {
          msg = msg~"Have dam"~"age off..";
        }
        if (substr(bits,7,1) == "1") {
          msg = msg~"Have Ter"~"rain mask. off..";
        }
        if (substr(bits,8,1) == "1") {
          msg = msg~"Have Dop"~"pler off..";
        }
        if (substr(bits,9,1) == "1") {
          msg = msg~"Had mp-l"~"ist on..";
        }
        if (substr(bits,10,1) == "1") {
          msg = msg~"Had s-fai"~"lures open..";
        }
        if (substr(bits,11,1) == "1") {
          msg = msg~"Had i-fa"~"ilures open..";
        }
      }
    }
    setprop("/sim/multiplay/chat", msg);
  }
  settimer(not, 60);
}

var changeGuiLoad = func()
{
    var searchname1 = "mp-list";
    var searchname2 = "instrument-failures";
    var searchname3 = "system-failures";
    var state = 0;
    
    foreach(var menu ; props.globals.getNode("/sim/menubar/default").getChildren("menu")) {
        foreach(var item ; menu.getChildren("item")) {
            foreach(var name ; item.getChildren("name")) {
                if(name.getValue() == searchname1) {
                    #var e = item.getNode("enabled").getValue();
                    #var path = item.getPath();
                    #item.remove();
                    #item = props.globals.getNode(path,1);
                    #item.getNode("enabled",1).setBoolValue(FALSE);
                    #item.getNode("binding").remove();
                    #item.getNode("name",1).setValue(searchname1);
                    item.getNode("binding/command").setValue("nasal");
                    item.getNode("binding/script").setValue("ja37.loadMPList()");
                    #item.getNode("enabled",1).setBoolValue(TRUE);
                }
                if(name.getValue() == searchname2) {
                    item.getNode("binding/command").setValue("nasal");
                    item.getNode("binding/dialog-name").remove();
                    item.getNode("binding/script",1).setValue("ja37.loadIFail()");
                }
                if(name.getValue() == searchname3) {
                    item.getNode("binding/command").setValue("nasal");
                    item.getNode("binding/dialog-name").remove();
                    item.getNode("binding/script",1).setValue("ja37.loadSysFail()");
                }
            }
        }
    }
    fgcommand("reinit", props.Node.new({"subsystem":"gui"}));
}

var loadMPList = func () {
  ct("lst");multiplayer.dialog.show();
}

var loadSysFail = func () {
  ct("sf");fgcommand("dialog-show", props.Node.new({"dialog-name":"system-failures"}));
}

var loadIFail = func () {
  ct("ifa");fgcommand("dialog-show", props.Node.new({"dialog-name":"instrument-failures"}));
}

var resetView = func () {
  var hd = getprop("sim/current-view/heading-offset-deg");
  var hd_t = getprop("sim/current-view/config/heading-offset-deg");
  if (hd > 180) {
    hd_t = hd_t + 360;
  }
  interpolate("sim/current-view/field-of-view", getprop("sim/current-view/config/default-field-of-view-deg"), 0.66);
  interpolate("sim/current-view/heading-offset-deg", hd_t,0.66);
  interpolate("sim/current-view/pitch-offset-deg", getprop("sim/current-view/config/pitch-offset-deg"),0.66);
  interpolate("sim/current-view/roll-offset-deg", getprop("sim/current-view/config/roll-offset-deg"),0.66);
  interpolate("sim/current-view/x-offset-m", 0, 1);
}

var HDDView = func () {
  if (getprop("sim/current-view/view-number") == 0) {
    var hd = getprop("sim/current-view/heading-offset-deg");
    var hd_t = 340;
    if (hd < 180) {
      hd_t = hd_t - 360;
    }
    interpolate("sim/current-view/field-of-view", 60, 0.66);
    interpolate("sim/current-view/heading-offset-deg", hd_t,0.66);
    interpolate("sim/current-view/pitch-offset-deg", -46,0.66);
    interpolate("sim/current-view/roll-offset-deg", getprop("sim/current-view/config/roll-offset-deg"),0.66);
    interpolate("sim/current-view/x-offset-m", 0, 1); 
  }
}

var HUDView = func () {
  if (getprop("sim/current-view/view-number") == 0) {
    var hd = getprop("sim/current-view/heading-offset-deg");
    var hd_t = getprop("sim/current-view/config/heading-offset-deg");
    if (hd > 180) {
      hd_t = hd_t + 360;
    }
    interpolate("sim/current-view/field-of-view", 48, 0.66);
    interpolate("sim/current-view/heading-offset-deg", hd_t,0.66);
    interpolate("sim/current-view/pitch-offset-deg", -3,0.66);
    interpolate("sim/current-view/roll-offset-deg", getprop("sim/current-view/config/roll-offset-deg"),0.66);
    interpolate("sim/current-view/x-offset-m", 0, 1); 
  }
}

dynamic_view.register(func {
              me.default_plane();      # uncomment one of these if you want
#           # me.default_helicopter(); # to base your code on the defaults
#
#                                      # positive values rotate (deg) or move (m)
#           me.heading_offset = ...    #     left
#           me.pitch_offset = ...      #     up
#           me.roll_offset = ...       #     right
#           me.x_offset = ...          #     right     (transversal axis)
#           me.y_offset = ...          #     up        (vertical axis)
#           me.z_offset = ...          #     back/aft  (longitudinal axis)
#           me.fov_offset = ...        #     zoom out  (field of view)
   });