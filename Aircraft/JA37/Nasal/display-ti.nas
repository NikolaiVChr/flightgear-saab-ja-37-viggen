
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
# 
#  call(canvas.Window.del, [], me);
#};
#var root = window.getCanvas(1).createGroup();
var mycanvas = nil;
var root = nil;
var setupCanvas = func {
	mycanvas = canvas.new({
	  "name": "TI",   
	  "size": [height, height], 
	  "view": [height, height], 
	  "mipmapping": 0,
	  #"additive-blend": 1
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
  string.compileTemplate('http://cartodb-basemaps-c.global.ssl.fastly.net/{type}/{z}/{x}/{y}.png');
var makePath =
  string.compileTemplate(maps_base ~ '/cartoL/{z}/{x}/{y}.png');
var num_tiles = [5, 5];# must be uneven, 5x5 will ensure we never see edge of map tiles when canvas is 512px high.

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

var FLIGHTDATA_ON  = 2;
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

var SVY_ELKA = 0;
var SVY_RMAX = 1;
var SVY_MI   = 2;
var SVY_ALL  = 0;
var SVY_RR   = 1;
var SVY_120  = 2;

var brightnessP = func {
	if (ti.active == FALSE) return;
	ti.brightness += 0.25;
};

var brightnessM = func {
	if (ti.active == FALSE) return;
	ti.brightness -= 0.25;
};

var bright = 0;

#TI symbol colors
var rWhite = 1.0; # other / self / own_missile
var gWhite = 1.0;
var bWhite = 1.0;
var COLOR_WHITE = [1,1,1];#I will slowly convert all of TI to use vectored colors instead.

var rYellow = 1.0;# possible threat
var gYellow = 1.0;
var bYellow = 0.0;
var COLOR_YELLOW = [1,1,0];

var rRed = 1.0;   # threat
var gRed = 0.0;
var bRed = 0.0;
var COLOR_RED = [1,0,0];

var rGreen = 0.0; # own side
var gGreen = 1.0;
var bGreen = 0.0;
var COLOR_GREEN = [0,1,0];

var rDTyrk = 0.20; # route polygon
var gDTyrk = 0.75;
var bDTyrk = 0.60;
var COLOR_TYRK_DARK = [0.20,0.75,0.60];

var rTyrk = 0.35; # navigation aid
var gTyrk = 1.00;
var bTyrk = 0.90;
var COLOR_TYRK = [0.35,1.00,0.90];

var rGrey = 0.5;   # inactive
var gGrey = 0.5;
var bGrey = 0.5;
var COLOR_GREY = [0.5,0.5,0.5];

var COLOR_GREY_LIGHT = [0.70,0.70,0.70];

var rBlack = 0.0;   # active
var gBlack = 0.0;
var bBlack = 0.0;
var COLOR_BLACK = [0.0,0.0,0.0];

var rGB = 0.5;   # flight data
var gGB = 0.5;
var bGB = 0.75;
var COLOR_GB = [0.5,0.5,0.75];

var a = 1.0;#alpha
var w = 1.0;#stroke width

var maxTracks   = 32;# how many radar tracks can be shown at once in the TI (was 16)
var maxMissiles =  6;
var maxThreats  =  5;
var maxSteers   = 48;#careful with this one
var maxBases    = 50;

var roundabout = func(x) {
  var y = x - int(x);
  return y < 0.5 ? int(x) : 1 + int(x) ;
};

var clamp = func(v, min, max) { v < min ? min : v > max ? max : v };

var circlePos = func (deg, radius) {
	return [radius*math.cos(deg*D2R),radius*math.sin(deg*D2R)];
}

var circlePosH = func (deg, radius) {
	# compensate for heading going opposite unit circle and 0 deg being forward
	return [radius*math.cos((-deg+90)*D2R),-radius*math.sin((-deg+90)*D2R)];
}

var containsVector = func (vec, item) {
	foreach(test; vec) {
		if (test == item) {
			return TRUE;
		}
	}
	return FALSE;
}

var extrapolate = func (x, x1, x2, y1, y2) {
    return y1 + ((x - x1) / (x2 - x1)) * (y2 - y1);
};

# notice the Swedish letter are missing accents in vertical menu items {ÅÖÄ} due to them not being always read correct by Nasal substr().
# Å = \xC3\x85
# Ö = \xC3\x96
# Ä = \xC3\x84

var dictSE = {
	'HORI': {'0': [TRUE, "AV"], '1': [TRUE, "RENS"], '2': [TRUE, "P\xC3\x85"]},
	'0':   {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "F\xC3\x96"], '13': [TRUE, "KONF"]},
	'8':   {'8': [TRUE, "R7V"], '9': [TRUE, "V7V"], '10': [TRUE, "S7V"], '11': [TRUE, "S7H"], '12': [TRUE, "V7H"], '13': [TRUE, "R7H"],
			'7': [TRUE, "MENY"], '14': [TRUE, "AKAN"], '15': [FALSE, "RENS"]},
	'9':   {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "F\xC3\x96"], '13': [TRUE, "KONF"],
	 		'1': [TRUE, "SL\xC3\x84CK"], '2': [TRUE, "DL"], '3': [TRUE, "OPT"], '4': [TRUE, "B"], '5': [TRUE, "UPOL"], '6': [TRUE, "TRAP"], '7': [TRUE, "MENY"],
	 		'14': [TRUE, "JAKT"], '15': [FALSE, "HK"],'16': [TRUE, "\xC3\x85POL"], '17': [TRUE, "L\xC3\x85"], '18': [TRUE, "LF"], '19': [TRUE, "LB"],'20': [TRUE, "L"]},
	'TRAP':{'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "F\xC3\x96"], '13': [TRUE, "KONF"],
	 		'2': [TRUE, "INL\xC3\x84"], '3': [TRUE, "AVFY"], '4': [TRUE, "FALL"], '5': [TRUE, "MAN"], '6': [TRUE, "S\xC3\x84TT"], '7': [TRUE, "MENY"], '14': [TRUE, "RENS"],
	 		'17': [FALSE, "ALLA"], '19': [TRUE, "NED"], '20': [TRUE, "UPP"]},
	'10':  {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "F\xC3\x96"], '13': [TRUE, "KONF"],
			'3': [TRUE, "ELKA"], '4': [TRUE, "ELKA"], '6': [TRUE, "SKAL"], '7': [TRUE, "MENY"], '14': [TRUE, "EOMR"], '15': [FALSE, "EOMR"], '16': [TRUE, "TID"],
			'17': [TRUE, "HORI"], '18': [TRUE, "HKM"], '19': [TRUE, "DAG"]},
	'11':  {'2': [TRUE, "INFG"], '3': [TRUE, "NY"], '5': [TRUE, "RADR"], # hack
	        '8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "F\xC3\x96"], '13': [TRUE, "KONF"],
			'4': [FALSE, "EDIT"], '6': [TRUE, "EDIT"], '7': [TRUE, "MENY"], '14': [TRUE, "EDIT"], '15': [TRUE, "\xC3\x85POL"], '16': [TRUE, "EDIT"],
			'17': [TRUE, "UPOL"], '18': [TRUE, "EDIT"], '19': [TRUE, "EGLA"], '20': [TRUE, "KMAN"]},
	'12':  {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "F\xC3\x96"], '13': [TRUE, "KONF"],
	 		'7': [TRUE, "MENY"], '19': [TRUE, "NED"], '20': [TRUE, "UPP"]},
	'13':  {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "F\xC3\x96"], '13': [TRUE, "KONF"],
			'5': [TRUE, "SVY"], '6': [TRUE, "FR28"], '7': [TRUE, "MENY"], '14': [TRUE, "GPS"], '19': [FALSE, "L\xC3\x84S"]},
	'GPS': {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "F\xC3\x96"], '13': [TRUE, "KONF"],
			'7': [TRUE, "MENU"], '14': [TRUE, "FIX"], '15': [TRUE, "INIT"]},
	'SVY': {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "F\xC3\x96"], '13': [TRUE, "KONF"],
			'5': [TRUE, "F\xC3\x96ST"], '6': [TRUE, "VISA"], '7': [TRUE, "MENU"], '14': [TRUE, "SKAL"], '15': [TRUE, "RMAX"], '16': [TRUE, "HMAX"]},
};

#ÅPOL = Return to base polygon (RPOL)
#UPOL = Mission Polygon (MPOL)

var dictEN = {
	'HORI': {'0': [TRUE, "OFF"], '1': [TRUE, "CLR"], '2': [TRUE, "ON"]},
	'0':   {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"]},
	'8':   {'8': [TRUE, "T7L"], '9': [TRUE, "W7L"], '10': [TRUE, "F7L"], '11': [TRUE, "F7R"], '12': [TRUE, "W7R"], '13': [TRUE, "T7R"],
			'7': [TRUE, "MENU"], '14': [TRUE, "AKAN"], '15': [FALSE, "CLR"]},
    '9':   {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
	 		'1': [TRUE, "OFF"], '2': [TRUE, "DL"], '3': [TRUE, "OPT"], '4': [TRUE, "S"], '5': [TRUE, "MPOL"], '6': [TRUE, "TRAP"], '7': [TRUE, "MENU"],
	 		'14': [TRUE, "FGHT"], '15': [FALSE, "ACRV"],'16': [TRUE, "RPOL"], '17': [TRUE, "LR"], '18': [TRUE, "LT"], '19': [TRUE, "LS"],'20': [TRUE, "L"]},
	'TRAP':{'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
	 		'2': [TRUE, "LOCK"], '3': [TRUE, "FIRE"], '4': [TRUE, "ECM"], '5': [TRUE, "MAN"], '6': [TRUE, "LAND"], '7': [TRUE, "MENU"], '14': [TRUE, "CLR"],
	 		'17': [FALSE, "ALL"], '19': [TRUE, "DOWN"], '20': [TRUE, "UP"]},
	'10':  {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
			'3': [TRUE, "EMAP"], '4': [TRUE, "EMAP"], '6': [TRUE, "SCAL"], '7': [TRUE, "MENU"], '14': [TRUE, "AAA"], '15': [TRUE, "AAA"], '16': [TRUE, "TIME"],
			'17': [TRUE, "HORI"], '18': [TRUE, "CURS"], '19': [TRUE, "DAY"]},
	'11':  {'2': [TRUE, "INS"], '3': [TRUE, "ADD"], '5': [TRUE, "DEL"], # hack
		    '8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
			'4': [FALSE, "EDIT"], '6': [TRUE, "EDIT"], '7': [TRUE, "MENU"], '14': [TRUE, "EDIT"], '15': [TRUE, "RPOL"], '16': [TRUE, "EDIT"],
			'17': [TRUE, "MPOL"], '18': [TRUE, "EDIT"], '19': [TRUE, "MYPS"], '20': [TRUE, "MMAN"]},
	'12':  {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
	 		'7': [TRUE, "MENU"], '19': [TRUE, "DOWN"], '20': [TRUE, "UP"]},
	'13':  {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
			'5': [TRUE, "SIDV"], '6': [TRUE, "FR28"], '7': [TRUE, "MENU"], '14': [TRUE, "GPS"], '19': [FALSE, "READ"]},
	'GPS': {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
			'7': [TRUE, "MENU"], '14': [TRUE, "FIX"], '15': [TRUE, "INIT"]},
	'SIDV': {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
			'5': [TRUE, "WIN"], '6': [TRUE, "SHOW"], '7': [TRUE, "MENU"], '14': [TRUE, "SCAL"], '15': [TRUE, "RMAX"], '16': [TRUE, "AMAX"]},
};

var TI = {

	# # # # # # # # # # # # # 
	# Z sorting:
	# root
	# 	map 1
	# 	svy 1
	# 	bug 4
	# 	rapports 5
	# 	time 7
	# 	root center 9
	# 		ecm 1
	# 		airports 2
	# 		mapScale 3
	# 		radar echoes 5
	# 		steerpoints 6
	# 		runway symbols 7
	# 		self 10	
	# 	FPI and arrow 10
	# 	infoBoxTarget 11
	# 	infoBox 11
	# 	menus 20
	# 	cursor 25
	# # # # # # # # # # # # 

	setupCanvasSymbols: func {
		# map groups
		me.mapCentrum = root.createChild("group")
			.set("z-index", 1)
			.setTranslation(width/2,height*2/3);
		me.mapCenter = me.mapCentrum.createChild("group");
		me.mapRot = me.mapCenter.createTransform();
		me.mapFinal = me.mapCenter.createChild("group");
		#me.mapFinal.setTranslation(-tile_size*center_tile_offset[0],-tile_size*center_tile_offset[1]);

		# groups
		me.rootCenter = root.createChild("group")
			.setTranslation(width/2,height*2/3)
			.set("z-index",  9);
		me.rootRealCenter = root.createChild("group")
			.setTranslation(width/2,height/2)
			.set("z-index", 10);

		# map scale
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


    	# hading bugs and line for direction of travel
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
		
		# own symbol
		me.selfSymbol = me.rootCenter.createChild("path")
		      .moveTo(-5*MM2TEX, 15*MM2TEX)
		      .lineTo( 0,         0*MM2TEX)
		      .lineTo( 5*MM2TEX, 15*MM2TEX)
		      .lineTo(-5*MM2TEX, 15*MM2TEX)
		      .setColor(rWhite,gWhite,bWhite, a)
		      .set("z-index", 10)
		      .setStrokeLineWidth(w);
		me.selfSymbolGPS = me.rootCenter.createChild("path")
		      .moveTo(-5*MM2TEX, 15*MM2TEX)
		      .lineTo( 0,         0*MM2TEX)
		      .lineTo( 5*MM2TEX, 15*MM2TEX)
		      .lineTo(-5*MM2TEX, 15*MM2TEX)
		      .setColor(rWhite,gWhite,bWhite, a)
		      .setColorFill(rWhite,gWhite,bWhite)
		      .set("z-index", 10)
		      .setStrokeLineWidth(w);
		me.selfVectorG = me.rootCenter.createChild("group")
			.set("z-index", 10)
			.setTranslation(0,0);
		me.selfVector = me.selfVectorG.createChild("path")
			  .set("z-index", 10)
			  .moveTo(0,  0)
			  .lineTo(0, -1*MM2TEX)
			  .setColor(rWhite,gWhite,bWhite, a)
		      .setStrokeLineWidth(w);

		# main radar and SVY group
		me.radar_group = me.rootCenter.createChild("group")
			.set("z-index", 5);

		me.echoesAircraft = [];
		me.echoesAircraftTri = [];
		me.echoesAircraftVector = [];
		# selection
		var grp = me.radar_group.createChild("group")
			.set("z-index", maxTracks-0);
		var grp2 = grp.createChild("group")
			.setTranslation(0,0);
		var vector = grp2.createChild("path")
		  .moveTo(0,  0)
		  .lineTo(0, -1*MM2TEX)
		  .setColor(rYellow,gYellow,bYellow, a)
	      .setStrokeLineWidth(w);
		var tri = grp.createChild("path")
	       .moveTo(-7.5, 7.5)
           .arcSmallCW(7.5, 7.5, 0, 15, 0)
           .arcSmallCW(7.5, 7.5, 0, -15, 0)
           .moveTo(-3.75, 11.25)
           .arcSmallCW(3.75, 3.75, 0, 7.5, 0)
           .arcSmallCW(3.75, 3.75, 0, -7.5, 0)
	       .setColor(rYellow,gYellow,bYellow, a)
	       .setStrokeLineWidth(w);
	    append(me.echoesAircraft, grp);
	    append(me.echoesAircraftTri, tri);
	    append(me.echoesAircraftVector, vector);
	    #unselected
		for (var i = 1; i < maxTracks; i += 1) {
			var grp = me.radar_group.createChild("group")
				.set("z-index", maxTracks-i);
			var grp2 = grp.createChild("group")
				.setTranslation(0, 0);
			var vector = grp2.createChild("path")
			  .moveTo(0,  0)
			  .lineTo(0, -1*MM2TEX)
			  .setColor(i!=0?rYellow:rRed,i!=0?gYellow:gRed,i!=0?bYellow:bRed, a)
		      .setStrokeLineWidth(w);
			var tri = grp.createChild("path")
		      .moveTo(-5*MM2TEX, 15*MM2TEX)
		      .lineTo( 0,         0*MM2TEX)
		      .moveTo( 5*MM2TEX, 15*MM2TEX)
		      .lineTo( 0,         0*MM2TEX)
		      .moveTo(-5*MM2TEX, 15*MM2TEX)
		      .lineTo( 5*MM2TEX, 15*MM2TEX)
		      .setColor(i!=0?rYellow:rRed,i!=0?gYellow:gRed,i!=0?bYellow:bRed, a)
		      .setStrokeLineWidth(w);
		    append(me.echoesAircraft, grp);
		    append(me.echoesAircraftTri, tri);
		    append(me.echoesAircraftVector, vector);
		}

		# SVY
		me.rootSVY = root.createChild("group")
    	    .set("z-index", 1);
    	me.svy_grp = me.rootSVY.createChild("group");
    	me.svy_grp2 = me.svy_grp.createChild("group")
    		.set("z-index", 1);
    	me.echoesAircraftSvy = [];
    	me.echoesAircraftSvyTri = [];
		me.echoesAircraftSvyVector = [];
		var grpS = me.svy_grp.createChild("group")
			.set("z-index", maxTracks-0);
		var grpS2 = grpS.createChild("group")
			.setTranslation(0,0);
		var vectorS = grpS2.createChild("path")
		  .moveTo(0,  0)
		  .lineTo(0, -1*MM2TEX)
		  .setColor(rYellow,gYellow,bYellow, a)
	      .setStrokeLineWidth(w);
		var tri = grpS.createChild("path")
	       .moveTo(-7.5, 7.5)
           .arcSmallCW(7.5, 7.5, 0, 15, 0)
           .arcSmallCW(7.5, 7.5, 0, -15, 0)
           .moveTo(-3.75, 11.25)
           .arcSmallCW(3.75, 3.75, 0, 7.5, 0)
           .arcSmallCW(3.75, 3.75, 0, -7.5, 0)
	       .setColor(rYellow,gYellow,bYellow, a)
	       .setStrokeLineWidth(w);
	    append(me.echoesAircraftSvy, grpS);
	    append(me.echoesAircraftSvyTri, tri);
	    append(me.echoesAircraftSvyVector, vectorS);
		for (var i = 1; i < maxTracks; i += 1) {
			var grp = me.svy_grp.createChild("group")
				.set("z-index", maxTracks-i);
			var vector = grp.createChild("path")
			  .moveTo(0,  0)
			  .lineTo(0, -1*MM2TEX)
			  .setColor(i!=0?rYellow:rRed,i!=0?gYellow:gRed,i!=0?bYellow:bRed, a)
		      .setStrokeLineWidth(w);
			var tri = grp.createChild("path")
		      .moveTo(-5*MM2TEX, 15*MM2TEX)
		      .lineTo( 0,         0*MM2TEX)
		      .moveTo( 5*MM2TEX, 15*MM2TEX)
		      .lineTo( 0,         0*MM2TEX)
		      .moveTo(-5*MM2TEX, 15*MM2TEX)
		      .lineTo( 5*MM2TEX, 15*MM2TEX)
		      .setColor(i!=0?rYellow:rRed,i!=0?gYellow:gRed,i!=0?bYellow:bRed, a)
		      .setStrokeLineWidth(w);
		    append(me.echoesAircraftSvy, grp);
		    append(me.echoesAircraftSvyTri, tri);
		    append(me.echoesAircraftSvyVector, vector);
		}
		me.selfSymbolSvy = me.svy_grp.createChild("path")
		      .moveTo(-5*MM2TEX,  15*MM2TEX)
		      .lineTo( 0,       0*MM2TEX)
		      .moveTo( 5*MM2TEX,  15*MM2TEX)
		      .lineTo( 0,       0*MM2TEX)
		      .moveTo(-5*MM2TEX,  15*MM2TEX)
		      .lineTo( 5*MM2TEX,  15*MM2TEX)
		      .setColor(rWhite,gWhite,bWhite, a)
		      .set("z-index", 10)
		      .setStrokeLineWidth(w);
		me.selfVectorSvy = me.svy_grp.createChild("path")
			  .moveTo(0,  0)
			  .set("z-index", 10)
			  .lineTo(1*MM2TEX, 0)
			  .setColor(rWhite,gWhite,bWhite, a)
		      .setStrokeLineWidth(w);
		# SVY coordinate text
		me.textSvyY = me.svy_grp.createChild("text")
    		.setText("40 KM")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("left-bottom")
    		.setTranslation(0, 0)
    		.set("z-index", 7)
    		.setFontSize(13, 1);
    	me.textSvyX = me.svy_grp.createChild("text")
    		.setText("120 KM")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("right-top")
    		.setTranslation(0, 0)
    		.set("z-index", 7)
    		.setFontSize(13, 1);

		# runway symbols
	    me.dest = me.rootCenter.createChild("group")
	    	.set("z-index", 7)
            .hide();
	    me.approach_line = me.dest.createChild("path")
	               .moveTo(0, 0)
	               .lineTo(0, -1)
	               .setStrokeLineWidth(w*1.5)
	               .setStrokeLineCap("butt")
	               .setColor(rTyrk,gTyrk,bTyrk, a)
	               .hide();
	    me.runway_line = me.dest.createChild("path")
	               .moveTo(0, 0)
	               .lineTo(0, 1)
	               .setStrokeLineWidth(w*4.5)
	               .setStrokeLineCap("butt")
	               .setColor(rWhite,gWhite,bWhite, a)
	               .hide();
	    me.runway_name = me.dest.createChild("text")
    		.setText("32")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-center")
    		.setTranslation(25, 0)
    		.setFontSize(15, 1);
	    me.dest_circle = me.dest.createChild("path")
	               .moveTo(-12.5, 0)
	               .arcSmallCW(12.5, 12.5, 0, 25, 0)
	               .arcSmallCW(12.5, 12.5, 0, -25, 0)
	               .setStrokeLineWidth(w)
	               .setColor(rTyrk,gTyrk,bTyrk, a);
	    me.approach_circle = me.rootCenter.createChild("path")
	    			.set("z-index", 7)
	               .moveTo(-100, 0)
	               .arcSmallCW(100, 100, 0, 200, 0)
	               .arcSmallCW(100, 100, 0, -200, 0)
	               .setStrokeLineWidth(w*1.5)
	               .setColor(rTyrk,gTyrk,bTyrk, a);

	    # threat circles
	    me.threats = [];
	    for (var i = 0; i < maxThreats; i += 1) {
	    	append(me.threats, me.radar_group.createChild("path")
	               .moveTo(-100, 0)
	               .arcSmallCW(100, 100, 0, 200, 0)
	               .arcSmallCW(100, 100, 0, -200, 0)
	               .setStrokeLineWidth(w)
	               .setColor(rRed,gRed,bRed, a));
	    }

	    # route symbols
	    me.steerpoint = [];
	    me.steerpointText = [];
	    me.steerpointSymbol = [];
	    for (var i = 0; i < maxSteers*7; i += 1) {#6 for routes, 1 for areas = 7 multiplier, maxSteers = 48
       		var stGrp = me.rootCenter.createChild("group");
       		append(me.steerpointText, stGrp.createChild("text")
	    		.setText("B2")
	    		.setColor(rWhite,gWhite,bWhite, a)
	    		.setAlignment("right-center")
	    		.setTranslation(-10*MM2TEX, 0)
	    		.set("z-index", 6)
	    		.setFontSize(13, 1));
    		append(me.steerpointSymbol, stGrp.createChild("path")
    		   .set("z-index", 6)
               .moveTo(-10*MM2TEX, 0)
               .lineTo(0, -15*MM2TEX)
               .lineTo(10*MM2TEX, 0)
               .lineTo(0, 15*MM2TEX)
               .lineTo(-10*MM2TEX, 0)
               .setStrokeLineWidth(w)
               .setColor(rDTyrk,gDTyrk,bDTyrk, a));
			append(me.steerpoint, stGrp);
	    }
	    me.steerPoly = me.rootCenter.createChild("group")
	    			.set("z-index", 6);

	    # missiles
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

	    # gps symbol
	    me.gpsSymbol = me.radar_group.createChild("path")
		      .moveTo(-10*MM2TEX, 10*MM2TEX)
		      .vert(            -20*MM2TEX)
		      .horiz(            20*MM2TEX)
		      .vert(             20*MM2TEX)
		      .horiz(           -20*MM2TEX)
		      .setColor(rTyrk,gTyrk,bTyrk, a)
		      .setStrokeLineWidth(w);

		me.radar_limit_grp = me.radar_group.createChild("group");

		me.cursor = root.createChild("path")# is off set 1 pixel to right
				.moveTo(-24*MM2TEX,0)
				.horiz(20*MM2TEX)
				.moveTo(0,0)
				.horiz(1*MM2TEX)
				.moveTo(6*MM2TEX,0)
				.horiz(20*MM2TEX)
				.moveTo(1*MM2TEX,-25*MM2TEX)
				.vert(20*MM2TEX)
				.moveTo(1*MM2TEX,5*MM2TEX)
				.vert(20*MM2TEX)
				.setStrokeLineWidth(w*3)
				.setTranslation(50*MM2TEX, height*0.5)
				.setStrokeLineCap("round")
				.set("z-index", 25)#max
		        .setColor(rWhite,gWhite,bWhite, a);

		# target info box
		me.tgtTextField     = root.createChild("group")
			.set("z-index", 11);
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
			.set("z-index", 11);
		me.wpStartx = width*0.060-3.125+6.25*2+w*2;
		me.wpStarty = height-height*0.1-height*0.025-w*2;
		me.wpW      = 0.29;
		me.wpH      = 0.15;
		me.wpTextFrame     = me.wpTextField.createChild("path")
			.moveTo(me.wpStartx,  me.wpStarty)#above bottom text field and next to fast menu sub boxes
		      .vert(            -height*me.wpH)
		      .horiz(            width*me.wpW)
		      .vert(             height*me.wpH)
		      .horiz(           -width*me.wpW)

		      .moveTo(me.wpStartx, me.wpStarty-height*me.wpH*0.2)
		      .horiz(            width*me.wpW)
		      .moveTo(me.wpStartx, me.wpStarty-height*me.wpH*0.4)
		      .horiz(            width*me.wpW)
		      .moveTo(me.wpStartx, me.wpStarty-height*me.wpH*0.6)
		      .horiz(            width*me.wpW)
		      .moveTo(me.wpStartx, me.wpStarty-height*me.wpH*0.8)
		      .horiz(            width*me.wpW)
		      .moveTo(me.wpStartx+width*me.wpW*0.3, me.wpStarty)
		      .vert(            -height*me.wpH)
		      .setColor(rWhite,gWhite,bWhite, a)
		      .setStrokeLineWidth(w);
		me.wpTextFrame1    = me.wpTextField.createChild("path")
			.moveTo(me.wpStartx,  me.wpStarty-height*me.wpH)#above bottom text field and next to fast menu sub boxes
		      .vert(            -height*me.wpH*0.2)
		      .horiz(            width*me.wpW)
		      .vert(             height*me.wpH*0.2)
		      .moveTo(me.wpStartx+width*me.wpW*0.3, me.wpStarty-height*me.wpH)
		      .vert(            -height*me.wpH*0.2)
		      .setColor(rWhite,gWhite,bWhite, a)
		      .setStrokeLineWidth(w);
		me.wpText2Desc = me.wpTextField.createChild("text")
    		.setText("BEN")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.15, me.wpStarty-height*me.wpH*0.8-w)
    		.setFontSize(15, 1);
    	me.wpText2 = me.wpTextField.createChild("text")
    		.setText("1 AV 4")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.65, me.wpStarty-height*me.wpH*0.8-w)
    		.setFontSize(15, 1);
    	me.wpText3Desc = me.wpTextField.createChild("text")
    		.setText("B")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.15, me.wpStarty-height*me.wpH*0.6-w)
    		.setFontSize(15, 1);
    	me.wpText3 = me.wpTextField.createChild("text")
    		.setText("0 -> 1")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.65, me.wpStarty-height*me.wpH*0.6-w)
    		.setFontSize(15, 1);
    	me.wpText4Desc = me.wpTextField.createChild("text")
    		.setText("H")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.15, me.wpStarty-height*me.wpH*0.4-w)
    		.setFontSize(15, 1);
    	me.wpText4 = me.wpTextField.createChild("text")
    		.setText("10000")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.65, me.wpStarty-height*me.wpH*0.4-w)
    		.setFontSize(15, 1);
    	me.wpText5Desc = me.wpTextField.createChild("text")
    		.setText("M")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.15, me.wpStarty-height*me.wpH*0.2-w)
    		.setFontSize(15, 1);
    	me.wpText5 = me.wpTextField.createChild("text")
    		.setText("300")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.65, me.wpStarty-height*me.wpH*0.2-w)
    		.setFontSize(15, 1);
    	me.wpText6Desc = me.wpTextField.createChild("text")
    		.setText("ETA")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.15, me.wpStarty-height*me.wpH*0.0-w)
    		.setFontSize(15, 1);
    	me.wpText6 = me.wpTextField.createChild("text")
    		.setText("3:43")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.65, me.wpStarty-height*me.wpH*0.0-w)
    		.setFontSize(15, 1);
    	me.wpText1Desc = me.wpTextField.createChild("text")
    		.setText("TOP")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.15, me.wpStarty-height*me.wpH*1.0-w)
    		.setFontSize(15, 1);
    	me.wpText1 = me.wpTextField.createChild("text")
    		.setText("BLABLA")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.65, me.wpStarty-height*me.wpH*1.0-w)
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
    		.setFontSize(27, 1);
    	me.textBAlpha = me.bottom_text_grp.createChild("text")
    		.setText("ALFA 20,5")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("right-bottom")
    		.setTranslation(width, height-height*0.01)
    		.setFontSize(16, 1);
    	me.textBWeight = me.bottom_text_grp.createChild("text")
    		.setText("VIKT 13,4")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("right-top")
    		.setTranslation(width, height-height*0.085)
    		.setFontSize(16, 1);

    	# log pages
    	me.logRoot = root.createChild("group")
    		.set("z-index", 5)
    		.hide();
    	me.errorList = me.logRoot.createChild("text")
    		.setText("..OKAY..\n..OKAY..")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("left-top")
    		.setTranslation(0, 20)
    		.setFontSize(10, 1);

    	# menu groups
    	me.menuMainRoot = root.createChild("group")
    		.set("z-index", 20)
    		.hide();
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

		# airport overlay
		me.base_grp = me.rootCenter.createChild("group")
			.set("z-index", 2);

		# large airports
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

		me.ecm_grp = me.rootCenter.createChild("group")
			.set("z-index", 1);
		me.ecmRadius = 50;
		me.ecm12 = me.ecm_grp.createChild("path")
			.moveTo(circlePosH(-14, me.ecmRadius)[0], circlePosH(-14, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(14, me.ecmRadius)[0]-circlePosH(-14, me.ecmRadius)[0], circlePosH(14, me.ecmRadius)[1]-circlePosH(-14, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(rGreen,gGreen,bGreen, a);
	    me.ecm1 = me.ecm_grp.createChild("path")
			.moveTo(circlePosH(16, me.ecmRadius)[0], circlePosH(16, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(44, me.ecmRadius)[0]-circlePosH(16, me.ecmRadius)[0], circlePosH(44, me.ecmRadius)[1]-circlePosH(16, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(rRed,gRed,bRed, a);
	    me.ecm2 = me.ecm_grp.createChild("path")
			.moveTo(circlePosH(46, me.ecmRadius)[0], circlePosH(46, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(74, me.ecmRadius)[0]-circlePosH(46, me.ecmRadius)[0], circlePosH(74, me.ecmRadius)[1]-circlePosH(46, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(rYellow,gYellow,bYellow, a);
	    me.ecm3 = me.ecm_grp.createChild("path")
			.moveTo(circlePosH(76, me.ecmRadius)[0], circlePosH(76, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(104, me.ecmRadius)[0]-circlePosH(76, me.ecmRadius)[0], circlePosH(104, me.ecmRadius)[1]-circlePosH(76, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(rYellow,gYellow,bYellow, a);
	    me.ecm4 = me.ecm_grp.createChild("path")
			.moveTo(circlePosH(106, me.ecmRadius)[0], circlePosH(106, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(134, me.ecmRadius)[0]-circlePosH(106, me.ecmRadius)[0], circlePosH(134, me.ecmRadius)[1]-circlePosH(106, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(rYellow,gYellow,bYellow, a);
	    me.ecm5 = me.ecm_grp.createChild("path")
			.moveTo(circlePosH(136, me.ecmRadius)[0], circlePosH(136, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(164, me.ecmRadius)[0]-circlePosH(136, me.ecmRadius)[0], circlePosH(164, me.ecmRadius)[1]-circlePosH(136, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(rYellow,gYellow,bYellow, a);
	    me.ecm6 = me.ecm_grp.createChild("path")
			.moveTo(circlePosH(166, me.ecmRadius)[0], circlePosH(166, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(194, me.ecmRadius)[0]-circlePosH(166, me.ecmRadius)[0], circlePosH(194, me.ecmRadius)[1]-circlePosH(166, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(rYellow,gYellow,bYellow, a);
	    me.ecm7 = me.ecm_grp.createChild("path")
			.moveTo(circlePosH(196, me.ecmRadius)[0], circlePosH(196, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(224, me.ecmRadius)[0]-circlePosH(196, me.ecmRadius)[0], circlePosH(224, me.ecmRadius)[1]-circlePosH(196, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(rYellow,gYellow,bYellow, a);
	    me.ecm8 = me.ecm_grp.createChild("path")
			.moveTo(circlePosH(226, me.ecmRadius)[0], circlePosH(226, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(254, me.ecmRadius)[0]-circlePosH(226, me.ecmRadius)[0], circlePosH(254, me.ecmRadius)[1]-circlePosH(226, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(rYellow,gYellow,bYellow, a);
	    me.ecm9 = me.ecm_grp.createChild("path")
			.moveTo(circlePosH(256, me.ecmRadius)[0], circlePosH(256, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(284, me.ecmRadius)[0]-circlePosH(256, me.ecmRadius)[0], circlePosH(284, me.ecmRadius)[1]-circlePosH(256, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(rYellow,gYellow,bYellow, a);
	    me.ecm10 = me.ecm_grp.createChild("path")
			.moveTo(circlePosH(286, me.ecmRadius)[0], circlePosH(286, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(314, me.ecmRadius)[0]-circlePosH(286, me.ecmRadius)[0], circlePosH(314, me.ecmRadius)[1]-circlePosH(286, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(rYellow,gYellow,bYellow, a);
	    me.ecm11 = me.ecm_grp.createChild("path")
			.moveTo(circlePosH(316, me.ecmRadius)[0], circlePosH(316, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(344, me.ecmRadius)[0]-circlePosH(316, me.ecmRadius)[0], circlePosH(344, me.ecmRadius)[1]-circlePosH(316, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(rYellow,gYellow,bYellow, a);

		# small airports
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


		# time
		me.textTime = root.createChild("text")
    		.setText("h:min:s")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("right-top")
    		.setTranslation(width, 4)
    		.set("z-index", 7)
    		.setFontSize(13, 1);
    	me.textFTime = root.createChild("text")
    		.setText("FTIME h:min")
    		.setColor(rWhite,gWhite,bWhite, a)
    		.setAlignment("left-top")
    		.setTranslation(0, 4)
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
	        APLockHeading:    	  "autopilot/locks/heading",
	        APTrueHeadingErr: 	  "autopilot/internal/true-heading-error-deg",
	        APnav0HeadingErr: 	  "autopilot/internal/nav1-heading-error-deg",
	        APHeadingBug:     	  "autopilot/settings/heading-bug-deg",
	        RMWaypointBearing:	  "autopilot/route-manager/wp/bearing-deg",
	        RMActive:             "autopilot/route-manager/active",
	        nav0Heading:          "instrumentation/nav[0]/heading-deg",
	        ias:                  "instrumentation/airspeed-indicator/indicated-speed-kt",
	        tas:                  "instrumentation/airspeed-indicator/true-speed-kt",
	        wow0:                 "fdm/jsbsim/gear/unit[0]/WOW",
        	wow1:                 "fdm/jsbsim/gear/unit[1]/WOW",
        	wow2:                 "fdm/jsbsim/gear/unit[2]/WOW",
        	gearsPos:         	  "gear/gear/position-norm",
      	};
   
      	foreach(var name; keys(ti.input)) {
        	ti.input[name] = props.globals.getNode(ti.input[name], 1);
      	}

      	ti.setupCanvasSymbols();
      	ti.day = TRUE;
      	ti.setupMap();

      	#map
      	ti.lat = getprop('/position/latitude-deg');
		ti.lon = getprop('/position/longitude-deg');
      	ti.mapSelfCentered = TRUE;

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
		ti.trapLand     = FALSE;

		# SVY
		ti.SVYactive    = FALSE;
		ti.SVYscale     = SVY_ELKA;
		ti.SVYrmax      = 120;# 15 -120
		ti.SVYhmax      = 20;# 5, 10, 20 or 40 KM
		ti.SVYsize      = 2;#size 1-3
		ti.SVYinclude   = SVY_ALL;

		ti.upText = FALSE;
		ti.logPage = 0;
		ti.off = FALSE;
		ti.showFullMenus = TRUE;
		ti.displayFlight = FLIGHTDATA_CLR;
		ti.displayTime = FALSE;
		ti.displayFTime = FALSE;
		ti.ownPosition = 0.25;
		ti.ownPositionDigital = 2;
		ti.mapPlaces = CLEANMAP;
		ti.ModeAttack = FALSE;
		#ti.GPSinit    = FALSE;
		ti.fr28Top    = FALSE;
		ti.dataLink   = FALSE;
		ti.mapshowing = TRUE;
		ti.basesNear  = [];
		ti.basesEnabled = FALSE;
		ti.logEvents  = events.LogBuffer.new(echo: 0);#compatible with older FG?		
		ti.logBIT     = events.LogBuffer.new(echo: 0);#compatible with older FG?
		ti.logLand    = events.LogBuffer.new(echo: 0);#compatible with older FG?
		ti.BITon = FALSE;
		ti.BITtime = 0;
		ti.BITok1 = FALSE;
		ti.BITok2 = FALSE;
		ti.BITok3 = FALSE;
		ti.BITok4 = FALSE;
		ti.active = TRUE;
		ti.showHostileZones = TRUE;
		ti.showFriendlyZones = TRUE;
		ti.newFails = FALSE;
		ti.lastFailBlink = TRUE;
		ti.landed = TRUE;
		ti.foes    = [];
		ti.friends = [];
		ti.ECMon   = FALSE;
		ti.lnk99   = FALSE;
		ti.tele    = [];

		# cursor
		ti.cursorPosX  = 0;
		ti.cursorPosY  = 0;
		ti.blinkBox2 = FALSE;
		ti.blinkBox3 = FALSE;
		ti.blinkBox4 = FALSE;
		ti.blinkBox5 = FALSE;

		# steerpoints
		ti.newSteerPos = nil;
		ti.showSteers = TRUE;#only for debug turn to false
		ti.showSteerPoly = TRUE;#only for debug turn to false

		# MI
		ti.mreg = FALSE;


		ti.startFailListener();

      	return ti;
	},


	startFailListener: func {
		#this will run entire session, so no need to unsubscribe.
		if (getprop("ja37/supported/failEvents") == TRUE) {
			FailureMgr.events["trigger-fired"].subscribe(func {call(func{me.newFails = 1}, nil, me, me)});
		}
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

		if (me.brightness < 0.25) {
			me.brightness = 0.25;
		} elsif (me.brightness > 1) {
			me.brightness = 1;
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
		me.updateMI();
		me.whereIsMap();#must be before mapUpdate
		me.updateMap();
		me.showMapScale();
		M2TEX = 1/(meterPerPixel[zoom]*math.cos(getprop('/position/latitude-deg')*D2R));
		me.updateSVY();# must be before displayRadarTracks and showselfvector
		me.showSelfVector();
		me.defineEnemies();# must be before displayRadarTracks
		me.displayRadarTracks();
		me.showRunway();
		me.showRadarLimit();
		me.showBottomText();# must be after displayRadarTracks
		me.menuUpdate();
		me.showTime();
		me.showFlightTime();
		me.showSteerPoints();
		me.showSteerPointInfo();
		me.showPoly();#must be under showSteerPoints
		me.showTargetInfo();#must be after displayRadarTracks
		me.updateMapNames();
		me.showBasesNear();		
		me.ecmOverlay();
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
		me.testLanding();
		me.showCursor();
		#me.rate = getprop("sim/frame-rate-worst");
		#me.rate = me.rate !=nil?clamp(1/(me.rate+0.001), 0.05, 0.5):0.5;
		me.rate = 0.05;
		settimer(func me.loopFast(), me.rate);#0.001 is to prevent divide by zero
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
				me.menuMainRoot.show();
				me.updateMainMenu();
				me.upText = TRUE;
			} elsif (me.menuShowMain == FALSE and me.menuShowFast == TRUE) {
				me.menuMainRoot.hide();
				me.stopEditPlan();
				me.upText = FALSE;
			} else {
				me.stopEditPlan();
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
				me.drawLog = FALSE;
				if (me.trapFire == TRUE) {
					me.buffer = armament.fireLog;
					me.bufferStr = "       Fire log:\n";
					me.drawLog = TRUE;
				} elsif (me.trapMan == TRUE) {
					me.buffer = me.logEvents;
					me.bufferStr = "       Event log:\n";
					me.drawLog = TRUE;
				} elsif (me.trapLock == TRUE) {
					me.buffer = radar_logic.lockLog;
					me.bufferStr = "       Lock log:\n";
					me.drawLog = TRUE;
				} elsif (me.trapLand == TRUE) {
					me.buffer = me.logLand;
					me.bufferStr = "       Landing log:\n";
					me.drawLog = TRUE;
				} elsif (me.trapECM == TRUE) {
					me.buffer = armament.ecmLog;
					me.bufferStr = "       ECM log:\n";
					me.drawLog = TRUE;
				}
				if (me.drawLog == TRUE) {
					me.hideMap();
					me.logRoot.show();
					call(func {
						me.bufferContent = me.buffer.get_buffer();
						me.str = me.bufferStr;
		    			foreach(entry; me.bufferContent) {
		      				me.str = me.str~"    "~entry.time~" "~entry.message~"\n";
		    			}
						me.errorList.setText(me.str);
					});
					me.clipLogPage();
				} else {
					me.showMap();
				}
			} elsif (me.menuMain == MAIN_FAILURES) {
				# failure menu
				me.hideMap();
				me.logRoot.show();
				call(func {
					me.buffer = FailureMgr.get_log_buffer();
					me.str = "       Failure log:\n";
	    			foreach(entry; me.buffer) {
	      				me.str = me.str~"    "~entry.time~" "~entry.message~"\n";
	    			}
					me.errorList.setText(me.str);
				}, nil, var err = []);
				me.newFails = FALSE;
				me.clipLogPage();
			} else {
				me.showMap();
			}
		} else {
			me.menuMainRoot.hide();
			me.menuFastRoot.hide();
			me.stopEditPlan();
			me.hideMap();
			me.logRoot.show();
			call(func {
				me.buffer = me.logBIT.get_buffer();
				me.str = "       RB-99 Build In Test (BIT) log:\n";
    			foreach(entry; me.buffer) {
      				me.str = me.str~"    "~entry.time~" "~entry.message~"\n";
    			}
				me.errorList.setText(me.str);
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
		if (me.menuMain != MAIN_MISSION_DATA) {
			me.dragMapEnabled = FALSE;
			me.mapSelfCentered = TRUE;
		}
	},

	clipLogPage: func {
		me.logRoot.setTranslation(0,  -(height-height*0.025*me.upText)*me.logPage);
		me.clip2 = 0~"px, "~width~"px, "~(height-height*0.025*me.upText)~"px, "~0~"px";
		me.logRoot.set("clip", "rect("~me.clip2~")");#top,right,bottom,left
	},

	stopEditPlan: func {
		route.Polygon.editPlan(nil);
	},

	showMap: func {
		#
		# Reveal map and its overlays
		#
		me.logPage = 0;
		me.mapCentrum.show();
		me.rootCenter.show();
		me.rootSVY.show();
		me.logRoot.hide();
		me.navBugs.show();
		me.bottom_text_grp.show();
		me.mapshowing = TRUE;
	},

	hideMap: func {
		#
		# Hide map and its overlays (due to a log page being displayed)
		#
		me.rootSVY.hide();
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
			if (i != MAIN_FAILURES or me.menuMain == MAIN_WEAPONS or me.newFails == FALSE or me.lastFailBlink == FALSE) {
				me.menuButton[i].setText(me.compileMainMenu(i));
			} else {
				# blink failure menu
				me.menuButton[i].setText("");
			}
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
		me.lastFailBlink = !me.lastFailBlink;
		if (me.menuMain != MAIN_MISSION_DATA) {
			me.stopEditPlan();
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
		me.pyl = 0;
		if (position == 8) {
			me.pyl = 5;
		} elsif (position == 9) {
			me.pyl = 1;
		} elsif (position == 10) {
			me.pyl = 2;
		} elsif (position == 11) {
			me.pyl = 4;
		} elsif (position == 12) {
			me.pyl = 3;
		} elsif (position == 13) {
			me.pyl = 6;
		}
		me.pylon = displays.common.armNamePylon(me.pyl);
		if (me.pylon != nil) {
			me.menuButton[position].setText(me.pylon);
		}
	},

	compileMainMenu: func (button) {
		me.str = nil;
		if (me.interoperability == displays.METRIC) {
			me.str = dictSE[me.menuGPS==TRUE?"GPS":(me.menuTrap==TRUE?"TRAP":(me.menuSvy==TRUE?"SVY":''~math.abs(me.menuMain)))];
		} else {
			me.str = dictEN[me.menuGPS==TRUE?"GPS":(me.menuTrap==TRUE?"TRAP":(me.menuSvy==TRUE?"SIDV":''~math.abs(me.menuMain)))];
		}
		if (me.str != nil) {
			me.str = me.str[''~button];
			if (me.str != nil and (me.showFullMenus == TRUE or me.str[0] == TRUE)) {
				return me.str[1];
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
			if (me.menuTrap == FALSE) {
				if (me.input.wow1.getValue() == 0) {
					if (getprop("/autopilot/target-tracking-ja37/enable") == TRUE) {
						me.menuButtonBox[1].show();
					}
					me.menuButton[1].setText(me.vertStr("RR"));
				}
				if (me.dataLink == TRUE) {
					me.menuButtonBox[2].show();
				}
				if (land.mode_B_active == TRUE or land.mode_LA_active == TRUE) {
					# is kind of a hack. It pretends that LÅ is a submode in S.
					me.menuButtonBox[4].show();
				}
				if (land.mode_LA_active == TRUE) {
					me.menuButtonBox[17].show();
				}
				if (land.mode_LF_active == TRUE) {
					me.menuButtonBox[18].show();
				}
				if (land.mode_LB_active == TRUE) {
					me.menuButtonBox[19].show();
				}
				if (land.mode_L_active == TRUE) {
					me.menuButtonBox[20].show();
				}
				if (land.mode_OPT_active == TRUE) {
					me.menuButtonBox[3].show();
				}
				if (me.ModeAttack == FALSE) {
					me.menuButtonBox[14].show();
				}
			} else {
				if (me.trapLock == TRUE) {
					me.menuButtonBox[2].show();
				} elsif (me.trapFire == TRUE) {
					me.menuButtonBox[3].show();
				} elsif (me.trapECM == TRUE) {
					me.menuButtonBox[4].show();
				} elsif (me.trapMan == TRUE) {
					me.menuButtonBox[5].show();
				} elsif (me.trapLand == TRUE) {
					me.menuButtonBox[6].show();
				}			
			}
		}
		if (me.menuMain == MAIN_DISPLAY) {
			if (me.displayTime == TRUE) {
				me.menuButtonBox[16].show();
			}
			if (me.day == TRUE) {
				me.menuButtonBox[19].show();
			}
			if (displays.common.cursor == displays.TI) {
				me.menuButtonBox[18].show();
			}
		}
		if (me.menuMain == MAIN_MISSION_DATA) {
			if (me.dragMapEnabled == TRUE) {
				me.menuButtonBox[20].show();
			}
		}
		if (me.menuMain == MAIN_CONFIGURATION and me.menuGPS == TRUE and (getprop("ja37/avionics/gps-nav") == TRUE or(getprop("ja37/avionics/gps-cmd") and me.input.twoHz.getValue()))) {
			me.menuButtonBox[15].show();
		}
		if (me.menuMain == MAIN_CONFIGURATION and me.menuGPS == TRUE and getprop("ja37/avionics/gps-nav") == TRUE) {
			if (radar_logic.selection != nil and radar_logic.selection.get_Callsign() == "FIX") {
				me.menuButtonBox[14].show();
			}
		}
	},

	compileFastMenu: func (button) {
		me.str = nil;
		if (me.interoperability == displays.METRIC) {
			me.str = dictSE[me.menuGPS==TRUE?"GPS":(me.menuTrap==TRUE?"TRAP":(me.menuSvy==TRUE?"SVY":''~math.abs(me.menuMain)))];
		} else {
			me.str = dictEN[me.menuGPS==TRUE?"GPS":(me.menuTrap==TRUE?"TRAP":(me.menuSvy==TRUE?"SIDV":''~math.abs(me.menuMain)))];
		}
		if (me.str != nil) {
			me.str = me.str[''~button];
			if (me.str != nil and (me.showFullMenus == TRUE or me.str[0] == TRUE)) {
				return me.vertStr(me.str[1]);
			}
		}
		return "";
	},

	vertStr: func (str) {
		me.compiled = "";
		for(var i = 0; i < size(str); i+=1) {
			me.sub = substr(str,i,1);
			if (me.sub == "\xC3") {
				# trick to read in Swedish special chars
				me.sub = substr(str,i,2);
				i += 1;
			}
			me.compiled = me.compiled~me.sub~(i==(size(str)-1)?"":"\n");
		}
		return me.compiled;
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
		me.seven = nil;
		if (me.interoperability == displays.METRIC) {
			me.seven = me.menuGPS==TRUE?"GPS":(me.menuTrap==TRUE?"TRAP":(me.menuSvy==TRUE?"SVY":(dictSE['0'][''~math.abs(me.menuMain)][1])));
		} else {
			me.seven = me.menuGPS==TRUE?"GPS":(me.menuTrap==TRUE?"TRAP":(me.menuSvy==TRUE?"SIDV":(dictEN['0'][''~math.abs(me.menuMain)][1])));
		}
		me.menuButtonSub[7].setText(me.vertStr(me.seven));
		if (me.menuMain == MAIN_DISPLAY) {
			#show flight data
			me.menuButtonSub[17].show();
			me.menuButtonSubBox[17].show();
			me.seventeen = nil;
			if (me.interoperability == displays.METRIC) {
				me.seventeen = dictSE['HORI'][''~me.displayFlight][1];
			} else {
				me.seventeen = dictEN['HORI'][''~me.displayFlight][1];
			}
			me.menuButtonSub[17].setText(me.vertStr(me.seventeen));

			# zoom level
			me.menuButtonSub[6].show();
			me.menuButtonSubBox[6].show();
			me.six = zoomLevels[zoom_curr]~"";
			me.menuButtonSub[6].setText(me.vertStr(me.six));

			# day/night map
			me.menuButtonSub[19].setText(me.vertStr(me.interoperability == displays.METRIC?"NATT":"NGHT"));
			me.menuButtonSub[19].show();
			if (me.day == FALSE) {
				me.menuButtonSubBox[19].show();
			}

			# place names overlay
			me.menuButtonSub[3].setText(me.vertStr(me.mapPlaces == TRUE?"MAX":"NORM"));
			me.menuButtonSub[3].show();
			#if (me.mapPlaces == TRUE) {
				me.menuButtonSubBox[3].show();
			#}

			# airports overlay
			me.menuButtonSub[4].setText(me.vertStr(me.interoperability == displays.METRIC?"TMAD":"AIRP"));
			me.menuButtonSub[4].show();
			if (me.basesEnabled == TRUE) {
				me.menuButtonSubBox[4].show();
			}

			# threat overlay
			me.menuButtonSub[14].setText(me.vertStr(me.interoperability == displays.METRIC?"FI":"HSTL"));
			me.menuButtonSub[14].show();
			if (me.showHostileZones == TRUE) {
				me.menuButtonSubBox[14].show();
			}

			# friendly AAA
			me.menuButtonSub[15].setText(me.vertStr(me.interoperability == displays.METRIC?"EGET":"FRND"));
			me.menuButtonSub[15].show();
			if (me.showFriendlyZones == TRUE) {
				me.menuButtonSubBox[15].show();
			}
		}
		if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
			if (me.input.wow1.getValue() == TRUE) {
				me.menuButtonSub[1].setText(me.vertStr("EP"));
				me.menuButtonSub[1].show();
			}
			me.menuButtonSub[14].setText(me.vertStr("ATT"));
			if (me.ModeAttack == TRUE) {
				me.menuButtonSubBox[14].show();
			}
			me.menuButtonSub[14].show();

			me.menuButtonSub[5].setText(me.vertStr(route.Polygon.flyMiss.getNameNumber()));
			me.menuButtonSub[5].show();
			if (route.Polygon.flyMiss == route.Polygon.primary) {
				me.menuButtonSubBox[5].show();
			}

			me.menuButtonSub[16].setText(me.vertStr(route.Polygon.flyRTB.getNameVariant()));
			me.menuButtonSub[16].show();
			if (route.Polygon.flyRTB == route.Polygon.primary) {
				me.menuButtonSubBox[16].show();
			}
		}
		if (me.menuMain == MAIN_MISSION_DATA) {
			if (me.showFullMenus == TRUE) {
				me.menuButtonSub[4].setText(me.vertStr("BEYE"));
				me.menuButtonSub[4].show();
			}

			me.isP = route.Polygon.editing != nil and route.Polygon.editing.type == route.TYPE_AREA;
			#hack:
			me.menuButtonSub[2].setText(me.vertStr(me.isP?"P":(me.interoperability == displays.METRIC?"B":"S")));
			me.menuButtonSub[2].show();
			if (route.Polygon.insertSteer) {
				me.menuButtonSubBox[2].show();
			}
			me.menuButtonSub[3].setText(me.vertStr(me.isP?"P":(me.interoperability == displays.METRIC?"B":"S")));
			me.menuButtonSub[3].show();
			if (route.Polygon.appendSteer) {
				me.menuButtonSubBox[3].show();
			}
			me.menuButtonSub[5].setText(me.vertStr(me.isP?"P":(me.interoperability == displays.METRIC?"B":"S")));
			me.menuButtonSub[5].show();

			me.menuButtonSub[6].setText(me.vertStr("POLY"));
			me.menuButtonSub[6].show();
			if (route.Polygon.editing != nil and (route.Polygon.editing.type == route.TYPE_AREA)) {
				me.menuButtonSubBox[6].show();
			}

			######

			if (me.ownPositionDigital == 0) {
				me.menuButtonSub[19].show();
			} else {
				me.menuButtonSub[19].setText(""~me.ownPositionDigital);
				me.menuButtonSub[19].show();
				me.menuButtonSubBox[19].show();
			}
			me.menuButtonSub[18].setText(me.vertStr(me.isP?"P":(me.interoperability == displays.METRIC?"B":"S")));
			me.menuButtonSub[18].show();
			if (route.Polygon.editSteer) {
				me.menuButtonSubBox[18].show();
			}
			me.menuButtonSub[14].setText(me.vertStr(me.interoperability == displays.METRIC?"\xC3\x85POL":"RPOL"));
			me.menuButtonSub[16].setText(me.vertStr(me.interoperability == displays.METRIC?"UPOL":"MPOL"));
			me.menuButtonSub[15].setText(me.vertStr(route.Polygon.editRTB.getNameVariant()));
			me.menuButtonSub[17].setText(me.vertStr(route.Polygon.editMiss.getNameNumber()));
			me.menuButtonSub[17].show();
			me.menuButtonSub[15].show();
			if (route.Polygon.editing != nil and (route.Polygon.editing.type == route.TYPE_MISS or route.Polygon.editing.type == route.TYPE_MIX)) {
				me.menuButtonSubBox[16].show();
			}
			if (route.Polygon.editing != nil and (route.Polygon.editing.type == route.TYPE_RTB or route.Polygon.editing.type == route.TYPE_MIX)) {
				me.menuButtonSubBox[14].show();
			}
			me.menuButtonSub[14].show();
			me.menuButtonSub[16].show();
		}
		if (me.menuMain == MAIN_CONFIGURATION and me.menuGPS == FALSE and me.menuSvy == FALSE) {
			# use top or belly antaenna
			me.ant = nil;
			if (me.interoperability == displays.METRIC) {
				me.ant = me.fr28Top==TRUE?"RYG":"BUK";
			} else {
				me.ant = me.fr28Top==TRUE?"OVER":"UNDR";
			}
			me.menuButtonSub[6].setText(me.vertStr(me.ant));
			me.menuButtonSub[6].show();
			me.menuButtonSubBox[6].show();
			me.menuButtonSub[19].setText(me.vertStr("DATA"));
			me.menuButtonSub[19].show();
		}
		if (me.menuMain == MAIN_CONFIGURATION and me.menuSvy == TRUE) {
			# side view configuration
			me.menuButtonSub[5].setText(me.vertStr(""~me.SVYsize));
			me.menuButtonSub[5].show();
			me.menuButtonSubBox[5].show();
			if (me.SVYinclude == SVY_ALL) {
				me.menuButtonSub[6].setText(me.vertStr(me.interoperability == displays.METRIC?"ALLT":"ALL"));
			} elsif (me.SVYinclude == SVY_120) {
				me.menuButtonSub[6].setText(me.vertStr("120"));
			} else {
				me.menuButtonSub[6].setText(me.vertStr(me.interoperability == displays.METRIC?"RR":"RR"));
			}
			me.menuButtonSub[6].show();
			me.menuButtonSubBox[6].show();

			me.skal = nil;
			if (me.interoperability == displays.METRIC) {
				me.skal = me.SVYscale==SVY_ELKA?"ELKA":(me.SVYscale==SVY_MI?"MI":"RMAX");
			} else {
				me.skal = me.SVYscale==SVY_ELKA?"EMAP":(me.SVYscale==SVY_MI?"MI":"RMAX");
			}
			me.menuButtonSub[14].setText(me.vertStr(me.skal));
			me.menuButtonSub[14].show();
			me.menuButtonSubBox[14].show();

			me.menuButtonSub[15].setText(me.vertStr(sprintf("%d", me.SVYrmax*1000*M2NM)));
			me.menuButtonSub[15].show();
			me.menuButtonSubBox[15].show();

			me.menuButtonSub[16].setText(me.vertStr(sprintf("%d", me.SVYhmax*M2FT)));
			me.menuButtonSub[16].show();
			me.menuButtonSubBox[16].show();
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
		me.trapMan  = FALSE;
		me.trapLock = FALSE;
		me.trapECM  = FALSE;
		me.trapLand = FALSE;
	},





	########################################################################################################
	########################################################################################################
	#
	#  MI functions
	#
	#
	########################################################################################################
	########################################################################################################

	updateMI: func {
		if (me.mreg == TRUE and me.mreg_time+3 < getprop("sim/time/elapsed-sec")) {
			me.mreg = FALSE;
		}
	},

	showSVY: func {
		# side view
		if (!me.active) return;
		me.SVYactive = !me.SVYactive;
	},

	showECM: func {
		# ECM and warnings
		if (!me.active) return;
		me.ECMon = !me.ECMon;
	},

	showLNK: func {
		# show RB99 link
		if (!me.active) return;

		me.lnk99 = !me.lnk99;
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
		me.tgt = "";
		me.mreg = TRUE;
		me.mreg_time = getprop("sim/time/elapsed-sec");
		if(radar_logic.selection != nil) {
			me.tgt = radar_logic.selection.get_Callsign();
		}
		me.echoes = size(radar_logic.tracks);
		me.message = sprintf("\n      IAS: %d kt\n      Heading: %d deg\n      Alt: %d ft\n      Selected: %s\n      Echoes: %d\n      Lat: %.4f deg\n      Lon: %.4f deg",
			me.input.ias.getValue(),
			me.input.headMagn.getValue(),
			me.input.alt_ft.getValue(),
			me.echoes==0?"":me.tgt,
			me.echoes,
			getprop("position/latitude-deg"),
			getprop("position/longitude-deg")
			);
		me.logEvents.push(me.message);
	},


	########################################################################################################
	########################################################################################################
	#
	#  misc overlays
	#
	#
	########################################################################################################
	########################################################################################################

	showCursor: func {
		if (displays.common.cursor == displays.TI and MI.cursorOn == TRUE) {
			if(!getprop("/ja37/systems/input-controls-flight")) {
				me.cursorSpeedY = getprop("fdm/jsbsim/fcs/elevator-cmd-norm");
				me.cursorSpeedX = getprop("fdm/jsbsim/fcs/aileron-cmd-norm");
				me.cursorMoveY  = 150 * me.rate * me.cursorSpeedY;
				me.cursorMoveX  = 150 * me.rate * me.cursorSpeedX;
				me.cursorPosX  += me.cursorMoveX;
				me.cursorPosY  += me.cursorMoveY;
				me.cursorPosX   = clamp(me.cursorPosX, -width*0.5,  width*0.5);
				me.cursorPosY   = clamp(me.cursorPosY, -me.rootCenterY, height-me.rootCenterY);#relative to map center
				me.cursorGPosX = me.cursorPosX + width*0.5;
				me.cursorGPosY = me.cursorPosY + me.rootCenterY;# relative to canvas
				me.cursorOPosX = me.cursorPosX + me.tempReal[0];
				me.cursorOPosY = me.cursorPosY + me.tempReal[1];# relative to rootCenter
				me.cursor.setTranslation(me.cursorGPosX,me.cursorGPosY);# is off set 1 pixel to right
				me.cursorTrigger = getprop("controls/armament/trigger");
				#printf("(%d,%d) %d",me.cursorPosX,me.cursorPosY, me.cursorTrigger);
				if (route.Polygon.editSteer) {
					#print("dragging steerpoint: "~geo.format(me.newSteerPos[0],me.newSteerPos[1]));
					if(me.cursorTrigger and !me.cursorTriggerPrev) {
						me.newSteerPos = me.TexelToLaLoMap(me.cursorPosX, me.cursorPosY);
						route.Polygon.editApply(me.newSteerPos[0],me.newSteerPos[1]);
					}
				} elsif (route.Polygon.insertSteer) {
					if(me.cursorTrigger and !me.cursorTriggerPrev) {
						me.newSteerPos = me.TexelToLaLoMap(me.cursorPosX, me.cursorPosY);
						route.Polygon.insertApply(me.newSteerPos[0],me.newSteerPos[1]);
					}
					#me.newSteerPos = nil;
				} elsif (route.Polygon.appendSteer) {
					if(me.cursorTrigger and !me.cursorTriggerPrev) {#if thsi is nested condition then only this can be done. Is this what we want?
						me.newSteerPos = me.TexelToLaLoMap(me.cursorPosX, me.cursorPosY);
						route.Polygon.appendApply(me.newSteerPos[0],me.newSteerPos[1]);
					}
					#me.newSteerPos = nil;
				} elsif (me.cursorTrigger and !me.cursorTriggerPrev) {
					# click on edge buttons
					me.newSteerPos = nil;
					me.bMethod = me.getButtonMethod();
					if (me.bMethod != nil) {
						me.bMethod();
					} elsif (me.dragMapEnabled) {
						me.newMapPos = me.TexelToLaLoMap(me.cursorPosX, me.cursorPosY);
						me.lat = me.newMapPos[0];
						me.lon = me.newMapPos[1];
						me.mapSelfCentered = FALSE;
					}
				}
			} else {
				me.cursorTrigger = FALSE;
				me.newSteerPos = nil;
			}
			me.cursor.show();
		} else {
			me.cursorTrigger = FALSE;
			me.newSteerPos = nil;
			me.cursor.hide();
		}
		me.cursorTriggerPrev = me.cursorTrigger;
	},

	getButtonMethod: func () {
		#TODO: should really highlight menutext
		if (me.cursorGPosY > height-6.25*2) {
			# possible main menu click
			if (me.cursorGPosX > width*0.135+((8-8)*width*0.1475)-6.25*3 and me.cursorGPosX < width*0.135+((8-8)*width*0.1475)-6.25*3+6*6.25) {
				return me.b8;
			}
			if (me.cursorGPosX > width*0.135+((9-8)*width*0.1475)-6.25*3 and me.cursorGPosX < width*0.135+((9-8)*width*0.1475)-6.25*3+6*6.25) {
				return me.b9;
			}
			if (me.cursorGPosX > width*0.135+((10-8)*width*0.1475)-6.25*3 and me.cursorGPosX < width*0.135+((10-8)*width*0.1475)-6.25*3+6*6.25) {
				return me.b10;
			}
			if (me.cursorGPosX > width*0.135+((11-8)*width*0.1475)-6.25*3 and me.cursorGPosX < width*0.135+((11-8)*width*0.1475)-6.25*3+6*6.25) {
				return me.b11;
			}
			if (me.cursorGPosX > width*0.135+((12-8)*width*0.1475)-6.25*3 and me.cursorGPosX < width*0.135+((12-8)*width*0.1475)-6.25*3+6*6.25) {
				return me.b12;
			}
			if (me.cursorGPosX > width*0.135+((13-8)*width*0.1475)-6.25*3 and me.cursorGPosX < width*0.135+((13-8)*width*0.1475)-6.25*3+6*6.25) {
				return me.b13;
			}
		} elsif (me.cursorGPosX < width*0.060-3.125+2*6.25) {
			# possible left menu click
			if (me.cursorGPosY > height*0.09+(1-1)*height*0.11-6.25*4 and me.cursorGPosY < height*0.09+(1-1)*height*0.11-6.25*4+8*6.25) {
				return me.b1;
			}
			if (me.cursorGPosY > height*0.09+(2-1)*height*0.11-6.25*4 and me.cursorGPosY < height*0.09+(2-1)*height*0.11-6.25*4+8*6.25) {
				return me.b2;
			}
			if (me.cursorGPosY > height*0.09+(3-1)*height*0.11-6.25*4 and me.cursorGPosY < height*0.09+(3-1)*height*0.11-6.25*4+8*6.25) {
				return me.b3;
			}
			if (me.cursorGPosY > height*0.09+(4-1)*height*0.11-6.25*4 and me.cursorGPosY < height*0.09+(4-1)*height*0.11-6.25*4+8*6.25) {
				return me.b4;
			}
			if (me.cursorGPosY > height*0.09+(5-1)*height*0.11-6.25*4 and me.cursorGPosY < height*0.09+(5-1)*height*0.11-6.25*4+8*6.25) {
				return me.b5;
			}
			if (me.cursorGPosY > height*0.09+(6-1)*height*0.11-6.25*4 and me.cursorGPosY < height*0.09+(6-1)*height*0.11-6.25*4+8*6.25) {
				return me.b6;
			}
			if (me.cursorGPosY > height*0.09+(7-1)*height*0.11-6.25*4 and me.cursorGPosY < height*0.09+(7-1)*height*0.11-6.25*4+8*6.25) {
				return me.b7;
			}
		} elsif (me.cursorGPosX > width*0.940+3.125-2*6.25) {
			# possible right menu click
			if (me.cursorGPosY > height*0.09+(1-1)*height*0.11-6.25*4 and me.cursorGPosY < height*0.09+(1-1)*height*0.11-6.25*4+8*6.25) {
				return me.b20;
			}
			if (me.cursorGPosY > height*0.09+(2-1)*height*0.11-6.25*4 and me.cursorGPosY < height*0.09+(2-1)*height*0.11-6.25*4+8*6.25) {
				return me.b19;
			}
			if (me.cursorGPosY > height*0.09+(3-1)*height*0.11-6.25*4 and me.cursorGPosY < height*0.09+(3-1)*height*0.11-6.25*4+8*6.25) {
				return me.b18;
			}
			if (me.cursorGPosY > height*0.09+(4-1)*height*0.11-6.25*4 and me.cursorGPosY < height*0.09+(4-1)*height*0.11-6.25*4+8*6.25) {
				return me.b17;
			}
			if (me.cursorGPosY > height*0.09+(5-1)*height*0.11-6.25*4 and me.cursorGPosY < height*0.09+(5-1)*height*0.11-6.25*4+8*6.25) {
				return me.b16;
			}
			if (me.cursorGPosY > height*0.09+(6-1)*height*0.11-6.25*4 and me.cursorGPosY < height*0.09+(6-1)*height*0.11-6.25*4+8*6.25) {
				return me.b15;
			}
			if (me.cursorGPosY > height*0.09+(7-1)*height*0.11-6.25*4 and me.cursorGPosY < height*0.09+(7-1)*height*0.11-6.25*4+8*6.25) {
				return me.b14;
			}
		} elsif (me.cursorGPosY > me.wpStarty-me.wpH*height and me.cursorGPosY < me.wpStarty and me.cursorGPosX < me.wpStartx+me.wpW*width and me.cursorGPosX > me.wpStartx) {
			# possible infoBox click
			if (me.cursorGPosY < me.wpStarty-0.8*me.wpH*height) {
				return me.box2;
			}
			if (me.cursorGPosY < me.wpStarty-0.6*me.wpH*height) {
				return me.box3;
			}
			if (me.cursorGPosY < me.wpStarty-0.4*me.wpH*height) {
				return me.box4;
			}
			if (me.cursorGPosY < me.wpStarty-0.2*me.wpH*height) {
				return me.box5;
			}
		}
		return nil;
	},

	isDAPActive: func {
		return me.blinkBox2 or me.blinkBox3 or me.blinkBox4 or me.blinkBox5;
	},

	stopDAP: func {
		me.blinkBox2 = FALSE;
		me.blinkBox3 = FALSE;
		me.blinkBox4 = FALSE;
		me.blinkBox5 = FALSE;
		route.Polygon.editDetailMethod(FALSE);
		if (dap.state == 237) {
			dap.set237(FALSE, 0, 0, nil);
		}
	},

	box2: func {
		if (me.isDAPActive() and me.blinkBox2 != TRUE) {
			# stop another field edit
			me.stopDAP();
		}
		if (me.isDAPActive()) {
			# cancel this field edit
			me.stopDAP();
		} elsif (!me.isDAPActive() and me.menuMain == MAIN_MISSION_DATA) {
			if (route.Polygon.editing != nil and route.Polygon.selectSteer != nil and route.Polygon.editing.type != route.TYPE_AREA) {
				route.Polygon.editDetailMethod(TRUE);
				dap.set237(TRUE, 7, me.dapBLo);
				me.blinkBox2 = TRUE;
			}
			if (route.Polygon.editing != nil and route.Polygon.editing.type == route.TYPE_AREA) {
				dap.set237(TRUE, 1, me.dapA);
				me.blinkBox2 = TRUE;
			}
		}
	},

	box3: func {
		if (me.isDAPActive() and me.blinkBox3 != TRUE) {
			# stop another field edit
			me.stopDAP();
		}
		if (me.isDAPActive()) {
			# cancel this field edit
			me.stopDAP();
		} elsif (!me.isDAPActive() and me.menuMain == MAIN_MISSION_DATA) {
			if (route.Polygon.editing != nil and route.Polygon.selectSteer != nil and route.Polygon.editing.type != route.TYPE_AREA) {
				route.Polygon.editDetailMethod(TRUE);
				dap.set237(TRUE, 6, me.dapBLa);
				me.blinkBox3 = TRUE;
			}
		}
	},

	box4: func {
		if (me.isDAPActive() and me.blinkBox4 != TRUE) {
			# stop another field edit
			me.stopDAP();
		}
		if (me.isDAPActive()) {
			# cancel this field edit
			me.stopDAP();
		} elsif (!me.isDAPActive() and me.menuMain == MAIN_MISSION_DATA) {
			if (route.Polygon.editing != nil and route.Polygon.selectSteer != nil and route.Polygon.editing.type != route.TYPE_AREA) {
				route.Polygon.editDetailMethod(TRUE);
				dap.set237(TRUE, 5, me.dapBalt);
				me.blinkBox4 = TRUE;
			} elsif (route.Polygon.editing != nil and route.Polygon.selectSteer != nil and route.Polygon.editing.type == route.TYPE_AREA) {
				route.Polygon.editDetailMethod(TRUE);
				dap.set237(TRUE, 7, me.dapBLo);
				me.blinkBox2 = TRUE;
			}
		}
	},

	box5: func {
		if (me.isDAPActive() and me.blinkBox5 != TRUE) {
			# stop another field edit
			me.stopDAP();
		}
		if (me.isDAPActive()) {
			# cancel this field edit
			me.stopDAP();
		} elsif (!me.isDAPActive() and me.menuMain == MAIN_MISSION_DATA) {
			if (route.Polygon.editing != nil and route.Polygon.selectSteer != nil and route.Polygon.editing.type != route.TYPE_AREA) {
				route.Polygon.editDetailMethod(TRUE);
				dap.set237(TRUE, 3, me.dapBspeed);
				me.blinkBox5 = TRUE;
			} elsif (route.Polygon.editing != nil and route.Polygon.selectSteer != nil and route.Polygon.editing.type == route.TYPE_AREA) {
				route.Polygon.editDetailMethod(TRUE);
				dap.set237(TRUE, 6, me.dapBLa);
				me.blinkBox3 = TRUE;
			}
		}
	},

	dapBLo: func (input, sign, myself) {
		# 
		sign = sign==0?"":"-";
		var deg = ja37.stringToLon(sign~input);
		print("TI recieved LO from DAP: "~sign~input);
		if (deg!=nil) {
			print("converted "~sign~input~" to "~ja37.convertDegreeToStringLon(deg));
			route.Polygon.setLon(deg);
			myself.stopDAP();
		} else {
			dap.setError();
		}
	},

	dapBLa: func (input, sign, myself) {
		# 
		sign = sign==0?"":"-";
		var deg = ja37.stringToLat(sign~input);
		print("TI recieved LA from DAP: "~sign~input);
		if (deg!=nil) {
			print("converted "~sign~input~" to "~ja37.convertDegreeToStringLat(deg));
			route.Polygon.setLat(deg);
			myself.stopDAP();
		} else {
			dap.setError();
		}
	},

	dapA: func (input, sign, myself) {
		# 
		if (input == 0 or input > 6 or sign) {
			dap.setError();
		} else {
			route.Polygon.editPlan(route.Polygon.polys["OP"~input]);
			print("TI recieved area number from DAP: "~input);
			myself.stopDAP();
		}
	},

	dapBspeed: func (input, sign, myself) {
		# 
		if (sign) {
			dap.setError();
		} else {
			var mach = num(input)/100;
			print("TI recieved mach from DAP: M"~mach);
			route.Polygon.setMach(mach);
			myself.stopDAP();
		}
	},

	dapBalt: func (input, sign, myself) {
		# 
		if (sign) {
			dap.setError();
		} else {
			var alt = num(input);
			print("TI recieved alt from DAP: "~alt);
			route.Polygon.setAlt(myself.interoperability == displays.METRIC?alt*M2FT:alt);#important!!! running in metric will input metric also!
			myself.stopDAP();
		}
	},

	ecmOverlay: func {
		if (me.ECMon == TRUE) {
			if (getprop("ja37/sound/incoming12") == TRUE) {
				me.ecm12.setColor(rRed,gRed,bRed,a);
			} elsif (radar_logic.rwr[11] == TRUE) {
				me.ecm12.setColor(rYellow,gYellow,bYellow,a);
			} else {
				me.ecm12.setColor(rGreen,gGreen,bGreen,a);
			}
			if (getprop("ja37/sound/incoming1") == TRUE) {
				me.ecm1.setColor(rRed,gRed,bRed,a);
			} elsif (radar_logic.rwr[0] == TRUE) {
				me.ecm1.setColor(rYellow,gYellow,bYellow,a);
			} else {
				me.ecm1.setColor(rGreen,gGreen,bGreen,a);
			}
			if (getprop("ja37/sound/incoming2") == TRUE) {
				me.ecm2.setColor(rRed,gRed,bRed,a);
			} elsif (radar_logic.rwr[1] == TRUE) {
				me.ecm2.setColor(rYellow,gYellow,bYellow,a);
			} else {
				me.ecm2.setColor(rGreen,gGreen,bGreen,a);
			}
			if (getprop("ja37/sound/incoming3") == TRUE) {
				me.ecm3.setColor(rRed,gRed,bRed,a);
			} elsif (radar_logic.rwr[2] == TRUE) {
				me.ecm3.setColor(rYellow,gYellow,bYellow,a);
			} else {
				me.ecm3.setColor(rGreen,gGreen,bGreen,a);
			}
			if (getprop("ja37/sound/incoming4") == TRUE) {
				me.ecm4.setColor(rRed,gRed,bRed,a);
			} elsif (radar_logic.rwr[3] == TRUE) {
				me.ecm4.setColor(rYellow,gYellow,bYellow,a);
			} else {
				me.ecm4.setColor(rGreen,gGreen,bGreen,a);
			}
			if (getprop("ja37/sound/incoming5") == TRUE) {
				me.ecm5.setColor(rRed,gRed,bRed,a);
			} elsif (radar_logic.rwr[4] == TRUE) {
				me.ecm5.setColor(rYellow,gYellow,bYellow,a);
			} else {
				me.ecm5.setColor(rGreen,gGreen,bGreen,a);
			}
			if (getprop("ja37/sound/incoming6") == TRUE) {
				me.ecm6.setColor(rRed,gRed,bRed,a);
			} elsif (radar_logic.rwr[5] == TRUE) {
				me.ecm6.setColor(rYellow,gYellow,bYellow,a);
			} else {
				me.ecm6.setColor(rGreen,gGreen,bGreen,a);
			}
			if (getprop("ja37/sound/incoming7") == TRUE) {
				me.ecm7.setColor(rRed,gRed,bRed,a);
			} elsif (radar_logic.rwr[6] == TRUE) {
				me.ecm7.setColor(rYellow,gYellow,bYellow,a);
			} else {
				me.ecm7.setColor(rGreen,gGreen,bGreen,a);
			}
			if (getprop("ja37/sound/incoming8") == TRUE) {
				me.ecm8.setColor(rRed,gRed,bRed,a);
			} elsif (radar_logic.rwr[7] == TRUE) {
				me.ecm8.setColor(rYellow,gYellow,bYellow,a);
			} else {
				me.ecm8.setColor(rGreen,gGreen,bGreen,a);
			}
			if (getprop("ja37/sound/incoming9") == TRUE) {
				me.ecm9.setColor(rRed,gRed,bRed,a);
			} elsif (radar_logic.rwr[8] == TRUE) {
				me.ecm9.setColor(rYellow,gYellow,bYellow,a);
			} else {
				me.ecm9.setColor(rGreen,gGreen,bGreen,a);
			}
			if (getprop("ja37/sound/incoming10") == TRUE) {
				me.ecm10.setColor(rRed,gRed,bRed,a);
			} elsif (radar_logic.rwr[9] == TRUE) {
				me.ecm10.setColor(rYellow,gYellow,bYellow,a);
			} else {
				me.ecm10.setColor(rGreen,gGreen,bGreen,a);
			}
			if (getprop("ja37/sound/incoming11") == TRUE) {
				me.ecm11.setColor(rRed,gRed,bRed,a);
			} elsif (radar_logic.rwr[10] == TRUE) {
				me.ecm11.setColor(rYellow,gYellow,bYellow,a);
			} else {
				me.ecm11.setColor(rGreen,gGreen,bGreen,a);
			}
			me.ecm_grp.show();
		} else {
			me.ecm_grp.hide();
		}
	},

	testLanding: func {
		me.wow = me.input.wow0.getValue() and me.input.wow0.getValue() and me.input.wow0.getValue();
		if (me.landed == FALSE and me.wow == TRUE) {
			me.logLand.push("Has landed.");
			me.landed = TRUE;
		} elsif (me.wow == FALSE) {
			me.landed = FALSE;
		}
	},

	updateSVY: func {
		# update and display side view
		if (me.SVYactive == TRUE) {
			me.svy_grp2.removeAllChildren();
			
			me.SVYoriginX = width*0.05;#texel
			me.SVYoriginY = height*0.125+height*0.125*me.SVYsize-height*0.05;#texel
			me.SVYwidth   = width*0.90;#texel
			me.SVYheight  = height*0.125+height*0.125*me.SVYsize-height*0.10;#texel
			me.SVYalt     = me.SVYhmax*1000;#meter
			me.SVYrange   = me.SVYscale==SVY_MI?me.input.radarRange.getValue():(me.SVYscale==SVY_RMAX?me.SVYrmax*1000:me.SVYwidth/M2TEX);#meter
			me.SVYticksize= width*0.01;#texel

			# not the most efficient code..
			me.svy_grp2.createChild("path")
				.moveTo(me.SVYoriginX, height*0.05)
				.vert(me.SVYheight)
				.horiz(me.SVYwidth)
				.moveTo(me.SVYoriginX-me.SVYticksize, height*0.05)
				.horiz(me.SVYticksize*2)
				.moveTo(me.SVYoriginX-me.SVYticksize, height*0.05+me.SVYheight*0.5)
				.horiz(me.SVYticksize*2)
				.moveTo(me.SVYoriginX-me.SVYticksize, height*0.05+me.SVYheight*0.75)
				.horiz(me.SVYticksize*2)
				.moveTo(me.SVYoriginX-me.SVYticksize, height*0.05+me.SVYheight*0.25)
				.horiz(me.SVYticksize*2)
				.moveTo(me.SVYoriginX+me.SVYwidth, me.SVYoriginY-me.SVYticksize)
				.vert(me.SVYticksize*2)
				.moveTo(me.SVYoriginX+me.SVYwidth*0.5, me.SVYoriginY-me.SVYticksize)
				.vert(me.SVYticksize*2)
				.moveTo(me.SVYoriginX+me.SVYwidth*0.75, me.SVYoriginY-me.SVYticksize)
				.vert(me.SVYticksize*2)
				.moveTo(me.SVYoriginX+me.SVYwidth*0.25, me.SVYoriginY-me.SVYticksize)
				.vert(me.SVYticksize*2)
				.setStrokeLineWidth(w)
				.setColor(rWhite,gWhite,bWhite,a);

			me.selfSymbolSvy.setTranslation(me.SVYoriginX, me.SVYoriginY-me.SVYheight*me.input.alt_ft.getValue()*FT2M/me.SVYalt);
			me.selfSymbolSvy.setRotation(90*D2R);
			me.selfVectorSvy.setTranslation(me.SVYoriginX, me.SVYoriginY-me.SVYheight*me.input.alt_ft.getValue()*FT2M/me.SVYalt);
			#me.selfVectorSvy.setRotation(90*D2R);

			me.textX = "";
			me.textY = "";

			if (me.interoperability == displays.METRIC) {
				me.textX = sprintf("%d KM" ,me.SVYrange*0.001);
				me.textY = sprintf("%d KM" ,me.SVYhmax);
			} else {
				me.textX = sprintf("%d NM" ,me.SVYrange*M2NM);
				me.textY = sprintf("%dK FT" ,me.SVYhmax*M2FT);
			}

			me.textSvyX.setText(me.textX);
			me.textSvyY.setText(me.textY);
			me.textSvyY.setTranslation(me.SVYoriginX, height*0.05-w);
			me.textSvyX.setTranslation(width*0.95, height*0.125+height*0.125*me.SVYsize-height*0.05+me.SVYticksize+w);

			me.svy_grp.update();
			me.svy_grp.show();
		} else {
			me.svy_grp.hide();
		}
	},

	updateMapNames: func {
		if (me.mapPlaces == PLACES or me.menuMain == MAIN_MISSION_DATA) {
			type = "light_all";
			makePath = string.compileTemplate(maps_base ~ '/cartoLN/{z}/{x}/{y}.png');
		} else {
			type = "light_nolabels";
			makePath = string.compileTemplate(maps_base ~ '/cartoL/{z}/{x}/{y}.png');
		}
	},

	updateBasesNear: func {
		if (me.basesEnabled == TRUE) {
			me.basesNear = [];
			me.ports = findAirportsWithinRange(75);
			foreach(var port; me.ports) {
				me.small = size(port.id) < 4;
			    append(me.basesNear, {"icao": port.id, "lat": port.lat, "lon": port.lon, "elev": port.elevation, "small": me.small});
			}
		}
	},

	showBasesNear: func {
		if (me.basesEnabled == TRUE and zoom_curr >= 2) {
			me.numL = 0;
			me.numS = 0;
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
					      		if (me.numS < maxBases) {
					      			me.baseSmall[me.numS].setTranslation(me.pixelX, me.pixelY);
					      			me.baseSmallText[me.numS].setTranslation(me.pixelX, me.pixelY);
					      			me.baseSmallText[me.numS].setText(me.baseIcao);
					      			me.baseSmallText[me.numS].setRotation(-getprop("orientation/heading-deg")*D2R);
					      			me.baseSmall[me.numS].show();
					      			me.baseSmallText[me.numS].show();
					      			me.numS += 1;
					      		}
				      		} else {
				      			if (me.numL < maxBases) {
				      				me.baseLarge[me.numL].setTranslation(me.pixelX, me.pixelY);
					      			me.baseLargeText[me.numL].setTranslation(me.pixelX, me.pixelY);
					      			me.baseLargeText[me.numL].setText(me.baseIcao);
					      			me.baseLargeText[me.numL].show();
					      			me.baseLargeText[me.numL].setRotation(-getprop("orientation/heading-deg")*D2R);
					      			me.baseLarge[me.numL].show();
					      			me.numL += 1;
					      		}
				      		}
				      	}
			    	}
			    }
			}
			for(var i = me.numL; i < maxBases; i += 1) {
				me.baseLargeText[i].hide();
				me.baseLarge[i].hide();
			}
			for(var i = me.numS; i < maxBases; i += 1) {
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
	  			me.tgtTextSpd.setText("");
	  			me.tgtTextHei.setText("");
	  		}
			me.tgtTextField.show();
		} else {
			me.tgtTextField.hide();
		}
	},

	showSteerPointInfo: func {
		if (me.menuMain == MAIN_CONFIGURATION and me.menuGPS == TRUE) {
			# GPS info
			me.wpText4.setFontSize(15, 1);
			me.wpText5.setFontSize(15, 1);
			me.wpText2.show();
			me.wpText3.show();
			me.wpText4.show();
			me.wpText5.show();

			me.wpText2Desc.setText("LON");
			me.wpText2.setText(getprop("ja37/avionics/gps-nav")?ja37.convertDegreeToStringLon(getprop("position/longitude-deg")):"000 00 00");

			me.wpText3Desc.setText("LAT");
			me.wpText3.setText(getprop("ja37/avionics/gps-nav")?ja37.convertDegreeToStringLat(getprop("position/latitude-deg")):"00 00 00");

			me.wpText2.setFontSize(13, 1.0);
			me.wpText3.setFontSize(13, 1.0);

			me.wpText4Desc.setText("FOM");
			me.wpText4.setText(getprop("ja37/avionics/gps-nav")?"1":"");

			me.wpText5Desc.setText("MOD");
			me.wpText5.setText(getprop("ja37/avionics/gps-cmd")?(getprop("ja37/avionics/gps-nav")?"NAV":"INIT"):"BIT");

			me.wpText6Desc.setText("FEL");
			me.wpText6.setText(getprop("fdm/jsbsim/systems/electrical/battery-charge-norm")<0.1?"BATT":"");

			me.wpText2.update();
			me.wpText3.update();
			me.wpText4.update();
			me.wpText5.update();

			me.wpTextFrame1.hide();
			me.wpText1.hide();
			me.wpText1Desc.hide();

			me.wpTextField.show();
			me.wpTextField.update();
		} elsif (me.menuMain == MAIN_MISSION_DATA) {
			if (route.Polygon.editing != nil and route.Polygon.selectSteer != nil and route.Polygon.editing.type != route.TYPE_AREA) {
				# info about selected steerpoint			
				me.wpText4.setFontSize(15, 1);
				me.wpText5.setFontSize(15, 1);

				me.wpText1Desc.setText("ID");
				me.wpText1.show();
				me.wpText1.setText(route.Polygon.selectSteer[0].id);
				me.wpText1Desc.show();
				me.wpTextFrame1.show();

				me.wpText2Desc.setText("LON");
				me.wpText2.setText(ja37.convertDegreeToStringLon(route.Polygon.selectSteer[0].wp_lon));
				me.wpText2.setFontSize(13, 1.0);
				if (me.blinkBox2 == FALSE or me.input.twoHz.getValue()) {
					me.wpText2.show();
				} else {
					me.wpText2.hide();
				}
				me.wpText2.update();

				me.wpText3Desc.setText("LAT");
				me.wpText3.setText(ja37.convertDegreeToStringLat(route.Polygon.selectSteer[0].wp_lat));
				me.wpText3.setFontSize(13, 1.0);
				if (me.blinkBox3 == FALSE or me.input.twoHz.getValue()) {
					me.wpText3.show();
				} else {
					me.wpText3.hide();
				}
				me.wpText3.update();

				me.constraint_alt = "-----";
				if (route.Polygon.selectSteer[0].alt_cstr != nil and route.Polygon.selectSteer[0].alt_cstr_type == "at") {
					me.constraint_alt = sprintf("%5d",me.interoperability==displays.METRIC?FT2M*route.Polygon.selectSteer[0].alt_cstr:route.Polygon.selectSteer[0].alt_cstr);
				}
				me.wpText4Desc.setText(me.interoperability==displays.METRIC?"H":"A");
				me.wpText4.setText(me.constraint_alt);
				if (me.blinkBox4 == FALSE or me.input.twoHz.getValue()) {
					me.wpText4.show();
				} else {
					me.wpText4.hide();
				}
				me.wpText4.update();

				me.constraint_speed = "-.--";
				if (route.Polygon.selectSteer[0].speed_cstr != nil and (route.Polygon.selectSteer[0].speed_cstr_type == "mach" or route.Polygon.selectSteer[0].speed_cstr_type == "computed-mach")) {
					me.constraint_speed = sprintf("%0.2f",route.Polygon.selectSteer[0].speed_cstr);
				}
				me.wpText5Desc.setText(me.interoperability==displays.METRIC?"M":"M");
				me.wpText5.setText(me.constraint_speed);
				if (me.blinkBox5 == FALSE or me.input.twoHz.getValue()) {
					me.wpText5.show();
				} else {
					me.wpText5.hide();
				}
				me.wpText5.update();

				me.of = me.interoperability==displays.METRIC?" AV ":" OF ";
				me.wpText6Desc.setText(me.interoperability==displays.METRIC?"B":"S");
				me.wpText6.setText((1+route.Polygon.selectSteer[1])~me.of~route.Polygon.editing.getSize());

				me.wpTextField.update();
				me.wpTextField.show();
			} elsif (route.Polygon.editing != nil) {
				# info about selected area point
				me.wpText2.setFontSize(15, 1);
				me.wpText3.setFontSize(15, 1);
				me.wpText3.show();

				me.wpText2Desc.setText("POL");
				me.wpText2.setText(route.Polygon.editing.getName());
				if (me.blinkBox2 == FALSE or me.input.twoHz.getValue()) {
					me.wpText2.show();
				} else {
					me.wpText2.hide();
				}

				me.of = me.interoperability==displays.METRIC?" AV ":" OF ";
				me.wpText3Desc.setText(route.Polygon.selectSteer != nil?(me.interoperability==displays.METRIC?"PKT":"PNT"):"");
				me.wpText3.setText(route.Polygon.selectSteer != nil?((1+route.Polygon.selectSteer[1])~me.of~route.Polygon.editing.getSize()):"");

				me.wpText4Desc.setText(route.Polygon.selectSteer != nil?"LON":"");
				me.wpText4.setText(route.Polygon.selectSteer != nil?ja37.convertDegreeToStringLon(route.Polygon.selectSteer[0].wp_lon):"");
				me.wpText4.setFontSize(13, 1.0);
				if (me.blinkBox4 == FALSE or me.input.twoHz.getValue()) {
					me.wpText4.show();
				} else {
					me.wpText4.hide();
				}

				me.wpText5Desc.setText(route.Polygon.selectSteer != nil?"LAT":"");
				me.wpText5.setText(route.Polygon.selectSteer != nil?ja37.convertDegreeToStringLat(route.Polygon.selectSteer[0].wp_lat):"");
				me.wpText5.setFontSize(13, 1.0);
				if (me.blinkBox5 == FALSE or me.input.twoHz.getValue()) {
					me.wpText5.show();
				} else {
					me.wpText5.hide();
				}

				me.wpText2.update();
				me.wpText3.update();
				me.wpText4.update();
				me.wpText5.update();

				me.wpText6Desc.hide();
				me.wpText6.hide();
				me.wpTextFrame1.hide();
				me.wpText1.hide();
				me.wpText1Desc.hide();
				me.wpTextField.show();
				me.wpTextField.update();
			} else {
				me.wpTextField.hide();
			}
		} else {
			# little infobox with details about next steerpoint
			me.wp     = getprop("autopilot/route-manager/current-wp");
			me.points = getprop("autopilot/route-manager/route/num");
			if (me.wp > me.points-1) {
				# bug in route manager occurred, fixing it. TODO: fix route-manager.
				setprop("autopilot/route-manager/current-wp", me.points-1);
				me.wp = me.points-1;
			}
			if (me.mapshowing == TRUE and getprop("autopilot/route-manager/active") == TRUE and me.wp != -1 and me.wp != nil and me.showSteers == TRUE and (me.input.currentMode.getValue() != displays.COMBAT or (radar_logic.selection == nil or radar_logic.selection.isPainted() == FALSE))) {
				# steerpoints ON and route active, plus not being in combat and having something selected by radar
				# that if statement needs refining!

				me.wpText2.setFontSize(15, 1);
				me.wpText3.setFontSize(15, 1);
				me.wpText4.setFontSize(15, 1);
				me.wpText5.setFontSize(15, 1);
				me.wpText2.show();
				me.wpText3.show();
				me.wpText4.show();
				me.wpText5.show();

				me.node   = globals.props.getNode("autopilot/route-manager/route/wp["~me.wp~"]");

				me.wpNum  = me.wp+1;
				
				me.legs   = me.points-1;
				me.legText = (me.legs==0 or me.wpNum == 1)?"":(me.wpNum-1)~(me.interoperability==displays.METRIC?" AV ":" OF ")~me.legs;

				me.wpAlt  = me.node.getNode("altitude-ft");
				if (me.wpAlt != nil) {
					me.wpAlt = me.wpAlt.getValue();
				}
				if (me.wpAlt == nil) {
					me.wpAlt = "";
				} elsif (me.wpAlt < 5000) {
					me.wpAlt = "";
				} else {
					# bad coding, shame on me..
					me.wpAlt  = me.interoperability==displays.METRIC?me.wpAlt*FT2M:me.wpAlt;
					me.wpAlt = sprintf("%d", me.wpAlt);
				}

				me.wpSpeed= me.node.getNode("speed-mach");
				if (me.wpSpeed != nil) {
					me.wpSpeed = me.wpSpeed.getValue();
				}
				if (me.wpSpeed == nil) {
					me.wpSpeed = "-.--";
				} else {
					me.wpSpeed = sprintf("%0.2f", me.wpSpeed);
				}

				me.wpETA  = int(getprop("autopilot/route-manager/ete")/60);#mins
				me.wpETAText = sprintf("%d", me.wpETA);
				if (me.wpETA > 500) {
					me.wpETAText = "";
				}

				me.wpText2Desc.setText(me.interoperability==displays.METRIC?"BEN":"LEG");
				me.wpText2.setText(me.legText);
				me.wpText3Desc.setText(me.interoperability==displays.METRIC?"B":"S");
				me.wpText3.setText((me.wpNum-1)~" -> "~me.wpNum);
				me.wpText4Desc.setText(me.interoperability==displays.METRIC?"H":"A");
				me.wpText4.setText(me.wpAlt);
				me.wpText5Desc.setText("M");
				me.wpText5.setText(sprintf("%d", me.interoperability==displays.METRIC?me.wpSpeed*KT2KMH:me.wpSpeed));
				me.wpText6Desc.setText("ETA");
				me.wpText6.setText(me.wpETAText);

				me.wpText2.update();
				me.wpText3.update();
				me.wpText4.update();
				me.wpText5.update();

				me.wpTextFrame1.hide();
				me.wpText1.hide();
				me.wpText1Desc.hide();

				me.wpTextField.show();
				me.wpTextField.update();
			} else {
				me.wpTextField.hide();
			}
		}
	},

	showSteerPoints: func {
		# steerpoints on map
		me.all_plans = [];# 0: plan  1: editing  2: MSDA menu
		me.steerRot = -getprop("orientation/heading-deg")*D2R;
		if (me.menuMain == MAIN_MISSION_DATA) {
			if (route.Polygon.primary.type == route.TYPE_MIX) {
				append(me.all_plans, [route.Polygon.primary, route.Polygon.primary == route.Polygon.editing, TRUE]);
				append(me.all_plans, nil);
				append(me.all_plans, nil);
				append(me.all_plans, nil);
				append(me.all_plans, nil);
				append(me.all_plans, nil);
				append(me.all_plans, [route.Polygon.polys["OP1"], route.Polygon.polys["OP1"] == route.Polygon.editing, TRUE]);
				append(me.all_plans, [route.Polygon.polys["OP2"], route.Polygon.polys["OP2"] == route.Polygon.editing, TRUE]);
				append(me.all_plans, [route.Polygon.polys["OP3"], route.Polygon.polys["OP3"] == route.Polygon.editing, TRUE]);
				append(me.all_plans, [route.Polygon.polys["OP4"], route.Polygon.polys["OP4"] == route.Polygon.editing, TRUE]);
				append(me.all_plans, [route.Polygon.polys["OP5"], route.Polygon.polys["OP5"] == route.Polygon.editing, TRUE]);
				append(me.all_plans, [route.Polygon.polys["OP6"], route.Polygon.polys["OP6"] == route.Polygon.editing, TRUE]);
			} else {
				append(me.all_plans, [route.Polygon.polys["1"], route.Polygon.polys["1"] == route.Polygon.editing, TRUE]);
				append(me.all_plans, [route.Polygon.polys["2"], route.Polygon.polys["2"] == route.Polygon.editing, TRUE]);
				append(me.all_plans, [route.Polygon.polys["3"], route.Polygon.polys["3"] == route.Polygon.editing, TRUE]);
				append(me.all_plans, [route.Polygon.polys["4"], route.Polygon.polys["4"] == route.Polygon.editing, TRUE]);
				append(me.all_plans, [route.Polygon.polys["1A"], route.Polygon.polys["1A"] == route.Polygon.editing, TRUE]);
				append(me.all_plans, [route.Polygon.polys["1B"], route.Polygon.polys["1B"] == route.Polygon.editing, TRUE]);
				append(me.all_plans, [route.Polygon.polys["OP1"], route.Polygon.polys["OP1"] == route.Polygon.editing, TRUE]);
				append(me.all_plans, [route.Polygon.polys["OP2"], route.Polygon.polys["OP2"] == route.Polygon.editing, TRUE]);
				append(me.all_plans, [route.Polygon.polys["OP3"], route.Polygon.polys["OP3"] == route.Polygon.editing, TRUE]);
				append(me.all_plans, [route.Polygon.polys["OP4"], route.Polygon.polys["OP4"] == route.Polygon.editing, TRUE]);
				append(me.all_plans, [route.Polygon.polys["OP5"], route.Polygon.polys["OP5"] == route.Polygon.editing, TRUE]);
				append(me.all_plans, [route.Polygon.polys["OP6"], route.Polygon.polys["OP6"] == route.Polygon.editing, TRUE]);
			}
		} else {
			append(me.all_plans, [route.Polygon.primary, FALSE, FALSE]);
			append(me.all_plans, nil);
			append(me.all_plans, nil);
			append(me.all_plans, nil);
			append(me.all_plans, nil);
			append(me.all_plans, nil);
			append(me.all_plans, [route.Polygon.polys["OP1"], FALSE, FALSE]);
			append(me.all_plans, [route.Polygon.polys["OP2"], FALSE, FALSE]);
			append(me.all_plans, [route.Polygon.polys["OP3"], FALSE, FALSE]);
			append(me.all_plans, [route.Polygon.polys["OP4"], FALSE, FALSE]);
			append(me.all_plans, [route.Polygon.polys["OP5"], FALSE, FALSE]);
			append(me.all_plans, [route.Polygon.polys["OP6"], FALSE, FALSE]);
		}

		me.nextDist = getprop("autopilot/route-manager/wp/dist");
		if (me.nextDist == nil or me.nextDist == 0) {
			me.nextDist = 1000000;
		}

		me.poly = [];#0: lat  1: lon  2: draw leg 3: color 4: z-index 5: -1 = first, +1 = last, 0 = not area
		me.steerSE = me.interoperability == displays.METRIC;
		me.steerB = me.steerSE?"B":"S";
		me.steerA = me.steerSE?"\xC3\x85":"R";
		me.steerM = me.steerSE?"M":"T";

		for(me.steerCounter = 0;me.steerCounter < 12; me.steerCounter += 1) {
			me.curr_plan = me.all_plans[me.steerCounter];
			if (me.curr_plan != nil and me.curr_plan[0].type == route.TYPE_AREA) {
				me.isArea = TRUE;
			} else {
				me.isArea = FALSE;
			}
			me.nextActive = FALSE;# in some steerpoints used to determine if leg which is drawn by next steerpoint should be drawn.
			if (me.curr_plan != nil) {
				me.polygon = me.curr_plan[0].getPolygon();
				me.points = size(me.polygon);
				#printf("%d Steers for %s", me.points, me.curr_plan[0].name);
				if (me.curr_plan[1] and route.Polygon.selectSteer != nil) {
					me.wpSelect = route.Polygon.selectSteer[1];
					#printf("ready for %d", me.wpSelect);
				} else {
					me.wpSelect = nil;
				}
			}
			for (var wp = 0; wp < (me.isArea?8:maxSteers); wp += 1) {
				# wp      = local index inside a polygon
				# wpindex = global index for use with canvas elements
				me.wpIndex = wp+48*me.steerCounter;
				if (me.isArea) {
					me.wpIndex = wp+48*6+8*(me.steerCounter-6);
				}

				if (me.curr_plan != nil and me.points > wp and ((me.isArea or (route.Polygon.isPrimaryActive() == TRUE and me.curr_plan[0].isPrimary())) or me.menuMain == MAIN_MISSION_DATA)) {
					me.node = me.polygon[wp];
	  				if (me.node == nil or me.showSteers == FALSE) {
	  					me.steerpoint[me.wpIndex].hide();
	    				continue;
	  				}
					me.lat_wp = me.node.wp_lat;
	  				me.lon_wp = me.node.wp_lon;
	  				#me.alt = node.getNode("altitude-m").getValue();
					me.name = me.node.id;
					me.texCoord = me.laloToTexel(me.lat_wp, me.lon_wp);
					if (me.isArea) {
						# point is part of area
						#printf("doing for %d", me.wpSelect);
						me.steerpoint[me.wpIndex].setColor(me.wpSelect == wp?COLOR_WHITE:me.curr_plan[0].color);
						me.steerpointSymbol[me.wpIndex].setScale(0.25);
						me.steerpointSymbol[me.wpIndex].setStrokeLineWidth(w*4);
						me.steerpoint[me.wpIndex].set("z-index", 11);
						me.areaEnd = wp==0?-1:(me.points == wp+1 and wp>1?1:0);
						append(me.poly, [me.texCoord[0], me.texCoord[1], wp != 0, me.curr_plan[1] == TRUE?COLOR_WHITE:me.curr_plan[0].color, me.curr_plan ==route.Polygon.editing?2:1, me.areaEnd]);
					} elsif (me.wpSelect == wp) {
						# waypoint is selected in MSDA
						#printf("doing for %d", me.wpSelect);
						me.steerpoint[me.wpIndex].setColor(COLOR_WHITE);
						me.steerpointSymbol[me.wpIndex].setScale(1);
						me.steerpointSymbol[me.wpIndex].setStrokeLineWidth(w);
						me.steerpoint[me.wpIndex].set("z-index", 11);
						append(me.poly, [me.texCoord[0], me.texCoord[1], wp != 0, COLOR_TYRK, 2, 0]);
						me.nextActive = FALSE;
					} elsif ((land.showActiveSteer == FALSE and me.curr_plan[2] == FALSE) and me.curr_plan[0].isPrimary() == TRUE and me.curr_plan[0].isPrimaryActive() == TRUE and me.curr_plan[0].getLeg() != nil and me.curr_plan[0].getLeg().id == me.node.id) {
						# we are not in MSDA and waypoint is hidden
						me.steerpoint[me.wpIndex].hide();
						if (wp != me.points-1) {
							# airport is not last steerpoint, we make a leg to/from that also
							append(me.poly, [me.texCoord[0], me.texCoord[1], TRUE, COLOR_TYRK_DARK, me.curr_plan[1] == TRUE?2:1, 0]);
						}
						me.nextActive = me.nextDist*NM2M<20000;
	    				continue;
					} elsif (me.curr_plan[2] == FALSE and me.curr_plan[0].isPrimary() == TRUE and me.curr_plan[0].isPrimaryActive() == TRUE and me.curr_plan[0].getLeg() != nil and me.curr_plan[0].getLeg().id == me.node.id) {
						# waypoint is the active and we not in MSDA menu
						me.steerpoint[me.wpIndex].setColor(COLOR_TYRK);
						me.steerpoint[me.wpIndex].set("z-index", 10);
						me.steerpointSymbol[me.wpIndex].setScale(1);
						me.steerpointSymbol[me.wpIndex].setStrokeLineWidth(w);
						me.steerpointText[me.wpIndex].set("z-index", 10);
						append(me.poly, [me.texCoord[0], me.texCoord[1], TRUE, COLOR_TYRK_DARK, 1, 0]);
						me.nextActive = me.nextDist*NM2M<20000;
					} elsif (me.curr_plan[1] == TRUE) {
						# waypoint is in the polygon selected for editing
						me.steerpoint[me.wpIndex].setColor(COLOR_TYRK);
						me.steerpoint[me.wpIndex].set("z-index", 10);
						me.steerpointSymbol[me.wpIndex].setScale(1);
						me.steerpointSymbol[me.wpIndex].setStrokeLineWidth(w);
						append(me.poly, [me.texCoord[0], me.texCoord[1], wp != 0, COLOR_TYRK, 2, 0]);
						me.nextActive = FALSE;
					} else {
						# ordinary waypoint
						me.steerpoint[me.wpIndex].set("z-index", 5);
						me.steerpoint[me.wpIndex].setColor(COLOR_TYRK_DARK);
						me.steerpointSymbol[me.wpIndex].setScale(1);
						me.steerpointSymbol[me.wpIndex].setStrokeLineWidth(w);
						append(me.poly, [me.texCoord[0], me.texCoord[1], wp != 0 and (me.nextActive or me.curr_plan[2]), COLOR_TYRK_DARK, 1, 0]);
						me.nextActive = FALSE;
					}
					me.steerpoint[me.wpIndex].setTranslation(me.texCoord[0], me.texCoord[1]);
					if (me.curr_plan[1] and me.cursorTrigger and !route.Polygon.editSteer and !route.Polygon.insertSteer and !route.Polygon.appendSteer and !me.isDAPActive()) {
						me.cursorDistX = me.cursorOPosX-me.texCoord[0];
						me.cursorDistY = me.cursorOPosY-me.texCoord[1];
						me.cursorDist = math.sqrt(me.cursorDistX*me.cursorDistX+me.cursorDistY*me.cursorDistY);
						if (me.cursorDist < 12) {
							route.Polygon.selectSteerpoint(me.curr_plan[0].getName(), me.node, wp);# dangerous!!! what if somebody is editing plan in routemanager?
							me.steerpoint[me.wpIndex].setColor(COLOR_WHITE);
							me.cursorTriggerPrev = TRUE;#a hack. It CAN happen that a steerpoint gets selected through infobox, in that case lets make sure infobox is not activated. bad UI fix. :(
						}
					}
					me.steerpoint[me.wpIndex].setRotation(me.steerRot);
					if (me.curr_plan[1] or (!me.curr_plan[1] and !me.curr_plan[2])) {
						# plan is being edited or we are not in MSDA page:
						me.wp_pre = me.curr_plan[0].type == route.TYPE_AREA?"":(me.curr_plan[0].type == route.TYPE_MIX?me.steerB:(me.curr_plan[0].type == route.TYPE_MISS?me.steerB:me.steerA));
						me.steerpointText[me.wpIndex].setText(me.wp_pre~(wp+1));
					} else {
						me.steerpointText[me.wpIndex].setText("");
					}
					if (!me.isArea or (me.curr_plan[2] and me.curr_plan[1])) {
						# its either part of a plan or we in MSDA menu and its being edited
						me.steerpoint[me.wpIndex].update();# might fix being shown at map center shortly when appending.
	  					me.steerpoint[me.wpIndex].show();
  					} else {
  						me.steerpoint[me.wpIndex].hide();
  					}
				} else {
					me.steerpoint[me.wpIndex].hide();
				}
	  		}
	  	}
  	},

  	laloToTexel: func (la, lo) {
		me.coord = geo.Coord.new();
  		me.coord.set_latlon(la, lo);
  		me.coordSelf = geo.Coord.new();#TODO: dont create this every time method is called
  		me.coordSelf.set_latlon(me.lat_own, me.lon_own);
  		me.angle = (me.coordSelf.course_to(me.coord)-me.input.headTrue.getValue())*D2R;
		me.pos_xx		 = -me.coordSelf.distance_to(me.coord)*M2TEX * math.cos(me.angle + math.pi/2);
		me.pos_yy		 = -me.coordSelf.distance_to(me.coord)*M2TEX * math.sin(me.angle + math.pi/2);
  		return [me.pos_xx, me.pos_yy];#relative to rootCenter
  	},

  	TexelToLaLoMap: func (x,y) {#relative to map center
  		x /= M2TEX;
  		y /= M2TEX;
  		me.mDist  = math.sqrt(x*x+y*y);
  		me.acosInput = clamp(x/me.mDist,-1,1);
  		if (y<0) {
  			me.texAngle = math.acos(me.acosInput);#unit circle on TI
  		} else {
  			me.texAngle = -math.acos(me.acosInput);
  		}
  		#printf("%d degs %0.1f NM", me.texAngle*R2D, me.mDist*M2NM);
  		me.texAngle  = -me.texAngle*R2D+90;#convert from unit circle to heading circle, 0=up on display
  		me.headAngle = getprop("orientation/heading-deg")+me.texAngle;#bearing
  		#printf("%d bearing   %d rel bearing", me.headAngle, me.texAngle);
  		me.coordSelf = geo.Coord.new();#TODO: dont create this every time method is called
  		me.coordSelf.set_latlon(me.lat, me.lon);
  		me.coordSelf.apply_course_distance(me.headAngle, me.mDist);

  		return [me.coordSelf.lat(), me.coordSelf.lon()];
  	},

  	showPoly: func {
  		# route/area polygon
  		#
  		# current leg is shown and next legs if less than 20Km away.
  		# If main menu MISSION-DATA is enabled, then show all legs.
  		# tyrk color if editing that polygon, else dark tyrk. White for currently edited leg (soon).
  		# 
  		# me.poly contain all points in both all routes and areas.
  		if (me.showSteers == TRUE and me.showSteerPoly == TRUE and size(me.poly) > 1) {
  			me.steerPoly.removeAllChildren();
  			me.prevLeg = nil;
  			me.firstLeg = nil;
  			foreach(leg; me.poly) {
  				if (me.prevLeg != nil and leg[2] == TRUE) {
  					me.steerPoly.createChild("path")
  						.moveTo(me.prevLeg[0], me.prevLeg[1])
  						.lineTo(leg[0], leg[1])
  						.setColor(leg[3])
  						.set("z-index", leg[4])
  						.setStrokeLineWidth(w);
  				}
  				me.prevLeg = leg;
  				if (leg[5] == -1) {
  					# first leg in area
  					me.firstLeg = leg;
  				} elsif (leg[5] == 1) {
  					# last leg in area
  					# close the area
  					me.steerPoly.createChild("path")
  						.moveTo(leg[0], leg[1])
  						.lineTo(me.firstLeg[0], me.firstLeg[1])
  						.setColor(me.firstLeg[3])
  						.set("z-index", me.firstLeg[4])
  						.setStrokeLineWidth(w);
  				}
  				me.lastLeg = leg;
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

	showFlightTime: func {
		if (me.displayFTime == TRUE) {
			me.fhour = int(displays.common.ftime/60/60);
			me.fmin  = int((displays.common.ftime-me.fhour*60*60)/60);
			me.textFTime.setText(sprintf("FTIME %d:%02d",  me.fhour, me.fmin));
			me.textFTime.show();
		} else {
			me.textFTime.hide();
		}
	},

	updateFlightData: func {
		me.fData = FALSE;
		if (getprop("ja37/sound/terrain-on") == TRUE or getprop("instrumentation/terrain-warning") == TRUE) {
			me.fData = TRUE;
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
		#me.fpi.setTranslation(me.fpi_x, me.fpi_y);
		me.fpi.show();
	},

	displayHorizon: func {
		me.rot = -getprop("orientation/roll-deg") * D2R;
		me.horz_rot.setRotation(me.rot);
		me.horizon_group2.setTranslation(0-me.fpi_x, texel_per_degree * getprop("orientation/pitch-deg")-me.fpi_y);
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
			me.ground_grp.setTranslation(0, 0);
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
		me.clip2 = (me.SVYactive*height*0.125+me.SVYactive*height*0.125*me.SVYsize)~"px, "~width~"px, "~(height-height*0.1-height*0.025*me.upText)~"px, "~0~"px";
		me.rootCenter.set("clip", "rect("~me.clip2~")");#top,right,bottom,left
		me.mapCentrum.set("clip", "rect("~me.clip2~")");#top,right,bottom,left
		me.clip3 = 0~"px, "~width~"px, "~(me.SVYactive*height*0.125+me.SVYactive*height*0.125*me.SVYsize)~"px, "~0~"px";
		me.svy_grp.set("clip", "rect("~me.clip3~")");#top,right,bottom,left
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
		me.icao = land.icao~((land.ils != 0 and getprop("ja37/hud/TILS") == TRUE)?" T":"  ");
		me.textBBase.setText(me.icao);
		
		me.mode = "";
		# DL: data link
		# RR: radar guided steering
		if(getprop("/autopilot/target-tracking-ja37/enable") == TRUE) {
			me.mode = me.interoperability == displays.METRIC?"RR":"RR";# landing steerpoint
			me.textBMode.setColor(rWhite,gWhite,bWhite);
		} elsif (land.mode_LB_active == TRUE) {
			me.mode = me.interoperability == displays.METRIC?"LB":"LS";# landing steerpoint
			me.textBMode.setColor(rWhite,gWhite,bWhite);
		} elsif (land.mode_LF_active == TRUE) {
			me.mode = me.interoperability == displays.METRIC?"LF":"LT";# landing touchdown point
			me.textBMode.setColor(rWhite,gWhite,bWhite);
		} elsif (land.mode_L_active == TRUE) {
			me.mode = "L ";# steering to landing base
			me.textBMode.setColor(rTyrk,gTyrk,bTyrk);
		} elsif (land.mode_B_active == TRUE) {
			me.mode = me.interoperability == displays.METRIC?"B ":"S";# following steerpoint route
			me.textBMode.setColor(rTyrk,gTyrk,bTyrk);
		} elsif (land.mode_OPT_active == TRUE) {
			me.mode = "OP";# visual landing phase
			me.textBMode.setColor(rWhite,gWhite,bWhite);
		} else {
			me.mode = "  ";# VFR
			me.textBMode.setColor(rWhite,gWhite,bWhite);
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
		if (me.input.currentMode.getValue() == displays.LANDING and me.input.gearsPos.getValue() == 1) {
			me.alphaT  = me.interoperability == displays.METRIC?"ALFA":"ALPH";
			me.weightT = me.interoperability == displays.METRIC?"VIKT":"WEIG";
			if (me.interoperability == displays.METRIC) {
				me.weight = getprop("fdm/jsbsim/inertia/weight-lbs")*LB2KG*0.001;
			} else {
				me.weight = getprop("fdm/jsbsim/inertia/weight-lbs")*0.001;
			}
			me.weightKG = getprop("fdm/jsbsim/inertia/weight-lbs")*LB2KG;
			me.alpha   = clamp(extrapolate(me.weightKG, 15000, 16500, 15.5, 9.0), 9, 20.5);#9 + ((me.weightLBM - 28000) / (38000 - 28000)) * (12 - 9);
			me.weightT = me.weightT~sprintf(" %.1f", me.weight);
			me.alphaT  = me.alphaT~sprintf(" %.1f", me.alpha);
			me.textBWeight.setText(me.weightT);
			me.textBAlpha.setText(me.alphaT);
		} elsif (me.lnk99 == TRUE) {
			me.weightT = "";
			for (var i = 0; i < 2; i+=1) {
				if (size(me.tele) > i) {
					me.weightT = me.weightT~sprintf("|%2ds%2d%%", clamp(me.tele[i][1],-9,99),me.tele[i][0]);
				} else {
					me.weightT = me.weightT~"|      ";
				}
			}
			me.alphaT = "";
			for (var i = 2; i < 4; i+=1) {
				if (size(me.tele) > i) {
					me.alphaT = me.alphaT~sprintf("|%2ds%2d%%", clamp(me.tele[i][1],-9,99),me.tele[i][0]);
				} else {
					me.alphaT  =  me.alphaT~"|      ";
				}
			}
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
				me.rdrField = 61.5*D2R;
				me.radius = M2TEX*me.input.radarRange.getValue();
				me.leftX = -math.sin(me.rdrField)*me.radius;
				me.leftY = -math.cos(me.rdrField)*me.radius;
				me.radarLimit = me.radar_limit_grp.createChild("path")
					.moveTo(me.leftX, me.leftY)
					.arcSmallCW(me.radius, me.radius, 0, -me.leftX*2, 0)
					.moveTo(me.leftX, me.leftY)
					.lineTo(me.leftX*0.80, me.leftY*0.80)
					.moveTo(-me.leftX, me.leftY)
					.lineTo(-me.leftX*0.80, me.leftY*0.80)
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
		if (land.mode_B_active == FALSE and (land.show_waypoint_circle == TRUE or land.show_runway_line == TRUE)) {
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
		    me.runway_l = land.line*1000;
		    me.scale = me.runway_l*M2TEX;
		    me.approach_line.setScale(1, me.scale);
		    me.heading = me.input.heading.getValue();#true
		    me.dest.setRotation((180+land.head-me.heading)*D2R);
		    me.runway_name.setText(land.runway);
		    me.runway_name.setRotation(-(180+land.head)*D2R);
		    me.runway_name.show();
		    me.approach_line.show();
		    if (land.runway_rw != nil and land.runway_rw.length > 0) {
		    	me.scale = land.runway_rw.length*M2TEX;
	    	} else {
	    		me.scale = 400*M2TEX;
	    	}
	    	me.runway_line.setScale(1, me.scale);
		    me.runway_line.show();
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
		    me.approach_line.hide();
		    me.approach_circle.hide();
		    me.runway_line.hide();
		    me.runway_name.hide();
		  }
		  me.dest.show();
		} else {
			me.dest_circle.hide();
			me.approach_line.hide();
			me.approach_circle.hide();
			me.runway_line.hide();
		    me.runway_name.hide();
		}
	},

	defineEnemies: func {
		me.foes    = [getprop("ja37/faf/foe-1"),getprop("ja37/faf/foe-2"),getprop("ja37/faf/foe-3"),getprop("ja37/faf/foe-4"),getprop("ja37/faf/foe-5"),getprop("ja37/faf/foe-6")];
		me.friends = [getprop("ja37/faf/friend-1"),getprop("ja37/faf/friend-2"),getprop("ja37/faf/friend-3"),getprop("ja37/faf/friend-4"),getprop("ja37/faf/friend-5"),getprop("ja37/faf/friend-6")];
	},

	displayRadarTracks: func () {

		me.threatIndex  = -1;
		me.missileIndex = -1;
	    me.track_index  = 1;
	    me.isGPS = FALSE;
	    me.selection_updated = FALSE;
	    me.tgt_dist = 1000000;
	    me.tgt_callsign = "";
	    me.tele = [];

	    if(me.input.tracks_enabled.getValue() == 1 and me.input.radar_serv.getValue() > 0) {
			me.radar_group.show();

			me.selection = radar_logic.selection;

			if (me.selection != nil and (me.selection.parents[0] == radar_logic.ContactGPS or me.selection.parents[0] == radar_logic.ContactGhost)) {
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
			  		me.echoesAircraftSvy[i].hide();
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
				if (me.SVYactive == TRUE) {
					me.echoesAircraftSvy[0].hide();
				}
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
		    me.boogie = 0;
		    if (containsVector(me.friends, contact.get_Callsign())) {
	    		me.boogie = 1;
	    	} elsif (containsVector(me.foes, contact.get_Callsign())) {
	    		me.boogie = -1;
	    	}

		    if (me.currentIndexT == 0 and contact.parents[0] == radar_logic.ContactGPS) {
		    	me.gpsSymbol.setTranslation(me.pos_xx, me.pos_yy);
		    	me.gpsSymbol.show();
		    	me.isGPS = TRUE;
		    	me.echoesAircraft[me.currentIndexT].hide();
		    	me.echoesAircraftSvy[me.currentIndexT].hide();
		    } elsif (me.ordn == FALSE) {
		    	me.echoesAircraft[me.currentIndexT].setTranslation(me.pos_xx, me.pos_yy);

		    	if (me.boogie == 1) {
		    		me.echoesAircraftTri[me.currentIndexT].setColor(rGreen,gGreen,bGreen,a);
		    		me.echoesAircraftVector[me.currentIndexT].setColor(rGreen,gGreen,bGreen,a);
		    	} elsif (me.boogie == -1) {
		    		me.echoesAircraftTri[me.currentIndexT].setColor(rRed,gRed,bRed,a);
		    		me.echoesAircraftVector[me.currentIndexT].setColor(rRed,gRed,bRed,a);
		    	} else {
		    		me.echoesAircraftTri[me.currentIndexT].setColor(rYellow,gYellow,bYellow,a);
		    		me.echoesAircraftVector[me.currentIndexT].setColor(rYellow,gYellow,bYellow,a);
		    	}

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
				if (me.SVYactive == TRUE) {
					me.altsvy  = contact.get_altitude()*FT2M;
					me.distsvy = math.cos(me.angle)*contact.get_Coord().distance_to(geo.aircraft_position());
					me.echoesAircraftSvy[me.currentIndexT].setTranslation(me.SVYoriginX+me.SVYwidth*me.distsvy/me.SVYrange, me.SVYoriginY-me.SVYheight*me.altsvy/me.SVYalt);
					if (me.boogie == 1) {
			    		me.echoesAircraftSvyTri[me.currentIndexT].setColor(rGreen,gGreen,bGreen,a);
			    		me.echoesAircraftSvyVector[me.currentIndexT].setColor(rGreen,gGreen,bGreen,a);
			    	} elsif (me.boogie == -1) {
			    		me.echoesAircraftSvyTri[me.currentIndexT].setColor(rRed,gRed,bRed,a);
			    		me.echoesAircraftSvyVector[me.currentIndexT].setColor(rRed,gRed,bRed,a);
			    	} else {
			    		me.echoesAircraftSvyTri[me.currentIndexT].setColor(rYellow,gYellow,bYellow,a);
			    		me.echoesAircraftSvyVector[me.currentIndexT].setColor(rYellow,gYellow,bYellow,a);
			    	}
				    if (me.tgtHeading != nil) {
				        me.relHeading = me.tgtHeading - me.myHeading;
				        #me.relHeading -= 180;
				        me.rot = 90;
				        if (math.abs(geo.normdeg180(me.relHeading)) > 90) {
				        	me.rot = -90;
				        }
				        me.echoesAircraftSvy[me.currentIndexT].setRotation(me.rot * D2R);
				    }
				    if (me.tgtSpeed != nil) {
				    	me.echoesAircraftSvyVector[me.currentIndexT].setScale(1, clamp(((me.tgtSpeed/60)*NM2M/me.SVYrange)*me.SVYwidth, 1, 750*MM2TEX));
			    	} else {
			    		me.echoesAircraftSvyVector[me.currentIndexT].setScale(1, 1);
			    	}
					me.echoesAircraftSvy[me.currentIndexT].show();
					me.echoesAircraftSvy[me.currentIndexT].update();
				}
			} else {
				me.eta99 = contact.getETA();
				me.hit99 = contact.getHitChance();
				if (me.eta99 != nil) {
					append(me.tele, [me.hit99, me.eta99]);
				}
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
				me.echoesAircraftSvy[me.currentIndexT].hide();
			}
			if(me.currentIndexT != 0) {
				me.track_index += 1;
				if (me.track_index == maxTracks) {
					me.track_index = -1;
				}
			}
			if (((me.showHostileZones == TRUE and me.boogie < 1) or (me.showFriendlyZones == TRUE and me.boogie == 1)) and me.threatIndex < maxThreats-1) {
				me.threatRadiusNM = -1;
				if (contact.get_model()      == "missile_frigate") {
					me.threatRadiusNM = 80;
				} elsif (contact.get_model() == "buk-m2") {
					me.threatRadiusNM = 30;
				}
				if (me.threatRadiusNM != -1) {
					me.threatIndex += 1;
					me.threats[me.threatIndex].setTranslation(me.pos_xx, me.pos_yy);
					if (me.boogie == 1) {
			    		me.threats[me.threatIndex].setColor(rGreen,gGreen,bGreen,a);
			    	} else {
			    		me.threats[me.threatIndex].setColor(rRed,gRed,bRed,a);
			    	}
					me.scale = me.threatRadiusNM*NM2M*M2TEX/100;
			      	me.threats[me.threatIndex].setStrokeLineWidth(w/me.scale);
			      	me.threats[me.threatIndex].setScale(me.scale);
					me.threats[me.threatIndex].show();
				}
			}
		}
	},

	showSelfVector: func {
		# length = time to travel in 60 seconds.
		me.spd = me.input.tas.getValue();# true airspeed so can be compared with other aircrafts speed. (should really be ground speed)
		me.selfVector.setScale(1, clamp((me.spd/60)*NM2M*M2TEX, 1, 750*MM2TEX));
		if (me.SVYactive == TRUE) {
			me.selfVectorSvy.setScale(clamp(((me.spd/60)*NM2M/me.SVYrange)*me.SVYwidth, 1, 750*MM2TEX),1);
		}
		if (getprop("ja37/avionics/gps-nav") == TRUE) {
			me.selfSymbol.hide();
			me.selfSymbolGPS.show();
		} else {
			me.selfSymbol.show();
			me.selfSymbolGPS.hide();
		}
	},

	showHeadingBug: func {
		me.desired_mag_heading = nil;
	    #if (me.input.APLockHeading.getValue() == "dg-heading-hold") {
	    #	me.desired_mag_heading = me.input.APHeadingBug.getValue();
	    #} elsif (me.input.APLockHeading.getValue() == "true-heading-hold") {
	    #	me.desired_mag_heading = me.input.APTrueHeadingErr.getValue()+me.input.headMagn.getValue();#getprop("autopilot/settings/true-heading-deg")+
	    #} elsif (me.input.APLockHeading.getValue() == "nav1-hold") {
	    #	me.desired_mag_heading = me.input.APnav0HeadingErr.getValue()+me.input.headMagn.getValue();
	    #} els
	    if( me.input.RMActive.getValue() == TRUE) {
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

	closeTraps: func {
		me.trapLock  = FALSE;
		me.trapFire  = FALSE;
		me.trapMan   = FALSE;
		me.trapECM   = FALSE;
		me.trapLand  = FALSE;
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
				if (me.input.wow1.getValue() == 1) {
					me.off = !me.off;
					MI.mi.off = me.off;
					me.active = !me.off;
				} else {
					if (getprop("/autopilot/target-tracking-ja37/enable") == TRUE) {
						auto.unfollow();
					} else {
						auto.follow();
					}
				}
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
				me.closeTraps();
				me.trapLock = TRUE;
				me.quickOpen = 10000;
			}	
			if(me.menuMain == MAIN_MISSION_DATA) {
				route.Polygon.insertSteerpoint();
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
				me.closeTraps();
				me.trapFire = TRUE;
				me.quickOpen = 10000;
			}		
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
				land.OPT();
			}
			if (me.menuMain == MAIN_DISPLAY) {
				# place names on map
				me.mapPlaces = !me.mapPlaces;
			}	
			if(me.menuMain == MAIN_MISSION_DATA) {
				route.Polygon.appendSteerpoint();
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
				#me.showSteers = !me.showSteers;
				land.B();
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == TRUE) {
				# tact ecm report
				me.closeTraps();
				me.trapECM = TRUE;
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
				me.closeTraps();
				me.trapMan = TRUE;
				me.quickOpen = 10000;
			}	
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
				me.activateAlso = FALSE;
				me.startAlso = FALSE;
				if (route.Polygon.flyMiss.isPrimary() == TRUE) {
					me.activateAlso = TRUE;
					if (route.Polygon.isPrimaryActive() == TRUE) {
						me.startAlso = TRUE;
					}
				}
				if (route.Polygon.flyMiss == route.Polygon.polys["1"]) {
					route.Polygon.flyMiss = route.Polygon.polys["2"];
				} elsif (route.Polygon.flyMiss == route.Polygon.polys["2"]) {
					route.Polygon.flyMiss = route.Polygon.polys["3"];
				} elsif (route.Polygon.flyMiss == route.Polygon.polys["3"]) {
					route.Polygon.flyMiss = route.Polygon.polys["4"];
				} elsif (route.Polygon.flyMiss == route.Polygon.polys["4"]) {
					route.Polygon.flyMiss = route.Polygon.polys["1"];
				}
				if (me.activateAlso == TRUE) {
					route.Polygon.flyMiss.setAsPrimary();
					if (me.startAlso == TRUE) {
						route.Polygon.startPrimary();
					}
				}
			}
			if (me.menuMain == MAIN_CONFIGURATION and me.menuSvy == FALSE and me.menuGPS == FALSE) {
				# side view
				me.menuSvy = TRUE;
			} elsif (me.menuMain == MAIN_CONFIGURATION and me.menuSvy == TRUE) {
				me.SVYsize += 1;
				if (me.SVYsize > 3) {
					me.SVYsize = 1;
				}
			}
			if(me.menuMain == MAIN_MISSION_DATA) {
				route.Polygon.deleteSteerpoint();
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
			} elsif (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == TRUE) {
				# land report
				me.closeTraps();
				me.trapLand  = TRUE;
				me.quickOpen = 10000;
			}
			if (me.menuMain == MAIN_DISPLAY) {
				# change zoom
				zoomIn();
			}
			if (me.menuMain == MAIN_MISSION_DATA) {
				route.Polygon.setToggleAreaEdit();
			}
			if (me.menuMain == MAIN_CONFIGURATION and me.menuGPS == FALSE and me.menuSvy == FALSE) {
				me.fr28Top = !me.fr28Top;
			}
			if (me.menuMain == MAIN_CONFIGURATION and me.menuGPS == FALSE and me.menuSvy == TRUE) {
				me.SVYinclude += 1;
				if (me.SVYinclude > 2) {
					me.SVYinclude = 0;
				}
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
				me.logLand.clear();
				radar_logic.lockLog.clear();
				armament.ecmLog.clear();
			}
			if (me.menuMain == MAIN_CONFIGURATION and me.menuGPS == TRUE) {
				# GPS fix
				if (getprop("ja37/avionics/gps-nav") == TRUE) {
					  me.coord = geo.aircraft_position();

					  me.ground = geo.elevation(me.coord.lat(), me.coord.lon());
    				  if(me.ground != nil) {
      						me.coord.set_alt(me.ground);
      				  }

					  me.contact = radar_logic.ContactGPS.new("FIX", me.coord);

					  radar_logic.selection = me.contact;
				}
			}
			if (me.menuMain == MAIN_CONFIGURATION and me.menuSvy == TRUE) {
				# svy scale
				if (me.SVYscale == SVY_ELKA) {
					me.SVYscale = SVY_RMAX;
				} elsif (me.SVYscale == SVY_RMAX) {
					me.SVYscale = SVY_MI;
				} elsif (me.SVYscale == SVY_MI) {
					me.SVYscale = SVY_ELKA;
				}
			}
			if (me.menuMain == MAIN_CONFIGURATION and me.menuGPS == FALSE and me.menuSvy == FALSE) {
				# GPS settings
				me.menuGPS = TRUE;
			}
			if (me.menuMain == MAIN_DISPLAY) {
				# show threat circles
				me.showHostileZones = !me.showHostileZones;
			}
			if (me.menuMain == MAIN_MISSION_DATA) {
				if (route.Polygon.editing != route.Polygon.editRTB) {
					route.Polygon.editPlan(route.Polygon.editRTB);
				} else {
					route.Polygon.editPlan(nil);
				}
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
				setprop("ja37/avionics/gps-cmd", !getprop("ja37/avionics/gps-cmd"));
				if (getprop("ja37/avionics/gps-cmd") == FALSE and radar_logic.selection != nil and radar_logic.selection.get_Callsign() == "FIX") {
					# clear the FIX if gps is turned off
					radar_logic.selection = nil;
				}
			}
			if (me.menuMain == MAIN_CONFIGURATION and me.menuSvy == TRUE) {
				me.SVYrmax *= 2;
				if (me.SVYrmax > 120) {
					me.SVYrmax = 15;
				}
			}
			if (me.menuMain == MAIN_DISPLAY) {
				# show friendly threat circles
				me.showFriendlyZones = !me.showFriendlyZones;
			}
			if (me.menuMain == MAIN_MISSION_DATA) {
				me.replaceEdit = route.Polygon.editRTB == route.Polygon.editing;
				if (route.Polygon.editRTB == route.Polygon.polys["1A"]) {
					route.Polygon.editRTB = route.Polygon.polys["1B"];
				} elsif (route.Polygon.editRTB == route.Polygon.polys["1B"]) {
					route.Polygon.editRTB = route.Polygon.polys["1A"];
				}
				if (me.replaceEdit == TRUE) {
					route.Polygon.editPlan(route.Polygon.editRTB);
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
			if (me.menuMain == MAIN_CONFIGURATION and me.menuSvy == TRUE) {
				me.SVYhmax *= 2;
				if (me.SVYhmax > 40) {
					me.SVYhmax = 5;
				}
			}
			if (me.menuMain == MAIN_CONFIGURATION and me.menuGPS == TRUE) {
				# ghost target
				me.contact = radar_logic.ContactGhost.new();
				radar_logic.selection = me.contact;
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
				me.activateAlso = FALSE;
				me.startAlso = FALSE;
				if (route.Polygon.flyRTB.isPrimary() == TRUE) {
					me.activateAlso = TRUE;
					if (route.Polygon.isPrimaryActive() == TRUE) {
						me.startAlso = TRUE;
					}
				}
				if (route.Polygon.flyRTB == route.Polygon.polys["1A"]) {
					route.Polygon.flyRTB = route.Polygon.polys["1B"];
				} elsif (route.Polygon.flyRTB == route.Polygon.polys["1B"]) {
					route.Polygon.flyRTB = route.Polygon.polys["1A"];
				}
				if (me.activateAlso == TRUE) {
					route.Polygon.flyRTB.setAsPrimary();
					if (me.startAlso == TRUE) {
						route.Polygon.startPrimary();
					}
				}
			}
			if (me.menuMain == MAIN_MISSION_DATA) {
				if (route.Polygon.editing != route.Polygon.editMiss) {
					route.Polygon.editPlan(route.Polygon.editMiss);
				} else {
					route.Polygon.editPlan(nil);
				}
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
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
				land.LA();
			}
			if(me.menuMain == MAIN_DISPLAY) {
				me.displayFlight += 1;
				if (me.displayFlight == 3) {
					me.displayFlight = 0;
				}
			}
			if (me.menuMain == MAIN_MISSION_DATA) {
				me.replaceEdit = route.Polygon.editMiss == route.Polygon.editing;
				if (route.Polygon.editMiss == route.Polygon.polys["1"]) {
					route.Polygon.editMiss = route.Polygon.polys["2"];
				} elsif (route.Polygon.editMiss == route.Polygon.polys["2"]) {
					route.Polygon.editMiss = route.Polygon.polys["3"];
				} elsif (route.Polygon.editMiss == route.Polygon.polys["3"]) {
					route.Polygon.editMiss = route.Polygon.polys["4"];
				} elsif (route.Polygon.editMiss == route.Polygon.polys["4"]) {
					route.Polygon.editMiss = route.Polygon.polys["1"];
				}
				if (me.replaceEdit == TRUE) {
					route.Polygon.editPlan(route.Polygon.editMiss);
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
			if(me.menuMain == MAIN_DISPLAY) {
				displays.common.cursor = !displays.common.cursor;
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
				land.LF();
			}
			if(me.menuMain == MAIN_MISSION_DATA) {
				route.Polygon.editSteerpoint();
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
			if(math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == TRUE and (me.trapFire == TRUE or me.trapMan == TRUE or me.trapLock == TRUE or me.trapECM == TRUE or me.trapLand  == TRUE)) {
				me.logPage += 1;
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
				land.LB();
			}
			if(me.menuMain == MAIN_DISPLAY) {
				me.day = !me.day;
			}
			if(me.menuMain == MAIN_MISSION_DATA) {
				if (me.ownPosition < 0.25) {
					me.ownPosition = 0.25;
					me.ownPositionDigital = 2;
				} elsif (me.ownPosition < 0.50) {
					me.ownPosition = 0.50;
					me.ownPositionDigital = 3;
				} elsif (me.ownPosition < 0.75) {
					me.ownPosition = 0.75;
					me.ownPositionDigital = 4;
				#} elsif (me.ownPosition < 1) {
				#	me.ownPosition = 1;
				#	me.ownPositionDigital = ?;
				} else {
					me.ownPosition = 0;
					me.ownPositionDigital = 1;
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
			if(math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == TRUE and (me.trapFire == TRUE or me.trapMan == TRUE or me.trapLock == TRUE or me.trapECM == TRUE or me.trapLand == TRUE)) {
				me.logPage -= 1;
				if (me.logPage < 0) {
					me.logPage = 0;
				}
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
				land.L();
			}
			if(me.menuMain == MAIN_MISSION_DATA) {
				me.dragMapEnabled = !me.dragMapEnabled;
				me.mapSelfCentered = !me.dragMapEnabled;
				if (!me.mapSelfCentered) {
					me.lat = me.lat_own;
					me.lon = me.lon_own;
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

	whereIsMap: func {
		# update the map position
		me.lat_own = getprop('/position/latitude-deg');
		me.lon_own = getprop('/position/longitude-deg');
		if (me.menuMain != MAIN_MISSION_DATA or me.mapSelfCentered) {
			# get current position
			me.lat = me.lat_own;
			me.lon = me.lon_own;# TODO: USE GPS/INS here.
		}
	},

	updateMap: func {
		# update the map
		if (lastDay != me.day)  {
			me.setupMap();
		}
		me.rootCenterY = height*0.875-(height*0.875)*me.ownPosition;
		if (!me.mapSelfCentered) {
			me.lat_wp   = getprop('/position/latitude-deg');
			me.lon_wp   = getprop('/position/longitude-deg');
			me.tempReal = me.laloToTexel(me.lat,me.lon);#delicate
			me.rootCenter.setTranslation(width/2-me.tempReal[0], me.rootCenterY-me.tempReal[1]);
		} else {
			me.tempReal = [0,0];
			me.rootCenter.setTranslation(width/2, me.rootCenterY);
		}
		me.mapCentrum.setTranslation(width/2, me.rootCenterY);

		me.n = math.pow(2, zoom);
		me.center_tile_float = [
			me.n * ((me.lon + 180) / 360),
			(1 - math.ln(math.tan(me.lat * D2R) + 1 / math.cos(me.lat * D2R)) / math.pi) / 2 * me.n
		];
		# center_tile_offset[1]
		me.center_tile_int = [int(me.center_tile_float[0]), int(me.center_tile_float[1])];

		me.center_tile_fraction_x = me.center_tile_float[0] - me.center_tile_int[0];
		me.center_tile_fraction_y = me.center_tile_float[1] - me.center_tile_int[1];
#printf("centertile: %d,%d fraction %.2f,%.2f",me.center_tile_int[0],me.center_tile_int[1],me.center_tile_fraction_x,me.center_tile_fraction_y);
		me.tile_offset = [int(num_tiles[0]/2), int(num_tiles[1]/2)];

		# 3x3 example: (same for both canvas-tiles and map-tiles)
		#  *************************
		#  * -1,-1 *  0,-1 *  1,-1 *
		#  *************************
		#  * -1, 0 *  0, 0 *  1, 0 *
		#  *************************
		#  * -1, 1 *  0, 1 *  1, 1 *
		#  *************************
		#

		for(var xxx = 0; xxx < num_tiles[0]; xxx += 1) {
			for(var yyy = 0; yyy < num_tiles[1]; yyy += 1) {
				tiles[xxx][yyy].setTranslation(-int((me.center_tile_fraction_x - xxx+me.tile_offset[0]) * tile_size), -int((me.center_tile_fraction_y - yyy+me.tile_offset[1]) * tile_size));
			}
		}

		me.liveMap = getprop("ja37/displays/live-map");
		if(me.center_tile_int[0] != last_tile[0] or me.center_tile_int[1] != last_tile[1] or type != last_type or zoom != last_zoom or me.liveMap != lastLiveMap or lastDay != me.day)  {
			for(var x = 0; x < num_tiles[0]; x += 1) {
		  		for(var y = 0; y < num_tiles[1]; y += 1) {
		  			# inside here we use 'var' instead of 'me.' due to generator function, should be able to remember it.
		  			var xx = me.center_tile_int[0] + x - me.tile_offset[0];
		  			if (xx < 0) {
		  				# when close to crossing 180 longitude meridian line, make sure we see the tiles on the positive side of the line.
		  				xx = me.n + xx;#print(xx~" from "~(xx-me.n));
		  			} elsif (xx >= me.n) {
		  				# when close to crossing 180 longitude meridian line, make sure we dont double load the tiles on the negative side of the line.
		  				xx = xx - me.n;#print(xx~" from "~(xx+me.n));
		  			}
					var pos = {
						z: zoom,
						x: xx,
						y: me.center_tile_int[1] + y - me.tile_offset[1],
						type: type
					};

					(func {# generator function
					    var img_path = makePath(pos);
					    var tile = tiles[x][y];
					    #print('showing ' ~ img_path);
					    if( io.stat(img_path) == nil and me.liveMap == TRUE) { # image not found, save in $FG_HOME
					      	var img_url = makeUrl(pos);
					      	#print('requesting ' ~ img_url);
					      	http.save(img_url, img_path)
					      		.done(func(r) {
					      	  		#print('received image ' ~ me.img_path~" " ~ r.status ~ " " ~ r.reason);
					      	  		#print(""~(io.stat(me.img_path) != nil));
					      	  		tile.set("src", img_path);# this sometimes fails with: 'Cannot find image file' if use me. instead of var.
					      	  		tile.update();
					      	  		})
					          #.done(func {print('received image ' ~ img_path); tile.set("src", img_path);})
					          .fail(func (r) {#print('Failed to get image ' ~ img_path ~ ' ' ~ r.status ~ ': ' ~ r.reason);
					          				tile.set("src", "Aircraft/JA37/Models/Cockpit/TI/emptyTile.png");
					      					tile.update();
					      					});
					    } elsif (io.stat(img_path) != nil) {# cached image found, reusing
					      	#print('loading ' ~ me.img_path);
					      	tile.set("src", img_path);
					      	tile.update();
					    } else {
					    	# internet not allowed, so noise tile shown
					    	tile.set("src", "Aircraft/JA37/Models/Cockpit/TI/noiseTile.png");
					      	tile.update();
					    }
					})();
		  		}
			}

		last_tile = me.center_tile_int;
		last_type = type;
		last_zoom = zoom;
		lastLiveMap = me.liveMap;
		lastDay = me.day;
		}

		me.mapRot.setRotation(-getprop("orientation/heading-deg")*D2R);
	},
};

var ti = nil;
var init = func {
	removelistener(idl); # only call once
	if (getprop("ja37/supported/canvas") == TRUE) {
		setupCanvas();
		ti = TI.new();
		ti.loop();#must be first due to me.rootCenterY
		ti.loopFast();
		ti.loopSlow();
	}
}

idl = setlistener("ja37/supported/initialized", init, 0, 0);