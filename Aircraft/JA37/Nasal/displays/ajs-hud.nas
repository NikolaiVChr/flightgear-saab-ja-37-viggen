var TRUE = 1;
var FALSE = 0;


# General, constant options
var opts = {
    res: 1024,
    ang_width: 2000,    # Coordinate system uses 1/100 deg as unit. Issues occur if this value is chosen too small.
    optical_axis_pitch_offset: 7.3,
    line_width: 10,
};

var input = {
    heading:        "/instrumentation/heading-indicator/indicated-heading-deg",
    pitch:          "/instrumentation/attitude-indicator/indicated-pitch-deg",
    roll:           "/instrumentation/attitude-indicator/indicated-roll-deg",
    speed:          "/instrumentation/airspeed-indicator/indicated-speed-kmh",
    fpv_up:         "/instrumentation/fpv/angle-up-stab-deg",
    fpv_right:      "/instrumentation/fpv/angle-right-stab-deg",
    fpv_head_true:  "/instrumentation/fpv/heading-true",
    head_true:      "/orientation/heading-deg",
    alpha:          "/orientation/alpha-deg",
    high_alpha:     "/fdm/jsbsim/autoflight/high-alpha",
    weight:         "/fdm/jsbsim/inertia/weight-lbs",
    alt:            "/instrumentation/altimeter/indicated-altitude-meter",
    rad_alt:        "/instrumentation/radar-altimeter/radar-altitude-m",
    rad_alt_ready:  "/instrumentation/radar-altimeter/ready",
    ref_alt:        "/ja37/displays/reference-altitude-m",
    rm_active:      "/autopilot/route-manager/active",
    wp_bearing:     "/autopilot/route-manager/wp/bearing-deg",
    eta:            "/autopilot/route-manager/wp/eta-seconds",
    fpv_fin_blink:  "/ja37/blink/four-Hz/state",
    declutter:      "/ja37/hud/declutter-mode",
    gear_pos:       "/gear/gear/position-norm",
};

foreach(var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}



### Canvas elements creators with default options

# Create a new path with default options
var make_path = func(parent) {
    return parent.createChild("path")
        .setColor(0,1,0,1)
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

# Create a new path and draw a dot (filled circle), with center (x,y) and diameter d
var make_dot = func(parent, x, y, d) {
    return make_circle(parent, x, y, d)
        .setStrokeLineWidth(0)
        .setColorFill(0,1,0,1);
}

# Create a new text element with default options.
var make_text = func(parent) {
    return parent.createChild("text")
        .setColor(0,1,0,1)
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



### HUD elements classes

# General conventions/methods for HUD elements classes:
# - new(parent): creates the element, 'parent' must be a Canvas
#                group used as root for the element.
# - set_mode(mode): used to indicate that the HUD display mode changed
# - update(): updates the element

# Artificial horizon and pitch scale lines
#
# The artificial horizon canvas groups are used for several other HUD elements.
# Specifically, the following
var Horizon = {
    new: func(parent) {
        var m = { parents: [Horizon], parent: parent, mode: -1 };
        m.initialize();
        return m;
    },

    initialize: func {
        me.roll_group = me.parent.createChild("group", "roll");
        me.horizon_group = me.roll_group.createChild("group", "horizon");
        me.ref_point_group = me.horizon_group.createChild("group", "reference point");
        me.navigation = me.ref_point_group.createChild("group", "nav artificial horizon");
        me.landing = me.ref_point_group.createChild("group", "landing artificial horizon");

        make_path(me.navigation)
            .moveTo(-1000,0).horizTo(-100).moveTo(1000,0).horizTo(100)
            .moveTo(-1000,-500).horiz(630).moveTo(1000,-500).horiz(-630)
            .moveTo(-1000,500).horiz(630).moveTo(1000,500).horiz(-630);
        make_dot(me.navigation, 0, 0, opts.line_width*2);
        make_label(me.navigation, -500, -520, "+5");
        make_label(me.navigation, 500, -520, "+5");
        make_label(me.navigation, -500, 520, "-5").setAlignment("center-top");
        make_label(me.navigation, 500, 520, "-5").setAlignment("center-top");

        make_path(me.landing)
            .moveTo(-1000,0).horizTo(1000)
            .moveTo(-1000,-500).horiz(630).moveTo(1000,-500).horiz(-630)
            .moveTo(-470, 287).horizTo(-100).moveTo(470, 287).horizTo(100);
        make_dot(me.landing, 0, 287, opts.line_width*2);
        make_label(me.landing, -500, -520, "+5");
        make_label(me.landing, 500, -520, "+5");
    },

    set_mode: func(mode) {
        me.mode = mode;
        if (mode == HUD.MODE_FINAL_NAV or mode == HUD.MODE_FINAL_OPT) {
            me.navigation.hide();
            me.landing.show();
        } else {
            me.navigation.show();
            me.landing.hide();
        }
    },

    update: func(fpv_rel_bearing) {
        me.roll_group.setRotation(-input.roll.getValue() * D2R);
        me.horizon_group.setTranslation(0, input.pitch.getValue() * 100);

        # Position of reference point (indicates target heading)
        if (me.mode == HUD.MODE_TAKEOFF_ROLL or me.mode == HUD.MODE_TAKEOFF_ROTATE) {
            # locked on forward axis at takeoff
            me.ref_point_offset = 0;
        } elsif (!input.rm_active.getBoolValue()) {
            # locked on FPV if no target is defined
            me.ref_point_offset = fpv_rel_bearing;
        } else {
            # towards target heading, clamped around FPV
            me.ref_point_offset = input.wp_bearing.getValue() - input.heading.getValue();
            me.ref_point_offset = math.periodic(-180, 180, me.ref_point_offset);
            me.ref_point_offset = math.clamp(me.ref_point_offset, fpv_rel_bearing - 3.6, fpv_rel_bearing + 3.6);
        }

        me.ref_point_group.setTranslation(me.ref_point_offset * 100, 0);
    },

    get_horizon_group: func { return me.horizon_group; },
    get_ref_point_group: func { return me.ref_point_group; },
    get_ref_point_offset: func { return me.ref_point_offset; },
};

var AltitudeBars = {
    new: func(parent) {
        var m = { parents: [AltitudeBars], parent: parent, mode: -1, base_pos: 0 };
        m.initialize();
        return m;
    },

    initialize: func {
        me.group = me.parent.createChild("group", "altitude referrence");
        me.bars = [nil, nil, nil];
        for (var i=1; i<=3; i+=1) {
            me.bars[i-1] = make_path(me.group)
                .moveTo(-100*i,0).vert(-100*i).moveTo(100*i,0).vert(-100*i);
        }
        me.ref_bars_group = me.group.createChild("group");
        me.ref_bars = make_path(me.ref_bars_group)
            .moveTo(-330, 0).vert(-300).moveTo(330,0).vert(-300);
        me.rhm_index = make_path(me.ref_bars_group)
            .moveTo(-305, 0).horiz(-50).moveTo(305,0).horiz(50);
    },

    # Set the bars normalised position.
    # pos=0: bottom of the bars on the horizon (indicates alt=0)
    # pos=1: top of the bars on the horizon (indicates alt=commanded alt)
    set_bars_pos: func(pos) {
        for (var i=1; i<=3; i+=1) {
            me.bars[i-1].setTranslation(0, 100 * i * pos);
        }
        me.ref_bars_group.setTranslation(0, 300 * pos);
        # Store position of the bottom of bars. It is used to place other hud elements.
        me.base_pos = 300 * pos;
    },

    set_mode: func(mode) {
        me.mode = mode;
        if (me.mode == HUD.MODE_NAV_DECLUTTER or me.mode == HUD.MODE_FINAL_OPT) {
            me.group.hide();
        } elsif (me.mode == HUD.MODE_FINAL_NAV) {
            me.group.show();
            me.group.setTranslation(0, 287);
        } else {
            me.group.show();
            me.group.setTranslation(0, 0);
        }
    },

    # All altitudes in meters
    update: func {
        if (me.mode == HUD.MODE_NAV_DECLUTTER or me.mode == HUD.MODE_FINAL_OPT) return;

        var altitude = input.alt.getValue();
        var radar_altitude = input.rad_alt_ready.getBoolValue() ? input.rad_alt.getValue() : nil;
        var command_altitude = input.ref_alt.getValue();

        # restrict displayed commanded altitude
        var min_command = math.max(altitude/2, altitude-500);
        var max_command = math.min(altitude*2, altitude+250);
        command_altitude = math.clamp(command_altitude, min_command, max_command);
        if (command_altitude <= 50) command_altitude = 50;

        me.set_bars_pos(math.clamp(altitude / command_altitude, 0, 2));

        # reference altitude bars
        if (command_altitude <= 500) {
            me.ref_bars.show();
            me.ref_bars.setScale(1, 100/command_altitude);
        } else {
            me.ref_bars.hide();
        }

        # radar altitude index
        if (radar_altitude != nil and me.mode != HUD.MODE_TAKEOFF_ROLL) {
            me.rhm_index.show();
            var rhm_pos = math.clamp((altitude - radar_altitude) / command_altitude, -1, 1);
            me.rhm_index.setTranslation(0, -300 * rhm_pos);
        } else {
            me.rhm_index.hide();
        }
    },

    # Get the vertical position of the bottom of the (largest) altitude bars,
    # relative to the horizon line, in the HUD coordonate units.
    # Used to position the heading and time line just below the altitude bars.
    get_base_pos: func {
        return me.base_pos;
    },
};

var DigitalAltitude = {
    new: func(parent) {
        var m = { parents: [DigitalAltitude], parent: parent, mode: -1 , side: 1, x: -430, y: -20 };
        m.initialize();
        return m;
    },

    initialize: func {
        me.text = make_text(me.parent);
        me.text.enableUpdate();
    },

    set_mode: func(mode) {
        me.mode = mode;
        if (me.mode == HUD.MODE_FINAL_NAV or me.mode == HUD.MODE_FINAL_OPT) {
            me.x = -380;
            me.y = 267;
        } else {
            me.x = -430;
            me.y = -20;
        }
    },

    # Altitude in meters
    update: func(ref_point_offset) {
        var altitude = input.alt.getValue();
        var str = "";
        if (altitude < -2.5) {
            # Negative altitudes (min -97.5), 2 digits, precision 5m
            altitude = math.round(altitude, 5);
            altitude = math.clamp(altitude, -95, -5);
            str = sprintf("-%.2d", -altitude);
        } elsif (altitude < 995) {
            # Below 1000m, 3 digits, precision 10m, precision 5m below 100m
            altitude = math.round(altitude, altitude < 100 ? 5 : 10);
            altitude = math.clamp(altitude, 0, 990);
            str = sprintf("%.3d", altitude);
        } else {
            # Above 1000m, 2 digits, precision 100m, units km, modulo 10km
            altitude = math.round(altitude/1000, 0.1);
            str = sprintf("%.1d,%.1d", math.mod(math.floor(altitude), 10), math.mod(altitude*10, 10));
        }
        me.text.updateText(str);

        # update position
        if (ref_point_offset < -2) me.side = -1; # switch to right side
        elsif (ref_point_offset > 0) me.side = 1;
        me.text.setTranslation(me.x * me.side, me.y);
    },
};

var DistanceLine = {
    new: func(parent) {
        var m = { parents: [DistanceLine], parent: parent, mode: -1 };
        m.initialize();
        return m;
    },

    initialize: func {
        me.group = me.parent.createChild("group", "distance line");
        me.line = make_path(me.group).moveTo(-300, 0).horizTo(300);
        me.middle_mark = make_path(me.group).moveTo(0, 0).vert(-50);
        me.left_mark = make_path(me.group).moveTo(0, 0).vert(-50);
        me.right_mark = make_path(me.group).moveTo(0, 0).vert(-50);
    },

    set_mode: func(mode) {
        me.mode = mode;
        if (mode == HUD.MODE_TAKEOFF_ROLL) {
            me.group.show();
            me.group.setTranslation(0, 1000);
            me.set_mid_mark(TRUE);
            me.set_side_marks(0.667);
        } elsif (mode == HUD.MODE_NAV) {
            me.set_mid_mark(TRUE);
            me.set_side_marks(0);
        } else {
            me.group.hide();
        }
    },

    # Time/distance line length, normalised in [0,1]. 0 hides the line.
    set_line: func(length) {
        if (length > 0) {
            me.line.setScale(length, 1);
            me.line.show();
        } else {
            me.line.hide();
        }
    },

    # Toggle middle marker on/off.
    set_mid_mark: func(show) {
        if (show) me.middle_mark.show();
        else me.middle_mark.hide();
    },

    # Set side markers position, normalised in [0,1]. 0 hides the markers.
    set_side_marks: func(pos) {
        if (pos > 0) {
            me.left_mark.setTranslation(-300*pos, 0);
            me.right_mark.setTranslation(300*pos, 0);
            me.left_mark.show();
            me.right_mark.show();
        } else {
            me.left_mark.hide();
            me.right_mark.hide();
        }
    },

    update: func(alt_bars_pos) {
        if (me.mode == HUD.MODE_TAKEOFF_ROLL) {
            # rotation speeds:
            #28725 lbm -> 250 km/h
            #40350 lbm -> 280 km/h
            var weight = input.weight.getValue();
            var rotation_speed = 250+((weight-28725)/(40350-28725))*(280-250);#km/h
            rotation_speed = math.clamp(rotation_speed, 250, 300);

            me.set_line(input.speed.getValue() * 0.667 / rotation_speed);
        } elsif (me.mode == HUD.MODE_NAV) {
            var eta = input.eta.getValue();
            if (eta != nil and eta <= 60) {
                me.group.show();
                me.set_line(eta / 60);
                me.group.setTranslation(0, alt_bars_pos);
            } else {
                me.group.hide();
            }
        }
    },
};

var HeadingScale = {
    new: func(parent) {
        var m = { parents: [HeadingScale], parent: parent, mode: -1 };
        m.initialize();
        return m;
    },

    initialize: func {
        me.group = me.parent.createChild("group", "heading scale");
        me.text = [nil, nil, nil];
        for (var i=-1; i<=1; i+=1) {
            me.text[i+1] = make_text(me.group)
                .setTranslation(1000*i, 0)
                .setAlignment("center-top");
            me.text[i+1].enableUpdate();
        }
        me.ticks = make_path(me.group)
            .moveTo(-1500, 5).vert(50)
            .moveTo(-500, 5).vert(50)
            .moveTo(500, 5).vert(50)
            .moveTo(1500, 5).vert(50);
    },

    set_mode: func(mode) {
        me.mode = mode;
        if (me.mode == HUD.MODE_NAV_DECLUTTER) {
            me.declutter_visible = FALSE;
            me.group.hide();
        } else {
            me.group.show();
        }
    },

    declutter_toggle: func {
        if (me.declutter_visible) {
            me.declutter_visible = FALSE;
            me.group.hide();
        } else {
            me.declutter_visible = TRUE;
            me.group.show();
        }
    },

    update: func(alt_bars_pos) {
        var heading = input.heading.getValue()/10;
        var heading_int = math.round(heading);
        var heading_frac = heading - heading_int;
        var text_grads = [heading_int-1, heading_int, heading_int+1];
        for (var i=0; i<3; i+=1) {
            me.text[i].updateText(sprintf("%02.0f", math.periodic(1, 37, text_grads[i])));
        }

        if (me.mode == HUD.MODE_TAKEOFF_ROLL) {
            var vpos = 1000;
        } elsif (me.mode == HUD.MODE_FINAL_NAV or me.mode == HUD.MODE_FINAL_OPT) {
            var vpos = 0;
        } elsif (me.mode == HUD.MODE_NAV_DECLUTTER) {
            var vpos = 300;
        } else {
            var vpos = alt_bars_pos;
        }
        me.group.setTranslation(heading_frac * -1000, vpos + 10);
    },
};

var FPV = {
    new: func(parent) {
        var m = { parents: [FPV], parent: parent, mode: -1 };
        m.initialize();
        return m;
    },

    initialize: func {
        me.group = me.parent.createChild("group", "flight path vector");

        me.circle = make_circle(me.group, 0, 0, 50);
        me.wings = make_path(me.group).moveTo(-25, 0).horiz(-75).moveTo(25, 0).horiz(75);
        me.tail = make_path(me.group).moveTo(0,-25).vert(-50);
    },

    set_mode: func(mode) {
        me.mode = mode;
        if (me.mode == HUD.MODE_TAKEOFF_ROLL or me.mode == HUD.MODE_TAKEOFF_ROTATE) {
            me.group.setTranslation(0, 1000);
            me.set_fin(FALSE);
        } else {
            me.set_fin(TRUE);
        }
    },

    # Display 'fin' (speed error indicator)
    # pos: normalised in [-1,1], 0: correct speed, -1: speed is too low
    set_fin: func(show, pos=0, blink=0) {
        if (show and (!blink or input.fpv_fin_blink.getBoolValue())) {
            me.tail.show();
            me.tail.setTranslation(0, -50*pos);
        } else {
            me.tail.hide();
        }
    },

    # Update 'fin' (speed error indicator) for landing mode
    update_landing_speed_error: func {
        var dev = 0;
        var blink = FALSE;
        if (input.gear_pos.getValue() != 1) {
            # Gear (partially) up, indicates speed deviation from 550km/h, max deviation is 37km/h
            dev = (input.speed.getValue() - 550) / 37;
        } else {
            # Gear full down, indicates alpha deviation from 12deg (or 15.5deg in high alpha mode)
            # maximum deviation is 3.3deg
            var high_alpha = input.high_alpha.getBoolValue();
            dev = - (input.alpha.getValue() - (high_alpha ? 15.5 : 12)) / 3.3;
            # If the lower limit of the indicator is reached, blink to indicate critical alpha
            # (in high alpha mode: 3/4 of lower limit).
            blink = (dev <= (high_alpha ? -0.75 : -1));
        }
        dev = math.clamp(dev, -1, 1);
        me.set_fin(TRUE, dev, blink);
    },

    update: func {
        if (me.mode == HUD.MODE_TAKEOFF_ROLL or me.mode == HUD.MODE_TAKEOFF_ROTATE) return;

        me.group.setTranslation(100 * input.fpv_right.getValue(), -100 * input.fpv_up.getValue());

        if (modes.main == modes.LANDING) {
            me.update_landing_speed_error();
        } else {
            me.set_fin(TRUE);
        }
    },
};



### Main HUD class
var HUD = {
    MODE_TAKEOFF_ROLL: 1,
    MODE_TAKEOFF_ROTATE: 2,
    MODE_NAV: 3,
    MODE_NAV_DECLUTTER: 4,
    MODE_FINAL_NAV: 5,
    MODE_FINAL_OPT: 6,

    new: func() {
        var m = { parents: [HUD], mode: -1 };
        m.initialize();
        return m;
    },

    canvas_opts: {
        name: "AJS HUD",
        size: [opts.res, opts.res],
        view: [opts.ang_width, opts.ang_width],
        mipmapping: 1,
    },

    addPlacement: func(placement) {
        me.canvas.addPlacement(placement);
    },

    initialize: func {
        me.canvas = canvas.new(me.canvas_opts);
        me.canvas.setColorBackground(0, 0, 0, 0);
        me.root = me.canvas.createGroup("root");
        me.root.set("font", "LiberationFonts/LiberationSans-Bold.ttf");

        me.groups = {};

        # Group centered on the HUD optical axis.
        # Using the HUD shader, it simply needs to be centered in the canvas.
        me.groups.optical_axis = me.root.createChild("group", "optical axis")
            .setTranslation(opts.ang_width/2, opts.ang_width/2);
        # Group centered on the aircraft forward axis.
        me.groups.forward_axis = me.groups.optical_axis.createChild("group", "forward axis")
            .setTranslation(0, -opts.optical_axis_pitch_offset * 100);

        # Artificial horizon. Most elements are attached to it.
        me.horizon = Horizon.new(me.groups.forward_axis);
        me.groups.horizon = me.horizon.get_horizon_group(); # Roll/Pitch stabilized group
        me.groups.ref_point = me.horizon.get_ref_point_group(); # Same + centered on reference point (target heading)

        # Other HUD elements
        me.alt_bars = AltitudeBars.new(me.groups.ref_point);
        me.dig_alt = DigitalAltitude.new(me.groups.ref_point);
        me.heading = HeadingScale.new(me.groups.horizon); # rooted on horizon, not ref_point: do not apply lateral offset
        me.distance = DistanceLine.new(me.groups.ref_point);
        me.fpv = FPV.new(me.groups.forward_axis);
    },

    set_mode: func(mode) {
        if (me.mode == mode) return;
        me.mode = mode;
        me.horizon.set_mode(mode);
        me.alt_bars.set_mode(mode);
        me.dig_alt.set_mode(mode);
        me.heading.set_mode(mode);
        me.distance.set_mode(mode);
        me.fpv.set_mode(mode);
    },

    update_mode: func {
        if (modes.main == modes.TAKEOFF) {
            if (me.mode != HUD.MODE_TAKEOFF_ROLL and me.mode != HUD.MODE_TAKEOFF_ROTATE) {
                me.set_mode(HUD.MODE_TAKEOFF_ROLL);
            } elsif (input.pitch.getValue() > 5) {
                me.set_mode(HUD.MODE_TAKEOFF_ROTATE);
            } elsif (input.pitch.getValue() < 3) {
                me.set_mode(HUD.MODE_TAKEOFF_ROLL);
            }
        } elsif (modes.main == modes.LANDING and (land.mode < 1 or land.mode == 4)) {
            me.set_mode(HUD.MODE_FINAL_OPT);
        } elsif (modes.main == modes.LANDING and land.mode == 3) {
            me.set_mode(HUD.MODE_FINAL_NAV);
        } elsif (modes.main == modes.LANDING) {
            # Initial landing phase, NAV display mode
            me.set_mode(HUD.MODE_NAV);
        } else { # Nav
            if (input.declutter.getBoolValue() and input.alt.getValue() < 97.5) {
                me.set_mode(HUD.MODE_NAV_DECLUTTER);
            } else {
                me.set_mode(HUD.MODE_NAV);
            }
        }
    },

    update: func {
        me.update_mode();
        me.fpv.update();
        var fpv_rel_bearing = input.fpv_head_true.getValue() - input.head_true.getValue();
        fpv_rel_bearing = math.periodic(-180, 180, fpv_rel_bearing);
        me.horizon.update(fpv_rel_bearing);
        var rel_bearing = me.horizon.get_ref_point_offset();
        me.dig_alt.update(rel_bearing);
        me.alt_bars.update();
        var alt_bars_pos = me.alt_bars.get_base_pos();
        me.distance.update(alt_bars_pos);
        me.heading.update(alt_bars_pos);
    },

    declutter_heading_toggle: func {
        me.heading.declutter_toggle();
    },
};
