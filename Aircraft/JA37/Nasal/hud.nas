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

var alt_scale_mode = -1; # the alt scale is not liniar, this indicates which part is showed

var FALSE = 0;
var TRUE = 1;

var on_backup_power = FALSE;

var TAKEOFF = 0;
var NAV = 1;
var COMBAT =2;
var LANDING = 3;

var mode = TAKEOFF;
var modeTimeTakeoff = -1;

# -100 - 0 : not blinking
# 1 - 10   : blinking
# 11 - 125 : steady on
var countQFE = 0;
var QFEcalibrated = FALSE;# if the altimeters are calibrated

var HUDTop = 0.77; # position of top of HUD in meters. 0.77
var HUDBottom = 0.63; # position of bottom of HUD in meters. 0.63
var HUDHoriz = -4.0; # position of HUD on x axis in meters. -4.0
var HUDHeight = HUDTop - HUDBottom; # height of HUD
var canvasWidth = 1024;
# HUD z is 0.63 - 0.77. Height of HUD is 0.14m
# Therefore each pixel is 0.14 / 1024 = 0.00013671875m or each meter is 7314.2857142857142857142857142857 pixels.
var pixelPerMeter = canvasWidth / HUDHeight;
var centerOffset = -1 * (canvasWidth/2 - ((HUDTop - getprop("sim/view[0]/config/y-offset-m"))*pixelPerMeter));#pilot eye position up from vertical center of HUD. (in line from pilots eyes)
# View is 0.71m so 0.77-0.71 = 0.06m down from top of HUD, since Y in HUD increases downwards we get pixels from top:
# 512 - (0.06 / 0.00013671875) = 73.142857142857142857142857142857 pixels up from center. Since -y is upward, result is -73.1. (Per default)


#vertical axis, view is tilted 10 degrees, zoom in when on runway to check it hit the 10deg line. Remember gear compressing will alter it.
var pixelPerDegreeY = pixelPerMeter*(((getprop("sim/view[0]/config/z-offset-m") - HUDHoriz) * math.tan(7.5*deg2rads))/7.5); 
var pixelPerDegreeX = pixelPerDegreeY; #horizontal axis
#var slant = 35; #degrees the HUD is slanted away from the pilot.
var sidewindPosition = centerOffset+(3*pixelPerDegreeY); #should be 2 degrees under horizon.
var sidewindPerKnot = 450/30; # Max sidewind displayed is set at 30 kts. 450pixels is maximum is can move to the side.
var radPointerProxim = 60; #when alt indicater is too close to radar ground indicator, hide indicator
var scalePlace = 200; #horizontal placement of alt scales
var numberOffset = 100; #alt scale numbers horizontal offset from scale 
var indicatorOffset = -10; #alt scale indicators horizontal offset from scale (must be high, due to bug #1054 in canvas) 
var headScalePlace = 300; # vert placement of alt scale
var headScaleTickSpacing = 65;# horizontal spacing between ticks. Remember to adjust bounding box when changing.
var altimeterScaleHeight = 225; # the height of the low alt scale. Also used in the other scales as a reference height.
var reticle_factor = 1.3;# size of flight path indicator, aiming reticle, and out of ammo reticle
var sidewind_factor = 1.0;# size of sidewind indicator
var airspeedPlace = 420;
var airspeedPlaceFinal = -100;
var sideslipPlaceX = 325;
var sideslipPlaceY = 425;
var sideslipPlaceXFinal = 0;
var sideslipPlaceYFinal = 0;
var r = 0.6;#HUD colors
var g = 1.0;
var b = 0.6;
var a = 1.0;
var w = getprop("sim/ja37/hud/stroke-linewidth");  #line stroke width (saved between sessions)
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
    HUDnasal.main.canvas.addPlacement(HUDnasal.main.place);
    HUDnasal.main.canvas.setColorBackground(0.36, g, 0.3, 0.05);
    HUDnasal.main.root = HUDnasal.main.canvas.createGroup()
                .set("font", "LiberationFonts/LiberationMono-Regular.ttf");# If using default font, horizontal alignment is not accurate (bug #1054), also prettier char spacing. 
    
    #HUDnasal.main.root.setScale(math.sin(slant*deg2rads), 1);
    HUDnasal.main.root.setTranslation(canvasWidth/2, canvasWidth/2);

    # digital airspeed kts/mach 
    HUDnasal.main.airspeed = HUDnasal.main.root.createChild("text")
      .setText("000")
      .setFontSize(85*fs, ar)
      .setColor(r,g,b, a)
      .setAlignment("center-center")
      .setTranslation(0 , airspeedPlace);
    HUDnasal.main.airspeedInt = HUDnasal.main.root.createChild("text")
      .setText("000")
      .setFontSize(85*fs, ar)
      .setColor(r,g,b, a)
      .setAlignment("center-center")
      .setTranslation(0 , airspeedPlace-70);


    # scale heading ticks
    HUDnasal.main.head_scale_grp = HUDnasal.main.root.createChild("group");
    HUDnasal.main.head_scale_grp.set("clip", "rect(62px, 687px, 262px, 337px)");#top,right,bottom,left
    HUDnasal.main.head_scale_grp_trans = HUDnasal.main.head_scale_grp.createTransform();
    HUDnasal.main.head_scale = HUDnasal.main.head_scale_grp.createChild("path")
        .moveTo(-headScaleTickSpacing*2, 0)
        .vert(-60)
        .moveTo(0, 0)
        .vert(-60)
        .moveTo(headScaleTickSpacing*2, 0)
        .vert(-60)
        .moveTo(-headScaleTickSpacing, 0)
        .vert(-40)
        .moveTo(headScaleTickSpacing, 0)
        .vert(-40)
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
    .moveTo( 0,  10)
    .lineTo( 0,  55)
    .moveTo( 15, 55)
    .lineTo( 15, 25)
    .moveTo(-15, 55)
    .lineTo(-15, 25);

    # scale heading end ticks
    HUDnasal.main.hdgLineL = HUDnasal.main.head_scale_grp.createChild("path")
    .setStrokeLineWidth(w)
      .setColor(r,g,b, a)
      .moveTo(-headScaleTickSpacing*3, 0)
      .vert(-40)
      .close();

    HUDnasal.main.hdgLineR = HUDnasal.main.head_scale_grp.createChild("path")
    .setStrokeLineWidth(w)
      .setColor(r,g,b, a)
      .moveTo(headScaleTickSpacing*3, 0)
      .vert(-40)
      .close();

    # headingindicator
    HUDnasal.main.head_scale_indicator = HUDnasal.main.root.createChild("path")
    .setColor(r,g,b, a)
    .setStrokeLineCap("round")
    .setStrokeLineWidth(w)
    .moveTo(-30, -headScalePlace+30)
    .lineTo(0, -headScalePlace)
    .lineTo(30, -headScalePlace+30);

    # Heading middle number
    HUDnasal.main.hdgM = HUDnasal.main.head_scale_grp.createChild("text");
    HUDnasal.main.hdgM.setColor(r,g,b, a);
    HUDnasal.main.hdgM.setAlignment("center-bottom");
    HUDnasal.main.hdgM.setFontSize(65*fs, ar);

    # Heading left number
    HUDnasal.main.hdgL = HUDnasal.main.head_scale_grp.createChild("text");
    HUDnasal.main.hdgL.setColor(r,g,b, a);
    HUDnasal.main.hdgL.setAlignment("center-bottom");
    HUDnasal.main.hdgL.setFontSize(65*fs, ar);

    # Heading right number
    HUDnasal.main.hdgR = HUDnasal.main.head_scale_grp.createChild("text");
    HUDnasal.main.hdgR.setColor(r,g,b, a);
    HUDnasal.main.hdgR.setAlignment("center-bottom");
    HUDnasal.main.hdgR.setFontSize(65*fs, ar);

    # Altitude
    HUDnasal.main.alt_scale_grp=HUDnasal.main.root.createChild("group")
      .set("clip", "rect(200px, 1800px, 824px, 0px)");#top,right,bottom,left
    HUDnasal.main.alt_scale_grp_trans = HUDnasal.main.alt_scale_grp.createTransform();

    # alt scale high
    HUDnasal.main.alt_scale_high=HUDnasal.main.alt_scale_grp.createChild("path")
      .moveTo(0, -6*altimeterScaleHeight/2)
      .horiz(75)
      .moveTo(0, -5*altimeterScaleHeight/2)
      .horiz(50)
      .moveTo(0, -2*altimeterScaleHeight)
      .horiz(75)
      .moveTo(0, -3*altimeterScaleHeight/2)
      .horiz(50)
      .moveTo(0, -altimeterScaleHeight)
      .horiz(75)
      .moveTo(0, -altimeterScaleHeight/2)
      .horiz(50)
      .moveTo(0, 0)
      .horiz(75)
      .setStrokeLineWidth(w)
      .setColor(r,g,b, a)
      .show();



    # alt scale medium
    HUDnasal.main.alt_scale_med=HUDnasal.main.alt_scale_grp.createChild("path")
      .moveTo(0, -5*altimeterScaleHeight/2)
      .horiz(50)
      .moveTo(0, -2*altimeterScaleHeight)
      .horiz(75)
      .moveTo(0, -3*altimeterScaleHeight/2)
      .horiz(50)
      .moveTo(0, -altimeterScaleHeight)
      .horiz(75)
      .moveTo(0, -4*altimeterScaleHeight/5)
      .horiz(25)
      .moveTo(0, -3*altimeterScaleHeight/5)
      .horiz(25)           
      .moveTo(0, -2*altimeterScaleHeight/5)
      .horiz(25)
      .moveTo(0, -1*altimeterScaleHeight/5)
      .horiz(25)           
      .moveTo(0, 0)
      .horiz(75)
      .setStrokeLineWidth(w)
      .setColor(r,g,b, a)
      .show();

    # alt scale low
    HUDnasal.main.alt_scale_low = HUDnasal.main.alt_scale_grp.createChild("path")
      .moveTo(0, -7*altimeterScaleHeight/4)
      .horiz(50)
      .moveTo(0, -6*altimeterScaleHeight/4)
      .horiz(75)
      .moveTo(0, -5*altimeterScaleHeight/4)
      .horiz(50)
      .moveTo(0, -altimeterScaleHeight)
      .horiz(75)
      .moveTo(0,-4*altimeterScaleHeight/5)
      .horiz(25)
      .moveTo(0, -3*altimeterScaleHeight/5)
      .horiz(25)
      .moveTo(0, -2*altimeterScaleHeight/5)
      .horiz(25)           
      .moveTo(0,-1*altimeterScaleHeight/5)
      .horiz(25)
      .moveTo(0, 0)
      .horiz(75)
      .setStrokeLineWidth(w)
      .setColor(r,g,b, a)
      .show();


      
    # vert line at zero alt if it is lower than radar zero
      HUDnasal.main.alt_scale_line = HUDnasal.main.alt_scale_grp.createChild("path")
      .moveTo(0, 30)
      .vert(-60)
      .setStrokeLineWidth(w)
      .setColor(r,g,b, a);
    # low alt number
    HUDnasal.main.alt_low = HUDnasal.main.alt_scale_grp.createChild("text")
      .setText(".")
      .setFontSize(75*fs, ar)
      .setColor(r,g,b, a)
      .setAlignment("left-center")
      .setTranslation(1, 0);
    # middle alt number 
    HUDnasal.main.alt_med = HUDnasal.main.alt_scale_grp.createChild("text")
      .setText(".")
      .setFontSize(75*fs, ar)
      .setColor(r,g,b, a)
      .setAlignment("left-center")
      .setTranslation(1, 0);
    # high alt number      
    HUDnasal.main.alt_high = HUDnasal.main.alt_scale_grp.createChild("text")
      .setText(".")
      .setFontSize(75*fs, ar)
      .setColor(r,g,b, a)
      .setAlignment("left-center")
      .setTranslation(1, 0);

    # higher alt number     
    HUDnasal.main.alt_higher = HUDnasal.main.alt_scale_grp.createChild("text")
      .setText(".")
      .setFontSize(75*fs, ar)
      .setColor(r,g,b, a)
      .setAlignment("left-center")
      .setTranslation(1, 0);
    # alt scale indicator
    HUDnasal.main.alt_pointer = HUDnasal.main.root.createChild("path")
      .setColor(r,g,b, a)
      .setStrokeLineCap("round")
      .setStrokeLineWidth(w)
      .moveTo(0,0)
      .lineTo(-45,-45)
      .moveTo(0,0)
      .lineTo(-45, 45)
      .setTranslation(scalePlace+indicatorOffset, 0);
    # alt scale radar ground indicator
    HUDnasal.main.rad_alt_pointer = HUDnasal.main.alt_scale_grp.createChild("path")
      .setColor(r,g,b, a)
      .setStrokeLineCap("round")
      .setStrokeLineWidth(w)
      .moveTo(0,0)
      .lineTo(-60,0)
      .moveTo(0,0)
      .lineTo(-30,50)
      .moveTo(-30,0)
      .lineTo(-60,50);
    
    # QFE warning (inhg not properly set / is being adjusted)
    HUDnasal.main.qfe = HUDnasal.main.root.createChild("text");
    HUDnasal.main.qfe.setText("QFE");
    HUDnasal.main.qfe.hide();
    HUDnasal.main.qfe.setColor(r,g,b, a);
    HUDnasal.main.qfe.setAlignment("center-center");
    HUDnasal.main.qfe.setTranslation(-365, centerOffset+(5.5*pixelPerDegreeY));
    HUDnasal.main.qfe.setFontSize(80*fs, ar);

    # Altitude number (Not shown in landing/takeoff mode. Radar at less than 100 feet)
    HUDnasal.main.alt = HUDnasal.main.root.createChild("text");
    HUDnasal.main.alt.setColor(r,g,b, a);
    HUDnasal.main.alt.setAlignment("center-center");
    HUDnasal.main.alt.setTranslation(-375, centerOffset+(7.5*pixelPerDegreeY));
    HUDnasal.main.alt.setFontSize(85*fs, ar);

    # Collision warning arrow
    HUDnasal.main.arrow_group = HUDnasal.main.root.createChild("group");  
    HUDnasal.main.arrow_trans   = HUDnasal.main.arrow_group.createTransform();
    HUDnasal.main.arrow =
      HUDnasal.main.arrow_group.createChild("path")
      .setColor(r,g,b, a)
      .moveTo(-15,  90)
      .lineTo(-15, -90)
      .lineTo(-30, -90)
      .lineTo(  0, -120)
      .lineTo( 30, -90)
      .lineTo( 15, -90)
      .lineTo( 15,  90)
      .setStrokeLineCap("round")
      .setStrokeLineWidth(w);

    # Cannon aiming reticle
    HUDnasal.main.reticle_cannon =
      HUDnasal.main.root.createChild("path")
      .setColor(r,g,b, a)
      .moveTo(-15*reticle_factor, 0)
      .lineTo(15*reticle_factor, 0)
      .moveTo(0, -15*reticle_factor)
      .lineTo(0,  15*reticle_factor)
      .setStrokeLineCap("round")
      .setStrokeLineWidth(w);
    # Missile aiming circle
    HUDnasal.main.reticle_missile =
      HUDnasal.main.root.createChild("path")
      .setColor(r,g,b, a)
      .moveTo( 200, centerOffset)
      .arcSmallCW(200,200, 0, -400, 0)
      .arcSmallCW(200,200, 0,  400, 0)
      .setStrokeLineCap("round")
      .setStrokeLineWidth(w);      
    # Out of ammo flight path indicator
    HUDnasal.main.reticle_no_ammo =
      HUDnasal.main.root.createChild("path")
      .setColor(r,g,b, a)
      .moveTo(-45*reticle_factor, 0) # draw this symbol in flight when no weapons selected (always as for now)
      .lineTo(-15*reticle_factor, 0)
      .lineTo(0, 15*reticle_factor)
      .lineTo(15*reticle_factor, 0)
      .lineTo(45*reticle_factor, 0)
      .setStrokeLineCap("round")
      .setStrokeLineWidth(w);
    # sidewind symbol
    HUDnasal.main.takeoff_symbol = HUDnasal.main.root.createChild("path")
      .moveTo(105*sidewind_factor, 0)
      .lineTo(75*sidewind_factor, 0)
      .moveTo(45*sidewind_factor, 0)
      .lineTo(15*sidewind_factor, 0)
      .arcSmallCCW(15*sidewind_factor, 15*sidewind_factor, 0, -30*sidewind_factor, 0)
      .arcSmallCCW(15*sidewind_factor, 15*sidewind_factor, 0,  30*sidewind_factor, 0)
      .close()
      .moveTo(-15*sidewind_factor, 0)
      .lineTo(-45*sidewind_factor, 0)
      .moveTo(-75*sidewind_factor, 0)
      .lineTo(-105*sidewind_factor, 0)
      .setStrokeLineWidth(w)
      .setStrokeLineCap("round")
      .setColor(r,g,b, a);
    #flight path indicator
    HUDnasal.main.reticle_group = HUDnasal.main.root.createChild("group");  
    HUDnasal.main.aim_reticle  = HUDnasal.main.reticle_group.createChild("path")
      .moveTo(45*reticle_factor, 0)
      .lineTo(15*reticle_factor, 0)
      .arcSmallCCW(15*reticle_factor, 15*reticle_factor, 0, -30*reticle_factor, 0)
      .arcSmallCCW(15*reticle_factor, 15*reticle_factor, 0,  30*reticle_factor, 0)
      .close()
      .moveTo(-15*reticle_factor, 0)
      .lineTo(-45*reticle_factor, 0)
      .setStrokeLineWidth(w)
      .setStrokeLineCap("round")
      .setColor(r,g,b, a);
    HUDnasal.main.reticle_fin_group = HUDnasal.main.reticle_group.createChild("group");  
    HUDnasal.main.aim_reticle_fin  = HUDnasal.main.reticle_fin_group.createChild("path")
      .moveTo(0, -15*reticle_factor)
      .lineTo(0, -30*reticle_factor)
      .setStrokeLineWidth(w)
      .setStrokeLineCap("round")
      .setColor(r,g,b, a);

    #turn coordinator
    HUDnasal.main.turn_group = HUDnasal.main.root.createChild("group").setTranslation(sideslipPlaceX, sideslipPlaceY);
    HUDnasal.main.turn_group2 = HUDnasal.main.turn_group.createChild("group");
    HUDnasal.main.t_rot   = HUDnasal.main.turn_group2.createTransform();
    HUDnasal.main.turn_indicator = HUDnasal.main.turn_group2.createChild("path")
         .moveTo(-20, 0)
         .horiz(-150)
         .moveTo(20, 0)
         .horiz(150)
         .moveTo(-20, 0)
         .vert(20)
         .moveTo(20, 0)
         .vert(20)     
         .setStrokeLineWidth(w)
         .setColor(r,g,b, a);
    HUDnasal.main.turn_group3 = HUDnasal.main.turn_group2.createChild("group");
    HUDnasal.main.slip_indicator = HUDnasal.main.turn_group3.createChild("path")
         .moveTo(-8, -26)
         .horiz(16)
         .vert(16)
         .horiz(-16)
         .vert(-16)
         .setColorFill(r,g,b, a)
         .setStrokeLineWidth(w)
         .setColor(r,g,b, a);


    # Horizon
    HUDnasal.main.horizon_group = HUDnasal.main.root.createChild("group");
    HUDnasal.main.horizon_group.set("clip", "rect(0px, 712px, 1024px, 0px)");#top,right,bottom,left (absolute in canvas)
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
                     .moveTo(200, -i * distance)
                     .horiz(50)
                     .moveTo(300, -i * distance)
                     .horiz(50)
                     .moveTo(400, -i * distance)
                     .horiz(50)
                     .moveTo(500, -i * distance)
                     .horiz(50)
                     .moveTo(600, -i * distance)
                     .horiz(50)
                     .moveTo(700, -i * distance)
                     .horiz(50)

                     .moveTo(-200, -i * distance)
                     .horiz(-50)
                     .moveTo(-300, -i * distance)
                     .horiz(-50)
                     .moveTo(-400, -i * distance)
                     .horiz(-50)
                     .moveTo(-500, -i * distance)
                     .horiz(-50)
                     .moveTo(-600, -i * distance)
                     .horiz(-50)
                     .moveTo(-700, -i * distance)
                     .horiz(-50)
                     
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a));
    }

    for(var i = 1; i <= 18; i += 1) # full drawn lines
      append(artifacts1, HUDnasal.main.horizon_group2.createChild("path")
         .moveTo(750, -i * distance)
         .horiz(-550)

         .moveTo(-750, -i * distance)
         .horiz(550)
         
         .setStrokeLineWidth(w)
         .setColor(r,g,b, a));

    for(var i = -18; i <= 18; i += 1) { # small vertical lines in combat mode
      append(artifacts1, HUDnasal.main.horizon_group3.createChild("path")
         .moveTo(-200, -i * distance)
         .vert(25)

         .moveTo(200, -i * distance)
         .vert(25)
         
         .setStrokeLineWidth(w)
         .setColor(r,g,b, a));
    }

    #pitch line numbers
    for(var i = -18; i <= 0; i += 1)
      append(artifactsText1, HUDnasal.main.horizon_group4.createChild("text")
         .setText(i*5)
         .setFontSize(75*fs, ar)
         .setAlignment("right-bottom")
         .setTranslation(-200, -i * distance - 5)
         .setColor(r,g,b, a));
    for(var i = 1; i <= 18; i += 1)
      append(artifactsText1, HUDnasal.main.horizon_group2.createChild("text")
         .setText("+" ~ i*5)
         .setFontSize(75*fs, ar)
         .setAlignment("right-bottom")
         .setTranslation(-200, -i * distance - 5)
         .setColor(r,g,b, a));
                 
 
    #Horizon line
    HUDnasal.main.horizon_line = HUDnasal.main.horizon_group2.createChild("path")
                     .moveTo(-850, 0)
                     .horiz(650)
                     .moveTo(200, 0)
                     .horiz(650)
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a);

    HUDnasal.main.horizon_line_gap = HUDnasal.main.horizon_group2.createChild("path")
                     .moveTo(-200, 0)
                     .horiz(400)
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a);

    # heading scale on horizon line
    HUDnasal.main.head_scale_horz_grp = HUDnasal.main.horizon_group2.createChild("group");
    HUDnasal.main.head_scale_horz_ticks = HUDnasal.main.head_scale_horz_grp.createChild("path")
                      .moveTo(0, 0)
                      .vert(-30)
                      .moveTo(10*pixelPerDegreeX, 0)
                      .vert(-30)
                      .moveTo(-10*pixelPerDegreeX, 0)
                      .vert(-30)
                      .setStrokeLineWidth(w)
                      .setColor(r,g,b, a);
    # Heading middle number on horizon line
    HUDnasal.main.hdgMH = HUDnasal.main.head_scale_horz_grp.createChild("text")
                      .setColor(r,g,b, a)
                      .setAlignment("center-bottom")
                      .setFontSize(65*fs, ar);
    # Heading left number on horizon line
    HUDnasal.main.hdgLH = HUDnasal.main.head_scale_horz_grp.createChild("text")
                      .setColor(r,g,b, a)
                      .setAlignment("center-bottom")
                      .setFontSize(65*fs, ar);
    # Heading right number on horizon line
    HUDnasal.main.hdgRH = HUDnasal.main.head_scale_horz_grp.createChild("text")
                      .setColor(r,g,b, a)
                      .setAlignment("center-bottom")
                      .setFontSize(65*fs, ar);
    #heading bug on horizon
    HUDnasal.main.heading_bug_horz_group = HUDnasal.main.horizon_group2.createChild("group");
    HUDnasal.main.heading_bug_horz = HUDnasal.main.heading_bug_horz_group.createChild("path")
                      .setColor(r,g,b, a)
                      .setStrokeLineCap("round")
                      .setStrokeLineWidth(w)
                      .moveTo( 0,  10)
                      .lineTo( 0,  55)
                      .moveTo( 15, 55)
                      .lineTo( 15, 25)
                      .moveTo(-15, 55)
                      .lineTo(-15, 25);                      


    HUDnasal.main.desired_lines3 = HUDnasal.main.desired_lines_group.createChild("path")
                     .moveTo(-200 + w/2, 0)
                     .vert(5*pixelPerDegreeY)
                     .moveTo(200 - w/2, 0)
                     .vert(5*pixelPerDegreeY)
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a);

    HUDnasal.main.landing_line = HUDnasal.main.horizon_group2.createChild("path")
                     .moveTo(-200, pixelPerDegreeY*2.86)
                     .horiz(160)
                     .moveTo(40, pixelPerDegreeY*2.86)
                     .horiz(160)
                     .moveTo(0, pixelPerDegreeY*2.86)
                     .arcSmallCW(4, 4, 0, -8, 0)
                     .arcSmallCW(4, 4, 0,  8, 0)
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a);                     

    HUDnasal.main.desired_lines2 = HUDnasal.main.desired_lines_group.createChild("path")
                     .moveTo(-140 + w/2, 0)
                     .vert(3*pixelPerDegreeY)
                     .moveTo(140 - w/2, 0)
                     .vert(3*pixelPerDegreeY)
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a);                     

    HUDnasal.main.horizon_dots = HUDnasal.main.horizon_group2.createChild("path")
                     .moveTo(-37, 0)#-35
                     .arcSmallCW(2, 2, 0, -4, 0)
                     .arcSmallCW(2, 2, 0, 4, 0)
                     .moveTo(-107, 0)#-105
                     .arcSmallCW(2, 2, 0, -4, 0)
                     .arcSmallCW(2, 2, 0, 4, 0)
                     .moveTo(-177, 0)#-175
                     .arcSmallCW(2, 2, 0, -4, 0)
                     .arcSmallCW(2, 2, 0, 4, 0)
                     .moveTo(177, 0)#175
                     .arcSmallCW(2, 2, 0, -4, 0)
                     .arcSmallCW(2, 2, 0, 4, 0)
                     .moveTo(107, 0)#105
                     .arcSmallCW(2, 2, 0, -4, 0)
                     .arcSmallCW(2, 2, 0, 4, 0)
                     .moveTo(37, 0)#35
                     .arcSmallCW(2, 2, 0, -4, 0)
                     .arcSmallCW(2, 2, 0, 4, 0)
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
                           .moveTo(-70,   0)
                           .lineTo(  0, -70)
                           .lineTo( 70,   0)
                           .lineTo(  0,  70)
                           .lineTo(-70,   0)
                           .setStrokeLineWidth(w)
                           .setColor(r,g,b, a);
    HUDnasal.main.target = HUDnasal.main.diamond_group.createChild("path")
                           .moveTo(-50,   0)
                           .lineTo(-50, -50)
                           .lineTo( 50, -50)
                           .lineTo( 50,   0)
                           .setStrokeLineWidth(w)
                           .setColor(r,g,b, a);                           
    HUDnasal.main.diamond_dist = HUDnasal.main.diamond_group.createChild("text");
    HUDnasal.main.diamond_dist.setText("..");
    HUDnasal.main.diamond_dist.setColor(r,g,b, a);
    HUDnasal.main.diamond_dist.setAlignment("left-top");
    HUDnasal.main.diamond_dist.setTranslation(40, 55);
    HUDnasal.main.diamond_dist.setFontSize(60*fs, ar);
    HUDnasal.main.diamond_name = HUDnasal.main.diamond_group.createChild("text");
    HUDnasal.main.diamond_name.setText("..");
    HUDnasal.main.diamond_name.setColor(r,g,b, a);
    HUDnasal.main.diamond_name.setAlignment("left-bottom");
    HUDnasal.main.diamond_name.setTranslation(40, -55);
    HUDnasal.main.diamond_name.setFontSize(60*fs, ar);


    HUDnasal.main.vel_vec_trans_group = HUDnasal.main.radar_group.createChild("group");
    HUDnasal.main.vel_vec_rot_group = HUDnasal.main.vel_vec_trans_group.createChild("group");
    #HUDnasal.main.vel_vec_rot = HUDnasal.main.vel_vec_rot_group.createTransform();
    HUDnasal.main.vel_vec = me.vel_vec_rot_group.createChild("path")
                                  .moveTo(0, 0)
                                  .lineTo(0,-1)
                                  .setStrokeLineWidth(w)
                                  .setColor(r,g,b, a);

    #tower symbol
    HUDnasal.main.tower_symbol = HUDnasal.main.root.createChild("group");
    HUDnasal.main.tower_symbol.createTransform();
    var tower = HUDnasal.main.tower_symbol.createChild("path")
                           .moveTo(-20,   0)
                           .lineTo(  0, -20)
                           .lineTo( 20,   0)
                           .lineTo(  0,  20)
                           .lineTo(-20,   0)
                           .setStrokeLineWidth(w)
                           .setColor(r,g,b, a);
    HUDnasal.main.tower_symbol_dist = HUDnasal.main.tower_symbol.createChild("text");
    HUDnasal.main.tower_symbol_dist.setText("..");
    HUDnasal.main.tower_symbol_dist.setColor(r,g,b, a);
    HUDnasal.main.tower_symbol_dist.setAlignment("left-top");
    HUDnasal.main.tower_symbol_dist.setTranslation(12, 12);
    HUDnasal.main.tower_symbol_dist.setFontSize(60*fs, ar);

    HUDnasal.main.tower_symbol_icao = HUDnasal.main.tower_symbol.createChild("text");
    HUDnasal.main.tower_symbol_icao.setText("..");
    HUDnasal.main.tower_symbol_icao.setColor(r,g,b, a);
    HUDnasal.main.tower_symbol_icao.setAlignment("left-bottom");
    HUDnasal.main.tower_symbol_icao.setTranslation(12, -12);
    HUDnasal.main.tower_symbol_icao.setFontSize(60*fs, ar);

    #distance scale
    HUDnasal.main.dist_scale_group = HUDnasal.main.root.createChild("group").setTranslation(-100, 200);
    HUDnasal.main.mySpeed = HUDnasal.main.dist_scale_group.createChild("path")
                            .moveTo(   0,   0)
                            .lineTo( -10, -10)
                            .lineTo(   0, -20)
                            .lineTo(  10, -10)
                            .lineTo(   0,   0)
                            .setStrokeLineWidth(w)
                            .setColor(r,g,b, a);
    HUDnasal.main.targetSpeed = HUDnasal.main.dist_scale_group.createChild("path")
                            .moveTo(   0,   0)
                            .lineTo(   0,  20)
                            .moveTo( -10,  20)
                            .lineTo(  10,  20)
                            .setStrokeLineWidth(w)
                            .setColor(r,g,b, a);
    HUDnasal.main.targetDistance1 = HUDnasal.main.dist_scale_group.createChild("path")
                            .moveTo(   0,   0)
                            .lineTo(   0,  20)
                            .lineTo(  20,  20)
                            .moveTo( -30,  20)
                            .lineTo( -30,  50)
                            .lineTo(   0,  50)
                            .setStrokeLineWidth(w)
                            .setColor(r,g,b, a);
    HUDnasal.main.targetDistance2 = HUDnasal.main.dist_scale_group.createChild("path")
                            .moveTo(   0,   0)
                            .lineTo(   0,  20)
                            .lineTo( -20,  20)
                            .setStrokeLineWidth(w)
                            .setColor(r,g,b, a);
    HUDnasal.main.distanceText = HUDnasal.main.dist_scale_group.createChild("text")
                            .setText("")
                            .setColor(r,g,b, a)
                            .setAlignment("left-top")
                            .setTranslation(200, 10)
                            .setFontSize(60*fs, ar);
    var distanceScale = HUDnasal.main.dist_scale_group.createChild("path")
                            .moveTo(   0, 0)
                            .lineTo( 200, 0)
                            .setStrokeLineWidth(w)
                            .setColor(r,g,b, a);

      #other targets
    HUDnasal.main.target_circle = [];
    HUDnasal.main.target_group = HUDnasal.main.radar_group.createChild("group");
    for(var i = 0; i < maxTracks; i += 1) {      
      target_circles = HUDnasal.main.target_group.createChild("path")
                           .moveTo(-50, 0)
                           .arcLargeCW(50, 50, 0,  100, 0)
                           #.arcLargeCW(50, 50, 0, -100, 0)
                           .setStrokeLineWidth(w)
                           .setColor(r,g,b, a);
      append(HUDnasal.main.target_circle, target_circles);
      append(artifacts1, target_circles);
    }

    artifacts0 = [HUDnasal.main.head_scale, HUDnasal.main.hdgLineL, HUDnasal.main.heading_bug, HUDnasal.main.vel_vec, HUDnasal.main.reticle_missile,
             HUDnasal.main.hdgLineR, HUDnasal.main.head_scale_indicator, HUDnasal.main.turn_indicator, HUDnasal.main.arrow, HUDnasal.main.head_scale_horz_ticks,
             HUDnasal.main.alt_scale_high, HUDnasal.main.alt_scale_med, HUDnasal.main.alt_scale_low, HUDnasal.main.slip_indicator,
             HUDnasal.main.alt_scale_line, HUDnasal.main.aim_reticle_fin, HUDnasal.main.reticle_cannon, HUDnasal.main.desired_lines2,
             HUDnasal.main.alt_pointer, HUDnasal.main.rad_alt_pointer, HUDnasal.main.target, HUDnasal.main.desired_lines3, HUDnasal.main.horizon_line_gap,
             HUDnasal.main.reticle_no_ammo, HUDnasal.main.takeoff_symbol, HUDnasal.main.horizon_line, HUDnasal.main.horizon_dots, HUDnasal.main.diamond,
             tower, HUDnasal.main.aim_reticle, HUDnasal.main.targetSpeed, HUDnasal.main.mySpeed, distanceScale, HUDnasal.main.targetDistance1,
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
          'character-size': 100,
        },
        place: placement
      };
      HUDnasal.main.verbose = 0;
      HUDnasal.main.input = {
        pitch:            "/orientation/pitch-deg",
        roll:             "/orientation/roll-deg",
        #     hdg:      "/instrumentation/magnetic-compass/indicated-heading-deg",
        #      hdg:      "/instrumentation/gps/indicated-track-magnetic-deg",
        hdg:              "/orientation/heading-magnetic-deg",
        hdgReal:          "/orientation/heading-deg",
        speed_n:          "velocities/speed-north-fps",
        speed_e:          "velocities/speed-east-fps",
        speed_d:          "velocities/speed-down-fps",
        alpha:            "/orientation/alpha-deg",
        alphaJSB:         "fdm/jsbsim/aero/alpha-deg",
        beta:             "/orientation/side-slip-deg",
        ias:              "instrumentation/airspeed-indicator/indicated-speed-kt",#"/velocities/airspeed-kt",
        mach:             "instrumentation/airspeed-indicator/indicated-mach",
        gs:               "/velocities/groundspeed-kt",
        vs:               "/velocities/vertical-speed-fps",
        rad_alt:          "position/altitude-agl-ft",#/instrumentation/radar-altimeter/radar-altitude-ft",
        alt_ft:           "/instrumentation/altimeter/indicated-altitude-ft",
        alt_ft_real:      "position/altitude-ft",
        wow0:             "/gear/gear[0]/wow",
        wow1:             "/gear/gear[1]/wow",
        wow2:             "/gear/gear[2]/wow",
        fdpitch:          "/autopilot/settings/fd-pitch-deg",
        fdroll:           "/autopilot/settings/fd-roll-deg",
        fdspeed:          "/autopilot/settings/target-speed-kt",
        mode:             "sim/ja37/hud/mode",
        currentMode:      "sim/ja37/hud/current-mode",
        service:          "/instrumentation/head-up-display/serviceable",
        radar_serv:       "instrumentation/radar/serviceable",
        units:            "sim/ja37/hud/units-metric",
        gearsPos:         "gear/gear/position-norm",
        combat:           "/sim/ja37/hud/combat",
        station:          "controls/armament/station-select",
        tenHz:            "sim/ja37/blink/ten-Hz/state",
        fiveHz:           "sim/ja37/blink/five-Hz/state",
        callsign:         "/sim/ja37/hud/callsign",
        elecDC:           "/systems/electrical/outputs/dc-voltage",
        elecAC:           "systems/electrical/outputs/ac-instr-voltage",
        altCalibrated:    "sim/ja37/avionics/altimeters-calibrated",
        carrierNear:      "fdm/jsbsim/ground/carrier-near",
        terrainOn:        "sim/ja37/sound/terrain-on",
        viewNumber:       "sim/current-view/view-number",
        viewZ:            "sim/current-view/y-offset-m",
        TILS:             "sim/ja37/hud/TILS",
        landingMode:      "sim/ja37/hud/landing-mode",
        tracks_enabled:   "sim/ja37/hud/tracks-enabled",
        final:            "sim/ja37/hud/final",
        elapsedSec:       "sim/time/elapsed-sec",
        cannonAmmo:       "ai/submodels/submodel[3]/count",
        nav0InRange:      "instrumentation/nav[0]/in-range",
        nav0Heading:      "instrumentation/nav[0]/heading-deg",
        nav0HeadingDefl:  "instrumentation/nav[0]/heading-needle-deflection",
        nav0HasGS:        "instrumentation/nav[0]/has-gs",
        nav0GSInRange:    "instrumentation/nav[0]/gs-in-range",
        nav0GSDirectDeg:  "instrumentation/nav[0]/gs-direct-deg",
        APLockHeading:    "autopilot/locks/heading",
        APHeadingBug:     "autopilot/settings/heading-bug-deg",
        APTrueHeadingErr: "autopilot/internal/true-heading-error-deg",
        APnav0HeadingErr: "autopilot/internal/nav1-heading-error-deg",
        RMActive:         "autopilot/route-manager/active",
        RMWaypointBearing:"autopilot/route-manager/wp/bearing-deg",
        APLockAlt:        "autopilot/locks/altitude",
        APTgtAlt:         "autopilot/settings/target-altitude-ft",
        APTgtAgl:         "autopilot/settings/target-agl-ft",
        RMCurrWaypoint:   "autopilot/route-manager/current-wp",
        towerAlt:         "sim/tower/altitude-ft",
        towerLat:         "sim/tower/latitude-deg",
        towerLon:         "sim/tower/longitude-deg",
        sideslipOn:       "sim/ja37/hud/bank-indicator",
        windHeading:      "environment/wind-from-heading-deg",
        windSpeed:        "environment/wind-speed-kt",        
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
    var has_power = TRUE;
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
        has_power = FALSE;
      }
    } elsif (on_backup_power == TRUE) {
      # was on backup, now is on primary
      reinit(FALSE);
      on_backup_power = FALSE;
    }
    
    if(has_power == FALSE or me.input.mode.getValue() == 0) {
      me.root.hide();
      me.root.update();
      settimer(func me.update(), 0.3);
     } elsif (me.input.service.getValue() == FALSE) {
      # The HUD has failed, due to the random failure system or crash, it will become frozen.
      # if it also later loses power, and the power comes back, the HUD will not reappear.
      settimer(func me.update(), 0.25);
     } else {
      # in case the user has adjusted the Z view position, we calculate the Y point in the HUD in line with pilots eyes.
      var fromTop = HUDTop - me.input.viewZ.getValue();
      centerOffset = -1 * (512 - (fromTop * pixelPerMeter));

      var takeoffForbidden = me.input.pitch.getValue() > 3 or me.input.mach.getValue() > 0.35 or me.input.gearsPos.getValue() != 1;

      if(mode != TAKEOFF and !takeoffForbidden and me.input.wow0.getValue() == TRUE and me.input.wow0.getValue() == TRUE and me.input.wow0.getValue() == TRUE) {
        mode = TAKEOFF;
        me.input.final.setValue(FALSE);
        modeTimeTakeoff = -1;
      } elsif (mode == TAKEOFF and modeTimeTakeoff == -1 and takeoffForbidden) {
        modeTimeTakeoff = me.input.elapsedSec.getValue();
        me.input.final.setValue(FALSE);
      } elsif (modeTimeTakeoff != -1 and me.input.elapsedSec.getValue() - modeTimeTakeoff > 3) {
        if (me.input.gearsPos.getValue() == 1 or me.input.landingMode.getValue() == TRUE) {
          mode = LANDING;
        } else {
          mode = me.input.combat.getValue() == 1 ? COMBAT : NAV;
          me.input.final.setValue(FALSE);
        }
        modeTimeTakeoff = -1;
      } elsif ((mode == COMBAT or mode == NAV) and (me.input.gearsPos.getValue() == 1 or me.input.landingMode.getValue() == TRUE)) {
        mode = LANDING;
        modeTimeTakeoff = -1;
      } elsif (mode == COMBAT or mode == NAV) {
        mode = me.input.combat.getValue() == 1 ? COMBAT : NAV;
        me.input.final.setValue(FALSE);
        modeTimeTakeoff = -1;
      } elsif (mode == LANDING and me.input.gearsPos.getValue() == 0 and me.input.landingMode.getValue() == FALSE) {
        mode = me.input.combat.getValue() == 1 ? COMBAT : NAV;
        me.input.final.setValue(FALSE);
        modeTimeTakeoff = -1;
      }
      me.input.currentMode.setValue(mode);

      # commented as long as diamond node is choosen in HUD
      #if (me.input.viewNumber.getValue() != 0 and me.input.viewNumber.getValue() != 13) {
        # in external view
      #  settimer(func me.update(), 0.03);
      #  return;
      #}

      var cannon = me.input.station.getValue() == 0 and me.input.combat.getValue() == TRUE;
      var out_of_ammo = FALSE;
      if (me.input.station.getValue() != 0 and getprop("payload/weight["~ (me.input.station.getValue()-1) ~"]/selected") == "none") {
            out_of_ammo = TRUE;
      } elsif (me.input.station.getValue() == 0 and me.input.cannonAmmo.getValue() == 0) {
            out_of_ammo = TRUE;
      } elsif (me.input.station.getValue() != 0 and getprop("payload/weight["~ (me.input.station.getValue()-1) ~"]/selected") == "M70" and getprop("ai/submodels/submodel["~(4+me.input.station.getValue())~"]/count") == 0) {
            out_of_ammo = TRUE;
      }

      # ground collision warning
      me.displayGroundCollisionArrow(mode);

      # digital speed
      me.displayDigitalSpeed();
            
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
      deflect = me.showReticle(mode, cannon, out_of_ammo);

      # Visual, TILS and ILS landing guide
      var guide = me.displayLandingGuide(mode, deflect);

      # desired alt lines
      me.displayDesiredAltitudeLines(guide);

      # distance scale
      me.showDistanceScale(mode);

      ### artificial horizon and pitch lines ###
      me.displayPitchLines(mode);

      ### turn coordinator ###
      me.displayTurnCoordinator();

      ####  Radar HUD tracks  ###
      me.displayRadarTracks(mode);

      # tower symbol
      me.displayTower();


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
      , 0.03, 0);
      #setprop("sim/hud/visibility[1]", 0);
    }#end of HUD running check
  },#end of update

  displayGroundCollisionArrow: func (mode) {
    var rad_alt = getprop("controls/altimeter-radar") == 1?me.input.rad_alt.getValue():nil;
    if (mode != TAKEOFF and ( (mode == LANDING and rad_alt != nil and rad_alt > (50/feet2meter)) or mode != LANDING )) {
      #var x = mp.getNode("position/global-x").getValue();# meters probably
      #var y = mp.getNode("position/global-y").getValue();
      #var z = mp.getNode("position/global-z").getValue();
      #var aircraftPos = geo.Coord.new().set_xyz(x, y, z);
      #var vel_gx = me.input.speed_n.getValue();#feet per second
      #var vel_gy = me.input.speed_e.getValue();
      var vel_gz = me.input.speed_d.getValue();

      #extend vector of ground elevations
      if(rad_alt != nil and vel_gz != nil) {
        var time_till_crash = rad_alt / vel_gz;

        # very simple ground detection.
        if(time_till_crash < 10 and time_till_crash > 0) {
          me.input.terrainOn.setValue(TRUE);
          if(me.input.tenHz.getValue() == TRUE) {
            me.arrow_trans.setRotation(- me.input.roll.getValue()*deg2rads);
            me.arrow.show();
          } else {
            me.arrow.hide();
          }
        } else {
          me.input.terrainOn.setValue(FALSE);
          me.arrow.hide();
        }
      } else {
        me.input.terrainOn.setValue(FALSE);
        me.arrow.hide();
      }
    } else {
      me.input.terrainOn.setValue(FALSE);
      me.arrow.hide();
    }
  },

  displayHeadingScale: func () {
    if (mode != LANDING or me.input.pitch.getValue() < -5 or me.input.pitch.getValue() > 7) {
      var heading = me.input.hdg.getValue();
      var headOffset = heading/10 - int (heading/10);
      var headScaleOffset = headOffset;
      var middleText = roundabout(me.input.hdg.getValue()/10);
      me.middleOffset = nil;
      if(middleText == 36) {
        middleText = 0;
      }
      var leftText = middleText == 0?35:middleText-1;
      var rightText = middleText == 35?0:middleText+1;
      if (headOffset > 0.5) {
        me.middleOffset = -(headScaleOffset-1)*headScaleTickSpacing*2;
        me.head_scale_grp_trans.setTranslation(me.middleOffset, -headScalePlace);
        me.head_scale_grp.update();
        me.hdgLineL.show();
        #me.hdgLineR.hide();
      } else {
        me.middleOffset = -headScaleOffset*headScaleTickSpacing*2;
        me.head_scale_grp_trans.setTranslation(me.middleOffset, -headScalePlace);
        me.head_scale_grp.update();
        me.hdgLineR.show();
        #me.hdgLineL.hide();
      }
      me.hdgR.setTranslation(headScaleTickSpacing*2, -65);
      me.hdgR.setText(sprintf("%02d", rightText));
      me.hdgM.setTranslation(0, -65);
      me.hdgM.setText(sprintf("%02d", middleText));
      me.hdgL.setTranslation(-headScaleTickSpacing*2, -65);
      me.hdgL.setText(sprintf("%02d", leftText));
      me.head_scale_grp.show();
      me.head_scale_indicator.show();
    } else {
      me.head_scale_grp.hide();
      me.head_scale_indicator.hide();
    }
  },

  displayHeadingHorizonScale: func () {
    if (mode == LANDING) {
      var heading = me.input.hdg.getValue();
      var headOffset = heading/10 - int (heading/10);
      var headScaleOffset = headOffset;
      var middleText = roundabout(me.input.hdg.getValue()/10);
      me.middleOffsetHorz = nil;
      if(middleText == 36) {
        middleText = 0;
      }
      var leftText = middleText == 0?35:middleText-1;
      var rightText = middleText == 35?0:middleText+1;
      if (headOffset > 0.5) {
        me.middleOffsetHorz = -(headScaleOffset-1)*10*pixelPerDegreeX;
        me.head_scale_horz_grp.setTranslation(me.middleOffsetHorz, 0);
        me.head_scale_horz_grp.update();
        #me.hdgLineL.show();
      } else {
        me.middleOffsetHorz = -headScaleOffset*10*pixelPerDegreeX;
        me.head_scale_horz_grp.setTranslation(me.middleOffsetHorz, 0);
        me.head_scale_horz_grp.update();
        #me.hdgLineR.show();
      }
      me.hdgRH.setTranslation(10*pixelPerDegreeX, -30);
      me.hdgRH.setText(sprintf("%02d", rightText));
      me.hdgMH.setTranslation(0, -30);
      me.hdgMH.setText(sprintf("%02d", middleText));
      me.hdgLH.setTranslation(-10*pixelPerDegreeX, -30);
      me.hdgLH.setText(sprintf("%02d", leftText));
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
    var desired_mag_heading = nil;
    if (mode == LANDING and me.input.nav0InRange.getValue() == TRUE) {
      desired_mag_heading = me.input.nav0Heading.getValue();
    } elsif (me.input.APLockHeading.getValue() == "dg-heading-hold") {
      desired_mag_heading = me.input.APHeadingBug.getValue();
    } elsif (me.input.APLockHeading.getValue() == "true-heading-hold") {
      desired_mag_heading = me.input.APTrueHeadingErr.getValue()+me.input.hdg.getValue();#getprop("autopilot/settings/true-heading-deg")+
    } elsif (me.input.APLockHeading.getValue() == "nav1-hold") {
      desired_mag_heading = me.input.APnav0HeadingErr.getValue()+me.input.hdg.getValue();
    } elsif( me.input.RMActive.getValue() == 1) {
      #var i = getprop("autopilot/route-manager/current-wp");
      desired_mag_heading = me.input.RMWaypointBearing.getValue();
    }
    if(desired_mag_heading != nil) {
      #print("desired "~desired_mag_heading);
      while(desired_mag_heading < 0) {
        desired_mag_heading += 360.0;
      }
      while(desired_mag_heading > 360) {
        desired_mag_heading -= 360.0;
      }
      var degOffset = nil;
      var headingMiddle = roundabout(me.input.hdg.getValue()/10.0)*10.0;
      #print("desired "~desired_mag_heading~" head-middle "~headingMiddle);

      #find difference between desired and middleText heading
      if (headingMiddle > desired_mag_heading) {
        if (headingMiddle - desired_mag_heading < 180) {
          # negative value
          degOffset = desired_mag_heading - headingMiddle;
        } else {
          # positive value
          headingMiddle = headingMiddle - 360;
          degOffset = desired_mag_heading - headingMiddle;
        }
      } else {
        if (desired_mag_heading - headingMiddle < 180) {
          # positive value
          degOffset = desired_mag_heading - headingMiddle;
        } else {
          # negative value
          desired_mag_heading = desired_mag_heading - 360;
          degOffset = desired_mag_heading - headingMiddle;
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
      
      var pos_x = me.middleOffset + degOffset*(headScaleTickSpacing/5);
      #print("bug offset deg "~degOffset~"bug offset pix "~pos_x);
      var blink = FALSE;
      #62px, 687px, 262px, 337px
      if (pos_x < 337-512) {
        blink = TRUE;
        pos_x = 337-512;
      } elsif (pos_x > 687-512) {
        blink = TRUE;
        pos_x = 687-512;
      }
      me.heading_bug_group.setTranslation(pos_x, -headScalePlace);
      if(mode != LANDING and (blink == FALSE or me.input.fiveHz.getValue() == TRUE)) {
        me.heading_bug.show();
      } else {
        me.heading_bug.hide();
      }
      if (mode == LANDING) {
        pos_x = me.middleOffsetHorz + degOffset*(pixelPerDegreeX);
        me.heading_bug_horz_group.setTranslation(pos_x, 0);
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
    var metric = me.input.units.getValue();
    var alt = metric == TRUE ? me.input.alt_ft.getValue() * feet2meter : me.input.alt_ft.getValue();
    var radAlt = getprop("controls/altimeter-radar") == 1?(metric == TRUE ? me.input.rad_alt.getValue() * feet2meter : me.input.rad_alt.getValue()):nil;

    me.displayAltitudeScale(alt, radAlt);
    me.displayDigitalAltitude(alt, radAlt);
  },

  displayAltitudeScale: func (alt, radAlt) {
    var metric = me.input.units.getValue();
    me.pixelPerFeet = nil;
    # determine which alt scale to use
    if(metric == 1) {
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
      var alt_scale_factor = metric == 1 ? 50 : 200;
      var offset = altimeterScaleHeight/alt_scale_factor * alt;#vertical placement of scale. Half-scale-height/alt-in-half-scale * alt
      if(me.verbose > 1) print("Alt offset = "~offset);
      me.alt_scale_grp_trans.setTranslation(scalePlace, offset);
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
      if(metric == TRUE) {
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
        var rad_offset = altimeterScaleHeight/alt_scale_factor * radAlt;
        me.rad_alt_pointer.setTranslation(indicatorOffset, rad_offset - offset);
        me.rad_alt_pointer.show();
        if ((-radPointerProxim) < rad_offset and rad_offset < radPointerProxim) {
          me.alt_pointer.hide();
        } else {
          me.alt_pointer.show();
        }
      } else {
        me.alt_pointer.show();
        me.rad_alt_pointer.hide();
      }
      me.alt_scale_grp.update();
      if(me.verbose > 2) print("alt " ~ sprintf("%3d", alt) ~ " radAlt:" ~ sprintf("%3d", radAlt) ~ " rad_offset:" ~ sprintf("%3d", rad_offset));
    } elsif (alt_scale_mode == 1) {
      var alt_scale_factor = metric == TRUE ? 100 : 400;
      me.alt_scale_med.show();
      me.alt_scale_high.hide();
      me.alt_scale_low.hide();
      me.alt_higher.hide();
      me.alt_high.show();
      me.alt_med.show();
      me.alt_low.show();
      var offset = 2*altimeterScaleHeight/alt_scale_factor * alt;#vertical placement of scale. Scale-height/alt-in-scale * alt
      if(me.verbose > 1) print("Alt offset = "~offset);
      me.alt_scale_grp_trans.setTranslation(scalePlace, offset);
      me.alt_low.setTranslation(numberOffset, 0);
      me.alt_med.setTranslation(numberOffset, -altimeterScaleHeight);
      me.alt_high.setTranslation(numberOffset, -altimeterScaleHeight*2);
      if(metric == TRUE) {
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
        var rad_offset = 2*altimeterScaleHeight/alt_scale_factor * radAlt;
        me.rad_alt_pointer.setTranslation(indicatorOffset, rad_offset - offset);
        me.rad_alt_pointer.show();
        if (radAlt < alt) {
          me.alt_scale_line.show();
        } else {
          me.alt_scale_line.hide();
        }
        if ((-radPointerProxim) < rad_offset and rad_offset < radPointerProxim) {
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
      var alt_scale_factor = metric == TRUE ? 200 : 1000;
      me.alt_scale_med.hide();
      me.alt_scale_high.show();
      me.alt_scale_low.hide();
      me.alt_scale_line.hide();
      me.alt_higher.show();
      me.alt_high.show();
      me.alt_med.show();
      me.alt_low.show();

      var fact = int(alt / (alt_scale_factor/2)) * (alt_scale_factor/2);
      var factor = alt - fact + (alt_scale_factor/2);
      var offset = 2*altimeterScaleHeight/alt_scale_factor * factor;#vertical placement of scale. Scale-height/alt-in-scale * alt

      if(me.verbose > 1) print("Alt offset = "~offset);
      me.alt_scale_grp_trans.setTranslation(scalePlace, offset);
      me.alt_low.setTranslation(numberOffset , 0);
      me.alt_med.setTranslation(numberOffset , -altimeterScaleHeight);
      me.alt_high.setTranslation(numberOffset , -2*altimeterScaleHeight);
      me.alt_higher.setTranslation(numberOffset , -3*altimeterScaleHeight);
      var low = fact - alt_scale_factor/2;
      if(low > 1000) {
        me.alt_low.setText(sprintf("%.1f", low/1000));
      } else {
        me.alt_low.setText(sprintf("%d", low));
      }
      var med = fact;
      if(med > 1000) {
        me.alt_med.setText(sprintf("%.1f", med/1000));
      } else {
        me.alt_med.setText(sprintf("%d", med));
      }
      var high = fact + alt_scale_factor/2;
      if(high > 1000) {
        me.alt_high.setText(sprintf("%.1f", high/1000));
      } else {
        me.alt_high.setText(sprintf("%d", high));
      }
      var higher = fact + alt_scale_factor;
      if(higher > 1000) {
        me.alt_higher.setText(sprintf("%.1f", higher/1000));
      } else {
        me.alt_higher.setText(sprintf("%d", higher));
      }
      if (radAlt != nil) {
        # Show radar altimeter ground height
        var rad_offset = 2*altimeterScaleHeight/alt_scale_factor * (radAlt);
        me.rad_alt_pointer.setTranslation(indicatorOffset, rad_offset - offset);
        me.rad_alt_pointer.show();
        if ((-radPointerProxim) < rad_offset and rad_offset < radPointerProxim) {
          me.alt_pointer.hide();
        } else {
          me.alt_pointer.show();
        }
      } else {
        me.alt_pointer.show();
        me.rad_alt_pointer.hide();
      }
      me.alt_scale_grp.update();
      #print("alt " ~ sprintf("%3d", alt) ~ " radAlt:" ~ sprintf("%3d", radAlt) ~ " rad_offset:" ~ sprintf("%3d", rad_offset));
    }
  },

  displayDigitalAltitude: func (alt, radAlt) {
    if (me.input.final.getValue() == TRUE) {
      me.alt.hide();
    } else {
      me.alt.show();
      # alt and radAlt is in current unit
      # determine max radar alt in current unit
      var radar_clamp = me.input.units.getValue() ==1 ? 100 : 100/feet2meter;
      var alt_diff = me.input.units.getValue() ==1 ? 7 : 7/feet2meter;
      if (radAlt == nil and getprop("controls/altimeter-radar") == 1) {
        # Radar alt instrument not initialized yet
        me.alt.setText("");
        countQFE = 0;
        QFEcalibrated = FALSE;
        me.input.altCalibrated.setValue(FALSE);
      } elsif (radAlt != nil and radAlt < radar_clamp) {
        # in radar alt range
        me.alt.setText("R " ~ sprintf("%3d", clamp(radAlt, 0, radar_clamp)));
        # check for QFE warning
        var diff = radAlt - alt;
        if (countQFE == 0 and (diff > alt_diff or diff < -alt_diff)) {
          #print("QFE warning " ~ countQFE);
          # is not calibrated, and is not blinking
          QFEcalibrated = FALSE;
          me.input.altCalibrated.setValue(FALSE);
          countQFE = 1;     
          #print("QFE not calibrated, and is not blinking");     
        } elsif (diff > -alt_diff and diff < alt_diff) {
            #is calibrated
          if (QFEcalibrated == FALSE and countQFE < 11) {
            # was not calibrated before, is now.
            #print("QFE was not calibrated before, is now. "~countQFE);
            countQFE = 11;
          }
          QFEcalibrated = TRUE;
          me.input.altCalibrated.setValue(TRUE);
        } elsif (QFEcalibrated == 1 and (diff > alt_diff or diff < -alt_diff)) {
          # was calibrated before, is not anymore.
          #print("QFE was calibrated before, is not anymore. "~countQFE);
          countQFE = 1;
          QFEcalibrated = FALSE;
          me.input.altCalibrated.setValue(FALSE);
        }
      } else {
        # is above height for checking for calibration
        countQFE = 0;
        #QFE = 0;
        QFEcalibrated = TRUE;
        me.input.altCalibrated.setValue(TRUE);
        #print("QFE not calibrated, and is not blinking");
        me.alt.setText(sprintf("%4d", clamp(alt, 0, 9999)));
      }
    }
  },

  displayDesiredAltitudeLines: func (guideUseLines) {
    if (guideUseLines == FALSE) {
      var desired_alt_delta_ft = nil;
      if(mode == TAKEOFF) {
        desired_alt_delta_ft = 1640-me.input.alt_ft.getValue();#500 meter
      } elsif (me.input.APLockAlt.getValue() == "altitude-hold") {
        desired_alt_delta_ft = me.input.APTgtAlt.getValue()-me.input.alt_ft.getValue();
      } elsif (me.input.APLockAlt.getValue() == "agl-hold") {
        desired_alt_delta_ft = me.input.APTgtAgl.getValue()-me.input.rad_alt.getValue();
      } elsif(me.input.RMActive.getValue() == 1) {
        var i = me.input.RMCurrWaypoint.getValue();
        var rt_alt = getprop("autopilot/route-manager/route/wp["~i~"]/altitude-ft");
        if(rt_alt != nil and rt_alt > 0) {
          desired_alt_delta_ft = rt_alt - me.input.alt_ft.getValue();
        }
      }# elsif (getprop("autopilot/locks/altitude") == "gs1-hold") {
      if(desired_alt_delta_ft != nil) {
        var pos_y = clamp(-desired_alt_delta_ft*me.pixelPerFeet, -2.5*pixelPerDegreeY, 2.5*pixelPerDegreeY);

        me.desired_lines3.setTranslation(0, pos_y);
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
    var guideUseLines = FALSE;
    if(mode == LANDING) {
      var deg = deflect;
      if (me.input.nav0InRange.getValue() == TRUE or me.input.TILS.getValue() == TRUE) {
        deg = me.input.nav0HeadingDefl.getValue()/2;# -10 to 10, divided by 2.

        if (me.input.nav0HasGS.getValue() == TRUE and me.input.nav0GSInRange.getValue() == TRUE) {
          var normDeviation = (clamp(me.input.nav0GSDirectDeg.getValue() - 2.86, -4, 4)/4);
          var dev3 = normDeviation * 5*pixelPerDegreeY+2.86*pixelPerDegreeY;
          var dev2 = normDeviation * 3*pixelPerDegreeY+2.86*pixelPerDegreeY;
          me.desired_lines3.setTranslation(pixelPerDegreeX*deg, dev3);
          me.desired_lines2.setTranslation(pixelPerDegreeX*deg, dev2);
          guideUseLines = TRUE;
        }
      }
      HUDnasal.main.landing_line.setTranslation(pixelPerDegreeX*deg, 0);
      HUDnasal.main.landing_line.show();
    } else {
      HUDnasal.main.landing_line.hide();
    }
    return guideUseLines;
  },

  displayDigitalSpeed: func () {
    var mach = me.input.mach.getValue();

    if(me.input.units.getValue() == TRUE) {
      me.airspeedInt.hide();
      if (mach >= 0.5) 
      {
        me.airspeed.setText(sprintf("%.2f", mach));
      } else {
        me.airspeed.setText(sprintf("%03d", me.input.ias.getValue() * kts2kmh));
      }
    } elsif (mode == LANDING or mode == TAKEOFF or mach < 0.5) {
      me.airspeedInt.hide();
      me.airspeed.setText(sprintf("KT%03d", me.input.ias.getValue()));
    } else {
      me.airspeedInt.setText(sprintf("KT%03d", me.input.ias.getValue()));
      me.airspeedInt.show();
      me.airspeed.setText(sprintf("M%.2f", mach));
    }

    if (me.input.final.getValue() == 1) {
      me.airspeed.setTranslation(0, airspeedPlaceFinal);
      me.airspeedInt.setTranslation(0, airspeedPlaceFinal - 70);
    } else {
      me.airspeed.setTranslation(0, airspeedPlace);
      me.airspeedInt.setTranslation(0, airspeedPlace - 70);
    }
  },

  displayPitchLines: func (mode) {
    me.horizon_group2.setTranslation(0, pixelPerDegreeY * me.input.pitch.getValue());
    me.horizon_group3.setTranslation(0, pixelPerDegreeY * me.input.pitch.getValue());
    me.horizon_group4.setTranslation(0, pixelPerDegreeY * me.input.pitch.getValue());
    me.horizon_group.setTranslation(0, centerOffset);
    var rot = -me.input.roll.getValue() * deg2rads;
    me.h_rot.setRotation(rot);
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
      #me.t_rot.setRotation(getprop("/orientation/roll-deg") * deg2rads * 0.5);
      me.slip_indicator.setTranslation(clamp(me.input.beta.getValue()*20, -150, 150), 0);
      if(me.input.final.getValue() == TRUE) {
        me.turn_group.setTranslation(sideslipPlaceXFinal, sideslipPlaceYFinal);
      } else {
        me.turn_group.setTranslation(sideslipPlaceX, sideslipPlaceY);
      }
      me.turn_group.show();
    } else {
      me.turn_group.hide();
    }
  },

  displayQFE: func (mode) {
    if (mode == LANDING and me.input.nav0InRange.getValue() == TRUE) {
      if (me.input.TILS.getValue() == TRUE) {
        if (getprop("instrumentation/dme/KDI572-574/nm") != "---" and getprop("instrumentation/dme/KDI572-574/nm") != "") {
          me.qfe.setText("TILS/DME");
        } else {
          me.qfe.setText("TILS");
        }
        me.qfe.show();
      } else {
        if (getprop("instrumentation/dme/KDI572-574/nm") != "---" and getprop("instrumentation/dme/KDI572-574/nm") != "") {
          me.qfe.setText("ILS/DME");
        } else {
          me.qfe.setText("ILS");
        }
        me.qfe.show();
      }
    } elsif ((mode == LANDING or mode == NAV) and getprop("instrumentation/dme/KDI572-574/nm") != "---" and getprop("instrumentation/dme/KDI572-574/nm") != "") {
      me.qfe.setText("DME");
      me.qfe.show();
    } elsif (mode == COMBAT) {
      var armSelect = me.input.station.getValue();
      if(armSelect == 0) {
        me.qfe.setText("KCA");
        me.qfe.show();
      } elsif(getprop("payload/weight["~ (armSelect-1) ~"]/selected") == "RB 24J") {
        me.qfe.setText("RB-24");
        me.qfe.show();
      } elsif(getprop("payload/weight["~ (armSelect-1) ~"]/selected") == "M70") {
        me.qfe.setText("M70");
        me.qfe.show();
      } else {
        me.qfe.hide();
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
        me.input.altCalibrated.setValue(TRUE);
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
      return me.showFlightPathVector(1, out_of_ammo);
    } elsif (mode == COMBAT and cannon == FALSE) {
      if(getprop("payload/weight["~ (me.input.station.getValue()-1) ~"]/selected") == "M70") {
        me.showSidewind(FALSE);
        me.reticle_cannon.show();
        me.reticle_missile.hide();
      } elsif(getprop("payload/weight["~ (me.input.station.getValue()-1) ~"]/selected") == "RB 24J") {
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.show();
      } else {
        me.showSidewind(FALSE);
        me.reticle_cannon.hide();
        me.reticle_missile.hide();
      }
      return me.showFlightPathVector(1, out_of_ammo);
    } elsif (mode != TAKEOFF and mode != LANDING) {# or me.input.wow_nlg.getValue() == 0
      # flight path vector (FPV)
      
      me.showSidewind(FALSE);
      me.reticle_cannon.hide();
      me.reticle_missile.hide();
      return me.showFlightPathVector(1, FALSE);
    } elsif(mode == TAKEOFF) {      
      me.showSidewind(TRUE);
      me.reticle_cannon.hide();
      me.reticle_missile.hide();
      return me.showFlightPathVector(!me.input.wow0.getValue(), FALSE);
    } elsif(mode == LANDING) {      
      me.showSidewind(FALSE);
      me.reticle_cannon.hide();
      me.reticle_missile.hide();
      return me.showFlightPathVector(!me.input.wow0.getValue(), FALSE);
    }
    return 0;
  },

  showSidewind: func(show) {
    if(show == TRUE) {
      #move sidewind symbol according to side wind:
      var wind_heading = me.input.windHeading.getValue();
      var wind_speed = me.input.windSpeed.getValue();
      var heading = me.input.hdgReal.getValue();
      #var speed = me.input.ias.getValue();
      var angle = (wind_heading -heading) * (math.pi / 180.0); 
      var wind_side = math.sin(angle) * wind_speed;
      #print((wind_heading -heading) ~ " " ~ wind_side);
      me.takeoff_symbol.setTranslation(clamp(-wind_side * sidewindPerKnot, -450, 450), sidewindPosition);
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

  showFlightPathVector: func (show, out_of_ammo) {
    if(show == TRUE) {
      var vel_gx = me.input.speed_n.getValue();
      var vel_gy = me.input.speed_e.getValue();
      var vel_gz = me.input.speed_d.getValue();
   
      var yaw = me.input.hdgReal.getValue() * deg2rads;
      var roll = me.input.roll.getValue() * deg2rads;
      var pitch = me.input.pitch.getValue() * deg2rads;
   
      var sy = math.sin(yaw);   var cy = math.cos(yaw);
      var sr = math.sin(roll);  var cr = math.cos(roll);
      var sp = math.sin(pitch); var cp = math.cos(pitch);
   
      var vel_bx = vel_gx * cy * cp
                 + vel_gy * sy * cp
                 + vel_gz * -sp;
      var vel_by = vel_gx * (cy * sp * sr - sy * cr)
                 + vel_gy * (sy * sp * sr + cy * cr)
                 + vel_gz * cp * sr;
      var vel_bz = vel_gx * (cy * sp * cr + sy * sr)
                 + vel_gy * (sy * sp * cr - cy * sr)
                 + vel_gz * cp * cr;
   
      var dir_y = math.atan2(round0(vel_bz), math.max(vel_bx, 0.001)) * rad2deg;
      var dir_x  = math.atan2(round0(vel_by), math.max(vel_bx, 0.001)) * rad2deg;
      
      var pos_x = clamp(dir_x * pixelPerDegreeX, -450, 450);
      var pos_y = clamp((dir_y * pixelPerDegreeY)+centerOffset, -450, 430);

      if ( out_of_ammo == TRUE) {
        me.aim_reticle.hide();
        me.aim_reticle_fin.hide();
        me.reticle_no_ammo.show();
        me.reticle_no_ammo.setTranslation(pos_x, pos_y);
      } else {
        me.reticle_no_ammo.hide();
        me.aim_reticle.show();
        
        me.reticle_group.setTranslation(pos_x, pos_y);
        # move fin to alpha
        me.reticle_fin_group.setTranslation(0, me.input.alphaJSB.getValue());
        if (me.input.alphaJSB.getValue() > 20) {
          # blink the fin if alpha is high
          if(me.input.tenHz.getValue() == TRUE) {
            me.aim_reticle_fin.show();
          } else {
            me.aim_reticle_fin.hide();
          }
        } else {
          me.aim_reticle_fin.show();
        }
      }    
      return dir_x;
    } else {
      me.aim_reticle_fin.hide();
      me.aim_reticle.hide();
      me.reticle_no_ammo.hide();
      return 0;
    }
  },

  showDistanceScale: func (mode) {
    if(mode == TAKEOFF) {
      var line = 200;
      var pixelPerKmh = (2/3*line)/250;
      if(me.input.ias.getValue() < 75/kts2kmh) {
        me.mySpeed.setTranslation(pixelPerKmh*75, 0);
      } else {
        var pos = pixelPerKmh*me.input.ias.getValue()*kts2kmh;
        if(pos > line) {
          pos = line;
        }
        me.mySpeed.setTranslation(pos, 0);
      }      
      me.targetSpeed.setTranslation(2/3*line, 0);
      me.targetSpeed.show();
      me.mySpeed.show();
      me.targetDistance1.hide();
      me.targetDistance2.hide();
      me.distanceText.hide();
      me.dist_scale_group.show();
    } elsif (mode == COMBAT and radar_logic.selection != nil) {
      var line = 200;
      var armSelect = me.input.station.getValue();
      var minDist = nil;
      var maxDist = nil;
      var currDist = radar_logic.selection[2];
      if(armSelect == 0) {
        # cannon
        minDist =  100;
        maxDist = 2500;# as per sources
      } elsif (getprop("payload/weight["~(armSelect-1)~"]/selected") == "RB 24J") {
        # sidewinders
        minDist =   300;
        maxDist = 18520;
      } elsif (getprop("payload/weight["~(armSelect-1)~"]/selected") == "M70") {
        # Rocket pod
        minDist =   200;
        maxDist =  2000;
      }
      if(currDist != nil and minDist != nil) {
        var pixelPerMeter = (3/5*line)/(maxDist - minDist);
        var startDist = (minDist - ((maxDist - minDist)/3));
        var pos = pixelPerMeter*(currDist-startDist);
        pos = clamp(pos, 0, line);
        me.mySpeed.setTranslation(pos, 0);
        me.mySpeed.show();
      } else {
        me.mySpeed.hide();
      }
      me.targetDistance1.setTranslation(1/5*line, 0);
      me.targetDistance2.setTranslation(4/5*line, 0);

      me.targetSpeed.hide();
      me.targetDistance1.show();
      me.targetDistance2.show();
      me.distanceText.hide();
      me.dist_scale_group.show();
    } elsif (getprop("instrumentation/dme/KDI572-574/nm") != "---" and getprop("instrumentation/dme/KDI572-574/nm") != "") {
      var distance = getprop("instrumentation/dme/indicated-distance-nm");
      var line = 200;
      var maxDist = 20;
      var pixelPerMeter = (line)/(maxDist);
      var pos = pixelPerMeter*distance;
      pos = clamp(pos, 0, line);
      me.mySpeed.setTranslation(pos, 0);
      me.mySpeed.show();

      me.targetDistance1.setTranslation(0, 0);
      me.distanceText.setText(sprintf("%.1f", me.input.units.getValue() == 1  ? distance*kts2kmh : distance));

      me.targetSpeed.hide();
      me.targetDistance1.show();
      me.targetDistance2.hide();
      me.distanceText.show();
      me.dist_scale_group.show();
    } else {
      me.dist_scale_group.hide();
    }
  },

  displayTower: func () {
    var towerAlt = me.input.towerAlt.getValue();
    var towerLat = me.input.towerLat.getValue();
    var towerLon = me.input.towerLon.getValue();
    if(mode != COMBAT and me.input.final.getValue() == FALSE and towerAlt != nil and towerLat != nil and towerLon != nil) {
      var towerPos = geo.Coord.new();
      towerPos.set_latlon(towerLat, towerLon, towerAlt);
      var showme = TRUE;

      var hud_pos = radar_logic.trackCalc(towerPos, 99000, FALSE);
      if(hud_pos != nil) {
        var distance = hud_pos[2];
        var pos_x = hud_pos[0];
        var pos_y = hud_pos[1];

        if(pos_x > 512) {
          showme = FALSE;
        }
        if(pos_x < -512) {
          showme = FALSE;
        }
        if(pos_y > 512) {
          showme = FALSE;
        }
        if(pos_y < -512) {
          showme = FALSE;
        }

        if(showme == TRUE) {
          me.tower_symbol.setTranslation(pos_x, pos_y);
          var tower_dist = me.input.units.getValue() ==1  ? distance : distance/kts2kmh;
          if(tower_dist < 10000) {
            me.tower_symbol_dist.setText(sprintf("%.1f", tower_dist/1000));
          } else {
            me.tower_symbol_dist.setText(sprintf("%02d", tower_dist/1000));
          }          
          me.tower_symbol_icao.setText(getprop("sim/tower/airport-id"));
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

  displayRadarTracks: func (mode) {
    me.track_index = 1;
    me.selection_updated = FALSE;

    if(me.input.tracks_enabled.getValue() == 1 and me.input.radar_serv.getValue() > 0) {
      me.radar_group.show();

      var selection = radar_logic.selection;

      # selection/hud_pos
      #
      # 0 - x position
      # 1 - y position
      # 2 - direct distance in meter
      # 3 - distance in radar screen plane
      # 4 - horizontal angle from aircraft in rad
      # 5 - identifier
      # 6 - node
      # 7 - carrier

      # do circles here
      foreach(hud_pos; radar_logic.tracks) {
        var pos_x = hud_pos[0];
        var pos_y = hud_pos[1];
        var distance = hud_pos[2];
        var showme = TRUE;
        
        if(pos_x > 512) {
          showme = FALSE;
        }
        if(pos_x < -512) {
          showme = FALSE;
        }
        if(pos_y > 512) {
          showme = FALSE;
        }
        if(pos_y < -512) {
          showme = FALSE;
        }

        var currentIndex = me.track_index;

        if(hud_pos == selection and hud_pos[0] != 90000) {
            me.selection_updated = TRUE;
            me.selection_index = 0;
            currentIndex = 0;
        }
        
        if(currentIndex > -1 and (showme == TRUE or currentIndex == 0)) {
          me.target_circle[currentIndex].setTranslation(pos_x, pos_y);
          me.target_circle[currentIndex].show();
          me.target_circle[currentIndex].update();  
          if(currentIndex != 0) {
            me.track_index += 1;
            if (me.track_index == maxTracks) {
              me.track_index = -1;
            }
          }
        }
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
      if(selection != nil and selection[6].getChild("valid").getValue() == TRUE and me.selection_updated == TRUE) {
        # selection is currently in forward looking radar view
        var blink = FALSE;

        var pos_x = selection[0];
        var pos_y = selection[1];

        if (pos_y != 0 and pos_x != 0 and (pos_x > 512 or pos_y > 512 or pos_x < -512 or pos_y < -462)) {
          # outside HUD view, we then use polar coordinates to find where on the border it should be displayed
          # notice we dont use the top 50 texels of the HUD, due to semi circles would become invisible.

          # TODO: the airplane axis should be uses as origin.
          var angle = math.atan2(-pos_y, pos_x) * rad2deg;
          
          if (angle > -45 and angle < 42.06) {
            # right side
            pos_x = 512;
            pos_y = -math.tan(angle*deg2rads) * 512;
          } elsif (angle > 137.94 or angle < -135) {
            # left side
            pos_x = -512;
            pos_y = math.tan(angle*deg2rads) * 512;
          } elsif (angle > 42.06 and angle < 137.94) {
            # top side
            pos_x = 1/math.tan(angle*deg2rads) * 462;
            pos_y = -462;
          } elsif (angle < -45 and angle > -135) {
            # bottom side
            pos_x = -1/math.tan(angle*deg2rads) * 512;
            pos_y = 512;
          }
        }

        if(pos_x >= 512) {#since radar logic run slower than HUD loop, this must be >= check to prevent erratic blinking since pos is being overwritten
          blink = TRUE;
          pos_x = 512;
        } elsif (pos_x <= -512) {
          blink = TRUE;
          pos_x = -512;
        }
        if(pos_y >= 512) {
          blink = TRUE;
          pos_y = 512;
        } elsif(pos_y <= -462) {
          blink = TRUE;
          pos_y = -462;
        }
        if(selection[7] == FALSE and mode == COMBAT) {
          #targetable
          diamond_node = selection[6];
          me.diamond_group.setTranslation(pos_x, pos_y);
          var diamond_dist = me.input.units.getValue() ==1  ? selection[2] : selection[2]/kts2kmh;
          
          if(diamond_dist < 10000) {
            me.diamond_dist.setText(sprintf("%.1f", diamond_dist/1000));
          } else {
            me.diamond_dist.setText(sprintf("%02d", diamond_dist/1000));
          }
          me.diamond_name.setText(selection[5]);
          me.target_circle[me.selection_index].hide();


          var armSelect = me.input.station.getValue();
          var diamond = 0;
          if(armament.AIM9.active[armSelect-1] != nil and armament.AIM9.active[armSelect-1].status == 1) {
            # lock
            var weak = armament.AIM9.active[armSelect-1].trackWeak;
            if (weak == TRUE) {
              diamond = 1;
            } else {
              diamond = 2;
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

          if (diamond > 0) {
            me.target.hide();

            if (blink == TRUE) {
              if((diamond == 1 and me.input.fiveHz.getValue() == TRUE) or (diamond == 2 and me.input.tenHz.getValue() == TRUE)) {
                me.diamond.show();
              } else {
                me.diamond.hide();
              }
            } else {
              if (diamond == 1 or me.input.tenHz.getValue() == TRUE) {
                me.diamond.show();
              } else {
                me.diamond.hide();
              }
            }

          } elsif (blink == FALSE or me.input.fiveHz.getValue() == TRUE) {
            me.target.show();
            me.diamond.hide();
          } else {
            me.target.hide();
            me.diamond.hide();
          }
          me.diamond_group.show();

        } else {
          #untargetable but selectable, like carriers and tankers, or planes in navigation mode
          diamond_node = nil;
          me.diamond_group.setTranslation(pos_x, pos_y);
          me.target_circle[me.selection_index].setTranslation(pos_x, pos_y);
          var diamond_dist = me.input.units.getValue() == TRUE  ? selection[2] : selection[2]/kts2kmh;
          if(diamond_dist < 10000) {
            me.diamond_dist.setText(sprintf("%.1f", diamond_dist/1000));
          } else {
            me.diamond_dist.setText(sprintf("%02d", diamond_dist/1000));
          }
          me.diamond_name.setText(selection[5]);
          
          if(blink == TRUE and me.input.fiveHz.getValue() == FALSE) {
            me.target_circle[me.selection_index].hide();
          } else {
            me.target_circle[me.selection_index].show();
          }
          me.diamond_group.show();
          me.diamond.hide();
          me.target.hide();
        }

        #velocity vector
        if(pos_x > -512 and pos_x < 512 and pos_y > -512 and pos_y < 512) {
          var tgtHeading = selection[6].getNode("orientation/true-heading-deg").getValue();
          var tgtSpeed = selection[6].getNode("velocities/true-airspeed-kt").getValue();
          var myHeading = me.input.hdgReal.getValue();
          var myRoll = me.input.roll.getValue();
          if (tgtHeading == nil or tgtSpeed == nil) {
            me.vel_vec.hide();
          } else {
            var relHeading = tgtHeading - myHeading - myRoll;
            
            relHeading -= 180;# this makes the line trail instead of lead
            relHeading = relHeading * deg2rads;

            me.vel_vec_trans_group.setTranslation(pos_x, pos_y);
            me.vel_vec_rot_group.setRotation(relHeading);
            me.vel_vec.setScale(1, tgtSpeed/4);
            
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
        diamond_node = nil;
        if(selection != nil) {
          selection[2] = nil;#no longer sure why I do this..
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
};#end of HUDnasal


var id = 0;

var reinitHUD = FALSE;
var hud_pilot = nil;
var init = func() {
  removelistener(id); # only call once
  if(getprop("sim/ja37/supported/hud") == TRUE) {
    hud_pilot = HUDnasal.new({"node": "hud", "texture": "hud.png"});
    #setprop("sim/hud/visibility[1]", 0);
    
    #print("HUD initialized.");
    hud_pilot.update();
  }
};

var init2 = setlistener("/sim/signals/reinit", func() {
  setprop("sim/hud/visibility[1]", 0);
}, 0, 0);

#setprop("/systems/electrical/battery", 0);
id = setlistener("sim/ja37/supported/initialized", init, 0, 0);

var reinit = func(backup = FALSE) {#mostly called to change HUD color
   #reinitHUD = 1;

   # if on backup power then amber will be the colour
   var red = backup == FALSE?r:1;
   var green = backup == FALSE?g:0.5;
   var blue = backup == FALSE?b:0;

   foreach(var item; artifacts0) {
    item.setColor(red, green, blue, a);
    item.setStrokeLineWidth(getprop("sim/ja37/hud/stroke-linewidth"));
   }

   foreach(var item; artifacts1) {
    item.setColor(red, green, blue, a);
    item.setStrokeLineWidth(getprop("sim/ja37/hud/stroke-linewidth"));
   }

   foreach(var item; artifactsText0) {
    item.setColor(red, green, blue, a);
   }

   foreach(var item; artifactsText1) {
    item.setColor(red, green, blue, a);
   }
   hud_pilot.slip_indicator.setColorFill(red, green, blue, a);
   
   if (backup == FALSE) {
     HUDnasal.main.canvas.setColorBackground(0.36, g, 0.3, 0.05);
   } else {
     HUDnasal.main.canvas.setColorBackground(red, green, 0.3, 0.05);
   }
  #print("HUD being reinitialized.");
};

var cycle_brightness = func () {
  if(getprop("sim/ja37/hud/mode") > 0) {
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
  if(getprop("sim/ja37/hud/mode") > 0) {
    ja37.click();
    var current = getprop("sim/ja37/hud/units-metric");
    if(current == TRUE) {
      setprop("sim/ja37/hud/units-metric", FALSE);
    } else {
      setprop("sim/ja37/hud/units-metric", TRUE);
    }
  } else {
    aircraft.HUD.cycle_type();
  }
};

var cycle_landingMode = func () {
    ja37.click();
    var current = getprop("sim/ja37/hud/landing-mode");
    if(current == TRUE) {
      setprop("sim/ja37/hud/landing-mode", FALSE);
    } else {
      setprop("sim/ja37/hud/landing-mode", TRUE);
    }
};

var toggle_combat = func () {
  if(getprop("sim/ja37/hud/mode") > 0) {
    ja37.click();
    var current = getprop("/sim/ja37/hud/combat");
    if(current == 1) {
      setprop("/sim/ja37/hud/combat", FALSE);
    } else {
      setprop("/sim/ja37/hud/combat", TRUE);
    }
  } else {
    aircraft.HUD.cycle_color();
  }
};

var toggleCallsign = func () {
  if(getprop("sim/ja37/hud/mode") > 0) {
    ja37.click();
    var current = getprop("/sim/ja37/hud/callsign");
    if(current == 1) {
      setprop("/sim/ja37/hud/callsign", FALSE);
    } else {
      setprop("/sim/ja37/hud/callsign", TRUE);
    }
  } else {
    aircraft.HUD.normal_type();
  }
};
