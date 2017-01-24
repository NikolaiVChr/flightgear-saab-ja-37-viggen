# ==============================================================================
# Head up display
#
# Nicked some code from the buccaneer and the wiki example to get started
#
# Made for the JA-37 by Necolatis
# ==============================================================================

var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }
var pow2 = func(x) { return x * x; };
var vec_length = func(x, y) { return math.sqrt(pow2(x) + pow2(y)); };
var round0 = func(x) { return math.abs(x) > 0.01 ? x : 0; };
var roundabout = func(x) {
  var y = x - int(x);
  return y < 0.5 ? int(x) : 1 + int(x) ;
};
var deg2rads = math.pi/180.0;
var rad2deg = 180.0/math.pi;
var kts2kmh = 1.852;
var feet2meter = 0.3048;

var alt_scale_mode = -1; # the alt scale is not linear, this indicates which part is showed

var FALSE = 0;
var TRUE = 1;

var on_backup_power = FALSE;

var TAKEOFF = 0;
var NAV = 1;
var COMBAT =2;
var LANDING = 3;

var mode = TAKEOFF;
var modeTimeTakeoff = -1;

var air2air = FALSE;
var air2ground = FALSE;

var skip = FALSE;

# -100 - 0 : not blinking
# 1 - 10   : blinking
# 11 - 125 : steady on
var countQFE = 0;
var QFEcalibrated = FALSE;# if the altimeters are calibrated

var HUDTop = 0.77; # position of top of HUD in meters. 0.77
var HUDBottom = 0.63; # position of bottom of HUD in meters. 0.63
#var HUDHoriz = -4.0; # position of HUD on x axis in meters. -4.0
var HUDHoriz = -4.06203;#pintos new hud
var HUDHeight = HUDTop - HUDBottom; # height of HUD
var canvasWidth = 256;
var max_width = (450/1024)*canvasWidth;
# HUD z is 0.63 - 0.77. Height of HUD is 0.14m
# Therefore each pixel is 0.14 / 1024 = 0.00013671875m or each meter is 7314.2857142857142857142857142857 pixels.
var pixelPerMeter = canvasWidth / HUDHeight;
var centerOffset = -1 * (canvasWidth/2 - ((HUDTop - getprop("sim/view[0]/config/y-offset-m"))*pixelPerMeter));#pilot eye position up from vertical center of HUD. (in line from pilots eyes)
# View is 0.71m so 0.77-0.71 = 0.06m down from top of HUD, since Y in HUD increases downwards we get pixels from top:
# 512 - (0.06 / 0.00013671875) = 73.142857142857142857142857142857 pixels up from center. Since -y is upward, result is -73.1. (Per default)


# Since the HUD is not curved, we have to choose an avarage degree where degree per pixel is calculated from. 7.5 is chosen.
var pixelPerDegreeY = pixelPerMeter*(((getprop("sim/view[0]/config/z-offset-m") - HUDHoriz) * math.tan(7.5*deg2rads))/7.5); 
var pixelPerDegreeX = pixelPerDegreeY; #horizontal axis
#var slant = 35; #degrees the HUD is slanted away from the pilot.
var distScalePos = 160;
var sidewindPosition = centerOffset+(10*pixelPerDegreeY); #should be 10 degrees under aicraft axis.
var sidewindPerKnot = max_width/30; # Max sidewind displayed is set at 30 kts. 450pixels is maximum is can move to the side.
var radPointerProxim = (60/1024)*canvasWidth; #when alt indicater is too close to radar ground indicator, hide indicator
var scalePlace = (200/1024)*canvasWidth; #horizontal placement of alt scales
var numberOffset = (100/1024)*canvasWidth; #alt scale numbers horizontal offset from scale 
var indicatorOffset = -(10/1024)*canvasWidth; #alt scale indicators horizontal offset from scale (must be high, due to bug #1054 in canvas) 
var headScalePlace = (350/1024)*canvasWidth; # vert placement of heading scale, remember to change clip also.
var headScaleTickSpacing = (65/1024)*canvasWidth;# horizontal spacing between ticks. Remember to adjust bounding box when changing.
var altimeterScaleHeight = (225/1024)*canvasWidth; # the height of the low alt scale. Also used in the other scales as a reference height.
var reticle_factor = 1.3;# size of flight path indicator, aiming reticle, and out of ammo reticle
var sidewind_factor = 1.0;# size of sidewind indicator
var airspeedPlace = (420/1024)*canvasWidth;
var airspeedPlaceFinal = -(100/1024)*canvasWidth;
var sideslipPlaceX = (325/1024)*canvasWidth;
var sideslipPlaceY = (425/1024)*canvasWidth;
var sideslipPlaceXFinal = 0;
var sideslipPlaceYFinal = 0;
var missile_aim_position = centerOffset+0.03*pixelPerMeter;
var QFE_position = centerOffset+(5.5*pixelPerDegreeY);
var dig_alt_position = centerOffset+(9.0*pixelPerDegreeY);
var r = 0.6;#HUD colors
var g = 1.0;
var b = 0.6;
var a = 1.0;
var w = (getprop("ja37/hud/stroke-linewidth")/1024)*canvasWidth;  #line stroke width (saved between sessions)
var ar = 1.0;#font aspect ratio, less than 1 make more wide.
var fs = 0.8;#font size factor
var artifacts0 = nil;
var artifacts1 = [];
var artifactsText1 = [];
var artifactsText0 = nil;
var maxTracks = 32;# how many radar tracks can be shown at once in the HUD (was 16)
var diamond_node = nil;

var HUDnasal = {
  canvas_settings: {
    "name": "HUDnasal",
    "size": [canvasWidth, canvasWidth],# size of the texture
    "view": [canvasWidth, canvasWidth],# size of canvas coordinate system
    "mipmapping": 0
  },
  main: nil,

  #tracking variables
  self: nil,
  myPitch: nil,
  myRoll: nil,
  groundAlt: nil,
  myHeading: nil,
  short_dist: nil,
  track_index: nil,

  redraw: func() {
    #HUDnasal.main.canvas.del();
    #HUDnasal.main.canvas = canvas.new(HUDnasal.canvas_settings);
    HUDnasal.inter = FALSE;
    HUDnasal.main.canvas.addPlacement(HUDnasal.main.place);
    HUDnasal.main.canvas.setColorBackground(0.36, g, 0.3, 0.025);
    HUDnasal.main.root = HUDnasal.main.canvas.createGroup()
                .set("font", "LiberationFonts/LiberationMono-Regular.ttf");# If using default font, horizontal alignment is not accurate (bug #1054), also prettier char spacing. 
    
    #HUDnasal.main.root.setScale(math.sin(slant*deg2rads), 1);
    HUDnasal.main.root.setTranslation(canvasWidth/2, canvasWidth/2);

    # digital airspeed kts/mach 
    HUDnasal.main.airspeed = HUDnasal.main.root.createChild("text")
      .setText("000")
      .setFontSize((85/1024)*canvasWidth*fs, ar)
      .setColor(r,g,b, a)
      .setAlignment("center-center")
      .setTranslation(0 , airspeedPlace);
    HUDnasal.main.airspeedInt = HUDnasal.main.root.createChild("text")
      .setText("000")
      .setFontSize((85/1024)*canvasWidth*fs, ar)
      .setColor(r,g,b, a)
      .setAlignment("center-center")
      .setTranslation(0 , airspeedPlace-(70/1024)*canvasWidth);


    # scale heading ticks
    var clip = (12/1024)*canvasWidth~"px, "~(687/1024)*canvasWidth~"px, "~(212/1024)*canvasWidth~"px, "~(337/1024)*canvasWidth~"px";
    HUDnasal.main.head_scale_grp = HUDnasal.main.root.createChild("group");
    HUDnasal.main.head_scale_grp.set("clip", "rect("~clip~")");#top,right,bottom,left
    HUDnasal.main.head_scale_grp_trans = HUDnasal.main.head_scale_grp.createTransform();
    HUDnasal.main.head_scale = HUDnasal.main.head_scale_grp.createChild("path")
        .moveTo(-headScaleTickSpacing*2, 0)
        .vert(-(60/1024)*canvasWidth)
        .moveTo(0, 0)
        .vert(-(60/1024)*canvasWidth)
        .moveTo(headScaleTickSpacing*2, 0)
        .vert(-(60/1024)*canvasWidth)
        .moveTo(-headScaleTickSpacing, 0)
        .vert(-(40/1024)*canvasWidth)
        .moveTo(headScaleTickSpacing, 0)
        .vert(-(40/1024)*canvasWidth)
        .setStrokeLineWidth(w)
        .setColor(r,g,b, a)
        .show();

        #heading bug
    HUDnasal.main.heading_bug_group = HUDnasal.main.root.createChild("group");
    #HUDnasal.main.heading_bug_group.set("clip", "rect(62px, 687px, 262px, 337px)");#top,right,bottom,left
    HUDnasal.main.heading_bug = HUDnasal.main.heading_bug_group.createChild("path")
    .setColor(r,g,b, a)
    .setStrokeLineCap("round")
    .setStrokeLineWidth(w)
    .moveTo( 0,  (10/1024)*canvasWidth)
    .lineTo( 0,  (55/1024)*canvasWidth)
    .moveTo( (15/1024)*canvasWidth, (55/1024)*canvasWidth)
    .lineTo( (15/1024)*canvasWidth, (25/1024)*canvasWidth)
    .moveTo(-(15/1024)*canvasWidth, (55/1024)*canvasWidth)
    .lineTo(-(15/1024)*canvasWidth, (25/1024)*canvasWidth);

    # scale heading end ticks
    HUDnasal.main.hdgLineL = HUDnasal.main.head_scale_grp.createChild("path")
    .setStrokeLineWidth(w)
      .setColor(r,g,b, a)
      .moveTo(-headScaleTickSpacing*3, 0)
      .vert(-(40/1024)*canvasWidth)
      .close();

    HUDnasal.main.hdgLineR = HUDnasal.main.head_scale_grp.createChild("path")
    .setStrokeLineWidth(w)
      .setColor(r,g,b, a)
      .moveTo(headScaleTickSpacing*3, 0)
      .vert(-(40/1024)*canvasWidth)
      .close();

    # headingindicator
    HUDnasal.main.head_scale_indicator = HUDnasal.main.root.createChild("path")
    .setColor(r,g,b, a)
    .setStrokeLineCap("round")
    .setStrokeLineWidth(w)
    .moveTo(-(30/1024)*canvasWidth, -headScalePlace+(30/1024)*canvasWidth)
    .lineTo(0, -headScalePlace)
    .lineTo((30/1024)*canvasWidth, -headScalePlace+(30/1024)*canvasWidth);

    # Heading middle number
    HUDnasal.main.hdgM = HUDnasal.main.head_scale_grp.createChild("text");
    HUDnasal.main.hdgM.setColor(r,g,b, a);
    HUDnasal.main.hdgM.setAlignment("center-bottom");
    HUDnasal.main.hdgM.setFontSize((65/1024)*canvasWidth*fs, ar);

    # Heading left number
    HUDnasal.main.hdgL = HUDnasal.main.head_scale_grp.createChild("text");
    HUDnasal.main.hdgL.setColor(r,g,b, a);
    HUDnasal.main.hdgL.setAlignment("center-bottom");
    HUDnasal.main.hdgL.setFontSize((65/1024)*canvasWidth*fs, ar);

    # Heading right number
    HUDnasal.main.hdgR = HUDnasal.main.head_scale_grp.createChild("text");
    HUDnasal.main.hdgR.setColor(r,g,b, a);
    HUDnasal.main.hdgR.setAlignment("center-bottom");
    HUDnasal.main.hdgR.setFontSize((65/1024)*canvasWidth*fs, ar);

    # Altitude
    clip = (200/1024)*canvasWidth~"px, "~(1800/1024)*canvasWidth~"px, "~(824/1024)*canvasWidth~"px, "~(0/1024)*canvasWidth~"px";
    HUDnasal.main.alt_scale_grp=HUDnasal.main.root.createChild("group")
      .set("clip", "rect("~clip~")");#top,right,bottom,left
    HUDnasal.main.alt_scale_grp_trans = HUDnasal.main.alt_scale_grp.createTransform();

    # alt scale high
    HUDnasal.main.alt_scale_high=HUDnasal.main.alt_scale_grp.createChild("path")
      .moveTo(0, -6*altimeterScaleHeight/2)
      .horiz((75/1024)*canvasWidth)
      .moveTo(0, -5*altimeterScaleHeight/2)
      .horiz((50/1024)*canvasWidth)
      .moveTo(0, -2*altimeterScaleHeight)
      .horiz((75/1024)*canvasWidth)
      .moveTo(0, -3*altimeterScaleHeight/2)
      .horiz((50/1024)*canvasWidth)
      .moveTo(0, -altimeterScaleHeight)
      .horiz((75/1024)*canvasWidth)
      .moveTo(0, -altimeterScaleHeight/2)
      .horiz((50/1024)*canvasWidth)
      .moveTo(0, 0)
      .horiz((75/1024)*canvasWidth)
      .setStrokeLineWidth(w)
      .setColor(r,g,b, a)
      .show();



    # alt scale medium
    HUDnasal.main.alt_scale_med=HUDnasal.main.alt_scale_grp.createChild("path")
      .moveTo(0, -5*altimeterScaleHeight/2)
      .horiz((50/1024)*canvasWidth)
      .moveTo(0, -2*altimeterScaleHeight)
      .horiz((75/1024)*canvasWidth)
      .moveTo(0, -3*altimeterScaleHeight/2)
      .horiz((50/1024)*canvasWidth)
      .moveTo(0, -altimeterScaleHeight)
      .horiz((75/1024)*canvasWidth)
      .moveTo(0, -4*altimeterScaleHeight/5)
      .horiz((25/1024)*canvasWidth)
      .moveTo(0, -3*altimeterScaleHeight/5)
      .horiz((25/1024)*canvasWidth)           
      .moveTo(0, -2*altimeterScaleHeight/5)
      .horiz((25/1024)*canvasWidth)
      .moveTo(0, -1*altimeterScaleHeight/5)
      .horiz((25/1024)*canvasWidth)           
      .moveTo(0, 0)
      .horiz((75/1024)*canvasWidth)
      .setStrokeLineWidth(w)
      .setColor(r,g,b, a)
      .show();

    # alt scale low
    HUDnasal.main.alt_scale_low = HUDnasal.main.alt_scale_grp.createChild("path")
      .moveTo(0, -7*altimeterScaleHeight/4)
      .horiz((50/1024)*canvasWidth)
      .moveTo(0, -6*altimeterScaleHeight/4)
      .horiz((75/1024)*canvasWidth)
      .moveTo(0, -5*altimeterScaleHeight/4)
      .horiz((50/1024)*canvasWidth)
      .moveTo(0, -altimeterScaleHeight)
      .horiz((75/1024)*canvasWidth)
      .moveTo(0,-4*altimeterScaleHeight/5)
      .horiz((25/1024)*canvasWidth)
      .moveTo(0, -3*altimeterScaleHeight/5)
      .horiz((25/1024)*canvasWidth)
      .moveTo(0, -2*altimeterScaleHeight/5)
      .horiz((25/1024)*canvasWidth)           
      .moveTo(0,-1*altimeterScaleHeight/5)
      .horiz((25/1024)*canvasWidth)
      .moveTo(0, 0)
      .horiz((75/1024)*canvasWidth)
      .setStrokeLineWidth(w)
      .setColor(r,g,b, a)
      .show();


      
    # vert line at zero alt if it is lower than radar zero
      HUDnasal.main.alt_scale_line = HUDnasal.main.alt_scale_grp.createChild("path")
      .moveTo(0, (30/1024)*canvasWidth)
      .vert(-(60/1024)*canvasWidth)
      .setStrokeLineWidth(w)
      .setColor(r,g,b, a);
    # low alt number
    HUDnasal.main.alt_low = HUDnasal.main.alt_scale_grp.createChild("text")
      .setText(".")
      .setFontSize((75/1024)*canvasWidth*fs, ar)
      .setColor(r,g,b, a)
      .setAlignment("left-center")
      .setTranslation(1, 0);
    # middle alt number 
    HUDnasal.main.alt_med = HUDnasal.main.alt_scale_grp.createChild("text")
      .setText(".")
      .setFontSize((75/1024)*canvasWidth*fs, ar)
      .setColor(r,g,b, a)
      .setAlignment("left-center")
      .setTranslation(1, 0);
    # high alt number      
    HUDnasal.main.alt_high = HUDnasal.main.alt_scale_grp.createChild("text")
      .setText(".")
      .setFontSize((75/1024)*canvasWidth*fs, ar)
      .setColor(r,g,b, a)
      .setAlignment("left-center")
      .setTranslation(1, 0);

    # higher alt number     
    HUDnasal.main.alt_higher = HUDnasal.main.alt_scale_grp.createChild("text")
      .setText(".")
      .setFontSize((75/1024)*canvasWidth*fs, ar)
      .setColor(r,g,b, a)
      .setAlignment("left-center")
      .setTranslation(1, 0);
    # alt scale indicator
    HUDnasal.main.alt_pointer = HUDnasal.main.root.createChild("path")
      .setColor(r,g,b, a)
      .setStrokeLineCap("round")
      .setStrokeLineWidth(w)
      .moveTo(0,0)
      .lineTo(-(45/1024)*canvasWidth,-(45/1024)*canvasWidth)
      .moveTo(0,0)
      .lineTo(-(45/1024)*canvasWidth, (45/1024)*canvasWidth)
      .setTranslation(scalePlace+indicatorOffset, 0);
    # alt scale radar ground indicator
    HUDnasal.main.rad_alt_pointer = HUDnasal.main.alt_scale_grp.createChild("path")
      .setColor(r,g,b, a)
      .setStrokeLineCap("round")
      .setStrokeLineWidth(w)
      .moveTo(0,0)
      .lineTo(-(60/1024)*canvasWidth,0)
      .moveTo(0,0)
      .lineTo(-(30/1024)*canvasWidth,(50/1024)*canvasWidth)
      .moveTo(-(30/1024)*canvasWidth,0)
      .lineTo(-(60/1024)*canvasWidth,(50/1024)*canvasWidth);
    
    # QFE warning (inhg not properly set / is being adjusted)
    HUDnasal.main.qfe = HUDnasal.main.root.createChild("text");
    HUDnasal.main.qfe.setText("QFE");
    HUDnasal.main.qfe.hide();
    HUDnasal.main.qfe.setColor(r,g,b, a);
    HUDnasal.main.qfe.setAlignment("center-center");
    HUDnasal.main.qfe.setTranslation(-(365/1024)*canvasWidth, QFE_position);
    HUDnasal.main.qfe.setFontSize((80/1024)*canvasWidth*fs, ar);

    # Altitude number (Not shown in landing/takeoff mode. Radar at less than 100 feet)
    HUDnasal.main.alt = HUDnasal.main.root.createChild("text");
    HUDnasal.main.alt.setColor(r,g,b, a);
    HUDnasal.main.alt.setAlignment("center-center");
    HUDnasal.main.alt.setTranslation(-(375/1024)*canvasWidth, dig_alt_position);
    HUDnasal.main.alt.setFontSize((85/1024)*canvasWidth*fs, ar);

    # Collision warning arrow
    HUDnasal.main.arrow_group = HUDnasal.main.root.createChild("group");  
    HUDnasal.main.arrow_trans   = HUDnasal.main.arrow_group.createTransform();
    HUDnasal.main.arrow =
      HUDnasal.main.arrow_group.createChild("path")
      .setColor(r,g,b, a)
      .moveTo(-(15/1024)*canvasWidth,  (90/1024)*canvasWidth)
      .lineTo(-(15/1024)*canvasWidth, -(90/1024)*canvasWidth)
      .lineTo(-(30/1024)*canvasWidth, -(90/1024)*canvasWidth)
      .lineTo(  0, -(120/1024)*canvasWidth)
      .lineTo( (30/1024)*canvasWidth, -(90/1024)*canvasWidth)
      .lineTo( (15/1024)*canvasWidth, -(90/1024)*canvasWidth)
      .lineTo( (15/1024)*canvasWidth,  (90/1024)*canvasWidth)
      .setStrokeLineCap("round")
      .setStrokeLineWidth(w);

    # Cannon aiming reticle
    HUDnasal.main.reticle_cannon =
      HUDnasal.main.root.createChild("path")
      .setColor(r,g,b, a)
      .moveTo(-(15/1024)*canvasWidth*reticle_factor, 0)
      .lineTo((15/1024)*canvasWidth*reticle_factor, 0)
      .moveTo(0, -(15/1024)*canvasWidth*reticle_factor)
      .lineTo(0,  (15/1024)*canvasWidth*reticle_factor)
      .setStrokeLineCap("round")
      .setStrokeLineWidth(w);
    # a2a Missile aiming circle
    HUDnasal.main.reticle_missile =
      HUDnasal.main.root.createChild("path")
      .setColor(r,g,b, a)
      .moveTo( (200/1024)*canvasWidth, missile_aim_position)
      .arcSmallCW((200/1024)*canvasWidth,(200/1024)*canvasWidth, 0, -(400/1024)*canvasWidth, 0)
      .arcSmallCW((200/1024)*canvasWidth,(200/1024)*canvasWidth, 0,  (400/1024)*canvasWidth, 0)
      .setStrokeLineCap("round")
      .setStrokeLineWidth(w);
    # a2g Missile aiming circle
    HUDnasal.main.reticle_c_missile =
      HUDnasal.main.root.createChild("path")
      .setColor(r,g,b, a)
      .moveTo( (150/1024)*canvasWidth, missile_aim_position-(75/1024)*canvasWidth)
      .lineTo( (150/1024)*canvasWidth, missile_aim_position+(75/1024)*canvasWidth)
      .moveTo( (-150/1024)*canvasWidth, missile_aim_position-(75/1024)*canvasWidth)
      .lineTo( (-150/1024)*canvasWidth, missile_aim_position+(75/1024)*canvasWidth)
      .setStrokeLineWidth(w);      
    # Out of ammo flight path indicator
    HUDnasal.main.reticle_no_ammo =
      HUDnasal.main.root.createChild("path")
      .setColor(r,g,b, a)
      .moveTo(-(45/1024)*canvasWidth*reticle_factor, 0) # draw this symbol in flight when no weapons selected (always as for now)
      .lineTo(-(15/1024)*canvasWidth*reticle_factor, 0)
      .lineTo(0, (15/1024)*canvasWidth*reticle_factor)
      .lineTo((15/1024)*canvasWidth*reticle_factor, 0)
      .lineTo((45/1024)*canvasWidth*reticle_factor, 0)
      .setStrokeLineCap("round")
      .setStrokeLineWidth(w);
    # sidewind symbol
    HUDnasal.main.takeoff_symbol = HUDnasal.main.root.createChild("path")
      .moveTo((105/1024)*canvasWidth*sidewind_factor, 0)
      .lineTo((75/1024)*canvasWidth*sidewind_factor, 0)
      .moveTo((45/1024)*canvasWidth*sidewind_factor, 0)
      .lineTo((15/1024)*canvasWidth*sidewind_factor, 0)
      .arcSmallCCW((15/1024)*canvasWidth*sidewind_factor, (15/1024)*canvasWidth*sidewind_factor, 0, -(30/1024)*canvasWidth*sidewind_factor, 0)
      .arcSmallCCW((15/1024)*canvasWidth*sidewind_factor, (15/1024)*canvasWidth*sidewind_factor, 0,  (30/1024)*canvasWidth*sidewind_factor, 0)
      .close()
      .moveTo(-(15/1024)*canvasWidth*sidewind_factor, 0)
      .lineTo(-(45/1024)*canvasWidth*sidewind_factor, 0)
      .moveTo(-(75/1024)*canvasWidth*sidewind_factor, 0)
      .lineTo(-(105/1024)*canvasWidth*sidewind_factor, 0)
      .setStrokeLineWidth(w)
      .setStrokeLineCap("round")
      .setColor(r,g,b, a);
    #flight path indicator
    HUDnasal.main.reticle_group = HUDnasal.main.root.createChild("group");  
    HUDnasal.main.aim_reticle  = HUDnasal.main.reticle_group.createChild("path")
      .moveTo((45/1024)*canvasWidth*reticle_factor, 0)
      .lineTo((15/1024)*canvasWidth*reticle_factor, 0)
      .arcSmallCCW((15/1024)*canvasWidth*reticle_factor, (15/1024)*canvasWidth*reticle_factor, 0, -(30/1024)*canvasWidth*reticle_factor, 0)
      .arcSmallCCW((15/1024)*canvasWidth*reticle_factor, (15/1024)*canvasWidth*reticle_factor, 0,  (30/1024)*canvasWidth*reticle_factor, 0)
      .close()
      .moveTo(-(15/1024)*canvasWidth*reticle_factor, 0)
      .lineTo(-(45/1024)*canvasWidth*reticle_factor, 0)
      .setStrokeLineWidth(w)
      .setStrokeLineCap("round")
      .setColor(r,g,b, a);
    HUDnasal.main.reticle_fin_group = HUDnasal.main.reticle_group.createChild("group");  
    HUDnasal.main.aim_reticle_fin  = HUDnasal.main.reticle_fin_group.createChild("path")
      .moveTo(0, -(15/1024)*canvasWidth*reticle_factor)
      .lineTo(0, -(30/1024)*canvasWidth*reticle_factor)
      .setStrokeLineWidth(w)
      .setStrokeLineCap("round")
      .setColor(r,g,b, a);

    #turn coordinator
    HUDnasal.main.turn_group = HUDnasal.main.root.createChild("group").setTranslation(sideslipPlaceX, sideslipPlaceY);
    HUDnasal.main.turn_group2 = HUDnasal.main.turn_group.createChild("group");
    HUDnasal.main.t_rot   = HUDnasal.main.turn_group2.createTransform();
    HUDnasal.main.turn_indicator = HUDnasal.main.turn_group2.createChild("path")
         .moveTo(-(20/1024)*canvasWidth, 0)
         .horiz(-(150/1024)*canvasWidth)
         .moveTo((20/1024)*canvasWidth, 0)
         .horiz((150/1024)*canvasWidth)
         .moveTo(-(20/1024)*canvasWidth, 0)
         .vert((20/1024)*canvasWidth)
         .moveTo((20/1024)*canvasWidth, 0)
         .vert((20/1024)*canvasWidth)     
         .setStrokeLineWidth(w)
         .setColor(r,g,b, a);
    HUDnasal.main.turn_group3 = HUDnasal.main.turn_group2.createChild("group");
    HUDnasal.main.slip_indicator = HUDnasal.main.turn_group3.createChild("path")
         .moveTo(-(8/1024)*canvasWidth, -(26/1024)*canvasWidth)
         .horiz((16/1024)*canvasWidth)
         .vert((16/1024)*canvasWidth)
         .horiz(-(16/1024)*canvasWidth)
         .vert(-(16/1024)*canvasWidth)
         .setColorFill(r,g,b, a)
         .setStrokeLineWidth(w)
         .setColor(r,g,b, a);


    # Horizon
    clip = (0/1024)*canvasWidth~"px, "~(712/1024)*canvasWidth~"px, "~(1024/1024)*canvasWidth~"px, "~(0/1024)*canvasWidth~"px";
    HUDnasal.main.horizon_group = HUDnasal.main.root.createChild("group");
    HUDnasal.main.horizon_group.set("clip", "rect("~clip~")");#top,right,bottom,left (absolute in canvas)
    HUDnasal.main.horizon_group2 = HUDnasal.main.horizon_group.createChild("group");
    HUDnasal.main.horizon_group4 = HUDnasal.main.horizon_group.createChild("group");
    HUDnasal.main.desired_lines_group = HUDnasal.main.horizon_group2.createChild("group");
    HUDnasal.main.horizon_group3 = HUDnasal.main.horizon_group.createChild("group");
    HUDnasal.main.h_rot   = HUDnasal.main.horizon_group.createTransform();

  
    # pitch lines
    var distance = pixelPerDegreeY * 5;
    HUDnasal.main.negative_horizon_lines = 
    for(var i = -18; i <= -1; i += 1) { # stipled lines
      append(artifacts1, HUDnasal.main.horizon_group4.createChild("path")
                     .moveTo((200/1024)*canvasWidth, -i * distance)
                     .horiz((50/1024)*canvasWidth)
                     .moveTo((300/1024)*canvasWidth, -i * distance)
                     .horiz((50/1024)*canvasWidth)
                     .moveTo((400/1024)*canvasWidth, -i * distance)
                     .horiz((50/1024)*canvasWidth)
                     .moveTo((500/1024)*canvasWidth, -i * distance)
                     .horiz((50/1024)*canvasWidth)
                     .moveTo((600/1024)*canvasWidth, -i * distance)
                     .horiz((50/1024)*canvasWidth)
                     .moveTo((700/1024)*canvasWidth, -i * distance)
                     .horiz((50/1024)*canvasWidth)

                     .moveTo(-(200/1024)*canvasWidth, -i * distance)
                     .horiz(-(50/1024)*canvasWidth)
                     .moveTo(-(300/1024)*canvasWidth, -i * distance)
                     .horiz(-(50/1024)*canvasWidth)
                     .moveTo(-(400/1024)*canvasWidth, -i * distance)
                     .horiz(-(50/1024)*canvasWidth)
                     .moveTo(-(500/1024)*canvasWidth, -i * distance)
                     .horiz(-(50/1024)*canvasWidth)
                     .moveTo(-(600/1024)*canvasWidth, -i * distance)
                     .horiz(-(50/1024)*canvasWidth)
                     .moveTo(-(700/1024)*canvasWidth, -i * distance)
                     .horiz(-(50/1024)*canvasWidth)
                     
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a));
    }

    for(var i = 1; i <= 18; i += 1) # full drawn lines
      append(artifacts1, HUDnasal.main.horizon_group2.createChild("path")
         .moveTo((750/1024)*canvasWidth, -i * distance)
         .horiz(-(550/1024)*canvasWidth)

         .moveTo(-(750/1024)*canvasWidth, -i * distance)
         .horiz((550/1024)*canvasWidth)
         
         .setStrokeLineWidth(w)
         .setColor(r,g,b, a));

    for(var i = -18; i <= 18; i += 1) { # small vertical lines in combat mode
      append(artifacts1, HUDnasal.main.horizon_group3.createChild("path")
         .moveTo(-(200/1024)*canvasWidth, -i * distance)
         .vert((25/1024)*canvasWidth)

         .moveTo((200/1024)*canvasWidth, -i * distance)
         .vert((25/1024)*canvasWidth)
         
         .setStrokeLineWidth(w)
         .setColor(r,g,b, a));
    }

    #pitch line numbers
    for(var i = -18; i <= 0; i += 1)
      append(artifactsText1, HUDnasal.main.horizon_group4.createChild("text")
         .setText(i*5)
         .setFontSize((75/1024)*canvasWidth*fs, ar)
         .setAlignment("right-bottom")
         .setTranslation(-(200/1024)*canvasWidth, -i * distance - 5)
         .setColor(r,g,b, a));
    for(var i = 1; i <= 18; i += 1)
      append(artifactsText1, HUDnasal.main.horizon_group2.createChild("text")
         .setText("+" ~ i*5)
         .setFontSize((75/1024)*canvasWidth*fs, ar)
         .setAlignment("right-bottom")
         .setTranslation(-(200/1024)*canvasWidth, -i * distance - 5)
         .setColor(r,g,b, a));
                 
 
    #Horizon line
    HUDnasal.main.horizon_line = HUDnasal.main.horizon_group2.createChild("path")
                     .moveTo(-(850/1024)*canvasWidth, 0)
                     .horiz((650/1024)*canvasWidth)
                     .moveTo((200/1024)*canvasWidth, 0)
                     .horiz((650/1024)*canvasWidth)
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a);

    HUDnasal.main.horizon_line_gap = HUDnasal.main.horizon_group2.createChild("path")
                     .moveTo(-(200/1024)*canvasWidth, 0)
                     .horiz((400/1024)*canvasWidth)
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a);

    # heading scale on horizon line
    HUDnasal.main.head_scale_horz_grp = HUDnasal.main.horizon_group2.createChild("group");
    HUDnasal.main.head_scale_horz_ticks = HUDnasal.main.head_scale_horz_grp.createChild("path")
                      .moveTo(0, 0)
                      .vert(-(30/1024)*canvasWidth)
                      .moveTo(10*pixelPerDegreeX, 0)
                      .vert(-(30/1024)*canvasWidth)
                      .moveTo(-10*pixelPerDegreeX, 0)
                      .vert(-(30/1024)*canvasWidth)
                      .setStrokeLineWidth(w)
                      .setColor(r,g,b, a);
    # Heading middle number on horizon line
    HUDnasal.main.hdgMH = HUDnasal.main.head_scale_horz_grp.createChild("text")
                      .setColor(r,g,b, a)
                      .setAlignment("center-bottom")
                      .setFontSize((65/1024)*canvasWidth*fs, ar);
    # Heading left number on horizon line
    HUDnasal.main.hdgLH = HUDnasal.main.head_scale_horz_grp.createChild("text")
                      .setColor(r,g,b, a)
                      .setAlignment("center-bottom")
                      .setFontSize((65/1024)*canvasWidth*fs, ar);
    # Heading right number on horizon line
    HUDnasal.main.hdgRH = HUDnasal.main.head_scale_horz_grp.createChild("text")
                      .setColor(r,g,b, a)
                      .setAlignment("center-bottom")
                      .setFontSize((65/1024)*canvasWidth*fs, ar);
    #heading bug on horizon
    HUDnasal.main.heading_bug_horz_group = HUDnasal.main.horizon_group2.createChild("group");
    HUDnasal.main.heading_bug_horz = HUDnasal.main.heading_bug_horz_group.createChild("path")
                      .setColor(r,g,b, a)
                      .setStrokeLineCap("round")
                      .setStrokeLineWidth(w)
                      .moveTo( 0,  (10/1024)*canvasWidth)
                      .lineTo( 0,  (55/1024)*canvasWidth)
                      .moveTo( (15/1024)*canvasWidth, (55/1024)*canvasWidth)
                      .lineTo( (15/1024)*canvasWidth, (25/1024)*canvasWidth)
                      .moveTo(-(15/1024)*canvasWidth, (55/1024)*canvasWidth)
                      .lineTo(-(15/1024)*canvasWidth, (25/1024)*canvasWidth);                      

    # altitude desired lines
    HUDnasal.main.desired_lines3 = HUDnasal.main.desired_lines_group.createChild("path")
                     .moveTo(-(200/1024)*canvasWidth + w/2, 0)
                     .vert(5*pixelPerDegreeY)
                     .moveTo((200/1024)*canvasWidth - w/2, 0)
                     .vert(5*pixelPerDegreeY)
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a);

    HUDnasal.main.landing_line = HUDnasal.main.horizon_group2.createChild("path")
                     .moveTo(-(200/1024)*canvasWidth, 0)
                     .horiz((160/1024)*canvasWidth)
                     .moveTo((40/1024)*canvasWidth, 0)
                     .horiz((160/1024)*canvasWidth)
                     .moveTo(0, 0)
                     .arcSmallCW((4/1024)*canvasWidth, (4/1024)*canvasWidth, 0, -(8/1024)*canvasWidth, 0)
                     .arcSmallCW((4/1024)*canvasWidth, (4/1024)*canvasWidth, 0,  (8/1024)*canvasWidth, 0)
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a);                     

    HUDnasal.main.desired_lines2 = HUDnasal.main.desired_lines_group.createChild("path")
                     .moveTo(-(140/1024)*canvasWidth + w/2, 0)
                     .vert(3*pixelPerDegreeY)
                     .moveTo((140/1024)*canvasWidth - w/2, 0)
                     .vert(3*pixelPerDegreeY)
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a);                     

    var dot_half = (2/1024)*canvasWidth;
    var dot_full = (4/1024)*canvasWidth;

    HUDnasal.main.horizon_dots = HUDnasal.main.horizon_group2.createChild("path")
                     .moveTo(-(37/1024)*canvasWidth, 0)#-35
                     .arcSmallCW(dot_half, dot_half, 0, -dot_full, 0)
                     .arcSmallCW(dot_half, dot_half, 0, dot_full, 0)
                     .moveTo(-(107/1024)*canvasWidth, 0)#-105
                     .arcSmallCW(dot_half, dot_half, 0, -dot_full, 0)
                     .arcSmallCW(dot_half, dot_half, 0, dot_full, 0)
                     .moveTo(-(177/1024)*canvasWidth, 0)#-175
                     .arcSmallCW(dot_half, dot_half, 0, -dot_full, 0)
                     .arcSmallCW(dot_half, dot_half, 0, dot_full, 0)
                     .moveTo((177/1024)*canvasWidth, 0)#175
                     .arcSmallCW(dot_half, dot_half, 0, -dot_full, 0)
                     .arcSmallCW(dot_half, dot_half, 0, dot_full, 0)
                     .moveTo((107/1024)*canvasWidth, 0)#105
                     .arcSmallCW(dot_half, dot_half, 0, -dot_full, 0)
                     .arcSmallCW(dot_half, dot_half, 0, dot_full, 0)
                     .moveTo((37/1024)*canvasWidth, 0)#35
                     .arcSmallCW(dot_half, dot_half, 0, -dot_full, 0)
                     .arcSmallCW(dot_half, dot_half, 0, dot_full, 0)
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a);

      ####  targets

    HUDnasal.main.radar_group = HUDnasal.main.root.createChild("group");

      #diamond
    HUDnasal.main.diamond_group = HUDnasal.main.radar_group.createChild("group");
    #HUDnasal.main.diamond_group_line = HUDnasal.main.diamond_group.createChild("group");
    #HUDnasal.main.track_line = nil;
    HUDnasal.main.diamond_group.createTransform();
    HUDnasal.main.diamond = HUDnasal.main.diamond_group.createChild("path")
                           .moveTo(-(70/1024)*canvasWidth,   0)
                           .lineTo(  0, -(70/1024)*canvasWidth)
                           .lineTo( (70/1024)*canvasWidth,   0)
                           .lineTo(  0,  (70/1024)*canvasWidth)
                           .lineTo(-(70/1024)*canvasWidth,   0)
                           .setStrokeLineWidth(w)
                           .setColor(r,g,b, a);
    HUDnasal.main.target_air = HUDnasal.main.diamond_group.createChild("path")
                           .moveTo(-(50/1024)*canvasWidth,   0)
                           .lineTo(-(50/1024)*canvasWidth, -(50/1024)*canvasWidth)
                           .lineTo( (50/1024)*canvasWidth, -(50/1024)*canvasWidth)
                           .lineTo( (50/1024)*canvasWidth,   0)
                           .setStrokeLineWidth(w)
                           .setColor(r,g,b, a);
    HUDnasal.main.target_ground = HUDnasal.main.diamond_group.createChild("path")
                           .moveTo(-(50/1024)*canvasWidth,   0)
                           .lineTo(-(50/1024)*canvasWidth, (50/1024)*canvasWidth)
                           .lineTo( (50/1024)*canvasWidth, (50/1024)*canvasWidth)
                           .lineTo( (50/1024)*canvasWidth,   0)
                           .setStrokeLineWidth(w)
                           .setColor(r,g,b, a);
    HUDnasal.main.target_sea = HUDnasal.main.diamond_group.createChild("path")
                           .moveTo(-(50/1024)*canvasWidth,   0)
                           .lineTo(0, (50/1024)*canvasWidth)
                           .lineTo( (50/1024)*canvasWidth,   0)
                           .setStrokeLineWidth(w)
                           .setColor(r,g,b, a); 
    HUDnasal.main.diamond_dist = HUDnasal.main.diamond_group.createChild("text");
    HUDnasal.main.diamond_dist.setText("..");
    HUDnasal.main.diamond_dist.setColor(r,g,b, a);
    HUDnasal.main.diamond_dist.setAlignment("left-top");
    HUDnasal.main.diamond_dist.setTranslation((40/1024)*canvasWidth, (55/1024)*canvasWidth);
    HUDnasal.main.diamond_dist.setFontSize((60/1024)*canvasWidth*fs, ar);
    HUDnasal.main.diamond_name = HUDnasal.main.diamond_group.createChild("text");
    HUDnasal.main.diamond_name.setText("..");
    HUDnasal.main.diamond_name.setColor(r,g,b, a);
    HUDnasal.main.diamond_name.setAlignment("left-bottom");
    HUDnasal.main.diamond_name.setTranslation((40/1024)*canvasWidth, -(55/1024)*canvasWidth);
    HUDnasal.main.diamond_name.setFontSize((60/1024)*canvasWidth*fs, ar);


    HUDnasal.main.vel_vec_trans_group = HUDnasal.main.radar_group.createChild("group");
    HUDnasal.main.vel_vec_rot_group = HUDnasal.main.vel_vec_trans_group.createChild("group");
    #HUDnasal.main.vel_vec_rot = HUDnasal.main.vel_vec_rot_group.createTransform();
    HUDnasal.main.vel_vec = me.vel_vec_rot_group.createChild("path")
                                  .moveTo(0, 0)
                                  .lineTo(0,-(1/1024)*canvasWidth)
                                  .setStrokeLineWidth(w)
                                  .setColor(r,g,b, a);

    #tower symbol
    HUDnasal.main.tower_symbol = HUDnasal.main.root.createChild("group");
    HUDnasal.main.tower_symbol.createTransform();
    var tower = HUDnasal.main.tower_symbol.createChild("path")
                           .moveTo(-(20/1024)*canvasWidth,   0)
                           .lineTo(  0, -(20/1024)*canvasWidth)
                           .lineTo( (20/1024)*canvasWidth,   0)
                           .lineTo(  0,  (20/1024)*canvasWidth)
                           .lineTo(-(20/1024)*canvasWidth,   0)
                           .setStrokeLineWidth(w)
                           .setColor(r,g,b, a);
    HUDnasal.main.tower_symbol_dist = HUDnasal.main.tower_symbol.createChild("text");
    HUDnasal.main.tower_symbol_dist.setText("..");
    HUDnasal.main.tower_symbol_dist.setColor(r,g,b, a);
    HUDnasal.main.tower_symbol_dist.setAlignment("left-top");
    HUDnasal.main.tower_symbol_dist.setTranslation((12/1024)*canvasWidth, (12/1024)*canvasWidth);
    HUDnasal.main.tower_symbol_dist.setFontSize((60/1024)*canvasWidth*fs, ar);

    HUDnasal.main.tower_symbol_icao = HUDnasal.main.tower_symbol.createChild("text");
    HUDnasal.main.tower_symbol_icao.setText("..");
    HUDnasal.main.tower_symbol_icao.setColor(r,g,b, a);
    HUDnasal.main.tower_symbol_icao.setAlignment("left-bottom");
    HUDnasal.main.tower_symbol_icao.setTranslation((12/1024)*canvasWidth, -(12/1024)*canvasWidth);
    HUDnasal.main.tower_symbol_icao.setFontSize((60/1024)*canvasWidth*fs, ar);

    #ccip symbol
    HUDnasal.main.ccip_symbol = HUDnasal.main.root.createChild("group");
    HUDnasal.main.ccip_symbol.createTransform();
    var ccip = HUDnasal.main.ccip_symbol.createChild("path")
                           .moveTo(-(5/1024)*canvasWidth,   0)
                           .lineTo(  0, -(5/1024)*canvasWidth)
                           .lineTo( (5/1024)*canvasWidth,   0)
                           .lineTo(  0,  (5/1024)*canvasWidth)
                           .lineTo(-(5/1024)*canvasWidth,   0)
                           .moveTo(-(25/1024)*canvasWidth,   0)
                           .arcLargeCW((25/1024)*canvasWidth, (25/1024)*canvasWidth, 0,  (50/1024)*canvasWidth, 0)
                           .moveTo(-(25/1024)*canvasWidth,   0)
                           .arcLargeCCW((25/1024)*canvasWidth, (25/1024)*canvasWidth, 0,  (50/1024)*canvasWidth, 0)
                           .setStrokeLineWidth(w)
                           .setColor(r,g,b, a);

    #distance scale
    HUDnasal.main.dist_scale_group = HUDnasal.main.root.createChild("group").setTranslation(-(100/1024)*canvasWidth, (distScalePos/1024)*canvasWidth);
    HUDnasal.main.mySpeed = HUDnasal.main.dist_scale_group.createChild("path")
                            .moveTo(   0,   0)
                            .lineTo( -(10/1024)*canvasWidth, -(10/1024)*canvasWidth)
                            .lineTo(   0, -(20/1024)*canvasWidth)
                            .lineTo(  (10/1024)*canvasWidth, -(10/1024)*canvasWidth)
                            .lineTo(   0,   0)
                            .setStrokeLineWidth(w)
                            .setColor(r,g,b, a);
    HUDnasal.main.targetSpeed = HUDnasal.main.dist_scale_group.createChild("path")
                            .moveTo(   0,   0)
                            .lineTo(   0,  (20/1024)*canvasWidth)
                            .moveTo( -(10/1024)*canvasWidth,  (20/1024)*canvasWidth)
                            .lineTo(  (10/1024)*canvasWidth,  (20/1024)*canvasWidth)
                            .setStrokeLineWidth(w)
                            .setColor(r,g,b, a);
    HUDnasal.main.targetDistance1 = HUDnasal.main.dist_scale_group.createChild("path")
                            .moveTo(   0,   0)
                            .lineTo(   0,  (20/1024)*canvasWidth)
                            .lineTo(  (20/1024)*canvasWidth,  (20/1024)*canvasWidth)
                            .moveTo( -(30/1024)*canvasWidth,  (20/1024)*canvasWidth)
                            .lineTo( -(30/1024)*canvasWidth,  (50/1024)*canvasWidth)
                            .lineTo(   0,  (50/1024)*canvasWidth)
                            .setStrokeLineWidth(w)
                            .setColor(r,g,b, a);
    HUDnasal.main.targetDistance2 = HUDnasal.main.dist_scale_group.createChild("path")
                            .moveTo(   0,   0)
                            .lineTo(   0,  (20/1024)*canvasWidth)
                            .lineTo( -(20/1024)*canvasWidth,  (20/1024)*canvasWidth)
                            .setStrokeLineWidth(w)
                            .setColor(r,g,b, a);
    HUDnasal.main.distanceText = HUDnasal.main.dist_scale_group.createChild("text")
                            .setText("")
                            .setColor(r,g,b, a)
                            .setAlignment("left-top")
                            .setTranslation((200/1024)*canvasWidth, (10/1024)*canvasWidth)
                            .setFontSize((60/1024)*canvasWidth*fs, ar);
    HUDnasal.main.distanceScale = HUDnasal.main.dist_scale_group.createChild("path")
                            .moveTo(   0, 0)
                            .lineTo( (200/1024)*canvasWidth, 0)
                            .setStrokeLineWidth(w)
                            .setColor(r,g,b, a);

      #other targets
    HUDnasal.main.target_circle = [];
    HUDnasal.main.target_group = HUDnasal.main.radar_group.createChild("group");
    for(var i = 0; i < maxTracks; i += 1) {      
      target_circles = HUDnasal.main.target_group.createChild("path")
                           .moveTo(-(50/1024)*canvasWidth, 0)
                           .arcLargeCW((50/1024)*canvasWidth, (50/1024)*canvasWidth, 0,  (100/1024)*canvasWidth, 0)
                           #.arcLargeCW(50, 50, 0, -100, 0)
                           .setStrokeLineWidth(w)
                           .setColor(r,g,b, a);
      append(HUDnasal.main.target_circle, target_circles);
      append(artifacts1, target_circles);
    }

    artifacts0 = [HUDnasal.main.head_scale, HUDnasal.main.hdgLineL, HUDnasal.main.heading_bug, HUDnasal.main.vel_vec, HUDnasal.main.reticle_missile, HUDnasal.main.reticle_c_missile,
             HUDnasal.main.hdgLineR, HUDnasal.main.head_scale_indicator, HUDnasal.main.turn_indicator, HUDnasal.main.arrow, HUDnasal.main.head_scale_horz_ticks,
             HUDnasal.main.alt_scale_high, HUDnasal.main.alt_scale_med, HUDnasal.main.alt_scale_low, HUDnasal.main.slip_indicator,
             HUDnasal.main.alt_scale_line, HUDnasal.main.aim_reticle_fin, HUDnasal.main.reticle_cannon, HUDnasal.main.desired_lines2,
             HUDnasal.main.alt_pointer, HUDnasal.main.rad_alt_pointer, HUDnasal.main.target_air, HUDnasal.main.target_sea, HUDnasal.main.target_ground, HUDnasal.main.desired_lines3, HUDnasal.main.horizon_line_gap,
             HUDnasal.main.reticle_no_ammo, HUDnasal.main.takeoff_symbol, HUDnasal.main.horizon_line, HUDnasal.main.horizon_dots, HUDnasal.main.diamond,
             tower, ccip, HUDnasal.main.aim_reticle, HUDnasal.main.targetSpeed, HUDnasal.main.mySpeed, HUDnasal.main.distanceScale, HUDnasal.main.targetDistance1,
             HUDnasal.main.targetDistance2, HUDnasal.main.landing_line, HUDnasal.main.heading_bug_horz];

    artifactsText0 = [HUDnasal.main.airspeedInt, HUDnasal.main.airspeed, HUDnasal.main.hdgM, HUDnasal.main.hdgL, HUDnasal.main.hdgR, HUDnasal.main.qfe,
                      HUDnasal.main.diamond_dist, HUDnasal.main.tower_symbol_dist, HUDnasal.main.tower_symbol_icao, HUDnasal.main.diamond_name,
                      HUDnasal.main.alt_low, HUDnasal.main.alt_med, HUDnasal.main.alt_high, HUDnasal.main.alt_higher, HUDnasal.main.alt,
                      HUDnasal.main.hdgMH, HUDnasal.main.hdgLH, HUDnasal.main.hdgRH, HUDnasal.main.distanceText];


  },
  setColorBackground: func () { 
    #me.texture.getNode('background', 1).setValue(_getColor(arg)); 
    me; 
  },

  new: func(placement) {
    if(HUDnasal.main == nil) {
      HUDnasal.main = {
        parents: [HUDnasal],
        canvas: canvas.new(HUDnasal.canvas_settings),
        text_style: {
          'font': "LiberationFonts/LiberationMono-Regular.ttf", 
          'character-size': (100/1024)*canvasWidth,
        },
        place: placement
      };
      HUDnasal.main.final = FALSE;
      HUDnasal.main.verbose = 0;
      HUDnasal.main.input = {
        #      hdg:      "instrumentation/gps/indicated-track-magnetic-deg",
        #     hdg:      "instrumentation/magnetic-compass/indicated-heading-deg",
        alpha:            "orientation/alpha-deg",
        alphaJSB:         "fdm/jsbsim/aero/alpha-deg",
        alt_ft:           "instrumentation/altimeter/indicated-altitude-ft",
        alt_ft_real:      "position/altitude-ft",
        altCalibrated:    "ja37/avionics/altimeters-calibrated",
        APHeadingBug:     "autopilot/settings/heading-bug-deg",
        APLockAlt:        "autopilot/locks/altitude",
        APLockHeading:    "autopilot/locks/heading",
        APnav0HeadingErr: "autopilot/internal/nav1-heading-error-deg",
        APTgtAgl:         "autopilot/settings/target-agl-ft",
        APTgtAlt:         "autopilot/settings/target-altitude-ft",
        APTrueHeadingErr: "autopilot/internal/true-heading-error-deg",
        beta:             "orientation/side-slip-deg",
        callsign:         "ja37/hud/callsign",
        cannonAmmo:       "ai/submodels/submodel[3]/count",
        carrierNear:      "fdm/jsbsim/ground/carrier-near",
        combat:           "ja37/hud/combat",
        ctrlRadar:        "controls/altimeter-radar",
        currentMode:      "ja37/hud/current-mode",
        dme:              "instrumentation/dme/KDI572-574/nm",
        dmeDist:          "instrumentation/dme/indicated-distance-nm",
        elapsedSec:       "sim/time/elapsed-sec",
        elecAC:           "systems/electrical/outputs/ac-instr-voltage",
        elecDC:           "systems/electrical/outputs/dc-voltage",
        fdpitch:          "autopilot/settings/fd-pitch-deg",
        fdroll:           "autopilot/settings/fd-roll-deg",
        fdspeed:          "autopilot/settings/target-speed-kt",
        fiveHz:           "ja37/blink/five-Hz/state",
        gearCmdNorm:      "/fdm/jsbsim/gear/gear-cmd-norm",
        gearsPos:         "gear/gear/position-norm",
        hdg:              "orientation/heading-magnetic-deg",
        hdgReal:          "orientation/heading-deg",
        ias:              "instrumentation/airspeed-indicator/indicated-speed-kt",#"/velocities/airspeed-kt",
        landingMode:      "ja37/hud/landing-mode",
        mach:             "instrumentation/airspeed-indicator/indicated-mach",
        mode:             "ja37/hud/mode",
        nav0GSNeedleDefl: "instrumentation/nav[0]/gs-needle-deflection-norm",
        nav0GSInRange:    "instrumentation/nav[0]/gs-in-range",
        nav0HasGS:        "instrumentation/nav[0]/has-gs",
        nav0Heading:      "instrumentation/nav[0]/heading-deg",
        nav0HeadingDefl:  "instrumentation/nav[0]/heading-needle-deflection",
        nav0InRange:      "instrumentation/nav[0]/in-range",
        pitch:            "orientation/pitch-deg",
        rad_alt:          "position/altitude-agl-ft",#/instrumentation/radar-altimeter/radar-altitude-ft",
        radar_serv:       "instrumentation/radar/serviceable",
        RMActive:         "autopilot/route-manager/active",
        rmDist:           "autopilot/route-manager/wp/dist",
        RMCurrWaypoint:   "autopilot/route-manager/current-wp",
        RMWaypointBearing:"autopilot/route-manager/wp/bearing-deg",
        roll:             "orientation/roll-deg",
        srvHead:          "instrumentation/heading-indicator/serviceable",
        srvTurn:          "instrumentation/turn-indicator/serviceable",
        service:          "instrumentation/head-up-display/serviceable",
        sideslipOn:       "ja37/hud/bank-indicator",
        speed_d:          "velocities/speed-down-fps",
        speed_e:          "velocities/speed-east-fps",
        speed_n:          "velocities/speed-north-fps",
        station:          "controls/armament/station-select",
        tenHz:            "ja37/blink/ten-Hz/state",
        terrainOn:        "ja37/sound/terrain-on",
        TILS:             "ja37/hud/TILS",
        towerAlt:         "sim/tower/altitude-ft",
        towerLat:         "sim/tower/latitude-deg",
        towerLon:         "sim/tower/longitude-deg",
        tracks_enabled:   "ja37/hud/tracks-enabled",
        units:            "ja37/hud/units-metric",
        viewNumber:       "sim/current-view/view-number",
        viewZ:            "sim/current-view/y-offset-m",
        vs:               "velocities/vertical-speed-fps",
        windHeading:      "environment/wind-from-heading-deg",
        windSpeed:        "environment/wind-speed-kt",        
        wow0:             "fdm/jsbsim/gear/unit[0]/WOW",
        wow1:             "fdm/jsbsim/gear/unit[1]/WOW",
        wow2:             "fdm/jsbsim/gear/unit[2]/WOW",
        dev:              "dev",
        elev_ft:          "position/ground-elev-ft",
        elev_m:           "position/ground-elev-m",
        gs:               "velocities/groundspeed-kt",
        terrainWarn:      "/instrumentation/terrain-warning"
      };
   
      foreach(var name; keys(HUDnasal.main.input)) {
        HUDnasal.main.input[name] = props.globals.getNode(HUDnasal.main.input[name], 1);
      }
    }

    HUDnasal.main.redraw();
    return HUDnasal.main;
    
  },

      ############################################################################
      #############             main loop                         ################
      ############################################################################
  update: func() {
    me.has_power = TRUE;
    if (me.input.elecAC.getValue() < 100) {
      # primary power is off
      if (me.input.elecDC.getValue() > 23) {
        # on backup
        if (on_backup_power == FALSE) {
          # change the colour to amber
          reinit(TRUE);
        }
        on_backup_power = TRUE;
      } else {
        # HUD has no power
        me.has_power = FALSE;
      }
    } elsif (on_backup_power == TRUE) {
      # was on backup, now is on primary
      reinit(FALSE);
      on_backup_power = FALSE;
    }
    
    # in case the user has adjusted the Z view position, we calculate the Y point in the HUD in line with pilots eyes.
    me.fromTop = HUDTop - me.input.viewZ.getValue();
    centerOffset = -1 * ((512/1024)*canvasWidth - (me.fromTop * pixelPerMeter));

    # since mode is used outside of the HUD also, the mode is calculated before we determine if the HUD should be updated:
    me.takeoffForbidden = me.input.pitch.getValue() > 3 or me.input.mach.getValue() > 0.35 or me.input.gearsPos.getValue() != 1;
    if(mode != TAKEOFF and !me.takeoffForbidden and me.input.wow0.getValue() == TRUE and me.input.wow0.getValue() == TRUE and me.input.wow0.getValue() == TRUE and me.input.dev.getValue() != TRUE) {
      mode = TAKEOFF;
      modeTimeTakeoff = -1;
    } elsif (me.input.dev.getValue() == TRUE and me.input.combat.getValue() == 1) {
      mode = COMBAT;
      modeTimeTakeoff = -1;
    } elsif (mode == TAKEOFF and modeTimeTakeoff == -1 and me.takeoffForbidden) {
      modeTimeTakeoff = me.input.elapsedSec.getValue();
    } elsif (modeTimeTakeoff != -1 and me.input.elapsedSec.getValue() - modeTimeTakeoff > 3) {
      if (me.input.gearsPos.getValue() == 1 or me.input.landingMode.getValue() == TRUE) {
        mode = LANDING;
      } else {
        mode = me.input.combat.getValue() == 1 ? COMBAT : NAV;
      }
      modeTimeTakeoff = -1;
    } elsif ((mode == COMBAT or mode == NAV) and (me.input.gearsPos.getValue() == 1 or me.input.landingMode.getValue() == TRUE)) {
      mode = LANDING;
      modeTimeTakeoff = -1;
    } elsif (mode == COMBAT or mode == NAV) {
      mode = me.input.combat.getValue() == 1 ? COMBAT : NAV;
      modeTimeTakeoff = -1;
    } elsif (mode == LANDING and me.input.gearsPos.getValue() == 0 and me.input.landingMode.getValue() == FALSE) {
      mode = me.input.combat.getValue() == 1 ? COMBAT : NAV;
      modeTimeTakeoff = -1;
    }
    me.input.currentMode.setIntValue(mode);

    if(me.has_power == FALSE or me.input.mode.getValue() == 0) {
      me.root.hide();
      me.root.update();
      air2air = FALSE;
      air2ground = FALSE;
      settimer(func me.update(), 0.3);
     } elsif (me.input.service.getValue() == FALSE) {
      # The HUD has failed, due to the random failure system or crash, it will become frozen.
      # if it also later loses power, and the power comes back, the HUD will not reappear.
      air2air = FALSE;
      air2ground = FALSE;
      settimer(func me.update(), 0.25);
     } else {
      # commented as long as diamond node is choosen in HUD
      #if (me.input.viewNumber.getValue() != 0 and me.input.viewNumber.getValue() != 13) {
        # in external view
      #  settimer(func me.update(), 0.03);
      #  return;
      #}

      me.cannon = me.input.station.getValue() == 0;
      me.cannon = me.cannon or getprop("payload/weight["~ (me.input.station.getValue()-1) ~"]/selected") == "M55 AKAN";
      me.cannon = me.input.combat.getValue() == TRUE and me.cannon;
      me.out_of_ammo = FALSE;
      #if (me.input.station.getValue() != 0 and getprop("payload/weight["~ (me.input.station.getValue()-1) ~"]/selected") == "none") {
      #      out_of_ammo = TRUE;
      #} elsif (me.input.station.getValue() == 0 and me.input.cannonAmmo.getValue() == 0) {
      #      out_of_ammo = TRUE;
      #} elsif (me.input.station.getValue() != 0 and getprop("payload/weight["~ (me.input.station.getValue()-1) ~"]/selected") == "M70 ARAK" and getprop("ai/submodels/submodel["~(4+me.input.station.getValue())~"]/count") == 0) {
      #      out_of_ammo = TRUE;
      #}
      me.ammo = armament.ammoCount(me.input.station.getValue());
      if (me.ammo > 0) {
        me.out_of_ammo = FALSE;
      } else {
        me.out_of_ammo = TRUE;
      }

      me.finalVisual = me.input.ctrlRadar.getValue() == 1? (me.input.rad_alt.getValue() * FT2M) < 15 : (me.input.alt_ft.getValue() * FT2M) < 35;

      # ground collision warning
      me.displayGroundCollisionArrow(mode);

      # heading scale
      me.displayHeadingScale();
      me.displayHeadingHorizonScale();

      #heading bug, must be after heading scale
      me.displayHeadingBug();

      # altitude. Digital and scale.
      me.displayAltitude();

      ####   display QFE or weapon   ####
      me.displayQFE(mode);

      ####   reticle  ####
      deflect = me.showReticle(mode, me.cannon, me.out_of_ammo);

      # digital speed (must be after showReticle)
      me.displayDigitalSpeed(mode);

      # Visual, TILS and ILS landing guide
      me.guide = me.displayLandingGuide(mode, deflect);

      # desired alt lines
      me.displayDesiredAltitudeLines(me.guide);

      # CCIP
      me.fallTime = me.displayCCIP();

      # distance scale
      me.showDistanceScale(mode, me.fallTime);

      ### artificial horizon and pitch lines ###
      me.displayPitchLines(mode);

      ### turn coordinator ###
      me.displayTurnCoordinator();

      ####  Radar HUD tracks  ###
      me.displayRadarTracks(mode);

      # tower symbol
      me.displayTower();

      

      skip = !skip;#we skip some function every other time, for performance

      if(reinitHUD == TRUE) {
        me.redraw();
        reinitHUD = FALSE;
        me.update();
      } else {
        me.root.show();
        me.root.update();          
      }
      settimer(
      #func debug.benchmark("hud loop", 
      func me.update()
      #)
      , 0.05);
      #setprop("sim/hud/visibility[1]", 0);
    }#end of HUD running check
  },#end of update

  displayGroundCollisionArrow: func (mode) {
    if (me.input.terrainWarn.getValue() == TRUE) {
      me.arrow_trans.setRotation(- me.input.roll.getValue()*deg2rads);
      me.arrow.show();
    } else {
      me.arrow.hide();
    }
  },

  topHeadingScaleShown: func () {
    return mode != LANDING or me.input.pitch.getValue() < -2 or me.input.pitch.getValue() > 13.5;
  },

  displayHeadingScale: func () {
    if (me.topHeadingScaleShown()) {
      if(me.input.srvHead.getValue() == TRUE) {
        me.heading = me.input.hdg.getValue();
        me.headOffset = me.heading/10 - int (me.heading/10);
        me.headScaleOffset = me.headOffset;
        me.middleText = roundabout(me.heading/10);
        me.middleOffset = nil;
        if(me.middleText == 36) {
          me.middleText = 0;
        }
        me.leftText = me.middleText == 0?35:me.middleText-1;
        me.rightText = me.middleText == 35?0:me.middleText+1;
        if (me.headOffset > 0.5) {
          me.middleOffset = -(me.headScaleOffset-1)*headScaleTickSpacing*2;
          me.head_scale_grp_trans.setTranslation(me.middleOffset, -headScalePlace);
          me.head_scale_grp.update();
          me.hdgLineL.show();
          #me.hdgLineR.hide();
        } else {
          me.middleOffset = -me.headScaleOffset*headScaleTickSpacing*2;
          me.head_scale_grp_trans.setTranslation(me.middleOffset, -headScalePlace);
          me.head_scale_grp.update();
          me.hdgLineR.show();
          #me.hdgLineL.hide();
        }
        me.hdgR.setTranslation(headScaleTickSpacing*2, -(65/1024)*canvasWidth);
        me.hdgR.setText(sprintf("%02d", me.rightText));
        me.hdgM.setTranslation(0, -(65/1024)*canvasWidth);
        me.hdgM.setText(sprintf("%02d", me.middleText));
        me.hdgL.setTranslation(-headScaleTickSpacing*2, -(65/1024)*canvasWidth);
        me.hdgL.setText(sprintf("%02d", me.leftText));
      }
      me.head_scale_grp.show();
      me.head_scale_indicator.show();
    } else {
      me.head_scale_grp.hide();
      me.head_scale_indicator.hide();
    }
  },

  displayHeadingHorizonScale: func () {
    if (mode == LANDING) {
      if(me.input.srvHead.getValue() == 1) {
        me.heading = me.input.hdg.getValue();
        me.headOffset = me.heading/10 - int (me.heading/10);
        me.headScaleOffset = me.headOffset;
        me.middleText = roundabout(me.input.hdg.getValue()/10);
        me.middleOffsetHorz = nil;
        if(me.middleText == 36) {
          me.middleText = 0;
        }
        me.leftText = me.middleText == 0?35:me.middleText-1;
        me.rightText = me.middleText == 35?0:me.middleText+1;
        if (me.headOffset > 0.5) {
          me.middleOffsetHorz = -(me.headScaleOffset-1)*10*pixelPerDegreeX;
          me.head_scale_horz_grp.setTranslation(me.middleOffsetHorz, 0);
          me.head_scale_horz_grp.update();
          #me.hdgLineL.show();
        } else {
          me.middleOffsetHorz = -me.headScaleOffset*10*pixelPerDegreeX;
          me.head_scale_horz_grp.setTranslation(me.middleOffsetHorz, 0);
          me.head_scale_horz_grp.update();
          #me.hdgLineR.show();
        }
        me.hdgRH.setTranslation(10*pixelPerDegreeX, -(30/1024)*canvasWidth);
        me.hdgRH.setText(sprintf("%02d", me.rightText));
        me.hdgMH.setTranslation(0, -(30/1024)*canvasWidth);
        me.hdgMH.setText(sprintf("%02d", me.middleText));
        me.hdgLH.setTranslation(-10*pixelPerDegreeX, -(30/1024)*canvasWidth);
        me.hdgLH.setText(sprintf("%02d", me.leftText));
      }
      me.hdgRH.show();
      me.hdgMH.show();
      me.hdgLH.show();
      me.head_scale_horz_ticks.show();
    } else {
      me.hdgRH.hide();
      me.hdgMH.hide();
      me.hdgLH.hide();
      me.head_scale_horz_ticks.hide();
    }
  },

  displayHeadingBug: func () {
    me.desired_mag_heading = nil;
    if (mode == LANDING and me.input.nav0InRange.getValue() == TRUE) {
      me.desired_mag_heading = me.input.nav0Heading.getValue();
    } elsif (me.input.APLockHeading.getValue() == "dg-heading-hold") {
      me.desired_mag_heading = me.input.APHeadingBug.getValue();
    } elsif (me.input.APLockHeading.getValue() == "true-heading-hold") {
      me.desired_mag_heading = me.input.APTrueHeadingErr.getValue()+me.input.hdg.getValue();#getprop("autopilot/settings/true-heading-deg")+
    } elsif (me.input.APLockHeading.getValue() == "nav1-hold") {
      me.desired_mag_heading = me.input.APnav0HeadingErr.getValue()+me.input.hdg.getValue();
    } elsif( me.input.RMActive.getValue() == 1) {
      #var i = getprop("autopilot/route-manager/current-wp");
      me.desired_mag_heading = me.input.RMWaypointBearing.getValue();
    }
    if(me.desired_mag_heading != nil) {
      #print("desired "~desired_mag_heading);
      while(me.desired_mag_heading < 0) {
        me.desired_mag_heading += 360.0;
      }
      while(me.desired_mag_heading > 360) {
        me.desired_mag_heading -= 360.0;
      }
      me.degOffset = nil;
      me.headingMiddle = roundabout(me.input.hdg.getValue()/10.0)*10.0;
      #print("desired "~desired_mag_heading~" head-middle "~headingMiddle);

      #find difference between desired and middleText heading
      if (me.headingMiddle > me.desired_mag_heading) {
        if (me.headingMiddle - me.desired_mag_heading < 180) {
          # negative value
          me.degOffset = me.desired_mag_heading - me.headingMiddle;
        } else {
          # positive value
          me.headingMiddle = me.headingMiddle - 360;
          me.degOffset = me.desired_mag_heading - me.headingMiddle;
        }
      } else {
        if (me.desired_mag_heading - me.headingMiddle < 180) {
          # positive value
          me.degOffset = me.desired_mag_heading - me.headingMiddle;
        } else {
          # negative value
          me.desired_mag_heading = me.desired_mag_heading - 360;
          me.degOffset = me.desired_mag_heading - me.headingMiddle;
        }
      }


#      if (headingMiddle > 300 and desired_mag_heading < 60) {
 #       headingMiddle = headingMiddle - 360;
  #      degOffset = desired_mag_heading - headingMiddle; # positive value
   #   } elsif (headingMiddle < 60 and desired_mag_heading > 300) {
    #    desired_mag_heading = desired_mag_heading - 360;
     #   degOffset = desired_mag_heading - headingMiddle; # negative value
      #} else {
       # degOffset = desired_mag_heading - headingMiddle;
      #}
      
      me.pos_x = me.middleOffset + me.degOffset*(headScaleTickSpacing/5);
      #print("bug offset deg "~degOffset~"bug offset pix "~pos_x);
      me.blink = FALSE;
      #62px, 687px, 262px, 337px
      if (me.pos_x < (337/1024)*canvasWidth-(512/1024)*canvasWidth) {
        me.blink = TRUE;
        me.pos_x = (337/1024)*canvasWidth-(512/1024)*canvasWidth;
      } elsif (me.pos_x > (687/1024)*canvasWidth-(512/1024)*canvasWidth) {
        me.blink = TRUE;
        me.pos_x = (687/1024)*canvasWidth-(512/1024)*canvasWidth;
      }
      me.heading_bug_group.setTranslation(me.pos_x, -headScalePlace);
      if(me.topHeadingScaleShown() and (me.blink == FALSE or me.input.fiveHz.getValue() == TRUE)) {
        me.heading_bug.show();
      } else {
        me.heading_bug.hide();
      }
      if (mode == LANDING) {
        me.pos_x = me.middleOffsetHorz + me.degOffset*(pixelPerDegreeX);
        me.heading_bug_horz_group.setTranslation(me.pos_x, 0);
        me.heading_bug_horz.show();
      } else {
        me.heading_bug_horz.hide();
      }
    } else {
      me.heading_bug.hide();
      me.heading_bug_horz.hide();
    }
  },

  displayAltitude: func () {
    me.metric = me.input.units.getValue();
    me.alti = me.metric == TRUE ? me.input.alt_ft.getValue() * feet2meter : me.input.alt_ft.getValue();
    me.radAlt = me.input.ctrlRadar.getValue() == 1?(me.metric == TRUE ? me.input.rad_alt.getValue() * feet2meter : me.input.rad_alt.getValue()):nil;

    me.displayAltitudeScale(me.alti, me.radAlt);
    me.displayDigitalAltitude(me.alti, me.radAlt);
  },

  displayAltitudeScale: func (alt, radAlt) {
    me.metric = me.input.units.getValue();
    me.pixelPerFeet = nil;
    # determine which alt scale to use
    if(me.metric == 1) {
      me.pixelPerFeet = altimeterScaleHeight/50;
      if (alt_scale_mode == -1) {
        if (alt < 45) {
          alt_scale_mode = 0;
        } elsif (alt < 90) {
          alt_scale_mode = 1;
        } else {
          alt_scale_mode = 2;
          me.pixelPerFeet = altimeterScaleHeight/100;
        }
      } elsif (alt_scale_mode == 0) {
        if (alt < 45) {
          alt_scale_mode = 0;
        } else {
          alt_scale_mode = 1;
        }
      } elsif (alt_scale_mode == 1) {
        if (alt < 90 and alt >= 40) {
          alt_scale_mode = 1;
        } else if (alt >= 90) {
          alt_scale_mode = 2;
          me.pixelPerFeet = altimeterScaleHeight/100;
        } else if (alt < 40) {
          alt_scale_mode = 0;
        } else {
          alt_scale_mode = 1;
        }
      } elsif (alt_scale_mode == 2) {
        if (alt >= 85) {
          alt_scale_mode = 2;
          me.pixelPerFeet = altimeterScaleHeight/100;
        } else {
          alt_scale_mode = 1;
        }
      }
    } else {#imperial
      me.pixelPerFeet = altimeterScaleHeight/200;
      if (alt_scale_mode == -1) {
        if (alt < 190) {
          alt_scale_mode = 0;
        } elsif (alt < 380) {
          alt_scale_mode = 1;
        } else {
          alt_scale_mode = 2;
          me.pixelPerFeet = altimeterScaleHeight/500;
        }
      } elsif (alt_scale_mode == 0) {
        if (alt < 190) {
          alt_scale_mode = 0;
        } else {
          alt_scale_mode = 1;
        }
      } elsif (alt_scale_mode == 1) {
        if (alt < 380 and alt >= 180) {
          alt_scale_mode = 1;
        } else if (alt >= 380) {
          alt_scale_mode = 2;
          me.pixelPerFeet = altimeterScaleHeight/500;
        } else if (alt < 180) {
          alt_scale_mode = 0;
        } else {
          alt_scale_mode = 1;
        }
      } elsif (alt_scale_mode == 2) {
        if (alt >= 380) {
          alt_scale_mode = 2;
          me.pixelPerFeet = altimeterScaleHeight/500;
        } else {
          alt_scale_mode = 1;
        }
      }
    }
    if(me.verbose > 1) print("Alt scale mode = "~alt_scale_mode);
    if(me.verbose > 1) print("Alt = "~alt);
    #place the scale
    me.alt_pointer.setTranslation(scalePlace+indicatorOffset, 0);
    if (alt_scale_mode == 0) {
      me.alt_scale_factor = me.metric == 1 ? 50 : 200;
      me.offset = altimeterScaleHeight/me.alt_scale_factor * alt;#vertical placement of scale. Half-scale-height/alt-in-half-scale * alt
      if(me.verbose > 1) print("Alt offset = "~me.offset);
      me.alt_scale_grp_trans.setTranslation(scalePlace, me.offset);
      me.alt_scale_med.hide();
      me.alt_scale_high.hide();
      me.alt_scale_low.show();
      me.alt_higher.hide();
      me.alt_high.show();
      me.alt_med.show();
      me.alt_low.show();
      me.alt_low.setTranslation(numberOffset, 0);
      me.alt_med.setTranslation(numberOffset, -altimeterScaleHeight);
      me.alt_high.setTranslation(numberOffset, -6*altimeterScaleHeight/4);
      if(me.metric == TRUE) {
        me.alt_low.setText("0");
        me.alt_med.setText("50");
        me.alt_high.setText("100");
      } else {
        me.alt_low.setText("0");
        me.alt_med.setText("200");
        me.alt_high.setText("400");
      }
      if (radAlt != nil and radAlt < alt) {
        me.alt_scale_line.show();
      } else {
        me.alt_scale_line.hide();
      }
      # Show radar altimeter ground height
      if (radAlt != nil) {
        me.rad_offset = altimeterScaleHeight/me.alt_scale_factor * radAlt;
        me.rad_alt_pointer.setTranslation(indicatorOffset, me.rad_offset - me.offset);
        me.rad_alt_pointer.show();
        if ((-radPointerProxim) < me.rad_offset and me.rad_offset < radPointerProxim) {
          me.alt_pointer.hide();
        } else {
          me.alt_pointer.show();
        }
      } else {
        me.alt_pointer.show();
        me.rad_alt_pointer.hide();
      }
      me.alt_scale_grp.update();
      if(me.verbose > 2) print("alt " ~ sprintf("%3d", alt) ~ " radAlt:" ~ sprintf("%3d", radAlt) ~ " rad_offset:" ~ sprintf("%3d", me.rad_offset));
    } elsif (alt_scale_mode == 1) {
      me.alt_scale_factor = me.metric == TRUE ? 100 : 400;
      me.alt_scale_med.show();
      me.alt_scale_high.hide();
      me.alt_scale_low.hide();
      me.alt_higher.hide();
      me.alt_high.show();
      me.alt_med.show();
      me.alt_low.show();
      me.offset = 2*altimeterScaleHeight/me.alt_scale_factor * alt;#vertical placement of scale. Scale-height/alt-in-scale * alt
      if(me.verbose > 1) print("Alt offset = "~me.offset);
      me.alt_scale_grp_trans.setTranslation(scalePlace, me.offset);
      me.alt_low.setTranslation(numberOffset, 0);
      me.alt_med.setTranslation(numberOffset, -altimeterScaleHeight);
      me.alt_high.setTranslation(numberOffset, -altimeterScaleHeight*2);
      if(me.metric == TRUE) {
        me.alt_low.setText("0");
        me.alt_med.setText("50");
        me.alt_high.setText("100");
      } else {
        me.alt_low.setText("0");
        me.alt_med.setText("200");
        me.alt_high.setText("400");
      }
      # Show radar altimeter ground height
      if (radAlt != nil) {
        me.rad_offset = 2*altimeterScaleHeight/me.alt_scale_factor * radAlt;
        me.rad_alt_pointer.setTranslation(indicatorOffset, me.rad_offset - me.offset);
        me.rad_alt_pointer.show();
        if (radAlt < alt) {
          me.alt_scale_line.show();
        } else {
          me.alt_scale_line.hide();
        }
        if ((-radPointerProxim) < me.rad_offset and me.rad_offset < radPointerProxim) {
          me.alt_pointer.hide();
        } else {
          me.alt_pointer.show();
        }
      } else {
        me.alt_pointer.show();
        me.rad_alt_pointer.hide();
      }
      me.alt_scale_grp.update();
      #print("alt " ~ sprintf("%3d", alt) ~ " placing med " ~ sprintf("%3d", offset));
    } elsif (alt_scale_mode == 2) {
      me.alt_scale_factor = me.metric == TRUE ? 200 : 1000;
      me.alt_scale_med.hide();
      me.alt_scale_high.show();
      me.alt_scale_low.hide();
      me.alt_scale_line.hide();
      me.alt_higher.show();
      me.alt_high.show();
      me.alt_med.show();
      me.alt_low.show();

      me.fact = int(alt / (me.alt_scale_factor/2)) * (me.alt_scale_factor/2);
      me.factor = alt - me.fact + (me.alt_scale_factor/2);
      me.offset = 2*altimeterScaleHeight/me.alt_scale_factor * me.factor;#vertical placement of scale. Scale-height/alt-in-scale * alt

      if(me.verbose > 1) print("Alt offset = "~me.offset);
      me.alt_scale_grp_trans.setTranslation(scalePlace, me.offset);
      me.alt_low.setTranslation(numberOffset , 0);
      me.alt_med.setTranslation(numberOffset , -altimeterScaleHeight);
      me.alt_high.setTranslation(numberOffset , -2*altimeterScaleHeight);
      me.alt_higher.setTranslation(numberOffset , -3*altimeterScaleHeight);
      me.low = me.fact - me.alt_scale_factor/2;
      if(me.low > 1000) {
        me.alt_low.setText(sprintf("%.1f", me.low/1000));
      } else {
        me.alt_low.setText(sprintf("%d", me.low));
      }
      me.med = me.fact;
      if(me.med > 1000) {
        me.alt_med.setText(sprintf("%.1f", me.med/1000));
      } else {
        me.alt_med.setText(sprintf("%d", me.med));
      }
      me.high = me.fact + me.alt_scale_factor/2;
      if(me.high > 1000) {
        me.alt_high.setText(sprintf("%.1f", me.high/1000));
      } else {
        me.alt_high.setText(sprintf("%d", me.high));
      }
      me.higher = me.fact + me.alt_scale_factor;
      if(me.higher > 1000) {
        me.alt_higher.setText(sprintf("%.1f", me.higher/1000));
      } else {
        me.alt_higher.setText(sprintf("%d", me.higher));
      }
      if (radAlt != nil) {
        # Show radar altimeter ground height
        me.rad_offset = 2*altimeterScaleHeight/me.alt_scale_factor * (radAlt);
        me.rad_alt_pointer.setTranslation(indicatorOffset, me.rad_offset - me.offset);
        me.rad_alt_pointer.show();
        if ((-radPointerProxim) < me.rad_offset and me.rad_offset < radPointerProxim) {
          me.alt_pointer.hide();
        } else {
          me.alt_pointer.show();
        }
      } else {
        me.alt_pointer.show();
        me.rad_alt_pointer.hide();
      }
      me.alt_scale_grp.update();
      #print("alt " ~ sprintf("%3d", alt) ~ " radAlt:" ~ sprintf("%3d", radAlt) ~ " rad_offset:" ~ sprintf("%3d", me.rad_offset));
    }
  },

  displayDigitalAltitude: func (alt, radAlt) {
    me.alt.show();
    # alt and radAlt is in current unit
    # determine max radar alt in current unit
    me.radar_clamp = me.input.units.getValue() ==1 ? 100 : 100/feet2meter;
    me.alt_diff = me.input.units.getValue() ==1 ? 7 : 7/feet2meter;
    me.INT = FALSE;
    if (me.input.units.getValue() == FALSE and (me.input.wow2.getValue() == TRUE
        or (me.inter == TRUE and me.input.gearCmdNorm.getValue() == 0 and me.input.gearsPos.getValue() > 0)
        or (me.inter == TRUE and me.input.gearsPos.getValue() == 1))) {
      if (me.input.gearsPos.getValue() == 1 or me.input.fiveHz.getValue() == TRUE) {
        me.alt.setText("INT");
      } else {
        me.alt.setText("");
      }
      me.inter = TRUE;
      me.INT = TRUE;
    }
    if (radAlt == nil and me.input.ctrlRadar.getValue() == 1) {
      # Radar alt instrument not initialized yet
      if (me.INT == FALSE) {
        me.inter = FALSE;
        me.alt.setText("");
      }
      countQFE = 0;
      QFEcalibrated = FALSE;
      me.input.altCalibrated.setBoolValue(FALSE);
    } elsif (radAlt != nil and radAlt < me.radar_clamp) {
      if (me.INT == FALSE) {
        me.inter = FALSE;
        # in radar alt range
        me.alt.setText("R " ~ sprintf("%3d", clamp(radAlt, 0, me.radar_clamp)));
      }
      # check for QFE warning
      me.diff = radAlt - alt;
      if (countQFE == 0 and (me.diff > me.alt_diff or me.diff < -me.alt_diff)) {
        #print("QFE warning " ~ countQFE);
        # is not calibrated, and is not blinking
        QFEcalibrated = FALSE;
        me.input.altCalibrated.setBoolValue(FALSE);
        countQFE = 1;     
        #print("QFE not calibrated, and is not blinking");     
      } elsif (me.diff > -me.alt_diff and me.diff < me.alt_diff) {
          #is calibrated
        if (QFEcalibrated == FALSE and countQFE < 11) {
          # was not calibrated before, is now.
          #print("QFE was not calibrated before, is now. "~countQFE);
          countQFE = 11;
        }
        QFEcalibrated = TRUE;
        me.input.altCalibrated.setBoolValue(TRUE);
      } elsif (QFEcalibrated == 1 and (me.diff > me.alt_diff or me.diff < -me.alt_diff)) {
        # was calibrated before, is not anymore.
        #print("QFE was calibrated before, is not anymore. "~countQFE);
        countQFE = 1;
        QFEcalibrated = FALSE;
        me.input.altCalibrated.setBoolValue(FALSE);
      }
    } else {
      # is above height for checking for calibration
      countQFE = 0;
      #QFE = 0;
      QFEcalibrated = TRUE;
      me.input.altCalibrated.setBoolValue(TRUE);
      #print("QFE not calibrated, and is not blinking");
      if (me.INT == FALSE) {
        me.inter = FALSE;
        me.gElev_ft = me.input.elev_ft.getValue();
        me.gElev_m  = me.input.elev_m.getValue();

        if (me.gElev_ft == nil or me.gElev_m == nil) {
          me.alt.setText("");
        } else {
          me.metric = me.input.units.getValue();
          me.terrainAlt = me.metric == TRUE?me.gElev_m:me.gElev_ft;

          me.alt.setText(sprintf("%4d", clamp(me.terrainAlt, 0, 9999)));
        }
      }
    }
  },

  displayDesiredAltitudeLines: func (guideUseLines) {
    if (guideUseLines == FALSE) {
      me.desired_alt_delta_ft = nil;
      if(mode == TAKEOFF) {
        me.desired_alt_delta_ft = (500*M2FT)-me.input.alt_ft.getValue();
      } elsif (me.input.APLockAlt.getValue() == "altitude-hold" and me.input.APTgtAlt.getValue() != nil) {
        me.desired_alt_delta_ft = me.input.APTgtAlt.getValue()-me.input.alt_ft.getValue();
      } elsif (me.input.APLockAlt.getValue() == "agl-hold" and me.input.APTgtAgl.getValue() != nil) {
        me.desired_alt_delta_ft = me.input.APTgtAgl.getValue()-me.input.rad_alt.getValue();
      } elsif(me.input.RMActive.getValue() == 1 and me.input.RMCurrWaypoint.getValue() != nil and me.input.RMCurrWaypoint.getValue() >= 0) {
        me.idx = me.input.RMCurrWaypoint.getValue();
        me.rt_alt = getprop("autopilot/route-manager/route/wp["~me.idx~"]/altitude-ft");
        if(me.rt_alt != nil and me.rt_alt > 0) {
          me.desired_alt_delta_ft = me.rt_alt - me.input.alt_ft.getValue();
        }
      }# elsif (getprop("autopilot/locks/altitude") == "gs1-hold") {
      if(me.desired_alt_delta_ft != nil) {
        me.pos_y = clamp(-me.desired_alt_delta_ft*me.pixelPerFeet, -2.5*pixelPerDegreeY, 2.5*pixelPerDegreeY);

        me.desired_lines3.setTranslation(0, me.pos_y);
        me.desired_lines3.show();
      } else {
        me.desired_lines3.hide();
      }
      me.desired_lines2.hide();
    } else {
      me.desired_lines2.show();
      me.desired_lines3.show();
    }
  },

  displayLandingGuide: func (mode, deflect) {
    me.guideUseLines = FALSE;
    if(mode == LANDING) {
      me.deg = deflect;
      
      if (me.finalVisual == FALSE and (me.input.nav0InRange.getValue() == TRUE or me.input.TILS.getValue() == TRUE)) {
        me.deg = me.input.nav0HeadingDefl.getValue()*0.8;# -10 to +10, showed as -8 till +8

        if (me.input.nav0HasGS.getValue() == TRUE and me.input.nav0GSInRange.getValue() == TRUE) {
          me.factor = me.input.nav0GSNeedleDefl.getValue() * -1;
          if (me.factor < 0) {
            # manual states that they can move one length down and half length up. This is to limit to half up.
            # Maybe should clip instead of scale, not sure.
            me.factor *= 0.5;
          }
          me.dev3 = me.factor * 5 * pixelPerDegreeY +2.86*pixelPerDegreeY;
          me.dev2 = me.factor * 3 * pixelPerDegreeY +2.86*pixelPerDegreeY;
          me.desired_lines3.setTranslation(pixelPerDegreeX*me.deg, me.dev3);
          me.desired_lines2.setTranslation(pixelPerDegreeX*me.deg, me.dev2);
          me.guideUseLines = TRUE;
        }
      }
      me.desiredSink_deg = 2.86;
      if (me.finalVisual == TRUE) {
        me.sinkRateMax_mps = 2.8;
        me.groundspeed_mps = me.input.gs.getValue() != 0?me.input.gs.getValue() * KT2FPS * FT2M:0.0001;
        me.desiredSink_deg = math.asin(me.sinkRateMax_mps/me.groundspeed_mps)*R2D;
      }
      HUDnasal.main.landing_line.setTranslation(pixelPerDegreeX*me.deg, me.desiredSink_deg*pixelPerDegreeY);
      HUDnasal.main.landing_line.show();
    } else {
      HUDnasal.main.landing_line.hide();
    }
    return me.guideUseLines;
  },

  displayDigitalSpeed: func (mode) {
    me.mach = me.input.mach.getValue();
    me.metric = me.input.units.getValue();
    if(me.metric == TRUE) {
      # metric
      me.airspeedInt.hide();
      if (me.mach >= 0.5) 
      {
        me.airspeed.setText(sprintf("%.2f", me.mach));
      } else {
        me.speed = air2ground == TRUE?me.input.gs.getValue()*kts2kmh:me.input.ias.getValue() * kts2kmh;
        me.airspeed.setText(sprintf("%03d", me.speed));
      }
    } elsif (mode == LANDING or mode == TAKEOFF or me.mach < 0.5) {
      me.airspeedInt.hide();
      me.speed = air2ground == TRUE?me.input.gs.getValue():me.input.ias.getValue();
      me.type  = air2ground == TRUE?"GS":"KT";
      me.airspeed.setText(sprintf(me.type~"%03d", me.speed));
    } else {
      me.speed = air2ground == TRUE?me.input.gs.getValue():me.input.ias.getValue();
      me.type  = air2ground == TRUE?"GS":"KT";
      me.airspeedInt.setText(sprintf(me.type~"%03d", me.speed));
      me.airspeedInt.show();
      me.airspeed.setText(sprintf("M%.2f", me.mach));
    }

    if (mode == LANDING and me.input.alphaJSB.getValue() > 8.5) {
      me.airspeed.setTranslation(0, airspeedPlaceFinal);
      me.airspeedInt.setTranslation(0, airspeedPlaceFinal - (70/1024)*canvasWidth);
      me.final = TRUE;
    } elsif (mode != LANDING or (me.final == FALSE) or (me.final == TRUE and me.input.alphaJSB.getValue() < 5.5)) {
      me.airspeed.setTranslation(0, airspeedPlace);
      me.airspeedInt.setTranslation(0, airspeedPlace - (70/1024)*canvasWidth);
      me.final = FALSE;
    }
  },

  displayPitchLines: func (mode) {
    me.horizon_group2.setTranslation(0, pixelPerDegreeY * me.input.pitch.getValue());
    me.horizon_group3.setTranslation(0, pixelPerDegreeY * me.input.pitch.getValue());
    me.horizon_group4.setTranslation(0, pixelPerDegreeY * me.input.pitch.getValue());
    me.horizon_group.setTranslation(0, centerOffset);
    me.rot = -me.input.roll.getValue() * deg2rads;
    me.h_rot.setRotation(me.rot);
    if(mode == COMBAT) {
      me.horizon_group3.show();
      me.horizon_group4.show();
      me.horizon_dots.hide();
      me.horizon_line_gap.hide();
    } elsif (mode == LANDING) {
      me.horizon_group3.hide();
      me.horizon_group4.hide();
      me.horizon_dots.hide();
      me.horizon_line_gap.show();
    } else {
      me.horizon_group3.hide();
      me.horizon_group4.show();
      me.horizon_dots.show();
      me.horizon_line_gap.hide();
    }
  },

  displayTurnCoordinator: func () {
    if (me.input.sideslipOn.getValue() == TRUE) {
      if(me.input.srvTurn.getValue() == 1) {
        #me.t_rot.setRotation(getprop("/orientation/roll-deg") * deg2rads * 0.5);
        me.slip_indicator.setTranslation(clamp(me.input.beta.getValue()*20, -(150/1024)*canvasWidth, (150/1024)*canvasWidth), 0);
        #if(me.final == TRUE) {
        #  me.turn_group.setTranslation(sideslipPlaceXFinal, sideslipPlaceYFinal);
        #} else {
          me.turn_group.setTranslation(sideslipPlaceX, sideslipPlaceY);
        #}
      }
      me.turn_group.show();
    } else {
      me.turn_group.hide();
    }
  },

  displayQFE: func (mode) {
    me.DME = me.input.dme.getValue() != "---" and me.input.dme.getValue() != "" and me.input.dmeDist.getValue() != nil and me.input.dmeDist.getValue() != 0;
    if (mode == LANDING and me.input.nav0InRange.getValue() == TRUE) {
      if (me.input.TILS.getValue() == TRUE) {
        if (me.DME == TRUE) {
          me.qfe.setText("TILS/DME");
        } else {
          me.qfe.setText("TILS");
        }
        me.qfe.show();
      } else {
        if (me.DME == TRUE) {
          me.qfe.setText("ILS/DME");
        } else {
          me.qfe.setText("ILS");
        }
        me.qfe.show();
      }
    } elsif ((mode == LANDING or mode == NAV) and me.DME == TRUE) {
      me.qfe.setText("DME");
      me.qfe.show();
    } elsif (mode == COMBAT) {
      me.armSelect = me.input.station.getValue();
      if (me.armSelect > 0) {
        me.armament = getprop("payload/weight["~ (me.armSelect-1) ~"]/selected");
      } else {
        me.armament = "";
      }
      if(me.armSelect == 0) {
        me.qfe.setText("AKAN");
        me.qfe.show();
      } elsif(me.armament == "RB 24 Sidewinder") {
        me.qfe.setText("RB-24");
        me.qfe.show();
      } elsif(me.armament == "RB 24J Sidewinder") {
        me.qfe.setText("RB-24J");
        me.qfe.show();
      } elsif(me.armament == "RB 74 Sidewinder") {
        me.qfe.setText("RB-74");
        me.qfe.show();
      } elsif(me.armament == "M70 ARAK") {
        me.qfe.setText("M70 ARAK");
        me.qfe.show();
      } elsif(me.armament == "RB 71 Skyflash") {
        me.qfe.setText("RB-71");
        me.qfe.show();
      } elsif(me.armament == "RB 99 Amraam") {
        me.qfe.setText("RB-99");
        me.qfe.show();
      } elsif(me.armament == "RB 15F Attackrobot") {
        me.qfe.setText("RB-15F");
        me.qfe.show();
      } elsif(me.armament == "RB 04E Attackrobot") {
        me.qfe.setText("RB-04E");
        me.qfe.show();
      } elsif(me.armament == "RB 05A Attackrobot") {
        me.qfe.setText("RB-05A");
        me.qfe.show();
      } elsif(me.armament == "RB 75 Maverick") {
        me.qfe.setText("RB-75");
        me.qfe.show();
      } elsif(me.armament == "M71 Bomblavett") {
        me.qfe.setText("M71");
        me.qfe.show();
      } elsif(me.armament == "M71 Bomblavett (Retarded)") {
        me.qfe.setText("M71R");
        me.qfe.show();
      } elsif(me.armament == "M90 Bombkapsel") {
        me.qfe.setText("M90");
        me.qfe.show();
      } elsif(me.armament == "M55 AKAN") {
        me.qfe.setText("M55 AKAN");
        me.qfe.show();
      } elsif(me.armament == "TEST") {
        me.qfe.setText("TEST");
        me.qfe.show();
      } else {
        me.qfe.setText("None");
        me.qfe.show();
      }        
    } elsif (countQFE > 0) {
      # QFE is shown
      me.qfe.setText("QFE");
      if(countQFE == 1) {
        countQFE = 2;
      }
      if(countQFE < 10) {
         # blink the QFE
        if(me.input.fiveHz.getValue() == TRUE) {
          me.qfe.show();
        } else {
          me.qfe.hide();
        }
      } elsif (countQFE == 10) {
        #if(me.input.ias.getValue() < 10) {
          # adjust the altimeter (commented out after placing altimeter in plane)
          # var inhg = getprop("systems/static/pressure-inhg");
          #setprop("instrumentation/altimeter/setting-inhg", inhg);
         # countQFE = 11;
          #print("QFE adjusted " ~ inhg);
        #} else {
          countQFE = -100;
        #}
      } elsif (countQFE < 125) {
        # QFE is steady
        countQFE = countQFE + 1;
        me.qfe.show();
        #print("steady on");
      } else {
        countQFE = -100;
        QFEcalibrated = TRUE;
        me.input.altCalibrated.setBoolValue(TRUE);
        #print("off");
      }
    } else {
      me.qfe.hide();
      countQFE = clamp(countQFE+1, -101, 0);
      #print("hide  off");
    }
    #print("QFE count " ~ countQFE);
  },

  showReticle: func (mode, cannon, out_of_ammo) {
    if (mode == COMBAT and cannon == TRUE) {
      me.showSidewind(FALSE);
      
      me.reticle_cannon.setTranslation(0, centerOffset);
      me.reticle_cannon.show();
      me.reticle_missile.hide();
      me.reticle_c_missile.hide();
      air2air = FALSE;
      air2ground = FALSE;
      return me.showFlightPathVector(1, out_of_ammo, mode);
    } elsif (mode == COMBAT and cannon == FALSE) {
      me.armament = getprop("payload/weight["~ (me.input.station.getValue()-1) ~"]/selected");
      if(me.armament == "M70 ARAK") {
        air2air = FALSE;
        air2ground = TRUE;
        me.showSidewind(FALSE);
        me.reticle_cannon.setTranslation(0, centerOffset);
        me.reticle_cannon.show();
        me.reticle_missile.hide();
        me.reticle_c_missile.show();
      } elsif(me.armament == "RB 24 Sidewinder") {
        air2air = TRUE;
        air2ground = FALSE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.show();
        me.reticle_c_missile.hide();
      } elsif(me.armament == "RB 24J Sidewinder") {
        air2air = TRUE;
        air2ground = FALSE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.show();
        me.reticle_c_missile.hide();
      } elsif(me.armament == "RB 74 Sidewinder") {
        air2air = TRUE;
        air2ground = FALSE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.show();
        me.reticle_c_missile.hide();
      } elsif(me.armament == "RB 71 Skyflash") {
        air2air = TRUE;
        air2ground = FALSE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.show();
        me.reticle_c_missile.hide();
      } elsif(me.armament == "RB 99 Amraam") {
        air2air = TRUE;
        air2ground = FALSE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.show();
        me.reticle_c_missile.hide();
      } elsif(me.armament == "RB 15F Attackrobot") {
        air2air = FALSE;
        air2ground = TRUE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.hide();
        me.reticle_c_missile.show();
      } elsif(me.armament == "RB 04E Attackrobot") {
        air2air = FALSE;
        air2ground = TRUE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.hide();
        me.reticle_c_missile.show();
      } elsif(me.armament == "RB 05A Attackrobot") {
        air2air = FALSE;
        air2ground = TRUE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.hide();
        me.reticle_c_missile.show();
      } elsif(me.armament == "RB 75 Maverick") {
        air2air = FALSE;
        air2ground = TRUE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.hide();
        me.reticle_c_missile.show();
      } elsif(me.armament == "M71 Bomblavett") {
        air2air = FALSE;
        air2ground = TRUE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.hide();
        me.reticle_c_missile.show();
      } elsif(me.armament == "M71 Bomblavett (Retarded)") {
        air2air = FALSE;
        air2ground = TRUE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.hide();
        me.reticle_c_missile.show();
      } elsif(me.armament == "M90 Bombkapsel") {
        air2air = FALSE;
        air2ground = TRUE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.hide();
        me.reticle_c_missile.show();
      } elsif(me.armament == "TEST") {
        air2air = TRUE;
        air2ground = FALSE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.show();
        me.reticle_c_missile.hide();
      } else {
        air2air = FALSE;
        air2ground = FALSE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.hide();
        me.reticle_c_missile.hide();
      }
      return me.showFlightPathVector(1, out_of_ammo, mode);
    } elsif (mode != TAKEOFF and mode != LANDING) {# or me.input.wow_nlg.getValue() == 0
      # flight path vector (FPV)
      air2air = FALSE;
      air2ground = FALSE;
      me.showSidewind(FALSE);
      me.reticle_cannon.hide();
      me.reticle_missile.hide();
      me.reticle_c_missile.hide();
      return me.showFlightPathVector(1, FALSE, mode);
    } elsif(mode == TAKEOFF) {      
      air2air = FALSE;
      air2ground = FALSE;
      me.showSidewind(TRUE);
      me.reticle_cannon.hide();
      me.reticle_missile.hide();
      me.reticle_c_missile.hide();
      return me.showFlightPathVector(!me.input.wow0.getValue(), FALSE, mode);
    } elsif(mode == LANDING) {      
      air2air = FALSE;
      air2ground = FALSE;
      me.showSidewind(FALSE);
      me.reticle_cannon.hide();
      me.reticle_missile.hide();
      me.reticle_c_missile.hide();
      return me.showFlightPathVector(!me.input.wow0.getValue(), FALSE, mode);
    }
    return 0;
  },

  showSidewind: func(show) {
    if(show == TRUE) {
      #move sidewind symbol according to side wind:
      me.wind_heading = me.input.windHeading.getValue();
      me.wind_speed = me.input.windSpeed.getValue();
      me.heading = me.input.hdgReal.getValue();
      #var speed = me.input.ias.getValue();
      me.angle = (me.wind_heading -me.heading) * (math.pi / 180.0); 
      me.wind_side = math.sin(me.angle) * me.wind_speed;
      #print((wind_heading -heading) ~ " " ~ wind_side);
      me.takeoff_symbol.setTranslation(clamp(-me.wind_side * sidewindPerKnot, -max_width, max_width), sidewindPosition);
      if(me.input.gearsPos.getValue() < 1 and me.input.gearsPos.getValue() > 0) {# gears are being deployed or retracted
        if(me.input.tenHz.getValue() == 1) {
          me.takeoff_symbol.show();
        } else {
          me.takeoff_symbol.hide();
        }
      } else {
        me.takeoff_symbol.show();
      }
    } else {
      me.takeoff_symbol.hide();
    }
  },

  showFlightPathVector: func (show, out_of_ammo, mode) {
    if(show == TRUE) {
      me.vel_gx = me.input.speed_n.getValue();
      me.vel_gy = me.input.speed_e.getValue();
      me.vel_gz = me.input.speed_d.getValue();
   
      me.yaw = me.input.hdgReal.getValue() * deg2rads;
      me.roll = me.input.roll.getValue() * deg2rads;
      me.pitch = me.input.pitch.getValue() * deg2rads;
   
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
   
      me.dir_y = math.atan2(round0(me.vel_bz), math.max(me.vel_bx, 0.001)) * rad2deg;
      me.dir_x  = math.atan2(round0(me.vel_by), math.max(me.vel_bx, 0.001)) * rad2deg;
      
      me.pos_x = clamp(me.dir_x * pixelPerDegreeX, -max_width, max_width);
      me.pos_y = clamp((me.dir_y * pixelPerDegreeY)+centerOffset, -max_width, (430/1024)*canvasWidth);

      if ( out_of_ammo == TRUE) {
        me.aim_reticle.hide();
        me.aim_reticle_fin.hide();
        me.reticle_no_ammo.show();
        me.reticle_no_ammo.setTranslation(me.pos_x, me.pos_y);
      } else {
        me.reticle_no_ammo.hide();
        me.aim_reticle.show();
        
        me.reticle_group.setTranslation(me.pos_x, me.pos_y);
                
        if (mode == LANDING and me.finalVisual == FALSE) {
          # move fin to alpha
          me.alpha = me.input.alphaJSB.getValue();
          me.speed = me.input.ias.getValue();
          me.highAlpha = getprop("ja37/avionics/high-alpha");
          me.speed_min = me.highAlpha==TRUE?105:150;
          me.speed_max = me.highAlpha==TRUE?134:170;
          me.translation_speed = 0;
          if (me.speed < me.speed_min) {
            # too low landing speed
            me.translation_speed = (me.speed_min - me.speed)*2;
          } elsif (me.speed > me.speed_max) {
            # too high landing speed
            me.translation_speed = (me.speed_max - me.speed)*2;
          }
          me.idealAlpha = 15.5;# the ideal aoa for landing.
          if (me.highAlpha == FALSE) {
            me.myWeight = getprop("fdm/jsbsim/inertia/weight-lbs");
            me.idealAlpha = 9 + ((me.myWeight - 28000) / (38000 - 28000)) * (12 - 9);#is 9-12 depending on weight
            me.idealAlpha = ja37.clamp(me.idealAlpha, 9, 12);
          }
          me.translation = (me.alpha-me.idealAlpha)*6.5;
          if (math.abs(me.translation) < math.abs(me.translation_speed)) {
            # using speed as guide for tail
            me.translation = me.translation_speed;
          }
          me.translation = clamp(me.translation, -60, 30);
          me.reticle_fin_group.setTranslation(0, (me.translation/1024)*canvasWidth);
          if (me.alpha > me.idealAlpha+3) {
            # blink the fin if alpha is way too high
            if(me.input.tenHz.getValue() == TRUE) {
              me.aim_reticle_fin.show();
            } else {
              me.aim_reticle_fin.hide();
            }
          } else {
            me.aim_reticle_fin.show();
          }
        } else {
          me.reticle_fin_group.setTranslation(0, 0);
          me.aim_reticle_fin.show();
        }
      }    
      return me.dir_x;
    } else {
      me.aim_reticle_fin.hide();
      me.aim_reticle.hide();
      me.reticle_no_ammo.hide();
      return 0;
    }
  },

  showDistanceScale: func (mode, fallTime) {
    if(mode == TAKEOFF) {
      me.line = (200/1024)*canvasWidth;

      # rotation speeds:
      #28725 lbm -> 250 km/h
      #40350 lbm -> 280 km/h
      # extra/inter-polation:
      # f(x) = y1 + ((x - x1) / (x2 - x1)) * (y2 - y1)
      me.weight = getprop("fdm/jsbsim/inertia/weight-lbs");
      me.rotationSpeed = 250+((me.weight-28725)/(40350-28725))*(280-250);#km/h
      # as per manual, minimum rotation speed is 250:
      me.rotationSpeed = ja37.clamp(me.rotationSpeed, 250, 1000);
      #rotationSpeed = getprop("fdm/jsbsim/systems/flight/rotation-speed");
      me.pixelPerKmh = (2/3*me.line)/me.rotationSpeed;
      if(me.input.ias.getValue() < 75/kts2kmh) {
        me.mySpeed.setTranslation(me.pixelPerKmh*75, 0);
      } else {
        me.pos = me.pixelPerKmh*me.input.ias.getValue()*kts2kmh;
        if(me.pos > me.line) {
          me.pos = me.line;
        }
        me.mySpeed.setTranslation(me.pos, 0);
      }      
      me.targetSpeed.setTranslation(2/3*me.line, 0);
      me.targetSpeed.show();
      me.mySpeed.show();
      me.targetDistance1.hide();
      me.targetDistance2.hide();
      me.distanceText.hide();
      me.distanceScale.show();
      me.dist_scale_group.show();
    } elsif (mode == COMBAT) {
      if (radar_logic.selection != nil) {
        me.line = (200/1024)*canvasWidth;
        me.armSelect = me.input.station.getValue();
        if (me.armSelect > 0) {
          me.armament = getprop("payload/weight["~ (me.armSelect-1) ~"]/selected");
        } else {
          me.armament = "";
        }
        me.minDist = nil;# meters
        me.maxDist = nil;# meters
        me.currDist = radar_logic.selection.get_range()*NM2M;
        me.unit = "meters";
        me.blink = FALSE;
        me.shown = TRUE;
        if(me.armSelect == 0) {
          # cannon
          me.minDist =  100;
          me.maxDist = 2500;# as per sources
        } elsif (me.armament == "RB 24 Sidewinder") {
          # sidewinders
          me.minDist =   400;
          me.maxDist = 12801.6;
        } elsif (me.armament == "RB 24J Sidewinder") {
          # sidewinders
          me.minDist =   300;# authentic: (1000ft)
          me.maxDist = 14500;
        } elsif (me.armament == "RB 74 Sidewinder") {
          # sidewinders
          me.minDist =   325;
          me.maxDist = 17964.4;
        } elsif (me.armament == "RB 71 Skyflash") {
          # skyflash
          me.minDist =   350;
          me.maxDist = 40744;
        } elsif (me.armament == "RB 99 Amraam") {
          # amraam
          me.minDist =   400;
          me.maxDist = 71857.6;
        } elsif (me.armament == "RB 15F Attackrobot") {
          # robot 15F
          me.minDist =   400;
          me.maxDist = 150000;
        } elsif (me.armament == "RB 04E Attackrobot") {
          # robot 15F
          me.minDist =   0.1 * NM2M;
          me.maxDist = 17.28 * NM2M;
        } elsif (me.armament == "RB 05A Attackrobot") {
          # robot 15F
          me.minDist =   0.2 * NM2M;
          me.maxDist = 4.86 * NM2M;
        } elsif (me.armament == "RB 75 Maverick") {
          # robot 15F
          me.minDist =   0.2 * NM2M;
          me.maxDist = 12 * NM2M;
        } elsif (me.armament == "M55 AKAN") {
          # robot 15F
          me.minDist =   0;
          me.maxDist = 2800;
        } elsif (me.armament == "M71 Bomblavett") {
          # robot 15F
          me.unit = "seconds";
          me.minDist =   4;
          me.maxDist =  16;
        } elsif (me.armament == "M71 Bomblavett (Retarded)") {
          # robot 15F
          me.unit = "seconds";
          me.minDist =   4;
          me.maxDist =  16;
        } elsif (me.armament == "M90 Bombkapsel") {
          # robot 15F
          me.minDist =   0.1 * NM2M;
          me.maxDist = 8 * NM2M;
        } elsif (me.armament == "M70 ARAK") {
          # Rocket pod
          me.minDist =   200;
          me.maxDist =  2000;
        } elsif (me.armament == "TEST") {
          # test
          me.minDist =     0;
          me.maxDist =180000;
        }
        if(me.currDist != nil and me.minDist != nil) {
          if (me.unit == "meters") {
            me.pixelPerMeterLine = (3/5*me.line)/(me.maxDist - me.minDist);
            me.startDist = (me.minDist - ((me.maxDist - me.minDist)/3));
            me.pos = me.pixelPerMeterLine*(me.currDist-me.startDist);
            me.pos = clamp(me.pos, 0, me.line);
            me.mySpeed.setTranslation(me.pos, 0);
          } else {
            me.pixelPerMeterLine = (3/5*me.line)/(me.maxDist - me.minDist);
            me.startDist = (me.minDist - ((me.maxDist - me.minDist)/3));
            me.pos = me.pixelPerMeterLine*(me.fallTime-me.startDist);
            me.pos = clamp(me.pos, 0, me.line);
            me.mySpeed.setTranslation(me.pos, 0);
            if (fallTime < 4) {
              me.blink = TRUE;
            }
            if (fallTime > 16) {
              me.shown = FALSE;
            }
          }
          if(me.shown == TRUE and (me.blink == FALSE or me.input.tenHz.getValue() == TRUE)) {
            me.mySpeed.show();
          } else {
            me.mySpeed.hide();
          }
        } else {
          me.mySpeed.hide();
        }
        me.targetDistance1.setTranslation(1/5*me.line, 0);
        me.targetDistance2.setTranslation(4/5*me.line, 0);

        me.targetSpeed.hide();
        if(me.shown == TRUE and (me.blink == FALSE or me.input.tenHz.getValue() == TRUE)) {
          me.targetDistance1.show();
          me.targetDistance2.show();
          me.distanceScale.show();
        } else {
          me.targetDistance1.hide();
          me.targetDistance2.hide();
          me.distanceScale.hide();
        }
      } else {
        me.mySpeed.hide();
        me.targetSpeed.hide();
        me.targetDistance1.hide();
        me.targetDistance2.hide();
        me.distanceScale.hide();
      }
      me.ammo = armament.ammoCount(me.input.station.getValue());
      if (me.input.station.getValue() == 0) {
        me.distanceText.setText(sprintf("%3d", me.ammo));
        me.distanceText.show();
      } elsif (me.ammo != -1) {
        me.distanceText.setText(sprintf("%1d", me.ammo));
        me.distanceText.show();
      } else {
        me.distanceText.hide();
      }
      me.dist_scale_group.show();
    } elsif (me.input.dme.getValue() != "---" and me.input.dme.getValue() != "" and me.input.dmeDist.getValue() != nil and me.input.dmeDist.getValue() != 0) {
      me.distance = me.input.dmeDist.getValue();
      me.line = (200/1024)*canvasWidth;
      me.maxDist = 20;
      me.pixelPerMeterLine = (me.line)/(me.maxDist);
      me.pos = me.pixelPerMeterLine*me.distance;
      me.pos = clamp(me.pos, 0, me.line);
      me.mySpeed.setTranslation(me.pos, 0);
      me.mySpeed.show();

      me.targetDistance1.setTranslation(0, 0);
      me.distanceText.setText(sprintf("%.1f", me.input.units.getValue() == 1  ? me.distance*kts2kmh : me.distance));

      me.targetSpeed.hide();
      me.targetDistance1.show();
      me.targetDistance2.hide();
      me.distanceText.show();
      me.distanceScale.show();
      me.dist_scale_group.show();
    } elsif (me.input.RMActive.getValue() == TRUE and me.input.rmDist.getValue() != nil) {
      me.distance = me.input.rmDist.getValue();
      me.line = (200/1024)*canvasWidth;
      me.maxDist = 20;
      me.pixelPerMeterLine = (me.line)/(me.maxDist);
      me.pos = me.pixelPerMeterLine*me.distance;
      me.pos = clamp(me.pos, 0, me.line);
      me.mySpeed.setTranslation(me.pos, 0);
      me.mySpeed.show();

      me.targetDistance1.setTranslation(0, 0);
      me.distanceText.setText(sprintf("%.1f", me.input.units.getValue() == 1  ? me.distance*kts2kmh : me.distance));

      me.targetSpeed.hide();
      me.targetDistance1.hide();
      me.targetDistance2.hide();
      me.distanceText.show();
      me.distanceScale.show();
      me.dist_scale_group.show();
    } else {
      me.dist_scale_group.hide();
    }
  },

  displayTower: func () {
    me.towerAlt = me.input.towerAlt.getValue();
    me.towerLat = me.input.towerLat.getValue();
    me.towerLon = me.input.towerLon.getValue();
    if(mode != COMBAT and me.towerAlt != nil and me.towerLat != nil and me.towerLon != nil) {# and me.final == FALSE
      me.towerPos = geo.Coord.new();
      me.towerPos.set_latlon(me.towerLat, me.towerLon, me.towerAlt*FT2M);
      me.showme = TRUE;

      me.hud_pos = radar_logic.ContactGPS.new(getprop("sim/tower/airport-id"), me.towerPos);
      if(me.hud_pos != nil) {
        me.distance = me.hud_pos.get_range()*NM2M;
        me.pos_x = me.hud_pos.get_cartesian()[0];
        me.pos_y = me.hud_pos.get_cartesian()[1];

        if(me.pos_x > (512/1024)*canvasWidth) {
          me.showme = FALSE;
        } elsif(me.pos_x < -(512/1024)*canvasWidth) {
          me.showme = FALSE;
        } elsif(me.pos_y > (512/1024)*canvasWidth) {
          me.showme = FALSE;
        } elsif(me.pos_y < -(512/1024)*canvasWidth) {
          me.showme = FALSE;
        }

        if(me.showme == TRUE) {
          me.tower_symbol.setTranslation(me.pos_x, me.pos_y);
          me.tower_dist = me.input.units.getValue() ==1  ? me.distance : me.distance/kts2kmh;
          if(me.tower_dist < 10000) {
            me.tower_symbol_dist.setText(sprintf("%.1f", me.tower_dist/1000));
          } else {
            me.tower_symbol_dist.setText(sprintf("%02d", me.tower_dist/1000));
          }          
          me.tower_symbol_icao.setText(me.hud_pos.get_Callsign());
          me.tower_symbol.show();
          me.tower_symbol.update();
        } else {
          me.tower_symbol.hide();
        }
      } else {
        me.tower_symbol.hide();
      }
    } else {
      me.tower_symbol.hide();
    }
  },

  displayCCIP: func () {
    if(mode == COMBAT) {

      me.armSelect = me.input.station.getValue();
      if(me.armSelect != 0 and (getprop("payload/weight["~ (me.armSelect-1) ~"]/selected") == "M71 Bomblavett" or getprop("payload/weight["~ (me.armSelect-1) ~"]/selected") == "M71 Bomblavett (Retarded)")) {

        me.bomb = nil;
        if(armament.AIM.active[me.armSelect-1] != nil) {
          me.bomb = armament.AIM.active[me.armSelect-1];
        } else {
          me.ccip_symbol.hide();
          return 20;
        }

        me.agl = getprop("position/altitude-agl-ft")*FT2M;
        me.alti = getprop("position/altitude-ft")*FT2M;
        me.roll = getprop("orientation/roll-deg");
        me.vel = getprop("velocities/groundspeed-kt")*0.5144;#m/s
        me.dens = getprop("fdm/jsbsim/atmosphere/density-altitude");
        me.mach = getprop("velocities/mach");
        me.speed_down_fps = getprop("velocities/speed-down-fps");
        me.speed_east_fps = getprop("velocities/speed-east-fps");
        me.speed_north_fps = getprop("velocities/speed-north-fps");

        me.t = 0.0;
        me.dt = 0.1;
        me.altC = me.agl;
        me.vel_z = -me.speed_down_fps*FT2M;#positive upwards
        me.fps_z = -me.speed_down_fps;
        me.vel_x = math.sqrt(me.speed_east_fps*me.speed_east_fps+me.speed_north_fps*me.speed_north_fps)*FT2M;
        me.fps_x = me.vel_x * M2FT;

        me.rs = me.bomb.rho_sndspeed(me.dens-(me.agl/2)*M2FT);
        me.rho = me.rs[0];
        me.Cd = me.bomb.drag(me.mach);
        me.mass = me.bomb.weight_launch_lbm / armament.slugs_to_lbm;
        me.q = 0.5 * me.rho * me.fps_z * me.fps_z;
        me.deacc = (me.Cd * me.q * me.bomb.eda) / me.mass;

        while (me.altC > 0 and me.t <= 16) {#16 secs is max fall time according to manual
          me.t += me.dt;
          me.acc = -9.81 + me.deacc * FT2M;
          me.vel_z += me.acc * me.dt;
          me.altC = me.altC + me.vel_z*me.dt+0.5*me.acc*me.dt*me.dt;
        }
        #printf("predict fall time=%0.1f", t);

        if (me.t >= 16) {
          me.ccip_symbol.hide();
          return me.t;
        }
        #t -= 0.75 * math.cos(pitch*D2R);            # fudge factor

        me.q = 0.5 * me.rho * me.fps_x * me.fps_x;
        me.deacc = (me.Cd * me.q * me.bomb.eda) / me.mass;
        me.acc = -me.deacc * FT2M;
        
        me.fps_x_final = me.t*me.acc+me.fps_x;# calc final horz speed
        me.fps_x_average = (me.fps_x-(me.fps_x-me.fps_x_final)*0.5);
        me.mach_average = me.fps_x_average / me.rs[1];
        
        me.Cd = me.bomb.drag(me.mach_average);
        me.q = 0.5 * me.rho * me.fps_x_average * me.fps_x_average;
        me.deacc = (me.Cd * me.q * me.bomb.eda) / me.mass;
        me.acc = -me.deacc * FT2M;
        me.dist = me.vel_x*me.t+0.5*me.acc*me.t*me.t;

        me.ac = geo.aircraft_position();
        me.ccipPos = geo.Coord.new(me.ac);

        # we calc heading from composite speeds, due to alpha and beta might influence direction bombs will fall:
        me.vectorMag = math.sqrt(me.speed_east_fps*me.speed_east_fps+me.speed_north_fps*me.speed_north_fps);
        me.heading = -math.asin(me.speed_north_fps/me.vectorMag)*R2D+90;#divide by vector mag, to get normalized unit vector length
        if (me.speed_east_fps/me.vectorMag < 0) {
          me.heading = -me.heading;
          while (me.heading > 360) {
            me.heading -= 360;
          }
          while (me.heading < 0) {
            me.heading += 360;
          }
        }
        me.ccipPos.apply_course_distance(me.heading, me.dist);
        #var elev = geo.elevation(ac.lat(), ac.lon());
        me.elev = me.alti-me.agl;#faster
        me.ccipPos.set_alt(me.elev);
        


        me.showme = TRUE;

        me.hud_pos = radar_logic.ContactGPS.new("CCIP", me.ccipPos);
        if(me.hud_pos != nil) {
          me.distance = me.hud_pos.get_range()*NM2M;
          me.pos_x = me.hud_pos.get_cartesian()[0];
          me.pos_y = me.hud_pos.get_cartesian()[1];

          #printf("dist=%0.1f (%3d , %3d)", dist, pos_x, pos_y);

          if(me.pos_x > (512/1024)*canvasWidth) {
            me.showme = FALSE;
          } elsif(me.pos_x < -(512/1024)*canvasWidth) {
            me.showme = FALSE;
          } elsif(me.pos_y > (512/1024)*canvasWidth) {
            me.showme = FALSE;
          } elsif(me.pos_y < -(512/1024)*canvasWidth) {
            me.showme = FALSE;
          }

          if(me.showme == TRUE) {
            me.ccip_symbol.setTranslation(me.pos_x, me.pos_y);
            me.ccip_symbol.show();
            me.ccip_symbol.update();
          } else {
            me.ccip_symbol.hide();
          }
        } else {
          me.ccip_symbol.hide();
        }
        return me.t;
      } else {
        me.ccip_symbol.hide();
      }
    } else {
      me.ccip_symbol.hide();
    }
    return 20;
  },

  displayRadarTracks: func (mode) {
    me.track_index = 1;
    me.selection_updated = FALSE;

    if(me.input.tracks_enabled.getValue() == 1 and me.input.radar_serv.getValue() > 0) {
      me.radar_group.show();

      me.selection = radar_logic.selection;

      if (me.selection != nil and me.selection.parents[0] == radar_logic.ContactGPS) {
        me.displayRadarTrack(me.selection);
      }

      # do circles here
      foreach(hud_pos; radar_logic.tracks) {
        me.displayRadarTrack(hud_pos);
      }
      if(me.track_index != -1) {
        #hide the the rest unused circles
        for(var i = me.track_index; i < maxTracks ; i+=1) {
          me.target_circle[i].hide();
        }
      }
      if(me.selection_updated == FALSE) {
        me.target_circle[0].hide();
      }
      #me.target_group.update();
      

      # draw selection
      if(me.selection != nil and me.selection.isValid() == TRUE and me.selection_updated == TRUE) {
        # selection is currently in forward looking radar view
        me.blink = FALSE;

        me.pos_x = me.selection.get_cartesian()[0];
        me.pos_y = me.selection.get_cartesian()[1];

        if (me.pos_y != 0 and me.pos_x != 0 and (me.pos_x > (512/1024)*canvasWidth or me.pos_y > (512/1024)*canvasWidth or me.pos_x < -(512/1024)*canvasWidth or me.pos_y < -(462/1024)*canvasWidth)) {
          # outside HUD view, we then use polar coordinates to find where on the border it should be displayed
          # notice we dont use the top 50 texels of the HUD, due to semi circles would become invisible.

          # TODO: the airplane axis should be uses as origin.
          me.angle = math.atan2(-me.pos_y, me.pos_x) * rad2deg;
          
          if (me.angle > -45 and me.angle < 42.06) {
            # right side
            me.pos_x = (512/1024)*canvasWidth;
            me.pos_y = -math.tan(me.angle*deg2rads) * (512/1024)*canvasWidth;
          } elsif (me.angle > 137.94 or me.angle < -135) {
            # left side
            me.pos_x = -(512/1024)*canvasWidth;
            me.pos_y = math.tan(me.angle*deg2rads) * (512/1024)*canvasWidth;
          } elsif (me.angle > 42.06 and me.angle < 137.94) {
            # top side
            me.pos_x = 1/math.tan(me.angle*deg2rads) * (462/1024)*canvasWidth;
            me.pos_y = -(462/1024)*canvasWidth;
          } elsif (me.angle < -45 and me.angle > -135) {
            # bottom side
            me.pos_x = -1/math.tan(me.angle*deg2rads) * (512/1024)*canvasWidth;
            me.pos_y = (512/1024)*canvasWidth;
          }
        }

        if(me.pos_x >= (512/1024)*canvasWidth) {#since radar logic run slower than HUD loop, this must be >= check to prevent erratic blinking since pos is being overwritten
          me.blink = TRUE;
          me.pos_x = (512/1024)*canvasWidth;
        } elsif (me.pos_x <= -(512/1024)*canvasWidth) {
          me.blink = TRUE;
          me.pos_x = -(512/1024)*canvasWidth;
        }
        if(me.pos_y >= (512/1024)*canvasWidth) {
          me.blink = TRUE;
          me.pos_y = (512/1024)*canvasWidth;
        } elsif(me.pos_y <= -(462/1024)*canvasWidth) {
          me.blink = TRUE;
          me.pos_y = -(462/1024)*canvasWidth;
        }
        if(me.selection.get_type() != radar_logic.ORDNANCE and mode == COMBAT) {
          #targetable
          #diamond_node = selection[6];
          armament.contact = me.selection;
          me.diamond_group.setTranslation(me.pos_x, me.pos_y);
          me.diamond_dista = me.input.units.getValue() ==1  ? me.selection.get_range()*NM2M : me.selection.get_range()*1000;
          
          if(me.diamond_dista < 10000) {
            me.diamond_dist.setText(sprintf("%.1f", me.diamond_dista/1000));
          } else {
            me.diamond_dist.setText(sprintf("%02d", me.diamond_dista/1000));
          }
          if (me.input.callsign.getValue() == TRUE) {
            me.diamond_name.setText(me.selection.get_Callsign());
          } else {
            me.diamond_name.setText(me.selection.get_model());
          }
          if (me.pos_x > (100/1024)*canvasWidth) {
            me.diamond_dist.setAlignment("right-top");
            me.diamond_dist.setTranslation(-(40/1024)*canvasWidth, (55/1024)*canvasWidth);
            me.diamond_name.setAlignment("right-bottom");
            me.diamond_name.setTranslation(-(40/1024)*canvasWidth, -(55/1024)*canvasWidth);
          } elsif (me.pos_x < -(100/1024)*canvasWidth) {
            me.diamond_dist.setAlignment("left-top");
            me.diamond_dist.setTranslation((40/1024)*canvasWidth, (55/1024)*canvasWidth);
            me.diamond_name.setAlignment("left-bottom");
            me.diamond_name.setTranslation((40/1024)*canvasWidth, -(55/1024)*canvasWidth);
          }
          me.target_circle[me.selection_index].hide();


          me.armSelect = me.input.station.getValue();
          me.displayDiamond = 0;
          #print();
          me.roll = me.input.roll.getValue();
          if(armament.AIM.active[me.armSelect-1] != nil and armament.AIM.active[me.armSelect-1].status == armament.MISSILE_LOCK
             and (armament.AIM.active[me.armSelect-1].rail == TRUE or (me.roll > -90 and me.roll < 90))) {
            # lock and not inverted if the missiles is to be dropped
            me.weak = armament.AIM.active[me.armSelect-1].trackWeak;
            if (me.weak == TRUE) {
              me.displayDiamond = 1;
            } else {
              me.displayDiamond = 2;
            }
          }		  
		  
          #var bearing = diamond_node.getNode("radar/bearing-deg").getValue();
          #var heading = diamond_node.getNode("orientation/true-heading-deg").getValue();
          #var speed = diamond_node.getNode("velocities/true-airspeed-kt").getValue();
          #var down = me.myHeading+180.0;
          #var relative_heading = heading + down - 90.0;
          #var relative_speed = speed/10.0;
          #var pos_y = relative_speed * math.sin(relative_heading/rad2deg);
          #var pos_x = relative_speed * math.cos(relative_heading/rad2deg);

          #if(me.track_line != nil) {
          #  me.diamond_group_line.removeAllChildren();
          #}

          #me.track_line = me.diamond_group_line.createChild("path")
          #               .lineTo( pos_x, pos_y)
          #               .setStrokeLineWidth(w)
          #               .setColor(r,g,b, a);
          #print("diamond="~diamond~" blink="~blink);
          if (me.displayDiamond > 0) {
            me.target_air.hide();
            me.target_ground.hide();
            me.target_sea.hide();

            if (me.blink == TRUE) {
              if((me.displayDiamond == 1 and me.input.fiveHz.getValue() == TRUE) or (me.displayDiamond == 2 and me.input.tenHz.getValue() == TRUE)) {
                me.diamond.show();
              } else {
                me.diamond.hide();
              }
            } else {
              if (me.diamond == 1 or me.input.tenHz.getValue() == TRUE) {
                me.diamond.show();
              } else {
                me.diamond.hide();
              }
            }

          } elsif (me.blink == FALSE or me.input.fiveHz.getValue() == TRUE) {
            if (me.selection.get_type() == radar_logic.SURFACE) {
              me.target_ground.show();
              me.target_air.hide();
              me.target_sea.hide();
            } elsif (me.selection.get_type() == radar_logic.MARINE) {
              me.target_ground.hide();
              me.target_sea.show();
              me.target_air.hide();
            } else {
              me.target_air.show();
              me.target_ground.hide();
              me.target_sea.hide();
            }
            me.diamond.hide();
          } else {
            me.target_air.hide();
            me.target_ground.hide();
            me.target_sea.hide();
            me.diamond.hide();
          }
          me.diamond_group.show();

        } else {
          #untargetable but selectable, like carriers and tankers, or planes in navigation mode
          #diamond_node = nil;
          armament.contact = nil;
          me.diamond_group.setTranslation(me.pos_x, me.pos_y);
          me.target_circle[me.selection_index].setTranslation(me.pos_x, me.pos_y);
          me.diamond_dista = me.input.units.getValue() == TRUE  ? me.selection.get_range()*NM2M : me.selection.get_range()*1000;
          if(me.diamond_dista < 10000) {
            me.diamond_dist.setText(sprintf("%.1f", me.diamond_dista/1000));
          } else {
            me.diamond_dist.setText(sprintf("%02d", me.diamond_dista/1000));
          }
          if (me.pos_x > (100/1024)*canvasWidth) {
            me.diamond_dist.setAlignment("right-top");
            me.diamond_dist.setTranslation(-(40/1024)*canvasWidth, (55/1024)*canvasWidth);
            me.diamond_name.setAlignment("right-bottom");
            me.diamond_name.setTranslation(-(40/1024)*canvasWidth, -(55/1024)*canvasWidth);
          } elsif (me.pos_x < -(100/1024)*canvasWidth) {
            me.diamond_dist.setAlignment("left-top");
            me.diamond_dist.setTranslation((40/1024)*canvasWidth, (55/1024)*canvasWidth);
            me.diamond_name.setAlignment("left-bottom");
            me.diamond_name.setTranslation((40/1024)*canvasWidth, -(55/1024)*canvasWidth);
          }
          if (me.input.callsign.getValue() == TRUE) {
            me.diamond_name.setText(me.selection.get_Callsign());
          } else {
            me.diamond_name.setText(me.selection.get_model());
          }
          
          if(me.blink == TRUE and me.input.fiveHz.getValue() == FALSE) {
            me.target_circle[me.selection_index].hide();
          } else {
            me.target_circle[me.selection_index].show();
          }
          me.diamond_group.show();
          me.diamond.hide();
          me.target_air.hide();
          me.target_ground.hide();
          me.target_sea.hide();
        }

        #velocity vector
        if(me.pos_x > -(512/1024)*canvasWidth and me.pos_x < (512/1024)*canvasWidth and me.pos_y > -(512/1024)*canvasWidth and me.pos_y < (512/1024)*canvasWidth) {
          me.tgtHeading = me.selection.get_heading();
          me.tgtSpeed = me.selection.get_Speed();
          me.myHeading = me.input.hdgReal.getValue();
          me.myRoll = me.input.roll.getValue();
          if (me.tgtHeading == nil or me.tgtSpeed == nil) {
            me.vel_vec.hide();
          } else {
            me.relHeading = me.tgtHeading - me.myHeading - me.myRoll;
            
            me.relHeading -= 180;# this makes the line trail instead of lead
            me.relHeading = me.relHeading * deg2rads;

            me.vel_vec_trans_group.setTranslation(me.pos_x, me.pos_y);
            me.vel_vec_rot_group.setRotation(me.relHeading);
            me.vel_vec.setScale(1, me.tgtSpeed/4);
            
            # note since trigonometry circle is opposite direction of compas heading direction, the line will trail the target.
            me.vel_vec.show();
          }
        } else {
          me.vel_vec.hide();
        }

        me.target_circle[me.selection_index].update();
        me.diamond_group.update();
      } else {
        # selection is outside radar view
        # or invalid
        # or nothing selected
        #diamond_node = nil;
        armament.contact = nil;
        if(me.selection != nil) {
          #selection[2] = nil;#no longer sure why I do this..
        }
        me.diamond_group.hide();
        me.vel_vec.hide();
        me.target_circle[0].hide();
      }
      #print("");
    } else {
      # radar tracks not shown at all
      me.radar_group.hide();
    }
  },

  displayRadarTrack: func (hud_pos) {
    me.pos_xx = hud_pos.get_cartesian()[0];
    me.pos_yy = hud_pos.get_cartesian()[1];
    me.showmeT = TRUE;
    
    if(me.pos_xx > (512/1024)*canvasWidth) {
      me.showmeT = FALSE;
    }
    if(me.pos_xx < -(512/1024)*canvasWidth) {
      me.showmeT = FALSE;
    }
    if(me.pos_yy > (512/1024)*canvasWidth) {
      me.showmeT = FALSE;
    }
    if(me.pos_yy < -(512/1024)*canvasWidth) {
      me.showmeT = FALSE;
    }

    me.currentIndexT = me.track_index;

    if(hud_pos == radar_logic.selection and me.pos_xx != 900000) {
        me.selection_updated = TRUE;
        me.selection_index = 0;
        me.currentIndexT = 0;
    }
    
    if(me.currentIndexT > -1 and (me.showmeT == TRUE or me.currentIndexT == 0)) {
      me.target_circle[me.currentIndexT].setTranslation(me.pos_xx, me.pos_yy);
      me.target_circle[me.currentIndexT].show();
      me.target_circle[me.currentIndexT].update();  
      if(me.currentIndexT != 0) {
        me.track_index += 1;
        if (me.track_index == maxTracks) {
          me.track_index = -1;
        }
      }
    }
  },
};#end of HUDnasal


var id = 0;

var reinitHUD = FALSE;
var hud_pilot = nil;
var init = func() {
  removelistener(id); # only call once
  if(getprop("ja37/supported/hud") == TRUE) {
    hud_pilot = HUDnasal.new({"node": "hud", "texture": "hud.png"});
    #setprop("sim/hud/visibility[1]", 0);
    
    #print("HUD initialized.");
    hud_pilot.update();
    IR_loop();
  }
};

var init2 = setlistener("/sim/signals/reinit", func() {
  setprop("sim/hud/visibility[1]", 0);
}, 0, 0);

#setprop("/systems/electrical/battery", 0);
id = setlistener("ja37/supported/initialized", init, 0, 0);

var IR_loop = func {
  reinit(on_backup_power);
  settimer(IR_loop, 1.5);
};

var reinit = func(backup = FALSE) {#mostly called to change HUD color
   #reinitHUD = 1;

   # if on backup power then amber will be the colour
   var red = backup == FALSE?r:1;
   var green = backup == FALSE?g:0.5;
   var blue = backup == FALSE?b:0;

   var IR = getprop("sim/rendering/shaders/skydome") == TRUE and getprop("sim/rendering/als-filters/use-filtering") == TRUE and getprop("sim/rendering/als-filters/use-IR-vision") == TRUE;

   if (IR) {
      # IR vision enabled, lets not have a green HUD:
      red = green;
      blue = green;
   }

   foreach(var item; artifacts0) {
    item.setColor(red, green, blue, a);
    item.setStrokeLineWidth((getprop("ja37/hud/stroke-linewidth")/1024)*canvasWidth);
   }

   foreach(var item; artifacts1) {
    item.setColor(red, green, blue, a);
    item.setStrokeLineWidth((getprop("ja37/hud/stroke-linewidth")/1024)*canvasWidth);
   }

   foreach(var item; artifactsText0) {
    item.setColor(red, green, blue, a);
   }

   foreach(var item; artifactsText1) {
    item.setColor(red, green, blue, a);
   }
   hud_pilot.slip_indicator.setColorFill(red, green, blue, a);
   
   if (IR) {
     HUDnasal.main.canvas.setColorBackground(red, green, blue, 0.025);
   } elsif (backup == FALSE) {
     HUDnasal.main.canvas.setColorBackground(0.36, g, 0.3, 0.025);
   } else {
     HUDnasal.main.canvas.setColorBackground(red, green, 0.3, 0.025);
   }
  #print("HUD being reinitialized.");
};

var cycle_brightness = func () {
  if(getprop("ja37/hud/mode") > 0) {
    g += 0.2;
    if(g > 1.0 and r == 0.6) {
      #reset
      g = 0.2;
      r = 0.0;
      b = 0.0;
    } elsif (g > 1.0) {
      r += 0.6;
      g =  1.0;
      b += 0.6;
    }
    setprop("controls/lighting/hud", r+g);
    reinit(on_backup_power);
    ja37.click();
  } else {
    aircraft.HUD.cycle_brightness();
  }
};

var cycle_units = func () {
  if(getprop("ja37/hud/mode") > 0) {
    ja37.click();
    var current = getprop("ja37/hud/units-metric");
    if(current == TRUE) {
      setprop("ja37/hud/units-metric", FALSE);
    } else {
      setprop("ja37/hud/units-metric", TRUE);
    }
  } else {
    aircraft.HUD.cycle_type();
  }
};

var cycle_landingMode = func () {
    ja37.click();
    var current = getprop("ja37/hud/landing-mode");
    if(current == TRUE) {
      setprop("ja37/hud/landing-mode", FALSE);
    } else {
      setprop("ja37/hud/landing-mode", TRUE);
    }
};

var toggle_combat = func () {
  if(getprop("ja37/hud/mode") > 0) {
    ja37.click();
    var current = getprop("/ja37/hud/combat");
    if(current == 1) {
      setprop("/ja37/hud/combat", FALSE);
    } else {
      setprop("/ja37/hud/combat", TRUE);
    }
  } else {
    aircraft.HUD.cycle_color();
  }
};

var toggleCallsign = func () {
  if(getprop("ja37/hud/mode") > 0) {
    ja37.click();
    var current = getprop("/ja37/hud/callsign");
    if(current == 1) {
      setprop("/ja37/hud/callsign", FALSE);
    } else {
      setprop("/ja37/hud/callsign", TRUE);
    }
  } else {
    aircraft.HUD.normal_type();
  }
};
