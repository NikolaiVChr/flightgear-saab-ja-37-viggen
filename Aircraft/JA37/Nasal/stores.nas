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
  combat:           "/sim/ja37/hud/current-mode",
  dcVolt:           "systems/electrical/outputs/dc-voltage",
  elapsed:          "sim/time/elapsed-sec",
  elecMain:         "controls/electric/main",
  engineRunning:    "engines/engine/running",
  gearCmdNorm:      "/fdm/jsbsim/gear/gear-cmd-norm",
  gearsPos:         "gear/gear/position-norm",
  hz05:             "sim/ja37/blink/five-Hz/state",
  hz10:             "sim/ja37/blink/ten-Hz/state",
  hzThird:          "sim/ja37/blink/third-Hz/state",
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

    # pylon payloads
    for(var i=0; i<=6; i=i+1) {
      var payloadName = props.globals.getNode("payload/weight["~ i ~"]/selected");
      var payloadWeight = props.globals.getNode("payload/weight["~ i ~"]/weight-lb");
      
      if(payloadName.getValue() != "none" and (
          (payloadName.getValue() == "M70" and payloadWeight.getValue() != 200)
          or (payloadName.getValue() == "RB 24J" and payloadWeight.getValue() != 179)
          or (payloadName.getValue() == "RB 74" and payloadWeight.getValue() != 188)
          or (payloadName.getValue() == "RB 71" and payloadWeight.getValue() != 425)
          or (payloadName.getValue() == "RB 99" and payloadWeight.getValue() != 291)
          or (payloadName.getValue() == "RB 15F" and payloadWeight.getValue() != 1763.7)
          or (payloadName.getValue() == "TEST" and payloadWeight.getValue() != 50)
          or (payloadName.getValue() == "Drop tank" and payloadWeight.getValue() != 224.87))) {
        # armament or drop tank was loaded manually through payload/fuel dialog, so setting the pylon to not released
        setprop("controls/armament/station["~(i+1)~"]/released", FALSE);
        #print("adding "~i);
        if(i != 6) {
          if (payloadName.getValue() == "RB 24J") {
            # is not center pylon and is RB24
            #print("rb24 "~i);
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
              #print("refusing to mount new RB-24 missile yet "~i);
            }
          } elsif (payloadName.getValue() == "RB 74") {
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
          } elsif (getprop("payload/weight["~ (i) ~"]/selected") == "M70") {
              setprop("ai/submodels/submodel["~(5+i)~"]/count", 6);
              if(armament.AIM.active[i] != nil and armament.AIM.active[i].status != MISSILE_FLYING) {
                # remove aim logic from that pylon
                armament.AIM.active[i].del();
                #print("removing aim logic");
              }
          } elsif (payloadName.getValue() == "RB 71") {
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
          } elsif (payloadName.getValue() == "RB 99") {
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
          } elsif (payloadName.getValue() == "RB 15F") {
            # is not center pylon and is RB99
            #print("rb71 "~i);
            if(armament.AIM.active[i] != nil and armament.AIM.active[i].type != "RB 15F") {
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
      }
      if(i != 6 and payloadName.getValue() == "none") {# and payloadWeight.getValue() != 0) {
        if(armament.AIM.active[i] != nil) {
          # pylon emptied through menu, so remove the logic
          #print("removing aim logic");
          armament.AIM.active[i].del();
        }
      }
    }

    #activate searcher on selected pylon if missile mounted
    var armSelect = input.stationSelect.getValue();
    for(i = 0; i <= 5; i += 1) {
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
    }

    var selected = nil;
    for(var i=0; i<=6; i=i+1) { # set JSBSim mass
      selected = getprop("payload/weight["~i~"]/selected");
      if(selected == "none") {
        # the pylon is empty, set its pointmass to zero
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 0) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 0);
        }
        if(i==6) {
          # no drop tank attached
          input.tank8Selected.setValue(FALSE);
          input.tank8Jettison.setValue(TRUE);
          input.tank8LvlNorm.setValue(0);
        }
      } elsif (selected == "RB 24J") {
        # the pylon has a sidewinder, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 179) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 179);
        }
      } elsif (selected == "RB 74") {
        # the pylon has a sidewinder, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 188) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 188);
        }
      } elsif (selected == "RB 71") {
        # the pylon has a skyflash, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 425) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 425);
        }
      } elsif (selected == "RB 99") {
        # the pylon has a amraam, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 291) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 291);
        }
      } elsif (selected == "M70") {
        # the pylon has a rocket pod, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 200) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 200);
        }
      } elsif (selected == "TEST") {
        # the pylon has a rocket pod, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 50) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 50);
        }
      } elsif (selected == "RB 15F") {
        # the pylon has a rocket pod, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") != 1763.7) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 1763.7);
        }
      } elsif (selected == "Drop tank") {
        # the pylon has a drop tank, give it a pointmass
        if (getprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]") == 0) {
          setprop("fdm/jsbsim/inertia/pointmass-weight-lbs["~ (i+1) ~"]", 224.87);#if change this also change it in jsbsim and -set file
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
          payloadName.setValue("RB 15F");
        } elsif (i == 2) {
          payloadName.setValue("RB 71");
        } elsif (i == 1 or i == 3) {
          payloadName.setValue("RB 99");
        } elsif (i == 4) {
          payloadName.setValue("RB 74");
        } elsif (i == 5) {
          payloadName.setValue("RB 24J");
        }
      }
    }

    #tracer ammo, due to it might run out faster than cannon rounds due to submodel delay not being precise
    if(input.subAmmo3.getValue() > 0) {
      input.subAmmo2.setValue(-1);
    } else {
      input.subAmmo2.setValue(0);
    }

    # outer stores
    var leftRb2474 = getprop("fdm/jsbsim/inertia/pointmass-weight-lbs[5]") == 188 or getprop("fdm/jsbsim/inertia/pointmass-weight-lbs[5]") == 179;
    var rightRb2474 = getprop("fdm/jsbsim/inertia/pointmass-weight-lbs[6]") == 188 or getprop("fdm/jsbsim/inertia/pointmass-weight-lbs[5]") == 179;
    input.MPint19.setIntValue(ja37.encode3bits(leftRb2474, rightRb2474, 0));

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
      setprop("sim/multiplay/generic/string[10]", flareStart~":flare");
    } else {
      # play the sound for out of flares
      setprop("ai/submodels/submodel[0]/flare-release-out-snd", TRUE);
    }
  }
  if (getprop("ai/submodels/submodel[0]/flare-release-snd") == TRUE and (flareStart + 1) < input.elapsed.getValue()) {
    setprop("ai/submodels/submodel[0]/flare-release-snd", FALSE);
    setprop("sim/multiplay/generic/string[10]", "0:noflare");
  }
  if (getprop("ai/submodels/submodel[0]/flare-release-out-snd") == TRUE and (flareStart + 1) < input.elapsed.getValue()) {
    setprop("ai/submodels/submodel[0]/flare-release-out-snd", FALSE);
  }
  if (flareCount > getprop("ai/submodels/submodel[0]/count")) {
    # A flare was released in last loop, we stop releasing flares, so user have to press button again to release new.
    setprop("ai/submodels/submodel[0]/flare-release", FALSE);
    flareCount = -1;
  }

  var mkeys = keys(armament.AIM.flying);
  var str = "";
  foreach(var m; mkeys) {
    var mid = m;
    m = armament.AIM.flying[m];
    var lat = m.latN.getValue();
    var lon = m.lonN.getValue();
    var alt = m.altN.getValue();
    #print();
    #print(mid);
    #print(lat);
    #print(lon);
    #print(alt);
    str = str~mid~";"~lat~";"~lon~";"~alt~":";
  }
  setprop("sim/multiplay/generic/string[13]", str);

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
    if (armSelect != 0 and getprop(str) == "M70") {
      setprop("/controls/armament/station["~armSelect~"]/trigger-m70", trigger);
    }
  } else {
    setprop("/controls/armament/station["~armSelect~"]/trigger", FALSE);
    setprop("/controls/armament/station["~armSelect~"]/trigger-m70", FALSE);
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

        setprop("payload/weight["~ (armSelect-1) ~"]/selected", "none");# empty the pylon
        setprop("controls/armament/station["~armSelect~"]/released", TRUE);# setting the pylon as fired
        #print("firing missile: "~armSelect~" "~getprop("controls/armament/station["~armSelect~"]/released"));
        var callsign = armament.AIM.active[armSelect-1].callsign;
        var type = armament.AIM.active[armSelect-1].type;
        armament.AIM.active[armSelect-1].release();#print("release "~(armSelect-1));
        
        var phrase = type ~ " fired at: " ~ callsign;
        if (getprop("payload/armament/msg")) {
          setprop("/sim/multiplay/chat", armament.defeatSpamFilter(phrase));
        } else {
          setprop("/sim/messages/atc", phrase);
        }
        var newStation = selectType(fired);
        if (newStation != -1) {
          input.stationSelect.setValue(newStation);
        }
      }
    }
  }
  if (fired == "M70") {
    var submodel = armSelect + 4;
    var ammo = getprop("ai/submodels/submodel["~submodel~"]/count");
    if (ammo == 0) {
      var newStation = selectType(fired);
      if (newStation != -1 and hasRockets(newStation) > 0) {
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
        if (distance < 50) {
          last_impact = input.elapsed.getValue();
          var phrase =  defeatSpamFilter(ballistic.getNode("name").getValue() ~ " hit: " ~ radar_logic.selection.get_Callsign());
          if (getprop("payload/armament/msg")) {
            setprop("/sim/multiplay/chat", phrase);
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

var warhead_lbs = {
    "aim-120":              44.00,
    "AIM120":               44.00,
    "RB-99":                44.00,
    "aim-7":                88.00,
    "RB-71":                88.00,
    "aim-9":                20.80,
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
      if (last_vector[1] == " FOX2 at" or last_vector[1] == " aim7 at" or last_vector[1] == " aim9 at" or last_vector[1] == " aim120 at" or last_vector[1] == " RB-24J fired at" or last_vector[1] == " RB-74 fired at" or last_vector[1] == " RB-71 fired at" or last_vector[1] == " RB-15F fired at" or last_vector[1] == " KN-06 fired at" or last_vector[1] == " RB-99 fired at" or m2000 == TRUE) {
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
      } elsif (getprop("sim/ja37/supported/old-custom-fails") > 0 and getprop("payload/armament/damage") == 1) {
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
              print(sprintf("Took %.1f", percent)~"% damage from "~type~" missile at "~dist~" meters distance! "~failed~" systems was hit.");
              nearby_explosion();
            }
          } 
        } elsif (last_vector[1] == " M70 rocket hit" or last_vector[1] == " KCA cannon shell hit" or last_vector[1] == " Gun Splash On " or last_vector[1] == " M61A1 shell hit") {
          # cannon hitting someone
          #print("cannon");
          if (size(last_vector) > 2 and last_vector[2] == " "~callsign) {
            # that someone is me!
            #print("hitting me");

            var probability = 0.20; # take 20% damage from each hit
            if (last_vector[1] == " Gun Splash On " or last_vector[1] == " M70 rocket hit") {
              probability = 0.30;
            }
            var failed = fail_systems(probability);
            print("Took "~probability*100~"% damage from cannon! "~failed~" systems was hit.");
            nearby_explosion();
          }
        }
      }
    }
  }
}

var spams = 0;

var defeatSpamFilter = func (str) {
  spams += 1;
  if (spams == 15) {
    spams = 1;
  }
  str = str~":";
  for (var i = 1; i <= spams; i+=1) {
    str = str~".";
  }
  return str;
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
  setprop("sim/ja37/sound/incoming"~clock, 1);
  settimer(func {stopIncomingSound(clock);},3);
}

var stopIncomingSound = func (clock) {
  setprop("sim/ja37/sound/incoming"~clock, 0);
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
  var priority = [1,3,2,4,5,6];
  var sel = -1;
  var i = 0;

  while (sel == -1 and i < 6) {
    var test = getprop("payload/weight["~(priority[i]-1)~"]/selected");
    if (test == type and hasRockets(priority[i]) != 0) {
      sel = priority[i];
    }
    i += 1;
  }

  return sel;
}

var hasRockets = func (station) {
  var loaded = -1;
  if (getprop("payload/weight["~(station-1)~"]/selected") == "M70") {
    var submodel = station + 4;
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
    if (type == "M70") {
      ammo = 0;
      for(var i = 1; i < 7; i += 1) {
        var rockets = hasRockets(i);
        ammo = rockets == -1?ammo:(rockets+ammo);
      }
    } elsif (type == "RB 71") {
      ammo = 0;
      for(var i = 0; i < 6; i += 1) {
        if(getprop("payload/weight["~i~"]/selected") == "RB 71") {
          ammo += 1;
        }
      }
    } elsif (type == "RB 99") {
      ammo = 0;
      for(var i = 0; i < 6; i += 1) {
        if(getprop("payload/weight["~i~"]/selected") == "RB 99") {
          ammo += 1;
        }
      }
    } elsif (type == "RB 74") {
      ammo = 0;
      for(var i = 0; i < 6; i += 1) {
        if(getprop("payload/weight["~i~"]/selected") == "RB 74") {
          ammo += 1;
        }
      }
    } elsif (type == "RB 24J") {
      ammo = 0;
      for(var i = 0; i < 6; i += 1) {
        if(getprop("payload/weight["~i~"]/selected") == "RB 24J") {
          ammo += 1;
        }
      }
    } elsif (type == "TEST") {
      ammo = 0;
      for(var i = 0; i < 6; i += 1) {
        if(getprop("payload/weight["~i~"]/selected") == "TEST") {
          ammo += 1;
        }
      }
    } elsif (type == "RB 15F") {
      ammo = 0;
      for(var i = 0; i < 6; i += 1) {
        if(getprop("payload/weight["~i~"]/selected") == "RB 15F") {
          ammo += 1;
        }
      }
    }
  }
  return ammo;
}

var cycle_weapons = func {
  # station 0 = cannon
  # station 1 = inner left wing
  # station 2 = left fuselage
  # station 3 = inner right wing
  # station 4 = right fuselage
  # station 5 = outer left wing
  # station 6 = outer right wing

  var sel = getprop("controls/armament/station-select");
  var type = sel==0?"KCA":getprop("payload/weight["~(sel-1)~"]/selected");
  var newType = "none";

  while(newType == "none") {
    if (type == "none") {
      sel = 0;
      newType = "KCA";
    } elsif (type == "KCA") {
      sel = selectType("M70");
      if (sel != -1) {
        newType = "M70";
      } else {
        type = "M70";
      }
    } elsif (type == "M70") {
      sel = selectType("RB 99");
      if (sel != -1) {
        newType = "RB 99";
      } else {
        type = "RB 99";
      }
    } elsif (type == "RB 99") {
      sel = selectType("RB 71");
      if (sel != -1) {
        newType = "RB 71";
      } else {
        type = "RB 71";
      }
    } elsif (type == "RB 71") {
      sel = selectType("RB 24J");
      if (sel != -1) {
        newType = "RB 24J";
      } else {
        type = "RB 24J";
      }
    } elsif (type == "RB 24J") {
      sel = selectType("TEST");
      if (sel != -1) {
        newType = "TEST";
      } else {
        type = "TEST";
      }
    } elsif (type == "TEST") {
      sel = selectType("RB 74");
      if (sel != -1) {
        newType = "RB 74";
      } else {
        type = "RB 74";
      }
    } elsif (type == "RB 74") {
      sel = selectType("RB 15F");
      if (sel != -1) {
        newType = "RB 15F";
      } else {
        type = "RB 15F";
      }
    } elsif (type == "RB 15F") {
      sel = 0;
      newType = "KCA";
    }
  }

  ja37.click();
  setprop("controls/armament/station-select", sel)
}

############ reload #####################

reloadAir2Air1979 = func {
  # Reload missiles - 6 of them.

  # Sidewinder
  setprop("payload/weight[1]/selected", "RB 24J");
  setprop("payload/weight[3]/selected", "RB 24J");
  setprop("payload/weight[4]/selected", "RB 24J");
  setprop("payload/weight[5]/selected", "RB 24J");
  screen.log.write("4 RB-24J missiles attached", 0.0, 1.0, 0.0);

  # Skyflash
  setprop("payload/weight[0]/selected", "RB 71");
  setprop("payload/weight[2]/selected", "RB 71");
  screen.log.write("2 RB-71 missiles attached", 0.0, 1.0, 0.0);

  # Reload flares - 40 of them.
  setprop("ai/submodels/submodel[0]/count", 60);
  setprop("ai/submodels/submodel[1]/count", 60);
  screen.log.write("60 flares loaded", 0.0, 1.0, 0.0);

  # Reload cannon - 146 of them.
  #setprop("ai/submodels/submodel[2]/count", 29);
  setprop("ai/submodels/submodel[3]/count", 146);
  setprop("ai/submodels/submodel[4]/count", 146);
  screen.log.write("146 cannon rounds loaded", 0.0, 1.0, 0.0);

  ja37.ct("rl");
}

reloadAir2Air1987 = func {
  # Reload missiles - 6 of them.

  # Sidewinder
  setprop("payload/weight[1]/selected", "RB 74");
  setprop("payload/weight[3]/selected", "RB 74");
  setprop("payload/weight[4]/selected", "RB 74");
  setprop("payload/weight[5]/selected", "RB 74");
  screen.log.write("4 RB-74 missiles attached", 0.0, 1.0, 0.0);

  # Skyflash
  setprop("payload/weight[0]/selected", "RB 71");
  setprop("payload/weight[2]/selected", "RB 71");
  screen.log.write("2 RB-71 missiles attached", 0.0, 1.0, 0.0);

  # Reload flares - 40 of them.
  setprop("ai/submodels/submodel[0]/count", 60);
  setprop("ai/submodels/submodel[1]/count", 60);
  screen.log.write("60 flares loaded", 0.0, 1.0, 0.0);

  # Reload cannon - 146 of them.
  #setprop("ai/submodels/submodel[2]/count", 29);
  setprop("ai/submodels/submodel[3]/count", 146);
  setprop("ai/submodels/submodel[4]/count", 146);
  screen.log.write("146 cannon rounds loaded", 0.0, 1.0, 0.0);

  ja37.ct("rl");
}

reloadAir2Air1997 = func {
  # Reload missiles - 6 of them.

  # Amraam
  setprop("payload/weight[1]/selected", "RB 99");
  setprop("payload/weight[3]/selected", "RB 99");
  setprop("payload/weight[0]/selected", "RB 99");
  setprop("payload/weight[2]/selected", "RB 99");
  screen.log.write("4 RB-99 missiles attached", 0.0, 1.0, 0.0);

  # Sidewinder
  setprop("payload/weight[4]/selected", "RB 74");
  setprop("payload/weight[5]/selected", "RB 74");
  screen.log.write("2 RB-74 missiles attached", 0.0, 1.0, 0.0);

  # Reload flares - 40 of them.
  setprop("ai/submodels/submodel[0]/count", 60);
  setprop("ai/submodels/submodel[1]/count", 60);
  screen.log.write("60 flares loaded", 0.0, 1.0, 0.0);

  # Reload cannon - 146 of them.
  #setprop("ai/submodels/submodel[2]/count", 29);
  setprop("ai/submodels/submodel[3]/count", 146);
  setprop("ai/submodels/submodel[4]/count", 146);
  screen.log.write("146 cannon rounds loaded", 0.0, 1.0, 0.0);

  ja37.ct("rl");
}

reloadAir2Ground = func {
  # Reload missiles - 4 of them.
  setprop("payload/weight[0]/selected", "RB 15F");
  setprop("payload/weight[1]/selected", "M70");
  setprop("payload/weight[2]/selected", "RB 15F");
  setprop("payload/weight[3]/selected", "M70");
  setprop("payload/weight[4]/selected", "RB 24J");
  setprop("payload/weight[5]/selected", "RB 24J");
  setprop("ai/submodels/submodel[5]/count", 6);
  setprop("ai/submodels/submodel[6]/count", 6);
  setprop("ai/submodels/submodel[7]/count", 6);
  setprop("ai/submodels/submodel[8]/count", 6);
  screen.log.write("2 Bofors M70 rocket pods attached", 0.0, 1.0, 0.0);
  screen.log.write("2 RB-15F cruise-missiles attached", 0.0, 1.0, 0.0);

  # Reload flares - 40 of them.
  setprop("ai/submodels/submodel[0]/count", 60);
  setprop("ai/submodels/submodel[1]/count", 60);
  screen.log.write("60 flares loaded", 0.0, 1.0, 0.0);

  # Reload cannon - 146 of them.
  #setprop("ai/submodels/submodel[2]/count", 29);
  setprop("ai/submodels/submodel[3]/count", 146);
  setprop("ai/submodels/submodel[4]/count", 146);
  screen.log.write("146 cannon rounds loaded", 0.0, 1.0, 0.0);

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
  var alt = active_node.getNode("altitude-m");
  var name = active_node.getNode("id");

  var coord = geo.Coord.new();
  coord.set_latlon(lat.getValue(), lon.getValue(), alt.getValue());

  var contact = radar_logic.ContactGPS.new(name.getValue(), coord);

  radar_logic.selection = contact;
}

setprop("/sim/failure-manager/display-on-screen", FALSE);