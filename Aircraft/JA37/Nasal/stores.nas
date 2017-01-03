var STORES_UPDATE_PERIOD = 0.05;

var FALSE = 0;
var TRUE = 1;

var MISSILE_STANDBY = -1;
var MISSILE_SEARCH = 0;
var MISSILE_LOCK = 1;
var MISSILE_FLYING = 2;

var flareCount = -1;
var flareStart = -1;

input = {
  acInstrVolt:      "systems/electrical/outputs/ac-instr-voltage",
  acMainVolt:       "systems/electrical/outputs/ac-main-voltage",
  asymLoad:         "fdm/jsbsim/inertia/asymmetric-wing-load",
  combat:           "/ja37/hud/current-mode",
  dcVolt:           "systems/electrical/outputs/dc-voltage",
  elapsed:          "sim/time/elapsed-sec",
  elecMain:         "controls/electric/main",
  engineRunning:    "engines/engine/running",
  gearCmdNorm:      "/fdm/jsbsim/gear/gear-cmd-norm",
  gearsPos:         "gear/gear/position-norm",
  hz05:             "ja37/blink/five-Hz/state",
  hz10:             "ja37/blink/ten-Hz/state",
  hzThird:          "ja37/blink/third-Hz/state",
  impact:           "/ai/models/model-impact",
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
  replay:           "sim/replay/replay-state",
  serviceElec:      "systems/electrical/serviceable",
  stationSelect:    "controls/armament/station-select",
  subAmmo2:         "ai/submodels/submodel[2]/count", 
  subAmmo3:         "ai/submodels/submodel[3]/count", 
  subAmmo9:         "ai/submodels/submodel[9]/count", 
  subAmmo10:         "ai/submodels/submodel[10]/count", 
  subAmmo11:         "ai/submodels/submodel[11]/count", 
  subAmmo12:         "ai/submodels/submodel[12]/count",
  subAmmo13:         "ai/submodels/submodel[13]/count", 
  subAmmo14:         "ai/submodels/submodel[14]/count", 
  tank8Jettison:    "/consumables/fuel/tank[8]/jettisoned",
  tank8LvlNorm:     "/consumables/fuel/tank[8]/level-norm",
  tank8Selected:    "/consumables/fuel/tank[8]/selected",
  trigger:          "controls/armament/trigger",
  wow0:             "fdm/jsbsim/gear/unit[0]/WOW",
  wow1:             "fdm/jsbsim/gear/unit[1]/WOW",
  wow2:             "fdm/jsbsim/gear/unit[2]/WOW",
  dev:              "dev",
};

############ main stores loop #####################

var loop_stores = func {

    if(input.replay.getValue() == TRUE) {
      # replay is active, skip rest of loop.
      settimer(loop_stores, STORES_UPDATE_PERIOD);
      return;
    }

    if (props.globals.getNode("payload/weight[6]/selected").getValue() == "RB 04E Attackrobot") {
      # if the rb04 is on center pylon, only room for sidewinders on fuselage pylons.
      var payloadName = props.globals.getNode("payload/weight[1]/selected");
      if (payloadName.getValue() != "none" and payloadName.getValue() != "RB 24 Sidewinder" and payloadName.getValue() != "RB 24J Sidewinder" and payloadName.getValue() != "RB 74 Sidewinder") {
        payloadName.setValue("none");
        screen.log.write("Armament on left fuselage pylon removed, no room for it.", 1.0, 0.0, 0.0);
      }
      payloadName = props.globals.getNode("payload/weight[3]/selected");
      if (payloadName.getValue() != "none" and payloadName.getValue() != "RB 24 Sidewinder" and payloadName.getValue() != "RB 24J Sidewinder" and payloadName.getValue() != "RB 74 Sidewinder") {
        payloadName.setValue("none");
        screen.log.write("Armament on right fuselage pylon removed, no room for it.", 1.0, 0.0, 0.0);
      }
    }

    # pylon payloads
    for(var i=0; i<=6; i=i+1) {
      var payloadName = props.globals.getNode("payload/weight["~ i ~"]/selected");
      var payloadWeight = props.globals.getNode("payload/weight["~ i ~"]/weight-lb");
      
      if(payloadName.getValue() != "none" and (
          (payloadName.getValue() == "M70 ARAK" and payloadWeight.getValue() != 794)
          or (payloadName.getValue() == "M55 AKAN" and payloadWeight.getValue() != 802.5)
          or (payloadName.getValue() == "M71 Bomblavett" and payloadWeight.getValue() != 1060)
          or (payloadName.getValue() == "M71 Bomblavett (Retarded)" and payloadWeight.getValue() != 1062)
          or (payloadName.getValue() == "RB 24 Sidewinder" and payloadWeight.getValue() != 160.94)
          or (payloadName.getValue() == "RB 24J Sidewinder" and payloadWeight.getValue() != 179)
          or (payloadName.getValue() == "RB 74 Sidewinder" and payloadWeight.getValue() != 188)
          or (payloadName.getValue() == "RB 71 Skyflash" and payloadWeight.getValue() != 425)
          or (payloadName.getValue() == "RB 99 Amraam" and payloadWeight.getValue() != 291)
          or (payloadName.getValue() == "RB 15F Attackrobot" and payloadWeight.getValue() != 1763.7)
          or (payloadName.getValue() == "RB 04E Attackrobot" and payloadWeight.getValue() != 1378)
          or (payloadName.getValue() == "RB 05A Attackrobot" and payloadWeight.getValue() != 672.4)
          or (payloadName.getValue() == "RB 75 Maverick" and payloadWeight.getValue() != 462)
          or (payloadName.getValue() == "M90 Bombkapsel" and payloadWeight.getValue() != 1322.77)
          or (payloadName.getValue() == "TEST" and payloadWeight.getValue() != 50)
          or (payloadName.getValue() == "Drop tank" and payloadWeight.getValue() != 211.64))) {
        # armament or drop tank was loaded manually through payload/fuel dialog, so setting the pylon to not released
        setprop("controls/armament/station["~(i+1)~"]/released", FALSE);
        #print("adding "~i);
        if (payloadName.getValue() == "RB 24 Sidewinder") {
          # is not center pylon and is RB24
          #print("rb24 "~i);
          if(armament.AIM.active[i] != nil and armament.AIM.active[i].type != "RB-24") {
            # remove aim-7 logic from that pylon
            #print("removing aim-7 logic");
            armament.AIM.active[i].del();
          }
          if(armament.AIM.new(i, "RB-24", "Sidewinder") == -1 and armament.AIM.active[i].status == MISSILE_FLYING) {
            #missile added through menu while another from that pylon is still flying.
            #to handle this we have to ignore that addition.
            setprop("controls/armament/station["~(i+1)~"]/released", TRUE);
            payloadName.setValue("none");
            #print("refusing to mount new RB-24 missile yet "~i);
          }
        } elsif (payloadName.getValue() == "RB 04E Attackrobot") {
          # is not center pylon and is RB24j
          #print("rb24j "~i);
          if(armament.AIM.active[i] != nil and armament.AIM.active[i].type != "RB-04E") {
            # remove aim-7 logic from that pylon
            #print("removing aim-7 logic");
            armament.AIM.active[i].del();
          }
          if(armament.AIM.new(i, "RB-04E", "Attackrobot") == -1 and armament.AIM.active[i].status == MISSILE_FLYING) {
            #missile added through menu while another from that pylon is still flying.
            #to handle this we have to ignore that addition.
            setprop("controls/armament/station["~(i+1)~"]/released", TRUE);
            payloadName.setValue("none");
            #print("refusing to mount new RB-24j missile yet "~i);
          }
        } elsif (payloadName.getValue() == "RB 05A Attackrobot") {
          # is not center pylon and is RB24j
          #print("rb24j "~i);
          if(armament.AIM.active[i] != nil and armament.AIM.active[i].type != "RB-05A") {
            # remove aim-7 logic from that pylon
            #print("removing aim-7 logic");
            armament.AIM.active[i].del();
          }
          if(armament.AIM.new(i, "RB-05A", "Attackrobot") == -1 and armament.AIM.active[i].status == MISSILE_FLYING) {
            #missile added through menu while another from that pylon is still flying.
            #to handle this we have to ignore that addition.
            setprop("controls/armament/station["~(i+1)~"]/released", TRUE);
            payloadName.setValue("none");
            #print("refusing to mount new RB-24j missile yet "~i);
          }
        } elsif (payloadName.getValue() == "RB 75 Maverick") {
          # is not center pylon and is RB24j
          #print("rb24j "~i);
          if(armament.AIM.active[i] != nil and armament.AIM.active[i].type != "RB-75") {
            # remove aim-7 logic from that pylon
            #print("removing aim-7 logic");
            armament.AIM.active[i].del();
          }
          if(armament.AIM.new(i, "RB-75", "Maverick") == -1 and armament.AIM.active[i].status == MISSILE_FLYING) {
            #missile added through menu while another from that pylon is still flying.
            #to handle this we have to ignore that addition.
            setprop("controls/armament/station["~(i+1)~"]/released", TRUE);
            payloadName.setValue("none");
            #print("refusing to mount new RB-24j missile yet "~i);
          }
        } elsif (payloadName.getValue() == "M90 Bombkapsel") {
          # is not center pylon and is RB24j
          #print("rb24j "~i);
          if(armament.AIM.active[i] != nil and armament.AIM.active[i].type != "M90") {
            # remove aim-7 logic from that pylon
            #print("removing aim-7 logic");
            armament.AIM.active[i].del();
          }
          if(armament.AIM.new(i, "M90", "Bombkapsel") == -1 and armament.AIM.active[i].status == MISSILE_FLYING) {
            #missile added through menu while another from that pylon is still flying.
            #to handle this we have to ignore that addition.
            setprop("controls/armament/station["~(i+1)~"]/released", TRUE);
            payloadName.setValue("none");
            #print("refusing to mount new RB-24j missile yet "~i);
          }
        } elsif (payloadName.getValue() == "RB 24J Sidewinder") {
          # is not center pylon and is RB24j
          #print("rb24j "~i);
          if(armament.AIM.active[i] != nil and armament.AIM.active[i].type != "RB-24J") {
            # remove aim-7 logic from that pylon
            #print("removing aim-7 logic");
            armament.AIM.active[i].del();
          }
          if(armament.AIM.new(i, "RB-24J", "Sidewinder") == -1 and armament.AIM.active[i].status == MISSILE_FLYING) {
            #missile added through menu while another from that pylon is still flying.
            #to handle this we have to ignore that addition.
            setprop("controls/armament/station["~(i+1)~"]/released", TRUE);
            payloadName.setValue("none");
            #print("refusing to mount new RB-24j missile yet "~i);
          }
        } elsif (payloadName.getValue() == "RB 74 Sidewinder") {
          # is not center pylon and is RB74
          #print("rb74 "~i);
          if(armament.AIM.active[i] != nil and armament.AIM.active[i].type != "RB-74") {
            # remove aim-7 logic from that pylon
            #print("removing aim-7 logic");
            armament.AIM.active[i].del();
          }
          if(armament.AIM.new(i, "RB-74", "Sidewinder") == -1 and armament.AIM.active[i].status == MISSILE_FLYING) {
            #missile added through menu while another from that pylon is still flying.
            #to handle this we have to ignore that addition.
            setprop("controls/armament/station["~(i+1)~"]/released", TRUE);
            payloadName.setValue("none");
            #print("refusing to mount new RB-74 missile yet "~i);
          }
        } elsif (payloadName.getValue() == "M71 Bomblavett") {
          # is not center pylon and is RB74
          #print("m71 "~i);
          setprop("payload/weight["~i~"]/ammo", 4);
          if(armament.AIM.active[i] != nil and armament.AIM.active[i].type != "M71") {
            # remove aim-7 logic from that pylon
            #print("removing aim-7 logic");
            armament.AIM.active[i].del();
          }
        } elsif (payloadName.getValue() == "M71 Bomblavett (Retarded)") {
          # is not center pylon and is RB74
          #print("m71 "~i);
          setprop("payload/weight["~i~"]/ammo", 4);
          if(armament.AIM.active[i] != nil and armament.AIM.active[i].type != "M71R") {
            # remove aim-7 logic from that pylon
            #print("removing aim-7 logic");
            armament.AIM.active[i].del();
          }
        } elsif (payloadName.getValue() == "M70 ARAK") {
            if (i == 6) {
              setprop("ai/submodels/submodel["~(15)~"]/count", 6);
            } else {
              setprop("ai/submodels/submodel["~(5+i)~"]/count", 6);
            }
            if(armament.AIM.active[i] != nil and armament.AIM.active[i].status != MISSILE_FLYING) {
              # remove aim logic from that pylon
              armament.AIM.active[i].del();
              #print("removing aim logic");
            }
        } elsif (payloadName.getValue() == "M55 AKAN") {
            var model = i==0?10:(i==2?12:14);
            setprop("ai/submodels/submodel["~model~"]/count", 150);
            if(armament.AIM.active[i] != nil and armament.AIM.active[i].status != MISSILE_FLYING) {
              # remove aim logic from that pylon
              armament.AIM.active[i].del();
              #print("removing aim logic");
            }
        } elsif (payloadName.getValue() == "RB 71 Skyflash") {
          # is not center pylon and is RB71
          #print("rb71 "~i);
          if(armament.AIM.active[i] != nil and armament.AIM.active[i].type != "RB-71") {
            # remove aim-9 logic from that pylon
            #print("removing aim-9 logic");
            armament.AIM.active[i].del();
          }
          if(armament.AIM.new(i, "RB-71", "Skyflash") == -1 and armament.AIM.active[i].status == MISSILE_FLYING) {
            #missile added through menu while another from that pylon is still flying.
            #to handle this we have to ignore that addition.
            setprop("controls/armament/station["~(i+1)~"]/released", TRUE);
            payloadName.setValue("none");
            #print("refusing to mount new RB-71 missile yet "~i);
          }
        } elsif (payloadName.getValue() == "RB 99 Amraam") {
          # is not center pylon and is RB99
          #print("rb71 "~i);
          if(armament.AIM.active[i] != nil and armament.AIM.active[i].type != "RB-99") {
            # remove aim-9 logic from that pylon
            #print("removing aim-9 logic");
            armament.AIM.active[i].del();
          }
          if(armament.AIM.new(i, "RB-99", "Amraam") == -1 and armament.AIM.active[i].status == MISSILE_FLYING) {
            #missile added through menu while another from that pylon is still flying.
            #to handle this we have to ignore that addition.
            setprop("controls/armament/station["~(i+1)~"]/released", TRUE);
            payloadName.setValue("none");
            #print("refusing to mount new RB-71 missile yet "~i);
          }
        } elsif (payloadName.getValue() == "TEST") {
          # is not center pylon and is RB99
          #print("rb71 "~i);
          if(armament.AIM.active[i] != nil and armament.AIM.active[i].type != "TEST") {
            # remove aim-9 logic from that pylon
            #print("removing aim-9 logic");
            armament.AIM.active[i].del();
          }
          if(armament.AIM.new(i, "TEST", "Missile-X") == -1 and armament.AIM.active[i].status == MISSILE_FLYING) {
            #missile added through menu while another from that pylon is still flying.
            #to handle this we have to ignore that addition.
            setprop("controls/armament/station["~(i+1)~"]/released", TRUE);
            payloadName.setValue("none");
            #print("refusing to mount new RB-71 missile yet "~i);
          }
        } elsif (payloadName.getValue() == "RB 15F Attackrobot") {
          # is not center pylon and is RB99
          #print("rb71 "~i);
          if(armament.AIM.active[i] != nil and armament.AIM.active[i].type != "RB-15F") {
            # remove aim-9 logic from that pylon
            #print("removing aim-9 logic");
            armament.AIM.active[i].del();
          }
          if(armament.AIM.new(i, "RB-15F", "Robot 15F") == -1 and armament.AIM.active[i].status == MISSILE_FLYING) {
            #missile added through menu while another from that pylon is still flying.
            #to handle this we have to ignore that addition.
            setprop("controls/armament/station["~(i+1)~"]/released", TRUE);
            payloadName.setValue("none");
            #print("refusing to mount new RB-71 missile yet "~i);
          }
        }
      }
      if(payloadName.getValue() == "M71 Bomblavett") {
        var ammo = getprop("payload/weight["~i~"]/ammo");
        if(ammo > 0) {
          if(armament.AIM.new(i, "M71", "Virgo") != -1) {
            # loaded a bomb            
          } else {
            # AIM already loaded
          }
        }
      }
      if(payloadName.getValue() == "M71 Bomblavett (Retarded)") {
        var ammo = getprop("payload/weight["~i~"]/ammo");
        if(ammo > 0) {
          if(armament.AIM.new(i, "M71R", "Virgo") != -1) {
            # loaded a bomb            
          } else {
            # AIM already loaded
          }
        }
      }
      if(payloadName.getValue() == "none") {# and payloadWeight.getValue() != 0) {
        if(armament.AIM.active[i] != nil) {
          # pylon emptied through menu, so remove the logic
          #print("removing aim logic");
          armament.AIM.active[i].del();
        }
      }
    }

    #activate searcher on selected pylon if missile mounted
    var armSelect = input.stationSelect.getValue();
    if (armSelect == 0) {
      setprop("ja37/avionics/vid", FALSE);
    }
    for(i = 0; i <= 6; i += 1) {
      var payloadName = props.globals.getNode("payload/weight["~ i ~"]/selected");
      if(armament.AIM.active[i] != nil) {
        # missile is mounted on pylon
        if(armSelect != (i+1) and armament.AIM.active[i].status != MISSILE_FLYING) {
          #pylon not selected, and not flying set missile on standby
          armament.AIM.active[i].status = MISSILE_STANDBY;
          #print("not sel "~i);
        } elsif (input.acMainVolt.getValue() < 150 or input.combat.getValue() != 2
                  or (armament.AIM.active[i].status != MISSILE_STANDBY
                      and armament.AIM.active[i].status != MISSILE_FLYING
                      and payloadName.getValue() == "none")) {
          #pylon has logic but missile not mounted and not flying or not in tactical mode or has no power
          armament.AIM.active[i].status = MISSILE_STANDBY;
          #print("empty "~i);
        } elsif (armSelect == (i+1) and armament.AIM.active[i].status == MISSILE_STANDBY
                  and input.combat.getValue() == 2) { # and payloadName.getValue() == "RB 24J"
          #pylon selected, missile mounted, in tactical mode, activate search
          armament.AIM.active[i].status = MISSILE_SEARCH;
          #print("active "~i);
          armament.AIM.active[i].search();
        } 
      }
      if (armSelect == (i+1)) {
        if(payloadName.getValue() == "RB 75 Maverick"
                and armament.AIM.active[i] != nil
                and armament.AIM.active[i].status == MISSILE_SEARCH
                and input.combat.getValue() == 2) {
          #pylon selected, maverick mounted, in tactical mode, searching: activate VID
          setprop("ja37/avionics/vid", TRUE);
        } else {
          setprop("ja37/avionics/vid", FALSE);
        }
      }
    }

    var selected = nil;
    for(var i=0; i<=6; i=i+1) { # set JSBSim mass
      selected = getprop("payload/weight["~i~"]/selected");
      if(i==6 and selected != "Drop tank") {
        # no drop tank attached
        input.tank8Selected.setValue(FALSE);
        input.tank8Jettison.setValue(TRUE);
        input.tank8LvlNorm.setValue(0);
      }
      if(selected == "none") {
        # the pylon is empty, set its pointmass to zero
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 0) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 0);
        }
      } elsif (selected == "RB 24 Sidewinder") {
        # the pylon has a sidewinder, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 160.94) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 160.94);
        }
      } elsif (selected == "RB 24J Sidewinder") {
        # the pylon has a sidewinder, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 179) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 179);
        }
      } elsif (selected == "RB 74 Sidewinder") {
        # the pylon has a sidewinder, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 188) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 188);
        }
      } elsif (selected == "RB 71 Skyflash") {
        # the pylon has a skyflash, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 425) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 425);
        }
      } elsif (selected == "RB 99 Amraam") {
        # the pylon has a amraam, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 291) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 291);
        }
      } elsif (selected == "M70 ARAK") {
        # the pylon has a rocket pod, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 794) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 794);
        }
      } elsif (selected == "TEST") {
        # the pylon has a rocket pod, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 50) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 50);
        }
      } elsif (selected == "RB 15F Attackrobot") {
        # the pylon has a rocket pod, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 1763.7) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 1763.7);
        }
      } elsif (selected == "RB 04E Attackrobot") {
        # the pylon has a rocket pod, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 1378) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 1378);
        }
      } elsif (selected == "RB 05A Attackrobot") {
        # the pylon has a rocket pod, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 672.4) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 672.4);
        }
      } elsif (selected == "RB 75 Maverick") {
        # the pylon has a rocket pod, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 462) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 462);
        }
      } elsif (selected == "M90 Bombkapsel") {
        # the pylon has a rocket pod, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 1322.77) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 1322.77);
        }
      } elsif (selected == "M71 Bomblavett") {
        # the pylon has a rocket pod, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 1060) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 1060);
        }
      } elsif (selected == "M71 Bomblavett (Retarded)") {
        # the pylon has a rocket pod, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 1062) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 1062);
        }
      } elsif (selected == "M55 AKAN") {
        # the pylon has a rocket pod, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 802.5) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 802.5);
        }
      } elsif (selected == "Drop tank") {
        # the pylon has a drop tank, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 211.64) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 211.64);#if change this also change it in jsbsim and -set file
        }
        input.tank8Selected.setValue(TRUE);
        input.tank8Jettison.setValue(FALSE);
      }
    }

    # for aerodynamic response to asymmetric wing loading
    if( (input.mass1.getValue()+input.mass5.getValue()) == (input.mass3.getValue()+input.mass6.getValue()) ) {
      # wing pylons symmetric loaded
      if (input.asymLoad.getValue() != 0) {
        input.asymLoad.setValue(0);
      }
    } elsif( (input.mass1.getValue()+input.mass5.getValue()) < (input.mass3.getValue()+input.mass6.getValue()) ) {
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

    if(getprop("dev") == TRUE) {
      for(var i=0; i<=6; i=i+1) {
        var payloadName = props.globals.getNode("payload/weight["~ i ~"]/selected");
        var payloadWeight = props.globals.getNode("payload/weight["~ i ~"]/weight-lb");
      
        if (i == 0) {
          payloadName.setValue("RB 71 Skyflash");
        } elsif (i == 2) {
          payloadName.setValue("RB 71 Skyflash");
        } elsif (i == 1 or i == 3) {
          payloadName.setValue("RB 99 Amraam");
        } elsif (i == 4) {
          payloadName.setValue("RB 74 Sidewinder");
        } elsif (i == 5) {
          payloadName.setValue("TEST");
        }
      }
    }

    #tracer ammo, due to it might run out faster than cannon rounds due to submodel delay not being precise
    if(input.subAmmo3.getValue() > 0) {
      input.subAmmo2.setValue(-1);
    } else {
      input.subAmmo2.setValue(0);
    }
    if(input.subAmmo10.getValue() > 0) {
      input.subAmmo9.setValue(-1);
    } else {
      input.subAmmo9.setValue(0);
    }
    if(input.subAmmo12.getValue() > 0) {
      input.subAmmo11.setValue(-1);
    } else {
      input.subAmmo11.setValue(0);
    }
    if(input.subAmmo14.getValue() > 0) {
      input.subAmmo13.setValue(-1);
    } else {
      input.subAmmo13.setValue(0);
    }

    # outer stores
    var leftRb2474 = getprop("fdm/jsbsim/inertia/pointmass-weight-lbs[5]") == 188 or getprop("fdm/jsbsim/inertia/pointmass-weight-lbs[5]") == 179;
    var rightRb2474 = getprop("fdm/jsbsim/inertia/pointmass-weight-lbs[6]") == 188 or getprop("fdm/jsbsim/inertia/pointmass-weight-lbs[6]") == 179;
    var wtv = getprop("fdm/jsbsim/effects/wingtip-vapour");
    input.MPint19.setIntValue(ja37.encode3bits(leftRb2474, rightRb2474, wtv));

  # Flare release
  if (getprop("ai/submodels/submodel[0]/flare-release-snd") == nil) {
    setprop("ai/submodels/submodel[0]/flare-release-snd", FALSE);
    setprop("ai/submodels/submodel[0]/flare-release-out-snd", FALSE);
  }
  var flareOn = getprop("ai/submodels/submodel[0]/flare-release-cmd");
  if (flareOn == TRUE and getprop("ai/submodels/submodel[0]/flare-release") == FALSE
      and getprop("ai/submodels/submodel[0]/flare-release-out-snd") == FALSE
      and getprop("ai/submodels/submodel[0]/flare-release-snd") == FALSE) {
    flareCount = getprop("ai/submodels/submodel[0]/count");
    flareStart = input.elapsed.getValue();
    setprop("ai/submodels/submodel[0]/flare-release-cmd", FALSE);
    if (flareCount > 0) {
      # release a flare
      setprop("ai/submodels/submodel[0]/flare-release-snd", TRUE);
      setprop("ai/submodels/submodel[0]/flare-release", TRUE);
      setprop("rotors/main/blade[3]/flap-deg", flareStart);
    } else {
      # play the sound for out of flares
      setprop("ai/submodels/submodel[0]/flare-release-out-snd", TRUE);
    }
  }
  if (getprop("ai/submodels/submodel[0]/flare-release-snd") == TRUE and (flareStart + 1) < input.elapsed.getValue()) {
    setprop("ai/submodels/submodel[0]/flare-release-snd", FALSE);
    setprop("rotors/main/blade[3]/flap-deg", 0);
  }
  if (getprop("ai/submodels/submodel[0]/flare-release-out-snd") == TRUE and (flareStart + 1) < input.elapsed.getValue()) {
    setprop("ai/submodels/submodel[0]/flare-release-out-snd", FALSE);
  }
  if (flareCount > getprop("ai/submodels/submodel[0]/count")) {
    # A flare was released in last loop, we stop releasing flares, so user have to press button again to release new.
    setprop("ai/submodels/submodel[0]/flare-release", FALSE);
    flareCount = -1;
  }

  settimer(func { loop_stores() }, STORES_UPDATE_PERIOD);
}


###########  listener for handling the trigger #########

var trigger_listener = func {
  var trigger = input.trigger.getValue();
  var armSelect = input.stationSelect.getValue();

  #if masterarm is on and HUD in tactical mode, propagate trigger to station
  if(input.combat.getValue() == 2 and input.dcVolt.getValue() > 23 and !(armSelect == 0 and input.acInstrVolt.getValue() < 100)) {
    setprop("/controls/armament/station["~armSelect~"]/trigger", trigger);
    var str = "payload/weight["~(armSelect-1)~"]/selected";
    if (armSelect != 0 and getprop(str) == "M70 ARAK") {
      setprop("/controls/armament/station["~1~"]/trigger-m70", trigger);
      setprop("/controls/armament/station["~2~"]/trigger-m70", trigger);
      setprop("/controls/armament/station["~3~"]/trigger-m70", trigger);
      setprop("/controls/armament/station["~4~"]/trigger-m70", trigger);
      setprop("/controls/armament/station["~7~"]/trigger-m70", trigger);
    }
    if (armSelect == 1 and getprop(str) == "M55 AKAN") {
      setprop("/controls/armament/station[8]/trigger", trigger);
      var str3 = "payload/weight["~(3-1)~"]/selected";
      if (getprop(str3) == "M55 AKAN") {
        setprop("/controls/armament/station[9]/trigger", trigger);
      }
      var str7 = "payload/weight["~(7-1)~"]/selected";
      if (getprop(str7) == "M55 AKAN") {
        setprop("/controls/armament/station[10]/trigger", trigger);
      }
    }
    if (armSelect == 3 and getprop(str) == "M55 AKAN") {
      setprop("/controls/armament/station[9]/trigger", trigger);
      var str1 = "payload/weight["~(1-1)~"]/selected";
      if (getprop(str1) == "M55 AKAN") {
        setprop("/controls/armament/station[8]/trigger", trigger);
      }
      var str7 = "payload/weight["~(7-1)~"]/selected";
      if (getprop(str7) == "M55 AKAN") {
        setprop("/controls/armament/station[10]/trigger", trigger);
      }
    }
    if (armSelect == 7 and getprop(str) == "M55 AKAN") {
      setprop("/controls/armament/station[10]/trigger", trigger);
      var str1 = "payload/weight["~(1-1)~"]/selected";
      if (getprop(str1) == "M55 AKAN") {
        setprop("/controls/armament/station[8]/trigger", trigger);
      }
      var str3 = "payload/weight["~(3-1)~"]/selected";
      if (getprop(str3) == "M55 AKAN") {
        setprop("/controls/armament/station[9]/trigger", trigger);
      }
    }
  } else {
    setprop("/controls/armament/station["~armSelect~"]/trigger", FALSE);
    setprop("/controls/armament/station["~1~"]/trigger-m70", FALSE);
    setprop("/controls/armament/station["~2~"]/trigger-m70", FALSE);
    setprop("/controls/armament/station["~3~"]/trigger-m70", FALSE);
    setprop("/controls/armament/station["~4~"]/trigger-m70", FALSE);
    setprop("/controls/armament/station["~7~"]/trigger-m70", FALSE);
    if (armSelect == 1 or armSelect == 7 or armSelect == 3) {
      setprop("/controls/armament/station[8]/trigger", FALSE);
      setprop("/controls/armament/station[9]/trigger", FALSE);
      setprop("/controls/armament/station[10]/trigger", FALSE);
    }
  }

  var fired = "KCA";
  if (armSelect > 0) {
    fired = getprop("payload/weight["~ (armSelect-1) ~"]/selected");
  }

  if(armSelect != 0 and getprop("/controls/armament/station["~armSelect~"]/trigger") == TRUE) {
    if(getprop("payload/weight["~(armSelect-1)~"]/selected") != "none") { 
      # trigger is pulled, a pylon is selected, the pylon has a missile that is locked on. The gear check is prevent missiles from firing when changing airport location.
      if (armament.AIM.active[armSelect-1] != nil and armament.AIM.active[armSelect-1].status == 1 and (input.gearsPos.getValue() != 1 or input.dev.getValue()==TRUE) and radar_logic.selection != nil) {
        #missile locked, fire it.

        if (fired != "M71 Bomblavett" and fired != "M71 Bomblavett (Retarded)") {
          setprop("payload/weight["~ (armSelect-1) ~"]/selected", "none");# empty the pylon
          setprop("controls/armament/station["~armSelect~"]/released", TRUE);# setting the pylon as fired
        }
        #print("firing missile: "~armSelect~" "~getprop("controls/armament/station["~armSelect~"]/released"));
        var callsign = armament.AIM.active[armSelect-1].callsign;
        var brevity = armament.AIM.active[armSelect-1].brevity;
        armament.AIM.active[armSelect-1].release();#print("release "~(armSelect-1));
        
        var phrase = brevity ~ " at: " ~ callsign;
        if (getprop("payload/armament/msg")) {
          armament.defeatSpamFilter(phrase);
        } else {
          setprop("/sim/messages/atc", phrase);
        }
        var next = TRUE;
        if (fired == "M71 Bomblavett" or fired == "M71 Bomblavett (Retarded)") {
          var ammo = getprop("payload/weight["~(armSelect-1)~"]/ammo");
          ammo = ammo - 1;
          setprop("payload/weight["~(armSelect-1)~"]/ammo", ammo);
          if(ammo > 0) {
            #next = FALSE;
          }
        }
        if(next == TRUE and (fired == "M71 Bomblavett" or fired == "M71 Bomblavett (Retarded)")) {
          var newStation = selectTypeBombs(fired, armSelect);
          if (newStation != -1) {
            input.stationSelect.setValue(newStation);
          }
        } elsif(next == TRUE) {
          var newStation = selectType(fired);
          if (newStation != -1) {
            input.stationSelect.setValue(newStation);
          }
        }
      }
    }
  }
  if (fired == "M70 ARAK") {
    var submodel = armSelect==7?15:armSelect + 4;
    var ammo = getprop("ai/submodels/submodel["~submodel~"]/count");
    if (ammo == 0) {
      var newStation = selectType(fired);
      if (newStation != -1 and hasRockets(newStation) > 0) {
        input.stationSelect.setValue(newStation);
      }
    }
  }
  if (fired == "M55 AKAN") {
    var submodel = armSelect==1?10:(armSelect==3?12:14);
    var ammo = getprop("ai/submodels/submodel["~submodel~"]/count");
    if (ammo == 0) {
      var newStation = selectType(fired);
      if (newStation != -1 and hasShells(newStation) > 0) {
        input.stationSelect.setValue(newStation);
      }
    }
  }
}

############ Cannon impact messages #####################

var last_impact = 0;

var hit_count = 0;

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

        var selectionPos = radar_logic.selection.get_Coord();

        var distance = impactPos.distance_to(selectionPos);
        if (distance < 125) {
          last_impact = input.elapsed.getValue();
          var phrase =  ballistic.getNode("name").getValue() ~ " hit: " ~ radar_logic.selection.get_Callsign();
          if (getprop("payload/armament/msg")) {
            defeatSpamFilter(phrase);
			      #hit_count = hit_count + 1;
          } else {
            setprop("/sim/messages/atc", phrase);
          }
        }
      }
    }
  }
}

############ response to MP messages #####################

var cannon_types = {
    " M70 rocket hit":        0.25, #135mm
    " M55 cannon shell hit":  0.10, # 30mm
    " KCA cannon shell hit":  0.10, # 30mm
    " Gun Splash On ":        0.10, # 30mm
    " M61A1 shell hit":       0.05, # 20mm
    " GAU-8/A hit":           0.10, # 30mm
    " BK27 cannon hit":       0.07, # 27mm
    " GSh-30 hit":            0.10, # 30mm
};
    
    
    
var warhead_lbs = {
    "aim-120":              44.00,
    "AIM120":               44.00,
    "RB-99":                44.00,
    "aim-7":                88.00,
    "AIM-7":                88.00,
    "RB-71":                88.00,
    "aim-9":                20.80,
    "AIM9":                 20.80,
    "AIM-9":                20.80,
    "RB-24":                20.80,
    "RB-24J":               20.80,
    "RB-74":                20.80,
    "R74":                  16.00,
    "MATRA-R530":           55.00,
    "Meteor":               55.00,
    "AIM-54":              135.00,
    "Matra R550 Magic 2":   27.00,
    "Matra MICA":           30.00,
    "RB-15F":              440.92,
    "SCALP":               992.00,
    "KN-06":               315.00,
    "GBU12":               190.00,
    "GBU16":               450.00,
    "Sea Eagle":           505.00,
    "AGM65":               200.00,
    "RB-04E":              661.00,
    "RB-05A":              353.00,
    "RB-75":               126.00,
    "M90":                 500.00,
    "M71":                 200.00,
    "M71R":                200.00,
    "MK-82":               192.00,
    "LAU-68":               10.00,
    "M317":                145.00,
    "GBU-31":              945.00,
    "AIM132":               22.05,
    "ALARM":               450.00,
    "STORMSHADOW":         850.00,
    "R-60":                  6.60,
    "R-27R1":               85.98,
    "R-27T1":               85.98,
};

var fireMsgs = {
  
    # F14
    " FOX3 at":       nil, # radar
    " FOX2 at":       nil, # heat
    " FOX1 at":       nil, # semi-radar

    # Viggen
    " Fox 1 at":      nil, # semi-radar
    " Fox 2 at":      nil, # heat
    " Fox 3 at":      nil, # radar
    " Greyhound at":  nil, # cruise missile
    " Bombs away at": nil, # bombs
    " Bruiser at":    nil, # anti-ship
    " Rifle at":      nil, # TV guided

    # SAM and missile frigate
    " Bird away at":  nil, # G/A

    # F15
    " aim7 at":       nil,
    " aim9 at":       nil,
    " aim120 at":     nil,
};

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
      #print("not me");
      var m2000 = FALSE;
      if (find(" at " ~ callsign ~ ". Release ", last_vector[1]) != -1) {
        # a m2000 is firing at us
        m2000 = TRUE;
      }
      if (contains(fireMsgs, last_vector[1]) or m2000 == TRUE) {
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
                  playIncomingSound("12");
                } elsif (clock >= 15 and clock < 45) {
                  playIncomingSound("1");
                } elsif (clock >= 45 and clock < 75) {
                  playIncomingSound("2");
                } elsif (clock >= 75 and clock < 105) {
                  playIncomingSound("3");
                } elsif (clock >= 105 and clock < 135) {
                  playIncomingSound("4");
                } elsif (clock >= 135 and clock < 165) {
                  playIncomingSound("5");
                } elsif (clock >= 165 and clock < 195) {
                  playIncomingSound("6");
                } elsif (clock >= 195 and clock < 225) {
                  playIncomingSound("7");
                } elsif (clock >= 225 and clock < 255) {
                  playIncomingSound("8");
                } elsif (clock >= 255 and clock < 285) {
                  playIncomingSound("9");
                } elsif (clock >= 285 and clock < 315) {
                  playIncomingSound("10");
                } elsif (clock >= 315 and clock < 345) {
                  playIncomingSound("11");
                } else {
                  playIncomingSound("");
                }

                #The incoming lamps overlap each other:
                if (clock >= 345 or clock <= 75) {
                  incomingLamp("1");
                } 
                if (clock >= 45 and clock <= 135) {
                  incomingLamp("3");
                }
                if (clock >= 105 and clock <= 195) {
                  incomingLamp("5");
                }
                if (clock >= 165 and clock <= 255) {
                  incomingLamp("7");
                }
                if (clock >= 225 and clock <= 315) {
                  incomingLamp("9");
                }
                if (clock >= 285 or clock <= 15) {
                  incomingLamp("11");
                }
                return;
              }
            }
          }
        }
      } elsif (getprop("ja37/supported/old-custom-fails") > 0 and getprop("payload/armament/damage") == 1) {
        # latest or second latest version of failure manager and taking damage enabled
        #print("damage enabled");
        var last1 = split(" ", last_vector[1]);
        if(size(last1) > 2 and last1[size(last1)-1] == "exploded" ) {
          #print("missile hitting someone");
          if (size(last_vector) > 3 and last_vector[3] == " "~callsign) {
            #print("that someone is me!");
            var type = last1[1];
            if (type == "Matra" or type == "Sea") {
              # Matra/seaeagle missiles have spaces in their names, so we fix that here.
              for (var i = 2; i < size(last1)-1; i += 1) {
                type = type~" "~last1[i];
              }
            }
            var number = split(" ", last_vector[2]);
            var distance = num(number[1]);
            #print(type~"|");
            if(distance != nil) {
              var dist = distance;

              if (type == "M90") {
                var prob = rand()*0.5;
                var failed = fail_systems(prob);
                var percent = 100 * prob;
                printf("Took %.1f%% damage from %s clusterbombs at %0.1f meters. %s systems was hit", percent,type,dist,failed);
                nearby_explosion();
                return;
              }

              distance = ja37.clamp(distance-1.5, 0, 1000000);
              var maxDist = 0;

              if (contains(warhead_lbs, type)) {
                maxDist = maxDamageDistFromWarhead(warhead_lbs[type]);
              } else {
                return;
              }

              var diff = maxDist-distance;

              if (diff < 0) {
                diff = 0;
              }

              diff = diff * diff;
              
              var probability = diff / (maxDist*maxDist);

              var failed = fail_systems(probability);
              var percent = 100 * probability;
              printf("Took %.1f%% damage from %s missile at %0.1f meters. %s systems was hit", percent,type,dist,failed);
              nearby_explosion();
            }
          } 
        } elsif (cannon_types[last_vector[1]] != nil) {
          if (size(last_vector) > 2 and last_vector[2] == " "~callsign) {
            var last3 = split(" ", last_vector[3]);
            if(size(last3) > 2 and size(last3[2]) > 2 and last3[2] == "hits" ) {
              var probability = cannon_types[last_vector[1]];
              var hit_count = num(last3[1]);
              if (hit_count != nil) {
                var damaged_sys = 0;
                for (var i = 1; i <= hit_count; i = i + 1) {
                  var failed = fail_systems(probability);
                  damaged_sys = damaged_sys + failed;
                }

                printf("Took %.1f%% x %2d damage from cannon! %s systems was hit.", probability*100, hit_count, damaged_sys);
                nearby_explosion();
              }
            } else {
              var probability = cannon_types[last_vector[1]];
              #print("probability: " ~ probability);
              
              var failed = fail_systems(probability * 3);# Old messages is assumed to be 3 hits
              printf("Took %.1f%% x 3 damage from cannon! %s systems was hit.", probability*100, failed);
              nearby_explosion();
            }
          }
        }
      }
    }
  }
}

var maxDamageDistFromWarhead = func (lbs) {
  # very simple
  var dist = 3*math.sqrt(lbs);

  return dist;
}

var fail_systems = func (probability) {
    var failure_modes = FailureMgr._failmgr.failure_modes;
    var mode_list = keys(failure_modes);
    var failed = 0;
    foreach(var failure_mode_id; mode_list) {
        if (rand() < probability) {
            FailureMgr.set_failure_level(failure_mode_id, 1);
            failed += 1;
        }
    }
    if(probability > 0.19) {
      setprop("environment/damage", 1);
    }
    return failed;
};

var playIncomingSound = func (clock) {
  setprop("ja37/sound/incoming"~clock, 1);
  settimer(func {stopIncomingSound(clock);},3);
}

var stopIncomingSound = func (clock) {
  setprop("ja37/sound/incoming"~clock, 0);
}

var incomingLamp = func (clock) {
  setprop("instrumentation/radar/twr"~clock, 1);
  settimer(func {stopIncomingLamp(clock);},4.5);
}

var stopIncomingLamp = func (clock) {
  setprop("instrumentation/radar/twr"~clock, 0);
}

var nearby_explosion = func {
  setprop("damage/sounds/nearby-explode-on", 0);
  settimer(nearby_explosion_a, 0);
}

var nearby_explosion_a = func {
  setprop("damage/sounds/nearby-explode-on", 1);
  settimer(nearby_explosion_b, 0.5);
}

var nearby_explosion_b = func {
  setprop("damage/sounds/nearby-explode-on", 0);
}

############ weapon selection #####################

var selectType = func (type) {
  var priority = [4,2,3,1,5,6,7];
  var sel = -1;
  var i = 0;

  while (sel == -1 and i < 7) {
    var test = getprop("payload/weight["~(priority[i]-1)~"]/selected");
    if (test == type and hasRockets(priority[i]) != 0 and hasShells(priority[i]) != 0 and hasBombs(priority[i]) != 0 and hasBombsR(priority[i]) != 0) {
      sel = priority[i];
    }
    i += 1;
  }

  return sel;
}

var selectTypeBombs = func (type, current) {
  # drop order as per manual:
  # RF, LF ... RW, LW ... C
  # So RF, LF, RF, LF, RF, LF, RF, LF, RW, LW, RW, LW, RW, LW, RW, LW, C, C, C, C
  var priority = [4,2,4,2,3,1,3,1,7,4,2,4,2,3,1,3,1,7];
  var sel = -1;
  var j = 0;

  var prio = -1;
  while (prio != current) {
    var prio = priority[j];
    j += 1;
  }

  var i = j;

  while (sel == -1 and i < 17) {
    var test = getprop("payload/weight["~(priority[i]-1)~"]/selected");
    if (test == type and hasBombs(priority[i]) != 0 and hasBombsR(priority[i]) != 0) {
      sel = priority[i];
    }
    i += 1;
  }

  return sel;
}

var hasBombs = func (station) {
  var loaded = -1;
  if (getprop("payload/weight["~(station-1)~"]/selected") == "M71 Bomblavett") {
    var payload = station -1; 
    var ammo = getprop("payload/weight["~payload~"]/ammo");
    if (ammo != nil) {
      loaded = ammo;
    }
  }
  return loaded;
}

var hasBombsR = func (station) {
  var loaded = -1;
  if (getprop("payload/weight["~(station-1)~"]/selected") == "M71 Bomblavett (Retarded)") {
    var payload = station -1; 
    var ammo = getprop("payload/weight["~payload~"]/ammo");
    if (ammo != nil) {
      loaded = ammo;
    }
  }
  return loaded;
}

var hasShells = func (station) {
  var loaded = -1;
  if (getprop("payload/weight["~(station-1)~"]/selected") == "M55 AKAN") {
    var submodel = station==1?10:(station==3?12:14);
    var ammo = getprop("ai/submodels/submodel["~submodel~"]/count");
    loaded = ammo;
  }
  return loaded;
}

var hasRockets = func (station) {
  var loaded = -1;
  if (getprop("payload/weight["~(station-1)~"]/selected") == "M70 ARAK") {
    var submodel = station==7?15:station + 4;
    var ammo = getprop("ai/submodels/submodel["~submodel~"]/count");
    loaded = ammo;
  }
  return loaded;
}

var ammoCount = func (station) {
  var ammo = -1;

  if (station == 0) {
    ammo = getprop("ai/submodels/submodel[3]/count");
  } else {
    var type = getprop("payload/weight["~(station-1)~"]/selected");
    if (type == "M70 ARAK") {
      ammo = 0;
      for(var i = 1; i < 8; i += 1) {
        var rockets = hasRockets(i);
        ammo = rockets == -1?ammo:(rockets+ammo);
      }
    } elsif (type == "RB 71 Skyflash") {
      ammo = 0;
      for(var i = 0; i < 8; i += 1) {
        if(getprop("payload/weight["~i~"]/selected") == "RB 71 Skyflash") {
          ammo += 1;
        }
      }
    } elsif (type == "RB 99 Amraam") {
      ammo = 0;
      for(var i = 0; i < 8; i += 1) {
        if(getprop("payload/weight["~i~"]/selected") == "RB 99 Amraam") {
          ammo += 1;
        }
      }
    } elsif (type == "RB 74 Sidewinder") {
      ammo = 0;
      for(var i = 0; i < 8; i += 1) {
        if(getprop("payload/weight["~i~"]/selected") == "RB 74 Sidewinder") {
          ammo += 1;
        }
      }
    } elsif (type == "RB 24J Sidewinder") {
      ammo = 0;
      for(var i = 0; i < 8; i += 1) {
        if(getprop("payload/weight["~i~"]/selected") == "RB 24J Sidewinder") {
          ammo += 1;
        }
      }
    } elsif (type == "RB 24 Sidewinder") {
      ammo = 0;
      for(var i = 0; i < 8; i += 1) {
        if(getprop("payload/weight["~i~"]/selected") == "RB 24 Sidewinder") {
          ammo += 1;
        }
      }
    } elsif (type == "TEST") {
      ammo = 0;
      for(var i = 0; i < 8; i += 1) {
        if(getprop("payload/weight["~i~"]/selected") == "TEST") {
          ammo += 1;
        }
      }
    } elsif (type == "RB 15F Attackrobot") {
      ammo = 0;
      for(var i = 0; i < 8; i += 1) {
        if(getprop("payload/weight["~i~"]/selected") == "RB 15F Attackrobot") {
          ammo += 1;
        }
      }
    } elsif (type == "RB 04E Attackrobot") {
      ammo = 0;
      for(var i = 0; i < 8; i += 1) {
        if(getprop("payload/weight["~i~"]/selected") == "RB 04E Attackrobot") {
          ammo += 1;
        }
      }
    } elsif (type == "RB 05A Attackrobot") {
      ammo = 0;
      for(var i = 0; i < 8; i += 1) {
        if(getprop("payload/weight["~i~"]/selected") == "RB 05A Attackrobot") {
          ammo += 1;
        }
      }
    } elsif (type == "RB 75 Maverick") {
      ammo = 0;
      for(var i = 0; i < 8; i += 1) {
        if(getprop("payload/weight["~i~"]/selected") == "RB 75 Maverick") {
          ammo += 1;
        }
      }
    } elsif (type == "M90 Bombkapsel") {
      ammo = 0;
      for(var i = 0; i < 8; i += 1) {
        if(getprop("payload/weight["~i~"]/selected") == "M90 Bombkapsel") {
          ammo += 1;
        }
      }
    } elsif (type == "M71 Bomblavett") {
      ammo = 0;
      for(var i = 1; i < 8; i += 1) {
        var bombs = hasBombs(i);
        ammo = bombs == -1?ammo:(bombs+ammo);
      }
    } elsif (type == "M71 Bomblavett (Retarded)") {
      ammo = 0;
      for(var i = 1; i < 8; i += 1) {
        var bombs = hasBombsR(i);
        ammo = bombs == -1?ammo:(bombs+ammo);
      }
    } elsif (type == "M55 AKAN") {
      ammo = 0;
      for(var i = 1; i < 8; i += 1) {
        var shells = hasShells(i);
        ammo = shells == -1?ammo:(shells+ammo);
      }
    }
  }
  return ammo;
}

var selectCannon = func {
  if(getprop("ja37/systems/variant") == 0) {
    setprop("controls/armament/station-select", 0);
    ja37.click();
  }
}

var cycle_weapons = func {
  # station 0 = cannon
  # station 1 = inner left wing
  # station 2 = left fuselage
  # station 3 = inner right wing
  # station 4 = right fuselage
  # station 5 = outer left wing
  # station 6 = outer right wing
  # station 7 = center pylon

  var sel = getprop("controls/armament/station-select");
  var type = sel==0?"KCA":getprop("payload/weight["~(sel-1)~"]/selected");
  var newType = "none";

  var loopRan = FALSE;

  while(newType == "none") {
    if (type == "none") {
      if(getprop("ja37/systems/variant") == 0) {
        sel = 0;
        newType = "KCA";
      } else {
        sel = selectType("M70 ARAK");
        if (sel != -1) {
          newType = "M70 ARAK";
        } else {
          type = "M70 ARAK";
        }
      }
    } elsif (type == "KCA") {
      sel = selectType("M70 ARAK");
      if (sel != -1) {
        newType = "M70 ARAK";
      } else {
        type = "M70 ARAK";
      }
    } elsif (type == "M70 ARAK") {
      sel = selectType("RB 99 Amraam");
      if (sel != -1) {
        newType = "RB 99 Amraam";
      } else {
        type = "RB 99 Amraam";
      }
    } elsif (type == "RB 99 Amraam") {
      sel = selectType("RB 71 Skyflash");
      if (sel != -1) {
        newType = "RB 71 Skyflash";
      } else {
        type = "RB 71 Skyflash";
      }
    } elsif (type == "RB 71 Skyflash") {
      sel = selectType("RB 24J Sidewinder");
      if (sel != -1) {
        newType = "RB 24J Sidewinder";
      } else {
        type = "RB 24J Sidewinder";
      }
    } elsif (type == "RB 24J Sidewinder") {
      sel = selectType("RB 24 Sidewinder");
      if (sel != -1) {
        newType = "RB 24 Sidewinder";
      } else {
        type = "RB 24 Sidewinder";
      }
    } elsif (type == "RB 24 Sidewinder") {
      sel = selectType("TEST");
      if (sel != -1) {
        newType = "TEST";
      } else {
        type = "TEST";
      }
    } elsif (type == "TEST") {
      sel = selectType("RB 74 Sidewinder");
      if (sel != -1) {
        newType = "RB 74 Sidewinder";
      } else {
        type = "RB 74 Sidewinder";
      }
    } elsif (type == "RB 74 Sidewinder") {
      sel = selectType("M55 AKAN");
      if (sel != -1) {
        newType = "M55 AKAN";
      } else {
        type = "M55 AKAN";
      }
    } elsif (type == "M55 AKAN") {
      sel = selectType("M71 Bomblavett");
      if (sel != -1) {
        newType = "M71 Bomblavett";
      } else {
        type = "M71 Bomblavett";
      }
    } elsif (type == "M71 Bomblavett") {
      sel = selectType("M71 Bomblavett (Retarded)");
      if (sel != -1) {
        newType = "M71 Bomblavett (Retarded)";
      } else {
        type = "M71 Bomblavett (Retarded)";
      }
    } elsif (type == "M71 Bomblavett (Retarded)") {
      sel = selectType("M90 Bombkapsel");
      if (sel != -1) {
        newType = "M90 Bombkapsel";
      } else {
        type = "M90 Bombkapsel";
      }
    } elsif (type == "M90 Bombkapsel") {
      sel = selectType("RB 04E Attackrobot");
      if (sel != -1) {
        newType = "RB 04E Attackrobot";
      } else {
        type = "RB 04E Attackrobot";
      }
    } elsif (type == "RB 04E Attackrobot") {
      sel = selectType("RB 05A Attackrobot");
      if (sel != -1) {
        newType = "RB 05A Attackrobot";
      } else {
        type = "RB 05A Attackrobot";
      }
    } elsif (type == "RB 05A Attackrobot") {
      sel = selectType("RB 75 Maverick");
      if (sel != -1) {
        newType = "RB 75 Maverick";
      } else {
        type = "RB 75 Maverick";
      }
    } elsif (type == "RB 75 Maverick") {
      sel = selectType("RB 15F Attackrobot");
      if (sel != -1) {
        newType = "RB 15F Attackrobot";
      } else {
        type = "RB 15F Attackrobot";
      }
    } elsif (type == "RB 15F Attackrobot") {
      if(getprop("ja37/systems/variant") == 0) {
        sel = 0;
        newType = "KCA";
      } else {
        sel = selectType("M70 ARAK");
        if (sel != -1) {
          newType = "M70 ARAK";
        } else {
          if (loopRan == FALSE) {
            loopRan = TRUE;
            type = "M70 ARAK";
          } else {
            # we have been here once before, so to prevent infinite loop, we just select station 1
            sel = 1;
            type = "none";
            newType = "empty";
          }
        }
      }
    }
  }

  ja37.click();
  setprop("controls/armament/station-select", sel)
}

############ reload #####################

reloadJAAir2Air1979 = func {
  # Reload missiles - 6 of them.

  # Sidewinder
  setprop("payload/weight[1]/selected", "RB 24J Sidewinder");
  setprop("payload/weight[3]/selected", "RB 24J Sidewinder");
  setprop("payload/weight[4]/selected", "RB 24J Sidewinder");
  setprop("payload/weight[5]/selected", "RB 24J Sidewinder");
  screen.log.write("4 RB-24J missiles attached", 0.0, 1.0, 0.0);

  # Skyflash
  setprop("payload/weight[0]/selected", "RB 71 Skyflash");
  setprop("payload/weight[2]/selected", "RB 71 Skyflash");
  screen.log.write("2 RB-71 missiles attached", 0.0, 1.0, 0.0);

  # Reload flares - 40 of them.
  setprop("ai/submodels/submodel[0]/count", 60);
  setprop("ai/submodels/submodel[1]/count", 60);
  screen.log.write("60 flares loaded", 0.0, 1.0, 0.0);

  # Reload cannon - 146 of them.
  reloadGuns();
  
}

reloadJAAir2Air1987 = func {
  # Reload missiles - 6 of them.

  # Sidewinder
  setprop("payload/weight[1]/selected", "RB 74 Sidewinder");
  setprop("payload/weight[3]/selected", "RB 74 Sidewinder");
  setprop("payload/weight[4]/selected", "RB 74 Sidewinder");
  setprop("payload/weight[5]/selected", "RB 74 Sidewinder");
  screen.log.write("4 RB-74 missiles attached", 0.0, 1.0, 0.0);

  # Skyflash
  setprop("payload/weight[0]/selected", "RB 71 Skyflash");
  setprop("payload/weight[2]/selected", "RB 71 Skyflash");
  screen.log.write("2 RB-71 missiles attached", 0.0, 1.0, 0.0);

  # Reload flares - 40 of them.
  setprop("ai/submodels/submodel[0]/count", 60);
  setprop("ai/submodels/submodel[1]/count", 60);
  screen.log.write("60 flares loaded", 0.0, 1.0, 0.0);

  # Reload cannon - 146 of them.
  reloadGuns();
  
}

reloadJAAir2Air1997 = func {
  # Reload missiles - 6 of them.

  # Amraam
  setprop("payload/weight[1]/selected", "RB 99 Amraam");
  setprop("payload/weight[3]/selected", "RB 99 Amraam");
  setprop("payload/weight[0]/selected", "RB 99 Amraam");
  setprop("payload/weight[2]/selected", "RB 99 Amraam");
  screen.log.write("4 RB-99 missiles attached", 0.0, 1.0, 0.0);

  # Sidewinder
  setprop("payload/weight[4]/selected", "RB 74 Sidewinder");
  setprop("payload/weight[5]/selected", "RB 74 Sidewinder");
  screen.log.write("2 RB-74 missiles attached", 0.0, 1.0, 0.0);

  # Reload flares - 40 of them.
  setprop("ai/submodels/submodel[0]/count", 60);
  setprop("ai/submodels/submodel[1]/count", 60);
  screen.log.write("60 flares loaded", 0.0, 1.0, 0.0);

  # Reload cannon - 146 of them.
  reloadGuns();
  
}

reloadJAAir2Ground = func {
  # Reload missiles - 4 of them.
  setprop("payload/weight[0]/selected", "M70 ARAK");
  setprop("payload/weight[1]/selected", "M70 ARAK");
  setprop("payload/weight[2]/selected", "M70 ARAK");
  setprop("payload/weight[3]/selected", "M70 ARAK");
  setprop("payload/weight[4]/selected", "RB 24J Sidewinder");
  setprop("payload/weight[5]/selected", "RB 24J Sidewinder");
  setprop("ai/submodels/submodel[5]/count", 6);
  setprop("ai/submodels/submodel[6]/count", 6);
  setprop("ai/submodels/submodel[7]/count", 6);
  setprop("ai/submodels/submodel[8]/count", 6);
  screen.log.write("2 Bofors M70 rocket pods attached", 0.0, 1.0, 0.0);
  screen.log.write("2 RB-15F cruise-missiles attached", 0.0, 1.0, 0.0);
  screen.log.write("2 RB-24J Sidewinder attached", 0.0, 1.0, 0.0);

  # Reload flares - 40 of them.
  setprop("ai/submodels/submodel[0]/count", 60);
  setprop("ai/submodels/submodel[1]/count", 60);
  screen.log.write("60 flares loaded", 0.0, 1.0, 0.0);

  # Reload cannon - 146 of them.
  reloadGuns();
  
}

reloadAJAir2Tank = func {
  # Reload missiles - 4 of them.
  setprop("payload/weight[0]/selected", "M70 ARAK");
  setprop("payload/weight[1]/selected", "RB 24J Sidewinder");
  setprop("payload/weight[2]/selected", "M70 ARAK");
  setprop("payload/weight[3]/selected", "RB 75 Maverick");
  setprop("payload/weight[4]/selected", "none");
  setprop("payload/weight[5]/selected", "none");
  setprop("ai/submodels/submodel[6]/count", 6);
  setprop("ai/submodels/submodel[8]/count", 6);
  screen.log.write("2 Bofors M70 rocket pods attached", 0.0, 1.0, 0.0);
  screen.log.write("1 RB-75 Maverick attached", 0.0, 1.0, 0.0);
  screen.log.write("1 RB-24J Sidewinder attached", 0.0, 1.0, 0.0);

  # Reload flares - 40 of them.
  setprop("ai/submodels/submodel[0]/count", 60);
  setprop("ai/submodels/submodel[1]/count", 60);
  screen.log.write("60 flares loaded", 0.0, 1.0, 0.0);

  # Reload cannon - 146 of them.
  reloadGuns();
}

reloadAJAir2Ship = func {
  # Reload missiles - 4 of them.
  setprop("payload/weight[0]/selected", "RB 04E Attackrobot");
  setprop("payload/weight[1]/selected", "RB 05A Attackrobot");
  setprop("payload/weight[2]/selected", "RB 04E Attackrobot");
  setprop("payload/weight[3]/selected", "RB 75 Maverick");
  setprop("payload/weight[4]/selected", "none");
  setprop("payload/weight[5]/selected", "none");
  screen.log.write("1 RB-05A missile attached", 0.0, 1.0, 0.0);
  screen.log.write("2 RB-04E cruise-antiship-missile attached", 0.0, 1.0, 0.0);
  screen.log.write("1 RB-75 Maverick attached", 0.0, 1.0, 0.0);

  # Reload flares - 40 of them.
  setprop("ai/submodels/submodel[0]/count", 60);
  setprop("ai/submodels/submodel[1]/count", 60);
  screen.log.write("60 flares loaded", 0.0, 1.0, 0.0);

  # Reload cannon - 146 of them.
  reloadGuns();
}

reloadAJAir2Personel = func {
  # Reload missiles - 4 of them.
  setprop("payload/weight[0]/selected", "M55 AKAN");
  setprop("ai/submodels/submodel[10]/count", 150);
  setprop("payload/weight[1]/selected", "M71 Bomblavett");
  setprop("payload/weight[1]/ammo", 4);
  setprop("payload/weight[2]/selected", "M55 AKAN");
  setprop("ai/submodels/submodel[12]/count", 150);
  setprop("payload/weight[3]/selected", "M71 Bomblavett");
  setprop("payload/weight[3]/ammo", 4);
  setprop("payload/weight[4]/selected", "none");
  setprop("payload/weight[5]/selected", "none");
  screen.log.write("2 M55 cannonpod attached", 0.0, 1.0, 0.0);
  screen.log.write("2 M71 bomblet rail attached", 0.0, 1.0, 0.0);

  # Reload flares - 40 of them.
  setprop("ai/submodels/submodel[0]/count", 60);
  setprop("ai/submodels/submodel[1]/count", 60);
  screen.log.write("60 flares loaded", 0.0, 1.0, 0.0);

  # Reload cannon - 146 of them.
  reloadGuns();
}

reloadAJAir2Air = func {
  # Reload missiles - 4 of them.
  setprop("payload/weight[0]/selected", "M55 AKAN");
  setprop("ai/submodels/submodel[10]/count", 150);
  setprop("payload/weight[1]/selected", "RB 24J Sidewinder");
  setprop("payload/weight[2]/selected", "M55 AKAN");
  setprop("ai/submodels/submodel[12]/count", 150);
  setprop("payload/weight[3]/selected", "RB 24J Sidewinder");
  setprop("payload/weight[4]/selected", "none");
  setprop("payload/weight[5]/selected", "none");
  screen.log.write("2 M55 cannonpod attached", 0.0, 1.0, 0.0);
  screen.log.write("2 RB-24J Sidewinder attached", 0.0, 1.0, 0.0);

  # Reload flares - 40 of them.
  setprop("ai/submodels/submodel[0]/count", 60);
  setprop("ai/submodels/submodel[1]/count", 60);
  screen.log.write("60 flares loaded", 0.0, 1.0, 0.0);

  # Reload cannon - 146 of them.
  reloadGuns();
}

reloadAJSAir2Tank = func {
  # Reload missiles - 4 of them.
  setprop("payload/weight[0]/selected", "RB 75 Maverick");
  setprop("payload/weight[1]/selected", "M70 ARAK");
  setprop("payload/weight[2]/selected", "RB 75 Maverick");
  setprop("payload/weight[3]/selected", "M70 ARAK");
  setprop("payload/weight[4]/selected", "RB 24J Sidewinder");
  setprop("payload/weight[5]/selected", "RB 24J Sidewinder");
  setprop("ai/submodels/submodel[6]/count", 6);
  setprop("ai/submodels/submodel[8]/count", 6);
  screen.log.write("2 Bofors M70 rocket pods attached", 0.0, 1.0, 0.0);
  screen.log.write("2 RB-75 Maverick attached", 0.0, 1.0, 0.0);
  screen.log.write("2 RB-24J Sidewinder attached", 0.0, 1.0, 0.0);

  # Reload flares - 40 of them.
  setprop("ai/submodels/submodel[0]/count", 60);
  setprop("ai/submodels/submodel[1]/count", 60);
  screen.log.write("60 flares loaded", 0.0, 1.0, 0.0);

  # Reload cannon - 146 of them.
  reloadGuns();
}

reloadAJSAir2Ship = func {
  # Reload missiles - 4 of them.
  setprop("payload/weight[0]/selected", "RB 15F Attackrobot");
  setprop("payload/weight[1]/selected", "RB 05A Attackrobot");
  setprop("payload/weight[2]/selected", "RB 15F Attackrobot");
  setprop("payload/weight[3]/selected", "RB 75 Maverick");
  setprop("payload/weight[4]/selected", "RB 24J Sidewinder");
  setprop("payload/weight[5]/selected", "RB 24J Sidewinder");
  screen.log.write("1 RB-05A missile attached", 0.0, 1.0, 0.0);
  screen.log.write("1 RB-75 Maverick attached", 0.0, 1.0, 0.0);
  screen.log.write("2 RB-15F cruise-missiles attached", 0.0, 1.0, 0.0);
  screen.log.write("2 RB-24J Sidewinder attached", 0.0, 1.0, 0.0);

  # Reload flares - 40 of them.
  setprop("ai/submodels/submodel[0]/count", 60);
  setprop("ai/submodels/submodel[1]/count", 60);
  screen.log.write("60 flares loaded", 0.0, 1.0, 0.0);

  # Reload cannon - 146 of them.
  reloadGuns();
}

reloadAJSAir2Personel = func {
  # Reload missiles - 4 of them.
  setprop("payload/weight[0]/selected", "M55 AKAN");
  setprop("ai/submodels/submodel[10]/count", 150);
  setprop("payload/weight[1]/selected", "M71 Bomblavett");
  setprop("payload/weight[1]/ammo", 4);
  setprop("payload/weight[2]/selected", "M90 Bombkapsel");
  setprop("payload/weight[3]/selected", "M71 Bomblavett");
  setprop("payload/weight[3]/ammo", 4);
  setprop("payload/weight[4]/selected", "RB 24J Sidewinder");
  setprop("payload/weight[5]/selected", "RB 24J Sidewinder");
  screen.log.write("1 M55 cannonpod attached", 0.0, 1.0, 0.0);
  screen.log.write("2 M71 bomblet rail attached", 0.0, 1.0, 0.0);
  screen.log.write("1 M90 cluster bomb attached", 0.0, 1.0, 0.0);
  screen.log.write("2 RB-24J Sidewinder attached", 0.0, 1.0, 0.0);

  # Reload flares - 40 of them.
  setprop("ai/submodels/submodel[0]/count", 60);
  setprop("ai/submodels/submodel[1]/count", 60);
  screen.log.write("60 flares loaded", 0.0, 1.0, 0.0);

  # Reload cannon - 146 of them.
  reloadGuns();
}

reloadAJSAir2Air = func {
  # Reload missiles - 4 of them.
  setprop("payload/weight[0]/selected", "M55 AKAN");
  setprop("ai/submodels/submodel[10]/count", 150);
  setprop("payload/weight[1]/selected", "RB 74 Sidewinder");
  setprop("payload/weight[2]/selected", "M55 AKAN");
  setprop("ai/submodels/submodel[12]/count", 150);
  setprop("payload/weight[3]/selected", "RB 74 Sidewinder");
  setprop("payload/weight[4]/selected", "RB 24J Sidewinder");
  setprop("payload/weight[5]/selected", "RB 24J Sidewinder");
  screen.log.write("2 M55 cannonpod attached", 0.0, 1.0, 0.0);
  screen.log.write("2 RB-24J Sidewinder attached", 0.0, 1.0, 0.0);
  screen.log.write("2 RB-74 Sidewinder attached", 0.0, 1.0, 0.0);

  # Reload flares - 40 of them.
  setprop("ai/submodels/submodel[0]/count", 60);
  setprop("ai/submodels/submodel[1]/count", 60);
  screen.log.write("60 flares loaded", 0.0, 1.0, 0.0);

  # Reload cannon - 146 of them.
  reloadGuns();
}

reloadGuns = func {
  # Reload cannon - 146 of them.
  #setprop("ai/submodels/submodel[2]/count", 29);
  if(getprop("ja37/systems/variant") == 0) {
    setprop("ai/submodels/submodel[3]/count", 146);
    setprop("ai/submodels/submodel[4]/count", 146);
    screen.log.write("146 cannon rounds loaded", 0.0, 1.0, 0.0);
  }

  ja37.ct("rl");
}

############ droptank #####################

var drop = func {
    if (getprop("/consumables/fuel/tank[8]/jettisoned") == TRUE) {
       ja37.popupTip("Drop tank already jettisoned.");
       return;
    }  
    if (input.wow0.getValue() > 0.05) {
       ja37.popupTip("Can not eject drop tank while on ground!"); 
       return;
    }
    if (getprop("systems/electrical/outputs/dc-voltage") < 23) {
       ja37.popupTip("Too little DC power to eject drop tank!");
       return;
    }
    ja37.click();
    setprop("payload/weight[6]/selected", "none");# empty the pylon
    ja37.popupTip("Drop tank shut off and ejected. Using internal fuel.");
 }

############ main function #####################

var main_weapons = func {
  # gets called from ja37.nas

  # setup property nodes for the loop
  foreach(var name; keys(input)) {
      input[name] = props.globals.getNode(input[name], 1);
  }

  # setup trigger listener
  setlistener("controls/armament/trigger", trigger_listener, 0, 0);

  # setup impact listener
  setlistener("/ai/models/model-impact", impact_listener, 0, 0);

  # setup incoming listener
  setlistener("/sim/multiplay/chat-history", incoming_listener, 0, 0);

  # start the main loop
  settimer(func { loop_stores() }, 0.1);
}

var selectNextWaypoint = func () {
  var active_wp = getprop("autopilot/route-manager/current-wp");

  if (active_wp == nil or active_wp < 0) {
    screen.log.write("Active route-manager waypoint invalid, unable to create target.", 1.0, 0.0, 0.0);
    return;
  }

  var active_node = globals.props.getNode("autopilot/route-manager/route/wp["~active_wp~"]");

  if (active_node == nil) {
    screen.log.write("Active route-manager waypoint invalid, unable to create target.", 1.0, 0.0, 0.0);
    return;
  }

  var lat = active_node.getNode("latitude-deg");
  var lon = active_node.getNode("longitude-deg");
  var alt = active_node.getNode("altitude-m").getValue();

  if (alt < -9000) {
    var ground = geo.elevation(lat.getValue(), lon.getValue());
    if(ground != nil) {
      alt = ground;
    } else {
      screen.log.write("Active route-manager waypoint has no altitude, unable to create target.", 1.0, 0.0, 0.0);
      return;
    }
  }

  var name = active_node.getNode("id");

  var coord = geo.Coord.new();
  coord.set_latlon(lat.getValue(), lon.getValue(), alt);

  var contact = radar_logic.ContactGPS.new(name.getValue(), coord);

  radar_logic.selection = contact;
}

setprop("/sim/failure-manager/display-on-screen", FALSE);