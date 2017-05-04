# todo:
# servicable, indicated
# buttons functions
# geo grid
# radar echoes types
# runway proper styles
# steerpoint symbols: # ?
# full OOP
# use Pinto's model
var (width,height) = (381,512);#381.315


var FALSE = 0;
var TRUE = 1;


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
var mycanvas = nil;
var root = nil;
var setupCanvas = func {
	mycanvas = canvas.new({
	  "name": "TI",   # The name is optional but allow for easier identification
	  "size": [height, height], # Size of the underlying texture (should be a power of 2, required) [Resolution]
	  "view": [height, height],  # Virtual resolution (Defines the coordinate system of the canvas [Dimensions]
	                        # which will be stretched the size of the texture, required)
	  "mipmapping": 0       # Enable mipmapping (optional)
	});
	root = mycanvas.createGroup();
	root.set("font", "LiberationFonts/LiberationMono-Regular.ttf");
	#window.getCanvas(1).setColorBackground(0.3, 0.3, 0.3, 1.0);
	#window.getCanvas(1).addPlacement({"node": "ti_screen", "texture": "ti.png"});
	mycanvas.setColorBackground(0.3, 0.3, 0.3, 1.0);
	mycanvas.addPlacement({"node": "ti_screen", "texture": "ti.png"});
}
var (center_x, center_y) = (width/2,height/2);

var MM2TEX = 1;
var texel_per_degree = 2*MM2TEX;
var KT2KMH = 1.85184;

# map setup

var tile_size = 256;
var zoom = 9;
var type = "light_nolabels";

# index   = zoom level
# content = meter per pixel of tiles
#                   0                             5                               10                               15                      19
meterPerPixel = [156412,78206,39103,19551,9776,4888,2444,1222,610.984,305.492,152.746,76.373,38.187,19.093,9.547,4.773,2.387,1.193,0.596,0.298];# at equator
zooms      = [4, 7, 9, 11, 13];
zoomLevels = [3.2, 1.6, 800, 400, 200];
zoom_curr  = 2;

var M2TEX = 1/meterPerPixel[zoom];

var zoomIn = func() {
	if (ti.active == FALSE) return;
  zoom_curr += 1;
  if (zoom_curr > 4) {
  	zoom_curr = 0;
  }
  zoom = zooms[zoom_curr];
  M2TEX = 1/(meterPerPixel[zoom]*math.cos(getprop('/position/latitude-deg')*D2R));
}

var zoomOut = func() {
	if (ti.active == FALSE) return;
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
  string.compileTemplate('http://cartodb-basemaps-c.global.ssl.fastly.net/{type}/{z}/{x}/{y}.png');#http://otile2.mqcdn.com/tiles/1.0.0/{type}/{z}/{x}/{y}.jpg'
var makePath =
  string.compileTemplate(maps_base ~ '/cartoL/{z}/{x}/{y}.png');#/osm-{type}/{z}/{x}/{y}.jpg
var num_tiles = [5, 5];

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
var last_zoom = zoom;
var lastLiveMap = getprop("ja37/displays/live-map");
var lastDay   = TRUE;

# stuff

var FLIGHTDATA_ON = 2;
var FLIGHTDATA_CLR = 1;
var FLIGHTDATA_OFF = 0;

var CLEANMAP = 0;
var PLACES   = 1;

var MAIN_WEAPONS       =  8;
var MAIN_SYSTEMS       =  9;
var MAIN_DISPLAY       = 10;
var MAIN_MISSION_DATA  = 11;
var MAIN_FAILURES      = 12;
var MAIN_CONFIGURATION = 13;

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

var rDTyrk = 0.15; # route polygon
var gDTyrk = 0.60;
var bDTyrk = 0.55;

var rGrey = 0.5;   # inactive
var gGrey = 0.5;
var bGrey = 0.5;

var rBlack = 0.0;   # active
var gBlack = 0.0;
var bBlack = 0.0;

var rGB = 0.5;   # flight data
var gGB = 0.5;
var bGB = 0.75;

var a = 1.0;#alpha
var w = 1.0;#stroke width

var fpi_min = 3;
var fpi_med = 6;
var fpi_max = 9;

var maxTracks   = 32;# how many radar tracks can be shown at once in the TI (was 16)
var maxMissiles = 6;
var maxThreats  = 5;
var maxSteers   =50;
var maxBases    =50;

var roundabout = func(x) {
  var y = x - int(x);
  return y < 0.5 ? int(x) : 1 + int(x) ;
};

var clamp = func(v, min, max) { v < min ? min : v > max ? max : v };

var circlePos = func (deg, radius) {
	return [radius*math.cos(deg*D2R),radius*math.sin(deg*D2R)];
}


var dictSE = {
	'HORI': {'0': [TRUE, "AV"], '1': [TRUE, "RENS"], '2': [TRUE, "PA"]},
	'0':   {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "FO"], '13': [TRUE, "KONF"]},
	'8':   {'8': [TRUE, "R7V"], '9': [TRUE, "V7V"], '10': [TRUE, "S7V"], '11': [TRUE, "S7H"], '12': [TRUE, "V7H"], '13': [TRUE, "R7H"],
			'7': [TRUE, "MENY"], '14': [TRUE, "AKAN"], '15': [FALSE, "RENS"]},
	'9':   {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "FO"], '13': [TRUE, "KONF"],
	 		'1': [TRUE, "SLACK"], '2': [TRUE, "DL"], '4': [TRUE, "B"], '5': [TRUE, "UPOL"], '6': [TRUE, "TRAP"], '7': [TRUE, "MENY"],
	 		'14': [TRUE, "JAKT"], '15': [FALSE, "HK"],'16': [FALSE, "APOL"], '17': [FALSE, "LA"], '18': [FALSE, "LF"], '19': [FALSE, "LB"],'20': [FALSE, "L"]},
	'TRAP':{'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "FO"], '13': [TRUE, "KONF"],
	 		'2': [TRUE, "INLA"], '3': [TRUE, "AVFY"], '4': [TRUE, "FALL"], '5': [TRUE, "MAN"], '6': [FALSE, "SATT"], '7': [TRUE, "MENY"], '14': [TRUE, "RENS"], '17': [FALSE, "ALLA"], '19': [TRUE, "NED"], '20': [TRUE, "UPP"]},
	'10':  {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "FO"], '13': [TRUE, "KONF"],
			'3': [TRUE, "ORTS"], '4': [TRUE, "TMAD"], '6': [TRUE, "SKAL"], '7': [TRUE, "MENY"], '14': [FALSE, "EOMR"], '15': [FALSE, "EOMR"], '16': [TRUE, "TID"], '17': [TRUE, "HORI"], '18': [FALSE, "HKM"], '19': [TRUE, "DAG"]},
	'11':  {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "FO"], '13': [TRUE, "KONF"],
			'4': [FALSE, "EDIT"], '6': [FALSE, "EDIT"], '7': [TRUE, "MENY"], '14': [FALSE, "EDIT"], '15': [FALSE, "APOL"], '16': [FALSE, "EDIT"], '17': [FALSE, "UPOL"], '18': [FALSE, "EDIT"], '19': [TRUE, "EGLA"], '20': [FALSE, "KMAN"]},
	'12':  {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "FO"], '13': [TRUE, "KONF"],
	 		'7': [TRUE, "MENY"], '19': [TRUE, "NED"], '20': [TRUE, "UPP"]},
	'13':  {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "FO"], '13': [TRUE, "KONF"],
			'5': [TRUE, "SVY"], '6': [TRUE, "FR28"], '7': [TRUE, "MENY"], '14': [TRUE, "GPS"], '19': [FALSE, "LAS"]},
	'GPS': {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "FO"], '13': [TRUE, "KONF"],
			'7': [TRUE, "MENU"], '14': [TRUE, "FIX"], '15': [TRUE, "INIT"]},
	'SVY': {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "FO"], '13': [TRUE, "KONF"],
			'5': [FALSE, "FOST"], '6': [FALSE, "VISA"], '7': [TRUE, "MENU"], '14': [FALSE, "SKAL"], '15': [FALSE, "RMAX"], '16': [FALSE, "HMAX"]},
};

var dictEN = {
	'HORI': {'0': [TRUE, "OFF"], '1': [TRUE, "CLR"], '2': [TRUE, "ON"]},
	'0':   {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"]},
	'8':   {'8': [TRUE, "T7L"], '9': [TRUE, "W7L"], '10': [TRUE, "F7L"], '11': [TRUE, "F7R"], '12': [TRUE, "W7R"], '13': [TRUE, "T7R"],
			'7': [TRUE, "MENU"], '14': [TRUE, "AKAN"], '15': [FALSE, "CLR"]},
    '9':   {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
	 		'1': [TRUE, "OFF"], '2': [TRUE, "DL"], '4': [TRUE, "ROUT"], '5': [TRUE, "POLY"], '6': [TRUE, "TRAP"], '7': [TRUE, "MENU"],
	 		'14': [TRUE, "FGHT"], '15': [FALSE, "ACRV"],'16': [FALSE, "APOL"], '17': [FALSE, "STPT"], '18': [FALSE, "LT"], '19': [FALSE, "LS"],'20': [FALSE, "L"]},
	'TRAP':{'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
	 		'2': [TRUE, "LOCK"], '3': [TRUE, "FIRE"], '4': [TRUE, "ECM"], '5': [TRUE, "MAN"], '6': [FALSE, "LAND"], '7': [TRUE, "MENU"], '14': [TRUE, "CLR"], '17': [FALSE, "ALL"], '19': [TRUE, "DOWN"], '20': [TRUE, "UP"]},
	'10':  {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
			'3': [TRUE, "TEXT"], '4': [TRUE, "AIRP"], '6': [TRUE, "SCAL"], '7': [TRUE, "MENU"], '14': [FALSE, "HSTL"], '15': [FALSE, "FRND"], '16': [TRUE, "TIME"], '17': [TRUE, "HORI"], '18': [FALSE, "CURS"], '19': [TRUE, "DAY"]},
	'11':  {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
			'4': [FALSE, "EDIT"], '6': [FALSE, "EDIT"], '7': [TRUE, "MENU"], '14': [FALSE, "EDIT"], '15': [FALSE, "POLY"], '16': [FALSE, "EDIT"], '17': [FALSE, "UPOL"], '18': [FALSE, "EDIT"], '19': [TRUE, "MYPS"], '20': [FALSE, "MMAN"]},
	'12':  {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
	 		'7': [TRUE, "MENU"], '19': [TRUE, "DOWN"], '20': [TRUE, "UP"]},
	'13':  {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
			'5': [TRUE, "SIDE"], '6': [TRUE, "FR28"], '7': [TRUE, "MENU"], '14': [TRUE, "GPS"], '19': [FALSE, "LOCK"]},
	'GPS': {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
			'7': [TRUE, "MENU"], '14': [TRUE, "FIX"], '15': [TRUE, "INIT"]},
	'SIDE': {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
			'5': [FALSE, "WIN"], '6': [FALSE, "SHOW"], '7': [TRUE, "MENU"], '14': [FALSE, "SCAL"], '15': [FALSE, "RMAX"], '16': [FALSE, "AMAX"]},
};

var TI = {

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
			.set("z-index",  9);
		me.rootRealCenter = root.createChild("group")
			.setTranslation(width/2,height/2)
			.set("z-index", 10);
		me.selfSymbol = me.rootCenter.createChild("path")
		      .moveTo(-5*MM2TEX,  5*MM2TEX)
		      .lineTo( 0,       -10*MM2TEX)
		      .moveTo( 5*MM2TEX,  5*MM2TEX)
		      .lineTo( 0,       -10*MM2TEX)
		      .moveTo(-5*MM2TEX,  5*MM2TEX)
		      .lineTo( 5*MM2TEX,  5*MM2TEX)
		      .setColor(rWhite,gWhite,bWhite, a)
		      .set("z-index", 10)
		      .setStrokeLineWidth(w);
		me.selfSymbolGPS = me.rootCenter.createChild("path")
		      .moveTo(-5*MM2TEX,  5*MM2TEX)
		      .lineTo( 0,       -10*MM2TEX)
		      .lineTo( 5*MM2TEX,  5*MM2TEX)
		      .lineTo(-5*MM2TEX,  5*MM2TEX)
		      .setColor(rWhite,gWhite,bWhite, a)
		      .setColorFill(rWhite,gWhite,bWhite)
		      .set("z-index", 10)
		      .setStrokeLineWidth(w);

		me.mapScaleTickPosX = width*0.975/2;
		me.mapScaleTickPosTxtX = width*0.975/2-width*0.025/2;
		me.mapScale = me.rootCenter.createChild("group")
			.set("z-index", 3);
		me.mapScale.createChild("path")
			.moveTo(me.mapScaleTickPosX, height)
			.vert(-height*2)
			.setColor(rWhite,gWhite,bWhite, a)
		    .setStrokeLineWidth(w);
		me.mapScaleTick0 = me.mapScale.createChild("path")
			.moveTo(me.mapScaleTickPosX, 0)
			.horiz(-width*0.025/2)
			.setColor(rWhite,gWhite,bWhite, a)
		    .setStrokeLineWidth(w);
		me.mapScaleTick0Txt = me.mapScale.createChild("text")
    		.setText("0")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("right-center")
    		.setTranslation(me.mapScaleTickPosTxtX, 0)
    		.setFontSize(15, 1);
    	me.mapScaleTick1 = me.mapScale.createChild("path")
			.moveTo(me.mapScaleTickPosX, 0)
			.horiz(-width*0.025/2)
			.setColor(rWhite,gWhite,bWhite, a)
		    .setStrokeLineWidth(w);
		me.mapScaleTick1Txt = me.mapScale.createChild("text")
    		.setText("50")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("right-center")
    		.setTranslation(me.mapScaleTickPosTxtX, -height/4)
    		.setFontSize(15, 1);
    	me.mapScaleTick2 = me.mapScale.createChild("path")
			.moveTo(me.mapScaleTickPosX, 0)
			.horiz(-width*0.025/2)
			.setColor(rWhite,gWhite,bWhite, a)
		    .setStrokeLineWidth(w);
		me.mapScaleTick2Txt = me.mapScale.createChild("text")
    		.setText("100")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("right-center")
    		.setTranslation(me.mapScaleTickPosTxtX, -height/2)
    		.setFontSize(15, 1);
    	me.mapScaleTick3 = me.mapScale.createChild("path")
			.moveTo(me.mapScaleTickPosX, 0)
			.horiz(-width*0.025/2)
			.setColor(rWhite,gWhite,bWhite, a)
		    .setStrokeLineWidth(w);
		me.mapScaleTick3Txt = me.mapScale.createChild("text")
    		.setText("150")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("right-center")
    		.setTranslation(me.mapScaleTickPosTxtX, -height/4)
    		.setFontSize(15, 1);
    	me.mapScaleTickM1 = me.mapScale.createChild("path")
			.moveTo(me.mapScaleTickPosX, 0)
			.horiz(-width*0.025/2)
			.setColor(rWhite,gWhite,bWhite, a)
		    .setStrokeLineWidth(w);
		me.mapScaleTickM1Txt = me.mapScale.createChild("text")
    		.setText("-50")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("right-center")
    		.setTranslation(me.mapScaleTickPosTxtX, -height/4)
    		.setFontSize(15, 1);
    	me.mapScaleTickM2 = me.mapScale.createChild("path")
			.moveTo(me.mapScaleTickPosX, 0)
			.horiz(-width*0.025/2)
			.setColor(rWhite,gWhite,bWhite, a)
		    .setStrokeLineWidth(w);
		me.mapScaleTickM2Txt = me.mapScale.createChild("text")
    		.setText("-100")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("right-center")
    		.setTranslation(me.mapScaleTickPosTxtX, -height/2)
    		.setFontSize(15, 1);
    	me.mapScaleTickM3 = me.mapScale.createChild("path")
			.moveTo(me.mapScaleTickPosX, 0)
			.horiz(-width*0.025/2)
			.setColor(rWhite,gWhite,bWhite, a)
		    .setStrokeLineWidth(w);
		me.mapScaleTickM3Txt = me.mapScale.createChild("text")
    		.setText("-150")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("right-center")
    		.setTranslation(me.mapScaleTickPosTxtX, -height/4)
    		.setFontSize(15, 1);


		me.navBugs = root.createChild("group")
			.set("z-index", 4);
		# direction of travel indicator
		me.navBugs.createChild("path")
		      .moveTo( width/2,  0)
		      .vert(7.5*MM2TEX)
		      .setColor(rWhite,gWhite,bWhite, a)
		      .setStrokeLineWidth(w)
		      .set("z-index", 5);
		# commanded direction of travel indicator
		me.commanded = me.navBugs.createChild("path")
		      .moveTo(-2.5*MM2TEX,  6*MM2TEX)
		      .vert(9*MM2TEX)
		      .moveTo(0,  0)
		      .vert(12*MM2TEX)
		      .moveTo(2.5*MM2TEX,  6*MM2TEX)
		      .vert(9*MM2TEX)
		      .setColor(rWhite,gWhite,bWhite, a)
		      .setStrokeLineWidth(w)
		      .set("z-index", 5);
		me.selfVectorG = me.rootCenter.createChild("group")
			.set("z-index", 10)
			.setTranslation(0,-10*MM2TEX);
		me.selfVector = me.selfVectorG.createChild("path")
			  .moveTo(0,  0)
			  .lineTo(0, -1*MM2TEX)
			  .setColor(rWhite,gWhite,bWhite, a)
		      .setStrokeLineWidth(w);

		me.radar_group = me.rootCenter.createChild("group")
			.set("z-index", 5);
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
	    	.set("z-index", 7)
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
	    			.set("z-index", 7)
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

	    me.steerpoint = [];
	    for (var i = 0; i < maxSteers; i += 1) {
	    	append(me.steerpoint, me.rootCenter.createChild("path")
	    			.set("z-index", 6)
	               .moveTo(-10*MM2TEX, 0)
	               .lineTo(0, -15*MM2TEX)
	               .lineTo(10*MM2TEX, 0)
	               .lineTo(0, 15*MM2TEX)
	               .lineTo(-10*MM2TEX, 0)
	               .setStrokeLineWidth(w)
	               .setColor(rDTyrk,gDTyrk,bDTyrk, a));
	    }
	    me.steerPoly = me.rootCenter.createChild("group")
	    			.set("z-index", 6);

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
		      .moveTo(-10*MM2TEX, 10*MM2TEX)
		      .vert(            -20*MM2TEX)
		      .horiz(            20*MM2TEX)
		      .vert(             20*MM2TEX)
		      .horiz(           -20*MM2TEX)
		      .setColor(rTyrk,gTyrk,bTyrk, a)
		      .setStrokeLineWidth(w);

		me.radar_limit_grp = me.radar_group.createChild("group");

		# target info box
		me.tgtTextField     = root.createChild("group")
			.set("z-index", 4);
		var tgtStartx = width*0.060-3.125+6.25*2+w*2;
		var tgtStarty = height-height*0.1-height*0.025-w*2;
		var tgtW      = 0.15;
		var tgtH      = 0.10;
		me.tgtTextFrame     = me.tgtTextField.createChild("path")
			.moveTo(tgtStartx,  tgtStarty)#above bottom text field and next to fast menu sub boxes
		      .vert(            -height*tgtH)
		      .horiz(            width*tgtW)
		      .vert(             height*tgtH)
		      .horiz(           -width*tgtW)

		      .moveTo(tgtStartx, tgtStarty-height*tgtH*0.33)
		      .horiz(            width*tgtW)
		      .moveTo(tgtStartx, tgtStarty-height*tgtH*0.66)
		      .horiz(            width*tgtW)
		      .moveTo(tgtStartx+width*tgtW*0.2, tgtStarty)
		      .vert(            -height*tgtH)
		      .setColor(rWhite,gWhite,bWhite, a)
		      .setStrokeLineWidth(w);
		me.tgtTextDistDesc = me.tgtTextField.createChild("text")
    		.setText("A")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(tgtStartx+width*tgtW*0.1, tgtStarty-height*tgtH*0.66-w)
    		.setFontSize(15, 1);
    	me.tgtTextDist = me.tgtTextField.createChild("text")
    		.setText("74")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(tgtStartx+width*tgtW*0.60, tgtStarty-height*tgtH*0.66-w)
    		.setFontSize(15, 1);
    	me.tgtTextHeiDesc = me.tgtTextField.createChild("text")
    		.setText("H")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(tgtStartx+width*tgtW*0.1, tgtStarty-height*tgtH*0.33-w)
    		.setFontSize(15, 1);
    	me.tgtTextHei = me.tgtTextField.createChild("text")
    		.setText("4700")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(tgtStartx+width*tgtW*0.60, tgtStarty-height*tgtH*0.33-w)
    		.setFontSize(15, 1);
    	me.tgtTextSpdDesc = me.tgtTextField.createChild("text")
    		.setText("M")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(tgtStartx+width*tgtW*0.1, tgtStarty-height*tgtH*0.0-w)
    		.setFontSize(15, 1);
    	me.tgtTextSpd = me.tgtTextField.createChild("text")
    		.setText("0,80")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(tgtStartx+width*tgtW*0.60, tgtStarty-height*tgtH*0.0-w)
    		.setFontSize(15, 1);		

		# steerpoint info box
		me.wpTextField     = root.createChild("group")
			.set("z-index", 4);
		var wpStartx = width*0.060-3.125+6.25*2+w*2;
		var wpStarty = height-height*0.1-height*0.025-w*2;
		var wpW      = 0.29;
		var wpH      = 0.15;
		me.wpTextFrame     = me.wpTextField.createChild("path")
			.moveTo(wpStartx,  wpStarty)#above bottom text field and next to fast menu sub boxes
		      .vert(            -height*wpH)
		      .horiz(            width*wpW)
		      .vert(             height*wpH)
		      .horiz(           -width*wpW)

		      .moveTo(wpStartx, wpStarty-height*wpH*0.2)
		      .horiz(            width*wpW)
		      .moveTo(wpStartx, wpStarty-height*wpH*0.4)
		      .horiz(            width*wpW)
		      .moveTo(wpStartx, wpStarty-height*wpH*0.6)
		      .horiz(            width*wpW)
		      .moveTo(wpStartx, wpStarty-height*wpH*0.8)
		      .horiz(            width*wpW)
		      .moveTo(wpStartx+width*wpW*0.3, wpStarty)
		      .vert(            -height*wpH)
		      .setColor(rWhite,gWhite,bWhite, a)
		      .setStrokeLineWidth(w);
		me.wpTextNumDesc = me.wpTextField.createChild("text")
    		.setText("BEN")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(wpStartx+width*wpW*0.15, wpStarty-height*wpH*0.8-w)
    		.setFontSize(15, 1);
    	me.wpTextNum = me.wpTextField.createChild("text")
    		.setText("1 AV 4")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(wpStartx+width*wpW*0.65, wpStarty-height*wpH*0.8-w)
    		.setFontSize(15, 1);
    	me.wpTextPosDesc = me.wpTextField.createChild("text")
    		.setText("B")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(wpStartx+width*wpW*0.15, wpStarty-height*wpH*0.6-w)
    		.setFontSize(15, 1);
    	me.wpTextPos = me.wpTextField.createChild("text")
    		.setText("0 -> 1")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(wpStartx+width*wpW*0.65, wpStarty-height*wpH*0.6-w)
    		.setFontSize(15, 1);
    	me.wpTextAltDesc = me.wpTextField.createChild("text")
    		.setText("H")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(wpStartx+width*wpW*0.15, wpStarty-height*wpH*0.4-w)
    		.setFontSize(15, 1);
    	me.wpTextAlt = me.wpTextField.createChild("text")
    		.setText("10000")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(wpStartx+width*wpW*0.65, wpStarty-height*wpH*0.4-w)
    		.setFontSize(15, 1);
    	me.wpTextSpeedDesc = me.wpTextField.createChild("text")
    		.setText("M")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(wpStartx+width*wpW*0.15, wpStarty-height*wpH*0.2-w)
    		.setFontSize(15, 1);
    	me.wpTextSpeed = me.wpTextField.createChild("text")
    		.setText("300")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(wpStartx+width*wpW*0.65, wpStarty-height*wpH*0.2-w)
    		.setFontSize(15, 1);
    	me.wpTextETADesc = me.wpTextField.createChild("text")
    		.setText("ETA")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(wpStartx+width*wpW*0.15, wpStarty-height*wpH*0.0-w)
    		.setFontSize(15, 1);
    	me.wpTextETA = me.wpTextField.createChild("text")
    		.setText("3:43")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(wpStartx+width*wpW*0.65, wpStarty-height*wpH*0.0-w)
    		.setFontSize(15, 1);


    	# bottom txt field
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
    		.set("z-index", 10)
    		.setFontSize(10, 1);
    	me.textBLinkFrame1 = me.bottom_text_grp.createChild("path")
    		.moveTo(65, height-height*0.085)
    		.horiz(16)
    		.vert(12)
    		.horiz(-16)
    		.vert(-12)
    		.setColor(rWhite,gWhite,bWhite, a)
		    .setStrokeLineWidth(w);
		me.textBLinkFrame2 = me.bottom_text_grp.createChild("path")
    		.moveTo(65, height-height*0.085)
    		.horiz(16)
    		.vert(12)
    		.horiz(-16)
    		.vert(-12)
    		.setColor(rWhite,gWhite,bWhite, a)
    		.set("z-index", 1)
		    .setColorFill(rGreen, gGreen, bGreen, a)
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
    		.setFontSize(17, 1);
    	me.textBWeight = me.bottom_text_grp.createChild("text")
    		.setText("VIKT 13,4")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("right-top")
    		.setTranslation(width, height-height*0.085)
    		.setFontSize(17, 1);

    	me.menuMainRoot = root.createChild("group")
    		.set("z-index", 20)
    		.hide();
    	me.logRoot = root.createChild("group")
    		.set("z-index", 5)
    		.hide();
    	me.errorList = me.logRoot.createChild("text")
    		.setText("..OKAY..\n..OKAY..")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("left-top")
    		.setTranslation(0, 20)
    		.setFontSize(10, 1);

    	me.menuFastRoot = root.createChild("group")
    		.set("z-index", 20);
    		#.hide();

    	# text for outer menu items
		#
    	me.menuButton = [nil];
    	for(var i = 1; i <= 7; i+=1) {
			append(me.menuButton,
				me.menuFastRoot.createChild("text")
    				.setText("M\nE\nN\nY")
    				.setColor(rWhite,gWhite,bWhite, a)
    				.setAlignment("left-center")
    				.setTranslation(width*0.025, height*0.09+(i-1)*height*0.11)
    				.setFontSize(12.5, 1));
		}
		for(var i = 8; i <= 13; i+=1) {
			append(me.menuButton, me.menuMainRoot.createChild("text")
    			.setText("MAIN")
    			.setColor(rWhite,gWhite,bWhite, a)
    			.setAlignment("center-bottom")
    			.setPadding(0,0,0,0)
    			.setTranslation(width*0.135+(i-8)*width*0.1475, height)
    			.setFontSize(13, 1));
		}
    	for(var i = 14; i <= 20; i+=1) {
			append(me.menuButton,
				me.menuFastRoot.createChild("text")
    				.setText("M\nE\nN\nY")
    				.setColor(rWhite,gWhite,bWhite, a)
    				.setAlignment("right-center")
    				.setTranslation(width*0.975, height*0.09+(6-(i-14))*height*0.11)
    				.setFontSize(12.5, 1));
		}

		# boxes for outer menu items
		#
		me.menuButtonBox = [nil];
    	for(var i = 1; i <= 7; i+=1) {
			append(me.menuButtonBox,
				me.menuFastRoot.createChild("path")
    				.moveTo(width*0.025-3.125, height*0.09+(i-1)*height*0.11-6.25*4)
    				.horiz(6.25*2)
    				.vert(6.25*8)
    				.horiz(-6.25*2)
    				.vert(-6.25*8)
    				.setColor(rWhite,gWhite,bWhite, a)
		    		.setStrokeLineWidth(w));
		}
		for(var i = 8; i <= 13; i+=1) {
			append(me.menuButtonBox, me.menuMainRoot.createChild("path")
					.moveTo(width*0.135+((i-8)*width*0.1475)-6.25*3, height)
    				.horiz(6.25*6)
    				.vert(-6.25*2)
    				.horiz(-6.25*6)
    				.vert(6.25*2)
    				.setColor(rWhite,gWhite,bWhite, a)
		    		.setStrokeLineWidth(w));
		}
    	for(var i = 14; i <= 20; i+=1) {
			append(me.menuButtonBox,
				me.menuFastRoot.createChild("path")
					.moveTo(width*0.975+3.125, height*0.09+(6-(i-14))*height*0.11-6.25*4)
    				.horiz(-6.25*2)
    				.vert(6.25*8)
    				.horiz(6.25*2)
    				.vert(-6.25*8)
    				.setColor(rWhite,gWhite,bWhite, a)
		    		.setStrokeLineWidth(w));
		}

		# text for inner menu items
		#
		me.menuButtonSub = [nil];
		for(var i = 1; i <= 7; i+=1) {
			append(me.menuButtonSub,
				me.menuFastRoot.createChild("text")
    				.setText("M\nE\nN\nY")
    				.setColor(rWhite,gWhite,bWhite, a)
    				.setColorFill(rGrey,gGrey,bGrey, a)
    				.setAlignment("left-center")
    				.setTranslation(width*0.060, height*0.09+(i-1)*height*0.11)
    				.setFontSize(12.5, 1));
		}
		for(var i = 8; i <= 13; i+=1) {
			append(me.menuButtonSub, nil);
		}
    	for(var i = 14; i <= 20; i+=1) {
			append(me.menuButtonSub,
				me.menuFastRoot.createChild("text")
    				.setText("M\nE\nN\nY")
    				.setColor(rWhite,gWhite,bWhite, a)
    				.setColorFill(rGrey,gGrey,bGrey, a)
    				.setAlignment("right-center")
    				.setTranslation(width*0.940, height*0.09+(6-(i-14))*height*0.11)
    				.setFontSize(12.5, 1));
		}

		# boxes for inner menu items
		#
		me.menuButtonSubBox = [nil];
    	for(var i = 1; i <= 7; i+=1) {
			append(me.menuButtonSubBox,
				me.menuFastRoot.createChild("path")
    				.moveTo(width*0.060-3.125, height*0.09+(i-1)*height*0.11-6.25*4)
    				.horiz(6.25*2)
    				.vert(6.25*8)
    				.horiz(-6.25*2)
    				.vert(-6.25*8)
    				.setColor(rWhite,gWhite,bWhite, a)
		    		.setStrokeLineWidth(w));
		}
		for(var i = 8; i <= 13; i+=1) {
			append(me.menuButtonSubBox, nil);
		}
    	for(var i = 14; i <= 20; i+=1) {
			append(me.menuButtonSubBox,
				me.menuFastRoot.createChild("path")
					.moveTo(width*0.940+3.125, height*0.09+(6-(i-14))*height*0.11-6.25*4)
    				.horiz(-6.25*2)
    				.vert(6.25*8)
    				.horiz(6.25*2)
    				.vert(-6.25*8)
    				.setColor(rWhite,gWhite,bWhite, a)
		    		.setStrokeLineWidth(w));
		}

		me.base_grp = me.rootCenter.createChild("group")
			.set("z-index", 2);

		me.baseLargeText = [];
		me.baseLarge = [];

		for(var i = 0; i < maxBases; i+=1) {
			append(me.baseLarge,
				me.base_grp.createChild("path")
	               .moveTo(-20, 0)
	               .arcSmallCW(20, 20, 0, 40, 0)
	               .arcSmallCW(20, 20, 0, -40, 0)
	               .setStrokeLineWidth(w)
	               .setColor(rTyrk,gTyrk,bTyrk, a));
			append(me.baseLargeText,
				me.base_grp.createChild("text")
    				.setText("ICAO")
    				.setColor(rTyrk,gTyrk,bTyrk, a)
    				.setAlignment("center-center")
    				.setTranslation(0,0)
    				.hide()
    				.setFontSize(13, 1));
		}

		me.baseSmallText = [];
		me.baseSmall = [];

		for(var i = 0; i < maxBases; i+=1) {
			append(me.baseSmall,
				me.base_grp.createChild("path")
					# stipled circle
	               .moveTo(circlePos(5, 15)[0], circlePos(5, 15)[1])
	               .arcSmallCW(15, 15, 0, circlePos(40, 15)[0]-circlePos(5, 15)[0], circlePos(40, 15)[1]-circlePos(5, 15)[1])

	               .moveTo(circlePos(50, 15)[0], circlePos(50, 15)[1])
	               .arcSmallCW(15, 15, 0, circlePos(85, 15)[0]-circlePos(50, 15)[0], circlePos(85, 15)[1]-circlePos(50, 15)[1])

	               .moveTo(circlePos(95, 15)[0], circlePos(95, 15)[1])
	               .arcSmallCW(15, 15, 0, circlePos(130, 15)[0]-circlePos(95, 15)[0], circlePos(130, 15)[1]-circlePos(95, 15)[1])

	               .moveTo(circlePos(140, 15)[0], circlePos(140, 15)[1])
	               .arcSmallCW(15, 15, 0, circlePos(175, 15)[0]-circlePos(140, 15)[0], circlePos(175, 15)[1]-circlePos(140, 15)[1])

	               .moveTo(circlePos(185, 15)[0], circlePos(185, 15)[1])
	               .arcSmallCW(15, 15, 0, circlePos(220, 15)[0]-circlePos(185, 15)[0], circlePos(220, 15)[1]-circlePos(185, 15)[1])

	               .moveTo(circlePos(230, 15)[0], circlePos(230, 15)[1])
	               .arcSmallCW(15, 15, 0, circlePos(265, 15)[0]-circlePos(230, 15)[0], circlePos(265, 15)[1]-circlePos(230, 15)[1])

	               .moveTo(circlePos(275, 15)[0], circlePos(275, 15)[1])
	               .arcSmallCW(15, 15, 0, circlePos(310, 15)[0]-circlePos(275, 15)[0], circlePos(310, 15)[1]-circlePos(275, 15)[1])

	               .moveTo(circlePos(320, 15)[0], circlePos(320, 15)[1])
	               .arcSmallCW(15, 15, 0, circlePos(355, 15)[0]-circlePos(320, 15)[0], circlePos(355, 15)[1]-circlePos(320, 15)[1])

	               .setStrokeLineWidth(w)
	               .setColor(rTyrk,gTyrk,bTyrk, a));
			append(me.baseSmallText,
				me.base_grp.createChild("text")
    				.setText("ICA")
    				.setColor(rTyrk,gTyrk,bTyrk, a)
    				.setAlignment("center-center")
    				.setTranslation(0,0)
    				.hide()
    				.setFontSize(13, 1));
		}

		# flight data
		var fpi_min = 3;
		var fpi_med = 6;
		var fpi_max = 9;

		me.fpi = me.rootRealCenter.createChild("path")
		      .moveTo(texel_per_degree*fpi_max, -w*2)
		      .lineTo(texel_per_degree*fpi_min, -w*2)
		      .moveTo(texel_per_degree*fpi_max,  w*2)
		      .lineTo(texel_per_degree*fpi_min,  w*2)
		      .moveTo(texel_per_degree*fpi_max, 0)
		      .lineTo(texel_per_degree*fpi_min, 0)
		      .arcSmallCCW(texel_per_degree*fpi_min, texel_per_degree*fpi_min, 0, -texel_per_degree*fpi_med, 0)
		      .arcSmallCCW(texel_per_degree*fpi_min, texel_per_degree*fpi_min, 0,  texel_per_degree*fpi_med, 0)
		      .close()
		      .moveTo(-texel_per_degree*fpi_min, -w*2)
		      .lineTo(-texel_per_degree*fpi_max, -w*2)
		      .moveTo(-texel_per_degree*fpi_min,  w*2)
		      .lineTo(-texel_per_degree*fpi_max,  w*2)
		      .moveTo(-texel_per_degree*fpi_min,  0)
		      .lineTo(-texel_per_degree*fpi_max,  0)
		      #tail
		      .moveTo(-w*1, -texel_per_degree*fpi_min)
		      .lineTo(-w*1, -texel_per_degree*fpi_med)
		      .moveTo(w*1, -texel_per_degree*fpi_min)
		      .lineTo(w*1, -texel_per_degree*fpi_med)
		      .setStrokeLineWidth(w*2)
		      .setColor(rGB,gGB,bGB, a);

		
		me.horizon_group = me.rootRealCenter.createChild("group");
		me.horz_rot = me.horizon_group.createTransform();
		me.horizon_group2 = me.horizon_group.createChild("group");
		me.horizon_line = me.horizon_group2.createChild("path")
		                     .moveTo(-height*0.75, 0)
		                     .horiz(height*1.5)
		                     .setStrokeLineWidth(w*2)
		                     .setColor(rGB,gGB,bGB, a);
		me.horizon_alt = me.horizon_group2.createChild("text")
				.setText("????")
				.setFontSize((25/512)*width, 1.0)
		        .setAlignment("center-bottom")
		        .setTranslation(-width*1/3, -w*4)
		        .setColor(rGB,gGB,bGB, a);

		# ground
		me.ground_grp = me.rootRealCenter.createChild("group");
		me.ground2_grp = me.ground_grp.createChild("group");
		me.ground_grp_trans = me.ground2_grp.createTransform();
		me.groundCurve = me.ground2_grp.createChild("path")
				.moveTo(0,0)
				.lineTo( -30*texel_per_degree, 7.5*texel_per_degree)
				.moveTo(0,0)
				.lineTo(  30*texel_per_degree, 7.5*texel_per_degree)
				.moveTo( -30*texel_per_degree, 7.5*texel_per_degree)
				.lineTo( -60*texel_per_degree, 30*texel_per_degree)
				.moveTo(  30*texel_per_degree, 7.5*texel_per_degree)
				.lineTo(  60*texel_per_degree, 30*texel_per_degree)
				.setStrokeLineWidth(w*2)
		        .setColor(rGB,gGB,bGB, a);

		# Collision warning arrow
		me.arr_15  = 5*0.75;
		me.arr_30  = 5*1.5;
		me.arr_90  = 3*9;
		me.arr_120 = 3*12;

		me.arrow_group = me.rootRealCenter.createChild("group");  
		me.arrow_trans = me.arrow_group.createTransform();
		me.arrow =
		      me.arrow_group.createChild("path")
		      .setColor(rRed,gRed,bRed, a)
		      .setColorFill(rRed,gRed,bRed, a)
		      .moveTo(-me.arr_15*MM2TEX,  me.arr_90*MM2TEX)
		      .lineTo(-me.arr_15*MM2TEX, -me.arr_90*MM2TEX)
		      .lineTo(-me.arr_30*MM2TEX, -me.arr_90*MM2TEX)
		      .lineTo(  0,                         -me.arr_120*MM2TEX)
		      .lineTo( me.arr_30*MM2TEX, -me.arr_90*MM2TEX)
		      .lineTo( me.arr_15*MM2TEX, -me.arr_90*MM2TEX)
		      .lineTo( me.arr_15*MM2TEX,  me.arr_90*MM2TEX)
		      .setStrokeLineWidth(w);

		me.textTime = root.createChild("text")
    		.setText("h:min:s")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("right-top")
    		.setTranslation(width, 4)
    		.set("z-index", 7)
    		.setFontSize(13, 1);
	},

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
			tracks_enabled:   	  "ja37/hud/tracks-enabled",
			radar_serv:       	  "instrumentation/radar/serviceable",
			tenHz:            	  "ja37/blink/ten-Hz/state",
			qfeActive:        	  "ja37/displays/qfe-active",
	        qfeShown:		  	  "ja37/displays/qfe-shown",
	        station:          	  "controls/armament/station-select",
	        currentMode:          "ja37/hud/current-mode",
	        ctrlRadar:        	  "controls/altimeter-radar",
	        acInstrVolt:      	  "systems/electrical/outputs/ac-instr-voltage",
	        nav0InRange:      	  "instrumentation/nav[0]/in-range",
	        fullMenus:            "ja37/displays/show-full-menus",
	        APLockHeading:    "autopilot/locks/heading",
	        APTrueHeadingErr: "autopilot/internal/true-heading-error-deg",
	        APnav0HeadingErr: "autopilot/internal/nav1-heading-error-deg",
	        APHeadingBug:     "autopilot/settings/heading-bug-deg",
	        RMWaypointBearing:"autopilot/route-manager/wp/bearing-deg",
	        RMActive:         "autopilot/route-manager/active",
	        nav0Heading:      "instrumentation/nav[0]/heading-deg",
	        ias:              "instrumentation/airspeed-indicator/indicated-speed-kt",
      	};
   
      	foreach(var name; keys(ti.input)) {
        	ti.input[name] = props.globals.getNode(ti.input[name], 1);
      	}

      	ti.setupCanvasSymbols();
      	ti.day = TRUE;
      	ti.setupMap();

      	ti.lastRRT = 0;
		ti.lastRR  = 0;
		ti.lastZ   = 0;


		ti.brightness = 1;

		ti.menuShowMain = FALSE;
		ti.menuShowFast = FALSE;
		ti.menuMain     = -MAIN_SYSTEMS;
		ti.menuTrap     = FALSE;
		ti.menuSvy      = FALSE;
		ti.menuGPS      = FALSE;
		ti.quickTimer   = -25;
		ti.trapFire     = FALSE;
		ti.trapMan      = FALSE;
		ti.trapLock     = FALSE;
		ti.trapECM      = FALSE;

		ti.upText = FALSE;
		ti.logPage = 0;
		ti.off = FALSE;
		ti.showFullMenus = TRUE;
		ti.displayFlight = FLIGHTDATA_OFF;
		ti.displayTime = FALSE;
		ti.ownPosition = 0.25;
		ti.mapPlaces = CLEANMAP;
		ti.showSteers = TRUE;
		ti.showSteerPoly = FALSE;
		ti.ModeAttack = TRUE;
		ti.GPSinit    = FALSE;
		ti.fr28Top    = FALSE;
		ti.dataLink   = FALSE;
		ti.mapshowing = TRUE;
		ti.basesNear  = [];
		ti.basesEnabled = FALSE;
		ti.logEvents  = events.LogBuffer.new(echo: 0);#compatible with older FG?		
		ti.logBIT     = events.LogBuffer.new(echo: 0);#compatible with older FG?
		ti.BITon = FALSE;
		ti.BITtime = 0;
		ti.BITok1 = FALSE;
		ti.BITok2 = FALSE;
		ti.BITok3 = FALSE;
		ti.BITok4 = FALSE;
		ti.active = TRUE;
		

      	return ti;
	},



	########################################################################################################
	########################################################################################################
	#
	#  begin main loops
	#
	#
	########################################################################################################
	########################################################################################################



	loop: func {
		#if ( gone == TRUE) {
		#	return;
		#}
		me.interoperability = me.input.units.getValue();

		if (bright > 0) {
			bright -= 1;
			me.brightness -= 0.25;
			if (me.brightness < 0.25) {
				me.brightness = 1;
			}
		}
		if (me.input.acInstrVolt.getValue() < 100 or me.off == TRUE) {
			setprop("ja37/avionics/brightness-ti", 0);
			#setprop("ja37/avionics/cursor-on", FALSE);
			settimer(func me.loop(), 0.25);
			return;
		} else {
			setprop("ja37/avionics/brightness-ti", me.brightness);
			#setprop("ja37/avionics/cursor-on", cursorOn);
		}
		if (me.day == TRUE) {
			mycanvas.setColorBackground(0.3, 0.3, 0.3, 1.0);
		} else {
			mycanvas.setColorBackground(0.15, 0.15, 0.15, 1.0);
		}

		me.updateMap();
		me.showMapScale();
		M2TEX = 1/(meterPerPixel[zoom]*math.cos(getprop('/position/latitude-deg')*D2R));
		me.showSelfVector();
		me.displayRadarTracks();
		me.showRunway();
		me.showRadarLimit();
		me.showBottomText();# must be after displayRadarTracks
		me.menuUpdate();
		me.showTime();
		me.showSteerPoints();
		me.showSteerPointInfo();
		me.showPoly();#must be under showSteerPoints
		me.showTargetInfo();#must be after displayRadarTracks
		me.showBasesNear();
		

		settimer(func me.loop(), 0.5);
	},

	loopFast: func {
		if (me.input.acInstrVolt.getValue() < 100 or me.off == TRUE) {
			settimer(func me.loopFast(), 0.05);
			return;
		} else {
		}
		me.updateFlightData();
		me.showHeadingBug();

		settimer(func me.loopFast(), 0.05);
	},

	loopSlow: func {
		if (me.input.acInstrVolt.getValue() < 100 or me.off == TRUE) {
			settimer(func me.loopSlow(), 0.05);
			return;
		} else {
		}
		me.updateBasesNear();

		settimer(func me.loopSlow(), 180);
	},



	########################################################################################################
	########################################################################################################
	#
	#  menu display
	#
	#
	########################################################################################################
	########################################################################################################



	menuUpdate: func {
		#
		# Update the display of the menus
		#
		if (me.BITon == FALSE) {
			me.showFullMenus = me.input.fullMenus.getValue();
			if (me.menuShowMain == FALSE and me.menuShowFast == TRUE) {
				if (me.input.timeElapsed.getValue() - me.quickTimer > me.quickOpen) {
					# close quick menu after 20 seconds, or after 3 seconds of a sidebutton press.
					me.menuShowFast = FALSE;
					me.menuMain = -MAIN_SYSTEMS;
					me.menuNoSub();
				}
			}
			if (me.menuShowMain == TRUE) {
				#me.menuShowFast = TRUE;#figure this out better
				me.menuMainRoot.show();
				me.updateMainMenu();
				me.upText = TRUE;
			} elsif (me.menuShowMain == FALSE and me.menuShowFast == TRUE) {
				me.menuMainRoot.hide();
				me.upText = FALSE;
			} else {
				me.menuMainRoot.hide();
				me.upText = FALSE;
			}
			if (me.menuShowFast == TRUE) {
				me.menuFastRoot.show();
				me.updateFastMenu();
				me.updateFastSubMenu();
			} else {
				me.menuFastRoot.hide();
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == TRUE) {
				if (me.trapFire == TRUE) {
					me.hideMap();
					me.logRoot.show();
					call(func {
						var buffer = armament.fireLog.get_buffer();
						var str = "       Fire log:\n";
		    			foreach(entry; buffer) {
		      				str = str~"    "~entry.time~" "~entry.message~"\n";
		    			}
						me.errorList.setText(str);
					});
					me.clipLogPage();
				} elsif (me.trapMan == TRUE) {
					me.hideMap();
					me.logRoot.show();
					call(func {
						var buffer = me.logEvents.get_buffer();
						var str = "       Event log:\n";
		    			foreach(entry; buffer) {
		      				str = str~"    "~entry.time~" "~entry.message~"\n";
		    			}
						me.errorList.setText(str);
					});
					me.clipLogPage();
				} elsif (me.trapLock == TRUE) {
					me.hideMap();
					me.logRoot.show();
					call(func {
						var buffer = radar_logic.lockLog.get_buffer();
						var str = "       Lock log:\n";
		    			foreach(entry; buffer) {
		      				str = str~"    "~entry.time~" "~entry.message~"\n";
		    			}
						me.errorList.setText(str);
					});
					me.clipLogPage();
				} elsif (me.trapECM == TRUE) {
					me.hideMap();
					me.logRoot.show();
					call(func {
						var buffer = armament.ecmLog.get_buffer();
						var str = "       ECM log:\n";
		    			foreach(entry; buffer) {
		      				str = str~"    "~entry.time~" "~entry.message~"\n";
		    			}
						me.errorList.setText(str);
					});
					me.clipLogPage();
				} else{
					me.showMap();
				}
			} elsif (me.menuMain == MAIN_FAILURES) {
				# failure menu
				me.hideMap();
				me.logRoot.show();
				call(func {
					var buffer = FailureMgr.get_log_buffer();
					var str = "       Failure log:\n";
	    			foreach(entry; buffer) {
	      				str = str~"    "~entry.time~" "~entry.message~"\n";
	    			}
					me.errorList.setText(str);
				});
				me.clipLogPage();
			} else {
				me.showMap();
			}
		} else {
			me.menuMainRoot.hide();
			me.menuFastRoot.hide();
			me.hideMap();
			me.logRoot.show();
			call(func {
				var buffer = me.logBIT.get_buffer();
				var str = "       RB-99 Build In Test (BIT) log:\n";
    			foreach(entry; buffer) {
      				str = str~"    "~entry.time~" "~entry.message~"\n";
    			}
				me.errorList.setText(str);
			});
			me.clipLogPage();

			# improve this crap programming:
			if (me.input.timeElapsed.getValue()-me.BITtime > armament.count99()*2+5) {
				me.BITon = FALSE;
				me.active = TRUE;
			} elsif (me.input.timeElapsed.getValue()-me.BITtime > 8 and me.BITok4 == FALSE) {
				if (armament.count99() > 3)
					me.logBIT.push("RB-99: ....OK");
				me.BITok4 = TRUE;
			} elsif (me.input.timeElapsed.getValue()-me.BITtime > 6 and me.BITok3 == FALSE) {
				if (armament.count99() > 2)
					me.logBIT.push("RB-99: ....OK");
				me.BITok3 = TRUE;
			} elsif (me.input.timeElapsed.getValue()-me.BITtime > 4 and me.BITok2 == FALSE) {
				if (armament.count99() > 1)
					me.logBIT.push("RB-99: ....OK");
				me.BITok2 = TRUE;
			} elsif (me.input.timeElapsed.getValue()-me.BITtime > 2 and me.BITok1 == FALSE) {
				if (armament.count99() > 0)
					me.logBIT.push("RB-99: ....OK");
				me.BITok1 = TRUE;
			}
		}
	},

	clipLogPage: func {
		me.logRoot.setTranslation(0,  -(height-height*0.025*me.upText)*me.logPage);
		me.clip2 = 0~"px, "~width~"px, "~(height-height*0.025*me.upText)~"px, "~0~"px";
		me.logRoot.set("clip", "rect("~me.clip2~")");#top,right,bottom,left
	},

	showMap: func {
		#
		# Reveal map and its overlays
		#
		me.logPage = 0;
		me.mapCentrum.show();
		me.rootCenter.show();
		me.logRoot.hide();
		me.navBugs.show();
		me.bottom_text_grp.show();
		me.mapshowing = TRUE;
	},

	hideMap: func {
		#
		# Hide map and its overlays (due to a log page being displayed)
		#
		me.mapCentrum.hide();
		me.rootCenter.hide();
		me.bottom_text_grp.hide();
		me.navBugs.hide();
		me.mapshowing = FALSE;
	},

	updateMainMenu: func {
		#
		# Update the display of the main menus
		#
		for(var i = MAIN_WEAPONS; i <= MAIN_CONFIGURATION; i+=1) {
			me.menuButton[i].setText(me.compileMainMenu(i));
			if (me.menuMain == MAIN_WEAPONS) {
				me.updateMainMenuTextWeapons(i);
			} else {
				if (me.menuMain == i) {
					me.menuButtonBox[i].show();
				} else {
					me.menuButtonBox[i].hide();
				}
			}
		}
		if (me.menuMain == MAIN_WEAPONS) {
			if (me.input.station.getValue() == 5) {
				me.menuButtonBox[8].show();
			} else {
				me.menuButtonBox[8].hide();
			}
			if (me.input.station.getValue() == 1) {
				me.menuButtonBox[9].show();
			} else {
				me.menuButtonBox[9].hide();
			}
			if (me.input.station.getValue() == 2) {
				me.menuButtonBox[10].show();
			} else {
				me.menuButtonBox[10].hide();
			}
			if (me.input.station.getValue() == 4) {
				me.menuButtonBox[11].show();
			} else {
				me.menuButtonBox[11].hide();
			}
			if (me.input.station.getValue() == 3) {
				me.menuButtonBox[12].show();
			} else {
				me.menuButtonBox[12].hide();
			}
			if (me.input.station.getValue() == 6) {
				me.menuButtonBox[13].show();
			} else {
				me.menuButtonBox[13].hide();
			}
		}
	},

	updateMainMenuTextWeapons: func (position) {
		var pyl = 0;
		if (position == 8) {
			pyl = 5;
		} elsif (position == 9) {
			pyl = 1;
		} elsif (position == 10) {
			pyl = 2;
		} elsif (position == 11) {
			pyl = 4;
		} elsif (position == 12) {
			pyl = 3;
		} elsif (position == 13) {
			pyl = 6;
		}
		me.pylon = displays.common.armNamePylon(pyl);
		if (me.pylon != nil) {
			me.menuButton[position].setText(me.pylon);
		}
	},

	compileMainMenu: func (button) {
		var str = nil;
		if (me.interoperability == displays.METRIC) {
			str = dictSE[me.menuGPS==TRUE?"GPS":(me.menuTrap==TRUE?"TRAP":(me.menuSvy==TRUE?"SVY":''~math.abs(me.menuMain)))];
		} else {
			str = dictEN[me.menuGPS==TRUE?"GPS":(me.menuTrap==TRUE?"TRAP":(me.menuSvy==TRUE?"SIDE":''~math.abs(me.menuMain)))];
		}
		if (str != nil) {
			str = str[''~button];
			if (str != nil and (me.showFullMenus == TRUE or str[0] == TRUE)) {
				return str[1];
			}
		}
		return "";
	},

	updateFastMenu: func {
		#
		# Update the display of the fast menus
		#
		for(var i = 1; i <= 7; i+=1) {
			me.menuButton[i].setText(me.compileFastMenu(i));
			me.menuButtonBox[i].hide();
		}
		for(var i = 14; i <= 20; i+=1) {
			me.menuButton[i].setText(me.compileFastMenu(i));
			me.menuButtonBox[i].hide();
		}
		if (me.menuMain == MAIN_WEAPONS and me.input.station.getValue() == 0) {
			me.menuButtonBox[14].show();
		}
		if (math.abs(me.menuMain) == MAIN_SYSTEMS) {
			if (me.menuTrap == FALSE and me.dataLink == TRUE) {
				me.menuButtonBox[2].show();
			}
			if (me.menuTrap == FALSE and me.showSteers == TRUE) {
				me.menuButtonBox[4].show();
			}
			if (me.menuTrap == FALSE and me.ModeAttack == FALSE) {
				me.menuButtonBox[14].show();
			}
			if (me.menuTrap == FALSE and me.showFullMenus == TRUE) {
				if (land.mode < 3 and land.mode > 0) {
					# landing before descent
					me.menuButtonBox[19].show();
				} elsif (land.mode > 2) {
					# landing descent
					me.menuButtonBox[18].show();
				} elsif (me.input.currentMode.getValue() == displays.LANDING) {
					# generic landing mode
					me.menuButtonBox[20].show();
				} elsif (me.showSteers == TRUE and me.input.rmActive.getValue() == TRUE) {
					# following route
					me.menuButtonBox[17].show();
				}
			}
			if (me.menuTrap == TRUE and me.trapLock == TRUE) {
				me.menuButtonBox[2].show();
			}
			if (me.menuTrap == TRUE and me.trapFire == TRUE) {
				me.menuButtonBox[3].show();
			}
			if (me.menuTrap == TRUE and me.trapECM == TRUE) {
				me.menuButtonBox[4].show();
			}
			if (me.menuTrap == TRUE and me.trapMan == TRUE) {
				me.menuButtonBox[5].show();
			}
			if (me.showSteerPoly == TRUE and me.menuTrap == FALSE) {
				me.menuButtonBox[5].show();
			}
		}
		if (me.menuMain == MAIN_DISPLAY) {
			if (me.mapPlaces == TRUE) {
				me.menuButtonBox[3].show();
			}
			if (me.basesEnabled == TRUE) {
				me.menuButtonBox[4].show();
			}
			if (me.displayTime == TRUE) {
				me.menuButtonBox[16].show();
			}
			if (me.day == TRUE) {
				me.menuButtonBox[19].show();
			}
		}
		if (me.menuMain == MAIN_CONFIGURATION and me.menuGPS == TRUE and me.GPSinit == TRUE) {
			me.menuButtonBox[15].show();
			if (radar_logic.selection != nil and radar_logic.selection.get_Callsign() == "FIX") {
				me.menuButtonBox[14].show();
			}
		}
	},

	compileFastMenu: func (button) {
		var str = nil;
		if (me.interoperability == displays.METRIC) {
			str = dictSE[me.menuGPS==TRUE?"GPS":(me.menuTrap==TRUE?"TRAP":(me.menuSvy==TRUE?"SVY":''~math.abs(me.menuMain)))];
		} else {
			str = dictEN[me.menuGPS==TRUE?"GPS":(me.menuTrap==TRUE?"TRAP":(me.menuSvy==TRUE?"SIDE":''~math.abs(me.menuMain)))];
		}
		if (str != nil) {
			str = str[''~button];
			if (str != nil and (me.showFullMenus == TRUE or str[0] == TRUE)) {
				return me.vertStr(str[1]);
			}
		}
		return "";
	},

	vertStr: func (str) {
		var compiled = "";
		for(var i = 0; i < size(str); i+=1) {
			compiled = compiled ~substr(str,i,1)~(i==(size(str)-1)?"":"\n");
		}
		return compiled;
	},

	updateFastSubMenu: func {
		#
		# Update the display of the fast inner menu items.
		#
		for(var i = 1; i <= 7; i+=1) {
			me.menuButtonSub[i].hide();
			me.menuButtonSubBox[i].hide();
		}
		for(var i = 14; i <= 20; i+=1) {
			me.menuButtonSub[i].hide();
			me.menuButtonSubBox[i].hide();
		}
		# button 7 is always showing stuff
		me.menuButtonSub[7].show();
		me.menuButtonSubBox[7].show();
		var seven = nil;
		if (me.interoperability == displays.METRIC) {
			seven = me.menuGPS==TRUE?"GPS":(me.menuTrap==TRUE?"TRAP":(me.menuSvy==TRUE?"SVY":(dictSE['0'][''~math.abs(me.menuMain)][1])));
		} else {
			seven = me.menuGPS==TRUE?"GPS":(me.menuTrap==TRUE?"TRAP":(me.menuSvy==TRUE?"SIDE":(dictEN['0'][''~math.abs(me.menuMain)][1])));
		}
		me.menuButtonSub[7].setText(me.vertStr(seven));
		if (me.menuMain == MAIN_DISPLAY) {
			#show flight data
			me.menuButtonSub[17].show();
			me.menuButtonSubBox[17].show();
			var seventeen = nil;
			if (me.interoperability == displays.METRIC) {
				seventeen = dictSE['HORI'][''~me.displayFlight][1];
			} else {
				seventeen = dictEN['HORI'][''~me.displayFlight][1];
			}
			me.menuButtonSub[17].setText(me.vertStr(seventeen));

			# zoom level
			me.menuButtonSub[6].show();
			me.menuButtonSubBox[6].show();
			var six = zoomLevels[zoom_curr]~"";
			me.menuButtonSub[6].setText(me.vertStr(six));

			# day/night map
			me.menuButtonSub[19].setText(me.vertStr(me.interoperability == displays.METRIC?"NATT":"NGHT"));
			me.menuButtonSub[19].show();
			if (me.day == FALSE) {
				me.menuButtonSubBox[19].show();
			}
		}
		if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
			# radar in attack or fight mode
			var ft = nil;
			if (me.interoperability == displays.METRIC) {
				ft = "ATT";
			} else {
				ft = "ATT";
			}
			me.menuButtonSub[14].setText(me.vertStr(ft));
			if (me.ModeAttack == TRUE) {
				me.menuButtonSubBox[14].show();
			}
			me.menuButtonSub[14].show();
		}
		if (me.menuMain == MAIN_CONFIGURATION and me.menuGPS == FALSE and me.menuSvy == FALSE) {
			# use top or belly antaenna
			var ant = nil;
			if (me.interoperability == displays.METRIC) {
				ant = me.fr28Top==TRUE?"RYG":"BUK";
			} else {
				ant = me.fr28Top==TRUE?"OVER":"UNDR";
			}
			me.menuButtonSub[6].setText(me.vertStr(ant));
			me.menuButtonSub[6].show();
			me.menuButtonSubBox[6].show();
		}
	},

	menuNoSub: func {
		#
		# Make sure none of the sub main menus are active
		#
		me.menuTrap = FALSE;
		me.menuSvy  = FALSE;
		me.menuGPS  = FALSE;
		me.trapFire = FALSE;
		me.trapMan = FALSE;
		me.trapLock = FALSE;
		me.trapECM  = FALSE;
	},





	########################################################################################################
	########################################################################################################
	#
	#  MI functions
	#
	#
	########################################################################################################
	########################################################################################################


	showSVY: func {
		# side view
		if (!me.active) return;
		me.menuMain = MAIN_CONFIGURATION;
		me.menuNoSub();			
		me.menuSvy = TRUE;
		me.menuShowMain = TRUE;
		me.menuShowFast = TRUE;
	},

	showECM: func {
		# ECM and warnings
		if (!me.active) return;

		# tact ecm report (todo: show current ecm instead)
		me.menuMain = MAIN_SYSTEMS;
		me.menuNoSub();
		me.menuTrap = TRUE;
		me.menuShowFast = TRUE;
		me.menuShowMain = TRUE;
		me.trapECM = TRUE;
		me.trapLock = FALSE;
		me.trapFire = FALSE;
		me.trapMan = FALSE;
		me.quickOpen = 10000;
	},

	showLNK: func {
		# show RB99 link
		if (!me.active) return;
		
	},

	doBIT: func {
		# test RB99
		if (!me.active) return;
		me.active = FALSE;
		me.BITon = TRUE;
		me.BITtime = me.input.timeElapsed.getValue();
		me.BITok1 = FALSE;
		me.BITok2 = FALSE;
		me.BITok3 = FALSE;
		me.BITok4 = FALSE;
	},

	recordEvent: func {
		# mark event
		#
		var tgt = "";
		if(radar_logic.selection != nil) {
			tgt = radar_logic.selection.get_Callsign();
		}
		var message = sprintf("\n      IAS: %d kt\n      Heading: %d deg\n      Alt: %d ft\n      Selected: %s\n      Echoes: %d\n      Lat: %.4f deg\n      Lon: %.4f deg",
			me.input.ias.getValue(),
			me.input.headMagn.getValue(),
			me.input.alt_ft.getValue(),
			tgt,
			size(radar_logic.tracks),
			getprop("position/latitude-deg"),
			getprop("position/longitude-deg")
			);
		me.logEvents.push(message);
	},


	########################################################################################################
	########################################################################################################
	#
	#  misc overlays
	#
	#
	########################################################################################################
	########################################################################################################

	

	updateBasesNear: func {
		if (me.basesEnabled == TRUE) {
			me.basesNear = [];
			me.ports = findAirportsWithinRange(75);
			foreach(var port; me.ports) {
				var small = size(port.id) < 4;
			    append(me.basesNear, {"icao": port.id, "lat": port.lat, "lon": port.lon, "elev": port.elevation, "small": small});
			}
		}
	},

	showBasesNear: func {
		if (me.basesEnabled == TRUE and zoom_curr >= 2) {
			var numL = 0;
			var numS = 0;
			foreach(var base; me.basesNear) {
				if (base["icao"] != land.icao) {
					me.coord = geo.Coord.new();
					me.coord.set_latlon(base["lat"], base["lon"], base["elev"]);
					if (me.coord.distance_to(geo.aircraft_position()) < height/M2TEX) {
			    		me.baseIcao = base["icao"];
			    		if (size(me.baseIcao) != nil and me.baseIcao != "") {
				    		me.small = base["small"];
				    		me.baseGPS = radar_logic.ContactGPS.new(me.baseIcao, me.coord);
				    		me.polar = me.baseGPS.get_polar();
				    		me.distance = me.polar[0];
				            me.xa_rad   = me.polar[1];
				      		me.pixelDistance = -me.distance*M2TEX; #distance in pixels
				      		#translate from polar coords to cartesian coords
				      		me.pixelX =  me.pixelDistance * math.cos(me.xa_rad + math.pi/2);
				      		me.pixelY =  me.pixelDistance * math.sin(me.xa_rad + math.pi/2);
				      		if (me.small == TRUE) {
					      		if (numS < maxBases) {
					      			me.baseSmall[numS].setTranslation(me.pixelX, me.pixelY);
					      			me.baseSmallText[numS].setTranslation(me.pixelX, me.pixelY);
					      			me.baseSmallText[numS].setText(me.baseIcao);
					      			me.baseSmallText[numS].setRotation(-getprop("orientation/heading-deg")*D2R);
					      			me.baseSmall[numS].show();
					      			me.baseSmallText[numS].show();
					      			numS += 1;
					      		}
				      		} else {
				      			if (numL < maxBases) {
				      				me.baseLarge[numL].setTranslation(me.pixelX, me.pixelY);
					      			me.baseLargeText[numL].setTranslation(me.pixelX, me.pixelY);
					      			me.baseLargeText[numL].setText(me.baseIcao);
					      			me.baseLargeText[numL].show();
					      			me.baseLargeText[numL].setRotation(-getprop("orientation/heading-deg")*D2R);
					      			me.baseLarge[numL].show();
					      			numL += 1;
					      		}
				      		}
				      	}
			    	}
			    }
			}
			for(var i = numL; i < maxBases; i += 1) {
				me.baseLargeText[i].hide();
				me.baseLarge[i].hide();
			}
			for(var i = numS; i < maxBases; i += 1) {
				me.baseSmallText[i].hide();
				me.baseSmall[i].hide();
			}
			me.base_grp.show();
		} else {
			me.base_grp.hide();
		}
	},

	showMapScale: func {
		if (me.mapshowing == TRUE and me.menuShowFast == FALSE) {
			var tick1 = 0;
			var tick2 = 0;
			var tick3 = 0;
			if (me.interoperability == displays.METRIC) {
				if (zoom == 4) {
					tick1 = 1000;
				} elsif (zoom == 7) {
					tick1 = 150;
				} elsif (zoom == 9) {
					tick1 = 35;
				} elsif (zoom == 11) {
					tick1 = 10;
				} elsif (zoom == 13) {
					tick1 = 2;
				}
				tick2 = tick1*2;
				tick3 = tick1*3;
				me.mapScaleTick1.setTranslation(0, -tick1*M2TEX*1000);
				me.mapScaleTick1Txt.setTranslation(me.mapScaleTickPosTxtX, -tick1*M2TEX*1000);
				me.mapScaleTick2.setTranslation(0, -tick2*M2TEX*1000);
				me.mapScaleTick2Txt.setTranslation(me.mapScaleTickPosTxtX, -tick2*M2TEX*1000);
				me.mapScaleTick3.setTranslation(0, -tick3*M2TEX*1000);
				me.mapScaleTick3Txt.setTranslation(me.mapScaleTickPosTxtX, -tick3*M2TEX*1000);
				me.mapScaleTick1Txt.setText(""~tick1);
				me.mapScaleTick2Txt.setText(""~tick2);
				me.mapScaleTick3Txt.setText(""~tick3);
				me.mapScaleTickM1.setTranslation(0, tick1*M2TEX*1000);
				me.mapScaleTickM1Txt.setTranslation(me.mapScaleTickPosTxtX, tick1*M2TEX*1000);
				me.mapScaleTickM2.setTranslation(0, tick2*M2TEX*1000);
				me.mapScaleTickM2Txt.setTranslation(me.mapScaleTickPosTxtX, tick2*M2TEX*1000);
				me.mapScaleTickM3.setTranslation(0, tick3*M2TEX*1000);
				me.mapScaleTickM3Txt.setTranslation(me.mapScaleTickPosTxtX, tick3*M2TEX*1000);
				me.mapScaleTickM1Txt.setText("-"~tick1);
				me.mapScaleTickM2Txt.setText("-"~tick2);
				me.mapScaleTickM3Txt.setText("-"~tick3);
			} else {
				if (zoom == 4) {
					tick1 = 500;
				} elsif (zoom == 7) {
					tick1 =  75;
				} elsif (zoom == 9) {
					tick1 =  20;
				} elsif (zoom == 11) {
					tick1 =   4;
				} elsif (zoom == 13) {
					tick1 =   1;
				}
				tick2 = tick1*2;
				tick3 = tick1*3;
				me.mapScaleTick1.setTranslation(0, -tick1*M2TEX*NM2M);
				me.mapScaleTick1Txt.setTranslation(me.mapScaleTickPosTxtX, -tick1*M2TEX*NM2M);
				me.mapScaleTick2.setTranslation(0, -tick2*M2TEX*NM2M);
				me.mapScaleTick2Txt.setTranslation(me.mapScaleTickPosTxtX, -tick2*M2TEX*NM2M);
				me.mapScaleTick3.setTranslation(0, -tick3*M2TEX*NM2M);
				me.mapScaleTick3Txt.setTranslation(me.mapScaleTickPosTxtX, -tick3*M2TEX*NM2M);
				me.mapScaleTick1Txt.setText(""~tick1);
				me.mapScaleTick2Txt.setText(""~tick2);
				me.mapScaleTick3Txt.setText(""~tick3);
				me.mapScaleTickM1.setTranslation(0, tick1*M2TEX*NM2M);
				me.mapScaleTickM1Txt.setTranslation(me.mapScaleTickPosTxtX, tick1*M2TEX*NM2M);
				me.mapScaleTickM2.setTranslation(0, tick2*M2TEX*NM2M);
				me.mapScaleTickM2Txt.setTranslation(me.mapScaleTickPosTxtX, tick2*M2TEX*NM2M);
				me.mapScaleTickM3.setTranslation(0, tick3*M2TEX*NM2M);
				me.mapScaleTickM3Txt.setTranslation(me.mapScaleTickPosTxtX, tick3*M2TEX*NM2M);
				me.mapScaleTickM1Txt.setText("-"~tick1);
				me.mapScaleTickM2Txt.setText("-"~tick2);
				me.mapScaleTickM3Txt.setText("-"~tick3);
			}
			me.mapScale.show();
		} else {
			me.mapScale.hide();
		}
	},
	showTargetInfo: func {
		if (me.mapshowing == TRUE and me.input.currentMode.getValue() == displays.COMBAT and radar_logic.selection != nil and radar_logic.selection.isPainted() == TRUE) {
			# this is info about the locked target.
    	
	  		if (me.tgt_dist != nil) {
	  			# distance
	  			if (me.interoperability == displays.METRIC) {
	  	  			me.tgtTextDistDesc.setText("A");
					if (me.tgt_dist < 10000) {
						me.distText = sprintf("%d", me.tgt_dist/1000);
					} else {
						me.distText = sprintf("%.1f", me.tgt_dist/1000);
					}
					me.tgtTextDist.setText(me.distText);
	  			} else {
	  				me.tgtTextDistDesc.setText("D");
					if (me.tgt_dist*M2NM > 10) {
						me.distText = sprintf("%d", me.tgt_dist*M2NM);
					} else {
						me.distText = sprintf("%.1f", me.tgt_dist*M2NM);
					}
					me.tgtTextDist.setText(me.distText);
	  			}
	  		} else {
	  			me.tgtTextDist.setText("");
	  		}
	  		
	  		if (me.tgt_alt != nil) {
	  			# altitude
	  			me.alt = me.tgt_alt;
	  			me.text = "";
				if (me.interoperability == displays.METRIC) {
					me.tgtTextHeiDesc.setText("H");
					if(me.alt < 1000) {
						me.text = ""~int(roundabout(me.alt/10)*10);
					} else {
						me.text = sprintf("%.1f", me.alt/1000);
					}
				} else {
					me.tgtTextHeiDesc.setText("A");
					if(me.alt*M2FT < 1000) {
						me.text = ""~int(roundabout(me.alt*M2FT/10)*10);
					} else {
						me.text = sprintf("%.1f", me.alt*M2FT/1000);
					}
				}
	  	  		me.tgtTextHei.setText(me.text);

	  	  		if (radar_logic.selection != nil) {
		    		# speed
		    		me.tgt_speed_kt = radar_logic.selection.get_Speed();
		    		me.rs = armament.AIM.rho_sndspeed(me.alt*M2FT);
					me.sound_fps = me.rs[1];
		    		me.speed_m = (me.tgt_speed_kt*KT2FPS) / me.sound_fps;
		  	  		me.tgtTextSpd.setText(sprintf("%.2f", me.speed_m));
		  		} else {
		  			me.tgtTextSpd.setText("");
		  		}
	  		} else {
	  			me.tgtSpdAlt.setText("");
	  			me.tgtTextAlt.setText("");
	  		}
			me.tgtTextField.show();
		} else {
			me.tgtTextField.hide();
		}
	},	

	showSteerPointInfo: func {
		# little infobox with details about next steerpoint
		me.wp     = getprop("autopilot/route-manager/current-wp");
		if (me.mapshowing == TRUE and getprop("autopilot/route-manager/active") == TRUE and me.wp != -1 and me.wp != nil and me.showSteers == TRUE and (me.input.currentMode.getValue() != displays.COMBAT or (radar_logic.selection == nil or radar_logic.selection.isPainted() == FALSE))) {
			# steerpoints ON and route active, plus not being in combat and having something selected by radar
			# that if statement needs refining!
			
			me.node   = globals.props.getNode("autopilot/route-manager/route/wp["~me.wp~"]");

			me.wpNum  = me.wp+1;
			me.points = getprop("autopilot/route-manager/route/num");
			me.legs   = me.points-1;
			me.legText = (me.legs==0 or me.wpNum == 1)?"":(me.wpNum-1)~(me.interoperability==displays.METRIC?" AV ":" OF ")~me.legs;

			me.wpAlt  = me.node.getNode("altitude-ft").getValue();
			if (me.wpAlt == nil) {
				me.wpAlt = "";
			} elsif (me.wpAlt < 5000) {
				me.wpAlt = "";
			} else {
				# bad coding, shame on me..
				me.wpAlt  = me.interoperability==displays.METRIC?me.wpAlt*FT2M:me.wpAlt;
				me.wpAlt = sprintf("%d", me.wpAlt);
			}
			me.wpSpeed= getprop("autopilot/route-manager/cruise/speed-kts");
			me.wpETA  = int(getprop("autopilot/route-manager/ete")/60);#mins
			me.wpETAText = sprintf("%d", me.wpETA);
			if (me.wpETA > 500) {
				me.wpETAText = "";
			}

			me.wpTextNumDesc.setText(me.interoperability==displays.METRIC?"BEN":"LEG");
			me.wpTextNum.setText(me.legText);
			me.wpTextPosDesc.setText(me.interoperability==displays.METRIC?"B":"SP");
			me.wpTextPos.setText((me.wpNum-1)~" -> "~me.wpNum);
			me.wpTextAltDesc.setText(me.interoperability==displays.METRIC?"H":"A");
			me.wpTextAlt.setText(me.wpAlt);
			me.wpTextSpeedDesc.setText(me.interoperability==displays.METRIC?"KMH":"KT");
			me.wpTextSpeed.setText(sprintf("%d", me.interoperability==displays.METRIC?me.wpSpeed*KT2KMH:me.wpSpeed));
			me.wpTextETADesc.setText("ETA");
			me.wpTextETA.setText(me.wpETAText);
			me.wpTextField.show();
		} else {
			me.wpTextField.hide();
		}
	},

	showSteerPoints: func {
		# steerpoints on map
		me.points = getprop("autopilot/route-manager/route/num");
		me.poly = [];
		for (var wp = 0; wp < maxSteers; wp += 1) {
			if (me.points-1 >= wp and getprop("autopilot/route-manager/active") == TRUE) {
				me.node = globals.props.getNode("autopilot/route-manager/route/wp["~wp~"]");

  				if (me.node == nil or me.showSteers == FALSE) {
  					me.steerpoint[wp].hide();
    				continue;
  				}
				me.lat = me.node.getNode("latitude-deg");
  				me.lon = me.node.getNode("longitude-deg");
  				#me.alt = node.getNode("altitude-m").getValue();
				me.name = me.node.getNode("id");
				me.texCoord = me.laloToTexel();
				if (getprop("autopilot/route-manager/current-wp") == wp and land.showActiveSteer == FALSE) {
					me.steerpoint[wp].hide();
					if (wp != me.points-1) {
						# airport is not last steerpoint, we make a leg to/from that also
						append(me.poly, [me.texCoord[0], me.texCoord[1]]);
					}
    				continue;
				} elsif (getprop("autopilot/route-manager/current-wp") == wp) {
					me.steerpoint[wp].setColor(rTyrk,gTyrk,bTyrk,a);
					me.steerpoint[wp].set("z-index", 10);
					append(me.poly, [me.texCoord[0], me.texCoord[1]]);
				} else {
					me.steerpoint[wp].set("z-index", 5);
					me.steerpoint[wp].setColor(rDTyrk,gDTyrk,bDTyrk,a);
					append(me.poly, [me.texCoord[0], me.texCoord[1]]);
				}
				me.steerpoint[wp].setTranslation(me.texCoord[0], me.texCoord[1]);
  				me.steerpoint[wp].show();
			} else {
				me.steerpoint[wp].hide();
			}
  		}
  	},

  	laloToTexel: func {
		me.coord = geo.Coord.new();
  		me.coord.set_latlon(me.lat.getValue(), me.lon.getValue());
  		me.coordSelf = geo.aircraft_position();
  		me.angle = (me.coordSelf.course_to(me.coord)-me.input.headTrue.getValue())*D2R;
		me.pos_xx		 = -me.coordSelf.distance_to(me.coord)*M2TEX * math.cos(me.angle + math.pi/2);
		me.pos_yy		 = -me.coordSelf.distance_to(me.coord)*M2TEX * math.sin(me.angle + math.pi/2);
  		return [me.pos_xx, me.pos_yy];
  	},

  	showPoly: func {
  		# route polygon
  		if (me.showSteers == TRUE and me.showSteerPoly == TRUE and size(me.poly) > 1) {
  			me.steerPoly.removeAllChildren();
  			me.prevLeg = nil;
  			foreach(leg; me.poly) {
  				if (me.prevLeg != nil) {
  					me.steerPoly.createChild("path")
  						.moveTo(me.prevLeg[0], me.prevLeg[1])
  						.lineTo(leg[0], leg[1])
  						.setColor(rDTyrk,gDTyrk,bDTyrk,a)
  						.setStrokeLineWidth(w);
  				}
  				me.prevLeg = leg;
  			}
  			me.steerPoly.update();
  			me.steerPoly.show();
  		} else {
  			me.steerPoly.hide();
  		}
  	},

  	showTime: func {
		if (me.displayTime == TRUE) {
			me.textTime.setText(getprop("sim/time/gmt-string")~" Z  ");# should really be local time
			me.textTime.show();
		} else {
			me.textTime.hide();
		}
	},

	updateFlightData: func {
		me.fData = FALSE;
		if (getprop("ja37/sound/terrain-on") == TRUE) {
			me.fData = TRUE;
#			if (me.menuMain == 12 or (me.menuTrap == TRUE and me.trapFire == TRUE)) {
#				me.menuShowMain = FALSE;
#				me.menuShowFast = FALSE;
#				me.menuNoSub();
#				me.menuTrap = TRUE;
#				me.menuMain = 9;
#			}
		} elsif (me.displayFlight == FLIGHTDATA_ON) {
			me.fData = TRUE;
		} elsif (me.displayFlight == FLIGHTDATA_CLR and (me.input.alt_ft.getValue()*FT2M < 1000 or getprop("orientation/pitch-deg") > 10 or math.abs(getprop("orientation/roll-deg")) > 45)) {
			me.fData = TRUE;
		}
		if (me.fData == TRUE) {
			me.displayFPI();
			me.displayHorizon();
			me.displayGround();
			me.displayGroundCollisionArrow();
		} else {
			me.fpi.hide();
			me.horizon_group2.hide();
			me.ground_grp.hide();
			me.arrow.hide();
		}
	},

	displayFPI: func {
		me.fpi_x_deg = getprop("ja37/displays/fpi-horz-deg");
		me.fpi_y_deg = getprop("ja37/displays/fpi-vert-deg");
		if (me.fpi_x_deg == nil) {
			me.fpi_x_deg = 0;
			me.fpi_y_deg = 0;
		}
		me.fpi_x = me.fpi_x_deg*texel_per_degree;
		me.fpi_y = me.fpi_y_deg*texel_per_degree;
		me.fpi.setTranslation(me.fpi_x, me.fpi_y);
		me.fpi.show();
	},

	displayHorizon: func {
		me.rot = -getprop("orientation/roll-deg") * D2R;
		me.horz_rot.setRotation(me.rot);
		me.horizon_group2.setTranslation(0, texel_per_degree * getprop("orientation/pitch-deg"));
		me.alt = getprop("instrumentation/altimeter/indicated-altitude-ft");
		if (me.alt != nil) {
			me.text = "";
			if (me.interoperability == displays.METRIC) {
				if(me.alt*FT2M < 1000) {
					me.text = ""~roundabout(me.alt*FT2M/10)*10;
				} else {
					me.text = sprintf("%.1f", me.alt*FT2M/1000);
				}
			} else {
				if(me.alt < 1000) {
					me.text = ""~roundabout(me.alt/10)*10;
				} else {
					me.text = sprintf("%.1f", me.alt/1000);
				}
			}
			me.horizon_alt.setText(me.text);
		} else {
			me.horizon_alt.setText("");
		}
		me.horizon_group2.show();
	},

	displayGroundCollisionArrow: func () {
	    if (getprop("/instrumentation/terrain-warning") == TRUE) {
	      me.arrow_trans.setRotation(-getprop("orientation/roll-deg") * D2R);
	      me.arrow.show();
	    } else {
	      me.arrow.hide();
	    }
	},

	displayGround: func () {
		me.time = getprop("fdm/jsbsim/gear/unit[0]/WOW") == TRUE?0:getprop("fdm/jsbsim/systems/indicators/time-till-crash");
		if (me.time != nil and me.time >= 0 and me.time < 40) {
			me.timeC = clamp(me.time - 10,0,30);
			me.dist = (me.timeC/30) * (height/2);
			me.ground_grp.setTranslation(me.fpi_x, me.fpi_y);
			me.ground_grp_trans.setRotation(-getprop("orientation/roll-deg") * D2R);
			me.groundCurve.setTranslation(0, me.dist);
			if (me.time < 10 and me.time != 0) {
				me.groundCurve.setColor(rRed,gRed,bRed, a);
			} else {
				me.groundCurve.setColor(rGB,gGB,bGB, a);
			}
			me.ground_grp.show();
		} else {
			me.ground_grp.hide();
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
			if (me.ModeAttack == TRUE) {
				me.textBTactType1.setText("A");
				me.textBTactType2.setText("T");
				me.textBTactType3.setText("T");
			} else {
				me.textBTactType1.setText("J");
				me.textBTactType2.setText("K");
				me.textBTactType3.setText("T");
			}
		} else {
			if (me.ModeAttack == TRUE) {
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
		# RR: radar guided steering
		if (land.mode < 3 and land.mode > 0) {
			me.mode = me.interoperability == displays.METRIC?"LB":"LS";# landing steerpoint
		} elsif (land.mode > 2) {
			me.mode = me.interoperability == displays.METRIC?"LF":"LT";# landing touchdown point
		} elsif (me.input.currentMode.getValue() == displays.LANDING) {
			me.mode = "L ";# landing
		} elsif (me.showSteers == TRUE and me.input.rmActive.getValue() == TRUE) {
			me.mode = me.interoperability == displays.METRIC?"B ":"SP";# following steerpoint route
		} else {
			me.mode = "  ";# VFR
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
		} elsif (displays.common.distance_m != -1) {
			me.textBWeight.setText(displays.common.distance_name);
			if (displays.common.distance_model != displays.common.distance_name) {
				me.textBAlpha.setText(displays.common.distance_model);
			} else {
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
		if (me.dataLink == FALSE) {
			me.textBlink.setColor(rGrey, gGrey, bGrey, a);
			me.textBLinkFrame2.hide();
			me.textBLinkFrame1.show();
		} else {
			me.textBlink.setColor(rBlack, gBlack, bBlack, a);
			me.textBLinkFrame1.hide();
			me.textBLinkFrame2.show();
		}
	},

	showRadarLimit: func {
		if (me.input.currentMode.getValue() == canvas_HUD.COMBAT and me.input.tracks_enabled.getValue() == TRUE) {
			if (me.lastZ != zoom_curr or me.lastRR != me.input.radarRange.getValue() or me.input.timeElapsed.getValue() - me.lastRRT > 1600) {
				me.radar_limit_grp.removeAllChildren();
				var rdrField = 61.5*D2R;
				var radius = M2TEX*me.input.radarRange.getValue();
				var (leftX, leftY)   = (-math.sin(rdrField)*radius, -math.cos(rdrField)*radius);
				me.radarLimit = me.radar_limit_grp.createChild("path")
					.moveTo(leftX, leftY)
					.arcSmallCW(radius, radius, 0, -leftX*2, 0)
					.moveTo(leftX, leftY)
					.lineTo(leftX*0.80, leftY*0.80)
					.moveTo(-leftX, leftY)
					.lineTo(-leftX*0.80, leftY*0.80)
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
		if (land.showActiveSteer == FALSE and (land.show_waypoint_circle == TRUE or land.show_runway_line == TRUE)) {
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
				me.tgt_dist = nil;
	          	me.tgt_alt  = nil;
			} else {
				me.tgt_dist = me.selection.get_range()*NM2M;
	          	me.tgt_alt  = me.selection.get_altitude()*FT2M;
			}
			if (me.isGPS == FALSE) {
				me.gpsSymbol.hide();
		    }
	    } else {
	      	# radar tracks not shown at all
	      	me.tgt_dist = nil;
	        me.tgt_alt  = nil;
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
		    me.myHeading = me.input.headTrue.getValue();
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
			    	me.echoesAircraftVector[me.currentIndexT].setScale(1, clamp((me.tgtSpeed/60)*NM2M*M2TEX, 1, 750*MM2TEX));
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
				    	me.missilesVector[me.missileIndex].setScale(1, clamp((me.tgtSpeed/60)*NM2M*M2TEX, 1, 750*MM2TEX));
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

	showSelfVector: func {
		# length = time to travel in 60 seconds.
		var spd = getprop("velocities/airspeed-kt");# true airspeed so can be compared with other aircrafts speed. (should really be ground speed)
		me.selfVector.setScale(1, clamp((spd/60)*NM2M*M2TEX, 1, 750*MM2TEX));
		if (me.GPSinit == TRUE) {
			me.selfSymbol.hide();
			me.selfSymbolGPS.show()
		} else {
			me.selfSymbol.show();
			me.selfSymbolGPS.hide()
		}
	},

	showHeadingBug: func {
		me.desired_mag_heading = nil;
	    if (me.input.APLockHeading.getValue() == "dg-heading-hold") {
	    	me.desired_mag_heading = me.input.APHeadingBug.getValue();
	    } elsif (me.input.APLockHeading.getValue() == "true-heading-hold") {
	    	me.desired_mag_heading = me.input.APTrueHeadingErr.getValue()+me.input.headMagn.getValue();#getprop("autopilot/settings/true-heading-deg")+
	    } elsif (me.input.APLockHeading.getValue() == "nav1-hold") {
	    	me.desired_mag_heading = me.input.APnav0HeadingErr.getValue()+me.input.headMagn.getValue();
	    } elsif( me.input.RMActive.getValue() == TRUE) {
	    	#var i = getprop("autopilot/route-manager/current-wp");
	    	me.desired_mag_heading = me.input.RMWaypointBearing.getValue();
	    } elsif (me.input.nav0InRange.getValue() == TRUE) {
	    	# bug to VOR, ADF or ILS
	    	me.desired_mag_heading = me.input.nav0Heading.getValue();# TODO: is this really mag?
	    }
	    if (me.desired_mag_heading != nil) {
	    	me.myMaghdg  = me.input.headMagn.getValue();
	    	me.bugOffset = geo.normdeg180(me.desired_mag_heading-me.myMaghdg);
	    	if (math.abs(me.bugOffset) < 90) {
	    		me.xxx       = math.tan(me.bugOffset*D2R)*(height*0.875-(height*0.875)*me.ownPosition)+width/2;
	    		me.yyy       = 0;
	    		if (me.xxx < 0) {
	    			# upper left side
	    			me.xxx = 0;
	    			me.yyy = math.tan((-90-me.bugOffset)*D2R)*width/2+(height*0.875-(height*0.875)*me.ownPosition);
	    			me.commanded.setRotation(-90*D2R);
	    			me.commanded.setTranslation(me.xxx, me.yyy);
	    			if (me.menuShowFast == FALSE) {
	    				me.commanded.show();
	    			} else {
	    				me.commanded.hide();
	    			}
	    		} elsif (me.xxx > width) {
	    			# upper right side
					me.xxx = width;
					me.yyy = math.tan((me.bugOffset+90)*D2R)*width/2+(height*0.875-(height*0.875)*me.ownPosition);
					me.commanded.setRotation(90*D2R);
					me.commanded.setTranslation(me.xxx, me.yyy);
					if (me.menuShowFast == FALSE) {
	    				me.commanded.show();
	    			} else {
	    				me.commanded.hide();
	    			}
	    		} else {
	    			# top
	    			me.commanded.setRotation(0*D2R);
	    			me.commanded.setTranslation(me.xxx, me.yyy);
	    			me.commanded.show();
	    		}
	    	} elsif (math.abs(me.bugOffset) > 90) {
	    		me.xxx       = -math.tan(me.bugOffset*D2R)*(height*0.9-(height*0.875-(height*0.875)*me.ownPosition))+width/2;
	    		me.yyy       = height*0.9;
	    		if (me.xxx < 0) {
	    			# lower left side
	    			me.xxx = 0;
	    			me.yyy = math.tan((-me.bugOffset-90)*D2R)*width/2+(height*0.875-(height*0.875)*me.ownPosition);
	    			me.commanded.setRotation(-90*D2R);
	    			me.commanded.setTranslation(me.xxx, me.yyy);
	    			if (me.menuShowFast == FALSE) {
	    				me.commanded.show();
	    			} else {
	    				me.commanded.hide();
	    			}
	    		} elsif (me.xxx > width) {
	    			# lower right side
					me.xxx = width;
					me.yyy = math.tan((me.bugOffset-90)*D2R)*width/2+(height*0.875-(height*0.875)*me.ownPosition);
					me.commanded.setRotation(90*D2R);
					me.commanded.setTranslation(me.xxx, me.yyy);
					if (me.menuShowFast == FALSE) {
	    				me.commanded.show();
	    			} else {
	    				me.commanded.hide();
	    			}
	    		} else {
	    			# bottom
	    			me.commanded.setRotation(180*D2R);
	    			me.commanded.setTranslation(me.xxx, me.yyy);
	    			if (me.menuShowMain == FALSE) {
	    				me.commanded.show();
	    			} else {
	    				me.commanded.hide();
	    			}
	    		}
	    	} else {
	    		me.commanded.hide();
	    	}
	    } else {
	    	me.commanded.hide();
	    }
	},


	########################################################################################################
	########################################################################################################
	#
	#  button functions
	#
	#
	########################################################################################################
	########################################################################################################

	openQuickMenu: func {
		me.menuShowFast = TRUE;
		me.quickTimer = me.input.timeElapsed.getValue();
		me.quickOpen = 20;
	},


	b1: func {
		if (me.off == TRUE) {
			me.off = !me.off;
			MI.mi.off = me.off;
			me.active = !me.off;
		} elsif (me.active and me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.active and me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
				me.off = !me.off;
				MI.mi.off = me.off;
				me.active = !me.off;
			}
		}
	},

	b2: func {
		if (!me.active) return;
		if (me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
				# datalink / STRILL
				me.dataLink = !me.dataLink;
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == TRUE) {
				# tact lock report
				me.trapLock = TRUE;
				me.trapFire = FALSE;
				me.trapMan = FALSE;
				me.trapECM = FALSE;
				me.quickOpen = 10000;
			}	
		}
	},

	b3: func {
		if (!me.active) return;
		if (me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
			
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == TRUE) {
				# tact fire report
				me.trapFire = TRUE;
				me.trapMan = FALSE;
				me.trapECM = FALSE;
				me.trapLock = FALSE;
				me.quickOpen = 10000;
			}		
			if (me.menuMain == MAIN_DISPLAY) {
				# place names on map
				me.mapPlaces = !me.mapPlaces;
				if (me.mapPlaces == PLACES) {
					type = "light_all";
					makePath = string.compileTemplate(maps_base ~ '/cartoLN/{z}/{x}/{y}.png');
				} else {
					type = "light_nolabels";
					makePath = string.compileTemplate(maps_base ~ '/cartoL/{z}/{x}/{y}.png');
				}
			}	
		}
	},

	b4: func {
		if (!me.active) return;
		if (me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
				me.showSteers = !me.showSteers;
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == TRUE) {
				# tact lock report
				me.trapECM = TRUE;
				me.trapLock = FALSE;
				me.trapFire = FALSE;
				me.trapMan = FALSE;
				me.quickOpen = 10000;
			}
			if (me.menuMain == 10) {
				me.basesEnabled = !me.basesEnabled;
				if (me.basesEnabled == TRUE) {
					# do initial update, since else we might wait up to 3 mins.
					me.updateBasesNear();
				}
			}
		}
	},

	b5: func {
		if (!me.active) return;
		if (me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == TRUE) {
				# event report
				me.trapMan = TRUE;
				me.trapFire = FALSE;
				me.trapECM = FALSE;
				me.trapLock = FALSE;
				me.quickOpen = 10000;
			}	
			if (math.abs(me.menuMain) == MAIN_SYSTEMS) {
				me.showSteerPoly = !me.showSteerPoly;
			}
			if (me.menuMain == MAIN_CONFIGURATION and me.menuSvy == FALSE and me.menuGPS == FALSE) {
				# side view
				me.menuSvy = TRUE;
			}
		}
	},

	b6: func {
		if (!me.active) return;
		if (me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
				# tactical report
				me.quickOpen = 20;
				me.menuTrap = TRUE;
			}
			if (me.menuMain == MAIN_DISPLAY) {
				# change zoom
				zoomIn();
			}
			if (me.menuMain == MAIN_CONFIGURATION and me.menuGPS == FALSE and me.menuSvy == FALSE) {
				me.fr28Top = !me.fr28Top;
			}
		}
	},

	b7: func {
		if (!me.active) return;
		if (me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} else {
			me.menuShowMain = FALSE;
			me.menuShowFast = FALSE;
			me.menuNoSub();
			me.menuMain = -9;
		}
	},

	b8: func {
		# weapons
		if (!me.active) return;
		if (me.menuShowMain == TRUE and me.menuMain != MAIN_WEAPONS) {
			me.menuMain = MAIN_WEAPONS;
			me.menuShowFast = TRUE;
			me.menuNoSub();
		} else {
			if (me.menuMain == MAIN_WEAPONS) {
				me.input.station.setIntValue(5);
			} else {
				me.menuShowMain = !me.menuShowMain;
				if (me.menuShowFast == TRUE) {
					me.menuMain = math.abs(me.menuMain);
				}
			}
		}
	},

	b9: func {
		# system
		if (!me.active) return;
		if (me.menuShowMain == TRUE and me.menuMain != MAIN_WEAPONS) {
			me.menuMain = MAIN_SYSTEMS;
			me.menuShowFast = TRUE;
			me.menuNoSub();
		} else {
			if (me.menuMain == MAIN_WEAPONS) {
				me.input.station.setIntValue(1);
			} else {
				me.menuShowMain = !me.menuShowMain;
				if (me.menuShowFast == TRUE) {
					me.menuMain = math.abs(me.menuMain);
				}
			}
		}
	},

	b10: func {
		# display
		if (!me.active) return;
		if (me.menuShowMain == TRUE and me.menuMain != MAIN_WEAPONS) {
			me.menuMain = MAIN_DISPLAY;
			me.menuShowFast = TRUE;
			me.menuNoSub();
		} else {
			if (me.menuMain == MAIN_WEAPONS) {
				me.input.station.setIntValue(2);
			} else {
				me.menuShowMain = !me.menuShowMain;
				if (me.menuShowFast == TRUE) {
					me.menuMain = math.abs(me.menuMain);
				}
			}
		}
	},

	b11: func {
		# flight data
		if (!me.active) return;
		if (me.menuShowMain == TRUE and me.menuMain != MAIN_WEAPONS) {
			me.menuMain = MAIN_MISSION_DATA;
			me.menuShowFast = TRUE;
			me.menuNoSub();
		} else {
			if (me.menuMain == MAIN_WEAPONS) {
				me.input.station.setIntValue(4);
			} else {
				me.menuShowMain = !me.menuShowMain;
				if (me.menuShowFast == TRUE) {
					me.menuMain = math.abs(me.menuMain);
				}
			}
		}
	},

	b12: func {
		# errors
		if (!me.active) return;
		if (me.menuShowMain == TRUE and me.menuMain != MAIN_WEAPONS) {
			me.menuMain = MAIN_FAILURES;
			me.menuShowFast = TRUE;
			me.menuNoSub();
		} else {
			if (me.menuMain == MAIN_WEAPONS) {
				me.input.station.setIntValue(3);
			} else {
				me.menuShowMain = !me.menuShowMain;
				if (me.menuShowFast == TRUE) {
					me.menuMain = math.abs(me.menuMain);
				}
			}
		}
	},

	b13: func {
		# configuration
		if (!me.active) return;
		if (me.menuShowMain == TRUE and me.menuMain != MAIN_WEAPONS) {
			me.menuMain = MAIN_CONFIGURATION;
			me.menuShowFast = TRUE;
			me.menuNoSub();
		} else {
			if (me.menuMain == MAIN_WEAPONS) {
				me.input.station.setIntValue(6);
			} else {
				me.menuShowMain = !me.menuShowMain;
				if (me.menuShowFast == TRUE) {
					me.menuMain = math.abs(me.menuMain);
				}
			}
		}
	},

	b14: func {
		if (!me.active) return;
		if (me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
			if (me.menuMain == MAIN_WEAPONS) {
				me.input.station.setIntValue(0);
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
				me.ModeAttack = !me.ModeAttack;
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == TRUE) {
				# clear tact reports
				armament.fireLog.clear();
				me.logEvents.clear();
				me.logBIT.clear();
				radar_logic.lockLog.clear();
				armament.ecmLog.clear();
			}
			if (me.menuMain == MAIN_CONFIGURATION and me.menuGPS == TRUE) {
				# GPS fix
				if (me.GPSinit == TRUE) {
					  var coord = geo.aircraft_position();

					  var ground = geo.elevation(coord.lat(), coord.lon());
    				  if(ground != nil) {
      						coord.set_alt(ground);
      				  }

					  var contact = radar_logic.ContactGPS.new("FIX", coord);

					  radar_logic.selection = contact;
				}
			}
			if (me.menuMain == MAIN_CONFIGURATION and me.menuGPS == FALSE and me.menuSvy == FALSE) {
				# GPS settings
				me.menuGPS = TRUE;
			}
		}
	},

	b15: func {
		if (!me.active) return;
		if (me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
			if (me.menuMain == MAIN_WEAPONS) {
				#clear weapon selection
			}
			if (me.menuMain == MAIN_CONFIGURATION and me.menuGPS == TRUE) {
				me.GPSinit = !me.GPSinit;
				if (me.GPSinit == FALSE and radar_logic.selection != nil and radar_logic.selection.get_Callsign() == "FIX") {
					# clear the FIX if gps is turned off
					radar_logic.selection = nil;
				}
			}
		}
	},

	b16: func {
		if (!me.active) return;
		if (me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
			if (me.menuMain == MAIN_DISPLAY) {
				me.displayTime = !me.displayTime;
			}
		}
	},

	b17: func {
		if (!me.active) return;
		if (me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
			if(me.menuMain == MAIN_DISPLAY) {
				me.displayFlight += 1;
				if (me.displayFlight == 3) {
					me.displayFlight = 0;
				}
			}
		}
	},

	b18: func {
		if (!me.active) return;
		if (me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
		}
	},

	b19: func {
		if (!me.active) return;
		if (me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
			if(math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == TRUE and (me.trapFire == TRUE or me.trapMan == TRUE or me.trapLock == TRUE or me.trapECM == TRUE)) {
				me.logPage += 1;
			}
			if(me.menuMain == MAIN_DISPLAY) {
				me.day = !me.day;
			}
			if(me.menuMain == MAIN_MISSION_DATA) {
				if (me.ownPosition < 0.25) {
					me.ownPosition = 0.25;
				} elsif (me.ownPosition < 0.50) {
					me.ownPosition = 0.50;
				} elsif (me.ownPosition < 0.75) {
					me.ownPosition = 0.75;
				} elsif (me.ownPosition < 1) {
					me.ownPosition = 1;
				} elsif (me.ownPosition = 1) {
					me.ownPosition = 0;
				}
			}
			if(me.menuMain == MAIN_FAILURES) {
				me.logPage += 1;
			}			
		}
	},

	b20: func {
		if (!me.active) return;
		if (me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
			if(math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == TRUE and (me.trapFire == TRUE or me.trapMan == TRUE or me.trapLock == TRUE or me.trapECM == TRUE)) {
				me.logPage -= 1;
				if (me.logPage < 0) {
					me.logPage = 0;
				}
			}
			if(me.menuMain == MAIN_FAILURES) {
				me.logPage -= 1;
				if (me.logPage < 0) {
					me.logPage = 0;
				}
			}
		}
	},



	########################################################################################################
	########################################################################################################
	#
	#  map display
	#
	#
	########################################################################################################
	########################################################################################################



	setupMap: func {
		me.mapFinal.removeAllChildren();
		for(var x = 0; x < num_tiles[0]; x += 1) {
		  	tiles[x] = setsize([], num_tiles[1]);
		  	for(var y = 0; y < num_tiles[1]; y += 1) {
		    	tiles[x][y] = me.mapFinal.createChild("image", "map-tile");
		    	if (me.day == TRUE) {
		    		tiles[x][y].set("fill", "rgb(128,128,128)");
	    		} else {
	    			tiles[x][y].set("fill", "rgb(64,64,64)");
	    		}
	    	}
		}
	},

	updateMap: func {
		# update the map
		if (lastDay != me.day)  {
			me.setupMap();
		}
		
		me.rootCenter.setTranslation(width/2, height*0.875-(height*0.875)*me.ownPosition);
		me.mapCentrum.setTranslation(width/2, height*0.875-(height*0.875)*me.ownPosition);
		
		# get current position
		var lat = getprop('/position/latitude-deg');
		var lon = getprop('/position/longitude-deg');

		var n = math.pow(2, zoom);
		var offset = [
			n * ((lon + 180) / 360) - center_tile_offset[0],
			(1 - math.ln(math.tan(lat * D2R) + 1 / math.cos(lat * D2R)) / math.pi) / 2 * n - center_tile_offset[1]
		];
		var tile_index = [int(offset[0]), int(offset[1])];

		var ox = tile_index[0] - offset[0];
		var oy = tile_index[1] - offset[1];

		for(var x = 0; x < num_tiles[0]; x += 1) {
			for(var y = 0; y < num_tiles[1]; y += 1) {
				tiles[x][y].setTranslation(int((ox + x) * tile_size + 0.5), int((oy + y) * tile_size + 0.5));
			}
		}
		var liveMap = getprop("ja37/displays/live-map");
		if(tile_index[0] != last_tile[0] or tile_index[1] != last_tile[1] or type != last_type or zoom != last_zoom or liveMap != lastLiveMap or lastDay != me.day)  {
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

					    if( io.stat(img_path) == nil and liveMap == TRUE) { # image not found, save in $FG_HOME
					      	var img_url = makeUrl(pos);
					      	#print('requesting ' ~ img_url);
					      	http.save(img_url, img_path)
					      		.done(func(r) {
					      	  		#print('received image ' ~ img_path~" " ~ r.status ~ " " ~ r.reason);
					      	  		tile.set("src", img_path);
					      	  		})
					          #.done(func {print('received image ' ~ img_path); tile.set("src", img_path);})
					          .fail(func (r) {#print('Failed to get image ' ~ img_path ~ ' ' ~ r.status ~ ': ' ~ r.reason);
					          				tile.set("src", "Aircraft/JA37/Models/Cockpit/TI/emptyTile.png");
					      					tile.update();
					      					});
					    } elsif (io.stat(img_path) != nil) {# cached image found, reusing
					      	#print('loading ' ~ img_path);
					      	tile.set("src", img_path);
					      	tile.update();
					    } else {
					    	# internet not allowed, so no tile shown
					    	tile.set("src", "Aircraft/JA37/Models/Cockpit/TI/emptyTile.png");
					      	tile.update();
					    }
					})();
		  		}
			}

		last_tile = tile_index;
		last_type = type;
		last_zoom = zoom;
		lastLiveMap = liveMap;
		lastDay = me.day;
		}

		me.mapRot.setRotation(-getprop("orientation/heading-deg")*D2R);
	},
};

var extrapolate = func (x, x1, x2, y1, y2) {
    return y1 + ((x - x1) / (x2 - x1)) * (y2 - y1);
};

var ti = nil;
var init = func {
	removelistener(idl); # only call once
	if (getprop("ja37/supported/canvas") == TRUE) {
		setupCanvas();
		ti = TI.new();
		ti.loop();
		ti.loopFast();
		ti.loopSlow();
	}
}

idl = setlistener("ja37/supported/initialized", init, 0, 0);