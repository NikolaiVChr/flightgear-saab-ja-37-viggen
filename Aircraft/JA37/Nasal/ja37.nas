# $Id$
var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }
var encode3bits = func(first, second, third) {
  var integer = first;
  integer = integer + 2 * second;
  integer = integer + 4 * third;
  return integer;
}

var UPDATE_PERIOD = 0.1;

var FALSE = 0;
var TRUE = 1;

var prevGear0 = TRUE;
var prevGear1 = TRUE;
var prevGear2 = TRUE;
var touchdown1 = FALSE;
var touchdown2 = FALSE;
var total_fuel = 0;
var bingoFuel = FALSE;

var warnEngineOff = TRUE;
var warnCanopy = TRUE;
var warnGenerator = TRUE;
var warnHydr1 = TRUE;
var warnHydr2 = TRUE;
var warnCabin = TRUE;

var mainOn = FALSE;
var mainTimer = -1;

var MISSILE_STANDBY = -1;
var MISSILE_SEARCH = 0;
var MISSILE_LOCK = 1;
var MISSILE_FLYING = 2;
############### Main loop ###############

input = {
  replay:           "sim/replay/replay-state",
  g3d:              "/velocities/groundspeed-3D-kt",
  wow0:             "/gear/gear[0]/wow",
  wow1:             "/gear/gear[1]/wow",
  wow2:             "/gear/gear[2]/wow",
  elapsed:          "sim/time/elapsed-sec",
  elapsedInit:      "sim/time/elapsed-at-init-sec",
  fullInit:         "sim/time/full-init",
  tank0LvlNorm:     "/consumables/fuel/tank[0]/level-norm",
  tank8LvlNorm:     "/consumables/fuel/tank[8]/level-norm",
  tank0LvlGal:      "/consumables/fuel/tank[0]/level-gal_us",
  tank1LvlGal:      "/consumables/fuel/tank[1]/level-gal_us",
  tank2LvlGal:      "/consumables/fuel/tank[2]/level-gal_us",
  tank3LvlGal:      "/consumables/fuel/tank[3]/level-gal_us",
  tank4LvlGal:      "/consumables/fuel/tank[4]/level-gal_us",
  tank5LvlGal:      "/consumables/fuel/tank[5]/level-gal_us",
  tank6LvlGal:      "/consumables/fuel/tank[6]/level-gal_us",
  tank7LvlGal:      "/consumables/fuel/tank[7]/level-gal_us",
  tank8LvlGal:      "/consumables/fuel/tank[8]/level-gal_us",
  fuelNeedleB:      "/instrumentation/fuel/needleB_rot",
  fuelNeedleF:      "/instrumentation/fuel/needleF_rot",
  fuelRatio:        "/instrumentation/fuel/ratio",
  fuelWarning:      "sim/ja37/sound/fuel-low-on",
  n1:               "/engines/engine/n1",
  n2:               "/engines/engine/n2",
  reversed:         "/engines/engine/reversed",
  augmentation:     "/controls/engines/engine[0]/augmentation",
  gearCmdNorm:      "/fdm/jsbsim/gear/gear-cmd-norm",
  gearsPos:         "gear/gear/position-norm",
  dcVolt:           "systems/electrical/outputs/dc-voltage",
  acInstrVolt:      "systems/electrical/outputs/ac-instr-voltage",
  acMainVolt:       "systems/electrical/outputs/ac-main-voltage",
  serviceElec:      "systems/electrical/serviceable",
  flapPosCmd:       "/fdm/jsbsim/fcs/flaps/pos-cmd",
  vgFps:            "/fdm/jsbsim/velocities/vg-fps",
  downFps:          "/velocities/down-relground-fps",
  thrustLb:         "engines/engine/thrust_lb",
  thrustLbAbs:      "engines/engine/thrust_lb-absolute",
  indAltMeter:      "instrumentation/altimeter/indicated-altitude-meter",
  indAltFt:         "instrumentation/altimeter/indicated-altitude-ft",
  rad_alt:          "position/altitude-agl-ft",
  autoReverse:      "sim/ja37/autoReverseThrust",
  stationSelect:    "controls/armament/station-select",
  combat:           "/sim/ja37/hud/current-mode",
  warnButton:       "sim/ja37/avionics/master-warning-button",
  warn:             "/instrumentation/master-warning",
  master:           "sim/ja37/sound/master-on",
  engineRunning:    "engines/engine/running",
  hz10:             "sim/ja37/blink/ten-Hz/state",
  hz05:             "sim/ja37/blink/five-Hz/state",
  hzThird:          "sim/ja37/blink/third-Hz/state",
  flame:            "engines/engine/flame",
  mass1:            "fdm/jsbsim/inertia/pointmass-weight-lbs[1]",
  mass3:            "fdm/jsbsim/inertia/pointmass-weight-lbs[3]",
  asymLoad:         "fdm/jsbsim/inertia/asymmetric-wing-load",
  indJoy:           "/instrumentation/joystick-indicator",
  indAtt:           "/instrumentation/attitude-indicator",
  indAlt:           "/instrumentation/altitude-indicator",
  indTrn:           "/instrumentation/transonic-indicator",
  indRev:           "/instrumentation/reverse-indicator",
  tank8Flow:        "fdm/jsbsim/propulsion/tank[8]/external-flow-rate-pps",
  tank8Selected:    "/consumables/fuel/tank[8]/selected",
  tank8Jettison:    "/consumables/fuel/tank[8]/jettisoned",
  lockHeading:      "/autopilot/locks/heading",
  lockAltitude:     "/autopilot/locks/altitude",
  lockPassive:      "/autopilot/locks/passive-mode",
  roll:             "/instrumentation/attitude-indicator/indicated-roll-deg",
  speedMach:        "/instrumentation/airspeed-indicator/indicated-mach",
  speedKt:          "/instrumentation/airspeed-indicator/indicated-speed-kt",
  TILS:             "sim/ja37/hud/TILS",
  pilotG:           "sim/ja37/accelerations/pilot-G",
  zAccPilot:        "accelerations/pilot/z-accel-fps_sec",
  gravity:          "fdm/jsbsim/accelerations/gravity-ft_sec2",
  trigger:          "controls/armament/trigger",
  landLightSwitch:  "controls/electric/lights-land-switch",
  landLight:        "sim/ja37/effect/landing-light",
  landLightSupport: "sim/ja37/supported/landing-light",
  landLightALS:     "sim/rendering/als-secondary-lights/use-landing-light",
  viewInternal:     "sim/current-view/internal",
  sunAngle:         "sim/time/sun-angle-rad",
  MPfloat2:         "sim/multiplay/generic/float[2]",
  MPfloat9:         "sim/multiplay/generic/float[9]",
  MPint9:           "sim/multiplay/generic/int[9]",
  MPint17:          "sim/multiplay/generic/int[17]",
  MPint18:          "sim/multiplay/generic/int[18]",
  subAmmo2:         "ai/submodels/submodel[2]/count", 
  subAmmo3:         "ai/submodels/submodel[3]/count", 
  breathVol:        "sim/ja37/sound/breath-volume",
  impact:           "/ai/models/model-impact",
  fdmAug:           "fdm/jsbsim/propulsion/engine/augmentation",
  hydr1On:          "fdm/jsbsim/systems/hydraulics/system1/pressure",
  hydr2On:          "fdm/jsbsim/systems/hydraulics/system2/pressure-main",
  hydrCombined:     "fdm/jsbsim/systems/hydraulics/flight-surface-actuation",
  lampFuelDistr:    "sim/ja37/avionics/uppf",
  canopyPos:        "canopy/position-norm",
  speedWarn:        "sim/ja37/sound/speed-on",
  cabinPressure:    "fdm/jsbsim/systems/flight/cabin-pressure-kpm2",
  elecMain:         "controls/electric/main",
  lampData:         "sim/ja37/avionics/primaryData",
  lampInertiaNav:   "sim/ja37/avionics/TN",
  lampStart:        "sim/ja37/avionics/startSys",
  cutoff:           "controls/engines/engine[0]/cutoff",
  lampIgnition:     "sim/ja37/avionics/ignitionSys",
  starter:          "controls/engines/engine[0]/starter-cmd",
  lampXTank:        "sim/ja37/avionics/xtank",
  lampStick:        "sim/ja37/avionics/joystick",
  lampOxygen:       "sim/ja37/avionics/oxygen",
  generatorOn:      "fdm/jsbsim/systems/electrical/generator-running-norm",
  lampCanopy:       "sim/ja37/avionics/canopyAndSeat",
  pneumatic:        "fdm/jsbsim/systems/fuel/pneumatics/serviceable",
  switchFlash:      "controls/electric/lights-ext-flash",
  switchBeacon:     "controls/electric/lights-ext-beacon",
  switchNav:        "controls/electric/lights-ext-nav",
};
   
var update_loop = func {

  # Stuff that will run even in replay:

  # breath sound volume
  input.breathVol.setValue(input.viewInternal.getValue() and input.fullInit.getValue());

  #augmented flame translucency
  var red = getprop("/rendering/scene/diffuse/red");
  # normal effect
  #var angle = input.sunAngle.getValue();# 1.25 - 2.45
  #var newAngle = (1.2 -(angle-1.25))*0.8333;
  #input.MPfloat2.setValue(newAngle);
  var translucency = clamp(red, 0.35, 1);
  input.MPfloat2.setValue(translucency);

  # ALS effect
  red = clamp(1 - red, 0.25, 1);
  input.MPfloat9.setValue(red);

  # End stuff

  if(input.replay.getValue() == TRUE) {
    # replay is active, skip rest of loop.
    settimer(update_loop, UPDATE_PERIOD);
  } else {
    # set the full-init property
    if(input.elapsed.getValue() > input.elapsedInit.getValue() + 5) {
      input.fullInit.setValue(TRUE);
    } else {
      input.fullInit.setValue(FALSE);
    }

  	 ## Sets fuel gauge needles rotation ##
  	 
     if(input.tank8LvlNorm.getValue() != nil) {
       input.fuelNeedleB.setValue(input.tank8LvlNorm.getValue()*230);
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


    input.fuelNeedleF.setValue((current / total_fuel) *230);
    input.fuelRatio.setValue(current / total_fuel);

    # fuel warning annuciator
    if((current / total_fuel) < 0.24) {# warning at 24% as per sources
      input.fuelWarning.setValue(TRUE);
    } else {
      input.fuelWarning.setValue(FALSE);
    }

    if((current / total_fuel) > 0.40) {
      # fuel flow distributor lamp
      input.lampFuelDistr.setValue(TRUE);
    } else {
      input.lampFuelDistr.setValue(FALSE);
    }

    if (current > 0 and input.tank8LvlNorm.getValue() > 0) {
      bingoFuel = FALSE;
    } else {
      bingoFuel = TRUE;
    }

    if (input.tank0LvlNorm.getValue() == 0) {
      # a bug in JSB makes NaN on fuel temp if tank has been empty.
      setprop("sim/ja37/supported/fuel-temp", FALSE);
    }


    ## control flaps ##

    var flapsCommand = 0;
    var battery = input.dcVolt.getValue();

    if (battery > 23) {
      flapsCommand = 1;
    } else {
      flapsCommand = 0;
    }
    if (input.flapPosCmd.getValue() != flapsCommand) {
      #trying to not write to fdm unless changed.
      input.flapPosCmd.setValue(flapsCommand);
    }
    
    #if(getprop("/sim/failure-manager/controls/flight/rudder/serviceable") == 1) {
    #  setprop("fdm/jsbsim/fcs/rudder/serviceable", 1);
    #} elsif (getprop("fdm/jsbsim/fcs/rudder/serviceable") == 1) {
    #  setprop("fdm/jsbsim/fcs/rudder-sum-stuck", getprop("fdm/jsbsim/fcs/rudder-sum"));
    #  setprop("fdm/jsbsim/fcs/rudder-serviceable", 0);
    #}

    
    # indicators
    var joystick = FALSE;
    var attitude = FALSE;
    var altitude = FALSE;
    var transonic = FALSE;
    var rev = FALSE;

    # joystick indicator
    if(input.acInstrVolt.getValue() > 50) {
      if (((input.lockHeading.getValue() != '' and input.lockHeading.getValue() != nil) and (input.lockAltitude.getValue() != ''
       and input.lockAltitude.getValue() != nil)) or input.lockPassive.getValue() == TRUE and input.dcVolt.getValue() > 23) {
        joystick = FALSE;
      } else {
        joystick = TRUE;
      }
    } else {
      joystick = FALSE;
    }

    # attitude indicator
    if(input.lockPassive.getValue() == TRUE or (input.lockHeading.getValue() != '' and input.lockHeading.getValue() != nil)
     and input.dcVolt.getValue() > 23) {
      if (input.roll.getValue() > 70 or input.roll.getValue() < -70) {
        attitude = input.hz05.getValue();
      } else {
        attitude = TRUE;
      }
    } else {
      attitude = FALSE;
    }

    # altitude indicator
    if(input.lockPassive.getValue() == TRUE or (input.lockAltitude.getValue() != '' and input.lockAltitude.getValue() != nil)
     and input.dcVolt.getValue() > 23) {
      if (input.speedMach.getValue() > 0.97 and input.speedMach.getValue() < 1.05) {
        altitude = input.hz05.getValue();
      } else {
        altitude = TRUE;
      }
    } else {
      altitude = FALSE;
    }

    #transonic indicator
    if (input.speedMach.getValue() > 0.97 and input.speedMach.getValue() < 1.05
     and input.dcVolt.getValue() > 23) {
      transonic = TRUE;
    } else {
      if(input.reversed.getValue() == TRUE and input.speedKt.getValue() < 64.8 and input.dcVolt.getValue() > 23) {
        # warning that speed is so low that its risky to continue reverse thrust
          transonic = TRUE;
        } else {
          transonic = FALSE;
        }
    }

    # reverse indicator
    if(input.reversed.getValue() == TRUE and input.dcVolt.getValue() > 23) {
      rev = TRUE;
    } else {
      rev = FALSE;
    }

    input.indJoy.setValue(joystick);
    input.indAtt.setValue(attitude);
    input.indAlt.setValue(altitude);
    input.indTrn.setValue(transonic);
    input.indRev.setValue(rev);

    # pylon payloads
    for(var i=0; i<=4; i=i+1) {
      if(getprop("payload/weight["~ (i) ~"]/selected") != "none" and getprop("payload/weight["~ (i) ~"]/weight-lb") == 0) {
        # missile was loaded manually through payload/fuel dialog, so setting the pylon to not released
        setprop("controls/armament/station["~(i+1)~"]/released", FALSE);
        #print("adding "~i);
        if(i != 4) {
          if (getprop("payload/weight["~ (i) ~"]/selected") == "RB 24J") {
            #is not center pylon and is RB24
            if(armament.AIM9.new(i) == -1 and armament.AIM9.active[i].status == MISSILE_FLYING) {
              #missile added through menu while another from that pylon is still flying.
              #to handle this we have to ignore that addition.
              setprop("controls/armament/station["~(i+1)~"]/released", TRUE);
              setprop("payload/weight["~ (i) ~"]/selected", "none");
              #print("refusing to mount new missile yet "~i);
            }
          } elsif (getprop("payload/weight["~ (i) ~"]/selected") == "M70") {
              setprop("ai/submodels/submodel["~(5+i)~"]/count", 6);
          }
        }
      }
      #if(i!=0 and getprop("payload/weight["~ (i-1) ~"]/selected") == "none" and getprop("payload/weight["~ (i-1) ~"]/weight-lb") != 0) {
      #  if(armament.AIM9.active[i-1] != nil) {
          # pylon emptied through menu, so remove the logic
          #print("removing "~i);
      #    armament.AIM9.active[i-1].del();
      #  } 
      #}
    }

    #activate searcher on selected pylon if missile mounted
    var armSelect = input.stationSelect.getValue();
    for(i = 0; i <= 3; i += 1) {
      if(armament.AIM9.active[i] != nil) {
        #missile is mounted on pylon
        if(armSelect != i+1 and armament.AIM9.active[i].status != MISSILE_FLYING) {
          #pylon not selected, and not flying set missile on standby
          armament.AIM9.active[i].status = MISSILE_STANDBY;#print("not sel "~(i));
        } elsif (input.combat.getValue() != 2 or (armament.AIM9.active[i].status != MISSILE_STANDBY and armament.AIM9.active[i].status != MISSILE_FLYING and getprop("payload/weight["~ (i) ~"]/selected") == "none")) {
          #pylon has logic but missile not mounted and not flying or not in tactical mode
          armament.AIM9.active[i].status = MISSILE_STANDBY;#print("empty "~(i));
        } elsif (armSelect == i+1 and armament.AIM9.active[i].status == MISSILE_STANDBY and getprop("payload/weight["~ (i) ~"]/selected") != "none" and input.combat.getValue() == 2) {
          #pylon selected, missile mounted, in tactical mode, activate search
          armament.AIM9.active[i].status = MISSILE_SEARCH;#print("active "~(i));
          armament.AIM9.active[i].search();
        }
      }
    }

    var selected = nil;
    for(var i=0; i<=4; i=i+1) { # set JSBSim mass
      selected = getprop("payload/weight["~i~"]/selected");
      if(selected == "none") {
        # the pylon is empty, set its pointmass to zero
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 0) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 0);
        }
        if(i==4) {
          # no drop tank attached
          input.tank8Selected.setValue(FALSE);
          input.tank8Jettison.setValue(TRUE);
          input.tank8LvlNorm.setValue(0);
        }
      } elsif (selected == "RB 24J") {
        # the pylon has a sidewinder, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 188) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 188);
        }
      } elsif (selected == "M70") {
        # the pylon has a sidewinder, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 200) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 200);
        }
      } elsif (selected == "Drop tank") {
        # the pylon has a drop tank, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") == 0) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 224.87);#if change this also change it in jsbsim
        }
        input.tank8Selected.setValue(TRUE);
        input.tank8Jettison.setValue(FALSE);
      }
    }

    # for aerodynamic response to asymmetric wing loading
    if(input.mass1.getValue() == input.mass3.getValue()) {
      # wing pylons symmetric loaded
      if (input.asymLoad.getValue() != 0) {
        input.asymLoad.setValue(0);
      }
    } elsif(input.mass1.getValue() < input.mass3.getValue()) {
      # right wing pylon has more load than left
      if (input.asymLoad.getValue() != -1) {
        input.asymLoad.setValue(-1);
      }
    } else {
      # left wing pylon has more load than right
      if (input.asymLoad.getValue() != 1) {
        input.asymLoad.setValue(1);
      }
    }


    # automatic reverse thrust enabler
    var reversed = input.reversed.getValue();

    var gear0 = input.wow0.getValue();
    var gear1 = input.wow1.getValue();
    var gear2 = input.wow2.getValue();

    if(input.autoReverse.getValue() == TRUE and reversed == FALSE) {
      if(gear1 == TRUE) {
        #left boogie touching
        if(prevGear1 == FALSE) {
          touchdown1 = TRUE;
        }
      } else {
        touchdown1 = FALSE;
      }
      if(gear2 == TRUE) {
        #right boogie touching
        if(prevGear2 == FALSE) {
          touchdown2 = TRUE;
        }
      } else {
        touchdown2 = FALSE;
      }
      if(touchdown1 == TRUE and touchdown2 == TRUE) {
        if(gear0 == TRUE) {
          #print("Auto-reversing the thrust");
          touchdown1 = FALSE;
          touchdown2 = FALSE;
          reversethrust.togglereverser();
        }
      }
    }

    prevGear0 = gear0;
    prevGear1 = gear1;
    prevGear2 = gear2;

    # Make sure have engine sound at reverse thrust

    var thrust = input.thrustLb.getValue();
     
    if(thrust != nil) {
      input.thrustLbAbs.setValue(abs(thrust));
    } else {
      input.thrustLbAbs.setValue(0);
    }

    # meter altitude property

    input.indAltMeter.setValue(input.indAltFt.getValue()*0.3048);

    # front gear compression calc for spinning of wheel
    # setprop("gear/gear/compression-wheel", (getprop("gear/gear/compression-ft")*0.3048-1.84812));

    # Master warning
    if(input.dcVolt.getValue() > 23 ) {
      var warning_sound = FALSE;
      var warning = FALSE;
      if (input.wow0.getValue() == FALSE) {
        if (input.engineRunning.getValue() == FALSE and autostarting == FALSE) {
          warning = TRUE;
          if (input.warnButton.getValue() == TRUE) {
            warnEngineOff = FALSE;
          }
          if (warnEngineOff == TRUE) {
            warning_sound = TRUE;
          }
        } else {
          warnEngineOff = TRUE;
        }
        if (input.canopyPos.getValue() > 0) {
          warning = TRUE;
          if (input.warnButton.getValue() == TRUE) {
            warnCanopy = FALSE;
          }
          if (warnCanopy == TRUE) {
            warning_sound = TRUE;
          }
        } else {
          warnCanopy = TRUE;
        }
        if (input.acInstrVolt.getValue() < 50) {
          warning = TRUE;
          if (input.warnButton.getValue() == TRUE) {
            warnGenerator = FALSE;
          }
          if (warnGenerator == TRUE) {
            warning_sound = TRUE;
          }
        } else {
          warnGenerator = TRUE;
        }
        if (input.hydr1On.getValue() != 1) {
          warning = TRUE;
          if (input.warnButton.getValue() == TRUE) {
            warnHydr1 = FALSE;
          }
          if (warnHydr1 == TRUE) {
            warning_sound = TRUE;
          }
        } else {
          warnHydr1 = TRUE;
        }
        if (input.hydr2On.getValue() != 1) {
          warning = TRUE;
          if (input.warnButton.getValue() == TRUE) {
            warnHydr2 = FALSE;
          }
          if (warnHydr2 == TRUE) {
            warning_sound = TRUE;
          }
        } else {
          warnHydr2 = TRUE;
        }
        if (input.cabinPressure.getValue() < .15) {
          warning = TRUE;
          if (input.warnButton.getValue() == TRUE) {
            warnCabin = FALSE;
          }
          if (warnCabin == TRUE) {
            warning_sound = TRUE;
          }
        } else {
          warnCabin = TRUE;
        }
      }
        
      # Master warning
      if(warning == TRUE and input.hz10.getValue() == TRUE) {
        input.warn.setValue(TRUE);
      } else {
        input.warn.setValue(FALSE);
      }
      if(warning_sound == TRUE and input.hzThird.getValue() == TRUE) {
        input.master.setValue(TRUE);
      } else {
        input.master.setValue(FALSE);
      }
    } else {
      input.warn.setValue(FALSE);
      input.master.setValue(FALSE);
    }

    #tracer ammo, due to it might run out faster than cannon rounds due to submodel delay not being precise
    if(input.subAmmo3.getValue() > 0) {
      input.subAmmo2.setValue(-1);
    } else {
      input.subAmmo2.setValue(0);
    }

    # low speed warning
    var lowSpeed = FALSE;
    if ((input.speedKt.getValue() * 1.852) < 375) {
      if (input.indAltMeter.getValue() < 1200) {
        if ((input.gearsPos.getValue() == 1 and (input.rad_alt.getValue() * 0.3048) > 500) or input.gearsPos.getValue() != 1) {#manual: should be 30, not 500
          if (input.n2.getValue() < 70.5 or input.reversed.getValue() == TRUE or input.engineRunning.getValue() == FALSE) {
            lowSpeed = TRUE;
          }
        }
      }
    }
    input.speedWarn.setValue(lowSpeed);

    # main electrical turned on
    var timer = input.elapsed.getValue();
    var main = input.dcVolt.getValue();
    if(main > 20 and mainOn == FALSE) {
      #main has been switched on
      mainTimer = timer;
      mainOn = TRUE;
      input.lampData.setValue(TRUE);
      input.lampInertiaNav.setValue(TRUE);
    } elsif (main > 20) {
      if (timer > (mainTimer + 20)) {
        input.lampData.setValue(FALSE);
      }
      if (timer > (mainTimer + 140)) {
        input.lampInertiaNav.setValue(FALSE);
      }
    } elsif (main <= 20) {
      mainOn = FALSE;
    }
    # engine start
    var n2 = input.n2.getValue();
    if (input.starter.getValue() == TRUE and n2 < 57 and input.thrustLb.getValue() == 0) {
      input.lampStart.setValue(TRUE);
    } else {
      input.lampStart.setValue(FALSE);
    }
    if (input.cutoff.getValue() == FALSE and n2 < 57 and n2 > 16 and input.thrustLb.getValue() == 0) {
      # manual says between 11-16% it goes on
      input.lampIgnition.setValue(TRUE);
    } else {
      input.lampIgnition.setValue(FALSE);
    }
    if (input.tank8Jettison.getValue() == FALSE and input.tank8LvlGal.getValue() > 45 and (input.starter.getValue() == TRUE or input.engineRunning.getValue() == 1) and (n2 < 70 or input.pneumatic.getValue() == 0)) {
      input.lampXTank.setValue(TRUE);
    } else {
      input.lampXTank.setValue(FALSE);
    }

    # joystick on indicator panel
    if ((main > 20 and input.acMainVolt.getValue() < 150) or input.hydrCombined.getValue() != 1) {
      input.lampStick.setValue(TRUE);
    } else {
      input.lampStick.setValue(FALSE);
    }

    if (main > 20 and getprop("controls/oxygen") == FALSE) {
      input.lampOxygen.setValue(TRUE);
    } else {
      input.lampOxygen.setValue(FALSE);
    }

    if (main > 20 and input.acMainVolt.getValue() < 150) {
      input.lampCanopy.setValue(TRUE);
    } else {
      input.lampCanopy.setValue(FALSE);
    }

    # exterior lights
    var flash = input.dcVolt.getValue() > 20 and input.switchFlash.getValue() == 1;
    var beacon = input.dcVolt.getValue() > 20 and input.switchBeacon.getValue() == 1;
    var nav = input.dcVolt.getValue() > 20 and input.switchNav.getValue() == 1;
    input.MPint9.setIntValue(encode3bits(flash, beacon, nav));

    # contrails
    var contrails = getprop("environment/temperature-degc") < -40 and getprop("position/altitude-ft") > 19000 and input.n2.getValue() > 50;
    input.MPint18.setIntValue(encode3bits(contrails, 0, 0));

    # smoke
    if (input.dcVolt.getValue() > 20) {
      setprop("/sim/ja37/effect/smoke", getprop("/sim/ja37/effect/smoke-cmd"));
    } else {
      setprop("/sim/ja37/effect/smoke", 1);
    }

    settimer(
      #func debug.benchmark("j37 loop", 
        update_loop
        #)
    , UPDATE_PERIOD);
  }
}

var TILSprev = FALSE;
var acPrev = 0;
var acTimer = 0;

# slow updating loop
var slow_loop = func () {
  #TILS
  if(input.TILS.getValue() == TRUE and input.acInstrVolt.getValue() > 100) {#  and canvas_HUD != nil and canvas_HUD.mode == canvas_HUD.LANDING
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
        popupTip("TILS tuned to "~icao~" "~closestRunway~standbyStr, 25, 6);
      }
    }
    TILSprev = TRUE;
  } else {
    TILSprev = FALSE;
  }

  #frost and rain
  var acSetting = getprop("controls/ventilation/airconditioning-type");
  if (acSetting != 0) {
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

  var airspeed = getprop("/velocities/airspeed-kt");
  # ja37
  #var airspeed_max = 250; 
  var airspeed_max = 120;
  if (airspeed > airspeed_max) {airspeed = airspeed_max;}
  airspeed = math.sqrt(airspeed/airspeed_max);
  # f-16
  var splash_x = -0.1 - 2.0 * airspeed;
  var splash_y = 0.0;
  var splash_z = 1.0 - 1.35 * airspeed;
  setprop("/environment/aircraft-effects/splash-vector-x", splash_x);
  setprop("/environment/aircraft-effects/splash-vector-y", splash_y);
  setprop("/environment/aircraft-effects/splash-vector-z", splash_z);

  var tempOutside = getprop("environment/temperature-degc");
  var tempInside = getprop("environment/temperature-inside-degc");
  var tempOutsideDew = getprop("environment/dewpoint-degc");
  var tempACDew = 5;#aircondition dew point. 5 = dry

  # calc inside temp
  if (input.canopyPos.getValue() > 0) {
    tempInside = tempOutside;
  } elsif(input.dcVolt.getValue() > 23 and getprop("controls/ventilation/airconditioning-enabled") == TRUE) {
    if (tempInside < tempAC) {
      tempInside = clamp(tempInside+0.15, -1000, tempAC);
    } elsif (tempInside > tempAC) {
      tempInside = clamp(tempInside-0.15, tempAC, 1000);
    }
  } else {
    if (tempInside < tempOutside) {
      tempInside = clamp(tempInside+1, -1000, tempOutside);
    } elsif (tempInside > tempOutside) {
      tempInside = clamp(tempInside-1, tempOutside, 1000);
    }
  }
  
  # calc temp of glass itself
  var tempIndex = 0.70; # 0.80 = good window   0.45 = bad window
  var tempGlass = tempIndex*(tempInside - tempOutside)+tempOutside;
  
  # calculate dew point for inside air. When full airconditioning is achieved at tempAC dewpoint will be tempACdew.
  # slope = (outsideDew - desiredInsideDew)/(outside-desiredInside)
  # insideDew = slope*(inside-desiredInside)+desiredInsideDew

  var slope = (tempOutsideDew - tempACDew)/(tempOutside-tempAC);
  var tempInsideDew = slope*(tempInside-tempAC)+tempACDew;

  # calc fogging outside and inside on glass
  var fogNormOutside = clamp((tempOutsideDew-tempGlass)*0.05, 0, 1);
  var fogNormInside = clamp((tempInsideDew-tempGlass)*0.05, 0, 1);

  var fogNorm = fogNormOutside>fogNormInside?fogNormOutside:fogNormInside;
  var frostNorm = clamp((tempGlass-0)*-0.05, 0, 1);# will freeze below 0

  var mask = FALSE;
  var knob = getprop("controls/ventilation/windshield-hot-air-knob");
  if (frostNorm <= knob and knob != 0 and input.dcVolt.getValue() > 23) {
    mask = TRUE;
  }

  setprop("/environment/aircraft-effects/use-mask", mask);
  setprop("/environment/aircraft-effects/fog-inside", fogNormInside);
  setprop("/environment/aircraft-effects/fog-outside", fogNormOutside);
  setprop("/environment/aircraft-effects/temperature-glass-degc", tempGlass);

  setprop("environment/temperature-inside-degc", tempInside);
  setprop("/environment/aircraft-effects/frost-level", frostNorm);
  setprop("/environment/aircraft-effects/fog-level", fogNorm);

  settimer(slow_loop, 1.5);
}

# fast updating loop
var speed_loop = func () {

  # switch on and off ALS landing lights
  if(input.landLight.getValue() > 0) {    
    if(input.viewInternal.getValue() == TRUE and input.landLightSupport.getValue() == TRUE) {
        input.landLightALS.setValue(TRUE);
      } else {
        input.landLightALS.setValue(FALSE);
      }
  } else {
    input.landLightALS.setValue(FALSE);
  }

  if(input.replay.getValue() == TRUE) {
    # replay is active, skip rest of loop.
    settimer(speed_loop, 0.5);
    return;
  }
  # calc g-force
  var gravity = input.gravity.getValue();
  var GCurrent = input.zAccPilot.getValue();  
  if (GCurrent != nil and gravity != nil) {
    GCurrent = - GCurrent / gravity;
    input.pilotG.setValue(GCurrent);
  }

  ## control augmented thrust ##
  var n1 = input.n1.getValue();
  var n2 = input.n2.getValue();
  var reversed = input.reversed.getValue();

  if ( input.fdmAug.getValue() == TRUE) { #was 99 and 97
    input.augmentation.setValue(TRUE);
  } else {
    input.augmentation.setValue(FALSE);
  }

  # Animating engine fire
  if (n1 > 100) n1 = 100;
  var flame = 100 / (101-n1);
  input.flame.setValue(flame);

  ## set groundspeed property used for crashcode ##
  var horz_speed = input.vgFps.getValue();
  var vert_speed = input.downFps.getValue();
  var real_speed = math.sqrt((horz_speed * horz_speed) + (vert_speed * vert_speed));
  real_speed = real_speed * 0.5924838;#ft/s to kt
  input.g3d.setValue(real_speed);

  # MP gear wow
  var wow0 = input.wow0.getValue();
  var wow1 = input.wow1.getValue();
  var wow2 = input.wow2.getValue();
  input.MPint17.setIntValue(encode3bits(wow0, wow1, wow2));

  settimer(speed_loop, 0.05);
}

###########  listener for handling the trigger #########
var trigger_listener = func {
    var trigger = input.trigger.getValue();
    var armSelect = input.stationSelect.getValue();

    #if masterarm is on and HUD in tactical mode, propagate trigger to station
    if(input.combat.getValue() == 2 and input.dcVolt.getValue() > 23 and !(armSelect == 0 and input.acInstrVolt.getValue() < 100)) {
      setprop("/controls/armament/station["~armSelect~"]/trigger", trigger);
      var str = "payload/weight["~(armSelect-1)~"]/selected";
      if (armSelect != 0 and getprop(str) == "M70") {
        setprop("/controls/armament/station["~armSelect~"]/trigger-m70", trigger);
      }
    } else {
      setprop("/controls/armament/station["~armSelect~"]/trigger", FALSE);
    }

    if(armSelect != 0 and getprop("/controls/armament/station["~armSelect~"]/trigger") == TRUE) {
      if(getprop("payload/weight["~(armSelect-1)~"]/selected") != "none") { 
        # trigger is pulled, a pylon is selected, the pylon has a missile that is locked on. The gear check is prevent missiles from firing when changing airport location.
        if (armament.AIM9.active[armSelect-1] != nil and  armament.AIM9.active[armSelect-1].status == 1 and input.gearsPos.getValue() != 1) {
          #missile locked, fire it.
          setprop("payload/weight["~ (armSelect-1) ~"]/selected", "none");# empty the pylon
          setprop("controls/armament/station["~armSelect~"]/released", TRUE);# setting the pylon as fired
          #print("firing missile: "~armSelect~" "~getprop("controls/armament/station["~armSelect~"]/released"));
        
          armament.AIM9.active[armSelect-1].release();#print("release "~(armSelect-1));
          var phrase = "RB-24J fired at: " ~ radar_logic.selection[5];
          if (getprop("sim/ja37/armament/msg")) {
            setprop("/sim/multiplay/chat", phrase);
          } else {
            setprop("/sim/messages/atc", phrase);
          }
        }
      }
    }
}

var last_impact = 0;

var impact_listener = func {
  if (radar_logic.selection != nil and (input.elapsed.getValue()-last_impact) > 1) {
    var ballistic_name = input.impact.getValue();
    var ballistic = props.globals.getNode(ballistic_name, 0);
    if (ballistic != nil) {
      var typeNode = ballistic.getNode("impact/type");
      if (typeNode != nil and typeNode.getValue() != "terrain") {
        var lat = ballistic.getNode("impact/latitude-deg").getValue();
        var lon = ballistic.getNode("impact/longitude-deg").getValue();
        var impactPos = geo.Coord.new().set_latlon(lat, lon);

        var track = radar_logic.selection[6];

        var x = track.getNode("position/global-x").getValue();
        var y = track.getNode("position/global-y").getValue();
        var z = track.getNode("position/global-z").getValue();
        var selectionPos = geo.Coord.new().set_xyz(x, y, z);

        var distance = impactPos.distance_to(selectionPos);
        if (distance < 50) {
          last_impact = input.elapsed.getValue();
          var phrase =  ballistic.getNode("name").getValue() ~ " hit " ~ radar_logic.selection[5];
          if (getprop("sim/ja37/armament/msg")) {
            setprop("/sim/multiplay/chat", phrase);
          } else {
            setprop("/sim/messages/atc", phrase);
          }
        }
      }
    }
  }
}

var incoming_listener = func {
  var history = getprop("/sim/multiplay/chat-history");
  var hist_vector = split("\n", history);
  if (size(hist_vector) > 0) {
    var last = hist_vector[size(hist_vector)-1];
    var last_vector = split(":", last);
    var author = last_vector[0];
    var callsign = getprop("sim/multiplay/callsign");
    if (size(last_vector) > 1 and author != callsign) {
      # not myself
      var m2000 = FALSE;
      if (find(" at " ~ callsign ~ ". Release ", last_vector[1]) != -1) {
        # a m2000 is firing at us
        m2000 = TRUE;
      }
      if (last_vector[1] == " FOX2 at" or last_vector[1] == " aim7 at" or last_vector[1] == " aim9 at" or last_vector[1] == " aim120 at" or last_vector[1] == " RB-24J fired at" or m2000 == TRUE) {
        # air2air being fired
        if (size(last_vector) > 2 or m2000 == TRUE) {
          #print("Missile launch detected at"~last_vector[2]~" from "~author);
          if (m2000 == TRUE or last_vector[2] == " "~callsign) {
            # its being fired at me
            #print("Incoming!");
            var enemy = radar_logic.getCallsign(author);
            if (enemy != nil) {
              #print("enemy identified");
              var bearingNode = enemy.getNode("radar/bearing-deg");
              if (bearingNode != nil) {
                #print("bearing to enemy found");
                var bearing = bearingNode.getValue();
                var heading = getprop("orientation/heading-deg");
                var clock = bearing - heading;
                while(clock < 0) {
                  clock = clock + 360;
                }
                while(clock > 360) {
                  clock = clock - 360;
                }
                #print("incoming from "~clock);
                if (clock >= 345 or clock < 15) {
                  setprop("sim/ja37/sound/incoming12", 1);
                } elsif (clock >= 15 and clock < 45) {
                  setprop("sim/ja37/sound/incoming1", 1);
                } elsif (clock >= 45 and clock < 75) {
                  setprop("sim/ja37/sound/incoming2", 1);
                } elsif (clock >= 75 and clock < 105) {
                  setprop("sim/ja37/sound/incoming3", 1);
                } elsif (clock >= 105 and clock < 135) {
                  setprop("sim/ja37/sound/incoming4", 1);
                } elsif (clock >= 135 and clock < 165) {
                  setprop("sim/ja37/sound/incoming5", 1);
                } elsif (clock >= 165 and clock < 195) {
                  setprop("sim/ja37/sound/incoming6", 1);
                } elsif (clock >= 195 and clock < 225) {
                  setprop("sim/ja37/sound/incoming7", 1);
                } elsif (clock >= 225 and clock < 255) {
                  setprop("sim/ja37/sound/incoming8", 1);
                } elsif (clock >= 255 and clock < 285) {
                  setprop("sim/ja37/sound/incoming9", 1);
                } elsif (clock >= 285 and clock < 315) {
                  setprop("sim/ja37/sound/incoming10", 1);
                } elsif (clock >= 315 and clock < 345) {
                  setprop("sim/ja37/sound/incoming11", 1);
                } else {
                  setprop("sim/ja37/sound/incoming", 1);
                }
                return;
              }
            }
          }
        }
      }
    }
  }
  setprop("sim/ja37/sound/incoming", 0);
  setprop("sim/ja37/sound/incoming1", 0);
  setprop("sim/ja37/sound/incoming2", 0);
  setprop("sim/ja37/sound/incoming3", 0);
  setprop("sim/ja37/sound/incoming4", 0);
  setprop("sim/ja37/sound/incoming5", 0);
  setprop("sim/ja37/sound/incoming6", 0);
  setprop("sim/ja37/sound/incoming7", 0);
  setprop("sim/ja37/sound/incoming8", 0);
  setprop("sim/ja37/sound/incoming9", 0);
  setprop("sim/ja37/sound/incoming10", 0);
  setprop("sim/ja37/sound/incoming11", 0);
  setprop("sim/ja37/sound/incoming12", 0);
}

var cycle_weapons = func {
  var sel = getprop("controls/armament/station-select");
  sel += 1;
  if(sel > 4) {
    sel = 0;
  }
  click();
  setprop("controls/armament/station-select", sel)
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
                
###############  Test which system the flightgear version support.  ###########

var test_support = func {
 
  var versionString = getprop("sim/version/flightgear");
  var version = split(".", versionString);
  var major = num(version[0]);
  var minor = num(version[1]);
  var detail = num(version[2]);
  if (major < 2) {
    popupTip("JA-37 is only supported in Flightgear version 2.8 and upwards. Sorry.");
      setprop("sim/ja37/supported/radar", FALSE);
      setprop("sim/ja37/supported/hud", FALSE);
      setprop("sim/ja37/supported/options", FALSE);
      setprop("sim/ja37/supported/old-custom-fails", 0);
      setprop("sim/ja37/supported/popuptips", 0);
      setprop("sim/ja37/supported/landing-light", FALSE);
      setprop("sim/ja37/supported/crash-system", 0);
      setprop("sim/ja37/supported/ubershader", FALSE);
  } elsif (major == 2) {
    setprop("sim/ja37/supported/landing-light", FALSE);
    if(minor < 7) {
      popupTip("JA-37 is only supported in Flightgear version 2.8 and upwards. Sorry.");
      setprop("sim/ja37/supported/radar", FALSE);
      setprop("sim/ja37/supported/hud", FALSE);
      setprop("sim/ja37/supported/options", FALSE);
      setprop("sim/ja37/supported/old-custom-fails", 0);
      setprop("sim/ja37/supported/popuptips", 0);
      setprop("sim/ja37/supported/crash-system", 0);
      setprop("sim/ja37/supported/ubershader", FALSE);
    } elsif(minor < 9) {
      popupTip("JA-37 Canvas Radar and HUD is only supported in Flightgear version 2.10 and upwards. They have been disabled.");
      setprop("sim/ja37/supported/radar", FALSE);
      setprop("sim/ja37/supported/hud", FALSE);
      setprop("sim/ja37/supported/options", FALSE);
      setprop("sim/ja37/supported/old-custom-fails", 0);
      setprop("sim/ja37/hud/mode", 0);
      setprop("sim/ja37/supported/popuptips", 0);
      setprop("sim/ja37/supported/crash-system", 0);
      setprop("sim/ja37/supported/ubershader", FALSE);
    } elsif(minor < 11) {
      setprop("sim/ja37/supported/radar", TRUE);
      setprop("sim/ja37/supported/hud", TRUE);
      setprop("sim/ja37/supported/options", FALSE);
      setprop("sim/ja37/supported/old-custom-fails", 0);
      setprop("sim/ja37/supported/popuptips", 0);
      setprop("sim/ja37/supported/crash-system", 0);
      setprop("sim/ja37/supported/ubershader", TRUE);
    } else {
      setprop("sim/ja37/supported/radar", TRUE);
      setprop("sim/ja37/supported/hud", TRUE);
      setprop("sim/ja37/supported/options", FALSE);
      setprop("sim/ja37/supported/old-custom-fails", 0);
      setprop("sim/ja37/supported/popuptips", 1);
      setprop("sim/ja37/supported/crash-system", 0);
      setprop("sim/ja37/supported/ubershader", TRUE);
    }
  } elsif (major == 3) {
    setprop("sim/ja37/supported/options", TRUE);
    setprop("sim/ja37/supported/radar", TRUE);
    setprop("sim/ja37/supported/hud", TRUE);
    setprop("sim/ja37/supported/old-custom-fails", 2);
    setprop("sim/ja37/supported/landing-light", TRUE);
    setprop("sim/ja37/supported/popuptips", 2);
    setprop("sim/ja37/supported/crash-system", 1);
    setprop("sim/ja37/supported/ubershader", TRUE);
    if (minor == 0) {
      setprop("sim/ja37/supported/old-custom-fails", 0);
      setprop("sim/ja37/supported/landing-light", FALSE);
      setprop("sim/ja37/supported/popuptips", 1);
      setprop("sim/ja37/supported/crash-system", 0);
    } elsif (minor <= 2) {
      setprop("sim/ja37/supported/old-custom-fails", 1);
      setprop("sim/ja37/supported/landing-light", FALSE);
      setprop("sim/ja37/supported/popuptips", 1);
    } elsif (minor <= 4) {
      setprop("sim/ja37/supported/old-custom-fails", 1);
      setprop("sim/ja37/supported/popuptips", 1);
    }
  } else {
    # future proof
    setprop("sim/ja37/supported/options", TRUE);
    setprop("sim/ja37/supported/radar", TRUE);
    setprop("sim/ja37/supported/hud", TRUE);
    setprop("sim/ja37/supported/old-custom-fails", 2);
    setprop("sim/ja37/supported/landing-light", TRUE);
    setprop("sim/ja37/supported/popuptips", 2);
    setprop("sim/ja37/supported/crash-system", 1);
    setprop("sim/ja37/supported/ubershader", TRUE);
  }
  setprop("sim/ja37/supported/initialized", TRUE);

  print();
  print("***************************************************************");
  print("**         Initializing Saab JA-37 Viggen systems.           **");
  print("**           Version "~getprop("sim/aircraft-version")~" on Flightgear "~version[0]~"."~version[1]~"."~version[2]~"               **");
  print("***************************************************************");
  print();
}

############################# main init ###############


var main_init = func {
  setprop("sim/time/elapsed-at-init-sec", getprop("sim/time/elapsed-sec"));

  test_support();

  aircraft.data.add("sim/ja37/radar/enabled",
                    "sim/ja37/hud/units-metric",
                    "sim/ja37/hud/mode",
                    "sim/ja37/hud/bank-indicator",
                    "sim/ja37/autoReverseThrust",
                    "sim/ja37/hud/stroke-linewidth",
                    "ai/submodels/submodel[2]/random",
                    "ai/submodels/submodel[3]/random");
  aircraft.data.save();

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

  screen.log.write("Welcome to Saab JA-37 Viggen, version "~getprop("sim/aircraft-version"), 1.0, 0.2, 0.2);

  # init cockpit temperature
  setprop("environment/temperature-inside-degc", getprop("environment/temperature-degc"));

  # init oxygen bottle pressure
  setprop("sim/ja37/systems/oxygen-bottle-pressure", rand()*75+50);#todo: start high, and lower slowly during flight

  # start minor loops
  speed_loop();
  slow_loop();
  battery_listener();
  hydr1Lost();

  # start beacon loop
  #beaconTimer.start();
  beaconLoop();

  # asymmetric vortex detachment
  asymVortex();

  # setup trigger listener
  setlistener("controls/armament/trigger", trigger_listener, 0, 0);

  # setup impact listener
  setlistener("/ai/models/model-impact", impact_listener, 0, 0);

  # setup incoming listener
  setlistener("/sim/multiplay/chat-history", incoming_listener, 0, 0);

  # start the main loop
	settimer(func { update_loop() }, 0.1);
}

# re init
var re_init = func {
  print("Re-initializing JA-37 Viggen systems");
  
  setprop("sim/time/elapsed-at-init-sec", getprop("sim/time/elapsed-sec"));

  # asymmetric vortex detachment
  asymVortex();

  #test_support();
}

var asymVortex = func () {
  if(rand() > 0.5) {
    setprop("fdm/jsbsim/aero/function/vortex", 1);
  } else {
    setprop("fdm/jsbsim/aero/function/vortex", -1);
  }
}

var load_interior = func{
    setprop("/sim/current-view/view-number", 0);
    print("..Done!");
  }

var main_init_listener = setlistener("sim/signals/fdm-initialized", func {
	main_init();
	removelistener(main_init_listener);
 }, 0, 0);

var re_init_listener = setlistener("/sim/signals/reinit", func {
  re_init();
 }, 0, 0);

############ droptank #####################

var drop = func {
    if (getprop("/consumables/fuel/tank[8]/jettisoned") == TRUE) {
       popupTip("Drop tank already jettisoned.");
       return;
    }  
    if (getprop("/gear/gear[0]/wow") > 0.05) {
       popupTip("Can not eject drop tank while on ground!"); 
       return;
    }
    if (input.combat.getValue() == 2) {
       popupTip("Can not eject drop tank when masterarm on!");
       return;
    }
    if (getprop("systems/electrical/outputs/dc-voltage") < 23) {
       popupTip("Too little DC power to eject drop tank!");
       return;
    }
    click();
    setprop("payload/weight[4]/selected", "none");# empty the pylon
    popupTip("Drop tank shut off and ejected. Using internal fuel.");
 }

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
    beacon_switch.setValue(value);
  }
  settimer(beaconLoop, 0);
};
#var beaconTimer = maketimer(0, beaconLoop); only usable in 2.11+


#var beacon = aircraft.light.new( "sim/model/lighting/beacon", [0, 1], beacon_switch );

############ blinkers ####################

var blinker = aircraft.light.new("sim/ja37/blink/five-Hz", [0.2, 0.2]);
blinker.switch(1);
blinker = aircraft.light.new("sim/ja37/blink/ten-Hz", [0.1, 0.1]);
blinker.switch(1);
blinker = aircraft.light.new("sim/ja37/blink/third-Hz", [2, 1]);
blinker.switch(1);

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
     popupTip("Stopping engine. Turning off electrical system.");
     click();
     stopAutostart();
    } else {
      #print("autostarting");
      setprop("fdm/jsbsim/systems/electrical/external/enable-cmd", TRUE);
      popupTip("Autostarting..");
  	  settimer(startSupply, 1.5, 1);
    }
  }
}

var stopAutostart = func {
  setprop("/controls/engines/engine[0]/cutoff", TRUE);
  setprop("/controls/engines/engine[0]/starter-cmd", FALSE);
  setprop("/controls/electric/engine[0]/generator", FALSE);
  setprop("/controls/electric/main", FALSE);
  setprop("/controls/electric/battery", FALSE);
  setprop("fdm/jsbsim/systems/electrical/external/switch", FALSE);
  setprop("fdm/jsbsim/systems/electrical/external/enable-cmd", FALSE);
  autostarting = FALSE;
}

var startSupply = func {
  if (getprop("fdm/jsbsim/systems/electrical/external/available") == TRUE) {
    # using ext. power
    click();
    setprop("fdm/jsbsim/systems/electrical/external/switch", TRUE);
    setprop("/controls/electric/main", TRUE);
    popupTip("Enabling power using external supply.");
  } else {
    # using battery
    click();
    setprop("/controls/electric/battery", TRUE);
    setprop("/controls/electric/main", TRUE);
    popupTip("Enabling power using battery.");
  }
  settimer(endSupply, 1.5, 1);
}

var endSupply = func {
  if (getprop("systems/electrical/outputs/dc-voltage") > 23) {
    # have power to start
    settimer(autostart, 1.5, 1);
  } else {
    # not enough power to start
    click();
    stopAutostart();
    popupTip("Not enough power to autostart, aborting.");
  }
}

#Simulating autostart function
var autostart = func {
  setprop("/controls/electric/engine[0]/generator", FALSE);
  popupTip("Starting engine..");
  click();
  setprop("/controls/engines/engine[0]/cutoff", TRUE);
  setprop("/controls/engines/engine[0]/starter-cmd", TRUE);
  start_count = 0;
  settimer(waiting_n1, 0.5, 1);
}

# Opens fuel valve in autostart
var waiting_n1 = func {
  start_count += 1* getprop("sim/speed-up");
  #print(start_count);
  if (start_count > 45) {
    if(bingoFuel == TRUE) {
      popupTip("Engine start failed. Check fuel.");
    } elsif (getprop("systems/electrical/outputs/dc-voltage") < 23) {
      popupTip("Engine start failed. Check battery.");
    } else {
      popupTip("Autostart failed. If engine has not reported failure, report bug to aircraft developer.");
    }
    print("Autostart failed. n1="~getprop("/engines/engine[0]/n1")~" cutoff="~getprop("/controls/engines/engine[0]/cutoff")~" starter="~getprop("/controls/engines/engine[0]/starter")~" generator="~getprop("/controls/electric/engine[0]/generator")~" battery="~getprop("/controls/electric/main")~" fuel="~bingoFuel);
    stopAutostart();
  } elsif (getprop("/engines/engine[0]/n1") > 4.9) {
    if (getprop("/engines/engine[0]/n1") < 20) {
      if (getprop("/controls/engines/engine[0]/cutoff") == TRUE) {
        click();
        setprop("/controls/engines/engine[0]/cutoff", FALSE);
        if (getprop("/controls/engines/engine[0]/cutoff") == FALSE) {
          popupTip("Engine igniting.");
          settimer(waiting_n1, 0.5, 1);
        } else {
          print("Autostart failed 2. n1="~getprop("/engines/engine[0]/n1")~" cutoff="~getprop("/controls/engines/engine[0]/cutoff")~" starter="~getprop("/controls/engines/engine[0]/starter")~" generator="~getprop("/controls/electric/engine[0]/generator")~" battery="~getprop("/controls/electric/main")~" fuel="~bingoFuel);
          stopAutostart();
          popupTip("Engine not igniting. Aborting engine start.");
        }
      } else {
        settimer(waiting_n1, 0.5, 1);
      }
    }  elsif (getprop("/engines/engine[0]/n1") > 10 and getprop("/controls/engines/engine[0]/cutoff") == FALSE) {
      #print("Autostart success. n1="~getprop("/engines/engine[0]/n1")~" cutoff="~getprop("/controls/engines/engine[0]/cutoff")~" starter="~getprop("/controls/engines/engine[0]/starter")~" generator="~getprop("/controls/electric/engine[0]/generator")~" battery="~getprop("/controls/electric/main"));
      click();
      setprop("controls/electric/engine[0]/generator", TRUE);
      popupTip("Generator on.");
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
      popupTip("Engine start failed. Check fuel.");
    } elsif (getprop("systems/electrical/outputs/dc-voltage") < 23) {
      popupTip("Engine start failed. Check battery.");
    } else {
      popupTip("Autostart failed. If engine has not reported failure, report bug to aircraft developer.");
    }    
    print("Autostart failed 3. n1="~getprop("/engines/engine[0]/n1")~" cutoff="~getprop("/controls/engines/engine[0]/cutoff")~" starter="~getprop("/controls/engines/engine[0]/starter")~" generator="~getprop("/controls/electric/engine[0]/generator")~" battery="~getprop("/controls/electric/main")~" fuel="~bingoFuel);
    stopAutostart();  
  } elsif (getprop("/engines/engine[0]/running") > FALSE) {
    popupTip("Engine ready.");
    setprop("/controls/engines/engine[0]/starter-cmd", FALSE);
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
      setprop("sim/ja37/sound/click-on", TRUE);
      settimer(clickOff, 0.15, 1);
    }
}

var clickOff = func {
    setprop("sim/ja37/sound/click-on", FALSE);
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
    popupTip("Yaw damper: ON");
  } else {
    popupTip("Yaw damper: OFF");
  }
}

var togglePitchDamper = func {
  ja37.click();
  var enabled = getprop("fdm/jsbsim/fcs/pitch-damper/enable");
  setprop("fdm/jsbsim/fcs/pitch-damper/enable", !enabled);
  if(enabled == FALSE) {
    popupTip("Pitch damper: ON");
  } else {
    popupTip("Pitch damper: OFF");
  }
}

var toggleRollDamper = func {
  ja37.click();
  var enabled = getprop("fdm/jsbsim/fcs/roll-damper/enable");
  setprop("fdm/jsbsim/fcs/roll-damper/enable", !enabled);
  if(enabled == FALSE) {
    popupTip("Roll damper: ON");
  } else {
    popupTip("Roll damper: OFF");
  }
}

var toggleHook = func {
  ja37.click();
  var enabled = getprop("fdm/jsbsim/systems/hook/tailhook-cmd-norm");
  setprop("fdm/jsbsim/systems/hook/tailhook-cmd-norm", !enabled);
  if(enabled == FALSE) {
    popupTip("Arrester hook: Extended");
  } else {
    popupTip("Arrester hook: Retracted");
  }
}

var toggleNosewheelSteer = func {
  ja37.click();
  var enabled = getprop("fdm/jsbsim/gear/unit[0]/nose-wheel-steering/enable");
  setprop("fdm/jsbsim/gear/unit[0]/nose-wheel-steering/enable", !enabled);
  if(enabled == FALSE) {
    popupTip("Nose Wheel Steering: ON", 1.5);
  } else {
    popupTip("Nose Wheel Steering: OFF", 1.5);
  }
}

var toggleTracks = func {
  ja37.click();
  var enabled = getprop("sim/ja37/hud/tracks-enabled");
  setprop("sim/ja37/hud/tracks-enabled", !enabled);
  if(enabled == FALSE) {
    popupTip("Radar ON");
  } else {
    popupTip("Radar OFF");
  }
}

var follow = func () {
  setprop("/autopilot/target-tracking-ja37/enable", FALSE);
  if(radar_logic.selection != nil) {
    var target = radar_logic.selection[6];
    setprop("/autopilot/target-tracking-ja37/target-root", target.getPath());
    #this is done in -set file: /autopilot/target-tracking-ja37/min-speed-kt
    setprop("/autopilot/target-tracking-ja37/enable", TRUE);
    var range = 0.075;
    setprop("/autopilot/target-tracking-ja37/goal-range-nm", range);
    popupTip("A/P follow: ON");

    setprop("autopilot/settings/target-altitude-ft", 10000);# set some default values until the follow script sets them.
    setprop("autopilot/settings/heading-bug-deg", 0);
    setprop("autopilot/settings/target-speed-kt", 200);

    setprop("/autopilot/locks/speed", "speed-with-throttle");
    setprop("/autopilot/locks/altitude", "altitude-hold");
    setprop("/autopilot/locks/heading", "dg-heading-hold");
  } else {
    setprop("/autopilot/target-tracking-ja37/enable", FALSE);
    popupTip("A/P follow: no valid target.");
    setprop("/autopilot/locks/speed", "");
    setprop("/autopilot/locks/altitude", "");
    setprop("/autopilot/locks/heading", "");
  }
}

var hydr1Lost = func {
  #if hydraulic system1 loses pressure or too low voltage then disengage A/P.
  if (input.hydr1On.getValue() == 0 or input.dcVolt.getValue() < 23) {
    setprop("sim/ja37/avionics/autopilot", TRUE);
    stopAP();
  } else {
    setprop("sim/ja37/avionics/autopilot", FALSE);
  }
  settimer(hydr1Lost, 1);
}

var unfollow = func () {
  popupTip("A/P follow: OFF");
  stopAP();
}

var stopAP = func {
  setprop("/autopilot/target-tracking-ja37/enable", FALSE);
  setprop("/autopilot/locks/speed", "");
  setprop("/autopilot/locks/altitude", "");
  setprop("/autopilot/locks/heading", "");
}

var lostfollow = func () {
  popupTip("A/P follow: lost target.");
  stopAP();
}

var apCont = func {
  unfollow();
  setprop("autopilot/settings/target-altitude-ft", getprop("instrumentation/altimeter/indicated-altitude-ft"));
  setprop("autopilot/settings/heading-bug-deg", getprop("orientation/heading-magnetic-deg"));
  setprop("autopilot/settings/target-speed-kt", getprop("instrumentation/airspeed-indicator/indicated-speed-kt"));

  setprop("/autopilot/locks/speed", "speed-with-throttle");
  setprop("/autopilot/locks/altitude", "altitude-hold");
  setprop("/autopilot/locks/heading", "dg-heading-hold");

  screen.log.write("A/P continuing on current heading, speed and altitude.", 0.0, 1.0, 0.0);
}

var applyParkingBrake = func(v) {
    controls.applyParkingBrake(v);
    if(!v) return;
    ja37.click();
    if (getprop("/controls/gear/brake-parking") == TRUE) {
      popupTip("Parking brakes: ON");
    } else {
      popupTip("Parking brakes: OFF");
    }
}

var cycleSmoke = func() {
    ja37.click();
    if (getprop("/sim/ja37/effect/smoke-cmd") == 1) {
      setprop("/sim/ja37/effect/smoke-cmd", 2);
      popupTip("Smoke: Yellow");
    } elsif (getprop("/sim/ja37/effect/smoke-cmd") == 2) {
      setprop("/sim/ja37/effect/smoke-cmd", 3);
      popupTip("Smoke: Blue");
    } else {
      setprop("/sim/ja37/effect/smoke-cmd", 1);#1 for backward compatibility to be off per default
      popupTip("Smoke: OFF");
    }
}

reloadAir2Air = func {
  # Reload missiles - 4 of them.
  setprop("payload/weight[0]/selected", "RB 24J");
  setprop("payload/weight[1]/selected", "RB 24J");
  setprop("payload/weight[2]/selected", "RB 24J");
  setprop("payload/weight[3]/selected", "RB 24J");
  screen.log.write("RB 24J missiles attached", 0.0, 1.0, 0.0);

  # Reload flares - 40 of them.
  setprop("ai/submodels/submodel[0]/count", 60);
  setprop("ai/submodels/submodel[1]/count", 60);
  screen.log.write("60 flares loaded", 0.0, 1.0, 0.0);

  # Reload cannon - 146 of them.
  #setprop("ai/submodels/submodel[2]/count", 29);
  setprop("ai/submodels/submodel[3]/count", 146);
  setprop("ai/submodels/submodel[4]/count", 146);
  screen.log.write("146 cannon rounds loaded", 0.0, 1.0, 0.0);
}

reloadAir2Ground = func {
  # Reload missiles - 4 of them.
  setprop("payload/weight[0]/selected", "M70");
  setprop("payload/weight[1]/selected", "M70");
  setprop("payload/weight[2]/selected", "M70");
  setprop("payload/weight[3]/selected", "M70");
  setprop("ai/submodels/submodel[5]/count", 6);
  setprop("ai/submodels/submodel[6]/count", 6);
  setprop("ai/submodels/submodel[7]/count", 6);
  setprop("ai/submodels/submodel[8]/count", 6);
  screen.log.write("Bofors M70 rocket pods attached", 0.0, 1.0, 0.0);

  # Reload flares - 40 of them.
  setprop("ai/submodels/submodel[0]/count", 60);
  setprop("ai/submodels/submodel[1]/count", 60);
  screen.log.write("60 flares loaded", 0.0, 1.0, 0.0);

  # Reload cannon - 146 of them.
  #setprop("ai/submodels/submodel[2]/count", 29);
  setprop("ai/submodels/submodel[3]/count", 146);
  setprop("ai/submodels/submodel[4]/count", 146);
  screen.log.write("146 cannon rounds loaded", 0.0, 1.0, 0.0);
}

var popupTip = func(label, y = 25, delay = nil) {
    #var node = props.Node.new({ "label": label, "x": getprop('/sim/startup/xsize')/2, "y": -y+getprop('/sim/startup/ysize'), "tooltip-id": "msg", "reason": "click"});
    #fgcommand("set-tooltip", node);
    #fgcommand("tooltip-timeout", props.Node.new({}));
    #var tooltip = canvas.Tooltip.new([300, 100]);
    #tooltip.createCanvas();
    if(getprop("sim/ja37/supported/popuptips") == 2) {
      gui.popupTip(label, delay, nil, {"y": y});
    } elsif(getprop("sim/ja37/supported/popuptips") == 0) {
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

var repair = func () {
  var ver = getprop("sim/ja37/supported/crash-system");
  if (ver == 0) {
    crash0.repair();
  } else {
    crash1.repair();
    failureSys.armAllTriggers();
  }
}

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
  setprop("payload/weight[4]/selected", "Drop Tank");
  input.tank8Selected.setValue(TRUE);
  input.tank8Jettison.setValue(FALSE);
  setprop("consumables/fuel/tank[8]/level-norm", 1.0);

  screen.log.write("Fuel configured for long range flight.", 0.0, 1.0, 0.0);
}