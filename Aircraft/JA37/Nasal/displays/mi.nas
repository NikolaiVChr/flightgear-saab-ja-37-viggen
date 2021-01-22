var (width_px,height_px) = (512,512);
var (width_mm,height_mm) = (180,180);

#var gone = 0;

#var window = canvas.Window.new([width, height],"dialog")
#                   .set('title', "MI display");
#window.del = func() {
#  print("Cleaning up window:","MI","\n");
  #update_timer.stop();
#  gone = TRUE;
#
#  call(canvas.Window.del, [], me);
#};
#var root = window.getCanvas(1).createGroup();
#window.getCanvas(1).setColorBackground(0, 0, 0, 1.0);
#window.getCanvas(1).addPlacement({"node": "screen", "texture": "mi_base.png"});

var mycanvas = nil;
var root = nil;
var setupCanvas = func {
	mycanvas = canvas.new({
	  "name": "MI",
	  "size": [width_px, height_px],
	  "view": [width_mm, height_mm],

	  "mipmapping": 1
	});
	root = mycanvas.createGroup();
	mycanvas.setColorBackground(0, 0, 0, 1.0);
	mycanvas.addPlacement({"node": "screen", "texture": "mi_base.png"});

	root.set("font", "LiberationFonts/LiberationMono-Regular.ttf");
};

# Center of radar area. Offset down a bit.
var (center_x, center_y) = (width_mm/2,height_mm/2+10);

var radar_area_width = 100;

var texel_per_degree = 397/(85*2);

var halfHeightOfSideScales = 50;
var sidePositionOfSideScales = 50;

var ticksLong                = 5;
var ticksMed                 = 3;
var ticksShort               = 2;

var heading_deg_to_mm        = radar_area_width/120;

var r = 0.0;#MI colors
var g = 1.0;
var b = 0.0;
var a = 1.0;#alpha
var w = 0.5;#stroke width

var maxTracks = 32;# how many radar tracks can be shown at once in the MI (was 16)

var roundabout = func(x) {
  var y = x - int(x);
  return y < 0.5 ? int(x) : 1 + int(x) ;
};

var FALSE = 0;
var TRUE = 1;

var helpOn = FALSE;

var pressP3 = func {
	helpOn = TRUE;
};

var releaseP3 = func {
	helpOn = FALSE;
	mi.helpTime = mi.input.timeElapsed.getValue();
};

var press2 = func {
	# SVY on TI
	TI.ti.showSVY();
};

var pressM2 = func {
	# ECM on TI
	TI.ti.showECM();
};

var pressX3 = func {
	# mark event
	#
	TI.ti.recordEvent();
};

var pressX1 = func {
	# RB99 self tests
	#
	# Show on TI
	TI.ti.doBIT();
};

var pressX2 = func {
	# RB99 link
	#
	# transfer to TI
	TI.ti.showLNK();
};

var cursor = func {
	cursorOn = !cursorOn;
	displays.common.resetCursorDelta();
	mi.cursor_pos = [0,-radar_area_width/2];
	if (!cursorOn) {
		if (getprop("controls/displays/stick-controls-cursor")) {
			ja37.notice("Cursor OFF. Flight ctrl ON.");
		}
		setprop("controls/displays/stick-controls-cursor", 0);
	}
}

var cursorOn = TRUE;

var MI = {

	new: func {
	  	var mi = { parents: [MI] };
	  	mi.input = {
			APmode:               "fdm/jsbsim/autoflight/mode",
			alt_m:                "instrumentation/altimeter/indicated-altitude-meter",
			brightnessSetting:    "ja37/avionics/brightness-mi-knob",
			flash_alt_bars:       "fdm/jsbsim/systems/indicators/flashing-alt-bars",
			heading:              "instrumentation/heading-indicator/indicated-heading-deg",
			hydrPressure:         "fdm/jsbsim/systems/hydraulics/system1/pressure",
			rad_alt:              "instrumentation/radar-altimeter/radar-altitude-ft",
			rad_alt_ready:        "instrumentation/radar-altimeter/ready",
			radar_active:         "ja37/radar/active",
			radarRange:           "instrumentation/radar/range",
			radarServ:            "instrumentation/radar/serviceable",
			ref_alt:              "ja37/displays/reference-altitude-m",
			rmActive:             "autopilot/route-manager/active",
			roll:                 "instrumentation/attitude-indicator/indicated-roll-deg",
			timeElapsed:          "sim/time/elapsed-sec",
			viewNumber:           "sim/current-view/view-number",
			headTrue:             "orientation/heading-deg",
			fpv_pitch:            "instrumentation/fpv/pitch-deg",
			fpv_up:               "instrumentation/fpv/angle-up-deg",
			fpv_right:            "instrumentation/fpv/angle-right-deg",
			twoHz:                "ja37/blink/two-Hz/state",
			callsign:             "ja37/hud/callsign",
			hdgReal:              "orientation/heading-deg",
			terrain_warning:      "/instrumentation/terrain-warning",
			gpws_time:            "fdm/jsbsim/systems/indicators/time-till-crash",
			radar_serv:           "instrumentation/radar/serviceable",
			twoHz:                "ja37/blink/two-Hz/state",
			qfeWarning:           "ja37/displays/qfe-warning",
			alphaJSB:             "fdm/jsbsim/aero/alpha-deg",
			mach:                 "instrumentation/airspeed-indicator/indicated-mach",
			wow0:                 "fdm/jsbsim/gear/unit[0]/WOW",
			cursor_iff:           "controls/displays/cursor-iff",
		};

		foreach(var name; keys(mi.input)) {
			mi.input[name] = props.globals.getNode(mi.input[name], 1);
		}

		mi.setupCanvasSymbols();

		mi.helpTime = -5;
		mi.cursor_pos = [0,-radar_area_width/2];
		mi.cursorTriggerPrev = FALSE;
		mi.radar_range = mi.input.radarRange.getValue();
		mi.head_true = mi.input.headTrue.getValue();
		mi.qfe = FALSE;
		mi.n_tracks = 0;

		return mi;
	},

	setupCanvasSymbols: func {

		me.rootCenter = root.createChild("group");
		me.rootCenter.setTranslation(center_x,center_y);

		# FPI
		me.fpi_wing_length = 7.5;
		me.fpi_tail_length = 5;
		me.fpi_circ_radius = 2.5;
		me.fpi = me.rootCenter.createChild("group");
		# wings
		me.fpi.createChild("path")
			.moveTo(me.fpi_circ_radius, 0)
			.horiz(me.fpi_wing_length)
			.moveTo(-me.fpi_circ_radius, 0)
			.horiz(-me.fpi_wing_length)
			.setStrokeLineWidth(2)
			.setStrokeLineCap("butt")
			.setColor(r,g,b,a);
		# tail
		me.fpi_tail = me.fpi.createChild("path")
			.moveTo(0, -me.fpi_circ_radius)
			.vert(-me.fpi_tail_length)
			.setStrokeLineWidth(1)
			.setStrokeLineCap("butt")
			.setColor(r,g,b,a);
		# circle
		me.fpi.createChild("path")
			.moveTo(me.fpi_circ_radius, 0)
			.arcSmallCCW(me.fpi_circ_radius, me.fpi_circ_radius, 0, -me.fpi_circ_radius*2, 0)
			.arcSmallCCW(me.fpi_circ_radius, me.fpi_circ_radius, 0, me.fpi_circ_radius*2, 0)
			.close()
			.setStrokeLineWidth(w)
			.setColor(r,g,b,a);

		# Horizon
		me.horizon_group = me.rootCenter.createChild("group");
		me.horizon_group2 = me.horizon_group.createChild("group");
		me.horz_rot = me.horizon_group.createTransform();
		me.horizon_line = me.horizon_group2.createChild("path")
			.moveTo(-radar_area_width*0.65, 0)
			.horiz(radar_area_width*1.3)
			.setStrokeLineWidth(0.7)
			.setColor(r,g,b,a);
		me.horizon_alt = me.horizon_group2.createChild("text");
		me.horizon_alt.enableUpdate();
		me.horizon_alt.updateText("")
			.setFontSize(6, 1.0)
			.setAlignment("center-center")
			.setTranslation(-radar_area_width/3, -6)
			.setColor(r,g,b,a);

		# alt lines
		me.alt_line_height = 25; # manual
		me.alt_line_pos = radar_area_width * 0.48;
		me.desired_lines = me.horizon_group2.createChild("path")
			.moveTo(me.alt_line_pos, 0)
			.vert(me.alt_line_height)
			.moveTo(-me.alt_line_pos, 0)
			.vert(me.alt_line_height)
			.setStrokeLineWidth(3)
			.setStrokeLineCap("butt")
			.setColor(r,g,b,a);

		# RHM indicator on alt lines
		me.rhm_index = me.horizon_group2.createChild("path")
			.moveTo(-me.alt_line_pos + 1.5, 0)
			.line(-5, 0)
			.moveTo(-me.alt_line_pos + 1.5, 0)
			.line(-5, 2.5)
			.moveTo(me.alt_line_pos - 1.5, 0)
			.line(5, 0)
			.moveTo(me.alt_line_pos - 1.5, 0)
			.line(5, 2.5)
			.setStrokeLineWidth(w)
			.setColor(r,g,b);

		# ground
		me.ground_grp = me.rootCenter.createChild("group");
		me.ground2_grp = me.ground_grp.createChild("group");
		me.ground_grp_trans = me.ground2_grp.createTransform();
		me.groundCurve = me.ground2_grp.createChild("path")
			.moveTo(-0.42*radar_area_width, 0.30*radar_area_width)
			.lineTo(-0.24*radar_area_width, 0.06*radar_area_width)
			.lineTo(0,0)
			.lineTo(0.24*radar_area_width, 0.06*radar_area_width)
			.lineTo(0.42*radar_area_width, 0.30*radar_area_width)
			.setStrokeLineWidth(2.5)
			.setStrokeLineJoin("miter")
			.setStrokeLineCap("butt")
			.setColor(r,g,b, a);

		# Collision warning arrow
		me.arrow_half_width = me.fpi_circ_radius*0.8;
		me.arrow_length = 25;
		me.arrow_point_half_width = me.arrow_half_width * 1.6;
		me.arrow = me.rootCenter.createChild("path")
			.moveTo(-me.arrow_half_width, -me.arrow_length/2)
			.vert(me.arrow_length)
			.moveTo(me.arrow_half_width, -me.arrow_length/2)
			.vert(me.arrow_length)
			.moveTo(0, -me.arrow_length/2 - me.arrow_half_width)
			.line(me.arrow_point_half_width, me.arrow_point_half_width)
			.moveTo(0, -me.arrow_length/2 - me.arrow_half_width)
			.line(-me.arrow_point_half_width, me.arrow_point_half_width)
			.setColor(r,g,b,a)
			.setStrokeLineWidth(0.7);

		# Altitude scale (right side)
		me.alt_scale = me.rootCenter.createChild("group")
			.setTranslation(radar_area_width/2 + 3, radar_area_width/2);
		me.alt_scale_marks = me.alt_scale.createChild("path")
			.setStrokeLineWidth(w)
			.setColor(r,g,b,a);
		for (var i=1; i<=19; i+=1) {
			if (math.mod(i, 5) == 0) continue;
			me.alt_scale_marks.moveTo(0, -radar_area_width*i/20)
				.horiz(ticksMed);
		}
		for (var i=0; i<=4; i+=1) {
			me.alt_scale_marks.moveTo(0, -radar_area_width*i/4)
				.horiz(ticksLong)
		}
		me.alt_scale_texts = [];
		for (var i=1; i<=4; i+=1) {
			me.alt_scale_text = me.alt_scale.createChild("text");
			me.alt_scale_text.enableUpdate();
			me.alt_scale_text.updateText(sprintf("%d", i*4))
				.setFontSize(5, 1.0)
				.setAlignment("left-bottom")
				.setTranslation(ticksMed, -radar_area_width*i/4 - 1)
				.setColor(r,g,b,a);
			append(me.alt_scale_texts, me.alt_scale_text);
		}

		me.alt_cursor = me.alt_scale.createChild("path")
				.moveTo(-1,0)
				.line(-3,3)
				.moveTo(-1,0)
				.line(-3,-3)
				.moveTo(-10,0)
				.horiz(20)
				.setStrokeLineWidth(w)
				.setColor(r,g,b, a);

		# Distance scale (left side)
		me.dist_scale = me.rootCenter.createChild("group")
			.setTranslation(-radar_area_width/2 - 3, radar_area_width/2);
		me.dist_scale_marks = me.dist_scale.createChild("path")
			.moveTo(0, 0).vert(-radar_area_width)
			.setStrokeLineWidth(w)
			.setColor(r,g,b,a);
		for (var i=0; i<=6; i+=1) {
			me.dist_scale_marks.moveTo(0, -radar_area_width*i/6)
				.horiz(-ticksMed);
		}
		me.dist_scale_text_1 = me.dist_scale.createChild("text");
		me.dist_scale_text_1.enableUpdate();
		me.dist_scale_text_1.updateText("5")
			.setFontSize(5, 1.0)
			.setAlignment("right-bottom")
			.setTranslation(-ticksMed, -radar_area_width*1/3-1)
			.setColor(r,g,b,a);
		me.dist_scale_text_2 = me.dist_scale.createChild("text");
		me.dist_scale_text_2.enableUpdate();
		me.dist_scale_text_2.updateText("10")
			.setFontSize(5, 1.0)
			.setAlignment("right-bottom")
			.setTranslation(-ticksMed, -radar_area_width*2/3-1)
			.setColor(r,g,b,a);
		me.dist_scale_text_3 = me.dist_scale.createChild("text");
		me.dist_scale_text_3.enableUpdate();
		me.dist_scale_text_3.updateText("15")
			.setFontSize(5, 1.0)
			# Careful, weird position for the last number
			.setAlignment("left-bottom")
			.setTranslation(0, -radar_area_width*3/3)
			.setColor(r,g,b,a);

		# Heading scale (top side)
		me.heading_scale = me.rootCenter.createChild("group")
			.setTranslation(0, -radar_area_width/2 - 8);
		me.heading_scale.createChild("path")
			# horizontal line
			.moveTo(-radar_area_width/2,0).horiz(radar_area_width)
			# fixed cursor
			.moveTo(0,0).vert(5)
			.moveTo(0,0).line(5,5)
			.moveTo(0,0).line(-5,5)
			.setStrokeLineWidth(w)
			.setColor(r,g,b,a);

		me.heading_scale_large_marks_grp = me.heading_scale.createChild("group");
		me.heading_scale_large_marks = me.heading_scale_large_marks_grp.createChild("path")
			.setStrokeLineWidth(w)
			.setColor(r,g,b,a);
		me.heading_scale_texts = [];
		for (var i=-1; i<=2; i+=1) {
			me.heading_scale_large_marks.moveTo(i*30*heading_deg_to_mm, 0)
				.vert(-ticksLong);
			me.heading_scale_text = me.heading_scale_large_marks_grp.createChild("text");
			me.heading_scale_text.enableUpdate();
			me.heading_scale_text.updateText(sprintf("%.2d", math.mod(3*i, 36)))
				.setFontSize(5, 1.0)
				.setAlignment("center-bottom")
				.setTranslation(i*30*heading_deg_to_mm, -ticksLong)
				.setColor(r,g,b,a);
			append(me.heading_scale_texts, me.heading_scale_text);
		}

		me.heading_scale_small_marks = me.heading_scale.createChild("path")
			.setStrokeLineWidth(w)
			.setColor(r,g,b,a);
		for (var i=-5; i<=6; i+=1) {
			me.heading_scale_small_marks.moveTo(i*10*heading_deg_to_mm, 0)
				.vert(-ticksMed);
		}

		# Center Marker at the bottom of the screen.
		me.rootCenter.createChild("path")
			.moveTo(0, radar_area_width/2)
			.line(5,5)
			.moveTo(0, radar_area_width/2)
			.line(-5,5)
			.setStrokeLineWidth(w)
			.setColor(r,g,b,a);


		# Radar display area
		me.radar_group = me.rootCenter.createChild("group")
			.setTranslation(0, radar_area_width/2);

		me.echoes_group = me.radar_group.createChild("group");
		me.echoes  = [];
		for(var i = 0; i < maxTracks; i += 1) {
			append(me.echoes, me.echoes_group.createChild("path")
				.moveTo(-1,0)
				.horiz(3)
				.setStrokeLineWidth(1.5)
				.setColor(r,g,b,a));
		}

		me.selection = me.echoes_group.createChild("group");
		me.selection_mark = me.selection.createChild("path")
			.moveTo(-4,2).horiz(8)
			.moveTo(-4,-2).horiz(8)
			.moveTo(2,-4).vert(8)
			.moveTo(-2,-4).vert(8)
			.setStrokeLineWidth(w)
			.setColor(r,g,b,a);

		me.selection_heading = me.selection.createChild("group");
		me.selection_speed_vector = me.selection_heading.createChild("path")
			.setTranslation(0,-4)
			.moveTo(0,0).vert(-8)
			.setStrokeLineWidth(2*w)
			.setColor(r,g,b,a);

		me.selection_iff = me.selection.createChild("path")
			.moveTo(-4,-4).lineTo(4,4)
			.moveTo(4,-4).lineTo(-4,4)
			.setStrokeLineWidth(1.5*w)
			.setColor(r,g,b,a);

		# Big dot showing selected target azimuth/elevation
		me.selection_dot_radius = 2;
		me.selection_azi_elev = me.rootCenter.createChild("path")
			.moveTo(me.selection_dot_radius, 0)
			.arcSmallCW(me.selection_dot_radius, me.selection_dot_radius, 0, -me.selection_dot_radius*2, 0)
			.arcSmallCW(me.selection_dot_radius, me.selection_dot_radius, 0, me.selection_dot_radius*2, 0)
			.close()
			.setColorFill(r,g,b,a);

		# Selection cursor
		me.cursor = me.radar_group.createChild("path")
			.moveTo(0,3).vert(8)
			.moveTo(0,-3).vert(-8)
			.moveTo(3,0).horiz(8)
			.moveTo(-3,0).horiz(-8)
			.setStrokeLineWidth(w)
			.setColor(r,g,b,a);

		# IFF a contact under cursor without selecting it.
		me.cursor_iff_time = -10;  # Time of IFF

		me.cursor_iff = me.radar_group.createChild("group") .hide();

		me.cursor_iff_pos = me.cursor_iff.createChild("path")
			.moveTo(-4,-4).lineTo(4,4)
			.moveTo(4,-4).lineTo(-4,4)
			.setStrokeLineWidth(1.5*w)
			.setColor(r,g,b,a);

		me.cursor_iff_neg = me.cursor_iff.createChild("path")
			.moveTo(-2,-2).horiz(4).vert(4).horiz(-4).close()
			.setStrokeLineWidth(w)
			.setColor(r,g,b,a);


		me.a2a_circle_radius = radar_area_width*3/8;
		me.a2a_cross_size = radar_area_width*2/6;
		me.a2a_circle = me.rootCenter.createChild("path")
			.setColor(r,g,b,a)
			.moveTo(-me.a2a_circle_radius, 0)
			.arcLargeCCW(me.a2a_circle_radius, me.a2a_circle_radius, 0, me.a2a_circle_radius, -me.a2a_circle_radius)
			.setStrokeLineWidth(w);
		me.a2a_circle_arc = me.rootCenter.createChild("path")
			.setColor(r,g,b,a)
			.moveTo(-me.a2a_circle_radius, 0)
			.arcSmallCW(me.a2a_circle_radius,me.a2a_circle_radius, 0,  me.a2a_circle_radius,-me.a2a_circle_radius)
			.setStrokeLineWidth(w);
		me.a2a_cross = me.rootCenter.createChild("path")
			.moveTo(-me.a2a_cross_size, me.a2a_cross_size)
			.lineTo(me.a2a_cross_size, -me.a2a_cross_size)
			.moveTo(me.a2a_cross_size, me.a2a_cross_size)
			.lineTo(-me.a2a_cross_size, me.a2a_cross_size)
			.setStrokeLineWidth(w)
			.setColor(r,g,b,a);


		# TYST (silent), bottom of radar area.
		me.text_silent = me.rootCenter.createChild("text");
		me.text_silent.enableUpdate();
		me.text_silent.updateText("")
			.setColor(r,g,b,a)
			.setAlignment("center-bottom")
			.setTranslation(0, radar_area_width/2)
			.setFontSize(13, 1);

		# SIKT (aiming mode), top of radar area.
		me.text_aim = me.rootCenter.createChild("text");
		me.text_aim.enableUpdate();
		me.text_aim.updateText("")
			.setColor(r,g,b,a)
			.setAlignment("center-bottom")
			.setTranslation(0, -radar_area_width/4)
			.setFontSize(13, 1);

		# Target speed/distance/altitude (top text)
		me.target_info = me.rootCenter.createChild("group")
			.setTranslation(0, -radar_area_width/2 - 42);

		me.machT = me.target_info.createChild("text");
		me.machT.enableUpdate();
		me.machT.updateText("M    ")
			.setColor(r,g,b, a)
			.setAlignment("center-top")
			.setTranslation(-radar_area_width/3, 0)
			.setFontSize(9, 1);

		me.distT = me.target_info.createChild("text");
		me.distT.enableUpdate();
		me.distT.updateText("A   ")
			.setColor(r,g,b, a)
			.setAlignment("center-top")
			.setTranslation(0, 0)
			.setFontSize(9, 1);

		me.altT = me.target_info.createChild("text");
		me.altT.enableUpdate();
		me.altT.updateText("H    ")
			.setColor(r,g,b, a)
			.setAlignment("center-top")
			.setTranslation(radar_area_width/3, 0)
			.setFontSize(9, 1);

		me.nameT = me.target_info.createChild("text");
		me.nameT.enableUpdate();
		me.nameT.updateText("")
			.setColor(r,g,b, a)
			.setAlignment("center-top")
			.setTranslation(0, 12)
			.setFontSize(9, 1);

		# QFE, or selected weapon, or Mach
		me.botl_text = me.rootCenter.createChild("text");
		me.botl_text.enableUpdate();
		me.botl_text.updateText("QFE")
			.setColor(r,g,b,a)
			.setAlignment("left-top")
			.setTranslation(-radar_area_width/2 + 5, radar_area_width/2 + 5)
			.setFontSize(9, 1);

		me.ti_msg = me.rootCenter.createChild("text");
		me.ti_msg.enableUpdate();
		me.ti_msg.updateText("MREG")
			.setColor(r,g,b,a)
			.setAlignment("right-top")
			.setTranslation(radar_area_width/2 - 5, radar_area_width/2 + 5)
			.setFontSize(9, 1);

		me.help_text = me.rootCenter.createChild("group")
			.setTranslation(0, height_mm - center_y - 12);

		me.help_text_1 = me.help_text.createChild("text");
		me.help_text_1.enableUpdate();
		me.help_text_1.updateText(" D   -   -  SVY  -   -  BIT LNK")
			.setColor(r,g,b,a)
			.setAlignment("center-bottom")
			.setFontSize(5, 1);

		me.help_text_2 = me.help_text.createChild("text");
		me.help_text_2.enableUpdate();
		me.help_text_2.updateText(" -   -   -  VMI  -  TNF HÄN  - ")
			.setColor(r,g,b,a)
			.setAlignment("center-bottom")
			.setTranslation(0, 7)
			.setFontSize(5, 1);

		me.lnk99_grp = me.rootCenter.createChild("group")
			.setTranslation(0, height_mm - center_y - 12);
		me.lnk99 = [];
		for (var i=0; i<4; i+=1) {
			append(me.lnk99, me.lnk99_grp.createChild("text"));
			me.lnk99[i].enableUpdate();
			me.lnk99[i].updateText("")
				.setColor(r,g,b,a)
				.setFontSize(5, 1)
				.setAlignment("left-bottom")
				.setTranslation((math.mod(i, 2) == 0 ? -35 : 5), (i >= 2 ? 7 : 0));
		}
	},

	########################################################################################################
	########################################################################################################
	#
	#  main loop
	#
	#
	########################################################################################################
	########################################################################################################
	loop: func {
		if (cursorOn == FALSE) {
			radar_logic.unlockSelection();
		}

		if (!displays.common.mi_ti_on) {
			setprop("ja37/avionics/brightness-mi", 0);
			setprop("ja37/avionics/cursor-on", FALSE);

			# Reset state
			mi.cursor_pos = [0,-radar_area_width/2];
			radar_logic.unlockSelection();
			return;
		} else {
			setprop("ja37/avionics/brightness-mi", me.input.brightnessSetting.getValue());
			setprop("ja37/avionics/cursor-on", cursorOn);
		}

		me.radar_range = me.input.radarRange.getValue();
		me.head_true = me.input.headTrue.getValue();

		me.displayAltScale();
		me.displayDistScale();
		me.displayRadarTracks();
		me.displayText();
		me.displayTargetInfo();
		me.displayArmCircle();
	},

	loopFast: func {
		if (!displays.common.mi_ti_on) return;

		me.displayFPI();
		me.displayHorizon();
		me.displayAltLines();
		me.displayDigitalAlt();
		me.displayGround();
		me.displayGroundCollisionArrow();
		me.displayHeadingScale();
		me.displayCursor();
		me.displaySelectionAziElev();
		me.blinkQFE();
	},

	displayFPI: func {
		if (modes.main_ja == modes.LANDING) {
			me.fpi_tail.hide();
		} else {
			me.fpi_tail.show();
		}
	},

	displayHorizon: func {
		me.fpi_x = 0;
		me.fpi_y = 0;
		me.horz_rot.setRotation(-me.input.roll.getValue() * D2R);
		# From manual, movement is proportional to sine, maximum 90mm
		me.horizon_group2.setTranslation(0, math.sin(me.input.fpv_pitch.getValue() * D2R) * 90);
	},

	displayAltLines: func {
		me.showLines = TRUE;
		if (modes.main_ja == modes.LANDING and land.mode != 1 and land.mode != 2) {
			me.showLines = FALSE;
		}
		if (modes.main_ja != modes.TAKEOFF and me.input.alt_m.getValue() > 1000 and me.input.APmode.getValue() != 3) {
			me.showLines = FALSE;
		}
		if (me.input.flash_alt_bars.getBoolValue() and !me.input.twoHz.getBoolValue()) {
			me.showLines = FALSE;
		}

		if (me.showLines) {
			me.desired_lines.show();

			# Minimum displayed reference alt is 200m
			me.alt = me.input.alt_m.getValue();
			me.ref_alt = me.input.ref_alt.getValue();
			me.min_ref_alt = math.max(me.alt/2, me.alt - 300);
			me.max_ref_alt = math.min(me.alt*2, me.alt + 150);
			me.ref_alt = math.clamp(me.ref_alt, me.min_ref_alt, me.max_ref_alt);
			if (me.ref_alt < 200) me.ref_alt = 200;

			# Scale is 12m/mm
			me.desired_lines.setTranslation(0, (me.alt - me.ref_alt) / 12);
			# Bar length scales with reference altitude up to 300m
			me.desired_lines.setScale(1, me.ref_alt <= 300 ? me.ref_alt / 300 : 1);

			# radar altitude
			me.rad_alt = me.input.rad_alt.getValue() * FT2M;
			if (me.input.rad_alt_ready.getBoolValue() and me.rad_alt <= 600) {
				me.rhm_index.show();
				# Scale is 12m/mm
				me.rhm_index.setTranslation(0, me.rad_alt/12);
			} else {
				me.rhm_index.hide();
			}
		} else {
			me.desired_lines.hide();
			me.rhm_index.hide();
		}
	},

	displayDigitalAlt: func {
		me.horizon_alt.updateText(displays.sprintalt(me.input.alt_m.getValue()));
	},

	displayGround: func () {
		me.time = me.input.wow0.getBoolValue() ? 0 : me.input.gpws_time.getValue();
		if (me.time != nil and me.time >= 0 and me.time < 40) {
			me.time = math.clamp(me.time - 10,0,30);
			me.dist = me.time/30 * radar_area_width/2;
			me.ground_grp_trans.setRotation(-me.input.roll.getValue() * D2R);
			me.groundCurve.setTranslation(0, me.dist);
			me.ground_grp.show();
		} else {
			me.ground_grp.hide();
		}
	},

	displayGroundCollisionArrow: func () {
		if (me.input.terrain_warning.getBoolValue()) {
			me.arrow.setRotation(-me.input.roll.getValue() * D2R);
			me.arrow.show();
		} else {
			me.arrow.hide();
		}
	},

	displayAltScale: func {
		me.alt = me.input.alt_m.getValue();
		me.alt_cursor.setTranslation(0, -me.alt/20000*radar_area_width);

		if (displays.metric) {
			for(var i=1; i<=4; i+=1) {
				me.alt_scale_texts[i-1].updateText(sprintf("%d", 5*i));
			}
		} else {
			for(var i=1; i<=4; i+=1) {
				me.alt_scale_texts[i-1].updateText(sprintf("%d", math.round(5*i*M2FT)));
			}
		}
	},

	imperial_range_text: func(dist) {
		return displays.sprintdec(dist, dist>=10 ? 0 : 1);
	},

	displayDistScale: func {
		if (displays.metric) {
			me.radar_displayed_range = me.radar_range * 0.001;
			me.dist_scale_text_1.updateText(sprintf("%d", me.radar_displayed_range/3));
			me.dist_scale_text_2.updateText(sprintf("%d", me.radar_displayed_range*2/3));
			me.dist_scale_text_3.updateText(sprintf("%d", me.radar_displayed_range));
		} else {
			me.radar_displayed_range = me.radar_range * M2NM;
			me.dist_scale_text_1.updateText(me.imperial_range_text(me.radar_displayed_range/3));
			me.dist_scale_text_2.updateText(me.imperial_range_text(me.radar_displayed_range*2/3));
			me.dist_scale_text_3.updateText(me.imperial_range_text(me.radar_displayed_range));
		}
	},

	displayHeadingScale: func () {
		me.heading = me.input.heading.getValue();
		me.large_marks_offset = math.mod(me.heading, 30);
		me.small_marks_offset = math.mod(me.heading, 10);
		me.heading_scale_large_marks_grp.setTranslation(-me.large_marks_offset * heading_deg_to_mm, 0);
		me.heading_scale_small_marks.setTranslation(-me.small_marks_offset * heading_deg_to_mm, 0);

		me.center_mark_text = (me.heading - me.large_marks_offset)/10;
		for (var i=-1; i<=2; i+=1) {
			# offset of 1 for this array
			me.heading_scale_texts[i+1].updateText(sprintf("%.2d", math.mod(me.center_mark_text + 3*i, 36)));
		}
	},

	displayText: func {
		# TYST/SILENT
		if (!me.input.radar_active.getBoolValue()) {
			# radar is off, so silent mode
			me.text_silent.show();
			me.text_silent.updateText(displays.metric ? "TYST" : "SILENT");
		} else {
			me.text_silent.hide();
		}

		# SIKT/AIM
		if (modes.main_ja == modes.AIMING) {
			me.text_aim.updateText(displays.metric ? "SIKT" : "AIM");
			me.text_aim.show();
		} else {
			me.text_aim.hide();
		}

		# Bottom left.
		if (me.input.qfeWarning.getBoolValue()) {
			me.qfe = TRUE;
			me.botl_text.updateText("QFE");
			me.blinkQFE();
		} elsif (fire_control.weapon_ready()) {
			me.qfe = FALSE;
			me.botl_text.updateText(displays.common.armNameShort());
			me.botl_text.show();
		} elsif ((me.mach = me.input.mach.getValue()) > 0.4) {
			me.qfe = FALSE;
			me.botl_text.updateText("M"~displays.sprintdec(me.mach, 2));
			me.botl_text.show();
		} else {
			me.qfe = FALSE;
			me.botl_text.hide();
		}

		# Bottom right
		if (TI.ti.mreg) {
			me.ti_msg.show();
			me.ti_msg.updateText("MREG");
		} elsif (TI.ti.newFails == TRUE) {
			me.ti_msg.show();
			me.ti_msg.updateText(displays.metric ? "FÖ" : "FAIL");
		} else {
			me.ti_msg.hide();
		}

		# Bottom text. Buttons help or Rb 99 telemetry.
		if (helpOn or me.input.timeElapsed.getValue() - me.helpTime < 5) {
			if (displays.metric) {
				me.help_text_1.updateText(" D   -   -  SVY  -   -  BIT LNK");
				me.help_text_2.updateText(" -   -   -  VMI  -  TNF HÄN  - ");
			} else {
				me.help_text_1.updateText(" D   -   -  SDV  -   -  BIT LNK");
				me.help_text_2.updateText(" -   -   -  ECM  -  INN EVN  - ");
			}
			me.help_text.show();
			me.lnk99_grp.hide();
		} elsif (size(me.tele) > 0) {
			me.help_text.hide();
			me.lnk99_grp.show();

			var i = 0;
			forindex (i; me.tele) {
				me.lnk99[i].updateText(sprintf("%2ds %2d%%", math.clamp(me.tele[i][1],-9,99), me.tele[i][0]));
				me.lnk99[i].show();
			}
			i += 1;
			for (; i<4; i+=1) {
				me.lnk99[i].hide();
			}
		} else {
			me.help_text.hide();
			me.lnk99_grp.hide();
		}
	},

	# Separate function with higher refresh rate for blinking.
	blinkQFE: func {
		if (!me.qfe) return;
		me.botl_text.setVisible(me.input.twoHz.getBoolValue());
	},

	displayTargetInfo: func {
		if (radar_logic.selection == nil) {
			me.target_info.hide();
			return;
		}
		me.target_info.show();

		me.tgt_dist = radar_logic.selection.get_range();
		if (displays.metric) {
			me.tgt_dist *= NM2M / 1000;
			me.distT.updateText(sprintf("A%3d", me.tgt_dist));
		} else {
			me.distT.updateText(sprintf("D%3d", me.tgt_dist));
		}

		me.tgt_alt = radar_logic.selection.get_indicated_altitude();
		if (displays.metric) {
			me.tgt_alt *= FT2M;
			me.tgt_alt = math.round(me.tgt_alt, 100);
			me.altT.updateText(sprintf("H%2d,%d", math.floor(me.tgt_alt/1000), math.mod(me.tgt_alt, 1000)/100));
		} else {
			me.tgt_alt = math.round(me.tgt_alt, 100);
			me.altT.updateText(sprintf("A%2d,%d", math.floor(me.tgt_alt/1000), math.mod(me.tgt_alt, 1000)/100));
		}

		me.tgt_speed = radar_logic.selection.get_Speed();
		me.rs = armament.AIM.rho_sndspeed(radar_logic.selection.get_altitude());
		me.sound_fps = me.rs[1];
		me.tgt_mach = me.tgt_speed * KT2FPS / me.sound_fps;
		me.machT.updateText("M"~displays.sprintdec(me.tgt_mach, 2));

		if (me.input.callsign.getBoolValue()) {
			me.nameT.updateText(radar_logic.selection.get_Callsign());
		} else {
			me.nameT.updateText(radar_logic.selection.get_model());
		}
	},

	displayArmCircle: func {
		me.armActive = displays.common.armActive();
		if (me.armActive != nil) {
			me.dlz = me.armActive.getDLZ();
			if (me.dlz != nil and size(me.dlz) > 0) {
				me.dlz_scale = 1;
				me.dlz_full = FALSE;
				me.dlz_circle = FALSE;
				me.dlz_cross  = FALSE;
				if (me.dlz[4] < me.dlz[3]) {
					# MIN
					me.dlz_circle = FALSE;
					me.dlz_cross  = TRUE;
				} elsif (me.dlz[4] < me.dlz[2]) {
					# NEZ
					me.dlz_full   = TRUE;
					me.dlz_scale  = 1;
					me.dlz_circle = TRUE;
				} elsif (me.dlz[4] < me.dlz[1]) {
					# OPT
					me.dlz_full   = FALSE;
					me.dlz_scale  = 1;
					me.dlz_circle = TRUE;
				} elsif (me.dlz[4] < me.dlz[0]) {
					# MISS
					me.dlz_full   = FALSE;
					me.dlz_circle = TRUE;
					me.dlz_scale  = extrapolate(me.dlz[4],me.dlz[1],me.dlz[0],1,0.01);
				} else {
					me.dlz_circle = FALSE;
					me.dlz_cross  = FALSE;
				}
				me.a2a_circle.setScale(me.dlz_scale);
				me.a2a_circle.setStrokeLineWidth(w/me.dlz_scale);
				if (me.dlz_circle == TRUE) {
					me.a2a_circle.show();
					if (me.dlz_full == TRUE) {
						me.a2a_circle_arc.show();
					} else {
						me.a2a_circle_arc.hide();
					}
				} else {
					me.a2a_circle.hide();
					me.a2a_circle_arc.hide();
				}
				if (me.dlz_cross == TRUE) {
					# for now this wont happen, as the missile wont have lock below min dist and therefore wont return dlz info.
					me.a2a_cross.show();
				} else {
					me.a2a_cross.hide();
				}
				return;
			}
		}
		me.a2a_circle.hide();
		me.a2a_circle_arc.hide();
		me.a2a_cross.hide();
	},

	# Convert bearing/distance to position on radar display (in group me.radar_group)
	# bearing is absolute, distance in meter
	bearingDistToRadarPosition: func(bearing, distance) {
		return [geo.normdeg180(bearing - me.head_true) * heading_deg_to_mm,
				-distance/me.radar_range * radar_area_width];
	},

	# Convert a track object to position on radar display (in group me.radar_group)
	trackToRadarPosition: func(track) {
		return me.bearingDistToRadarPosition(track.get_bearing(), track.get_range()*NM2M);
	},

	isInRadarScreen: func(pos) {
		return pos[0] >= -radar_area_width/2 and pos[0] <= radar_area_width/2
			and pos[1] <= 0 and pos[1] >= -radar_area_width;
	},

	displayRadarTrack: func(track) {
		if (me.n_tracks >= maxTracks) return;
		var pos = me.trackToRadarPosition(track);
		if (!me.isInRadarScreen(pos)) return;

		append(me.radar_tracks, track);
		append(me.radar_tracks_pos, pos);
		me.echoes[me.n_tracks].setTranslation(pos[0], pos[1]).show();
		me.n_tracks += 1;

		if (track.get_type() == radar_logic.ORDNANCE) {
			var eta = track.getETA();
			var hit = track.getHitChance();
			if (eta != nil) {
				append(me.tele, [hit, eta]);
			}
		}

		# Rest of the function is for the selected track.
		if (track != radar_logic.selection) return;

		me.selection_updated = TRUE;
		me.selection.setTranslation(pos[0], pos[1]);
		me.selection_heading.setRotation((track.get_heading() - me.head_true) * D2R);
		me.selection_speed_vector.setScale(1, track.get_Speed()/600);
		if (track.getIFF()) {
			me.selection_iff.show();
			me.selection_mark.hide();
		} else {
			me.selection_iff.hide();
			me.selection_mark.show();
		}
		me.selection.show();

		# This indicator is enabled here, not in its own update function
		# because otherwise it shows up before the rest due to higher refresh rate.
		me.selection_azi_elev.show();
	},

	displayRadarTracks: func {
		me.radar_tracks = [];
		me.radar_tracks_pos = [];
		me.n_tracks = 0;

		me.tele = [];

		if (!me.input.radar_active.getBoolValue()) {
			me.echoes_group.hide();
			return;
		}
		me.echoes_group.show();

		me.selection_updated = FALSE;
		foreach (track; radar_logic.tracks) {
			me.displayRadarTrack(track);
		}

		# Hide remaining echoes
		for (var i = me.n_tracks; i < maxTracks; i += 1) me.echoes[i].hide();
		if (!me.selection_updated) {
			me.selection.hide();
		}
	},

	displaySelectionAziElev: func {
		if (radar_logic.selection == nil) {
			me.selection_azi_elev.hide();
			return;
		}

		# 'show()' is not done here but in the displayRadarTracks() loop.
		# Otherwise the different refresh rates make this indicator appear
		# before other selected target indicators, which looks weird.
		#me.selection_azi_elev.show();
		me.sel_pos = radar_logic.selection.get_cartesian();
		me.sel_pos[0] -= me.input.fpv_right.getValue();
		me.sel_pos[1] += me.input.fpv_up.getValue();
		me.sel_pos[0] *= heading_deg_to_mm;
		me.sel_pos[1] *= heading_deg_to_mm;
		me.sel_pos[0] = math.clamp(me.sel_pos[0], -radar_area_width/2, radar_area_width/2);
		me.sel_pos[1] = math.clamp(me.sel_pos[1], -radar_area_width/2, radar_area_width/2);
		me.selection_azi_elev.setTranslation(me.sel_pos[0], me.sel_pos[1]);
	},

	distCursorTrack: func(i) {
		return math.sqrt((me.cursor_pos[0] - me.radar_tracks_pos[i][0]) * (me.cursor_pos[0] - me.radar_tracks_pos[i][0])
						+ (me.cursor_pos[1] - me.radar_tracks_pos[i][1]) * (me.cursor_pos[1] - me.radar_tracks_pos[i][1]));
	},

	findCursorTrack: func() {
		var closest_i = nil;
		var min_dist = 100000;

		for (var i=0; i<me.n_tracks; i+=1) {
			var dist = me.distCursorTrack(i);
			if (dist < min_dist) {
				closest_i = i;
				min_dist = dist;
			}
		}

		if (min_dist < 8) return me.radar_tracks[closest_i];
		else return nil;
	},

	displayCursor: func {
		if (!cursorOn or displays.common.cursor != displays.MI) {
			me.cursor.hide();
			return;
		}

		# Retrieve cursor movement from JSBSim
		me.cursor_mov = displays.common.getCursorDelta();
		displays.common.resetCursorDelta();

		# 1.5 seconds to cover the entire screen.
		me.cursor_pos[0] += me.cursor_mov[0] * radar_area_width * 2/3;
		me.cursor_pos[1] += me.cursor_mov[1] * radar_area_width * 2/3;
		me.cursor_pos[0] = math.clamp(me.cursor_pos[0], -radar_area_width/2, radar_area_width/2);
		me.cursor_pos[1] = math.clamp(me.cursor_pos[1], -radar_area_width, 0);

		me.cursor.show();
		me.cursor.setTranslation(me.cursor_pos[0], me.cursor_pos[1]);

		if (me.cursor_mov[2] and !me.cursorTriggerPrev) {
			var new_sel = me.findCursorTrack();
			if (new_sel != nil) {
				radar_logic.setSelection(new_sel);
			} else {
				radar_logic.unlockSelection();
			}
		} elsif (me.input.cursor_iff.getBoolValue()) {
			me.cursor_iff.hide();
			me.displayCursorIFF(me.findCursorTrack());
		} elsif (me.cursor_iff_time + 2 < me.input.timeElapsed.getValue()) {
			me.cursor_iff.hide();
		}


		me.cursorTriggerPrev = me.cursor_mov[2];
	},

	displayCursorIFF: func(track) {
		if (track == nil) return;
		var pos = me.trackToRadarPosition(track);
		if (!me.isInRadarScreen(pos)) return;

		me.cursor_iff.setTranslation(pos[0], pos[1]).show();

		if (track.getIFF()) {
			me.cursor_iff_pos.show();
			me.cursor_iff_neg.hide();
		} else {
			me.cursor_iff_pos.hide();
			me.cursor_iff_neg.show();
		}

		me.cursor_iff_time = me.input.timeElapsed.getValue();
	},
};

var extrapolate = func (x, x1, x2, y1, y2) {
    return y1 + ((x - x1) / (x2 - x1)) * (y2 - y1);
};

var mi = nil;
