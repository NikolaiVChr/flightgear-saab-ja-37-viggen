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
var (width,height) = (381.315,512);

#var window = canvas.Window.new([height, height],"dialog")
#					.set('x', width*2.75)
#                   .set('title', "TI display");
#var gone = 0;
#window.del = func() {
#  print("Cleaning up window:","TI","\n");
  #update_timer.stop();
#  gone = TRUE;
# explanation for the call() technique at: http://wiki.flightgear.org/Object_oriented_programming_in_Nasal#Making_safer_base-class_calls
#  call(canvas.Window.del, [], me);
#};
#var root = window.getCanvas(1).createGroup();
var canvas = canvas.new({
  "name": "TI",   # The name is optional but allow for easier identification
  "size": [height, height], # Size of the underlying texture (should be a power of 2, required) [Resolution]
  "view": [height, height],  # Virtual resolution (Defines the coordinate system of the canvas [Dimensions]
                        # which will be stretched the size of the texture, required)
  "mipmapping": 0       # Enable mipmapping (optional)
});
var root = canvas.createGroup();
root.set("font", "LiberationFonts/LiberationMono-Regular.ttf");
#window.getCanvas(1).setColorBackground(0.3, 0.3, 0.3, 1.0);
#window.getCanvas(1).addPlacement({"node": "ti_screen", "texture": "ti.png"});
canvas.setColorBackground(0.3, 0.3, 0.3, 1.0);
canvas.addPlacement({"node": "ti_screen", "texture": "ti.png"});

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

var zoomIn = func() {
  zoom_curr += 1;
  if (zoom_curr > 4) {
  	zoom_curr = 0;
  }
  zoom = zooms[zoom_curr];
  M2TEX = 1/(meterPerPixel[zoom]*math.cos(getprop('/position/latitude-deg')*D2R));
}

var zoomOut = func() {
  zoom_curr -= 1;
  if (zoom_curr < 0) {
  	zoom_curr = 4;
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
  string.compileTemplate('http://cartodb-basemaps-c.global.ssl.fastly.net/light_nolabels/{z}/{x}/{y}.png');#http://otile2.mqcdn.com/tiles/1.0.0/{type}/{z}/{x}/{y}.jpg'
var makePath =
  string.compileTemplate(maps_base ~ '/cartoL/{z}/{x}/{y}.png');#/osm-{type}/{z}/{x}/{y}.jpg
var num_tiles = [4, 4];

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

var brightness = func {
	bright += 1;
};

var bright = 0;

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

var rGrey = 0.5;   # inactive
var gGrey = 0.5;
var bGrey = 0.5;

var rBlack = 0.0;   # active
var gBlack = 0.0;
var bBlack = 0.0;

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


var dictSE = {
	'8':  {'7': "MENY", '1': "R7V", '2': "V7V", '3': "S7V", '18': "S7H", '19': "V7H", '20': "R7H", '16': "AKAN", '15': "RENS"},
	'10': {'3': "ELKA", '4': "TMAD", '6': "SKAL", '7': "MENY", '14': "EOMR", '15': "EOMR", '16': "TID", '17': "HORI", '18': "HKM", '19': "DAG"},
	'12': {'19': "NED", '20': "UPP"},
};

var dictEN = {
	'8':  {'7': "MENU", '1': "T7L", '2': "W7L", '3': "F7L", '18': "F7R", '19': "W7R", '20': "T7R", '16': "AKAN", '15': "CLR"},
	'10': {'3': "MAP", '4': "OLAY", '6': "SCAL", '7': "MENU", '14': "HOST", '15': "FRIE", '16': "TIME", '17': "HORI", '18': "CURS", '19': "DAY"},
	'12': {'19': "DOWN", '20': "UP"},
};

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
	        ctrlRadar:        		"controls/altimeter-radar",
	        acInstrVolt:      		"systems/electrical/outputs/ac-instr-voltage",
	        nav0InRange:      		"instrumentation/nav[0]/in-range",
      	};
   
      	foreach(var name; keys(ti.input)) {
        	ti.input[name] = props.globals.getNode(ti.input[name], 1);
      	}

      	ti.setupCanvasSymbols();
      	ti.setupMap();

      	ti.lastRRT = 0;
		ti.lastRR  = 0;
		ti.lastZ   = 0;


		ti.brightness = 1;

		ti.menuShowMain = FALSE;
		ti.menuShowFast = FALSE;
		ti.menuMain     = 9;
		ti.menuTrap     = TRUE;
		ti.menuSvy      = TRUE;
		ti.menuGPS      = TRUE;
		ti.upText = FALSE;
		ti.errorLogPage = 0;

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

		me.radar_limit_grp = me.radar_group.createChild("group");

		me.bottom_text_grp = root.createChild("group");
		me.textBArmType = me.bottom_text_grp.createChild("text")
    		.setText("74")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("left-top")
    		.setTranslation(0, height-height*0.09)
    		.setFontSize(35, 1);
    	me.textBArmAmmo = me.bottom_text_grp.createChild("text")
    		.setText("71")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(25, height-height*0.01)
    		.setFontSize(15, 1);
    	me.textBTactType1 = me.bottom_text_grp.createChild("text")
    		.setText("J")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-top")
    		.setTranslation(55, height-height*0.08)
    		.setFontSize(13, 1);
    	me.textBTactType2 = me.bottom_text_grp.createChild("text")
    		.setText("K")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-top")
    		.setTranslation(55, height-height*0.08+15)
    		.setFontSize(13, 1);
    	me.textBTactType3 = me.bottom_text_grp.createChild("text")
    		.setText("T")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-top")
    		.setTranslation(55, height-height*0.08+30)
    		.setFontSize(13, 1);
    	me.textBTactType = me.bottom_text_grp.createChild("path")
    		.moveTo(50, height-height*0.09)
    		.horiz(12)
    		.vert(45)
    		.horiz(-12)
    		.vert(-45)
    		.setColor(rWhite,gWhite,bWhite, a)
		    .setStrokeLineWidth(w);
    	me.textBBase = me.bottom_text_grp.createChild("text")
    		.setText("9040T")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(80, height-height*0.01)
    		.setFontSize(10, 1);
    	me.textBlink = me.bottom_text_grp.createChild("text")
    		.setText("DL")
    		.setColor(rGrey,gGrey,bGrey, a)
    		.setAlignment("center-top")
    		.setTranslation(72, height-height*0.08)
    		.setFontSize(10, 1);
    	me.textBLinkFrame = me.bottom_text_grp.createChild("path")
    		.moveTo(65, height-height*0.085)
    		.horiz(16)
    		.vert(12)
    		.horiz(-16)
    		.vert(-12)
    		.setColor(rWhite,gWhite,bWhite, a)
		    .setStrokeLineWidth(w);
		me.textBerror = me.bottom_text_grp.createChild("text")
    		.setText("F")
    		.setColor(rGrey,gGrey,bGrey, a)
    		.setAlignment("center-top")
    		.setTranslation(89, height-height*0.08)
    		.set("z-index", 10)
    		.setFontSize(10, 1);
    	me.textBerrorFrame1 = me.bottom_text_grp.createChild("path")
    		.moveTo(85, height-height*0.085)
    		.horiz(10)
    		.vert(12)
    		.horiz(-10)
    		.vert(-12)
    		.setColor(rWhite,gWhite,bWhite, a)
		    .setStrokeLineWidth(w);
		me.textBerrorFrame2 = me.bottom_text_grp.createChild("path")
    		.moveTo(85, height-height*0.085)
    		.horiz(10)
    		.vert(12)
    		.horiz(-10)
    		.vert(-12)
    		.setColor(rWhite,gWhite,bWhite, a)
    		.hide()
    		.set("z-index", 1)
		    .setColorFill(rGreen, gGreen, bGreen, a)
		    .setStrokeLineWidth(w);
    	me.textBMode = me.bottom_text_grp.createChild("text")
    		.setText("LF")
    		.setColor(rTyrk,gTyrk,bTyrk, a)
    		.setAlignment("center-center")
    		.setTranslation(125, height-height*0.05)
    		.setFontSize(40, 1);
    	me.textBDistN = me.bottom_text_grp.createChild("text")
    		.setText("A")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("right-bottom")
    		.setTranslation(width/2, height-height*0.015)
    		.setFontSize(20, 1);
    	me.textBDist = me.bottom_text_grp.createChild("text")
    		.setText("11")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("left-bottom")
    		.setTranslation(width/2, height-height*0.015)
    		.setFontSize(30, 1);
    	me.textBAlpha = me.bottom_text_grp.createChild("text")
    		.setText("ALFA 20,5")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("right-bottom")
    		.setTranslation(width, height-height*0.01)
    		.setFontSize(18, 1);
    	me.textBWeight = me.bottom_text_grp.createChild("text")
    		.setText("VIKT 13,4")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("right-top")
    		.setTranslation(width, height-height*0.085)
    		.setFontSize(18, 1);

    	me.menuMainRoot = root.createChild("group")
    		.set("z-index", 20)
    		.hide();
    	me.menuBottom8 = me.menuMainRoot.createChild("text")
    		.setText("VAP")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-Bottom")
    		.setTranslation(width*0.11, height)
    		.setFontSize(13, 1);
    	me.menuBottom9 = me.menuMainRoot.createChild("text")
    		.setText("SYST")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-Bottom")
    		.setTranslation(width*0.25, height)
    		.setFontSize(13, 1);
    	me.menuBottom10 = me.menuMainRoot.createChild("text")
    		.setText("PMGD")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-Bottom")
    		.setTranslation(width*0.40, height)
    		.setFontSize(13, 1);
    	me.menuBottom11 = me.menuMainRoot.createChild("text")
    		.setText("UDAT")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-Bottom")
    		.setTranslation(width*0.55, height)
    		.setFontSize(13, 1);
    	me.menuBottom12 = me.menuMainRoot.createChild("text")
    		.setText("FO")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-Bottom")
    		.setTranslation(width*0.71, height)
    		.setFontSize(13, 1);
    	me.menuBottom13 = me.menuMainRoot.createChild("text")
    		.setText("KONF")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-Bottom")
    		.setTranslation(width*0.84, height)
    		.setFontSize(13, 1);
    	me.errorRoot = root.createChild("group")
    		.hide();
    	me.errorList = me.errorRoot.createChild("text")
    		.setText("..OKAY..\n..OKAY..")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("left-top")
    		.setTranslation(0, 20)
    		.setFontSize(10, 1);

    	me.menuFastRoot = root.createChild("group")
    		.set("z-index", 20);
    		#.hide();
    	me.menuButton = [nil];
    	for(var i = 1; i <= 7; i+=1) {
			append(me.menuButton,
				me.menuFastRoot.createChild("text")
    				.setText("M\nE\nN\nY")
    				.setColor(rWhite,gWhite,bWhite, a)
    				.setAlignment("left-center")
    				.setTranslation(width*0.025, height*0.09+(i-1)*height*0.11)
    				.setFontSize(13, 1));
		}
		for(var i = 8; i <= 13; i+=1) {
			append(me.menuButton, nil);
		}
    	for(var i = 14; i <= 20; i+=1) {
			append(me.menuButton,
				me.menuFastRoot.createChild("text")
    				.setText("M\nE\nN\nY")
    				.setColor(rWhite,gWhite,bWhite, a)
    				.setAlignment("right-center")
    				.setTranslation(width*0.975, height*0.09+(6-(i-14))*height*0.11)
    				.setFontSize(13, 1));
		}
	},

	loop: func {
		#if ( gone == TRUE) {
		#	return;
		#}
		if (bright > 0) {
			bright -= 1;
			me.brightness -= 0.25;
			if (me.brightness < 0) {
				me.brightness = 1;
			}
		}
		if (me.brightness == 0 or me.input.acInstrVolt.getValue() < 100) {
			setprop("ja37/avionics/brightness-ti", 0);
			#setprop("ja37/avionics/cursor-on", FALSE);
			settimer(func me.loop(), 0.25);
			return;
		} else {
			setprop("ja37/avionics/brightness-ti", me.brightness);
			#setprop("ja37/avionics/cursor-on", cursorOn);
		}
		me.interoperability = me.input.units.getValue();

		me.updateMap();
		M2TEX = 1/(meterPerPixel[zoom]*math.cos(getprop('/position/latitude-deg')*D2R));
		me.showSelfVector();
		me.displayRadarTracks();
		me.showRunway();
		me.showRadarLimit();
		me.showBottomText();
		me.menuUpdate();

		settimer(func me.loop(), 0.5);
	},

	menuUpdate: func {
		if (me.menuShowMain == TRUE) {
			me.menuShowFast = TRUE;#figure this out better
			me.menuMainRoot.show();
			me.updateMainMenu();
			me.upText = TRUE;
		} else {
			me.menuMainRoot.hide();
			me.upText = FALSE;
		}
		if (me.menuShowFast == TRUE) {
			me.menuFastRoot.show();
			me.updateFastMenu();
		} else {
			me.menuFastRoot.hide();
		}
		if (me.menuMain == 12) {
			# failure menu
			me.mapCentrum.hide();
			me.rootCenter.hide();
			me.bottom_text_grp.hide();
			me.errorRoot.show();
			call(func {
				var buffer = FailureMgr.get_log_buffer();
				var str = "";
    			foreach(entry; buffer) {
      				str = str~entry.time~" "~entry.message~"\n";
    			}
				me.errorList.setText(str)});
			me.errorRoot.setTranslation(0,  -(height-height*0.025*me.upText)*me.errorLogPage);
			me.clip2 = 0~"px, "~width~"px, "~(height-height*0.025*me.upText)~"px, "~0~"px";
			me.errorRoot.set("clip", "rect("~me.clip2~")");#top,right,bottom,left
		} else {
			me.errorLogPage = 0;
			me.mapCentrum.show();
			me.rootCenter.show();
			me.bottom_text_grp.show();
			me.errorRoot.hide();
		}
	},

	updateMainMenu: func {
		if (me.interoperability == displays.METRIC) {
			me.menuBottom8.setText("VAP");
			me.menuBottom9.setText("SYST");
			me.menuBottom10.setText("PMGD");
			me.menuBottom11.setText("UDAT");
			me.menuBottom12.setText("FO");
			me.menuBottom13.setText("KONF");
		} else {
			me.menuBottom8.setText("WEAP");
			me.menuBottom9.setText("SYST");
			me.menuBottom9.update();
			me.menuBottom10.setText("DISP");
			me.menuBottom11.setText("FLDA");
			me.menuBottom12.setText("FAIL");
			me.menuBottom13.setText("CONF");
		}
	},

	updateFastMenu: func {
		for(var i = 1; i <= 7; i+=1) {
			me.menuButton[i].setText(me.compileFastMenu(i));
		}
		for(var i = 14; i <= 20; i+=1) {
			me.menuButton[i].setText(me.compileFastMenu(i));
		}
	},

	compileFastMenu: func (button) {
		var str = nil;
		if (me.interoperability == displays.METRIC) {
			str = dictSE[''~me.menuMain];
		} else {
			str = dictEN[''~me.menuMain];
		}
		if (str != nil) {
			str = str[''~button];
			if (str != nil) {
				var compiled = "";
				for(var i = 0; i < size(str); i+=1) {
					compiled = compiled ~substr(str,i,1)~(i==(size(str)-1)?"":"\n");
				}
				return compiled;
			}
		}
		return "";
	},

	menuNoSub: func {
		me.menuTrap = FALSE;
		me.menuSvy  = FALSE;
		me.menuGPS  = FALSE;
	},

	b1: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
		}
	},

	b2: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
		}
	},

	b3: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
		}
	},

	b4: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
		}
	},

	b5: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
			if (me.menuMain == 13 and me.menuSvy == FALSE) {
				# side view
				me.menuSvy = TRUE;
			}
		}
	},

	b6: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
			if (me.menuMain == 9 and me.menuTrap == FALSE) {
				# tactical report
				me.menuTrap = TRUE;
			}
		}
	},

	b7: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
			me.menuShowMain = FALSE;
			me.menuShowFast = FALSE;
			me.menuTrap = TRUE;
			me.menuMain = 9;
		}
	},

	b8: func {
		# weapons
		if (me.menuShowMain == TRUE) {
			me.menuMain = 8;
			me.menuNoSub();
		} else {
			me.menuShowMain = !me.menuShowMain;
		}
	},

	b9: func {
		# system
		if (me.menuShowMain == TRUE) {
			me.menuMain = 9;
			me.menuNoSub();
		} else {
			me.menuShowMain = !me.menuShowMain;
		}
	},

	b10: func {
		# display
		if (me.menuShowMain == TRUE) {
			me.menuMain = 10;
			me.menuNoSub();
		} else {
			me.menuShowMain = !me.menuShowMain;
		}
	},

	b11: func {
		# flight data
		if (me.menuShowMain == TRUE) {
			me.menuMain = 11;
			me.menuNoSub();
		} else {
			me.menuShowMain = !me.menuShowMain;
		}
	},

	b12: func {
		# errors
		if (me.menuShowMain == TRUE) {
			me.menuMain = 12;
			me.menuNoSub();
		} else {
			me.menuShowMain = !me.menuShowMain;
		}
	},

	b13: func {
		# configuration
		if (me.menuShowMain == TRUE) {
			me.menuMain = 13;
			me.menuNoSub();
		} else {
			me.menuShowMain = !me.menuShowMain;
		}
	},

	b14: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
			if (me.menuMain == 13 and me.menuGPS == FALSE) {
				# GPS settings
				me.menuGPS = TRUE;
			}
		}
	},

	b15: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
		}
	},

	b16: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
		}
	},

	b17: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
		}
	},

	b18: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
		}
	},

	b19: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
			if(me.menuMain == 12) {
				me.errorLogPage += 1;
			}
		}
	},

	b20: func {
		if (me.menuShowFast == FALSE) {
			me.menuShowFast = TRUE;
		} else {
			if(me.menuMain == 12) {
				me.errorLogPage -= 1;
				if (me.errorLogPage < 0) {
					me.errorLogPage = 0;
				}
			}
		}
	},

	showBottomText: func {
		#clip is in canvas coordinates
		me.clip2 = 0~"px, "~width~"px, "~(height-height*0.1-height*0.025*me.upText)~"px, "~0~"px";
		me.rootCenter.set("clip", "rect("~me.clip2~")");#top,right,bottom,left
		me.mapCentrum.set("clip", "rect("~me.clip2~")");#top,right,bottom,left
		me.bottom_text_grp.setTranslation(0,-height*0.025*me.upText);
		me.textBArmType.setText(displays.common.currArmNameSh);
		me.ammo = armament.ammoCount(me.input.station.getValue());
	    if (me.ammo == -1) {
	    	me.ammoT = "  ";
	    } else {
	    	me.ammoT = me.ammo~"";
	    }
		me.textBArmAmmo.setText(me.ammoT);
		if (me.interoperability == displays.METRIC) {
			if (displays.common.currArmNameSh == "70") {
				me.textBTactType1.setText("A");
				me.textBTactType2.setText("T");
				me.textBTactType3.setText("T");
			} else {
				me.textBTactType1.setText("J");
				me.textBTactType2.setText("K");
				me.textBTactType3.setText("T");
			}
		} else {
			if (displays.common.currArmNameSh == "70") {
				me.textBTactType1.setText("A");
				me.textBTactType2.setText("T");
				me.textBTactType3.setText("T");
			} else {
				me.textBTactType1.setText("F");
				me.textBTactType2.setText("G");
				me.textBTactType3.setText("T");
			}
		}
		me.icao = land.icao~((me.input.nav0InRange.getValue() == TRUE)?" T":"  ");
		me.textBBase.setText(me.icao);
		
		me.mode = "";
		# DL: data link
		# RR: radar
		if (land.mode < 3 and land.mode > 0) {
			me.mode = "LB";# landing waypoint
		} elsif (land.mode > 2) {
			me.mode = "LF";# landing touchdown point
		} elsif (me.input.currentMode.getValue() == displays.LANDING) {
			me.mode = "L ";# landing
		} else {
			me.mode = "  ";# 
		}
		me.textBMode.setText(me.mode);

		if (displays.common.distance_m != -1) {
			if (me.interoperability == displays.METRIC) {
				me.distance_un = displays.common.distance_m/1000;
				me.textBDistN.setText("A");
			} else {
				me.distance_un = displays.common.distance_m*M2NM;
				me.textBDistN.setText("NM");
			}
			if (me.distance_un < 10) {
				me.textBDist.setText(sprintf("%.1f", me.distance_un));
			} else {
				me.textBDist.setText(sprintf("%d", me.distance_un));
			}
		} else {
			me.textBDist.setText("  ");
			me.textBDistN.setText(" ");
		}
		if (me.input.currentMode.getValue() == displays.LANDING) {
			me.alphaT  = me.interoperability == displays.METRIC?"ALFA":"ALPH";
			me.weightT = me.interoperability == displays.METRIC?"VIKT":"WEIG";
			if (me.interoperability == displays.METRIC) {
				me.weight = getprop("fdm/jsbsim/inertia/weight-lbs")*0.453592*0.001;
			} else {
				me.weight = getprop("fdm/jsbsim/inertia/weight-lbs")*0.001;
			}
			var weight = getprop("fdm/jsbsim/inertia/weight-lbs");
			me.alpha   = 9 + ((weight - 28000) / (38000 - 28000)) * (12 - 9);
			me.weightT = me.weightT~sprintf(" %.1f", me.weight);
			me.alphaT  = me.alphaT~sprintf(" %.1f", me.alpha);
			me.textBWeight.setText(me.weightT);
			me.textBAlpha.setText(me.alphaT);
		} elsif (me.input.currentMode.getValue() == displays.COMBAT) {
			if (radar_logic.selection != nil) {
				me.textBWeight.setText(radar_logic.selection.get_Callsign());
				me.textBAlpha.setText(radar_logic.selection.get_model());
			} else {
				me.textBWeight.setText("");
				me.textBAlpha.setText("");
			}
		} else {
			me.textBWeight.setText("");
			me.textBAlpha.setText("");
		}
		if (displays.common.error == FALSE) {
			me.textBerror.setColor(rGrey, gGrey, bGrey, a);
			me.textBerrorFrame2.hide();
			me.textBerrorFrame1.show();
		} else {
			me.textBerror.setColor(rBlack, gBlack, bBlack, a);
			me.textBerrorFrame1.hide();
			me.textBerrorFrame2.show();
		}
	},

	showRadarLimit: func {
		if (me.input.currentMode.getValue() == canvas_HUD.COMBAT and me.input.tracks_enabled.getValue() == TRUE) {
			if (me.lastZ  != zoom_curr or me.lastRR != me.input.radarRange.getValue() or me.input.timeElapsed.getValue() - me.lastRRT > 1600) {
				me.radar_limit_grp.removeAllChildren();
				var rdrField = 61.5*D2R;
				var radius = M2TEX*me.input.radarRange.getValue();
				var (leftX, leftY)   = (-math.sin(rdrField)*radius, -math.cos(rdrField)*radius);
				me.radarLimit = me.radar_limit_grp.createChild("path")
					.moveTo(leftX, leftY)
					.arcSmallCW(radius, radius, 0, -leftX*2, 0)
					.moveTo(leftX, leftY)
					.lineTo(leftX*0.75, leftY*0.75)
					.moveTo(-leftX, leftY)
					.lineTo(-leftX*0.75, leftY*0.75)
					.setColor(rTyrk,gTyrk,bTyrk, a)
			    	.setStrokeLineWidth(w);
			    me.lastRRT = me.input.timeElapsed.getValue();
			    me.lastRR  = me.input.radarRange.getValue();
			    me.lastZ  = zoom_curr;
			}
			me.radar_limit_grp.show();
	    } else {
	    	me.radar_limit_grp.hide();
	    }
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
		    	tiles[x][y] = me.mapFinal.createChild("image", "map-tile")
		    	.set("fill", "rgb(128,128,128)");
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