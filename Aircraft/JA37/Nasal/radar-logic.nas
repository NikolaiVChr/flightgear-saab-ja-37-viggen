var FALSE = 0;
var TRUE = 1;

var deg2rads = math.pi/180.0;
var rad2deg = 180.0/math.pi;
var kts2kmh = 1.852;
var feet2meter = 0.3048;
var round0 = func(x) { return math.abs(x) > 0.01 ? x : 0; };
var radarRange = getprop("ja37/systems/variant") == 0?120000:120000;#meter, is estimate. The AJ(S)-37 has 120KM and JA37 is almost 10 years newer, so is reasonable I think.

var containsVector = func (vec, item) {
  foreach(test; vec) {
    if (test == item) {
      return TRUE;
    }
  }
  return FALSE;
}

var containsVectorIndex = func (vec, item) {
  var ii = 0;
  foreach(test; vec) {
    if (test == item) {
      return ii;
    }
    ii += 1;
  }
  return -1;
}

var getClock = func (bearing) {
    var clock = int(((geo.normdeg(bearing)-15)/30)+1);
    if (clock == 0) {
      return 12;
    } else {
      return clock;
    }
}

var toggleRadarSteerOrder = func {
  steerOrder = !steerOrder;
  if (steerOrder == TRUE) {
    land.RR();
  }
}

var disableSteerOrder = func {
  steerOrder = FALSE;
}

var setSelection = func (s) {
  selection = s;
  steerOrder = FALSE;
}

var steerOrder = FALSE;

var self = nil;
var myAlt = nil;
var myPitch = nil;
var myRoll = nil;
var myHeading = nil;

var selection = nil;
var selection_updated = FALSE;
var tracks_index = 0;
var tracks = [];
var callsign_struct = {};
var rwr = [];

var lockLog  = events.LogBuffer.new(echo: 0);#compatible with older FG?
var lockLast = nil;

var AIR = 0;
var MARINE = 1;
var SURFACE = 2;
var ORDNANCE = 3;

var knownShips = {
    "missile_frigate":       nil,
    "frigate":       nil,
    "USS-LakeChamplain":     nil,
    "USS-NORMANDY":     nil,
    "USS-OliverPerry":     nil,
    "USS-SanAntonio":     nil,
};

var input = {
        radar_serv:       "instrumentation/radar/serviceable",
        hdgReal:          "/orientation/heading-deg",
        pitch:            "/orientation/pitch-deg",
        roll:             "/orientation/roll-deg",
        tracks_enabled:   "ja37/hud/tracks-enabled",
        callsign:         "/ja37/hud/callsign",
        carrierNear:      "fdm/jsbsim/ground/carrier-near",
        voltage:          "systems/electrical/outputs/ac-main-voltage",
        hydrPressure:     "fdm/jsbsim/systems/hydraulics/system1/pressure",
        ai_models:        "/ai/models",
        lookThrough:      "ja37/radar/look-through-terrain",
        dopplerOn:        "ja37/radar/doppler-enabled",
        dopplerSpeed:     "ja37/radar/min-doppler-speed-kt",
};

var RadarLogic = {

    new: func() {
        var radarLogic     = { parents : [RadarLogic]};
        radarLogic.typeHashes = {};
        return radarLogic;
    },

    loop: func () {
      me.findRadarTracks();
      #settimer(func me.loop(), 0.25);
    },

    findRadarTracks: func () {
      me.friends = [getprop("ja37/faf/friend-1"),getprop("ja37/faf/friend-2"),getprop("ja37/faf/friend-3"),getprop("ja37/faf/friend-4"),getprop("ja37/faf/friend-5"),getprop("ja37/faf/friend-6")];
      rwr = [FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE, FALSE];
      self      =  geo.aircraft_position();
      myPitch   =  input.pitch.getValue()*D2R;
      myRoll    =  input.roll.getValue()*D2R;
      myAlt     =  self.alt();
      myHeading =  input.hdgReal.getValue();
      selection_updated = FALSE;
      
      tracks = [];

      #do the MP planes
      me.players = [];
      foreach(item; multiplayer.model.list) {
        append(me.players, item.node);
      }
      me.AIplanes = input.ai_models.getChildren("aircraft");
      me.tankers = input.ai_models.getChildren("tanker");
      me.ships = input.ai_models.getChildren("ship");
      me.vehicles = input.ai_models.getChildren("groundvehicle");
      me.rb24 = input.ai_models.getChildren("rb-24");
      me.rb24j = input.ai_models.getChildren("rb-24j");
      me.rb71 = input.ai_models.getChildren("rb-71");
      me.rb74 = input.ai_models.getChildren("rb-74");
      me.rb99 = input.ai_models.getChildren("rb-99");
      me.rb15 = input.ai_models.getChildren("rb-15f");
      me.rb04 = input.ai_models.getChildren("rb-04e");
      me.rb05 = input.ai_models.getChildren("rb-05a");
      me.rb75 = input.ai_models.getChildren("rb-75");
      me.m90 = input.ai_models.getChildren("m90");
      me.test = input.ai_models.getChildren("test");
      if(selection != nil and selection.isValid() == FALSE) {
        #print("not valid");
        me.paint(selection.getNode(), FALSE);
        selection = nil;
        steerOrder = FALSE;
      }


      me.processTracks(me.players, FALSE, FALSE, TRUE);    
      me.processTracks(me.tankers, FALSE, FALSE, FALSE, AIR);
      me.processTracks(me.ships, FALSE, FALSE, FALSE, MARINE);
  #debug.benchmark("radar process AI tracks", func {    
      me.processTracks(me.AIplanes, FALSE, FALSE, FALSE, AIR);
  #});
      me.processTracks(me.vehicles, FALSE, FALSE, FALSE, SURFACE);
      me.processTracks(me.rb24, FALSE, TRUE, FALSE, ORDNANCE);
      me.processTracks(me.rb24j, FALSE, TRUE, FALSE, ORDNANCE);
      me.processTracks(me.rb71, FALSE, TRUE, FALSE, ORDNANCE);
      me.processTracks(me.rb74, FALSE, TRUE, FALSE, ORDNANCE);
      me.processTracks(me.rb99, FALSE, TRUE, FALSE, ORDNANCE);
      me.processTracks(me.rb15, FALSE, TRUE, FALSE, ORDNANCE);
      me.processTracks(me.rb04, FALSE, TRUE, FALSE, ORDNANCE);
      me.processTracks(me.rb05, FALSE, TRUE, FALSE, ORDNANCE);
      me.processTracks(me.rb75, FALSE, TRUE, FALSE, ORDNANCE);
      me.processTracks(me.m90, FALSE, TRUE, FALSE, ORDNANCE);
      me.processTracks(me.test, FALSE, TRUE, FALSE, ORDNANCE);
      me.processCallsigns(me.players);

      me.carriers = input.ai_models.getChildren("carrier");
      me.processTracks(me.carriers, TRUE, FALSE, FALSE, MARINE);

      if(input.tracks_enabled.getValue() == TRUE and input.radar_serv.getValue() > FALSE
         and input.voltage.getValue() > 170 and input.hydrPressure.getValue() == TRUE) {
        setprop("ja37/radar/active" , TRUE);
      } else {
        # Do not supply target info to the missiles if radar is off.
        if(selection != nil) {
          me.paint(selection.getNode(), FALSE);
        }
        selection = nil;
        steerOrder = FALSE;
        setprop("ja37/radar/active" , FALSE);
      }
      if(selection != nil and selection_updated == FALSE and selection.parents[0] != radar_logic.ContactGPS) {
        disableSteerOrder();
        #append(selection, "lock");
      }
  },

  processCallsigns: func (players) {
    callsign_struct = {};
    foreach (var player; players) {
      if(player.getChild("valid") != nil and player.getChild("valid").getValue() == TRUE and player.getChild("callsign") != nil and player.getChild("callsign").getValue() != "" and player.getChild("callsign").getValue() != nil) {
        me.callsign = player.getChild("callsign").getValue();
        callsign_struct[me.callsign] = player;
      }
    }
  },

  processTracks: func (vector, carrier, missile = 0, mp = 0, type = -1) {
    me.carrierNear = FALSE;
    foreach (var track; vector) {
      if(track != nil and track.getChild("valid") != nil and track.getChild("valid").getValue() == TRUE) {#only the tracks that are valid are sent here
        me.trackInfo = nil;
  #debug.benchmark("radar trackitemcalc", func {
        if(missile == FALSE) {
          me.trackInfo = me.trackItemCalc(track, getprop("instrumentation/radar/range"), carrier, mp, type);
        } else {
          me.trackInfo = me.trackMissileCalc(track, getprop("instrumentation/radar/range"), carrier, mp, type);
        }
  #});
  #debug.benchmark("radar process", func {
        if(me.trackInfo != nil) {
          me.distance = me.trackInfo.get_range()*NM2M;

          # find and remember the type of the track
          me.typeNode = track.getChild("model-shorter");
          me.model = nil;
          if (me.typeNode != nil) {
            me.model = me.typeNode.getValue();
          } else {
            me.pathNode = track.getNode("sim/model/path");
            if (me.pathNode != nil) {
              me.path = me.pathNode.getValue();

              me.model = split(".", split("/", me.path)[-1])[0];

              if (me.distance < 1000 and (me.model == "mp-clemenceau" or me.model == "mp-eisenhower" or me.model == "mp-nimitz" or me.model == "mp-vinson")) {
                me.carrierNear = TRUE;
              }

              me.model = me.remove_suffix(me.model, "-model");
              me.model = me.remove_suffix(me.model, "-anim");
              track.addChild("model-shorter").setValue(me.model);

              var funcHash = {
                new: func (trackN, pNode) {
                  me.listenerID1 = setlistener(trackN.getChild("valid"), func me.callme1(), nil, 1);
                  me.listenerID2 = setlistener(pNode,                    func me.callme2(), nil, 1);
                },
                callme1: func () {
                  if(me.trackme.getChild("valid").getValue() == FALSE) {
                    var child = me.trackme.removeChild("model-shorter",0);#index 0 must be specified!
                    if (child != nil) {#for some reason this can be called two times, even if listener removed, therefore this check.
                      me.del();
                    }
                  }
                },
                callme2: func () {
                  if(me.trackme.getNode("sim/model/path") == nil or funcHash.trackme.getNode("sim/model/path").getValue() != me.oldpath) {
                    var child = me.trackme.removeChild("model-shorter",0);
                    if (child != nil) {#for some reason this can be called two times, even if listener removed, therefore this check.
                      me.del();
                    }
                  }
                },
                del: func () {
                  removelistener(me.listenerID1);
                  removelistener(me.listenerID2);
                  radar_logic.radarLogic.typeHashes[me.trackme.getPath()] = nil;
                },
              };
              
              funcHash.trackme = track;
              funcHash.oldpath = me.path;

              me.typeHashes[track.getPath()] = funcHash;

              funcHash.new(track, me.pathNode);
            }
          }

          # tell the jsbsim hook system that if we are near a carrier
          if(carrier == TRUE and me.distance < 1000) {
            # is carrier and is within 1 Km range
            me.carrierNear = TRUE;
          }

          me.unique = track.getChild("unique");
          if (me.unique == nil) {
            me.unique = track.addChild("unique");
            me.unique.setDoubleValue(rand());
          }

          append(tracks, me.trackInfo);

          if(1==0 and selection == nil and getprop("ja37/avionics/cursor-on") != FALSE) {
            #this is first tracks in radar field, so will be default selection
            selection = me.trackInfo;
            lookatSelection();
            selection_updated = TRUE;
            #if (selection.get_type() == AIR) {
              me.paint(selection.getNode(), TRUE);
            #} else {
            #  me.paint(selection.getNode(), FALSE);
            #}
          #} elsif (track.getChild("name") != nil and track.getChild("name").getValue() == "RB-24J") {
            #for testing that selection view follows missiles
          #  selection = trackInfo;
          #  lookatSelection();
          #  selection_updated = TRUE;
          } elsif (selection != nil and selection.getUnique() == me.unique.getValue()) {
            # this track is already selected, updating it
            #print("updating target");
            selection = me.trackInfo;
            #if (selection.get_type() == AIR) {
              me.paint(selection.getNode(), TRUE);
            #} else {
            #  me.paint(selection.getNode(), FALSE);
            #}
            selection_updated = TRUE;
          } else {
            #print("end2 "~selection.getUnique()~"=="~unique.getValue());
            me.paint(me.trackInfo.getNode(), FALSE);
          }
        } else {
          #print("end");
          me.paint(track, FALSE);
        }
  #});      
      }#end of valid check
    }#end of foreach
    if(carrier == TRUE) {
      if(me.carrierNear != input.carrierNear.getValue()) {
        input.carrierNear.setBoolValue(me.carrierNear);
      }      
    }
  },#end of processTracks

  paint: func (node, painted) {
    if (node == nil) {
      return;
    }
    me.attr = node.getChild("painted");
    if (me.attr == nil) {
      me.attr = node.addChild("painted");
    }
    me.attr.setBoolValue(painted);
    #if(painted == TRUE) { 
      #print("painted "~attr.getPath()~" "~painted);
    #}
  },

  remove_suffix: func(s, x) {
      me.len = size(x);
      if (substr(s, -me.len) == x)
          return substr(s, 0, size(s) - me.len);
      return s;
  },

# trackInfo
#
# 0 - x position
# 1 - y position
# 2 - direct distance in meter
# 3 - distance in radar screen plane
# 4 - horizontal angle from aircraft in rad
# 5 - identifier
# 6 - node
# 7 - not targetable

  trackItemCalc: func (track, range, carrier, mp, type) {
    me.pos = track.getNode("position");
    me.x = me.pos.getNode("global-x").getValue();
    me.y = me.pos.getNode("global-y").getValue();
    me.z = me.pos.getNode("global-z").getValue();
    if(me.x == nil or me.y == nil or me.z == nil) {
      return nil;
    }
    me.aircraftPos = geo.Coord.new().set_xyz(me.x, me.y, me.z);
    me.item = me.trackCalc(me.aircraftPos, range, carrier, mp, type, track);
    
    return me.item;
  },

  trackMissileCalc: func (track, range, carrier, mp, type) {
    me.pos = track.getNode("position");
    me.alt = me.pos.getNode("altitude-ft").getValue();
    me.lat = me.pos.getNode("latitude-deg").getValue();
    me.lon = me.pos.getNode("longitude-deg").getValue();
    if(me.alt == nil or me.lat == nil or me.lon == nil) {
      return nil;
    }
    me.aircraftPos = geo.Coord.new().set_latlon(me.lat, me.lon, me.alt*feet2meter);
    return me.trackCalc(me.aircraftPos, range, carrier, mp, type, track);
  },

  trackCalc: func (aircraftPos, range, carrier, mp, type, node) {
    me.distance = nil;
    me.distanceDirect = nil;
    
    call(func {me.distance = self.distance_to(aircraftPos); me.distanceDirect = self.direct_distance_to(aircraftPos);}, nil, var err = []);

    if ((size(err))or(me.distance==nil)) {
      # Oops, have errors. Bogus position data (and distance==nil).
      #print("Received invalid position data: dist "~distance);
      #target_circle[track_index+maxTargetsMP].hide();
      #print(i~" invalid pos.");
      return nil;
    }

    if (mp == TRUE or getprop("ja37/supported/picking") == TRUE) {
      # is multiplayer or 2017.2.1+
      if (me.isNotBehindTerrain(aircraftPos) == FALSE) {
        #hidden behind terrain
        return nil;
      }
    }

    if (me.distance < 120000 and mp == TRUE and node.getNode("callsign") != nil and getprop("ja37/systems/variant") == 0 and TI.ti.ECMon == TRUE) {
        # if within 120 Km and a multiplayer, we check if its radar beams are detected.
        var callsign = node.getNode("callsign").getValue();
        #print("callsign "~callsign);
        if (!containsVector(me.friends, callsign)) {
            # its not a friend, so lets do the check
            if (node.getNode("orientation/true-heading-deg") != nil) {
                var bearing = self.course_to(aircraftPos);
                var trAct = node.getNode("instrumentation/transponder/inputs/mode");
                if (trAct != nil and trAct.getValue() != 0) {
                  # transponder on
                  var clock = getClock(bearing-myHeading);
                  rwr[clock-1] = TRUE;
                } else {
                  var heading = node.getNode("orientation/true-heading-deg").getValue();
                  
                  var inv_bearing =  bearing+180;
                  var deviation = inv_bearing - heading;
                  #print("dev "~deviation);
                  var rdrAct = node.getNode("sim/multiplay/generic/int[2]");
                  if (((rdrAct != nil and rdrAct.getValue()!=0) or rdrAct == nil) and math.abs(geo.normdeg180(deviation)) < 60) {
                      # we detect its radar is pointed at us and active
                      var clock = getClock(bearing-myHeading);
                      rwr[clock-1] = TRUE;
                  }
                }
            }
        }
    }

    if (me.distanceDirect < range or node.getName() == "rb-99") {#is max radar range of ja37
      # Node with valid position data (and "distance!=nil").
      #distance = distance*kts2kmh*1000;
      me.aircraftAlt = aircraftPos.alt(); #altitude in meters

      #aircraftAlt = aircraftPos.x();
      #myAlt = self.x();
      #distance = math.sqrt(pow2(aircraftPos.z() - self.z()) + pow2(aircraftPos.y() - self.y()));

      #ground angle
      me.yg_rad = vector.Math.getPitch(self, aircraftPos)*D2R-myPitch;#math.atan2(aircraftAlt-myAlt, distance) - myPitch; 
      me.xg_rad = (self.course_to(aircraftPos) - myHeading) * D2R;

      while (me.xg_rad > math.pi) {
        me.xg_rad = me.xg_rad - 2*math.pi;
      }
      while (me.xg_rad < -math.pi) {
        me.xg_rad = me.xg_rad + 2*math.pi;
      }
      while (me.yg_rad > math.pi) {
        me.yg_rad = me.yg_rad - 2*math.pi;
      }
      while (me.yg_rad < -math.pi) {
        me.yg_rad = me.yg_rad + 2*math.pi;
      }

      #aircraft angle
      me.ya_rad = me.xg_rad * math.sin(myRoll) + me.yg_rad * math.cos(myRoll);
      me.xa_rad = me.xg_rad * math.cos(myRoll) - me.yg_rad * math.sin(myRoll);

      while (me.xa_rad < -math.pi) {
        me.xa_rad = me.xa_rad + 2*math.pi;
      }
      while (me.xa_rad > math.pi) {
        me.xa_rad = me.xa_rad - 2*math.pi;
      }
      while (me.ya_rad > math.pi) {
        me.ya_rad = me.ya_rad - 2*math.pi;
      }
      while (me.ya_rad < -math.pi) {
        me.ya_rad = me.ya_rad + 2*math.pi;
      }

      if(node.getName() == "rb-99" or (me.ya_rad > -61.5 * D2R and me.ya_rad < 61.5 * D2R and me.xa_rad > -61.5 * D2R and me.xa_rad < 61.5 * D2R)) {
        #is within the radar cone
        # AJ37 manual: 61.5 deg sideways.

        
        if (mp == TRUE) {
          me.shrtr = node.getChild("model-shorter")==nil?"nil":node.getChild("model-shorter").getValue();
          if (me.doppler(aircraftPos, node) == TRUE) {
            # doppler picks it up, must be an aircraft
            type = AIR;
          } elsif (me.aircraftAlt > 1 and !contains(knownShips, me.shrtr)) {
            # doppler does not see it, and is not on sea, must be ground target
            type = SURFACE;
          } else {
            type = MARINE;
          }
        }

        me.contact = Contact.new(node, type);

        if (node.getName() == "rb-99" or rcs.inRadarRange(me.contact, 40, 3.2) == TRUE) {
          return me.contact;
        } else {
          return nil;
        }        

      } elsif (carrier == TRUE) {
        # need to return carrier even if out of radar cone, due to carrierNear calc
        me.contact = Contact.new(node, type);
        #me.contact.setPolar(900000, me.xa_rad_corr, me.xa_rad, me.ya_rad);#TODO: fix
        #me.contact.setCartesian(900000, 900000);# 900000 used in hud to know if out of radar cone.
        return me.contact;
      }
    }
    return nil;
  },

#
# The following 6 methods is partly from Mirage 2000-5
#
  isNotBehindTerrain: func(SelectCoord) {
    me.myOwnPos = geo.aircraft_position();
    if(me.myOwnPos.alt() > 8900 and SelectCoord.alt() > 8900) {
      # both higher than mt. everest, so not need to check.
      return TRUE;
    }
    if (getprop("ja37/supported/picking") == TRUE) {
      me.xyz = {"x":me.myOwnPos.x(),                  "y":me.myOwnPos.y(),                 "z":me.myOwnPos.z()};
      me.dir = {"x":SelectCoord.x()-me.myOwnPos.x(),  "y":SelectCoord.y()-me.myOwnPos.y(), "z":SelectCoord.z()-me.myOwnPos.z()};

      # Check for terrain between own aircraft and other:
      me.v = get_cart_ground_intersection(me.xyz, me.dir);
      if (me.v == nil) {
        return TRUE;
        #printf("No terrain, planes has clear view of each other");
      } else {
       me.terrain = geo.Coord.new();
       me.terrain.set_latlon(me.v.lat, me.v.lon, me.v.elevation);
       me.maxDist = me.myOwnPos.direct_distance_to(SelectCoord);
       me.terrainDist = me.myOwnPos.direct_distance_to(me.terrain);
       if (me.terrainDist < me.maxDist) {
         #print("terrain found between the planes");
         return FALSE;
       } else {
          return TRUE;
          #print("The planes has clear view of each other");
       }
      }
    } else {
      # this function has been optimized by Pinto
      me.isVisible = 0;
      
      # Because there is no terrain on earth that can be between these 2
      if(input.lookThrough.getValue() == FALSE)
      {
          # Temporary variable
          # A (our plane) coord in meters
          me.a = me.myOwnPos.x();
          me.b = me.myOwnPos.y();
          me.c = me.myOwnPos.z();
          # B (target) coord in meters
          me.d = SelectCoord.x();
          me.e = SelectCoord.y();
          me.f = SelectCoord.z();
          me.difa = me.d - me.a;
          me.difb = me.e - me.b;
          me.difc = me.f - me.c;
      
      #print("a,b,c | " ~ a ~ "," ~ b ~ "," ~ c);
      #print("d,e,f | " ~ d ~ "," ~ e ~ "," ~ f);
      
          # direct Distance in meters
          me.myDistance = math.sqrt( math.pow((me.d-me.a),2) + math.pow((me.e-me.b),2) + math.pow((me.f-me.c),2)); #calculating distance ourselves to avoid another call to geo.nas (read: speed, probably).
          #print("myDistance: " ~ myDistance);
          me.Aprime = geo.Coord.new();
          
          # Here is to limit FPS drop on very long distance
          me.L = 500;
          if(me.myDistance > 50000)
          {
              me.L = me.myDistance / 15;
          }
          me.maxLoops = int(me.myDistance / me.L);
          
          me.isVisible = 1;
          # This loop will make travel a point between us and the target and check if there is terrain
          for(var i = 1 ; i <= me.maxLoops ; i += 1)
          {
            #calculate intermediate step
            #basically dividing the line into maxLoops number of steps, and checking at each step
            #to ascii-art explain it:
            #  |us|----------|step 1|-----------|step 2|--------|step 3|----------|them|
            #there will be as many steps as there is i
            #every step will be equidistant
            
            #also, if i == 0 then the first step will be our plane
            
            me.x = ((me.difa/(me.maxLoops+1))*i)+me.a;
            me.y = ((me.difb/(me.maxLoops+1))*i)+me.b;
            me.z = ((me.difc/(me.maxLoops+1))*i)+me.c;
            #print("i:" ~ i ~ "|x,y,z | " ~ x ~ "," ~ y ~ "," ~ z);
            me.Aprime.set_xyz(me.x,me.y,me.z);
            me.AprimeTerrainAlt = geo.elevation(me.Aprime.lat(), me.Aprime.lon());
            if(me.AprimeTerrainAlt == nil)
            {
              me.AprimeTerrainAlt = 0;
            }
            
            if(me.AprimeTerrainAlt > me.Aprime.alt())
            {
              return 0;
            }
          }
      }
      else
      {
          me.isVisible = 1;
      }
    }
    return me.isVisible;
  },

# will return true if absolute closure speed of target is greater than 50kt
#
  doppler: func(t_coord, t_node) {
    # Test to check if the target can hide below us
    # Or Hide using anti doppler movements

    if (input.dopplerOn.getValue() == FALSE or 
        (t_node.getNode("velocities/true-airspeed-kt") != nil and t_node.getNode("velocities/true-airspeed-kt").getValue() != nil
         and t_node.getNode("radar/range-nm") != nil and t_node.getNode("radar/range-nm").getValue() != nil
         and math.atan2(t_node.getNode("velocities/true-airspeed-kt").getValue(), t_node.getNode("radar/range-nm").getValue()*1000) > 0.025)# if aircraft traverse speed seen from me is high
        ) {
      return TRUE;
    }

    me.DopplerSpeedLimit = input.dopplerSpeed.getValue();
    me.InDoppler = 0;
    me.groundNotbehind = me.isGroundNotBehind(t_coord, t_node);

    if(me.groundNotbehind)
    {
        me.InDoppler = 1;
    } elsif(abs(me.get_closure_rate_from_Coord(t_coord, t_node)) > me.DopplerSpeedLimit)
    {
        me.InDoppler = 1;
    }
    return me.InDoppler;
  },

  isGroundNotBehind: func(t_coord, t_node){
    me.myPitch = me.get_Elevation_from_Coord(t_coord);
    me.GroundNotBehind = 1; # sky is behind the target (this don't work on a valley)
    if(me.myPitch < 0)
    {
        # the aircraft is below us, the ground could be below
        # Based on earth curve. Do not work with mountains
        # The script will calculate what is the ground distance for the line (us-target) to reach the ground,
        # If the earth was flat. Then the script will compare this distance to the horizon distance
        # If our distance is greater than horizon, then sky behind
        # If not, we cannot see the target unless we have a doppler radar
        me.distHorizon = geo.aircraft_position().alt() / math.tan(abs(me.myPitch * D2R)) * M2NM;
        me.horizon = me.get_horizon( geo.aircraft_position().alt() *M2FT, t_node);
        me.TempBool = (me.distHorizon > me.horizon);
        me.GroundNotBehind = (me.distHorizon > me.horizon);
    }
    return me.GroundNotBehind;
  },

  get_Elevation_from_Coord: func(t_coord) {
    # fix later: Nasal runtime error: floating point error in math.asin() when logged in as observer:
    #var myPitch = math.asin((t_coord.alt() - geo.aircraft_position().alt()) / t_coord.direct_distance_to(geo.aircraft_position())) * R2D;
    return vector.Math.getPitch(geo.aircraft_position(), t_coord);
  },

  get_horizon: func(own_alt, t_node){
      me.tgt_alt = t_node.getNode("position/altitude-ft").getValue();
      if(debug.isnan(me.tgt_alt))
      {
          return(0);
      }
      if(me.tgt_alt < 0 or me.tgt_alt == nil)
      {
          me.tgt_alt = 0;
      }
      if(own_alt < 0 or own_alt == nil)
      {
          own_alt = 0;
      }
      # Return the Horizon in NM
      return (2.2 * ( math.sqrt(own_alt * FT2M) + math.sqrt(me.tgt_alt * FT2M)));# don't understand the 2.2 conversion to NM here..
  },

  get_closure_rate_from_Coord: func(t_coord, t_node) {
      me.MyAircraftCoord = geo.aircraft_position();

      if(t_node.getNode("orientation/true-heading-deg") == nil) {
        return 0;
      }

      # First step : find the target heading.
      me.myHeading = t_node.getNode("orientation/true-heading-deg").getValue();
      
      # Second What would be the aircraft heading to go to us
      me.myCoord2 = t_coord;
      me.projectionHeading = me.myCoord2.course_to(me.MyAircraftCoord);
      
      if (me.myHeading == nil or me.projectionHeading == nil) {
        return 0;
      }

      # Calculate the angle difference
      me.myAngle = me.myHeading - me.projectionHeading; #Should work even with negative values
      
      # take the "ground speed"
      # velocities/true-air-speed-kt
      me.mySpeed = t_node.getNode("velocities/true-airspeed-kt").getValue();
      me.myProjetedHorizontalSpeed = me.mySpeed*math.cos(me.myAngle*D2R); #in KTS
      
      #print("Projetted Horizontal Speed:"~ myProjetedHorizontalSpeed);
      
      # Now getting the pitch deviation
      me.myPitchToAircraft = - t_node.getNode("radar/elevation-deg").getValue();
      #print("My pitch to Aircraft:"~myPitchToAircraft);
      
      # Get V speed
      if(t_node.getNode("velocities/vertical-speed-fps").getValue() == nil)
      {
          return 0;
      }
      me.myVspeed = t_node.getNode("velocities/vertical-speed-fps").getValue()*FPS2KT;
      # This speed is absolutely vertical. So need to remove pi/2
      
      me.myProjetedVerticalSpeed = me.myVspeed * math.cos(me.myPitchToAircraft-90*D2R);
      
      # Control Print
      #print("myVspeed = " ~myVspeed);
      #print("Total Closure Rate:" ~ (myProjetedHorizontalSpeed+myProjetedVerticalSpeed));
      
      # Total Calculation
      me.cr = me.myProjetedHorizontalSpeed+me.myProjetedVerticalSpeed;
      
      # Setting Essential properties
      #var rng = me. get_range_from_Coord(MyAircraftCoord);
      #var newTime= ElapsedSec.getValue();
      #if(me.get_Validity())
      #{
      #    setprop(me.InstrString ~ "/" ~ me.shortstring ~ "/closure-last-range-nm", rng);
      #    setprop(me.InstrString ~ "/" ~ me.shortstring ~ "/closure-rate-kts", cr);
      #}
      
      return me.cr;
  },

};

var nextTarget = func () {
  if (getprop("ja37/avionics/cursor-on") != FALSE and getprop("ja37/radar/active") == TRUE) {
  var max_index = size(tracks)-1;
  if(max_index > -1) {
    if(tracks_index < max_index) {
      tracks_index += 1;
    } else {
      tracks_index = 0;
    }
    selection = tracks[tracks_index];
    steerOrder = FALSE;
    #if (selection.get_type() == AIR) {
      radarLogic.paint(selection.getNode(), TRUE);
    #} else {
    #  radarLogic.paint(selection.getNode(), FALSE);
    #}
    lookatSelection();
  } else {
    tracks_index = -1;
    if (selection != nil) {
      radarLogic.paint(selection.getNode(), FALSE);
    }
  }
}
};

var centerTarget = func () {
  if (getprop("ja37/avionics/cursor-on") != FALSE and getprop("ja37/radar/active") == TRUE) {
    var centerMost = nil;
    var centerDist = 99999;
    var centerIndex = -1;
    var i = -1;
    foreach(var track; tracks) {
      i += 1;
      if(track.get_cartesian()[0] != 900000) {
        var dist = math.abs(track.get_cartesian()[0]) + math.abs(track.get_cartesian()[1]);
        if(dist < centerDist) {
          centerDist = dist;
          centerMost = track;
          centerIndex = i;
        }
      }
    }
    if (centerMost != nil) {
      if (centerMost != selection) {
        steerOrder = FALSE;
      }
      selection = centerMost;
      #if (selection.get_type() == AIR) {
        radarLogic.paint(selection.getNode(), TRUE);
      #} else {
      #  radarLogic.paint(selection.getNode(), FALSE);
      #}
      lookatSelection();
      tracks_index = centerIndex;
    }
  }
};

var jumper = nil;

var jumpTo = func (c) {
  jumper = c;
};

var jumpExecute = func {
  if (jumper != nil) {
    var index = containsVectorIndex(tracks, jumper);
    if (index != -1) {
      selection = jumper;
      radarLogic.paint(selection.getNode(), TRUE);
      lookatSelection();
      tracks_index = index;
      steerOrder = TRUE;
      land.RR();
    }
    jumper = nil;
  }
};

var jumper2 = nil;

var jump2To = func (c) {
  jumper2 = c;
};

var jump2Execute = func {
  if (jumper2 != nil) {
    var index = containsVectorIndex(tracks, jumper2);
    if (index != -1) {
      selection = jumper2;
      radarLogic.paint(selection.getNode(), TRUE);
      lookatSelection();
      tracks_index = index;
    }
    jumper2 = nil;
  }
};

var lookatSelection = func () {
  props.globals.getNode("/ja37/radar/selection-heading-deg", 1).unalias();
  props.globals.getNode("/ja37/radar/selection-pitch-deg", 1).unalias();
  props.globals.getNode("/ja37/radar/selection-heading-deg", 1).alias(selection.getNode().getNode("radar/bearing-deg"));
  props.globals.getNode("/ja37/radar/selection-pitch-deg", 1).alias(selection.getNode().getNode("radar/elevation-deg"));
};

# setup property nodes for the loop
foreach(var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
};

var getCallsign = func (callsign) {
  var node = callsign_struct[callsign];
  return node;
};

var Contact = {
    # For now only used in guided missiles, to make it compatible with Mirage 2000-5.
    new: func(c, class) {
        var obj             = { parents : [Contact]};
#debug.benchmark("radar process1", func {
        obj.rdrProp         = c.getNode("radar");
        obj.oriProp         = c.getNode("orientation");
        obj.velProp         = c.getNode("velocities");
        obj.posProp         = c.getNode("position");
        obj.heading         = obj.oriProp.getNode("true-heading-deg");
#});
#debug.benchmark("radar process2", func {
        obj.alt             = obj.posProp.getNode("altitude-ft");
        obj.lat             = obj.posProp.getNode("latitude-deg");
        obj.lon             = obj.posProp.getNode("longitude-deg");

        obj.x             = obj.posProp.getNode("global-x");
        obj.y             = obj.posProp.getNode("global-y");
        obj.z             = obj.posProp.getNode("global-z");
#});
#debug.benchmark("radar process3", func {
        #As it is a geo.Coord object, we have to update lat/lon/alt ->and alt is in meters
        obj.coord = geo.Coord.new();
        if (obj.x == nil or obj.x.getValue() == nil) {
          obj.coord.set_latlon(obj.lat.getValue(), obj.lon.getValue(), obj.alt.getValue() * FT2M);
        } else {
          obj.coord.set_xyz(obj.x.getValue(), obj.y.getValue(), obj.z.getValue());
        }
#});
#debug.benchmark("radar process4", func {
        obj.pitch           = obj.oriProp.getNode("pitch-deg");
        obj.roll            = obj.oriProp.getNode("roll-deg");
        obj.speed           = obj.velProp.getNode("true-airspeed-kt");
        obj.vSpeed          = obj.velProp.getNode("vertical-speed-fps");
        obj.callsign        = c.getNode("callsign", 1);
        obj.shorter         = c.getNode("model-shorter");
        obj.orig_callsign   = obj.callsign.getValue();
        obj.name            = c.getNode("name");
        obj.sign            = c.getNode("sign",1);
        obj.valid           = c.getNode("valid");
        obj.painted         = c.getNode("painted");
        obj.unique          = c.getNode("unique");
        obj.validTree       = 0;

        obj.eta             = c.getNode("ETA");
        obj.hit             = c.getNode("hit");
#});
#debug.benchmark("radar process5", func {        
        #obj.transponderID   = c.getNode("instrumentation/transponder/transmitted-id");
#});
#debug.benchmark("radar process6", func {                
        obj.acType          = c.getNode("sim/model/ac-type");
        obj.rdrAct          = c.getNode("sim/multiplay/generic/int[2]");
        obj.type            = c.getName();
        obj.index           = c.getIndex();
        obj.string          = "ai/models/" ~ obj.type ~ "[" ~ obj.index ~ "]";
        obj.shortString     = obj.type ~ "[" ~ obj.index ~ "]";
#});
#debug.benchmark("radar process7", func {
        obj.range           = obj.rdrProp.getNode("range-nm");
        obj.bearing         = obj.rdrProp.getNode("bearing-deg");
        #obj.elevation       = obj.rdrProp.getNode("elevation-deg"); this is computes in C++ using atan, so does not take curvature of earth into account.
#});        
        obj.deviation       = nil;

        obj.node            = c;
        obj.class           = class;

        obj.polar           = [0,0];
        obj.cartesian       = [0,0];
        
        return obj;
    },

    getETA: func {
      if (me.eta != nil) {
        return me.eta.getValue();
      }
      return nil;
    },

    getHitChance: func {
      if (me.hit != nil) {
        return me.hit.getValue();
      }
      return nil;
    },

    isValid: func () {
      var valid = me.valid.getValue();
      if (valid == nil) {
        valid = FALSE;
      }
      if (me.callsign.getValue() != me.orig_callsign) {
        valid = FALSE;
      }
      return valid;
    },

    isRadarActive: func {
      if (me.rdrAct == nil or me.rdrAct.getValue() < 0 or me.rdrAct.getValue() > 1) {
        return TRUE;
      }
      return me.rdrAct.getValue();
    },

    isPainted: func () {
      if (me.painted == nil) {
        me.painted = me.node.getNode("painted");
      }
      if (me.painted == nil) {
        return nil;
      }
      var p = me.painted.getValue();
      return p;
    },

    getUnique: func () {
      if (me.unique == nil) {
        me.unique = me.node.getNode("unique");
      }
      if (me.unique == nil) {
        return nil;
      }
      var u = me.unique.getValue();
      return u;
    },

    getElevation: func() {
        return vector.Math.getPitch(geo.aircraft_position(), me.coord);
    },

    getNode: func () {
      return me.node;
    },

    getFlareNode: func () {
      return me.node.getNode("rotors/main/blade[3]/flap-deg");
    },

    getChaffNode: func () {
      return me.node.getNode("rotors/main/blade[3]/position-deg");
    },

    remove: func(){
        if(me.validTree != 0){
          me.validTree.setBoolValue(0);
        }
    },

    get_Coord: func(){
        if (me.x != nil and me.x.getValue() != nil) {
          me.coord.set_xyz(me.x.getValue(), me.y.getValue(), me.z.getValue());
        } else {
          me.coord.set_latlon(me.lat.getValue(), me.lon.getValue(), me.alt.getValue() * FT2M);
        }
        var TgTCoord  = geo.Coord.new(me.coord);
        return TgTCoord;
    },

    get_Callsign: func(){
        var n = me.callsign.getValue();
        if(n != "" and n != nil) {
            return n;
        }
        if (me.name == nil) {
          me.name = me.getNode().getNode("name");
        }
        if (me.name == nil) {
          n = "";
        } else {
          n = me.name.getValue();
        }
        if(n != "" and n != nil) {
            return n;
        }
        n = me.sign.getValue();
        if(n != "" and n != nil) {
            return n;
        }
        return "UFO";
    },

    get_model: func(){
        var n = "";
        if (me.shorter == nil) {
          me.shorter = me.node.getNode("model-shorter");
        }
        if (me.shorter != nil) {
          n = me.shorter.getValue();
        }
        if(n != "" and n != nil) {
            return n;
        }
        n = me.sign.getValue();
        if(n != "" and n != nil) {
            return n;
        }
        if (me.name == nil) {
          me.name = me.getNode().getNode("name");
        }
        if (me.name == nil) {
          n = "";
        } else {
          n = me.name.getValue();
        }
        if(n != "" and n != nil) {
            return n;
        }
        return me.get_Callsign();
    },

    get_Speed: func(){
        # return true airspeed
        var n = me.speed.getValue();
        return n;
    },

    get_Longitude: func(){
        var n = me.lon.getValue();
        return n;
    },

    get_Latitude: func(){
        var n = me.lat.getValue();
        return n;
    },

    get_Pitch: func(){
        var n = me.pitch.getValue();
        return n;
    },

    get_Roll: func(){
        var n = me.roll.getValue();
        return n;
    },

    get_heading : func(){
        var n = me.heading.getValue();
        if(n == nil)
        {
            n = 0;
        }
        return n;
    },

    get_bearing: func(){
        var n = 0;
        n = me.bearing.getValue();
        if(n == nil or n == 0) {
            # AI/MP has no radar properties
            n = me.get_bearing_from_Coord(geo.aircraft_position());
        }
        return n;
    },

    get_bearing_from_Coord: func(MyAircraftCoord){
        me.get_Coord();
        var myBearing = 0;
        if(me.coord.is_defined()) {
            myBearing = MyAircraftCoord.course_to(me.coord);
        }
        return myBearing;
    },

    getMagBearing: func() {
      #not super tested
      me.mag_offset = getprop("/orientation/heading-magnetic-deg") - getprop("/orientation/heading-deg");
      return geo.normdeg(me.get_bearing() + me.mag_offset);
    },

    get_reciprocal_bearing: func(){
        return geo.normdeg(me.get_bearing() + 180);
    },

    get_deviation: func(true_heading_ref, coord){
        me.deviation =  - deviation_normdeg(true_heading_ref, me.get_bearing_from_Coord(coord));
        return me.deviation;
    },

    get_altitude: func(){
        #Return Alt in feet
        return me.alt.getValue();
    },

    get_Elevation_from_Coord: func(MyAircraftCoord) {
        #me.get_Coord();
        #var value = (me.coord.alt() - MyAircraftCoord.alt()) / me.coord.direct_distance_to(MyAircraftCoord);
        #if (math.abs(value) > 1) {
          # warning this else will fail if logged in as observer and see aircraft on other side of globe
        #  return 0;
        #}
        #var myPitch = math.asin(value) * R2D;
        return vector.Math.getPitch(me.get_Coord(), MyAircraftCoord);
    },

    get_total_elevation_from_Coord: func(own_pitch, MyAircraftCoord){
        var myTotalElevation =  - deviation_normdeg(own_pitch, me.get_Elevation_from_Coord(MyAircraftCoord));
        return myTotalElevation;
    },
    
    get_total_elevation: func(own_pitch) {
        me.deviation =  - deviation_normdeg(own_pitch, me.getElevation());
        return me.deviation;
    },

    get_range: func() {
        var r = 0;
        if(me.range == nil or me.range.getValue() == nil or me.range.getValue() == 0) {
            # AI/MP has no radar properties
            me.get_Coord();
            r = me.coord.direct_distance_to(geo.aircraft_position()) * M2NM;
        } else {
          r = me.range.getValue();
        }
        return r;
    },

    get_range_from_Coord: func(MyAircraftCoord) {
        var myCoord = me.get_Coord();
        var myDistance = 0;
        if(myCoord.is_defined()) {
            myDistance = MyAircraftCoord.direct_distance_to(myCoord) * M2NM;
        }
        return myDistance;
    },

    get_type: func () {
      return me.class;
    },

    get_cartesian: func() {
      me.get_Coord();
      me.crft = geo.aircraft_position();
      me.ptch = vector.Math.getPitch(me.crft,me.coord);
      me.dst  = me.crft.direct_distance_to(me.coord);
      me.brng = me.crft.course_to(me.coord);
      me.hrz  = math.cos(me.ptch*D2R)*me.dst;

      me.vel_gz = -math.sin(me.ptch*D2R)*me.dst;
      me.vel_gx = math.cos(me.brng*D2R) *me.hrz;
      me.vel_gy = math.sin(me.brng*D2R) *me.hrz;
      

      me.yaw   = input.hdgReal.getValue() * D2R;
      me.myroll= input.roll.getValue()    * D2R;
      me.mypitch= input.pitch.getValue()   * D2R;

      #printf("heading %.1f bearing %.1f pitch %.1f north %.1f east %.1f down %.1f", input.hdgReal.getValue(), me.brng, me.ptch, me.vel_gx, me.vel_gy, me.vel_gz);

      me.sy = math.sin(me.yaw);   me.cy = math.cos(me.yaw);
      me.sr = math.sin(me.myroll);  me.cr = math.cos(me.myroll);
      me.sp = math.sin(me.mypitch); me.cp = math.cos(me.mypitch);
   
      me.vel_bx = me.vel_gx * me.cy * me.cp
                 + me.vel_gy * me.sy * me.cp
                 + me.vel_gz * -me.sp;
      me.vel_by = me.vel_gx * (me.cy * me.sp * me.sr - me.sy * me.cr)
                 + me.vel_gy * (me.sy * me.sp * me.sr + me.cy * me.cr)
                 + me.vel_gz * me.cp * me.sr;
      me.vel_bz = me.vel_gx * (me.cy * me.sp * me.cr + me.sy * me.sr)
                 + me.vel_gy * (me.sy * me.sp * me.cr - me.cy * me.sr)
                 + me.vel_gz * me.cp * me.cr;
   
      me.dir_y  = math.atan2(round0(me.vel_bz), math.max(me.vel_bx, 0.001)) * R2D;
      me.dir_x  = math.atan2(round0(me.vel_by), math.max(me.vel_bx, 0.001)) * R2D;

      var hud_pos_x = canvas_HUD.pixelPerDegreeX * me.dir_x;
      var hud_pos_y = canvas_HUD.centerOffset + canvas_HUD.pixelPerDegreeY * me.dir_y;

      return [hud_pos_x, hud_pos_y];
    },

    get_polar: func() {
      me.get_Coord();
      var aircraftAlt = me.coord.alt();

      var self      =  geo.aircraft_position();
      var myPitch   =  input.pitch.getValue()*D2R;
      var myRoll    =  0;#input.roll.getValue()*deg2rads;  Ignore roll, since a real radar does that
      var myAlt     =  self.alt();
      var myHeading =  input.hdgReal.getValue();
      var distance  =  self.distance_to(me.coord);

      var yg_rad = vector.Math.getPitch(self, me.coord)*D2R-myPitch;#math.atan2(aircraftAlt-myAlt, distance) - myPitch; 
      var xg_rad = (self.course_to(me.coord) - myHeading) * deg2rads;
      
      while (xg_rad > math.pi) {
        xg_rad = xg_rad - 2*math.pi;
      }
      while (xg_rad < -math.pi) {
        xg_rad = xg_rad + 2*math.pi;
      }
      while (yg_rad > math.pi) {
        yg_rad = yg_rad - 2*math.pi;
      }
      while (yg_rad < -math.pi) {
        yg_rad = yg_rad + 2*math.pi;
      }

      #aircraft angle
      var ya_rad = xg_rad * math.sin(myRoll) + yg_rad * math.cos(myRoll);
      var xa_rad = xg_rad * math.cos(myRoll) - yg_rad * math.sin(myRoll);
      var xa_rad_corr = xg_rad;

      while (xa_rad_corr < -math.pi) {
        xa_rad_corr = xa_rad_corr + 2*math.pi;
      }
      while (xa_rad_corr > math.pi) {
        xa_rad_corr = xa_rad_corr - 2*math.pi;
      }
      while (xa_rad < -math.pi) {
        xa_rad = xa_rad + 2*math.pi;
      }
      while (xa_rad > math.pi) {
        xa_rad = xa_rad - 2*math.pi;
      }
      while (ya_rad > math.pi) {
        ya_rad = ya_rad - 2*math.pi;
      }
      while (ya_rad < -math.pi) {
        ya_rad = ya_rad + 2*math.pi;
      }

      var distanceRadar = distance;#/math.cos(myPitch);

      return [distanceRadar, xa_rad_corr, xa_rad, ya_rad, ya_rad+myPitch];
    },
};

var ContactGPS = {
  new: func(callsign, coord) {
    var obj             = { parents : [ContactGPS]};# in real OO class this should inherit from Contact, but in nasal it does not need to
    obj.coord           = coord;
    obj.callsign        = callsign;
    obj.unique          = rand();
    return obj;
  },

  isValid: func () {
    return TRUE;
  },

  isRadarActive: func {
    return FALSE;
  },

  isPainted: func () {
    return TRUE;
  },

  getUnique: func () {
    return me.unique;
  },

  getElevation: func() {
      #var e = 0;
      #var self = geo.aircraft_position();
      #var angleInv = ja37.clamp(self.distance_to(me.coord)/self.direct_distance_to(me.coord), -1, 1);
      #e = (self.alt()>me.coord.alt()?-1:1)*math.acos(angleInv)*R2D;
      return vector.Math.getPitch(self, me.coord);
  },

  getNode: func () {
    return nil;
  },

  getFlareNode: func () {
    return nil;
  },

  getChaffNode: func () {
    return nil;
  },

  remove: func(){
      
  },

  get_Coord: func(){
      return me.coord;
  },

  getETA: func {
      return nil;
    },

    getHitChance: func {
      return nil;
    },

  get_Callsign: func(){
      return me.callsign;
  },

  get_model: func(){
      return "GPS Location";
  },

  get_Speed: func(){
      # return true airspeed
      return 0;
  },

  get_Longitude: func(){
      var n = me.coord.lon();
      return n;
  },

  get_Latitude: func(){
      var n = me.coord.lat();
      return n;
  },

  get_Pitch: func(){
      return 0;
  },

  get_Roll: func(){
      return 0;
  },

  get_heading : func(){
      return 0;
  },

  get_bearing: func(){
      var n = me.get_bearing_from_Coord(geo.aircraft_position());
      return n;
  },

  get_bearing_from_Coord: func(MyAircraftCoord){
      var myBearing = 0;
      if(me.coord.is_defined()) {
          myBearing = MyAircraftCoord.course_to(me.coord);
      }
      return myBearing;
  },

  get_reciprocal_bearing: func(){
      return geo.normdeg(me.get_bearing() + 180);
  },

  getMagBearing: func() {
    #not super tested
    me.mag_offset = getprop("/orientation/heading-magnetic-deg") - getprop("/orientation/heading-deg");
    return geo.normdeg(me.get_bearing() + me.mag_offset);
  },

  get_deviation: func(true_heading_ref, coord){
      me.deviation =  - deviation_normdeg(true_heading_ref, me.get_bearing_from_Coord(coord));
      return me.deviation;
  },

  get_altitude: func(){
      #Return Alt in feet
      return me.coord.alt()*M2FT;
  },

  get_Elevation_from_Coord: func(MyAircraftCoord) {
      #var value = (me.coord.alt() - MyAircraftCoord.alt()) / me.coord.direct_distance_to(MyAircraftCoord);
      #if (math.abs(value) > 1) {
        # warning this else will fail if logged in as observer and see aircraft on other side of globe
      #  return 0;
      #}
      #var myPitch = math.asin(value) * R2D;
      return vector.Math.getPitch(me.get_Coord(), MyAircraftCoord);
  },

  get_total_elevation_from_Coord: func(own_pitch, MyAircraftCoord){
      var myTotalElevation =  - deviation_normdeg(own_pitch, me.get_Elevation_from_Coord(MyAircraftCoord));
      return myTotalElevation;
  },
  
  get_total_elevation: func(own_pitch) {
      me.deviation =  - deviation_normdeg(own_pitch, me.getElevation());
      return me.deviation;
  },

  get_range: func() {
      var r = me.coord.direct_distance_to(geo.aircraft_position()) * M2NM;
      return r;
  },

  get_range_from_Coord: func(MyAircraftCoord) {
      var myDistance = 0;
      if(me.coord.is_defined()) {
          myDistance = MyAircraftCoord.direct_distance_to(me.coord) * M2NM;
      }
      return myDistance;
  },

  get_type: func () {
    return SURFACE;
  },

  get_cartesian: func {
    me.crft = geo.aircraft_position();
    me.ptch = vector.Math.getPitch(me.crft,me.coord);
    me.dst  = me.crft.direct_distance_to(me.coord);
    me.brng = me.crft.course_to(me.coord);
    me.hrz  = math.cos(me.ptch*D2R)*me.dst;

    me.vel_gz = -math.sin(me.ptch*D2R)*me.dst;
    me.vel_gx = math.cos(me.brng*D2R) *me.hrz;
    me.vel_gy = math.sin(me.brng*D2R) *me.hrz;
    

    me.yaw   = input.hdgReal.getValue() * D2R;
    me.roll  = input.roll.getValue()    * D2R;
    me.pitch = input.pitch.getValue()   * D2R;

    #printf("heading %.1f bearing %.1f pitch %.1f north %.1f east %.1f down %.1f", input.hdgReal.getValue(), me.brng, me.ptch, me.vel_gx, me.vel_gy, me.vel_gz);

    me.sy = math.sin(me.yaw);   me.cy = math.cos(me.yaw);
    me.sr = math.sin(me.roll);  me.cr = math.cos(me.roll);
    me.sp = math.sin(me.pitch); me.cp = math.cos(me.pitch);
 
    me.vel_bx = me.vel_gx * me.cy * me.cp
               + me.vel_gy * me.sy * me.cp
               + me.vel_gz * -me.sp;
    me.vel_by = me.vel_gx * (me.cy * me.sp * me.sr - me.sy * me.cr)
               + me.vel_gy * (me.sy * me.sp * me.sr + me.cy * me.cr)
               + me.vel_gz * me.cp * me.sr;
    me.vel_bz = me.vel_gx * (me.cy * me.sp * me.cr + me.sy * me.sr)
               + me.vel_gy * (me.sy * me.sp * me.cr - me.cy * me.sr)
               + me.vel_gz * me.cp * me.cr;
 
    me.dir_y  = math.atan2(round0(me.vel_bz), math.max(me.vel_bx, 0.001)) * R2D;
    me.dir_x  = math.atan2(round0(me.vel_by), math.max(me.vel_bx, 0.001)) * R2D;

    var hud_pos_x = canvas_HUD.pixelPerDegreeX * me.dir_x;
    var hud_pos_y = canvas_HUD.centerOffset + canvas_HUD.pixelPerDegreeY * me.dir_y;

    return [hud_pos_x, hud_pos_y];
  },

  get_polar: func() {

    var aircraftAlt = me.coord.alt();

    var self      =  geo.aircraft_position();
    var myPitch   =  input.pitch.getValue()*deg2rads;
    var myRoll    =  0;#input.roll.getValue()*deg2rads;  Ignore roll, since a real radar does that
    var myAlt     =  self.alt();
    var myHeading =  input.hdgReal.getValue();
    var distance  =  self.distance_to(me.coord);

    var yg_rad = vector.Math.getPitch(self, me.coord)*D2R-myPitch;#math.atan2(aircraftAlt-myAlt, distance) - myPitch; 
    var xg_rad = (self.course_to(me.coord) - myHeading) * deg2rads;
    
    while (xg_rad > math.pi) {
      xg_rad = xg_rad - 2*math.pi;
    }
    while (xg_rad < -math.pi) {
      xg_rad = xg_rad + 2*math.pi;
    }
    while (yg_rad > math.pi) {
      yg_rad = yg_rad - 2*math.pi;
    }
    while (yg_rad < -math.pi) {
      yg_rad = yg_rad + 2*math.pi;
    }

    #aircraft angle
    var ya_rad = xg_rad * math.sin(myRoll) + yg_rad * math.cos(myRoll);
    var xa_rad = xg_rad * math.cos(myRoll) - yg_rad * math.sin(myRoll);
    var xa_rad_corr = xg_rad;

    while (xa_rad_corr < -math.pi) {
      xa_rad_corr = xa_rad_corr + 2*math.pi;
    }
    while (xa_rad_corr > math.pi) {
      xa_rad_corr = xa_rad_corr - 2*math.pi;
    }
    while (xa_rad < -math.pi) {
      xa_rad = xa_rad + 2*math.pi;
    }
    while (xa_rad > math.pi) {
      xa_rad = xa_rad - 2*math.pi;
    }
    while (ya_rad > math.pi) {
      ya_rad = ya_rad - 2*math.pi;
    }
    while (ya_rad < -math.pi) {
      ya_rad = ya_rad + 2*math.pi;
    }

    var distanceRadar = distance;#/math.cos(myPitch);

    return [distanceRadar, xa_rad_corr, xa_rad, ya_rad, ya_rad+myPitch];
  },
};

var ContactGhost = {
  new: func() {
    var obj             = { parents : [ContactGhost]};# in real OO class this should inherit from Contact, but in nasal it does not need to
    obj.callsign        = "Ghost";
    obj.unique          = rand();
    return obj;
  },

  isValid: func () {
    return TRUE;
  },

  isRadarActive: func {
    return FALSE;
  },

  isPainted: func () {
    return TRUE;
  },

  getUnique: func () {
    return me.unique;
  },

  getElevation: func() {
      #var e = 0;
      #var self = geo.aircraft_position();
      #var angleInv = ja37.clamp(self.distance_to(me.coord)/self.direct_distance_to(me.coord), -1, 1);
      #e = (self.alt()>me.coord.alt()?-1:1)*math.acos(angleInv)*R2D;
      return 0;
  },

  getNode: func () {
    return nil;
  },

  getFlareNode: func () {
    return nil;
  },

  getChaffNode: func () {
    return nil;
  },

  remove: func(){
      
  },

  get_Coord: func(){
      var ghost = geo.aircraft_position();
      var alt = ghost.alt()+0;
      ghost.apply_course_distance(getprop("orientation/heading-deg"),8*NM2M);
      ghost.set_alt(alt);
      return ghost;
  },

  getETA: func {
      return nil;
    },

    getHitChance: func {
      return nil;
    },

  get_Callsign: func(){
      return me.callsign;
  },

  get_model: func(){
      return "Training target";
  },

  get_Speed: func(){
      # return true airspeed
      return getprop("velocities/airspeed-kt");
  },

  get_Longitude: func(){
      var n = me.get_Coord().lon();
      return n;
  },

  get_Latitude: func(){
      var n = me.get_Coord().lat();
      return n;
  },

  get_Pitch: func(){
      return 0;
  },

  get_Roll: func(){
      return 0;
  },

  get_heading : func(){
      return getprop("orientation/heading-deg");
  },

  get_bearing: func(){
      return getprop("orientation/heading-deg");
  },

  get_bearing_from_Coord: func(MyAircraftCoord){
      var myBearing = 0;
      myBearing = MyAircraftCoord.course_to(me.get_Coord());
      return myBearing;
  },

  get_reciprocal_bearing: func(){
      return geo.normdeg(me.get_bearing() + 180);
  },

  getMagBearing: func() {
    #not super tested
    me.mag_offset = getprop("/orientation/heading-magnetic-deg") - getprop("/orientation/heading-deg");
    return geo.normdeg(me.get_bearing() + me.mag_offset);
  },

  get_deviation: func(true_heading_ref, coord){
      me.deviation =  - deviation_normdeg(true_heading_ref, me.get_bearing_from_Coord(coord));
      return me.deviation;
  },

  get_altitude: func(){
      #Return Alt in feet
      return getprop("position/altitude-ft");
  },

  get_Elevation_from_Coord: func(MyAircraftCoord) {
      return vector.Math.getPitch(me.get_Coord(), MyAircraftCoord);
  },

  get_total_elevation_from_Coord: func(own_pitch, MyAircraftCoord){
      var myTotalElevation =  - deviation_normdeg(own_pitch, me.get_Elevation_from_Coord(MyAircraftCoord));
      return myTotalElevation;
  },
  
  get_total_elevation: func(own_pitch) {
      me.deviation =  - deviation_normdeg(own_pitch, me.getElevation());
      return me.deviation;
  },

  get_range: func() {
      var r = me.get_Coord().direct_distance_to(geo.aircraft_position()) * M2NM;
      return r;
  },

  get_range_from_Coord: func(MyAircraftCoord) {
      var myDistance = 0;
      if(me.coord.is_defined()) {
          myDistance = MyAircraftCoord.direct_distance_to(me.get_Coord()) * M2NM;
      }
      return myDistance;
  },

  get_type: func () {
    return AIR;
  },

  get_cartesian: func() {
    var gpsAlt = me.get_Coord().alt();

    var self      =  geo.aircraft_position();
    var myPitch   =  input.pitch.getValue()*deg2rads;
    var myRoll    =  input.roll.getValue()*deg2rads;
    var myAlt     =  self.alt();
    var myHeading =  input.hdgReal.getValue();
    var distance  =  self.distance_to(me.get_Coord());

    var yg_rad = vector.Math.getPitch(self, me.get_Coord())*D2R-myPitch;#math.atan2(gpsAlt-myAlt, distance) - myPitch; 
    var xg_rad = (self.course_to(me.get_Coord()) - myHeading) * deg2rads;
    
    while (xg_rad > math.pi) {
      xg_rad = xg_rad - 2*math.pi;
    }
    while (xg_rad < -math.pi) {
      xg_rad = xg_rad + 2*math.pi;
    }
    while (yg_rad > math.pi) {
      yg_rad = yg_rad - 2*math.pi;
    }
    while (yg_rad < -math.pi) {
      yg_rad = yg_rad + 2*math.pi;
    }

    #aircraft angle, remember positive roll is right
    var ya_rad = xg_rad * math.sin(myRoll) + yg_rad * math.cos(myRoll);
    var xa_rad = xg_rad * math.cos(myRoll) - yg_rad * math.sin(myRoll);

    while (xa_rad < -math.pi) {
      xa_rad = xa_rad + 2*math.pi;
    }
    while (xa_rad > math.pi) {
      xa_rad = xa_rad - 2*math.pi;
    }
    while (ya_rad > math.pi) {
      ya_rad = ya_rad - 2*math.pi;
    }
    while (ya_rad < -math.pi) {
      ya_rad = ya_rad + 2*math.pi;
    }

    var hud_pos_x = canvas_HUD.pixelPerDegreeX * xa_rad * rad2deg;
    var hud_pos_y = canvas_HUD.centerOffset + canvas_HUD.pixelPerDegreeY * -ya_rad * rad2deg;

    return [hud_pos_x, hud_pos_y];
  },

  get_polar: func() {
    var aircraftAlt = me.get_Coord().alt();

    var self      =  geo.aircraft_position();
    var myPitch   =  input.pitch.getValue()*deg2rads;
    var myRoll    =  0;#input.roll.getValue()*deg2rads;  Ignore roll, since a real radar does that
    var myAlt     =  self.alt();
    var myHeading =  input.hdgReal.getValue();
    var distance  =  self.distance_to(me.get_Coord());

    var yg_rad = vector.Math.getPitch(self, me.get_Coord())*D2R-myPitch;#math.atan2(aircraftAlt-myAlt, distance) - myPitch; 
    var xg_rad = (self.course_to(me.get_Coord()) - myHeading) * deg2rads;
    
    while (xg_rad > math.pi) {
      xg_rad = xg_rad - 2*math.pi;
    }
    while (xg_rad < -math.pi) {
      xg_rad = xg_rad + 2*math.pi;
    }
    while (yg_rad > math.pi) {
      yg_rad = yg_rad - 2*math.pi;
    }
    while (yg_rad < -math.pi) {
      yg_rad = yg_rad + 2*math.pi;
    }

    #aircraft angle
    var ya_rad = xg_rad * math.sin(myRoll) + yg_rad * math.cos(myRoll);
    var xa_rad = xg_rad * math.cos(myRoll) - yg_rad * math.sin(myRoll);
    var xa_rad_corr = xg_rad;

    while (xa_rad_corr < -math.pi) {
      xa_rad_corr = xa_rad_corr + 2*math.pi;
    }
    while (xa_rad_corr > math.pi) {
      xa_rad_corr = xa_rad_corr - 2*math.pi;
    }
    while (xa_rad < -math.pi) {
      xa_rad = xa_rad + 2*math.pi;
    }
    while (xa_rad > math.pi) {
      xa_rad = xa_rad - 2*math.pi;
    }
    while (ya_rad > math.pi) {
      ya_rad = ya_rad - 2*math.pi;
    }
    while (ya_rad < -math.pi) {
      ya_rad = ya_rad + 2*math.pi;
    }

    var distanceRadar = distance;#/math.cos(myPitch);

    return [distanceRadar, xa_rad_corr, xa_rad, ya_rad, ya_rad+myPitch];
  },
};

var deviation_normdeg = func(our_heading, target_bearing) {
  var dev_norm = geo.normdeg180(our_heading - target_bearing);
  return dev_norm;
}

var radarLogic = nil;

var starter = func () {
  removelistener(lsnr);
  if(getprop("ja37/supported/radar") == TRUE) {
    radarLogic = RadarLogic.new();
    #radarLogic.loop();
  }
};
#var lsnr = setlistener("ja37/supported/initialized", starter);