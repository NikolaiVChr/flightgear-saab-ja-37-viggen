# $Id$
var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }

var FALSE = 0;
var TRUE = 1;

var mainOn = FALSE;
var mainTimer = -1;

var acPrev = 0;
var acTimer = 0;

var flareCount = -1;
var flareStart = -1;

############### Main loop ###############

var input = utils.property_map({
  aeroSmoke:        "/ja37/effect/smoke",
  aeroSmokeCmd:     "/ja37/effect/smoke-cmd",
  airspeed:         "velocities/airspeed-kt",
  alpha:            "orientation/alpha-deg",
  alt:              "position/altitude-ft",
  annunc_serv:      "ja37/avionics/annunciator/serviceable",
  apLockAlt:        "autopilot/locks/altitude",
  apLockHead:       "autopilot/locks/heading",
  apLockSpeed:      "autopilot/locks/speed",
  asymLoad:         "fdm/jsbsim/inertia/asymmetric-wing-load",
  #autoReverse:      "ja37/autoReverseThrust",
  buffOut:          "fdm/jsbsim/systems/flight/buffeting/output",
  cabinPressure:    "fdm/jsbsim/systems/flight/cabin-pressure-kpm2",
  canopyPos:        "fdm/jsbsim/fcs/canopy/pos-norm",
  canopyHinge:      "/fdm/jsbsim/fcs/canopy/hinges/serviceable",
  reload_allowed:   "/ja37/reload-allowed",
  cutoff:           "fdm/jsbsim/propulsion/engine/cutoff-commanded",
  damage:           "environment/damage",
  damageSmoke:      "ja37/effect/damage-smoke",
  dens:             "fdm/jsbsim/atmosphere/density-altitude",
  downFps:          "/velocities/down-relground-fps",
  elapsed:          "sim/time/elapsed-sec",
  elapsedInit:      "sim/time/elapsed-at-init-sec",
  elecMain:         "controls/electric/main",
  engineRunning:    "engines/engine/running",
  envVol:           "ja37/sound/environment-volume",
  flame:            "engines/engine/flame",
  flapPosCmd:       "/fdm/jsbsim/fcs/flaps/pos-cmd",
  fuelFeedTank:     "/consumables/fuel/tank[0]/level-norm",
  fullInit:         "sim/time/full-init",
  g3d:              "/velocities/groundspeed-3D-kt",
  gearSteerNorm:    "/gear/gear[0]/steering-norm",
  gearCmdNorm:      "/fdm/jsbsim/gear/gear-cmd-norm",
  gearsPos:         "gear/gear/position-norm",
  gravity:          "fdm/jsbsim/accelerations/gravity-ft_sec2",
  GVValpha:         "fdm/jsbsim/systems/sound/gvv/alpha-warning-level",
  GVVload:          "fdm/jsbsim/systems/sound/gvv/loadfactor-warning-level",
  GVVspeed:         "fdm/jsbsim/systems/sound/gvv/speed-warning",
  headshake:        "ja37/effect/headshake",
  heading:          "/instrumentation/heading-indicator/indicated-heading-deg",
  hz05:             "ja37/blink/five-Hz/state",
  hz10:             "ja37/blink/four-Hz/state",
  hzThird:          "ja37/blink/third-Hz/state",
  impact:           "/ai/models/model-impact",
  indAA:            "ja37/avionics/auto-altitude-on",
  indAH:            "ja37/avionics/auto-attitude-on",
  indAlt:           "/instrumentation/altitude-indicator",
  indAltFt:         "instrumentation/altimeter/indicated-altitude-ft",
  indAltMeter:      "instrumentation/altimeter/indicated-altitude-meter",
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
  land_warn_on:     "ja37/avionics/landing-warnings-enable",
  lockPassive:      "/autopilot/locks/passive-mode",
  mach:             "velocities/mach",
  MPbool4:          "sim/multiplay/generic/bool[4]",
  n1:               "/engines/engine/n1",
  n2:               "/engines/engine/n2",
  nearby:           "damage/sounds/nearby-explode-on",
  explode:          "damage/sounds/explode-on",
  pilotG:           "ja37/accelerations/pilot-G",
  pneumatic:        "fdm/jsbsim/systems/fuel/pneumatics/serviceable",
  rainNorm:         "environment/rain-norm",
  rainVol:          "ja37/sound/rain-volume",
  replay:           "sim/replay/replay-state",
  reversed:         "/engines/engine/is-reversed",
  roll:             "/instrumentation/attitude-indicator/indicated-roll-deg",
  sceneRed:         "/rendering/scene/diffuse/red",
  sceneRed2:        "/rendering/scene/diffuse/red-unbound",
  flameLowR:        "sim/model/ja37/effect/flame-low-color-r",
  flameLowG:        "sim/model/ja37/effect/flame-low-color-g",
  flameLowB:        "sim/model/ja37/effect/flame-low-color-b",
  flameHighR:       "sim/model/ja37/effect/flame-high-color-r",
  flameHighG:       "sim/model/ja37/effect/flame-high-color-g",
  flameHighB:       "sim/model/ja37/effect/flame-high-color-b",
  flameDensity:     "sim/model/ja37/effect/flame-density",
  servFire:         "engines/engine[0]/fire/serviceable",
  serviceElec:      "systems/electrical/serviceable",
  speedKt:          "/instrumentation/airspeed-indicator/indicated-speed-kt",
  speedTrueKt:      "fdm/jsbsim/velocities/vtrue-kts",
  speedMach:        "/instrumentation/airspeed-indicator/indicated-mach",
  starter:          "controls/engines/engine[0]/starter-cmd",
  subAmmo2:         "ai/submodels/submodel[2]/count", 
  subAmmo3:         "ai/submodels/submodel[3]/count", 
  sunAngle:         "sim/time/sun-angle-rad",
  taxiLight:        "ja37/effect/taxi-light",
  tempDegC:         "environment/temperature-degc",
  thrustLb:         "engines/engine/thrust_lb",
  thrustLbAbs:      "engines/engine/thrust_lb-absolute",
  vgFps:            "/fdm/jsbsim/velocities/vg-fps",
  viewInternal:     "sim/current-view/internal",
  viewName:         "sim/current-view/name",
  viewYOffset:      "sim/current-view/y-offset-m",
  defaultYOffset:   "sim/view[0]/config/y-offset-m",
  warnButton:       "ja37/avionics/master-warning-button",
  wow0:             "fdm/jsbsim/gear/unit[0]/WOW",
  wow1:             "fdm/jsbsim/gear/unit[1]/WOW",
  wow2:             "fdm/jsbsim/gear/unit[2]/WOW",
  zAccPilot:        "accelerations/pilot/z-accel-fps_sec",
  fuseGVV:          "ja37/fuses/gvv",
  inputCursor:      "controls/displays/stick-controls-cursor",
  terrainControls:  "fdm/jsbsim/systems/mkv/controls-warning",
  terrainSound:     "fdm/jsbsim/systems/mkv/ja-sound",
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
});

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

    # Properties to adjust color depending on scene light.
    var red = input.sceneRed.getValue();
    # Effect don't work well with tied properties. This is just a copy to work around that.
    input.sceneRed2.setValue(red);
    # Flame intensity
    input.flameLowR.setValue(0.863+(1-red));
    input.flameLowG.setValue(0.347+(1-red));
    input.flameLowB.setValue(0.238+(1-red));
    input.flameHighR.setValue(0.863+(1-red));
    input.flameHighG.setValue(0.238+(1-red));
    input.flameHighB.setValue(0.347+(1-red));
    input.flameDensity.setValue(math.clamp(1-red, 0.25, 1));


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

    #if(getprop("/sim/failure-manager/controls/flight/rudder/serviceable") == 1) {
    #  setprop("fdm/jsbsim/fcs/rudder/serviceable", 1);
    #} elsif (getprop("fdm/jsbsim/fcs/rudder/serviceable") == 1) {
    #  setprop("fdm/jsbsim/fcs/rudder-sum-stuck", getprop("fdm/jsbsim/fcs/rudder-sum"));
    #  setprop("fdm/jsbsim/fcs/rudder-serviceable", 0);
    #}

    # front gear compression calc for spinning of wheel
    # setprop("gear/gear/compression-wheel", (getprop("gear/gear/compression-ft")*0.3048-1.84812));

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

    # smoke
    if (power.prop.dcMainBool.getValue()) {
      input.aeroSmoke.setIntValue(input.aeroSmokeCmd.getValue());
    } else {
      input.aeroSmoke.setIntValue(1);
    }

    #if(!variant.JA and getprop("/instrumentation/radar/range") == 180000) {
    #  setprop("/instrumentation/radar/range", 120000);
    #}

    # ALS heat blur
    me.inv_speed = 100-getprop("velocities/airspeed-kt");
    setprop("velocities/airspeed-kt-inv", me.inv_speed);
    setprop("ja37/effect/heatblur/dens", clamp((getprop("engines/engine/n2")/100-getprop("velocities/airspeed-kt")/250)*0.035, 0, 1));

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
        if (variant.AJS) ground_panel.Dialog.close();
      }
      setprop("sim/freeze/fuel",0);
      setprop("/sim/speed-up", 1);
      setprop("/gui/map/draw-traffic", 0);
      setprop("/sim/gui/dialogs/map-canvas/draw-TFC", 0);
    }
  },

  # fast updating loop
  speed_loop: func {
    if(input.replay.getValue() == TRUE) {
      # replay is active, skip rest of loop.
      return;
    }

    me.n1 = input.n1.getValue();
    me.n2 = input.n2.getValue();
    me.reversed = input.reversed.getValue();

    # RWR
    rwr.loop();

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

    logTime();

    if (input.inputCursor.getBoolValue() and input.terrainControls.getValue()) {
      input.inputCursor.setBoolValue(FALSE);
      notice("Terrain warning made you grab the flight controls! Cursor inactive.");
    }

    if (input.parachuteDeploy.getValue() != nil) {
        input.parachuteForce.setDoubleValue(7-5*input.parachuteDeploy.getValue());
    } else {
      input.parachuteForce.setDoubleValue(7);
    }

    me.aural();
    me.flare();
  },

  flare: func {
    # Flare/chaff release
    var flareCmd = getprop("ai/submodels/submodel[0]/flare-release-cmd");
    if (flareCmd and !getprop("ai/submodels/submodel[0]/flare-release")
                 and !getprop("ai/submodels/submodel[0]/flare-release-out-snd")
                 and !getprop("ai/submodels/submodel[0]/flare-release-snd")
                 and input.gearsPos.getValue() == 0) {
      flareCount = getprop("ai/submodels/submodel[0]/count");
      flareStart = input.elapsed.getValue();
      if (flareCount > 0) {
        # release a flare
        setprop("ai/submodels/submodel[0]/flare-release-snd", TRUE);
        setprop("ai/submodels/submodel[0]/flare-release", TRUE);
        setprop("rotors/main/blade[3]/flap-deg", flareStart);
        setprop("rotors/main/blade[3]/position-deg", flareStart);
        damage.flare_released();
      } else {
        # play the sound for out of flares
        setprop("ai/submodels/submodel[0]/flare-release-out-snd", TRUE);
      }
    }
    setprop("ai/submodels/submodel[0]/flare-release-cmd", FALSE);
    if (getprop("ai/submodels/submodel[0]/flare-release-snd") == TRUE and (flareStart + 1.3) < input.elapsed.getValue()) {
      setprop("ai/submodels/submodel[0]/flare-release-snd", FALSE);# sound sample is 0.7s long
      setprop("rotors/main/blade[3]/flap-deg", 0);
      setprop("rotors/main/blade[3]/position-deg", 0);#MP interpolates between numbers, so nil is better than 0.
    }
    if (getprop("ai/submodels/submodel[0]/flare-release-out-snd") == TRUE and (flareStart + 2) < input.elapsed.getValue()) {
      setprop("ai/submodels/submodel[0]/flare-release-out-snd", FALSE);#sound sample is 1.4s long
    }
    if (flareCount > getprop("ai/submodels/submodel[0]/count")) {
      # A flare was released in last loop, we stop releasing flares, so user have to press button again to release new.
      setprop("ai/submodels/submodel[0]/flare-release", FALSE);
      flareCount = -1;
    }
  },

  aural: func {
    if (!variant.JA) {
      # AJS only has high alpha sound warning
      input.toneGVV.setBoolValue(
        power.prop.dcMainBool.getBoolValue()
        and input.annunc_serv.getBoolValue()
        and input.GVValpha.getValue() == 3
      );
      return;
    }

    # CK37 issued aural warnings (minus master-warning, as its played seperate)
    #
    # at MKV ground collision warning the load-factor warning is force set at 110. (until 10 secs after)
    me.warnGiven = 0;
    if (!power.prop.dcMainBool.getValue() or !input.annunc_serv.getBoolValue()) {
      me.warnGiven = 1;
    }
    if (!me.warnGiven and input.terrainSound.getBoolValue()) {
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
    if (!me.warnGiven and (input.GVValpha.getValue() == 3 or input.GVVload.getValue() == 3 or input.GVVspeed.getBoolValue())) {
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
    if (me.floor != getprop("ja37/sound/floor-ft")) {
        me.floor = getprop("ja37/sound/floor-ft");
        me.floor_armed = 0;
    }

    if (input.indAltFt.getValue() >= me.floor) {
      if (me.floor_armed == 0) me.floor_armed = 1;  # arm
    } else {
      if (me.floor_armed == 1) me.floor_armed = 2;  # play sound when possible
    }

    if (!me.warnGiven and me.floor > 0 and me.floor_armed == 2 and !input.land_warn_on.getBoolValue()) {
      input.toneFloor.setBoolValue(1);
      me.warnGiven = 1;
      me.floorPlaying = 1;
      me.floor_armed = 0;
      settimer(func {me.floorTimed()},4);
    }
    if (!me.warnGiven and input.GVValpha.getValue() == 2) {
      input.tonePreA2.setBoolValue(1);
      me.warnGiven = 1;
    } else {
      input.tonePreA2.setBoolValue(0);
    }
    if (!me.warnGiven and input.GVValpha.getValue() == 1) {
      input.tonePreA1.setBoolValue(1);
      me.warnGiven = 1;
    } else {
      input.tonePreA1.setBoolValue(0);
    }
    if (!me.warnGiven and input.GVVload.getValue() == 2) {
      input.tonePreL2.setBoolValue(1);
      me.warnGiven = 1;
    } else {
      input.tonePreL2.setBoolValue(0);
    }
    if (!me.warnGiven and input.GVVload.getValue() == 1) {
      input.tonePreL1.setBoolValue(1);
      me.warnGiven = 1;
    } else {
      input.tonePreL1.setBoolValue(0);
    }
  },
  
  floorPlaying: 0,
  floor: 0,
  floor_armed: 0,
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

    if (view.index != 0) return;

    if (((me.G > 7 or me.alpha>4.5) and me.rSpeed>30) or (me.mach>0.97 and me.mach<1.05) or (me.wow and me.rSpeed>100) or me.near == TRUE or me.explode == TRUE) {
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
    } else {
      me.factor = 0;
    }
    setprop("ja37/effect/buffeting", me.factor);
    if (input.headshake.getBoolValue()) {
      defaultView = input.defaultYOffset.getValue();
      input.viewYOffset.setDoubleValue(defaultView+input.buffOut.getValue()*me.factor);
    }
  },

  # slow updating loop
  slow_loop: func(dt) {
    if(input.replay.getValue() == TRUE) {
      # replay is active, skip rest of loop.
      return;
    }


    if (getprop("sim/replay/replay-state") == 0 and power.prop.dcSecondBool.getValue()) {
      setprop("ja37/avionics/record-on", TRUE);
    } else {
      setprop("ja37/avionics/record-on", FALSE);
    }

    # terrain profile map
    if (variant.JA) elev.loop();

    me.environment(dt);

    # consume oxygen bottle pressure
    if (getprop("controls/oxygen") == TRUE) {
      me.amount = getprop("ja37/systems/oxygen-bottle-pressure")-127/(27000/dt);#7.5 hours to consume all 127 kpm2
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

    if (input.inputCursor.getBoolValue() and rand() > 0.95) {
      ja37.notice("Flight ctrls OFF. Press key 'y' to reactivate.");
    }
  },

  environment: func(dt) {
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
      me.tempInside += me.hotAirOnWindshield * (me.hotAir_deg_min/(60/dt)); # having hot air on windshield will also heat cockpit (10 degs/5 mins).
      if (me.tempInside < 37) {
        me.tempInside += me.pilot_deg_min/(60/dt); # pilot will also heat cockpit with 1 deg per 5 mins
      }
      # outside temp ram air temp and static temp will influence inside temp:
      me.coolingFactor = ((me.tempOutside+getprop("environment/temperature-degc"))*0.5-me.tempInside)*me.glass_deg_min_per_deg_diff/(60/dt);# 1 degrees difference will cool/warm with 0.5 DegCelsius/min
      me.tempInside += me.coolingFactor;
      if (me.ACRunning) {
        # AC is running and will work to influence the inside temperature
        me.tempInside += (me.tempAC-me.tempInside)*me.AC_deg_min_per_deg_diff/(60/dt);# (tempAC-tempInside) = degs/mins it should change
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

  startSystem: func {
    # aircraft/display modes
    modes.initialize();
    modes.update();

    # flightplans
    if (variant.JA) route.poly_start();
    else route.init();

    # displays commons
    displays.common.loop();
    displays.common.loopFast();

    # radar
    radar.init();
    rwr.init();

    fire_control.init();

    callsign.callInit();

    # Radios
    channels.init();
    if (variant.JA) freq_sel.init();

    if (!variant.JA) {
      # CI display
      ci.init();
    }

    if (variant.JA) {
      # TI
      # must not start looping before route has been init
      TI.setupCanvas();
      TI.ti = TI.TI.new();
      TI.ti.loop();#must be first due to me.rootCenterY

      # MI
      # must be after TI
      MI.setupCanvas();
      MI.mi = MI.MI.new();
    }

    # HUD:
    hud.initialize();

    if (variant.JA) {
      # data-panel
      dap.callInit();
      # fighterlink
      fighterlink.init();
      # terrain profile map
      elev.init();
    }

    # Old ALS landing/taxi lights
    if (!getprop("/ja37/supported/compositor")) lm.light_manager.init();

    # Startall the loops
    scheduler.start();
  },
};

var saab37 = Saab37.new();















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
var lexi_compare = func (v1, v2) {
  var s1 = size(v1);
  var s2 = size(v2);
  var s = math.min(s1, s2);
  for (var i=0; i<s; i+=1) {
    if (v1[i] < v2[i]) return -1;
    elsif (v1[i] > v2[i]) return 1;
  }

  if (s1 < s2) return -1;
  elsif (s1 > s2) return 1;
  else return 0;
}

var test_support = func {
 
  var versionString = getprop("sim/version/flightgear");
  var minVersionString = getprop("sim/minimum-fg-version");
  var version = split(".", versionString);
  var minVersion = split(".", minVersionString);

  setprop("ja37/supported/compositor", lexi_compare(version, [2020,4,0]) >= 0);
  setprop("ja37/supported/canvas-arcs", lexi_compare(version, [2020,4,0]) >= 0);

  if (lexi_compare(version, minVersion) < 0) {
    notice("Minimum supported Flightgear version for Saab 37 is "~minVersionString);
    notice("Some functionalities will not work as expected");
  }

  setprop("ja37/supported/initialized", TRUE);

  print();
  print("***************************************************************");
  print("         Initializing "~getprop("sim/description")~" systems.");
  print("           Version "~getprop("sim/aircraft-version")~" on Flightgear "~versionString);
  print("***************************************************************");
  print();
}

############################# random cockpit state for cold start ######

var rand_bool = func (p=0.5) {
  return rand() < p;
}
var rand_int = func (min, max, step) {
  return min + math.floor(rand() * ((max - min)/step + 1)) * step;
}
var rand_double = func (min, max) {
  return min + rand() * (max - min);
}

# Random switches in the cockpit. Value is probability that it is on.
var random_switches = {
  "controls/electric/lights-ext-beacon": 0.5,
  "controls/electric/lights-ext-form": 0.5,
  "controls/altimeter-radar": 0.5,
  "controls/electric/engine[0]/generator": 0.5,
  "controls/engines/engine/reverser-cmd": 0.3,
  "instrumentation/transponder/switch-power": 0.5,
  "instrumentation/transponder/switch-mode": 0.5,
  "instrumentation/comm[0]/transmitter": 0.5,
  # Not used under normal operation: usual position with high probability.
  "controls/ventilation/airconditioning-enabled": 0.9,
  "controls/fuel/auto": 0.9,
  "controls/fuel/tank-pump": 0.9,
  "controls/engines/engine[0]/cutoff-augmentation": 0.1,
  "controls/electric/reserve": 0.1,
  "fdm/jsbsim/fcs/elevator/gearing-enable": 0.9,
  "controls/engines/engine[0]/deice": 0.3,
};

# Variant specific switches
if (variant.JA) {
  random_switches["ja37/avionics/collision-warning"] = 0.5;
} else {
  random_switches["ja37/hud/switch-hojd"] = 0.5;
  random_switches["ja37/hud/switch-slav"] = 0.5;
}

var random_multipos = {
  "controls/electric/lights-ext-nav": [-1,1],
  "controls/electric/lights-land-switch": [-1,1],
  "controls/electric/lights-ext-form-bright": [0,3],
  "instrumentation/radio/mode": [0,7],
  "instrumentation/fr22/frequency-10mhz": [10,39],
  "instrumentation/fr22/frequency-1mhz": [0,9],
  "instrumentation/fr22/frequency-100khz": [0,9],
  "instrumentation/fr22/frequency-1khz": [0,75,25],
  "instrumentation/fr22/button-selected": [0,19],
  "instrumentation/fr22/group": [1,41],
  "instrumentation/fr22/base-knob": [0,83],
  "instrumentation/kv1/button-selected": [0,2],
  "instrumentation/iff/power-knob": [0,2],
  "instrumentation/iff/channel": [1,11],
  "instrumentation/datalink/channel": [0,999],
  "instrumentation/datalink/ident": [0,9],
};

var random_continuous = {
  "controls/lighting/flood-knob": [0,1],
  "controls/lighting/instruments-knob": [0,1],
  "controls/ventilation/airconditioning-temperature": [15,26],
  "controls/ventilation/windshield-hot-air-knob": [0,1],
  "instrumentation/altimeter/setting-hpa": [990,1030],
  "instrumentation/altimeter[1]/setting-hpa": [990,1030],
};

var random_cockpit_state = func {
  foreach (var prop; keys(random_switches)) {
    setprop(prop, rand_bool(random_switches[prop]));
  }
  foreach (var prop; keys(random_multipos)) {
    var step = size(random_multipos[prop]) == 3 ? random_multipos[prop][2] : 1;
    setprop(prop, rand_int(random_multipos[prop][0], random_multipos[prop][1], step));
  }
  foreach (var prop; keys(random_continuous)) {
    setprop(prop, rand_double(random_continuous[prop][0], random_continuous[prop][1]));
  }

  # Parking brake needs special code to release.
  if (rand_bool()) setParkingBrake(0);
}

############################# main init ###############


var main_init = func {
  srand();
  
  setprop("sim/time/elapsed-at-init-sec", getprop("sim/time/elapsed-sec"));

  # Hint to MP server for how far away MP planes should transmit to this aircraft.
  # Increased 100->200 for the S-200 (needs to be at least the missile range, which is ~160)
  # Do NOT set this property in -set.xml, FG overrides it at startup.
  setprop("/sim/multiplay/visibility-range-nm", 200);

  test_support();

  hack.init();
  #setprop("ja37/avionics/master-warning-button", 0);# for when starting up with engines running, to prevent master warning.

  #aircraft.data.save();
  aircraft.data.save(0.5);#every 30 seconds



  # define the locks since they otherwise start with some undefined value I cannot test on.
  setprop("/autopilot/locks/speed", "");
  setprop("/autopilot/locks/heading", "");
  setprop("/autopilot/locks/altitude", "");

  setprop("/consumables/fuel/tank[8]/jettisoned", FALSE);

  # Load exterior at startup to avoid stale sim at first external view selection. ( taken from TU-154B )
  logprint(LOG_INFO, "Loading exterior, wait...");
  # return to cabin to next cycle
  settimer(load_interior, 0.5, 1);
  view.setViewByIndex(1);
  setprop("/sim/gui/tooltips-enabled", TRUE);
  
  # inst. light

  setprop("/instrumentation/instrumentation-light/r", 1.0);
  setprop("/instrumentation/instrumentation-light/g", 0.3);
  setprop("/instrumentation/instrumentation-light/b", 0.0);

  screen.log.write("Welcome to "~getprop("sim/description")~", version "~getprop("sim/aircraft-version"), 1.0, 0.2, 0.2);

  # init cockpit temperature
  setprop("environment/aircraft-effects/temperature-inside-degC", getprop("environment/temperature-degc"));
  setprop("/environment/aircraft-effects/dewpoint-inside-degC", getprop("environment/dewpoint-degc"));

  # init oxygen bottle pressure
  setprop("ja37/systems/oxygen-bottle-pressure", 127);# 127 kp/cm2 as per manual

  # asymmetric vortex detachment
  asymVortex();

  # Setup lightning listener
  setlistener("/environment/lightning/lightning-pos-y", thunder_listener);

  var state = getprop("ja37/systems/state");

  if(state == "parked") {
    random_cockpit_state();
  }

  # start the main loop
  saab37.startSystem();

  # Starting with all systems on.
  if (getprop("/ja37/avionics/init-done")) {
    mainTimer = -100;
    mainOn = TRUE;
  }

  # Initialize state of nasal systems when starting in the air.
  if (state == "cruise") {
    modes.nav_init();
    autoflight.System.engageMode(2);
    # JSBSim autopilot needs a bit of time before selecting altitude hold.
    # Otherwise target altitude is 0.
    settimer(func {autoflight.System.engageMode(3);}, 0);
  }
  if (state == "approach") {
    modes.landing_init();
    autoflight.System.engageMode(2);
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


# re init
var re_init = func {
  if (getprop("/sim/signals/reinit")==0) {return;}
  logprint(LOG_INFO, "Re-initializing Saab 37 Viggen systems");
  
  setprop("sim/time/elapsed-at-init-sec", getprop("sim/time/elapsed-sec"));

  # init oxygen bottle pressure
  setprop("ja37/systems/oxygen-bottle-pressure", 127);# 127 kp/cm2 as per manual
  logprint(LOG_INFO, "Reinit: Oxygen replenished.");
  # asymmetric vortex detachment
  asymVortex();
  repair();
  autoflight.System.engageMode(0);
  setprop("/controls/gear/gear-down", 1);
  setParkingBrake(1);
  setprop("ja37/done",0);
  view.setViewByIndex(0);
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
  logprint(LOG_INFO, "Init: Battery fully recharged.");
}

var asymVortex = func () {
  if(rand() > 0.5) {
    setprop("fdm/jsbsim/aero/function/vortex", 1);
  } else {
    setprop("fdm/jsbsim/aero/function/vortex", -1);
  }
}

var load_interior = func {
    view.setViewByIndex(0);
    logprint(LOG_INFO, "..Done!");
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
      setprop("/controls/gear/chocks", TRUE);
      setprop("fdm/jsbsim/systems/electrical/external/available", TRUE);
      notice("Autostarting..");
      setParkingBrake(1);
      setprop("fdm/jsbsim/fcs/canopy/engage", FALSE);
      setprop("controls/ventilation/airconditioning-enabled", TRUE);
      setprop("controls/ventilation/airconditioning-temperature", 18);
      setprop("controls/ventilation/windshield-hot-air-knob", 0);
  	  settimer(startSupply, 1.5, 1);
    }
  }
}

var stopAutostart = func {
  if (!variant.JA) setprop("/ja37/mode/selector-ajs", 1); # STBY
  setprop("/controls/electric/main", FALSE);
  setprop("/controls/engines/engine/throttle", 0);
  settimer(stopFinal, 5, 1);#allow time for ram air and flaps to retract
}

var stopFinal = func {
  setprop("/controls/engines/engine/throttle", 0);
  setprop("/controls/engines/engine/throttle-cutoff", TRUE);
  setprop("fdm/jsbsim/propulsion/engine/cutoff-commanded", TRUE);
  setprop("/controls/engines/engine[0]/starter-cmd", FALSE);
  setprop("/controls/engines/engine[0]/starter-cmd-hold", FALSE);
  setprop("/controls/electric/engine[0]/generator", FALSE);
  setprop("fdm/jsbsim/systems/electrical/external/available", FALSE);
  autostarting = FALSE;
}

var startSupply = func {
  if (getprop("fdm/jsbsim/systems/electrical/external/available") == TRUE) {
    # using ext. power
    click();
    setprop("/controls/electric/main", TRUE);
    setprop("controls/electric/reserve", FALSE);
    notice("Enabling power using external supply.");
    settimer(endSupply, 1.5, 1);
  } elsif (getprop("ja37/elec/dc-bus-battery-3-volt") > 20) {
    # using battery
    click();
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
  setprop("controls/engines/engine/reverser-cmd", FALSE);
  setprop("controls/fuel/auto", TRUE);
  setprop("controls/altimeter-radar", TRUE);
  setprop("ja37/avionics/collision-warning", TRUE);
  setprop("fdm/jsbsim/fcs/elevator/gearing-enable", TRUE);
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
  setprop("controls/electric/lights-ext-form-bright", 3);
  setprop("controls/lighting/flood-knob", 0.5);
  setprop("controls/lighting/instruments-knob", 0.5);
  setprop("instrumentation/transponder/switch-power", TRUE);
  setprop("instrumentation/transponder/switch-mode", TRUE);
  setprop("instrumentation/iff/power-knob", 1);
  setprop("ja37/hud/switch-hojd", FALSE);
  setprop("ja37/hud/switch-slav", FALSE);
  setprop("ja37/hud/brightness-si", 0.5);
  setprop("/instrumentation/altimeter/setting-std", 0);
  setprop("/instrumentation/altimeter/setting-inhg", getprop("/environment/pressure-inhg"));
  setprop("/instrumentation/altimeter[1]/setting-inhg", getprop("/environment/pressure-inhg"));
  setprop("/controls/electric/engine[0]/generator", FALSE);
  notice("Starting engine..");
  click();
  setprop("fdm/jsbsim/propulsion/engine/cutoff-commanded", FALSE);
  setprop("/controls/engines/engine/throttle-cutoff", FALSE);
  setprop("/controls/engines/engine/throttle", 0);
  setprop("/controls/engines/engine/cutoff-augmentation", FALSE);
  setprop("/controls/engines/engine[0]/starter-cmd-hold", TRUE);
  setprop("/controls/engines/engine[0]/starter-cmd", TRUE);
  start_count = 0;
  settimer(waiting_n1, 0.5, 1);
}

# Opens fuel valve in autostart
var waiting_n1 = func {
  start_count += 1* getprop("sim/speed-up");
  #print(start_count);
  if (start_count > 55) {
    if(input.fuelFeedTank.getValue() < 0.01) {
      notice("Engine start failed. Check fuel.");
    } elsif (!power.prop.dcSecondBool.getValue()) {
      notice("Engine start failed. Check battery.");
    } else {
      notice("Autostart failed.");
    }
    logprint(DEV_WARN, "Autostart failed. n1="~getprop("/engines/engine[0]/n1")~" cutoff="~getprop("fdm/jsbsim/propulsion/engine/cutoff-commanded")~" starter="~getprop("/controls/engines/engine[0]/starter")~" generator="~getprop("/controls/electric/engine[0]/generator")~" battery="~getprop("/controls/electric/main")~" fuel="~getprop("/instrumentation/fuel/ratio"));
    stopAutostart();
  } elsif (getprop("/engines/engine[0]/n1") > 4.9) {
    if (getprop("/engines/engine[0]/n1") < 20) {
      if (getprop("/controls/engines/engine[0]/starter-cmd-hold") == TRUE) {
        click();
        setprop("/controls/engines/engine[0]/starter-cmd-hold", FALSE);
        setprop("/controls/engines/engine/throttle-cutoff", FALSE);
        setprop("/controls/engines/engine/throttle", 0);
        notice("Engine igniting.");
        settimer(waiting_n1, 0.5, 1);
      } else {
        settimer(waiting_n1, 0.5, 1);
      }
    }  elsif (getprop("/engines/engine[0]/n1") > 10 and getprop("/controls/engines/engine[0]/starter-cmd-hold") == FALSE) {
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
  if (start_count > 80) {
    if(input.fuelFeedTank.getValue() < 0.01) {
      notice("Engine start failed. Check fuel.");
    } elsif (!power.prop.dcSecondBool.getValue()) {
      notice("Engine start failed. Check battery.");
    } else {
      notice("Autostart failed.");
    }
    logprint(DEV_WARN, "Autostart failed 3. n1="~getprop("/engines/engine[0]/n1")~" cutoff="~getprop("fdm/jsbsim/propulsion/engine/cutoff-commanded")~" starter="~getprop("/controls/engines/engine[0]/starter")~" generator="~getprop("/controls/electric/engine[0]/generator")~" battery="~getprop("/controls/electric/main")~" fuel="~~getprop("/instrumentation/fuel/ratio"));
    stopAutostart();
  } elsif (getprop("/engines/engine[0]/running") > FALSE) {
    notice("Engine ready.");
    setprop("/controls/gear/chocks", FALSE);
    setprop("fdm/jsbsim/systems/electrical/external/available", FALSE);
    if (variant.JA) {
        displays.common.toggleJAdisplays(TRUE);
    } else {
        setprop("/ja37/mode/selector-ajs", 2); # NAV
    }
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

# Override default function
controls.applyParkingBrake = func(v) {
  # /controls/gear/brake-parking indicates that the pilot is pulling the handle.
  # /controls/gear/brake-parking-handle is the actual position of the handle
  setprop("/controls/gear/brake-parking", v);
  if (!v) return;

  if (!getprop("/controls/gear/brake-parking-handle")) {
    # Parking brake currently not set
    ja37.click();
    if (getprop("/controls/gear/brake-left") < 0.6 or getprop("/controls/gear/brake-left") < 0.6) {
      notice("Press brakes then pull the handle to set parking brake");
    }
  } else {
    # Parking brake currently set
    notice("Press brakes to release parking brake");
  }
}

# Function to magically set/unset parking brake in scripts.
var setParkingBrake = func(v) {
  setprop("/controls/gear/brake-parking", 0);
  # Set internal state of parking brake logic. See jsb-controls.xml for details.
  setprop("/fdm/jsbsim/fcs/brake/parking-brake-state", v ? 2 : 0);
}


var toggleChocks = func {
  var c = !getprop("/controls/gear/chocks");
  setprop("/controls/gear/chocks", c);
  notice("Chocks "~(c ? "placed" : "removed"));
}

var toggleExternalPower = func {
  var p = !getprop("fdm/jsbsim/systems/electrical/external/available");
  setprop("fdm/jsbsim/systems/electrical/external/available", p);
  notice("External power "~(p ? "connected" : "disconnected"));
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

# Seat movement parameters (y-axis)
var seat_min = 0.6;
var seat_max = 0.8;
var seat_step = 0.0025;

var move_seat = func(dir) {
  # Apply seat movement to default view y position, clamped.
  var step = seat_step * (dir > 0 ? 1 : -1);
  var old_pos = input.defaultYOffset.getValue();
  var pos = math.clamp(old_pos + step, seat_min, seat_max);
  input.defaultYOffset.setValue(pos);
  step = pos - old_pos; # Clamped movement

  # Apply same (clamped) movement to actual y position, when in pilot view.
  if (view.index != 0) return;

  input.viewYOffset.setValue(input.viewYOffset.getValue() + step);
}


# Button on throttle. Gear up on AJS: IR quick select, otherwise: A/T disengage.
var selectIR_disengageAT = func() {
  if (variant.JA or input.gearsPos.getValue() > 0) {
    autoflight.System.athrQuickDisengage();
  } else {
    fire_control.quick_select_missile();
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
    view.setViewByIndex(0);
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
  if (getprop("sim/current-view/view-number-raw") == 0) {
    var hd = getprop("sim/current-view/heading-offset-deg");
    var hd_t = getprop("sim/current-view/config/heading-offset-deg");
    if (hd > 180) {
      hd_t = hd_t + 360;
    }
    interpolate("sim/current-view/field-of-view", 55, 0.66);
    interpolate("sim/current-view/heading-offset-deg", hd_t,0.66);
    interpolate("sim/current-view/pitch-offset-deg", -36,0.66);
    interpolate("sim/current-view/roll-offset-deg", getprop("sim/current-view/config/roll-offset-deg"),0.66);
    interpolate("sim/current-view/x-offset-m", 0, 1); 
  }
}

var HUDView = func () {
  if (getprop("sim/current-view/view-number-raw") == 0) {
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


setprop("ja37/normalmap", !getprop("sim/rendering/rembrandt/enabled"));
