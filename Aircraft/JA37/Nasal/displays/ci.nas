#### AJS37 Radar display (CI)
#
### Rendering
#
# The CI rendering consists of two parts:

# - The symbols (artificial horizon, and navigation symbols).
#   They are the brightest elements displayed on the CI.
#   In the real display, they are drawn by an electron gun which "bypasses"
#   the memory layer. In FG, they are directly rendered as Canvas elements.
#
# - The radar picture itself, which is drawn on a memory layer.
#   The "sweeping beam" erases the layer (makes it bright),
#   and an electron gun writes (makes it dark) on it just after.
#   The radar picture consists of:
#   * the radar picture proper (radar echoes)
#   * distance and azimuth marks
#   * in some modes, a cross (videomarkör)
#
# Rendering the radar picture efficiently in FG is hard for a few reasons:
# - The radar is displayed as a PPI. Doing the cartesian -> polar transformation
#   with Nasal and Canvas' setPixel() is possible, but a bit slow.
# - The picture has a noticeable decay over time.
#   Implementing it requires to change the entire picture all the time.
#   Doing so with setPixel() is out of question.
#
# The solution used is to let a custom shader do the previous two "hard things"
# (PPI and decay). The Canvas setPixel() does not try to draw a nice picture,
# but simply has to send all required information to the shader, as efficiently as possible.
#
# Data is transmitted to the shader ("drawn") as follows:
# - Symbols are drawn in the Red channel, as is.
# - Radar echoes are drawn in the Green channel, as a B-scope spanning the entire texture.
#   The shader then does the coordinate transformation.
# - The blue channel is organized in a number of horizontal strips, containing metadata:
#   * time of writing (modulo 1min)
#   * the radar range
#   * the position of the cross (and whether or not it is displayed)
#   * deviation of the centerline (used for some aiming modes)
#   * the distance of range aiming marks
#   This metadata is interpreted per column. The information for a given column
#   corresponds to the state of the radar when this column was written (in the green channel).
#
# This way, for the radar picture, only the column corresponding to the current
# radar azimuth needs to be written to.

# The shader is then capable of resconstructing the picture as follows.
# Given a pixel position, the shader does the PPI -> B-scope transformation
# to find the Canvas pixel to sample to obtain the radar echo strength (G channel).
# In the same column, at the appropriate line, the shader also samples the B channel to obtain the time of writing.
# Compared to the current time, this gives the 'age' of the pixel, which is used to animate decay.
# Additional symbols are drawn by sampling the other metadata.


var TRUE = 1;
var FALSE = 0;

var input = {
    heading:        "instrumentation/heading-indicator/indicated-heading-deg",
    roll:           "instrumentation/attitude-indicator/indicated-roll-deg",
    fpv_pitch:      "instrumentation/fpv/pitch-deg",
    track_true:     "instrumentation/fpv/track-true-deg",
    head_true:      "/orientation/heading-deg",
    alt:            "instrumentation/altimeter/displays-altitude-meter",
    rad_alt:        "instrumentation/radar-altimeter/radar-altitude-m",
    rad_alt_ready:  "instrumentation/radar-altimeter/ready",
    ref_alt:        "ja37/displays/reference-altitude-m",
    ajs_bars_flash: "fdm/jsbsim/systems/mkv/ajs-alt-bars-blink",
    fiveHz:         "ja37/blink/five-Hz/state",
    radar_range:    "instrumentation/radar/range",
    radar_filter:   "instrumentation/radar/polaroid-filter",
    time:           "sim/time/elapsed-sec",
    shader_mode:    "instrumentation/radar/effect/mode",
    radar_time1:    "instrumentation/radar/effect/time1",
    radar_time2:    "instrumentation/radar/effect/time2",
    beam_pos:       "instrumentation/radar/effect/beam-pos-norm",
    beam_dir:       "instrumentation/radar/effect/beam-dir",
    quality:        "instrumentation/radar/ground-radar-quality",
    antenna_angle:  "instrumentation/radar/antenna-angle-norm",
    # shaders controls
    compositor:     "ja37/supported/compositor",
    als_on:         "sim/rendering/shaders/skydome",
    comp_shaders:   "sim/rendering/shaders/use-shaders",
    old_shaders1:   "sim/rendering/shaders/quality-level",
    old_shaders2:   "sim/rendering/shaders/model",
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
# azimuth to top-right corner
var PPI_corner_angle = math.asin(PPI_side / PPI_radius) * R2D;

var B_scope_half_width = 52;
var B_scope_height = 92;
# B scope bottom relative to PPI origin
var B_scope_origin = (PPI_radius - B_scope_height) / 2;

var PPI_sweep_speed = 110.0;

# Display range limit function of azimuth
var azimuth_range = func(azimuth, max_range, b_scope) {
    azimuth = abs(azimuth);
    if (b_scope) {
        if (azimuth > 20) return 0;
        else return max_range;
    } else {
        if (azimuth <= PPI_corner_angle) return max_range;
        else return max_range * PPI_side / PPI_radius / math.sin(azimuth * D2R);
    }
}


# time is encoded over two values, because of precision issues
var time1_factor = 60.0;
var time2_factor = 1920.0;


### Radar picture
#
# This is the code which "encodes" information used by the shader.

var RadarImage = {
    img_full_res: 128,

    quality_settings: [
        { width:64, height:32, },
        { width:96, height:48, },
        { width:128, height:64, },
    ],

    new: func(parent) {
        var m = { parents: [RadarImage], parent: parent, };
        m.init();
        return m;
    },

    init: func {
        me.img = me.parent.createChild("image")
            .set("src", "Aircraft/JA37/Nasal/displays/ci-radar.png");

        me.mode = -1;
        me.display = -1;

        # metadata (blue channel)
        me.metadata = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
        me.update_metadata();

        me.update_quality(input.quality.getValue());
    },

    # Metadata strips, from bottom to top
    # - time of writing (2 values)
    # - radar range, normalized as: 0.25: 12km, 0.5: 30km, 0.75: 60km, 1: 120km,
    #   0: show cross marker, hide range/azimuth marks
    # - azimuth (of either center line or cross marker)
    # - distance (of cross marker or aiming line)
    #
    # Each strip spans 1/8 of the height of the texture.
    # One should be careful when sampling to avoid interpolation issues:
    # sample in the middle of of the strip, and make sensible comparisons for intermediate values.

    INFO: {
        TIME1:          0,
        TIME2:          1,
        RANGE:          2,
        AZIMUTH:        3,
        DISTANCE:       4,
        N_STRIPS:       8,
    },

    NORM_RANGE: {
        15000: 0.25,
        30000: 0.5,
        60000: 0.75,
        120000: 1.0,
    },

    # Modify me.info() to contain current metadata.
    update_metadata: func {
        var time = input.time.getValue();
        me.metadata[me.INFO.TIME1] = math.fmod(time / time1_factor, 1.0);
        me.metadata[me.INFO.TIME2] = math.fmod(time / time2_factor, 1.0);
        me.metadata[me.INFO.RANGE] = me.NORM_RANGE[input.radar_range.getValue()];
        if (me.mode == MODE.RB04) {
            var track = input.track_true.getValue() - input.head_true.getValue();
            track = math.clamp(geo.normdeg180(track), -PPI_half_angle, PPI_half_angle);
            me.metadata[me.INFO.AZIMUTH] = track * 0.5 / PPI_half_angle + 0.5;
            me.metadata[me.INFO.DISTANCE] = 1.0;
        } else {
            me.metadata[me.INFO.AZIMUTH] = 0.0;
            me.metadata[me.INFO.DISTANCE] = 0.0;
        }
    },

    update_quality: func(quality) {
        me.width = me.quality_settings[quality].width;
        me.height = me.quality_settings[quality].height;

        me.strip_height = me.height / me.INFO.N_STRIPS;

        me.img.setScale(canvas_size / me.width, canvas_size / me.height);
        me.img.setTranslation(0, canvas_size * (1.0 - me.img_full_res / me.height));

        me.clear_img();
    },

    clear_img: func {
        me.img.fillRect([0,0,me.img_full_res,me.img_full_res], [0,0,0,0]);
    },

    draw_empty_sector: func(start_azi, end_azi) {
        var min_x = math.floor((math.min(start_azi, end_azi)*0.5/PPI_half_angle + 0.5) * me.width);
        var max_x = math.floor((math.max(start_azi, end_azi)*0.5/PPI_half_angle + 0.5) * me.width);

        var meta_idx = 0;
        var meta = me.metadata[meta_idx];

        # For some reason fillRect() does not work correctly here.
        for (var y = 0; y < me.height; y += 1) {
            if (y >= (meta_idx+1) * me.strip_height) {
                meta_idx += 1;
                meta = me.metadata[meta_idx];
            }
            var color = [0,0,meta,1];

            for (var x = min_x; x < max_x; x += 1) {
                me.img.setPixel(x, y, color);
            }
        }
    },

    draw_azimuth_data: func(azimuth, azi_width, data) {
        var min_x = math.floor(((azimuth - azi_width/2)*0.5/PPI_half_angle + 0.5) * me.width);
        var max_x = math.floor(((azimuth + azi_width/2)*0.5/PPI_half_angle + 0.5) * me.width);
        min_x = math.max(min_x, 0);
        max_x = math.min(max_x, me.width);

        if (min_x == max_x) return;

        var meta_idx = 0;
        var meta = me.metadata[meta_idx];

        for (var y = 0; y < me.height; y += 1) {
            var val = math.clamp(data[y], 0, 1);
            if (y >= (meta_idx+1) * me.strip_height) {
                meta_idx += 1;
                meta = me.metadata[meta_idx];
            }
            var color = [0,val,meta,1];

            for (var x = min_x; x < max_x; x += 1) {
                me.img.setPixel(x, y, color);
            }
        }
    },

    prepare_draw: func {
        me.update_metadata();
    },

    show_image: func {
        me.img.dirtyPixels();
    },

    set_mode: func(mode, display) {
        if (display != me.display or mode == MODE.STBY) me.clear_img();
        me.display = display;
        me.mode = mode;
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
        me.mode = -1;
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
        me.mode = mode;
        me.root.setVisible(display == DISPLAY.PPI);
    },

    update: func {
        if (me.display != DISPLAY.PPI) return;

        var scale = input.radar_range.getValue();

        # Mode restrictions from Beskrivning FPL AJS37 Del 4
        var wpt_visible = (land.show_waypoint_circle and me.mode != MODE.BOMB and me.mode != MODE.AIR);
        var line_visible = (land.show_runway_line and (me.mode == MODE.SILENT or me.mode == MODE.NORMAL));
        var appch_circle_visible = (line_visible and land.show_approach_circle);

        me.wpt_circle.setVisible(wpt_visible);
        me.line.setVisible(line_visible);
        me.appch_circle.setVisible(appch_circle_visible);

        if (wpt_visible or line_visible) {
            me.set_elt_pos_polar(me.wpt_group, land.runway_dist*NM2M, land.runway_bug, scale);
        }
        if (line_visible) {
            me.set_line_length(land.line*1000, scale);
            me.line.setRotation((180 + land.head - input.heading.getValue()) * D2R);
        }
        if (appch_circle_visible) {
            me.set_appch_circle_scale(scale);
            var ac_pos = geo.aircraft_position();
            var bearing = ac_pos.course_to(land.approach_circle) - input.heading.getValue();
            var dist = ac_pos.distance_to(land.approach_circle);
            me.set_elt_pos_polar(me.appch_circle, dist, bearing, scale);
        }
    },
};


### Background shape, only used when shaders are disabled

var PPIBackground = {
    new: func(parent) {
        var m = { parents: [PPIBackground], parent: parent, };
        m.init();
        return m;
    },

    init: func {
        me.bg = me.parent.createChild("path")
            .setColorFill(0.3, 1.0, 0.3, 1.0)
            .set("stroke-width", 0)
            .lineTo(PPI_side_bot, PPI_side)
            .lineTo(PPI_side_top, PPI_side)
            .arcSmallCCWTo(PPI_radius, PPI_radius, 0, PPI_side_top, -PPI_side)
            .lineTo(PPI_side_bot, -PPI_side)
            .close();

        me.lines_grp = me.parent.createChild("group")
            .set("z-index", 1)
            .set("stroke", "rgba(0,0,0,1)")
            .set("stroke-width", 0.8);

        # lines
        var line_angle = 30.0 * D2R;
        me.lines_grp.createChild("path")
            .moveTo(0,0).lineTo(PPI_radius, 0)
            .moveTo(0,0).lineTo(PPI_radius * math.cos(line_angle), PPI_radius * math.sin(line_angle))
            .moveTo(0,0).lineTo(PPI_radius * math.cos(line_angle), -PPI_radius * math.sin(line_angle));

        # arcs
        me.arc_80 = me.lines_grp.createChild("path")
            .moveTo(0,-80).arcSmallCWTo(80,80,0,0,80);
        me.arc_40 = me.lines_grp.createChild("path")
            .moveTo(0,-40).arcSmallCWTo(40,40,0,0,40);
        me.arc_20 = me.lines_grp.createChild("path")
            .moveTo(0,-20).arcSmallCWTo(20,20,0,0,20);
        me.arc_10 = me.lines_grp.createChild("path")
            .moveTo(0,-10).arcSmallCWTo(10,10,0,0,10);
    },

    update: func {
        var range = input.radar_range.getValue();
        me.arc_10.setVisible(range >= 120000);
        me.arc_20.setVisible(range >= 60000);
        me.arc_40.setVisible(range >= 30000);
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


### Antenna angle indicator
var AngleIndicator = {
    new: func(parent) {
        var m = { parents: [AngleIndicator], parent: parent, };
        m.init();
        return m;
    },

    max_offset: 20,

    init: func {
        me.root = me.parent.createChild("group", "antenna angle")
            # Just above PPI
            .set("stroke-width", 1.0)
            .setTranslation(0, PPI_base_offset - PPI_radius - 4);

        var tick_size = 2;
        me.root.createChild("path")
            .moveTo(-tick_size, 0).horiz(2*tick_size)
            .moveTo(-me.max_offset - tick_size, 0).horiz(2*tick_size)
            .moveTo(me.max_offset - tick_size, 0).horiz(2*tick_size);

        me.mark = me.root.createChild("path")
            .moveTo(0,-3).vert(6);

        me.visible = -1;
    },

    set_mode: func(mode, display) {
        me.visible = (mode == MODE.AIR and display == DISPLAY.PPI);
        me.root.setVisible(me.visible);
    },

    update: func {
        if (!me.visible) return;

        me.mark.setTranslation(input.antenna_angle.getValue() * me.max_offset, 0);
    },
};



## CI mode
# Separated in type of display (PPI vs B-scope), type of symbology.

var DISPLAY = {
    PPI: ps37_mode.SCAN_MODE.WIDE,
    B:   ps37_mode.SCAN_MODE.NARROW,
};

var MODE = ps37_mode.CI_MODE;


var CI = {
    symbols_width: 1.5,

    new: func(parent) {
        var m = { parents: [CI], root: parent, };
        m.init();
        return m;
    },

    init: func {
        me.root
            .set("stroke-linecap", "round")
            .set("stroke-linejoin", "round");

        me.symbols_grp = me.root.createChild("group", "symbols")
            .set("z-index", 5)
            .set("stroke", "rgba(255,0,0,1)")
            .set("stroke-width", me.symbols_width)
            .setTranslation(canvas_size/2, canvas_size/2);

        me.rdr_symbols_grp = me.symbols_grp.createChild("group", "nav symbols")
            .set("z-index", 5)
            .setTranslation(0, PPI_base_offset)
            .setRotation(-math.pi/2);

        me.bg_grp = me.symbols_grp.createChild("group", "radar background")
            .set("z-index", -10)
            .setTranslation(0, PPI_base_offset)
            .setRotation(-math.pi/2);

        me.img_grp = me.root.createChild("group", "radar image")
            # HIGHER z-index, for blending magic
            .set("z-index", 10)
            # Additive blend, the two groups use different color channels, which must be treated independently.
            .set("blend-source", "one")
            .set("blend-destination", "one");

        me.radar_img = RadarImage.new(me.img_grp);
        me.nav_symbols = NavSymbols.new(me.rdr_symbols_grp);
        me.bg = PPIBackground.new(me.bg_grp);
        me.horizon = Horizon.new(me.symbols_grp);
        me.angle_indicator = AngleIndicator.new(me.symbols_grp);

        me.mode = -1;
        me.display = -1;

        me.beam_pos = 0.0;
        me.last_beam_pos = 0.0;
        me.beam_dir = 1;

        me.zero_buffer = [];

        me.use_shader = -1;
        me.update_shader();
    },

    # Test if CI shader is enabled.
    # When disabled, only navigation symbols are shown.
    update_shader: func {
        var use_shader = input.als_on.getBoolValue()
            or (input.compositor.getBoolValue() and input.comp_shaders.getBoolValue())
            or (!input.compositor.getBoolValue() and input.old_shaders1.getBoolValue() and input.old_shaders2.getBoolValue());

        if (use_shader == me.use_shader) return;
        me.use_shader = use_shader;

        if (me.use_shader) {
            # symbols drawn in red canal, shader interprets it as needed
            me.symbols_grp.set("stroke", "rgba(255,0,0,1)");
            # display radar
            me.img_grp.show();
            me.bg_grp.hide();
            me.clear_radar_image();
            me.show_radar_image(0.01);
        } else {
            # draw symbols with correct color
            me.symbols_grp.set("stroke", "rgba(220,255,220,1)");
            # no radar picture
            me.img_grp.hide();
            me.bg_grp.show();
        }
    },

    set_mode: func(mode, display) {
        if (me.mode == mode and me.display == display) return;
        me.mode = mode;
        me.display = display;

        if (me.mode == MODE.STBY) {
            input.shader_mode.setValue(0);
            # Reset internal state
            me.beam_pos = 0.0;
            me.last_beam_pos = 0.0;
            me.beam_dir = 1;
        } else {
            input.shader_mode.setValue(me.display == DISPLAY.PPI ? 1 : 2);
        }

        # For MODE.STBY, everything is hidden, but notify CI elements so that they can cleanup if necessary.
        me.radar_img.set_mode(mode, display);
        me.nav_symbols.set_mode(mode, display);
        me.angle_indicator.set_mode(mode, display);

        me.root.setVisible(mode != MODE.STBY);
    },

    update: func(dt) {
        # Mode controlled by ps37_mode.nas (shared with radar)
        me.set_mode(ps37_mode.ci_mode, ps37_mode.scan_mode or DISPLAY.PPI);

        if (me.mode == MODE.STBY) return;

        me.nav_symbols.update();
        me.horizon.update();
        me.angle_indicator.update();
        me.show_radar_image(dt);
    },

    update_quality: func(quality) {
        me.radar_img.update_quality(quality);

        setsize(me.zero_buffer, me.radar_img.height);
        forindex (var i; me.zero_buffer) {
            me.zero_buffer[i] = 0.0;
        }
    },

    ## API for radar system

    # Draw radar returns on a given azimuth
    # args:
    # - azimuth: Angle off centerline, degrees, positive is right.
    # - azi_width: Radar returns are drawn in a cone, this is the width of the cone in degrees.
    # - data: Array radar return strength (from 0 to 1) on the given azimuth,
    #         with uniform sampling between 0 and radar range.
    draw_radar_data: func(azimuth, azi_width, data) {
        if (!me.use_shader) return;

        me.radar_img.draw_azimuth_data(azimuth, azi_width, data);
    },

    # Call this each frame once the radar is done drawing
    show_radar_image: func(dt) {
        if (!me.use_shader) {
            me.bg.update();
            return;
        }

        if (me.mode != MODE.SILENT) {
            # Radar antenna position
            me.beam_pos = radar.ps37.getCaretPosition()[0];
            if (me.beam_pos > me.last_beam_pos)
                me.beam_dir = 1;
            elsif (me.beam_pos < me.last_beam_pos)
                me.beam_dir = -1;
        } else {
            # In silent mode, sweep continues to draw the screen, but does not match the radar
            me.silent_sweep(dt);
        }
        me.last_beam_pos = me.beam_pos;

        me.radar_img.show_image();

        # Radar shader input properties
        var time = input.time.getValue();
        input.radar_time1.setValue(math.fmod(time / time1_factor, 1.0));
        input.radar_time2.setValue(math.fmod(time / time2_factor + 0.001, 1.0));
        input.beam_pos.setValue(me.beam_pos);
        input.beam_dir.setValue(me.mode == MODE.MEMORY ? 0 : me.beam_dir);  # Disable beam in memory mode

        # Prepare radar picture for next loop
        me.radar_img.prepare_draw();
    },

    silent_sweep: func(dt) {
        var prev_angle = me.beam_pos * PPI_half_angle;
        var next_angle = prev_angle + me.beam_dir * dt * PPI_sweep_speed;
        if (next_angle > PPI_half_angle) {
            next_angle = PPI_half_angle;
            me.beam_dir = -1;
        } elsif (next_angle < -PPI_half_angle) {
            next_angle = -PPI_half_angle;
            me.beam_dir = 1;
        }

        me.radar_img.draw_empty_sector(prev_angle, next_angle);

        me.beam_pos = next_angle / PPI_half_angle;
    },

    clear_radar_image: func {
        me.radar_img.clear_img();
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
        me.root = me.canvas.createGroup("root");
    },

    add_placement: func(placement) {
        me.canvas.addPlacement(placement);
    },
};


var max_dt = 0.1;

var ci_cvs = nil;
var ci = nil;


var init = func {
    ci_cvs = CICanvas.new();
    ci_cvs.add_placement({"node": "radarScreen", "texture": "radar-canvas.png"});
    ci = CI.new(ci_cvs.root);

    setlistener(input.quality, func (node) { ci.update_quality(node.getValue()); }, 0, 0);
    setlistener(input.als_on, func { ci.update_shader(); }, 0, 0);
    if (input.compositor.getBoolValue()) {
      setlistener(input.comp_shaders, func { ci.update_shader(); }, 0, 0);
    } else {
      setlistener(input.old_shaders1, func { ci.update_shader(); }, 0, 0);
      setlistener(input.old_shaders2, func { ci.update_shader(); }, 0, 0);
    }
}

var loop = func(dt) {
    dt = math.min(dt, max_dt);
    ci.update(dt);
}
