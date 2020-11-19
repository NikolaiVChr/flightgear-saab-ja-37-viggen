# General, constant options
var opts = {
    res: 1024,              # Actual resolution of the canvas.
    ang_width: 20,          # Angular width of the HUD picture.
    canvas_ang_width: 21,   # Angular width to which the canvas is mapped.
                            # Adds a small margin due to border clipping issues.
    optical_axis_pitch_offset: 7.3,
    line_width: 10,
    # HUD physical dimensions
    hud_center_y: 0.7,
    hud_center_z: -4.06203,
    hud_width: 0.15,
};


### HUD elements classes

# General conventions/methods for HUD elements classes:
# - new(parent): creates the element, 'parent' must be a Canvas
#                group used as root for the element.
# - set_mode(mode): used to indicate that the HUD display mode changed
# - update(): updates the element

# Artificial horizon and pitch scale lines
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
        var m = { parents: [AltitudeBars], parent: parent, mode: -1 };
        m.initialize();
        return m;
    },

    initialize: func {
        me.group = me.parent.createChild("group", "altitude referrence");
        me.bars = [nil, nil, nil];
        for (var i=1; i<=3; i+=1) {
            me.bars[i-1] = make_path(me.group)
                .moveTo(-100*i,0).vert(100*i).moveTo(100*i,0).vert(100*i);
        }
        me.base_pos = 0;
        # Group centered on the top of the outer altitude bars.
        me.outer_bars_group = me.group.createChild("group");

        me.ref_bars = make_path(me.outer_bars_group)
            .setTranslation(0, 300) # bottom of outer bars
            .moveTo(-330, 0).vert(-300).moveTo(330,0).vert(-300);
        me.rhm_index = make_path(me.outer_bars_group)
            .moveTo(-305, 0).horiz(-50).moveTo(305,0).horiz(50);
        me.rhm_shown = FALSE;
    },

    # Set the bars normalised position.
    # pos=-1: bottom of the bars on the horizon (indicates alt=0)
    # pos=0: top of the bars on the horizon (indicates alt=commanded alt)
    set_bars_pos: func(pos) {
        for (var i=1; i<=3; i+=1) {
            me.bars[i-1].setTranslation(0, 100 * i * pos);
        }
        me.outer_bars_group.setTranslation(0, 300 * pos);
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

    # Clamp reference altitude to obtain the final value used for display.
    clamp_reference_altitude: func(ref_alt, alt) {
        # Fixed at takeoff
        if (me.mode == HUD.MODE_TAKEOFF_ROLL or me.mode == HUD.MODE_TAKEOFF_ROTATE) return 500;

        # Limits (whichever is more restrictive)
        # - between half and double the current altitude
        # - between -500 and +250 compared to the current altitude
        # Effectively, the former applies for ref_alt < 500, and the latter for ref_alt > 500.
        var min = math.max(alt/2, alt-500);
        var max = math.min(alt*2, alt+250);
        ref_alt = math.clamp(ref_alt, min, max);
        # Never less than 50.
        return math.max(ref_alt, 50);
    },

    # Reference altitude bars, displayed at reference altitude < 500m
    # Their length corresponds to 100m.
    update_ref_bars: func(ref_alt) {
        if (ref_alt <= 500) {
            me.ref_bars.show();
            me.ref_bars.setScale(1, 100/ref_alt);
        } else {
            me.ref_bars.hide();
        }
    },

    update_rhm_index: func(scale, bars_pos) {
        var rad_alt = input.rad_alt.getValue();
        # Off during takeoff before rotation.
        # Turns off at radar altitude > 575 (or if radar altitude is unavailable, obviously).
        # Turns back on at radar altitude < 550 (small margin to avoid hysteresis).
        if (me.mode == HUD.MODE_TAKEOFF_ROLL or !input.rad_alt_ready.getBoolValue() or rad_alt > 575) {
            me.rhm_shown = FALSE;
        } elsif (rad_alt < 550) {
            me.rhm_shown = TRUE;
        }

        if (!me.rhm_shown) {
            me.rhm_index.hide();
            return;
        }

        # Position relative to artificial horizon.
        var rhm_pos = rad_alt / scale;
        # Position relative to the top of outer altitude bars.
        rhm_pos -= bars_pos;
        # Clamp (max: top of outer altitude bars, min: length of alt bars below the bottom of bars).
        rhm_pos = math.clamp(rhm_pos, 0, 2);
        me.rhm_index.setTranslation(0, 300 * rhm_pos);
        me.rhm_index.show();
    },

    # All altitudes in meters
    update: func {
        if (me.mode == HUD.MODE_NAV_DECLUTTER or me.mode == HUD.MODE_FINAL_OPT) return;

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
        me.bars_pos = math.clamp((alt - ref_alt)/scale, -1, 1);
        me.set_bars_pos(me.bars_pos);

        me.update_ref_bars(ref_alt);
        me.update_rhm_index(scale, me.bars_pos);
    },

    # Get the vertical position of the bottom of the (largest) altitude bars,
    # relative to the horizon line, in the HUD coordonate units.
    # Used to position the heading and time line just below the altitude bars.
    get_base_pos: func {
        return 300 * (me.bars_pos + 1);
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
        if (altitude < 995) {
            # Below 1000m, 3 digits, 10m precision.
            # In declutter mode, 2 digits, 5m precision instead.
            # Below 0m, 2 digits
            if (me.mode == HUD.MODE_NAV_DECLUTTER) {
                altitude = math.round(altitude, 5);
                altitude = math.clamp(altitude, -95, 95);
            } else {
                altitude = math.round(altitude, 10);
                altitude = math.clamp(altitude, -90, 990);
            }
            if (altitude < 0) {
                str = sprintf("-%.2d", -altitude);
            } elsif (me.mode == HUD.MODE_NAV_DECLUTTER) {
                str = sprintf("%.2d", altitude);
            } else {
                str = sprintf("%.3d", altitude);
            }
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
            me.text[i].updateText(sprintf("%.2d", math.periodic(0, 36, text_grads[i])));
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

        make_circle(me.group, 0, 0, 50);                                        # circle
        make_path(me.group).moveTo(-25, 0).horiz(-75).moveTo(25, 0).horiz(75);  # wings
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
        if (show and (!blink or input.fourHz.getBoolValue())) {
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

        me.group.setTranslation(100 * input.fpv_right_stab.getValue(), -100 * input.fpv_up_stab.getValue());

        if (modes.landing) {
            me.update_landing_speed_error();
        } else {
            me.set_fin(TRUE);
        }
    },
};



### Main HUD class
var HUD = {
    MODE_STBY: 0,
    MODE_TAKEOFF_ROLL: 1,
    MODE_TAKEOFF_ROTATE: 2,
    MODE_NAV: 3,
    MODE_NAV_DECLUTTER: 4,
    MODE_FINAL_NAV: 5,
    MODE_FINAL_OPT: 6,

    new: func(root) {
        var m = { parents: [HUD], mode: -1 };
        m.initialize(root);
        return m;
    },

    initialize: func(root) {
        me.groups = {};

        # Group centered on the aircraft forward axis, with unit 0.01deg.
        # Provided by class HUDCanvas from hud-shared.nas
        me.root = root;

        # Artificial horizon. Most elements are attached to it.
        me.horizon = Horizon.new(me.root);
        me.groups.horizon = me.horizon.get_horizon_group(); # Roll/Pitch stabilized group
        me.groups.ref_point = me.horizon.get_ref_point_group(); # Same + centered on reference point (target heading)

        # Other HUD elements
        me.alt_bars = AltitudeBars.new(me.groups.ref_point);
        me.dig_alt = DigitalAltitude.new(me.groups.ref_point);
        me.heading = HeadingScale.new(me.groups.horizon); # rooted on horizon, not ref_point: do not apply lateral offset
        me.distance = DistanceLine.new(me.groups.ref_point);
        me.fpv = FPV.new(me.root);
    },

    set_mode: func(mode) {
        if (me.mode == mode) return;
        me.mode = mode;

        if (mode == HUD.MODE_STBY) {
            me.root.hide();
        } else {
            me.root.show();
            me.horizon.set_mode(mode);
            me.alt_bars.set_mode(mode);
            me.dig_alt.set_mode(mode);
            me.heading.set_mode(mode);
            me.distance.set_mode(mode);
            me.fpv.set_mode(mode);
        }
    },

    update_mode: func {
        if (!displays.common.hud_on) {
            me.set_mode(HUD.MODE_STBY);
        } elsif (modes.takeoff) {
            if (me.mode != HUD.MODE_TAKEOFF_ROLL and me.mode != HUD.MODE_TAKEOFF_ROTATE) {
                me.set_mode(HUD.MODE_TAKEOFF_ROLL);
            } elsif (input.pitch.getValue() > 5) {
                me.set_mode(HUD.MODE_TAKEOFF_ROTATE);
            } elsif (input.pitch.getValue() < 3) {
                me.set_mode(HUD.MODE_TAKEOFF_ROLL);
            }
        } elsif (modes.landing and (land.mode < 1 or land.mode == 4)) {
            me.set_mode(HUD.MODE_FINAL_OPT);
        } elsif (modes.landing and land.mode == 3) {
            me.set_mode(HUD.MODE_FINAL_NAV);
        } elsif (modes.landing and (land.mode == 1 or land.mode == 2)) {
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
        if (me.mode == HUD.MODE_STBY) return;

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
