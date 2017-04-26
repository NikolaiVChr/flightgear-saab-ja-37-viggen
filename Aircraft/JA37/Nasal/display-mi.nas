# todo:
# servicable, indicated
# power supply, on off, brightness (emmision)
# heading bug?
# steerpoint symbols: #
# nez indicator
# full OOP
# use Pinto's model
var (width,height) = (341,512);

var window = canvas.Window.new([width, height],"dialog")
                   .set('title', "MI display");
var gone = 0;
window.del = func() {
  print("Cleaning up window:","MI","\n");
  #update_timer.stop();
  gone = TRUE;
# explanation for the call() technique at: http://wiki.flightgear.org/Object_oriented_programming_in_Nasal#Making_safer_base-class_calls
  call(canvas.Window.del, [], me);
};
var root = window.getCanvas(1).createGroup();
root.set("font", "LiberationFonts/LiberationMono-Regular.ttf");
window.getCanvas(1).setColorBackground(0, 0, 0, 1.0);

var (center_x, center_y) = (width/2,height/2);

var texel_per_degree = width/(85*2);

var halfHeightOfSideScales   = 75 * texel_per_degree;
var sidePositionOfSideScales = 70 * texel_per_degree;
var ticksLong                = 10 * texel_per_degree;
var ticksMed                 =  5 * texel_per_degree;
var ticksShort               =2.5 * texel_per_degree;
var sidePositionOfAltLines   = 60 * texel_per_degree;

var r = 0.0;#MI colors
var g = 1.0;
var b = 0.0;
var a = 1.0;#alpha
var w = 1.0;#stroke width

var fpi_min = 3;
var fpi_med = 6;
var fpi_max = 9;

var maxTracks = 32;# how many radar tracks can be shown at once in the MI (was 16)

var roundabout = func(x) {
  var y = x - int(x);
  return y < 0.5 ? int(x) : 1 + int(x) ;
};

var clamp = func(v, min, max) { v < min ? min : v > max ? max : v };

var FALSE = 0;
var TRUE = 1;

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
	        ctrlRadar:        "controls/altimeter-radar",
	        alphaJSB:         "fdm/jsbsim/aero/alpha-deg",
	        mach:             "instrumentation/airspeed-indicator/indicated-mach",
      	};
   
      	foreach(var name; keys(mi.input)) {
        	mi.input[name] = props.globals.getNode(mi.input[name], 1);
      	}

      	mi.setupCanvasSymbols();

      	mi.modeHelp = TRUE;
      	mi.tgt_dist_last = nil;

      	return mi;
	},

	setupCanvasSymbols: func {

		me.fpi = root.createChild("path")
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

		me.rootCenter = root.createChild("group");
		me.rootCenter.setTranslation(width/2,height/2);
		me.horizon_group = me.rootCenter.createChild("group");
		me.horz_rot = me.horizon_group.createTransform();
		me.horizon_group2 = me.horizon_group.createChild("group");
		me.horizon_line = me.horizon_group2.createChild("path")
		                     .moveTo(-height*0.75, -w*1.5)
		                     .horiz(height*1.5)
		                     .moveTo(-height*0.75, w*1.5)
		                     .horiz(height*1.5)
		                     .setStrokeLineWidth(w)
		                     .setColor(r,g,b, a);
		me.horizon_alt = me.horizon_group2.createChild("text")
				.setText("")
				.setFontSize((25/512)*width, 1.0)
		        .setAlignment("center-bottom")
		        .setTranslation(-sidePositionOfSideScales*2/3, -w*4)
		        .setColor(r,g,b, a);

		for(var i = 0; i <= 20; i += 1) # alt scale (right side)
		      me.rootCenter.createChild("path")
		         .moveTo(sidePositionOfSideScales, -i * halfHeightOfSideScales / 10 + halfHeightOfSideScales)
		         .horiz(ticksMed)         
		         .setStrokeLineWidth(w)
		         .setColor(r,g,b, a);
		for(var i = 0; i <= 4; i += 1) # alt scale large ticks (right side)
		      me.rootCenter.createChild("path")
		         .moveTo(sidePositionOfSideScales, -i * halfHeightOfSideScales / 2 + halfHeightOfSideScales)
		         .horiz(ticksLong)         
		         .setStrokeLineWidth(w)
		         .setColor(r,g,b, a);
		me.altScaleTexts = [];
		for(var i = 0; i <= 4; i += 1) # alt scale large ticks text (right side)
		      append(me.altScaleTexts, me.rootCenter.createChild("text")
		      	 .setText(i*5)
		         .setFontSize((15/512)*width, 1.0)
		         .setAlignment("right-bottom")
		         .setTranslation(sidePositionOfSideScales+ticksLong, -i * halfHeightOfSideScales / 2 + halfHeightOfSideScales-w)
		         .setColor(r,g,b, a));

		me.alt_cursor = me.rootCenter.createChild("path")
				.moveTo(0,0)
				.lineTo(-5*texel_per_degree,5*texel_per_degree)
				.moveTo(0,0)
				.lineTo(-5*texel_per_degree,-5*texel_per_degree)
				.setStrokeLineWidth(w)
		        .setColor(r,g,b, a);

		me.alt_tgt_cursor = me.rootCenter.createChild("path")
				.moveTo(-ticksShort, 0)
	            .arcSmallCW(ticksShort, ticksShort, 0,  ticksShort*2, 0)
	            .arcSmallCW(ticksShort, ticksShort, 0, -ticksShort*2, 0)
				.setStrokeLineWidth(w)
		        .setColor(r,g,b, a);

		me.ground_cursor = me.rootCenter.createChild("path")
				.moveTo(-10*texel_per_degree,0)
				.horiz(ticksLong*2)
				.setStrokeLineWidth(w)
		        .setColor(r,g,b, a);

		# ground
		me.ground_grp = root.createChild("group");
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
		me.arr_15 = 1.5;
		me.arr_30 = 3;
		me.arr_90 = 9;
		me.arr_120 = 12;

		me.arrow_group = me.rootCenter.createChild("group");  
		me.arrow_trans = me.arrow_group.createTransform();
		me.arrow =
		      me.arrow_group.createChild("path")
		      .setColor(r,g,b, a)
		      .moveTo(-me.arr_15*texel_per_degree,  me.arr_90*texel_per_degree)
		      .lineTo(-me.arr_15*texel_per_degree, -me.arr_90*texel_per_degree)
		      .lineTo(-me.arr_30*texel_per_degree, -me.arr_90*texel_per_degree)
		      .lineTo(  0,                         -me.arr_120*texel_per_degree)
		      .lineTo( me.arr_30*texel_per_degree, -me.arr_90*texel_per_degree)
		      .lineTo( me.arr_15*texel_per_degree, -me.arr_90*texel_per_degree)
		      .lineTo( me.arr_15*texel_per_degree,  me.arr_90*texel_per_degree)
		      .setStrokeLineWidth(w);

		    # scale heading ticks
		me.headScaleTickSpacing = ticksLong;
		me.headScalePlace       = 5 * texel_per_degree + halfHeightOfSideScales;
		me.head_scale_grp = me.rootCenter.createChild("group");

		#clip is in canvas coordinates
		me.clip = (center_y-me.headScalePlace-texel_per_degree*7.5-(15/512)*width-w)~"px, "~(center_x+60*texel_per_degree)~"px, "~(center_y-me.headScalePlace+w)~"px, "~(center_x-60*texel_per_degree)~"px";
		me.head_scale_grp.set("clip", "rect("~me.clip~")");#top,right,bottom,left

		me.head_scale_grp_trans = me.head_scale_grp.createTransform();
		me.head_scale = me.head_scale_grp.createChild("path")
		        .moveTo(0, 0)
		        .vert(-ticksMed)
		        .moveTo(me.headScaleTickSpacing*2, 0)
		        .vert(-ticksShort)
		        .moveTo(-me.headScaleTickSpacing*2, 0)
		        .vert(-ticksShort)
		        .moveTo(-me.headScaleTickSpacing*1, 0)
		        .vert(-ticksShort)
		        .moveTo(me.headScaleTickSpacing*1, 0)
		        .vert(-ticksShort)
		        .moveTo(me.headScaleTickSpacing*3, 0)
		        .vert(-ticksMed)
		        .moveTo(-me.headScaleTickSpacing*3, 0)
		        .vert(-ticksMed)
		        .moveTo(me.headScaleTickSpacing*4, 0)
		        .vert(-ticksShort)
		        .moveTo(-me.headScaleTickSpacing*4, 0)
		        .vert(-ticksShort)
		        .moveTo(me.headScaleTickSpacing*5, 0)
		        .vert(-ticksShort)
		        .moveTo(-me.headScaleTickSpacing*5, 0)
		        .vert(-ticksShort)
		        .moveTo(me.headScaleTickSpacing*6, 0)
		        .vert(-ticksMed)
		        .moveTo(-me.headScaleTickSpacing*6, 0)
		        .vert(-ticksMed)
		        .moveTo(me.headScaleTickSpacing*7, 0)
		        .vert(-ticksShort)
		        .moveTo(me.headScaleTickSpacing*8, 0)
		        .vert(-ticksShort)
		        .moveTo(me.headScaleTickSpacing*9, 0)
		        .vert(-ticksMed)
		        .moveTo(me.headScaleTickSpacing*-9, 0)
		        .horiz(me.headScaleTickSpacing*18)
		        .setStrokeLineWidth(w)
		        .setColor(r,g,b, a);

		    # headingindicator
		me.head_scale_indicator = me.rootCenter.createChild("path")
		    .moveTo(-ticksMed, -me.headScalePlace+ticksMed)
		    .lineTo(0, -me.headScalePlace)
		    .lineTo(ticksMed, -me.headScalePlace+ticksMed)
		    .setColor(r,g,b, a)
		    .setStrokeLineWidth(w);

		    # Heading middle number
		me.hdgM = me.head_scale_grp.createChild("text")
		    .setColor(r,g,b, a)
		    .setAlignment("center-bottom")
		    .setFontSize((15/512)*width, 1);

		    # Heading left number
		me.hdgL = me.head_scale_grp.createChild("text")
		    .setColor(r,g,b, a)
		    .setAlignment("center-bottom")
		    .setFontSize((15/512)*width, 1);

		    # Heading right number
		me.hdgR = me.head_scale_grp.createChild("text")
		    .setColor(r,g,b, a)
		    .setAlignment("center-bottom")
		    .setFontSize((15/512)*width, 1);

		    # Heading left2 number
		me.hdgL2 = me.head_scale_grp.createChild("text")
		    .setColor(r,g,b, a)
		    .setAlignment("center-bottom")
		    .setFontSize((15/512)*width, 1);

		    # Heading right2 number
		me.hdgR2 = me.head_scale_grp.createChild("text")
		    .setColor(r,g,b, a)
		    .setAlignment("center-bottom")
		    .setFontSize((15/512)*width, 1);

		    # Heading right3 number
		me.hdgR3 = me.head_scale_grp.createChild("text")
		    .setColor(r,g,b, a)
		    .setAlignment("center-bottom")
		    .setFontSize((15/512)*width, 1);


		    # alt lines
		me.desired_lines3 = me.horizon_group2.createChild("path")
		               .moveTo(-sidePositionOfAltLines, 0)
		               .lineTo(-sidePositionOfAltLines, halfHeightOfSideScales*0.5)
		               .moveTo(-sidePositionOfAltLines+w*2.5, 0)
		               .lineTo(-sidePositionOfAltLines+w*2.5, halfHeightOfSideScales*0.5)
		               .moveTo(-sidePositionOfAltLines-w*2.5, 0)
		               .lineTo(-sidePositionOfAltLines-w*2.5, halfHeightOfSideScales*0.5)
		               .moveTo(sidePositionOfAltLines, 0)
		               .lineTo(sidePositionOfAltLines, halfHeightOfSideScales*0.5)
		               .moveTo(sidePositionOfAltLines+w*2.5, 0)
		               .lineTo(sidePositionOfAltLines+w*2.5, halfHeightOfSideScales*0.5)
		               .moveTo(sidePositionOfAltLines-w*2.5, 0)
		               .lineTo(sidePositionOfAltLines-w*2.5, halfHeightOfSideScales*0.5)
		               .setStrokeLineWidth(w)
		               .setColor(r,g,b);

		me.radar_index = me.horizon_group2.createChild("path")
		               .moveTo(-sidePositionOfAltLines-w*2.5, 0)
		               .horiz(-ticksLong)
		               .moveTo(-sidePositionOfAltLines-w*2.5, 0)
		               .lineTo(-ticksLong-sidePositionOfAltLines-w*2.5, 5*texel_per_degree)
		               .moveTo(sidePositionOfAltLines+w*2.5, 0)
		               .horiz(ticksLong)
		               .moveTo(sidePositionOfAltLines+w*2.5, 0)
		               .lineTo(ticksLong+sidePositionOfAltLines+w*2.5, 5*texel_per_degree)
		               .setStrokeLineWidth(w)
		               .setColor(r,g,b);

		me.radar_group = me.rootCenter.createChild("group");

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
	    me.diamond_name = me.rootCenter.createChild("text")
		    .setText("..")
		    .setColor(r,g,b, a)
		    .setAlignment("center-bottom")
		    .setTranslation(0, texel_per_degree*25+halfHeightOfSideScales)
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
	      me.target_circles = me.target_group.createChild("path")
	                           .moveTo(-texel_per_degree*6, 0)
	                           .arcLargeCW(texel_per_degree*6, texel_per_degree*6, 0,  texel_per_degree*12, 0)
	                           .setStrokeLineWidth(w)
	                           .setColor(r,g,b, a);
	      me.target_m = me.target_group.createChild("path")
	                           .moveTo(-texel_per_degree*4, 0)
	                           .arcLargeCW(texel_per_degree*4, texel_per_degree*4, 0,  texel_per_degree*8, 0)
	                           .setStrokeLineWidth(w)
	                           .setColor(r,g,b, a);
	      append(me.target_circle, me.target_circles);
	      append(me.target_missile, me.target_m);
	    }

	    # tgt scale (left side)
      	me.rootCenter.createChild("path")
			.moveTo(-sidePositionOfSideScales, halfHeightOfSideScales)
			.vert(-2*halfHeightOfSideScales)         
			.setStrokeLineWidth(w)
			.setColor(r,g,b, a);
		for(var i = 0; i <= 6; i += 1) # tgt scale ticks (left side)
		      me.rootCenter.createChild("path")
		         .moveTo(-sidePositionOfSideScales, -i * halfHeightOfSideScales / 3 + halfHeightOfSideScales)
		         .horiz(-ticksLong)         
		         .setStrokeLineWidth(w)
		         .setColor(r,g,b, a);
		me.tgtTexts = [];
		for(var i = 0; i <= 3; i += 1) {# tgt scale large ticks text (left side)
		      append(me.tgtTexts, me.rootCenter.createChild("text")
		      	 .setText(i*10)
		         .setFontSize((15/512)*width, 1.0)
		         .setAlignment("right-bottom")
		         .setTranslation(i!=3?-ticksMed-sidePositionOfSideScales:-sidePositionOfSideScales+ticksMed, -i * halfHeightOfSideScales / 1.5 + halfHeightOfSideScales-w)
		         .setColor(r,g,b, a));
		}
		me.dist_cursor = me.rootCenter.createChild("path")
			.moveTo(0,0)
			.lineTo(ticksMed,ticksMed)
			.moveTo(0,0)
			.lineTo(ticksMed,-ticksMed)
			.setStrokeLineWidth(w)
	        .setColor(r,g,b, a);

		me.qfe = me.rootCenter.createChild("text")
    		.setText("QFE")
    		.setColor(r,g,b, a)
    		.setAlignment("left-top")
    		.setTranslation(5*texel_per_degree-sidePositionOfSideScales, halfHeightOfSideScales+5*texel_per_degree)
    		.setFontSize(15, 1);

    	me.arm = me.rootCenter.createChild("text")
    		.setText("None")
    		.setColor(r,g,b, a)
    		.setAlignment("left-top")
    		.setTranslation(-10*texel_per_degree-sidePositionOfSideScales, halfHeightOfSideScales+15*texel_per_degree)
    		.setFontSize(15, 1);

    	me.machT = me.rootCenter.createChild("text")
    		.setText("M")
    		.setColor(r,g,b, a)
    		.setAlignment("left-bottom")
    		.setTranslation(-sidePositionOfSideScales, -halfHeightOfSideScales-27*texel_per_degree)
    		.setFontSize(15, 1);

    	me.distT = me.rootCenter.createChild("text")
    		.setText("A")
    		.setColor(r,g,b, a)
    		.setAlignment("center-bottom")
    		.setTranslation(0, -halfHeightOfSideScales-27*texel_per_degree)
    		.setFontSize(15, 1);

    	me.distT2 = me.rootCenter.createChild("text")
    		.setText("ÖKA")
    		.setColor(r,g,b, a)
    		.setAlignment("center-bottom")
    		.setTranslation(0, -halfHeightOfSideScales-20*texel_per_degree)
    		.setFontSize(15, 1);

    	me.altT = me.rootCenter.createChild("text")
    		.setText("H")
    		.setColor(r,g,b, a)
    		.setAlignment("right-bottom")
    		.setTranslation(sidePositionOfSideScales, -halfHeightOfSideScales-27*texel_per_degree)
    		.setFontSize(15, 1);

    	me.rowBottom1 = me.rootCenter.createChild("text")
    		.setText(" D   -   -  SVY  -   -  BIT LNK")
    		.setColor(r,g,b, a)
    		.setAlignment("center-bottom")
    		.setTranslation(0, height/2-25)
    		.setFontSize(15, 1);

    	me.rowBottom2 = me.rootCenter.createChild("text")
    		.setText(" -   -   -  VMI  -  TNF HÄN  - ")
    		.setColor(r,g,b, a)
    		.setAlignment("center-bottom")
    		.setTranslation(0, height/2-10)
    		.setFontSize(15, 1);
	},

	loop: func {
		if ( gone == TRUE) {
			return;
		}
		me.interoperability = me.input.units.getValue();
		

		me.fpi_x_deg = getprop("ja37/displays/fpi-horz-deg");
		me.fpi_y_deg = getprop("ja37/displays/fpi-vert-deg");
		if (me.fpi_x_deg == nil) {
			me.fpi_x_deg = 0;
			me.fpi_y_deg = 0;
		}
		me.fpi_x = center_x+me.fpi_x_deg*texel_per_degree;
		me.fpi_y = center_y+me.fpi_y_deg*texel_per_degree;
		me.fpi.setTranslation(me.fpi_x, me.fpi_y);

		me.rot = -getprop("orientation/roll-deg") * D2R;
		me.horz_rot.setRotation(me.rot);
		me.horizon_group2.setTranslation(0, texel_per_degree * getprop("orientation/pitch-deg"));

		me.displayHeadingScale();
		me.displayGround();
		me.displayGroundCollisionArrow();
		me.showAltLines();
		me.displayRadarTracks();
		me.altScale();
		me.targetScale();
		me.showTgtName();
		me.showqfe();
		me.showArm();
		me.radarIndex();
		me.showTopInfo();
		me.showBottomInfo();
		settimer(func me.loop(), 0.05);
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
			me.time = clamp(me.time - 10,0,30);
			me.dist = me.time/30 * halfHeightOfSideScales;
			me.ground_grp.setTranslation(me.fpi_x, me.fpi_y);
			me.ground_grp_trans.setRotation(-getprop("orientation/roll-deg") * D2R);
			me.groundCurve.setTranslation(0, me.dist);
			me.ground_grp.show();
		} else {
			me.ground_grp.hide();
		}
	},

	displayHeadingScale: func () {
	    me.heading = getprop("orientation/heading-magnetic-deg");
	    me.headOffset = me.heading/30 - int (me.heading/30);
	    me.middleText = int(me.heading/30)*3;
	    me.middleOffset = nil;
	    if(me.middleText == 36) {
	      me.middleText = 0;
	    }
	    me.leftText   = me.middleText ==  0?33 :me.middleText-3;
	    me.rightText  = me.middleText == 33?0  :me.middleText+3;
	    me.leftText2  = me.leftText   ==  0?33 :me.leftText-3;
	    me.rightText2 = me.rightText  == 33?0  :me.rightText+3;
	    me.rightText3 = me.rightText2 == 33?0  :me.rightText2+3;

	    if (me.headOffset > 0.5) {
	      me.middleOffset = -(me.headOffset)*me.headScaleTickSpacing*3;
	      me.head_scale_grp_trans.setTranslation(me.middleOffset, -me.headScalePlace);
	      me.head_scale_grp.update();
	    } else {
	      me.middleOffset = -me.headOffset*me.headScaleTickSpacing*3;
	      me.head_scale_grp_trans.setTranslation(me.middleOffset, -me.headScalePlace);
	      me.head_scale_grp.update();
	    }
	    me.hdgM.setTranslation(0, -7.5*texel_per_degree);
	    me.hdgM.setText(sprintf("%02d", me.middleText));
	    me.hdgL.setTranslation(-me.headScaleTickSpacing*3, -7.5*texel_per_degree);
	    me.hdgL.setText(sprintf("%02d", me.leftText));
	    me.hdgR.setTranslation(me.headScaleTickSpacing*3, -7.5*texel_per_degree);
	    me.hdgR.setText(sprintf("%02d", me.rightText));
	    me.hdgL2.setTranslation(-me.headScaleTickSpacing*6, -7.5*texel_per_degree);
	    me.hdgL2.setText(sprintf("%02d", me.leftText2));
	    me.hdgR2.setTranslation(me.headScaleTickSpacing*6, -7.5*texel_per_degree);
	    me.hdgR2.setText(sprintf("%02d", me.rightText2));
	    me.hdgR3.setTranslation(me.headScaleTickSpacing*9, -7.5*texel_per_degree);
	    me.hdgR3.setText(sprintf("%02d", me.rightText3));
	    me.head_scale_grp.show();
	    me.head_scale_indicator.show();
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
				me.qfe.setFontSize(15, 1);
				if (me.input.qfeShown.getValue() == TRUE) {
					me.qfe.show();
				} else {
					me.qfe.hide();
				}
			} else {
				if (size(me.tele) != 0) {
					var text = "LNK99";
					for(var i = 0; i < size(me.tele); i+=1) {
						text = text ~ me.tele[i];
					}
					me.qfe.setText(text);
					me.qfe.setFontSize(12.5, 1);
					me.qfe.show();
				} else {
					me.qfe.hide();
				}
			}
		}
	},

  	displayRadarTracks: func () {

	  	var mode = canvas_HUD.mode;

	    me.track_index = 1;
	    me.selection_updated = FALSE;
	    me.tgt_dist = 1000000;
	    me.tgt_callsign = "";
	    me.tele = [];

	    if(me.input.tracks_enabled.getValue() == TRUE and me.input.radar_serv.getValue() > 0) {
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
	          me.tgt_alt  = me.selection.get_altitude()*FT2M;
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
	          me.tgt_alt  = me.selection.get_altitude()*FT2M;

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
	        me.tgt_alt  = nil;
	      	me.tgt_dist = nil;
	      }
	      #print("");
	    } else {
	      # radar tracks not shown at all
	      me.tgt_alt  = nil;
	      me.tgt_dist = nil;
	      me.radar_group.hide();
	    }
  	},

    showTgtName: func {
  	  	if (me.input.tracks_enabled.getValue() == TRUE) {
  			me.diamond_name.setText(me.tgt_callsign);
  		} else {
  			# radar is off, so silent mode
  			me.diamond_name.setText("..Silent..");
  		}
    },

    showTopInfo: func {
    	# this is info about the target.
    	
  		if (me.tgt_dist != nil) {
  			# distance
  			if (me.interoperability == displays.METRIC) {
  	  			me.distT.setText(sprintf("A%d", me.tgt_dist/1000));
  			} else {
  				me.distT.setText(sprintf("NM%d", me.tgt_dist*M2NM));
  			}
  			if (me.tgt_dist_last != nil) {
  				if (me.interoperability == displays.METRIC) {
	  	  			me.distT2.setText(sprintf("%s", me.tgt_dist>me.tgt_dist_last?"ÖKA":me.tgt_dist!=me.tgt_dist_last?"AVTA":""));
	  			} else {
	  				me.distT2.setText(sprintf("%s", me.tgt_dist>me.tgt_dist_last?"INC":me.tgt_dist!=me.tgt_dist_last?"DEC":""));
	  			}
  			}
  			me.tgt_dist_last = me.tgt_dist;
  		} else {
  			me.distT.setText("");
  			me.distT2.setText("");
  			me.tgt_dist_last = nil;
  		}
  		
  		if (me.tgt_alt != nil) {
  			# altitude
  			me.alt = me.tgt_alt*M2FT;
  			me.text = "";
			if (me.interoperability == displays.METRIC) {
				if(me.alt*FT2M < 1000) {
					me.text = "H"~roundabout(me.alt*FT2M/10)*10;
				} else {
					me.text = sprintf("H%.1f", me.alt*FT2M/1000);
				}
			} else {
				me.text = sprintf("FT%d", roundabout(me.alt/10)*10);
			}
  	  		me.altT.setText(me.text);

  	  		if (radar_logic.selection != nil) {
	    		# speed
	    		me.tgt_speed_kt = radar_logic.selection.get_Speed();
	    		me.rs = armament.AIM.rho_sndspeed(me.alt);
				me.sound_fps = me.rs[1];
	    		me.speed_m = (me.tgt_speed_kt*KT2FPS) / me.sound_fps;
	  	  		me.machT.setText(sprintf("M%.2f", me.speed_m));
	  		} else {
	  			me.machT.setText("");
	  		}
  		} else {
  			me.altT.setText("");
  			me.machT.setText("");
  		}
    },

    showBottomInfo: func {
    	if (me.modeHelp == TRUE) {
    		me.rowBottom1.show();
    		me.rowBottom1.show();
		} else {
			me.rowBottom1.hide();
			me.rowBottom2.hide();
		}
    },

  	targetScale: func {
	  	if (me.tgt_dist != nil and me.tgt_dist < me.input.radarRange.getValue()) {
	  		me.dist_cursor.setTranslation(-sidePositionOfSideScales, -(me.tgt_dist / me.input.radarRange.getValue()) * 2 * halfHeightOfSideScales + halfHeightOfSideScales);
	  		me.dist_cursor.show();
		} else {
			me.dist_cursor.hide();
		}
		if (me.interoperability == displays.METRIC) {
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
		} else {
			if (me.input.radarRange.getValue() == 15000) {
				me.tgtTexts[0].setText("0");
				me.tgtTexts[1].setText("2.7");
				me.tgtTexts[2].setText("5.4");
				me.tgtTexts[3].setText("8.1");
			} elsif (me.input.radarRange.getValue() == 30000) {
				me.tgtTexts[0].setText("0");
				me.tgtTexts[1].setText("5.4");
				me.tgtTexts[2].setText("11");
				me.tgtTexts[3].setText("16");
			} elsif (me.input.radarRange.getValue() == 60000) {
				me.tgtTexts[0].setText("0");
				me.tgtTexts[1].setText("11");
				me.tgtTexts[2].setText("22");
				me.tgtTexts[3].setText("32");
			} elsif (me.input.radarRange.getValue() == 120000) {
				me.tgtTexts[0].setText("0");
				me.tgtTexts[1].setText("22");
				me.tgtTexts[2].setText("43");
				me.tgtTexts[3].setText("65");
			}
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
				var eta = hud_pos.getETA();
				var hit = hud_pos.getHitChance();
				if (eta != nil) {
					append(me.tele, sprintf(": %d%% %ds", hit, eta))
				}
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

	altScale: func {
		me.alt = getprop("instrumentation/altimeter/indicated-altitude-ft");
		me.ground = getprop("position/ground-elev-m");
		if (me.ground == nil) {
			me.ground = -10000;
		}
		if (me.alt != nil) {
			if (me.tgt_alt != nil) {
				me.alt_tgt_cursor.setTranslation(sidePositionOfSideScales+7.5*texel_per_degree, -(me.tgt_alt)/20000 * 2 * halfHeightOfSideScales + halfHeightOfSideScales);
				me.alt_tgt_cursor.show();
			} else {
				me.alt_tgt_cursor.hide();
			}
			me.alt_cursor.setTranslation(sidePositionOfSideScales, -(me.alt*FT2M)/20000 * 2 * halfHeightOfSideScales + halfHeightOfSideScales);
			me.ground_cursor.setTranslation(sidePositionOfSideScales, -(me.ground)/20000 * 2 * halfHeightOfSideScales + halfHeightOfSideScales);
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
			if (me.interoperability == displays.METRIC) {
				me.altScaleTexts[0].setText("0");
				me.altScaleTexts[1].setText("5");
				me.altScaleTexts[2].setText("10");
				me.altScaleTexts[3].setText("15");
				me.altScaleTexts[4].setText("20");
			} else {
				me.altScaleTexts[0].setText("0");
				me.altScaleTexts[1].setText("16");
				me.altScaleTexts[2].setText("33");
				me.altScaleTexts[3].setText("49");
				me.altScaleTexts[4].setText("66");
			}
			me.alt_cursor.show();
			me.ground_cursor.show();
			me.horizon_alt.show();
		} else {
			me.alt_cursor.hide();
			me.ground_cursor.hide();
			me.horizon_alt.hide();
		}
	},

	showAltLines: func {
		if (me.input.alt_ft.getValue() != nil) {
	      me.showLines = TRUE;
	      me.desired_alt_delta_ft = nil;
	      me.desired_alt_ft = nil;
	      if(canvas_HUD.mode == canvas_HUD.TAKEOFF) {
	      	me.desired_alt_ft = (500*M2FT);
	        me.desired_alt_delta_ft = (500*M2FT)-me.input.alt_ft.getValue();
	      } elsif (me.input.APLockAlt.getValue() == "altitude-hold" and me.input.APTgtAlt.getValue() != nil) {
	      	me.desired_alt_ft = me.input.APTgtAlt.getValue();
	        me.desired_alt_delta_ft = me.input.APTgtAlt.getValue()-me.input.alt_ft.getValue();
	      } elsif(canvas_HUD.mode == canvas_HUD.LANDING and land.mode < 3 and land.mode > 0) {
	      	me.desired_alt_ft = (500*M2FT);
	        me.desired_alt_delta_ft = (500*M2FT)-me.input.alt_ft.getValue();
	      } elsif (me.input.APLockAlt.getValue() == "agl-hold" and me.input.APTgtAgl.getValue() != nil) {
	      	me.desired_alt_ft = me.input.APTgtAgl.getValue();
	        me.desired_alt_delta_ft = me.input.APTgtAgl.getValue()-me.input.rad_alt.getValue();
	      } elsif(me.input.rmActive.getValue() == 1 and me.input.RMCurrWaypoint.getValue() != nil and me.input.RMCurrWaypoint.getValue() >= 0) {
	        me.i = me.input.RMCurrWaypoint.getValue();
	        me.rt_alt = getprop("autopilot/route-manager/route/wp["~me.i~"]/altitude-ft");
	        if(me.rt_alt != nil and me.rt_alt > 0) {
	          me.desired_alt_ft = me.rt_alt;
	          me.desired_alt_delta_ft = me.rt_alt - me.input.alt_ft.getValue();
	        }
	      }
	      if(me.desired_alt_delta_ft != nil) {
	        me.pos_y = clamp(-((me.desired_alt_delta_ft*FT2M)/300)*halfHeightOfSideScales*0.5, -halfHeightOfSideScales*0.25, halfHeightOfSideScales*0.5);#150 m up, 300 m down

	        me.desired_lines3.setTranslation(0, me.pos_y);

	        me.scale = clamp(extrapolate(me.desired_alt_ft, 200, 300, 0.6666, 1), 0.6666, 1);

	        me.desired_lines3.setScale(1, me.scale);

	        if (me.showLines == TRUE and (getprop("fdm/jsbsim/systems/indicators/auto-altitude-secondary") == FALSE or me.input.twoHz.getValue())) {
	          me.desired_lines3.show();
	        } else {
	          me.desired_lines3.hide();
	        }
	      } else {
	        me.desired_lines3.hide();
	      }
	  	}
	},

	radarIndex: func {
		me.radAlt = me.input.ctrlRadar.getValue() == TRUE?me.input.rad_alt.getValue() * FT2M : nil;
		if (me.radAlt != nil and me.radAlt < 600) {
			me.radar_index.setTranslation(0, extrapolate(me.radAlt, 0, 600, 0, halfHeightOfSideScales));
			me.radar_index.show();
		} else {
			me.radar_index.hide();
		}
	},
};

var extrapolate = func (x, x1, x2, y1, y2) {
    return y1 + ((x - x1) / (x2 - x1)) * (y2 - y1);
};

var mi = MI.new();
mi.loop();