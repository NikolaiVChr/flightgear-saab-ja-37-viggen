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

input = {
        radar_serv:       "instrumentation/radar/serviceable",
        alt_ft_real:      "position/altitude-ft",
        hdgReal:          "/orientation/heading-deg",
        pitch:            "/orientation/pitch-deg",
        roll:             "/orientation/roll-deg",
        tracks_enabled:   "sim/ja37/hud/tracks-enabled",
        callsign:         "/sim/ja37/hud/callsign",
        carrierNear:      "fdm/jsbsim/ground/carrier-near",
};

var findRadarTracks = func () {
  self      =  geo.aircraft_position();
  myPitch   =  input.pitch.getValue()*deg2rads;
  myRoll    = -input.roll.getValue()*deg2rads;
  myAlt     =  input.alt_ft_real.getValue()*feet2meter;
  myHeading =  input.hdgReal.getValue();
  
  tracks = [];

  if(input.tracks_enabled.getValue() == 1 and input.radar_serv.getValue() > 0) {

    #do the MP planes
    var players = [];
    foreach(item; multiplayer.model.list) {
      append(players, item.node);
    }

    #do the AI:
    var node_ai = props.globals.getNode("/ai/models");
    var AIplanes = node_ai.getChildren("aircraft");
    var tankers = node_ai.getChildren("tanker");
    var ships = node_ai.getChildren("ship");
    var carriers = node_ai.getChildren("carrier");
    var vehicles = node_ai.getChildren("groundvehicle");

    if(selection != nil and selection[6].getNode("valid").getValue() == FALSE) {
      selection = nil;
    }

    processTracks(players, FALSE);    
    processTracks(carriers, TRUE);
    processTracks(tankers, FALSE);
    processTracks(ships, FALSE);
    processTracks(AIplanes, FALSE);
    processTracks(vehicles, FALSE);
  }
}


var processTracks = func (vector, carrier) {
  var carrierNear = FALSE;
  foreach (var track; vector) {
    if(track != nil and track.getNode("valid").getValue() == TRUE) {#only the tracks that are valid are sent here
      
      trackInfo = trackItemCalc(track, radarRange, carrier);

      if(trackInfo != nil) {
        
        append(tracks, trackInfo);
        var distance = trackInfo[2];

        # tell the jsbsim hook system that if we are near a carrier
        if(carrier == TRUE and distance < 1000) {
          # is carrier and is within 1 Km range
          carrierNear = TRUE;
        }

        # find and remember the type of the track
        var typeNode = track.getNode("model-shorter");
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
              init: func (listener) {
                funcHash.listenerID = listener;
              },
              call: func {
                if(track.getNode("valid").getValue() == FALSE) {
                  var child = track.removeChild("model-shorter");                    
                  if (child != nil) {#for some reason this can be called two times, even if listener removed, therefore this check.
                    removelistener(listenerID);
                  }
                }
              }
            };
            funcHash.init(setlistener(track.getNode("valid"), func () {funcHash.call()}, 0, 0));
          }
        }


        append(trackInfo, nil);
        
        # figure out what indentification to show in hud
        if(input.callsign.getValue() == 1) {
          if(track.getNode("callsign") != nil and track.getNode("callsign").getValue() != "" and track.getNode("callsign").getValue() != nil) {
            ident = track.getNode("callsign").getValue();
          } elsif (track.getNode("name") != nil and track.getNode("name").getValue() != "" and track.getNode("name").getValue() != nil) {
            #only used by AI
            ident = track.getNode("name").getValue();
          } elsif (track.getNode("sign") != nil and track.getNode("sign").getValue() != "" and track.getNode("sign").getValue() != nil) {
            #only used by AI
            ident = track.getNode("sign").getValue();
          } else {
            ident = "";
          }
        } else {
          if(model != nil) {
            ident = model;
          } elsif (track.getNode("sign") != nil and track.getNode("sign").getValue() != "" and track.getNode("sign").getValue() != nil) {
            #only used by AI
            ident = track.getNode("sign").getValue();  
          } elsif (track.getNode("name") != nil and track.getNode("name").getValue() != "" and track.getNode("name").getValue() != nil) {
            #only used by AI
            ident = track.getNode("name").getValue();
          } elsif (track.getNode("callsign") != nil and track.getNode("callsign").getValue() != "" and track.getNode("callsign").getValue() != nil) {
            ident = track.getNode("callsign").getValue();
          } else {
            ident = "";
          } 
        }

        append(trackInfo, ident);
        append(trackInfo, track);
        append(trackInfo, carrier);

        var unique = track.getChild("unique");
        if (unique == nil) {
          unique = track.addChild("unique");
          unique.setValue(rand());
        }

        if(selection == nil and trackInfo[7] == FALSE) {
          #this is first tracks in radar field, so will be default target
          selection = trackInfo;
          lookatSelection();
          selection_updated = TRUE;
        } elsif (selection != nil and selection[6].getChild("unique").getValue() == unique.getValue() and trackInfo[7] == FALSE) {
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
}#end of trackAI

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
# 2 - distance in meter
# 3 - horizontal angle from aircraft in rad
# 4 - nil
# 5 - identifier
# 6 - node
# 7 - carrier

var trackItemCalc = func (track, range, carrier) {
  var x = track.getNode("position/global-x").getValue();
  var y = track.getNode("position/global-y").getValue();
  var z = track.getNode("position/global-z").getValue();
  var aircraftPos = geo.Coord.new().set_xyz(x, y, z);
  return trackCalc(aircraftPos, range, carrier);
}

var trackCalc = func (aircraftPos, range, carrier) {
  var distance = nil;
  
  call(func distance = self.distance_to(aircraftPos), nil, var err = []);

  if ((size(err))or(distance==nil)) {
    # Oops, have errors. Bogus position data (and distance==nil).
    #print("Received invalid position data: " ~ debug._error(mp.callsign));
    #target_circle[track_index+maxTargetsMP].hide();
    #print(i~" invalid pos.");
  } elsif (distance < range) {#is max radar range of ja37
    # Node with valid position data (and "distance!=nil").
    #distance = distance*kts2kmh*1000;
    var aircraftAlt = aircraftPos.alt(); #altitude in meters
    
    #ground angle
    var yg_rad = math.atan2((aircraftAlt-myAlt), distance)-myPitch; 
    var xg_rad = (self.course_to(aircraftPos)-myHeading)*deg2rads;
    
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
      var hud_pos_x = canvas_HUD.pixelPerDegreeX * xa_rad * rad2deg;
      var hud_pos_y = canvas_HUD.centerOffset + canvas_HUD.pixelPerDegreeY * -ya_rad * rad2deg;
      return [hud_pos_x, hud_pos_y, distance, xa_rad];
    } elsif (carrier == TRUE) {
      # need to return carrier even if out of radar cone, due to carrierNear calc
      return [90000, 90000, distance, xa_rad];
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
loop();