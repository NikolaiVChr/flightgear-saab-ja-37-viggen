# General, constant options
var opts = {
    res: 512,               # Actual resolution of the canvas.
    ang_width: 20,          # Angular width of the HUD picture.
    canvas_ang_width: 21,   # Angular width to which the canvas is mapped.
                            # Adds a small margin due to border clipping issues.
    optical_axis_pitch_offset: 7.3,
    line_width: 10,
    # HUD physical dimensions. This is the object on which the Canvas is applied.
    # These values are only used for Nasal parallax correction (ALS off).
    hud_center_y: nil,  # see update_hud_position below
    hud_center_z: nil,  # see update_hud_position below
    # Maximum of width/height (actually, the size to which the texture is mapped).
    hud_size: 0.14,

    placement: {"node": "aj37hud", "texture": "hud.png"},

    color: "128,255,128",   # "R,G,B", 0 to 255
};


# AJS HUD movement.
# This function updates opts.hud_center_{y,z} when the HUD is moving.
# It is only used for nasal parallax correction
var update_hud_position = func (node) {
    # Matches translate animation for 'aj37hud' in Models/AJS37-Viggen.xml
    var pos = node.getValue();
    opts.hud_center_y = 0.71 - 0.05*pos;
    opts.hud_center_z = -4.11 + 0.04*pos;
    if (globals.hud["hud_canvas"] != nil) hud_canvas.update_parallax(force:TRUE);
}

setlistener("ja37/hud/position", update_hud_position, 1, 0);


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
        me.gs_pos = 286;
        me.glideslope = me.landing.createChild("group", "glideslope")
            .setTranslation(0, me.gs_pos);

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
            .moveTo(-1000,-500).horiz(630).moveTo(1000,-500).horiz(-630);
        make_label(me.landing, -500, -520, "+5");
        make_label(me.landing, 500, -520, "+5");

        make_path(me.glideslope)
            .moveTo(-470, 0).horizTo(-100).moveTo(470, 0).horizTo(100);
        make_dot(me.glideslope, 0, 0, opts.line_width*2);
    },

    set_mode: func(mode) {
        me.mode = mode;
        if (mode == HUD.MODE_AIM) {
            # In aiming mode, the horizon doesn't actually display anything,
            # it just provides a parent group.
            me.navigation.hide();
            me.landing.hide();
            # Reset as aiming mode only uses roll_group.
            me.horizon_group.setTranslation(0,0);
            me.ref_point_group.setTranslation(0,0);
        } elsif (mode == HUD.MODE_FINAL_NAV or mode == HUD.MODE_FINAL_OPT) {
            me.navigation.hide();
            me.landing.show();
            me.roll_group.setTranslation(0,0);  # Reset after aiming mode.
        } else {
            me.navigation.show();
            me.landing.hide();
            me.roll_group.setTranslation(0,0);  # Reset after aiming mode.
        }
    },

    # Converts a bearing to a reference point offset (used to set position of ref_point_group).
    # fpv_rel_bearing: clamp the resulting offset within 3.6 of this value.
    bearing_to_offset: func(bearing, fpv_rel_bearing) {
        var offset = bearing - input.heading.getValue();
        offset = geo.normdeg180(offset);
        if (fpv_rel_bearing != nil) offset = math.clamp(offset, fpv_rel_bearing - 3.6, fpv_rel_bearing + 3.6);
        return offset;
    },

    update: func(fpv_rel_bearing) {
        me.roll_group.setRotation(-input.roll.getValue() * D2R);
        me.horizon_group.setTranslation(0, input.pitch.getValue() * 100);

        # Position of reference point (indicates target heading)
        if (me.mode == HUD.MODE_TAKEOFF_ROLL or me.mode == HUD.MODE_TAKEOFF_ROTATE) {
            # locked on forward axis at takeoff
            me.ref_point_offset = 0;
        } elsif (me.mode == HUD.MODE_FINAL_NAV or me.mode == HUD.MODE_FINAL_OPT) {
            if (me.mode == HUD.MODE_FINAL_NAV and input.nav_lock.getBoolValue() and navigation.has_rwy and navigation.ils) {
                # TILS command
                var heading = input.nav_rdl.getValue() + input.nav_defl.getValue()*2;
                me.ref_point_offset = me.bearing_to_offset(heading, fpv_rel_bearing);
            } elsif (!input.hud_slav.getBoolValue() and navigation.has_rwy) {
                me.ref_point_offset = me.bearing_to_offset(navigation.rwy_heading, fpv_rel_bearing);
            } else {
                # No runway in route manager, or switch SLAV to on: locked on FPV.
                me.ref_point_offset = fpv_rel_bearing;
            }

            # Landing flare mode.
            me.gs_pos = 286;
            if (me.mode == HUD.MODE_FINAL_OPT) {
                # If sufficiently low, switch to landing flare mode. Threshold is lower if RHM is used.
                if (input.rad_alt_ready.getBoolValue()) {
                    var flare = input.rad_alt.getValue() < 15;
                } else {
                    var flare = input.alt.getValue() < 30;
                }
                # During flare, glideslope moves up to indicate maximal acceptable vertical speed (2.96m/s)
                if (flare) {
                    var groundspeed = input.groundspeed.getValue() * KT2MPS;
                    me.gs_pos = math.min(math.atan2(2.96, groundspeed) * R2D * 100, 286);
                }
            }
            me.glideslope.setTranslation(0, me.gs_pos);
        } elsif (!input.rm_active.getBoolValue()) {
            # locked on FPV if no target is defined
            me.ref_point_offset = fpv_rel_bearing;
        } else {
            # towards target heading, clamped around FPV
            me.ref_point_offset = me.bearing_to_offset(input.wp_bearing.getValue(), fpv_rel_bearing);
        }

        me.ref_point_group.setTranslation(me.ref_point_offset * 100, 0);
    },

    # Special update function for aiming mode.
    #
    # Takes reticle position as input.
    update_aim: func(pos) {
        me.roll_group.setTranslation(pos[0], pos[1]);
        me.roll_group.setRotation(-input.roll.getValue() * D2R);
        me.ref_point_offset = 0;
    },

    get_horizon_group: func { return me.horizon_group; },
    get_ref_point_group: func { return me.ref_point_group; },
    get_glideslope_pos: func { return [me.ref_point_offset*100, me.gs_pos]; },
};

# Altitude bars, indicate altitude relative to commanded altitude.
var AltitudeBars = {
    alt_bars_length: 300,

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
        me.bars_pos = -1;
        # Group centered on the top of the outer altitude bars.
        me.outer_bars_group = me.group.createChild("group");

        me.ref_bars = make_path(me.outer_bars_group)
            .setTranslation(0, me.alt_bars_length); # bottom of outer bars
        me.rhm_index = make_path(me.outer_bars_group)
            .moveTo(-305, 0).horiz(-50).moveTo(305,0).horiz(50);
        me.rhm_shown = FALSE;
    },

    # Set the bars normalised position.
    # pos=-1: bottom of the bars on the horizon (indicates alt=0)
    # pos=0: top of the bars on the horizon (indicates alt=commanded alt)
    set_bars_pos: func(pos) {
        me.bars_pos = pos;
        for (var i=1; i<=3; i+=1) {
            me.bars[i-1].setTranslation(0, 100 * i * pos);
        }
        me.outer_bars_group.setTranslation(0, me.alt_bars_length * pos);
    },

    # height=1 = length of outer altitude bars
    set_ref_bars_height: func(height) {
        me.ref_bars
            .reset()
            .moveTo(-330, 0).vert(-me.alt_bars_length * height)
            .moveTo(330,0).vert(-me.alt_bars_length * height);
    },

    set_mode: func(mode) {
        me.mode = mode;
        if (me.mode == HUD.MODE_AIM or me.mode == HUD.MODE_NAV_DECLUTTER or me.mode == HUD.MODE_FINAL_OPT) {
            me.group.hide();
        } elsif (me.mode == HUD.MODE_FINAL_NAV) {
            me.group.setTranslation(0, 287);
            me.group.show();
            # Should be displayed, but it would require altitude bars to display
            # an actual commanded altitude, not just ILS glideslope deviation.
            me.ref_bars.hide();
            me.rhm_index.hide();
            me.rhm_shown = FALSE;
        } else {
            me.group.setTranslation(0, 0);
            me.group.show();
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
            # MKV blinking
            me.ref_bars.setVisible(!input.ajs_bars_flash.getBoolValue() or input.fiveHz.getBoolValue());
            me.set_ref_bars_height(100/ref_alt);
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
        me.rhm_index.setTranslation(0, me.alt_bars_length * rhm_pos);
        # MKV blinking
        me.rhm_index.setVisible(!input.ajs_bars_flash.getBoolValue() or input.fiveHz.getBoolValue());
    },

    # All altitudes in meters
    update: func {
        if (me.mode == HUD.MODE_NAV_DECLUTTER or me.mode == HUD.MODE_FINAL_OPT) return;

        if (me.mode == HUD.MODE_FINAL_NAV) {
            if (navigation.has_rwy and navigation.ils and input.nav_has_gs.getBoolValue() and input.nav_gs_lock.getBoolValue()) {
                me.set_bars_pos(math.clamp(-input.nav_gs_defl.getValue(), -0.5, 1));
                me.group.show();
            } else {
                me.group.hide();
            }
            return;
        }

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
        me.set_bars_pos(bars_pos);

        me.update_ref_bars(ref_alt);
        me.update_rhm_index(scale, bars_pos);
    },

    # Get the vertical position of the bottom of the (largest) altitude bars,
    # relative to the horizon line, in the HUD coordonate units.
    # Used to position the heading and time line just below the altitude bars.
    get_base_pos: func {
        return me.alt_bars_length * (me.bars_pos + 1);
    },
};

# Digital altitude indicator
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
            me.y = 268;
        } else {
            me.x = -430;
            me.y = 0;
        }
    },

    update_text: func {
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
    },

    update: func(gs_pos) {
        me.update_text();

        # update position
        if (me.mode == HUD.MODE_AIM) {
            # Moves to the right when firing.
            me.side = fire_control.is_firing() ? -1 : 1;
        } else {
            if (gs_pos[0] < -200) me.side = -1; # switch to right side
            elsif (gs_pos[0] > 0) me.side = 1;
        }
        if (me.mode == HUD.MODE_FINAL_OPT) {
            me.y = gs_pos[1];
        }
        me.text.setTranslation(me.x * me.side, me.y - 20);
    },
};

# Time/Distance line (time/distance/... to waypoint or event)
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
        } elsif (mode == HUD.MODE_AIM) {
            me.set_mid_mark(TRUE);
            me.group.setTranslation(0, 150);
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
            me.set_line(input.speed.getValue() * 0.667 / input.rotation_speed.getValue());
        } elsif (me.mode == HUD.MODE_NAV) {
            var eta = input.eta.getValue();
            var popup = (route.get_current_idx() & route.WPT.type_mask) == route.WPT.U;

            if (eta == nil or eta <= 0 or eta > 60 or (popup and eta > 40)) {
                me.group.hide();
            } else {
                if (popup) {
                    # marker at 1/3, eta decrease from 40s to these markers
                    eta += 20;
                    me.set_side_marks(0.333);
                } else {
                    me.set_side_marks(0);
                }
                me.set_line(eta / 60);
                me.group.setTranslation(0, alt_bars_pos);
                me.group.show();
            }
        }
    },

    update_aim: func(params) {
        if (!params.enabled) {
            me.group.hide();
            return;
        }

        me.set_line(params.line / params.max);
        me.set_side_marks(params.mark / params.max);
        me.group.setVisible(!params.blinking or input.fiveHz.getBoolValue());
    },
};

# Heading indicator
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
        if (me.mode == HUD.MODE_AIM) {
            me.group.hide();
        } elsif (me.mode == HUD.MODE_NAV_DECLUTTER) {
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

# Flight path vector marker
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
        if (me.mode == HUD.MODE_AIM) {
            me.group.hide();
        } elsif (me.mode == HUD.MODE_TAKEOFF_ROLL or me.mode == HUD.MODE_TAKEOFF_ROTATE) {
            me.group.show();
            me.group.setTranslation(0, 1000);
            me.set_fin(FALSE);
        } else {
            me.group.show();
            me.set_fin(TRUE);
        }
    },

    # Display 'fin' (speed error indicator)
    # pos: normalised in [-1,1], 0: correct speed, -1: speed is too low
    set_fin: func(show, pos=0, blink=0) {
        if (show and (!blink or input.fiveHz.getBoolValue())) {
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

        if (modes.landing) {
            me.update_landing_speed_error();
        } else {
            me.set_fin(TRUE);
        }
    },
};


### Aiming mode HUD
# All aiming mode symbols except for the time/distance line, and the digital altitude.
var AimingMode = {
    new: func(parent, hud_group) {
        var m = { parents: [AimingMode], parent: parent, hud_grp: hud_group, mode: -1, };
        m.initialize();
        return m;
    },

    initialize: func {
        me.group = me.parent.createChild("group");
        # Aiming reticle
        me.reticle = make_dot(me.group, 0, 0, 2*opts.line_width);
        # Fixed bars, on except for A/A mode before radar lock.
        me.bars = make_path(me.group).moveTo(-300,-150).vert(300).moveTo(300,-150).vert(300);
        # Wingspan indicator, for A/A mode before radar lock.
        me.wing = me.group.createChild("group");
        me.wing_L = make_path(me.wing).moveTo(0,-15).vert(30).setTranslation(-120,0);
        me.wing_R = make_path(me.wing).moveTo(0,-15).vert(30).setTranslation(120,0);
        # Small vertical bar, indicates that radar ranging is active.
        me.range_mark = make_path(me.group).moveTo(0,-150).vert(-50);
        # Small horiontal bars around reticle, indicate firing window.
        me.firing_mark = make_path(me.group).moveTo(-25,0).horiz(-75).moveTo(25,0).horiz(75);
        # Vertical bars, flash to indicate distance below safe minimum.
        me.break_bars = make_path(me.group).moveTo(-200,-100).vert(200).moveTo(200,-100).vert(200);

        me.reticle_pos = [0,0];
        me.dist_line = {
            enabled: 0,
            max: 8000,
            line: 0,
            mark: 0,
            blinking: 0,
        };

        # Secondary reticle (target position, and some other functions).
        # In a separate group, so that its position is given in HUD coordinates.
        me.target = make_circle(me.hud_grp, 0, 0, 50);
        me.target_pos = geo.Coord.new();

        # Made up, Rb75 seeker position
        me.seeker = make_circle(me.hud_grp, 0, 0, 25);
    },

    set_mode: func(mode) {
        if (mode == HUD.MODE_AIM) {
            me.group.show();
        } else {
            me.group.hide();
            me.target.hide();
            me.seeker.hide();
            me.set_AG_flag(FALSE);
        }
    },

    # External A/G aiming flag, used for ground collision warning
    set_AG_flag: func(b) {
        input.gnd_aiming.setBoolValue(b);
    },

    ## AA sight

    # Wingspan indicator (before radar lock)
    set_wingspan: func(span, dist) {
        var pos = span/2/dist*R2D*100;
        me.wing_L.setTranslation(-pos,0);
        me.wing_R.setTranslation(pos,0);
    },

    # return [planned firing distance, min firing distance, max g-load]
    fire_dist_AA: func(type, has_radar_dist) {
        # AJS37 SFI part 3 sec 3.1.1
        if (type == "M55") return [500,0,nil];
        # AJS37 SFI part 3 sec 6.7
        if (type == "RB-05A") return [2800,0,nil];

        var rb24 = (var wpn = fire_control.get_weapon()) != nil and wpn.type == "RB-24";
        var min_dist = rb24 ? 900 : 500;
        var max_g = rb24 ? 2 : 6;

        if (has_radar_dist) {
            var alt = math.max(input.pres_alt.getValue(), 2000);
            var fire_dist = rb24 ? 1000 + 0.25 * alt : 1200 + 0.65 * alt;
        } else {
            var fire_dist = rb24 ? 1000 : 1500;
        }
        return [fire_dist, min_dist, max_g];
    },

    update_AA: func(type) {
        var radar_dist = radar.get_AA_range();

        # Shooting distance, depending on weapon type.
        var fire_dist = me.fire_dist_AA(type, radar_dist != nil);
        var shoot_dist = fire_dist[0];
        var min_dist = fire_dist[1];

        # G-load warning for IR missiles.
        var g_warning = fire_dist[2] != nil and input.g_load.getValue() > fire_dist[2];

        # Reticle position
        if (type == "M55") {
            # A/G sight computer is used for this, and this is essentially what the real AJS does too
            # (no lead, target velocity is not measured, radar ranging is to indicate firing distance).
            sight.AGsight.update(m55_AA_mode:TRUE);
            var pos = sight.AGsight.get_pos();
            me.reticle_pos[0] = pos[0] * MIL2HUD;
            me.reticle_pos[1] = pos[1] * MIL2HUD;
        } else {
            me.reticle_pos[0] = 0;
            # Missile boresight position is 0.8deg down, except for outer pylons.
            var pylon = fire_control.get_selected_pylons();
            if (size(pylon) > 0 and (pylon[0] == pylons.STATIONS.R7V or pylon[0] == pylons.STATIONS.R7H)) {
                me.reticle_pos[1] = 0;
            } else {
                me.reticle_pos[1] = 80;
            }
        }

        me.bars.setVisible(radar_dist != nil);
        me.range_mark.hide();
        me.break_bars.hide();
        me.target.hide();
        me.seeker.hide();
        me.reticle.setVisible(radar_dist != nil or type == "M55");
        me.firing_mark.setVisible(g_warning and input.fiveHz.getBoolValue());
        me.wing.setVisible(radar_dist == nil);

        if (radar_dist == nil) {
            me.set_wingspan(input.wingspan.getValue(), shoot_dist);
            me.dist_line.enabled = FALSE;
        } elsif (radar_dist > 8000) {
            me.dist_line.enabled = FALSE;
        } else {
            var resize_dist = (type == "M55") ? 2000 : 4000;

            me.dist_line.enabled = TRUE;
            me.dist_line.max = radar_dist < resize_dist ? resize_dist : 8000;
            me.dist_line.line = radar_dist;
            me.dist_line.mark = shoot_dist;
            me.dist_line.blinking = (radar_dist < min_dist);
        }
    },

    ## Cannon / rocket sight

    update_AG: func(type) {
        me.set_AG_flag(TRUE);

        var arak_long = (type == "M70" and input.arak_long.getBoolValue());

        sight.AGsight.update();
        var pos = sight.AGsight.get_pos();
        # Vector [target dist, evade dist, firing dist, radar range used]
        var dist = sight.AGsight.get_dist();
        var speed = input.groundspeed.getValue() * KT2MPS;

        me.reticle.show();
        me.bars.show();
        me.wing.hide();
        me.update_target_ring();
        me.seeker.hide();

        me.reticle_pos[0] = pos[0] * MIL2HUD;
        me.reticle_pos[1] = pos[1] * MIL2HUD;

        if (dist == nil) {
            me.dist_line.enabled = FALSE;
            me.range_mark.hide();
            me.firing_mark.hide();
            me.break_bars.hide();
            return;
        }

        var target_dist = dist[0];
        var break_dist = dist[1];
        var fire_dist = dist[2];
        var has_radar_range = dist[3];

        me.range_mark.setVisible(has_radar_range);

        if (arak_long) {
            var time = sight.AGsight.get_time();
            var pitch = sight.AGsight.get_pitch();
            me.firing_mark.setVisible(
                # Distance <=7km, more than minimum firing distance
                target_dist <= 7000 and target_dist >= fire_dist
                # Pitch at least 3deg, at most 6deg
                and pitch <= -3 and pitch >= -6
                # Time <= 18s and >= 0.5s
                and time <= 18 and time >= 0.5
                # Blinking 2s before last firing point
                and (target_dist > fire_dist + speed*2 or input.fiveHz.getBoolValue()));
        } else {
            # Firing mark 0.5s before firing.
            me.firing_mark.setVisible(target_dist <= fire_dist + speed*0.5);
        }
        # Pull up bars flashing after break distance.
        me.break_bars.setVisible(target_dist < break_dist and input.fiveHz.getBoolValue());

        # distance line
        if (target_dist > 8000) {
            me.dist_line.enabled = FALSE;
        } else {
            me.dist_line.enabled = TRUE;
            me.dist_line.max = 8000;
            me.dist_line.line = target_dist;
            me.dist_line.mark = fire_dist;
            me.dist_line.blinking = (target_dist >= fire_dist and target_dist <= fire_dist + speed*2);
        }
    },

    ## Bombs sight

    update_bomb: func(type) {
        me.set_AG_flag(TRUE);

        me.reticle.show();
        me.bars.show();
        me.wing.hide();
        me.range_mark.hide();
        me.firing_mark.hide();
        me.break_bars.hide();
        me.update_target_ring();
        me.seeker.hide();

        if ((var bomb = fire_control.get_weapon()) != nil and (var ccip = bomb.getCCIPadv(16, 0.2)) != nil) {
            var pos = vector.AircraftPosition.coordToLocalAziElev(ccip[0]);
            me.reticle_pos[0] = pos[0]*100;
            me.reticle_pos[1] = -pos[1]*100;

            me.dist_line.enabled = TRUE;
            me.dist_line.max = 16.0;            # seconds
            me.dist_line.line = ccip[2];        # fall time
            me.dist_line.mark = bomb.arming_time;
            me.dist_line.blinking = !ccip[1];   # has time to arm
        } else {
            me.reticle_pos[0] = 0;
            me.reticle_pos[1] = 300;
            me.dist_line.enabled = FALSE;
        }
    },

    update_RB75: func {
        me.set_AG_flag(FALSE);

        me.reticle.show();
        me.bars.show();
        me.wing.hide();
        me.range_mark.hide();
        me.firing_mark.hide();
        me.break_bars.hide();
        me.update_target_ring();
        # Default position of Rb 75 seeker
        me.reticle_pos[0] = 0;
        me.reticle_pos[1] = 130;

        # Display seeker position with small circle, to compensate for the lack of EP13.
        if ((var rb75 = fire_control.get_weapon()) != nil
            and (var pos = rb75.getSeekerInfo()) != nil
            # Don't display if lock was lost (uncaged + no lock).
            and (rb75.isCaged() or rb75.status == armament.MISSILE_LOCK)) {
            me.seeker.setTranslation(pos[0]*100, pos[1]*-100);
            me.seeker.show();
        } else {
            me.seeker.hide();
        }

        me.dist_line.enabled = FALSE;
    },

    # Target waypoint position ring, shown before unsafing.
    update_target_ring: func {
        if (fire_control.is_armed() or route.get_current_wpt() == nil or !route.is_tgt(route.get_current_idx())) {
            me.target.hide();
            return;
        }

        me.target_pos.set(route.get_current_wpt().coord);
        me.target_pos.set_alt(input.true_alt_ft.getValue() * FT2M - input.alt.getValue());
        var pos = vector.AircraftPosition.coordToLocalAziElev(me.target_pos);
        me.target.setTranslation(pos[0]*100, pos[1]*-100);
        me.target.show();
    },

    ## Main update function

    update: func {
        var type = fire_control.get_type();

        if (type == "IR-RB"
            or (type == "RB-05A" and input.wpn_knob.getValue() == fire_control.WPN_SEL.RR_LUFT)
            or (type == "M55" and input.wpn_knob.getValue() == fire_control.WPN_SEL.AKAN_JAKT)) {
            me.update_AA(type);
        } elsif (type == "M55" or type == "M70") {
            me.update_AG(type);
        } elsif (type == "M71" or type == "M71R") {
            me.update_bomb(type);
        } elsif (type == "RB-75") {
            me.update_RB75();
        }
    },

    get_reticle_pos: func {
        return me.reticle_pos;
    },

    # Parameters for distance line: { enabled, max, line, mark, blinking}
    get_dist_line: func {
        return me.dist_line;
    },
};



### Main HUD class
var HUD = {
    MODE_STBY: 0,
    MODE_TAKEOFF_ROLL: 1,
    MODE_TAKEOFF_ROTATE: 2,
    MODE_NAV: 3,
    MODE_NAV_DECLUTTER: 4,
    MODE_AIM: 5,
    MODE_FINAL_NAV: 6,
    MODE_FINAL_OPT: 7,

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
        me.heading = HeadingScale.new(me.groups.horizon); # rooted on horizon, not ref_point: not lateral offset
        me.distance = DistanceLine.new(me.groups.ref_point);
        me.fpv = FPV.new(me.root);
        me.aiming = AimingMode.new(me.groups.ref_point, me.root);

        # Disable at >15deg flight path angle. Re-enable at <12deg.
        me.high_angle_off = FALSE;
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
            me.aiming.set_mode(mode);
        }
    },

    # Conditions to enable some kind of aiming mode, before considering selected weapon type.
    # This is intended for external use as hud.HUD.aiming_mode_condition().
    aiming_mode_condition: func {
        if (input.gear_pos.getValue() > 0) return FALSE;
        if (fire_control.selected == nil) return FALSE;
        if (modes.selector_ajs < modes.NAV or modes.selector_ajs > modes.RECO) return FALSE;
        if (modes.selector_ajs != modes.COMBAT and !fire_control.is_armed()) return FALSE;
        return TRUE;
    },

    # HUD internal test for aiming mode, weapon dependent.
    # This is the HUD internal notion of aiming mode, which excludes
    # "aiming modes that look like nav"
    aiming_mode_test: func {
        if (!me.aiming_mode_condition()) return FALSE;

        var type = fire_control.get_type();
        # Firing presentation is the same as navigation mode for these weapons.
        # (Rb 05: navigation mode except in A/A mode)
        if (type == "RB-04E" or type == "RB-15F" or type == "M90"
            or (type == "RB-05A" and input.wpn_knob.getValue() != fire_control.WPN_SEL.RR_LUFT))
            return FALSE;

        return TRUE;
    },

    update_mode: func {
        var fpv_pitch = input.fpv_pitch.getValue();
        if (fpv_pitch < 12 and fpv_pitch > -12) me.high_angle_off = FALSE;
        elsif (fpv_pitch > 15 or fpv_pitch < -15) me.high_angle_off = TRUE;

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
        } elsif (me.aiming_mode_test()) {
            me.set_mode(HUD.MODE_AIM);
        } elsif (me.high_angle_off) {
            me.set_mode(HUD.MODE_STBY);
        } elsif (modes.landing and (land.mode < 1 or land.mode == 4)) {
            me.set_mode(HUD.MODE_FINAL_OPT);
        } elsif (modes.landing and land.mode == 3) {
            me.set_mode(HUD.MODE_FINAL_NAV);
        } elsif (modes.landing and (land.mode == 1 or land.mode == 2)) {
            # Initial landing phase, NAV display mode
            me.set_mode(HUD.MODE_NAV);
        } elsif (input.hud_slav.getBoolValue() and input.alt.getValue() < 97.5) {
            me.set_mode(HUD.MODE_NAV_DECLUTTER);
        } else {
            me.set_mode(HUD.MODE_NAV);
        }
    },

    update: func {
        me.update_mode();
        if (me.mode == HUD.MODE_STBY) return;

        if (me.mode == HUD.MODE_AIM) {
            # First update this, as it computes reticle position.
            me.aiming.update();
            me.horizon.update_aim(me.aiming.get_reticle_pos());
            me.dig_alt.update([0,0]);
            me.distance.update_aim(me.aiming.get_dist_line());
            return;
        }

        me.fpv.update();
        var fpv_rel_bearing = input.fpv_track.getValue() - input.head_true.getValue();
        fpv_rel_bearing = math.periodic(-180, 180, fpv_rel_bearing);
        me.horizon.update(fpv_rel_bearing);
        me.dig_alt.update(me.horizon.get_glideslope_pos());
        me.alt_bars.update();
        var alt_bars_pos = me.alt_bars.get_base_pos();
        me.distance.update(alt_bars_pos);
        me.heading.update(alt_bars_pos);
    },

    declutter_heading_toggle: func {
        me.heading.declutter_toggle();
    },
};

# For radar A/A range mode
var get_reticle_pos = func {
    return hud.aiming.get_reticle_pos();
}
