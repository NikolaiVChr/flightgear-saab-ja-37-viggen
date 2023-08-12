
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

var type = "light_nolabels";

# index   = zoom level
# content = meter per pixel of tiles
#                   0                             5                               10                               15                      19
var meterPerPixel = [156412,78206,39103,19551,9776,4888,2444,1222,610.984,305.492,152.746,76.373,38.187,19.093,9.547,4.773,2.387,1.193,0.596,0.298];# at equator
#zooms      = [4, 7, 9, 11, 13];#old
var zooms      = [6, 7, 8, 9, 10];
var zoomLevels = [3.2, 1.6, 800, 400, 200];
var zoom_curr  = 2;
var zoom = zooms[zoom_curr];
# display width = 0.3 meter
# 381 pixels = 0.300 meter   1270 pixels/meter = 1:1
# so at setting 800:1   1 meter = 800 meter    meter/pixel= 1270/800 = 1.58
#cos = 0.63
#print("200   = "~200000/1270);
#print("400   = "~400000/1270);
#print("800   = "~800000/1270);
#print("1.6   = "~1600000/1270);
#print("3.2   = "~3200000/1270);
#print("");
#for(i=0;i<20;i+=1) {
#	print(i~"  ="~meterPerPixel[i]*math.cos(65*D2R)~" m/px");
#}

var M2TEX = 1/(meterPerPixel[zoom]*math.cos(getprop('/position/latitude-deg')*D2R));

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
  string.compileTemplate('https://cartodb-basemaps-c.global.ssl.fastly.net/{type}/{z}/{x}/{y}.png');
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
var SVY_120  = 1;
var SVY_RR   = 2;

var brightnessP = func {
	if (ti.active == FALSE) return;
	edgeButtonsStruct[21] = getprop("sim/time/elapsed-sec");
	ti.brightness += 0.25;
};

var brightnessM = func {
	if (ti.active == FALSE) return;
	edgeButtonsStruct[21] = getprop("sim/time/elapsed-sec");
	ti.brightness -= 0.25;
};

var contrastP = func {
	if (ti.active == FALSE) return;
	edgeButtonsStruct[0] = getprop("sim/time/elapsed-sec");
	var c = getprop("ja37/displays/ti-contrast");
	c += 0.05;
	if (c > 4) {
		c = 4;
	}
	setprop("ja37/displays/ti-contrast", c);
};

var contrastM = func {
	if (ti.active == FALSE) return;
	edgeButtonsStruct[0] = getprop("sim/time/elapsed-sec");
	var c = getprop("ja37/displays/ti-contrast");
	c -= 0.05;
	if (c < 0.25) {
		c = 0.25;
	}
	setprop("ja37/displays/ti-contrast", c);
};



var bright = 0;

#TI symbol colors
var COLOR_WHITE      = [1.00,1.00,1.00];# self
var COLOR_YELLOW     = [1.00,1.00,0.00];# possible threat LV
var COLOR_RED        = [1.00,0.00,0.00];# threat LV
var COLOR_GREEN      = [0.00,1.00,0.00];# own side LV
var COLOR_GREEN_DARK = [0.00,0.50,0.00];# RWR
var COLOR_BLUE_LIGHT = [0.65,0.65,1.00];
var COLOR_TYRK_DARK  = [0.20,0.75,0.60];# route polygon
var COLOR_TYRK       = [0.35,1.00,0.90];# navigation aids
var COLOR_GREY       = [0.50,0.50,0.50];# inactive
var COLOR_GREY_LIGHT = [0.70,0.70,0.70];
var COLOR_BLACK      = [0.00,0.00,0.00];# active
var COLOR_GREY_BLUE  = [0.60,0.60,0.85];# flight data

var COLOR_DAY   = "rgb(128,128,128)";# color fill behind map which will modulate to make it darker.
var COLOR_NIGHT = "rgb( 64, 64, 64)";

var a = 1.0;#alpha
var w = 1.0;#stroke width

var maxTracks   = 4;
var maxDLTracks = 20;
var maxMissiles = 4;
var maxSteers   = 48;#careful with this one
var maxBases    = 50;

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

# notice the Swedish letter are missing accents in vertical menu items {ÅÖÄ} due to them not being always read correct by Nasal substr(). (fixed)
# Å = \xC3\x85 å = \xC3\xA5
# Ö = \xC3\x96 ö = \xC3\xB6
# Ä = \xC3\x84 ä = \xC3\xA4

# degree
# \xc2\xb0

var dictSE = {
	'HORI': {'0': [TRUE, "AV"], '1': [TRUE, "RENS"], '2': [TRUE, "P\xC3\x85"]},
	'0':   {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "F\xC3\x96"], '13': [TRUE, "KONF"]},
	'8':   {'8': [TRUE, "R7V"], '9': [TRUE, "V7V"], '10': [TRUE, "S7V"], '11': [TRUE, "S7H"], '12': [TRUE, "V7H"], '13': [TRUE, "R7H"],
			'7': [TRUE, "MENY"], '14': [TRUE, "AKAN"], '15': [TRUE, "RENS"], '20': [TRUE, "STA"]},
	'9':   {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "F\xC3\x96"], '13': [TRUE, "KONF"],
	 		'1': [TRUE, "SL\xC3\x84CK"], '2': [TRUE, "DL"], '4': [TRUE, "B"], '5': [TRUE, "UPOL"], '6': [TRUE, "TRAP"], '7': [TRUE, "MENY"],
	 		'14': [TRUE, "JAKT"], '15': [FALSE, "HK"],'16': [TRUE, "\xC3\x85POL"], '17': [TRUE, "L\xC3\x85"], '18': [TRUE, "LF"], '19': [TRUE, "LB"],'20': [TRUE, "L"]},
	'TRAP':{'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "F\xC3\x96"], '13': [TRUE, "KONF"],
	 		'2': [TRUE, "INL\xC3\x84"], '3': [TRUE, "AVFY"], '4': [TRUE, "FALL"], '5': [TRUE, "MAN"], '6': [TRUE, "S\xC3\x84TT"], '7': [TRUE, "MENY"], '14': [TRUE, "RENS"],
	 		'17': [TRUE, "ALLA"], '19': [TRUE, "NED"], '20': [TRUE, "UPP"]},
	'10':  {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "F\xC3\x96"], '13': [TRUE, "KONF"],
			'3': [TRUE, "ELKA"], '4': [TRUE, "ELKA"], '6': [TRUE, "SKAL"], '7': [TRUE, "MENY"], '14': [FALSE, "EOMR"], '15': [TRUE, "EOMR"], '16': [TRUE, "TID"],
			'17': [TRUE, "HORI"], '18': [TRUE, "HKM"], '19': [TRUE, "DAG"]},
	'11':  {'2': [TRUE, "INFG"], '3': [TRUE, "NY"], #'5': [TRUE, "RADR"], # hack
	        '8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "F\xC3\x96"], '13': [TRUE, "KONF"],
			'4': [TRUE, "EDIT"], '6': [TRUE, "EDIT"], '7': [TRUE, "MENY"], '14': [TRUE, "EDIT"], '15': [TRUE, "\xC3\x85POL"], '16': [TRUE, "EDIT"],
			'17': [TRUE, "UPOL"], '18': [TRUE, "EDIT"], '19': [TRUE, "EGLA"], '20': [TRUE, "KMAN"]},
	'12':  {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "F\xC3\x96"], '13': [TRUE, "KONF"],
	 		'7': [TRUE, "MENY"], '19': [TRUE, "NED"], '20': [TRUE, "UPP"]},
	'13':  {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "F\xC3\x96"], '13': [TRUE, "KONF"],
			'5': [TRUE, "SVY"], '6': [TRUE, "FR28"], '7': [TRUE, "MENY"], '14': [TRUE, "GPS"], '19': [FALSE, "L\xC3\x84S"]},
	'GPS': {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "F\xC3\x96"], '13': [TRUE, "KONF"],
			'7': [TRUE, "MENU"], '14': [FALSE, "FIX"], '15': [TRUE, "INIT"]},
	'SVY': {'8': [TRUE, "VAP"], '9': [TRUE, "SYST"], '10': [TRUE, "PMGD"], '11': [TRUE, "UDAT"], '12': [TRUE, "F\xC3\x96"], '13': [TRUE, "KONF"],
			'5': [TRUE, "F\xC3\x96ST"], '6': [TRUE, "VISA"], '7': [TRUE, "MENU"], '14': [TRUE, "SKAL"], '15': [TRUE, "RMAX"], '16': [TRUE, "HMAX"]},
};

#ÅPOL = Return to base polygon (RPOL)
#UPOL = Mission Polygon (MPOL)

var dictEN = {
	'HORI': {'0': [TRUE, "OFF"], '1': [TRUE, "CLR"], '2': [TRUE, "ON"]},
	'0':   {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"]},
	'8':   {'8': [TRUE, "T7L"], '9': [TRUE, "W7L"], '10': [TRUE, "F7L"], '11': [TRUE, "F7R"], '12': [TRUE, "W7R"], '13': [TRUE, "T7R"],
			'7': [TRUE, "MENU"], '14': [TRUE, "AKAN"], '15': [TRUE, "CLR"], '20': [TRUE, "STA"]},
    '9':   {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
	 		'1': [TRUE, "OFF"], '2': [TRUE, "DL"], '4': [TRUE, "S"], '5': [TRUE, "MPOL"], '6': [TRUE, "TRAP"], '7': [TRUE, "MENU"],
	 		'14': [TRUE, "FGHT"], '15': [FALSE, "ACRV"],'16': [TRUE, "RPOL"], '17': [TRUE, "LR"], '18': [TRUE, "LT"], '19': [TRUE, "LS"],'20': [TRUE, "L"]},
	'TRAP':{'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
	 		'2': [TRUE, "LOCK"], '3': [TRUE, "FIRE"], '4': [TRUE, "ECM"], '5': [TRUE, "MAN"], '6': [TRUE, "LAND"], '7': [TRUE, "MENU"], '14': [TRUE, "CLR"],
	 		'17': [TRUE, "ALL"], '19': [TRUE, "DOWN"], '20': [TRUE, "UP"]},
	'10':  {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
			'3': [TRUE, "EMAP"], '4': [TRUE, "EMAP"], '6': [TRUE, "SCAL"], '7': [TRUE, "MENU"], '14': [FALSE, "AAA"], '15': [TRUE, "AAA"], '16': [TRUE, "TIME"],
			'17': [TRUE, "HORI"], '18': [TRUE, "CURS"], '19': [TRUE, "DAY"]},
	'11':  {'2': [TRUE, "INS"], '3': [TRUE, "ADD"],# '5': [TRUE, "DEL"], # unauthentic as this
		    '8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
			'4': [TRUE, "EDIT"], '6': [TRUE, "EDIT"], '7': [TRUE, "MENU"], '14': [TRUE, "EDIT"], '15': [TRUE, "RPOL"], '16': [TRUE, "EDIT"],
			'17': [TRUE, "MPOL"], '18': [TRUE, "EDIT"], '19': [TRUE, "MYPS"], '20': [TRUE, "MMAN"]},
	'12':  {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
	 		'7': [TRUE, "MENU"], '19': [TRUE, "DOWN"], '20': [TRUE, "UP"]},
	'13':  {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
			'5': [TRUE, "SIDV"], '6': [TRUE, "FR28"], '7': [TRUE, "MENU"], '14': [TRUE, "GPS"], '19': [FALSE, "READ"]},
	'GPS': {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
			'7': [TRUE, "MENU"], '14': [FALSE, "FIX"], '15': [TRUE, "INIT"]},
	'SIDV': {'8': [TRUE, "WEAP"], '9': [TRUE, "SYST"], '10': [TRUE, "DISP"], '11': [TRUE, "MSDA"], '12': [TRUE, "FAIL"], '13': [TRUE, "CONF"],
			'5': [TRUE, "WIN"], '6': [TRUE, "SHOW"], '7': [TRUE, "MENU"], '14': [TRUE, "SCAL"], '15': [TRUE, "RMAX"], '16': [TRUE, "AMAX"]},
};

var edgeButtonsStruct = [0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0];

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
	# 		ecm 0
	#       bulls-eye 1
	# 		airports 2
	#       LV/FF    2
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
			
		me.gridGroup = me.mapCenter.createChild("group")
			.set("z-index", 24);
		me.gridGroupText = me.mapCenter.createChild("group")
			.set("z-index", 25);

		# map scale
		me.mapScaleTickPosX = width*0.975/2;
		me.mapScaleTickPosTxtX = width*0.975/2-width*0.025/2;
		me.mapScale = me.rootCenter.createChild("group")
			.set("z-index", 3);
		me.mapScale.createChild("path")
			.moveTo(me.mapScaleTickPosX, height)
			.vert(-height*2)
			.setColor(COLOR_WHITE)
		    .setStrokeLineWidth(w);
		me.mapScaleTick0 = me.mapScale.createChild("path")
			.moveTo(me.mapScaleTickPosX, 0)
			.horiz(-width*0.025/2)
			.setColor(COLOR_WHITE)
		    .setStrokeLineWidth(w);
		me.mapScaleTick0Txt = me.mapScale.createChild("text")
    		.setText("0")
    		.setColor(COLOR_WHITE)
    		.setAlignment("right-center")
    		.setTranslation(me.mapScaleTickPosTxtX, 0)
    		.setFontSize(15, 1);
    	me.mapScaleTick1 = me.mapScale.createChild("path")
			.moveTo(me.mapScaleTickPosX, 0)
			.horiz(-width*0.025/2)
			.setColor(COLOR_WHITE)
		    .setStrokeLineWidth(w);
		me.mapScaleTick1Txt = me.mapScale.createChild("text")
    		.setText("50")
    		.setColor(COLOR_WHITE)
    		.setAlignment("right-center")
    		.setTranslation(me.mapScaleTickPosTxtX, -height/4)
    		.setFontSize(15, 1);
    	me.mapScaleTick2 = me.mapScale.createChild("path")
			.moveTo(me.mapScaleTickPosX, 0)
			.horiz(-width*0.025/2)
			.setColor(COLOR_WHITE)
		    .setStrokeLineWidth(w);
		me.mapScaleTick2Txt = me.mapScale.createChild("text")
    		.setText("100")
    		.setColor(COLOR_WHITE)
    		.setAlignment("right-center")
    		.setTranslation(me.mapScaleTickPosTxtX, -height/2)
    		.setFontSize(15, 1);
    	me.mapScaleTick3 = me.mapScale.createChild("path")
			.moveTo(me.mapScaleTickPosX, 0)
			.horiz(-width*0.025/2)
			.setColor(COLOR_WHITE)
		    .setStrokeLineWidth(w);
		me.mapScaleTick3Txt = me.mapScale.createChild("text")
    		.setText("150")
    		.setColor(COLOR_WHITE)
    		.setAlignment("right-center")
    		.setTranslation(me.mapScaleTickPosTxtX, -height/4)
    		.setFontSize(15, 1);
    	me.mapScaleTickM1 = me.mapScale.createChild("path")
			.moveTo(me.mapScaleTickPosX, 0)
			.horiz(-width*0.025/2)
			.setColor(COLOR_WHITE)
		    .setStrokeLineWidth(w);
		me.mapScaleTickM1Txt = me.mapScale.createChild("text")
    		.setText("-50")
    		.setColor(COLOR_WHITE)
    		.setAlignment("right-center")
    		.setTranslation(me.mapScaleTickPosTxtX, -height/4)
    		.setFontSize(15, 1);
    	me.mapScaleTickM2 = me.mapScale.createChild("path")
			.moveTo(me.mapScaleTickPosX, 0)
			.horiz(-width*0.025/2)
			.setColor(COLOR_WHITE)
		    .setStrokeLineWidth(w);
		me.mapScaleTickM2Txt = me.mapScale.createChild("text")
    		.setText("-100")
    		.setColor(COLOR_WHITE)
    		.setAlignment("right-center")
    		.setTranslation(me.mapScaleTickPosTxtX, -height/2)
    		.setFontSize(15, 1);
    	me.mapScaleTickM3 = me.mapScale.createChild("path")
			.moveTo(me.mapScaleTickPosX, 0)
			.horiz(-width*0.025/2)
			.setColor(COLOR_WHITE)
		    .setStrokeLineWidth(w);
		me.mapScaleTickM3Txt = me.mapScale.createChild("text")
    		.setText("-150")
    		.setColor(COLOR_WHITE)
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
		      .setColor(COLOR_WHITE)
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
		      .setColor(COLOR_WHITE)
		      .setStrokeLineWidth(w)
		      .set("z-index", 5);

		# own symbol
		me.selfSymbol = me.rootCenter.createChild("path")
		      .moveTo(-5*MM2TEX, 15*MM2TEX)
		      .lineTo( 0,         0*MM2TEX)
		      .lineTo( 5*MM2TEX, 15*MM2TEX)
		      .lineTo(-5*MM2TEX, 15*MM2TEX)
		      .setColor(COLOR_WHITE)
		      .set("z-index", 10)
		      .setStrokeLineWidth(w);
		me.selfSymbolGPS = me.rootCenter.createChild("path")
		      .moveTo(-5*MM2TEX, 15*MM2TEX)
		      .lineTo( 0,         0*MM2TEX)
		      .lineTo( 5*MM2TEX, 15*MM2TEX)
		      .lineTo(-5*MM2TEX, 15*MM2TEX)
		      .setColor(COLOR_WHITE)
		      .setColorFill(COLOR_WHITE)
		      .set("z-index", 10)
		      .setStrokeLineWidth(w);
		me.selfVectorG = me.rootCenter.createChild("group")
			.set("z-index", 10)
			.setTranslation(0,0);
		me.selfVector = me.selfVectorG.createChild("path")
			  .set("z-index", 10)
			  .moveTo(0,  0)
			  .lineTo(0, -1*MM2TEX)
			  .setColor(COLOR_WHITE)
		      .setStrokeLineWidth(w);

		me.ppGrp = me.rootCenter.createChild("group")
			.set("z-index", 2);

		# main radar and SVY group
		me.radar_group = me.rootCenter.createChild("group")
			.set("z-index", 5);

		me.tracks = [];
		for (var i=0; i<maxTracks; i+=1) {
			var echo = {};
			echo.grp = me.radar_group.createChild("group")
				.set("z-index", maxTracks+maxDLTracks+maxMissiles-i);
			# Speed vector
			echo.vector = echo.grp.createChild("path")
				.moveTo(0, 0).vert(-1 * MM2TEX)
				.setStrokeLineWidth(w);
			# Primary target symbol
			echo.primary = echo.grp.createChild("path")
				.moveTo(-8*MM2TEX, 4*MM2TEX).horiz(16*MM2TEX)
				.moveTo(-8*MM2TEX, -4*MM2TEX).horiz(16*MM2TEX)
				.moveTo(4*MM2TEX, -8*MM2TEX).vert(16*MM2TEX)
				.moveTo(-4*MM2TEX, -8*MM2TEX).vert(16*MM2TEX)
				.setStrokeLineWidth(w);
			# Secondary target symbol
			echo.secondary = echo.grp.createChild("path")
				.moveTo(-8*MM2TEX, 4*MM2TEX).horiz(4*MM2TEX).vert(4*MM2TEX)
				.moveTo(-8*MM2TEX, -4*MM2TEX).horiz(4*MM2TEX).vert(-4*MM2TEX)
				.moveTo(8*MM2TEX, 4*MM2TEX).horiz(-4*MM2TEX).vert(4*MM2TEX)
				.moveTo(8*MM2TEX, -4*MM2TEX).horiz(-4*MM2TEX).vert(-4*MM2TEX)
				.setStrokeLineWidth(w);
			# Targeted, IFF friendly
			echo.friendly = echo.grp.createChild("path")
				.moveTo(-8*MM2TEX, -8*MM2TEX).lineTo(8*MM2TEX, 8*MM2TEX)
				.moveTo(-8*MM2TEX, 8*MM2TEX).lineTo(8*MM2TEX, -8*MM2TEX)
				.setStrokeLineWidth(w);
			# Text for datalink identifier
			echo.datalink_id = echo.grp.createChild("text")
				.setTranslation(0, 30*MM2TEX)
				.setAlignment("center-bottom")
				.setFontSize(15*MM2TEX, 1)
				.setText("");
			append(me.tracks, echo);
		}

		me.DLtracks = [];
		for (var i=0; i<maxDLTracks; i+=1) {
			var echo = {};
			echo.grp = me.radar_group.createChild("group")
				.set("z-index", maxDLTracks+maxMissiles-i);
			# Speed vector
			echo.vector = echo.grp.createChild("path")
				.moveTo(0, 0).vert(-1 * MM2TEX)
				.setStrokeLineWidth(w);
			# On datalink symbol
			echo.datalink = echo.grp.createChild("path")
				.moveTo(0, 0)
				.lineTo(5*MM2TEX, 7*MM2TEX)
				.lineTo(5*MM2TEX, 15*MM2TEX)
				.lineTo(-5*MM2TEX, 15*MM2TEX)
				.lineTo(-5*MM2TEX, 7*MM2TEX)
				.lineTo(0, 0)
				.moveTo(0, 15*MM2TEX)
				.lineTo(0, 8*MM2TEX)
				.setStrokeLineWidth(w);
			# From datalink symbol
			echo.dl_tgt = echo.grp.createChild("path")
				.moveTo(-7.5, 7.5)
				.arcSmallCW(7.5, 7.5, 0, 15, 0)
				.arcSmallCW(7.5, 7.5, 0, -15, 0)
				.moveTo(-3.75, 11.25)
				.arcSmallCW(3.75, 3.75, 0, 7.5, 0)
				.arcSmallCW(3.75, 3.75, 0, -7.5, 0)
				.setStrokeLineWidth(w);
			# Text for datalink identifier
			echo.datalink_id = echo.grp.createChild("text")
				.setTranslation(0, 30*MM2TEX)
				.setAlignment("center-bottom")
				.setFontSize(15*MM2TEX, 1)
				.setText("");
			append(me.DLtracks, echo);
		}

		# missiles
		me.missiles = [];
		for (var i = 0; i < maxMissiles; i += 1) {
			var missile = {};
			missile.grp = me.radar_group.createChild("group")
				.set("z-index", maxMissiles-i);
			missile.vector = missile.grp.createChild("path")
				.moveTo(0, 0).vert(-1*MM2TEX)
				.setColor(COLOR_WHITE)
				.setStrokeLineWidth(w);
			missile.symbol = missile.grp.createChild("path")
				.moveTo(0,0)
				.lineTo(-2.5*MM2TEX,  15*MM2TEX)
				.lineTo(2.5*MM2TEX,  15*MM2TEX)
				.close()
				.setColor(COLOR_WHITE)
				.setStrokeLineWidth(w);
			append(me.missiles, missile);
		}

		# SVY
		me.rootSVY = root.createChild("group")
			.set("z-index", 1);
		me.svy_grp = me.rootSVY.createChild("group");
		me.svy_radar_grp = me.svy_grp.createChild("group");
		me.svy_grp2 = me.svy_grp.createChild("group")
			.set("z-index", 1);

		me.tracksSVY = [];
		for (var i=0; i<maxTracks; i+=1) {
			var echo = {};
			echo.grp = me.svy_radar_grp.createChild("group")
				.set("z-index", maxTracks+maxDLTracks+maxMissiles-i);
			# Speed vector
			echo.vector = echo.grp.createChild("path")
				.moveTo(0, 0).vert(-1 * MM2TEX)
				.setStrokeLineWidth(w);
			# Primary target symbol
			echo.primary = echo.grp.createChild("path")
				.moveTo(-8*MM2TEX, 4*MM2TEX).horiz(16*MM2TEX)
				.moveTo(-8*MM2TEX, -4*MM2TEX).horiz(16*MM2TEX)
				.moveTo(4*MM2TEX, -8*MM2TEX).vert(16*MM2TEX)
				.moveTo(-4*MM2TEX, -8*MM2TEX).vert(16*MM2TEX)
				.setStrokeLineWidth(w);
			# Secondary target symbol
			echo.secondary = echo.grp.createChild("path")
				.moveTo(-8*MM2TEX, 4*MM2TEX).horiz(4*MM2TEX).vert(4*MM2TEX)
				.moveTo(-8*MM2TEX, -4*MM2TEX).horiz(4*MM2TEX).vert(-4*MM2TEX)
				.moveTo(8*MM2TEX, 4*MM2TEX).horiz(-4*MM2TEX).vert(4*MM2TEX)
				.moveTo(8*MM2TEX, -4*MM2TEX).horiz(-4*MM2TEX).vert(-4*MM2TEX)
				.setStrokeLineWidth(w);
			# Targeted, IFF friendly
			echo.friendly = echo.grp.createChild("path")
				.moveTo(-8*MM2TEX, -8*MM2TEX).lineTo(8*MM2TEX, 8*MM2TEX)
				.moveTo(-8*MM2TEX, 8*MM2TEX).lineTo(8*MM2TEX, -8*MM2TEX)
				.setStrokeLineWidth(w);
			# Text for datalink identifier
			echo.datalink_id = echo.grp.createChild("text")
				.setTranslation(0, 30*MM2TEX)
				.setAlignment("center-bottom")
				.setFontSize(15*MM2TEX, 1)
				.setText("");
			append(me.tracksSVY, echo);
		}

		me.DLtracksSVY = [];
		for (var i=0; i<maxDLTracks; i+=1) {
			var echo = {};
			echo.grp = me.svy_radar_grp.createChild("group")
				.set("z-index", maxDLTracks+maxMissiles-i);
			# Speed vector
			echo.vector = echo.grp.createChild("path")
				.moveTo(0, 0).vert(-1 * MM2TEX)
				.setStrokeLineWidth(w);
			# On datalink symbol
			echo.datalink = echo.grp.createChild("path")
				.moveTo(0, 0)
				.lineTo(5*MM2TEX, 7*MM2TEX)
				.lineTo(5*MM2TEX, 15*MM2TEX)
				.lineTo(-5*MM2TEX, 15*MM2TEX)
				.lineTo(-5*MM2TEX, 7*MM2TEX)
				.lineTo(0, 0)
				.moveTo(0, 15*MM2TEX)
				.lineTo(0, 8*MM2TEX)
				.setStrokeLineWidth(w);
			# From datalink symbol
			echo.dl_tgt = echo.grp.createChild("path")
				.moveTo(-7.5, 7.5)
				.arcSmallCW(7.5, 7.5, 0, 15, 0)
				.arcSmallCW(7.5, 7.5, 0, -15, 0)
				.moveTo(-3.75, 11.25)
				.arcSmallCW(3.75, 3.75, 0, 7.5, 0)
				.arcSmallCW(3.75, 3.75, 0, -7.5, 0)
				.setStrokeLineWidth(w);
			# Text for datalink identifier
			echo.datalink_id = echo.grp.createChild("text")
				.setTranslation(0, 30*MM2TEX)
				.setAlignment("center-bottom")
				.setFontSize(15*MM2TEX, 1)
				.setText("");
			append(me.DLtracksSVY, echo);
		}

		# missiles
		me.missilesSVY = [];
		for (var i = 0; i < maxMissiles; i += 1) {
			var missile = {};
			missile.grp = me.svy_radar_grp.createChild("group")
				.set("z-index", maxMissiles-i);
			missile.vector = missile.grp.createChild("path")
				.moveTo(0, 0).vert(-1*MM2TEX)
				.setColor(COLOR_WHITE)
				.setStrokeLineWidth(w);
			missile.symbol = missile.grp.createChild("path")
				.moveTo(0,0)
				.lineTo(-2.5*MM2TEX,  15*MM2TEX)
				.lineTo(2.5*MM2TEX,  15*MM2TEX)
				.close()
				.setColor(COLOR_WHITE)
				.setStrokeLineWidth(w);
			append(me.missilesSVY, missile);
		}

		me.selfGroupSvy = me.svy_grp.createChild("group");

		me.selfSymbolSvy = me.selfGroupSvy.createChild("path")
			.moveTo(-5*MM2TEX,  15*MM2TEX)
			.lineTo( 0,       0*MM2TEX)
			.moveTo( 5*MM2TEX,  15*MM2TEX)
			.lineTo( 0,       0*MM2TEX)
			.moveTo(-5*MM2TEX,  15*MM2TEX)
			.lineTo( 5*MM2TEX,  15*MM2TEX)
			.setColor(COLOR_WHITE)
			.setRotation(90*D2R)
			.set("z-index", 10)
			.setStrokeLineWidth(w);
		me.selfVectorSvy = me.selfGroupSvy.createChild("path")
			.moveTo(0,  0)
			.set("z-index", 10)
			.lineTo(1*MM2TEX, 0)
			.setColor(COLOR_WHITE)
			.setStrokeLineWidth(w);

		me.radarTopSvy = me.svy_grp.createChild("path")
			.setColor(COLOR_WHITE)
			.set("z-index", 10)
			.setStrokeLineWidth(w);
		me.radarBotSvy = me.svy_grp.createChild("path")
			.setColor(COLOR_WHITE)
			.set("z-index", 10)
			.setStrokeLineWidth(w);

		# SVY coordinate text
		me.textSvyY = me.svy_grp.createChild("text")
    		.setText("40 KM")
    		.setColor(COLOR_WHITE)
    		.setAlignment("left-bottom")
    		.setTranslation(0, 0)
    		.set("z-index", 7)
    		.setFontSize(13, 1);
    	me.textSvyX = me.svy_grp.createChild("text")
    		.setText("120 KM")
    		.setColor(COLOR_WHITE)
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
	               .setColor(COLOR_TYRK)
	               .hide();
	    me.runway_line = me.dest.createChild("path")
	               .moveTo(0, 0)
	               .lineTo(0, 1)
	               .setStrokeLineWidth(w*4.5)
	               .setStrokeLineCap("butt")
	               .setColor(COLOR_WHITE)
	               .hide();
	    me.runway_name = me.dest.createChild("text")
    		.setText("32")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-center")
    		.setTranslation(25, 0)
    		.setFontSize(15, 1);
	    me.dest_circle = me.dest.createChild("path")
	               .moveTo(-12.5, 0)
	               .arcSmallCW(12.5, 12.5, 0, 25, 0)
	               .arcSmallCW(12.5, 12.5, 0, -25, 0)
	               .setStrokeLineWidth(w)
	               .setColor(COLOR_TYRK);
	    me.approach_circle = me.rootCenter.createChild("path")
	    			.set("z-index", 7)
	               .moveTo(-100, 0)
	               .arcSmallCW(100, 100, 0, 200, 0)
	               .arcSmallCW(100, 100, 0, -200, 0)
	               .setStrokeLineWidth(w*1.5)
	               .setColor(COLOR_TYRK);

	    # route symbols
	    me.steerpoint = [];
	    me.steerpointText = [];
	    me.steerpointSymbol = [];
	    me.steerPointMax = -1;
	    
	    me.rrSymbolS = me.rootCenter.createChild("path")
	       .moveTo(-15, 0)
           .arcSmallCW(15, 15, 0, 30, 0)
           .arcSmallCW(15, 15, 0, -30, 0)
           .set("z-index", 6)
	       .setColor(COLOR_WHITE)
	       .setStrokeLineWidth(w);
	    me.steerPoly = me.rootCenter.createChild("group")
	    			.set("z-index", 6);


		me.rrSymbol = me.radar_group.createChild("group");
		me.rrSymbol2 = me.rrSymbol.createChild("path")
			.moveTo(-15, 0)
			.arcSmallCW(15, 15, 0, 30, 0)
			.arcSmallCW(15, 15, 0, -30, 0)
			.set("z-index", maxTracks+maxDLTracks+maxMissiles)
			.setColor(COLOR_WHITE)
			.setStrokeLineWidth(w);

		me.radar_limit_grp = me.radar_group.createChild("group");

		var csize = 24;
		me.cursor = root.createChild("path")
			.moveTo(-csize*MM2TEX,0).horizTo(-4*MM2TEX)
			.moveTo(csize*MM2TEX,0).horizTo(4*MM2TEX)
			.moveTo(0,-csize*MM2TEX).vertTo(-4*MM2TEX)
			.moveTo(0,csize*MM2TEX).vertTo(4*MM2TEX)
			.moveTo(-w,0).horizTo(w)
			.setStrokeLineWidth(w*2)
			.setTranslation(50*MM2TEX, height*0.5)
			.setStrokeLineCap("butt")
			.set("z-index", 25)#max
			.setColor(COLOR_WHITE);

		var MI_csize = 18;
		me.MI_cursor = me.radar_group.createChild("path")
			.moveTo(-MI_csize*MM2TEX, -MI_csize*MM2TEX).lineTo(-3*MM2TEX, -3*MM2TEX)
			.moveTo(-MI_csize*MM2TEX, MI_csize*MM2TEX).lineTo(-3*MM2TEX, 3*MM2TEX)
			.moveTo(MI_csize*MM2TEX, -MI_csize*MM2TEX).lineTo(3*MM2TEX, -3*MM2TEX)
			.moveTo(MI_csize*MM2TEX, MI_csize*MM2TEX).lineTo(3*MM2TEX, 3*MM2TEX)
			.moveTo(-w,0).horizTo(w)
			.setStrokeLineWidth(w*2)
			.setTranslation(50*MM2TEX, height*0.5)
			.setStrokeLineCap("butt")
			.set("z-index", 25)#max
			.setColor(COLOR_WHITE);

		# bulls eye

		me.bullsEye = me.rootCenter.createChild("path")
					.set("z-index", 1)
				    .moveTo(-14, 0)
				    .horiz(28)
				    .moveTo(0, 14)
				    .vert(-42)
				    .moveTo(0, -28)
				    .lineTo(7, -21)
				    .moveTo(0, -28)
				    .lineTo(-7, -21)
	                .moveTo(-14, 0)
	                .arcSmallCW(14, 14, 0, 28, 0)
	                .arcSmallCW(14, 14, 0, -28, 0)
	                .setStrokeLineWidth(w)
	                .setColor(COLOR_TYRK);

		# bulls eye info box

		me.beTextField     = root.createChild("group")
			.set("z-index", 11);

		var beW      = 0.35;
		var beH      = 0.03;
		var beStartx = width-(width*0.060-3.125+6.25*2+w*2) - width*beW;
		var beStarty = height-height*0.1-height*0.025-w*2;

		me.beTextFrame     = me.beTextField.createChild("path")
			.moveTo(beStartx, beStarty)#above bottom text field and next to fast menu sub boxes
		      .vert(            -height*beH)
		      .horiz(            width*beW)
		      .vert(             height*beH)
		      .horiz(           -width*beW)

		      .moveTo(beStartx+width*beW*0.2, beStarty)
		      .vert(            -height*beH)
		      .setColor(COLOR_WHITE)
		      .setStrokeLineWidth(w);

		me.beTextDesc = me.beTextField.createChild("text")
    		.setText("B-E")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-bottom")
    		.setTranslation(beStartx+width*beW*0.1, beStarty-w)
    		.setFontSize(15, 1);
    	me.beText = me.beTextField.createChild("text")
    		.setText("190  A132")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-bottom")
    		.setTranslation(beStartx+width*beW*0.6, beStarty-w)
    		.setFontSize(15, 1);

		# target info box
		me.tgtTextField     = root.createChild("group")
			.set("z-index", 11);

		var tgtW      = 0.15;
		var tgtH      = 0.10;
		var tgtStartx = width-(width*0.060-3.125+6.25*2+w*2) - width*tgtW;
		var tgtStarty = height-height*0.14-height*0.025-w*2;

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
		      .setColor(COLOR_WHITE)
		      .setStrokeLineWidth(w);
		me.tgtTextDistDesc = me.tgtTextField.createChild("text")
    		.setText("A")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-bottom")
    		.setTranslation(tgtStartx+width*tgtW*0.1, tgtStarty-height*tgtH*0.66-w)
    		.setFontSize(15, 1);
    	me.tgtTextDist = me.tgtTextField.createChild("text")
    		.setText("74")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-bottom")
    		.setTranslation(tgtStartx+width*tgtW*0.60, tgtStarty-height*tgtH*0.66-w)
    		.setFontSize(15, 1);
    	me.tgtTextHeiDesc = me.tgtTextField.createChild("text")
    		.setText("H")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-bottom")
    		.setTranslation(tgtStartx+width*tgtW*0.1, tgtStarty-height*tgtH*0.33-w)
    		.setFontSize(15, 1);
    	me.tgtTextHei = me.tgtTextField.createChild("text")
    		.setText("4700")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-bottom")
    		.setTranslation(tgtStartx+width*tgtW*0.60, tgtStarty-height*tgtH*0.33-w)
    		.setFontSize(15, 1);
    	me.tgtTextSpdDesc = me.tgtTextField.createChild("text")
    		.setText("M")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-bottom")
    		.setTranslation(tgtStartx+width*tgtW*0.1, tgtStarty-height*tgtH*0.0-w)
    		.setFontSize(15, 1);
    	me.tgtTextSpd = me.tgtTextField.createChild("text")
    		.setText("0,80")
    		.setColor(COLOR_WHITE)
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
		      .setColor(COLOR_WHITE)
		      .setStrokeLineWidth(w);
		me.wpTextFrame1    = me.wpTextField.createChild("path")
			.moveTo(me.wpStartx,  me.wpStarty-height*me.wpH)#above bottom text field and next to fast menu sub boxes
		      .vert(            -height*me.wpH*0.2)
		      .horiz(            width*me.wpW)
		      .vert(             height*me.wpH*0.2)
		      .moveTo(me.wpStartx+width*me.wpW*0.3, me.wpStarty-height*me.wpH)
		      .vert(            -height*me.wpH*0.2)
		      .setColor(COLOR_WHITE)
		      .setStrokeLineWidth(w);
		me.wpText2Desc = me.wpTextField.createChild("text")
    		.setText("BEN")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.15, me.wpStarty-height*me.wpH*0.8-w)
    		.setFontSize(15, 1);
    	me.wpText2 = me.wpTextField.createChild("text")
    		.setText("1 AV 4")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.65, me.wpStarty-height*me.wpH*0.8-w)
    		.setFontSize(15, 1);
    	me.wpText3Desc = me.wpTextField.createChild("text")
    		.setText("B")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.15, me.wpStarty-height*me.wpH*0.6-w)
    		.setFontSize(15, 1);
    	me.wpText3 = me.wpTextField.createChild("text")
    		.setText("0 -> 1")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.65, me.wpStarty-height*me.wpH*0.6-w)
    		.setFontSize(15, 1);
    	me.wpText4Desc = me.wpTextField.createChild("text")
    		.setText("H")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.15, me.wpStarty-height*me.wpH*0.4-w)
    		.setFontSize(15, 1);
    	me.wpText4 = me.wpTextField.createChild("text")
    		.setText("10000")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.65, me.wpStarty-height*me.wpH*0.4-w)
    		.setFontSize(15, 1);
    	me.wpText5Desc = me.wpTextField.createChild("text")
    		.setText("M")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.15, me.wpStarty-height*me.wpH*0.2-w)
    		.setFontSize(15, 1);
    	me.wpText5 = me.wpTextField.createChild("text")
    		.setText("300")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.65, me.wpStarty-height*me.wpH*0.2-w)
    		.setFontSize(15, 1);
    	me.wpText6Desc = me.wpTextField.createChild("text")
    		.setText("ETA")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.15, me.wpStarty-height*me.wpH*0.0-w)
    		.setFontSize(15, 1);
    	me.wpText6 = me.wpTextField.createChild("text")
    		.setText("3:43")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.65, me.wpStarty-height*me.wpH*0.0-w)
    		.setFontSize(15, 1);
    	me.wpText1Desc = me.wpTextField.createChild("text")
    		.setText("TOP")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.15, me.wpStarty-height*me.wpH*1.0-w)
    		.setFontSize(15, 1);
    	me.wpText1 = me.wpTextField.createChild("text")
    		.setText("BLABLA")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-bottom")
    		.setTranslation(me.wpStartx+width*me.wpW*0.65, me.wpStarty-height*me.wpH*1.0-w)
    		.setFontSize(15, 1);


    	# bottom txt field
		me.bottom_text_grp = root.createChild("group");
		me.textBArmType = me.bottom_text_grp.createChild("text")
    		.setText("74")
    		.setColor(COLOR_WHITE)
    		.setAlignment("left-top")
    		.setTranslation(0, height-height*0.09)
    		.setFontSize(35, 1);
    	me.textBArmAmmo = me.bottom_text_grp.createChild("text")
    		.setText("71")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-bottom")
    		.setTranslation(25, height-height*0.01)
    		.setFontSize(15, 1);
    	me.textBTactType1 = me.bottom_text_grp.createChild("text")
    		.setText("J")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-top")
    		.setTranslation(55, height-height*0.08)
    		.setFontSize(13, 1);
    	me.textBTactType2 = me.bottom_text_grp.createChild("text")
    		.setText("K")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-top")
    		.setTranslation(55, height-height*0.08+15)
    		.setFontSize(13, 1);
    	me.textBTactType3 = me.bottom_text_grp.createChild("text")
    		.setText("T")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-top")
    		.setTranslation(55, height-height*0.08+30)
    		.setFontSize(13, 1);
    	me.textBTactType = me.bottom_text_grp.createChild("path")
    		.moveTo(50, height-height*0.09)
    		.horiz(12)
    		.vert(45)
    		.horiz(-12)
    		.vert(-45)
    		.setColor(COLOR_WHITE)
		    .setStrokeLineWidth(w);
    	me.textBBase = me.bottom_text_grp.createChild("text")
    		.setText("9040T")
    		.setColor(COLOR_WHITE)
    		.setAlignment("center-bottom")
    		.setTranslation(80, height-height*0.01)
    		.setFontSize(10, 1);
    	me.textBlink = me.bottom_text_grp.createChild("text")
    		.setText("DL")
    		.setColor(COLOR_GREY)
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
    		.setColor(COLOR_WHITE)
		    .setStrokeLineWidth(w);
		me.textBLinkFrame2 = me.bottom_text_grp.createChild("path")
    		.moveTo(65, height-height*0.085)
    		.horiz(16)
    		.vert(12)
    		.horiz(-16)
    		.vert(-12)
    		.setColor(COLOR_WHITE)
    		.set("z-index", 1)
		    .setColorFill(COLOR_GREEN)
		    .setStrokeLineWidth(w);
		me.textBerror = me.bottom_text_grp.createChild("text")
    		.setText("F")
    		.setColor(COLOR_GREY)
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
    		.setColor(COLOR_WHITE)
		    .setStrokeLineWidth(w);
		me.textBerrorFrame2 = me.bottom_text_grp.createChild("path")
    		.moveTo(85, height-height*0.085)
    		.horiz(10)
    		.vert(12)
    		.horiz(-10)
    		.vert(-12)
    		.setColor(COLOR_WHITE)
    		.hide()
    		.set("z-index", 1)
		    .setColorFill(COLOR_GREEN)
		    .setStrokeLineWidth(w);
    	me.textBMode = me.bottom_text_grp.createChild("text")
    		.setText("LF")
    		.setColor(COLOR_TYRK)
    		.setAlignment("center-center")
    		.setTranslation(125, height-height*0.05)
    		.setFontSize(40, 1);
    	me.textBDistN = me.bottom_text_grp.createChild("text")
    		.setText("A")
    		.setColor(COLOR_WHITE)
    		.setAlignment("right-bottom")
    		.setTranslation(width/2, height-height*0.015)
    		.setFontSize(20, 1);
    	me.textBDist = me.bottom_text_grp.createChild("text")
    		.setText("11")
    		.setColor(COLOR_WHITE)
    		.setAlignment("left-bottom")
    		.setTranslation(width/2, height-height*0.015)
    		.setFontSize(27, 1);
    	me.textBAlpha = me.bottom_text_grp.createChild("text")
    		.setText("ALFA 20,5")
    		.setColor(COLOR_WHITE)
    		.setAlignment("right-bottom")
    		.setTranslation(width, height-height*0.01)
    		.setFontSize(16, 1);
    	me.textBWeight = me.bottom_text_grp.createChild("text")
    		.setText("VIKT 13,4")
    		.setColor(COLOR_WHITE)
    		.setAlignment("right-top")
    		.setTranslation(width, height-height*0.085)
    		.setFontSize(16, 1);

    	# log pages
    	me.logRoot = root.createChild("group")
    		.set("z-index", 5)
    		.hide();
    	me.errorList = me.logRoot.createChild("text")
    		.setText("..OKAY..\n..OKAY..")
    		.setColor(COLOR_WHITE)
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
    				.setColor(COLOR_WHITE)
    				.setAlignment("left-center")
    				.setTranslation(width*0.025, height*0.09+(i-1)*height*0.11)
    				.setFontSize(12.5, 1));
		}
		for(var i = 8; i <= 13; i+=1) {
			append(me.menuButton, me.menuMainRoot.createChild("text")
    			.setText("MAIN")
    			.setColor(COLOR_WHITE)
    			.setAlignment("center-bottom")
    			.setPadding(0,0,0,0)
    			.setTranslation(width*0.135+(i-8)*width*0.1475, height)
    			.setFontSize(13, 1));
		}
    	for(var i = 14; i <= 20; i+=1) {
			append(me.menuButton,
				me.menuFastRoot.createChild("text")
    				.setText("M\nE\nN\nY")
    				.setColor(COLOR_WHITE)
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
    				.setColor(COLOR_WHITE)
		    		.setStrokeLineWidth(w));
		}
		for(var i = 8; i <= 13; i+=1) {
			append(me.menuButtonBox, me.menuMainRoot.createChild("path")
					.moveTo(width*0.135+((i-8)*width*0.1475)-6.25*3, height)
    				.horiz(6.25*6)
    				.vert(-6.25*2)
    				.horiz(-6.25*6)
    				.vert(6.25*2)
    				.setColor(COLOR_WHITE)
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
    				.setColor(COLOR_WHITE)
		    		.setStrokeLineWidth(w));
		}

		# text for inner menu items
		#
		me.menuButtonSub = [nil];
		for(var i = 1; i <= 7; i+=1) {
			append(me.menuButtonSub,
				me.menuFastRoot.createChild("text")
    				.setText("M\nE\nN\nY")
    				.setColor(COLOR_WHITE)
    				.setColorFill(COLOR_GREY)
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
    				.setColor(COLOR_WHITE)
    				.setColorFill(COLOR_GREY)
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
    				.setColor(COLOR_WHITE)
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
    				.setColor(COLOR_WHITE)
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
	               .setColor(COLOR_TYRK));
			append(me.baseLargeText,
				me.base_grp.createChild("text")
    				.setText("ICAO")
    				.setColor(COLOR_TYRK)
    				.setAlignment("center-center")
    				.setTranslation(0,0)
    				.hide()
    				.setFontSize(13, 1));
		}

		me.ecm_grp = me.rootCenter.createChild("group")
			.set("z-index", 0);
		me.ecmRadius = 50;
		me.ecm = [];
	    append(me.ecm, me.ecm_grp.createChild("path")
			.moveTo(circlePosH(-14, me.ecmRadius)[0], circlePosH(-14, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(14, me.ecmRadius)[0]-circlePosH(-14, me.ecmRadius)[0], circlePosH(14, me.ecmRadius)[1]-circlePosH(-14, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(COLOR_YELLOW));
	    append(me.ecm, me.ecm_grp.createChild("path")
			.moveTo(circlePosH(16, me.ecmRadius)[0], circlePosH(16, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(44, me.ecmRadius)[0]-circlePosH(16, me.ecmRadius)[0], circlePosH(44, me.ecmRadius)[1]-circlePosH(16, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(COLOR_YELLOW));
	    append(me.ecm, me.ecm_grp.createChild("path")
			.moveTo(circlePosH(46, me.ecmRadius)[0], circlePosH(46, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(74, me.ecmRadius)[0]-circlePosH(46, me.ecmRadius)[0], circlePosH(74, me.ecmRadius)[1]-circlePosH(46, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(COLOR_YELLOW));
	    append(me.ecm, me.ecm_grp.createChild("path")
			.moveTo(circlePosH(76, me.ecmRadius)[0], circlePosH(76, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(104, me.ecmRadius)[0]-circlePosH(76, me.ecmRadius)[0], circlePosH(104, me.ecmRadius)[1]-circlePosH(76, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(COLOR_YELLOW));
	    append(me.ecm, me.ecm_grp.createChild("path")
			.moveTo(circlePosH(106, me.ecmRadius)[0], circlePosH(106, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(134, me.ecmRadius)[0]-circlePosH(106, me.ecmRadius)[0], circlePosH(134, me.ecmRadius)[1]-circlePosH(106, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(COLOR_YELLOW));
	    append(me.ecm, me.ecm_grp.createChild("path")
			.moveTo(circlePosH(136, me.ecmRadius)[0], circlePosH(136, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(164, me.ecmRadius)[0]-circlePosH(136, me.ecmRadius)[0], circlePosH(164, me.ecmRadius)[1]-circlePosH(136, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(COLOR_YELLOW));
	    append(me.ecm, me.ecm_grp.createChild("path")
			.moveTo(circlePosH(166, me.ecmRadius)[0], circlePosH(166, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(194, me.ecmRadius)[0]-circlePosH(166, me.ecmRadius)[0], circlePosH(194, me.ecmRadius)[1]-circlePosH(166, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(COLOR_YELLOW));
	    append(me.ecm, me.ecm_grp.createChild("path")
			.moveTo(circlePosH(196, me.ecmRadius)[0], circlePosH(196, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(224, me.ecmRadius)[0]-circlePosH(196, me.ecmRadius)[0], circlePosH(224, me.ecmRadius)[1]-circlePosH(196, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(COLOR_YELLOW));
	    append(me.ecm, me.ecm_grp.createChild("path")
			.moveTo(circlePosH(226, me.ecmRadius)[0], circlePosH(226, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(254, me.ecmRadius)[0]-circlePosH(226, me.ecmRadius)[0], circlePosH(254, me.ecmRadius)[1]-circlePosH(226, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(COLOR_YELLOW));
	    append(me.ecm, me.ecm_grp.createChild("path")
			.moveTo(circlePosH(256, me.ecmRadius)[0], circlePosH(256, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(284, me.ecmRadius)[0]-circlePosH(256, me.ecmRadius)[0], circlePosH(284, me.ecmRadius)[1]-circlePosH(256, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(COLOR_YELLOW));
	    append(me.ecm, me.ecm_grp.createChild("path")
			.moveTo(circlePosH(286, me.ecmRadius)[0], circlePosH(286, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(314, me.ecmRadius)[0]-circlePosH(286, me.ecmRadius)[0], circlePosH(314, me.ecmRadius)[1]-circlePosH(286, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(COLOR_YELLOW));
	    append(me.ecm, me.ecm_grp.createChild("path")
			.moveTo(circlePosH(316, me.ecmRadius)[0], circlePosH(316, me.ecmRadius)[1])
	        .arcSmallCW(me.ecmRadius, me.ecmRadius, 0, circlePosH(344, me.ecmRadius)[0]-circlePosH(316, me.ecmRadius)[0], circlePosH(344, me.ecmRadius)[1]-circlePosH(316, me.ecmRadius)[1])
	        .setStrokeLineWidth(w*10)
	        .setColor(COLOR_YELLOW));

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
	               .setColor(COLOR_TYRK));
			append(me.baseSmallText,
				me.base_grp.createChild("text")
    				.setText("ICA")
    				.setColor(COLOR_TYRK)
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
		      .setColor(COLOR_GREY_BLUE);


		me.horizon_group = me.rootRealCenter.createChild("group");
		me.horz_rot = me.horizon_group.createTransform();
		me.horizon_group2 = me.horizon_group.createChild("group");
		me.horizon_line = me.horizon_group2.createChild("path")
		                     .moveTo(-height*0.75, 0)
		                     .horiz(height*1.5)
		                     .setStrokeLineWidth(w*2)
		                     .setColor(COLOR_GREY_BLUE);
		me.horizon_alt = me.horizon_group2.createChild("text")
				.setText("????")
				.setFontSize((25/512)*width, 1.0)
		        .setAlignment("center-bottom")
		        .setTranslation(-width*1/3, -w*4)
		        .setColor(COLOR_GREY_BLUE);

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
		        .setColor(COLOR_GREY_BLUE);

		# Collision warning arrow
		me.arr_15  = 5*0.75;
		me.arr_30  = 5*1.5;
		me.arr_90  = 3*9;
		me.arr_120 = 3*12;

		me.arrow_group = me.rootRealCenter.createChild("group");
		me.arrow_trans = me.arrow_group.createTransform();
		me.arrow =
		      me.arrow_group.createChild("path")
		      .setColor(COLOR_RED)
		      .setColorFill(COLOR_RED)
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
    		.setColor(COLOR_WHITE)
    		.setAlignment("right-top")
    		.setTranslation(width, 4)
    		.set("z-index", 7)
    		.setFontSize(13, 1);
    	me.textFTime = root.createChild("text")
    		.setText("FTIME h:min")
    		.setColor(COLOR_WHITE)
    		.setAlignment("left-top")
    		.setTranslation(0, 4)
    		.set("z-index", 7)
    		.setFontSize(13, 1);
	},

	new: func {
	  	var ti = { parents: [TI] };
	  	ti.input = {
			alt_ft:               "instrumentation/altimeter/indicated-altitude-ft",
			alt_true_ft:          "position/altitude-ft",
			heading:              "instrumentation/heading-indicator/indicated-heading-deg",
			radarStandby:         "instrumentation/radar/radar-standby",
			rad_alt:              "instrumentation/radar-altimeter/radar-altitude-ft",
			rad_alt_ready:        "instrumentation/radar-altimeter/ready",
			rmActive:             "autopilot/route-manager/active",
			rmDist:               "autopilot/route-manager/wp/dist",
			rmId:                 "autopilot/route-manager/wp/id",
			rmBearing:            "autopilot/route-manager/wp/true-bearing-deg",
			RMCurrWaypoint:       "autopilot/route-manager/current-wp",
			roll:                 "instrumentation/attitude-indicator/indicated-roll-deg",
			timeElapsed:          "sim/time/elapsed-sec",
			headTrue:             "orientation/heading-deg",
			fpv_up:               "instrumentation/fpv/angle-up-deg",
			fpv_right:            "instrumentation/fpv/angle-right-deg",
#			twoHz:                "ja37/blink/two-Hz/state",
			roll:             	  "orientation/roll-deg",
			pitch:             	  "orientation/pitch-deg",
			units:                "ja37/hud/units-metric",
			radar_serv:       	  "instrumentation/radar/serviceable",
			tenHz:            	  "ja37/blink/four-Hz/state",
	        nav0InRange:      	  "instrumentation/nav[0]/in-range",
	        fullMenus:            "ja37/displays/show-full-menus",
	        APLockHeading:    	  "autopilot/locks/heading",
	        APTrueHeadingErr: 	  "autopilot/internal/true-heading-error-deg",
	        APnav0HeadingErr: 	  "autopilot/internal/nav1-heading-error-deg",
	        APHeadingBug:     	  "autopilot/settings/heading-bug-deg",
	        RMActive:             "autopilot/route-manager/active",
	        nav0Heading:          "instrumentation/nav[0]/heading-deg",
	        ias:                  "instrumentation/airspeed-indicator/indicated-speed-kt",
	        tas:                  "instrumentation/airspeed-indicator/true-speed-kt",
	        wow0:                 "fdm/jsbsim/gear/unit[0]/WOW",
        	wow1:                 "fdm/jsbsim/gear/unit[1]/WOW",
        	wow2:                 "fdm/jsbsim/gear/unit[2]/WOW",
        	gearsPos:         	  "gear/gear/position-norm",
        	latitude:             "position/latitude-deg",
        	longitude:            "position/longitude-deg",
			gpws_arrow:           "fdm/jsbsim/systems/mkv/ja-pull-up-arrow",
			gpws_margin:          "fdm/jsbsim/systems/mkv/ja-warning-margin-norm",
			elevCmd:              "fdm/jsbsim/fcs/elevator-cmd-norm",
			ailCmd:               "fdm/jsbsim/fcs/aileron-cmd-norm",
			instrNorm:            "controls/lighting/instruments-norm",
			bullseyeOn:           "ja37/navigation/bulls-eye-defined",
			bullseyeLat:          "ja37/navigation/bulls-eye-lat",
			bullseyeLon:          "ja37/navigation/bulls-eye-lon",
			datalink:             "/instrumentation/datalink/on",
			weight:               "fdm/jsbsim/inertia/weight-lbs",
			max_approach_alpha:   "fdm/jsbsim/systems/flight/approach-alpha-base",
      	};

      	foreach(var name; keys(ti.input)) {
        	ti.input[name] = props.globals.getNode(ti.input[name], 1);
      	}
      	ti.input["tiLight"] = [];
      	for (i=0;i<22;i+=1) {
      		append(ti.input.tiLight, props.globals.getNode("ja37/light/ti"~i,1));
      	}
      	
      	ti.setupCanvasSymbols();
      	
      	#map
      	ti.lat = ti.input.latitude.getValue();
		ti.lon = ti.input.longitude.getValue();
      	ti.mapSelfCentered = TRUE;
      	ti.day = TRUE;
		ti.ownPosition = 0.25;
		ti.ownPositionDigital = 2;
		ti.mapPlaces = CLEANMAP;
      	ti.setupMap();

      	# radar limit overlay
      	ti.lastRRT = 0;
		ti.lastRR  = 0;
		ti.lastZ   = 0;
		ti.lastScanW = 0;
		
		#grid
		ti.last_lat = 0;
		ti.last_lon = 0;
		ti.last_range = 0;
		ti.last_result = 0;
		ti.gridTextO = [];
		ti.gridTextA = [];
		ti.gridTextMaxA = -1;
		ti.gridTextMaxO = -1;
		
		# display
		ti.on = FALSE;
		ti.brightness = 1;
		ti.active = FALSE;

		# menu system
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
		ti.trapAll      = FALSE;
		ti.upText = FALSE;
		ti.logPage = 0;
		ti.showFullMenus = TRUE;
		ti.mapshowing = TRUE;

		# SidVY
		ti.SVYactive    = FALSE;
		ti.SVYscale     = SVY_ELKA;
		ti.SVYrmax      = 3;
		ti.SVYrmaxSE    = [15,30,60, 120];#km
		ti.SVYrmaxEN    = [8, 16, 32, 64];#nm
		ti.SVYhmax      = 2;
		ti.SVYhmaxSE    = [5, 10, 20, 40];#km
		ti.SVYhmaxEN    = [15,30,50, 100];#kFT
		ti.SVYsize      = 2;#size 1-3
		ti.SVYinclude   = SVY_ALL;
		ti.SVYheight    = 0;
		ti.SVYoriginY   = 0;

		# flight data overlay
		ti.displayFlight = FLIGHTDATA_OFF;
		
		# time/startfix overlay
		ti.displayTime = FALSE;
		ti.displayFTime = FALSE;
		
		# system stuff
		ti.ModeAttack = FALSE;
		ti.fr28Top    = FALSE;

		# Base overlay
		ti.basesNear  = [];
		ti.basesEnabled = FALSE;
		
		# log pages
		ti.logEvents  = events.LogBuffer.new(echo: 0);#compatible with older FG?
		ti.logBIT     = events.LogBuffer.new(echo: 0);#compatible with older FG?
		ti.logLand    = events.LogBuffer.new(echo: 0);#compatible with older FG?
		ti.BITon = FALSE;
		ti.BITtime = 0;
		ti.BITok1 = FALSE;
		ti.BITok2 = FALSE;
		ti.BITok3 = FALSE;
		ti.BITok4 = FALSE;
		ti.newFails = FALSE;
		ti.lastFailBlink = TRUE;
		ti.battChargeReported = 0;
		ti.landed = TRUE;
		
		# LV overlay
		ti.showAAAZones = TRUE;
		
		# rwr overlay
		ti.ECMon   = FALSE;
		
		# RB99 datalink
		ti.lnk99   = FALSE;

		# cursor
		ti.cursorPosX  = 0;
		ti.cursorPosY  = 0;
		ti.cursorGPosX=50*MM2TEX;
		ti.cursorGPosY=height*0.5;
		ti.blinkBox2 = FALSE;
		ti.blinkBox3 = FALSE;
		ti.blinkBox4 = FALSE;
		ti.blinkBox5 = FALSE;
		ti.blinkBox6 = FALSE;
		ti.cursorDidSomething = FALSE;
		ti.lvffDrag = nil;
		ti.sDrag = nil;
		ti.cursorTrigger = FALSE;
		ti.cursorTriggerPrev = FALSE;

		# steerpoints
		ti.newSteerPos = nil;
		ti.showSteers = TRUE;#only for debug turn to false
		ti.showSteerPoly = TRUE;#only for debug turn to false

		# bulls-eye
		ti.be = geo.Coord.new();
  		ti.cs = geo.Coord.new();

		# MI
		ti.mreg = FALSE;

		ti.startFailListener();
		
		# misc
		ti.twoHz = 0;
		

      	return ti;
	},


	startFailListener: func {
		#this will run entire session, so no need to unsubscribe.
		FailureMgr.events["trigger-fired"].subscribe(func {call(func{me.newFails = 1}, nil, me, me)});
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
		me.swedishMode = displays.metric;

		if (me.brightness < 0.25) {
			me.brightness = 0.25;
		} elsif (me.brightness > 1) {
			me.brightness = 1;
		}

		me.ac_pos = geo.aircraft_position();
		me.ind_head_true = me.input.heading.getValue();
		me.head_true = me.input.headTrue.getValue();
		me.indicated_alt_offset_ft = me.input.alt_ft.getValue() - me.input.alt_true_ft.getValue();

		if (!me.on) {
			setprop("ja37/avionics/brightness-ti", 0);
			
			return;
		} else {
			setprop("ja37/avionics/brightness-ti", me.brightness);
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
		me.updateSVY();# must be before displayRadarTracks and showselfvector
		me.showSelfVector();
		me.displayRadarTracks();
		me.showRunway();
		me.menuUpdate();
		me.showTime();
		me.showFlightTime();
		me.showSteerPoints();
		me.showBottomText();# must be after displayRadarTracks and showsteerpoints
		me.showSteerPointInfo();
		me.showPoly();#must be under showSteerPoints
		me.showLVFF();
		me.showTargetInfo();
		me.updateMapNames();
		me.showBasesNear();
		me.ecmOverlay();
		me.gridOverlay();
		me.showBullsEye();
		
		me.twoHz = !me.twoHz;
		if (!me.battChargeReported and getprop("fdm/jsbsim/systems/electrical/battery-charge-norm") < 0.1) {
            FailureMgr._failmgr.logbuf.push("Warning: Battery charge less than 10%!");# dangerous, is private method!
            me.newFails = 1;
            me.battChargeReported = 1;
		} elsif (getprop("fdm/jsbsim/systems/electrical/battery-charge-norm") > 0.11) {
			me.battChargeReported = 0;
		}
	},

	loopFast: func {
		if (me.on != displays.common.mi_ti_on) {
			me.on = displays.common.mi_ti_on;
			me.active = me.on;
			# Reset state on restart
			if (me.on) me.restart();
		}
		if (!me.on) {
			return;
		}
		me.updateFlightData();
		me.showHeadingBug();
		me.testLanding();
		me.showCursor();
		me.edgeButtons();
		me.showRadarLimit();
		#me.rate = getprop("sim/frame-rate-worst");
		#me.rate = me.rate !=nil?clamp(1/(me.rate+0.001), 0.05, 0.5):0.5;
		#me.rate = 0.05;
	},

	loopSlow: func {
		if (!me.on) {
			#settimer(func me.loopSlow(), 0.05);
			return;
		}
		me.updateBasesNear();
	},

	restart: func {
		me.menuShowMain = FALSE;
		me.menuShowFast = FALSE;
		me.menuMain = -MAIN_SYSTEMS;
		me.menuNoSub();
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
					me.buffer = fire_control.fireLog;
					if (me.swedishMode)
						me.bufferStr = "       Registrerede avfyringar:\n";
					else
						me.bufferStr = "       Fire log:\n";
					me.drawLog = TRUE;
				} elsif (me.trapMan == TRUE) {
					me.buffer = me.logEvents;
					if (me.swedishMode)
						me.bufferStr = "       Manuella markeringar:\n";
					else
						me.bufferStr = "       Manual event log:\n";
					me.drawLog = TRUE;
				} elsif (me.trapLock == TRUE) {
					me.buffer = radar.lockLog;
					if (me.swedishMode)
						me.bufferStr = "       Registrerede inl\xC3\xA5sninger:\n";
					else
						me.bufferStr = "       Lock log:\n";
					me.drawLog = TRUE;
				} elsif (me.trapLand == TRUE) {
					me.buffer = me.logLand;
					if (me.swedishMode)
						me.bufferStr = "       Registrerede s\xC3\xA4ttningar:\n";
					else
						me.bufferStr = "       Landing log:\n";
					me.drawLog = TRUE;
				} elsif (me.trapECM == TRUE) {
					me.buffer = radar.ecmLog;
					if (me.swedishMode)
						me.bufferStr = "       Registrerede motmedelsf\xC3\xA4llninger:\n";
					else
						me.bufferStr = "       ECM log:\n";
					me.drawLog = TRUE;
				} elsif (me.trapAll == TRUE) {
					me.bufferContent = events.combineBuffers([radar.ecmLog.get_buffer(), me.logLand.get_buffer(), radar.lockLog.get_buffer(), me.logEvents.get_buffer(), fire_control.fireLog.get_buffer()]);
					if (me.swedishMode)
						me.bufferStr = "       Alla h\xC3\xA4ndelser:\n";
					else
						me.bufferStr = "       All logs:\n";
					me.drawLog = TRUE;
				}
				if (me.drawLog == TRUE) {
					me.hideMap();
					me.logRoot.show();
					call(func {
						if (me.trapAll == FALSE) {
							me.bufferContent = me.buffer.get_buffer();
						}
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
					me.str = "       F\xC3\xB6rvillelser:\n";
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
			me.count99 = pylons.get_ammo("RB-99");
			if (me.input.timeElapsed.getValue()-me.BITtime > me.count99*2+5) {
				me.BITon = FALSE;
				me.active = TRUE;
			} elsif (me.input.timeElapsed.getValue()-me.BITtime > 8 and me.BITok4 == FALSE) {
				if (me.count99 > 3)
					me.logBIT.push("RB-99: ....OK");
				me.BITok4 = TRUE;
			} elsif (me.input.timeElapsed.getValue()-me.BITtime > 6 and me.BITok3 == FALSE) {
				if (me.count99 > 2)
					me.logBIT.push("RB-99: ....OK");
				me.BITok3 = TRUE;
			} elsif (me.input.timeElapsed.getValue()-me.BITtime > 4 and me.BITok2 == FALSE) {
				if (me.count99 > 1)
					me.logBIT.push("RB-99: ....OK");
				me.BITok2 = TRUE;
			} elsif (me.input.timeElapsed.getValue()-me.BITtime > 2 and me.BITok1 == FALSE) {
				if (me.count99 > 0)
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

	pylon_to_main_button: {
		5: 8,
		1: 9,
		2: 10,
		4: 11,
		3: 12,
		6: 13,
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
			for(var i = MAIN_WEAPONS; i <= MAIN_CONFIGURATION; i+=1) {
				me.menuButtonBox[i].hide();
			}
			foreach(var pylon; fire_control.get_selected_pylons()) {
				if (contains(me.pylon_to_main_button, pylon)) {
					me.menuButtonBox[me.pylon_to_main_button[pylon]].show();
				}
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
		if (me.swedishMode) {
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
		if (me.menuMain == MAIN_WEAPONS and fire_control.selected == nil) {
			me.menuButtonBox[15].show();
		} elsif (me.menuMain == MAIN_WEAPONS and fire_control.selected.type == "M75") {
			me.menuButtonBox[14].show();
		}
		if (math.abs(me.menuMain) == MAIN_SYSTEMS) {
			if (me.menuTrap == FALSE) {
				if (me.input.wow1.getValue() == 0) {
					if (displays.common.ti_selection != nil) {
						me.menuButtonBox[1].show();
					}
					me.menuButton[1].setText(me.vertStr("RR"));
				}
				if (me.input.datalink.getBoolValue()) {
					me.menuButtonBox[2].show();
				}
				if (modes.nav_ja == modes.B or modes.nav_ja == modes.LA) {
					# is kind of a hack. It pretends that LÅ is a submode in S.
					me.menuButtonBox[4].show();
				}
				if (modes.nav_ja == modes.LA) {
					me.menuButtonBox[17].show();
				}
				if (modes.nav_ja == modes.LF) {
					me.menuButtonBox[18].show();
				}
				if (modes.nav_ja == modes.LB) {
					me.menuButtonBox[19].show();
				}
				if (modes.nav_ja == modes.L) {
					me.menuButtonBox[20].show();
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
				} elsif (me.trapAll == TRUE) {
					me.menuButtonBox[17].show();
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
		if (me.menuMain == MAIN_CONFIGURATION and me.menuGPS == TRUE and (getprop("ja37/avionics/gps-nav") == TRUE or ((getprop("ja37/avionics/gps-bit") or getprop("ja37/avionics/gps-init")) and me.twoHz))) {
			me.menuButtonBox[15].show();
		}
		if (me.menuMain == MAIN_WEAPONS) {
			if (displays.common.armActive() == nil) {
				me.menuButton[20].setText("");
			}
		}
	},

	compileFastMenu: func (button) {
		me.str = nil;
		if (me.swedishMode) {
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
		if (me.swedishMode) {
			me.seven = me.menuGPS==TRUE?"GPS":(me.menuTrap==TRUE?"TRAP":(me.menuSvy==TRUE?"SVY":(dictSE['0'][''~math.abs(me.menuMain)][1])));
		} else {
			me.seven = me.menuGPS==TRUE?"GPS":(me.menuTrap==TRUE?"TRAP":(me.menuSvy==TRUE?"SIDV":(dictEN['0'][''~math.abs(me.menuMain)][1])));
		}
		me.menuButtonSub[7].setText(me.vertStr(me.seven));
		if (me.menuMain == MAIN_WEAPONS) {
			me.aim9 = displays.common.armActive();
			if (me.aim9 != nil) {
				me.menuButtonSub[20].show();
				if (me.aim9.status == armament.MISSILE_STANDBY) {
					me.menuButtonSub[20].setText(me.vertStr("STBY"));
				} elsif (me.aim9.status == armament.MISSILE_STARTING) {
					me.menuButtonSub[20].setText(me.vertStr("STBY"));
					me.menuButtonSubBox[20].show();
				} elsif (me.aim9.status >= armament.MISSILE_SEARCH) {
					me.menuButtonSub[20].setText(me.vertStr("RDY"));
					me.menuButtonSubBox[20].show();
				}
			}
		}
		if (me.menuMain == MAIN_DISPLAY) {
			#show flight data
			me.menuButtonSub[17].show();
			me.menuButtonSubBox[17].show();
			me.seventeen = nil;
			if (me.swedishMode) {
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
			me.menuButtonSub[19].setText(me.vertStr(me.swedishMode?"NATT":"NGHT"));
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
			me.menuButtonSub[4].setText(me.vertStr(me.swedishMode?"TMAD":"AIRP"));
			me.menuButtonSub[4].show();
			if (me.basesEnabled == TRUE) {
				me.menuButtonSubBox[4].show();
			}

			# AAA from STRIL (not functional)
			me.menuButtonSub[14].setText(me.vertStr(me.swedishMode?"FI":"HSTL"));
			me.menuButtonSub[14].setVisible(me.showFullMenus);

			# own AAA points
			me.menuButtonSub[15].setText(me.vertStr(me.swedishMode?"EGET":"OWN"));
			me.menuButtonSub[15].show();
			if (me.showAAAZones == TRUE) {
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

			me.menuButtonSub[16].setText(me.vertStr(route.Polygon.flyRTB.getName()));
			me.menuButtonSub[16].show();
			if (route.Polygon.flyRTB == route.Polygon.primary) {
				me.menuButtonSubBox[16].show();
			}
		}
		if (me.menuMain == MAIN_MISSION_DATA) {
			if (route.Polygon.editBullsEye) {
				me.menuButtonSubBox[4].show();
			}
			me.menuButtonSub[4].setText(me.vertStr("BEYE"));
			me.menuButtonSub[4].show();

			me.isP = route.Polygon.editing != nil and route.Polygon.editing.type == route.TYPE_AREA;
			#hack:
			me.menuButtonSub[2].setText(me.vertStr(me.isP?"P":(me.swedishMode?"B":"S")));
			me.menuButtonSub[2].show();
			if (route.Polygon.insertSteer) {
				me.menuButtonSubBox[2].show();
			}
			me.menuButtonSub[3].setText(me.vertStr(me.isP?"P":(me.swedishMode?"B":"S")));
			me.menuButtonSub[3].show();
			if (route.Polygon.appendSteer) {
				me.menuButtonSubBox[3].show();
			}
			#me.menuButtonSub[5].setText(me.vertStr(me.isP?"P":(me.swedishMode?"B":"S")));
			#me.menuButtonSub[5].show();

			me.menuButtonSub[6].setText(me.vertStr("POLY"));
			me.menuButtonSub[6].show();
			if (route.Polygon.editing != nil and (route.Polygon.editing.type == route.TYPE_AREA)) {
				me.menuButtonSubBox[6].show();
			}

			######

			if (me.ownPositionDigital == 0) {
				me.menuButtonSub[19].show();
			} else {
				me.menuButtonSub[19].setText(str(me.ownPositionDigital));
				me.menuButtonSub[19].show();
				me.menuButtonSubBox[19].show();
			}
			me.menuButtonSub[18].setText(me.vertStr(me.isP?"P":(me.swedishMode?"B":"S")));
			me.menuButtonSub[18].show();
			if (route.Polygon.dragSteer) {
				me.menuButtonSubBox[18].show();
			}
			me.menuButtonSub[14].setText(me.vertStr(me.swedishMode?"\xC3\x85POL":"RPOL"));
			me.menuButtonSub[16].setText(me.vertStr(me.swedishMode?"UPOL":"MPOL"));
			me.menuButtonSub[15].setText(me.vertStr(route.Polygon.editRTB.getName()));
			me.menuButtonSub[17].setText(me.vertStr(route.Polygon.editMiss.getNameNumber()));
			me.menuButtonSub[17].show();
			me.menuButtonSub[15].show();
			if (route.Polygon.editing != nil and route.Polygon.editing.type == route.TYPE_MISS) {
				me.menuButtonSubBox[16].show();
			}
			if (route.Polygon.editing != nil and route.Polygon.editing.type == route.TYPE_RTB) {
				me.menuButtonSubBox[14].show();
			}
			me.menuButtonSub[14].show();
			me.menuButtonSub[16].show();
		}
		if (me.menuMain == MAIN_CONFIGURATION and me.menuGPS == FALSE and me.menuSvy == FALSE) {
			# use top or belly antaenna
			me.ant = nil;
			if (me.swedishMode) {
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
			me.menuButtonSub[5].setText(me.vertStr(str(me.SVYsize)));
			me.menuButtonSub[5].show();
			me.menuButtonSubBox[5].show();
			if (me.SVYinclude == SVY_ALL) {
				me.menuButtonSub[6].setText(me.vertStr(me.swedishMode?"ALLT":"ALL"));
			} elsif (me.SVYinclude == SVY_120) {
				me.menuButtonSub[6].setText(me.vertStr("120"));
			} else {
				me.menuButtonSub[6].setText(me.vertStr(me.swedishMode?"RR":"RR"));
			}
			me.menuButtonSub[6].show();
			me.menuButtonSubBox[6].show();

			me.skal = nil;
			if (me.swedishMode) {
				me.skal = me.SVYscale==SVY_ELKA?"ELKA":(me.SVYscale==SVY_MI?"MI":"RMAX");
			} else {
				me.skal = me.SVYscale==SVY_ELKA?"EMAP":(me.SVYscale==SVY_MI?"MI":"RMAX");
			}
			me.menuButtonSub[14].setText(me.vertStr(me.skal));
			me.menuButtonSub[14].show();
			me.menuButtonSubBox[14].show();
			if (me.swedishMode) {
				me.menuButtonSub[15].setText(me.vertStr(sprintf("%d", me.SVYrmaxSE[me.SVYrmax])));
				me.menuButtonSub[16].setText(me.vertStr(sprintf("%d", me.SVYhmaxSE[me.SVYhmax])));
			} else {
				me.menuButtonSub[15].setText(me.vertStr(sprintf("%d", me.SVYrmaxEN[me.SVYrmax])));
				me.menuButtonSub[16].setText(me.vertStr(sprintf("%d", me.SVYhmaxEN[me.SVYhmax])));
			}
			me.menuButtonSub[15].show();
			me.menuButtonSubBox[15].show();

			
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
		me.trapAll  = FALSE;
	},





	########################################################################################################
	########################################################################################################
	#
	#  functions called from MI display buttons
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
		# SFI del 1 flik 20 sida 17:
		# pos, speed, alt and course (same for any locks)
		#
		me.mreg = TRUE;
		me.mreg_time = getprop("sim/time/elapsed-sec");
		me.message = "";
		me.message = sprintf("Pilot entered event\n      Own speed: %.2f M\n      Own Heading: %d deg\n      Own Alt: %d ft\n      Own Lon: %s\n      Own Lat: %s\n",
			getprop("velocities/mach"),
			me.input.heading.getValue(),
			me.input.alt_ft.getValue(),
			ja37.convertDegreeToStringLon(me.input.longitude.getValue()),
			ja37.convertDegreeToStringLat(me.input.latitude.getValue()));

		if ((var tgt = radar.ps46.getPriorityTarget()) != nil and (var info = tgt.getLastBlep()) != nil) {
			if (info.hasTrackInfo()) {
				me.message = me.message ~ sprintf("      Radar tgt. spd: %d kt\n      Radar tgt. heading: %d deg\n",
					info.getSpeed(),
					info.getHeading()
				);
			}
			me.message = me.message ~ sprintf("      Radar tgt. alt: %d ft\n      Radar tgt. Lon: %s\n      Radar tgt. Lat: %s",
				info.getAltitude() + me.indicated_alt_offset_ft,
				ja37.convertDegreeToStringLon(info.getCoord().lon()),
				ja37.convertDegreeToStringLat(info.getCoord().lat())
			);
		}

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

	edgeButtons: func {
		me.lightNorm = me.input.instrNorm.getValue();
		me.elapsedTime = me.input.timeElapsed.getValue();
		for (me.i = 0; me.i <22;me.i+=1) {
			if (me.elapsedTime-edgeButtonsStruct[me.i]<0.30) {
				# todo: stop using setprop
				me.input.tiLight[me.i].setDoubleValue(0.75);
			} else {
				me.input.tiLight[me.i].setDoubleValue(me.lightNorm);
			}
		}
	},

	########################################################################################################
	########################################################################################################
	#
	#  misc overlays
	#
	#
	########################################################################################################
	########################################################################################################
	
	
	gridOverlay: func {
		#line finding algorithm taken from $fgdata mapstructure:
		var lines = [];
		if (me.menuMain != MAIN_MISSION_DATA) {
			me.gridGroup.hide();
			me.gridGroupText.hide();
			return;
		}
		if (zoomLevels[zoom_curr] == 3.2) {
			me.gridGroup.hide();
			me.gridGroupText.hide();
			return;
		} elsif (zoomLevels[zoom_curr] == 1.6) {
			me.granularity_lon = 2;
			me.granularity_lat = 2;
		} elsif (zoomLevels[zoom_curr] == 800) {
			me.granularity_lon = 1;
			me.granularity_lat = 1;
		} elsif (zoomLevels[zoom_curr] == 400) {
			me.granularity_lon = 0.5;
			me.granularity_lat = 0.5;
		} elsif (zoomLevels[zoom_curr] == 200) {
			me.granularity_lon = 0.25;
			me.granularity_lat = 0.25;
		}
		
		var delta_lon = me.granularity_lon;
		var delta_lat = me.granularity_lat;

		# Find the nearest lat/lon line to the map position.  If we were just displaying
		# integer lat/lon lines, this would just be rounding.
		
		var lat = delta_lat * math.round(me.lat / delta_lat);
	  	var lon = delta_lon * math.round(me.lon / delta_lon);
	  	
		var range = 0.75*height*M2NM/M2TEX;#simplified
		#printf("grid range=%d %.3f %.3f",range,me.lat,me.lon);

		# Return early if no significant change in lat/lon/range - implies no additional
		# grid lines required
		if ((lat == me.last_lat) and (lon == me.last_lon) and (range == me.last_range)) {
			lines = me.last_result;
		} else {

			# Determine number of degrees of lat/lon we need to display based on range
			# 60nm = 1 degree latitude, degree range for longitude is dependent on latitude.
			var lon_range = 1;
			call(func{lon_range = geo.Coord.new().set_latlon(lat,lon,me.input.alt_ft.getValue()*FT2M).apply_course_distance(90.0, range*NM2M).lon() - lon;},nil, var err=[]);
			#courseAndDistance
			if (size(err)) {
				#printf("fail lon %.7f  lat %.7f  ft %.2f  ft %.2f",lon,lat,me.input.alt_ft.getValue(),range*NM2M);
				# typically this fail close to poles. Floating point exception in geo asin.
			}
			var lat_range = range/60.0;

			lon_range = delta_lon * math.ceil(lon_range / delta_lon);
			lat_range = delta_lat * math.ceil(lat_range / delta_lat);

			lon_range = clamp(lon_range,delta_lon,250);
			lat_range = clamp(lat_range,delta_lat,250);
			
			#printf("range lon %f  lat %f",lon_range,lat_range);
			for (var x = (lon - lon_range); x <= (lon + lon_range); x += delta_lon) {
				var coords = [];
				if (x>180) {
				#	x-=360;
					continue;
				} elsif (x<-180) {
				#	x+=360;
					continue;
				}
				# We could do a simple line from start to finish, but depending on projection,
				# the line may not be straight.
				for (var y = (lat - lat_range); y <= (lat + lat_range); y +=  delta_lat) {
					append(coords, {lon:x, lat:y});
				}
				var ddLon = math.round(math.fmod(abs(x), 1.0) * 60.0);
				append(lines, {
					id: x,
					type: "lon",
					text1: sprintf("%4d",int(x)),
					text2: ddLon==0?"":ddLon~"",
					path: coords,
					equals: func(o){
						return (me.id == o.id and me.type == o.type); # We only display one line of each lat/lon
					}
				});
			}
			
			# Lines of latitude
			for (var y = (lat - lat_range); y <= (lat + lat_range); y += delta_lat) {
				var coords = [];
				if (y>90 or y<-90) continue;
				# We could do a simple line from start to finish, but depending on projection,
				# the line may not be straight.
				for (var x = (lon - lon_range); x <= (lon + lon_range); x += delta_lon) {
					append(coords, {lon:x, lat:y});
				}

				var ddLat = math.round(math.fmod(abs(y), 1.0) * 60.0);
				append(lines, {
					id: y,
					type: "lat",
					text: str(int(y))~(ddLat==0?"   ":" "~ddLat),
					path: coords,
					equals: func(o){
						return (me.id == o.id and me.type == o.type); # We only display one line of each lat/lon
					}
				});
			}
#printf("range %d  lines %d",range, size(lines));
		}
		me.last_result = lines;
		me.last_lat = lat;
		me.last_lon = lon;
		me.last_range = range;
		
		
		me.gridGroup.removeAllChildren();
		#me.gridGroupText.removeAllChildren();
		me.gridTextNoA = 0;
		me.gridTextNoO = 0;
		me.gridH = height*0.80;
		foreach (var line;lines) {
			var skip = 1;
			me.posi1 = [];
			foreach (var coord;line.path) {
				if (!skip) {
					me.posi2 = me.laloToTexelMap(coord.lat,coord.lon);
					me.aline.lineTo(me.posi2);
					if (line.type=="lon") {
						var arrow = [(me.posi1[0]*4+me.posi2[0])/5,(me.posi1[1]*4+me.posi2[1])/5];
						me.aline.moveTo(arrow);
						me.aline.lineTo(arrow[0]-7,arrow[1]+10);
						me.aline.moveTo(arrow);
						me.aline.lineTo(arrow[0]+7,arrow[1]+10);
						me.aline.moveTo(me.posi2);
						if (me.posi2[0]<me.gridH and me.posi2[0]>-me.gridH and me.posi2[1]<me.gridH and me.posi2[1]>-me.gridH) {
							# sadly when zoomed in alot it draws too many crossings, this condition should help
							me.setGridTextO(line.text1,[me.posi2[0]-20,me.posi2[1]+5]);
					    	if (line.text2 != "") {
					    		me.setGridTextO(line.text2,[me.posi2[0]+12,me.posi2[1]+5]);
						    }
						}
					} else {
						me.posi3 = [(me.posi1[0]+me.posi2[0])*0.5, (me.posi1[1]+me.posi2[1])*0.5-5];
						if (me.posi3[0]<me.gridH and me.posi3[0]>-me.gridH and me.posi3[1]<me.gridH and me.posi3[1]>-me.gridH) {
							# sadly when zoomed in alot it draws too many crossings, this condition should help
							me.setGridTextA(line.text,me.posi3);
						}
					}
					me.posi1=me.posi2;
				} else {
					me.posi1 = me.laloToTexelMap(coord.lat,coord.lon);
					me.aline = me.gridGroup.createChild("path")
						.moveTo(me.posi1)
						.setStrokeLineWidth(w)
						.setColor(COLOR_BLUE_LIGHT);
				}
				skip = 0;
			}
		}
		for (me.jjjj = me.gridTextNoO;me.jjjj<=me.gridTextMaxO;me.jjjj+=1) {
			me.gridTextO[me.jjjj].hide();
		}
		for (me.kkkk = me.gridTextNoA;me.kkkk<=me.gridTextMaxA;me.kkkk+=1) {
			me.gridTextA[me.kkkk].hide();
		}
		me.gridGroupText.update();
		me.gridGroup.update();
		me.gridGroupText.show();
		me.gridGroup.show();
	},
	
	setGridTextO: func (text, pos) {
		if (me.gridTextNoO > me.gridTextMaxO) {
				append(me.gridTextO,me.gridGroupText.createChild("text")
    					.setText(text)
			    		.setColor(COLOR_BLUE_LIGHT)
			    		.setAlignment("center-top")
			    		.setTranslation(pos)
			    		.setFontSize(14, 1));
			me.gridTextMaxO += 1;	
		} else {
			me.gridTextO[me.gridTextNoO].setText(text).setTranslation(pos);
		}
		me.gridTextO[me.gridTextNoO].show();
		me.gridTextNoO += 1;
	},
	
	setGridTextA: func (text, pos) {
		if (me.gridTextNoA > me.gridTextMaxA) {
				append(me.gridTextA,me.gridGroupText.createChild("text")
    					.setText(text)
			    		.setColor(COLOR_BLUE_LIGHT)
			    		.setAlignment("center-bottom")
			    		.setTranslation(pos)
			    		.setFontSize(14, 1));
			me.gridTextMaxA += 1;	
		} else {
			me.gridTextA[me.gridTextNoA].setText(text).setTranslation(pos);
		}
		me.gridTextA[me.gridTextNoA].show();
		me.gridTextNoA += 1;
	},

	isCursorOnMap: func {
		if (me.cursorGPosY < height*0.9-height*0.025*me.upText) {
			# the cursor is above bottom text field
			if (me.cursorGPosY > me.SVYoriginY*me.SVYactive*(me.menuMain != MAIN_MISSION_DATA)) {
				# the cursor is below SVY field
				return TRUE;
			}
		}
		return FALSE;
	},

	isCursorOnSVY: func {
		if (me.cursorGPosY < me.SVYoriginY*me.SVYactive) {
			# the cursor is in SVY field
			return TRUE;
		}
		return FALSE;
	},
	
	setupMMAP: func {
		# center cursor in display
		me.cursorPosX = 0;
		me.cursorPosY = (-me.rootCenterY+height-me.rootCenterY)*0.5;
		displays.common.setCursorDisplay(displays.TI);
	},

	showCursor: func {
		# this function is called more often than regular overlays
		if (displays.common.cursor == displays.TI) {
			# Retrieve cursor movement from JSBSim
			me.cursorMov = displays.common.getCursorDelta();
			displays.common.resetCursorDelta();
			#  2.5 seconds to cover the screen (bottom to top)
			me.cursorMoveX = me.cursorMov[0] * height * 0.4;
			me.cursorMoveY = me.cursorMov[1] * height * 0.4;
			if (me.dragMapEnabled) {
				me.newMapPos = me.TexelToLaLoMap(me.cursorMoveX, me.cursorMoveY);
				me.lat = me.newMapPos[0];
				me.lon = me.newMapPos[1];
			} else {
				me.cursorPosX  += me.cursorMoveX;
				me.cursorPosY  += me.cursorMoveY;
			}
			me.cursorPosX   = clamp(me.cursorPosX, -width*0.5,  width*0.5);
			me.cursorPosY   = clamp(me.cursorPosY, -me.rootCenterY, height-me.rootCenterY);#relative to map center
			me.cursorGPosX = me.cursorPosX + width*0.5;
			me.cursorGPosY = me.cursorPosY + me.rootCenterY;# relative to canvas
			me.cursorOPosX = me.cursorPosX + me.tempReal[0];
			me.cursorOPosY = me.cursorPosY + me.tempReal[1];# relative to rootCenter
			#me.cursorRPosX = me.cursorPosX + me.rootCenterTranslation[0];
			#me.cursorRPosY = me.cursorPosY + me.rootCenterTranslation[1];# relative to own position
			me.cursor.setTranslation(me.cursorGPosX,me.cursorGPosY);
			me.cursorTrigger = me.cursorMov[2];
			if (me.lvffDrag == nil and me.sDrag == nil) {
				me.cursorDidSomething = FALSE;
			} else {
				me.cursorDidSomething = TRUE;
			}
			#printf("(%d,%d) %d",me.cursorPosX,me.cursorPosY, me.cursorTrigger);
			if (route.Polygon.editBullsEye) {
				if(me.cursorTrigger and !me.cursorTriggerPrev) {
					me.newSteerPos = me.TexelToLaLoMap(me.cursorPosX, me.cursorPosY);
					me.input.bullseyeOn.setBoolValue(TRUE);
					me.input.bullseyeLat.setDoubleValue(me.newSteerPos[0]);
					me.input.bullseyeLon.setDoubleValue(me.newSteerPos[1]);
					dap.checkLVSave();
					me.cursorDidSomething = TRUE;
				}
			} elsif (me.sDrag != nil) {
				#logprint(LOG_DEBUG, "dragging steerpoint: "~geo.format(me.newSteerPos[0],me.newSteerPos[1]));
				if(me.cursorTrigger) {
					# drag the steer to new place
					me.newSteerPos = me.TexelToLaLoMap(me.cursorPosX, me.cursorPosY);
					route.Polygon.editApply(me.newSteerPos[0],me.newSteerPos[1]);
					me.cursorDidSomething = TRUE;
				} elsif (!me.cursorTrigger and me.cursorTriggerPrev) {
					# finished dragging a steer
					route.Polygon.editFinish();
					me.sDrag = nil;
					me.cursorDidSomething = TRUE;
				}
			} elsif (route.Polygon.insertSteer) {
				if(me.cursorTrigger and !me.cursorTriggerPrev) {
					me.newSteerPos = me.TexelToLaLoMap(me.cursorPosX, me.cursorPosY);
					route.Polygon.insertApply(me.newSteerPos[0],me.newSteerPos[1]);
					me.cursorDidSomething = TRUE;
				}
				#me.newSteerPos = nil;
			} elsif (route.Polygon.appendSteer) {
				if(me.cursorTrigger and !me.cursorTriggerPrev) {#if this is nested condition then only this can be done. Is this what we want?
					me.newSteerPos = me.TexelToLaLoMap(me.cursorPosX, me.cursorPosY);
					route.Polygon.appendApply(me.newSteerPos[0],me.newSteerPos[1]);
					me.cursorDidSomething = TRUE;
				}
				#me.newSteerPos = nil;
			} elsif (me.cursorTrigger and !me.cursorTriggerPrev) {
				# click on edge buttons
				me.newSteerPos = nil;
				me.bMethod = me.getButtonMethod();
				if (me.bMethod != nil) {
					me.bMethod();
					me.cursorDidSomething = TRUE;
				}
			}
			me.cursor.show();
			me.MI_cursor.hide();
		} else {
			#me.cursorIsClicking = FALSE;
			me.cursorTrigger = FALSE;
			me.newSteerPos = nil;
			me.cursor.hide();

			if (MI.mi.cursor_shown) {
				me.texelDistance = MI.mi.cursor_range * M2TEX;
				me.angle = MI.mi.cursor_azi * D2R;
				me.pos_xx = me.texelDistance * math.sin(me.angle);
				me.pos_yy = -me.texelDistance * math.cos(me.angle);
				me.MI_cursor.setTranslation(me.pos_xx, me.pos_yy);
				me.MI_cursor.show();
			} else {
				me.MI_cursor.hide();
			}
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
		} elsif (me.wpTextField.getVisible() and me.cursorGPosY > me.wpStarty-me.wpH*height and me.cursorGPosY < me.wpStarty and me.cursorGPosX < me.wpStartx+me.wpW*width and me.cursorGPosX > me.wpStartx) {
			# possible infoBox click
			if      (me.cursorGPosY < me.wpStarty-0.8*me.wpH*height and (me.wpText2.getVisible() or me.blinkBox2)) {
				return me.box2;
			} elsif (me.cursorGPosY < me.wpStarty-0.6*me.wpH*height and (me.wpText3.getVisible() or me.blinkBox3)) {
				return me.box3;
			} elsif (me.cursorGPosY < me.wpStarty-0.4*me.wpH*height and (me.wpText4.getVisible() or me.blinkBox4)) {
				return me.box4;
			} elsif (me.cursorGPosY < me.wpStarty-0.2*me.wpH*height and (me.wpText5.getVisible() or me.blinkBox5)) {
				return me.box5;
			} elsif (me.cursorGPosY < me.wpStarty-0.0*me.wpH*height and (me.wpText6.getVisible() or me.blinkBox6)) {#  wont work if blinking
				return me.box6;
			}
		}
		return nil;
	},

	isDAPActive: func {
		return me.blinkBox2 or me.blinkBox3 or me.blinkBox4 or me.blinkBox5 or me.blinkBox6;
	},

	stopDAP: func {
		me.blinkBox2 = FALSE;
		me.blinkBox3 = FALSE;
		me.blinkBox4 = FALSE;
		me.blinkBox5 = FALSE;
		me.blinkBox6 = FALSE;
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
				me.blinkBox4 = TRUE;
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
				me.blinkBox5 = TRUE;
			}
		}
	},

	box6: func {
		if (me.isDAPActive() and me.blinkBox6 != TRUE) {
			# stop another field edit
			me.stopDAP();
		}
		if (me.isDAPActive()) {
			# cancel this field edit
			me.stopDAP();
		} elsif (!me.isDAPActive() and me.menuMain == MAIN_MISSION_DATA) {
			if (route.Polygon.editing != nil and route.Polygon.selectSteer != nil and route.Polygon.editing.type != route.TYPE_AREA) {
				#route.Polygon.editDetailMethod(TRUE);
				dap.set237(TRUE, 1, me.dapType);
				me.blinkBox6 = TRUE;
			}
		}
	},

	dapBLo: func (input, sign, myself) {
		#
		if (input == nil) {
			dap.setError();
			return;
		}
		sign = sign>0?"":"-";
		var deg = ja37.stringToLon(sign~input);
		logprint(LOG_DEBUG, "TI recieved LO from DAP: "~sign~input);
		if (deg!=nil) {
			logprint(LOG_DEBUG, "converted "~sign~input~" to "~ja37.convertDegreeToStringLon(deg));
			route.Polygon.setLon(deg);
			myself.stopDAP();
		} else {
			dap.setError();
		}
	},

	dapBLa: func (input, sign, myself) {
		#
		if (input == nil) {
			dap.setError();
			return;
		}
		sign = sign>0?"":"-";
		var deg = ja37.stringToLat(sign~input);
		logprint(LOG_DEBUG, "TI recieved LA from DAP: "~sign~input);
		if (deg!=nil) {
			logprint(LOG_DEBUG, "converted "~sign~input~" to "~ja37.convertDegreeToStringLat(deg));
			route.Polygon.setLat(deg);
			myself.stopDAP();
		} else {
			dap.setError();
		}
	},

	dapA: func (input, sign, myself) {
		#
		if (input == nil or input == 0 or input > 6 or sign < 0) {
			dap.setError();
		} else {
			route.Polygon.editPlan(route.Polygon.polys["OP"~input]);
			logprint(LOG_DEBUG, "TI recieved area number from DAP: "~input);
			myself.stopDAP();
		}
	},

	dapBspeed: func (input, sign, myself) {
		#
		if (sign < 0) {
			dap.setError();
		} else {
			if (input != nil) {
				var mach = num(input)/100;
				logprint(LOG_DEBUG, "TI recieved mach from DAP: M"~mach);
				route.Polygon.setMach(mach);
			} else {
				logprint(LOG_DEBUG, "TI recieved no mach from DAP.");
				route.Polygon.setMach(nil);
			}
			myself.stopDAP();
		}
	},

	dapType: func (input, sign, myself) {
		#
		if (input == nil) {
			dap.setError();
			return;
		}
		var typ = num(input);
		if (sign < 0 or typ > 1) {
			dap.setError();
		} else {
			logprint(LOG_DEBUG, "TI recieved steerpoint type from DAP: "~typ);
			route.Polygon.setType(typ);
			myself.stopDAP();
		}
	},

	dapBalt: func (input, sign, myself) {
		#
		if (sign < 0) {
			dap.setError();
		} else {
			if (input != nil) {
				var alt = num(input);
				logprint(LOG_DEBUG, "TI recieved alt from DAP: "~alt);
				route.Polygon.setAlt(myself.swedishMode?alt*M2FT:alt);#important!!! running in metric will input metric also!
			} else {
				logprint(LOG_DEBUG, "TI recieved no alt from DAP");
				route.Polygon.setAlt(nil);#important!!! running in metric will input metric also!
			}
			myself.stopDAP();
		}
	},

	ecmOverlay: func {
		if (me.ECMon == TRUE) {
			for (var i=0; i<12; i+=1) {
				if(rwr.ja_rwr_sectors[i] == 2) me.ecm[i].setColor(COLOR_RED);
				elsif(rwr.ja_rwr_sectors[i] == 1) me.ecm[i].setColor(COLOR_YELLOW);
				else me.ecm[i].setColor(COLOR_GREEN_DARK);
			}
			me.ecm_grp.show();
		} else {
			me.ecm_grp.hide();
		}
	},

	testLanding: func {
		me.wow = me.input.wow0.getValue() and me.input.wow1.getValue() and me.input.wow2.getValue();
		if (me.landed == FALSE and me.wow == TRUE) {
			me.logLand.push("Has landed.");
			me.landed = TRUE;
		} elsif (me.wow == FALSE) {
			me.landed = FALSE;
		}
	},

	updateSVY: func {
		# update and display side view
		if (me.SVYactive == TRUE and me.menuMain != MAIN_MISSION_DATA) {#TODO: Find out if SVY really WAS shown in MSDA menu..
			me.svy_grp2.removeAllChildren();

			me.SVYoriginX = width*0.05;#texel
			me.SVYoriginY = height*0.125+height*0.125*me.SVYsize-height*0.05;#texel
			me.SVYwidth   = width*0.90;#texel
			me.SVYheight  = height*0.125+height*0.125*me.SVYsize-height*0.10;#texel
			me.SVYalt     = me.swedishMode?me.SVYhmaxSE[me.SVYhmax]*1000:me.SVYhmaxEN[me.SVYhmax]*1000*FT2M;#meter
			me.SVYrange   = me.SVYscale==SVY_MI?radar.ps46.getRangeM():(me.SVYscale==SVY_RMAX?(me.swedishMode?me.SVYrmaxSE[me.SVYrmax]*1000:me.SVYrmaxEN[me.SVYrmax]*NM2M):me.SVYwidth/M2TEX);#meter
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
				.setColor(COLOR_WHITE);

			me.selfSvyPos = [me.SVYoriginX, me.SVYoriginY - me.SVYheight*me.input.alt_ft.getValue()*FT2M/me.SVYalt];
			me.selfGroupSvy.setTranslation(me.selfSvyPos);

			me.textX = "";
			me.textY = "";

			if (me.swedishMode) {
				me.textX = sprintf("%d KM" ,me.SVYscale==SVY_MI?radar.ps46.getRangeM()*0.001:(me.SVYscale==SVY_RMAX?me.SVYrmaxSE[me.SVYrmax]:0.001*me.SVYwidth/M2TEX));
				me.textY = sprintf("%d KM" ,me.SVYhmaxSE[me.SVYhmax]);
			} else {
				me.textX = sprintf("%d NM" ,me.SVYscale==SVY_MI?radar.ps46.getRangeM()*M2NM:(me.SVYscale==SVY_RMAX?me.SVYrmaxEN[me.SVYrmax]:M2NM*me.SVYwidth/M2TEX));
				me.textY = sprintf("%d kFT" ,me.SVYhmaxEN[me.SVYhmax]);
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
		# this function is run in a very slow loop as its very expensive
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
				if (base["icao"] != navigation.icao) {
					me.coord = geo.Coord.new();
					me.coord.set_latlon(base["lat"], base["lon"], base["elev"]);
					me.distance = me.ac_pos.distance_to(me.coord);
					if (me.distance < height/M2TEX) {
			    		me.baseIcao = base["icao"];
			    		if (size(me.baseIcao) != nil and me.baseIcao != "") {
				    		me.small = base["small"];
							me.xa_rad = (me.ac_pos.course_to(me.coord) - me.ind_head_true) * D2R;
				      		me.pixelDistance = -me.distance*M2TEX; #distance in pixels
				      		#translate from polar coords to cartesian coords
				      		me.pixelX =  me.pixelDistance * math.cos(me.xa_rad + math.pi/2);
				      		me.pixelY =  me.pixelDistance * math.sin(me.xa_rad + math.pi/2);
				      		if (me.small == TRUE) {
					      		if (me.numS < maxBases) {
					      			me.baseSmall[me.numS].setTranslation(me.pixelX, me.pixelY);
					      			me.baseSmallText[me.numS].setTranslation(me.pixelX, me.pixelY);
					      			me.baseSmallText[me.numS].setText(me.baseIcao);
					      			me.baseSmallText[me.numS].setRotation(-me.input.heading.getValue()*D2R);
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
					      			me.baseLargeText[me.numL].setRotation(-me.input.heading.getValue()*D2R);
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
			if (me.swedishMode) {
				if (zoom == 4) {
					tick1 = 800;
				} elsif (zoom == 5) {
					tick1 = 400;
				} elsif (zoom == 6) {
					tick1 = 200;
				} elsif (zoom == 7) {
					tick1 = 100;
				} elsif (zoom == 8) {
					tick1 = 50;
				} elsif (zoom == 9) {
					tick1 = 25;
				} elsif (zoom == 10) {
					tick1 = 12.5;
				} elsif (zoom == 11) {
					tick1 = 6;
				} elsif (zoom == 13) {
					tick1 = 1;
				}
				tick2 = tick1*2;
				tick3 = tick1*3;
				me.mapScaleTick1.setTranslation(0, -tick1*M2TEX*1000);
				me.mapScaleTick1Txt.setTranslation(me.mapScaleTickPosTxtX, -tick1*M2TEX*1000);
				me.mapScaleTick2.setTranslation(0, -tick2*M2TEX*1000);
				me.mapScaleTick2Txt.setTranslation(me.mapScaleTickPosTxtX, -tick2*M2TEX*1000);
				me.mapScaleTick3.setTranslation(0, -tick3*M2TEX*1000);
				me.mapScaleTick3Txt.setTranslation(me.mapScaleTickPosTxtX, -tick3*M2TEX*1000);
				me.mapScaleTick1Txt.setText(str(tick1));
				me.mapScaleTick2Txt.setText(str(tick2));
				me.mapScaleTick3Txt.setText(str(tick3));
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
					tick1 = 400;
				} elsif (zoom == 5) {#using 5-9
					tick1 =  200;
				} elsif (zoom == 6) {
					tick1 =  100;
				} elsif (zoom == 7) {
					tick1 =  50;
				} elsif (zoom == 8) {
					tick1 =  25;
				} elsif (zoom == 9) {
					tick1 =  15;
				} elsif (zoom == 10) {
					tick1 =  7.5;
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
				me.mapScaleTick1Txt.setText(str(tick1));
				me.mapScaleTick2Txt.setText(str(tick2));
				me.mapScaleTick3Txt.setText(str(tick3));
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
		# this is a little infobox about the locked target.
		if (!me.mapshowing
			or (var tgt = radar.ps46.getPriorityTarget()) == nil
			or (var info = tgt.getLastBlep()) == nil
			or !info.hasTrackInfo())
		{
			me.tgtTextField.hide();
			return;
		}

		me.tgt_dist = info.getRangeNow();
		if (me.tgt_dist != nil) {
			# distance
			if (me.swedishMode) {
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

		me.tgt_alt = info.getAltitude();
		if (me.tgt_alt != nil) {
			# altitude
			me.tgt_alt += me.indicated_alt_offset_ft;
			me.tgt_alt = math.max(me.tgt_alt, 0);
			me.text = "";
			if (me.swedishMode) {
				me.tgt_alt *= FT2M;
				me.tgtTextHeiDesc.setText("H");
				if(me.tgt_alt < 1000) {
					me.text = str(math.round(me.tgt_alt, 10));
				} else {
					me.text = sprintf("%.1f", me.tgt_alt/1000);
				}
			} else {
				me.tgtTextHeiDesc.setText("A");
				if(me.tgt_alt < 1000) {
					me.text = str(math.round(me.tgt_alt, 10));
				} else {
					me.text = sprintf("%.1f", me.tgt_alt/1000);
				}
			}
			me.tgtTextHei.setText(me.text);
		} else {
			me.tgtTextHei.setText("");
		}

		me.tgt_speed = info.getSpeed();
		me.tgt_alt = info.getAltitude();
		if (me.tgt_speed != nil and me.tgt_alt != nil) {
			# speed
			me.rs = armament.AIM.rho_sndspeed(me.tgt_alt);
			me.sound_fps = me.rs[1];
			me.speed_m = me.tgt_speed * KT2FPS / me.sound_fps;
			me.tgtTextSpd.setText(sprintf("%.2f", me.speed_m));
		} else {
			me.tgtTextSpd.setText("");
		}

		me.tgtTextField.show();
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
			me.wpText2.setText(getprop("ja37/avionics/gps-nav")?ja37.convertDegreeToStringLon(me.input.longitude.getValue()):"000 00 00");

			me.wpText3Desc.setText("LAT");
			me.wpText3.setText(getprop("ja37/avionics/gps-nav")?ja37.convertDegreeToStringLat(me.input.latitude.getValue()):"00 00 00");

			me.wpText2.setFontSize(13, 1.0);
			me.wpText3.setFontSize(13, 1.0);

			me.wpText4Desc.setText("FOM");#figure of merit
			me.wpText4.setText(getprop("ja37/avionics/gps-nav")?"1":"");

			me.wpText5Desc.setText("MOD");# mode
			me.gps5 = "";
			if (getprop("ja37/navigation/gps-installed")) {
				if (getprop("ja37/avionics/gps-nav")) {
					me.gps5 = "NAV";
				} elsif (getprop("ja37/avionics/gps-bit")) {
					me.gps5 = "BIT";
				} elsif (getprop("ja37/avionics/gps-init")) {
					me.gps5 = "INIT";
				}
			}
			me.wpText5.setText(me.gps5);

			me.wpText6Desc.setText(me.swedishMode?"FEL":"ERR");# error
			me.wpText6.setText(getprop("ja37/navigation/gps-installed")?(getprop("fdm/jsbsim/systems/electrical/battery-charge-norm")<0.1?"BATT":""):"FPLDATA");#TODO: Don't know what the real error would look like in FPLDATA case.

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
				if (me.blinkBox2 == FALSE or me.twoHz) {
					me.wpText2.show();
				} else {
					me.wpText2.hide();
				}
				me.wpText2.update();

				me.wpText3Desc.setText("LAT");
				me.wpText3.setText(ja37.convertDegreeToStringLat(route.Polygon.selectSteer[0].wp_lat));
				me.wpText3.setFontSize(13, 1.0);
				if (me.blinkBox3 == FALSE or me.twoHz) {
					me.wpText3.show();
				} else {
					me.wpText3.hide();
				}
				me.wpText3.update();

				me.constraint_alt = "-----";
				if (route.Polygon.selectSteer[0].alt_cstr != nil and route.Polygon.selectSteer[0].alt_cstr_type == "at" and route.Polygon.selectSteer[0].alt_cstr>-5000) {#Fg has habit of defaulting it to -9999
					me.constraint_alt = sprintf("%5d",me.swedishMode?FT2M*route.Polygon.selectSteer[0].alt_cstr:route.Polygon.selectSteer[0].alt_cstr);
				}
				me.wpText4Desc.setText(me.swedishMode?"H":"A");
				me.wpText4.setText(me.constraint_alt);
				if (me.blinkBox4 == FALSE or me.twoHz) {
					me.wpText4.show();
				} else {
					me.wpText4.hide();
				}
				me.wpText4.update();

				me.constraint_speed = "-.--";
				if (route.Polygon.selectSteer[0].speed_cstr != nil and (route.Polygon.selectSteer[0].speed_cstr_type == "mach" or route.Polygon.selectSteer[0].speed_cstr_type == "computed-mach")) {
					me.constraint_speed = sprintf("%0.2f",route.Polygon.selectSteer[0].speed_cstr);
				}
				me.wpText5Desc.setText(me.swedishMode?"M":"M");
				me.wpText5.setText(me.constraint_speed);
				if (me.blinkBox5 == FALSE or me.twoHz) {
					me.wpText5.show();
				} else {
					me.wpText5.hide();
				}
				me.wpText5.update();

				#me.of = me.swedishMode?" AV ":" OF ";
				#me.wpText6Desc.setText(me.swedishMode?"B":"S");
				#me.wpText6.setText((1+route.Polygon.selectSteer[1])~me.of~route.Polygon.editing.getSize());

				me.wpText6Desc.setText("TYP");
				# Hold = target
				me.wpText6.setText(route.Polygon.selectSteer[0].fly_type=="flyOver"?(me.swedishMode?"M\xC3\x85L":"TARGET"):(me.swedishMode?"BRYT":"STEER"));
				if (me.blinkBox6 == FALSE or me.twoHz) {
					me.wpText6.show();
				} else {
					me.wpText6.hide();
				}
				me.wpText6Desc.show();

				me.wpTextField.update();
				me.wpTextField.show();
			} elsif (route.Polygon.editing != nil) {
				# info about selected area point
				me.wpText2.setFontSize(15, 1);
				me.wpText3.setFontSize(15, 1);
				me.wpText3.show();

				me.wpText2Desc.setText("POL");
				me.wpText2.setText(route.Polygon.editing.getName());
				if (me.blinkBox2 == FALSE or me.twoHz) {
					me.wpText2.show();
				} else {
					me.wpText2.hide();
				}

				me.of = me.swedishMode?" AV ":" OF ";
				me.wpText3Desc.setText(route.Polygon.selectSteer != nil?(me.swedishMode?"PKT":"PNT"):"");
				me.wpText3.setText(route.Polygon.selectSteer != nil?((1+route.Polygon.selectSteer[1])~me.of~route.Polygon.editing.getSize()):"");

				me.wpText4Desc.setText(route.Polygon.selectSteer != nil?"LON":"");
				me.wpText4.setText(route.Polygon.selectSteer != nil?ja37.convertDegreeToStringLon(route.Polygon.selectSteer[0].wp_lon):"");
				me.wpText4.setFontSize(13, 1.0);
				if (me.blinkBox4 == FALSE or me.twoHz) {
					me.wpText4.show();
				} else {
					me.wpText4.hide();
				}

				me.wpText5Desc.setText(route.Polygon.selectSteer != nil?"LAT":"");
				me.wpText5.setText(route.Polygon.selectSteer != nil?ja37.convertDegreeToStringLat(route.Polygon.selectSteer[0].wp_lat):"");
				me.wpText5.setFontSize(13, 1.0);
				if (me.blinkBox5 == FALSE or me.twoHz) {
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
			if (me.mapshowing == TRUE and getprop("autopilot/route-manager/active") == TRUE and me.wp != -1 and me.wp != nil and me.showSteers == TRUE and displays.common.ti_selection == nil) {
				# steerpoints ON and route active, plus not being in radar steer order mode.
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
				me.legText = (me.legs==0 or me.wpNum == 1)?"":(me.wpNum-1)~(me.swedishMode?" AV ":" OF ")~me.legs;

				me.wpAlt  = me.node.getNode("altitude-ft");
				if (me.wpAlt != nil) {
					me.wpAlt = me.wpAlt.getValue();
				}
				if (me.wpAlt == nil) {
					me.wpAlt = "-----";
				} elsif (me.wpAlt < -5000) {
					# FG has habit of setting default to -9999 ft
					me.wpAlt = "-----";
				} else {
					# bad coding, shame on me..
					me.wpAlt  = me.swedishMode?me.wpAlt*FT2M:me.wpAlt;
					me.wpAlt = sprintf("%d", me.wpAlt);
				}

				me.wpSpeed= me.node.getNode("speed-mach");
				if (me.wpSpeed != nil) {
					me.wpSpeed = me.wpSpeed.getValue();
					#if (me.wpSpeed != nil and math.abs(me.wpSpeed) > 9.9 or me.wpSpeed < 0) {
					#	me.wpSpeed = nil;
					#}
				}
				if (me.wpSpeed == nil) {
					me.wpSpeed = "-.--";
				} else {
					me.wpSpeed = sprintf("%0.2f", me.wpSpeed);
				}

				me.wpETA  = math.ceil(getprop("autopilot/route-manager/ete")/60);#mins
				me.wpETAText = sprintf("%d", me.wpETA);
				if (me.wpETA > 500) {
					me.wpETAText = "---";#todo should be time predicted when steerpoint is passed like 12:40:31. Also There should be a T field above it same formating, no clue what for.
				}

				me.wpText2Desc.setText(me.swedishMode?"BEN":"LEG");
				me.wpText2.setText(me.legText);
				me.wpText3Desc.setText(me.swedishMode?"B":"S");
				me.wpText3.setText((me.wpNum-1)~" -> "~me.wpNum);
				me.wpText4Desc.setText(me.swedishMode?"H":"A");
				me.wpText4.setText(me.wpAlt);
				me.wpText5Desc.setText("M");
				me.wpText5.setText(me.wpSpeed);
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
	
	createSteerpoint: func (wp) {
		#TODO: double check that it can only increase by 1 from max
		if (wp > me.steerPointMax) {
	   		var stGrp = me.rootCenter.createChild("group").setTranslation(2000, 2000);
	   		append(me.steerpointText, stGrp.createChild("text")
	    		.setText("B2")
	    		.setColor(COLOR_WHITE)
	    		.setAlignment("right-center")
	    		.setTranslation(-15*MM2TEX, 0)
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
	           .setColor(COLOR_TYRK_DARK));
			append(me.steerpoint, stGrp);
			me.steerPointMax += 1;
		}
		if (wp>me.steerPointMax) logprint(LOG_DEBUG, wp~" - "~me.steerPointMax);
	},

	showSteerPoints: func {
		# steerpoints on map
		me.rrSymbolS.hide();
		me.all_plans = [];# 0: plan  1: editing  2: MSDA menu
		me.steerRot = -me.input.heading.getValue()*D2R;
		if (me.menuMain == MAIN_MISSION_DATA) {
			append(me.all_plans, [route.Polygon.polys["1"], route.Polygon.polys["1"] == route.Polygon.editing, TRUE]);
			append(me.all_plans, [route.Polygon.polys["2"], route.Polygon.polys["2"] == route.Polygon.editing, TRUE]);
			append(me.all_plans, [route.Polygon.polys["3"], route.Polygon.polys["3"] == route.Polygon.editing, TRUE]);
			append(me.all_plans, [route.Polygon.polys["4"], route.Polygon.polys["4"] == route.Polygon.editing, TRUE]);
			append(me.all_plans, [route.Polygon.polys["1A"], route.Polygon.polys["1A"] == route.Polygon.editing, TRUE]);
			append(me.all_plans, [route.Polygon.polys["1B"], route.Polygon.polys["1B"] == route.Polygon.editing, TRUE]);
			append(me.all_plans, [route.Polygon.polys["2A"], route.Polygon.polys["2A"] == route.Polygon.editing, TRUE]);
			append(me.all_plans, [route.Polygon.polys["2B"], route.Polygon.polys["2B"] == route.Polygon.editing, TRUE]);
			append(me.all_plans, [route.Polygon.polys["3A"], route.Polygon.polys["3A"] == route.Polygon.editing, TRUE]);
			append(me.all_plans, [route.Polygon.polys["3B"], route.Polygon.polys["3B"] == route.Polygon.editing, TRUE]);
			append(me.all_plans, [route.Polygon.polys["4A"], route.Polygon.polys["4A"] == route.Polygon.editing, TRUE]);
			append(me.all_plans, [route.Polygon.polys["4B"], route.Polygon.polys["4B"] == route.Polygon.editing, TRUE]);
			append(me.all_plans, [route.Polygon.polys["OP1"], route.Polygon.polys["OP1"] == route.Polygon.editing, TRUE]);
			append(me.all_plans, [route.Polygon.polys["OP2"], route.Polygon.polys["OP2"] == route.Polygon.editing, TRUE]);
			append(me.all_plans, [route.Polygon.polys["OP3"], route.Polygon.polys["OP3"] == route.Polygon.editing, TRUE]);
			append(me.all_plans, [route.Polygon.polys["OP4"], route.Polygon.polys["OP4"] == route.Polygon.editing, TRUE]);
			append(me.all_plans, [route.Polygon.polys["OP5"], route.Polygon.polys["OP5"] == route.Polygon.editing, TRUE]);
			append(me.all_plans, [route.Polygon.polys["OP6"], route.Polygon.polys["OP6"] == route.Polygon.editing, TRUE]);
		} else {
			me.all_plans = [[route.Polygon.primary, FALSE, FALSE],nil,nil,nil,nil,nil,nil,nil,nil,nil,nil,nil];
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

		me.steerB = me.swedishMode?"B":"S";
		me.steerA = me.swedishMode?"\xC3\x85":"R";
		me.steerM = me.swedishMode?"M":"T";
		me.wpIndex = -1;
		for(me.steerCounter = 0;me.steerCounter < 18; me.steerCounter += 1) {
			me.curr_plan = me.all_plans[me.steerCounter];
			if (me.curr_plan != nil and me.curr_plan[0].type == route.TYPE_AREA) {#maybe more solid to check steercounter
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
			} else {
				me.points = 0;
			}
			for (var wp = 0; wp < me.points; wp += 1) {
				# wp      = local index inside a polygon
				# wpIndex = global index for use with canvas elements
				
				
				me.isSelectable = FALSE;
				me.doRR = FALSE;
				if (me.curr_plan != nil and me.points > wp and ((me.isArea or (route.Polygon.isPrimaryActive() == TRUE and me.curr_plan[0].isPrimary())) or me.menuMain == MAIN_MISSION_DATA)) {
					me.node = me.polygon[wp];
	  				if (me.node == nil or me.showSteers == FALSE) {
	  					#me.steerpoint[me.wpIndex].hide();
	    				continue;
	  				}
	  				me.wpIndex += 1;
	  				me.createSteerpoint(me.wpIndex);
					me.lat_wp = me.node.wp_lat;
	  				me.lon_wp = me.node.wp_lon;
	  				me.target_wp = me.node.fly_type=="flyOver";
	  				#me.alt = node.getNode("altitude-m").getValue();
					me.name = me.node.id;
					me.texCoord = me.laloToTexel(me.lat_wp, me.lon_wp);
					if (me.isArea) {
						# this point is part of area
						#printf("doing for %d", me.wpSelect);
						me.steerpoint[me.wpIndex].setColor(me.wpSelect == wp?COLOR_WHITE:me.curr_plan[0].color);
						me.steerpointSymbol[me.wpIndex].setScale(0.25);
						me.steerpointSymbol[me.wpIndex].setStrokeLineWidth(w*4);
						me.steerpoint[me.wpIndex].set("z-index", 11);
						me.areaEnd = wp==0?-1:(me.points == wp+1 and wp>1?1:0);
						append(me.poly, [me.texCoord[0], me.texCoord[1], wp != 0, me.curr_plan[1] == TRUE?COLOR_WHITE:me.curr_plan[0].color, me.curr_plan ==route.Polygon.editing?2:1, me.areaEnd]);
					} elsif (me.wpSelect == wp) {
						# this waypoint is selected in MSDA
						#printf("doing for %d", me.wpSelect);
						me.steerpoint[me.wpIndex].setColor(COLOR_WHITE);
						me.steerpointSymbol[me.wpIndex].setScale(1);
						me.steerpointSymbol[me.wpIndex].setStrokeLineWidth(w);
						me.steerpoint[me.wpIndex].set("z-index", 11);
						append(me.poly, [me.texCoord[0], me.texCoord[1], wp != 0, COLOR_TYRK, 2, 0]);
						me.nextActive = FALSE;
					} elsif ((!modes.TI_show_wp and me.curr_plan[2] == FALSE) and me.curr_plan[0].isPrimary() == TRUE and me.curr_plan[0].isPrimaryActive() == TRUE and me.curr_plan[0].getLeg() != nil and me.curr_plan[0].getLeg().id == me.node.id) {
						# The route is being flown. We are not in MSDA and waypoint is current but should not be shown.
						me.steerpoint[me.wpIndex].hide();
						if (wp != me.points-1) {
							# airport is not last steerpoint, we make a leg to/from that also
							append(me.poly, [me.texCoord[0], me.texCoord[1], TRUE, COLOR_TYRK_DARK, me.curr_plan[1] == TRUE?2:1, 0]);
						}
						me.nextActive = me.nextDist*NM2M<20000;
	    				continue;
					} elsif (me.curr_plan[2] == FALSE and me.curr_plan[0].isPrimary() == TRUE and me.curr_plan[0].isPrimaryActive() == TRUE and me.curr_plan[0].getLeg() != nil and me.curr_plan[0].getLeg().id == me.node.id) {
						# Route is being flown, waypoint is current and we not in MSDA menu.
						me.steerpoint[me.wpIndex].setColor(COLOR_TYRK);
						me.steerpoint[me.wpIndex].set("z-index", 10);
						me.steerpointSymbol[me.wpIndex].setScale(1);
						me.steerpointSymbol[me.wpIndex].setStrokeLineWidth(w);
						me.steerpointText[me.wpIndex].set("z-index", 10);
						me.doRR = TRUE;
						append(me.poly, [me.texCoord[0], me.texCoord[1], TRUE, COLOR_TYRK_DARK, 1, 0]);
						me.nextActive = me.nextDist*NM2M<20000;
					} elsif (me.curr_plan[1] == TRUE) {
						# We are in MSDA, waypoint is in the polygon selected for editing.
						me.steerpoint[me.wpIndex].setColor(COLOR_TYRK);
						me.steerpoint[me.wpIndex].set("z-index", 10);
						me.steerpointSymbol[me.wpIndex].setScale(1);
						me.steerpointSymbol[me.wpIndex].setStrokeLineWidth(w);
						append(me.poly, [me.texCoord[0], me.texCoord[1], wp != 0, COLOR_TYRK, 2, 0]);
						me.nextActive = FALSE;
					} else {
						# ordinary waypoint (MSDA or not)
						me.steerpoint[me.wpIndex].set("z-index", 5);
						me.steerpoint[me.wpIndex].setColor(COLOR_TYRK_DARK);
						me.steerpointSymbol[me.wpIndex].setScale(1);
						me.steerpointSymbol[me.wpIndex].setStrokeLineWidth(w);
						append(me.poly, [me.texCoord[0], me.texCoord[1], wp != 0 and (me.nextActive or me.curr_plan[2]), COLOR_TYRK_DARK, 1, 0]);
						me.nextActive = FALSE;
						if (me.menuMain != MAIN_MISSION_DATA) {
							me.isSelectable = TRUE;
						}
					}
					me.steerpoint[me.wpIndex].setTranslation(me.texCoord[0], me.texCoord[1]);
					if (me.doRR) {
						#draw steerorder symbol around steerpoint.
						me.rrSymbolS.setTranslation(me.texCoord[0], me.texCoord[1]);
						me.rrSymbolS.show();
					}
					if (me.isSelectable and me.cursorTrigger and !me.cursorDidSomething) {
						# not in MSDA so check if cursor is clicking on the steerpoint and if so, set it current.
						me.cursorDistX = me.cursorOPosX-me.texCoord[0];
						me.cursorDistY = me.cursorOPosY-me.texCoord[1];
						me.cursorDist = math.sqrt(me.cursorDistX*me.cursorDistX+me.cursorDistY*me.cursorDistY);
						if (me.cursorDist < 12) {
							route.Polygon.jumpTo(me.node, wp);
							me.cursorTriggerPrev = TRUE;#a hack. It CAN happen that a steerpoint gets selected through infobox, in that case lets make sure infobox is not activated. bad UI fix. :(
							me.cursorDidSomething = TRUE;
						}
					}
					if (me.curr_plan[1] and me.cursorTrigger and !me.cursorDidSomething and !route.Polygon.editSteer and !route.Polygon.insertSteer and !route.Polygon.appendSteer and !me.isDAPActive()) {
						# This is where cursor select a steer when a plan is in edit mode..
						me.cursorDistX = me.cursorOPosX-me.texCoord[0];
						me.cursorDistY = me.cursorOPosY-me.texCoord[1];
						me.cursorDist = math.sqrt(me.cursorDistX*me.cursorDistX+me.cursorDistY*me.cursorDistY);
						if (me.cursorDist < 12) {
							# select the steerpoint
							route.Polygon.selectSteerpoint(me.curr_plan[0].getName(), me.node, wp);# dangerous!!! what if somebody is editing plan in routemanager?
							me.steerpoint[me.wpIndex].setColor(COLOR_WHITE);
							me.cursorTriggerPrev = TRUE;#a hack. It CAN happen that a steerpoint gets selected through infobox, in that case lets make sure infobox is not activated. bad UI fix. :(
							me.cursorDidSomething = TRUE;
							if (route.Polygon.dragSteer and me.sDrag == nil) {
								me.dragOk = route.Polygon.startDragging();
								if (me.dragOk) {
									# start dragging
									me.sDrag = me.node;
								}
							}
						}
					}
					me.steerpoint[me.wpIndex].setRotation(me.steerRot);
					if (me.curr_plan[1] or (!me.curr_plan[1] and !me.curr_plan[2])) {
						# plan is being edited or we are not in MSDA page so set text name by it.
						me.wp_pre = me.curr_plan[0].type == route.TYPE_AREA ?"":(me.target_wp?me.steerM:(me.curr_plan[0].type == route.TYPE_MISS?me.steerB:me.steerA));
						me.steerpointText[me.wpIndex].setText(me.wp_pre~(wp+1));
						me.steerpointText[me.wpIndex].show();
					} else {
						me.steerpointText[me.wpIndex].hide();
					}
					if (!me.isArea or (me.curr_plan[2] and me.curr_plan[1])) {
						# its either part of a plan or we in MSDA menu and its being edited
						me.steerpoint[me.wpIndex].update();# might fix being shown at map center shortly when appending.
	  					me.steerpoint[me.wpIndex].show();
  					} else {
  						me.steerpoint[me.wpIndex].hide();
  					}
				} else {
					#me.steerpoint[me.wpIndex].hide();
				}
	  		}
	  	}
	  	#me.wpIndex = me.wpIndex==-1?0:me.wpIndex;
	  	me.wpIndex += 1;
	  	for (me.j = me.wpIndex;me.j<=me.steerPointMax;me.j+=1) {
	  		me.steerpoint[me.j].hide();
	  	}
	  	route.Polygon.jumpExecute();
  	},

  	laloToTexel: func (la, lo) {
		me.coord = geo.Coord.new();
  		me.coord.set_latlon(la, lo);
  		me.coordSelf = geo.Coord.new();#TODO: dont create this every time method is called
  		me.coordSelf.set_latlon(me.lat_own, me.lon_own);
  		me.angle = (me.coordSelf.course_to(me.coord)-me.input.heading.getValue())*D2R;
		me.pos_xx		 = -me.coordSelf.distance_to(me.coord)*M2TEX * math.cos(me.angle + math.pi/2);
		me.pos_yy		 = -me.coordSelf.distance_to(me.coord)*M2TEX * math.sin(me.angle + math.pi/2);
  		return [me.pos_xx, me.pos_yy];#relative to rootCenter
  	},
  	
  	laloToTexelMap: func (la, lo) {
		me.coord = geo.Coord.new();
  		me.coord.set_latlon(la, lo);
  		me.coordSelf = geo.Coord.new();#TODO: dont create this every time method is called
  		me.coordSelf.set_latlon(me.lat, me.lon);
  		me.angle = (me.coordSelf.course_to(me.coord))*D2R;
		me.pos_xx		 = -me.coordSelf.distance_to(me.coord)*M2TEX * math.cos(me.angle + math.pi/2);
		me.pos_yy		 = -me.coordSelf.distance_to(me.coord)*M2TEX * math.sin(me.angle + math.pi/2);
  		return [me.pos_xx, me.pos_yy];#relative to mapCenter
  	},

  	TexelToLaLoMap: func (x,y) {#relative to map center
  		x /= M2TEX;
  		y /= M2TEX;
  		me.mDist  = math.sqrt(x*x+y*y);
  		if (me.mDist == 0) {
  			return [me.lat, me.lon];
  		}
  		me.acosInput = clamp(x/me.mDist,-1,1);
  		if (y<0) {
  			me.texAngle = math.acos(me.acosInput);#unit circle on TI
  		} else {
  			me.texAngle = -math.acos(me.acosInput);
  		}
  		#printf("%d degs %0.1f NM", me.texAngle*R2D, me.mDist*M2NM);
  		me.texAngle  = -me.texAngle*R2D+90;#convert from unit circle to heading circle, 0=up on display
  		me.headAngle = me.input.heading.getValue()+me.texAngle;#bearing
  		#printf("%d bearing   %d rel bearing", me.headAngle, me.texAngle);
  		me.coordSelf = geo.Coord.new();#TODO: dont create this every time method is called
  		me.coordSelf.set_latlon(me.lat, me.lon);
  		me.coordSelf.apply_course_distance(me.headAngle, me.mDist);

  		return [me.coordSelf.lat(), me.coordSelf.lon()];
  	},

  	showBullsEye: func {
  		if (me.input.bullseyeOn.getBoolValue()) {
  			me.beLaLo = [me.input.bullseyeLat.getValue(), me.input.bullseyeLon.getValue()];
  			me.bePos = me.laloToTexel(me.beLaLo[0], me.beLaLo[1]);
			me.be.set_latlon(me.beLaLo[0], me.beLaLo[1], 0);
  			me.bullsEye.setTranslation(me.bePos[0], me.bePos[1]);
  			me.bullsEye.setRotation(-me.input.heading.getValue()*D2R);
  			if (displays.common.cursor == displays.TI) {
  				# bearing and distance from Bulls-Eye to cursor
				#
  				me.cursorLaLo = me.TexelToLaLoMap(me.cursorPosX, me.cursorPosY);
  				me.cs.set_latlon(me.cursorLaLo[0], me.cursorLaLo[1],0);
  				me.bear = geo.normdeg(me.be.course_to(me.cs));
  				me.beDist = me.be.distance_to(me.cs);
  				me.beDist = me.swedishMode?0.001*me.beDist:M2NM*me.beDist;
  				me.beDistTxt = sprintf("%d",me.beDist);
  				if (me.beDist > 10000) {
  					me.beDistTxt = sprintf("%dK",me.beDist*0.001);
  				} elsif (me.beDist > 1000) {
  					me.beDistTxt = sprintf("%.1fK",me.beDist*0.001);
  				}
  				if (!me.isCursorOnMap()) {
  					me.beText.setText("");
  				} else {
  					me.beText.setText(sprintf("%03d\xc2\xb0 %s%s",me.bear,me.swedishMode?" A":"NM",me.beDistTxt));
  				}
  				me.beTextField.show();
  			} elsif ((var tgt = radar.ps46.getPriorityTarget()) != nil and (var coord = tgt.getLastCoord()) != nil) {
  				# bearing and distance from Bulls-Eye to selected radar echo
				#
  				me.cs.set_latlon(coord.lat(), coord.lon(),0);
  				me.bear = geo.normdeg(me.be.course_to(me.cs));
  				me.beDist = me.be.distance_to(me.cs);
  				me.beDist = me.swedishMode?0.001*me.beDist:M2NM*me.beDist;
  				me.beDistTxt = sprintf("%d",me.beDist);
  				if (me.beDist > 10000) {
  					me.beDistTxt = sprintf("%dK",me.beDist*0.001);
  				} elsif (me.beDist > 1000) {
  					me.beDistTxt = sprintf("%.1fK",me.beDist*0.001);
  				}
  				me.beText.setText(sprintf("%03d\xc2\xb0 %s%s",me.bear,me.swedishMode?" A":"NM",me.beDistTxt));
  				me.beTextField.show();
  			} else {
  				me.beTextField.hide();
  			}
  			me.bullsEye.show();
		} else {
			me.beTextField.hide();
			me.bullsEye.hide();
		}
  	},

  	showLVFF: func {
  		# LV and FF points
  		#
  		# address, color (0=red 1=yellow 2=tyrk), radius(KM) (-1= 3.5mm), type (0=LV, 1=FF, 2=STRIL), lon, lat
  		if (!me.cursorTrigger or me.menuMain != MAIN_MISSION_DATA) {
  			me.lvffDrag = nil;
  		}
  		me.lv = dap.lv;
  		me.ppGrp.removeAllChildren();
  		foreach(me.lvp;keys(me.lv)) {
  			# for now just paint all of them and hope the pilot do not input tons at the same time
  			me.pp = me.lv[me.lvp];

  			me.ppCol = me.pp.color==0?COLOR_RED:(me.pp.color==1?COLOR_YELLOW:COLOR_TYRK);
  			me.ppRad = me.pp.radius==-1?15:M2TEX*me.pp.radius*1000;
  			me.ppNum = sprintf("%03d",me.pp.address);
  			if (me.lvffDrag == me.pp.address) {
  				me.laloDap = me.TexelToLaLoMap(me.cursorPosX, me.cursorPosY);
  				dap.lv[me.lvp].lat = me.laloDap[0];
  				dap.lv[me.lvp].lon = me.laloDap[1];
  				me.ppXY = [me.cursorOPosX, me.cursorOPosY];
  			} else {
  				me.ppXY  = me.laloToTexel(me.pp.lat, me.pp.lon);
  			}
  			
  			if (me.pp.type==1) {
  				# FF
  				me.ppGrp.createChild("group")
  						.setTranslation(me.ppXY[0], me.ppXY[1])
  				        .createChild("path")
  						.moveTo(me.ppRad, me.ppRad)
  						.horiz(-me.ppRad*2)
  						.vert(-me.ppRad*2)
  						.horiz(me.ppRad*2)
  						.vert(me.ppRad*2)
  						.setRotation(-me.input.heading.getValue()*D2R)
  						.setColor(me.ppCol)
  						.setStrokeLineWidth(w);
  				if (me.menuMain==MAIN_MISSION_DATA or dap.settingKnob == dap.KNOB_TI) {
  					me.ppGrp.createChild("group")
  						.setTranslation(me.ppXY[0], me.ppXY[1])
  						.setRotation(-me.input.heading.getValue()*D2R)
  				        .createChild("text")
  						.setText(me.ppNum)
  						.setColor(me.ppCol)
    					.setAlignment("left-center")
    					.setTranslation(me.ppRad+5, 0)
    					.setFontSize(15, 1);
  				}
			} else {
				# LV
				if (me.menuMain==MAIN_MISSION_DATA or me.showAAAZones) {
					me.ppGrp.createChild("path")
	  						.moveTo(me.ppXY[0]-me.ppRad, me.ppXY[1])
	  						.arcSmallCW(me.ppRad, me.ppRad, 0, me.ppRad*2, 0)
	           				.arcSmallCW(me.ppRad, me.ppRad, 0, -me.ppRad*2, 0)
	  						.setColor(me.ppCol)
	  						.setStrokeLineWidth(w);
  				}
				if (me.menuMain==MAIN_MISSION_DATA or (dap.settingKnob == dap.KNOB_TI and me.showAAAZones)) {
					me.lvPadX = 0;
					me.lvPadY = 0;
					me.lvAlign = "center-center";
  					if (me.ppRad < 20) {
  						# the circle is so small that the text wont fit inside it.
  						me.lvPadX = (me.ppRad+5)*math.cos(-me.input.heading.getValue()*D2R);
  						me.lvPadY = (me.ppRad+5)*math.sin(-me.input.heading.getValue()*D2R);
						me.lvAlign = "left-center";
  					}
  					me.ppGrp.createChild("text")#TODO: Make this and FF texts be reused. (like gridlines text do) As text is very heavy to create.
  						.setText(me.ppNum)
  						.setColor(me.ppCol)
    					.setAlignment(me.lvAlign)
    					.setTranslation(me.ppXY[0]+me.lvPadX, me.ppXY[1]+me.lvPadY)
    					.setRotation(-me.input.heading.getValue()*D2R)
    					.setFontSize(15, 1);
  				}
			}
			#printf("%d %d %d %d %d ",me.menuMain == MAIN_MISSION_DATA,me.cursorTrigger,!me.cursorDidSomething,route.Polygon.editing == nil,me.lvffDrag == nil);
			if (me.menuMain == MAIN_MISSION_DATA and me.cursorTrigger and !me.cursorDidSomething and route.Polygon.editing == nil and me.lvffDrag == nil) {
				me.cursorDistX = me.cursorOPosX-me.ppXY[0];
				me.cursorDistY = me.cursorOPosY-me.ppXY[1];
				me.cursorDist = math.sqrt(me.cursorDistX*me.cursorDistX+me.cursorDistY*me.cursorDistY);
				if (me.cursorDist < 12) {
					me.lvffDrag = me.pp.address;
					me.cursorDidSomething = TRUE;
				}
			}
  		}
  		me.ppGrp.update();
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
		if (me.displayTime == TRUE or (route.Polygon.editing != nil and route.Polygon.editing.type != route.TYPE_AREA)) {
			me.textTime.setText(getprop("sim/time/gmt-string")~" Z  ");# should really be local time
			me.textTime.show();
		} elsif (getprop("/ja37/avionics/ins-init") > 0) {
			me.textTime.setText("STARTFIX  ");
			me.textTime.show();
		} else {
			me.textTime.hide();
		}
	},

	showFlightTime: func {
		# set true from DAP, when DAP knob is in TI (OUT).
		if (me.displayFTime == TRUE) {
			me.fhour = math.floor(displays.common.ftime/60/60);
			me.fmin  = math.floor((displays.common.ftime-me.fhour*60*60)/60);
			me.textFTime.setText(sprintf("FTIME %d:%02d",  me.fhour, me.fmin));
			me.textFTime.show();
		} else {
			me.textFTime.hide();
		}
	},

	updateFlightData: func {
		me.fData = FALSE;
		if (me.input.gpws_arrow.getBoolValue()) {
			me.fData = TRUE;
		} elsif (me.displayFlight == FLIGHTDATA_ON) {
			me.fData = TRUE;
		} elsif (me.displayFlight == FLIGHTDATA_CLR and (me.input.rad_alt_ready.getBoolValue() and me.input.rad_alt.getValue()*FT2M < 1000 or math.abs(me.input.pitch.getValue()) > 10 or math.abs(me.input.roll.getValue()) > 45)) {
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
		me.fpi_x_deg = me.input.fpv_right.getValue();
		me.fpi_y_deg = -me.input.fpv_up.getValue();
		me.fpi_x = me.fpi_x_deg*texel_per_degree;
		me.fpi_y = me.fpi_y_deg*texel_per_degree;
		#me.fpi.setTranslation(me.fpi_x, me.fpi_y);
		me.fpi.show();
	},

	displayHorizon: func {
		me.rot = -me.input.roll.getValue() * D2R;
		me.horizon_group.setTranslation(-me.fpi_x, -me.fpi_y);
		me.horz_rot.setRotation(me.rot);
		me.horizon_group2.setTranslation(0, texel_per_degree * me.input.pitch.getValue());

		me.alt = getprop("instrumentation/altimeter/indicated-altitude-ft");
		if (me.alt != nil) {
			me.text = "";
			if (me.swedishMode) {
				if(me.alt*FT2M < 1000) {
					me.text = str(math.round(me.alt*FT2M, 10));
				} else {
					me.text = sprintf("%.1f", me.alt*FT2M/1000);
				}
			} else {
				if(me.alt < 1000) {
					me.text = str(math.round(me.alt, 10));
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
	    if (me.input.gpws_arrow.getBoolValue()) {
	      me.arrow_trans.setRotation(-me.input.roll.getValue() * D2R);
	      me.arrow.show();
	    } else {
	      me.arrow.hide();
	    }
	},

	displayGround: func () {
		me.margin = me.input.gpws_margin.getValue();
		if (me.margin < 1) {
			me.dist = me.margin * (height/2);
			me.ground_grp.setTranslation(0, 0);
			me.ground_grp_trans.setRotation(-me.input.roll.getValue() * D2R);
			me.groundCurve.setTranslation(0, me.dist);
			if (me.margin < 0.5) {
				me.groundCurve.setColor(COLOR_RED);
			} else {
				me.groundCurve.setColor(COLOR_GREY_BLUE);
			}
			me.ground_grp.show();
		} else {
			me.ground_grp.hide();
		}
	},

	showBottomText: func {
		#clip is in canvas coordinates
		me.clip2 = ((me.menuMain != MAIN_MISSION_DATA)*(me.SVYactive*height*0.125+me.SVYactive*height*0.125*me.SVYsize))~"px, "~width~"px, "~(height-height*0.1-height*0.025*me.upText)~"px, "~0~"px";
		me.rootCenter.set("clip", "rect("~me.clip2~")");#top,right,bottom,left
		me.mapCentrum.set("clip", "rect("~me.clip2~")");#top,right,bottom,left
		me.clip3 = 0~"px, "~width~"px, "~((me.menuMain != MAIN_MISSION_DATA)*(me.SVYactive*height*0.125+me.SVYactive*height*0.125*me.SVYsize))~"px, "~0~"px";
		me.svy_grp.set("clip", "rect("~me.clip3~")");#top,right,bottom,left
		me.bottom_text_grp.setTranslation(0,-height*0.025*me.upText);
		me.textBArmType.setText(displays.common.currArmNameSh);
		me.ammo = fire_control.get_current_ammo();
	    if (me.ammo == -1) {
	    	me.ammoT = "  ";
	    } else {
	    	me.ammoT = me.ammo~"";
	    }
		me.textBArmAmmo.setText(me.ammoT);
		if (me.swedishMode) {
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
		me.icao = navigation.icao~((navigation.ils) ?" T":"  ");
		me.textBBase.setText(me.icao);

		me.mode = "";
		# DL: data link
		# RR: radar guided steering
		if (displays.common.ti_selection != nil) {
			me.mode = "RR";# landing steerpoint
			me.textBMode.setColor(COLOR_WHITE);
		} elsif (modes.nav_ja == modes.LB) {
			me.mode = me.swedishMode?"LB":"LS";# landing steerpoint
			me.textBMode.setColor(COLOR_WHITE);
		} elsif (modes.nav_ja == modes.LF) {
			me.mode = me.swedishMode?"LF":"LT";# landing touchdown point
			me.textBMode.setColor(COLOR_WHITE);
		} elsif (modes.nav_ja == modes.L) {
			me.mode = "L ";# steering to landing base
			me.textBMode.setColor(COLOR_TYRK);
		} elsif (modes.nav_ja == modes.OPT) {
			me.mode = "OP";# visual landing phase
			me.textBMode.setColor(COLOR_WHITE);
		} elsif ((modes.nav_ja == modes.B or modes.nav_ja == modes.LA) and route.Polygon.primary != nil) {
			me.target_wp = route.Polygon.primary.isTarget(route.Polygon.primary.getIndex());
			me.wp_pre = me.target_wp?me.steerM:(route.Polygon.primary.type == route.TYPE_MISS?me.steerB:me.steerA);
			me.wp_post = route.Polygon.primary.getIndex()+1;
			me.mode = me.wp_pre~me.wp_post;
			if (!me.target_wp) {
				me.textBMode.setColor(COLOR_TYRK);
			} else {
				me.textBMode.setColor(COLOR_WHITE);
			}
		} else {
			me.mode = "  ";# VFR
			me.textBMode.setColor(COLOR_WHITE);
		}
		me.textBMode.setText(me.mode);

		if (displays.common.distance_m != nil) {
			if (me.swedishMode) {
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
		if (modes.main_ja == modes.LANDING and me.input.gearsPos.getValue() == 1) {
			me.alphaT  = me.swedishMode?"ALFA":"ALPH";
			me.weightT = me.swedishMode?"VIKT":"WEIG";
			me.weight = me.input.weight.getValue() * 0.001;
			if (me.swedishMode) me.weight *= LB2KG;
			me.alpha   = me.input.max_approach_alpha.getValue();
			me.weightT = me.weightT~sprintf(" %.1f", me.weight);
			me.alphaT  = me.alphaT~sprintf(" %.1f", me.alpha);
			me.textBWeight.setText(me.weightT);
			me.textBAlpha.setText(me.alphaT);
		} elsif (me.lnk99 == TRUE) {
			me.rb99_list = radar.rb99_datalink.getMissileList();
			me.weightT = "";
			for (var i = 0; i < 2; i+=1) {
				if (size(me.rb99_list) > i) {
					me.weightT = me.weightT~"|"~radar.rb99_datalink.display_str(me.rb99_list[i]);
				} else {
					me.weightT = me.weightT~"|      ";
				}
			}
			me.alphaT = "";
			for (var i = 2; i < 4; i+=1) {
				if (size(me.rb99_list) > i) {
					me.alphaT = me.alphaT~"|"~radar.rb99_datalink.display_str(me.rb99_list[i]);
				} else {
					me.alphaT  =  me.alphaT~"|      ";
				}
			}
			me.textBWeight.setText(me.weightT);
			me.textBAlpha.setText(me.alphaT);
		} else {
			me.textBWeight.setText("");
			me.textBAlpha.setText("");
		}
		
		if (displays.common.error == FALSE) {
			me.textBerror.setColor(COLOR_GREY);
			me.textBerrorFrame2.hide();
			me.textBerrorFrame1.show();
		} else {
			me.textBerror.setColor(COLOR_BLACK);
			me.textBerrorFrame1.hide();
			me.textBerrorFrame2.show();
		}
		if (!me.input.datalink.getBoolValue()) {
			me.textBlink.setColor(COLOR_GREY);
			me.textBLinkFrame2.hide();
			me.textBLinkFrame1.show();
		} else {
			me.textBlink.setColor(COLOR_BLACK);
			me.textBLinkFrame1.hide();
			me.textBLinkFrame2.show();
		}
	},

	showRadarLimit: func {
		if (me.input.radarStandby.getBoolValue()) {
			me.radar_limit_grp.hide();
			me.radarTopSvy.hide();
			me.radarBotSvy.hide();
			return;
		}

		if (me.lastZ != zoom_curr
			or me.lastRR != radar.ps46.getRangeM()
			or me.lastScanW != radar.ps46.getAzimuthRadius()
			or me.input.timeElapsed.getValue() - me.lastRRT > 1600)
		{
			me.lastZ  = zoom_curr;
			me.lastRR  = radar.ps46.getRangeM();
			me.lastScanW = radar.ps46.getAzimuthRadius();
			me.lastRRT = me.input.timeElapsed.getValue();

			# Redraw radar arc
			me.radar_limit_grp.removeAllChildren();
			me.rdrField = me.lastScanW * D2R;
			me.radius = me.lastRR * M2TEX;
			me.leftX = -math.sin(me.rdrField)*me.radius;
			me.leftY = -math.cos(me.rdrField)*me.radius;
			me.radarLimit = me.radar_limit_grp.createChild("path")
				.moveTo(me.leftX, me.leftY)
				.arcSmallCW(me.radius, me.radius, 0, -me.leftX*2, 0)
				.moveTo(me.leftX, me.leftY)
				.lineTo(me.leftX*0.80, me.leftY*0.80)
				.moveTo(-me.leftX, me.leftY)
				.lineTo(-me.leftX*0.80, me.leftY*0.80)
				.setColor(COLOR_TYRK)
				.setStrokeLineWidth(w);
		}

		me.radar_limit_grp.setRotation(radar.ps46.getDeviation() * D2R);
		me.radar_limit_grp.show();

		# Rest is for sideview

		# Do not hide the lines immediately when sideview turns off,
		# it will be done with the rest of the sideview in updateSVY().
		if (!me.SVYactive or me.menuMain == MAIN_MISSION_DATA) return;
		# dirty hack to check updateSVY() ran at least once to set the required parameters
		if (!contains(me, "selfSvyPos")) return;

		if (radar.ps46.getMode() == "Disk") {
			# radar angles don't work in this mode
			me.radarTopSvy.hide();
			me.radarBotSvy.hide();
			return;
		}

		me.radar_elev = radar.ps46.currentMode.upperAngle;
		me.radar_slope = math.tan(me.radar_elev * D2R);
		me.radar_slope *= - me.SVYheight / me.SVYwidth / me.SVYalt * me.SVYrange;
		me.line_end_x = me.SVYoriginX + me.SVYwidth;
		me.line_end_y = me.selfSvyPos[1] + me.radar_slope * me.SVYwidth;
		if (me.line_end_y > me.SVYoriginY) {
			me.line_end_x -= (me.line_end_y - me.SVYoriginY) / me.radar_slope;
			me.line_end_y = me.SVYoriginY;
		} elsif (me.line_end_y < me.SVYoriginY - me.SVYheight) {
			me.line_end_x -= (me.line_end_y - me.SVYoriginY + me.SVYheight) / me.radar_slope;
			me.line_end_y = me.SVYoriginY - me.SVYheight;
		}
		me.radarTopSvy.reset();
		me.radarTopSvy.moveTo(me.selfSvyPos).lineTo(me.line_end_x, me.line_end_y);
		me.radarTopSvy.show();

		me.radar_elev = radar.ps46.currentMode.lowerAngle;
		me.radar_slope = math.tan(me.radar_elev * D2R);
		me.radar_slope *= - me.SVYheight / me.SVYwidth / me.SVYalt * me.SVYrange;
		me.line_end_x = me.SVYoriginX + me.SVYwidth;
		me.line_end_y = me.selfSvyPos[1] + me.radar_slope * me.SVYwidth;
		if (me.line_end_y > me.SVYoriginY) {
			me.line_end_x -= (me.line_end_y - me.SVYoriginY) / me.radar_slope;
			me.line_end_y = me.SVYoriginY;
		} elsif (me.line_end_y < me.SVYoriginY - me.SVYheight) {
			me.line_end_x -= (me.line_end_y - me.SVYoriginY + me.SVYheight) / me.radar_slope;
			me.line_end_y = me.SVYoriginY - me.SVYheight;
		}
		me.radarBotSvy.reset();
		me.radarBotSvy.moveTo(me.selfSvyPos).lineTo(me.line_end_x, me.line_end_y);
		me.radarBotSvy.show();
	},

	showRunway: func {
		if (modes.nav_ja != modes.B and (land.show_waypoint_circle == TRUE or land.show_runway_line == TRUE)) {
		  me.heading = me.input.heading.getValue();#true
		  me.rwy_dist = (me.input.rmDist.getValue() or 0) * NM2M;
		  me.rwy_bearing = (me.input.rmBearing.getValue() or 0) - me.heading;
		  me.x = math.cos(-(me.rwy_bearing - 90) * D2R) * me.rwy_dist * M2TEX;
		  me.y = math.sin(-(me.rwy_bearing - 90) * D2R) * me.rwy_dist * M2TEX;

		  me.dest.setTranslation(me.x, -me.y);

		  if (land.show_waypoint_circle == TRUE) {
		  	  #me.scale = clamp(2000*M2TEX/100, 25/100, 50);
		      #me.dest_circle.setStrokeLineWidth(w/me.scale);
		      #me.dest_circle.setScale(me.scale);
		      me.dest_circle.show();
		  } else {
		      me.dest_circle.hide();
		  }

		  if (navigation.has_rwy) {
		    me.runway_l = land.line*1000;
		    me.scale = clamp(me.runway_l*M2TEX,10*MM2TEX,1000);#in the real they are always 10mm, cheated abit.
		    me.approach_line.setScale(1, me.scale);
		    me.dest.setRotation((180+navigation.rwy_heading-me.heading)*D2R);
		    me.runway_name.setText(navigation.rwy_name);
		    me.runway_name.setRotation(-(180+navigation.rwy_heading)*D2R);
		    me.runway_name.show();
		    me.approach_line.show();
		    me.approach_line.update();
		    if (navigation.rwy.length > 0) {
		    	me.scale = navigation.rwy.length*M2TEX;
	    	} else {
	    		me.scale = 400*M2TEX;
	    	}
	    	me.runway_line.setScale(1, me.scale);
		    me.runway_line.show();
		    me.runway_line.update();
		    if (land.show_approach_circle == TRUE) {
		      me.scale = 4100*M2TEX/100;
		      me.approach_circle.setStrokeLineWidth(w/me.scale);
		      me.approach_circle.setScale(me.scale);
		      me.distance = me.ac_pos.distance_to(land.approach_circle);
		      me.xa_rad   = (me.ac_pos.course_to(land.approach_circle) - me.ind_head_true) * D2R;
		      me.pixelDistance = -me.distance*M2TEX; #distance in pixels
		      #translate from polar coords to cartesian coords
		      me.pixelX =  me.pixelDistance * math.cos(me.xa_rad + math.pi/2);
		      me.pixelY =  me.pixelDistance * math.sin(me.xa_rad + math.pi/2);
		      me.approach_circle.setTranslation(me.pixelX, me.pixelY);
		      me.approach_circle.update();#needed
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
		  me.dest.update();
		} else {
			me.dest_circle.hide();
			me.approach_line.hide();
			me.approach_circle.hide();
			me.runway_line.hide();
		    me.runway_name.hide();
		}
	},

	displayRadarTracks: func () {
		me.track_index = 0;
		me.DLtrack_index = 0;
		me.missile_index = 0;

		# This is to avoid displaying the same track twice with radar + datalink
		me.displayed_id = {};

		me.rrSymbol.hide();
		me.sel_updated = FALSE;

		me.radar_group.show();
		me.svy_radar_grp.show();

		foreach (var contact; radar.ps46.getTracks()) {
			var id = contact.getUnique();
			if (me.track_index >= maxTracks or contains(me.displayed_id, id)) break;

			if (me.displayRadarTrack(contact)) {
				me.displayed_id[id] = 1;
			}
		}

		foreach (var contact; fighterlink.dl_contacts) {
			var id = contact.getUnique();
			if (me.DLtrack_index >= maxDLTracks or contains(me.displayed_id, id)) break;

			if (me.displayRadarTrack(contact, TRUE)) {
				me.displayed_id[id] = 1;
			}
		}

		foreach(var contact; radar.rb99_datalink.getMissileList()) {
			if (me.missile_index >= maxMissiles) break;
			me.displayRadarTrack(contact, FALSE, TRUE);
		}

		# hide the remaining unused echoes
		for (; me.track_index < maxTracks; me.track_index += 1) {
			me.tracks[me.track_index].grp.hide();
			me.tracksSVY[me.track_index].grp.hide();
		}
		for (; me.DLtrack_index < maxDLTracks; me.DLtrack_index += 1) {
			me.DLtracks[me.DLtrack_index].grp.hide();
			me.DLtracksSVY[me.DLtrack_index].grp.hide();
		}
		for (; me.missile_index < maxMissiles; me.missile_index += 1) {
			me.missiles[me.missile_index].grp.hide();
			me.missilesSVY[me.missile_index].grp.hide();
		}

		if (displays.common.ti_selection != nil and !me.sel_updated) {
			displays.common.unsetTISelection();
		}
	},

	# Returns whether or not the track was actually displayed
	displayRadarTrack: func (contact, dl=0, missile=0) {
		# Track parameters
		me.coord = nil;
		me.tgtSpeed = nil;
		me.tgtHeading = nil;
		if (missile or dl) {
			me.coord = contact.getCoord();
			me.tgtSpeed = contact.getSpeed();
			me.tgtHeading = contact.getHeading();
			me.tgtAlt = contact.getAltitude();
		} else {
			me.coord = contact.getLastCoord();
			me.tgtSpeed = contact.getLastSpeed();
			me.tgtHeading = contact.getLastHeading();
			me.tgtAlt = contact.getLastAltitude();
		}
		if (me.coord == nil or me.tgtSpeed == nil or me.tgtHeading == nil) return FALSE;

		me.texelDistance = me.ac_pos.distance_to(me.coord) * M2TEX;
		me.angle         = (me.ac_pos.course_to(me.coord) - me.ind_head_true) * D2R;
		me.pos_xx        = me.texelDistance * math.sin(me.angle);
		me.pos_yy        = -me.texelDistance * math.cos(me.angle);
		me.relHeading = me.tgtHeading - me.head_true;

		# Object to show
		if (missile) {
			if (me.missile_index >= maxMissiles) return FALSE;
			me.echo = me.missiles[me.missile_index];
			me.echoSVY = me.missilesSVY[me.missile_index];
			me.missile_index += 1;
		} elsif (dl) {
			if (me.DLtrack_index >= maxDLTracks) return FALSE;
			me.echo = me.DLtracks[me.DLtrack_index];
			me.echoSVY = me.DLtracksSVY[me.DLtrack_index];
			me.DLtrack_index += 1;
		} else {
			if (me.track_index >= maxTracks) return FALSE;
			me.echo = me.tracks[me.track_index];
			me.echoSVY = me.tracksSVY[me.track_index];
			me.track_index += 1;
		}

		me.on_svy = (me.SVYactive and me.menuMain != MAIN_MISSION_DATA);

		# Placement
		me.echo.grp.setTranslation(me.pos_xx, me.pos_yy);
		me.echo.grp.setRotation(me.relHeading * D2R);
		me.echo.vector.setScale(1, clamp(me.tgtSpeed/60.0*NM2M*M2TEX, 1, 750*MM2TEX));
		me.echo.grp.show();

		if (me.on_svy) {
			# Compute sideview parameters
			me.altsvy = (me.tgtAlt + me.indicated_alt_offset_ft) * FT2M;
			me.distsvy = me.ac_pos.distance_to(me.coord);
			me.anglesvy = me.ac_pos.course_to(me.coord) - me.ind_head_true;
			me.center_angle = me.SVYinclude == SVY_RR ? radar.ps46.getDeviation() : 0;
			me.angle_limit = me.SVYinclude == SVY_RR ? radar.ps46.getAzimuthRadius() : me.SVYinclude == SVY_120 ? 60 : 180;
			# Check if it should really be displayed
			me.on_svy = me.altsvy >= 0 and me.altsvy <= me.SVYalt
				and me.distsvy <= me.SVYrange
				and abs(geo.normdeg180(me.anglesvy - me.center_angle)) <= me.angle_limit;
		}
		if (me.on_svy) {
			# Display on sideview
			me.pos_xxx = me.SVYoriginX+me.SVYwidth*me.distsvy/me.SVYrange;
			me.pos_yyy = me.SVYoriginY-me.SVYheight*me.altsvy/me.SVYalt;
			me.echoSVY.grp.setTranslation(me.pos_xxx, me.pos_yyy);
			me.rot = (math.abs(geo.normdeg180(me.relHeading)) > 90) ? -90 : 90;
			me.echoSVY.grp.setRotation(me.rot * D2R);
			# Vector scale is the same as on the horizontal view, regardless of sideview scale
			me.echoSVY.vector.setScale(1, clamp(me.tgtSpeed/60.0*NM2M*M2TEX, 1, 750*MM2TEX));

			me.echoSVY.grp.show();
		} else {
			me.echoSVY.grp.hide();
		}

		if (!missile and me.menuMain != MAIN_MISSION_DATA and me.cursorTrigger and !me.cursorDidSomething) {
			me.cursorDist = 100;
			if (me.isCursorOnMap()) {
				# not in MSDA so check if cursor is clicking on the aircraft
				me.cursorDistX = me.cursorOPosX-me.pos_xx;
				me.cursorDistY = me.cursorOPosY-me.pos_yy;
				me.cursorDist = math.sqrt(me.cursorDistX*me.cursorDistX+me.cursorDistY*me.cursorDistY);
			} elsif (me.on_svy and me.isCursorOnSVY()) {
				me.cursorDistX = me.cursorGPosX-me.pos_xxx;
				me.cursorDistY = me.cursorGPosY-me.pos_yyy;
				me.cursorDist = math.sqrt(me.cursorDistX*me.cursorDistX+me.cursorDistY*me.cursorDistY);
			}
			if (me.cursorDist < 10) {
				displays.common.setTISelection(contact, dl ? displays.TI_SEL_DL : displays.TI_SEL_RADAR);
				me.cursorTriggerPrev = TRUE;#a hack. It CAN happen that a contact gets selected through infobox, in that case lets make sure infobox is not activated. bad UI fix. :(
				me.cursorDidSomething = TRUE;
			}
		}

		if (contact == displays.common.ti_selection) {
			me.rrSymbol.setTranslation(me.pos_xx, me.pos_yy);
			me.rrSymbol.setRotation(me.relHeading * D2R);
			me.rrSymbol.show();
			# adjust symbol position. Radar symbols are centered on aircraft, DL are behind.
			me.rrSymbol2.setTranslation(0, dl ? 7.5 : 0);
			me.sel_updated = TRUE;
			# update DL / radar type
			displays.common.ti_sel_type = dl ? displays.TI_SEL_DL : displays.TI_SEL_RADAR;
		}

		# Symbols
		if (missile) return TRUE; # nothing to do

		# datalink information (check even if this is not from the datalink list)
		if (contact["dl_known"]) {
			me.dl_connected = contact.dl_connected;
			me.dl_iff = contact.dl_iff;
			me.dl_ident = contact.dl_ident;
		} else {
			me.dl_connected = FALSE;
			me.dl_iff = 0;
			me.dl_ident = nil;
		}

		if (dl) {
			me.iff = me.dl_iff;

			me.echo.datalink.setVisible(me.dl_connected);
			me.echo.dl_tgt.setVisible(!me.dl_connected);

			if (me.on_svy) {
				me.echoSVY.datalink.setVisible(me.dl_connected);
				me.echoSVY.dl_tgt.setVisible(!me.dl_connected);
			}
		} else {
			me.primary = radar.ps46.isPrimary(contact);
			me.iff = radar.stored_iff(contact);
			# combine self and datalink iff info
			if (me.dl_iff > 0) me.iff = 1;
			elsif (me.dl_iff < 0 and me.iff == 0) me.iff = -1;

			me.echo.primary.setVisible(me.primary);
			me.echo.secondary.setVisible(!me.primary);
			me.echo.friendly.setVisible(me.iff > 0);

			if (me.on_svy) {
				me.echoSVY.primary.setVisible(me.primary);
				me.echoSVY.secondary.setVisible(!me.primary);
				me.echoSVY.friendly.setVisible(me.iff > 0);
			}
		}

		me.color = me.iff > 0 ? COLOR_GREEN : me.iff < 0 ? COLOR_RED : COLOR_YELLOW;
		if (me.dl_ident == nil) me.dl_ident = "";

		me.echo.grp.setColor(me.color);
		me.echo.datalink_id.setText(me.dl_ident);

		if (me.on_svy) {
			me.echoSVY.grp.setColor(me.color);
			me.echoSVY.datalink_id.setText(me.dl_ident);
		}

		return TRUE;
	},

	showSelfVector: func {
		# length = time to travel in 60 seconds.
		me.spd = me.input.tas.getValue();# true airspeed so can be compared with other aircrafts speed. (should really be ground speed)
		me.selfVector.setScale(1, clamp((me.spd/60)*NM2M*M2TEX, 1, 750*MM2TEX));
		if (me.SVYactive == TRUE and me.menuMain != MAIN_MISSION_DATA) {
			# Vector scale is the same as on the horizontal view, regardless of sideview scale
			me.selfVectorSvy.setScale(clamp((me.spd/60)*NM2M*M2TEX, 1, 750*MM2TEX), 1);
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
	    if (displays.common.heading != nil) {
	    	me.myHdg  = me.input.heading.getValue();
	    	me.bugOffset = geo.normdeg180(displays.common.heading-me.myHdg);
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
		me.trapAll   = FALSE;
	},


	b1: func {
		edgeButtonsStruct[1] = me.input.timeElapsed.getValue();
		if (!me.active) {
			if (me.input.wow1.getValue() == 1) {
				displays.common.toggleJAdisplays(TRUE);
			} elsif (displays.common.ti_selection != nil) {
				displays.common.unsetTISelection();
			} elsif (modes.landing) {
				land.noMode();
			}
		} elsif (me.active and me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.active and me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
				dap.syst();
				if (me.input.wow1.getValue() == 1) {
					displays.common.toggleJAdisplays(FALSE);
				} elsif (displays.common.ti_selection != nil) {
					displays.common.unsetTISelection();
				} elsif (modes.landing) {
					land.noMode();
				}
			}
		}
	},

	b2: func {
		if (!me.active) return;
		edgeButtonsStruct[2] = me.input.timeElapsed.getValue();
		if (me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
				# toggle datalink / STRIL
				# real function is different
				# should be active in backup menu, but it would be strange for DL toggle
				dap.syst();
				me.input.datalink.setValue(!me.input.datalink.getBoolValue());
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
		edgeButtonsStruct[3] = me.input.timeElapsed.getValue();
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
		edgeButtonsStruct[4] = me.input.timeElapsed.getValue();
		if (!me.active) {
			modes.buttons.B();
			dap.syst();
		} elsif (me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
				#me.showSteers = !me.showSteers;
				modes.buttons.B();
				dap.syst();
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
			if (me.menuMain == MAIN_MISSION_DATA) {
				route.Polygon.setToggleBEEdit();
			}
		}
	},

	b5: func {
		if (!me.active) return;
		edgeButtonsStruct[5] = me.input.timeElapsed.getValue();
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
				dap.syst();
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
			#	route.Polygon.deleteSteerpoint();
			}
		}
	},

	b6: func {
		if (!me.active) return;
		edgeButtonsStruct[6] = me.input.timeElapsed.getValue();
		if (me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
				# tactical report
				dap.syst();
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
				zoomOut();
			}
			if (me.menuMain == MAIN_MISSION_DATA) {
				route.Polygon.setToggleAreaEdit();
				if (route.Polygon.editing != nil) {
					displays.common.setCursorDisplay(displays.TI);
				}
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
		edgeButtonsStruct[7] = me.input.timeElapsed.getValue();
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
		edgeButtonsStruct[8] = me.input.timeElapsed.getValue();
		if (!me.active) {
			fire_control.select_pylon(5);
		} elsif (me.menuShowMain == TRUE and me.menuMain != MAIN_WEAPONS) {
			me.menuMain = MAIN_WEAPONS;
			me.menuShowFast = TRUE;
			me.menuNoSub();
		} else {
			if (me.menuMain == MAIN_WEAPONS) {
				fire_control.select_pylon(5);
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
		edgeButtonsStruct[9] = me.input.timeElapsed.getValue();
		if (!me.active) {
			fire_control.select_pylon(1);
		} elsif (me.menuShowMain == TRUE and me.menuMain != MAIN_WEAPONS) {
			me.menuMain = MAIN_SYSTEMS;
			me.menuShowFast = TRUE;
			me.menuNoSub();
		} else {
			if (me.menuMain == MAIN_WEAPONS) {
				fire_control.select_pylon(1);
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
		edgeButtonsStruct[10] = me.input.timeElapsed.getValue();
		if (!me.active) {
			fire_control.select_pylon(2);
		} elsif (me.menuShowMain == TRUE and me.menuMain != MAIN_WEAPONS) {
			me.menuMain = MAIN_DISPLAY;
			me.menuShowFast = TRUE;
			me.menuNoSub();
		} else {
			if (me.menuMain == MAIN_WEAPONS) {
				fire_control.select_pylon(2);
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
		edgeButtonsStruct[11] = me.input.timeElapsed.getValue();
		if (!me.active) {
			fire_control.select_pylon(4);
		} elsif (me.menuShowMain == TRUE and me.menuMain != MAIN_WEAPONS) {
			me.menuMain = MAIN_MISSION_DATA;
			me.menuShowFast = TRUE;
			me.menuNoSub();
		} else {
			if (me.menuMain == MAIN_WEAPONS) {
				fire_control.select_pylon(4);
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
		edgeButtonsStruct[12] = me.input.timeElapsed.getValue();
		if (!me.active) {
			fire_control.select_pylon(3);
		} elsif (me.menuShowMain == TRUE and me.menuMain != MAIN_WEAPONS) {
			me.menuMain = MAIN_FAILURES;
			me.menuShowFast = TRUE;
			me.menuNoSub();
		} else {
			if (me.menuMain == MAIN_WEAPONS) {
				fire_control.select_pylon(3);
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
		edgeButtonsStruct[13] = me.input.timeElapsed.getValue();
		if (!me.active) {
			fire_control.select_pylon(6);
		} elsif (me.menuShowMain == TRUE and me.menuMain != MAIN_WEAPONS) {
			me.menuMain = MAIN_CONFIGURATION;
			me.menuShowFast = TRUE;
			me.menuNoSub();
		} else {
			if (me.menuMain == MAIN_WEAPONS) {
				fire_control.select_pylon(6);
			} else {
				me.menuShowMain = !me.menuShowMain;
				if (me.menuShowFast == TRUE) {
					me.menuMain = math.abs(me.menuMain);
				}
			}
		}
	},

	b14: func {
		edgeButtonsStruct[14] = me.input.timeElapsed.getValue();
		if (!me.active) {
			fire_control.select_cannon();
		} elsif (me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
			if (me.menuMain == MAIN_WEAPONS) {
				fire_control.select_cannon();
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
				dap.syst();
				me.ModeAttack = !me.ModeAttack;
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == TRUE) {
				# clear tact reports
				fire_control.fireLog.clear();
				me.logEvents.clear();
				me.logBIT.clear();
				me.logLand.clear();
				radar.lockLog.clear();
				radar.ecmLog.clear();
			}
			if (me.menuMain == MAIN_CONFIGURATION and me.menuGPS == TRUE) {
				# toggle GPS automatic fixes, not implemented
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
			if (me.menuMain == MAIN_MISSION_DATA) {
				if (route.Polygon.editing != route.Polygon.editRTB) {
					route.Polygon.editPlan(route.Polygon.editRTB);
					displays.common.setCursorDisplay(displays.TI);
				} else {
					route.Polygon.editPlan(nil);
				}
			}
		}
	},

	b15: func {
		edgeButtonsStruct[15] = me.input.timeElapsed.getValue();
		if (!me.active) {
			fire_control.deselect_weapon();
		} elsif (me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
			if (me.menuMain == MAIN_WEAPONS) {
				fire_control.deselect_weapon();
			}
			if (me.menuMain == MAIN_CONFIGURATION and me.menuGPS == TRUE) {
				setprop("ja37/avionics/gps-cmd", !getprop("ja37/avionics/gps-cmd"));
			}
			if (me.menuMain == MAIN_CONFIGURATION and me.menuSvy == TRUE) {
				me.SVYrmax += 1;
				if (me.SVYrmax > 3) {
					me.SVYrmax = 0;
				}
			}
			if (me.menuMain == MAIN_DISPLAY) {
				# show AAA threat circles
				me.showAAAZones = !me.showAAAZones;
			}
			if (me.menuMain == MAIN_MISSION_DATA) {
				route.Polygon.toggleEditRTB();
			}
		}
	},

	b16: func {
		if (!me.active) return;
		edgeButtonsStruct[16] = me.input.timeElapsed.getValue();
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
				me.SVYhmax += 1;
				if (me.SVYhmax > 3) {
					me.SVYhmax = 0;
				}
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
				dap.syst();
				route.Polygon.toggleFlyRTB();
			}
			if (me.menuMain == MAIN_MISSION_DATA) {
				if (route.Polygon.editing != route.Polygon.editMiss) {
					route.Polygon.editPlan(route.Polygon.editMiss);
					displays.common.setCursorDisplay(displays.TI);
				} else {
					route.Polygon.editPlan(nil);
				}
			}
		}
	},

	b17: func {
		edgeButtonsStruct[17] = me.input.timeElapsed.getValue();
		if (!me.active) {
			dap.syst();
			modes.buttons.LA();
		} elsif (me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
				dap.syst();
				modes.buttons.LA();
			} elsif (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == TRUE) {
				# tact reports (all of them)
				me.closeTraps();
				me.trapAll = TRUE;
				me.quickOpen = 10000;
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
		edgeButtonsStruct[18] = me.input.timeElapsed.getValue();
		if (!me.active) {
			dap.syst();
			modes.buttons.LF();
		} elsif (me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
			if(me.menuMain == MAIN_DISPLAY) {
				displays.common.toggleCursorDisplay();
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
				dap.syst();
				modes.buttons.LF();
			}
			if(me.menuMain == MAIN_MISSION_DATA) {
				route.Polygon.editSteerpoint();#toogle draggable steerpoints
			}
		}
	},

	b19: func {
		edgeButtonsStruct[19] = me.input.timeElapsed.getValue();
		if (!me.active) {
			dap.syst();
			modes.buttons.LB();
		} elsif (me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
			if(math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == TRUE and (me.trapFire == TRUE or me.trapAll == TRUE or me.trapMan == TRUE or me.trapLock == TRUE or me.trapECM == TRUE or me.trapLand  == TRUE)) {
				me.logPage += 1;
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
				dap.syst();
				modes.buttons.LB();
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
		edgeButtonsStruct[20] = me.input.timeElapsed.getValue();
		if (!me.active) {
			dap.syst();
			modes.buttons.L();
		} elsif (me.menuShowFast == FALSE and me.menuShowMain == FALSE) {
			me.openQuickMenu();
		} elsif (me.menuShowFast == TRUE) {
			if (me.menuShowMain == FALSE) {
				me.quickTimer = me.input.timeElapsed.getValue();
				me.quickOpen = 3;
			}
			if(math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == TRUE and (me.trapFire == TRUE or me.trapAll == TRUE or me.trapMan == TRUE or me.trapLock == TRUE or me.trapECM == TRUE or me.trapLand == TRUE)) {
				me.logPage -= 1;
				if (me.logPage < 0) {
					me.logPage = 0;
				}
			}
			if (math.abs(me.menuMain) == MAIN_SYSTEMS and me.menuTrap == FALSE) {
				dap.syst();
				modes.buttons.L();
			}
			if(me.menuMain == MAIN_MISSION_DATA) {
				me.dragMapEnabled = !me.dragMapEnabled;
				me.mapSelfCentered = !me.dragMapEnabled;
				if (!me.mapSelfCentered) {
					me.lat = me.lat_own;
					me.lon = me.lon_own;
					me.setupMMAP();
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
		    	tiles[x][y] = me.mapFinal.createChild("image", "map-tile").set("z-index", 15);
		    	if (me.day == TRUE) {
		    		tiles[x][y].set("fill", COLOR_DAY);
	    		} else {
	    			tiles[x][y].set("fill", COLOR_NIGHT);
	    		}
	    	}
		}
	},

	whereIsMap: func {
		# update the map position
		me.lat_own = me.input.latitude.getValue();
		me.lon_own = me.input.longitude.getValue();
		if (me.menuMain != MAIN_MISSION_DATA or me.mapSelfCentered) {
			# get current position
			me.lat = me.lat_own;
			me.lon = me.lon_own;# TODO: USE GPS/INS here.
		}		
		M2TEX = 1/(meterPerPixel[zoom]*math.cos(me.lat*D2R));
	},

	updateMap: func {
		# update the map
		if (lastDay != me.day)  {
			me.setupMap();
		}
		me.rootCenterY = height*0.875-(height*0.875)*me.ownPosition;
		if (!me.mapSelfCentered) {
			me.lat_wp   = me.input.latitude.getValue();
			me.lon_wp   = me.input.longitude.getValue();
			me.tempReal = me.laloToTexel(me.lat,me.lon);
			me.rootCenter.setTranslation(width/2-me.tempReal[0], me.rootCenterY-me.tempReal[1]);
			#me.rootCenterTranslation = [width/2-me.tempReal[0], me.rootCenterY-me.tempReal[1]];
		} else {
			me.tempReal = [0,0];
			me.rootCenter.setTranslation(width/2, me.rootCenterY);
			#me.rootCenterTranslation = [width/2, me.rootCenterY];
		}
		me.mapCentrum.setTranslation(width/2, me.rootCenterY);

		me.n = math.pow(2, zoom);
		me.center_tile_float = [
			me.n * ((me.lon + 180) / 360),
			(1 - math.ln(math.tan(me.lat * D2R) + 1 / math.cos(me.lat * D2R)) / math.pi) / 2 * me.n
		];
		# center_tile_offset[1]
		me.center_tile_int = [math.floor(me.center_tile_float[0]), math.floor(me.center_tile_float[1])];

		me.center_tile_fraction_x = me.center_tile_float[0] - me.center_tile_int[0];
		me.center_tile_fraction_y = me.center_tile_float[1] - me.center_tile_int[1];
		#printf("centertile: %d,%d fraction %.2f,%.2f",me.center_tile_int[0],me.center_tile_int[1],me.center_tile_fraction_x,me.center_tile_fraction_y);
		me.tile_offset = [math.floor(num_tiles[0]/2), math.floor(num_tiles[1]/2)];

		# 3x3 example: (same for both canvas-tiles and map-tiles)
		#  *************************
		#  * -1,-1 *  0,-1 *  1,-1 *
		#  *************************
		#  * -1, 0 *  0, 0 *  1, 0 *
		#  *************************
		#  * -1, 1 *  0, 1 *  1, 1 *
		#  *************************
		#
		# x goes from -180 lon to +180 lon (zero to me.n)
		# y goes from +85.0511 lat to -85.0511 lat (zero to me.n)
		#
		# me.center_tile_float is always positives, it denotes where we are in x,y (floating points)
		# me.center_tile_int is the x,y tile that we are in (integers)
		# me.center_tile_fraction is where in that tile we are located (normalized)
		# me.tile_offset is the negative buffer so that we show tiles all around us instead of only in x,y positive direction

		for(var xxx = 0; xxx < num_tiles[0]; xxx += 1) {
			for(var yyy = 0; yyy < num_tiles[1]; yyy += 1) {
				tiles[xxx][yyy].setTranslation(-math.floor((me.center_tile_fraction_x - xxx+me.tile_offset[0]) * tile_size), -math.floor((me.center_tile_fraction_y - yyy+me.tile_offset[1]) * tile_size));
			}
		}

		me.liveMap = getprop("ja37/displays/live-map");
		me.zoomed = zoom != last_zoom;
		if(me.center_tile_int[0] != last_tile[0] or me.center_tile_int[1] != last_tile[1] or type != last_type or me.zoomed or me.liveMap != lastLiveMap or lastDay != me.day)  {
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
					    #logprint(LOG_DEBUG, 'showing ' ~ img_path);
					    if( io.stat(img_path) == nil and me.liveMap == TRUE) { # image not found, save in $FG_HOME
					      	var img_url = makeUrl(pos);
					      	#logprint(LOG_DEBUG, 'requesting ' ~ img_url);
					      	http.save(img_url, img_path)
					      		.done(func(r) {
					      	  		#logprint(LOG_DEBUG, 'received image ' ~ me.img_path~" " ~ r.status ~ " " ~ r.reason);
					      	  		#logprint(LOG_DEBUG, str(io.stat(me.img_path) != nil));
					      	  		tile.set("src", img_path);# this sometimes fails with: 'Cannot find image file' if use me. instead of var.
					      	  		tile.update();
					      	  		})
					          #.done(func {logprint(LOG_DEBUG, 'received image ' ~ img_path); tile.set("src", img_path);})
					          .fail(func (r) {#logprint(LOG_DEBUG, 'Failed to get image ' ~ img_path ~ ' ' ~ r.status ~ ': ' ~ r.reason);
					          				tile.set("src", "Aircraft/JA37/Models/Cockpit/TI/emptyTile.png");
					      					tile.update();
					      					});
					    } elsif (io.stat(img_path) != nil) {# cached image found, reusing
					      	#logprint(LOG_DEBUG, 'loading ' ~ me.img_path);
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

		me.mapCenter.setRotation(-me.input.heading.getValue()*D2R);
		#switched to direct rotation to try and solve issue with approach line not updating fast.
		me.mapCenter.update();
	},
};

var ti = nil;
var init = func {
	removelistener(idl); # only call once
	setupCanvas();
	ti = TI.new();
	settimer(func {
		ti.loop();#must be first due to me.rootCenterY
		ti.loopFast();
		ti.loopSlow();
	},0.5);# this will prevent it from starting before route has been initialized.
}

#idl = setlistener("ja37/supported/initialized", init, 0, 0);

var MapStructure_selfTest = func() {
	var temp = {};
	temp.dlg = canvas.Window.new([600,400],"dialog");
	temp.canvas = temp.dlg.createCanvas().setColorBackground(1,1,1,1);
	temp.root = temp.canvas.createGroup();
	var TestMap = temp.root.createChild("map");
	TestMap.setController("Aircraft position");
	TestMap.setRange(50); # TODO: implement zooming/panning via mouse/wheel here, for lack of buttons :-/
	TestMap.setTranslation(
		temp.canvas.get("view[0]")/2,
		temp.canvas.get("view[1]")/2
	);
	var r = func(name,vis=1,zindex=nil) return caller(0)[0];
	# TODO: we'll need some z-indexing here, right now it's just random
	# TODO: use foreach/keys to show all layers in this case by traversing SymbolLayer.registry direclty ?
	# maybe encode implicit z-indexing for each lcontroller ctor call ? - i.e. preferred above/below order ?
#	foreach(var type; [r('TFC',0),r('APT'),r('DME'),r('VOR'),r('NDB'),r('FIX',0),r('RTE'),r('WPT'),r('FLT'),r('WXR'),r('APS'), ] )
#		TestMap.addLayer(factory: canvas.SymbolLayer, type_arg: type.name,
#					visible: type.vis, priority: type.zindex,
#		);
	foreach(var type; [ r('SLIPPY')]) {
			TestMap.addLayer(factory: canvas.OverlayLayer, type_arg: type.name,
											 visible: type.vis, priority: type.zindex
											  );
	}
};

#MapStructure_selfTest();
