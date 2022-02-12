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
};

foreach(var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}


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


### Radar image green background

var RadarBackground = {
    new: func(PPI_root, B_root) {
        var m = { parents: [RadarBackground], PPI_root: PPI_root, B_root: B_root, };
        m.init();
        return m;
    },

    init: func {
        me.PPI = me.PPI_root.createChild("path")
            .moveTo(0,0)
            .lineTo(PPI_side_bot,PPI_side)
            .lineTo(PPI_side_top,PPI_side)
            .arcSmallCCW(PPI_radius, PPI_radius, 0, 0, -2*PPI_side)
            .lineTo(PPI_side_bot,-PPI_side)
            .close();

        me.B_scope = me.B_root.createChild("path")
            .moveTo(0,-B_scope_half_width)
            .lineTo(B_scope_height,-B_scope_half_width)
            .lineTo(B_scope_height,B_scope_half_width)
            .lineTo(0,B_scope_half_width)
            .close();
    },

    set_mode: func(mode, display) {
        me.PPI.setVisible(display == CI.DISPLAY_PPI);
        me.B_scope.setVisible(display == CI.DISPLAY_B);
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
        me.B_root = me.root.createChild("group", "B-scope")
            .setTranslation(0,B_scope_height/2)
            .setRotation(-math.pi/2);

        me.PPI_bg_grp = me.PPI_root.createChild("group", "background")
            .set("z-index", 0);
        me.B_bg_grp = me.B_root.createChild("group", "background")
            .set("z-index", 0);

        me.PPI_symbols_grp = me.PPI_root.createChild("group", "radar_symbols")
            .set("stroke", "rgba(0,0,0,1)")
            .set("stroke-width", me.radar_symbols_width)
            .set("z-index", 200);
        me.B_symbols_grp = me.B_root.createChild("group", "radar_symbols")
            .set("stroke", "rgba(0,0,0,1)")
            .set("stroke-width", me.radar_symbols_width)
            .set("z-index", 200);

        me.nav_symbols_grp = me.PPI_root.createChild("group", "symbols")
            .set("stroke-width", me.symbols_width)
            .set("z-index", 201);

        me.horizon_grp = me.root.createChild("group", "horizon")
            .set("stroke-width", me.symbols_width)
            .set("z-index", 202);

        me.color_listener = setlistener(input.radar_filter, func {
            me.update_colors();
        }, 1, 0);

        me.radar_bg = RadarBackground.new(me.PPI_bg_grp, me.B_bg_grp);
        me.radar_marks = RadarMarks.new(me.PPI_symbols_grp);
        me.nav_symbols = NavSymbols.new(me.nav_symbols_grp);
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
        me.PPI_bg_grp.set("fill", bg_str);
        me.B_bg_grp.set("fill", bg_str);

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
        me.nav_symbols_grp.set("stroke", smb_str);
        me.horizon_grp.set("stroke", smb_str);
    },

    set_mode: func(mode, display) {
        if (me.mode == mode and me.display == display) return;
        me.mode = mode;
        me.display = display;

        if (mode == CI.MODE_STBY) {
            me.root.hide();
        } else {
            me.root.show();
            me.radar_bg.set_mode(mode, display);
            me.radar_marks.set_mode(mode, display);
            me.nav_symbols.set_mode(mode, display);
        }
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
        me.horizon.update();
        me.nav_symbols.update();
    },
};


var CICanvas = {
    res: 512,       # pixels
    width: 144,     # internal units, 140x140 really used

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

var init = func {
    ci_cvs = CICanvas.new();
    ci_cvs.add_placement({"node": "radarScreen", "texture": "radar-canvas.png"});
    ci = CI.new(ci_cvs.root);
}

var loop = func {
    ci.update();
}
