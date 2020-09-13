# ==============================================================================
# Head up display
#
# Nicked some code from the buccaneer and the wiki example to get started
#
# Made for the JA-37 by Nikolai V. Chr.
# ==============================================================================

var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }
var pow2 = func(x) { return x * x; };
var vec_length = func(x, y) { return math.sqrt(pow2(x) + pow2(y)); };
var round0 = func(x) { return math.abs(x) > 0.01 ? x : 0; };
var roundabout = func(x) {
  var y = x - int(x);
  return y < 0.5 ? int(x) : 1 + int(x) ;
};
var extrapolate = func (x, x1, x2, y1, y2) {
    return y1 + ((x - x1) / (x2 - x1)) * (y2 - y1);
};

var KT2KMH = NM2M*0.001;
var NM2KM = KT2KMH;
var NM2FT = NM2M*M2FT;

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

var HUDTop = 0.77; # position of top of HUD in meters. 0.77
var HUDBottom = 0.63; # position of bottom of HUD in meters. 0.63
#var HUDHoriz = -4.0; # position of HUD on x axis in meters. -4.0
var HUDHoriz = -4.06203;#pintos new hud
var HUDHeight = HUDTop - HUDBottom; # height of HUD
var canvasWidth = 512;
var max_width = (450/1024)*canvasWidth;
# HUD z is 0.63 - 0.77. Height of HUD is 0.14m
# Therefore each pixel is 0.14 / 1024 = 0.00013671875m or each meter is 7314.2857142857142857142857142857 pixels.
var pixelPerMeter = canvasWidth / HUDHeight;
var defaultHeadHeight = getprop("sim/view[0]/config/y-offset-m");
var centerOffset = -1 * (canvasWidth/2 - ((HUDTop - defaultHeadHeight)*pixelPerMeter));#pilot eye position up from vertical center of HUD. (in line from pilots eyes)
# View is 0.71m so 0.77-0.71 = 0.06m down from top of HUD, since Y in HUD increases downwards we get pixels from top:
# 512 - (0.06 / 0.00013671875) = 73.142857142857142857142857142857 pixels up from center. Since -y is upward, result is -73.1. (Per default)

# Default head-HUD distance (positive is backward)
var defaultHeadDistance = getprop("sim/view[0]/config/z-offset-m") - HUDHoriz;
# Since the HUD is not curved, we have to choose an avarage degree where degree per pixel is calculated from. 7.5 is chosen.
var pixelPerDegreeY = pixelPerMeter*((defaultHeadDistance * math.tan(7.5*D2R))/7.5);
var pixelPerDegreeX = pixelPerDegreeY; #horizontal axis
#printf("HUD total field of view %.1f degs (the real is 17 degs)", 512/pixelPerDegreeY);#17.3 degs in last test
#printf("HUD optical center %.1f degs below aircraft axis. (the real is 7.3 degs, so adjust %0.2f meter up)", -centerOffset/pixelPerDegreeY, (7.3+centerOffset/pixelPerDegreeY)*pixelPerDegreeY/pixelPerMeter);
#var slant = 35; #degrees the HUD is slanted away from the pilot.
var distScalePos = 2.75*pixelPerDegreeY;
var sidewindPosition = centerOffset+(10*pixelPerDegreeY); #should be 10 degrees under aicraft axis.
var sidewindPerKnot = max_width/30; # Max sidewind displayed is set at 30 kts. 450pixels is maximum is can move to the side.
var headScalePlace = 2.5*pixelPerDegreeY; # vert placement of heading scale, remember to change clip also.
var headScaleTickSpacing = (65/1024)*canvasWidth;# horizontal spacing between ticks. Remember to adjust bounding box when changing.

# Maximal angle from the hud optical center: nothing beyond that is displayed
var HUD_max_angle = 14;
var HUD_max_pixel = math.tan(HUD_max_angle * D2R) * defaultHeadDistance * pixelPerMeter;

var reticle_factor = 1.15;# size of flight path indicator, aiming reticle, and out of ammo reticle
var sidewind_factor = 1.0;# size of sidewind indicator
var airspeedPlace = 5*pixelPerDegreeY;
var airspeedPlaceFinal = -5*pixelPerDegreeY;
var missile_aim_position = centerOffset+0.03*pixelPerMeter;
var QFE_position = centerOffset+(5.5*pixelPerDegreeY);
var dig_alt_position = centerOffset+(9.0*pixelPerDegreeY);
var r = 0.0;#HUD colors
var g = 1.0;
var b = 0.0;
var a = 1.0;
var color = nil;
var a_res = 0.85;
var w = (getprop("ja37/hud/stroke-linewidth")/1024)*canvasWidth;  #line stroke width (saved between sessions)
var ar = 1.0;#font aspect ratio, less than 1 make more wide.
var fs = 0.8;#font size factor

# alt scale
var altimeterScaleHeight = (112.5/1024)*canvasWidth; # the height of the low alt scale. Also used in the other scales as a reference height.
var scalePlace = 3.5*pixelPerDegreeX; #horizontal placement of alt scales
var altScaleWidth = (200/1024)*canvasWidth;
var altScaleTickS = (15/1024)*canvasWidth;#small
var altScaleTickM = (25/1024)*canvasWidth;#medium
var altScaleTickL = (40/1024)*canvasWidth;#large
var altScaleFontSize = (60/1024)*canvasWidth*fs;
var numberOffset = (55/1024)*canvasWidth; #alt scale numbers horizontal offset from scale 
var radPointerProxim = (60/1024)*canvasWidth; #when alt indicater is too close to radar ground indicator, hide indicator
var indicatorOffset = -(10/1024)*canvasWidth; #alt scale indicators horizontal offset from scale (must be high, due to bug #1054 in canvas)
# +-78 texel high, 

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
    "mipmapping": 1,
    "additive-blend": 1# bool
    #"coverage-samples": int
    #"color-samples": int
    #"freeze": bool
    #"render-always": bool
    #"update": bool
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
    #me.canvas.del();
    #me.canvas = canvas.new(HUDnasal.canvas_settings);
    HUDnasal.inter = FALSE;
    me.canvas.addPlacement(me.place);
    #me.canvas.setColorBackground(0.36, g, 0.3, 0.025);
    me.canvas.setColorBackground(r, g, b, 0.0);

    # The hud can not display anything at angles beyond 14 degrees from the optical centerline
    # (the optical center line joins the head resting position and the hud center).
    # This is simulated by clipping the display to a disk which moves together with the rest of the hud content.
    #
    # Clip the display to a square as first approximation.
    me.root_clip_rect = sprintf("rect(%.1fpx, %.1fpx, %.1fpx, %.1fpx)", -HUD_max_pixel, HUD_max_pixel, HUD_max_pixel, -HUD_max_pixel);
    me.root = me.canvas.createGroup()
      .set("font", "LiberationFonts/LiberationMono-Regular.ttf") # If using default font, horizontal alignment is not accurate (bug #1054), also prettier char spacing.
      .set("clip-frame", canvas.Element.LOCAL)
      .set("clip", me.root_clip_rect)
      .setTranslation(canvasWidth/2, canvasWidth/2)
      .set("z-order", 0);

    # Use blending to obtain the final circular clipping area.
    me.root_clip_disk = me.root.createChild("image")
      .setTranslation(-HUD_max_pixel,-HUD_max_pixel)
      .setScale(HUD_max_pixel/128)
      .set("z-index",50)
      .set("blend-source-rgb","zero")
      .set("blend-source-alpha","zero")
      .set("blend-destination-rgb","one")
      .set("blend-destination-alpha","one-minus-src-alpha")
      .set("src", "Aircraft/JA37/gui/canvas-blend-mask/hud-global-mask.png");

    # groups for horizon and FPI
    me.fpi_group = me.root.createChild("group")
      .set("z-order", 1);
    me.horizon_group = me.root.createChild("group")
      .set("z-order", 1);

        # masking
    #me.clipAltScale = sprintf("rect(%.1fpx, %.1fpx, %.1fpx, %.1fpx)", -altimeterScaleHeight*1.4, altScaleWidth, altimeterScaleHeight*1.4, -(70/1024)*canvasWidth);
    me.alt_scale_clip_grp=me.horizon_group.createChild("group")
      #.set("clip-frame", canvas.Element.LOCAL)#canvas.Element.GLOBAL (the default value), canvas.Element.PARENT or canvas.Element.LOCAL
      #.set("clip", me.clipAltScale)#top,right,bottom,left
      .set("z-order", 0);


    # scale heading ticks
#    var clip = sprintf("rect(%.1fpx, %.1fpx, %.1fpx, %.1fpx)", (12/1024)*canvasWidth, (687/1024)*canvasWidth, (212/1024)*canvasWidth, (337/1024)*canvasWidth);
    me.head_scale_grp = me.alt_scale_clip_grp.createChild("group")
      .set("z-index",5);
#    me.head_scale_grp.set("clip", clip);#top,right,bottom,left
#    me.head_scale_grp.set("clip-frame", canvas.Element.GLOBAL);
#    me.alty2=me.head_scale_grp.createChild("path")
#  .moveTo(-5000,-5000)
#  .lineTo(5000,5000)
#  .setStrokeLineWidth(5000)
  #.setColorFill(0,0,1,0.5)
#  .setColor(0,0,1,0.5);

me.clipHeadScale = me.alt_scale_clip_grp.createChild("image")
.setTranslation(-128,-headScalePlace-128)
.set("z-index",10)
.set("blend-source-rgb","zero")
.set("blend-source-alpha","zero")
.set("blend-destination-rgb","one")
.set("blend-destination-alpha","one-minus-src-alpha")
.set("src", "Aircraft/JA37/gui/canvas-blend-mask/hud-head-scale.png");
    me.head_scale = me.head_scale_grp.createChild("path")
        .moveTo(-headScaleTickSpacing*2, 0)
        .vert(-(40/1024)*canvasWidth)
        .moveTo(0, 0)
        .vert(-(40/1024)*canvasWidth)
        .moveTo(headScaleTickSpacing*2, 0)
        .vert(-(40/1024)*canvasWidth)
        .moveTo(-headScaleTickSpacing, 0)
        .vert(-(20/1024)*canvasWidth)
        .moveTo(headScaleTickSpacing, 0)
        .vert(-(20/1024)*canvasWidth)
        .setStrokeLineWidth(w)
        .setColor(r,g,b, a)
        .show();

        #heading bug
    me.heading_bug_group = me.alt_scale_clip_grp.createChild("group")
    .set("z-index",5);
    #me.heading_bug_group.set("clip", "rect(62px, 687px, 262px, 337px)");#top,right,bottom,left
    me.heading_bug = me.heading_bug_group.createChild("path")
    .setColor(r,g,b, a)
    
    .setStrokeLineWidth(w)
    .moveTo( 0,  (10/1024)*canvasWidth)
    .lineTo( 0,  (55/1024)*canvasWidth)
    .moveTo( (15/1024)*canvasWidth, (55/1024)*canvasWidth)
    .lineTo( (15/1024)*canvasWidth, (25/1024)*canvasWidth)
    .moveTo(-(15/1024)*canvasWidth, (55/1024)*canvasWidth)
    .lineTo(-(15/1024)*canvasWidth, (25/1024)*canvasWidth);

    # scale heading end ticks
    me.hdgLineL = me.head_scale_grp.createChild("path")
    .setStrokeLineWidth(w)
      .setColor(r,g,b, a)
      .moveTo(-headScaleTickSpacing*3, 0)
      .vert(-(20/1024)*canvasWidth)
      .close();

    me.hdgLineR = me.head_scale_grp.createChild("path")
    .setStrokeLineWidth(w)
      .setColor(r,g,b, a)
      .moveTo(headScaleTickSpacing*3, 0)
      .vert(-(20/1024)*canvasWidth)
      .close();

    # headingindicator
    me.head_scale_indicator = me.alt_scale_clip_grp.createChild("path")
    .setColor(r,g,b, a)
    .set("z-index",5)
    .setStrokeLineWidth(w)
    .moveTo(-(30/1024)*canvasWidth, -headScalePlace+(30/1024)*canvasWidth)
    .lineTo(0, -headScalePlace)
    .lineTo((30/1024)*canvasWidth, -headScalePlace+(30/1024)*canvasWidth);

    # Heading middle number
    me.hdgM = me.head_scale_grp.createChild("text");
    me.hdgM.setColor(r,g,b, a);
    me.hdgM.setAlignment("center-bottom");
    me.hdgM.setFontSize((65/1024)*canvasWidth*fs, ar);

    # Heading left number
    me.hdgL = me.head_scale_grp.createChild("text");
    me.hdgL.setColor(r,g,b, a);
    me.hdgL.setAlignment("center-bottom");
    me.hdgL.setFontSize((65/1024)*canvasWidth*fs, ar);

    # Heading right number
    me.hdgR = me.head_scale_grp.createChild("text");
    me.hdgR.setColor(r,g,b, a);
    me.hdgR.setAlignment("center-bottom");
    me.hdgR.setFontSize((65/1024)*canvasWidth*fs, ar);

    




    # digital airspeed kts/mach 
    me.airspeed = me.alt_scale_clip_grp.createChild("text")
      .setText("000")
      .setFontSize((75/1024)*canvasWidth*fs, ar)
      .setColor(r,g,b, a)
      .setAlignment("center-top")
      .setTranslation(0 , airspeedPlace)
      .set("z-order", 12);
    me.airspeedInt = me.alt_scale_clip_grp.createChild("text")
      .setText("000")
      .setFontSize((75/1024)*canvasWidth*fs, ar)
      .setColor(r,g,b, a)
      .setAlignment("center-top")
      .setTranslation(0 , airspeedPlace-(70/1024)*canvasWidth)
      .set("z-order", 12);


      #altitude scale
me.clipAltScale = me.alt_scale_clip_grp.createChild("image")
.setTranslation(scalePlace-00,-128)
.set("z-index",10)
.set("blend-source-rgb","zero")
.set("blend-source-alpha","zero")
.set("blend-destination-rgb","one")
.set("blend-destination-alpha","one-minus-src-alpha")
.set("src", "Aircraft/JA37/gui/canvas-blend-mask/hud-alt-scale.png");
    me.alt_scale_grp=me.alt_scale_clip_grp.createChild("group")
    .setTranslation(scalePlace,0);
    # tactical altitude number
    me.alt_tact = me.alt_scale_clip_grp.createChild("text")
      .setText(".")
      .setFontSize((60/1024)*canvasWidth*fs, ar)
      .setColor(r,g,b, a)
      .setAlignment("left-center")
      .setTranslation(scalePlace, 0);
    #me.alt_scale_grp_trans = me.alt_scale_grp.createTransform();

#me.alty=me.alt_scale_clip_grp.createChild("path")
#.moveTo(-5000,-5000)
#.lineTo(5000,5000)
#.setStrokeLineWidth(5000)
#.set("z-order", 5)
#.setColor(0,0,1,0.01);
    # alt scale high
    me.alt_scale_high=me.alt_scale_grp.createChild("path")
      .moveTo(0, -6*altimeterScaleHeight/2)
      .horiz(altScaleTickL)
      .moveTo(0, -5*altimeterScaleHeight/2)
      .horiz(altScaleTickM)
      .moveTo(0, -2*altimeterScaleHeight)
      .horiz(altScaleTickL)
      .moveTo(0, -3*altimeterScaleHeight/2)
      .horiz(altScaleTickM)
      .moveTo(0, -altimeterScaleHeight)
      .horiz(altScaleTickL)
      .moveTo(0, -altimeterScaleHeight/2)
      .horiz(altScaleTickM)
      .moveTo(0, 0)
      .horiz(altScaleTickL)
      .setStrokeLineWidth(w)
      .setColor(r,g,b, a)
      .show();



    # alt scale medium
    me.alt_scale_med=me.alt_scale_grp.createChild("path")
      .moveTo(0, -5*altimeterScaleHeight/2)
      .horiz(altScaleTickM)
      .moveTo(0, -2*altimeterScaleHeight)
      .horiz(altScaleTickL)
      .moveTo(0, -3*altimeterScaleHeight/2)
      .horiz(altScaleTickM)
      .moveTo(0, -altimeterScaleHeight)
      .horiz(altScaleTickL)
      .moveTo(0, -4*altimeterScaleHeight/5)
      .horiz(altScaleTickS)
      .moveTo(0, -3*altimeterScaleHeight/5)
      .horiz(altScaleTickS)           
      .moveTo(0, -2*altimeterScaleHeight/5)
      .horiz(altScaleTickS)
      .moveTo(0, -1*altimeterScaleHeight/5)
      .horiz(altScaleTickS)           
      .moveTo(0, 0)
      .horiz(altScaleTickL)
      .setStrokeLineWidth(w)
      .setColor(r,g,b, a)
      .show();

    # alt scale low
    me.alt_scale_low = me.alt_scale_grp.createChild("path")
      .moveTo(0, -7*altimeterScaleHeight/4)
      .horiz(altScaleTickM)
      .moveTo(0, -6*altimeterScaleHeight/4)
      .horiz(altScaleTickL)
      .moveTo(0, -5*altimeterScaleHeight/4)
      .horiz(altScaleTickM)
      .moveTo(0, -altimeterScaleHeight)
      .horiz(altScaleTickL)
      .moveTo(0,-4*altimeterScaleHeight/5)
      .horiz(altScaleTickS)
      .moveTo(0, -3*altimeterScaleHeight/5)
      .horiz(altScaleTickS)
      .moveTo(0, -2*altimeterScaleHeight/5)
      .horiz(altScaleTickS)           
      .moveTo(0,-1*altimeterScaleHeight/5)
      .horiz(altScaleTickS)
      .moveTo(0, 0)
      .horiz(altScaleTickL)
      .setStrokeLineWidth(w)
      .setColor(r,g,b, a)
      .show();


      
    # vert line at zero alt if it is lower than radar zero
      me.alt_scale_line = me.alt_scale_grp.createChild("path")
      .moveTo(0, (30/1024)*canvasWidth)
      .vert(-(60/1024)*canvasWidth)
      .setStrokeLineWidth(w)
      .setColor(r,g,b, a);
    # low alt number
    me.alt_low = me.alt_scale_grp.createChild("text")
      .setText(".")
      .setFontSize(altScaleFontSize, ar)
      .setColor(r,g,b, a)
      .setAlignment("left-center")
      .setTranslation(1, 0);
    # middle alt number 
    me.alt_med = me.alt_scale_grp.createChild("text")
      .setText(".")
      .setFontSize(altScaleFontSize, ar)
      .setColor(r,g,b, a)
      .setAlignment("left-center")
      .setTranslation(1, 0);
    # high alt number      
    me.alt_high = me.alt_scale_grp.createChild("text")
      .setText(".")
      .setFontSize(altScaleFontSize, ar)
      .setColor(r,g,b, a)
      .setAlignment("left-center")
      .setTranslation(1, 0);

    # higher alt number     
    me.alt_higher = me.alt_scale_grp.createChild("text")
      .setText(".")
      .setFontSize(altScaleFontSize, ar)
      .setColor(r,g,b, a)
      .setAlignment("left-center")
      .setTranslation(1, 0);
    # alt scale indicator
    me.alt_pointer = me.alt_scale_clip_grp.createChild("path")
      .setColor(r,g,b, a)
      
      .setStrokeLineWidth(w)
      .moveTo(0,0)
      .lineTo(-(30/1024)*canvasWidth,-(30/1024)*canvasWidth)
      .moveTo(0,0)
      .lineTo(-(30/1024)*canvasWidth, (30/1024)*canvasWidth)
      .setTranslation(scalePlace+indicatorOffset, 0);
    # alt scale radar ground indicator
    me.rad_alt_pointer = me.alt_scale_grp.createChild("path")
      .setColor(r,g,b, a)
      
      .setStrokeLineWidth(w)
      .moveTo(0,0)
      .lineTo(-(50/1024)*canvasWidth,0)
      .moveTo(0,0)
      .lineTo(-(25/1024)*canvasWidth,(42/1024)*canvasWidth)
      .moveTo(-(25/1024)*canvasWidth,0)
      .lineTo(-(50/1024)*canvasWidth,(42/1024)*canvasWidth);
    
    # Altitude number (Not shown in landing/takeoff mode. Radar at less than 100 feet)
    me.alt = me.root.createChild("text");
    me.alt.setColor(r,g,b, a);
    me.alt.setAlignment("center-center");
    me.alt.setTranslation(-(375/1024)*canvasWidth, dig_alt_position);
    me.alt.setFontSize((70/1024)*canvasWidth*fs, ar);

    
    # Collision warning arrow
    me.arrow_group = me.fpi_group.createChild("group");  
    me.arrow_trans   = me.arrow_group.createTransform();
    me.arrow =
      me.arrow_group.createChild("path")
      .setColor(r,g,b, a)
      .moveTo(-(10/1024)*canvasWidth*reticle_factor,  (45/1024)*canvasWidth*reticle_factor)
      .lineTo(-(10/1024)*canvasWidth*reticle_factor, -(45/1024)*canvasWidth*reticle_factor)
      .lineTo(-(15/1024)*canvasWidth*reticle_factor, -(45/1024)*canvasWidth*reticle_factor)
      .lineTo(  0, -(60/1024)*canvasWidth*reticle_factor)
      .lineTo( (15/1024)*canvasWidth*reticle_factor, -(45/1024)*canvasWidth*reticle_factor)
      .lineTo( (10/1024)*canvasWidth*reticle_factor, -(45/1024)*canvasWidth*reticle_factor)
      .lineTo( (10/1024)*canvasWidth*reticle_factor,  (45/1024)*canvasWidth*reticle_factor)
      
      .setStrokeLineWidth(w);

    # Cannon aiming reticle
    me.reticle_cannon =
      me.root.createChild("path")
      .setColor(r,g,b, a)
      .moveTo(-(15/1024)*canvasWidth*reticle_factor, 0)
      .lineTo((15/1024)*canvasWidth*reticle_factor, 0)
      .moveTo(0, -(15/1024)*canvasWidth*reticle_factor)
      .lineTo(0,  (15/1024)*canvasWidth*reticle_factor)
      
      .setStrokeLineWidth(w);
    # a2a Missile aiming circle
    me.reticle_missile =
      me.root.createChild("path")
      .setColor(r,g,b, a)
      .moveTo( (200/1024)*canvasWidth, missile_aim_position)
      .arcSmallCW((200/1024)*canvasWidth,(200/1024)*canvasWidth, 0, -(400/1024)*canvasWidth, 0)
      .arcSmallCW((200/1024)*canvasWidth,(200/1024)*canvasWidth, 0,  (400/1024)*canvasWidth, 0)
      
      .hide()
      .setStrokeLineWidth(w);
    # a2g Missile aiming circle
    me.reticle_c_missile =
      me.root.createChild("path")
      .setColor(r,g,b, a)
      .moveTo( (150/1024)*canvasWidth, missile_aim_position-(75/1024)*canvasWidth)
      .lineTo( (150/1024)*canvasWidth, missile_aim_position+(75/1024)*canvasWidth)
      .moveTo( (-150/1024)*canvasWidth, missile_aim_position-(75/1024)*canvasWidth)
      .lineTo( (-150/1024)*canvasWidth, missile_aim_position+(75/1024)*canvasWidth)
      .hide()
      .setStrokeLineWidth(w);      
    # Out of ammo flight path indicator
    me.reticle_no_ammo =
      me.fpi_group.createChild("path")
      .setColor(r,g,b, a)
      .moveTo(-(45/1024)*canvasWidth*reticle_factor, 0) # draw this symbol in flight when no weapons selected (always as for now)
      .lineTo(-(15/1024)*canvasWidth*reticle_factor, 0)
      .lineTo(0, (15/1024)*canvasWidth*reticle_factor)
      .lineTo((15/1024)*canvasWidth*reticle_factor, 0)
      .lineTo((45/1024)*canvasWidth*reticle_factor, 0)
      
      .setStrokeLineWidth(w);
    # sidewind symbol
    me.takeoff_symbol = me.root.createChild("path")
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
      
      .setColor(r,g,b, a);
    #flight path indicator
    me.reticle_group = me.fpi_group.createChild("group");  
    me.aim_reticle  = me.reticle_group.createChild("path")
      .moveTo((45/1024)*canvasWidth*reticle_factor, 0)
      .lineTo((15/1024)*canvasWidth*reticle_factor, 0)
      .arcSmallCCW((15/1024)*canvasWidth*reticle_factor, (15/1024)*canvasWidth*reticle_factor, 0, -(30/1024)*canvasWidth*reticle_factor, 0)
      .arcSmallCCW((15/1024)*canvasWidth*reticle_factor, (15/1024)*canvasWidth*reticle_factor, 0,  (30/1024)*canvasWidth*reticle_factor, 0)
      .close()
      .moveTo(-(15/1024)*canvasWidth*reticle_factor, 0)
      .lineTo(-(45/1024)*canvasWidth*reticle_factor, 0)
      .setStrokeLineWidth(w)
      
      .setColor(r,g,b, a);
    me.reticle_fin_group = me.reticle_group.createChild("group");  
    me.aim_reticle_fin  = me.reticle_fin_group.createChild("path")
      .moveTo(0, -(15/1024)*canvasWidth*reticle_factor)
      .lineTo(0, -(30/1024)*canvasWidth*reticle_factor)
      .setStrokeLineWidth(w)
      
      .setColor(r,g,b, a);

    # Horizon
    #clip = (0/1024)*canvasWidth~"px, "~(712/1024)*canvasWidth~"px, "~(1024/1024)*canvasWidth~"px, "~(0/1024)*canvasWidth~"px";
    #me.horizon_group.set("clip", "rect("~clip~")");#top,right,bottom,left (absolute in canvas)
    me.horizon_group2 = me.horizon_group.createChild("group");
    me.horizon_group4 = me.horizon_group.createChild("group");
    me.desired_lines_group = me.horizon_group2.createChild("group");
    me.horizon_group3 = me.horizon_group.createChild("group");
    me.h_rot   = me.horizon_group.createTransform();

  
    # pitch lines
    var distance = pixelPerDegreeY * 5;
    #me.negative_horizon_lines = 
    for(var i = -18; i <= -1; i += 1) { # stipled lines
      append(artifacts1, me.horizon_group4.createChild("path")
                     .moveTo(2*pixelPerDegreeX, -i * distance)
                     .horiz(0.75*pixelPerDegreeX)
                     #.moveTo((300/1024)*canvasWidth, -i * distance)
                     #.horiz((50/1024)*canvasWidth)
                     .moveTo(5*pixelPerDegreeX, -i * distance)
                     .horiz(0.75*pixelPerDegreeX)
                     .moveTo(6.5*pixelPerDegreeX, -i * distance)
                     .horiz(0.75*pixelPerDegreeX)
                     .moveTo(8*pixelPerDegreeX, -i * distance)
                     .horiz(0.75*pixelPerDegreeX)
                     .moveTo(9.5*pixelPerDegreeX, -i * distance)
                     .horiz(0.75*pixelPerDegreeX)
                     .moveTo(11*pixelPerDegreeX, -i * distance)
                     .horiz(0.75*pixelPerDegreeX)
                     .moveTo(12.5*pixelPerDegreeX, -i * distance)
                     .horiz(0.75*pixelPerDegreeX)

                     .moveTo(-2*pixelPerDegreeX, -i * distance)
                     .horiz(-0.75*pixelPerDegreeX)
                     .moveTo(-3.5*pixelPerDegreeX, -i * distance)
                     .horiz(-0.75*pixelPerDegreeX)
                     .moveTo(-5*pixelPerDegreeX, -i * distance)
                     .horiz(-0.75*pixelPerDegreeX)
                     .moveTo(-6.5*pixelPerDegreeX, -i * distance)
                     .horiz(-0.75*pixelPerDegreeX)
                     .moveTo(-8*pixelPerDegreeX, -i * distance)
                     .horiz(-0.75*pixelPerDegreeX)
                     .moveTo(-9.5*pixelPerDegreeX, -i * distance)
                     .horiz(-0.75*pixelPerDegreeX)
                     .moveTo(-11*pixelPerDegreeX, -i * distance)
                     .horiz(-0.75*pixelPerDegreeX)
                     .moveTo(-12.5*pixelPerDegreeX, -i * distance)
                     .horiz(-0.75*pixelPerDegreeX)

                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a));
    }

    for(var i = 1; i <= 18; i += 1) # full drawn lines
      append(artifacts1, me.horizon_group2.createChild("path")
         .moveTo((950/1024)*canvasWidth, -i * distance)
         .horiz(-(950/1024)*canvasWidth+2*pixelPerDegreeX)

         .moveTo(-(950/1024)*canvasWidth, -i * distance)
         .horiz((950/1024)*canvasWidth-2*pixelPerDegreeX)
         
         .setStrokeLineWidth(w)
         .setColor(r,g,b, a));

    for(var i = -18; i <= 18; i += 1) { # small vertical lines in combat mode
      append(artifacts1, me.horizon_group3.createChild("path")
         .moveTo(-2*pixelPerDegreeX, -i * distance)
         .vert((25/1024)*canvasWidth)

         .moveTo(2*pixelPerDegreeX, -i * distance)
         .vert((25/1024)*canvasWidth)
         
         .setStrokeLineWidth(w)
         .setColor(r,g,b, a));
    }

    #pitch line numbers
    for(var i = -18; i <= 0; i += 1)
      append(artifactsText1, me.horizon_group4.createChild("text")
         .setText(i*5)
         .setFontSize((75/1024)*canvasWidth*fs, ar)
         .setAlignment("right-bottom")
         .setTranslation(-2.75*pixelPerDegreeX, -i * distance - 5)
         .setColor(r,g,b, a));
    for(var i = 1; i <= 18; i += 1)
      append(artifactsText1, me.horizon_group2.createChild("text")
         .setText("+" ~ i*5)
         .setFontSize((75/1024)*canvasWidth*fs, ar)
         .setAlignment("right-bottom")
         .setTranslation(-2.75*pixelPerDegreeX, -i * distance - 5)
         .setColor(r,g,b, a));
                 
 
    #Horizon line
    me.horizon_line_nav = me.horizon_group2.createChild("path")
                     .moveTo(-(850/1024)*canvasWidth, 0)
                     .horiz((850/1024)*canvasWidth-2.5*pixelPerDegreeX)
                     .moveTo(3*pixelPerDegreeX, 0)
                     .horiz(0.5*pixelPerDegreeX)
                     .moveTo(5.5*pixelPerDegreeX, 0)
                     .horiz((500/1024)*canvasWidth)
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a);

    #Horizon line
    me.horizon_line = me.horizon_group2.createChild("path")
                     .moveTo(-(850/1024)*canvasWidth, 0)
                     .horiz((850/1024)*canvasWidth-2*pixelPerDegreeX)
                     .moveTo(2*pixelPerDegreeX, 0)
                     .horiz((650/1024)*canvasWidth)
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a);

    me.horizon_line_gap = me.horizon_group2.createChild("path")
                     .moveTo(-2.5*pixelPerDegreeX, 0)
                     .horiz(5*pixelPerDegreeX)
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a);

    # heading scale on horizon line
    me.head_scale_horz_grp = me.horizon_group2.createChild("group");
    me.head_scale_horz_ticks = me.head_scale_horz_grp.createChild("path")
                      .moveTo(0, 0)
                      .vert(-(30/1024)*canvasWidth)
                      .moveTo(10*pixelPerDegreeX, 0)
                      .vert(-(30/1024)*canvasWidth)
                      .moveTo(-10*pixelPerDegreeX, 0)
                      .vert(-(30/1024)*canvasWidth)
                      .setStrokeLineWidth(w)
                      .setColor(r,g,b, a);
    # Heading middle number on horizon line
    me.hdgMH = me.head_scale_horz_grp.createChild("text")
                      .setColor(r,g,b, a)
                      .setAlignment("center-bottom")
                      .setFontSize((65/1024)*canvasWidth*fs, ar);
    # Heading left number on horizon line
    me.hdgLH = me.head_scale_horz_grp.createChild("text")
                      .setColor(r,g,b, a)
                      .setAlignment("center-bottom")
                      .setFontSize((65/1024)*canvasWidth*fs, ar);
    # Heading right number on horizon line
    me.hdgRH = me.head_scale_horz_grp.createChild("text")
                      .setColor(r,g,b, a)
                      .setAlignment("center-bottom")
                      .setFontSize((65/1024)*canvasWidth*fs, ar);
    #heading bug on horizon
    me.heading_bug_horz_group = me.horizon_group2.createChild("group");
    me.heading_bug_horz = me.heading_bug_horz_group.createChild("path")
                      .setColor(r,g,b, a)
                      
                      .setStrokeLineWidth(w)
                      .moveTo( 0,  (10/1024)*canvasWidth)
                      .lineTo( 0,  (55/1024)*canvasWidth)
                      .moveTo( (15/1024)*canvasWidth, (55/1024)*canvasWidth)
                      .lineTo( (15/1024)*canvasWidth, (25/1024)*canvasWidth)
                      .moveTo(-(15/1024)*canvasWidth, (55/1024)*canvasWidth)
                      .lineTo(-(15/1024)*canvasWidth, (25/1024)*canvasWidth);                      

    # altitude desired lines
    me.desired_lines3 = me.desired_lines_group.createChild("path")
                     .moveTo(-2.5*pixelPerDegreeX + w/2, 0)
                     .vert(5*pixelPerDegreeY)
                     .moveTo(2.5*pixelPerDegreeX - w/2, 0)
                     .vert(5*pixelPerDegreeY)
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a);

    # altitude boxes
    me.desired_boxes = me.desired_lines_group.createChild("path")
                     .moveTo(-2.5*pixelPerDegreeX-(15/1024)*canvasWidth + w/2, 0)
                     .vert(2.5*pixelPerDegreeY)
                     .horiz((30/1024)*canvasWidth)
                     .vert(-2.5*pixelPerDegreeY)
                     .horiz((-30/1024)*canvasWidth)
                     .moveTo(2.5*pixelPerDegreeX+(15/1024)*canvasWidth - w/2, 0)
                     .vert(2.5*pixelPerDegreeY)
                     .horiz((-30/1024)*canvasWidth)
                     .vert(-2.5*pixelPerDegreeY)
                     .horiz((30/1024)*canvasWidth)
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a);

    me.landing_line = me.horizon_group2.createChild("path")
                     .moveTo(-(200/1024)*canvasWidth, 0)
                     .horiz((160/1024)*canvasWidth)
                     .moveTo((40/1024)*canvasWidth, 0)
                     .horiz((160/1024)*canvasWidth)
                     .moveTo(0, 0)
                     .arcSmallCW((4/1024)*canvasWidth, (4/1024)*canvasWidth, 0, -(8/1024)*canvasWidth, 0)
                     .arcSmallCW((4/1024)*canvasWidth, (4/1024)*canvasWidth, 0,  (8/1024)*canvasWidth, 0)
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a);                     

    me.desired_lines2 = me.desired_lines_group.createChild("path")
                     .moveTo(-1.5*pixelPerDegreeX + w/2, 0)
                     .vert(3*pixelPerDegreeY)
                     .moveTo(1.5*pixelPerDegreeX - w/2, 0)
                     .vert(3*pixelPerDegreeY)
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a);                     

    var dot_half = w;
    var dot_full = w*2;

    me.horizon_dots = me.horizon_group2.createChild("path")
                     .moveTo(-2.5*pixelPerDegreeX+2.5*pixelPerDegreeX/3.5, 0)#-35
                     .arcSmallCW(dot_half, dot_half, 0, -dot_full, 0)
                     .arcSmallCW(dot_half, dot_half, 0, dot_full, 0)
                     .moveTo(-2.5*pixelPerDegreeX+2*2.5*pixelPerDegreeX/3.5, 0)#-105
                     .arcSmallCW(dot_half, dot_half, 0, -dot_full, 0)
                     .arcSmallCW(dot_half, dot_half, 0, dot_full, 0)
                     .moveTo(-2.5*pixelPerDegreeX+3*2.5*pixelPerDegreeX/3.5, 0)#-175
                     .arcSmallCW(dot_half, dot_half, 0, -dot_full, 0)
                     .arcSmallCW(dot_half, dot_half, 0, dot_full, 0)
                     .moveTo(-2.5*pixelPerDegreeX+4*2.5*pixelPerDegreeX/3.5, 0)#175
                     .arcSmallCW(dot_half, dot_half, 0, -dot_full, 0)
                     .arcSmallCW(dot_half, dot_half, 0, dot_full, 0)
                     .moveTo(-2.5*pixelPerDegreeX+5*2.5*pixelPerDegreeX/3.5, 0)#105
                     .arcSmallCW(dot_half, dot_half, 0, -dot_full, 0)
                     .arcSmallCW(dot_half, dot_half, 0, dot_full, 0)
                     .moveTo(-2.5*pixelPerDegreeX+6*2.5*pixelPerDegreeX/3.5, 0)#35
                     .arcSmallCW(dot_half, dot_half, 0, -dot_full, 0)
                     .arcSmallCW(dot_half, dot_half, 0, dot_full, 0)
                     .setStrokeLineWidth(w)
                     .setColorFill(r,g,b, a)
                     .setColor(r,g,b, a);

      ####  targets

    me.radar_group = me.root.createChild("group");

      #diamond
    me.diamond_group = me.radar_group.createChild("group");
    #me.diamond_group_line = me.diamond_group.createChild("group");
    #me.track_line = nil;
    me.diamond_group.createTransform();
    me.diamond_small = me.root.createChild("path")
                           .moveTo(-(25/1024)*canvasWidth,   0)
                           .lineTo(  0, -(25/1024)*canvasWidth)
                           .lineTo( (25/1024)*canvasWidth,   0)
                           .lineTo(  0,  (25/1024)*canvasWidth)
                           .lineTo(-(25/1024)*canvasWidth,   0)
                           .setStrokeLineWidth(w)
                           .hide()
                           .setColor(r,g,b, a);
#    me.diamond = me.diamond_group.createChild("path")
    me.lock_rdr = me.diamond_group.createChild("path")
                           .moveTo(-(50/1024)*canvasWidth, 0)
                           .arcLargeCW((50/1024)*canvasWidth, (50/1024)*canvasWidth, 0,  (100/1024)*canvasWidth, 0)
                           .setStrokeLineWidth(w)
                           .setColor(r,g,b, a);
    me.lock_ir  = me.root.createChild("path")
                           .moveTo((50/1024)*canvasWidth, 0)
                           .arcLargeCW((50/1024)*canvasWidth, (50/1024)*canvasWidth, 0, -(100/1024)*canvasWidth, 0)
                           .setStrokeLineWidth(w)
                           .setColor(r,g,b, a);                           
#    me.target_air = me.diamond_group.createChild("path")
#                           .moveTo(-(50/1024)*canvasWidth,   0)
#                           .lineTo(-(50/1024)*canvasWidth, -(50/1024)*canvasWidth)
#                           .lineTo( (50/1024)*canvasWidth, -(50/1024)*canvasWidth)
#                           .lineTo( (50/1024)*canvasWidth,   0)
#                           .setStrokeLineWidth(w)
#                           .setColor(r,g,b, a);
#    me.target_ground = me.diamond_group.createChild("path")
#                           .moveTo(-(50/1024)*canvasWidth,   0)
#                           .lineTo(-(50/1024)*canvasWidth, (50/1024)*canvasWidth)
#                           .lineTo( (50/1024)*canvasWidth, (50/1024)*canvasWidth)
#                           .lineTo( (50/1024)*canvasWidth,   0)
#                           .setStrokeLineWidth(w)
#                           .setColor(r,g,b, a);
#    me.target_sea = me.diamond_group.createChild("path")
#                           .moveTo(-(50/1024)*canvasWidth,   0)
#                           .lineTo(0, (50/1024)*canvasWidth)
#                           .lineTo( (50/1024)*canvasWidth,   0)
#                           .setStrokeLineWidth(w)
#                           .setColor(r,g,b, a); 
    me.diamond_dist = me.diamond_group.createChild("text");
    me.diamond_dist.setText("..");
    me.diamond_dist.setColor(r,g,b, a);
    me.diamond_dist.setAlignment("left-top");
    me.diamond_dist.setTranslation((40/1024)*canvasWidth, (55/1024)*canvasWidth);
    me.diamond_dist.setFontSize((60/1024)*canvasWidth*fs, ar);
    me.diamond_name = me.diamond_group.createChild("text");
    me.diamond_name.setText("");
    me.diamond_name.setColor(r,g,b, a);
    me.diamond_name.setAlignment("left-bottom");
    me.diamond_name.setTranslation((40/1024)*canvasWidth, -(55/1024)*canvasWidth);
    me.diamond_name.setFontSize((60/1024)*canvasWidth*fs, ar);


    #other targets

    me.target_circle = [];
    me.target_group = me.radar_group.createChild("group");
    for(var i = 0; i < maxTracks; i += 1) {      
      target_circles = me.target_group.createChild("path")
                           .moveTo(-(50/1024)*canvasWidth,   0)
                           .lineTo(-(50/1024)*canvasWidth, -(50/1024)*canvasWidth)
                           .lineTo( (50/1024)*canvasWidth, -(50/1024)*canvasWidth)
                           .lineTo( (50/1024)*canvasWidth,   0)
                           .setStrokeLineWidth(w)
                           .setColor(r,g,b, a);
      append(me.target_circle, target_circles);
      append(artifacts1, target_circles);
    }

    me.vel_vec_trans_group = me.radar_group.createChild("group");
    me.vel_vec_rot_group = me.vel_vec_trans_group.createChild("group");
    #me.vel_vec_rot = me.vel_vec_rot_group.createTransform();
    me.vel_vec = me.vel_vec_rot_group.createChild("path")
                                  .moveTo(0, 0)
                                  .lineTo(0,-(1/1024)*canvasWidth)
                                  .setStrokeLineWidth(w)
                                  .setColor(r,g,b, a);

    #tower symbol
    me.tower_symbol = me.root.createChild("group");
    me.tower_symbol.createTransform();
    var tower = me.tower_symbol.createChild("path")
                           .moveTo(-(20/1024)*canvasWidth,   0)
                           .lineTo(  0, -(20/1024)*canvasWidth)
                           .lineTo( (20/1024)*canvasWidth,   0)
                           .lineTo(  0,  (20/1024)*canvasWidth)
                           .lineTo(-(20/1024)*canvasWidth,   0)
                           .setStrokeLineWidth(w)
                           .setColor(r,g,b, a);
    me.tower_symbol_dist = me.tower_symbol.createChild("text");
    me.tower_symbol_dist.setText("..");
    me.tower_symbol_dist.setColor(r,g,b, a);
    me.tower_symbol_dist.setAlignment("left-top");
    me.tower_symbol_dist.setTranslation((12/1024)*canvasWidth, (12/1024)*canvasWidth);
    me.tower_symbol_dist.setFontSize((60/1024)*canvasWidth*fs, ar);

    me.tower_symbol_icao = me.tower_symbol.createChild("text");
    me.tower_symbol_icao.setText("..");
    me.tower_symbol_icao.setColor(r,g,b, a);
    me.tower_symbol_icao.setAlignment("left-bottom");
    me.tower_symbol_icao.setTranslation((12/1024)*canvasWidth, -(12/1024)*canvasWidth);
    me.tower_symbol_icao.setFontSize((60/1024)*canvasWidth*fs, ar);

    #ccip symbol
    me.ccip_symbol = me.root.createChild("group");
    me.ccip_symbol.createTransform();
    var ccip = me.ccip_symbol.createChild("path")
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
    me.dist_scale_group = me.alt_scale_clip_grp.createChild("group")
                            .setTranslation(-(100/1024)*canvasWidth, distScalePos)
                            .set("z-index",15);
    me.mySpeed = me.dist_scale_group.createChild("path")
                            .moveTo(   0,   0)
                            .lineTo( -(10/1024)*canvasWidth, -(10/1024)*canvasWidth)
                            .lineTo(   0, -(20/1024)*canvasWidth)
                            .lineTo(  (10/1024)*canvasWidth, -(10/1024)*canvasWidth)
                            .lineTo(   0,   0)
                            .setStrokeLineWidth(w)
                            .setColor(r,g,b, a);
    me.targetSpeed = me.dist_scale_group.createChild("path")
                            .moveTo(   0,   0)
                            .lineTo(   0,  (20/1024)*canvasWidth)
                            .moveTo( -(10/1024)*canvasWidth,  (20/1024)*canvasWidth)
                            .lineTo(  (10/1024)*canvasWidth,  (20/1024)*canvasWidth)
                            .setStrokeLineWidth(w)
                            .setColor(r,g,b, a);
    me.targetDistance1 = me.dist_scale_group.createChild("path")
                            .moveTo(   0,   0)
                            .lineTo(   0,  (20/1024)*canvasWidth)
                            .lineTo(  (20/1024)*canvasWidth,  (20/1024)*canvasWidth)
                            .moveTo( -(30/1024)*canvasWidth,  (20/1024)*canvasWidth)
                            .lineTo( -(30/1024)*canvasWidth,  (50/1024)*canvasWidth)
                            .lineTo(   0,  (50/1024)*canvasWidth)
                            .setStrokeLineWidth(w)
                            .setColor(r,g,b, a);
    me.targetDistance2 = me.dist_scale_group.createChild("path")
                            .moveTo(   0,   0)
                            .lineTo(   0,  (20/1024)*canvasWidth)
                            .lineTo( -(20/1024)*canvasWidth,  (20/1024)*canvasWidth)
                            .setStrokeLineWidth(w)
                            .setColor(r,g,b, a);
    me.distanceText = me.dist_scale_group.createChild("text")
                            .setText("")
                            .setColor(r,g,b, a)
                            .setAlignment("left-top")
                            .setTranslation((200/1024)*canvasWidth, (10/1024)*canvasWidth)
                            .setFontSize((60/1024)*canvasWidth*fs, ar);
    # QFE warning (inhg not properly set / is being adjusted)
    me.qfe = me.dist_scale_group.createChild("text");
    me.qfe.setText("QFE");
    me.qfe.setColor(r,g,b, a);
    me.qfe.setAlignment("right-center");
    me.qfe.setTranslation(-(20/1024)*canvasWidth, 0);
    me.qfe.setFontSize((75/1024)*canvasWidth*fs, ar);

    me.distanceScale = me.dist_scale_group.createChild("path")
                            .moveTo(   0, 0)
                            .lineTo( (200/1024)*canvasWidth, 0)
                            .setStrokeLineWidth(w)
                            .setColor(r,g,b, a);
    

    artifacts0 = [me.head_scale, me.hdgLineL, me.heading_bug, me.vel_vec, me.reticle_missile, me.reticle_c_missile,
             me.hdgLineR, me.head_scale_indicator, me.arrow, me.head_scale_horz_ticks,
             me.alt_scale_high, me.alt_scale_med, me.alt_scale_low,
             me.alt_scale_line, me.aim_reticle_fin, me.reticle_cannon, me.desired_lines2,
             me.alt_pointer, me.rad_alt_pointer, me.desired_lines3, me.horizon_line_gap, me.lock_rdr, me.lock_ir,# me.target_air, me.target_sea, me.target_ground, me.diamond
             me.desired_boxes, me.reticle_no_ammo, me.takeoff_symbol, me.horizon_line, me.horizon_line_nav, me.horizon_dots, me.diamond_small,
             tower, ccip, me.aim_reticle, me.targetSpeed, me.mySpeed, me.distanceScale, me.targetDistance1,
             me.targetDistance2, me.landing_line, me.heading_bug_horz];
#artifacts0 =[];
    artifactsText0 = [me.airspeedInt, me.airspeed, me.hdgM, me.hdgL, me.hdgR, me.qfe,
                      me.diamond_dist, me.tower_symbol_dist, me.tower_symbol_icao, me.diamond_name,
                      me.alt_low, me.alt_med, me.alt_high, me.alt_higher, me.alt,
                      me.hdgMH, me.hdgLH, me.hdgRH, me.distanceText, me.alt_tact];
#artifactsText0 = [];
    me.pos_x = canvasWidth*0.4;
    me.lock_ir_last = FALSE;
    
    #EEGS:
    me.eegsGroup = me.root.createChild("group");
    me.funnelParts = 17;#number of segments in funnel sides. If increase, remember to increase all relevant vectors also.
    me.eegsRightX = me.makeVector(me.funnelParts,0);
    me.eegsRightY = me.makeVector(me.funnelParts,0);
    me.eegsLeftX  = me.makeVector(me.funnelParts,0);
    me.eegsLeftY  = me.makeVector(me.funnelParts,0);
    me.gunPos   = nil;
    me.eegsMe = {ac: geo.Coord.new(), eegsPos: geo.Coord.new(),shellPosX: me.makeVector(me.funnelParts,0),shellPosY: me.makeVector(me.funnelParts,0),shellPosDist: me.makeVector(me.funnelParts,0)};
    me.lastTime = systime();
    me.averageDt = 0.100;
    me.eegsLoop = maketimer(me.averageDt, me, me.displayEEGS);
    me.eegsLoop.simulatedTime = 1;
    me.designatedDistanceFT = nil;
    me.resetGunPos();
    color = [r, g, b, a];
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
        #APHeadingBug:     "autopilot/settings/heading-bug-deg",
        APmode:           "fdm/jsbsim/autoflight/mode",
        #APLockHeading:    "autopilot/locks/heading",
        #APnav0HeadingErr: "autopilot/internal/nav1-heading-error-deg",
        #APTgtAgl:         "autopilot/settings/target-agl-ft",
        APTgtAlt:         "fdm/jsbsim/autoflight/pitch/alt/target",
        #APTrueHeadingErr: "autopilot/internal/true-heading-error-deg",
        beta:             "orientation/side-slip-deg",
        callsign:         "ja37/hud/callsign",
        cannonAmmo:       "ai/submodels/submodel[3]/count",
        combat:           "ja37/hud/combat",
        currentMode:      "ja37/hud/current-mode",
        dme:              "instrumentation/dme/KDI572-574/nm",
        dmeDist:          "instrumentation/dme/indicated-distance-nm",
        elapsedSec:       "sim/time/elapsed-sec",
        fdpitch:          "autopilot/settings/fd-pitch-deg",
        fdroll:           "autopilot/settings/fd-roll-deg",
        fdspeed:          "autopilot/settings/target-speed-kt",
        fiveHz:           "ja37/blink/two-Hz/state",
        gearCmdNorm:      "/fdm/jsbsim/gear/gear-cmd-norm",
        gearsPos:         "gear/gear/position-norm",
        hdg:              "orientation/heading-magnetic-deg",
        hdgReal:          "orientation/heading-deg",
        ias:              "instrumentation/airspeed-indicator/indicated-speed-kt",#"/velocities/airspeed-kt",
        landingMode:      "ja37/hud/landing-mode",
        mach:             "instrumentation/airspeed-indicator/indicated-mach",
        nav0GSNeedleDefl: "instrumentation/nav[0]/gs-needle-deflection-norm",
        nav0GSNeedleDeflD:"instrumentation/nav[0]/gs-needle-deflection-deg",
        nav0GSInRange:    "instrumentation/nav[0]/gs-in-range",
        nav0HasGS:        "instrumentation/nav[0]/has-gs",
        nav0Heading:      "instrumentation/nav[0]/heading-deg",
        nav0HeadingDefl:  "instrumentation/nav[0]/heading-needle-deflection",
        nav0InRange:      "instrumentation/nav[0]/in-range",
        pitch:            "orientation/pitch-deg",
        rad_alt:          "instrumentation/radar-altimeter/radar-altitude-ft",
        rad_alt_ready:    "instrumentation/radar-altimeter/ready",
        radar_serv:       "instrumentation/radar/serviceable",
        RMActive:         "autopilot/route-manager/active",
        rmDist:           "autopilot/route-manager/wp/dist",
        RMCurrWaypoint:   "autopilot/route-manager/current-wp",
        RMWaypointBearing:"autopilot/route-manager/wp/bearing-deg",
        roll:             "orientation/roll-deg",
        srvHead:          "instrumentation/heading-indicator/serviceable",
        service:          "instrumentation/head-up-display/serviceable",
        speed_d:          "velocities/speed-down-fps",
        speed_e:          "velocities/speed-east-fps",
        speed_n:          "velocities/speed-north-fps",
        station:          "controls/armament/station-select-custom",
        tenHz:            "ja37/blink/four-Hz/state",
        twoHz:            "ja37/blink/two-Hz/state",
        terrainOn:        "ja37/sound/terrain-on",
        TILS:             "ja37/hud/TILS",
        towerAlt:         "sim/tower/altitude-ft",
        towerLat:         "sim/tower/latitude-deg",
        towerLon:         "sim/tower/longitude-deg",
        tracks_enabled:   "ja37/hud/tracks-enabled",
        units:            "ja37/hud/units-metric",
        viewNumber:       "sim/current-view/view-number",
        viewX:            "sim/current-view/x-offset-m",
        viewY:            "sim/current-view/y-offset-m",
        viewZ:            "sim/current-view/z-offset-m",
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
        terrainWarn:      "/instrumentation/terrain-warning",
        qfeActive:        "ja37/displays/qfe-active",
        qfeShown:         "ja37/displays/qfe-shown",
        fpiHorz:          "ja37/displays/fpi-horz-deg",
        fpiVert:          "ja37/displays/fpi-vert-deg",
        hudBright:        "ja37/hud/brightness",
        hudBrightSI:      "ja37/hud/brightness-si",
        hudBrightRES:     "ja37/hud/brightness-res",
        als:              "sim/rendering/shaders/skydome",
        alsFilter:        "sim/rendering/als-filters/use-filtering",
        alsIR:            "sim/rendering/als-filters/use-IR-vision",
        stroke:           "ja37/hud/stroke-linewidth",
      };
   
      foreach(var name; keys(HUDnasal.main.input)) {
        HUDnasal.main.input[name] = props.globals.getNode(HUDnasal.main.input[name], 1);
      }
    }

    HUDnasal.main.redraw();
    return HUDnasal.main;
    
  },
  lastPower: 0,
      ############################################################################
      #############             main loop                         ################
      ############################################################################
  update: func() {
    #setprop("instrumentation/airspeed-indicator/indicated-speed-kmh", getprop("instrumentation/airspeed-indicator/indicated-speed-kt")*KT2KMH);
    me.has_power = TRUE;
    if (!power.prop.acSecondBool.getValue()) {
      # primary power is off
      if (power.prop.dcMainBool.getValue()) {
        # on backup
        if (on_backup_power == FALSE) {
          # change the colour to amber
          #reinit();
        }
        on_backup_power = TRUE;
      } else {
        # HUD has no power
        me.has_power = FALSE;
      }
    } elsif (on_backup_power == TRUE) {
      # was on backup, now is on primary
      #reinit();
      on_backup_power = FALSE;
    }
    if (me.lastPower != power.prop.dcMain.getValue()+power.prop.acSecond.getValue()) {
      reinit();
    }
    me.lastPower = power.prop.dcMain.getValue()+power.prop.acSecond.getValue();

    mode = me.input.currentMode.getValue();
    me.station = me.input.station.getValue();

    me.displaySeeker(mode);

    if(me.has_power == FALSE or testing.ongoing == TRUE) {
      me.root.hide();
      me.root.update();
      air2air = FALSE;
      air2ground = FALSE;
      if (me.eegsLoop.isRunning) {
        me.eegsLoop.stop();
      }
      #settimer(func me.update(), 0.3);
    } elsif (me.input.service.getValue() == FALSE) {
      # The HUD has failed, due to the random failure system or crash, it will become frozen.
      # if it also later loses power, and the power comes back, the HUD will not reappear.
      air2air = FALSE;
      air2ground = FALSE;
      if (me.eegsLoop.isRunning) {
        me.eegsLoop.stop();
      }
      #settimer(func me.update(), 0.25);
    } else {
      # commented as long as diamond node is choosen in HUD
      #if (me.input.viewNumber.getValue() != 0 and me.input.viewNumber.getValue() != 13) {
        # in external view
      #  settimer(func me.update(), 0.03);
      #  return;
      #}

      me.cannon = me.station == 0;
      me.cannon = me.cannon or (me.station != -1 and getprop("payload/weight["~ (me.station-1) ~"]/selected") == "M55 AKAN");
      me.cannon = mode == COMBAT and me.cannon;
      me.out_of_ammo = FALSE;
      #if (me.input.station.getValue() != 0 and getprop("payload/weight["~ (me.input.station.getValue()-1) ~"]/selected") == "none") {
      #      out_of_ammo = TRUE;
      #} elsif (me.input.station.getValue() == 0 and me.input.cannonAmmo.getValue() == 0) {
      #      out_of_ammo = TRUE;
      #} elsif (me.input.station.getValue() != 0 and getprop("payload/weight["~ (me.input.station.getValue()-1) ~"]/selected") == "M70 ARAK" and getprop("ai/submodels/submodel["~(4+me.input.station.getValue())~"]/count") == 0) {
      #      out_of_ammo = TRUE;
      #}
      me.ammo = armament.ammoCount(me.station);
      if (me.ammo > 0) {
        me.out_of_ammo = FALSE;
      } else {
        me.out_of_ammo = TRUE;
      }

      me.finalVisual = land.mode_OPT_active;

      # ground collision warning
      me.displayGroundCollisionArrow(mode);

      # heading scale
      me.displayHeadingScale();
      me.displayHeadingHorizonScale();

      #heading bug, must be after heading scale
      me.displayHeadingBug();

      ####   display QFE or weapon   ####
      me.displayQFE(mode);

      ####   reticle  ####
      deflect = me.showReticle(mode, me.cannon, me.out_of_ammo);
      
      # altitude. Digital and scale.
      me.displayAltitude();

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

      ####  Radar HUD tracks  ###
      me.displayRadarTracks(mode);

      # tower symbol
      me.displayTower();
      
      # Gun pipper
      me.displayGunPipper();

      

      skip = !skip;#we skip some function every other time, for performance

      if(reinitHUD == TRUE) {
        me.redraw();
        reinitHUD = FALSE;
        me.update();
      } else {
        me.root.show();
        me.root.update();          
      }
      #settimer(
      #func debug.benchmark("hud loop", 
      #func me.update()
      #)
      #, 0.05);
      #setprop("sim/hud/visibility[1]", 0);
    }#end of HUD running check
  },#end of update

  displayGroundCollisionArrow: func (mode) {
    if (me.input.terrainWarn.getValue() == TRUE) {
      me.arrow_trans.setRotation(- me.input.roll.getValue()*D2R);
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
          me.hdgLineL.show();
          #me.hdgLineR.hide();
        } else {
          me.middleOffset = -me.headScaleOffset*headScaleTickSpacing*2;
          me.hdgLineR.show();
          #me.hdgLineL.hide();
        }
        me.head_scale_grp.setTranslation(me.middleOffset, -headScalePlace);
        me.head_scale_grp.update();
        me.hdgR.setTranslation(headScaleTickSpacing*2, -(45/1024)*canvasWidth);
        me.hdgR.setText(sprintf("%02d", me.rightText));
        me.hdgM.setTranslation(0, -(45/1024)*canvasWidth);
        me.hdgM.setText(sprintf("%02d", me.middleText));
        me.hdgL.setTranslation(-headScaleTickSpacing*2, -(45/1024)*canvasWidth);
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
    #if (me.input.APLockHeading.getValue() == "dg-heading-hold") {
    #  me.desired_mag_heading = me.input.APHeadingBug.getValue();
    #} elsif (me.input.APLockHeading.getValue() == "true-heading-hold") {
    #  me.desired_mag_heading = me.input.APTrueHeadingErr.getValue()+me.input.hdg.getValue();#getprop("autopilot/settings/true-heading-deg")+
    #} elsif (me.input.APLockHeading.getValue() == "nav1-hold") {
    #  me.desired_mag_heading = me.input.APnav0HeadingErr.getValue()+me.input.hdg.getValue();
    #} els
    if (radar_logic.steerOrder == TRUE and radar_logic.selection != nil) {
        me.desired_mag_heading = radar_logic.selection.getMagInterceptBearing();
    } elsif( me.input.RMActive.getValue() == TRUE) {
      me.desired_mag_heading = me.input.RMWaypointBearing.getValue();
#    } elsif (me.input.nav0InRange.getValue() == TRUE) {
      # bug to VOR, ADF or ILS
#      me.desired_mag_heading = me.input.nav0Heading.getValue();# TODO: is this really mag?
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
      
      me.pos_xxx = me.middleOffset + me.degOffset*(headScaleTickSpacing/5);
      #print("bug offset deg "~degOffset~"bug offset pix "~pos_x);
      me.blink = FALSE;
      #62px, 687px, 262px, 337px
      if (me.pos_xxx < (337/1024)*canvasWidth-(512/1024)*canvasWidth) {
        me.blink = TRUE;
        me.pos_xxx = (337/1024)*canvasWidth-(512/1024)*canvasWidth;
      } elsif (me.pos_xxx > (687/1024)*canvasWidth-(512/1024)*canvasWidth) {
        me.blink = TRUE;
        me.pos_xxx = (687/1024)*canvasWidth-(512/1024)*canvasWidth;
      }
      me.heading_bug_group.setTranslation(me.pos_xxx, -headScalePlace);
      if(me.topHeadingScaleShown() and (me.blink == FALSE or me.input.fiveHz.getValue() == TRUE)) {
        me.heading_bug.show();
      } else {
        me.heading_bug.hide();
      }
      if (mode == LANDING) {
        me.pos_xxx = me.middleOffsetHorz + me.degOffset*(pixelPerDegreeX);
        me.heading_bug_horz_group.setTranslation(me.pos_xxx, 0);
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
    me.alti = me.metric == TRUE ? me.input.alt_ft.getValue() * FT2M : me.input.alt_ft.getValue();
    me.radAlt = me.input.rad_alt_ready.getBoolValue() ?(me.metric == TRUE ? me.input.rad_alt.getValue() * FT2M : me.input.rad_alt.getValue()):nil;
    if (mode == COMBAT) {
      me.displayAltitudeNumber(me.alti);
    } else {
      me.displayAltitudeScale(me.alti, me.radAlt);
    }
    me.displayDigitalAltitude(me.alti, me.radAlt);
  },

  displayAltitudeNumber: func (alt) {
    me.altTact = "";
    if (alt < 1000) {
      me.altTact = sprintf("%d", alt);
    } else {
      me.altTact = sprintf("%.1f", alt/1000);
    }
    me.alt_tact.setText(me.altTact);
    me.alt_tact.show();
    me.alt_scale_grp.hide();
    me.alt_pointer.hide();
  },

  displayAltitudeScale: func (alt, radAlt) {
    me.alt_tact.hide();
    me.metric = me.input.units.getValue();
    me.pixelPerFeet = nil;
    # determine which alt scale to use
    if(me.metric == 1) {
      me.pixelPerFeet = altimeterScaleHeight/(50*M2FT);
      if (alt_scale_mode == -1) {
        if (alt < 45) {
          alt_scale_mode = 0;
        } elsif (alt < 90) {
          alt_scale_mode = 1;
        } else {
          alt_scale_mode = 2;
          me.pixelPerFeet = altimeterScaleHeight/(100*M2FT);
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
          me.pixelPerFeet = altimeterScaleHeight/(100*M2FT);
        } else if (alt < 40) {
          alt_scale_mode = 0;
        } else {
          alt_scale_mode = 1;
        }
      } elsif (alt_scale_mode == 2) {
        if (alt >= 85) {
          alt_scale_mode = 2;
          me.pixelPerFeet = altimeterScaleHeight/(100*M2FT);
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
      me.alt_scale_grp.setTranslation(scalePlace, me.offset);
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
      me.alt_scale_grp.setTranslation(scalePlace, me.offset);
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
      me.alt_scale_grp.setTranslation(scalePlace, me.offset);
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
      #me.alt_scale_clip_grp.setTranslation(scalePlace, 0);# move alt. scale lateral with FPI.
      #me.alt_scale_clip_grp.set("clip", me.clipAltScale);
      #print("alt " ~ sprintf("%3d", alt) ~ " radAlt:" ~ sprintf("%3d", radAlt) ~ " rad_offset:" ~ sprintf("%3d", me.rad_offset));
    }
    me.alt_scale_grp.update();
    me.alt_scale_grp.show();
  },

  displayDigitalAltitude: func (alt, radAlt) {
    me.alt.show();
    # alt and radAlt is in current unit
    # determine max radar alt in current unit
    me.radar_clamp = me.input.units.getValue() ==1 ? 100 : 100*M2FT;
    me.alt_diff = me.input.units.getValue() ==1 ? 7 : 7*M2FT;
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
    if (radAlt != nil and radAlt < me.radar_clamp) {
      if (me.INT == FALSE) {
        me.inter = FALSE;
        # in radar alt range
        me.alt.setText(sprintf("R %3d", clamp(radAlt, 0, me.radar_clamp)));
      }
    } else {
      if (me.INT == FALSE) {
        me.inter = FALSE;
        me.gElev_ft = me.input.elev_ft.getValue();
        me.gElev_m  = me.input.elev_m.getValue();

        if (me.gElev_ft == nil or me.gElev_m == nil) {
          me.alt.setText("");
        } else {
          me.metric = me.input.units.getValue();
          if (me.metric == TRUE) {
            me.terrainAlt = me.gElev_m;
            me.alt.setText(sprintf("%4d", clamp(me.terrainAlt, 0, 9999)));
          } else {
            me.terrainAlt = me.gElev_ft;
            me.alt.setText(sprintf("%5d", clamp(me.terrainAlt, 0, 99999)));
          }          
        }
      }
    }
  },

  displayDesiredAltitudeLines: func (guideUseLines) {
    if (guideUseLines == FALSE) {
      me.desired_alt_delta_ft = nil;
      me.showBoxes = FALSE;
      me.showLines = TRUE;
      if(mode == TAKEOFF) {
        me.desired_alt_delta_ft = (500*M2FT)-me.input.alt_ft.getValue();
      } elsif (me.input.APmode.getValue() == 3 and me.input.APTgtAlt.getValue() != nil) {
        me.desired_alt_delta_ft = me.input.APTgtAlt.getValue()-me.input.alt_ft.getValue();
        me.showBoxes = TRUE;
        if (me.input.alt_ft.getValue() * FT2M > 1000) {
          me.showLines = FALSE;
        }
      } elsif(mode == LANDING and land.mode < 3 and land.mode > 0) {
        me.desired_alt_delta_ft = (500*M2FT)-me.input.alt_ft.getValue();
      #} elsif (me.input.APLockAlt.getValue() == "agl-hold" and me.input.APTgtAgl.getValue() != nil) {
      #  me.desired_alt_delta_ft = me.input.APTgtAgl.getValue()-me.input.rad_alt.getValue();
      } elsif(me.input.RMActive.getValue() == 1 and me.input.RMCurrWaypoint.getValue() != nil and me.input.RMCurrWaypoint.getValue() >= 0) {
        me.idx = me.input.RMCurrWaypoint.getValue();
        me.rt_alt = getprop("autopilot/route-manager/route/wp["~me.idx~"]/altitude-ft");
        if(me.rt_alt != nil and me.rt_alt > 0) {
          me.desired_alt_delta_ft = me.rt_alt - me.input.alt_ft.getValue();
        }
      }# elsif (getprop("autopilot/locks/altitude") == "gs1-hold") {
      if(me.desired_alt_delta_ft != nil) {
        me.pos_yyy = clamp(-me.desired_alt_delta_ft*me.pixelPerFeet, -2.5*pixelPerDegreeY, 2.5*pixelPerDegreeY);

        me.desired_lines3.setTranslation(0, me.pos_yyy);
        me.desired_boxes.setTranslation(0, me.pos_yyy);
        if (me.showLines == TRUE) {
          me.desired_lines3.show();
        } else {
          me.desired_lines3.hide();
        }
        if (me.showBoxes == TRUE and (!getprop("fdm/jsbsim/systems/indicators/flashing-alt-bars") or me.input.twoHz.getValue())) {
          me.desired_boxes.show();
        } else {
          me.desired_boxes.hide();
        }
      } else {
        me.desired_lines3.hide();
        me.desired_boxes.hide();
      }
      me.desired_lines2.hide();
    } else {
      me.desired_lines2.show();
      me.desired_lines3.show();
      me.desired_boxes.hide();# todo: show them
    }
  },

  displayLandingGuide: func (mode, deflect) {
    me.guideUseLines = FALSE;
    if(mode == LANDING and (land.mode < 1 or land.mode > 2)) {
      me.deg = 0;#clamp(deflect, -8, 6);
      
      if (me.finalVisual == FALSE and me.input.nav0InRange.getValue() == TRUE and (land.has_waypoint < 1 or ( land.has_waypoint > 1 and land.ils != 0 and getprop("ja37/hud/TILS") == TRUE))) {
        me.deg = clamp(me.input.nav0HeadingDefl.getValue(), -8, 8);# -10 to +10, clamped as -8 till +6

        if (me.input.nav0HasGS.getValue() == TRUE and me.input.nav0GSInRange.getValue() == TRUE) {
          me.factor = clamp(me.input.nav0GSNeedleDefl.getValue() * -1, -0.5, 1);
          
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
        me.desiredSink_deg = math.asin(clamp(me.sinkRateMax_mps/me.groundspeed_mps,-1,1))*R2D;
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
    me.displayGS = air2ground;# in AJ(S) speed type is selected by weapon type when in tactical mode.
    if (mode == LANDING or (me.input.rad_alt_ready.getBoolValue() and me.input.rad_alt.getValue()*FT2M > 1000)) {
      # page 368 in JA37Di manual (small).
      me.displayGS = FALSE;
    } elsif (getprop("ja37/systems/variant") == 0) {
      #JA-37Di
      me.displayGS = TI.ti.ModeAttack;# in JA speed type can be selected on TI display
    }
    if(me.metric == TRUE) {
      # metric
      me.airspeedInt.hide();
      if (me.mach >= 0.5 and mode != LANDING and mode != TAKEOFF) {
        me.speed = me.displayGS == TRUE?me.input.gs.getValue()*KT2KMH:me.input.ias.getValue()*KT2KMH;
        me.type  = me.displayGS == TRUE?"GS":"";
        me.airspeedInt.setText(sprintf(me.type~"%03d", me.speed));
        me.airspeedInt.show();
        me.airspeed.setText(sprintf("%.2f", me.mach));
      } else {
        me.speed = me.displayGS == TRUE?me.input.gs.getValue()*KT2KMH:me.input.ias.getValue() * KT2KMH;
        me.type  = me.displayGS == TRUE?"GS":"";
        if (me.input.ias.getValue() * KT2KMH > 75) {
          me.airspeed.setText(sprintf("%s%03d", me.type, me.speed));
        } else {
          me.airspeed.setText("");
        }
      }
    } elsif (mode == LANDING or mode == TAKEOFF or me.mach < 0.5) {
      # interoperability without mach
      me.airspeedInt.hide();
      if (me.input.ias.getValue() * KT2KMH > 75) {
        me.speed = me.displayGS == TRUE?me.input.gs.getValue():me.input.ias.getValue();
        me.type  = me.displayGS == TRUE?"GS":"KT";
        me.airspeed.setText(sprintf(me.type~"%03d", me.speed));
      } else {
        me.airspeed.setText("");
      }
    } else {
      # interoperability with mach
      me.speed = me.displayGS == TRUE?me.input.gs.getValue():me.input.ias.getValue();
      me.type  = me.displayGS == TRUE?"GS":"KT";
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
    me.rot = -me.input.roll.getValue() * D2R;
    me.h_rot.setRotation(me.rot);
    # now figure out how much we move horizon group laterally, to keep FPI in middle of it.
    me.pos_y_rel = me.pos_y - centerOffset;
    me.fpi_polar = clamp(math.sqrt(me.pos_x*me.pos_x+me.pos_y_rel*me.pos_y_rel),0.0001,10000);
    me.inv_angle = clamp(-me.pos_y_rel/me.fpi_polar,-1,1);
    me.fpi_angle = math.acos(me.inv_angle);
    if (me.pos_x < 0) {
      me.fpi_angle *= -1;
    }
    me.fpi_pos_rel_x    = math.sin(me.fpi_angle-me.rot)*me.fpi_polar;
    
    #me.fpi_pos_rel_y = math.cos(me.fpi_angle-me.rot)*me.fpi_polar;
    #me.fpi_lateral_polar = me.fpi_pos_rel_y/math.cos(me.rot);
    me.max_lateral_pitchnumbers = 0;
    me.max_lateral_pitchnumbers_p = 0;
    me.rot_deg = geo.normdeg(-me.input.roll.getValue());
    me.default_lateral_pitchnumbers = canvasWidth*0.25;
    me.max_vertical_max = 0;
    me.max_vertical_min = 0;
    me.vertical_buffer = mode==LANDING?altimeterScaleHeight*1.4:6*pixelPerDegreeY;
    if (me.rot_deg >= 0 and me.rot_deg < 90) {
      me.max_lateral_pitchnumbers   = extrapolate(me.rot_deg,0,90,me.default_lateral_pitchnumbers,me.default_lateral_pitchnumbers+centerOffset);
      me.max_lateral_pitchnumbers_p = extrapolate(me.rot_deg,0,90,me.default_lateral_pitchnumbers*0.65,me.default_lateral_pitchnumbers*0.65-centerOffset);
      me.max_vertical_min = extrapolate(me.rot_deg,0,90, -centerOffset-canvasWidth/4, -canvasWidth/4);
      me.max_vertical_max = extrapolate(me.rot_deg,0,90, canvasWidth/2-centerOffset-me.vertical_buffer, canvasWidth/2-me.vertical_buffer);
    } elsif (me.rot_deg >= 90 and me.rot_deg < 180) {
      me.max_lateral_pitchnumbers   = extrapolate(me.rot_deg,90,180,me.default_lateral_pitchnumbers+centerOffset,me.default_lateral_pitchnumbers);
      me.max_lateral_pitchnumbers_p = extrapolate(me.rot_deg,90,180,me.default_lateral_pitchnumbers*0.65-centerOffset,me.default_lateral_pitchnumbers*0.65);
      me.max_vertical_min = extrapolate(me.rot_deg,90,180, -canvasWidth/4, centerOffset-canvasWidth/4);
      me.max_vertical_max = extrapolate(me.rot_deg,90,180, canvasWidth/2-me.vertical_buffer, canvasWidth/2+centerOffset-me.vertical_buffer);
    } elsif (me.rot_deg >= 180 and me.rot_deg < 270) {
      me.max_lateral_pitchnumbers   = extrapolate(me.rot_deg,180,270,me.default_lateral_pitchnumbers,me.default_lateral_pitchnumbers-centerOffset);
      me.max_lateral_pitchnumbers_p = extrapolate(me.rot_deg,180,270,me.default_lateral_pitchnumbers*0.65,me.default_lateral_pitchnumbers*0.65+centerOffset);
      me.max_vertical_min = extrapolate(me.rot_deg,180,270, centerOffset-canvasWidth/4, -canvasWidth/4);
      me.max_vertical_max = extrapolate(me.rot_deg,180,270, canvasWidth/2+centerOffset-me.vertical_buffer, canvasWidth/2-me.vertical_buffer);
    } else {
      me.max_lateral_pitchnumbers   = extrapolate(me.rot_deg,270,360,me.default_lateral_pitchnumbers-centerOffset,me.default_lateral_pitchnumbers);
      me.max_lateral_pitchnumbers_p = extrapolate(me.rot_deg,270,360,me.default_lateral_pitchnumbers*0.65+centerOffset,me.default_lateral_pitchnumbers*0.65);
      me.max_vertical_min = extrapolate(me.rot_deg,270,360, -canvasWidth/4,-centerOffset-canvasWidth/4);
      me.max_vertical_max = extrapolate(me.rot_deg,270,360, canvasWidth/2-me.vertical_buffer,canvasWidth/2-centerOffset-me.vertical_buffer);
    }
    me.horizon_lateral  = clamp(me.fpi_pos_rel_x,-me.max_lateral_pitchnumbers,me.max_lateral_pitchnumbers_p);#-math.sqrt(me.fpi_lateral_polar*me.fpi_lateral_polar-me.fpi_pos_rel_y*me.fpi_pos_rel_y);
    me.horizon_vertical = clamp(-math.cos(me.fpi_angle-me.rot)*me.fpi_polar, me.max_vertical_min, me.max_vertical_max);
    me.horizon_group.setTranslation(0, centerOffset);
    me.horizon_group2.setTranslation(me.horizon_lateral, pixelPerDegreeY * me.input.pitch.getValue());
    me.horizon_group3.setTranslation(me.horizon_lateral, pixelPerDegreeY * me.input.pitch.getValue());
    me.horizon_group4.setTranslation(me.horizon_lateral, pixelPerDegreeY * me.input.pitch.getValue());
    me.alt_scale_clip_grp.setTranslation(me.horizon_lateral, me.horizon_vertical);
    if(mode == COMBAT) {
      me.horizon_group3.show();
      me.horizon_group4.show();
      me.horizon_dots.hide();
      me.horizon_line_gap.hide();
      me.horizon_line_nav.hide();
      me.horizon_line.show();
    } elsif (mode == LANDING) {
      me.horizon_group3.hide();
      me.horizon_group4.hide();
      me.horizon_dots.hide();
      me.horizon_line_gap.show();
      me.horizon_line_nav.hide();
      me.horizon_line.show();
    } else {
      me.horizon_group3.hide();
      me.horizon_group4.show();
      me.horizon_dots.show();
      me.horizon_line_gap.hide();
      me.horizon_line_nav.show();
      me.horizon_line.hide();
    }
  },

  displayQFE: func (mode) {
    me.DME = me.input.dme.getValue() != "---" and me.input.dme.getValue() != "" and me.input.dmeDist.getValue() != nil and me.input.dmeDist.getValue() != 0;
    if (mode == LANDING and me.input.nav0InRange.getValue() == TRUE) {
      if (land.has_waypoint > 1 and land.ils != 0) {
        if (me.DME == TRUE) {
          me.qfe.setText("TILS/DME");
        } else {
          me.qfe.setText("TILS");
        }
        if (getprop("instrumentation/TLS-light")) {
          me.qfe.show();
        } else {
          # blinking
          me.qfe.hide();
        }
      } elsif (land.has_waypoint < 1) {
        if (me.DME == TRUE) {
          me.qfe.setText("ILS/DME");
        } else {
          me.qfe.setText("ILS");
        }
        me.qfe.show();
      } else {
        if (me.DME == TRUE) {
          me.qfe.setText("DME");
          me.qfe.show();
        } else {
          me.qfe.hide();
        }
      }
    } elsif ((mode == LANDING or mode == NAV) and me.DME == TRUE) {
      me.qfe.setText("DME");
      me.qfe.show();
    } elsif (mode == COMBAT) {
      me.qfe.setText(displays.common.currArmNameMedium);
      me.qfe.show();
    } elsif (me.input.qfeActive.getValue()) {
      # QFE is shown
      me.qfe.setText("QFE");
      if(me.input.qfeShown.getValue() == TRUE) {
        me.qfe.show();
      } else {
        me.qfe.hide();
      }
    } else {
      me.qfe.hide();
    }
    #me.qfe.update(); probably not needed
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
      return me.showFlightPathVector(out_of_ammo, out_of_ammo, mode);
    } elsif (mode == COMBAT and cannon == FALSE) {
      if (me.station == -1) {
        air2air = FALSE;
        air2ground = FALSE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.hide();
        me.reticle_c_missile.hide();
        return;
      }
      me.armament = getprop("payload/weight["~ (me.station-1) ~"]/selected");
      if(me.armament == "M70 ARAK") {
        air2air = FALSE;
        air2ground = TRUE;
        me.showSidewind(FALSE);
        me.reticle_cannon.setTranslation(0, centerOffset);
        me.reticle_cannon.show();
        me.reticle_missile.hide();
        #me.reticle_c_missile.show();
      } elsif(me.armament == "RB 24 Sidewinder") {
        air2air = TRUE;
        air2ground = FALSE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        #me.reticle_missile.show();
        me.reticle_c_missile.hide();
      } elsif(me.armament == "RB 24J Sidewinder") {
        air2air = TRUE;
        air2ground = FALSE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        #me.reticle_missile.show();
        me.reticle_c_missile.hide();
      } elsif(me.armament == "RB 74 Sidewinder") {
        air2air = TRUE;
        air2ground = FALSE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        #me.reticle_missile.show();
        me.reticle_c_missile.hide();
      } elsif(me.armament == "RB 71 Skyflash") {
        air2air = TRUE;
        air2ground = FALSE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        #me.reticle_missile.show();
        me.reticle_c_missile.hide();
      } elsif(me.armament == "RB 99 Amraam") {
        air2air = TRUE;
        air2ground = FALSE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        #me.reticle_missile.show();
        me.reticle_c_missile.hide();
      } elsif(me.armament == "RB 15F Attackrobot") {
        air2air = FALSE;
        air2ground = TRUE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.hide();
        #me.reticle_c_missile.show();
      } elsif(me.armament == "RB 04E Attackrobot") {
        air2air = FALSE;
        air2ground = TRUE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.hide();
        #me.reticle_c_missile.show();
      } elsif(me.armament == "RB 05A Attackrobot") {
        air2air = FALSE;
        air2ground = TRUE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.hide();
        #me.reticle_c_missile.show();
      } elsif(me.armament == "RB 75 Maverick") {
        air2air = FALSE;
        air2ground = TRUE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.hide();
        #me.reticle_c_missile.show();
      } elsif(me.armament == "M71 Bomblavett") {
        air2air = FALSE;
        air2ground = TRUE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.hide();
        #me.reticle_c_missile.show();
      } elsif(me.armament == "M71 Bomblavett (Retarded)") {
        air2air = FALSE;
        air2ground = TRUE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.hide();
        #me.reticle_c_missile.show();
      } elsif(me.armament == "M90 Bombkapsel") {
        air2air = FALSE;
        air2ground = TRUE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.hide();
        #me.reticle_c_missile.show();
      } elsif(me.armament == "TEST") {
        air2air = TRUE;
        air2ground = FALSE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        #me.reticle_missile.show();
        me.reticle_c_missile.hide();
      } else {
        air2air = FALSE;
        air2ground = FALSE;
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.hide();
        me.reticle_c_missile.hide();
      }
      return me.showFlightPathVector(out_of_ammo, out_of_ammo, mode);
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
    me.vel_gx = me.input.speed_n.getValue();
    me.vel_gy = me.input.speed_e.getValue();
    me.vel_gz = me.input.speed_d.getValue();

    me.yaw = me.input.hdgReal.getValue() * D2R;
    me.roll = me.input.roll.getValue() * D2R;
    me.pitch = me.input.pitch.getValue() * D2R;

    if (math.sqrt(me.vel_gx *me.vel_gx+me.vel_gy*me.vel_gy+me.vel_gz*me.vel_gz)<15) {
      # we are pretty much still, point the vector along axis.
      me.vel_gx = math.cos(me.yaw)*1;
      me.vel_gy = math.sin(me.yaw)*1;
      me.vel_gz = 0;
    }
 
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
 
    me.dir_y  = math.atan2(round0(me.vel_bz), math.max(me.vel_bx, 0.001)) * R2D;
    me.dir_x  = math.atan2(round0(me.vel_by), math.max(me.vel_bx, 0.001)) * R2D;
    
    me.input.fpiHorz.setDoubleValue(me.dir_x);#used in MI display
    me.input.fpiVert.setDoubleValue(me.dir_y);

    me.pos_x = clamp(me.dir_x * pixelPerDegreeX, -max_width, max_width);
    me.pos_y = clamp((me.dir_y * pixelPerDegreeY)+centerOffset, -max_width, (800/1024)*canvasWidth);

    me.fpi_group.setTranslation(me.pos_x, me.pos_y);
    if(show == TRUE) {
      if ( out_of_ammo == TRUE) {
        me.aim_reticle.hide();
        me.aim_reticle_fin.hide();
        me.reticle_no_ammo.show();
        #me.reticle_no_ammo.setTranslation(me.pos_x, me.pos_y);
      } else {
        me.reticle_no_ammo.hide();
        me.aim_reticle.show();
        
        #me.reticle_group.setTranslation(me.pos_x, me.pos_y);
                
        if (mode == LANDING) {
          # move fin to alpha or speed
          me.gearsDown = me.input.gearsPos.getValue();

          if (me.gearsDown == TRUE) {
            me.alpha = me.input.alphaJSB.getValue();
            me.highAlpha = getprop("fdm/jsbsim/autoflight/high-alpha");
            me.idealAlpha = 15.5;# the ideal aoa for landing.
            if (me.highAlpha == FALSE) {
              me.myWeight = getprop("fdm/jsbsim/inertia/weight-lbs")*LB2KG;
              me.idealAlpha = extrapolate(me.myWeight, 15000, 16500, 15.5, 9.0);#9 + ((me.myWeight - 28000) / (38000 - 28000)) * (12 - 9);#is 9-12 depending on weight
              me.idealAlpha = ja37.clamp(me.idealAlpha, 9, 12);
            }
            me.translation = (me.alpha-me.idealAlpha)*6.5;
          } else {
            me.speed = me.input.ias.getValue();
            me.speed_goal = 297;
            me.translation = (me.speed_goal - me.speed)*2;
          }        

          me.translation = clamp(me.translation, -60, 30);
          me.reticle_fin_group.setTranslation(0, (me.translation/1024)*canvasWidth);
          if (me.gearsDown == TRUE and me.alpha > me.idealAlpha+3) {
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
      if (me.input.pitch.getValue() < 5) {
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
        if(me.input.ias.getValue() < 75/KT2KMH) {
          me.mySpeed.setTranslation(me.pixelPerKmh*75, 0);
        } else {
          me.pos = me.pixelPerKmh*me.input.ias.getValue()*KT2KMH;
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
      } else {
        me.targetSpeed.hide();
        me.mySpeed.hide();
        me.targetDistance1.hide();
        me.targetDistance2.hide();
        me.distanceText.hide();
        me.distanceScale.hide();
      }
    } elsif (mode == COMBAT) {
      if (radar_logic.selection != nil) {
        me.line = (200/1024)*canvasWidth;
        me.aim = displays.common.armActive();
        if (me.aim != nil) {
          me.dlz = me.aim.getDLZ();
        } else {
          me.dlz = nil;
        }
        me.armSelect = me.station;
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
        } elsif (me.aim != nil) {
          # missile code
          me.minDist =   me.aim.min_fire_range_nm*NM2M;
          me.maxDist =   me.aim.max_fire_range_nm*NM2M;
        } elsif (me.armament == "M55 AKAN") {
          # pylon mounted cannons
          me.minDist =  100;
          me.maxDist = 2800;
        } elsif (me.armament == "M70 ARAK") {
          # Rocket pods
          me.minDist =   200;
          me.maxDist =  2000;
        }
        if (me.dlz != nil) {
          if (size(me.dlz) > 0) {
            me.pixelPerMeterLine = me.line/(me.dlz[0]*NM2M);
            me.mySpeed.setTranslation(me.pixelPerMeterLine*(me.dlz[4]*NM2M), 0);
            me.targetSpeed.setTranslation(me.pixelPerMeterLine*(me.dlz[1]*NM2M), 0);
            me.targetDistance1.setTranslation(me.pixelPerMeterLine*(me.dlz[3]*NM2M), 0);
            me.targetDistance2.setTranslation(me.pixelPerMeterLine*(me.dlz[2]*NM2M), 0);
            me.targetSpeed.show();
            me.targetDistance1.show();
            me.targetDistance2.show();
            me.distanceScale.show();
            if (me.input.tenHz.getValue() == TRUE or (me.dlz[4] > me.dlz[2] and me.dlz[4] > me.dlz[3])) {
              me.mySpeed.show();
            } else {
              me.mySpeed.hide();
            }            
          } else {
            me.targetSpeed.hide();
            me.targetDistance1.hide();
            me.targetDistance2.hide();
            me.distanceScale.hide();
            me.mySpeed.hide();
          }
          me.ammo = armament.ammoCount(me.station);
          if (me.station == 0) {
            me.distanceText.setText(sprintf("%3d", me.ammo));
            me.distanceText.show();
          } elsif (me.ammo != -1) {
            me.distanceText.setText(sprintf("%1d", me.ammo));
            me.distanceText.show();
          } else {
            me.distanceText.hide();
          }
          return;
        } elsif(me.currDist != nil and me.minDist != nil) {
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
          me.shown = FALSE;
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
      me.ammo = armament.ammoCount(me.station);
      if (me.station == 0) {
        me.distanceText.setText(sprintf("%3d", me.ammo));
        me.distanceText.show();
      } elsif (me.ammo != -1) {
        me.distanceText.setText(sprintf("%1d", me.ammo));
        me.distanceText.show();
      } else {
        me.distanceText.hide();
      }
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
      me.distanceText.setText(sprintf("%.1f", me.input.units.getValue() == 1  ? me.distance*NM2KM : me.distance));

      me.targetSpeed.hide();
      me.targetDistance1.show();
      me.targetDistance2.hide();
      me.distanceText.show();
      me.distanceScale.show();
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
      me.distanceText.setText(sprintf("%.1f", me.input.units.getValue() == 1  ? me.distance*KT2KMH : me.distance));

      me.targetSpeed.hide();
      me.targetDistance1.hide();
      me.targetDistance2.hide();
      me.distanceText.show();
      me.distanceScale.show();
    } else {
      me.targetSpeed.hide();
      me.mySpeed.hide();
      me.targetDistance1.hide();
      me.targetDistance2.hide();
      me.distanceText.hide();
      me.distanceScale.hide();
    }
    me.dist_scale_group.setTranslation(-(100/1024)*canvasWidth, distScalePos);
  },

  displayTower: func () {
    me.towerAlt = me.input.towerAlt.getValue();
    me.towerLat = me.input.towerLat.getValue();
    me.towerLon = me.input.towerLon.getValue();
    if(mode != COMBAT and me.towerAlt != nil and me.towerLat != nil and me.towerLon != nil and me.final == FALSE) {# and me.final == FALSE
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
          me.tower_dist = me.input.units.getValue() ==1  ? me.distance : me.distance/NM2KM;
          if(me.tower_dist < 10000) {
            me.tower_symbol_dist.setText(sprintf("%.1f", me.tower_dist/1000));
          } else {
            me.tower_symbol_dist.setText(sprintf("%02d", me.tower_dist/1000));
          }          
          me.tower_symbol_icao.setText("");#me.hud_pos.get_Callsign());  disabled for realism
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
  
  resetGunPos: func {
      me.gunPos   = [];
      for(i = 0;i < me.funnelParts;i+=1){
        var tmp = [];
        for(var myloopy = 0;myloopy <= i+1;myloopy+=1){
          append(tmp,nil);
        }
        append(me.gunPos, tmp);
      }
  },
  
  makeVector: func (siz,content) {
      var vec = setsize([],siz);
      var k = 0;
      while(k<siz) {
          vec[k] = content;
          k += 1;
      }
      return vec;
  },
  
  displayGunPipper: func {
    var eegsShow = 0;
    if(me.cannon) {
        eegsShow = 1;
    }
    me.eegsGroup.setVisible(eegsShow);
    if (eegsShow and !me.eegsLoop.isRunning) {
        me.eegsLoop.start();
    } elsif (!eegsShow and me.eegsLoop.isRunning) {
        me.eegsLoop.stop();
    }
  },
  
  getPosFromCoord: func (coord, viewer) {
    me.ptch = vector.Math.getPitch(viewer,coord);
    me.dst  = viewer.direct_distance_to(coord);
    me.brng = viewer.course_to(coord);
    me.hrz  = math.cos(me.ptch*D2R)*me.dst;

    me.vel_gz = -math.sin(me.ptch*D2R)*me.dst;
    me.vel_gx = math.cos(me.brng*D2R) *me.hrz;
    me.vel_gy = math.sin(me.brng*D2R) *me.hrz;
    

    me.yaw   = me.input.hdgReal.getValue() * D2R;
    me.roll  = me.input.roll.getValue()    * D2R;
    me.pitch = me.input.pitch.getValue()   * D2R;

    #printf("heading %.1f bearing %.1f pitch %.1f north %.1f east %.1f down %.1f", input.hdgReal.getValue(), me.brng, me.ptch, me.vel_gx, me.vel_gy, me.vel_gz);

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
 
    me.dir_y  = math.atan2(round0(me.vel_bz), math.max(me.vel_bx, 0.001)) * R2D;
    me.dir_x  = math.atan2(round0(me.vel_by), math.max(me.vel_bx, 0.001)) * R2D;

    var hud_pos_x = me.getPosFromDeg(me.dir_x);
    var hud_pos_y = centerOffset + me.getPosFromDeg(me.dir_y);

    return [hud_pos_x, hud_pos_y];
  },
  
  getPosFromDeg: func (deg) {
    return pixelPerMeter*defaultHeadDistance * math.tan(deg*D2R);
  },
  
  displayEEGS: func() {
        #note: this stuff is expensive like hell to compute, but..lets do it anyway.
        
        var st = systime();
        me.eegsMe.dt = st-me.lastTime;
        if (me.eegsMe.dt > me.averageDt*3) {
            me.lastTime = st;
            me.resetGunPos();
            me.eegsGroup.removeAllChildren();
        } else {
            me.lastTime = st;
            
            me.eegsMe.hdg   = getprop("orientation/heading-deg");
            me.eegsMe.pitch = getprop("orientation/pitch-deg");
            me.eegsMe.roll  = getprop("orientation/roll-deg");
            
            me.eegsMe.ac = geo.viewer_position();
            me.eegsMe.allow = 1;
            me.drawEEGSPipper = 0;
            for (var l = 0;l < me.funnelParts;l+=1) {
                # compute display positions of funnel on hud
                var pos = me.gunPos[l][l+1];
                if (pos == nil) {
                    me.eegsMe.allow = 0;
                } else {
                    var ac  = me.gunPos[l][l][1];
                    pos     = me.gunPos[l][l][0];
                    me.eegsMe.posTemp = me.getPosFromCoord(pos, ac);
                    me.eegsMe.shellPosDist[l] = ac.direct_distance_to(pos)*M2FT;
                    me.eegsMe.shellPosX[l] = me.eegsMe.posTemp[0];
                    me.eegsMe.shellPosY[l] = me.eegsMe.posTemp[1];
                    
                    if (me.designatedDistanceFT != nil and !me.drawEEGSPipper) {
                      if (l != 0 and me.eegsMe.shellPosDist[l] >= me.designatedDistanceFT and me.eegsMe.shellPosDist[l]>me.eegsMe.shellPosDist[l-1]) {
                        var highdist = me.eegsMe.shellPosDist[l];
                        var lowdist = me.eegsMe.shellPosDist[l-1];
                        me.eegsPipperX = extrapolate(me.designatedDistanceFT,lowdist,highdist,me.eegsMe.shellPosX[l-1],me.eegsMe.shellPosX[l]);
                        me.eegsPipperY = extrapolate(me.designatedDistanceFT,lowdist,highdist,me.eegsMe.shellPosY[l-1],me.eegsMe.shellPosY[l]);
                        me.drawEEGSPipper = 1;
                      }
                    }
                }
            }
            if (me.eegsMe.allow) {
                # draw the funnel
                #for (var k = 0;k<me.funnelParts;k+=1) {
                #    var halfspan = math.atan2(35*0.5,me.eegsMe.shellPosDist[k])*R2D*pixelPerDegreeX;#35ft average fighter wingspan
                #    me.eegsRightX[k] = me.eegsMe.shellPosX[k]-halfspan;
                #    me.eegsRightY[k] = me.eegsMe.shellPosY[k];
                #    me.eegsLeftX[k]  = me.eegsMe.shellPosX[k]+halfspan;
                #    me.eegsLeftY[k]  = me.eegsMe.shellPosY[k];
                #}
                me.eegsGroup.removeAllChildren();
                #for (var i = 1; i < me.funnelParts-1; i+=1) {#changed to i=1 as we dont need funnel to start so close
                #    me.eegsGroup.createChild("path")
                #        .moveTo(me.eegsRightX[i], me.eegsRightY[i])
                #        .lineTo(me.eegsRightX[i+1], me.eegsRightY[i+1])
                #        .moveTo(me.eegsLeftX[i], me.eegsLeftY[i])
                #        .lineTo(me.eegsLeftX[i+1], me.eegsLeftY[i+1])
                #        .setStrokeLineWidth(w)
                #        .setColor(color);
                #}
                if (me.drawEEGSPipper) {
                    var radius = 20;
                    me.eegsGroup.createChild("path")
                          .moveTo(me.eegsPipperX, me.eegsPipperY-radius)
                          .arcSmallCW(radius,radius,0,0,radius*2)
                          .arcSmallCW(radius,radius,0,0,-radius*2)
                          .setStrokeLineWidth(w)
                          .setStrokeDashArray([3,10])
                          .setColor(color);
                }
                me.eegsGroup.update();
            }
            
            
            
            
            #calc shell positions
            
            me.eegsMe.vel = getprop("velocities/uBody-fps")+3383.33;#3383.33 = speed
            
            me.eegsMe.geodPos = aircraftToCart({x:1.0589, y:-0.20321, z: 0.9124});#position of gun in aircraft (x and z inverted)
            me.eegsMe.eegsPos.set_xyz(me.eegsMe.geodPos.x, me.eegsMe.geodPos.y, me.eegsMe.geodPos.z);
            me.eegsMe.altC = me.eegsMe.eegsPos.alt();
            
            me.eegsMe.rs = armament.AIM.rho_sndspeed(me.eegsMe.altC*M2FT);#simplified
            me.eegsMe.rho = me.eegsMe.rs[0];
            me.eegsMe.mass =  2.69/ armament.slugs_to_lbm;#2.69=lbs
            
            for (var j = 0;j < me.funnelParts;j+=1) {
                
                #calc new speed
                me.eegsMe.Cd = drag(me.eegsMe.vel/ me.eegsMe.rs[1],0.193);#0.193=cd
                me.eegsMe.q = 0.5 * me.eegsMe.rho * me.eegsMe.vel * me.eegsMe.vel;
                me.eegsMe.deacc = (me.eegsMe.Cd * me.eegsMe.q * 0.00136354) / me.eegsMe.mass;#0.00136354=eda
                me.eegsMe.vel -= me.eegsMe.deacc * me.averageDt;
                me.eegsMe.speed_down_fps       = -math.sin(me.eegsMe.pitch * D2R) * (me.eegsMe.vel);
                me.eegsMe.speed_horizontal_fps = math.cos(me.eegsMe.pitch * D2R) * (me.eegsMe.vel);
                
                me.eegsMe.speed_down_fps += 9.81 *M2FT *me.averageDt;
                
                
                 
                me.eegsMe.altC -= (me.eegsMe.speed_down_fps*me.averageDt)*FT2M;
                
                
                me.eegsMe.dist = (me.eegsMe.speed_horizontal_fps*me.averageDt)*FT2M;
                
                me.eegsMe.eegsPos.apply_course_distance(me.eegsMe.hdg, me.eegsMe.dist);
                me.eegsMe.eegsPos.set_alt(me.eegsMe.altC);
                
                var old = me.gunPos[j];
                me.gunPos[j] = [[geo.Coord.new(me.eegsMe.eegsPos),me.eegsMe.ac]];
                for (var m = 0;m<j+1;m+=1) {
                    append(me.gunPos[j], old[m]);
                } 
                
                me.eegsMe.vel = math.sqrt(me.eegsMe.speed_down_fps*me.eegsMe.speed_down_fps+me.eegsMe.speed_horizontal_fps*me.eegsMe.speed_horizontal_fps);
                me.eegsMe.pitch = math.atan2(-me.eegsMe.speed_down_fps,me.eegsMe.speed_horizontal_fps)*R2D;
            }                        
        }
    },

  displayCCIP: func () {
    if(mode == COMBAT) {

      me.armSelect = me.station;
      if(me.armSelect > 0 and (getprop("payload/weight["~ (me.armSelect-1) ~"]/selected") == "M71 Bomblavett" or getprop("payload/weight["~ (me.armSelect-1) ~"]/selected") == "M71 Bomblavett (Retarded)")) {

        me.bomb = nil;
        if(armament.AIM.active[me.armSelect-1] != nil) {
          me.bomb = armament.AIM.active[me.armSelect-1];
        } else {
          me.ccip_symbol.hide();
          return 20;
        }

        me.ccip_result = me.bomb.getCCIPadv(17, 0.1);
        if (me.ccip_result == nil) {
          me.ccip_symbol.hide();
          return 20;
        }
        
        me.ccipPos  = me.ccip_result[0];
        me.t = me.ccip_result[2];
        
        if (me.t >= 16) {
          me.ccip_symbol.hide();
          return me.t;
        }

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

  displaySeeker: func (mode) {
    me.missileCurr = displays.common.armActive();
    me.diamond_small.hide();
    me.lock_ir.hide();
    if (me.missileCurr != nil and mode == COMBAT and me.missileCurr.guidance == "heat") {
      me.ds = me.missileCurr.getSeekerInfo();
      if (me.ds == nil) {
          me.diamond_small.hide();
          me.lock_ir_last = FALSE;
      } else {
          if (me.missileCurr.status != armament.MISSILE_LOCK) {
            if ((me.missileCurr.isBore() and me.missileCurr.isCaged()) or (!me.missileCurr.isSlave() and !me.missileCurr.isBore() and !me.missileCurr.isCaged()) or (me.missileCurr.isCaged() and me.missileCurr.isSlave() and !me.missileCurr.command_tgt)) {
              # small seeker diamond should show. TODO: refine this if statement
              me.diamond_small.setTranslation(me.ds[0]*pixelPerDegreeX, -me.ds[1]*pixelPerDegreeY+centerOffset);
              me.diamond_small.show();
            }
            me.lock_ir_last = FALSE;
          } else {
            if (me.lock_ir_last == FALSE) {
              radar_logic.lockLog.push(sprintf("IR lock on to %s (%s)",me.missileCurr.callsign,me.missileCurr.type));
            }
            me.lock_ir_last = TRUE;
            me.lock_ir.setTranslation(me.ds[0]*pixelPerDegreeX, -me.ds[1]*pixelPerDegreeY+centerOffset);
            me.lock_ir.show();
          }
      }
    } else {
      me.lock_ir_last = FALSE;
    }
    me.diamond_small.update();
    me.lock_ir.update();
    if (me.missileCurr != nil and (me.missileCurr.isBore() or (!me.missileCurr.isSlave() and !me.missileCurr.isBore() and !me.missileCurr.isCaged()) or (me.missileCurr.isSlave() and !me.missileCurr.command_tgt))) {
      me.missileCurr.setContacts(radar_logic.complete_list);
    } elsif (me.missileCurr != nil) {
      me.missileCurr.setContacts([]);
    }
  },

  displayRadarTracks: func (mode) {
    me.designatedDistanceFT = nil;
    me.track_index = 1;
    me.selection_updated = FALSE;
    me.armSelect = me.station;
    me.missileCurr = displays.common.armActive();
    if(me.input.tracks_enabled.getValue() == 1 and me.input.radar_serv.getValue() > 0 and getprop("ja37/radar/active") == TRUE) {
      me.radar_group.show();

      me.selection = radar_logic.selection;

      if (me.selection != nil and (me.selection.parents[0] == radar_logic.ContactGPS or me.selection.parents[0] == radar_logic.ContactGhost)) {
        me.displayRadarTrack(me.selection);
      }

      # do upper semi squares here
      foreach(hud_pos; radar_logic.tracks) {
        me.displayRadarTrack(hud_pos);
      }
      if(me.track_index != -1) {
        #hide the the rest unused upper semi squares
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
        me.designatedDistanceFT = me.selection.get_range()*NM2FT;
        me.pos_x = me.selection.get_cartesian()[0];
        me.pos_y = me.selection.get_cartesian()[1];

        if (me.pos_y != 0 and me.pos_x != 0 and (me.pos_x > (512/1024)*canvasWidth or me.pos_y > (512/1024)*canvasWidth or me.pos_x < -(512/1024)*canvasWidth or me.pos_y < -(462/1024)*canvasWidth)) {
          # outside HUD view, we then use polar coordinates to find where on the border it should be displayed
          # notice we dont use the top 50 texels of the HUD, due to semi circles would become invisible.

          # TODO: the airplane axis should be uses as origin.
          me.angle = math.atan2(-me.pos_y, me.pos_x) * R2D;
          
          if (me.angle > -45 and me.angle < 42.06) {
            # right side
            me.pos_x = (512/1024)*canvasWidth;
            me.pos_y = -math.tan(me.angle*D2R) * (512/1024)*canvasWidth;
          } elsif (me.angle > 137.94 or me.angle < -135) {
            # left side
            me.pos_x = -(512/1024)*canvasWidth;
            me.pos_y = math.tan(me.angle*D2R) * (512/1024)*canvasWidth;
          } elsif (me.angle > 42.06 and me.angle < 137.94) {
            # top side
            me.pos_x = 1/math.tan(me.angle*D2R) * (462/1024)*canvasWidth;
            me.pos_y = -(462/1024)*canvasWidth;
          } elsif (me.angle < -45 and me.angle > -135) {
            # bottom side
            me.pos_x = -1/math.tan(me.angle*D2R) * (512/1024)*canvasWidth;
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
          if (getprop("ja37/systems/variant") > 0) {
            # only show names in HUD on the AJ variants as they lack the MI display.
            if (me.input.callsign.getValue() == TRUE) {
              me.diamond_name.setText(me.selection.get_Callsign());
            } else {
              me.diamond_name.setText(me.selection.get_model());
            }
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

          me.displayDiamond = 0;
          #print();
          me.roll = me.input.roll.getValue();
          if(me.missileCurr != nil and me.missileCurr.status == armament.MISSILE_LOCK
             and (me.missileCurr.rail == TRUE or (me.roll > -90 and me.roll < 90))) {
            # lock and not inverted if the missiles is to be dropped
            
            me.displayDiamond = 2;
#            me.diamond_small.hide();
          }
		  
          #var bearing = diamond_node.getNode("radar/bearing-deg").getValue();
          #var heading = diamond_node.getNode("orientation/true-heading-deg").getValue();
          #var speed = diamond_node.getNode("velocities/true-airspeed-kt").getValue();
          #var down = me.myHeading+180.0;
          #var relative_heading = heading + down - 90.0;
          #var relative_speed = speed/10.0;
          #var pos_y = relative_speed * math.sin(relative_heading*D2R);
          #var pos_x = relative_speed * math.cos(relative_heading*D2R);

          #if(me.track_line != nil) {
          #  me.diamond_group_line.removeAllChildren();
          #}

          #me.track_line = me.diamond_group_line.createChild("path")
          #               .lineTo( pos_x, pos_y)
          #               .setStrokeLineWidth(w)
          #               .setColor(r,g,b, a);
          #print("diamond="~diamond~" blink="~blink);
          if (me.displayDiamond > 0) {
            if (radar_logic.lockLast == nil or (radar_logic.lockLast != nil and radar_logic.lockLast.getUnique() != me.selection.getUnique())) {
              radar_logic.lockLog.push(sprintf("Radar lock on to %s (%s)",me.selection.get_Callsign(),armament.AIM.active[me.armSelect-1].type));
              radar_logic.lockLast = me.selection;
            }

            if (me.blink == TRUE) {
              if(me.input.fiveHz.getValue() == TRUE) {
                me.lock_rdr.show();
              } else {
                me.lock_rdr.hide();
              }
            } else {
              me.lock_rdr.show();
            }
            me.target_circle[0].hide();
          } elsif (me.blink == FALSE or me.input.fiveHz.getValue() == TRUE) {
            me.lock_rdr.hide();
            me.target_circle[0].setTranslation(me.pos_x, me.pos_y);
            me.target_circle[0].show();
          } else {
            me.lock_rdr.hide();
            me.target_circle[0].hide();
          }          
          me.diamond_group.show();
        } else {
          #untargetable but selectable, like carriers and tankers, or planes in navigation mode
          #diamond_node = nil;
          radar_logic.lockLast = nil;
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
          if (getprop("ja37/systems/variant") > 0) {
            # only show names in HUD on the AJ variants as they lack the MI display.
            if (me.input.callsign.getValue() == TRUE) {
              me.diamond_name.setText(me.selection.get_Callsign());
            } else {
              me.diamond_name.setText(me.selection.get_model());
            }
          }
          
          if(me.blink == TRUE and me.input.fiveHz.getValue() == FALSE) {
            me.target_circle[me.selection_index].hide();
          } else {
            me.target_circle[me.selection_index].show();
          }
          me.diamond_group.show();
          me.lock_rdr.hide();
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
            me.relHeading = me.relHeading * D2R;

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
        radar_logic.lockLast = nil;
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
      radar_logic.lockLast = nil;
      armament.contact = nil;
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

  # Translate HUD to follow head movements
  followHeadPosition: func () {
    var head_x_offset = me.input.viewX.getValue() * pixelPerMeter;
    # This one is inverted, because y+ is up in the view coord. system, and down in the HUD coord. system.
    var head_y_offset = (defaultHeadHeight - me.input.viewY.getValue()) * pixelPerMeter;
    var head_z_distance = me.input.viewZ.getValue() - HUDHoriz;
    var scaling_factor = head_z_distance / defaultHeadDistance;
    # On the y axis, scaling is centered on the HUD center,
    # whereas we need it to be centered on the pilot eyes position.
    # This additional vertical offset corrects the error.
    var corrected_y_offset = head_y_offset + (1 - scaling_factor) * centerOffset;

    me.root.setTranslation(canvasWidth/2 + head_x_offset, canvasWidth/2 + corrected_y_offset);
    me.root.setScale(scaling_factor);
  },
};#end of HUDnasal


var id = 0;

var reinitHUD = FALSE;
var hud_pilot = nil;
var init = func() {
  removelistener(id); # only call once
  hud_pilot = HUDnasal.new({"node": "hud", "texture": "hud.png"});
  #setprop("sim/hud/visibility[1]", 0);
  
  #print("HUD initialized.");
  hud_pilot.update();
  #IR_loop();
};

var init2 = setlistener("/sim/signals/reinit", func() {
  setprop("sim/hud/visibility[1]", 0);
}, 0, 0);

#setprop("/systems/electrical/battery", 0);
#id = setlistener("ja37/supported/initialized", init, 0, 0);

var reinit = func() {#mostly called to change HUD color
   #reinitHUD = 1;
   
   if (getprop("sim/rendering/shaders/skydome") == TRUE) {
     r = 0.75;
     b = 0.75;
   } else {
     r = 0.6;
     b = 0.6;
   }
   var backup = on_backup_power;
   # if on backup power then amber will be the colour
   var red = backup == FALSE?r:1;
   var green = backup == FALSE?g:0.5;
   var blue = backup == FALSE?b:0;
   var alpha = backup == FALSE?hud_pilot.input.hudBrightSI.getValue():hud_pilot.input.hudBrightRES.getValue();
   hud_pilot.input.hudBright.setDoubleValue(alpha);
   #printf("alpha=%.7f",alpha);
   var IR = hud_pilot.input.als.getValue() and hud_pilot.input.alsFilter.getValue() and hud_pilot.input.alsIR.getValue();

   if (1==2 and IR) {
      # IR vision enabled, lets not have a green HUD:
      red = green;
      blue = green;
   }

   foreach(var item; artifacts0) {
    item.setColor(red, green, blue, alpha);
    item.setStrokeLineWidth((hud_pilot.input.stroke.getValue()/1024)*canvasWidth);
   }

   foreach(var item; artifacts1) {
    item.setColor(red, green, blue, alpha);
    item.setStrokeLineWidth((hud_pilot.input.stroke.getValue()/1024)*canvasWidth);
   }

   foreach(var item; artifactsText0) {
    item.setColor(red, green, blue, alpha);
   }

   foreach(var item; artifactsText1) {
    item.setColor(red, green, blue, alpha);
   }
   color = [red, green, blue, alpha];

   if (IR) {
     HUDnasal.main.canvas.setColorBackground(red, green, blue, 0);
   } elsif (backup == FALSE) {
     HUDnasal.main.canvas.setColorBackground(red, green, blue, 0);
   } else {
     HUDnasal.main.canvas.setColorBackground(red, green, blue, 0);
   }
  #print("HUD being reinitialized.");
};

setlistener("ja37/hud/brightness-si", reinit,0,0);
setlistener("ja37/hud/brightness-res", reinit,0,0);
setlistener("sim/rendering/shaders/skydome", reinit,0,0);
setlistener("sim/rendering/als-filters/use-filtering", reinit,0,0);
setlistener("sim/rendering/als-filters/use-IR-vision", reinit,0,0);

var cycle_units = func () {
  ja37.click();
  var current = getprop("ja37/hud/units-metric");
  if(current == TRUE) {
    setprop("ja37/hud/units-metric", FALSE);
  } else {
    setprop("ja37/hud/units-metric", TRUE);
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
  ja37.click();
  var current = getprop("/ja37/hud/combat");
  if(current == 1) {
    setprop("/ja37/hud/combat", FALSE);
  } else {
    setprop("/ja37/hud/combat", TRUE);
  }
};

var toggleCallsign = func () {
  ja37.click();
  var current = getprop("/ja37/hud/callsign");
  if(current == 1) {
    setprop("/ja37/hud/callsign", FALSE);
  } else {
    setprop("/ja37/hud/callsign", TRUE);
  }
};


var drag = func (Mach, _cd) {
    if (Mach < 0.7)
        return 0.0125 * Mach + _cd;
    elsif (Mach < 1.2)
        return 0.3742 * math.pow(Mach, 2) - 0.252 * Mach + 0.0021 + _cd;
    else
        return 0.2965 * math.pow(Mach, -1.1506) + _cd;
};
