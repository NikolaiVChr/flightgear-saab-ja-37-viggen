# $Id$
var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }
var encode3bits = func(first, second, third) {
  var integer = first;
  integer = integer + 2 * second;
  integer = integer + 4 * third;
  return integer;
}

var LOOP_SLOW_RATE     = 1.50;

var FALSE = 0;
var TRUE = 1;

var bingoFuel = FALSE;

var mainOn = FALSE;
var mainTimer = -1;

var TILSprev = FALSE;
var acPrev = 0;
var acTimer = 0;

var MISSILE_STANDBY = -1;
var MISSILE_SEARCH = 0;
var MISSILE_LOCK = 1;
var MISSILE_FLYING = 2;
############### Main loop ###############

input = {
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
  reload_allowed:   "/ja37/reload-allowed",
  combat:           "/ja37/hud/current-mode",
  cutoff:           "fdm/jsbsim/propulsion/engine/cutoff-commanded",
  damage:           "environment/damage",
  damageSmoke:      "environment/damage-smoke",
  dens:             "fdm/jsbsim/atmosphere/density-altitude",
  downFps:          "/velocities/down-relground-fps",
  elapsed:          "sim/time/elapsed-sec",
  elapsedInit:      "sim/time/elapsed-at-init-sec",
  elecMain:         "controls/electric/main",
  engineRunning:    "engines/engine/running",
  envVol:           "ja37/sound/environment-volume",
  fdmAug:           "fdm/jsbsim/propulsion/engine/augmentation",
  flame:            "engines/engine/flame",
  flapPosCmd:       "/fdm/jsbsim/fcs/flaps/pos-cmd",
  fuelRatio:        "/instrumentation/fuel/ratio",
  fuelTemp:         "ja37/supported/fuel-temp",
  fullInit:         "sim/time/full-init",
  g3d:              "/velocities/groundspeed-3D-kt",
  gearSteerNorm:    "/gear/gear[0]/steering-norm",
  gearCmdNorm:      "/fdm/jsbsim/gear/gear-cmd-norm",
  gearsPos:         "gear/gear/position-norm",
  generatorOn:      "fdm/jsbsim/systems/electrical/generator-running-norm",
  gravity:          "fdm/jsbsim/accelerations/gravity-ft_sec2",
  headingMagn:      "/orientation/heading-magnetic-deg",
  hz05:             "ja37/blink/five-Hz/state",
  hz10:             "ja37/blink/four-Hz/state",
  hzThird:          "ja37/blink/third-Hz/state",
  impact:           "/ai/models/model-impact",
  indAA:            "ja37/avionics/auto-altitude-on",
  indAH:            "ja37/avionics/auto-attitude-on",
  indAlt:           "/instrumentation/altitude-indicator",
  indAltFt:         "instrumentation/altimeter/indicated-altitude-ft",
  indAltMeter:      "instrumentation/altimeter/indicated-altitude-meter",
  indAT:            "fdm/jsbsim/autoflight/athr",
  indAtt:           "/instrumentation/attitude-indicator",
  indJoy:           "/instrumentation/joystick-indicator",
  indRev:           "/instrumentation/reverse-indicator",
  lampCanopy:       "ja37/avionics/canopyAndSeat",
  lampData:         "ja37/avionics/primaryData",
  lampIgnition:     "ja37/avionics/ignitionSys",
  insCmd:           "ja37/avionics/ins-cmd",
  lampOxygen:       "ja37/avionics/oxygen",
  lampStart:        "ja37/avionics/startSys",
  lampStick:        "ja37/avionics/joystick",
  lampXTank:        "ja37/avionics/xtank",
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
  MPbool4:          "sim/multiplay/generic/bool[4]",
  n1:               "/engines/engine/n1",
  n2:               "/engines/engine/n2",
  nearby:           "damage/sounds/nearby-explode-on",
  explode:          "damage/sounds/explode-on",
  pilotG:           "ja37/accelerations/pilot-G",
  pneumatic:        "fdm/jsbsim/systems/fuel/pneumatics/serviceable",
  rad_alt:          "instrumentation/radar-altimeter/radar-altitude-ft",
  rad_alt_ready:    "instrumentation/radar-altimeter/ready",
  rainNorm:         "environment/rain-norm",
  rainVol:          "ja37/sound/rain-volume",
  replay:           "sim/replay/replay-state",
  reversed:         "/engines/engine/is-reversed",
  rmActive:         "/autopilot/route-manager/active",
  RMWaypointBearing:"autopilot/route-manager/wp/bearing-deg",
  landingMode:      "ja37/hud/landing-mode",
  approachMode:     "ja37/avionics/approach",
  roll:             "/instrumentation/attitude-indicator/indicated-roll-deg",
  sceneRed:         "/rendering/scene/diffuse/red",
  servFire:         "engines/engine[0]/fire/serviceable",
  serviceElec:      "systems/electrical/serviceable",
  speedKt:          "/instrumentation/airspeed-indicator/indicated-speed-kt",
  speedTrueKt:      "fdm/jsbsim/velocities/vtrue-kts",
  speedMach:        "/instrumentation/airspeed-indicator/indicated-mach",
  speedWarn:        "ja37/sound/speed-on",
  starter:          "controls/engines/engine[0]/starter-cmd",
  subAmmo2:         "ai/submodels/submodel[2]/count", 
  subAmmo3:         "ai/submodels/submodel[3]/count", 
  sunAngle:         "sim/time/sun-angle-rad",
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
  taxiLight:        "ja37/effect/taxi-light",
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
  waypointType:     "instrumentation/waypoint-indicator/type",
  waypointNumber:   "instrumentation/waypoint-indicator/number",
  zAccPilot:        "accelerations/pilot/z-accel-fps_sec",
  terrainOverr:     "instrumentation/terrain-override",
  fuseGVV:          "ja37/fuses/gvv",
  inputFlight:      "ja37/systems/input-controls-flight",
  terrainWarn:      "instrumentation/terrain-warning",
  parachuteDeploy:  "payload/armament/es/flags/deploy-id-10",
  parachuteForce:    "ja37/force",
  toneTerr: "ja37/sound/tones/terrain-on",
  toneOut: "ja37/sound/tones/flare-release-out",
  toneCM: "ja37/sound/tones/flare-release",
  toneGVV: "ja37/sound/tones/gvv-main",
  toneVne: "ja37/sound/tones/vne",
  toneTs: "ja37/sound/tones/transonic",
  toneFloor: "ja37/sound/tones/floor",
  tonePreA2: "ja37/sound/tones/alpha-pre-2",
  tonePreA1: "ja37/sound/tones/alpha-pre-1",
  tonePreL2: "ja37/sound/tones/load-pre-2",
  tonePreL1: "ja37/sound/tones/load-pre-1",
};

var Saab37 = {
  new: func {
    var saab37 = {parents: [Saab37]};
    saab37.oldUnit = -1;
    return saab37;
  },

  update_loop: func {

    # Stuff that will run even in replay:
    me.currentUnit = getprop("ja37/hud/units-metric");
    if (me.currentUnit != me.oldUnit) {#since there can be many texture replacements we dont wanna do this every loop:
      if (me.currentUnit) {
          setprop("ja37/language/textureRadarPanel", "radar-panel-se.png");
      } else {
          setprop("ja37/language/textureRadarPanel", "radar-panel.png");
      }    
    }
    me.oldUnit = me.currentUnit;
    # breath sound volume
    input.breathVol.setDoubleValue(input.viewInternal.getValue() and input.fullInit.getValue());

    #augmented flame translucency
    me.red = input.sceneRed.getValue();
    setprop("rendering/scene/diffuse/red-unbound", me.red);
    # normal effect
    #var angle = input.sunAngle.getValue();# 1.25 - 2.45
    #var newAngle = (1.2 -(angle-1.25))*0.8333;
    #input.MPfloat2.setValue(newAngle);
    me.translucency = clamp(me.red, 0.35, 1);
    input.MPfloat2.setDoubleValue(me.translucency);

    # ALS effect
    me.red2 = clamp(1 - me.red, 0.25, 1);
    input.MPfloat9.setDoubleValue(me.red2);

    # set afterburner white at night:
    setprop("sim/model/j37/effect/flame-low-color-r",  0.863+(1-me.red));
    setprop("sim/model/j37/effect/flame-low-color-g",  0.347+(1-me.red));
    setprop("sim/model/j37/effect/flame-low-color-b",  0.238+(1-me.red));
    setprop("sim/model/j37/effect/flame-high-color-r", 0.863+(1-me.red));
    setprop("sim/model/j37/effect/flame-high-color-g", 0.238+(1-me.red));
    setprop("sim/model/j37/effect/flame-high-color-b", 0.347+(1-me.red));

    # End stuff

    if(input.replay.getValue() == TRUE) {
      # replay is active, skip rest of loop.
      return;
    }


    # set the full-init property
    if(input.elapsed.getValue() > input.elapsedInit.getValue() + 5) {
      input.fullInit.setBoolValue(TRUE);
    } else {
      input.fullInit.setBoolValue(FALSE);
    }

    if (input.fuelRatio.getValue() > 0 and input.tank8LvlNorm.getValue() > 0) {
      bingoFuel = FALSE;
    } else {
      bingoFuel = TRUE;
    }

    #if (input.tank0LvlNorm.getValue() == 0) {
      # a bug in JSB makes NaN on fuel temp if tank has been empty. [old bug, long fixed]
      # input.fuelTemp.setBoolValue(FALSE);
    #}

    #if(getprop("/sim/failure-manager/controls/flight/rudder/serviceable") == 1) {
    #  setprop("fdm/jsbsim/fcs/rudder/serviceable", 1);
    #} elsif (getprop("fdm/jsbsim/fcs/rudder/serviceable") == 1) {
    #  setprop("fdm/jsbsim/fcs/rudder-sum-stuck", getprop("fdm/jsbsim/fcs/rudder-sum"));
    #  setprop("fdm/jsbsim/fcs/rudder-serviceable", 0);
    #}

    # front gear compression calc for spinning of wheel
    # setprop("gear/gear/compression-wheel", (getprop("gear/gear/compression-ft")*0.3048-1.84812));


    # low speed warning (as per manual page 279 in JA37C part 1)
    me.lowSpeed = FALSE;
    if (!input.indAT.getBoolValue() and (input.speedKt.getValue() * 1.85184) < 375 and input.wow1.getValue() == FALSE) {
      if (input.indAltMeter.getValue() < 1200) {
        if (
          (input.gearsPos.getValue() == 1 and (input.rad_alt_ready.getBoolValue()?(input.rad_alt.getValue() * FT2M) > 30:(input.indAltFt.getValue() * FT2M) > 30))
          or input.gearsPos.getValue() != 1) {
          if (getprop("fdm/jsbsim/fcs/throttle-pos-deg") < 19 or input.reversed.getValue() == TRUE or input.engineRunning.getValue() == FALSE) {
            me.lowSpeed = TRUE;
          }
        }
      }
    }
    input.speedWarn.setBoolValue(me.lowSpeed);

    # main electrical turned on
    me.timer = input.elapsed.getValue();
    me.main = power.prop.dcMainBool.getValue();
    if(me.main and mainOn == FALSE) {
      #main has been switched on
      mainTimer = me.timer;
      mainOn = TRUE;
      input.lampData.setBoolValue(TRUE);
      input.insCmd.setBoolValue(TRUE);
    } elsif (me.main) {
      if (me.timer > (mainTimer + 20)) {
        input.lampData.setBoolValue(FALSE);
      }
    } elsif (!me.main) {
      mainOn = FALSE;
    }

    # contrails, damage smoke
    me.contrails = input.tempDegC.getValue() < -40 and input.alt.getValue() > 19000 and input.n2.getValue() > 50;
    me.d_smoke = !input.servFire.getValue()+input.damage.getValue();
    input.damageSmoke.setValue(me.d_smoke);
    input.MPbool4.setValue(me.contrails);
    input.MPint18.setIntValue(encode3bits(me.contrails, me.d_smoke, 0));

    # smoke
    if (power.prop.dcMainBool.getValue()) {
      input.aeroSmoke.setIntValue(input.aeroSmokeCmd.getValue());
    } else {
      input.aeroSmoke.setIntValue(1);
    }

    # AJS waypoint indicator
    if(input.rmActive.getBoolValue()) {
      me.wp = flightplan().currentWP();
      me.wp_index = me.wp.index;
      if(me.wp_index == 0) {
        # takeoff
        input.waypointType.setIntValue(1);
        input.waypointNumber.setIntValue(11);
      } elsif(me.wp.wp_role == "approach") {
        # landing
        if(!input.landingMode.getBoolValue()) {
          input.waypointType.setIntValue(1);
        } elsif(!input.approachMode.getBoolValue()) {
          input.waypointType.setIntValue(2);
        } else {
          input.waypointType.setIntValue(3);
        }
        input.waypointNumber.setIntValue(1);
      } else {
        # Can only correctly display waypoint 1-9
        if(me.wp_index > 9) me.wp_index = 10;
        input.waypointType.setIntValue(4);
        input.waypointNumber.setIntValue(me.wp_index);
      }
    } else {
      input.waypointType.setIntValue(0);
      input.waypointNumber.setIntValue(0);
    }

    #if(getprop("ja37/systems/variant") != 0 and getprop("/instrumentation/radar/range") == 180000) {
    #  setprop("/instrumentation/radar/range", 120000);
    #}

    # ALS heat blur
    me.inv_speed = 100-getprop("velocities/airspeed-kt");
    setprop("velocities/airspeed-kt-inv", me.inv_speed);
    setprop("ja37/effect/heatblur/dens", clamp((getprop("engines/engine/n2")/100-getprop("velocities/airspeed-kt")/250)*0.035, 0, 1));

    ## terrain detection ##
    if (getprop("ja37/supported/picking") == TRUE) {
      setprop("ja37/radar/look-through-terrain", FALSE);
    }
    if (getprop("controls/electric/main") and getprop("ja37/avionics/collision-warning") and getprop("ja37/supported/picking") == TRUE and (getprop("velocities/speed-east-fps") != 0 or getprop("velocities/speed-north-fps") != 0)) {
      # main elec switch must be on to enable this system, dont run on batt
      me.start = geo.aircraft_position();

      me.speed_down_fps  = getprop("velocities/speed-down-fps");
      me.speed_east_fps  = getprop("velocities/speed-east-fps");
      me.speed_north_fps = getprop("velocities/speed-north-fps");
      me.speed_horz_fps  = math.sqrt((me.speed_east_fps*me.speed_east_fps)+(me.speed_north_fps*me.speed_north_fps));
      me.speed_fps       = math.sqrt((me.speed_horz_fps*me.speed_horz_fps)+(me.speed_down_fps*me.speed_down_fps));
      me.heading = 0;
      if (me.speed_north_fps >= 0) {
        me.heading -= math.acos(me.speed_east_fps/me.speed_horz_fps)*R2D - 90;
      } else {
        me.heading -= -math.acos(me.speed_east_fps/me.speed_horz_fps)*R2D - 90;
      }
      me.heading = geo.normdeg(me.heading);
      #cos(90-heading)*horz = east
      #acos(east/horz) - 90 = -head

      me.end = geo.Coord.new(me.start);
      me.end.apply_course_distance(me.heading, me.speed_horz_fps*FT2M);
      me.end.set_alt(me.end.alt()-me.speed_down_fps*FT2M);

      me.dir_x = me.end.x()-me.start.x();
      me.dir_y = me.end.y()-me.start.y();
      me.dir_z = me.end.z()-me.start.z();
      me.xyz = {"x":me.start.x(),  "y":me.start.y(),  "z":me.start.z()};
      me.dir = {"x":me.dir_x,      "y":me.dir_y,      "z":me.dir_z};

      me.geod = get_cart_ground_intersection(me.xyz, me.dir);
      if (me.geod != nil) {
        me.end.set_latlon(me.geod.lat, me.geod.lon, me.geod.elevation);
        me.dist = me.start.direct_distance_to(me.end)*M2FT;
        me.time = me.dist / me.speed_fps;
        setprop("/ja37/radar/time-till-crash", me.time);
      } else {
        setprop("/ja37/radar/time-till-crash", 15);
      }
    } else {
      setprop("/ja37/radar/time-till-crash", 15);
    }

    if (getprop("fdm/jsbsim/gear/gear-lever-lock-mech") == TRUE and getprop("controls/gear/gear-down")==FALSE) {
      setprop("controls/gear/gear-down", TRUE);
      notice("The gear lever wont budge.");
    } elsif (getprop("fdm/jsbsim/gear/gear-lever-lock-electro") == TRUE and getprop("controls/gear/gear-down")==TRUE) {
      setprop("controls/gear/gear-down", FALSE);
      notice("The gear lever wont budge.");
    }
    if (getprop("payload/armament/msg") == TRUE) {
      
      #call(func{fgcommand('dialog-close', multiplayer.dialog.dialog.prop())},nil,var err= []);# props.Node.new({"dialog-name": "location-in-air"}));
      call(func{multiplayer.dialog.del();},nil,var err= []);
      if (!reload_allowed()) {
        call(func{fgcommand('dialog-close', props.Node.new({"dialog-name": "WeightAndFuel"}))},nil,var err2 = []);        
        call(func{fgcommand('dialog-close', props.Node.new({"dialog-name": "system-failures"}))},nil,var err2 = []);
        call(func{fgcommand('dialog-close', props.Node.new({"dialog-name": "instrument-failures"}))},nil,var err2 = []);  
        loadout.Dialog.close();
      }
      setprop("sim/freeze/fuel",0);
      setprop("/sim/speed-up", 1);
      setprop("/gui/map/draw-traffic", 0);
      setprop("/sim/gui/dialogs/map-canvas/draw-TFC", 0);
    }
    setprop("/sim/rendering/als-filters/use-filtering", 1);
  },

  # fast updating loop
  speed_loop: func {
    if(input.replay.getValue() == TRUE) {
      # replay is active, skip rest of loop.
      return;
    }

    ## control augmented thrust ##
    me.n1 = input.n1.getValue();
    me.n2 = input.n2.getValue();
    me.reversed = input.reversed.getValue();

    if ( input.fdmAug.getValue() == TRUE) { #was 99 and 97
      input.augmentation.setBoolValue(TRUE);
    } else {
      input.augmentation.setBoolValue(FALSE);
    }

    # RWR
    rwr.update_rwr();

    # Animating engine fire
    if (me.n1 > 100) me.n1 = 100;
    me.flame = 100 / (101-me.n1);
    input.flame.setDoubleValue(me.flame);

    ## set groundspeed property used for crashcode ##
    me.horz_speed = input.vgFps.getValue();
    me.vert_speed = input.downFps.getValue();
    me.real_speed = math.sqrt((me.horz_speed * me.horz_speed) + (me.vert_speed * me.vert_speed));
    me.real_speed = me.real_speed * FPS2KT;
    input.g3d.setDoubleValue(me.real_speed);

    # MP gear wow
    me.wow0 = input.wow0.getValue();
    me.wow1 = input.wow1.getValue();
    me.wow2 = input.wow2.getValue();
    input.MPint17.setIntValue(encode3bits(me.wow0, me.wow1, me.wow2));

    # environment volume
    me.canopy = input.canopyHinge.getValue() == FALSE?1:input.canopyPos.getValue();
    me.internal = input.viewInternal.getValue();
    me.vol = 0;
    if(me.internal != nil and me.canopy != nil) {
      me.vol = clamp(1-(me.internal*0.5)+(me.canopy*0.5), 0, 1);
    } else {
      me.vol = 0;
    }
    input.envVol.setDoubleValue(me.vol);
    me.rain = input.rainNorm.getValue();
    if (me.rain == nil) {
      me.rain = 0;
    }
    input.rainVol.setDoubleValue(me.rain*0.35*me.vol);

    me.theShakeEffect();
    # The HUD should not shake (relative to the background).
    # This requires to update the hud translation just after head movements.
    canvas_HUD.hud_pilot.followHeadPosition();

    logTime();
  
    if (!input.inputFlight.getValue() and input.terrainWarn.getValue()) {
      input.inputFlight.setBoolValue(TRUE);
      notice("Terrain warning made you grab the flight controls! Cursor inactive.");
    }

    if (input.parachuteDeploy.getValue() != nil) {
        input.parachuteForce.setDoubleValue(7-5*input.parachuteDeploy.getValue());
    } else {
      input.parachuteForce.setDoubleValue(7);
    }
    
    me.aural();
    me.headingBug();
  },
  
  aural: func {
    # CK37 issued aural warnings (minus master-warning, as its played seperate)
    #
    # at MKV ground collision warning the load-factor warning is force set at 110. (until 10 secs after)
    me.warnGiven = 0;
    if (!power.prop.dcMainBool.getValue() or !getprop("ja37/avionics/annunciator/serviceable")) {
      me.warnGiven = 1;
    }
    if (!me.warnGiven and getprop("ja37/sound/terrain-on")) {
      input.toneTerr.setBoolValue(1);
      me.warnGiven = 1;
    } else {
      input.toneTerr.setBoolValue(0);
    }
    if (!me.warnGiven and getprop("ai/submodels/submodel[0]/flare-release-out-snd")) {
      input.toneOut.setBoolValue(1);
      me.warnGiven = 1;
    } else {
      input.toneOut.setBoolValue(0);
    }
    if (!me.warnGiven and getprop("ai/submodels/submodel[0]/flare-release-snd")) {
      input.toneCM.setBoolValue(1);
      me.warnGiven = 1;
    } else {
      input.toneCM.setBoolValue(0);
    }
    if (!me.warnGiven and input.fuseGVV.getValue() and ((input.alpha.getValue()>getprop("fdm/jsbsim/systems/sound/alpha-limit-high") and !input.gearsPos.getValue()) or getprop("ja37/sound/pilot-G-norm")>1 or getprop("ja37/sound/speed-on") or (input.alpha.getValue()>18 and getprop("gear/gear/position-norm") and !getprop("fdm/jsbsim/gear/unit[0]/WOW") and !getprop("fdm/jsbsim/gear/unit[2]/WOW")))) {
      input.toneGVV.setBoolValue(1);
      me.warnGiven = 1;
    } else {
      input.toneGVV.setBoolValue(0);
    }
    if (!me.warnGiven and (input.speedKt.getValue()>getprop("limits/vne") or input.speedMach.getValue()>getprop("limits/vne-mach"))) {
      input.toneVne.setBoolValue(1);
      me.warnGiven = 1;
    } else {
      input.toneVne.setBoolValue(0);
    }
    if (me.tsPlaying) me.warnGiven = 1;
    if (getprop("fdm/jsbsim/systems/indicators/transonic")) {
      if (!me.warnGiven and !me.ts) {
        input.toneTs.setBoolValue(1);
        settimer(func {me.tsTimed()},2.1);
        me.warnGiven = 1;
        me.tsPlaying = 1;
      }
      me.ts = 1;
    } else {
      me.ts = 0;
    }
    if (me.floorPlaying) me.warnGiven = 1;
    if (input.indAltFt.getValue() < getprop("ja37/sound/floor-ft")) {
      if (!me.warnGiven and !me.floor) {
        input.toneFloor.setBoolValue(1);
        settimer(func {me.floorTimed()},2.1);
        me.warnGiven = 1;
        me.floorPlaying = 1;
        
      }
      me.floor = 1;
    } else {
      me.floor = 0;
      #setprop("ja37/sound/tones/floor",0);
    }
    if (!me.warnGiven and input.fuseGVV.getValue() and !input.gearsPos.getValue() and input.alpha.getValue() > getprop("fdm/jsbsim/systems/sound/alpha-limit-medium") and input.alpha.getValue() < getprop("fdm/jsbsim/systems/sound/alpha-limit-high")) {
      input.tonePreA2.setBoolValue(1);
      me.warnGiven = 1;
    } else {
      input.tonePreA2.setBoolValue(0);
    }
    if (!me.warnGiven and input.fuseGVV.getValue() and !input.gearsPos.getValue() and input.alpha.getValue() > getprop("fdm/jsbsim/systems/sound/alpha-limit-low") and input.alpha.getValue() < getprop("fdm/jsbsim/systems/sound/alpha-limit-medium")) {
      input.tonePreA1.setBoolValue(1);
      me.warnGiven = 1;
    } else {
      input.tonePreA1.setBoolValue(0);
    }
    if (!me.warnGiven and input.fuseGVV.getValue() and !input.gearsPos.getValue() and getprop("ja37/sound/pilot-G-norm") > 0.92 and getprop("ja37/sound/pilot-G-norm") < 1) {
      input.tonePreL2.setBoolValue(1);
      me.warnGiven = 1;
    } else {
      input.tonePreL2.setBoolValue(0);
    }
    if (!me.warnGiven and input.fuseGVV.getValue() and !input.gearsPos.getValue() and getprop("ja37/sound/pilot-G-norm") > 0.85 and getprop("ja37/sound/pilot-G-norm") < 0.92) {
      input.tonePreL1.setBoolValue(1);
      me.warnGiven = 1;
    } else {
      input.tonePreL1.setBoolValue(0);
    }
  },
  
  floorPlaying: 0,
  floor: 0,
  ts: 0,
  tsPlaying: 0,
  
  floorTimed: func {
    input.toneFloor.setBoolValue(0);
    me.floorPlaying = 0;
  },
  
  tsTimed: func {
    input.toneTs.setBoolValue(0);
    me.tsPlaying = 0;
  },

  theShakeEffect: func {
    me.rSpeed = input.airspeed.getValue();#change to ground speed
    me.G = input.pilotG.getValue();
    me.alpha = input.alpha.getValue();
    me.mach = input.mach.getValue();
    me.wow = input.wow1.getValue();
    me.near = input.nearby.getValue();
    me.explode = input.explode.getValue();

    if (me.rSpeed == nil or me.G == nil or me.alpha == nil or me.mach == nil or me.wow == nil or me.near == nil or me.explode == nil) {
      return;
    }

    defaultView = getprop("ja37/effect/seat");

    if(input.viewName.getValue() == "Cockpit View" and (((me.G > 7 or me.alpha>4.5) and me.rSpeed>30) or (me.mach>0.97 and me.mach<1.05) or (me.wow and me.rSpeed>100) or me.near == TRUE or me.explode == TRUE)) {
      me.factor = 0;
      me.densFactor = clamp(1-input.dens.getValue()/30000, 0, 1);
      if (me.G > 7) {
        me.factor += map(me.G,7,9,0,1)*me.densFactor;
      }
      if (me.alpha > 4.5 and me.rSpeed > 30 and me.mach < 1) {
        me.factor += map(me.alpha,4.5,12,0,1)*me.densFactor;# manual says no buffeting from alpha at mach 1+. And that it starts from 4.5 and goes to max at 12.
      }
      if (me.mach>0.97 and me.mach<1.05) {
        me.factor += 1*me.densFactor;
      }
      if (me.wow == TRUE and me.rSpeed > 100) {
        me.factor += map(me.rSpeed,100,200,0,0.50);
      }    
      me.factor = clamp(me.factor,0,1);
      if (me.near == TRUE) {
        me.factor += 2;
      }
      if (me.explode == TRUE) {
        me.factor += 3.5;
      }
      setprop("ja37/effect/buffeting", me.factor);
      input.viewYOffset.setDoubleValue(defaultView+input.buffOut.getValue()*me.factor); 
    } elsif (input.viewName.getValue() == "Cockpit View") {
      setprop("ja37/effect/buffeting", 0);
      input.viewYOffset.setDoubleValue(defaultView);
    } 
  },

  # slow updating loop
  slow_loop: func {
    if(input.replay.getValue() == TRUE) {
      # replay is active, skip rest of loop.
      return;
    }


    if (getprop("sim/replay/replay-state") == 0 and power.prop.dcSecondBool.getValue()) {
      setprop("ja37/avionics/record-on", TRUE);
    } else {
      setprop("ja37/avionics/record-on", FALSE);
    }

    me.environment();

    # consume oxygen bottle pressure
    if (getprop("controls/oxygen") == TRUE) {
      me.amount = getprop("ja37/systems/oxygen-bottle-pressure")-127/(27000/LOOP_SLOW_RATE);#7.5 hours to consume all 127 kpm2
      setprop("ja37/systems/oxygen-bottle-pressure", me.amount);
    }

    # warnings if trouble breathing
    me.mask = getprop("fdm/jsbsim/systems/flight/oxygen-pressure-kPa");
    me.cabin = getprop("fdm/jsbsim/systems/flight/cabin-pressure-kPa");
    me.oxy = getprop("/controls/oxygen");
    me.bottle = getprop("/ja37/systems/oxygen-bottle-pressure");
    if (rand() > 0.75) {
      if (me.cabin < 25) {
        if (me.oxy == FALSE or me.bottle < 25) {
          screen.log.write("You feel dizzy from lack of oxygen", 1.0, 0.0, 0.0);
        }
      } elsif (me.cabin < 35) {
        if (me.oxy == FALSE or me.bottle < 35) {
          screen.log.write("You feel the lack of oxygen", 1.0, 0.5, 0.0);
        }
      }
    }

    #warning if max rolling speed is exceeded
    me.max = getprop("limits/vroll");
    if ((input.wow0.getValue() == TRUE or input.wow2.getValue() == TRUE) and me.max != nil and getprop("instrumentation/airspeed-indicator/indicated-speed-kt") > me.max) {
      screen.log.write("Maximum allowed rolling speed exceeded!", 1.0, 0.0, 0.0);
    }

    if (getprop("ja37/systems/input-controls-flight") == FALSE and rand() > 0.95) {
      ja37.notice("Flight ctrls OFF. Press key 'y' to reactivate.");
    }
  },

  environment: func {
    ###########################################################
    #               Aircondition, frost, fog and rain         #
    ###########################################################

    # If AC is set to warm or cold, then it will put warm/cold air into the cockpit for 12 seconds, and then revert to auto setting.

    me.acSetting = getprop("controls/ventilation/airconditioning-type");
    if (me.acSetting != 0) {
      # 12 second of cold or hot air has been selected.
      if (acPrev != me.acSetting) {
        acTimer = input.elapsed.getValue();
      } elsif (acTimer+12 < input.elapsed.getValue()) {
        setprop("controls/ventilation/airconditioning-type", 0);
        me.acSetting = 0;
      }
    }
    acPrev = me.acSetting;
    me.tempAC = getprop("controls/ventilation/airconditioning-temperature");
    if (me.acSetting == -1) {
      me.tempAC = -4;
    } elsif (me.acSetting == 1) {
      me.tempAC = 80;
    }

    # Here is calculated how raindrop move over the surface of the glass

    me.airspeed = getprop("/velocities/airspeed-kt");
    # ja37
    #var airspeed_max = 250; 
    me.airspeed_max = 120;
    if (me.airspeed > me.airspeed_max) {
      me.airspeed = me.airspeed_max;
    }
    me.airspeed = math.sqrt(me.airspeed/me.airspeed_max);
    # Reverted the vector from what is used on the f-16
    me.splash_x = -(-0.1 - 2.0 * me.airspeed);
    me.splash_y = 0.0;
    me.splash_z = -(1.0 - 1.35 * me.airspeed);
    setprop("/environment/aircraft-effects/splash-vector-x", me.splash_x);
    setprop("/environment/aircraft-effects/splash-vector-y", me.splash_y);
    setprop("/environment/aircraft-effects/splash-vector-z", me.splash_z);

    # If the AC is turned on and on auto setting, it will slowly move the cockpit temperature toward its temperature setting.
    # The dewpoint inside the cockpit depends on the outside dewpoint and how the AC is working.
    me.tempOutside = getprop("environment/temperature-degc");
    me.ramRise     = (input.speedTrueKt.getValue()*input.speedTrueKt.getValue())/(87*87);#this is called the ram rise formula
    me.tempOutside += me.ramRise;
    me.tempInside  = getprop("environment/aircraft-effects/temperature-inside-degC");
    me.tempOutsideDew = getprop("environment/dewpoint-degc");
    me.tempInsideDew = getprop("/environment/aircraft-effects/dewpoint-inside-degC");
    me.tempACDew = 5;# aircondition dew point target. 5 = dry
    me.ACRunning = power.prop.dcMainBool.getValue() and getprop("controls/ventilation/airconditioning-enabled") == TRUE and testing.ongoing == FALSE;

    # calc inside temp
    me.hotAir_deg_min = 2.0;# how fast does the sources heat up cockpit.
    me.pilot_deg_min  = 0.2;
    me.glass_deg_min_per_deg_diff  = 0.15;
    me.AC_deg_min_per_deg_diff     = 0.50;
    me.knob = getprop("controls/ventilation/windshield-hot-air-knob");
    me.hotAirOnWindshield = power.prop.dcMainBool.getValue()?me.knob:0;
    if (input.canopyPos.getValue() > 0 or input.canopyHinge.getValue() == FALSE) {
      me.tempInside = getprop("environment/temperature-degc");
    } else {
      me.tempInside += me.hotAirOnWindshield * (me.hotAir_deg_min/(60/LOOP_SLOW_RATE)); # having hot air on windshield will also heat cockpit (10 degs/5 mins).
      if (me.tempInside < 37) {
        me.tempInside += me.pilot_deg_min/(60/LOOP_SLOW_RATE); # pilot will also heat cockpit with 1 deg per 5 mins
      }
      # outside temp ram air temp and static temp will influence inside temp:
      me.coolingFactor = ((me.tempOutside+getprop("environment/temperature-degc"))*0.5-me.tempInside)*me.glass_deg_min_per_deg_diff/(60/LOOP_SLOW_RATE);# 1 degrees difference will cool/warm with 0.5 DegCelsius/min
      me.tempInside += me.coolingFactor;
      if (me.ACRunning) {
        # AC is running and will work to influence the inside temperature
        me.tempInside += (me.tempAC-me.tempInside)*me.AC_deg_min_per_deg_diff/(60/LOOP_SLOW_RATE);# (tempAC-tempInside) = degs/mins it should change
      }
    }

    # calc temp of glass itself
    me.tempIndex = getprop("/environment/aircraft-effects/glass-temperature-index"); # 0.80 = good window   0.45 = bad window
    me.tempGlass = me.tempIndex*(me.tempInside - me.tempOutside)+me.tempOutside;
    
    # calc dewpoint inside
    if (input.canopyPos.getValue() > 0 or input.canopyHinge.getValue() == FALSE) {
      # canopy is open, inside dewpoint aligns to outside dewpoint instead
      me.tempInsideDew = me.tempOutsideDew;
    } else {
      me.tempInsideDewTarget = 0;
      if (me.ACRunning == TRUE) {
        # calculate dew point for inside air. When full airconditioning is achieved at tempAC dewpoint will be tempACdew.
        # slope = (outsideDew - desiredInsideDew)/(outside-desiredInside)
        # insideDew = slope*(inside-desiredInside)+desiredInsideDew
        if ((me.tempOutside-me.tempAC) == 0) {
          me.slope = 1; # divide by zero prevention
        } else {
          me.slope = (me.tempOutsideDew - me.tempACDew)/(me.tempOutside-me.tempAC);
        }
        me.tempInsideDewTarget = me.slope*(me.tempInside-me.tempAC)+me.tempACDew;
      } else {
        me.tempInsideDewTarget = me.tempOutsideDew;
      }
      if (me.tempInsideDewTarget > me.tempInsideDew) {
        me.tempInsideDew = clamp(me.tempInsideDew + 0.15, -1000, me.tempInsideDewTarget);
      } else {
        me.tempInsideDew = clamp(me.tempInsideDew - 0.15, me.tempInsideDewTarget, 1000);
      }
    }
    

    # calc fogging outside and inside on glass
    me.fogNormOutside = clamp((me.tempOutsideDew-me.tempGlass)*0.05, 0, 1);
    me.fogNormInside = clamp((me.tempInsideDew-me.tempGlass)*0.05, 0, 1);
    
    # calc frost
    me.frostNormOutside = getprop("/environment/aircraft-effects/frost-outside");
    me.frostNormInside = getprop("/environment/aircraft-effects/frost-inside");
    me.rain = getprop("/environment/rain-norm");
    if (me.rain == nil) {
      me.rain = 0;
    }
    me.frostSpeedInside = clamp(-me.tempGlass, -60, 60)/600 + (me.tempGlass<0?me.fogNormInside/50:0);
    me.frostSpeedOutside = clamp(-me.tempGlass, -60, 60)/600 + (me.tempGlass<0?(me.fogNormOutside/50 + me.rain/50):0);
    me.maxFrost = clamp(1 + ((me.tempGlass + 5) / (0 + 5)) * (0 - 1), 0, 1);# -5 is full frost, 0 is no frost
    me.maxFrostInside = clamp(me.maxFrost - clamp(me.tempInside/30,0,1), 0, 1);# frost having harder time to form while being constantly thawed.
    me.frostNormOutside = clamp(me.frostNormOutside + me.frostSpeedOutside, 0, me.maxFrost);
    me.frostNormInside = clamp(me.frostNormInside + me.frostSpeedInside, 0, me.maxFrostInside);
    me.frostNorm = me.frostNormOutside>me.frostNormInside?me.frostNormOutside:me.frostNormInside;
    #var frostNorm = clamp((tempGlass-0)*-0.05, 0, 1);# will freeze below 0

    # recalc fogging from frost levels, frost will lower the fogging
    me.fogNormOutside = clamp(me.fogNormOutside - me.frostNormOutside / 4, 0, 1);
    me.fogNormInside = clamp(me.fogNormInside - me.frostNormInside / 4, 0, 1);
    me.fogNorm = me.fogNormOutside>me.fogNormInside?me.fogNormOutside:me.fogNormInside;

    # If the hot air on windshield is enabled and its setting is high enough, then apply the mask which will defog the windshield.
    me.mask = FALSE;
    if (me.frostNorm <= me.hotAirOnWindshield and me.hotAirOnWindshield != 0) {
      me.mask = TRUE;
    }

    # internal environment
    setprop("/environment/aircraft-effects/fog-inside", me.fogNormInside);
    setprop("/environment/aircraft-effects/fog-outside", me.fogNormOutside);
    setprop("/environment/aircraft-effects/frost-inside", me.frostNormInside);
    setprop("/environment/aircraft-effects/frost-outside", me.frostNormOutside);
    setprop("/environment/aircraft-effects/temperature-glass-degC", me.tempGlass);
    setprop("/environment/aircraft-effects/dewpoint-inside-degC", me.tempInsideDew);
    setprop("/environment/aircraft-effects/temperature-inside-degC", me.tempInside);
    setprop("/environment/aircraft-effects/temperature-outside-ram-degC", me.tempOutside);
    # effects
    setprop("/environment/aircraft-effects/frost-level", me.frostNorm);
    setprop("/environment/aircraft-effects/fog-level", me.fogNorm);
    setprop("/environment/aircraft-effects/use-mask", me.mask);
    if (rand() > 0.95) {
      if (me.tempInside < 10) {
        if (me.tempInside < 5) {
          screen.log.write("You are freezing, the cabin is very cold", 1.0, 0.0, 0.0);
        } else {
          screen.log.write("You feel cold, the cockpit is cold", 1.0, 0.5, 0.0);
        }
      } elsif (me.tempInside > 25) {
        if (me.tempInside > 28) {
          screen.log.write("You are sweating, the cabin is way too hot", 1.0, 0.0, 0.0);
        } else {
          screen.log.write("You feel its too warm in the cabin", 1.0, 0.5, 0.0);
        }
      }
    }
  },
  
  headingBug: func () {
    # for the heading indicator
    me.desired_mag_heading = nil;
    if (radar_logic.steerOrder == TRUE and radar_logic.selection != nil) {
        me.desired_mag_heading = radar_logic.selection.getMagInterceptBearing();
        me.itsHead = radar_logic.selection.get_heading();
        me.mag_offset = getprop("/orientation/heading-magnetic-deg") - getprop("/orientation/heading-deg");
        setprop("ja37/avionics/heading-indicator-target", geo.normdeg(input.headingMagn.getValue()-(me.itsHead + me.mag_offset)));
    } elsif( input.rmActive.getValue() == TRUE) {
      me.desired_mag_heading = input.RMWaypointBearing.getValue();
    }
    if(me.desired_mag_heading != nil) {
      setprop("ja37/avionics/heading-indicator-bug", geo.normdeg(input.headingMagn.getValue()-me.desired_mag_heading));
    } else {
      setprop("ja37/avionics/heading-indicator-bug", input.headingMagn.getValue());
    }
  },

  loopSystem: func {
    #
    # start all the loops in aircraft.
    # Some loops are are not started here though, but most are.
    # Notice some loop timers are slightly changed to spread out calls,
    # so that many loops are not called in same frame.
    #
    me.loop_slow     = maketimer(LOOP_SLOW_RATE, me, func me.slow_loop());
    me.loop_fast     = maketimer(0.06, me, func me.speed_loop());
    me.loop_saab37   = maketimer(0.25, me, func me.update_loop());

    # displays commons
    displays.common.loop();
    displays.common.loopFast();
    me.loop_common   = maketimer(0.21, displays.common, func displays.common.loop());
    me.loop_commonF  = maketimer(0.05, displays.common, func displays.common.loopFast());
    me.loop_common.start();
    me.loop_commonF.start();

    me.loop_land     = maketimer(0.27, land.lander, func land.lander.loop());
    me.loop_nav      = maketimer(0.28, me, func navigation.heading_indicator());

    # stores
    armament.main_weapons();
    me.loop_stores   = maketimer(0.29, me, func armament.loop_stores());#0.05
 
    me.loop_saab37.start();
    me.loop_fast.start();
    me.loop_slow.start();
    me.loop_land.start();
    me.loop_nav.start();
    me.loop_stores.start();

    # radar
    radar_logic.radarLogic = radar_logic.RadarLogic.new();
    me.loop_logic  = maketimer(0.24, radar_logic.radarLogic, func radar_logic.radarLogic.loop());
    #me.loop_logic.start();

    # immatriculation
    call(func {# issue on some fast linux PCs..
      callsign.callInit();
      me.loop_callsign = maketimer(1, me, func callsign.loop_callsign());
      me.loop_callsign.start();
    },nil,var err=[]);
    if(size(err)) {
      foreach(var i;err) {
        print(i);
      }
    }

    if (getprop("ja37/systems/variant") != 0) {
      # CI display
      rdr.scope = rdr.radar.new();
      me.loop_radar_screen = maketimer(0.10, rdr.scope, func rdr.scope.update());
      me.loop_radar_screen.start();
    }

    # flightplans
    route.poly_start();

    if (getprop("ja37/systems/variant") == 0) {
      # TI
      # must not start looping before route has been init
      TI.setupCanvas();
      TI.ti = TI.TI.new();
      TI.ti.loop();#must be first due to me.rootCenterY
      me.loop_ti  = maketimer(0.50, TI.ti, func TI.ti.loop());
      me.loop_tiF = maketimer(0.05, TI.ti, func TI.ti.loopFast());
      me.loop_tiS = maketimer(180, TI.ti, func TI.ti.loopSlow());
      me.loop_ti.start();
      me.loop_tiF.start();
      me.loop_tiS.start();

      # MI
      # must be after TI
      MI.setupCanvas();
      MI.mi = MI.MI.new();
      me.loop_mi  = maketimer(0.15, MI.mi, func MI.mi.loop());
      me.loop_mi.start();
    }

    # HUD:
    canvas_HUD.hud_pilot = canvas_HUD.HUDnasal.new({"node": "hud", "texture": "hud.png"});
    me.loop_hud = maketimer(0.05, canvas_HUD.hud_pilot, func canvas_HUD.hud_pilot.update());
    #me.loop_ir  = maketimer(1.5, me, func canvas_HUD.IR_loop());

    me.loop_hud.start();
    #me.loop_ir.start();

    if (getprop("ja37/systems/variant") == 0) {
      # data-panel
      dap.callInit();
      me.loop_dap  = maketimer(1, me, func dap.loop_main());
      me.loop_dap.start();
      me.loop_plan  = maketimer(0.5, me, func route.Polygon.loop());
      me.loop_plan.start();
    }
    # radar (must be called after TI)
    me.loop_logic.start();

    # fire
    failureSys.init_fire();
    me.loop_fire  = maketimer(1, me, func failureSys.loop_fire());
    me.loop_fire.start();

    me.loop_test  = maketimer(0.25, me, func testing.loop());
    me.loop_test.start();
  },
  
  loopSystem2: func {
    #
    # start all the loops in aircraft.
    # Some loops are are not started here though, but most are.
    # Notice some loop timers are slightly changed to spread out calls,
    # so that many loops are not called in same frame.
    #
    me.loop_slow     = maketimer(LOOP_SLOW_RATE, me, func {timer.timeLoop("ja37-slow", me.slow_loop,me);});
    me.loop_fast     = maketimer(0.06, me, func {timer.timeLoop("ja37-fast", me.speed_loop,me);});
    me.loop_saab37   = maketimer(0.25, me, func {timer.timeLoop("ja37-medium", me.update_loop,me);});

    # displays commons
    displays.common.loop();
    displays.common.loopFast();
    me.loop_common   = maketimer(0.21, displays.common, func {timer.timeLoop("common-slow", displays.common.loop,displays.common);});
    me.loop_commonF  = maketimer(0.05, displays.common, func {timer.timeLoop("common-fast", displays.common.loopFast,displays.common);});
    me.loop_common.start();
    me.loop_commonF.start();

    me.loop_land     = maketimer(0.27, land.lander, func {timer.timeLoop("landing-mode", land.lander.loop,land.lander);});
    me.loop_nav      = maketimer(0.28, me, func {timer.timeLoop("heading-indicator", navigation.heading_indicator,me);});

    # stores
    armament.main_weapons();
    me.loop_stores   = maketimer(0.29, me, func {timer.timeLoop("stores", armament.loop_stores,me);});#0.05
 
    me.loop_saab37.start();
    me.loop_fast.start();
    me.loop_slow.start();
    me.loop_ap.start();
    me.loop_hydrLost.start();    
    me.loop_land.start();
    me.loop_nav.start();
    me.loop_stores.start();

    # radar
    radar_logic.radarLogic = radar_logic.RadarLogic.new();
    me.loop_logic  = maketimer(0.24, radar_logic.radarLogic, func {timer.timeLoop("Radar", radar_logic.radarLogic.loop,radar_logic.radarLogic);});
    #me.loop_logic.start();

    # immatriculation
    call(func {# issue on some fast linux PCs..
      callsign.callInit();
      me.loop_callsign = maketimer(1, me, func {timer.timeLoop("Callsign", callsign.loop_callsign,me);});
      me.loop_callsign.start();
    },nil,var err=[]);
    if(size(err)) {
      foreach(var i;err) {
        print(i);
      }
    }

    if (getprop("ja37/systems/variant") != 0) {
      # CI display
      rdr.scope = rdr.radar.new();
      me.loop_radar_screen = maketimer(0.10, rdr.scope, func rdr.scope.update());
      me.loop_radar_screen.start();
    }

    # flightplans
    route.poly_start();

    if (getprop("ja37/systems/variant") == 0) {
      # TI
      # must not start looping before route has been init
      TI.setupCanvas();
      TI.ti = TI.TI.new();
      TI.ti.loop();#must be first due to me.rootCenterY
      me.loop_ti  = maketimer(0.50, TI.ti, func {timer.timeLoop("TI-medium", TI.ti.loop,    TI.ti);});
      me.loop_tiF = maketimer(0.05, TI.ti, func {timer.timeLoop("TI-fast",   TI.ti.loopFast,TI.ti);});
      me.loop_tiS = maketimer(180, TI.ti,  func {timer.timeLoop("TI-slow",   TI.ti.loopSlow,TI.ti);});
      me.loop_ti.start();
      me.loop_tiF.start();
      me.loop_tiS.start();

      # MI
      # must be after TI
      MI.setupCanvas();
      MI.mi = MI.MI.new();
      me.loop_mi  = maketimer(0.15, MI.mi, func {timer.timeLoop("MI", MI.mi.loop,MI.mi);});
      me.loop_mi.start();
    }

    # HUD:
    canvas_HUD.hud_pilot = canvas_HUD.HUDnasal.new({"node": "hud", "texture": "hud.png"});
    me.loop_hud = maketimer(0.05, canvas_HUD.hud_pilot, func {timer.timeLoop("HUD", canvas_HUD.hud_pilot.update,canvas_HUD.hud_pilot);});
    #me.loop_ir  = maketimer(1.5, me, func canvas_HUD.IR_loop());

    me.loop_hud.start();
    #me.loop_ir.start();

    if (getprop("ja37/systems/variant") == 0) {
      # data-panel
      dap.callInit();
      me.loop_dap  = maketimer(1, me, func {timer.timeLoop("DAP", dap.loop_main,me);});
      me.loop_dap.start();
      me.loop_plan  = maketimer(0.5, me, func {timer.timeLoop("Plans", route.Polygon.loop,me);});
      me.loop_plan.start();
    }
    # radar (must be called after TI)
    me.loop_logic.start();

    # fire
    failureSys.init_fire();
    me.loop_fire  = maketimer(1, me, func {timer.timeLoop("Failure", failureSys.loop_fire,me);});
    me.loop_fire.start();

    me.loop_test  = maketimer(0.25, me, func {timer.timeLoop("Test", testing.loop,me);});
    me.loop_test.start();
  },
};

var saab37 = Saab37.new();















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



###########  loop for handling the battery signal for cockpit sound #########
var voltage = 0;
var signalInProgress = FALSE;
var battery_listener = func {

    if (signalInProgress == FALSE and !voltage and power.prop.dcMainBool.getValue()) {
      setprop("/systems/electrical/batterysignal", TRUE);
      signalInProgress = TRUE;
      settimer(func {
        setprop("/systems/electrical/batterysignal", FALSE);
        signalInProgress = FALSE;
        }, 6);
    }
    voltage = power.prop.dcMainBool.getValue();
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
  if (major < 2016) {
    notice("Saab 37 is only supported in Flightgear version 2016.1.1 and upwards. Sorry.");
    setprop("ja37/supported/picking", FALSE);
    setprop("ja37/supported/multiple-flightplans", FALSE);
  } elsif (major == 2016) {
    setprop("ja37/supported/picking", FALSE);
    setprop("ja37/supported/multiple-flightplans", FALSE);
  } elsif (major == 2017) {
    setprop("ja37/supported/picking", FALSE);
    setprop("ja37/supported/multiple-flightplans", FALSE);
    if (minor == 2) {
      setprop("ja37/supported/picking", TRUE);
    }
    if (minor == 3) {
      setprop("ja37/supported/picking", TRUE);
      if (detail > 0) {
        setprop("ja37/supported/multiple-flightplans", TRUE);
      }
    }
    if (minor == 4) {
      setprop("ja37/supported/picking", TRUE);
      setprop("ja37/supported/multiple-flightplans", TRUE);
    }
  } else {
    # future proof
    setprop("ja37/supported/picking", TRUE);
    setprop("ja37/supported/multiple-flightplans", TRUE);
  }
  setprop("ja37/supported/initialized", TRUE);

  print();
  print("***************************************************************");
  print("         Initializing "~getprop("sim/description")~" systems.           ");
  print("           Version "~getprop("sim/aircraft-version")~" on Flightgear "~version[0]~"."~version[1]~"."~version[2]~"            ");
  print("***************************************************************");
  print();
}

############################# main init ###############


var main_init = func {
  srand();
  
  power.init();
  
  setprop("sim/time/elapsed-at-init-sec", getprop("sim/time/elapsed-sec"));

  test_support();

  hack.init();
  if (getprop("ja37/systems/state") != "parked") {
    # to prevent battery from starting drained when choosing state with engine on we have to delay turning it on.
    setprop("controls/electric/battery", TRUE);
  }
  #setprop("ja37/avionics/master-warning-button", 0);# for when starting up with engines running, to prevent master warning.

#  aircraft.data.add("ja37/radar/enabled",
#                    "ja37/hud/units-metric",
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

  battery_listener();
  #code_ct();
  #not();

  # asymmetric vortex detachment
  asymVortex();

  # Setup lightning listener
  setlistener("/environment/lightning/lightning-pos-y", thunder_listener);

  if(getprop("ja37/systems/state") == "parked") {
    setprop("controls/engines/engine/reverser-cmd", rand()>0.5?TRUE:FALSE);
    setprop("controls/gear/brake-parking", rand()>0.5?TRUE:FALSE);
    setprop("controls/electric/reserve", rand()>0.5?TRUE:FALSE);
    setprop("controls/electric/lights-ext-form", rand()>0.5?TRUE:FALSE);
    setprop("controls/electric/lights-ext-beacon", rand()>0.5?TRUE:FALSE);
    setprop("controls/electric/lights-ext-nav", math.floor(rand()*3) - 1);     # between -1 and 1
    setprop("controls/electric/lights-land-switch", math.floor(rand()*3) - 1); # between -1 and 1
    setprop("controls/fuel/auto", rand()>0.5?TRUE:FALSE);
  }

  # start the main loop
  saab37.loopSystem();

  if (getprop("ja37/systems/state") == "cruise") {
      #setprop("position/altitude-ft", 20000);
      #setprop("velocities/mach", 0.65);
      setprop("fdm/jsbsim/gear/gear-filtered-norm", 0);
      setprop("fdm/jsbsim/gear/gear-pos-norm", 0);
      setprop("controls/gear/gear-down", 0);
      autoflight.System.engageMode(3);
      settimer(cruise, 1.5);
  } else {
    setprop("fdm/jsbsim/gear/gear-filtered-norm", 1);
    setprop("fdm/jsbsim/gear/gear-pos-norm", 1);
  }
  recharge_battery();
  setup_custom_stick_bindings();
  settimer(func{setprop("fdm/jsbsim/systems/electrical/generator-takeoff",0);},10);
}

var setup_custom_stick_bindings = func {
  call(func {
      append(joystick.buttonBindings, joystick.NasalHoldButton.new  ("Cursor Click", 'setprop("controls/displays/cursor-click",1);', 'setprop("controls/displays/cursor-click",0);'));
      append(joystick.axisBindings,   joystick.PropertyScaleAxis.new("Cursor Vertical", "/controls/displays/cursor-slew-y"));
      append(joystick.axisBindings,   joystick.PropertyScaleAxis.new("Cursor Horizontal", "/controls/displays/cursor-slew-x"));
  },nil,var err=[]);
  var dlg = gui.Dialog.new("/sim/gui/dialogs/button-axis-config/dialog", "Aircraft/JA37/gui/dialogs/button-axis-config.xml", "button-axis-config");
  var dlg = gui.Dialog.new("/sim/gui/dialogs/button-config/dialog", "Aircraft/JA37/gui/dialogs/button-config.xml", "button-config");
}



var cruise = func {
  setprop("controls/gear/gear-down", 0);
  setprop("fdm/jsbsim/gear/gear-filtered-norm", 0);
  setprop("fdm/jsbsim/gear/gear-pos-norm", 0);
}

# re init
var re_init = func {
  if (getprop("/sim/signals/reinit")==0) {return;}
  print("Re-initializing Saab 37 Viggen systems");
  
  setprop("sim/time/elapsed-at-init-sec", getprop("sim/time/elapsed-sec"));

  # init oxygen bottle pressure
  setprop("ja37/systems/oxygen-bottle-pressure", 127);# 127 kp/cm2 as per manual
  #print("Reinit: Oxygen replenished.");
  # asymmetric vortex detachment
  asymVortex();
  repair(FALSE);
  autoflight.engageMode(0);
  setprop("/controls/gear/gear-down", 1);
  setprop("/controls/gear/brake-parking", 1);
  setprop("ja37/done",0);
  setprop("sim/view[0]/enabled",1);
  setprop("/sim/current-view/view-number", 0);
  #test_support();
  recharge_battery();
}

var recharge_battery = func {
  setprop("ja37/systems/battery-reinit",1);
  setprop("ja37/systems/battery-recharge-rate",10);
  settimer(recharge_battery2, 2);
}

var recharge_battery2 = func {
  setprop("ja37/systems/battery-reinit",0);
  setprop("ja37/systems/battery-recharge-rate",0.001666);
  #print("Init: Battery fully recharged.");
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
  if (getprop("sim/signals/fdm-initialized") == 1) {
	 main_init();
	 removelistener(main_init_listener);
  }
 }, 0, 0);

var re_init_listener = setlistener("/sim/signals/reinit", func {
  re_init();
 }, 0, 0);


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
  setprop("/controls/engines/engine/throttle", 0);
  settimer(stopFinal, 5, 1);#allow time for ram air and flaps to retract
}

stopFinal = func {
  setprop("/controls/engines/engine/throttle", 0);
  setprop("/controls/engines/engine/throttle-cutoff", TRUE);
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
  } elsif (getprop("ja37/elec/dc-bus-battery-3-volt") > 20) {
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
  if (power.prop.dcSecondBool.getValue()) {
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
  setprop("controls/electric/lights-ext-form", TRUE);
  setprop("controls/electric/lights-ext-beacon", TRUE);
  setprop("controls/electric/lights-ext-nav", 1);
  setprop("controls/electric/lights-land-switch", 1);
  setprop("/controls/engines/engine[0]/starter-cmd-hold", FALSE);
  setprop("/controls/electric/engine[0]/generator", FALSE);
  notice("Starting engine..");
  click();
  setprop("fdm/jsbsim/propulsion/engine/cutoff-commanded", TRUE);
  setprop("/controls/engines/engine/throttle-cutoff", TRUE);
  setprop("/controls/engines/engine/throttle", 0);
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
    } elsif (!power.prop.dcSecondBool.getValue()) {
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
        setprop("/controls/engines/engine/throttle-cutoff", FALSE);
        setprop("/controls/engines/engine/throttle", 0);
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
    } elsif (!power.prop.dcSecondBool.getValue()) {
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

# Simplified, single button controls for speedbrakes
var speedbrakes_simple_command = -1; # last command. -1: retract, 1: extend
var speedbrakes_release_timer = maketimer(2, func {setprop("/controls/flight/speedbrake-switch", 0);});
speedbrakes_release_timer.singleShot = 1;
speedbrakes_release_timer.simulatedTime = 1;

var toggleSpeedbrakesSimplified = func (pos) {
  if (getprop("fdm/jsbsim/gear/gear-pos-norm") > 0) {
    # landing gear out, hold the switch to keep speedbrakes extended
    setprop("/controls/flight/speedbrake-switch", pos);
    speedbrakes_simple_command = -1;
  } else {
    # landing gear in, press to toggle speedbrakes
    if (!pos) return;
    speedbrakes_simple_command = -speedbrakes_simple_command;
    setprop("/controls/flight/speedbrake-switch", speedbrakes_simple_command);
    speedbrakes_release_timer.restart(2);
  }
}

var toggleTracks = func {
  ja37.click();
  var enabled = getprop("ja37/hud/tracks-enabled");
  setprop("ja37/hud/tracks-enabled", !enabled);
  if(enabled == FALSE) {
    notice("Radar ON");
    armament.ecmLog.push("Radar switched active.");
  } else {
    notice("Radar OFF");
    armament.ecmLog.push("Radar switched silent.");
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
    gui.popupTip(label, delay, nil, {"y": y});
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

var on_damage_enabled = func() {
    var internal = view.current.getNode("internal");
    if (internal == nil or !internal.getBoolValue()) {
        #view.setView(0); added only in FG 2019
        setprop("/sim/current-view/view-number", 0);
        setprop("/sim/current-view/view-number-raw", view.views[0].getIndex());
        screen.log.write("External views are disabled with damage on");
    }
}

var damage_listener = setlistener("/payload/armament/msg", func (node) {
    if (node.getBoolValue()) on_damage_enabled();
}, 1, 0);

var reload_allowed = func(msg = nil) {
    var b = input.reload_allowed.getBoolValue();
    if(!b and msg != nil) screen.log.write(msg);
    return b;
}

var repair_msg = "If you need to repair now, then use Menu-Location-SelectAirport instead.";

var repair = func {
    if(!reload_allowed(repair_msg)) return;

    crash.repair();
    failureSys.armAllTriggers();
    setprop("environment/damage", FALSE);
    setprop("ja37/done",0);
    setprop("sim/view[0]/enabled",1);
    setprop("/sim/current-view/view-number", 0);
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

var convertDoubleToDegree = func (value) {
  var sign = value < 0 ? -1 : 1;
  value = math.abs(value);
  var deg = math.floor(value);
  value = math.fmod(value,1) * 60;
  var min = math.floor(value);
  value = math.fmod(value,1) * 60;
  var sec = math.round(value);
  # Because of the rounding, sec may be 60.
  if (sec == 60) {
    sec = 0;
    min = min + 1;
    if (min == 60) {
      min = 0;
      deg = deg + 1;
    }
  }
  return [sign,deg,min,sec];
}
var convertDegreeToStringLat = func (lat) {
  lat = convertDoubleToDegree(lat);
  var s = "N";
  if (lat[0]<0) {
    s = "S";
  }
  return sprintf("%02d %02d %02d%s",lat[1],lat[2],lat[3],s);
}
var convertDegreeToStringLon = func (lon) {
  lon = convertDoubleToDegree(lon);
  var s = getprop("ja37/hud/units-metric")?"\xC3\x96":"E";
  if (lon[0]<0) {
    s = getprop("ja37/hud/units-metric")?"V":"W";
  }
  return sprintf("%03d %02d %02d%s",lon[1],lon[2],lon[3],s);
}
var convertDegreeToDispStringLat = func (lat) {
  lat = convertDoubleToDegree(lat);
  var s = "";
  if (lat[0]<0) {
    s = "-";
  }
  return sprintf("%s%02d%02d%02d",s,lat[1],lat[2],lat[3]);
}
var convertDegreeToDispStringLon = func (lon) {
  lon = convertDoubleToDegree(lon);
  var s = "";
  if (lon[0]<0) {
    s = "-";
  }
  return sprintf("%s%03d%02d%02d",s,lon[1],lon[2],lon[3]);
}
var convertDegreeToDouble = func (hour, minute, second) {
  var d = hour+minute/60+second/3600;
  return d;
}
var myPosToString = func {
  print(convertDegreeToStringLat(getprop("position/latitude-deg"))~"  "~convertDegreeToStringLon(getprop("position/longitude-deg")));
}
var stringToLon = func (str) {
  var total = num(str);
  if (total==nil) {
    return nil;
  }
  var sign = 1;
  if (total<0) {
    str = substr(str,1);
    sign = -1;
  }
  var deg = num(substr(str,0,2));
  var min = num(substr(str,2,2));
  var sec = num(substr(str,4,2));
  if (size(str) == 7) {
    deg = num(substr(str,0,3));
    min = num(substr(str,3,2));
    sec = num(substr(str,5,2));
  } 
  if(deg <= 180 and min<60 and sec<60) {
    return convertDegreeToDouble(deg,min,sec)*sign;
  } else {
    return nil;
  }
}
var stringToLat = func (str) {
  var total = num(str);
  if (total==nil) {
    return nil;
  }
  var sign = 1;
  if (total<0) {
    str = substr(str,1);
    sign = -1;
  }
  var deg = num(substr(str,0,2));
  var min = num(substr(str,2,2));
  var sec = num(substr(str,4,2));
  if(deg <= 90 and min<60 and sec<60) {
    return convertDegreeToDouble(deg,min,sec)*sign;
  } else {
    return nil;
  }
}
#myPosToString();

view.stepView = func(step, force = 0) {
    step = step > 0 ? 1 : -1;
    var n = view.index;
    for (var i = 0; i < size(view.views); i += 1) {
        n += step;
        if (n < 0)
            n = size(view.views) - 1;
        elsif (n >= size(view.views))
            n = 0;
        var e = view.views[n].getNode("enabled");
        var internal = view.views[n].getNode("internal");

        if ((force or e == nil or e.getBoolValue())
            and view.views[n].getNode("name") != nil
            and ((internal != nil and internal.getBoolValue()) or !getprop("/payload/armament/msg")))
            break;
    }
    #view.setView(n); added only in FG 2019
    setprop("/sim/current-view/view-number", n);
    setprop("/sim/current-view/view-number-raw", view.views[n].getIndex());

    # And pop up a nice reminder
    var popup=getprop("/sim/view-name-popup");
    if(popup == 1 or popup==nil) gui.popupTip(view.views[n].getNode("name").getValue());
}

var action_view_handler = {
  init : func {
    me.latN = props.globals.getNode("/sim/viewer/latitude-deg", 1);
    me.lonN = props.globals.getNode("/sim/viewer/longitude-deg", 1);
    me.altN = props.globals.getNode("/sim/viewer/altitude-ft", 1);
    me.vnN = props.globals.getNode("/velocities/speed-north-fps", 1);
    me.veN = props.globals.getNode("/velocities/speed-east-fps", 1);
    me.vdN = props.globals.getNode("/velocities/speed-down-fps", 1);
    me.hdgN = props.globals.getNode("/orientation/heading-deg", 1);

    setlistener("/sim/signals/reinit", func(n) { n.getValue() or me.reset() });
    setlistener("/sim/crashed", func(n) { n.getValue() and me.reset() });
    setlistener("/sim/freeze/replay-state", func {
      settimer(func { me.reset() }, 1); # time for replay to catch up
    });
    me.reset();
  },
  start : func {
    me.reset();
  },
  reset: func {
    me.chase = -getprop("/sim/chase-distance-m");
    # me.course = me.hdgN.getValue();
    var vn = me.vnN.getValue();
    var ve = me.veN.getValue();
    me.course = (0.5*math.pi - math.atan2(vn, ve))*R2D;
    
    me.last = geo.aircraft_position();
    me.setpos(1);
    # me.dist = 20;
  },
  setpos : func(force = 0) {
    var pos = geo.aircraft_position();
    var vn = me.vnN.getValue();
    var ve = me.veN.getValue();
    var vd = me.vdN.getValue();

    var dist = 0.0;
    if ( force ) {
        # predict distance based on speed
        var mps = math.sqrt( vn*vn + ve*ve ) * FT2M;
        dist = mps * 3.5; # 3.5 seconds worth of travel
    } else {
        # use actual distance
        dist = me.last.distance_to(pos);
        # reset when too far (i.e. position changed due to skipping time in replay mode)
        if (dist>5000) return me.reset();
    }

    # check if the aircraft has moved enough
    if (dist < 1.7 * me.chase and !force)
      return 1.13;

    # "predict" and remember next aircraft position
    # var course = me.hdgN.getValue();
    var course = (0.5*math.pi - math.atan2(vn, ve))*R2D;
    var delta_alt = (pos.alt() - me.last.alt()) * rand();
    pos.apply_course_distance(course, dist * 0.8);
    pos.set_alt(pos.alt() + delta_alt);
    me.last.set(pos);

    # apply random deviation
    var radius = me.chase * (3 * rand() + 0.7);
    var agl = getprop("/position/altitude-agl-ft") * FT2M;
    if (agl > me.chase)
      var angle = rand() * 2 * math.pi;
    else
      var angle = ((2 * rand() - 1) * 0.15 + 0.5) * (rand() < 0.5 ? -math.pi : math.pi);

    var dev_alt = math.cos(angle) * radius;
    var dev_side = math.sin(angle) * radius;
    pos.apply_course_distance(course + 90, dev_side);

    # and make sure it's not under ground
    var lat = pos.lat();
    var lon = pos.lon();
    var alt = pos.alt();
    var elev = geo.elevation(lat, lon);
    if (elev != nil) {
      elev += 2;   # min elevation
      if (alt + dev_alt < elev and dev_alt < 0)
        dev_alt = -dev_alt;
      if (alt + dev_alt < elev)
        alt = elev;
      else
        alt += dev_alt;
    }

    # set new view point
    me.latN.setValue(lat);
    me.lonN.setValue(lon);
    me.altN.setValue(alt * M2FT);
    return me.clamp(rand()*10,2,10);
  },
  clamp: func(v, min, max) {
   v < min ? min : v > max ? max : v
  },
  update : func {
    return me.setpos();
  },
};

view.manager.register("Fly-By View", action_view_handler);


var KIAStoGS = func (kt,ft) {
  return (0.02*(ft*0.001)+1)*kt;
}

var horiSpeed = func () {
  var e = getprop("velocities/speed-east-fps");
  var n = getprop("velocities/speed-north-fps");
  return math.sqrt(n*n+e*e)*FPS2KT;
}

setprop("ja37/normalmap", !getprop("sim/rendering/rembrandt/enabled"));
