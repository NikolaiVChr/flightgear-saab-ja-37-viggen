# todo:
# servicable, indicated, common snippets with HUD, interoperability
# power supply, on off, brightness
# alt lines should shrink
# heading bug?
# steerpoint symbols: #
# nez indicator
# rb99 link
# full OOP
# use Pinto's model
var (width,height) = (341,512);

var window = canvas.Window.new([width, height],"dialog")
                   .set('title', "MI display");
var root = window.getCanvas(1).createGroup();
root.set("font", "LiberationFonts/LiberationMono-Regular.ttf");
window.getCanvas(1).setColorBackground(0, 0, 0, 1.0);

var (center_x, center_y) = (width/2,height/2);

var texel_per_degree = width/(85*2);

var r = 0.0;#MI colors
var g = 1.0;
var b = 0.0;
var a = 1.0;#alpha
var w = 1.0;#stroke width

var fpi_min = 3;
var fpi_med = 6;
var fpi_max = 9;

var maxTracks = 32;# how many radar tracks can be shown at once in the MI (was 16)

var fpi = root.createChild("path")
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
      .setStrokeLineWidth(w)
      .setColor(r,g,b, a);

var rootCenter = root.createChild("group");
rootCenter.setTranslation(width/2,height/2);
var horizon_group = rootCenter.createChild("group");
var horz_rot = horizon_group.createTransform();
var horizon_group2 = horizon_group.createChild("group");
var horizon_line = horizon_group2.createChild("path")
                     .moveTo(-height*0.75, -w*1.5)
                     .horiz(height*1.5)
                     .moveTo(-height*0.75, w*1.5)
                     .horiz(height*1.5)
                     .setStrokeLineWidth(w)
                     .setColor(r,g,b, a);
var horizon_alt = horizon_group2.createChild("text")
		.setText("")
		.setFontSize((25/512)*width, 1.0)
        .setAlignment("center-bottom")
        .setTranslation(-texel_per_degree*45, -w*4)
        .setColor(r,g,b, a);

for(var i = 0; i <= 20; i += 1) # alt scale (right side)
      rootCenter.createChild("path")
         .moveTo(texel_per_degree*70, -i * (85/10) * texel_per_degree + 85 * texel_per_degree)
         .horiz(5 * texel_per_degree)         
         .setStrokeLineWidth(w)
         .setColor(r,g,b, a);
for(var i = 0; i <= 4; i += 1) # alt scale large ticks (right side)
      rootCenter.createChild("path")
         .moveTo(texel_per_degree*70, -i * (85/2) * texel_per_degree + 85 * texel_per_degree)
         .horiz(10 * texel_per_degree)         
         .setStrokeLineWidth(w)
         .setColor(r,g,b, a);
for(var i = 0; i <= 4; i += 1) # alt scale large ticks text (right side)
      rootCenter.createChild("text")
      	 .setText(i*5)
         .setFontSize((15/512)*width, 1.0)
         .setAlignment("right-bottom")
         .setTranslation(texel_per_degree*80, -i * (85/2) * texel_per_degree + 85 * texel_per_degree-w)
         .setColor(r,g,b, a);

var alt_cursor = rootCenter.createChild("path")
		.moveTo(0,0)
		.lineTo(-5*texel_per_degree,5*texel_per_degree)
		.moveTo(0,0)
		.lineTo(-5*texel_per_degree,-5*texel_per_degree)
		.setStrokeLineWidth(w)
        .setColor(r,g,b, a);

var ground_cursor = rootCenter.createChild("path")
		.moveTo(-10*texel_per_degree,0)
		.horiz(20*texel_per_degree)
		.setStrokeLineWidth(w)
        .setColor(r,g,b, a);

# ground
var ground_grp = root.createChild("group");
var ground2_grp = ground_grp.createChild("group");
var ground_grp_trans = ground2_grp.createTransform();
var ground = ground2_grp.createChild("path")
		.moveTo(0,0)
		.lineTo( -30*texel_per_degree, 7.5*texel_per_degree)
		.moveTo(0,0)
		.lineTo(  30*texel_per_degree, 7.5*texel_per_degree)
		.moveTo( -30*texel_per_degree, 7.5*texel_per_degree)
		.lineTo( -60*texel_per_degree, 30*texel_per_degree)
		.moveTo(  30*texel_per_degree, 7.5*texel_per_degree)
		.lineTo(  60*texel_per_degree, 30*texel_per_degree)
		.moveTo(0,w*2)
		.lineTo( -30*texel_per_degree, 7.5*texel_per_degree+w*2)
		.moveTo(0,w*2)
		.lineTo(  30*texel_per_degree, 7.5*texel_per_degree+w*2)
		.moveTo( -30*texel_per_degree, 7.5*texel_per_degree+w*2)
		.lineTo( -60*texel_per_degree, 30*texel_per_degree+w*2)
		.moveTo(  30*texel_per_degree, 7.5*texel_per_degree+w*2)
		.lineTo(  60*texel_per_degree, 30*texel_per_degree+w*2)
		.moveTo(0,-w*2)
		.lineTo( -30*texel_per_degree, 7.5*texel_per_degree-w*2)
		.moveTo(0,-w*2)
		.lineTo(  30*texel_per_degree, 7.5*texel_per_degree-w*2)
		.moveTo( -30*texel_per_degree, 7.5*texel_per_degree-w*2)
		.lineTo( -60*texel_per_degree, 30*texel_per_degree-w*2)
		.moveTo(  30*texel_per_degree, 7.5*texel_per_degree-w*2)
		.lineTo(  60*texel_per_degree, 30*texel_per_degree-w*2)
		.setStrokeLineWidth(w)
        .setColor(r,g,b, a);

    # Collision warning arrow
var arr_15 = 1.5;
var arr_30 = 3;
var arr_90 = 9;
var arr_120 = 12;

var arrow_group = rootCenter.createChild("group");  
var arrow_trans = arrow_group.createTransform();
var arrow =
      arrow_group.createChild("path")
      .setColor(r,g,b, a)
      .moveTo(-arr_15*texel_per_degree,  arr_90*texel_per_degree)
      .lineTo(-arr_15*texel_per_degree, -arr_90*texel_per_degree)
      .lineTo(-arr_30*texel_per_degree, -arr_90*texel_per_degree)
      .lineTo(  0, -arr_120*texel_per_degree)
      .lineTo( arr_30*texel_per_degree, -arr_90*texel_per_degree)
      .lineTo( arr_15*texel_per_degree, -arr_90*texel_per_degree)
      .lineTo( arr_15*texel_per_degree,  arr_90*texel_per_degree)
      .setStrokeLineWidth(w);

    # scale heading ticks
var headScaleTickSpacing = 10 * texel_per_degree;
var headScalePlace       = 90 * texel_per_degree;
var head_scale_grp = rootCenter.createChild("group");

#clip is in canvas coordinates
var clip = (center_y-headScalePlace-texel_per_degree*7.5-(15/512)*width-w)~"px, "~(center_x+60*texel_per_degree)~"px, "~(center_y-headScalePlace+w)~"px, "~(center_x-60*texel_per_degree)~"px";
head_scale_grp.set("clip", "rect("~clip~")");#top,right,bottom,left

var head_scale_grp_trans = head_scale_grp.createTransform();
var head_scale = head_scale_grp.createChild("path")
        .moveTo(0, 0)
        .vert(-5*texel_per_degree)
        .moveTo(headScaleTickSpacing*2, 0)
        .vert(-2.5*texel_per_degree)
        .moveTo(-headScaleTickSpacing*2, 0)
        .vert(-2.5*texel_per_degree)
        .moveTo(-headScaleTickSpacing*1, 0)
        .vert(-2.5*texel_per_degree)
        .moveTo(headScaleTickSpacing*1, 0)
        .vert(-2.5*texel_per_degree)
        .moveTo(headScaleTickSpacing*3, 0)
        .vert(-5*texel_per_degree)
        .moveTo(-headScaleTickSpacing*3, 0)
        .vert(-5*texel_per_degree)
        .moveTo(headScaleTickSpacing*4, 0)
        .vert(-2.5*texel_per_degree)
        .moveTo(-headScaleTickSpacing*4, 0)
        .vert(-2.5*texel_per_degree)
        .moveTo(headScaleTickSpacing*5, 0)
        .vert(-2.5*texel_per_degree)
        .moveTo(-headScaleTickSpacing*5, 0)
        .vert(-2.5*texel_per_degree)
        .moveTo(headScaleTickSpacing*6, 0)
        .vert(-5*texel_per_degree)
        .moveTo(-headScaleTickSpacing*6, 0)
        .vert(-5*texel_per_degree)
        .moveTo(headScaleTickSpacing*7, 0)
        .vert(-2.5*texel_per_degree)
        .moveTo(headScaleTickSpacing*8, 0)
        .vert(-2.5*texel_per_degree)
        .moveTo(headScaleTickSpacing*9, 0)
        .vert(-5*texel_per_degree)
        .moveTo(headScaleTickSpacing*-9, 0)
        .horiz(headScaleTickSpacing*18)
        .setStrokeLineWidth(w)
        .setColor(r,g,b, a);

    # headingindicator
var head_scale_indicator = rootCenter.createChild("path")
    .moveTo(-5*texel_per_degree, -headScalePlace+5*texel_per_degree)
    .lineTo(0, -headScalePlace)
    .lineTo(5*texel_per_degree, -headScalePlace+5*texel_per_degree)
    .setColor(r,g,b, a)
    .setStrokeLineWidth(w);

    # Heading middle number
var hdgM = head_scale_grp.createChild("text")
    .setColor(r,g,b, a)
    .setAlignment("center-bottom")
    .setFontSize((15/512)*width, 1);

    # Heading left number
var hdgL = head_scale_grp.createChild("text")
    .setColor(r,g,b, a)
    .setAlignment("center-bottom")
    .setFontSize((15/512)*width, 1);

    # Heading right number
var hdgR = head_scale_grp.createChild("text")
    .setColor(r,g,b, a)
    .setAlignment("center-bottom")
    .setFontSize((15/512)*width, 1);

    # Heading left2 number
var hdgL2 = head_scale_grp.createChild("text")
    .setColor(r,g,b, a)
    .setAlignment("center-bottom")
    .setFontSize((15/512)*width, 1);

    # Heading right2 number
var hdgR2 = head_scale_grp.createChild("text")
    .setColor(r,g,b, a)
    .setAlignment("center-bottom")
    .setFontSize((15/512)*width, 1);

    # Heading right3 number
var hdgR3 = head_scale_grp.createChild("text")
    .setColor(r,g,b, a)
    .setAlignment("center-bottom")
    .setFontSize((15/512)*width, 1);


    # alt lines
var desired_lines3 = horizon_group2.createChild("path")
               .moveTo(-60*texel_per_degree, 0)
               .lineTo(-60*texel_per_degree, 85*texel_per_degree*0.5)
               .moveTo(-60*texel_per_degree+w*2.5, 0)
               .lineTo(-60*texel_per_degree+w*2.5, 85*texel_per_degree*0.5)
               .moveTo(-60*texel_per_degree-w*2.5, 0)
               .lineTo(-60*texel_per_degree-w*2.5, 85*texel_per_degree*0.5)
               .moveTo(60*texel_per_degree, 0)
               .lineTo(60*texel_per_degree, 85*texel_per_degree*0.5)
               .moveTo(60*texel_per_degree+w*2.5, 0)
               .lineTo(60*texel_per_degree+w*2.5, 85*texel_per_degree*0.5)
               .moveTo(60*texel_per_degree-w*2.5, 0)
               .lineTo(60*texel_per_degree-w*2.5, 85*texel_per_degree*0.5)
               .setStrokeLineWidth(w)
               .setColor(r,g,b);

var roundabout = func(x) {
  var y = x - int(x);
  return y < 0.5 ? int(x) : 1 + int(x) ;
};

var clamp = func(v, min, max) { v < min ? min : v > max ? max : v };

var FALSE = 0;
var TRUE = 1;

var fpi_x = 0;
var fpi_y = 0;

var loop = func {
	fpi_x_deg = getprop("ja37/displays/fpi-horz-deg");
	fpi_y_deg = getprop("ja37/displays/fpi-vert-deg");
	if (fpi_x_deg == nil) {
		fpi_x_deg = 0;
		fpi_y_deg = 0;
	}
	fpi_x = center_x+fpi_x_deg*texel_per_degree;
	fpi_y = center_y+fpi_y_deg*texel_per_degree;
	fpi.setTranslation(fpi_x, fpi_y);

	var rot = -getprop("orientation/roll-deg") * D2R;
	horz_rot.setRotation(rot);
	horizon_group2.setTranslation(0, texel_per_degree * getprop("orientation/pitch-deg"));

	var alt = getprop("instrumentation/altimeter/indicated-altitude-ft");
	var ground = getprop("position/ground-elev-m");
	if (ground == nil) {
		ground = -10000;
	}
	if (alt != nil) {
		alt_cursor.setTranslation(texel_per_degree*70, -(alt*FT2M)/20000 * 2 * 85 * texel_per_degree + 85 * texel_per_degree);
		ground_cursor.setTranslation(texel_per_degree*70, -(ground)/20000 * 2 * 85 * texel_per_degree + 85 * texel_per_degree);
		var text = "";
		if(alt*FT2M < 1000) {
			text = ""~roundabout(alt*FT2M/10)*10;
		} else {
			text = sprintf("%.1f", alt*FT2M/1000);
		}
		horizon_alt.setText(text);
		alt_cursor.show();
		ground_cursor.show();
		horizon_alt.show();
	} else {
		alt_cursor.hide();
		ground_cursor.hide();
		horizon_alt.hide();
	}
	displayHeadingScale();
	displayGround();
	displayGroundCollisionArrow();
	mi.showAltLines();
	mi.displayRadarTracks();
	mi.showqfe();
	mi.showArm();
	settimer(loop,0.05);
};

var displayGroundCollisionArrow = func () {
    if (getprop("/instrumentation/terrain-warning") == TRUE) {
      arrow_trans.setRotation(-getprop("orientation/roll-deg") * D2R);
      arrow.show();
    } else {
      arrow.hide();
    }
};

var displayGround = func () {
	var time = getprop("fdm/jsbsim/gear/unit[0]/WOW") == TRUE?0:getprop("fdm/jsbsim/systems/indicators/time-till-crash");
	if (time != nil and time >= 0 and time < 40) {
		time = clamp(time - 10,0,30);
		var dist = time/30 * 90 * texel_per_degree;
		ground_grp.setTranslation(fpi_x, fpi_y);
		ground_grp_trans.setRotation(-getprop("orientation/roll-deg") * D2R);
		ground.setTranslation(0, dist);
		ground_grp.show();
	} else {
		ground_grp.hide();
	}
};

var displayHeadingScale = func () {
    var heading = getprop("orientation/heading-magnetic-deg");
    var headOffset = heading/30 - int (heading/30);
    var middleText = int(heading/30)*3;
    var middleOffset = nil;
    if(middleText == 36) {
      middleText = 0;
    }
    var leftText   = middleText ==  0?33 :middleText-3;
    var rightText  = middleText == 33?0  :middleText+3;
    var leftText2  = leftText   ==  0?33 :leftText-3;
    var rightText2 = rightText  == 33?0  :rightText+3;
    var rightText3 = rightText2 == 33?0  :rightText2+3;

    if (headOffset > 0.5) {
      middleOffset = -(headOffset)*headScaleTickSpacing*3;
      head_scale_grp_trans.setTranslation(middleOffset, -headScalePlace);
      head_scale_grp.update();
    } else {
      middleOffset = -headOffset*headScaleTickSpacing*3;
      head_scale_grp_trans.setTranslation(middleOffset, -headScalePlace);
      head_scale_grp.update();
    }
    hdgM.setTranslation(0, -7.5*texel_per_degree);
    hdgM.setText(sprintf("%02d", middleText));
    hdgL.setTranslation(-headScaleTickSpacing*3, -7.5*texel_per_degree);
    hdgL.setText(sprintf("%02d", leftText));
    hdgR.setTranslation(headScaleTickSpacing*3, -7.5*texel_per_degree);
    hdgR.setText(sprintf("%02d", rightText));
    hdgL2.setTranslation(-headScaleTickSpacing*6, -7.5*texel_per_degree);
    hdgL2.setText(sprintf("%02d", leftText2));
    hdgR2.setTranslation(headScaleTickSpacing*6, -7.5*texel_per_degree);
    hdgR2.setText(sprintf("%02d", rightText2));
    hdgR3.setTranslation(headScaleTickSpacing*9, -7.5*texel_per_degree);
    hdgR3.setText(sprintf("%02d", rightText3));
    head_scale_grp.show();
    head_scale_indicator.show();
};

var MI = {

	new: func {
	  	var mi = { parents: [MI] };
	  	mi.input = {
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
      	};
   
      	foreach(var name; keys(mi.input)) {
        	mi.input[name] = props.globals.getNode(mi.input[name], 1);
      	}

      	mi.setupCanvasSymbols();

      	return mi;
	},

	setupCanvasSymbols: func {
		me.radar_group = rootCenter.createChild("group");

		      #diamond
	    me.diamond_group = me.radar_group.createChild("group");
	    
	    me.diamond_group.createTransform();
	    me.diamond = me.diamond_group.createChild("path")
	                           .moveTo(-texel_per_degree*10,   0)
	                           .lineTo(  0, -texel_per_degree*10)
	                           .lineTo( texel_per_degree*10,   0)
	                           .lineTo(  0,  texel_per_degree*10)
	                           .lineTo(-texel_per_degree*10,   0)
	                           .setStrokeLineWidth(w)
	                           .setColor(r,g,b, a);
	    me.target_air = me.diamond_group.createChild("path")
	                           .moveTo(-texel_per_degree*7,   0)
	                           .lineTo(-texel_per_degree*7, -texel_per_degree*7)
	                           .lineTo( texel_per_degree*7, -texel_per_degree*7)
	                           .lineTo( texel_per_degree*7,   0)
	                           .setStrokeLineWidth(w)
	                           .setColor(r,g,b, a);
	    me.target_ground = me.diamond_group.createChild("path")
	                           .moveTo(-texel_per_degree*7,   0)
	                           .lineTo(-texel_per_degree*7, texel_per_degree*7)
	                           .lineTo( texel_per_degree*7, texel_per_degree*7)
	                           .lineTo( texel_per_degree*7,   0)
	                           .setStrokeLineWidth(w)
	                           .setColor(r,g,b, a);
	    me.target_sea = me.diamond_group.createChild("path")
	                           .moveTo(-texel_per_degree*7,   0)
	                           .lineTo(0, texel_per_degree*7)
	                           .lineTo( texel_per_degree*7,   0)
	                           .setStrokeLineWidth(w)
	                           .setColor(r,g,b, a); 
#	    me.diamond_dist = me.diamond_group.createChild("text")
#	    	.setText("..")
#	     	.setColor(r,g,b, a)
#	     	.setAlignment("left-top")
#	     	.setTranslation(texel_per_degree*5, texel_per_degree*4)
#	     	.setFontSize(10, 1);
	    me.diamond_name = rootCenter.createChild("text")
		    .setText("..")
		    .setColor(r,g,b, a)
		    .setAlignment("center-bottom")
		    .setTranslation(0, texel_per_degree*100)
		    .setFontSize(15, 1);


	    me.vel_vec_trans_group = me.radar_group.createChild("group");
	    me.vel_vec_rot_group = me.vel_vec_trans_group.createChild("group");
	    #me.vel_vec_rot = me.vel_vec_rot_group.createTransform();
	    me.vel_vec = me.vel_vec_rot_group.createChild("path")
	                                  .moveTo(0, 0)
	                                  .lineTo(0,-1)
	                                  .setStrokeLineWidth(w)
	                                  .setColor(r,g,b, a);


		# halfcircle targets
	    me.target_circle  = [];
	    me.target_missile = [];
	    me.target_group = me.radar_group.createChild("group");
	    for(var i = 0; i < maxTracks; i += 1) {      
	      target_circles = me.target_group.createChild("path")
	                           .moveTo(-texel_per_degree*6, 0)
	                           .arcLargeCW(texel_per_degree*6, texel_per_degree*6, 0,  texel_per_degree*12, 0)
	                           .setStrokeLineWidth(w)
	                           .setColor(r,g,b, a);
	      target_m = me.target_group.createChild("path")
	                           .moveTo(-texel_per_degree*4, 0)
	                           .arcLargeCW(texel_per_degree*4, texel_per_degree*4, 0,  texel_per_degree*8, 0)
	                           .setStrokeLineWidth(w)
	                           .setColor(r,g,b, a);
	      append(me.target_circle, target_circles);
	      append(me.target_missile, target_m);
	    }

	    # tgt scale (left side)
      	rootCenter.createChild("path")
			.moveTo(-texel_per_degree*70, 85 * texel_per_degree)
			.vert(-2*85 * texel_per_degree)         
			.setStrokeLineWidth(w)
			.setColor(r,g,b, a);
		for(var i = 0; i <= 6; i += 1) # tgt scale ticks (left side)
		      rootCenter.createChild("path")
		         .moveTo(-texel_per_degree*70, -i * (85/3) * texel_per_degree + 85 * texel_per_degree)
		         .horiz(-10 * texel_per_degree)         
		         .setStrokeLineWidth(w)
		         .setColor(r,g,b, a);
		me.tgtTexts = [];
		for(var i = 0; i <= 3; i += 1) {# tgt scale large ticks text (left side)
		      append(me.tgtTexts, rootCenter.createChild("text")
		      	 .setText(i*10)
		         .setFontSize((15/512)*width, 1.0)
		         .setAlignment("right-bottom")
		         .setTranslation(i!=3?-texel_per_degree*75:-texel_per_degree*65, -i * (85/1.5) * texel_per_degree + 85 * texel_per_degree-w)
		         .setColor(r,g,b, a));
		}
		me.dist_cursor = rootCenter.createChild("path")
			.moveTo(0,0)
			.lineTo(5*texel_per_degree,5*texel_per_degree)
			.moveTo(0,0)
			.lineTo(5*texel_per_degree,-5*texel_per_degree)
			.setStrokeLineWidth(w)
	        .setColor(r,g,b, a);

		me.qfe = rootCenter.createChild("text")
    		.setText("QFE")
    		.setColor(r,g,b, a)
    		.setAlignment("center-top")
    		.setTranslation(-70*texel_per_degree, 90*texel_per_degree)
    		.setFontSize(15, 1);

    	me.arm = rootCenter.createChild("text")
    		.setText("None")
    		.setColor(r,g,b, a)
    		.setAlignment("left-top")
    		.setTranslation(-80*texel_per_degree, 100*texel_per_degree)
    		.setFontSize(15, 1);
	},

	showArm: func {
		if (me.input.currentMode.getValue() == displays.COMBAT) {
			me.ammo = armament.ammoCount(me.input.station.getValue());
		    if (me.ammo == -1) {
		    	me.ammoT = "  ";
		    } else {
		    	me.ammoT = me.ammo~" ";
		    }
      		me.arm.setText(me.ammoT~displays.common.currArmName);
      		me.arm.show();
      	} else {
      		me.arm.hide();
      	}
	},

	showqfe: func {
		if (me.input.qfeActive.getValue() != nil) {
			if (me.input.qfeActive.getValue() == TRUE) {
				me.qfe.setText("QFE");
				if (me.input.qfeShown.getValue() == TRUE) {
					me.qfe.show();
				} else {
					me.qfe.hide();
				}
			} else {
				me.qfe.hide();
			}
		}
	},

  displayRadarTracks: func () {

  	var mode = canvas_HUD.mode;

    me.track_index = 1;
    me.selection_updated = FALSE;
    me.tgt_dist = 1000000;
    me.tgt_callsign = "";

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
          me.target_missile[i].hide();
        }
      }
      if(me.selection_updated == FALSE) {
        me.target_circle[0].hide();
        me.target_missile[0].hide();
      }
      
      #me.target_group.update();
      

      # draw selection
      if(me.selection != nil and me.selection.isValid() == TRUE and me.selection_updated == TRUE) {
        # selection is currently in forward looking radar view
        me.blink = FALSE;

        me.pos_x = me.selection.get_polar()[2]*R2D;
        me.pos_y = -me.selection.get_polar()[3]*R2D;
        me.distPolar = me.selection.get_polar()[0];

        if(me.selection.get_type() != radar_logic.ORDNANCE and mode == canvas_HUD.COMBAT) {
          #targetable
          #diamond_node = selection[6];
          #armament.contact = me.selection;
          me.diamond_group.setTranslation(me.pos_x*texel_per_degree, me.pos_y*texel_per_degree);
          me.diamond_dista = me.input.units.getValue() ==1  ? me.selection.get_range()*NM2M : me.selection.get_range()*1000;
          
          me.tgt_dist = me.selection.get_range()*NM2M;
          if (me.input.callsign.getValue() == TRUE) {
            me.tgt_callsign = me.selection.get_Callsign();
          } else {
            me.tgt_callsign = me.selection.get_model();
          }
#          if (me.pos_x > 10) {
#            me.diamond_dist.setAlignment("right-top");
#            me.diamond_dist.setTranslation(-7*texel_per_degree, 5*texel_per_degree);
#            me.diamond_name.setAlignment("right-bottom");
#            me.diamond_name.setTranslation(-7*texel_per_degree, -5*texel_per_degree);
#          } elsif (me.pos_x < -10) {
#            me.diamond_dist.setAlignment("left-top");
#            me.diamond_dist.setTranslation(7*texel_per_degree, 5*texel_per_degree);
#            me.diamond_name.setAlignment("left-bottom");
#            me.diamond_name.setTranslation(7*texel_per_degree, -5*texel_per_degree);
#          }
          me.target_circle[me.selection_index].hide();
          me.target_missile[me.selection_index].hide();


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
		  
          if (me.displayDiamond > 0) {
            me.target_air.hide();
            me.target_ground.hide();
            me.target_sea.hide();

            if (me.diamond == 1 or me.input.tenHz.getValue() == TRUE) {
                me.diamond.show();
            } else {
                me.diamond.hide();
            }
          } else {
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
          }# else {
          #  me.target_air.hide();
          #  me.target_ground.hide();
          #  me.target_sea.hide();
          #  me.diamond.hide();
          #}
          me.diamond_group.show();

        } else {
          #untargetable but selectable, like carriers and tankers, or planes in navigation mode
          #diamond_node = nil;
          #armament.contact = nil;
          me.diamond_group.setTranslation(me.pos_x*texel_per_degree, me.pos_y*texel_per_degree);
          me.target_circle[me.selection_index].setTranslation(me.pos_x*texel_per_degree, me.pos_y*texel_per_degree);
          if (me.selection.get_type() == armament.ORDNANCE) {
          	me.target_missile[me.selection_index].setTranslation(me.pos_x*texel_per_degree, me.pos_y*texel_per_degree);
          	me.target_missile[me.selection_index].show();
          } else {
          	me.target_missile[me.selection_index].hide();
          }
          me.diamond_dista = me.input.units.getValue() == TRUE  ? me.selection.get_range()*NM2M : me.selection.get_range()*1000;
          me.tgt_dist = me.selection.get_range()*NM2M;

          if (me.input.callsign.getValue() == TRUE) {
            me.tgt_callsign = me.selection.get_Callsign();
          } else {
            me.tgt_callsign = me.selection.get_model();
          }
          
          
          me.target_circle[me.selection_index].show();
          
          me.diamond_group.show();
          me.diamond.hide();
          me.target_air.hide();
          me.target_ground.hide();
          me.target_sea.hide();
        }

        #velocity vector
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

	        me.vel_vec_trans_group.setTranslation(me.pos_x*texel_per_degree, me.pos_y*texel_per_degree);
	        me.vel_vec_rot_group.setRotation(me.relHeading);
	        me.vel_vec.setScale(1, me.tgtSpeed/10);
	        
	        # note since trigonometry circle is opposite direction of compas heading direction, the line will trail the target.
	        me.vel_vec.show();
	      }

        me.target_circle[me.selection_index].update();
        me.target_missile[me.selection_index].update();
        me.diamond_group.update();
      } else {
        # selection is outside radar view
        # or invalid
        # or nothing selected
        #diamond_node = nil;
        #armament.contact = nil;
        if(me.selection != nil) {
          #selection[2] = nil;#no longer sure why I do this..
        }
        me.diamond_group.hide();
        me.vel_vec.hide();
        me.target_circle[0].hide();
        me.target_missile[0].hide();
      }
      #print("");
    } else {
      # radar tracks not shown at all
      me.radar_group.hide();
    }
    me.targetScale();
  },

  targetScale: func {
  	if (me.tgt_dist < me.input.radarRange.getValue()) {
  		me.dist_cursor.setTranslation(-70*texel_per_degree, -(me.tgt_dist / me.input.radarRange.getValue()) * 85 * 2 * texel_per_degree + 85 * texel_per_degree);
  		me.diamond_name.setText(me.tgt_callsign);
  		me.dist_cursor.show();
	} else {
		me.diamond_name.setText("");
		me.dist_cursor.hide();
	}
	if (me.input.radarRange.getValue() == 15000) {
		me.tgtTexts[0].setText("0");
		me.tgtTexts[1].setText("5");
		me.tgtTexts[2].setText("10");
		me.tgtTexts[3].setText("15");
	} elsif (me.input.radarRange.getValue() == 30000) {
		me.tgtTexts[0].setText("0");
		me.tgtTexts[1].setText("10");
		me.tgtTexts[2].setText("20");
		me.tgtTexts[3].setText("30");
	} elsif (me.input.radarRange.getValue() == 60000) {
		me.tgtTexts[0].setText("0");
		me.tgtTexts[1].setText("20");
		me.tgtTexts[2].setText("40");
		me.tgtTexts[3].setText("60");
	} elsif (me.input.radarRange.getValue() == 120000) {
		me.tgtTexts[0].setText("0");
		me.tgtTexts[1].setText("40");
		me.tgtTexts[2].setText("80");
		me.tgtTexts[3].setText("120");
	}
  },

	displayRadarTrack: func (hud_pos) {
		me.pos_xx = hud_pos.get_polar()[2]*R2D;
		me.pos_yy = -hud_pos.get_polar()[3]*R2D;
		me.showmeT = hud_pos.get_cartesian()[0]<me.input.radarRange.getValue()?TRUE:FALSE;

		me.currentIndexT = me.track_index;

		if(hud_pos == radar_logic.selection and hud_pos.get_cartesian()[0] != 900000) {
			me.selection_updated = TRUE;
			me.selection_index = 0;
			me.currentIndexT = 0;
		}

		if(me.currentIndexT > -1 and (me.showmeT == TRUE or me.currentIndexT == 0)) {
			me.target_circle[me.currentIndexT].setTranslation(me.pos_xx*texel_per_degree, me.pos_yy*texel_per_degree);
			me.target_circle[me.currentIndexT].show();
			me.target_circle[me.currentIndexT].update();
			if (hud_pos.get_type() != radar_logic.ORDNANCE) {
				me.target_missile[me.currentIndexT].hide();
			} else {
				me.target_missile[me.currentIndexT].setTranslation(me.pos_xx*texel_per_degree, me.pos_yy*texel_per_degree);
				me.target_missile[me.currentIndexT].show();
				me.target_missile[me.currentIndexT].update();
			}
			if(me.currentIndexT != 0) {
				me.track_index += 1;
				if (me.track_index == maxTracks) {
					me.track_index = -1;
				}
			}
		}
	},

	showAltLines: func {
		if (me.input.alt_ft.getValue() != nil) {
	      me.showLines = TRUE;
	      me.desired_alt_delta_ft = nil;
	      if(canvas_HUD.mode == canvas_HUD.TAKEOFF) {
	        me.desired_alt_delta_ft = (500*M2FT)-me.input.alt_ft.getValue();
	      } elsif (me.input.APLockAlt.getValue() == "altitude-hold" and me.input.APTgtAlt.getValue() != nil) {
	        me.desired_alt_delta_ft = me.input.APTgtAlt.getValue()-me.input.alt_ft.getValue();
	      } elsif(canvas_HUD.mode == canvas_HUD.LANDING and land.mode < 3 and land.mode > 0) {
	        me.desired_alt_delta_ft = (500*M2FT)-me.input.alt_ft.getValue();
	      } elsif (me.input.APLockAlt.getValue() == "agl-hold" and me.input.APTgtAgl.getValue() != nil) {
	        me.desired_alt_delta_ft = me.input.APTgtAgl.getValue()-me.input.rad_alt.getValue();
	      } elsif(me.input.rmActive.getValue() == 1 and me.input.RMCurrWaypoint.getValue() != nil and me.input.RMCurrWaypoint.getValue() >= 0) {
	        me.i = me.input.RMCurrWaypoint.getValue();
	        me.rt_alt = getprop("autopilot/route-manager/route/wp["~me.i~"]/altitude-ft");
	        if(me.rt_alt != nil and me.rt_alt > 0) {
	          me.desired_alt_delta_ft = me.rt_alt - me.input.alt_ft.getValue();
	        }
	      }
	      if(me.desired_alt_delta_ft != nil) {
	        me.pos_y = clamp(-((me.desired_alt_delta_ft*FT2M)/300)*85*texel_per_degree*0.5, -85*texel_per_degree*0.25, 85*texel_per_degree*0.5);#150 m up, 300 m down

	        desired_lines3.setTranslation(0, me.pos_y);
	        if (me.showLines == TRUE) {
	          desired_lines3.show();
	        } else {
	          desired_lines3.hide();
	        }
	 #       if (me.showBoxes == TRUE and (getprop("fdm/jsbsim/systems/indicators/auto-altitude-secondary") == FALSE or me.input.twoHz.getValue())) {
	 #         me.desired_boxes.show();
	 #       } else {
	 #         me.desired_boxes.hide();
	 #       }
	      } else {
	        desired_lines3.hide();
	      }
	  	}
	},
};

var mi = MI.new();
loop();