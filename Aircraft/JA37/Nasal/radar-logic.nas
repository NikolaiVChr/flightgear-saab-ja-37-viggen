var FALSE = 0;
var TRUE = 1;

var deg2rads = math.pi/180.0;
var rad2deg = 180.0/math.pi;
var kts2kmh = 1.852;
var feet2meter = 0.3048;

var radarRange = 48000;#meter

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

input = {
        radar_serv:       "instrumentation/radar/serviceable",
        hdgReal:          "/orientation/heading-deg",
        pitch:            "/orientation/pitch-deg",
        roll:             "/orientation/roll-deg",
        tracks_enabled:   "sim/ja37/hud/tracks-enabled",
        callsign:         "/sim/ja37/hud/callsign",
        carrierNear:      "fdm/jsbsim/ground/carrier-near",
        voltage:          "systems/electrical/outputs/ac-main-voltage",
        hydrPressure:     "fdm/jsbsim/systems/hydraulics/system1/pressure",
};

var findRadarTracks = func () {
  self      =  geo.aircraft_position();
  myPitch   =  input.pitch.getValue()*deg2rads;
  myRoll    = -input.roll.getValue()*deg2rads;
  myAlt     =  self.alt();
  myHeading =  input.hdgReal.getValue();
  
  tracks = [];

  var node_ai = props.globals.getNode("/ai/models");

  if(input.tracks_enabled.getValue() == 1 and input.radar_serv.getValue() > 0 and input.voltage.getValue() > 170 and input.hydrPressure.getValue() == 1) {

    #do the MP planes
    var players = [];
    foreach(item; multiplayer.model.list) {
      append(players, item.node);
    }

    var AIplanes = node_ai.getChildren("aircraft");
    var tankers = node_ai.getChildren("tanker");
    var ships = node_ai.getChildren("ship");
    var vehicles = node_ai.getChildren("groundvehicle");
    var rb24 = node_ai.getChildren("rb-24j");

    if(selection != nil and selection[6].getNode("valid").getValue() == FALSE) {
      selection = nil;
    }

    processTracks(players, FALSE);    
    processTracks(tankers, FALSE);
    processTracks(ships, FALSE);
    processTracks(AIplanes, FALSE);
    processTracks(vehicles, FALSE);
    processTracks(rb24, FALSE, TRUE);
    processCallsigns(players);
  }
  var carriers = node_ai.getChildren("carrier");
  processTracks(carriers, TRUE);
}

var processCallsigns = func (players) {
  callsign_struct = {};
  foreach (var player; players) {
    if(player.getChild("valid") != nil and player.getChild("valid").getValue() == TRUE and player.getChild("callsign") != nil and player.getChild("callsign").getValue() != "" and player.getChild("callsign").getValue() != nil) {
      var callsign = player.getChild("callsign").getValue();
      callsign_struct[callsign] = player;
    }
  }
}


var processTracks = func (vector, carrier, missile = FALSE) {
  var carrierNear = FALSE;
  foreach (var track; vector) {
    if(track != nil and track.getChild("valid") != nil and track.getChild("valid").getValue() == TRUE) {#only the tracks that are valid are sent here
      var trackInfo = nil;
      
      if(missile == FALSE) {
        trackInfo = trackItemCalc(track, radarRange, carrier);
      } else {
        trackInfo = trackMissileCalc(track, radarRange, carrier);
      }
      if(trackInfo != nil) {
        var distance = trackInfo[2];

        # tell the jsbsim hook system that if we are near a carrier
        if(carrier == TRUE and distance < 1000) {
          # is carrier and is within 1 Km range
          carrierNear = TRUE;
        }

        # find and remember the type of the track
        var typeNode = track.getChild("model-shorter");
        var model = nil;
        if (typeNode != nil) {
          model = typeNode.getValue();
        } else {
          var pathNode = track.getNode("sim/model/path");
          if (pathNode != nil) {
            var path = pathNode.getValue();
            model = split(".", split("/", path)[-1])[0];
            model = remove_suffix(model, "-model");
            model = remove_suffix(model, "-anim");
            track.addChild("model-shorter").setValue(model);

            var funcHash = {
              #init: func (listener, trck) {
              #  me.listenerID = listener;
              #  me.trackme = trck;
              #},
              callme1: func {
                if(funcHash.trackme.getChild("valid").getValue() == FALSE) {
                  var child = funcHash.trackme.removeChild("model-shorter",0);#index 0 must be specified!
                  if (child != nil) {#for some reason this can be called two times, even if listener removed, therefore this check.
                    removelistener(funcHash.listenerID1);
                    removelistener(funcHash.listenerID2);
                  }
                }
              },
              callme2: func {
                if(funcHash.trackme.getNode("sim/model/path") == nil or funcHash.trackme.getNode("sim/model/path").getValue() != me.oldpath) {
                  var child = funcHash.trackme.removeChild("model-shorter",0);
                  if (child != nil) {#for some reason this can be called two times, even if listener removed, therefore this check.
                    removelistener(funcHash.listenerID1);
                    removelistener(funcHash.listenerID2);
                  }
                }
              }
            };
            
            funcHash.trackme = track;
            funcHash.oldpath = path;
            funcHash.listenerID1 = setlistener(track.getChild("valid"), func {call(func funcHash.callme1(), nil, funcHash, funcHash, var err =[]);}, 0, 1);
            funcHash.listenerID2 = setlistener(pathNode,                func {call(func funcHash.callme2(), nil, funcHash, funcHash, var err =[]);}, 0, 1);
          }
        }


        #append(trackInfo, nil);
        
        # figure out what indentification to show in hud
        if(input.callsign.getValue() == 1) {
          if(track.getChild("callsign") != nil and track.getChild("callsign").getValue() != "" and track.getChild("callsign").getValue() != nil) {
            ident = track.getChild("callsign").getValue();
          } elsif (track.getChild("name") != nil and track.getChild("name").getValue() != "" and track.getChild("name").getValue() != nil) {
            #only used by AI
            ident = track.getChild("name").getValue();
          } elsif (track.getChild("sign") != nil and track.getChild("sign").getValue() != "" and track.getChild("sign").getValue() != nil) {
            #only used by AI
            ident = track.getChild("sign").getValue();
          } else {
            ident = "";
          }
        } else {
          if(model != nil) {
            ident = model;
          } elsif (track.getChild("sign") != nil and track.getChild("sign").getValue() != "" and track.getChild("sign").getValue() != nil) {
            #only used by AI
            ident = track.getChild("sign").getValue();  
          } elsif (track.getChild("name") != nil and track.getChild("name").getValue() != "" and track.getChild("name").getValue() != nil) {
            #only used by AI
            ident = track.getChild("name").getValue();
          } elsif (track.getChild("callsign") != nil and track.getChild("callsign").getValue() != "" and track.getChild("callsign").getValue() != nil) {
            ident = track.getChild("callsign").getValue();
          } else {
            ident = "";
          } 
        }

        append(trackInfo, ident);
        append(trackInfo, track);
        append(trackInfo, (carrier == TRUE or missile == TRUE)?TRUE:FALSE);

        var unique = track.getChild("unique");
        if (unique == nil) {
          unique = track.addChild("unique");
          unique.setValue(rand());
        }

        append(tracks, trackInfo);

        if(selection == nil) {
          #this is first tracks in radar field, so will be default selection
          selection = trackInfo;
          lookatSelection();
          selection_updated = TRUE;
        #} elsif (track.getChild("name") != nil and track.getChild("name").getValue() == "RB-24J") {
          #for testing that selection view follows missiles
        #  selection = trackInfo;
        #  lookatSelection();
        #  selection_updated = TRUE;
        } elsif (selection != nil and selection[6].getChild("unique").getValue() == unique.getValue()) {
          # this track is already selected, updating it
          selection = trackInfo;
          selection_updated = TRUE;
        }
      }#end of error check
    }#end of valid check
  }#end of foreach
  if(carrier == TRUE) {
    if(carrierNear != input.carrierNear.getValue()) {
      input.carrierNear.setValue(carrierNear);
    }      
  }
}#end of processTracks

var remove_suffix = func(s, x) {
    var len = size(x);
    if (substr(s, -len) == x)
        return substr(s, 0, size(s) - len);
    return s;
}

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

var trackItemCalc = func (track, range, carrier) {
  var x = track.getNode("position/global-x").getValue();
  var y = track.getNode("position/global-y").getValue();
  var z = track.getNode("position/global-z").getValue();
  var aircraftPos = geo.Coord.new().set_xyz(x, y, z);
  return trackCalc(aircraftPos, range, carrier);
}

var trackMissileCalc = func (track, range, carrier) {
  var alt = track.getNode("position/altitude-ft").getValue();
  var lat = track.getNode("position/latitude-deg").getValue();
  var lon = track.getNode("position/longitude-deg").getValue();
  if(alt == nil or lat == nil or lon == nil) {
    return nil;
  }
  var aircraftPos = geo.Coord.new().set_latlon(lat, lon, alt*feet2meter);
  return trackCalc(aircraftPos, range, carrier);
}

var trackCalc = func (aircraftPos, range, carrier) {
  var distance = nil;
  var distanceDirect = nil;
  
  call(func {distance = self.distance_to(aircraftPos); distanceDirect = self.direct_distance_to(aircraftPos);}, nil, var err = []);

  if ((size(err))or(distance==nil)) {
    # Oops, have errors. Bogus position data (and distance==nil).
    #print("Received invalid position data: dist "~distance);
    #target_circle[track_index+maxTargetsMP].hide();
    #print(i~" invalid pos.");
  } elsif (distanceDirect < range) {#is max radar range of ja37
    # Node with valid position data (and "distance!=nil").
    #distance = distance*kts2kmh*1000;
    var aircraftAlt = aircraftPos.alt(); #altitude in meters

    #aircraftAlt = aircraftPos.x();
    #myAlt = self.x();
    #distance = math.sqrt(pow2(aircraftPos.z() - self.z()) + pow2(aircraftPos.y() - self.y()));

    #ground angle
    var yg_rad = math.atan2(aircraftAlt-myAlt, distance) - myPitch; 
    var xg_rad = (self.course_to(aircraftPos) - myHeading) * deg2rads;
    
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
    var ya_rad = xg_rad * math.sin(-myRoll) + yg_rad * math.cos(-myRoll);
    var xa_rad = xg_rad * math.cos(-myRoll) - yg_rad * math.sin(-myRoll);

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

    if(ya_rad > -1 and ya_rad < 1 and xa_rad > -1 and xa_rad < 1) {
      #is within the radar cone

      var distanceRadar = distance/math.cos(myPitch);

      var hud_pos_x = canvas_HUD.pixelPerDegreeX * xa_rad * rad2deg;
      var hud_pos_y = canvas_HUD.centerOffset + canvas_HUD.pixelPerDegreeY * -ya_rad * rad2deg;
      return [hud_pos_x, hud_pos_y, distanceDirect, distanceRadar, xa_rad];
    } elsif (carrier == TRUE) {
      # need to return carrier even if out of radar cone, due to carrierNear calc
      return [90000, 90000, distanceDirect, distanceDirect, xa_rad];# 90000 used in hud to know if out of radar cone.
    }
  }
  return nil;
}

var nextTarget = func () {
  var max_index = size(tracks)-1;
  if(max_index > -1) {
    if(tracks_index < max_index) {
      tracks_index += 1;
    } else {
      tracks_index = 0;
    }
    selection = tracks[tracks_index];
    lookatSelection();
  } else {
    tracks_index = -1;
  }
}

var centerTarget = func () {
  var centerMost = nil;
  var centerDist = 99999;
  var centerIndex = -1;
  var i = -1;
  foreach(var track; tracks) {
    i += 1;
    if(track[0] != 90000) {
      var dist = math.abs(track[0]) + math.abs(track[1]);
      if(dist < centerDist) {
        centerDist = dist;
        centerMost = track;
        centerIndex = i;
      }
    }
  }
  if (centerMost != nil) {
    selection = centerMost;
    lookatSelection();
    tracks_index = centerIndex;
  }
}

var lookatSelection = func () {
  props.globals.getNode("/sim/ja37/radar/selection-heading-deg", 1).unalias();
  props.globals.getNode("/sim/ja37/radar/selection-pitch-deg", 1).unalias();
  props.globals.getNode("/sim/ja37/radar/selection-heading-deg", 1).alias(selection[6].getNode("radar/bearing-deg"));
  props.globals.getNode("/sim/ja37/radar/selection-pitch-deg", 1).alias(selection[6].getNode("radar/elevation-deg"));
}

# setup property nodes for the loop
foreach(var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}

#loop
var loop = func () {
  findRadarTracks();
  settimer(loop, 0.05);
}

var starter = func () {
  removelistener(lsnr);
  if(getprop("sim/ja37/supported/radar") == TRUE) {
    loop();
  }
}

var getCallsign = func (callsign) {
  var node = callsign_struct[callsign];
  return node;
}

var lsnr = setlistener("sim/ja37/supported/initialized", starter);