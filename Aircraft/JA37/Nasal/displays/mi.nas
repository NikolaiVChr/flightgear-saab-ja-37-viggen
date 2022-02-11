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

var max_contacts = 16;  # max nb of aircrafts for which radar echoes can be displayed
var max_tracks = 4;     # max nb of tracked aircrafts in TWS

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

var cursor = func {}


var MI = {

	new: func {
	  	var mi = { parents: [MI] };
	  	mi.input = {
			APmode:               "fdm/jsbsim/autoflight/mode",
			alt_m:                "instrumentation/altimeter/indicated-altitude-meter",
			alt_ft:               "instrumentation/altimeter/indicated-altitude-ft",
			alt_true_ft:          "position/altitude-ft",
			brightnessSetting:    "ja37/avionics/brightness-mi-knob",
			flash_alt_bars:       "fdm/jsbsim/systems/indicators/flashing-alt-bars",
			heading:              "instrumentation/heading-indicator/indicated-heading-deg",
			hydrPressure:         "fdm/jsbsim/systems/hydraulics/system1/pressure",
			rad_alt:              "instrumentation/radar-altimeter/radar-altitude-ft",
			rad_alt_ready:        "instrumentation/radar-altimeter/ready",
			radar_stby:           "instrumentation/radar/radar-standby",
			ref_alt:              "ja37/displays/reference-altitude-m",
			roll:                 "instrumentation/attitude-indicator/indicated-roll-deg",
			timeElapsed:          "sim/time/elapsed-sec",
			headTrue:             "orientation/heading-deg",
			fpv_pitch:            "instrumentation/fpv/pitch-deg",
			fpv_up:               "instrumentation/fpv/angle-up-deg",
			fpv_right:            "instrumentation/fpv/angle-right-deg",
			twoHz:                "ja37/blink/two-Hz/state",
			hdgReal:              "orientation/heading-deg",
			terrain_warning:      "/instrumentation/terrain-warning",
			gpws_time:            "fdm/jsbsim/systems/indicators/time-till-crash",
			radar_serv:           "instrumentation/radar/serviceable",
			twoHz:                "ja37/blink/two-Hz/state",
			qfeWarning:           "ja37/displays/qfe-warning",
			qnhMode:              "ja37/hud/qnh-mode",
			alphaJSB:             "fdm/jsbsim/aero/alpha-deg",
			mach:                 "instrumentation/airspeed-indicator/indicated-mach",
			wow0:                 "fdm/jsbsim/gear/unit[0]/WOW",
			flares_n:             "ai/submodels/submodel[0]/count",
			msl_warn_light:       "instrumentation/rwr/ja-lights",
		};

		foreach(var name; keys(mi.input)) {
			mi.input[name] = props.globals.getNode(mi.input[name], 1);
		}

		mi.setupCanvasSymbols();

		mi.helpTime = -5;
		mi.cursor_pos = [0,-radar_area_width/2];
		mi.cursorTriggerPrev = FALSE;
		# cursor position used by TI
		mi.cursor_azi = 0;
		mi.cursor_range = 30000;
		mi.cursor_shown = TRUE;

		mi.radar_range = radar.ps46.currentMode.getRangeM();
		mi.head_true = mi.input.headTrue.getValue();
		mi.time = mi.input.timeElapsed.getValue();
		# Add to convert true alt -> indicated alt
		mi.indicated_alt_offset_ft = (mi.input.alt_ft.getValue() - mi.input.alt_true_ft.getValue()) * FT2M;
		mi.qfe = FALSE;
		mi.n_contacts = 0;

		return mi;
	},

	# Converts azimuth/radar range to coordinates in radar group.
	# Returns nil if outside of radar display area bounds.
	azi_range_to_radar_pos: func(azimuth, range, radar_range) {
		var pos = [
			azimuth * heading_deg_to_mm,
			- range / radar_range * radar_area_width
		];
		if (pos[0] < -radar_area_width/2 or pos[0] > radar_area_width/2
			or pos[1] > 0 or pos[1] < -radar_area_width)
			return nil;
		else
			return pos;
	},

	# Trail of radar echoes corresponding to a contact.
	ContactEchoes: {
		max_echoes: 12,

		new: func(radar_grp) {
			var e = { parents: [MI.ContactEchoes], parent: radar_grp, };
			e.init();
			return e;
		},

		init: func {
			me.grp = me.parent.createChild("group");

			me.echoes = [];
			for (var i=0; i<me.max_echoes; i+=1) {
				append(me.echoes, me.grp.createChild("path")
					.moveTo(-1,0).horizTo(1)
					.setStrokeLineWidth(1)
					.setColor(r,g,b,a));
			}

			me.iff = me.grp.createChild("path")
				.moveTo(-3,-3).lineTo(3,3)
				.moveTo(-3,3).lineTo(3,-3)
				.setStrokeLineWidth(1.5*w)
				.setColor(r,g,b,a);
		},

		hide: func {
			me.grp.hide();
		},

		display_iff: func(contact, radar_range) {
			if (radar.test_iff(contact) <= 0) {
				me.iff.hide();
				return;
			}

			var info = contact.getLastBlep();
			var pos = MI.azi_range_to_radar_pos(info.getAZDeviation(), info.getRangeNow(), radar_range);
			if (pos == nil) {
				me.iff.hide();
				return;
			}

			me.iff.setTranslation(pos[0], pos[1]);
			me.iff.show();
		},

		display: func(contact, radar_range, current_time) {
			var echoes = contact.getBleps();
			var n_echoes = size(echoes);

			var max_echo_time = radar.ps46.currentMode.timeToFadeBleps;

			if (n_echoes == 0 or current_time - echoes[n_echoes-1].getBlepTime() > max_echo_time) {
				me.hide();
				return FALSE;
			}

			for (var i=0; i<me.max_echoes; i+=1) {
				if (i >= n_echoes) {
					me.echoes[i].hide();
					continue;
				}

				var info = echoes[n_echoes-i-1];
				if (current_time - info.getBlepTime() > max_echo_time) {
					me.echoes[i].hide();
					continue;
				}

				var pos = MI.azi_range_to_radar_pos(info.getAZDeviation(), info.getRangeNow(), radar_range);
				if (pos == nil) {
					me.echoes[i].hide();
					continue;
				}

				me.echoes[i].setTranslation(pos[0], pos[1]);
				var strength = 1 - (current_time - info.getBlepTime()) / max_echo_time;
				strength = math.pow(strength, 1.6);
				me.echoes[i].setColor(r,g,b,a*strength);
				me.echoes[i].show();
			}

			me.display_iff(contact, radar_range);
			me.grp.show();
			return TRUE;
		},
	},

	# Tracking symbology (TWS and STT)
	ContactTrack: {
		new: func(radar_grp) {
			var c = { parents: [MI.ContactTrack], parent: radar_grp, };
			c.init();
			return c;
		},

		init: func {
			me.grp = me.parent.createChild("group");

			me.primary = me.grp.createChild("path")
				.moveTo(-4,2).horiz(8)
				.moveTo(-4,-2).horiz(8)
				.moveTo(2,-4).vert(8)
				.moveTo(-2,-4).vert(8)
				.setStrokeLineWidth(w)
				.setColor(r,g,b,a);

			me.primary_lost = me.grp.createChild("path")
				.moveTo(-4,-4).lineTo(-4,4).lineTo(4,4).lineTo(4,-4).close()
				.setStrokeLineWidth(w)
				.setColor(r,g,b,a);

			me.secondary = me.grp.createChild("path")
				.moveTo(4,2).lineTo(2,2).lineTo(2,4)
				.moveTo(-4,2).lineTo(-2,2).lineTo(-2,4)
				.moveTo(4,-2).lineTo(2,-2).lineTo(2,-4)
				.moveTo(-4,-2).lineTo(-2,-2).lineTo(-2,-4)
				.setStrokeLineWidth(w)
				.setColor(r,g,b,a);

			me.secondary_lost = me.grp.createChild("path")
				.moveTo(4,2).lineTo(4,4).lineTo(2,4)
				.moveTo(-4,2).lineTo(-4,4).lineTo(-2,4)
				.moveTo(4,-2).lineTo(4,-4).lineTo(2,-4)
				.moveTo(-4,-2).lineTo(-4,-4).lineTo(-2,-4)
				.setStrokeLineWidth(w)
				.setColor(r,g,b,a);

			me.track = me.grp.createChild("path")
				.setStrokeLineWidth(2*w)
				.setColor(r,g,b,a);
		},

		hide: func {
			me.grp.hide();
		},

		display: func (contact, radar_range, current_time, head_true) {
			var info = contact.getLastBlep();
			if (info == nil) {
				me.hide();
				return FALSE;
			}

			var pos = MI.azi_range_to_radar_pos(info.getAZDeviation(), info.getRangeNow(), radar_range);
			if (pos == nil) {
				me.hide();
				return FALSE;
			}
			me.grp.setTranslation(pos[0], pos[1]);

			var tracking = info.hasTrackInfo()
				and current_time - info.getBlepTime() < radar.ps46.currentMode.timeToFadeBleps;
			var primary = radar.ps46.isPrimary(contact);

			me.primary.setVisible(primary and tracking);
			me.primary_lost.setVisible(primary and !tracking);
			me.secondary.setVisible(!primary and tracking);
			me.secondary_lost.setVisible(!primary and !tracking);

			if (tracking) {
				me.track.setRotation((contact.getHeading() - head_true) * D2R);
				me.track.reset();
				me.track.moveTo(0,-4).vert(-info.getSpeed() / 75);
				me.track.show();
			} else {
				me.track.hide();
			}

			me.grp.show();

			return TRUE;
		},
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

		me.horizon_alt = me.horizon_group2.createChild("group")
			.setTranslation(-0.36*radar_area_width, -2);
		# text for metric mode, and interoperability values below 1000
		me.horizon_alt1 = me.horizon_alt.createChild("text");
		me.horizon_alt1.enableUpdate();
		me.horizon_alt1.updateText("-000")
			.setFontSize(7, 1.0)
			.setAlignment("right-baseline")
			.setTranslation(0.08*radar_area_width, 0)
			.setColor(r,g,b,a);
		# text for interoperability mode above 1000, first two digits
		me.horizon_alt2 = me.horizon_alt.createChild("text");
		me.horizon_alt2.enableUpdate();
		me.horizon_alt2.updateText("0,0")
			.setFontSize(7, 1.0)
			.setAlignment("right-baseline")
			.setTranslation(0, 0)
			.setColor(r,g,b,a);
		# text for interoperability mode above 1000, last three digits
		me.horizon_alt3 = me.horizon_alt.createChild("text");
		me.horizon_alt3.enableUpdate();
		me.horizon_alt3.updateText("000")
			.setFontSize(5, 1.0)
			.setAlignment("left-baseline")
			.setTranslation(0, 0)
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

		me.alt_scale_metric = me.alt_scale.createChild("group");
		me.alt_scale_marks = me.alt_scale_metric.createChild("path")
			.setStrokeLineWidth(w)
			.setColor(r,g,b,a);
		for (var i=1; i<=19; i+=1) {
			if (math.mod(i, 5) == 0) continue;
			me.alt_scale_marks.moveTo(0, -radar_area_width*i/20)
				.horiz(ticksMed);
		}
		me.alt_scale_text = [];
		for (var i=0; i<=4; i+=1) {
			me.alt_scale_marks.moveTo(0, -radar_area_width*i/4)
				.horiz(ticksLong);

			if (i == 0) continue;
			var text = me.alt_scale_metric.createChild("text");
			text.enableUpdate();
			text.updateText(sprintf("%d", i*5))
				.setFontSize(5, 1.0)
				.setAlignment("left-bottom")
				.setTranslation(ticksMed, -radar_area_width*i/4 - 1)
				.setColor(r,g,b,a);
			append(me.alt_scale_text, text);
		}

		me.alt_cursor = me.alt_scale.createChild("path")
			.moveTo(-1,0)
			.line(-3,3)
			.moveTo(-1,0)
			.line(-3,-3)
			.moveTo(-10,0)
			.horiz(20)
			.setStrokeLineWidth(w)
			.setColor(r,g,b,a);

		me.alt_tgt_index = me.alt_scale.createChild("path")
			.moveTo(ticksMed, 0)
			.horiz(ticksMed)
			.setStrokeLineWidth(3*w)
			.setColor(r,g,b,a);

		me.scan_height_line = me.alt_scale.createChild("path")
			.setTranslation(ticksMed, 0)
			.setStrokeLineWidth(3*w)
			.setColor(r,g,b,a);

		me.cmd_alt_index = me.alt_scale.createChild("path")
			.moveTo(ticksMed, 0)
			.arcSmallCW(ticksLong*0.5, ticksLong*0.5, 0, ticksLong, 0)
			.arcSmallCW(ticksLong*0.5, ticksLong*0.5, 0, -ticksLong, 0)
			.setStrokeLineWidth(1.5*w)
			.setColor(r,g,b,a);

		# Interoperability altitude scale
		me.alt_scale_int = me.alt_scale.createChild("group");
		# Scale is slightly shorter than metric one, as it goes up to 60000ft instead of 20km.
		me.alt_scale_int_size = radar_area_width * FT2M * 60 / 20;
		me.alt_scale_int_marks = me.alt_scale_int.createChild("path")
			.setStrokeLineWidth(w)
			.setColor(r,g,b,a);
		me.alt_scale_int_text = [];
		# Only 6 marks, all with text
		for (var i=0; i<=6; i+=1) {
			me.alt_scale_int_marks.moveTo(0, -me.alt_scale_int_size*i/6)
				.horiz(ticksLong);

			if (i == 0) continue;
			var text = me.alt_scale_int.createChild("text");
			text.enableUpdate();
			text.updateText(sprintf("%d0", i))
				.setFontSize(5, 1.0)
				.setAlignment("left-bottom")
				.setTranslation(ticksMed, -me.alt_scale_int_size*i/6 - 1)
				.setColor(r,g,b,a);
			append(me.alt_scale_text, text);
		}

		# Distance scale (left side)
		me.dist_scale = me.rootCenter.createChild("group")
			.setTranslation(-radar_area_width/2 - 3, radar_area_width/2);

		me.dist_scale_metric = me.dist_scale.createChild("group");
		me.dist_scale_marks = me.dist_scale_metric.createChild("path")
			.moveTo(0, 0).vert(-radar_area_width)
			.setStrokeLineWidth(w)
			.setColor(r,g,b,a);
		for (var i=0; i<=6; i+=1) {
			me.dist_scale_marks.moveTo(0, -radar_area_width*i/6)
				.horiz(-ticksMed);
		}
		me.dist_scale_text_1 = me.dist_scale_metric.createChild("text");
		me.dist_scale_text_1.enableUpdate();
		me.dist_scale_text_1.updateText("5")
			.setFontSize(5, 1.0)
			.setAlignment("right-bottom")
			.setTranslation(-ticksMed, -radar_area_width*1/3-1)
			.setColor(r,g,b,a);
		me.dist_scale_text_2 = me.dist_scale_metric.createChild("text");
		me.dist_scale_text_2.enableUpdate();
		me.dist_scale_text_2.updateText("10")
			.setFontSize(5, 1.0)
			.setAlignment("right-bottom")
			.setTranslation(-ticksMed, -radar_area_width*2/3-1)
			.setColor(r,g,b,a);
		me.dist_scale_text_3 = me.dist_scale_metric.createChild("text");
		me.dist_scale_text_3.enableUpdate();
		me.dist_scale_text_3.updateText("15")
			.setFontSize(5, 1.0)
			# Careful, weird position for the last number
			.setAlignment("left-bottom")
			.setTranslation(0, -radar_area_width*3/3)
			.setColor(r,g,b,a);

		# Interoperability distance scale
		me.dist_scale_int = me.dist_scale.createChild("group");
		# Scale is slightly shorter than metric one, as it goes up to 64nm instead of 120Km
		me.dist_scale_int_size = radar_area_width * NM2M * 64 / 120000;
		me.dist_scale_int_marks = me.dist_scale_int.createChild("path")
			.moveTo(0, 0).vert(-me.dist_scale_int_size)
			.setStrokeLineWidth(w)
			.setColor(r,g,b,a);
		me.dist_scale_int_text = [];
		# Only 4 marks, all with text
		for (var i=0; i<=4; i+=1) {
			me.dist_scale_int_marks.moveTo(0, -me.dist_scale_int_size*i/4)
				.horiz(-ticksMed);
			var text = me.dist_scale_int.createChild("text");
			text.enableUpdate();
			text.updateText(2*i)
				.setFontSize(5, 1.0)
				.setAlignment("right-bottom")
				.setTranslation(-ticksMed, -me.dist_scale_int_size*i/4 - 1)
				.setColor(r,g,b,a);
			append(me.dist_scale_int_text, text);
		}

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

		me.heading_index = me.heading_scale.createChild("path")
			.setStrokeLineWidth(ticksMed)
			.moveTo(0,-ticksMed).vert(2*ticksMed)
			.setColor(r,g,b,a);

		# Radar display area
		me.radar_group = me.rootCenter.createChild("group")
			.setTranslation(0, radar_area_width/2);

		# Center Marker at the bottom of the screen.
		me.radar_group.createChild("path")
			.moveTo(0,0)
			.line(5,5)
			.moveTo(0,0)
			.line(-5,5)
			.setStrokeLineWidth(w)
			.setColor(r,g,b,a);

		# Top and bottom lines indicating search width
		me.scan_width_line_bot = me.radar_group.createChild("path")
			.setStrokeLineWidth(1.5*w)
			.setColor(r,g,b,a);
		me.scan_width_line_top = me.radar_group.createChild("path")
			.setTranslation(0, -radar_area_width)
			.setStrokeLineWidth(1.5*w)
			.setColor(r,g,b,a);

		me.scan_sweep_mark = me.radar_group.createChild("path")
			.moveTo(0,0).vert(-10)
			.setStrokeLineWidth(1.5*w)
			.setColor(r,g,b,a);

		me.dlz_grp = me.radar_group.createChild("group");

		me.dlz_bot_left = me.dlz_grp.createChild("path")
			.moveTo(0,-2.5).vert(2.5).horiz(5)
			.setStrokeLineWidth(1.5*w)
			.setColor(r,g,b,a);
		me.dlz_bot_right = me.dlz_grp.createChild("path")
			.moveTo(0,-2.5).vert(2.5).horiz(-5)
			.setStrokeLineWidth(1.5*w)
			.setColor(r,g,b,a);
		me.dlz_top_left = me.dlz_grp.createChild("path")
			.moveTo(0,2.5).vert(-2.5).horiz(5)
			.setStrokeLineWidth(1.5*w)
			.setColor(r,g,b,a);
		me.dlz_top_right = me.dlz_grp.createChild("path")
			.moveTo(0,2.5).vert(-2.5).horiz(-5)
			.setStrokeLineWidth(1.5*w)
			.setColor(r,g,b,a);


		me.echoes_group = me.radar_group.createChild("group");
		me.echoes = [];
		for(var i = 0; i < max_contacts; i += 1) {
			append(me.echoes, me.ContactEchoes.new(me.echoes_group));
		}
		me.tracks = [];
		for(var i = 0; i < max_tracks; i += 1) {
			append(me.tracks, me.ContactTrack.new(me.echoes_group));
		}

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
			.moveTo(-5,5).lineTo(0,0).lineTo(5,5)
			.setStrokeLineWidth(1.5*w)
			.setColor(r,g,b,a);

		# TI selection
		me.cmd_circle = me.radar_group.createChild("path")
			.moveTo(-5,0)
			.arcSmallCW(5,5,0,10,0)
			.arcSmallCW(5,5,0,-10,0)
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
			.setTranslation(0, radar_area_width/2 - 2)
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
		me.machT.updateText("0,00")
			.setColor(r,g,b, a)
			.setAlignment("left-baseline")
			.setTranslation(-0.45*radar_area_width, 10)
			.setFontSize(9, 1);

		me.target_info_metric = me.target_info.createChild("group");
		me.target_info_metric.createChild("text")
			.setText("M")
			.setColor(r,g,b, a)
			.setAlignment("right-baseline")
			.setTranslation(-0.45*radar_area_width, 10)
			.setFontSize(9, 1);
		me.target_info_metric.createChild("text")
			.setText("A")
			.setColor(r,g,b, a)
			.setAlignment("right-baseline")
			.setTranslation(-0.1*radar_area_width, 10)
			.setFontSize(9, 1);
		me.target_info_metric.createChild("text")
			.setText("H")
			.setColor(r,g,b, a)
			.setAlignment("right-baseline")
			.setTranslation(0.25*radar_area_width, 10)
			.setFontSize(9, 1);
		me.distT = me.target_info_metric.createChild("text");
		me.distT.enableUpdate();
		me.distT.updateText("000")
			.setColor(r,g,b, a)
			.setAlignment("left-baseline")
			.setTranslation(-0.1*radar_area_width, 10)
			.setFontSize(9, 1);
		me.altT = me.target_info_metric.createChild("text");
		me.altT.enableUpdate();
		me.altT.updateText("00,0")
			.setColor(r,g,b, a)
			.setAlignment("left-baseline")
			.setTranslation(0.25*radar_area_width, 10)
			.setFontSize(9, 1);

		me.target_info_int = me.target_info.createChild("group");
		me.target_info_int.createChild("text")
			.setText("M")
			.setColor(r,g,b, a)
			.setAlignment("right-baseline")
			.setTranslation(-0.45*radar_area_width, 10)
			.setFontSize(6, 1);
		me.target_info_int.createChild("text")
			.setText("NM")
			.setColor(r,g,b, a)
			.setAlignment("right-baseline")
			.setTranslation(-0.1*radar_area_width, 10)
			.setFontSize(6, 1);
		me.target_info_int.createChild("text")
			.setText("FT")
			.setColor(r,g,b, a)
			.setAlignment("right-baseline")
			.setTranslation(0.25*radar_area_width, 10)
			.setFontSize(6, 1);
		me.distT_int = me.target_info_int.createChild("text");
		me.distT_int.enableUpdate();
		me.distT_int.updateText("000")
			.setColor(r,g,b, a)
			.setAlignment("left-baseline")
			.setTranslation(-0.1*radar_area_width, 10)
			.setFontSize(9, 1);
		me.altT_int = me.target_info_int.createChild("text");
		me.altT_int.enableUpdate();
		me.altT_int.updateText("000")
			.setColor(r,g,b, a)
			.setAlignment("left-baseline")
			.setTranslation(0.25*radar_area_width, 10)
			.setFontSize(9, 1);
		me.altT_int2 = me.target_info_int.createChild("text");
		me.altT_int2.enableUpdate();
		me.altT_int2.updateText("000")
			.setColor(r,g,b, a)
			.setAlignment("left-baseline")
			.setTranslation(0.37*radar_area_width, 10)
			.setFontSize(6, 1);

		# QFE, or selected weapon, or Mach
		me.botl_text = me.rootCenter.createChild("text");
		me.botl_text.enableUpdate();
		me.botl_text.updateText("QFE")
			.setColor(r,g,b,a)
			.setAlignment("right-top")
			.setTranslation(radar_area_width * -0.3, radar_area_width/2 + 4)
			.setFontSize(8, 1);

		me.ti_msg = me.rootCenter.createChild("text");
		me.ti_msg.enableUpdate();
		me.ti_msg.updateText("MREG")
			.setColor(r,g,b,a)
			.setAlignment("left-top")
			.setTranslation(radar_area_width * 0.3, radar_area_width/2 + 4)
			.setFontSize(8, 1);

		me.help_text = me.rootCenter.createChild("group")
			.setTranslation(0, height_mm - center_y - 5);

		me.help_text_1 = me.help_text.createChild("text");
		me.help_text_1.enableUpdate();
		me.help_text_1.updateText(" D   -   -  SVY  -   -  BIT LNK")
			.setColor(r,g,b,a)
			.setAlignment("center-bottom")
			.setTranslation(0, -7)
			.setFontSize(5, 1);

		me.help_text_2 = me.help_text.createChild("text");
		me.help_text_2.enableUpdate();
		me.help_text_2.updateText(" -   -   -  VMI  -  TNF HÄN  - ")
			.setColor(r,g,b,a)
			.setAlignment("center-bottom")
			.setFontSize(5, 1);

		me.lnk99_grp = me.rootCenter.createChild("group")
			.setTranslation(0, height_mm - center_y - 5);
		me.lnk99 = [];
		for (var i=0; i<4; i+=1) {
			append(me.lnk99, me.lnk99_grp.createChild("text"));
			me.lnk99[i].enableUpdate();
			me.lnk99[i].updateText("10s99%")
				.setColor(r,g,b,a)
				.setFontSize(5, 1)
				.setAlignment("left-bottom")
				.setTranslation((math.mod(i, 2) == 0 ? 10 : 30), (i >= 2 ? 0 : -8));
		}

		me.flares_grp = me.rootCenter.createChild("group")
			.setTranslation(0, height_mm - center_y - 5);
		me.flares = me.flares_grp.createChild("text");
		me.flares.enableUpdate();
		me.flares.updateText("F2  48")
			.setColor(r,g,b,a)
			.setTranslation(-45, -8)
			.setAlignment("left-bottom")
			.setFontSize(8, 1);
		me.chaff = me.flares_grp.createChild("text");
		me.chaff.enableUpdate();
		me.chaff.updateText("R2  320")
			.setColor(r,g,b,a)
			.setTranslation(-45, 0)
			.setAlignment("left-bottom")
			.setFontSize(8, 1);

		me.rwr_cross_grp = me.rootCenter.createChild("group")
			.setTranslation(0, height_mm - center_y - 12);
		me.rwr_cross_grp.createChild("path")
			.moveTo(0,-7).vertTo(7)
			.moveTo(-7,0).horizTo(7)
			.setStrokeLineWidth(w)
			.setColor(r,g,b,a);
		me.rwr_cross = [];
		for (var i=0; i<4; i+=1) {
			append(me.rwr_cross, me.rwr_cross_grp.createChild("text")
				.setText("M")
				.setColor(r,g,b,a)
				.setFontSize(8,1)
				.setAlignment("center-center")
				.setTranslation(
					i <= 1 ? 3.5 : -3.5,
					(i == 1 or i == 2) ? 3.5 : -3.5,
				)
			);
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
		if (!displays.common.mi_ti_on) {
			setprop("ja37/avionics/brightness-mi", 0);

			# Reset state
			mi.cursor_pos = [0,-radar_area_width/2];
			return;
		} else {
			setprop("ja37/avionics/brightness-mi", me.input.brightnessSetting.getValue());
		}

		me.radar_range = radar.ps46.getRangeM();
		me.current_time = me.input.timeElapsed.getValue();
		me.head_true = me.input.headTrue.getValue();
		me.indicated_alt_offset_ft = me.input.alt_ft.getValue() - me.input.alt_true_ft.getValue();

		me.displayAltScale();
		me.displayDistScale();
		me.displayText();
		if (radar.ps46.getMode() != "STT") {
			me.displayRadarTracks();
			me.displayTargetInfo();
			me.displayTargetAziElev();
		}
		me.displayCommandTarget();
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
		me.displayScanInfo();
		me.displayDLZ();
		if (radar.ps46.getMode() == "STT") {
			# Faster update in STT mode (affordable since there should be only one contact to show)
			me.displayRadarTracks();
			me.displayTargetInfo();
			me.displayTargetAziElev();
		}
		me.displayCursor();
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
		var alt = me.input.alt_m.getValue();
		if (displays.metric) {
			alt = math.round(alt, 10);
			if (alt <= 990) {
				alt = math.max(alt, -50);
				me.horizon_alt1.updateText(sprintf("%.3d", alt));
				me.horizon_alt2.updateText("");
				me.horizon_alt3.updateText("");
			} else {
				alt = math.round(alt, 100) / 1000;
				me.horizon_alt1.updateText(displays.sprintdec(alt, 1));
				me.horizon_alt2.updateText("");
				me.horizon_alt3.updateText("");
			}
		} else {
			alt *= M2FT;
			alt = math.round(alt, 10);
			if (alt <= 990) {
				alt = math.max(alt, -50);
				me.horizon_alt1.updateText(sprintf("%.3d", alt));
				me.horizon_alt2.updateText("");
				me.horizon_alt3.updateText("");
			} else {
				alt = math.round(alt, 100);
				me.horizon_alt1.updateText("");
				me.horizon_alt2.updateText(sprintf("%2d", math.floor(alt/1000)));
				me.horizon_alt3.updateText(sprintf("%.3d", math.mod(alt, 1000)));
			}
		}
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
		if (me.alt >= 0 and me.alt <= 20000) {
			me.alt_cursor.setTranslation(0, -me.alt/20000*radar_area_width);
			me.alt_cursor.show();
		} else {
			me.alt_cursor.hide();
		}

		me.alt_scale_metric.setVisible(displays.metric);
		me.alt_scale_int.setVisible(!displays.metric);
	},

	displayDistScale: func {
		if (displays.metric) {
			me.dist_scale_metric.show();
			me.dist_scale_int.hide();

			me.radar_displayed_range = me.radar_range * 0.001;
			me.dist_scale_text_1.updateText(sprintf("%d", me.radar_displayed_range/3));
			me.dist_scale_text_2.updateText(sprintf("%d", me.radar_displayed_range*2/3));
			me.dist_scale_text_3.updateText(sprintf("%d", me.radar_displayed_range));
		} else {
			me.dist_scale_metric.hide();
			me.dist_scale_int.show();

			me.radar_displayed_range = math.floor(me.radar_range * M2NM);
			for (var i=1; i<=4; i+=1) {
				me.dist_scale_int_text[i].updateText(sprintf("%d", me.radar_displayed_range*i/4));
			}
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

		if (displays.common.heading != nil) {
			var pos = geo.normdeg180(displays.common.heading - me.heading);
			pos = math.clamp(pos, -60, 60);
			pos *= heading_deg_to_mm;
			me.heading_index.setTranslation(pos, 0);
			me.heading_index.show();
		} else {
			me.heading_index.hide();
		}

	},

	displayText: func {
		# TYST/SILENT
		if (me.input.radar_stby.getBoolValue()) {
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
			me.botl_text.updateText((!displays.metric and me.input.qnhMode.getBoolValue()) ? "QNH" : "QFE");
			me.blinkQFE();
		} elsif (fire_control.weapon_ready()) {
			me.qfe = FALSE;
			me.botl_text.updateText(displays.common.armNameMedium());
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

		# Bottom text. Buttons help or Rb 99 telemetry + flares / chaff.
		me.rb99_list = radar.rb99_datalink.getMissileList();

		if (helpOn or me.input.timeElapsed.getValue() - me.helpTime < 5) {
			if (displays.metric) {
				me.help_text_1.updateText(" D   -   -  SVY  -   -  BIT LNK");
				me.help_text_2.updateText(" -   -   -  VMI  -  TNF HÄN  - ");
			} else {
				me.help_text_1.updateText(" D   -   -  SDV  -   -  BIT LNK");
				me.help_text_2.updateText(" -   -   -  RWR  -  INN EVN  - ");
			}
			me.help_text.show();
			me.flares_grp.hide();
			me.rwr_cross_grp.hide();
			me.lnk99_grp.hide();
		} else {
			me.help_text.hide();

			me.flares.updateText(sprintf("F2  %2d", me.input.flares_n.getValue()));
			me.chaff.updateText(sprintf("%s2  %3d", displays.metric ? "R" : "C", me.input.flares_n.getValue() * 6));
			me.flares_grp.show();

			forindex (var i; me.rwr_cross) {
				me.rwr_cross[i].setVisible(me.input.msl_warn_light.getChild("sector", i, 1).getBoolValue());
			}
			me.rwr_cross_grp.show();

			if (size(me.rb99_list) > 0) {
				me.lnk99_grp.show();

				var i = 0;
				forindex (i; me.rb99_list) {
					if (i >= 4) break; # could happen with reloading in air
					me.lnk99[i].updateText(radar.rb99_datalink.display_str(me.rb99_list[i]));
					me.lnk99[i].show();
				}
				i += 1;
				for (; i<4; i+=1) {
					me.lnk99[i].hide();
				}
			} else {
				me.lnk99_grp.hide();
			}
		}
	},

	# Separate function with higher refresh rate for blinking.
	blinkQFE: func {
		if (!me.qfe) return;
		me.botl_text.setVisible(me.input.twoHz.getBoolValue());
	},

	displayTargetInfo: func {
		if ((var target = radar.ps46.getPriorityTarget()) == nil
			or (var info = target.getLastBlep()) == nil
			or !info.hasTrackInfo())
		{
			me.target_info.hide();
			return;
		}

		me.target_info.show();
		me.target_info_metric.setVisible(displays.metric);
		me.target_info_int.setVisible(!displays.metric);

		me.tgt_speed = info.getSpeed();
		me.tgt_alt = info.getAltitude();
		if (me.tgt_speed != nil and me.tgt_alt != nil) {
			me.rs = armament.AIM.rho_sndspeed(me.tgt_alt);
			me.sound_fps = me.rs[1];
			me.tgt_mach = me.tgt_speed * KT2FPS / me.sound_fps;
			me.machT.updateText(displays.sprintdec(me.tgt_mach, 2));
			me.machT.show();
		} else {
			me.machT.hide();
		}

		me.tgt_dist = info.getRangeNow();
		if (me.tgt_dist != nil) {
			if (displays.metric) {
				me.tgt_dist /= 1000;
				me.tgt_dist = math.min(me.tgt_dist, 999);
				me.distT.updateText(sprintf("%3d", me.tgt_dist));
				me.distT.show();
			} else {
				me.tgt_dist *= M2NM;
				me.tgt_dist = math.min(me.tgt_dist, 999);
				if (me.tgt_dist <= 9.95) {
					me.distT_int.updateText(" "~displays.sprintdec(me.tgt_dist, 1));
				} else {
					me.distT_int.updateText(sprintf("%3d", me.tgt_dist));
				}
				me.distT_int.show();
			}
		} else {
			me.distT.hide();
			me.distT_int.hide();
		}

		me.tgt_alt = info.getAltitude();
		if (me.tgt_alt != nil) {
			# convert relative to indicated altitude
			me.tgt_alt += me.indicated_alt_offset_ft;
			me.tgt_alt = math.max(me.tgt_alt, 0);
			if (displays.metric) {
				me.tgt_alt *= FT2M;
				me.tgt_alt = math.round(me.tgt_alt, 100);
				if (me.tgt_alt <= 900) {
					me.altT.updateText(sprintf("%3d", me.tgt_alt));
				} else {
					me.altT.updateText(sprintf("%2d,%d", math.floor(me.tgt_alt/1000), math.mod(me.tgt_alt, 1000)/100));
				}
				me.altT.show();
			} else {
				me.tgt_alt = math.round(me.tgt_alt, 100);
				if (me.tgt_alt <= 900) {
					me.altT_int.updateText(sprintf("%3d", me.tgt_alt));
					me.altT_int2.updateText("");
				} else {
					me.altT_int.updateText(sprintf("%2d", math.floor(me.tgt_alt/1000)));
					me.altT_int2.updateText(sprintf("%.3d", math.mod(me.tgt_alt, 1000)));
				}
				me.altT_int.show();
				me.altT_int2.show();
			}
		} else {
			me.altT.hide();
			me.altT_int.hide();
			me.altT_int2.hide();
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

	displayScanInfo: func {
		if (me.input.radar_stby.getBoolValue()) {
			me.scan_height_line.hide();
			me.scan_width_line_top.hide();
			me.scan_width_line_bot.hide();
			me.scan_sweep_mark.hide();
			return;
		}

		# Vertical limits (doesn't work in disk search mode)
		if (radar.ps46.getMode() != "Disk" and (var alt_limits = radar.ps46.getCursorAltitudeLimits()) != nil) {
			alt_limits[0] += me.indicated_alt_offset_ft;
			alt_limits[1] += me.indicated_alt_offset_ft;
			alt_limits[0] *= FT2M/20000*radar_area_width;
			alt_limits[1] *= FT2M/20000*radar_area_width;
			alt_limits[0] = math.clamp(alt_limits[0], 5*w, radar_area_width);
			alt_limits[1] = math.clamp(alt_limits[1], 0, radar_area_width - 5*w);

			me.scan_height_line.reset();
			me.scan_height_line.moveTo(0, -alt_limits[0]).vertTo(-alt_limits[1]);
			me.scan_height_line.show();
		} else {
			me.scan_height_line.hide();
		}

		# Azimuth limits
		var scan_center = radar.ps46.getDeviation();
		var scan_half_width = radar.ps46.getAzimuthRadius();
		var left = (scan_center - scan_half_width) * heading_deg_to_mm;
		var right = (scan_center + scan_half_width) * heading_deg_to_mm;

		me.scan_width_line_top.reset()
			.moveTo(left, 0).horizTo(right);
		me.scan_width_line_top.show();
		me.scan_width_line_bot.reset()
			.moveTo(left, 0).horizTo(right);
		me.scan_width_line_bot.show();

		var caret = radar.ps46.getCaretPosition();
		me.scan_sweep_mark.setTranslation(caret[0] * radar_area_width / 2, 0);
		me.scan_sweep_mark.show();
	},

	displayDLZ: func {
		var min_dist = nil;
		var max_dist = nil;

		var type = fire_control.get_type();
		if (type == "M70" or (type == "M75" and TI.ti.ModeAttack)) {
			# A/G
			var dist = sight.AGsight.get_dist();
			min_dist = dist != nil ? dist[1] : sight.FiringDistanceComputer.safety_distance(type);
			max_dist = type == "M75" ? 5000 : 6000;
		} elsif (type == "M75") {
			# A/A
			min_dist = 200;
			max_dist = 3200;
		} elsif ((var wpn = fire_control.get_weapon()) != nil) {
			var dlz = wpn.getDLZ(TRUE);
			if (dlz != nil and size(dlz) >= 4) {
				min_dist = dlz[3] * NM2M;
				max_dist = dlz[1] * NM2M;
			} else {
				min_dist = wpn.min_fire_range_nm * NM2M;
				max_dist = wpn.max_fire_range_nm * NM2M;
			}
		}

		if (min_dist == nil or max_dist == nil) {
			me.dlz_grp.hide();
			return;
		}

		# show DLZ vertically, scan width horizontally
		var bot = - min_dist / me.radar_range * radar_area_width;
		var top = - max_dist / me.radar_range * radar_area_width;
		top = math.max(top, -radar_area_width + 2.5);
		# scan width is clamped
		var scan_center = radar.ps46.getDeviation();
		var scan_half_width = math.max(radar.ps46.getAzimuthRadius(), 7.5);
		var left = math.clamp(scan_center - scan_half_width, -50, 35);
		var right = math.clamp(scan_center + scan_half_width, -35, 50);
		left *= heading_deg_to_mm;
		right *= heading_deg_to_mm;

		me.dlz_bot_left.setTranslation(left, bot);
		me.dlz_bot_right.setTranslation(right, bot);
		me.dlz_top_left.setTranslation(left, top);
		me.dlz_top_right.setTranslation(right, top);
		me.dlz_grp.show();
	},

	displayRadarTracks: func {
		# Used for cursor lock
		me.radar_contacts = [];
		me.radar_contacts_pos = [];
		me.n_contacts = 0;

		# Display radar echoes
		var contact_idx = 0;
		foreach (var contact; radar.ps46.getActiveBleps()) {
			if (contact_idx >= max_contacts) break;

			if (me.echoes[contact_idx].display(contact, me.radar_range, me.current_time)) {
				contact_idx += 1;

				# track is valid / not too old, remember it for cursor
				var info = contact.getLastBlep();
				var pos = me.azi_range_to_radar_pos(info.getAZDeviation(), info.getRangeNow(), me.radar_range);
				if (pos == nil) continue;
				append(me.radar_contacts, contact);
				append(me.radar_contacts_pos, pos);
				me.n_contacts += 1;
			}
		}

		# Hide remaining
		for (; contact_idx < max_contacts; contact_idx += 1) {
			me.echoes[contact_idx].hide();
		}

		# Display tracked aircrafts
		var track_idx = 0;
		foreach (var contact; radar.ps46.getTracks()) {
			if (track_idx >= max_tracks) break;
			if (me.tracks[track_idx].display(contact, me.radar_range, me.current_time, me.head_true))
				track_idx += 1;
		}
		# Hide remaining
		for (; track_idx < max_tracks; track_idx += 1) {
			me.tracks[track_idx].hide();
		}
	},

	displayTargetAziElev: func {
		if ((var tgt = radar.ps46.getPriorityTarget()) == nil or tgt.getLastBlep() == nil) {
			me.selection_azi_elev.hide();
			me.alt_tgt_index.hide();
			return;
		}

		var pos = tgt.getLastCoord();
		pos = vector.AircraftPosition.coordToLocalAziElev(pos);
		pos[0] -= me.input.fpv_right.getValue();
		pos[1] -= me.input.fpv_up.getValue();
		pos[0] *= heading_deg_to_mm;
		pos[1] *= heading_deg_to_mm;
		pos[0] = math.clamp(pos[0], -radar_area_width/2, radar_area_width/2);
		pos[1] = math.clamp(pos[1], -radar_area_width/2, radar_area_width/2);
		me.selection_azi_elev.setTranslation(pos[0], -pos[1]);
		me.selection_azi_elev.show();

		var alt = (tgt.getLastAltitude() + me.indicated_alt_offset_ft) * FT2M;
		if (alt >= 0 and alt <= 20000) {
			me.alt_tgt_index.setTranslation(0, -alt / 20000 * radar_area_width);
			me.alt_tgt_index.show();
		} else {
			me.alt_tgt_index.hide();
		}
	},

	displayCommandTarget: func {
		if (displays.common.ti_selection == nil or displays.common.ti_sel_type != displays.TI_SEL_DL) {
			me.cmd_circle.hide();
			me.cmd_alt_index.hide();
			return;
		}

		var range = displays.common.ti_selection.getRangeDirect();
		var bearing = displays.common.ti_selection.getDeviationHeading();
		pos = me.azi_range_to_radar_pos(bearing, range, me.radar_range);
		if (pos != nil) {
			me.cmd_circle.setTranslation(pos[0], pos[1]);
			me.cmd_circle.show();
		} else {
			me.cmd_circle.hide();
		}

		var alt = (displays.common.ti_selection.getAltitude() + me.indicated_alt_offset_ft) * FT2M;
		if (alt >= 0 and alt <= 20000) {
			me.cmd_alt_index.setTranslation(0, -alt / 20000 * radar_area_width);
			me.cmd_alt_index.show();
		} else {
			me.cmd_alt_index.hide();
		}
	},

	distCursorTrack: func(i) {
		return math.sqrt(
			math.pow(me.cursor_pos[0] - me.radar_contacts_pos[i][0], 2)
			+ math.pow(me.cursor_pos[1] - me.radar_contacts_pos[i][1], 2)
		);
	},

	findCursorTrack: func() {
		var closest_i = nil;
		var min_dist = 100000;

		for (var i=0; i<me.n_contacts; i+=1) {
			var dist = me.distCursorTrack(i);
			if (dist < min_dist) {
				closest_i = i;
				min_dist = dist;
			}
		}

		if (min_dist < 8) return me.radar_contacts[closest_i];
		else return nil;
	},

	displayCursor: func {
		if (displays.common.cursor != displays.MI) {
			me.cursor_shown = FALSE;
			me.cursor.hide();
			return;
		}

		# Retrieve cursor movement from JSBSim
		var cursor_mov = displays.common.getCursorDelta();
		displays.common.resetCursorDelta();
		var click = cursor_mov[2] and !me.cursorTriggerPrev;
		me.cursorTriggerPrev = cursor_mov[2];

		if (radar.ps46.getPriorityTarget() != nil) {
			me.cursor_shown = FALSE;
			me.cursor.hide();
			# clicking unlocks
			if (click) {
				# cursor restarts from current target position
				var info = radar.ps46.getPriorityTarget().getLastBlep();
				if (info != nil) {
					me.cursor_pos[0] = info.getAZDeviation() * heading_deg_to_mm;
					me.cursor_pos[1] = -info.getRangeNow() / me.radar_range * radar_area_width;
					me.cursor_pos[0] = math.clamp(me.cursor_pos[0], -radar_area_width/2, radar_area_width/2);
					me.cursor_pos[1] = math.clamp(me.cursor_pos[1], -radar_area_width, 0);
				}
				radar.ps46.undesignate();
			}
			return;
		}

		if (radar.ps46.getMode() == "Disk") {
			me.cursor_shown = FALSE;
			me.cursor.hide();
			return;
		}

		# 1.5 seconds to cover the entire screen.
		me.cursor_pos[0] += cursor_mov[0] * radar_area_width * 2/3;
		me.cursor_pos[1] += cursor_mov[1] * radar_area_width * 2/3;
		me.cursor_pos[0] = math.clamp(me.cursor_pos[0], -radar_area_width/2, radar_area_width/2);
		me.cursor_pos[1] = math.clamp(me.cursor_pos[1], -radar_area_width, 0);

		me.cursor.show();
		me.cursor.setTranslation(me.cursor_pos[0], me.cursor_pos[1]);

		me.cursor_azi = me.cursor_pos[0] / heading_deg_to_mm;
		me.cursor_range = -me.cursor_pos[1] / radar_area_width * me.radar_range;
		me.cursor_shown = TRUE;

		radar.ps46.setCursorDistance(me.cursor_range * M2NM);
		radar.ps46.setCursorDeviation(me.cursor_azi);

		if (click) {
			var new_sel = me.findCursorTrack();
			if (new_sel != nil) radar.ps46.designate(new_sel);
		}
	},
};

var extrapolate = func (x, x1, x2, y1, y2) {
    return y1 + ((x - x1) / (x2 - x1)) * (y2 - y1);
};

var mi = nil;
