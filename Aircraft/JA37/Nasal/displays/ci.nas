var TRUE = 1;
var FALSE = 0;

var input = {
    time:           "sim/time/elapsed-sec",
    heading:        "instrumentation/heading-indicator/indicated-heading-deg",
    roll:           "instrumentation/attitude-indicator/indicated-roll-deg",
    fpv_pitch:      "instrumentation/fpv/pitch-deg",
    alt:            "instrumentation/altimeter/displays-altitude-meter",
    rad_alt:        "instrumentation/radar-altimeter/radar-altitude-m",
    rad_alt_ready:  "instrumentation/radar-altimeter/ready",
    ref_alt:        "ja37/displays/reference-altitude-m",
    ajs_bars_flash: "fdm/jsbsim/systems/mkv/ajs-alt-bars-blink",
    fiveHz:         "ja37/blink/five-Hz/state",
    radar_range:    "instrumentation/radar/range",
    radar_mode:     "instrumentation/radar/mode",
    radar_passive:  "ja37/radar/panel/passive",
    radar_filter:   "instrumentation/radar/polaroid-filter",
    radar_quality:  "instrumentation/radar/ground-radar-quality",
};

foreach(var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}


var canvas_res = 256;   # pixels
# internal units (= 1/120 of radius of PPI)
# A disk of diameter 140 really used.
var canvas_size = 144;


### Shape of the radar scopes

# WARNING: the groups related to the radar scope itself have x pointing up (and y right),
# which is unusual for Canvas. The rest (mostly the horizon) have x right, y down.
# careful when using vert() / horiz()

var PPI_base_offset = 64;

# from bottom point to top arc
var PPI_radius = 120;
var PPI_half_angle = 61.5;
# maximum range at the limit angle
var PPI_bottom_length = 60;
# x coordinate of vertical sides
var PPI_side = math.sin(PPI_half_angle * D2R) * PPI_bottom_length;
# bottom of vertical side
var PPI_side_bot = math.cos(PPI_half_angle * D2R) * PPI_bottom_length;
# top of vertical side
var PPI_side_top = math.sqrt(PPI_radius * PPI_radius - PPI_side * PPI_side);

var B_scope_half_width = 52;
var B_scope_height = 92;
# B scope bottom relative to PPI origin
var B_scope_origin = (PPI_radius - B_scope_height) / 2;


### Radar image green background

var RadarBackground = {
    new: func(parent) {
        var m = { parents: [RadarBackground], parent: parent, };
        m.init();
        return m;
    },

    init: func {
        me.PPI = me.parent.createChild("path")
            .moveTo(0,0)
            .lineTo(PPI_side_bot,PPI_side)
            .lineTo(PPI_side_top,PPI_side)
            .arcSmallCCW(PPI_radius, PPI_radius, 0, 0, -2*PPI_side)
            .lineTo(PPI_side_bot,-PPI_side)
            .close();

        me.B_scope = me.parent.createChild("path")
            .moveTo(B_scope_origin, -B_scope_half_width)
            .line(B_scope_height, 0)
            .line(0, 2*B_scope_half_width)
            .line(-B_scope_height, 0)
            .close();
    },

    set_mode: func(mode, display) {
        me.PPI.setVisible(display == CI.DISPLAY_PPI);
        me.B_scope.setVisible(display == CI.DISPLAY_B);
    },
};


### Radar picture

var RadarImage = {
    quality_settings: [
        { img_res: 64, },
        { img_res: 96, },
        { img_res: 128, },
    ],

    img_full_res: 128,

    new: func(parent) {
        var m = { parents: [RadarImage], parent: parent, };
        m.init();
        return m;
    },

    init: func {
        me.img = me.parent.createChild("image")
            .set("blend-source-rgb","zero")
            .set("blend-source-alpha","zero")
            .set("blend-destination-rgb","one-minus-src-color")
            .set("blend-destination-alpha","one")
            .set("src", "Aircraft/JA37/Nasal/displays/ci-radar.png");

        me.update_quality(input.radar_quality.getValue());

        me.display = -1;
    },

    update_quality: func(quality) {
        me.clear_img();

        # Only part of the image is used at lower quality settings.
        me.img_res = me.quality_settings[quality].img_res;
        me.from_px = PPI_radius / me.img_res;       # internal units per pixel
        me.to_px = 1 / me.from_px;                  # pixels per internal unit

        # The entire width of the image is not used.
        me.img_half_width = math.ceil(PPI_side * me.to_px);

        # y is inverted in images...
        me.img.setScale(me.from_px, -me.from_px);
        # PPI origin at bottom center of image.
        # y translation is positive because of the previous setScale().
        me.img.setTranslation(0, (me.img_full_res / 2) * me.from_px);
    },

    clear_img: func {
        me.img.fillRect([0,0,me.img_full_res,me.img_full_res], [0,0,0,1]);
    },

    # Draw radar returns on a given azimuth
    # args:
    # - azimuth: Angle off centerline, degrees, positive is right.
    # - azi_width: Radar returns are drawn in a cone, this is the width of the cone in degrees.
    # - data: Array radar return strength (from 0 to 1) on the given azimuth,
    #         with uniform sampling between 0 and radar range.
    draw_azimuth_data: func(azimuth, azi_width, data) {
        var min_angle = azimuth - azi_width/2;
        var max_angle = azimuth + azi_width/2;
        var min_tan = math.tan(min_angle * D2R);
        var max_tan = math.tan(max_angle * D2R);

        for (var x = 0; x < me.img_res; x+=1) {
            var y_min = math.max(math.ceil(min_tan * x), -me.img_half_width);
            var y_max = math.min(math.floor(max_tan * x), me.img_half_width);

            for (var y = y_min; y <= y_max; y+=1) {
                var dist = math.sqrt(x*x + y*y) * me.from_px;
                if (dist >= PPI_radius) continue;

                var val = data[math.floor(dist / PPI_radius * size(data))];
                val = math.clamp(val * 0.25, 0, 1);
                me.img.setPixel(x, y + me.img_full_res/2, [val, val, val, 1]);
            }
        }
    },

    set_mode: func(mode, display) {
        if (display != me.display or mode == CI.MODE_STBY) me.clear_img();

        me.display = display;
        me.img.setVisible(display == CI.DISPLAY_PPI);
    },

    update: func {
        if (me.display != CI.DISPLAY_PPI) return;

        # TODO
        me.img.dirtyPixels();
    },
};


### Radar image reference marks

var RadarMarks = {
    new: func(parent) {
        var m = { parents: [RadarMarks], parent: parent, };
        m.init();
        return m;
    },

    init: func {
        me.PPI_marks = me.parent.createChild("group");

        me.center_line = me.PPI_marks.createChild("path").lineTo(PPI_radius,0);
        me.PPI_marks.createChild("path").lineTo(PPI_radius,0).setRotation(30 * D2R);
        me.PPI_marks.createChild("path").lineTo(PPI_radius,0).setRotation(-30 * D2R);

        var sn = math.sin(PPI_half_angle * D2R);
        var cs = math.cos(PPI_half_angle * D2R);
        me.arc10 = me.PPI_marks.createChild("path")
            .moveTo(cs * 10, -sn * 10)
            .arcSmallCW(10, 10, 0, 0, 20*sn);
        me.arc20 = me.PPI_marks.createChild("path")
            .moveTo(cs * 20, -sn * 20)
            .arcSmallCW(20, 20, 0, 0, 40*sn);
        me.arc40 = me.PPI_marks.createChild("path")
            .moveTo(cs * 40, -sn * 40)
            .arcSmallCW(40, 40, 0, 0, 80*sn);

        var arc80_angle = math.asin(PPI_side / 80);
        var arc80_bot = 80 * math.cos(arc80_angle);
        me.arc80 = me.PPI_marks.createChild("path")
            .moveTo(arc80_bot, -PPI_side)
            .arcSmallCW(80, 80, 0, 0, 2*PPI_side);

        me.display = -1;
    },

    set_mode: func(mode, display) {
        me.display = display;
        me.PPI_marks.setVisible(display == CI.DISPLAY_PPI);
    },

    update: func {
        if (me.display != CI.DISPLAY_PPI) return;

        var range = input.radar_range.getValue();
        me.arc10.setVisible(range >= 120000);
        me.arc20.setVisible(range >= 60000);
        me.arc40.setVisible(range >= 30000);
    },
};


### Sweeping beam

var RadarBeam = {
    new: func(dim_grp, bright_grp) {
        var m = { parents: [RadarBeam], dim_grp: dim_grp, bright_grp: bright_grp, };
        m.init();
        return m;
    },

    init: func {
        me.dim_beam = me.dim_grp.createChild("path")
            .moveTo(0,0).line(0,7).line(canvas_size,0).line(0,-7).close();
        me.bright_beam = me.bright_grp.createChild("path")
            .moveTo(0,7).line(canvas_size,0);

        me.display = -1;
        me.last_pos = 0;
        me.dir = 1;
    },

    set_pos: func(angle, dir) {
        me.dim_beam.setRotation(angle * dir * D2R);
        me.dim_beam.setScale(1, dir);
        me.bright_beam.setRotation(angle * dir * D2R);
        me.bright_beam.setScale(1, dir);
    },

    set_mode: func(mode, display) {
        me.display = display;

        var visible = display == CI.DISPLAY_PPI;
        me.dim_beam.setVisible(visible);
        me.bright_beam.setVisible(visible);
    },

    update: func {
        if (me.display != CI.DISPLAY_PPI) return;

        var pos = radar.ps37.getCaretPosition()[0] * radar.ps37.fieldOfRegardMaxAz;
        if (pos > me.last_pos) me.dir = 1;
        elsif (pos < me.last_pos) me.dir = -1;
        me.last_pos = pos;
        me.set_pos(pos, me.dir);
    },
};


### Waypoint circle and other navigation related symbols

var NavSymbols = {
    new: func(parent) {
        var m = { parents: [NavSymbols], parent: parent, };
        m.init();
        return m;
    },

    init: func {
        me.root = me.parent.createChild("group", "nav symbols");

        me.wpt_group = me.root.createChild("group", "waypoint");
        me.wpt_circle = me.wpt_group.createChild("path")
            .moveTo(-12,0).arcSmallCW(12,12,0,24,0).arcSmallCW(12,12,0,-24,0);
        me.line = me.wpt_group.createChild("path");
        me.appch_circle = me.root.createChild("path");

        me.display = -1;
    },

    set_line_length: func(length, scale) {
        me.line.reset().lineTo(length/scale*PPI_radius,0);
    },

    set_appch_circle_scale: func(scale) {
        var r = 4100/scale*PPI_radius;
        me.appch_circle.reset()
            .moveTo(-r,0).arcSmallCW(r,r,0,2*r,0).arcSmallCW(r,r,0,-2*r,0);
    },

    # Position elements on the radar scope.
    # Position given relative to aircraft axes. Distances in meters.
    set_elt_pos_cart: func(elt, fwd, right, scale) {
        elt.setTranslation(fwd/scale*PPI_radius, right/scale*PPI_radius);
    },

    # Position elements on the radar scope.
    # Position given relative to aircraft axes. Distances in meters, angles in degrees.
    set_elt_pos_polar: func(elt, dist, bearing, scale) {
        bearing *= D2R;
        me.set_elt_pos_cart(elt, math.cos(bearing)*dist, math.sin(bearing)*dist, scale);
    },

    set_mode: func(mode, display) {
        me.display = display;
        me.root.setVisible(display == CI.DISPLAY_PPI);
    },

    update: func {
        if (me.display != CI.DISPLAY_PPI) return;

        var scale = input.radar_range.getValue();

        me.wpt_circle.setVisible(land.show_waypoint_circle);
        me.line.setVisible(land.show_runway_line);
        me.appch_circle.setVisible(land.show_approach_circle);

        if (land.show_waypoint_circle or land.show_runway_line) {
            me.set_elt_pos_polar(me.wpt_group, land.runway_dist*NM2M, land.runway_bug, scale);
        }
        if (land.show_runway_line) {
            me.set_line_length(land.line*1000, scale);
            me.line.setRotation((180 + land.head - input.heading.getValue()) * D2R);
        }
        if (land.show_approach_circle) {
            me.set_appch_circle_scale(scale);
            var ac_pos = geo.aircraft_position();
            var bearing = ac_pos.course_to(land.approach_circle) - input.heading.getValue();
            var dist = ac_pos.distance_to(land.approach_circle);
            me.set_elt_pos_polar(me.appch_circle, dist, bearing, scale);
        }
    },
};


### Artificial horizon

var Horizon = {
    alt_bars_length: 20,

    new: func(parent) {
        # Inherits from hud.AltitudeBars since both work exactly the same way
        var m = { parents: [Horizon, hud.AltitudeBars], parent: parent, };
        m.init();
        return m;
    },

    init: func {
        me.roll_group = me.parent.createChild("group", "roll");
        me.horizon_group = me.roll_group.createChild("group", "horizon");
        me.alt_bars_group = me.horizon_group.createChild("group", "altitude bars");

        # reference mark
        me.parent.createChild("path")
            .moveTo(4,0).horiz(10)
            .moveTo(-4,0).horiz(-10);
        # horizon
        me.horizon_group.createChild("path")
            .moveTo(4,0).horizTo(70)
            .moveTo(-4,0).horizTo(-70);

        me.alt_bars_group.createChild("path")
            .moveTo(57,0).vert(me.alt_bars_length)
            .moveTo(-57,0).vert(me.alt_bars_length);
        me.ref_bars = me.alt_bars_group.createChild("path")
            .setTranslation(0,me.alt_bars_length); # bottom of altitude bars
        me.rhm_index = me.alt_bars_group.createChild("path")
            .moveTo(57,0).horiz(6)
            .moveTo(-57,0).horiz(-6);

        me.rhm_shown = FALSE;

        # HUD mode for altitude bars, not CI mode
        me.mode = -1;
    },

    # height=1 = length of outer altitude bars
    set_ref_bars_height: func(height) {
        me.ref_bars
            .reset()
            .moveTo(60, 0).vert(-me.alt_bars_length * height)
            .moveTo(-60,0).vert(-me.alt_bars_length * height);
    },

    update: func {
        me.mode = hud.hud.mode;

        me.roll_group.setRotation(-input.roll.getValue() * D2R);
        me.horizon_group.setTranslation(0, math.sin(input.fpv_pitch.getValue() * D2R) * 50);

        var alt = input.alt.getValue();
        var ref_alt = me.clamp_reference_altitude(input.ref_alt.getValue(), alt);
        # The outer altitude bars should be interpreted as an altitude scale
        # - top of the bars is commanded altitude
        # - artificial horizon is aircraft altitude
        # - rhm index is ground altitude
        # - reference bars go from 0m to 100m, when displayed.
        # This is the scale (altitude difference corresponding to the outer altitude bars).
        # If ref_alt < 500, the bottom of the bars corresponds to 0m.
        var scale = math.min(ref_alt, 500);

        # Store position of the bars. It is used to place other hud elements.
        var bars_pos = math.clamp((alt - ref_alt)/scale, -1, 1);
        me.alt_bars_group.setTranslation(0, me.alt_bars_length * bars_pos);
        me.update_ref_bars(ref_alt);
        me.update_rhm_index(scale, bars_pos);
    },
};





var CI = {
    symbols_width: 1.5,
    radar_symbols_width: 0.8,

    ## CI mode
    # Separated in type of display (PPI vs B-scope), type of symbology.
    # Radar mode is yet another thing, which is handled separately.

    DISPLAY_PPI: 0,
    DISPLAY_B: 1,

    MODE_STBY: 0,
    MODE_NORMAL: 1,
    #MODE_FIX: 2,
    #MODE_LAND: 3,
    #MODE_RB04: 4,
    #MODE_BOMB: 5,
    #MODE_AIR: 6,


    new: func(parent) {
        var m = { parents: [CI], root: parent, };
        m.init();
        return m;
    },

    init: func {
        me.root
            .set("stroke-linecap", "round")
            .set("stroke-linejoin", "round");

        # Radar root groups (centered at lowest point of radar display, x right, y _up_)
        me.PPI_root = me.root.createChild("group", "PPI")
            .setTranslation(0,PPI_base_offset)
            .setRotation(-math.pi/2);

        me.bg_grp = me.PPI_root.createChild("group", "background")
            .set("z-index", 0);

        me.img_grp = me.PPI_root.createChild("group", "radar image")
            .set("z-index", 100);

        me.marks_grp = me.PPI_root.createChild("group", "radar marks")
            .set("stroke", "rgba(0,0,0,1)")
            .set("stroke-width", me.radar_symbols_width)
            .set("z-index", 200);

        me.beam_grp = me.PPI_root.createChild("group", "symbols")
            .set("z-index", 201);

        me.symbols_grp = me.PPI_root.createChild("group", "symbols")
            .set("stroke-width", me.symbols_width)
            .set("z-index", 202);

        me.horizon_grp = me.root.createChild("group", "horizon")
            .set("stroke-width", me.symbols_width)
            .set("z-index", 202);

        me.color_listener = setlistener(input.radar_filter, func {
            me.update_colors();
        }, 1, 0);

        me.radar_bg = RadarBackground.new(me.bg_grp);
        me.radar_img = RadarImage.new(me.img_grp);
        me.radar_marks = RadarMarks.new(me.marks_grp);
        me.radar_beam = RadarBeam.new(me.beam_grp, me.symbols_grp);
        me.nav_symbols = NavSymbols.new(me.symbols_grp);
        me.horizon = Horizon.new(me.horizon_grp);

        me.mode = -1;
        me.display = -1;
    },

    update_colors: func {
        filter = input.radar_filter.getValue();

        # from 0=red to 1=green
        var hue = 1 / (1 + math.exp(-10 * (filter - 0.5)));
        var G_factor = math.min(1, 2*hue);
        var R_factor = math.min(1, 2 - 2*hue);

        # Radar background
        var bg_value = math.pow(filter, 0.8) * 0.8;
        var bg_desat = filter * 0.3;                # 1-saturation

        var bg_rgb = [
            bg_value * (R_factor + bg_desat * (1 - R_factor)),
            bg_value * (G_factor + bg_desat * (1 - G_factor)),
            bg_value * bg_desat,
        ];
        forindex (var i; bg_rgb) {
            bg_rgb[i] = int(bg_rgb[i] * 255);
        }
        var bg_str = sprintf("rgba(%d,%d,%d,1)", bg_rgb[0], bg_rgb[1], bg_rgb[2]);
        me.bg_grp.set("fill", bg_str);
        me.beam_grp.set("fill", bg_str);

        # Bright symbols layer
        var smb_value = math.pow(filter, 0.6);
        var smb_desat = math.pow(filter, 1.3) * 0.8;

        var smb_rgb = [
            smb_value * (R_factor + smb_desat * (1 - R_factor)),
            smb_value * (G_factor + smb_desat * (1 - G_factor)),
            smb_value * smb_desat,
        ];
        forindex (var i; smb_rgb) {
            smb_rgb[i] = int(smb_rgb[i] * 255);
        }
        var smb_str = sprintf("rgba(%d,%d,%d,1)", smb_rgb[0], smb_rgb[1], smb_rgb[2]);
        me.symbols_grp.set("stroke", smb_str);
        me.horizon_grp.set("stroke", smb_str);
    },

    update_quality: func(quality) {
        me.radar_img.update_quality(quality);
    },

    set_mode: func(mode, display) {
        if (me.mode == mode and me.display == display) return;
        me.mode = mode;
        me.display = display;

        # For MODE_STBY, everything is hidden, but notify CI elements so that they can cleanup if necessary.
        me.radar_bg.set_mode(mode, display);
        me.radar_img.set_mode(mode, display);
        me.radar_marks.set_mode(mode, display);
        me.radar_beam.set_mode(mode, display);
        me.nav_symbols.set_mode(mode, display);

        me.root.setVisible(mode != CI.MODE_STBY);
    },

    update_mode: func {
        if (!displays.common.ci_on
            or (input.radar_mode.getValue() == 0 and !input.radar_passive.getValue() and !modes.landing)) {
            me.set_mode(CI.MODE_STBY, CI.DISPLAY_PPI);
        } elsif (input.radar_mode.getValue() == 2) {
            me.set_mode(CI.MODE_NORMAL, CI.DISPLAY_B);
        } else {
            me.set_mode(CI.MODE_NORMAL, CI.DISPLAY_PPI);
        }
    },

    update: func {
        me.update_mode();
        if (me.mode == CI.MODE_STBY) return;

        me.radar_marks.update();
        me.radar_img.update();
        me.radar_beam.update();     # must be after radar_img.update()
        me.nav_symbols.update();
        me.horizon.update();
    },
};


var CICanvas = {
    res: canvas_res,
    width: canvas_size,

    new: func {
        var m = { parents: [CICanvas], };
        m.init();
        return m;
    },

    init: func {
        me.canvas_opts = {
            name: "CI",
            size: [me.res, me.res],
            view: [me.width, me.width],
            mipmapping: 1,
        };
        me.canvas = canvas.new(me.canvas_opts);
        me.canvas.setColorBackground(0,0,0,1);

        # Root group (centered)
        me.root = me.canvas.createGroup("root")
            .setTranslation(me.width/2, me.width/2);
    },

    add_placement: func(placement) {
        me.canvas.addPlacement(placement);
    },
};



var ci_cvs = nil;
var ci = nil;
var quality_listener = nil;

var init = func {
    ci_cvs = CICanvas.new();
    ci_cvs.add_placement({"node": "radarScreen", "texture": "radar-canvas.png"});
    ci = CI.new(ci_cvs.root);

    if (quality_listener != nil) removelistener(quality_listener);

    quality_listener = setlistener(input.radar_quality, func(node) {
        ci.update_quality(node.getValue());
    }, 0, 0);
}

var loop = func {
    ci.update();
}
