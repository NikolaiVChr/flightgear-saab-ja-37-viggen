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
	  var rb71 = node_ai.getChildren("rb-71");
    var rb74 = node_ai.getChildren("rb-74");

    if(selection != nil and selection[6].getNode("valid").getValue() == FALSE) {
      paint(selection[6], FALSE);
      selection = nil;
    }

    processTracks(players, FALSE, FALSE, TRUE);    
    processTracks(tankers, FALSE);
    processTracks(ships, FALSE);
    processTracks(AIplanes, FALSE);
    processTracks(vehicles, FALSE);
    processTracks(rb24, FALSE, TRUE);
	  processTracks(rb71, FALSE, TRUE);
    processTracks(rb74, FALSE, TRUE);
    processCallsigns(players);
  } else {
    # Do not supply target info to the missiles if radar is off.
    if(selection != nil) {
      paint(selection[6], FALSE);
    }
    selection = nil;
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


var processTracks = func (vector, carrier, missile = FALSE, mp = FALSE) {
  var carrierNear = FALSE;
  foreach (var track; vector) {
    if(track != nil and track.getChild("valid") != nil and track.getChild("valid").getValue() == TRUE) {#only the tracks that are valid are sent here
      var trackInfo = nil;
      
      if(missile == FALSE) {
        trackInfo = trackItemCalc(track, radarRange, carrier, mp);
      } else {
        trackInfo = trackMissileCalc(track, radarRange, carrier, mp);
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
          paint(selection[6], TRUE);
        #} elsif (track.getChild("name") != nil and track.getChild("name").getValue() == "RB-24J") {
          #for testing that selection view follows missiles
        #  selection = trackInfo;
        #  lookatSelection();
        #  selection_updated = TRUE;
        } elsif (selection != nil and selection[6].getChild("unique").getValue() == unique.getValue()) {
          # this track is already selected, updating it
          selection = trackInfo;
          paint(selection[6], TRUE);
          selection_updated = TRUE;
        } else {
          paint(trackInfo[6], FALSE);
        }
      } else {
        paint(track, FALSE);
      }
    }#end of valid check
  }#end of foreach
  if(carrier == TRUE) {
    if(carrierNear != input.carrierNear.getValue()) {
      input.carrierNear.setValue(carrierNear);
    }      
  }
}#end of processTracks

var paint = func (node, painted) {
  var attr = node.getChild("painted");
  if (attr == nil) {
    attr = node.addChild("painted");
  }
  attr.setValue(painted);
  #if(painted == TRUE) { print("painted something"); }
}

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

var trackItemCalc = func (track, range, carrier, mp) {
  var x = track.getNode("position/global-x").getValue();
  var y = track.getNode("position/global-y").getValue();
  var z = track.getNode("position/global-z").getValue();
  var aircraftPos = geo.Coord.new().set_xyz(x, y, z);
  if (mp == FALSE or doppler(aircraftPos, track) == TRUE) {
    return trackCalc(aircraftPos, range, carrier, mp);
  }
  return nil;
}

var trackMissileCalc = func (track, range, carrier, mp) {
  var alt = track.getNode("position/altitude-ft").getValue();
  var lat = track.getNode("position/latitude-deg").getValue();
  var lon = track.getNode("position/longitude-deg").getValue();
  if(alt == nil or lat == nil or lon == nil) {
    return nil;
  }
  var aircraftPos = geo.Coord.new().set_latlon(lat, lon, alt*feet2meter);
  return trackCalc(aircraftPos, range, carrier, mp);
}

var trackCalc = func (aircraftPos, range, carrier, mp) {
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

    if(ya_rad > -1 and ya_rad < 1 and xa_rad > -1 and xa_rad < 1 and (mp == FALSE or isNotBehindTerrain(aircraftPos) == TRUE)) {
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

#
# The following 3 methods is from Mirage 2000-5
#
var isNotBehindTerrain = func(SelectCoord) {
    var isVisible = 0;
    var MyCoord = geo.aircraft_position();
    
    # Because there is no terrain on earth that can be between these 2
    if(MyCoord.alt() < 8900 and SelectCoord.alt() < 8900 and getprop("sim/ja37/radar/look-through-terrain") == FALSE)
    {
        # Temporary variable
        # A (our plane) coord in meters
        var a = MyCoord.x();
        var b = MyCoord.y();
        var c = MyCoord.z();
        # B (target) coord in meters
        var d = SelectCoord.x();
        var e = SelectCoord.y();
        var f = SelectCoord.z();
        var x = 0;
        var y = 0;
        var z = 0;
        var RecalculatedL = 0;
        var difa = d - a;
        var difb = e - b;
        var difc = f - c;
        # direct Distance in meters
        var myDistance = SelectCoord.direct_distance_to(MyCoord);
        var Aprime = geo.Coord.new();
        
        # Here is to limit FPS drop on very long distance
        var L = 1000;
        if(myDistance > 50000)
        {
            L = myDistance / 15;
        }
        var step = L;
        var maxLoops = int(myDistance / L);
        
        isVisible = 1;
        # This loop will make travel a point between us and the target and check if there is terrain
        for(var i = 0 ; i < maxLoops ; i += 1)
        {
            L = i * step;
            var K = (L * L) / (1 + (-1 / difa) * (-1 / difa) * (difb * difb + difc * difc));
            var DELTA = (-2 * a) * (-2 * a) - 4 * (a * a - K);
            
            if(DELTA >= 0)
            {
                # So 2 solutions or 0 (1 if DELTA = 0 but that 's just 2 solution in 1)
                var x1 = (-(-2 * a) + math.sqrt(DELTA)) / 2;
                var x2 = (-(-2 * a) - math.sqrt(DELTA)) / 2;
                # So 2 y points here
                var y1 = b + (x1 - a) * (difb) / (difa);
                var y2 = b + (x2 - a) * (difb) / (difa);
                # So 2 z points here
                var z1 = c + (x1 - a) * (difc) / (difa);
                var z2 = c + (x2 - a) * (difc) / (difa);
                # Creation Of 2 points
                var Aprime1  = geo.Coord.new();
                Aprime1.set_xyz(x1, y1, z1);
                
                var Aprime2  = geo.Coord.new();
                Aprime2.set_xyz(x2, y2, z2);
                
                # Here is where we choose the good
                if(math.round((myDistance - L), 2) == math.round(Aprime1.direct_distance_to(SelectCoord), 2))
                {
                    Aprime.set_xyz(x1, y1, z1);
                }
                else
                {
                    Aprime.set_xyz(x2, y2, z2);
                }
                var AprimeLat = Aprime.lat();
                var Aprimelon = Aprime.lon();
                var AprimeTerrainAlt = geo.elevation(AprimeLat, Aprimelon);
                if(AprimeTerrainAlt == nil)
                {
                    AprimeTerrainAlt = 0;
                }
                
                if(AprimeTerrainAlt > Aprime.alt())
                {
                    isVisible = 0;
                }
            }
        }
    }
    else
    {
        isVisible = 1;
    }
    return isVisible;
}

# will return true if absolute closure speed of target is greater than 50kt
#
var doppler = func(t_coord, t_node) {
    # Test to check if the target can hide below us
    # Or Hide using anti doppler movements

    if (getprop("sim/ja37/radar/doppler-enabled") == FALSE) {
      return TRUE;
    }

    var DopplerSpeedLimit = getprop("sim/ja37/radar/min-doppler-speed-kt");
    var InDoppler = 0;
    var groundNotbehind = isGroundNotBehind(t_coord, t_node);

    if(groundNotbehind)
    {
        InDoppler = 1;
    } elsif(abs(get_closure_rate_from_Coord(t_coord, t_node)) > DopplerSpeedLimit)
    {
        InDoppler = 1;
    }
    return InDoppler;
}

var isGroundNotBehind = func(t_coord, t_node){
    var myPitch = get_Elevation_from_Coord(t_coord);
    var GroundNotBehind = 1; # sky is behind the target (this don't work on a valley)
    if(myPitch < 0)
    {
        # the aircraft is below us, the ground could be below
        # Based on earth curve. Do not work with mountains
        # The script will calculate what is the ground distance for the line (us-target) to reach the ground,
        # If the earth was flat. Then the script will compare this distance to the horizon distance
        # If our distance is greater than horizon, then sky behind
        # If not, we cannot see the target unless we have a doppler radar
        var distHorizon = geo.aircraft_position().alt() / math.tan(abs(myPitch * D2R)) * M2NM;
        var horizon = get_horizon( geo.aircraft_position().alt() *M2FT, t_node);
        var TempBool = (distHorizon > horizon);
        GroundNotBehind = (distHorizon > horizon);
    }
    return GroundNotBehind;
}

var get_Elevation_from_Coord = func(t_coord) {
    var myPitch = math.asin((t_coord.alt() - geo.aircraft_position().alt()) / t_coord.direct_distance_to(geo.aircraft_position())) * R2D;
    return myPitch;
}

var get_horizon = func(own_alt, t_node){
    var tgt_alt = t_node.getNode("position/altitude-ft").getValue();
    if(debug.isnan(tgt_alt))
    {
        return(0);
    }
    if(tgt_alt < 0 or tgt_alt == nil)
    {
        tgt_alt = 0;
    }
    if(own_alt < 0 or own_alt == nil)
    {
        own_alt = 0;
    }
    # Return the Horizon in NM
    return (2.2 * ( math.sqrt(own_alt * FT2M) + math.sqrt(tgt_alt * FT2M)));# don't understand the 2.2 conversion to NM here..
}

var get_closure_rate_from_Coord = func(t_coord, t_node) {
    var MyAircraftCoord = geo.aircraft_position();

    # First step : find the target heading.
    var myHeading = t_node.getNode("orientation/true-heading-deg").getValue();
    
    # Second What would be the aircraft heading to go to us
    var myCoord = t_coord;
    var projectionHeading = myCoord.course_to(MyAircraftCoord);
    
    # Calculate the angle difference
    var myAngle = myHeading - projectionHeading; #Should work even with negative values
    
    # take the "ground speed"
    # velocities/true-air-speed-kt
    var mySpeed = t_node.getNode("velocities/true-airspeed-kt").getValue();
    var myProjetedHorizontalSpeed = mySpeed*math.cos(myAngle*D2R); #in KTS
    
    #print("Projetted Horizontal Speed:"~ myProjetedHorizontalSpeed);
    
    # Now getting the pitch deviation
    var myPitchToAircraft = - t_node.getNode("radar/elevation-deg").getValue();
    #print("My pitch to Aircraft:"~myPitchToAircraft);
    
    # Get V speed
    if(t_node.getNode("velocities/vertical-speed-fps").getValue() == nil)
    {
        return 0;
    }
    var myVspeed = t_node.getNode("velocities/vertical-speed-fps").getValue()*FPS2KT;
    # This speed is absolutely vertical. So need to remove pi/2
    
    var myProjetedVerticalSpeed = myVspeed * math.cos(myPitchToAircraft-90*D2R);
    
    # Control Print
    #print("myVspeed = " ~myVspeed);
    #print("Total Closure Rate:" ~ (myProjetedHorizontalSpeed+myProjetedVerticalSpeed));
    
    # Total Calculation
    var cr = myProjetedHorizontalSpeed+myProjetedVerticalSpeed;
    
    # Setting Essential properties
    #var rng = me. get_range_from_Coord(MyAircraftCoord);
    #var newTime= ElapsedSec.getValue();
    #if(me.get_Validity())
    #{
    #    setprop(me.InstrString ~ "/" ~ me.shortstring ~ "/closure-last-range-nm", rng);
    #    setprop(me.InstrString ~ "/" ~ me.shortstring ~ "/closure-rate-kts", cr);
    #}
    
    return cr;
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
    paint(selection[6], TRUE);
    lookatSelection();
  } else {
    tracks_index = -1;
    if (selection != nil) {
      paint(selection[6], FALSE);
    }
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
    paint(selection[6], TRUE);
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