var STORES_UPDATE_PERIOD = 0.05;

var FALSE = 0;
var TRUE = 1;

var MISSILE_STANDBY = -1;
var MISSILE_SEARCH = 0;
var MISSILE_LOCK = 1;
var MISSILE_FLYING = 2;

var flareCount = -1;
var flareStart = -1;

var fireLog = events.LogBuffer.new(echo: 0);#compatible with older FG?
var ecmLog = events.LogBuffer.new(echo: 0);#compatible with older FG?

var jettisonAll = FALSE;

input = {
  asymLoad:         "fdm/jsbsim/inertia/asymmetric-wing-load",
  combat:           "/ja37/hud/current-mode",
  elapsed:          "sim/time/elapsed-sec",
  elecMain:         "controls/electric/main",
  engineRunning:    "engines/engine/running",
  gearCmdNorm:      "/fdm/jsbsim/gear/gear-cmd-norm",
  gearsPos:         "gear/gear/position-norm",
  hz05:             "ja37/blink/five-Hz/state",
  hz10:             "ja37/blink/four-Hz/state",
  hzThird:          "ja37/blink/third-Hz/state",
  impact:           "/ai/models/model-impact",
  mass1:            "fdm/jsbsim/inertia/pointmass-weight-lbs[1]",
  mass3:            "fdm/jsbsim/inertia/pointmass-weight-lbs[3]",
  mass5:            "fdm/jsbsim/inertia/pointmass-weight-lbs[5]",
  mass6:            "fdm/jsbsim/inertia/pointmass-weight-lbs[6]",
  MPfloat2:         "sim/multiplay/generic/float[2]",
  MPfloat9:         "sim/multiplay/generic/float[9]",
  MPint19:          "sim/multiplay/generic/int[19]",
  rb05_pitch:       "payload/armament/rb05-control-pitch",
  rb05_yaw:         "payload/armament/rb05-control-yaw",
  replay:           "sim/replay/replay-state",
  serviceElec:      "systems/electrical/serviceable",
  stationSelect:    "controls/armament/station-select-custom",
  subAmmo2:         "ai/submodels/submodel[2]/count", 
  subAmmo3:         "ai/submodels/submodel[3]/count", 
  subAmmo9:         "ai/submodels/submodel[9]/count", 
  subAmmo10:         "ai/submodels/submodel[10]/count", 
  subAmmo11:         "ai/submodels/submodel[11]/count", 
  subAmmo12:         "ai/submodels/submodel[12]/count",
  tank8Jettison:    "/consumables/fuel/tank[8]/jettisoned",
  tank8LvlNorm:     "/consumables/fuel/tank[8]/level-norm",
  tank8Selected:    "/consumables/fuel/tank[8]/selected",
  trigger:          "controls/armament/trigger",
  wow0:             "fdm/jsbsim/gear/unit[0]/WOW",
  wow1:             "fdm/jsbsim/gear/unit[1]/WOW",
  wow2:             "fdm/jsbsim/gear/unit[2]/WOW",
  dev:              "dev",
};


### Rb05 guidance
# Rb05 guidance signals are transmitted to missile.nas through a callback,
# (called midFlightFunction in missile.nas).

var make_rb05_midFlightFunction = func(pos) {
    var params = {
        active: active_rb05,
        pos: pos,
        input_yaw: input.rb05_yaw,
        input_pitch: input.rb05_pitch,
    };

    return func(input) {
        # Missile can be controlled ~1.7s after launch (manual)
        var active = (params.active[params.pos]
                      and input.time_s >= 1.7);

        var res = {};
        if(active) {
            res.remote_yaw = params.input_yaw.getValue();
            res.remote_pitch = params.input_pitch.getValue();
        } else {
            res.remote_yaw = 0;
            res.remote_pitch = 0;
        }
        return res;
    };
}

# Maps pylons to guidance status (boolean: actively controlled or not)
var active_rb05 = {};
# Last fired Rb05, should be the only active one.
var last_rb05 = nil;


############ main stores loop #####################

var loop_stores = func {

    if(input.replay.getValue() == TRUE) {
      # replay is active, skip rest of loop.
      #settimer(loop_stores, STORES_UPDATE_PERIOD);
      return;
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
          # Mid flight function to transmit guidance inputs to missile.nas
          var mf = make_rb05_midFlightFunction(i);
          if(armament.AIM.new(i, "RB-05A", "Attackrobot", mf) == -1 and armament.AIM.active[i].status == MISSILE_FLYING) {
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
            setprop("ai/submodels/submodel["~(5+i)~"]/count", 6);
            if(armament.AIM.active[i] != nil and armament.AIM.active[i].status != MISSILE_FLYING) {
              # remove aim logic from that pylon
              armament.AIM.active[i].del();
              #print("removing aim logic");
            }
        } elsif (payloadName.getValue() == "M55 AKAN") {
            var model = i==0?10:12;
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
    if (armSelect == 0 or armSelect == -1) {
      setprop("ja37/avionics/vid", FALSE);
    }
    for(i = 0; i <= 6; i += 1) {
      var payloadName = props.globals.getNode("payload/weight["~ i ~"]/selected");
      if(armament.AIM.active[i] != nil) {
        # missile is mounted on pylon
        if(jettisonAll == TRUE) {
          armament.AIM.active[i].eject();
          if (payloadName.getValue() != "M71 Bomblavett" and payloadName.getValue() != "M71 Bomblavett (Retarded)") {
            payloadName.setValue("none");# empty the pylon
            setprop("controls/armament/station["~(1+i)~"]/released", TRUE);# setting the pylon as fired
          }
          if (payloadName.getValue() == "M71 Bomblavett" or payloadName.getValue() == "M71 Bomblavett (Retarded)") {
            var ammo = getprop("payload/weight["~i~"]/ammo");
            ammo = ammo - 1;
            setprop("payload/weight["~i~"]/ammo", ammo);
            if (ammo == 0) {
              setprop("payload/weight["~ i ~"]/selected", "none");# empty the pylon
            }
          }
        } elsif(armSelect != (i+1) and armament.AIM.active[i].status != MISSILE_FLYING) {
          #pylon not selected, and not flying set missile on standby
          armament.AIM.active[i].stop();
          #print("not sel "~i);
        } elsif (!power.prop.acMainBool.getValue() or input.combat.getValue() != 2
                  or (armament.AIM.active[i].status != MISSILE_STANDBY
                      and armament.AIM.active[i].status != MISSILE_FLYING
                      and payloadName.getValue() == "none")) {
          #pylon has logic but missile not mounted and not flying or not in tactical mode or has no power
          armament.AIM.active[i].stop();
          #print("empty "~i);
        } elsif (armSelect == (i+1) and armament.AIM.active[i].status == MISSILE_STANDBY and input.combat.getValue() == 2) {
          #pylon selected, missile mounted, in tactical mode, activate search
          armament.AIM.active[i].start();
          #print("active "~i);
          # For AJ(S), set IR seekers to bore sight mode
          if (getprop("ja37/systems/variant") != 0 and armament.AIM.active[i].guidance == "heat") {
            armament.AIM.active[i].setAutoUncage(0);
            armament.AIM.active[i].setCaged(1);
            armament.AIM.active[i].setBore(1);
          }
        }
      } elsif (jettisonAll == TRUE and (payloadName.getValue() == "M70 ARAK" or payloadName.getValue() == "M55 AKAN" or payloadName.getValue() == "Drop tank")) {
        payloadName.setValue("none");
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

    # outer stores
    var leftRb2474 = getprop("fdm/jsbsim/inertia/pointmass-weight-lbs[5]") == 188 or getprop("fdm/jsbsim/inertia/pointmass-weight-lbs[5]") == 179;
    var rightRb2474 = getprop("fdm/jsbsim/inertia/pointmass-weight-lbs[6]") == 188 or getprop("fdm/jsbsim/inertia/pointmass-weight-lbs[6]") == 179;
    var wtv = getprop("fdm/jsbsim/effects/wingtip-vapour");
    input.MPint19.setIntValue(ja37.encode3bits(leftRb2474, rightRb2474, wtv));

  # Flare/chaff release
  var flareCmd = getprop("ai/submodels/submodel[0]/flare-release-cmd");
  if (flareCmd and !getprop("ai/submodels/submodel[0]/flare-release")
               and !getprop("ai/submodels/submodel[0]/flare-release-out-snd")
               and !getprop("ai/submodels/submodel[0]/flare-release-snd")) {
    flareCount = getprop("ai/submodels/submodel[0]/count");
    flareStart = input.elapsed.getValue();
    if (flareCount > 0) {
      # release a flare
      setprop("ai/submodels/submodel[0]/flare-release-snd", TRUE);
      setprop("ai/submodels/submodel[0]/flare-release", TRUE);
      setprop("rotors/main/blade[3]/flap-deg", flareStart);
      setprop("rotors/main/blade[3]/position-deg", flareStart);
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

  # conditionals for dropping M70/droptank
  if (getprop("fdm/jsbsim/structural/wings/serviceable") == TRUE
      and getprop("sim/multiplay/generic/float[11]") == 794) {
    #left wing rocket pod mounted, wings not broken
    setprop("ja37/effect/pod0", FALSE);
    setprop("ai/submodels/submodel[14]/count", 1);
  } else {
    setprop("ja37/effect/pod0", TRUE);
  }
  if (getprop("sim/multiplay/generic/float[12]") == 794) {
    #left fuselage rocket pod mounted
    setprop("ja37/effect/pod1", FALSE);
    setprop("ai/submodels/submodel[15]/count", 1);
  } else {
    setprop("ja37/effect/pod1", TRUE);
  }
  if (getprop("fdm/jsbsim/structural/wings/serviceable") == TRUE
      and getprop("sim/multiplay/generic/float[13]") == 794) {
    #right wing rocket pod mounted, wings not broken
    setprop("ja37/effect/pod2", FALSE);
    setprop("ai/submodels/submodel[16]/count", 1);
  } else {
    setprop("ja37/effect/pod2", TRUE);
  }
  if (getprop("sim/multiplay/generic/float[14]") == 794) {
    #right fuselage rocket pod mounted
    setprop("ja37/effect/pod3", FALSE);
    setprop("ai/submodels/submodel[17]/count", 1);
  } else {
    setprop("ja37/effect/pod3", TRUE);
  }

  #settimer(func { loop_stores() }, STORES_UPDATE_PERIOD);
}


###########  listener for handling the trigger #########

# Indices in /payload/weight[i] with potential M70 pod.
# Add 1 to obtain the corresponding index in /controls/armament/station[i].
var m70_stations = [0, 1, 2, 3];

# Maps indices in /payload/weight[i] with potential M55 pod,
# to the corresponding indices in /controls/armament/station[i].
var m55_stations = {0: 8, 2: 9};

var trigger_listener = func {
  # Currently only the JA uses the trigger to click.
  # This allows the trigger to remain functional on the AJS
  # while controlling Rb05 with flight controls.
  if(!getprop("/ja37/systems/input-controls-flight")
     and getprop("/ja37/systems/variant") == 0) return;
  var trigger = input.trigger.getValue();
  var armSelect = input.stationSelect.getValue();

  var fired = "KCA";
  if (armSelect > 0) {
    fired = getprop("payload/weight["~ (armSelect-1) ~"]/selected");
  }

  #if masterarm is on and HUD in tactical mode, propagate trigger to station
  if(armSelect != -1 and input.combat.getValue() == 2 and power.prop.dcMainBool.getValue() and !(armSelect == 0 and !power.prop.acMainBool.getValue())) {
    setprop("/controls/armament/station["~armSelect~"]/trigger", trigger);

    # M70 and M55 use specific trigger properties.
    if (armSelect != 0 and fired== "M70 ARAK") {
      foreach(var station; m70_stations) {
        if(getprop("payload/weight["~station~"]/selected") == "M70 ARAK") {
          setprop("/controls/armament/station["~(station+1)~"]/trigger-m70", trigger);
        }
      }
    }
    if (armSelect != 0 and fired == "M55 AKAN") {
      foreach(var station; keys(m55_stations)) {
        if(getprop("payload/weight["~station~"]/selected") == "M55 AKAN") {
          setprop("/controls/armament/station["~(m55_stations[station])~"]/trigger", trigger);
        }
      }
    }
  } else {
    if (armSelect != -1) {
      setprop("/controls/armament/station["~armSelect~"]/trigger", FALSE);
    }
    foreach(var station; m70_stations) {
      setprop("/controls/armament/station["~(station+1)~"]/trigger-m70", FALSE);
    }
    foreach(var station; keys(m55_stations)) {
      setprop("/controls/armament/station["~(m55_stations[station])~"]/trigger", FALSE);
    }
  }

  if(armSelect > 0 and getprop("/controls/armament/station["~armSelect~"]/trigger") == TRUE) {
    if(getprop("payload/weight["~(armSelect-1)~"]/selected") != "none"
       and (input.gearsPos.getValue() == 0 or input.dev.getValue())) {
      # Trigger is pulled, a pylon is selected, and loaded.
      # The gear check is prevent missiles from firing when changing airport location.
      if (fired == "M71 Bomblavett" or fired == "M71 Bomblavett (Retarded)") {
        var brevity = armament.AIM.active[armSelect-1].brevity;

        armament.AIM.active[armSelect-1].release(radar_logic.complete_list);#print("release "~(armSelect-1));

        var phrase = brevity;
        if (getprop("payload/armament/msg")) {
          armament.defeatSpamFilter(phrase);
        } else {
          setprop("/sim/messages/atc", phrase);
        }
        fireLog.push("Self: "~phrase);
        var next = TRUE;

        var ammo = getprop("payload/weight["~(armSelect-1)~"]/ammo");
        ammo = ammo - 1;
        setprop("payload/weight["~(armSelect-1)~"]/ammo", ammo);
        if(ammo > 0) {
          #next = FALSE;
        }

        if(next == TRUE) {
          var newStation = selectTypeBombs(fired, armSelect);
          if (newStation != -1) {
            input.stationSelect.setValue(newStation);
          }
        }
      } elsif (fired == "RB 05A Attackrobot") {
        # Release control from previous missile
        if(last_rb05 != nil) active_rb05[last_rb05] = FALSE;
        # Take control of the new one
        last_rb05 = armSelect-1;
        active_rb05[last_rb05] = TRUE;

        var brevity = armament.AIM.active[armSelect-1].brevity;

        armament.AIM.active[armSelect-1].release(radar_logic.complete_list);

        setprop("payload/weight["~ (armSelect-1) ~"]/selected", "none");# empty the pylon
        setprop("controls/armament/station["~armSelect~"]/released", TRUE);# setting the pylon as fired

        var phrase = brevity;
        if (getprop("payload/armament/msg")) {
          armament.defeatSpamFilter(phrase);
        } else {
          setprop("/sim/messages/atc", phrase);
        }

        fireLog.push("Self: "~phrase);
        var newStation = selectType(fired);
        if (newStation != -1) {
          input.stationSelect.setValue(newStation);
        }
      } elsif (armament.AIM.active[armSelect-1] != nil and armament.AIM.active[armSelect-1].status == MISSILE_LOCK) {
        #missile locked, fire it.
        setprop("payload/weight["~ (armSelect-1) ~"]/selected", "none");# empty the pylon
        setprop("controls/armament/station["~armSelect~"]/released", TRUE);# setting the pylon as fired

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
        fireLog.push("Self: "~phrase);
        var newStation = selectType(fired);
        if (newStation != -1) {
          input.stationSelect.setValue(newStation);
        }
      }
    }
  }
  if (fired == "M70 ARAK") {
    var submodel = armSelect + 4;
    var ammo = getprop("ai/submodels/submodel["~submodel~"]/count");
    if (ammo == 0) {
      var newStation = selectType(fired);
      if (newStation != -1 and hasRockets(newStation) > 0) {
        input.stationSelect.setValue(newStation);
      }
    }
  }
  if (fired == "M55 AKAN") {
    var submodel = armSelect==1?10:12;
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

var hits_count = 0;
var hit_timer = nil;
var hit_callsign = "";

var Mp = props.globals.getNode("ai/models");
var valid_mp_types = {
  multiplayer: 1, tanker: 1, aircraft: 1, ship: 1, groundvehicle: 1,
};

# Find a MP aircraft close to a given point (code from the Mirage 2000)
var findmultiplayer = func(targetCoord, dist) {
  if(targetCoord == nil) return nil;

  var raw_list = Mp.getChildren();
  var SelectedMP = nil;
  foreach(var c ; raw_list)
  {    
    var is_valid = c.getNode("valid");
    if(is_valid == nil or !is_valid.getBoolValue()) continue;
    
    var type = c.getName();
    
    var position = c.getNode("position");
    var name = c.getValue("callsign");
    if(name == nil or name == "") {
      # fallback, for some AI objects
      var name = c.getValue("name");
    }
    if(position == nil or name == nil or name == "" or !contains(valid_mp_types, type)) continue;

    var lat = position.getValue("latitude-deg");
    var lon = position.getValue("longitude-deg");
    var elev = position.getValue("altitude-ft") * FT2M;

    if(lat == nil or lon == nil or elev == nil) continue;

    MpCoord = geo.Coord.new().set_latlon(lat, lon, elev);
    var tempoDist = MpCoord.direct_distance_to(targetCoord);
    if(dist > tempoDist) {
      dist = tempoDist;
      SelectedMP = name;
    }
  }
  return SelectedMP;
}

var impact_listener = func {
  var ballistic_name = input.impact.getValue();
  var ballistic = props.globals.getNode(ballistic_name, 0);
  if (ballistic != nil and ballistic.getName() != "munition") {
    var typeNode = ballistic.getNode("impact/type");
    if (typeNode != nil and typeNode.getValue() != "terrain") {
      var lat = ballistic.getNode("impact/latitude-deg").getValue();
      var lon = ballistic.getNode("impact/longitude-deg").getValue();
      var elev = ballistic.getNode("impact/elevation-m").getValue();
      var impactPos = geo.Coord.new().set_latlon(lat, lon, elev);
      var target = findmultiplayer(impactPos, 80);

      if (target != nil) {
        var typeOrd = ballistic.getNode("name").getValue();

        if(target == hit_callsign) {
          # Previous impacts on same target
          hits_count += 1;
        } else {
          if(hit_timer != nil) {
            # Previous impacts on different target, flush them first
            hit_timer.stop();
            hitmessage(typeOrd);
          }
          hits_count = 1;
          hit_callsign = target;
          hit_timer = maketimer(1, func{hitmessage(typeOrd);});
          hit_timer.singleShot = 1;
          hit_timer.start();
        }
      }
    }
  }
}

var hitmessage = func(typeOrd) {
  #print("inside hitmessage");
  var phrase = typeOrd ~ " hit: " ~ hit_callsign ~ ": " ~ hits_count ~ " hits";
  if (getprop("payload/armament/msg") == TRUE) {
    defeatSpamFilter(phrase);
  } else {
    setprop("/sim/messages/atc", phrase);
  }
  hit_callsign = "";
  hit_timer = nil;
  hits_count = 0;
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
    var submodel = station==1?10:12;
    var ammo = getprop("ai/submodels/submodel["~submodel~"]/count");
    loaded = ammo;
  }
  return loaded;
}

var hasRockets = func (station) {
  var loaded = -1;
  if (getprop("payload/weight["~(station-1)~"]/selected") == "M70 ARAK") {
    var submodel = station + 4;
    var ammo = getprop("ai/submodels/submodel["~submodel~"]/count");
    loaded = ammo;
  }
  return loaded;
}

var count99 = func () {
  for (var i = 0;i<6;i+=1) {
    var type = getprop("payload/weight["~i~"]/selected");
    if (type == "RB 99 Amraam") {
      return ammoCount(i+1);
    }
  }
  return 0;
}

var ammoCount = func (station) {
  var ammo = -1;
  if (station == -1) {
    ammo == -1;
  } elsif (station == 0) {
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
    setprop("controls/armament/station-select-custom", 0);
    ja37.click();
  }
}

var cycle_weapons = func {
  # station -1= none selected
  # station 0 = cannon
  # station 1 = inner left wing
  # station 2 = left fuselage
  # station 3 = inner right wing
  # station 4 = right fuselage
  # station 5 = outer left wing
  # station 6 = outer right wing
  # station 7 = center pylon

  var sel = getprop("controls/armament/station-select-custom");
  var type = sel==-1?"none":(sel==0?"KCA":getprop("payload/weight["~(sel-1)~"]/selected"));
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
  setprop("controls/armament/station-select-custom", sel);
}

var buttonIRRB = func {
  # station 0 = cannon
  # station 1 = inner left wing
  # station 2 = left fuselage
  # station 3 = inner right wing
  # station 4 = right fuselage
  # station 5 = outer left wing
  # station 6 = outer right wing
  # station 7 = center pylon

  var sel = getprop("controls/armament/station-select-custom");
  var type = sel==-1?"none":(sel==0?"KCA":getprop("payload/weight["~(sel-1)~"]/selected"));
  var newType = "none";

  var loopRan = FALSE;

  while(newType == "none") {
    if (type == "none" or (type != "RB 74 Sidewinder" and type != "RB 24J Sidewinder" and type != "RB 24 Sidewinder")) {
        sel = selectType("RB 74 Sidewinder");
        if (sel != -1) {
          newType = "RB 74 Sidewinder";
        } else {
          type = "RB 74 Sidewinder";
        }
    } elsif (type == "RB 74 Sidewinder") {
      sel = selectType("RB 24 Sidewinder");
      if (sel != -1) {
        newType = "RB 24 Sidewinder";
      } else {
        type = "RB 24 Sidewinder";
      }
    } elsif (type == "RB 24 Sidewinder") {
      sel = selectType("RB 24J Sidewinder");
      if (sel != -1) {
        newType = "RB 24J Sidewinder";
      } else {
        type = "RB 24J Sidewinder";
      }
    } elsif (type == "RB 24J Sidewinder") {
      sel = selectType("RB 74 Sidewinder");
      if (sel != -1) {
        newType = "RB 74 Sidewinder";
      } else {
        type = "RB 74 Sidewinder";
        if (loopRan == FALSE) {
          loopRan = TRUE;
        } else {
          # we have been here once before, so to prevent infinite loop, we just select nothing
          sel = -1;
          type = "none";
          newType = "empty";
        }
      }
    }
  }
  setprop("controls/armament/station-select-custom", sel);
}



# Caging of the IR seeker for AJ(S)
var setIRCaged = func (cage) {
    # Check master arm on, IR seeker selected
    if (input.combat.getValue() != 2) return;
    var armSelect = input.stationSelect.getValue();
    if (armSelect <= 0) return;
    var arm = armament.AIM.active[armSelect-1];
    if (arm == nil) return;
    # Only Rb24j and Rb74 can uncage the seeker
    if (arm.type != "RB-24J" and arm.type != "RB-74") return;


    if (cage) {
        arm.setAutoUncage(FALSE);
        arm.setCaged(TRUE);
        arm.setBore(TRUE);
    } elsif (arm.status == armament.MISSILE_LOCK) {
        # Uncaging is only possible with lock
        arm.setAutoUncage(TRUE);
        arm.setCaged(FALSE);
        arm.setBore(FALSE); # The seeker should not come back to bore until reset.
    }
}

# Pressing the button uncages, holding it re-cages
var uncageIRButtonTimer = maketimer(1, func { setIRCaged(TRUE); });
uncageIRButtonTimer.singleShot = TRUE;
uncageIRButtonTimer.simulatedTime = TRUE;

var uncageIRButton = func (pushed) {
    if (pushed) {
        setIRCaged(FALSE);
        uncageIRButtonTimer.start();
    } else {
        uncageIRButtonTimer.stop();
    }
}


############ droptank #####################

var drop = func {
    if (getprop("/consumables/fuel/tank[8]/jettisoned") == TRUE) {
       screen.log.write("Drop tank already jettisoned.", 0.0, 1.0, 0.0);
       return;
    }  
    if (input.wow0.getValue() > 0.05) {
       screen.log.write("Can not eject drop tank while on ground!", 0.0, 1.0, 0.0);
       return;
    }
    if (!power.prop.dcMainBool.getValue()) {
       screen.log.write("Too little DC power to eject drop tank!", 0.0, 1.0, 0.0);
       return;
    }
    ja37.click();
    setprop("payload/weight[6]/selected", "none");# empty the pylon
    screen.log.write("Drop tank shut off and ejected. Using internal fuel.", 0.0, 1.0, 0.0);
 }

 var dropAll = func {
    if (input.wow0.getValue() > 0.05) {
       screen.log.write("Can not jettison stores while on ground!", 0.0, 1.0, 0.0);
       return;
    }
    if (!power.prop.dcMainBool.getValue()) {
       screen.log.write("Too little DC power to jettison!", 0.0, 1.0, 0.0);
       return;
    }
    ja37.click();
    screen.log.write("All stores jettisoning.", 0.0, 1.0, 0.0);
    jettisonAll = TRUE;
    settimer(func {jettisonAll = FALSE;},5);
#    setprop("payload/weight[0]/selected", "none");
#    setprop("payload/weight[1]/selected", "none");
#    setprop("payload/weight[2]/selected", "none");
#    setprop("payload/weight[3]/selected", "none");
#    setprop("payload/weight[4]/selected", "none");
#    setprop("payload/weight[5]/selected", "none");
#    setprop("payload/weight[6]/selected", "none");# empty the pylon
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

  # start the main loop
  #settimer(func { loop_stores() }, 0.1);
}

var selectNextWaypoint = func () {
  if (getprop("ja37/avionics/cursor-on") != FALSE) {
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
    coord.set_latlon(lat.getValue(), lon.getValue(), alt+1);#plus 1 to raise it a little above ground if its on ground, so LOS can still have view of it.

    var contact = radar_logic.ContactGPS.new(name.getValue(), coord);

    radar_logic.setSelection(contact);
  }
}

setprop("/sim/failure-manager/display-on-screen", FALSE);
