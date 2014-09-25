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



var TAKEOFF = 0;
var NAV = 1;
var COMBAT =2;

var FALSE = 0;
var TRUE = 1;

# -100 - 0 : not blinking
# 1 - 10   : blinking
# 11 - 125 : steady on
var countQFE = 0;
var QFEcalibrated = FALSE;# if the altimeters are calibrated

var HUDTop = 0.79; # position of top of HUD in meters
# HUD z is 0 to 0.25 and raised 0.54 up. Finally is 0.54m to 0.79m, height of HUD is 0.25m
var pixelPerMeter = 4096;
# Therefore each pixel is 0.25 / 1024 = 0.000244140625m or each meter is 4096 pixels.
var centerOffset = -143;#pilot eye position up from vertical center of HUD. (in line from pilots eyes)
# View is 0.70m so 0.79-0.70 = 0.09m down from top of HUD, since Y in HUD increases downwards we get pixels from top:
# 512 - (0.09 / 0.000244140625) = 143.36 pixels up from center. Since -y is upward, result is -143. (Per default)

var pixelPerDegreeY = 37; #vertical axis, view is tilted 10 degrees, zoom in on runway to check it hit the 10deg line
var pixelPerDegreeX = 37; #horizontal axis
#var slant = 35; #degrees the HUD is slanted away from the pilot.
var sidewindPosition = centerOffset+(2*pixelPerDegreeY); #should be 2 degrees under horizon.
var sidewindPerKnot = 450/30; # Max sidewind displayed is set at 30 kts. 450pixels is maximum is can move to the side.
var radPointerProxim = 60; #when alt indicater is too close to radar ground indicator, hide indicator
var scalePlace = 200; #horizontal placement of alt scales
var numberOffset = 100; #alt scale numbers horizontal offset from scale 
var indicatorOffset = -10; #alt scale indicators horizontal offset from scale (must be high, due to bug #1054 in canvas) 
var headScalePlace = 300; # vert placement of alt scale
var headScaleTickSpacing = 65;# horizontal spacing between ticks. Remember to adjust bounding box when changing.
var altimeterScaleHeight = 225; # the height of the low alt scale. Also used in the other scales as a reference height.
var reticle_factor = 1.5;# size of flight path indicator, aiming reticle, and out of fuel reticle
var sidewind_factor = 1.0;# size of sidewind indicator
var r = 0.0;
var g = 1.0;
var b = 0.0;#HUD colors
var a = 1.0;
var w = 4;  #line stroke width
var ar = 0.9;#font aspect ratio
var fs = 0.8;#font size factor
var artifacts0 = nil;
var artifacts1 = [];
var maxTracks = 16;# how many radar tracks can be shown at once in the HUD
var diamond_node = nil;
var selection = nil;
var tracks = [];
var tracks_index = -1;

var HUDnasal = {
  canvas_settings: {
    "name": "HUDnasal",
    "size": [2048, 2048],# width of texture to be replaced
    "view": [1024, 1024],# width of canvas
    "mipmapping": 1
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
    HUDnasal.main.canvas.setColorBackground(0.36, g, 0.3, 0.02);
    HUDnasal.main.root = HUDnasal.main.canvas.createGroup()
                .set("font", "LiberationFonts/LiberationMono-Regular.ttf");# If using default font, horizontal alignment is not accurate (bug #1054), also prettier char spacing. 
    
    #HUDnasal.main.root.setScale(math.sin(slant*deg2rads), 1);
    HUDnasal.main.root.setTranslation(512, 512);

    # digital airspeed kts/mach 
    HUDnasal.main.airspeed = HUDnasal.main.root.createChild("text")
      .setText("000")
      .setFontSize(100*fs, ar)
      .setColor(r,g,b, a)
      .setAlignment("center-center")
      .setTranslation(0 , 400);
    HUDnasal.main.airspeedInt = HUDnasal.main.root.createChild("text")
      .setText("000")
      .setFontSize(100*fs, ar)
      .setColor(r,g,b, a)
      .setAlignment("center-center")
      .setTranslation(0 , 315);


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
    HUDnasal.main.qfe.setTranslation(-375, 125);
    HUDnasal.main.qfe.setFontSize(80*fs, ar);

    # Altitude number (Not shown in landing/takeoff mode. Radar at less than 100 feet)
    HUDnasal.main.alt = HUDnasal.main.root.createChild("text");
    HUDnasal.main.alt.setColor(r,g,b, a);
    HUDnasal.main.alt.setAlignment("center-center");
    HUDnasal.main.alt.setTranslation(-375, 300);
    HUDnasal.main.alt.setFontSize(85*fs, ar);

    # Cannon aiming reticle
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
    HUDnasal.main.turn_group = HUDnasal.main.root.createChild("group").setTranslation(325, 425);
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
         .moveTo(-8, -20)
         .horiz(16)
         .setStrokeLineWidth(16)
         .setColor(r,g,b, a);


    # Horizon
    HUDnasal.main.horizon_group = HUDnasal.main.root.createChild("group");
    HUDnasal.main.horizon_group.set("clip", "rect(0px, 712px, 1024px, 0px)");#top,right,bottom,left (absolute in canvas)
    HUDnasal.main.horizon_group2 = HUDnasal.main.horizon_group.createChild("group");
    HUDnasal.main.desired_lines_group = HUDnasal.main.horizon_group2.createChild("group");
    HUDnasal.main.horizon_group3 = HUDnasal.main.horizon_group.createChild("group");
    HUDnasal.main.h_rot   = HUDnasal.main.horizon_group.createTransform();

  
    # pitch lines
    var distance = pixelPerDegreeY * 5;
    for(var i = -18; i <= -1; i += 1) {
      append(artifacts1, HUDnasal.main.horizon_group2.createChild("path")
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
                     
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a));
    }

    for(var i = 1; i <= 18; i += 1)
      append(artifacts1, HUDnasal.main.horizon_group2.createChild("path")
         .moveTo(650, -i * distance)
         .horiz(-450)

         .moveTo(-650, -i * distance)
         .horiz(450)
         
         .setStrokeLineWidth(w)
         .setColor(r,g,b, a));

    for(var i = -18; i <= 18; i += 1) {
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
      append(artifacts1, HUDnasal.main.horizon_group2.createChild("text")
         .setText(i*5)
         .setFontSize(75*fs, ar)
         .setAlignment("right-bottom")
         .setTranslation(-200, -i * distance - 5)
         .setColor(r,g,b, a));
    for(var i = 1; i <= 18; i += 1)
      append(artifacts1, HUDnasal.main.horizon_group2.createChild("text")
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

    HUDnasal.main.desired_lines = HUDnasal.main.desired_lines_group.createChild("path")
                     .moveTo(-200 + w/2, 0)
                     .vert(5*pixelPerDegreeY)
                     .moveTo(200 - w/2, 0)
                     .vert(5*pixelPerDegreeY)
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

      #other targets
    HUDnasal.main.target_circle = [];
    for(var i = 0; i < maxTracks; i += 1) {      
      var target_group = HUDnasal.main.radar_group.createChild("group");
      append(HUDnasal.main.target_circle, target_group);
      target_group.createTransform();
      target_circles = target_group.createChild("path")
                           .moveTo(-50, 0)
                           .arcLargeCW(50, 50, 0,  100, 0)
                           #.arcLargeCW(50, 50, 0, -100, 0)
                           .setStrokeLineWidth(w)
                           .setColor(r,g,b, a);
      append(artifacts1, target_circles);
    }

    artifacts0 = [HUDnasal.main.airspeedInt, HUDnasal.main.airspeed, HUDnasal.main.head_scale, HUDnasal.main.hdgLineL, HUDnasal.main.heading_bug, HUDnasal.main.vel_vec,
             HUDnasal.main.hdgLineR, HUDnasal.main.head_scale_indicator, HUDnasal.main.hdgM, HUDnasal.main.hdgL, HUDnasal.main.turn_indicator, HUDnasal.main.arrow,
             HUDnasal.main.hdgR, HUDnasal.main.alt_scale_high, HUDnasal.main.alt_scale_med, HUDnasal.main.alt_scale_low, HUDnasal.main.slip_indicator,
             HUDnasal.main.alt_scale_line, HUDnasal.main.alt_low, HUDnasal.main.alt_med, HUDnasal.main.alt_high, HUDnasal.main.aim_reticle_fin, HUDnasal.main.reticle_cannon,
             HUDnasal.main.alt_higher, HUDnasal.main.alt_pointer, HUDnasal.main.rad_alt_pointer, HUDnasal.main.qfe, HUDnasal.main.target, HUDnasal.main.desired_lines,
             HUDnasal.main.alt, HUDnasal.main.reticle_no_ammo, HUDnasal.main.takeoff_symbol, HUDnasal.main.horizon_line, HUDnasal.main.horizon_dots, HUDnasal.main.diamond,
             tower, HUDnasal.main.diamond_dist, HUDnasal.main.tower_symbol_dist, HUDnasal.main.tower_symbol_icao, HUDnasal.main.diamond_name, HUDnasal.main.aim_reticle];


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
        pitch:    "/orientation/pitch-deg",
        roll:     "/orientation/roll-deg",
        #     hdg:      "/instrumentation/magnetic-compass/indicated-heading-deg",
        #      hdg:      "/instrumentation/gps/indicated-track-magnetic-deg",
        hdg:      "/orientation/heading-magnetic-deg",
        hdgReal:  "/orientation/heading-deg",
        speed_n:  "velocities/speed-north-fps",
        speed_e:  "velocities/speed-east-fps",
        speed_d:  "velocities/speed-down-fps",
        alpha:    "/orientation/alpha-deg",
        alphaJSB: "fdm/jsbsim/aero/alpha-deg",
        beta:     "/orientation/side-slip-deg",
        ias:      "/velocities/airspeed-kt",
        mach:     "/velocities/mach",
        gs:       "/velocities/groundspeed-kt",
        vs:       "/velocities/vertical-speed-fps",
        rad_alt:  "position/altitude-agl-ft",#/instrumentation/radar-altimeter/radar-altitude-ft",
        alt_ft:   "/instrumentation/altimeter/indicated-altitude-ft",
        alt_ft_real: "position/altitude-ft",
        wow_nlg:  "/gear/gear[0]/wow",
        #Vr:       "/controls/switches/HUDnasal_rotation_speed",
        #Bright:   "/controls/switches/HUDnasal_brightness",
        #Dir_sw:   "/controls/switches/HUDnasal_director", 
        #H_sw:     "/controls/switches/HUDnasal_height", 
        #Speed_sw: "/controls/switches/HUDnasal_speed", 
        #Test_sw:  "/controls/switches/HUDnasal_test",
        fdpitch:  "/autopilot/settings/fd-pitch-deg",
        fdroll:   "/autopilot/settings/fd-roll-deg",
        fdspeed:  "/autopilot/settings/target-speed-kt",
        mode:     "sim/ja37/hud/mode",
        service:  "/instrumentation/head-up-display/serviceable",
        units:    "sim/ja37/hud/units-metric",
        gears:    "gear/gear/position-norm",
        combat:   "/sim/ja37/hud/combat",
        station:  "controls/armament/station-select",
        tenHz:    "sim/ja37/blink/ten-Hz/state",
        fiveHz:   "sim/ja37/blink/five-Hz/state",
        callsign: "/sim/ja37/hud/callsign",
        elec:     "/systems/electrical/outputs/hud",
        altCalibrated: "sim/ja37/avionics/altimeters-calibrated",
        carrierNear: "fdm/jsbsim/ground/carrier-near",
        terrainOn:   "sim/ja37/sound/terrain-on",
        viewNumber:  "sim/current-view/view-number",
        viewZ:       "sim/current-view/y-offset-m"
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
    if(me.input.elec.getValue() < 24 or me.input.mode.getValue() == 0) {
      me.root.hide();
      me.root.update();
      settimer(func me.update(), 0.5);
     } elsif (me.input.service.getValue() == FALSE) {
      # The HUD has failed, due to the random failure system or crash, it will become frozen.
      # if it also later loses power, and the power comes back, the HUD will not reappear.
      settimer(func me.update(), 1);
     } else {
      if(me.input.viewNumber.getValue() == 0) {
        # in case the user has adjusted the Z view position, we calculate the Y point in the HUD in line with pilots eyes.
        var fromTop = HUDTop - me.input.viewZ.getValue();
        centerOffset = -1 * (512 - (fromTop * pixelPerMeter));
      }
      var mode = me.input.gears.getValue() != 0 ? TAKEOFF : (me.input.combat.getValue() == 1 ? COMBAT : NAV);
      var cannon = me.input.station.getValue() == 0 and me.input.combat.getValue() == 1;
      var out_of_ammo = FALSE;
      if (me.input.combat.getValue() == 1 and me.input.station.getValue() != 0 and 
          getprop("payload/weight["~ (me.input.station.getValue()-1) ~"]/selected") == "none") {
            out_of_ammo = 1;
      }

      # ground collision warning
      me.displayGroundCollisionArrow(mode);

      # digital speed
      me.displayDigitalSpeed();
            
      # heading scale
      me.displayHeadingScale();

      #heading bug, must be after heading scale
      me.displayHeadingBug();

      # altitude. Digital and scale.
      me.displayAltitude();

      # desired alt lines
      me.displayDesiredAltitudeLines();

      ####   display QFE or weapon   ####
      me.displayQFE(mode);

      ####   reticle  ####
      me.showReticle(mode, cannon, out_of_ammo);

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
    var rad_alt = me.input.rad_alt.getValue();
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
      if(mode != TAKEOFF and time_till_crash < 10 and time_till_crash > 0) {
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
    }
  },

  displayHeadingScale: func () {
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
  },

  displayHeadingBug: func () {
    var desired_mag_heading = nil;
    if (getprop("autopilot/locks/heading") == "dg-heading-hold") {
      desired_mag_heading = getprop("autopilot/settings/heading-bug-deg");
    } elsif (getprop("autopilot/locks/heading") == "true-heading-hold") {
      desired_mag_heading = getprop("autopilot/internal/true-heading-error-deg")+me.input.hdg.getValue();#getprop("autopilot/settings/true-heading-deg")+
    } elsif (getprop("autopilot/locks/heading") == "nav1-hold") {
      desired_mag_heading = getprop("/autopilot/internal/nav1-heading-error-deg")+me.input.hdg.getValue();
    } elsif( getprop("autopilot/route-manager/active") == 1) {
      #var i = getprop("autopilot/route-manager/current-wp");
      desired_mag_heading = getprop("autopilot/route-manager/wp/bearing-deg");
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
      if(blink == FALSE or me.input.fiveHz.getValue() == TRUE) {
        me.heading_bug.show();
      } else {
        me.heading_bug.hide();
      }
    } else {
      me.heading_bug.hide();
    }
  },

  displayAltitude: func () {
    var metric = me.input.units.getValue();
    var alt = metric == TRUE ? me.input.alt_ft.getValue() * feet2meter : me.input.alt_ft.getValue();
    var radAlt = metric == TRUE ? me.input.rad_alt.getValue() * feet2meter : me.input.rad_alt.getValue();

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
      if (radAlt < alt) {
        me.alt_scale_line.show();
      } else {
        me.alt_scale_line.hide();
      }
      # Show radar altimeter ground height
      var rad_offset = altimeterScaleHeight/alt_scale_factor * radAlt;
      me.rad_alt_pointer.setTranslation(indicatorOffset, rad_offset - offset);
      me.rad_alt_pointer.show();
      if (radPointerProxim < rad_offset - offset or rad_offset - offset < -radPointerProxim) {
        me.alt_pointer.show();
      } else {
        me.alt_pointer.hide();
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
      var rad_offset = 2*altimeterScaleHeight/alt_scale_factor * radAlt;
      me.rad_alt_pointer.setTranslation(indicatorOffset, rad_offset - offset);
      me.rad_alt_pointer.show();
      if (radAlt < alt) {
        me.alt_scale_line.show();
      } else {
        me.alt_scale_line.hide();
      }
      if (radPointerProxim > rad_offset - offset > -radPointerProxim) {
        me.alt_pointer.show();
      } else {
        me.alt_pointer.hide();
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
      # Show radar altimeter ground height
      var rad_offset = 2*altimeterScaleHeight/alt_scale_factor * (radAlt);
      me.rad_alt_pointer.setTranslation(indicatorOffset, rad_offset - offset);
      me.rad_alt_pointer.show();
      if (radPointerProxim > rad_offset - offset > -radPointerProxim) {
        me.alt_pointer.show();
      } else {
        me.alt_pointer.hide();
      }
      me.alt_scale_grp.update();
      #print("alt " ~ sprintf("%3d", alt) ~ " radAlt:" ~ sprintf("%3d", radAlt) ~ " rad_offset:" ~ sprintf("%3d", rad_offset));
    }
  },

  displayDigitalAltitude: func (alt, radAlt) {
    # alt and radAlt is in current unit
    # determine max radar alt in current unit
    var radar_clamp = me.input.units.getValue() ==1 ? 100 : 100/feet2meter;
    if (radAlt == nil) {
      # Radar alt instrument not initialized yet.
      me.alt.setText("");
      countQFE = 0;
      QFEcalibrated = FALSE;
      me.input.altCalibrated.setValue(FALSE);
    } elsif (radAlt < radar_clamp) {
      # in radar alt range
      me.alt.setText("R " ~ sprintf("%3d", clamp(radAlt, 0, radar_clamp)));
      # check for QFE warning
      var diff = radAlt - alt;
      if (countQFE == 0 and (diff > 7 or diff < -7)) {
        #print("QFE warning " ~ countQFE);
        # is not calibrated, and is not blinking
        QFEcalibrated = FALSE;
        me.input.altCalibrated.setValue(FALSE);
        countQFE = 1;     
        #print("QFE not calibrated, and is not blinking");     
      } elsif (diff > -7 and diff < 7) {
          #is calibrated
        if (QFEcalibrated == FALSE and countQFE < 11) {
          # was not calibrated before, is now.
          #print("QFE was not calibrated before, is now. "~countQFE);
          countQFE = 11;
        }
        QFEcalibrated = TRUE;
        me.input.altCalibrated.setValue(TRUE);
      } elsif (QFEcalibrated == 1 and (diff > 7 or diff < -7)) {
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
  },

  displayDesiredAltitudeLines: func () {
    var desired_alt_delta_ft = nil;
    if (getprop("autopilot/locks/altitude") == "altitude-hold") {
      desired_alt_delta_ft = getprop("autopilot/settings/target-altitude-ft")-me.input.alt_ft.getValue();
    } elsif (getprop("autopilot/locks/altitude") == "agl-hold") {
      desired_alt_delta_ft = getprop("autopilot/settings/target-agl-ft")-me.input.rad_alt.getValue();
    } elsif(getprop("autopilot/route-manager/active") == 1) {
      var i = getprop("autopilot/route-manager/current-wp");
      var rt_alt = getprop("autopilot/route-manager/route/wp["~i~"]/altitude-ft");
      if(rt_alt != nil and rt_alt > 0) {
        desired_alt_delta_ft = rt_alt - me.input.alt_ft.getValue();
      }
    }# elsif (getprop("autopilot/locks/altitude") == "gs1-hold") {
    if(desired_alt_delta_ft != nil) {
      var pos_y = clamp(-desired_alt_delta_ft*me.pixelPerFeet, -2.5*pixelPerDegreeY, 2.5*pixelPerDegreeY);

      me.desired_lines.setTranslation(0, pos_y);
      me.desired_lines.show();
    } else {
      me.desired_lines.hide();
    }
  },

  displayTower: func () {
    var towerAlt = getprop("sim/tower/altitude-ft");
    var towerLat = getprop("sim/tower/latitude-deg");
    var towerLon = getprop("sim/tower/longitude-deg");
    if(towerAlt != nil and towerLat != nil and towerLon != nil) {
      var towerPos = geo.Coord.new();
      towerPos.set_latlon(towerLat, towerLon, towerAlt);
      var showme = TRUE;

      var hud_pos = me.trackCalc(towerPos, 99000, 1);
      if(hud_pos != nil) {
        var distance = hud_pos[2];
        var pos_x = hud_pos[0];
        var pos_y = hud_pos[1];

        if(pos_x > 512) {
          showme = FALSE;
          #pos_x = 512;
        }
        if(pos_x < -512) {
          showme = FALSE;
          #pos_x = -512;
        }
        if(pos_y > 512) {
          showme = FALSE;
          #pos_y = 512;
        }
        if(pos_y < -512) {
          showme = FALSE;
          #pos_y = -512;
        }

        if(showme == TRUE) {
          me.tower_symbol.setTranslation(pos_x, pos_y);
          var tower_dist = me.input.units.getValue() ==1  ? distance : distance/kts2kmh;
          me.tower_symbol_dist.setText(sprintf("%02d", tower_dist/1000));
          me.tower_symbol_icao.setText(getprop("sim/tower/airport-id"));
          me.tower_symbol.show();
          me.tower_symbol.update();
          #print(i~" "~mp.getNode("callsign").getValue());
        } else {
          me.tower_symbol.hide();
          #print(i~" hidden! "~mp.getNode("callsign").getValue());
        }
      } else {
        me.tower_symbol.hide();
      }
    } else {
      me.tower_symbol.hide();
    }
  },

  displayRadarTracks: func (mode) {
    me.self      =  geo.aircraft_position();
    me.myPitch   =  me.input.pitch.getValue()*deg2rads;
    me.myRoll    = -me.input.roll.getValue()*deg2rads;
    me.groundAlt =  me.input.alt_ft_real.getValue()*feet2meter;
    me.myHeading =  me.input.hdgReal.getValue();
    me.track_index = 0;
    me.selection_updated = FALSE;
    #me.short_dist = nil;

    if(getprop("sim/ja37/hud/tracks-enabled") == 1) {
      me.radar_group.show();

      tracks = [];

      #do the MP planes

      var players = [];
      foreach(item; multiplayer.model.list) {
        append(players, item.node);
      }
      me.trackAI(players, 1);

      #AI planes:
      var node_ai = props.globals.getNode("/ai/models");
      var planes = node_ai.getChildren("aircraft");
      var tankers = node_ai.getChildren("tanker");
      var ships = node_ai.getChildren("ship");
      var carriers = node_ai.getChildren("carrier");
      var vehicles = node_ai.getChildren("groundvehicle");
      #print();
      
      me.trackAI(carriers, 0);
      #print(size(carriers)~"carriers: "~me.track_index);
      me.trackAI(tankers, 1);
      #print(size(tankers)~"tankers: "~me.track_index);
      me.trackAI(ships, 1);
      #print(size(ships)~"ship: "~me.track_index);
      me.trackAI(planes, 1);
      #print(size(planes)~"planes: "~me.track_index);
      me.trackAI(vehicles, 1);
      #print();
      if(me.track_index != -1) {
        #hide the the rest unused circles
        for(i = me.track_index; i < maxTracks ; i+=1) {
          me.target_circle[i].hide();
        }
      }

      # draw selection
      if(selection != nil) {
        # something is selected
        if (selection[5].getChild("valid").getValue() == TRUE) {
          if (me.selection_updated == TRUE) {
            # selection is currently in forward looking radar view
            var blink = FALSE;
            if(selection[0] > 512) {
              blink = TRUE;
              selection[0] = 512;
            }
            if(selection[0] < -512) {
              blink = TRUE;
              selection[0] = -512;
            }
            if(selection[1] > 512) {
              blink = TRUE;
              selection[1] = 512;
            }
            if(selection[1] < -450) {
              blink = TRUE;
              selection[1] = -450;
            }
            if(selection[6] == TRUE and mode == COMBAT) {
              #targetable
              diamond_node = selection[5];
              me.diamond_group.setTranslation(selection[0], selection[1]);
              var diamond_dist = me.input.units.getValue() ==1  ? selection[2] : selection[2]/kts2kmh;
              me.diamond_dist.setText(sprintf("%02d", diamond_dist/1000));
              me.diamond_name.setText(selection[4]);
              me.target_circle[selection[3]].hide();


              var armSelect = me.input.station.getValue();
              
              if(armament.AIM9.active[armSelect-1] != nil and armament.AIM9.active[armSelect-1].status == 1) {
                me.diamond.show();
                me.target.hide();
              } else {
                me.target.show();
                me.diamond.hide();
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
              if(blink == TRUE and me.input.fiveHz.getValue() == FALSE) {
                me.diamond_group.hide();
              } else {
                me.diamond_group.show();
              }
            } else {
              #untargetable, like carriers and tankers
              diamond_node = nil;
              me.diamond_group.setTranslation(selection[0], selection[1]);
              me.target_circle[selection[3]].setTranslation(selection[0], selection[1]);
              var diamond_dist = me.input.units.getValue() == TRUE  ? selection[2] : selection[2]/kts2kmh;
              me.diamond_dist.setText(sprintf("%02d", diamond_dist/1000));
              me.diamond_name.setText(selection[4]);
              
              if(blink == TRUE and me.input.fiveHz.getValue() == FALSE) {
                me.diamond_group.hide();
                me.target_circle[selection[3]].hide();
              } else {
                me.diamond_group.show();
                me.target_circle[selection[3]].show()
              }
              me.diamond.hide();
              me.target.hide();
            }

            #velocity vector
            if(selection[0] > -512 and selection[0] < 512 and selection[1] > -512 and selection[1] < 512) {
              var tgtHeading = selection[5].getNode("orientation/true-heading-deg").getValue();
              var tgtSpeed = selection[5].getNode("velocities/true-airspeed-kt").getValue();
              var myHeading = me.input.hdgReal.getValue();
              var myRoll = me.input.roll.getValue();
              if (tgtHeading == nil or tgtSpeed == nil) {
                me.vel_vec.hide();
              } else {
                var relHeading = tgtHeading - myHeading - myRoll;
                
                relHeading -= 180;# this makes the line trail instead of lead
                relHeading = relHeading * deg2rads;

                me.vel_vec_trans_group.setTranslation(selection[0], selection[1]);
                me.vel_vec_rot_group.setRotation(relHeading);
                me.vel_vec.setScale(1, tgtSpeed/4);
                
                # note since trinometry circle is opposite direction of compas heading direction, the line will trail the target.
                me.vel_vec.show();
              }
            } else {
              me.vel_vec.hide();
            }

            me.target_circle[selection[3]].update();
            me.diamond_group.update();
          } else {
            # selection is outside radar view
            diamond_node = nil;
            me.diamond_group.hide();
            me.vel_vec.hide();
          }
        } else {
          # selection is no longer valid
          selection = nil;
          diamond_node = nil;
          me.vel_vec.hide();
          me.diamond_group.hide();
        }
      } else {
        # Nothing selected
        diamond_node = nil;
        me.vel_vec.hide();
        me.diamond_group.hide();
      }
      #print("");
    } else {
      # radar tracks not shown at all
      me.radar_group.hide();
    }
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
    } else {
      me.airspeedInt.setText(sprintf("KT%03d", me.input.ias.getValue()));
      me.airspeedInt.show();
      me.airspeed.setText(sprintf("M%.2f", mach));
    }
  },

  displayPitchLines: func (mode) {
    me.horizon_group2.setTranslation(0, pixelPerDegreeY * me.input.pitch.getValue());
    me.horizon_group3.setTranslation(0, pixelPerDegreeY * me.input.pitch.getValue());
    me.horizon_group.setTranslation(0, centerOffset);
    var rot = -me.input.roll.getValue() * deg2rads;
    me.h_rot.setRotation(rot);
    if(mode == COMBAT) {
      me.horizon_group3.show();
      me.horizon_dots.hide();
    } else {
      me.horizon_group3.hide();
      me.horizon_dots.show();
    }
  },

  displayTurnCoordinator: func () {
    if (getprop("sim/ja37/hud/bank-indicator") == 1) {
      #me.t_rot.setRotation(getprop("/orientation/roll-deg") * deg2rads * 0.5);
      me.slip_indicator.setTranslation(clamp(getprop("/orientation/side-slip-deg")*20, -150, 150), 0);
      me.turn_group.show();
    } else {
      me.turn_group.hide();
    }
  },

  displayQFE: func (mode) {
    if (mode == COMBAT) {
      var armSelect = me.input.station.getValue();
      if(armSelect == 0) {
        me.qfe.setText("KCA");
        me.qfe.show();
      } elsif(getprop("payload/weight["~ (armSelect-1) ~"]/selected") != "none") {
        me.qfe.setText("RB-24");
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

  remove_suffix: func(s, x) {
      var len = size(x);
      if (substr(s, -len) == x)
          return substr(s, 0, size(s) - len);
      return s;
  },

  # param carrier must be 0 for carriers
  trackAI: func (AI_vector, carrier) {
    var carrierNear = FALSE;
    foreach (var mp; AI_vector) {
      if(mp != nil and me.track_index != -1 and mp.getNode("valid").getValue() != FALSE) {#only the MP that are valid are sent here
        hud_pos = me.trackItemCalc(mp, 48000, carrier);

        if(hud_pos != nil) {
          append(tracks, hud_pos);
          var pos_x = hud_pos[0];
          var pos_y = hud_pos[1];
          var distance = hud_pos[2];
          var showme = 1;

          # tell the jsbsim hook system that if we are near a carrier
          if(carrier == 0 and distance < 1000) {
            # is carrier and is within 1 Km range
            carrierNear = TRUE;
          }

          # find and remember the type of the track
          var typeNode = mp.getNode("model-shorter");
          var model = nil;
          if (typeNode != nil) {
            model = typeNode.getValue();
          } else {
            var pathNode = mp.getNode("sim/model/path");
            if (pathNode != nil) {
              var path = pathNode.getValue();
              model = split(".", split("/", path)[-1])[0];
              model = me.remove_suffix(model, "-model");
              model = me.remove_suffix(model, "-anim");
              mp.addChild("model-shorter").setValue(model);

              var funcHash = {
                init: func (listener) {
                  funcHash.listenerID = listener;
                },
                call: func {
                  if(mp.getNode("valid").getValue() == FALSE) {
                    var child = mp.removeChild("model-shorter");                    
                    if (child != nil) {#for some reason this can be called two times, even if listener removed, therefore this check.
                      removelistener(me.listenerID);
                    }
                  }
                }
              };
              funcHash.init(setlistener(mp.getNode("valid"), func () {funcHash.call()}, 0, 0));
            }
          }


          append(hud_pos, me.track_index);
          
          # figure out what indentification to show in hud
          if(me.input.callsign.getValue() == 1) {
            if(mp.getNode("callsign") != nil and mp.getNode("callsign").getValue() != "" and mp.getNode("callsign").getValue() != nil) {
              ident = mp.getNode("callsign").getValue();
            } elsif (mp.getNode("name") != nil and mp.getNode("name").getValue() != "" and mp.getNode("name").getValue() != nil) {
              #only used by AI
              ident = mp.getNode("name").getValue();
            } elsif (mp.getNode("sign") != nil and mp.getNode("sign").getValue() != "" and mp.getNode("sign").getValue() != nil) {
              #only used by AI
              ident = mp.getNode("sign").getValue();
            } else {
              ident = "";
            }
          } else {
            if(model != nil) {
              ident = model;
            } elsif (mp.getNode("sign") != nil and mp.getNode("sign").getValue() != "" and mp.getNode("sign").getValue() != nil) {
              #only used by AI
              ident = mp.getNode("sign").getValue();  
            } elsif (mp.getNode("name") != nil and mp.getNode("name").getValue() != "" and mp.getNode("name").getValue() != nil) {
              #only used by AI
              ident = mp.getNode("name").getValue();
            } elsif (mp.getNode("callsign") != nil and mp.getNode("callsign").getValue() != "" and mp.getNode("callsign").getValue() != nil) {
              ident = mp.getNode("callsign").getValue();
            } else {
              ident = "";
            } 
          }

          append(hud_pos, ident);
          append(hud_pos, mp);
          append(hud_pos, carrier);

          var unique = mp.getChild("unique");
          if (unique == nil) {
            unique = mp.addChild("unique");
            unique.setValue(rand());
          }

          if(selection == nil and pos_x != 90000) {
            #this is first tracks in radar field, so will be default target
            selection = hud_pos;
            me.selection_updated = TRUE;
          } elsif (selection != nil and selection[5].getChild("unique").getValue() == unique.getValue() and pos_x != 90000) {
            # this track is already selected, updating it
            selection = hud_pos;
            me.selection_updated = TRUE;
          }

          #me.short_dist = hud_pos;
          #print(i~" Diamond: "~mp.getNode("callsign").getValue());
          #}

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
            me.target_circle[me.track_index].setTranslation(pos_x, pos_y);
            me.target_circle[me.track_index].show();
            me.target_circle[me.track_index].update();
            #print(me.track_index~" "~mp.getNode("callsign").getValue()~" dist="~distance~" shortest="~me.short_dist[2]);
            me.track_index += 1;
            if (me.track_index == maxTracks) {
              me.track_index = -1;
            }
          } else {
            #print(me.track_index~" not shown. Select="~selected);
          }
        }#end of error check
      }#end of valid check
    }#end of foreach
    if(carrier == 0) {
      if(carrierNear != me.input.carrierNear.getValue()) {
        me.input.carrierNear.setValue(carrierNear);
      }      
    }
  },#end of trackAI

  # hud_pos
  #
  # 0 - x position
  # 1 - y position
  # 2 - distance in meter
  # 3 - track index
  # 4 - identifier
  # 5 - node
  # 6 - targetable

  trackItemCalc: func (mp, range, carrier) {
    var x = mp.getNode("position/global-x").getValue();
    var y = mp.getNode("position/global-y").getValue();
    var z = mp.getNode("position/global-z").getValue();
    var aircraftPos = geo.Coord.new().set_xyz(x, y, z);
    return me.trackCalc(aircraftPos, range, carrier);
  },

  trackCalc: func (aircraftPos, range, carrier) {
    var distance = nil;
    
    call(func distance = me.self.distance_to(aircraftPos), nil, var err = []);

    if ((size(err))or(distance==nil)) {
      # Oops, have errors. Bogus position data (and distance==nil).
      #print("Received invalid position data: " ~ debug._error(mp.callsign));
      #me.target_circle[track_index+maxTargetsMP].hide();
      #print(i~" invalid pos.");
    } elsif (distance < range) {#is max radar range of ja37
      # Node with valid position data (and "distance!=nil").
      #distance = distance*kts2kmh*1000;
      var aircraftAlt=aircraftPos.alt(); #altitude in meters
      #ground angle
      var yg_rad=math.atan2((aircraftAlt-me.groundAlt), distance)-me.myPitch; 
      var xg_rad=(me.self.course_to(aircraftPos)-me.myHeading)*deg2rads;
      if (xg_rad > math.pi) {
        xg_rad = xg_rad - 2*math.pi;
      }
      if (xg_rad < -math.pi) {
        xg_rad = xg_rad + 2*math.pi;
      }

      if (yg_rad > math.pi) {
        yg_rad = yg_rad - 2*math.pi;
      }
      if (yg_rad < -math.pi) {
        yg_rad = yg_rad + 2*math.pi;
      }

      #aircraft angle
      var ya_rad=xg_rad*math.sin(-me.myRoll)+yg_rad*math.cos(-me.myRoll);
      var xa_rad=xg_rad*math.cos(-me.myRoll)-yg_rad*math.sin(-me.myRoll);

      if (xa_rad < -math.pi) {
        xa_rad = xa_rad + 2*math.pi;
      }
      if (xa_rad > math.pi) {
        xa_rad = xa_rad - 2*math.pi;
      }
      if (ya_rad > math.pi) {
        ya_rad = ya_rad - 2*math.pi;
      }
      if (ya_rad < -math.pi) {
        ya_rad = ya_rad + 2*math.pi;
      }

      if(ya_rad > -1 and ya_rad < 1 and xa_rad > -1 and xa_rad < 1) {
        #is within the radar cone
        var pos_x = pixelPerDegreeX*xa_rad*rad2deg;
        var pos_y = centerOffset+pixelPerDegreeY*-ya_rad*rad2deg;

        return [pos_x, pos_y, distance];
      } elsif (carrier == 0) {
        return [90000, 90000, distance];
      }
    }
    return nil;
  },

  showReticle: func (mode, cannon, out_of_ammo) {
    if (mode == COMBAT and cannon == TRUE) {
      me.showSidewind(FALSE);
      
      me.reticle_cannon.setTranslation(0, centerOffset);
      me.reticle_cannon.show();

      me.showFlightPathVector(1, 0);
    } elsif (mode != TAKEOFF) {# or me.input.wow_nlg.getValue() == 0
      # flight path vector (FPV)
      me.showFlightPathVector(1, out_of_ammo);
      me.showSidewind(FALSE);
      me.reticle_cannon.hide();
    } elsif(mode == TAKEOFF) {
      me.showFlightPathVector(!me.input.wow_nlg.getValue(), out_of_ammo);
      me.showSidewind(TRUE);
      me.reticle_cannon.hide();
    }    
  },

  showSidewind: func(show) {
    if(show == TRUE) {
      #move sidewind symbol according to side wind:
      var wind_heading = getprop("environment/wind-from-heading-deg");
      var wind_speed = getprop("environment/wind-speed-kt");
      var heading = me.input.hdgReal.getValue();
      #var speed = me.input.ias.getValue();
      var angle = (wind_heading -heading) * (math.pi / 180.0); 
      var wind_side = math.sin(angle) * wind_speed;
      #print((wind_heading -heading) ~ " " ~ wind_side);
      me.takeoff_symbol.setTranslation(clamp(-wind_side * sidewindPerKnot, -450, 450), sidewindPosition);    
      me.takeoff_symbol.show();
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
    } else {
      me.aim_reticle_fin.hide();
      me.aim_reticle.hide();
      me.reticle_no_ammo.hide();
    }
  }
};#end of HUDnasal


var id = 0;

var reinitHUD = FALSE;
var init = func() {
  removelistener(id); # only call once
  if(getprop("sim/ja37/supported/hud") == TRUE) {
    var hud_pilot = HUDnasal.new({"node": "HUDobject", "texture": "hud.png"});
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

var reinit = func() {#mostly called to change HUD color
   #reinitHUD = 1;

   foreach(var item; artifacts0) {
    item.setColor(r, g, b, a);
   }

   foreach(var item; artifacts1) {
    item.setColor(r, g, b, a);
   }

   HUDnasal.main.canvas.setColorBackground(0.36, g, 0.3, 0.02);
   ja37.click();
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
    reinit();
  } else {
    aircraft.HUD.cycle_brightness();
  }
};

var cycle_units = func () {
  if(getprop("sim/ja37/hud/mode") > 0) {
    ja37.click();
    var current = getprop("sim/ja37/hud/units-metric");
    if(current == 1) {
      setprop("sim/ja37/hud/units-metric", FALSE);
    } else {
      setprop("sim/ja37/hud/units-metric", TRUE);
    }
  } else {
    aircraft.HUD.cycle_type();
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

var nextTarget = func () {
  var max_index = size(tracks)-1;
  if(max_index > -1) {
    if(tracks_index < max_index) {
      tracks_index += 1;
    } else {
      tracks_index = 0;
    }
    selection = tracks[tracks_index];
  } else {
    tracks_index = -1;
  }
}