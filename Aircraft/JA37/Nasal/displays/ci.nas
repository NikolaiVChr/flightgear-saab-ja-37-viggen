var TRUE = 1;
var FALSE = 0;

var input = {
    time:           "sim/time/elapsed-sec",
    heading:        "orientation/heading-deg",
    alt:            "instrumentation/altimeter/displays-altitude-meter",
    rad_alt:        "instrumentation/radar-altimeter/radar-altitude-m",
    rad_alt_ready:  "instrumentation/radar-altimeter/ready",
    ref_alt:        "ja37/displays/reference-altitude-m",
    ajs_bars_flash: "fdm/jsbsim/systems/mkv/ajs-alt-bars-blink",
    fiveHz:         "ja37/blink/five-Hz/state",
    roll:           "instrumentation/attitude-indicator/indicated-roll-deg",
    fpv_pitch:      "instrumentation/fpv/pitch-deg",
    radar_range:    "instrumentation/radar/range",
    radar_mode:     "instrumentation/radar/mode",
    radar_passive:  "ja37/radar/panel/passive",
};

foreach(var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}


### Shape of the radar scopes

# WARNING: the groups related to the radar scope itself have x pointing up (and y right),
# which is unusual for Canvas. The rest (mostly the horizon) have y pointing down.
# An annoying side effect is that CW and CCW are inverted for arcs.

var PPI_base_offset = 64;

# from bottom point to top arc
var PPI_radius = 120;
var PPI_half_angle = 61.5;
# maximum range at the limit angle
var PPI_bottom_length = 60;
# x coordinate of vertical sides
var PPI_side_x = math.sin(PPI_half_angle * D2R) * PPI_bottom_length;
# bottom of vertical side
var PPI_side_y1 = math.cos(PPI_half_angle * D2R) * PPI_bottom_length;
# top of vertical side
var PPI_side_y2 = math.sqrt(PPI_radius * PPI_radius - PPI_side_x * PPI_side_x);

var B_scope_half_x = 52;
var B_scope_y = 92;


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
            .lineTo(PPI_side_x,PPI_side_y1)
            .lineTo(PPI_side_x,PPI_side_y2)
            .arcSmallCW(PPI_radius, PPI_radius, 0, -2*PPI_side_x, 0)
            .lineTo(-PPI_side_x,PPI_side_y1)
            .close();

        me.B_scope = me.B_root.createChild("path")
            .moveTo(-B_scope_half_x, 0)
            .vert(B_scope_y)
            .horiz(2*B_scope_half_x)
            .vert(-B_scope_y)
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

        me.center_line = me.PPI_marks.createChild("path") .vert(PPI_radius);
        me.PPI_marks.createChild("path").vert(PPI_radius).setRotation(30 * D2R);
        me.PPI_marks.createChild("path").vert(PPI_radius).setRotation(-30 * D2R);

        var sn = math.sin(PPI_half_angle * D2R);
        var cs = math.cos(PPI_half_angle * D2R);
        me.arc10 = me.PPI_marks.createChild("path")
            .moveTo(-sn * 10, cs * 10)
            .arcSmallCCW(10, 10, 0, 20*sn, 0);
        me.arc20 = me.PPI_marks.createChild("path")
            .moveTo(-sn * 20, cs * 20)
            .arcSmallCCW(20, 20, 0, 40*sn, 0);
        me.arc40 = me.PPI_marks.createChild("path")
            .moveTo(-sn * 40, cs * 40)
            .arcSmallCCW(40, 40, 0, 80*sn, 0);

        var arc80_angle = math.asin(PPI_side_x / 80);
        var arc80_y = 80 * math.cos(arc80_angle);
        me.arc80 = me.PPI_marks.createChild("path")
            .moveTo(-PPI_side_x, arc80_y)
            .arcSmallCCW(80, 80, 0, 2*PPI_side_x, 0);

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
            .setTranslation(0,me.alt_bars_length) # bottom of altitude bars
            .moveTo(60,0).vert(-me.alt_bars_length)
            .moveTo(-60,0).vert(-me.alt_bars_length);
        me.rhm_index = me.alt_bars_group.createChild("path")
            .moveTo(57,0).horiz(6)
            .moveTo(-57,0).horiz(-6);

        me.rhm_shown = FALSE;

        # HUD mode for altitude bars, not CI mode
        me.mode = -1;
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


### Layers of display

var symbols_color = "rgba(192,255,192,1)";
var symbols_width = 1.5;

var radar_bg_color = "rgba(50,200,50,1)";

var radar_symbols_color = "rgba(0,0,0,1)";
var radar_symbols_width = 0.8;
var CI = {

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
            .setScale(1,-1);
        me.B_root = me.root.createChild("group", "B-scope")
            .setTranslation(0,B_scope_y/2)
            .setScale(1,-1);

        me.PPI_bg_grp = me.PPI_root.createChild("group", "background")
            .set("fill", radar_bg_color)
            .set("z-index", 0);
        me.B_bg_grp = me.B_root.createChild("group", "background")
            .set("fill", radar_bg_color)
            .set("z-index", 0);

        me.PPI_symbols_grp = me.PPI_root.createChild("group", "radar_symbols")
            .set("stroke", "rgba(0,0,0,1)")
            .set("stroke-width", radar_symbols_width)
            .set("z-index", 200);
        me.B_symbols_grp = me.B_root.createChild("group", "radar_symbols")
            .set("stroke", "rgba(0,0,0,1)")
            .set("stroke-width", radar_symbols_width)
            .set("z-index", 200);

        me.nav_symbols_grp = me.PPI_root.createChild("group", "symbols")
            .set("stroke", symbols_color)
            .set("stroke-width", symbols_width)
            .set("z-index", 201);

        me.horizon_grp = me.root.createChild("group", "horizon")
            .set("stroke", symbols_color)
            .set("stroke-width", symbols_width)
            .set("z-index", 202);

        me.radar_bg = RadarBackground.new(me.PPI_bg_grp, me.B_bg_grp);
        me.radar_marks = RadarMarks.new(me.PPI_symbols_grp);
        me.horizon = Horizon.new(me.horizon_grp);

        me.mode = -1;
        me.display = -1;
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
