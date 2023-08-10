#### This file contains all HUD code shared by the JA and AJS variants.

var TRUE = 1;
var FALSE = 0;


var extrapolate = func (x, x1, x2, y1, y2) {
    return y1 + ((x - x1) / (x2 - x1)) * (y2 - y1);
};


# Milliradians to HUD units (1/100 deg)
var MIL2HUD = R2D/10;


var input = utils.property_map({
    heading:        "/instrumentation/heading-indicator/indicated-heading-deg",
    pitch:          "/instrumentation/attitude-indicator/indicated-pitch-deg",
    roll:           "/instrumentation/attitude-indicator/indicated-roll-deg",
    speed:          "/instrumentation/airspeed-indicator/indicated-speed-kmh",
    speed_kt:       "/instrumentation/airspeed-indicator/indicated-speed-kt",
    groundspeed:    "/velocities/groundspeed-kt",
    mach:           "/instrumentation/airspeed-indicator/indicated-mach",
    fpv_up:         "/instrumentation/fpv/angle-up-deg",
    fpv_right:      "/instrumentation/fpv/angle-right-deg",
    fpv_track:      "/instrumentation/fpv/track-true-deg",
    fpv_pitch:      "/instrumentation/fpv/pitch-deg",
    head_true:      "/orientation/heading-deg",
    alpha:          "/orientation/alpha-deg",
    g_load:         "/instrumentation/accelerometer/g-force-indicated",
    high_alpha:     "/fdm/jsbsim/autoflight/high-alpha",
    approach_alpha: "/fdm/jsbsim/systems/flight/approach-alpha",
    alt:            "/instrumentation/altimeter/displays-altitude-meter",
    alt_aal:        "/instrumentation/altimeter/indicated-altitude-aal-meter",
    airbase_alt_ft: "/instrumentation/altimeter/airbase-altitude-ft",
    rad_alt:        "/instrumentation/radar-altimeter/radar-altitude-m",
    rad_alt_ready:  "/instrumentation/radar-altimeter/ready",
    pres_alt:       "/instrumentation/altimeter/pressure-alt-meter",
    ref_alt:        "/ja37/displays/reference-altitude-m",
    terrain_hgt:    "/ja37/avionics/terrain-height-m",
    true_alt_ft:    "/position/altitude-ft",
    rm_active:      "/instrumentation/waypoint-indicator/active",
    wp_bearing:     "/instrumentation/waypoint-indicator/true-bearing-deg",
    eta:            "/instrumentation/waypoint-indicator/eta-s",
    hud_slav:       "/ja37/hud/switch-slav",
    gear_pos:       "/gear/gear/position-norm",
    use_ALS:        "/sim/rendering/shaders/skydome",
    view_x:         "/sim/current-view/x-offset-m",
    view_y:         "/sim/current-view/y-offset-m",
    view_z:         "/sim/current-view/z-offset-m",
    wow:            "/fdm/jsbsim/gear/unit[0]/WOW",
    units_metric:   "/ja37/hud/units-metric",
    qfe_warning:    "ja37/displays/qfe-warning",
    nav_lock:       "/instrumentation/nav[0]/in-range",
    nav_defl:       "/instrumentation/nav[0]/heading-needle-deflection",
    nav_rdl:        "/instrumentation/nav[0]/radials/target-radial-deg",
    nav_has_gs:     "/instrumentation/nav[0]/has-gs",
    nav_gs_lock:    "/instrumentation/nav[0]/gs-in-range",
    nav_gs_defl:    "/instrumentation/nav[0]/gs-needle-deflection-deg",
    tils_steady:    "/instrumentation/TLS-light-steady",
    tils_blink:     "/instrumentation/TLS-light-blink",
    APmode:         "/fdm/jsbsim/autoflight/mode",
    alt_bars_flash: "/fdm/jsbsim/systems/indicators/flashing-alt-bars",
    ajs_bars_flash: "/fdm/jsbsim/systems/mkv/ajs-alt-bars-blink",
    ja_gpw:         "/fdm/jsbsim/systems/mkv/ja-pull-up-arrow",
    twoHz:          "/ja37/blink/two-Hz/state",
    fourHz:         "/ja37/blink/four-Hz/state",
    fiveHz:         "/ja37/blink/five-Hz/state",
    wpn_knob:       "/controls/armament/weapon-panel/selector-knob",
    wingspan:       "/controls/armament/wingspan",
    gunsight_dist:  "/instrumentation/gunsight[0]/distance-m",
    arak_long:      "/controls/armament/weapon-panel/switch-impulse",
    gnd_aiming:     "/ja37/hud/ground-aiming",
    bright:         "/ja37/hud/brightness",
    bright_hud:     "/ja37/hud/brightness-si",
    bright_bck:     "/ja37/hud/brightness-res",
    rotation_speed: "/fdm/jsbsim/systems/flight/rotation-speed-kmh",
    show_ground_h:  "/ja37/hud/display-terrain-height",
    alt_window:     "/ja37/hud/display-alt-window",
    qnh_mode:       "/ja37/hud/qnh-mode",
    airbase_index:  "/ja37/hud/display-alt-base",
    true_alt_ft:    "/fdm/jsbsim/position/h-sl-ft",
    true_alt_agl_ft:"/fdm/jsbsim/position/h-agl-ft",
    scene_red:      "/rendering/scene/diffuse/red",
});


### /!\ NOTE ON CANVAS STYLE PROPERTIES
#
# Goal: setting the HUD colour globally (with a single property on the root group).
#
# Canvas has cascading (a style set on a group propagates to its children),
# which can be used to accomplish this goal.
#
# Problem is, path elements require to set the colour with "stroke",
# while text elements require to set it with "fill".
# And if you set "fill" on a (closed) path, or "stroke" on text, it looks wrong.
# Which means you can't just set "fill" and "stroke" at the root.
# The Canvas nasal API has a method .setColor() for this reason:
# it sets "fill" on text, "stroke" on colour, and on groups it propagates
# to all text and path descendants, which is stupid and horribly slow.
#
# Having separate groups for text and paths is also out of the question,
# it would mean duplicating all the group transformations logic.
#
# So here's my stupid solution to this problem:
# 1. Set "fill" and "stroke" to the desired colour on the root group.
# 2. Set "fill": "none" on all paths, and "stroke": "none" on all text individually,
#    to mask the undesired global style.
#
# Step 2 is slow and stupid (equivalent to calling .setColor() on the root),
# but it only needs to be done when creating the canvas, so it's fine.
# Afterwards, to change the colour, you only need to change the "fill" and "stroke"
# styles of the root, which is _way_ faster than calling .setColor() on the root.
#
# Setting "fill"/"stroke": "none" is done by the constructors make_path() and make_text() below.
#
# If you ever need a filled path, it suffice to not add "fill": "none" on that path.
# The second (optional) argument of make_path() does exactly that.
#
#
# All of the above means that any setColor() or setFillColor()
# in the HUD code is almost certainly an error.


### Canvas elements creators

# Create a new path.
var make_path = func(parent, fill=0) {
    var p = parent.createChild("path");
    # Mask the global "fill" colour, cf. remarks above.
    if (!fill) p.set("fill", "none");
    return p;
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
        .moveTo(x,y).line(0.001*d,0)
        .setStrokeLineWidth(d)
        .setStrokeLineCap("round");
}

# Create a new text element with default options.
var make_text = func(parent) {
    return parent.createChild("text")
        # Mask the global "stroke" colour, cf. remarks above.
        .set("stroke", "none");
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
        me.root.setTranslation(canvas_width/2, canvas_width/2)
            # Default options
            # Text
            .set("font", "LiberationFonts/LiberationSans-Bold.ttf")
            .set("character-size", 80)
            .set("character-aspect-ratio", 1)
            .set("alignment", "center-bottom")
            # Paths
            .set("stroke-width", opts.line_width)
            .set("stroke-linecap", "round")
            .set("stroke-linejoin", "round");

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
            .set("src", "Aircraft/JA37/Nasal/displays/hud-mask.png");

        # Group centered on the aircraft forward axis.
        me.forward_axis = me.optical_axis.createChild("group", "forward axis")
            .setTranslation(0, -opts.optical_axis_pitch_offset * 100);

        me.grp_hud = me.forward_axis.createChild("group", "HUD");
        me.grp_backup = me.forward_axis.createChild("group", "Backup sight");

        me.bright_hud = 0;
        me.bright_bck = 0;

        # For parallax correction
        me.last_view_x = 0;
        me.last_view_y = 0;
        me.last_view_z = 0;
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
    #
    # This allows the rest of the HUD code to pretend that the canvas
    # is mapped to a disk of radius 'canvas_ang_width/2',
    # centered around the designated optical axis, in front of the eye.
    update_parallax: func(force=0) {
        var pos = [
            input.view_x.getValue(),
            input.view_y.getValue(),
            input.view_z.getValue(),
        ];
        if (!force and pos[0] == me.last_view_x and pos[1] == me.last_view_y and pos[2] == me.last_view_z) return;
        me.last_view_x = pos[0];
        me.last_view_y = pos[1];
        me.last_view_z = pos[2];

        # Position relative to HUD
        # x right, y up, z forward
        pos = vector.Math.minus(pos, [
            0,
            opts.hud_center_y,
            opts.hud_center_z,
        ]);

        # Rotate to match optical axis
        var cs = math.cos(opts.optical_axis_pitch_offset*D2R);
        var sn = math.sin(opts.optical_axis_pitch_offset*D2R);
        pos = [
            pos[0],
            cs * pos[1] - sn * pos[2],
            sn * pos[1] + cs * pos[2],
        ];

        # Scaling
        # pos[2] is normally positive (view behind the HUD)
        var scale = pos[2] * 2 * math.tan(opts.canvas_ang_width/2*D2R) / opts.hud_size;
        me.optical_axis.setScale(scale);

        # Translation
        var m_to_hud_units = opts.canvas_ang_width * 100 / opts.hud_size;
        var x_offset = pos[0] * m_to_hud_units;
        var y_offset = -pos[1] * m_to_hud_units;   # canvas y is down
        me.optical_axis.setTranslation(x_offset, y_offset);

        # 'update()' required to have this take effect in the same frame
        # (Otherwise the HUD picture follows a frame late, which looks like it is stuttering.
        # This is extremely annoying when using headtracking.)
        me.optical_axis.update();
    },

    set_hud_brightness: func(brightness) {
        var color = sprintf("rgba(%s,%f)", opts.color, brightness);
        me.grp_hud.set("stroke", color);
        me.grp_hud.set("fill", color);
    },

    set_backup_brightness: func(brightness) {
        var color = sprintf("rgba(%s,%f)", opts.backup_color, brightness);
        me.grp_backup.set("stroke", color);
        me.grp_backup.set("fill", color);
    },

    update_brightness: func {
        var scene_bright = input.scene_red.getValue();
        # Brightness level from photocell
        me.bright_hud = 0.7 + 0.3*scene_bright*scene_bright;
        # Adjust with brightness knob.
        me.bright_hud *= (0.7 + 0.6 * input.bright_hud.getValue());
        me.bright_hud = math.clamp(me.bright_hud, 0, 1);
        me.set_hud_brightness(me.bright_hud);

        if (variant.JA) {
            me.bright_bck = input.bright_bck.getValue() * 0.4;
            if (me.bright_bck > 0) me.bright_bck += 0.6;
            me.set_backup_brightness(me.bright_bck);
        }

        input.bright.setValue(math.max(me.bright_hud, me.bright_bck) * 1.2);
    },
};

var hud_canvas = nil;
var hud = nil;
var backup_sight = nil;
var parallax_timer = nil;

var initialize = func {
    hud_canvas = HUDCanvas.new();
    hud_canvas.add_placement(opts.placement);
    hud = HUD.new(hud_canvas.get_group_hud());
    if (variant.JA) {
        backup_sight = BackupSight.new(hud_canvas.get_group_backup());
    }
    hud_canvas.update_brightness();

    setlistener(input.bright_hud, func { hud_canvas.update_brightness(); }, 0, 0);
    setlistener(input.bright_bck, func { hud_canvas.update_brightness(); }, 0, 0);

    # View properties are tied, which makes these update annoying to do.
    # - Timer is for update after the core logic, which doesn't trigger listeners.
    # - Listeners are for any nasal script which changes the view (e.g. headtracking).
    #   They are needed because because the timer might run before headtracking script,
    #   which results in the view stuttering.
    setlistener(input.view_x, func { hud_canvas.update_parallax(); }, 0, 0);
    setlistener(input.view_y, func { hud_canvas.update_parallax(); }, 0, 0);
    setlistener(input.view_z, func { hud_canvas.update_parallax(); }, 0, 0);
}

var update = func {
    hud_canvas.update_parallax();
    hud.update();
    if (variant.JA) {
        hud_canvas.get_group_backup().setVisible(
            hud_canvas.bright_bck > 0 and power.prop.dcMainBool.getBoolValue()
        );
    }
}

var loop_slow = func {
    # For ambient light change.
    hud_canvas.update_brightness();
}
