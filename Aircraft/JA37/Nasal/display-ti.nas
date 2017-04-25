# todo:
# servicable, indicated
# power supply, on off, brightness (emmision)
# buttons functions
# geo grid
# radar echoes types
# runway proper styles
# bottom text
# buttons text
# steerpoint symbols: # ?
# ground symbol, ground arrow, horizont, FPI in some modes
# full OOP
# use Pinto's model
var (width,height) = (341,512);

var window = canvas.Window.new([width, height],"dialog")
					.set('x', width*2.75)
                   .set('title', "TI display");
var root = window.getCanvas(1).createGroup();
root.set("font", "LiberationFonts/LiberationMono-Regular.ttf");
window.getCanvas(1).setColorBackground(0, 0, 0, 1.0);

var (center_x, center_y) = (width/2,height/2);

var MM2TEX = 1;

# map setup

var tile_size = 256;
var zoom = 9;
var type = "sat";

# index   = zoom level
# content = meter per pixel of tiles
#                   0                             5                               10                               15                      19
meterPerPixel = [156412,78206,39103,19551,9776,4888,2444,1222,610.984,305.492,152.746,76.373,38.187,19.093,9.547,4.773,2.387,1.193,0.596,0.298];
zooms = [4, 7, 9, 11, 13];
zoom_curr = 2;

var M2TEX = 1/meterPerPixel[zoom];

var changeZoom = func() {
  zoom_curr += 1;
  if (zoom_curr > 4) {
  	zoom_curr = 0;
  }
  zoom = zooms[zoom_curr];
  M2TEX = 1/(meterPerPixel[zoom]*math.cos(getprop('/position/latitude-deg')*D2R));
}

var maps_base = getprop("/sim/fg-home") ~ '/cache/mapsTI';

# max zoom 18
# light_all,
# dark_all,
# light_nolabels,
# light_only_labels,
# dark_nolabels,
# dark_only_labels

var makeUrl =
  string.compileTemplate('http://cartodb-basemaps-c.global.ssl.fastly.net/dark_nolabels/{z}/{x}/{y}.png');#http://otile2.mqcdn.com/tiles/1.0.0/{type}/{z}/{x}/{y}.jpg'
var makePath =
  string.compileTemplate(maps_base ~ '/carto/{z}/{x}/{y}.png');#/osm-{type}/{z}/{x}/{y}.jpg
var num_tiles = [3, 3];#figure this out

var center_tile_offset = [(num_tiles[0] - 1) / 2,(num_tiles[1] - 1) / 2];#(width/tile_size)/2,(height/tile_size)/2];
#  (num_tiles[0] - 1) / 2,
#  (num_tiles[1] - 1) / 2
#];

##
# initialize the map by setting up
# a grid of raster images  

var tiles = setsize([], num_tiles[0]);


var last_tile = [-1,-1];
var last_type = type;

# stuff

#TI symbol colors
var rWhite = 1.0; # other / self / own_missile
var gWhite = 1.0;
var bWhite = 1.0;

var rYellow = 1.0;# possible threat
var gYellow = 1.0;
var bYellow = 0.0;

var rRed = 1.0;   # threat
var gRed = 0.0;
var bRed = 0.0;

var rGreen = 0.0; # own side
var gGreen = 1.0;
var bGreen = 0.0;

var rTyrk = 0.25; # navigation aid
var gTyrk = 0.88;
var bTyrk = 0.81;

var a = 1.0;#alpha
var w = 1.0;#stroke width

var fpi_min = 3;
var fpi_med = 6;
var fpi_max = 9;

var maxTracks   = 32;# how many radar tracks can be shown at once in the TI (was 16)
var maxMissiles = 6;
var maxThreats  = 5;

var roundabout = func(x) {
  var y = x - int(x);
  return y < 0.5 ? int(x) : 1 + int(x) ;
};

var clamp = func(v, min, max) { v < min ? min : v > max ? max : v };

var FALSE = 0;
var TRUE = 1;

var TI = {

	new: func {
	  	var ti = { parents: [TI] };
	  	ti.input = {
			alt_ft:               "instrumentation/altimeter/indicated-altitude-ft",
			APLockAlt:            "autopilot/locks/altitude",
			APTgtAgl:             "autopilot/settings/target-agl-ft",
			APTgtAlt:             "autopilot/settings/target-altitude-ft",
			heading:              "instrumentation/heading-indicator/indicated-heading-deg",
			hydrPressure:         "fdm/jsbsim/systems/hydraulics/system1/pressure",
			rad_alt:              "position/altitude-agl-ft",
			radarEnabled:         "ja37/hud/tracks-enabled",
			radarRange:           "instrumentation/radar/range",
			radarScreenVoltage:   "systems/electrical/outputs/dc-voltage",
			radarServ:            "instrumentation/radar/serviceable",
			radarVoltage:         "systems/electrical/outputs/ac-main-voltage",
			rmActive:             "autopilot/route-manager/active",
			rmDist:               "autopilot/route-manager/wp/dist",
			rmId:                 "autopilot/route-manager/wp/id",
			rmTrueBearing:        "autopilot/route-manager/wp/true-bearing-deg",
			RMCurrWaypoint:       "autopilot/route-manager/current-wp",
			roll:                 "instrumentation/attitude-indicator/indicated-roll-deg",
			screenEnabled:        "ja37/radar/enabled",
			timeElapsed:          "sim/time/elapsed-sec",
			viewNumber:           "sim/current-view/view-number",
			headTrue:             "orientation/heading-deg",
			headMagn:             "orientation/heading-magnetic-deg",
			twoHz:                "ja37/blink/two-Hz/state",
			station:          	  "controls/armament/station-select",
			roll:             	  "orientation/roll-deg",
			units:                "ja37/hud/units-metric",
			callsign:             "ja37/hud/callsign",
			hdgReal:              "orientation/heading-deg",
			tracks_enabled:   	  "ja37/hud/tracks-enabled",
			radar_serv:       	  "instrumentation/radar/serviceable",
			tenHz:            	  "ja37/blink/ten-Hz/state",
			qfeActive:        	  "ja37/displays/qfe-active",
	        qfeShown:		  	  "ja37/displays/qfe-shown",
	        station:          	  "controls/armament/station-select",
	        currentMode:          "ja37/hud/current-mode",
	        ctrlRadar:        "controls/altimeter-radar",
      	};
   
      	foreach(var name; keys(ti.input)) {
        	ti.input[name] = props.globals.getNode(ti.input[name], 1);
      	}

      	ti.setupCanvasSymbols();
      	ti.setupMap();

      	return ti;
	},

	setupCanvasSymbols: func {
		me.mapCentrum = root.createChild("group")
			.set("z-index", 1)
			.setTranslation(width/2,height*2/3);
		me.mapCenter = me.mapCentrum.createChild("group");
		me.mapRot = me.mapCenter.createTransform();
		me.mapFinal = me.mapCenter.createChild("group");
		me.mapFinal.setTranslation(-tile_size*center_tile_offset[0],-tile_size*center_tile_offset[1]);

		me.rootCenter = root.createChild("group")
			.setTranslation(width/2,height*2/3)
			.set("z-index", 10);
		me.selfSymbol = me.rootCenter.createChild("path")
		      .moveTo(-5*MM2TEX,  5*MM2TEX)
		      .lineTo( 0,       -10*MM2TEX)
		      .moveTo( 5*MM2TEX,  5*MM2TEX)
		      .lineTo( 0,       -10*MM2TEX)
		      .moveTo(-5*MM2TEX,  5*MM2TEX)
		      .lineTo( 5*MM2TEX,  5*MM2TEX)
		      .setColor(rWhite,gWhite,bWhite, a)
		      .setStrokeLineWidth(w);
		me.selfVectorG = me.rootCenter.createChild("group")
			.setTranslation(0,-10*MM2TEX);
		me.selfVector = me.selfVectorG.createChild("path")
			  .moveTo(0,  0)
			  .lineTo(0, -1*MM2TEX)
			  .setColor(rWhite,gWhite,bWhite, a)
		      .setStrokeLineWidth(w);

		me.radar_group = me.rootCenter.createChild("group");
		me.echoesAircraft = [];
		me.echoesAircraftVector = [];
		for (var i = 0; i < maxTracks; i += 1) {
			var grp = me.radar_group.createChild("group")
				.set("z-index", maxTracks-i);
			var grp2 = grp.createChild("group")
				.setTranslation(0,-10*MM2TEX);
			var vector = grp2.createChild("path")
			  .moveTo(0,  0)
			  .lineTo(0, -1*MM2TEX)
			  .setColor(i!=0?rYellow:rRed,i!=0?gYellow:gRed,i!=0?bYellow:bRed, a)
		      .setStrokeLineWidth(w);
			grp.createChild("path")
		      .moveTo(-5*MM2TEX,  5*MM2TEX)
		      .lineTo( 0,       -10*MM2TEX)
		      .moveTo( 5*MM2TEX,  5*MM2TEX)
		      .lineTo( 0,       -10*MM2TEX)
		      .moveTo(-5*MM2TEX,  5*MM2TEX)
		      .lineTo( 5*MM2TEX,  5*MM2TEX)
		      .setColor(i!=0?rYellow:rRed,i!=0?gYellow:gRed,i!=0?bYellow:bRed, a)
		      .setStrokeLineWidth(w);
		    append(me.echoesAircraft, grp);
		    append(me.echoesAircraftVector, vector);
		}

	    me.dest = me.rootCenter.createChild("group")
            .hide()
            .set("z-index", 5);
	    me.dest_runway = me.dest.createChild("path")
	               .moveTo(0, 0)
	               .lineTo(0, -1)
	               .setStrokeLineWidth(w)
	               .setColor(rTyrk,gTyrk,bTyrk, a)
	               .hide();
	    me.dest_circle = me.dest.createChild("path")
	               .moveTo(-25, 0)
	               .arcSmallCW(25, 25, 0, 50, 0)
	               .arcSmallCW(25, 25, 0, -50, 0)
	               .setStrokeLineWidth(w)
	               .setColor(rTyrk,gTyrk,bTyrk, a);
	    me.approach_circle = me.rootCenter.createChild("path")
	               .moveTo(-100, 0)
	               .arcSmallCW(100, 100, 0, 200, 0)
	               .arcSmallCW(100, 100, 0, -200, 0)
	               .setStrokeLineWidth(w)
	               .setColor(rTyrk,gTyrk,bTyrk, a);

	    me.threats = [];
	    for (var i = 0; i < maxThreats; i += 1) {
	    	append(me.threats, me.radar_group.createChild("path")
	               .moveTo(-100, 0)
	               .arcSmallCW(100, 100, 0, 200, 0)
	               .arcSmallCW(100, 100, 0, -200, 0)
	               .setStrokeLineWidth(w)
	               .setColor(rRed,gRed,bRed, a));
	    }

	    me.missiles = [];
	    me.missilesVector = [];
	    for (var i = 0; i < maxMissiles; i += 1) {
	    	var grp = me.radar_group.createChild("group")
				.set("z-index", maxTracks-i);
			var grp2 = grp.createChild("group")
				.setTranslation(0,-10*MM2TEX);
			var vector = grp2.createChild("path")
			  .moveTo(0,  0)
			  .lineTo(0, -1*MM2TEX)
			  .setColor(rWhite,gWhite,bWhite, a)
		      .setStrokeLineWidth(w);
			grp.createChild("path")
		      .moveTo(-2.5*MM2TEX,  5*MM2TEX)
		      .lineTo(   0,       -10*MM2TEX)
		      .moveTo( 2.5*MM2TEX,  5*MM2TEX)
		      .lineTo(   0,       -10*MM2TEX)
		      .moveTo(-2.5*MM2TEX,  5*MM2TEX)
		      .lineTo( 2.5*MM2TEX,  5*MM2TEX)
		      .setColor(rWhite,gWhite,bWhite, a)
		      .setStrokeLineWidth(w);
		    append(me.missiles, grp);
		    append(me.missilesVector, vector);
	    }

	    me.gpsSymbol = me.radar_group.createChild("path")
		      .moveTo(-5*MM2TEX, 10*MM2TEX)
		      .vert(            -20*MM2TEX)
		      .moveTo( 5*MM2TEX, 10*MM2TEX)
		      .vert(            -20*MM2TEX)
		      .moveTo(-10*MM2TEX, 5*MM2TEX)
		      .horiz(            20*MM2TEX)
		      .moveTo(-10*MM2TEX,-5*MM2TEX)
		      .horiz(            20*MM2TEX)
		      .setColor(rTyrk,gTyrk,bTyrk, a)
		      .setStrokeLineWidth(w);
	},

	loop: func {
		me.interoperability = me.input.units.getValue();

		me.updateMap();
		me.showSelfVector();
		me.displayRadarTracks();
		me.showRunway();

		settimer(func me.loop(), 0.5);
	},

	showRunway: func {
		if (land.show_waypoint_circle == TRUE or land.show_runway_line == TRUE) {
		  me.x = math.cos(-(land.runway_bug-90) * D2R) * land.runway_dist*NM2M*M2TEX;
		  me.y = math.sin(-(land.runway_bug-90) * D2R) * land.runway_dist*NM2M*M2TEX;

		  me.dest.setTranslation(me.x, -me.y);		  

		  if (land.show_waypoint_circle == TRUE) {
		  	  #me.scale = clamp(2000*M2TEX/100, 25/100, 50);
		      #me.dest_circle.setStrokeLineWidth(w/me.scale);
		      #me.dest_circle.setScale(me.scale);
		      me.dest_circle.show();
		  } else {
		      me.dest_circle.hide();
		  }

		  if (land.show_runway_line == TRUE) {
		    # 10 20 20 40 Km long line, depending on radar setting, as per AJ manual.
		    me.runway_l = land.line*1000;
		#        if (me.radarRange == 120000 or me.radarRange == 180000) {
		#          me.runway_l = 40000;
		#        } elsif (me.radarRange == 60000) {
		#          me.runway_l = 20000;
		#        } elsif (me.radarRange == 30000) {
		#          me.runway_l = 20000;
		#        }
		    me.scale = me.runway_l*M2TEX;
		    me.dest_runway.setScale(1, me.scale);
		    me.heading = me.input.heading.getValue();#true
		    me.dest.setRotation((180+land.head-me.heading)*D2R);
		    me.dest_runway.show();
		    if (land.show_approach_circle == TRUE) {
		      me.scale = 4100*M2TEX/100;
		      me.approach_circle.setStrokeLineWidth(w/me.scale);
		      me.approach_circle.setScale(me.scale);
		      me.acir = radar_logic.ContactGPS.new("circle", land.approach_circle);
		      me.distance = me.acir.get_polar()[0];
		      me.xa_rad   = me.acir.get_polar()[1];
		      me.pixelDistance = -me.distance*M2TEX; #distance in pixels
		      #translate from polar coords to cartesian coords
		      me.pixelX =  me.pixelDistance * math.cos(me.xa_rad + math.pi/2);
		      me.pixelY =  me.pixelDistance * math.sin(me.xa_rad + math.pi/2);
		      me.approach_circle.setTranslation(me.pixelX, me.pixelY);
		      me.approach_circle.show();
		    } else {
		      me.approach_circle.hide();#pitch.......1x.......................................................
		    }            
		  } else {
		    me.dest_runway.hide();
		    me.approach_circle.hide();
		  }
		  me.dest.show();
		} else {
		me.dest_circle.hide();
		me.dest_runway.hide();
		me.approach_circle.hide();
		}
	},

	displayRadarTracks: func () {

	  	var mode = canvas_HUD.mode;
		me.threatIndex = -1;
		me.missileIndex = -1;
	    me.track_index = 1;
	    me.isGPS = FALSE;
	    me.selection_updated = FALSE;
	    me.tgt_dist = 1000000;
	    me.tgt_callsign = "";

	    if(me.input.tracks_enabled.getValue() == 1 and me.input.radar_serv.getValue() > 0) {
			me.radar_group.show();

			me.selection = radar_logic.selection;

			if (me.selection != nil and me.selection.parents[0] == radar_logic.ContactGPS) {
		        me.displayRadarTrack(me.selection);
		    }

			# do yellow triangles here
			foreach(hud_pos; radar_logic.tracks) {
				me.displayRadarTrack(hud_pos);
			}
			if(me.track_index != -1) {
				#hide the the rest unused echoes
				for(var i = me.track_index; i < maxTracks ; i+=1) {
			  		me.echoesAircraft[i].hide();
				}
			}
			if(me.threatIndex < maxThreats-1) {
				#hide the the rest unused threats
				for(var i = me.threatIndex; i < maxThreats-1 ; i+=1) {
			  		me.threats[i+1].hide();
				}
			}
			if(me.missileIndex < maxMissiles-1) {
				#hide the the rest unused missiles
				for(var i = me.missileIndex; i < maxMissiles-1 ; i+=1) {
			  		me.missiles[i+1].hide();
				}
			}
			if(me.selection_updated == FALSE) {
				me.echoesAircraft[0].hide();
			}
			if (me.isGPS == FALSE) {
				me.gpsSymbol.hide();
		    }
	    } else {
	      	# radar tracks not shown at all
	      	me.radar_group.hide();
	    }
	},

	displayRadarTrack: func (contact) {
		me.texelDistance = contact.get_polar()[0]*M2TEX;
		me.angle         = contact.get_polar()[1];
		me.pos_xx		 = -me.texelDistance * math.cos(me.angle + math.pi/2);
		me.pos_yy		 = -me.texelDistance * math.sin(me.angle + math.pi/2);

		me.showmeT = TRUE;

		me.currentIndexT = me.track_index;

		me.ordn = contact.get_type() == radar_logic.ORDNANCE;

		if(contact == radar_logic.selection and contact.get_cartesian()[0] != 900000) {
			me.selection_updated = TRUE;
			me.currentIndexT = 0;
		}

		if(me.currentIndexT > -1 and (me.showmeT == TRUE or me.currentIndexT == 0)) {
			me.tgtHeading = contact.get_heading();
		    me.tgtSpeed = contact.get_Speed();
		    me.myHeading = me.input.hdgReal.getValue();
		    if (me.currentIndexT == 0 and contact.parents[0] == radar_logic.ContactGPS) {
		    	me.gpsSymbol.setTranslation(me.pos_xx, me.pos_yy);
		    	me.gpsSymbol.show();
		    	me.isGPS = TRUE;
		    	me.echoesAircraft[me.currentIndexT].hide();
		    } elsif (me.ordn == FALSE) {
		    	me.echoesAircraft[me.currentIndexT].setTranslation(me.pos_xx, me.pos_yy);
			    if (me.tgtHeading != nil) {
			        me.relHeading = me.tgtHeading - me.myHeading;
			        #me.relHeading -= 180;
			        me.echoesAircraft[me.currentIndexT].setRotation(me.relHeading * D2R);
			    }
			    if (me.tgtSpeed != nil) {
			    	me.echoesAircraftVector[me.currentIndexT].setScale(1, clamp((me.tgtSpeed/60)*NM2M*M2TEX, 1, 250*MM2TEX));
		    	} else {
		    		me.echoesAircraftVector[me.currentIndexT].setScale(1, 1);
		    	}
				me.echoesAircraft[me.currentIndexT].show();
				me.echoesAircraft[me.currentIndexT].update();
			} else {
				if (me.missileIndex < maxMissiles-1) {
					me.missileIndex += 1;
					me.missiles[me.missileIndex].setTranslation(me.pos_xx, me.pos_yy);					
					if (me.tgtHeading != nil) {
				        me.relHeading = me.tgtHeading - me.myHeading;
				        #me.relHeading -= 180;
				        me.missiles[me.missileIndex].setRotation(me.relHeading * D2R);
				    }
				    if (me.tgtSpeed != nil) {
				    	me.missilesVector[me.missileIndex].setScale(1, clamp((me.tgtSpeed/60)*NM2M*M2TEX, 1, 250*MM2TEX));
			    	} else {
			    		me.missilesVector[me.missileIndex].setScale(1, 1);
			    	}
			    	me.missiles[me.missileIndex].show();
			    	me.missiles[me.missileIndex].update();
			    }
				me.echoesAircraft[me.currentIndexT].hide();
			}
			if(me.currentIndexT != 0) {
				me.track_index += 1;
				if (me.track_index == maxTracks) {
					me.track_index = -1;
				}
			}
			if (contact.get_model() == "missile_frigate" and me.threatIndex < maxThreats-1) {
				me.threatIndex += 1;
				me.threats[me.threatIndex].setTranslation(me.pos_xx, me.pos_yy);
				me.scale = 60*NM2M*M2TEX/100;
		      	me.threats[me.threatIndex].setStrokeLineWidth(w/me.scale);
		      	me.threats[me.threatIndex].setScale(me.scale);
				me.threats[me.threatIndex].show();
			} elsif (contact.get_model() == "buk-m2" and me.threatIndex < maxThreats-1) {
				me.threatIndex += 1;
				me.threats[me.threatIndex].setTranslation(me.pos_xx, me.pos_yy);
				me.scale = 20*NM2M*M2TEX/100;
		      	me.threats[me.threatIndex].setStrokeLineWidth(w/me.scale);
		      	me.threats[me.threatIndex].setScale(me.scale);
				me.threats[me.threatIndex].show();
			}
		}
	},

	setupMap: func {
		for(var x = 0; x < num_tiles[0]; x += 1) {
		  	tiles[x] = setsize([], num_tiles[1]);
		  	for(var y = 0; y < num_tiles[1]; y += 1)
		    	tiles[x][y] = me.mapFinal.createChild("image", "map-tile");
		}
	},

	showSelfVector: func {
		# length = time to travel in 60 seconds.
		var spd = getprop("velocities/airspeed-kt");# true airspeed so can be compared with other aircrats speed. (should really be ground speed)
		me.selfVector.setScale(1, clamp((spd/60)*NM2M*M2TEX, 1, 250*MM2TEX));
	},

	updateMap: func {
		# update the map
		
		  # get current position
		  var lat = getprop('/position/latitude-deg');
		  var lon = getprop('/position/longitude-deg');

		  var n = math.pow(2, zoom);
		  var offset = [
		    n * ((lon + 180) / 360) - center_tile_offset[0],
		    (1 - math.ln(math.tan(lat * math.pi/180) + 1 / math.cos(lat * math.pi/180)) / math.pi) / 2 * n - center_tile_offset[1]
		  ];
		  var tile_index = [int(offset[0]), int(offset[1])];

		  var ox = tile_index[0] - offset[0];
		  var oy = tile_index[1] - offset[1];

		  for(var x = 0; x < num_tiles[0]; x += 1) {
		    for(var y = 0; y < num_tiles[1]; y += 1) {
		      tiles[x][y].setTranslation(int((ox + x) * tile_size + 0.5), int((oy + y) * tile_size + 0.5));
		      #tiles[x][y].update();
		    }
		  }

		  if(tile_index[0] != last_tile[0] or tile_index[1] != last_tile[1] or type != last_type )  {
		    for(var x = 0; x < num_tiles[0]; x += 1) {
		      for(var y = 0; y < num_tiles[1]; y += 1) {
		        var pos = {
		          z: zoom,
		          x: int(offset[0] + x),
		          y: int(offset[1] + y),
		          type: type
		        };

		        (func {
			        var img_path = makePath(pos);
			        var tile = tiles[x][y];

			        if( io.stat(img_path) == nil ) { # image not found, save in $FG_HOME
			          var img_url = makeUrl(pos);
			          #print('requesting ' ~ img_url);
			          http.save(img_url, img_path)
			          		.done(func(r) {
			          	  		#print('received image ' ~ img_path~" " ~ r.status ~ " " ~ r.reason);
			          	  		tile.set("src", img_path);
			          	  	})
			              #.done(func {print('received image ' ~ img_path); tile.set("src", img_path);})
			              .fail(func (r) print('Failed to get image ' ~ img_path ~ ' ' ~ r.status ~ ': ' ~ r.reason));
			        }
			        else {# cached image found, reusing
			          #print('loading ' ~ img_path);
			          tile.set("src", img_path);
			          tile.update();
			        }
		        })();
		      }
		    }

		    last_tile = tile_index;
		    last_type = type;
		  }

		  me.mapRot.setRotation(-getprop("orientation/heading-deg")*D2R);
	},

	displayGroundCollisionArrow: func () {
	    if (getprop("/instrumentation/terrain-warning") == TRUE) {
	      me.arrow_trans.setRotation(-getprop("orientation/roll-deg") * D2R);
	      me.arrow.show();
	    } else {
	      me.arrow.hide();
	    }
	},
};

var extrapolate = func (x, x1, x2, y1, y2) {
    return y1 + ((x - x1) / (x2 - x1)) * (y2 - y1);
};

var ti = TI.new();
ti.loop();