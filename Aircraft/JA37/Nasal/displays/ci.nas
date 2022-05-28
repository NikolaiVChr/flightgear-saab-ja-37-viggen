var TRUE = 1;
var FALSE = 0;

var input = {
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
    radar_filter:   "instrumentation/radar/polaroid-filter",
    time:           "sim/time/elapsed-sec",
    radar_time:     "instrumentation/radar/effect/time",
    beam_pos:       "instrumentation/radar/effect/beam-pos-norm",
    beam_dir:       "instrumentation/radar/effect/beam-dir",
    quality:        "instrumentation/radar/ground-radar-quality",
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


### Radar picture

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

        me.update_quality(input.quality.getValue());

        me.display = -1;
    },

    update_quality: func(quality) {
        me.clear_img();

        me.width = me.quality_settings[quality].width;
        me.height = me.quality_settings[quality].height;

        me.img.setScale(canvas_size / me.width, canvas_size / me.height);
        me.img.setTranslation(0, canvas_size * (1.0 - me.img_full_res / me.height));
    },

    clear_img: func {
        var t = math.fmod(input.time.getValue() / 60.0, 1);
        me.img.fillRect([0,0,me.img_full_res,me.img_full_res], [0,0,t,0]);
    },

    draw_azimuth_data: func(azimuth, azi_width, data) {
        var min_x = math.floor(((azimuth - azi_width/2)*0.5/PPI_half_angle + 0.5) * me.width);
        var max_x = math.floor(((azimuth + azi_width/2)*0.5/PPI_half_angle + 0.5) * me.width);
        min_x = math.max(min_x, 0);
        max_x = math.min(max_x, me.width);

        if (min_x == max_x) return;

        var t = math.fmod(input.time.getValue() / 60.0, 1);

        for (var y = 0; y < me.height; y += 1) {
            var val = math.clamp(data[y], 0, 1);
            var color = [0,val,t,1];

            for (var x = min_x; x < max_x; x += 1) {
                me.img.setPixel(x, y, color);
            }
        }
    },

    show_image: func {
        me.img.dirtyPixels();
    },

    set_mode: func(mode, display) {
        if (display != me.display or mode == MODE.STBY) me.clear_img();
        me.display = display;

        me.img.setVisible(mode != MODE.STBY and display == DISPLAY.PPI);
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
        me.root.setVisible(display == DISPLAY.PPI);
    },

    update: func {
        if (me.display != DISPLAY.PPI) return;

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



## CI mode
# Separated in type of display (PPI vs B-scope), type of symbology.

var DISPLAY = {
    PPI: ps37_mode.SCAN_MODE.WIDE,
    B:   ps37_mode.SCAN_MODE.NARROW,
};

var MODE = ps37_mode.CI_MODE;


var CI = {
    symbols_width: 1.5,
    radar_symbols_width: 0.8,

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
            .set("z-index", 0)
            .set("stroke", "rgba(255,0,0,1)")
            .set("stroke-width", me.symbols_width)
            .setTranslation(canvas_size/2, canvas_size/2);

        me.rdr_symbols_grp = me.symbols_grp.createChild("group", "radar symbols")
            .setTranslation(0, PPI_base_offset)
            .setRotation(-math.pi/2);

        me.img_grp = me.root.createChild("group", "radar image")
            # HIGHER z-index, for blending magic
            .set("z-index", 100)
            # Additive blend, the two groups use different color channels, which must be treated independently.
            .set("blend-source", "one")
            .set("blend-destination", "one");

        me.radar_img = RadarImage.new(me.img_grp);
        me.nav_symbols = NavSymbols.new(me.rdr_symbols_grp);
        me.horizon = Horizon.new(me.symbols_grp);

        me.mode = -1;
        me.display = -1;

        me.last_beam_pos = 0.0;
        me.beam_dir = 1;
    },

    set_mode: func(mode, display) {
        if (me.mode == mode and me.display == display) return;
        me.mode = mode;
        me.display = display;

        # For MODE.STBY, everything is hidden, but notify CI elements so that they can cleanup if necessary.
        me.radar_img.set_mode(mode, display);
        me.nav_symbols.set_mode(mode, display);

        me.root.setVisible(mode != MODE.STBY);
    },

    update_mode: func {
        if (!displays.common.ci_on) {
            me.set_mode(MODE.STBY, DISPLAY.PPI);
            return;
        }

        # Mode controlled by ps37_mode.nas (shared with radar)
        me.set_mode(ps37_mode.ci_mode, ps37_mode.scan_mode or DISPLAY.PPI);
    },

    update_quality: func(quality) {
        me.radar_img.update_quality(quality);
    },

    update: func {
        me.update_mode();
        if (me.mode == MODE.STBY) return;

        me.nav_symbols.update();
        me.horizon.update();
        me.show_radar_image();
    },

    ## API for radar system

    # Draw radar returns on a given azimuth
    # args:
    # - azimuth: Angle off centerline, degrees, positive is right.
    # - azi_width: Radar returns are drawn in a cone, this is the width of the cone in degrees.
    # - data: Array radar return strength (from 0 to 1) on the given azimuth,
    #         with uniform sampling between 0 and radar range.
    draw_radar_data: func(azimuth, azi_width, data) {
        me.radar_img.draw_azimuth_data(azimuth, azi_width, data);
    },

    # Call this each frame once the radar is done drawing
    show_radar_image: func {
        me.radar_img.show_image();
        # Radar shader input properties
        input.radar_time.setValue(math.fmod(input.time.getValue() / 60.0, 1));

        var beam_pos = radar.ps37.getCaretPosition()[0];
        input.beam_pos.setValue(beam_pos);
        if (beam_pos > me.last_beam_pos)
            me.beam_dir = 1;
        elsif (beam_pos < me.last_beam_pos)
            me.beam_dir = -1;
        input.beam_dir.setValue(me.beam_dir);
        me.last_beam_pos = beam_pos;
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



var ci_cvs = nil;
var ci = nil;

var quality_listener = nil;

var init = func {
    ci_cvs = CICanvas.new();
    ci_cvs.add_placement({"node": "radarScreen", "texture": "radar-canvas.png"});
    ci = CI.new(ci_cvs.root);

    if (quality_listener != nil) removelistener(quality_listener);
    quality_listener = setlistener(input.quality, func (node) {
        ci.update_quality(node.getValue());
    }, 0, 0);
}

var loop = func {
    ci.update();
}
