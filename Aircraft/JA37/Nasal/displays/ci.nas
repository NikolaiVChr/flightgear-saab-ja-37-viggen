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
};

foreach(var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}



### Radar image reference marks

var RadarMarks = {
    new: func(parent) {
        var m = { parents: [RadarMarks], parent: parent, };
        m.init();
        return m;
    },

    init: func {
        var sn = math.sin(61.5 * D2R);
        var cs = math.cos(61.5 * D2R);

        me.center_line = me.parent.createChild("path") .vert(-120);
        me.parent.createChild("path").vert(-120).setRotation(30 * D2R);
        me.parent.createChild("path").vert(-120).setRotation(-30 * D2R);

        me.arc10 = me.parent.createChild("path")
            .moveTo(-sn * 10, -cs * 10)
            .arcSmallCW(10, 10, 0, 20*sn, 0);
        me.arc20 = me.parent.createChild("path")
            .moveTo(-sn * 20, -cs * 20)
            .arcSmallCW(20, 20, 0, 40*sn, 0);
        me.arc40 = me.parent.createChild("path")
            .moveTo(-sn * 40, -cs * 40)
            .arcSmallCW(40, 40, 0, 80*sn, 0);

        var arc80_x = 60 * sn;
        var arc80_angle = math.asin(arc80_x / 80);
        var arc80_y = 80 * math.cos(arc80_angle);
        me.arc80 = me.parent.createChild("path")
            .moveTo(-arc80_x, -arc80_y)
            .arcSmallCW(80, 80, 0, 2*arc80_x, 0);
    },

    update: func {
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
        var m = { parents: [Horizon, hud.AltitudeBars], parent: parent, mode: -1, };
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


var CICanvas = {
    res: 512,       # pixels
    width: 144,     # internal units, 140x140 really used

    new: func() {
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
            .setTranslation(me.width/2, me.width/2)
            .set("stroke-linecap", "round")
            .set("stroke-linejoin", "round");

        # Radar root group (centered at lowest point of radar display == aircraft position)
        me.radar_root = me.root.createChild("group", "radar")
            .setTranslation(0,64);

        me.radar_bg_grp = me.radar_root.createChild("group", "background")
            .set("fill", radar_bg_color)
            .set("z-index", 0);

        me.radar_symbols_grp = me.radar_root.createChild("group", "radar_symbols")
            .set("stroke", radar_symbols_color)
            .set("stroke-width", radar_symbols_width)
            .set("z-index", 200);

        me.symbols_grp = me.radar_root.createChild("group", "symbols")
            .set("stroke", symbols_color)
            .set("stroke-width", symbols_width)
            .set("z-index", 201);

        me.horizon_grp = me.root.createChild("group", "horizon")
            .set("stroke", symbols_color)
            .set("stroke-width", symbols_width)
            .set("z-index", 202);

        me.radar_marks = RadarMarks.new(me.radar_symbols_grp);
        me.horizon = Horizon.new(me.horizon_grp);
    },

    add_placement: func(placement) {
        me.canvas.addPlacement(placement);
    },

    update: func {
        me.radar_marks.update();
        me.horizon.update();
    },
};



var CI = nil;

var init = func {
    CI = CICanvas.new();
    CI.add_placement({"node": "radarScreen", "texture": "radar-canvas.png"});
}

var loop = func {
    CI.update();
}
