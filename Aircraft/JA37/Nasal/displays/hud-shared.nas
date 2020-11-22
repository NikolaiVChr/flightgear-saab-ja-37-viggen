#### This file contains all HUD code shared by the JA and AJS variants.

var TRUE = 1;
var FALSE = 0;


var extrapolate = func (x, x1, x2, y1, y2) {
    return y1 + ((x - x1) / (x2 - x1)) * (y2 - y1);
};


var input = {
    heading:        "/instrumentation/heading-indicator/indicated-heading-deg",
    pitch:          "/instrumentation/attitude-indicator/indicated-pitch-deg",
    roll:           "/instrumentation/attitude-indicator/indicated-roll-deg",
    speed:          "/instrumentation/airspeed-indicator/indicated-speed-kmh",
    speed_kt:       "/instrumentation/airspeed-indicator/indicated-speed-kt",
    groundspeed:    "/velocities/groundspeed-kt",
    mach:           "/instrumentation/airspeed-indicator/indicated-mach",
    fpv_up:         "/instrumentation/fpv/angle-up-deg",
    fpv_up_stab:    "/instrumentation/fpv/angle-up-stab-deg",
    fpv_right:      "/instrumentation/fpv/angle-right-deg",
    fpv_right_stab: "/instrumentation/fpv/angle-right-stab-deg",
    fpv_head_true:  "/instrumentation/fpv/heading-true",
    head_true:      "/orientation/heading-deg",
    alpha:          "/orientation/alpha-deg",
    high_alpha:     "/fdm/jsbsim/autoflight/high-alpha",
    weight:         "/fdm/jsbsim/inertia/weight-lbs",
    alt:            "/instrumentation/altimeter/indicated-altitude-meter",
    alt_ft:         "/instrumentation/altimeter/indicated-altitude-ft",
    rad_alt:        "/instrumentation/radar-altimeter/radar-altitude-m",
    rad_alt_ft:     "/instrumentation/radar-altimeter/radar-altitude-ft",
    rad_alt_ready:  "/instrumentation/radar-altimeter/ready",
    ref_alt:        "/ja37/displays/reference-altitude-m",
    rm_active:      "/autopilot/route-manager/active",
    wp_bearing:     "/autopilot/route-manager/wp/bearing-deg",
    wp_dist:        "/autopilot/route-manager/wp/dist-km",
    wp_dist_nm:     "/autopilot/route-manager/wp/dist",
    eta:            "/autopilot/route-manager/wp/eta-seconds",
    hud_slav:       "/ja37/hud/switch-slav",
    gear_pos:       "/gear/gear/position-norm",
    use_ALS:        "/sim/rendering/shaders/skydome",
    view_x:         "/sim/current-view/x-offset-m",
    view_y:         "/sim/current-view/y-offset-m",
    view_z:         "/sim/current-view/z-offset-m",
    wow:            "/fdm/jsbsim/gear/unit[0]/WOW",
    units_metric:   "/ja37/hud/units-metric",
    qfe_warning:    "ja37/displays/qfe-warning",
    tils:           "ja37/hud/TILS",
    nav_lock:       "/instrumentation/nav[0]/in-range",
    nav_defl:       "/instrumentation/nav[0]/heading-needle-deflection",
    nav_rdl:        "/instrumentation/nav[0]/radials/target-radial-deg",
    nav_has_gs:     "/instrumentation/nav[0]/has-gs",
    nav_gs_lock:    "/instrumentation/nav[0]/gs-in-range",
    nav_gs_defl:    "/instrumentation/nav[0]/gs-needle-deflection-deg",
    tils_steady:    "/instrumentation/TLS-light-steady",
    tils_blink:     "/instrumentation/TLS-light-blink",
    radar_range:    "/instrumentation/radar/range",
    APmode:         "/fdm/jsbsim/autoflight/mode",
    alt_bars_flash: "/fdm/jsbsim/systems/indicators/flashing-alt-bars",
    gpw:            "/instrumentation/terrain-warning",
    trigger:        "/controls/armament/trigger-final",
    twoHz:          "/ja37/blink/two-Hz/state",
    fourHz:         "/ja37/blink/four-Hz/state",
    bright:         "/ja37/hud/brightness",
    bright_hud:     "/ja37/hud/brightness-si",
    bright_bck:     "/ja37/hud/brightness-res",
};

foreach(var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}



### Canvas elements creators with default options

# Create a new path with default options
var make_path = func(parent) {
    return parent.createChild("path")
        .setStrokeLineWidth(opts.line_width)
        .setStrokeLineJoin("round")
        .setStrokeLineCap("round");
}

# Create a new path and draw a circle, with center (x,y) and diameter d
var make_circle = func(parent, x, y, d) {
    var r = d/2.0;
    return make_path(parent)
        .moveTo(x + r, y)
        .arcSmallCW(r, r, 0, -d, 0)
        .arcSmallCW(r, r, 0, d, 0);
}

# Create a new path and draw a dot, with center (x,y) and diameter d
var make_dot = func(parent, x, y, d) {
    return make_path(parent)
        # Hack
        .moveTo(x,y).line(0.001,0)
        .setStrokeLineWidth(d)
        .setStrokeLineCap("round");
}

# Create a new text element with default options.
var make_text = func(parent) {
    return parent.createChild("text")
        .setAlignment("center-bottom")
        .setFontSize(80, 1);
}

# Create a new text element, and initialize its position and content.
# Intended for fixed text elements.
var make_label = func(parent, x, y, text) {
    return make_text(parent)
        .setText(text)
        .setTranslation(x,y);
}


### HUD Canvas.
#
# This class only creates the class and a couple of root groups,
# and handles some optical effects (clipping, parallax).
# It does not contain any graphical elements (they are in
# the class HUD from either ajs-hud.nas or ja-hud.nas).
#
# This class exposes a canvas group via get_group().
# This group is centered on the aircraft forward axis, and uses 0.01deg as unit.
# (note: choosing a larger unit, e.g. 1deg, seems to cause issues
# such as circles looking like squares. Maybe due to rounding?)

var HUDCanvas = {
    new: func() {
        var m = { parents: [HUDCanvas], };
        m.initialize();
        m.centered = TRUE;
        return m;
    },

    initialize: func {
        # In internal units (0.01deg)
        var canvas_width = opts.canvas_ang_width*100;
        var width = opts.ang_width*100;
        me.canvas_opts = {
            name: "HUD",
            size: [opts.res, opts.res],
            view: [canvas_width, canvas_width],
            mipmapping: 1,
        };

        me.canvas = canvas.new(me.canvas_opts);
        me.canvas.setColorBackground(0, 0, 0, 0);
        me.root = me.canvas.createGroup("root");
        me.root.set("font", "LiberationFonts/LiberationSans-Bold.ttf")
            .setTranslation(canvas_width/2, canvas_width/2);

        # Group centered on the HUD optical axis.
        # (Used with HUD shader off, when simulating parallax in Nasal).
        me.optical_axis = me.root.createChild("group", "optical axis")
            # Clipping
            .set("clip-frame", canvas.Element.LOCAL)
            .set("clip", sprintf("rect(-%d, %d, %d, -%d)", width/2, width/2, width/2, width/2));

        # Clip the picture to a 20deg diameter disk.
        me.optical_axis.createChild("image")
            .setTranslation(-width, width)
            .setScale(width/256)
            .set("z-index",50)
            .set("blend-source-rgb","zero")
            .set("blend-source-alpha","zero")
            .set("blend-destination-rgb","one")
            .set("blend-destination-alpha","one-minus-src-alpha")
            .set("src", "Aircraft/JA37/gui/canvas-blend-mask/hud-global-mask.png");

        # Group centered on the aircraft forward axis.
        me.forward_axis = me.optical_axis.createChild("group", "forward axis")
            .setTranslation(0, -opts.optical_axis_pitch_offset * 100);

        me.grp_hud = me.forward_axis.createChild("group", "HUD");
        me.grp_backup = me.forward_axis.createChild("group", "Backup sight");

        me.bright_hud = -1;
        me.bright_bck = -1;
    },

    add_placement: func(placement) {
        me.canvas.addPlacement(placement);
    },

    get_group_hud: func {
        return me.grp_hud;
    },

    get_group_backup: func {
        return me.grp_backup;
    },

    # Update the position of me.optical_axis to simulate parallax.
    update_parallax: func {
        # With ALS, the HUD shader deals with parallax, simply recenter the group.
        if (input.use_ALS.getBoolValue()) {
            if (!me.centered) {
                me.optical_axis.setScale(1);
                me.optical_axis.setTranslation(0, 0);
                me.centered = TRUE;
            }
            return;
        }

        # Scaling
        var distance = input.view_z.getValue() - opts.hud_center_z;
        var scale = distance * 2 * math.tan(opts.canvas_ang_width/2*D2R) / opts.hud_width;
        me.optical_axis.setScale(scale);

        # Translation
        var m_to_hud_units = opts.canvas_ang_width * 100 / opts.hud_width;
        var x_offset = input.view_x.getValue() * m_to_hud_units;
        var y_offset = (opts.hud_center_y - input.view_y.getValue()) * m_to_hud_units;
        # This group must not be centered in front of the pilot eyes, but 7.3deg below.
        y_offset += distance * math.tan(opts.optical_axis_pitch_offset*D2R) * m_to_hud_units;
        me.optical_axis.setTranslation(x_offset, y_offset);

        me.centered = FALSE;
    },

    update_brightness: func {
        var bright_hud = input.bright_hud.getValue();
        if (bright_hud != me.bright_hud) {
            me.bright_hud = bright_hud;
            me.grp_hud.setColor(0,1,0,me.bright_hud);
        }

        var bright_bck = input.bright_bck.getValue();
        if (bright_bck != me.bright_bck) {
            me.bright_bck = bright_bck;
            me.grp_backup.setColor(1,0.5,0,me.bright_bck);
        }

        input.bright.setValue(math.max(me.bright_hud, me.bright_bck));
    },
};

var hud_canvas = nil;
var hud = nil;

var initialize = func {
    hud_canvas = HUDCanvas.new();
    hud_canvas.add_placement({"node": "hud", "texture": "hud.png"});
    hud = HUD.new(hud_canvas.get_group_hud());
    hud_canvas.update_brightness();

    setlistener(input.bright_hud, func { hud_canvas.update_brightness(); });
    setlistener(input.bright_bck, func { hud_canvas.update_brightness(); });
}

var update = func {
    hud_canvas.update_parallax();
    hud.update();
}
