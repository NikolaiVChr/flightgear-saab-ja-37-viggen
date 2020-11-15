# General, constant options
var opts = {
    res: 1024,              # Actual resolution of the canvas.
    ang_width: 28,          # Angular width of the HUD picture.
    canvas_ang_width: 29,   # Angular width to which the canvas is mapped.
                            # Adds a small margin due to border clipping issues.
    optical_axis_pitch_offset: 7.3,
    line_width: 10,
    # HUD physical dimensions
    hud_center_y: 0.7,
    hud_center_z: -4.06203,
    hud_width: 0.15,
};


var metric = nil;


### HUD elements classes

# General conventions/methods for HUD elements classes:
# - new(parent): creates the element, 'parent' must be a Canvas
#                group used as root for the element.
# - set_mode(mode): used to indicate that the HUD display mode changed
# - update(): updates the element


# Flight path vector, or aiming reticle in aiming mode.
# Most of the HUD is centered on it.
var FPV = {
    new: func(parent) {
        var m = { parents: [FPV], parent: parent, mode: -1, };
        m.initialize();
        return m;
    },

    initialize: func {
        me.group = me.parent.createChild("group", "flight path vector");

        me.nav = me.group.createChild("group");
        make_circle(me.nav, 0, 0, 50);                                          # circle
        make_path(me.nav).moveTo(-25,0).horiz(-75).moveTo(25,0).horiz(75);    # wings
        me.tail = make_path(me.nav).moveTo(0,-25).vert(-50);

        me.takeoff = me.group.createChild("group");
        make_circle(me.takeoff, 0, 0, 50);
        make_path(me.takeoff)
            .moveTo(-25,0).horiz(-75).moveTo(-125,0).horiz(-50)
            .moveTo(25,0).horiz(75).moveTo(125,0).horiz(50);

        me.aim = me.group.createChild("group");
        make_path(me.aim)
            .moveTo(-100,0).lineTo(-25,0).lineTo(0,25).lineTo(25,0).lineTo(100,0);

        me.pos_x = me.pos_y = 0;
    },

    set_mode: func(mode) {
        me.mode = mode;
        if (me.mode == HUD.MODE_TAKEOFF_ROLL or me.mode == HUD.MODE_TAKEOFF_ROTATE) {
            me.nav.hide();
            me.takeoff.show();
            me.aim.hide();
        } elsif (me.mode == HUD.MODE_AIM) {
            me.nav.hide();
            me.takeoff.hide();
            me.aim.show();
        } else {
            me.nav.show();
            me.takeoff.hide();
            me.aim.hide();
        }
    },

    update: func {
        if (input.wow.getBoolValue()) {
            me.pos_x = 0;
        } else {
            me.pos_x = 100 * input.fpv_right.getValue();
            me.pos_x = math.clamp(me.pos_x, -800, 800);
        }

        if (me.mode == HUD.MODE_TAKEOFF_ROLL or me.mode == HUD.MODE_TAKEOFF_ROTATE) {
            me.pos_y = 1000;
        } else {
            me.pos_y = -100 * input.fpv_up.getValue();
            me.pos_y = math.clamp(me.pos_y, -800, 1600);
        }
        me.group.setTranslation(me.pos_x, me.pos_y);
    },

    get_pos: func {
        return [me.pos_x, me.pos_y];
    },

    get_group: func {
        return me.group;
    },
};


# Artificial horizon. Fixed on FPV.
var Horizon = {
    new: func(parent) {
        var m = { parents: [Horizon], parent: parent, mode: -1, };
        m.initialize();
        return m;
    },

    initialize: func {
        me.roll_group = me.parent.createChild("group", "roll");
        me.horizon = me.roll_group.createChild("group", "horizon");

        # Navigation mode pitch scale
        me.nav = me.horizon.createChild("group");
        me.nav_bars = {};
        for (var i=5; i<=90; i+=5) {
            me.nav_bars[i] = me.make_upper_bar(me.nav, i);
        }
        me.nav_bars[0] = me.make_center_bar(me.nav);
        for (var i=-5; i>=-90; i-=5) {
            me.nav_bars[i] = me.make_lower_bar(me.nav, i);
        }

        # Landing mode pitch scale
        me.landing = me.horizon.createChild("group");
        me.make_upper_bar(me.landing, 5);
        make_path(me.landing).moveTo(-1000,0).lineTo(1000,0);
        me.glideslope = me.make_glideslope(me.landing)
            .setTranslation(0, 286);

        # Aiming mode pitch scale
        me.aim = me.horizon.createChild("group");
        me.aim_bars = {};
        for (var i=0; i<=90; i+=5) {
            me.aim_bars[i] = me.make_aim_upper_bar(me.aim, i);
        }
        for (var i=-5; i>=-90; i-=5) {
            me.aim_bars[i] = me.make_aim_lower_bar(me.aim, i);
        }

        # Only 3 bars are shown at any time.
        # This remembers which bars are currently displayed.
        me.displayed_bars = {};
        for (var i=-90; i<=90; i+=5) {
            me.nav_bars[i].hide();
            me.aim_bars[i].hide();
        }
    },

    # Horizon scale bars. 3 types for navigation mode, 2 types for aiming mode.
    make_upper_bar: func(group, angle) {
        var bar = group.createChild("group")
            .setTranslation(0, angle*-100);
        make_path(bar)
            .moveTo(-1000,0).horizTo(-200).moveTo(1000,0).horizTo(200);
        make_label(bar, -400, -20, sprintf("%+d", angle)).setAlignment("left-bottom");
        return bar;
    },

    make_center_bar: func(group) {
        var bar = group.createChild("group");
        make_path(bar)
            .moveTo(-1000,0).horizTo(-300)
            .moveTo(1000,0).horizTo(580).moveTo(380,0).horizTo(300);
        for (var i=-250; i<=250; i+=100) {
            make_dot(bar, i, 0, opts.line_width*2);
        }
        make_label(bar, -400, -20, "0").setAlignment("left-bottom");
        return bar;
    },

    make_lower_bar: func(group, angle) {
        var bar = group.createChild("group")
            .setTranslation(0, angle*-100);

        # Dashes
        var path = make_path(bar).moveTo(-200,0);
        for (var i=0; i<6; i+=1) {
            path.horiz(-80).move(-64,0);
        }
        # Right side: skip over one dash to make space for the altitude scale.
        path.moveTo(200,0).horiz(80).move(208,0);
        for (var i=0; i<4; i+=1) {
            path.horiz(80).move(64,0);
        }

        make_label(bar, -400, -20, sprintf("%+d", angle)).setAlignment("left-bottom");

        return bar;
    },

    make_aim_upper_bar: func(group, angle) {
        var bar = group.createChild("group")
            .setTranslation(0, angle*-100);
        make_path(bar)
            .moveTo(-1000,0).horizTo(-440).vert(30)
            .moveTo(1000,0).horizTo(440).vert(30);
        make_label(bar, -540, -20, sprintf("%+d", angle)).setAlignment("left-bottom");
        return bar;
    },

    make_aim_lower_bar: func(group, angle) {
        var bar = group.createChild("group")
            .setTranslation(0, angle*-100);

        # Dashes
        var path = make_path(bar).moveTo(-440,0);
        for (var i=0; i<4; i+=1) {
            path.horiz(-86).move(-72,0);
        }
        path.moveTo(440,0);
        for (var i=0; i<4; i+=1) {
            path.horiz(86).move(72,0);
        }
        path.moveTo(-440,0).vert(30);
        path.moveTo(440,0).vert(30);

        make_label(bar, -540, -20, sprintf("%+d", angle)).setAlignment("left-bottom");
        return bar;
    },

    # Glideslope indicator at landing.
    make_glideslope: func(group) {
        var bar = group.createChild("group");
        make_path(bar)
            .moveTo(-600,0).horizTo(-100)
            .moveTo(700,0).horizTo(650).moveTo(380,0).horizTo(100);
        make_dot(bar, 0, 0, 2*opts.line_width);
        return bar;
    },

    set_mode: func(mode) {
        me.mode = mode;
        if (me.mode == HUD.MODE_FINAL_NAV or me.mode == HUD.MODE_FINAL_OPT) {
            me.nav.hide();
            me.landing.show();
            me.aim.hide();
        } elsif (me.mode == HUD.MODE_AIM) {
            me.nav.hide();
            me.landing.hide();
            me.aim.show();
        } else {
            me.nav.show();
            me.landing.hide();
            me.aim.hide();
        }
    },

    show_bars: func(bars) {
        foreach(var bar; keys(me.displayed_bars)) {
            if (!contains(bars, bar)) {
                me.nav_bars[bar].hide();
                me.aim_bars[bar].hide();
                delete(me.displayed_bars, bar);
            }
        }
        foreach(var bar; keys(bars)) {
            if (!contains(me.displayed_bars, bar)) {
                me.nav_bars[bar].show();
                me.aim_bars[bar].show();
                me.displayed_bars[bar] = 1;
            }
        }
    },

    update: func(fpv_roll, fpv_pitch) {
        # Position of pitch scale.
        me.roll_group.setRotation(-fpv_roll * D2R);
        me.horizon.setTranslation(0, fpv_pitch * 100);

        # Only show 3 pitch bars, closest to FPV.
        var center_bar = math.round(fpv_pitch, 5);
        center_bar = math.clamp(center_bar, -85, 85);
        var bars = {};
        bars[center_bar] = 1;
        bars[center_bar+5] = 1;
        bars[center_bar-5] = 1;
        me.show_bars(bars);
    },

    get_roll_group: func { return me.roll_group; },
    get_horizon_group: func { return me.horizon; },
    get_gs_pos: func { return 286; },
};


# Heading scale
var Heading = {
    Marker: {
        new: func(parent) {
            var m = { parents: [Heading.Marker], parent: parent, };
            m.initialize();
            return m;
        },

        initialize: func {
            me.group = me.parent.createChild("group");
            me.mark = make_path(me.group).vert(-50);
            me.text = make_text(me.group)
                .setAlignment("center-bottom")
                .setTranslation(0, -60);
            me.text.enableUpdate();
            me.long = TRUE;
        },

        set_pos: func(pos) { me.group.setTranslation(pos, 0); },

        update: func(hdg, long) {
            # Marker length
            if (long and !me.long) {
                me.long = TRUE;
                me.mark.setScale(1, 1);
                me.text.show();
            } elsif (!long and me.long) {
                me.long = FALSE;
                me.mark.setScale(1, 0.6);
                me.text.hide();
            }
            if (me.long) {
                me.text.updateText(sprintf("%.2d", hdg/10));
            }
        },
    },

    new: func(parent) {
        var m = { parents: [Heading], parent: parent, mode: -1, };
        m.initialize();
        return m;
    },

    initialize: func {
        me.group = me.parent.createChild("group")
            .setTranslation(0, -300);

        # Fixed track index
        make_path(me.group).moveTo(0,0).lineTo(-25,50).moveTo(0,0).lineTo(25,50);

        # Commanded track index
        me.index = make_path(me.group)
            .moveTo(0,50).vert(75)
            .moveTo(-25,75).vert(50)
            .moveTo(25,75).vert(50);

        me.marker_grp = me.group.createChild("group");

        me.markers = [];
        setsize(me.markers, 5);
        forindex (var i; me.markers) {
            me.markers[i] = Heading.Marker.new(me.marker_grp);
        }

        me.scale_factor = -1;
        me.set_scale_factor(100/6.7);
    },

    set_scale_factor: func(factor) {
        if (factor == me.scale_factor) return;
        me.scale_factor = factor;

        forindex (var i; me.markers) {
            me.markers[i].set_pos(me.scale_factor * (i-2) * 5);
        }
    },

    set_mode: func(mode) {
        me.mode = mode;
        if (me.mode == HUD.MODE_FINAL_HIGH_PITCH or me.mode == HUD.MODE_AIM) {
            me.group.hide();
        } elsif (me.mode == HUD.MODE_FINAL_NAV or me.mode == HUD.MODE_FINAL_OPT) {
            me.group.setTranslation(0, 0);
            me.set_scale_factor(100);
            me.group.show();
            me.index.hide();
        } else {
            me.group.setTranslation(0, -300);
            me.set_scale_factor(100/6.7);
            me.group.show();
        }
    },

    update: func(fpv_heading) {
        if (me.mode == HUD.MODE_FINAL_HIGH_PITCH or me.mode == HUD.MODE_AIM) return;

        # Track angle. The way it is computed depends on the mode.
        if (input.wow.getBoolValue()) {
            # On the ground, heading and track are the same,
            # and heading is well defined when stopped, so use heading.
            var track = input.heading.getValue();
        } elsif (me.mode == HUD.MODE_FINAL_NAV or me.mode == HUD.MODE_FINAL_OPT) {
            # 1:1 heading scale presentation. Use heading of FPV marker (and not actual track angle)
            # so that the heading scale matches the real world.
            var track = fpv_heading;
        } else {
            # Otherwise use track angle.
            var track = input.fpv_head_true.getValue() - input.head_true.getValue() + input.heading.getValue();
        }

        var center_mark = math.round(track, 5);

        me.marker_grp.setTranslation((center_mark - track) * me.scale_factor, 0);
        forindex (var i; me.markers) {
            var hdg = geo.normdeg(center_mark + (i-2) * 5);
            var long = math.mod(hdg, 10) == 0;
            me.markers[i].update(hdg, long);
        }

        if (me.mode != HUD.MODE_FINAL_NAV and me.mode != HUD.MODE_FINAL_OPT) {
            if (input.rm_active.getBoolValue()) {
                var pos = geo.normdeg180(input.wp_bearing.getValue() - track);
                pos *= me.scale_factor;
                pos = math.clamp(pos, -200, 200);
                me.index.setTranslation(pos, 0);
                me.index.show();
            } else {
                me.index.hide();
            }
        }
    },
};


# Digital airspeed indicator.
var Speed = {
    new: func(parent) {
        var m = { parents: [Speed], parent: parent, mode: -1, };
        m.initialize();
        return m;
    },

    initialize: func {
        me.group = me.parent.createChild("group", "speed");
        me.text = make_text(me.group);
        me.text.enableUpdate();
        me.text.setTranslation(0, 490);

        me.moved_up = FALSE;
    },

    set_mode: func(mode) {
        me.mode = mode;

        if (me.mode != HUD.MODE_FINAL_NAV and me.mode != HUD.MODE_FINAL_OPT) {
            me.group.setTranslation(0, 0);
            me.move_up(FALSE);
        }
    },

    move_up: func(up) {
        if (up == me.moved_up) return;

        me.moved_up = up;
        me.text.setTranslation(0, up ? 300 : 490);
    },

    update: func {
        if (me.mode == HUD.MODE_FINAL_NAV or me.mode == HUD.MODE_FINAL_OPT) {
            # At landing, move airspeed up when alpha is 8.5deg.
            var alpha = -input.fpv_up.getValue();
            if (alpha >= 8.5) me.move_up(TRUE);
            elsif (alpha <= 5.5) me.move_up(FALSE);
        }

        var mach = input.mach.getValue();
        if (mach >= 0.5) {
            mach = math.round(mach * 100);
            me.text.updateText(sprintf("%d,%.2d", math.floor(mach/100), math.mod(mach, 100)));
            me.text.show();
        } elsif (metric) {
            var speed = math.round(input.speed.getValue(), 5);
            if (speed >= 75) {
                me.text.updateText(sprintf("%d", speed));
                me.text.show();
            } else {
                me.text.hide();
            }
        } else {
            var speed = math.round(input.speed_kt.getValue());
            if (speed >= 40) {
                me.text.updateText(sprintf("%d", speed));
                me.text.show();
            } else {
                me.text.hide();
            }
        }
    },
};


# Altitude scale
var Altitude = {
    # Altitude scale markers subclass.
    Marker: {
        new: func(parent) {
            var m = { parents: [Altitude.Marker], parent: parent, };
            m.initialize();
            return m;
        },

        initialize: func {
            me.group = me.parent.createChild("group");
            me.mark = make_path(me.group).horiz(50);
            me.text = make_text(me.group)
                .setAlignment("left-center")
                .setTranslation(70, 0);
            me.text.enableUpdate();
            me.long = TRUE;
        },

        hide: func { me.group.hide(); },
        show: func { me.group.show(); },
        set_pos: func(pos) { me.group.setTranslation(0, pos); },

        update: func(alt, long, show_text) {
            # Marker length
            if (long and !me.long) {
                me.long = TRUE;
                me.mark.setScale(1, 1);
            } elsif (!long and me.long) {
                me.long = FALSE;
                me.mark.setScale(0.6, 1);
            }

            # Text
            if (!show_text) {
                me.text.hide();
            } else {
                if (alt < 1000) {
                    me.text.updateText(sprintf("%d", alt));
                } else {
                    alt /= 100;
                    me.text.updateText(sprintf("%d,%1d", math.floor(alt/10), math.mod(alt, 10)));
                }
                me.text.show();
            }
        },
    },


    new: func(parent) {
        var m = { parents: [Altitude], parent: parent, mode: -1, };
        m.initialize();
        return m;
    },

    initialize: func {
        me.group = me.parent.createChild("group", "altitude scale");

        # Fixed index
        make_path(me.group)
            .moveTo(0,0).lineTo(-40,40)
            .moveTo(0,0).lineTo(-40,-40);

        # At sufficient altitude, the linear part of the scale contains 9 markers.
        me.lin_markers = [];
        setsize(me.lin_markers, 11);
        forindex(var i; me.lin_markers) {
            me.lin_markers[i] = Altitude.Marker.new(me.group);
        }

        # 10m markers until 50m, at low altitude.
        me.low_grp = me.group.createChild("group");
        me.low_markers = [];
        setsize(me.low_markers, 4);
        forindex(var i; me.low_markers) {
            me.low_markers[i] = make_path(me.low_grp).horiz(30);
        }
        me.marker_75 = make_path(me.low_grp).horiz(30);

        me.marker_0 = me.group.createChild("group");
        make_path(me.marker_0).horiz(50);
        make_label(me.marker_0, 70, 0, "0").setAlignment("left-center");
        # Vertical bar indicating that scale is not fully linear.
        me.non_lin_mark = make_path(me.marker_0).moveTo(0,-40).vertTo(40);

        me.rhm_index = make_path(me.group)
            .horiz(-60)
            .moveTo(-30,0).lineTo(-60,50)
            .moveTo(0,0).lineTo(-30,50);

        # Markers above this are not displayed.
        me.upper_limit = -320;
    },

    set_mode: func(mode) {
        me.mode = mode;
        if (me.mode == HUD.MODE_AIM or me.mode == HUD.MODE_FINAL_HIGH_PITCH) {
            me.group.hide();
        } else {
            me.group.show();
        }
    },

    # Set aircraft altitude, used by function alt2pos() to compute position of other altitude markers.
    set_ac_alt: func(ac_alt) {
        me.ac_alt = ac_alt;

        # Parameters
        # - scale_{low,high}_limit: when ac_alt is between them, the scaling factor is proportional
        #   to ac_alt, so that ac_alt is displayed as 3deg.
        #   Outside of these limits, the scaling factor remains constant.
        # - lin_limit: within this distance of ac_alt, the altitude scale is linear.
        # - lin_limit_0: below this altitude, the altitude scale is linear (relative to 0 marker).

        if (metric) {
            # In m
            me.scale_low_limit = 50;
            me.scale_high_limit = 300;
            me.lin_limit = 225;
            me.lin_limit_0 = 40;
        } else {
            # In ft
            me.scale_low_limit = 200;
            me.scale_high_limit = 1000;
            me.lin_limit = 550;
            me.lin_limit_0 = 150;
        }
        # Scaling factor in meter per HUD unit. (for the part of the altitude scale close to the index)
        me.scale_factor = math.clamp(ac_alt, me.scale_low_limit, me.scale_high_limit) / 300;
    },

    # Map an altitude to a position of the scale, relative to the reading index.
    # Assumes that the position is in the linear part of the altitude scale.
    # (used for scale indices for efficiency)
    lin_alt2pos: func(alt) {
        return (me.ac_alt-alt) / me.scale_factor;
    },

    # Map an altitude to a position of the scale, relative to the reading index.
    # Aircraft altitude must be set through set_ac_alt() prior to using this function.
    alt2pos: func(alt) {
        # When aircraft is sufficiently low, the entire scale is linear.
        if (me.ac_alt <= me.scale_high_limit) return me.lin_alt2pos(alt);

        # Close to ac_alt, the scale is linear.
        if (alt >= me.ac_alt - me.lin_limit) return me.lin_alt2pos(alt);
        # Close to 0, the scale is linear.
        elsif (alt <= me.lin_limit_0) return 300 - alt/me.scale_factor;
        else {
            # Extrapolate between the two.
            return extrapolate(alt, me.lin_limit_0, me.ac_alt - me.lin_limit,
                               300 - me.lin_limit_0/me.scale_factor, me.lin_limit/me.scale_factor);
        }
    },

    update: func(fpv_pitch) {
        if (me.mode == HUD.MODE_AIM or me.mode == HUD.MODE_FINAL_HIGH_PITCH) return;

        # Update position: move up to 1deg towards the horizon,
        # so that it is fixed on the horizon when FPV pitch is between -1 and 1.
        # Does not apply during final, because it is fixed on glideslope.
        if (me.mode != HUD.MODE_FINAL_NAV and me.mode != HUD.MODE_FINAL_OPT) {
            me.group.setTranslation(380, math.clamp(fpv_pitch*100, -100, 100));
        } else {
            me.group.setTranslation(380, 0);
        }

        me.set_ac_alt(metric ? input.alt.getValue() : input.alt_ft.getValue());

        # Markers for the linear part of the scale.
        var spacing = metric ? 50 : 100;
        var center_mark = math.round(me.ac_alt, spacing);
        var mark_limit = metric ? 200 : 500;

        var i = 0;
        for (var alt = center_mark - mark_limit; alt <= center_mark + mark_limit; alt += spacing) {
            var pos = me.lin_alt2pos(alt);
            # Too high or too low
            if (alt <= 0 or pos < me.upper_limit) {
                me.lin_markers[i].hide();
            } else {
                if (metric) {
                    # Long mark for every 100m, plus 50m when below 100m.
                    var long_mark = math.mod(alt, 100) == 0 or (me.ac_alt <= 100 and alt == 50);
                    # Text for every 200m, plus 100m when below 225m, plus 50m when below 100m.
                    var show_text = math.mod(alt, 200) == 0
                        or (me.ac_alt <= 225 and alt == 100)
                        or (me.ac_alt <= 100 and alt == 50);
                } else {
                    # In imperial units, long mark every 500ft, plus 200ft below 500ft
                    # Same for text
                    var long_mark = math.mod(alt, 500) == 0
                        or (me.ac_alt <= 500 and alt == 200)
                        or (me.ac_alt <= 200 and alt == 100);
                    var show_text = long_mark;
                }

                me.lin_markers[i].set_pos(pos);
                me.lin_markers[i].update(alt, long_mark, show_text);
                me.lin_markers[i].show();
            }
            i += 1;
        }
        # Hide remaining markers.
        for (; i<size(me.lin_markers); i+=1) {
            me.lin_markers[i].hide();
        }

        # 10m markers at low altitude, plus one at 75m.
        # Imperial: 50ft markers.
        if (me.ac_alt <= (metric ? 100 : 200)) {
            var spacing = metric ? 10 : 20;
            var alt = spacing;
            forindex (var i; me.low_markers) {
                var pos = me.lin_alt2pos(alt);
                if (pos < me.upper_limit) {
                    me.low_markers[i].hide();
                } else {
                    me.low_markers[i].setTranslation(0, me.lin_alt2pos(alt));
                    me.low_markers[i].show();
                }
                alt += spacing;
            }

            var pos = me.lin_alt2pos(metric ? 75 : 150);
            if (pos < me.upper_limit) {
                me.marker_75.hide();
            } else {
                me.marker_75.setTranslation(0, pos);
                me.marker_75.show();
            }
            me.low_grp.show();
        } else {
            me.low_grp.hide();
        }

        # 0 marker
        if (me.ac_alt <= me.lin_limit) {
            # Displayed as a regular marker.
            var pos = me.lin_alt2pos(0);
            if (pos < me.upper_limit) {
                me.marker_0.hide();
            } else {
                me.marker_0.setTranslation(0, pos);
                me.marker_0.show();
                me.non_lin_mark.hide();
            }
        } elsif(input.rad_alt_ready.getBoolValue()) {
            # Displayed together with radar altimeter index.
            # Fixed 3deg below index.
            me.marker_0.setTranslation(0, 300);
            me.marker_0.show();
            me.non_lin_mark.show();
        } else {
            me.marker_0.hide();
        }

        if (input.rad_alt_ready.getBoolValue()) {
            var rad_alt = metric ? input.rad_alt.getValue() : input.rad_alt_ft.getValue();
            var pos = me.alt2pos(me.ac_alt - rad_alt);
            if (pos <= 500) {
                me.rhm_index.setTranslation(0, pos);
                me.rhm_index.show();
            } else {
                me.rhm_index.hide();
            }
        } else {
            me.rhm_index.hide();
        }
    },

    get_scale_factor: func {
        if (metric) return me.scale_factor;
        else return me.scale_factor * FT2M;
    },
};


# Digital altitude (aiming mode)
var DigitalAltitude = {
    new: func(parent) {
        var m = { parents: [DigitalAltitude], parent: parent, mode: -1, };
        m.initialize();
        return m;
    },

    initialize: func {
        me.shown = FALSE;
        me.text = make_text(me.parent)
            .setTranslation(400, 0)
            .setAlignment("left-bottom");
        me.text.enableUpdate();
        me.text.hide();
    },

    set_mode: func(mode) {
        me.mode = mode;
        if (mode == HUD.MODE_AIM) {
            me.text.show();
        } else {
            me.text.hide();
        }
    },

    update: func {
        if (me.mode != HUD.MODE_AIM) return;

        var alt = metric ? input.alt.getValue() : input.alt_ft.getValue();
        alt = math.round(alt, 10);
        if (alt < 1000) {
            me.text.updateText(sprintf("%3d", alt));
        } else {
            alt = math.round(alt, 100);
            alt /= 100;
            me.text.updateText(sprintf("%d,%1d", math.floor(alt/10), math.mod(alt, 10)));
        }
    },
};


# Digital radar altitude
var RadarAltitude = {
    new: func(parent) {
        var m = { parents: [RadarAltitude], parent: parent, mode: -1, };
        m.initialize();
        return m;
    },

    initialize: func {
        me.shown = FALSE;
        me.text = make_text(me.parent)
            .setTranslation(-400, 600);
        me.text.enableUpdate();
        me.text.hide();
    },

    set_mode: func(mode) {},

    update: func {
        if (modes.takeoff_30s_inhibit or modes.landing or !input.rad_alt_ready.getValue()) {
            me.shown = FALSE;
        } else {
            var alt = metric ? input.rad_alt.getValue() : input.rad_alt_ft.getValue();
            alt = math.round(alt);
            if (alt < (metric ? 100 : 300)) me.shown = TRUE;
            elsif (alt >= (metric ? 110 : 350)) me.shown = FALSE;
        }

        if (me.shown) {
            me.text.updateText(sprintf("R%3d", alt));
            me.text.show();
        } else {
            me.text.hide();
        }
    },
};


# Text message in lower left part. QFE, TILS, or weapon.
var TextMessage = {
    new: func(parent) {
        var m = { parents: [TextMessage], parent: parent, mode: -1, };
        m.initialize();
        return m;
    },

    initialize: func {
        me.text = make_text(me.parent)
            .setTranslation(-300, 300);
        me.text.enableUpdate();
    },

    set_mode: func(mode) {},

    update: func {
        if (input.qfe_active.getBoolValue()) {
            me.text.updateText("QFE");
            if (input.qfe_shown.getBoolValue()) {
                me.text.show();
            } else {
                me.text.hide();
            }
        } elsif (modes.landing and (land.mode == 2 or land.mode == 3)
                 and (input.tils_steady.getBoolValue() or input.tils_blink.getBoolValue())) {
            me.text.updateText("TILS");
            if (input.tils_blink.getBoolValue() and !input.fourHz.getBoolValue()) {
                me.text.hide();
            } else {
                me.text.show();
            }
        } elsif (!modes.takeoff_30s_inhibit and fire_control.selected != nil
                 and fire_control.selected.weapon_ready()) {
            me.text.updateText(displays.common.currArmNameMedium);
            me.text.show();
        } else {
            me.text.hide();
        }
    },
};


# Reference altitude / altitude hold / TILS glideslope bars.
var AltitudeBars = {
    new: func(parent) {
        var m = { parents: [AltitudeBars], parent: parent, mode: -1, };
        m.initialize();
        return m;
    },

    initialize: func {
        me.alt_bars = make_path(me.parent)
            .moveTo(-300,0).vert(300).moveTo(300,0).vert(300);

        me.tils_bars_3 = make_path(me.parent)
            .moveTo(-300,0).vert(300).moveTo(300,0).vert(300);
        me.tils_bars_2 = make_path(me.parent)
            .moveTo(-200,0).vert(200).moveTo(200,0).vert(200);

        me.alt_boxes = make_path(me.parent)
            .moveTo(-325,0).horiz(50).vert(150).horiz(-50).vert(-150)
            .moveTo(325,0).horiz(-50).vert(150).horiz(50).vert(-150);
    },

    set_mode: func(mode) {
        me.mode = mode;
    },

    update: func(scale_factor, show_horizon) {
        if (!show_horizon) {
            me.alt_bars.hide();
            me.alt_boxes.hide();
            me.tils_bars_2.hide();
            me.tils_bars_3.hide();
            return;
        } elsif (me.mode == HUD.MODE_FINAL_NAV) {
            # TILS final, only TILS guidance bars are displayed.
            me.alt_bars.hide();
            me.alt_boxes.hide();
            #me.tils_bars_2.show();
            #me.tils_bars_3.show();
        } elsif (me.mode == HUD.MODE_TAKEOFF_ROLL or me.mode == HUD.MODE_TAKEOFF_ROTATE) {
            # Takeoff mode, altitude bars fixed above the horizon, no boxes.
            me.alt_bars.setTranslation(0, -300);
            me.alt_bars.show();

            me.alt_boxes.hide();
            me.tils_bars_2.hide();
            me.tils_bars_3.hide();
        } else {
            me.tils_bars_2.hide();
            me.tils_bars_3.hide();

            var alt = input.alt.getValue();

            # Show/hide bars appropriately.
            # Altitude bars. On below 1000m, except on final or aiming mode (not sure about aiming mode).
            if (alt <= 1000 and me.mode != HUD.MODE_FINAL_OPT and !modes.combat) {
                me.alt_bars.show();
            } else {
                me.alt_bars.hide();
            }

            # Altitude hold boxes. On when autopilot hold is engaged. Possibly flashing.
            if (input.APmode.getValue() == 3
                and (!input.alt_bars_flash.getBoolValue() or input.twoHz.getBoolValue())) {
                me.alt_boxes.show();
            } else {
                me.alt_boxes.hide();
            }

            # Position bars.
            # Clamp displayed reference altitude.
            var ref_alt = input.ref_alt.getValue();
            ref_alt = math.clamp(ref_alt, alt - 300 * scale_factor, alt + 150 * scale_factor);
            ref_alt = math.max(ref_alt, 50);
            var pos = (alt - ref_alt) / scale_factor;
            pos = math.clamp(pos, -300, 300);
            me.alt_bars.setTranslation(0, pos);
            me.alt_boxes.setTranslation(0, pos);
        }
    },
};


var Distance = {
    new: func(parent) {
        var m = { parents: [Distance], parent: parent, mode: -1, dist_mode: -1, };
        m.initialize();
        return m;
    },

    initialize: func {
        me.group = me.parent.createChild("group").setTranslation(-150, 300);

        # Distance scale
        me.line = make_path(me.group).horiz(300);
        # Index (diamond above the scale)
        me.index = make_path(me.group)
            .lineTo(25,-25).lineTo(0,-50).lineTo(-25,-25).lineTo(0,0);
        # Cursors (below the scale)
        me.cursorL = make_path(me.group).vert(30).horiz(25);
        me.cursorM = make_path(me.group).vert(30);
        me.cursorR = make_path(me.group).vert(30).horiz(-25);

        # Digital distance
        me.dist = make_text(me.group)
            .setTranslation(340, 20)
            .setAlignment("right-top");
        me.dist.enableUpdate();
    },

    # Distance display mode: either distance line or digital distance.
    MODE_OFF: 0,
    MODE_LINE: 1,
    MODE_DIG: 2,

    set_dist_mode: func(dist_mode) {
        if (me.dist_mode == dist_mode) return;
        me.dist_mode = dist_mode;

        if (me.dist_mode == Distance.MODE_LINE) {
            me.line.show();
            me.cursorL.show();
            me.cursorM.show();
            me.cursorR.show();
        } else {
            me.line.hide();
            me.cursorL.hide();
            me.cursorM.hide();
            me.cursorR.hide();
        }

        if (me.dist_mode == Distance.MODE_DIG) {
            me.dist.show();
            me.index.setTranslation(300,0);
        } else {
            me.dist.hide();
        }

        if (me.dist_mode != Distance.MODE_OFF) {
            me.index.show();
        } else {
            me.index.hide();
        }
    },

    set_mode: func(mode) {
        me.mode = mode;
        if (me.mode == HUD.MODE_TAKEOFF_ROLL) {
            me.set_dist_mode(Distance.MODE_LINE);
            me.cursorL.setTranslation(200,0);
            me.cursorM.setTranslation(200,0);
            me.cursorR.setTranslation(200,0);
        } elsif (me.mode == HUD.MODE_NAV or me.mode == HUD.MODE_FINAL_NAV) {
            me.set_dist_mode(Distance.MODE_DIG);
        } else {
            me.set_dist_mode(Distance.MODE_OFF);
        }
    },

    update: func {
        if (me.mode == HUD.MODE_TAKEOFF_ROLL) {
            var weight = input.weight.getValue();
            var rotation_speed = 250+((weight-28725)/(40350-28725))*(280-250);#km/h
            rotation_speed = math.clamp(rotation_speed, 250, 300);

            # The length of the distance scale corresponds to 144kph (manual) (96 before cursor, 48 after).
            var pos = extrapolate(input.speed.getValue(), rotation_speed - 96, rotation_speed + 48, 0, 300);
            pos = math.clamp(pos, 0, 300);
            me.index.setTranslation(pos, 0);
        } elsif (me.mode == HUD.MODE_NAV or me.mode == HUD.MODE_FINAL_NAV) {
            if (input.rm_active.getBoolValue()) {
                var dist = metric ? input.wp_dist.getValue() : input.wp_dist_nm.getValue();
                dist = math.round(dist);

                if (dist < 1000) {
                    me.set_dist_mode(Distance.MODE_DIG);
                    me.dist.updateText(sprintf("%d", dist));
                } else {
                    me.set_dist_mode(Distance.MODE_OFF);
                }
            } else {
                me.set_dist_mode(Distance.MODE_OFF);
            }
        }
    },
};


var GPW = {
    new: func(parent) {
        var m = { parents: [GPW], parent: parent, };
        m.initialize();
        return m;
    },

    initialize: func {
        me.arrow = make_path(me.parent)
            .moveTo(-25, -125).vert(250)
            .moveTo(25, -125).vert(250)
            .moveTo(0, -150).line(50,50)
            .moveTo(0, -150).line(-50,50)
    },

    set_mode: func(mode) {},

    update: func {
        if (input.gpw.getBoolValue()) {
            me.arrow.show();
        } else {
            me.arrow.hide();
        }
    },
};


var HUD = {
    MODE_STBY: 0,
    MODE_TAKEOFF_ROLL: 1,
    MODE_TAKEOFF_ROTATE: 2,
    MODE_NAV: 3,
    MODE_AIM: 4,
    MODE_FINAL_NAV: 5,
    MODE_FINAL_OPT: 6,
    MODE_FINAL_HIGH_PITCH: 7,

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

        me.fpv = FPV.new(me.root);
        me.horizon = Horizon.new(me.fpv.get_group());

        me.hdg_scale_grp = me.horizon.get_roll_group().createChild("group");
        me.scales_grp = me.hdg_scale_grp.createChild("group");

        me.heading = Heading.new(me.hdg_scale_grp);
        me.speed = Speed.new(me.scales_grp);
        me.alt_scale = Altitude.new(me.scales_grp);
        me.dig_alt = DigitalAltitude.new(me.scales_grp);
        me.rad_alt = RadarAltitude.new(me.root);
        me.text = TextMessage.new(me.scales_grp);
        me.dist = Distance.new(me.scales_grp);
        me.gpw = GPW.new(me.horizon.get_roll_group());

        me.alt_bars = AltitudeBars.new(me.horizon.get_horizon_group());

        me.fpv_pitch = 0;
    },

    set_mode: func(mode) {
        if (me.mode == mode) return;
        me.mode = mode;

        if (mode == HUD.MODE_STBY) {
            me.root.hide();
        } else {
            me.root.show();
            me.fpv.set_mode(mode);
            me.horizon.set_mode(mode);
            me.heading.set_mode(mode);
            me.speed.set_mode(mode);
            me.alt_scale.set_mode(mode);
            me.dig_alt.set_mode(mode);
            me.rad_alt.set_mode(mode);
            me.text.set_mode(mode);
            me.dist.set_mode(mode);
            me.alt_bars.set_mode(mode);
            me.gpw.set_mode(mode);
        }
    },

    update_mode: func {
        # Whether or not the horizon line is shown. Used to decide to hide some HUD elements.
        # Values of previous loop are used. Hopefully it won't be too much of an issue.
        me.show_horizon = me.fpv_pitch <= 7.5 and me.fpv_pitch >= -7.5;

        if (modes.takeoff) {
            if (me.mode != HUD.MODE_TAKEOFF_ROLL and me.mode != HUD.MODE_TAKEOFF_ROTATE) {
                me.set_mode(HUD.MODE_TAKEOFF_ROLL);
            } elsif (input.pitch.getValue() > 5) {
                me.set_mode(HUD.MODE_TAKEOFF_ROTATE);
            } elsif (input.pitch.getValue() < 3) {
                me.set_mode(HUD.MODE_TAKEOFF_ROLL);
            }
        } elsif (modes.landing and (land.mode < 1 or land.mode == 4)) {
            if (!me.show_horizon) {
                me.set_mode(HUD.MODE_FINAL_HIGH_PITCH);
            } else {
                me.set_mode(HUD.MODE_FINAL_OPT);
            }
        } elsif (modes.landing and land.mode == 3) {
            if (!me.show_horizon) {
                me.set_mode(HUD.MODE_FINAL_HIGH_PITCH);
            } else {
                me.set_mode(HUD.MODE_FINAL_NAV);
            }
        } elsif (modes.landing and (land.mode == 1 or land.mode == 2)) {
            # Initial landing phase, NAV display mode
            me.set_mode(HUD.MODE_NAV);
        } elsif (modes.combat) {
            me.set_mode(HUD.MODE_AIM);
        } else {
            me.set_mode(HUD.MODE_NAV);
        }
    },

    compute_fpv_pitch_hdg: func(fpv_pos) {
        # Pitch/heading of FPV marker. Needs to be recomputed here,
        # because the HUD FPV marker does not exactly coincide with the real FPV
        # (clamping, takeoff mode, aiming reticle).
        me.roll = input.roll.getValue() * D2R; # Roll in radians because used by math functions.

        me.fpv_pitch = input.pitch.getValue()
            - (math.cos(me.roll) * fpv_pos[1] / 100)
            - (math.sin(me.roll) * fpv_pos[0] / 100);
        if (me.fpv_pitch > 90) {
            me.fpv_pitch = 180 - me.fpv_pitch;
            me.roll += math.pi;
        } elsif (me.fpv_pitch < -90) {
            me.fpv_pitch = -180 - me.fpv_pitch;
            me.roll += math.pi;
        }

        # WARNING: fpv_heading is completely wrong at high pitch angles.
        # However, it is only used for the heading scale in final mode,
        # which is only shown at low pitch angles.
        me.fpv_heading = input.heading.getValue()
            + (math.cos(me.roll) * fpv_pos[0] / 100)
            - (math.sin(me.roll) * fpv_pos[1] / 100);
    },

    update: func {
        metric = input.units_metric.getBoolValue();

        me.update_mode();

        me.fpv.update();
        me.compute_fpv_pitch_hdg(me.fpv.get_pos());

        me.horizon.update(me.roll * R2D, me.fpv_pitch);
        var gs_pos = me.horizon.get_gs_pos();

        # During final, heading is on the horizon, altitude/speed,... are on the glideslope.
        if (me.mode == HUD.MODE_FINAL_NAV or me.mode == HUD.MODE_FINAL_OPT) {
            me.hdg_scale_grp.setTranslation(0, me.fpv_pitch * 100);
            me.scales_grp.setTranslation(0, gs_pos);
        } else {
            me.hdg_scale_grp.setTranslation(0, 0);
            me.scales_grp.setTranslation(0, 0);
        }

        me.heading.update(me.fpv_heading);
        me.speed.update();
        me.alt_scale.update(me.fpv_pitch);
        me.dig_alt.update();
        me.rad_alt.update();
        me.text.update();
        me.dist.update();
        me.alt_bars.update(me.alt_scale.get_scale_factor(), me.show_horizon);
        me.gpw.update();
    },
};
