var FALSE = 0;
var TRUE = 1;

var deg2rads = math.pi/180.0;
var rad2deg = 180.0/math.pi;
var kts2kmh = 1.852;
var feet2meter = 0.3048;

var radarRange = getprop("sim/description") == "Saab JA-37 Viggen"?180000:120000;#meter, is estimate. The AJ-37 has 120KM and JA37 is almost 10 years newer, so is reasonable I think.

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

var AIR = 0;
var MARINE = 1;
var SURFACE = 2;
var ORDNANCE = 3;

input = {
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

var findRadarTracks = func () {
  self      =  geo.aircraft_position();
  myPitch   =  input.pitch.getValue()*deg2rads;
  myRoll    =  input.roll.getValue()*deg2rads;
  myAlt     =  self.alt();
  myHeading =  input.hdgReal.getValue();
  
  tracks = [];

  if(input.tracks_enabled.getValue() == TRUE and input.radar_serv.getValue() > FALSE
     and input.voltage.getValue() > 170 and input.hydrPressure.getValue() == TRUE) {

    #do the MP planes
    var players = [];
    foreach(item; multiplayer.model.list) {
      append(players, item.node);
    }
    var AIplanes = input.ai_models.getChildren("aircraft");
    var tankers = input.ai_models.getChildren("tanker");
    var ships = input.ai_models.getChildren("ship");
    var vehicles = input.ai_models.getChildren("groundvehicle");
    var rb24 = input.ai_models.getChildren("rb-24");
    var rb24j = input.ai_models.getChildren("rb-24j");
	  var rb71 = input.ai_models.getChildren("rb-71");
    var rb74 = input.ai_models.getChildren("rb-74");
    var rb99 = input.ai_models.getChildren("rb-99");
    var rb15 = input.ai_models.getChildren("rb-15f");
    var rb04 = input.ai_models.getChildren("rb-04e");
    var rb05 = input.ai_models.getChildren("rb-05a");
    var rb75 = input.ai_models.getChildren("rb-75");
    var m90 = input.ai_models.getChildren("m90");
    var test = input.ai_models.getChildren("test");
    if(selection != nil and selection.isValid() == FALSE) {
      #print("not valid");
      paint(selection.getNode(), FALSE);
      selection = nil;
    }


    processTracks(players, FALSE, FALSE, TRUE);    
    processTracks(tankers, FALSE, FALSE, FALSE, AIR);
    processTracks(ships, FALSE, FALSE, FALSE, MARINE);
#debug.benchmark("radar process AI tracks", func {    
    processTracks(AIplanes, FALSE, FALSE, FALSE, AIR);
#});
    processTracks(vehicles, FALSE, FALSE, FALSE, SURFACE);
    processTracks(rb24, FALSE, TRUE, FALSE, ORDNANCE);
    processTracks(rb24j, FALSE, TRUE, FALSE, ORDNANCE);
	  processTracks(rb71, FALSE, TRUE, FALSE, ORDNANCE);
    processTracks(rb74, FALSE, TRUE, FALSE, ORDNANCE);
    processTracks(rb99, FALSE, TRUE, FALSE, ORDNANCE);
    processTracks(rb15, FALSE, TRUE, FALSE, ORDNANCE);
    processTracks(rb04, FALSE, TRUE, FALSE, ORDNANCE);
    processTracks(rb05, FALSE, TRUE, FALSE, ORDNANCE);
    processTracks(rb75, FALSE, TRUE, FALSE, ORDNANCE);
    processTracks(m90, FALSE, TRUE, FALSE, ORDNANCE);
    processTracks(test, FALSE, TRUE, FALSE, ORDNANCE);
    processCallsigns(players);

  } else {
    # Do not supply target info to the missiles if radar is off.
    if(selection != nil) {
      paint(selection.getNode(), FALSE);
    }
    selection = nil;
  }
  var carriers = input.ai_models.getChildren("carrier");
  processTracks(carriers, TRUE, FALSE, FALSE, MARINE);

  if(selection != nil) {
    #append(selection, "lock");
  }
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


var processTracks = func (vector, carrier, missile = 0, mp = 0, type = -1) {
  var carrierNear = FALSE;
  foreach (var track; vector) {
    if(track != nil and track.getChild("valid") != nil and track.getChild("valid").getValue() == TRUE) {#only the tracks that are valid are sent here
      var trackInfo = nil;
#debug.benchmark("radar trackitemcalc", func {
      if(missile == FALSE) {
        trackInfo = trackItemCalc(track, radarRange, carrier, mp, type);
      } else {
        trackInfo = trackMissileCalc(track, radarRange, carrier, mp, type);
      }
#});
#debug.benchmark("radar process", func {
      if(trackInfo != nil) {
        var distance = trackInfo.get_range()*NM2M;

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

            if (distance < 1000 and (model == "mp-clemenceau" or model == "mp-eisenhower" or model == "mp-nimitz" or model == "mp-vinson")) {
              carrierNear = TRUE;
            }

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

        # tell the jsbsim hook system that if we are near a carrier
        if(carrier == TRUE and distance < 1000) {
          # is carrier and is within 1 Km range
          carrierNear = TRUE;
        }

        var unique = track.getChild("unique");
        if (unique == nil) {
          unique = track.addChild("unique");
          unique.setDoubleValue(rand());
        }

        append(tracks, trackInfo);

        if(selection == nil) {
          #this is first tracks in radar field, so will be default selection
          selection = trackInfo;
          lookatSelection();
          selection_updated = TRUE;
          paint(selection.getNode(), TRUE);
        #} elsif (track.getChild("name") != nil and track.getChild("name").getValue() == "RB-24J") {
          #for testing that selection view follows missiles
        #  selection = trackInfo;
        #  lookatSelection();
        #  selection_updated = TRUE;
        } elsif (selection != nil and selection.getUnique() == unique.getValue()) {
          # this track is already selected, updating it
          #print("updating target");
          selection = trackInfo;
          paint(selection.getNode(), TRUE);
          selection_updated = TRUE;
        } else {
          #print("end2 "~selection.getUnique()~"=="~unique.getValue());
          paint(trackInfo.getNode(), FALSE);
        }
      } else {
        #print("end");
        paint(track, FALSE);
      }
#});      
    }#end of valid check
  }#end of foreach
  if(carrier == TRUE) {
    if(carrierNear != input.carrierNear.getValue()) {
      input.carrierNear.setBoolValue(carrierNear);
    }      
  }
}#end of processTracks

var paint = func (node, painted) {
  if (node == nil) {
    return;
  }
  var attr = node.getChild("painted");
  if (attr == nil) {
    attr = node.addChild("painted");
  }
  attr.setBoolValue(painted);
  #if(painted == TRUE) { 
    #print("painted "~attr.getPath()~" "~painted);
  #}
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

var trackItemCalc = func (track, range, carrier, mp, type) {
  var pos = track.getNode("position");
  var x = pos.getNode("global-x").getValue();
  var y = pos.getNode("global-y").getValue();
  var z = pos.getNode("global-z").getValue();
  if(x == nil or y == nil or z == nil) {
    return nil;
  }
  var aircraftPos = geo.Coord.new().set_xyz(x, y, z);
  var item = trackCalc(aircraftPos, range, carrier, mp, type, track);
  
  return item;
}

var trackMissileCalc = func (track, range, carrier, mp, type) {
  var pos = track.getNode("position");
  var alt = pos.getNode("altitude-ft").getValue();
  var lat = pos.getNode("latitude-deg").getValue();
  var lon = pos.getNode("longitude-deg").getValue();
  if(alt == nil or lat == nil or lon == nil) {
    return nil;
  }
  var aircraftPos = geo.Coord.new().set_latlon(lat, lon, alt*feet2meter);
  return trackCalc(aircraftPos, range, carrier, mp, type, track);
}

var trackCalc = func (aircraftPos, range, carrier, mp, type, node) {
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

    myRoll    =  0;# Ignore roll, since a real radar does that

    #aircraft angle
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

    if(ya_rad > -61.5 * D2R and ya_rad < 61.5 * D2R and xa_rad > -61.5 * D2R and xa_rad < 61.5 * D2R) {
      #is within the radar cone
      # AJ37 manual: 61.5 deg sideways.

      if (mp == TRUE) {
        # is multiplayer
        if (isNotBehindTerrain(aircraftPos) == FALSE) {
          #hidden behind terrain
          return nil;
        }
        if (doppler(aircraftPos, node) == TRUE) {
          # doppler picks it up, must be an aircraft
          type = AIR;
        } elsif (aircraftAlt > 1) {
          # doppler does not see it, and is not on sea, must be ground target
          type = SURFACE;
        } else {
          type = MARINE;
        }
      }

      var distanceRadar = distance/math.cos(myPitch);
      var hud_pos_x = canvas_HUD.pixelPerDegreeX * xa_rad * rad2deg;
      var hud_pos_y = canvas_HUD.centerOffset + canvas_HUD.pixelPerDegreeY * -ya_rad * rad2deg;

      var contact = Contact.new(node, type);
      contact.setPolar(distanceRadar, xa_rad);
      contact.setCartesian(hud_pos_x, hud_pos_y);
      return contact;

    } elsif (carrier == TRUE) {
      # need to return carrier even if out of radar cone, due to carrierNear calc
      var contact = Contact.new(node, type);
      contact.setPolar(900000, xa_rad);
      contact.setCartesian(900000, 900000);# 900000 used in hud to know if out of radar cone.
      return contact;
    }
  }
  return nil;
}

#
# The following 6 methods is from Mirage 2000-5
#
var isNotBehindTerrain = func(SelectCoord) {
    var isVisible = 0;
    var MyCoord = geo.aircraft_position();
    
    # Because there is no terrain on earth that can be between these 2
    if(MyCoord.alt() < 8900 and SelectCoord.alt() < 8900 and input.lookThrough.getValue() == FALSE)
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
        var L = 500;
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
                    # This will prevent the rest of the loop to run if a masking high point is found:
                    return 0;
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

    if (input.dopplerOn.getValue() == FALSE or 
        (t_node.getNode("velocities/true-airspeed-kt") != nil and t_node.getNode("velocities/true-airspeed-kt").getValue() != nil and t_node.getNode("velocities/true-airspeed-kt").getValue() > 250)
        ) {
      return TRUE;
    }

    var DopplerSpeedLimit = input.dopplerSpeed.getValue();
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
    # fix later: Nasal runtime error: floating point error in math.asin() when logged in as observer:
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

    if(t_node.getNode("orientation/true-heading-deg") == nil) {
      return 0;
    }

    # First step : find the target heading.
    var myHeading = t_node.getNode("orientation/true-heading-deg").getValue();
    
    # Second What would be the aircraft heading to go to us
    var myCoord = t_coord;
    var projectionHeading = myCoord.course_to(MyAircraftCoord);
    
    if (myHeading == nil or projectionHeading == nil) {
      return 0;
    }

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
    paint(selection.getNode(), TRUE);
    lookatSelection();
  } else {
    tracks_index = -1;
    if (selection != nil) {
      paint(selection.getNode(), FALSE);
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
    selection = centerMost;
    paint(selection.getNode(), TRUE);
    lookatSelection();
    tracks_index = centerIndex;
  }
}

var lookatSelection = func () {
  props.globals.getNode("/ja37/radar/selection-heading-deg", 1).unalias();
  props.globals.getNode("/ja37/radar/selection-pitch-deg", 1).unalias();
  props.globals.getNode("/ja37/radar/selection-heading-deg", 1).alias(selection.getNode().getNode("radar/bearing-deg"));
  props.globals.getNode("/ja37/radar/selection-pitch-deg", 1).alias(selection.getNode().getNode("radar/elevation-deg"));
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
  if(getprop("ja37/supported/radar") == TRUE) {
    loop();
  }
}

var getCallsign = func (callsign) {
  var node = callsign_struct[callsign];
  return node;
}

var lsnr = setlistener("ja37/supported/initialized", starter);



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
#});
#debug.benchmark("radar process3", func {
        #As it is a geo.Coord object, we have to update lat/lon/alt ->and alt is in meters
        obj.coord = geo.Coord.new();
        obj.coord.set_latlon(obj.lat.getValue(), obj.lon.getValue(), obj.alt.getValue() * FT2M);
#});
#debug.benchmark("radar process4", func {
        obj.pitch           = obj.oriProp.getNode("pitch-deg");
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
#});
#debug.benchmark("radar process5", func {        
        #obj.transponderID   = c.getNode("instrumentation/transponder/transmitted-id");
#});
#debug.benchmark("radar process6", func {                
        obj.acType          = c.getNode("sim/model/ac-type");
        obj.type            = c.getName();
        obj.index           = c.getIndex();
        obj.string          = "ai/models/" ~ obj.type ~ "[" ~ obj.index ~ "]";
        obj.shortString     = obj.type ~ "[" ~ obj.index ~ "]";
#});
#debug.benchmark("radar process7", func {
        obj.range           = obj.rdrProp.getNode("range-nm");
        obj.bearing         = obj.rdrProp.getNode("bearing-deg");
        obj.elevation       = obj.rdrProp.getNode("elevation-deg");
#});        
        obj.deviation       = nil;

        obj.node            = c;
        obj.class           = class;

        obj.polar           = [0,0];
        obj.cartesian       = [0,0];
        
        return obj;
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
        var e = 0;
        e = me.elevation.getValue();
        if(e == nil or e == 0) {
            # AI/MP has no radar properties
            var self = geo.aircraft_position();
            me.get_Coord();
            var angleInv = ja37.clamp(self.distance_to(me.coord)/self.direct_distance_to(me.coord), -1, 1);
            e = (self.alt()>me.coord.alt()?-1:1)*math.acos(angleInv)*R2D;
        }
        return e;
    },

    getNode: func () {
      return me.node;
    },

    getFlareNode: func () {
      return me.node.getNode("sim/multiplay/generic/string[10]");
    },

    setPolar: func(dist, angle) {
      me.polar = [dist,angle];
    },

    setCartesian: func(x, y) {
      me.cartesian = [x,y];
    },

    remove: func(){
        if(me.validTree != 0){
          me.validTree.setBoolValue(0);
        }
    },

    get_Coord: func(){
        me.coord.set_latlon(me.lat.getValue(), me.lon.getValue(), me.alt.getValue() * FT2M);
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
        me.get_Coord();
        var value = (me.coord.alt() - MyAircraftCoord.alt()) / me.coord.direct_distance_to(MyAircraftCoord);
        if (math.abs(value) > 1) {
          # warning this else will fail if logged in as observer and see aircraft on other side of globe
          return 0;
        }
        var myPitch = math.asin(value) * R2D;
        return myPitch;
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
      return me.cartesian;
    },

    get_polar: func() {
      return me.polar;
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

  isPainted: func () {
    return TRUE;
  },

  getUnique: func () {
    return me.unique;
  },

  getElevation: func() {
      var e = 0;
      var self = geo.aircraft_position();
      var angleInv = ja37.clamp(self.distance_to(me.coord)/self.direct_distance_to(me.coord), -1, 1);
      e = (self.alt()>me.coord.alt()?-1:1)*math.acos(angleInv)*R2D;
      return e;
  },

  getNode: func () {
    return nil;
  },

  getFlareNode: func () {
    return "";
  },

  remove: func(){
      
  },

  get_Coord: func(){
      return me.coord;
  },

  get_Callsign: func(){
      return me.callsign;
  },

  get_model: func(){
      return "GPS Target";
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

  get_deviation: func(true_heading_ref, coord){
      me.deviation =  - deviation_normdeg(true_heading_ref, me.get_bearing_from_Coord(coord));
      return me.deviation;
  },

  get_altitude: func(){
      #Return Alt in feet
      return me.coord.alt()*M2FT;
  },

  get_Elevation_from_Coord: func(MyAircraftCoord) {
      var value = (me.coord.alt() - MyAircraftCoord.alt()) / me.coord.direct_distance_to(MyAircraftCoord);
      if (math.abs(value) > 1) {
        # warning this else will fail if logged in as observer and see aircraft on other side of globe
        return 0;
      }
      var myPitch = math.asin(value) * R2D;
      return myPitch;
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

  get_cartesian: func() {

    var gpsAlt = me.coord.alt();

    var self      =  geo.aircraft_position();
    var myPitch   =  input.pitch.getValue()*deg2rads;
    var myRoll    =  input.roll.getValue()*deg2rads;
    var myAlt     =  self.alt();
    var myHeading =  input.hdgReal.getValue();
    var distance  =  self.distance_to(me.coord);

    var yg_rad = math.atan2(gpsAlt-myAlt, distance) - myPitch; 
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

    var aircraftAlt = me.coord.alt();

    var self      =  geo.aircraft_position();
    var myPitch   =  input.pitch.getValue()*deg2rads;
    var myRoll    =  0;#input.roll.getValue()*deg2rads;  Ignore roll, since a real radar does that
    var myAlt     =  self.alt();
    var myHeading =  input.hdgReal.getValue();
    var distance  =  self.distance_to(me.coord);

    var yg_rad = math.atan2(aircraftAlt-myAlt, distance) - myPitch; 
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

    var distanceRadar = distance/math.cos(myPitch);

    return [distanceRadar, xa_rad];
  },
}

