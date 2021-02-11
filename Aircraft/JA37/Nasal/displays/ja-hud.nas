# General, constant options
var opts = {
    res: 1024,              # Actual resolution of the canvas.
    ang_width: 28,          # Angular width of the HUD picture.
    canvas_ang_width: 29,   # Angular width to which the canvas is mapped.
                            # Adds a small margin due to border clipping issues.
    optical_axis_pitch_offset: 7.3,
    line_width: 10,
    # HUD physical dimensions. This is the object on which the Canvas is applied.
    # This values are only used for Nasal parallax correction (ALS off).
    hud_center_y: 0.69,
    hud_center_z: -4.07,
    # Maximum of width/height (actually, the size to which the texture is mapped).
    hud_size: 0.16,

    placement: {"node": "ja37hud", "texture": "hud.png"},
};


### HUD elements classes

# General conventions/methods for HUD elements classes:
# - new(parent): creates the element, 'parent' must be a Canvas
#                group used as root for the element.
# - set_mode(mode): used to indicate that the HUD display mode changed
# - update(): updates the element


# Flight path vector, or aiming reticle in aiming mode.
# Most of the HUD is centered on it.
var FPV = {
    # FPV reticle mode. Some other elements depend on it.
    MODE_OTHER: 0,
    MODE_AA_GUN: 1, # A/A cannon sight
    MODE_AG: 2,     # A/G cannon/rocket sight

    lateral_clamp: 750,     # 7.5 degs laterally. Not sure what the source was for that.
    top_clamp: -600,        # 6 degs up (guess)
    bottom_clamp: 1600,     # 16 degs down (guess, just enough for 15.5 AoA)

    new: func(parent) {
        var m = { parents: [FPV], parent: parent, mode: -1, reticle_mode: 0, };
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
        me.aim_empty = make_path(me.aim)
            .moveTo(-100,0).lineTo(-25,0).lineTo(0,25).lineTo(25,0).lineTo(100,0);
        me.aim_missile = make_path(me.aim)
            .moveTo(-20,0).horizTo(80).moveTo(0,-20).vertTo(20);

        # Cannon/rockets aiming reticle. With submodes
        me.aim_reticle = me.aim.createChild("group");
        make_dot(me.aim_reticle, 0, 0, opts.line_width*2);

        # A/A mode
        me.aim_AA_reticle = me.aim_reticle.createChild("group");

        me.trace_line_rot = me.aim_AA_reticle.createChild("group");
        me.trace_line = make_path(me.trace_line_rot).horiz(300).hide();
        me.fire_mark = make_path(me.aim_AA_reticle).moveTo(-30,0).horizTo(30).moveTo(0,-30).vertTo(30).hide();

        # A/A without target lock reticle
        me.aim_gun_free = me.aim_AA_reticle.createChild("group");
        make_path(me.aim_gun_free).moveTo(-250,250).lineTo(-250,300).lineTo(-200,300);   # L in bottom left
        # Vertical lines indicating wingspan of target.
        me.wingspan_l = make_path(me.aim_gun_free).moveTo(0,-50).vert(250);
        me.wingspan_r = make_path(me.aim_gun_free).moveTo(0,-50).vert(250);
        me.wingspan_txt = make_text(me.aim_gun_free).setAlignment("left-bottom");
        me.wingspan_txt.enableUpdate();
        me.dist_txt = make_text(me.aim_gun_free).setAlignment("left-bottom");
        me.dist_txt.enableUpdate();

        # A/A with target lock reticle
        me.aim_gun_tgt = me.aim_AA_reticle.createChild("group");
        make_path(me.aim_gun_tgt)
            .moveTo(-200,0).horizTo(-100).moveTo(200,0).horizTo(100)
            .moveTo(0,-125).vertTo(-175)
            .moveTo(-60,60).lineTo(-90,90).lineTo(-75,105);
        make_dot(me.aim_gun_tgt, 0, 100, opts.line_width);
        make_dot(me.aim_gun_tgt, 0, -100, opts.line_width);
        me.dist_index = me.aim_gun_tgt.createChild("group");
        me.dist_index_norm = make_path(me.dist_index)
            .moveTo(-100,0).line(25,25).line(25,-25).line(-25,-25).line(-25,25);
        me.dist_index_fire = make_path(me.dist_index)
            .moveTo(-100,0).line(35,25).moveTo(-100,0).line(35,-25);
        me.dist_arc = make_path(me.aim_gun_tgt);
        me.dist_tgt = make_text(me.aim_gun_tgt).setAlignment("left-bottom").setTranslation(120,190);
        me.dist_tgt.enableUpdate();

        # A/G reticle
        me.aim_AG_reticle = me.aim_reticle.createChild("group");
        make_path(me.aim_AG_reticle)
            .moveTo(-100,0).horizTo(-30).moveTo(100,0).horizTo(30);
        me.aim_AG_reticle_vert = make_path(me.aim_AG_reticle)
            .moveTo(0,-100).vertTo(-30).moveTo(0,100).vertTo(30);

        me.pos_x = me.pos_y = 0;
    },

    set_mode: func(mode) {
        me.mode = mode;
        if (me.mode == HUD.MODE_TAKEOFF_ROLL or me.mode == HUD.MODE_TAKEOFF_ROTATE) {
            me.nav.hide();
            me.takeoff.show();
            me.aim.hide();
            me.reticle_mode = FPV.MODE_OTHER;
        } elsif (me.mode == HUD.MODE_AIM) {
            me.nav.hide();
            me.takeoff.hide();
            me.aim.show();
        } else {
            me.nav.show();
            me.takeoff.hide();
            me.aim.hide();
            me.reticle_mode = FPV.MODE_OTHER;
        }
    },

    update_AA_reticle: func {
        # Run A/A sight update loop when we are using it.
        sight.AAsight.update();
        var pos = sight.AAsight.get_pos();
        # gunsight uses mils
        me.pos_x = math.clamp(pos[0] * MIL2HUD, -me.lateral_clamp, me.lateral_clamp);
        me.pos_y = math.clamp(pos[1] * MIL2HUD, me.top_clamp, me.bottom_clamp);

        if (radar_logic.selection != nil) {
            me.aim_gun_tgt.show();
            me.aim_gun_free.hide();

            # Target distance
            var dist = radar_logic.selection.get_range()*NM2M/1000;
            me.dist_tgt.updateText(displays.sprintdist(dist, 1));
            # Circular target index/line
            var index_angle = math.min(dist/1.6*math.pi, 2*math.pi);
            if (dist <= 3.2) {
                me.dist_index.setRotation(-index_angle);
                me.dist_index.show();
                if (dist >= 0.3 and dist <= 1.2) {
                    me.dist_index_fire.show();
                    me.dist_index_norm.hide();
                } else {
                    me.dist_index_fire.hide();
                    me.dist_index_norm.show();
                }
            } else {
                me.dist_index.hide();
            }
            var arc_end_x = -math.cos(index_angle)*100;
            var arc_end_y = math.sin(index_angle)*100;
            me.dist_arc.reset();
            me.dist_arc.moveTo(-100,0);
            if (index_angle <= math.pi) me.dist_arc.arcSmallCCWTo(100, 100, 0, arc_end_x, arc_end_y);
            else me.dist_arc.arcLargeCCWTo(100, 100, 0, arc_end_x, arc_end_y);
        } else {
            me.aim_gun_tgt.hide();
            me.aim_gun_free.show();

            var wingspan = 15;  # m
            var dist = 0.6;     # km

            # Angle from center to wingspan indication lines
            var offset = wingspan/2/dist * MIL2HUD;

            me.wingspan_l.setTranslation(-offset, 0);
            me.wingspan_r.setTranslation(offset, 0);
            me.wingspan_txt.updateText(sprintf("%d", wingspan));
            me.dist_txt.updateText(displays.sprintdist(dist, 1));
            me.wingspan_txt.setTranslation(offset + 30, 0);
            me.dist_txt.setTranslation(offset + 60, 250);
        }

        if (fire_control.is_armed()) {
            var mark_pos = sight.AAsight.get_pos_sec();
            mark_pos[0] = mark_pos[0] * MIL2HUD - me.pos_x;
            mark_pos[1] = mark_pos[1] * MIL2HUD - me.pos_y;
            var angle = math.atan2(mark_pos[1], mark_pos[0]);
            var length = math.sqrt(mark_pos[0]*mark_pos[0] + mark_pos[1]*mark_pos[1]);
            var capped_length = math.min(length, 300);
            me.trace_line_rot.setRotation(angle);
            me.trace_line.setScale(capped_length/300, 1);
            me.trace_line.show();

            if (fire_control.is_firing()) {
                me.fire_mark.setTranslation(mark_pos[0]/length*capped_length, mark_pos[1]/length*capped_length);
                me.fire_mark.show();
            } else {
                me.fire_mark.hide();
            }
        } else {
            me.trace_line.hide();
            me.fire_mark.hide();
        }
    },

    update_AG_reticle: func {
        # Run A/G sight update loop when we are using it.
        sight.AGsight.update();
        var pos = sight.AGsight.get_pos();
        # Hide vertical bar of crosshair once armed.
        me.aim_AG_reticle_vert.setVisible(!fire_control.is_armed());
        # sight uses mils
        me.pos_x = math.clamp(pos[0] * MIL2HUD, -me.lateral_clamp, me.lateral_clamp);
        me.pos_y = math.clamp(pos[1] * MIL2HUD, me.top_clamp, me.bottom_clamp);
    },

    update_reticle: func {
        if (TI.ti.ModeAttack or fire_control.get_type() == "M70 ARAK") {
            # A/G mode
            me.aim_AA_reticle.hide();
            me.aim_AG_reticle.show();
            me.update_AG_reticle();
            me.reticle_mode = FPV.MODE_AG;
        } else {
            # A/A mode
            me.aim_AA_reticle.show();
            me.aim_AG_reticle.hide();
            me.update_AA_reticle();
            me.reticle_mode = FPV.MODE_AA_GUN;
        }
    },

    # Update function for aiming mode.
    update_aim: func {
        me.pos_x = 0;
        me.pos_y = 0;

        # Aiming mode. Reticle display depends on selected weapon.
        if (!fire_control.weapon_ready()) {
            # No weapon. Normal FPV, with a special symbol.
            me.pos_x = math.clamp(100 * input.fpv_right.getValue(), -me.lateral_clamp, me.lateral_clamp);
            me.pos_y = math.clamp(-100 * input.fpv_up.getValue(), me.top_clamp, me.bottom_clamp);
            me.aim_empty.show();
            me.aim_missile.hide();
            me.aim_reticle.hide();
            me.reticle_mode = FPV.MODE_OTHER;
        } elsif (fire_control.get_type() == "M70 ARAK" or fire_control.get_type() == "M75 AKAN") {
            me.aim_empty.hide();
            me.aim_missile.hide();
            me.aim_reticle.show();

            me.update_reticle();
        } else {
            # Small reticle for missiles.
            me.aim_empty.hide();
            me.aim_missile.show();
            me.aim_reticle.hide();
            me.reticle_mode = FPV.MODE_OTHER;
        }

        me.group.setTranslation(me.pos_x, me.pos_y);
    },

    update: func {
        if (me.mode == HUD.MODE_AIM) return me.update_aim();

        # Update FPV position.
        me.pos_x = math.clamp(100 * input.fpv_right.getValue(), -me.lateral_clamp, me.lateral_clamp);
        if (me.mode == HUD.MODE_TAKEOFF_ROLL or me.mode == HUD.MODE_TAKEOFF_ROTATE) {
            me.pos_y = 1000;    # Fixed 10deg below forward axis for takeoff.
        } else {
            me.pos_y = math.clamp(-100 * input.fpv_up.getValue(), me.top_clamp, me.bottom_clamp);
        }
        me.group.setTranslation(me.pos_x, me.pos_y);

        # Commanded speed.
        if (modes.landing) {
            var dev = 0;
            var blink = FALSE;
            if (input.gear_pos.getValue() != 1) {
                # Gear (partially) up, indicates speed deviation from 550km/h.
                # Max deviation is 37km/h (from AJS, no JA source).
                dev = (input.speed.getValue() - 550) / 37;
            } else {
                # Gear full down, indicates alpha deviation.
                # Target alpha depends on weight and is capped to 12deg (15.5deg in high alpha mode).
                # Maximum deviation is 3.3deg (from AJS, no JA source).
                var weight = input.weight.getValue() * LB2KG;
                var high_alpha = input.high_alpha.getBoolValue();
                var target_alpha = extrapolate(weight, 15000, 16500, 15.5, 9.0);
                target_alpha = math.clamp(target_alpha, 9, high_alpha ? 15.5 : 12);
                dev = (target_alpha - input.alpha.getValue()) / 3.3;
                # Critical alpha (indicator starts blinking).
                # Values for 12deg and 15.5deg are from AJS again.
                var critical_limit = extrapolate(target_alpha, 12, 15.5, -1, -0.75);
                critical_limit = math.clamp(critical_limit, -1, -0.75);
                blink = (dev <= critical_limit);
            }
            dev = math.clamp(dev, -1, 1);
            me.tail.setTranslation(0, -50*dev);
            me.tail.setVisible(!blink or input.fourHz.getBoolValue());
        } else {
            me.tail.setTranslation(0,0);
            me.tail.show();
        }
    },

    get_pos: func {
        return [me.pos_x, me.pos_y];
    },

    get_group: func {
        return me.group;
    },

    get_fpv_mode: func {
        return me.reticle_mode;
    },
};


# Artificial horizon. Fixed on FPV.
var Horizon = {
    # A bar of the pitch scale.
    #
    # A bar object can be changed to display a bar for any pitch angle.
    # This is done to only have 3 PitchBar objects (because only 3 pitch bars are displayed at all time).
    PitchBar: {
        new: func(parent, x, y) {
            var b = { parents: [Horizon.PitchBar], parent: parent, aim_mode: -1, };
            b.initialize(x, y);
            return b;
        },

        initialize: func(x,y) {
            me.group = me.parent.createChild("group").setTranslation(x,y);
            me.nav = me.group.createChild("group");
            me.aim = me.group.createChild("group");

            # Create all different types of bars.
            # Navigation mode
            me.nav_upper_bar = make_path(me.nav)
                .moveTo(-1000,0).horizTo(-200).moveTo(1000,0).horizTo(200);

            me.nav_horizon = me.nav.createChild("group");
            make_path(me.nav_horizon)
                .moveTo(-1000,0).horizTo(-300)
                .moveTo(1000,0).horizTo(580).moveTo(380,0).horizTo(300);
            # Center dots (drawn as very short lines to simplify).
            var dots = make_path(me.nav_horizon).setStrokeLineWidth(2*opts.line_width);
            for (var i=-250; i<=250; i+=100) {
                dots.moveTo(i-0.01,0).horizTo(i+0.01);
            }

            me.nav_lower_bar = me.nav.createChild("group");
            make_path(me.nav_lower_bar).moveTo(-1000,0).horizTo(-200).setStrokeDashArray([80,64]);
            make_path(me.nav_lower_bar).moveTo(1000,0).horizTo(488).setStrokeDashArray([80,64]);
            make_path(me.nav_lower_bar).moveTo(280,0).horizTo(200);

            # Aim mode
            me.aim_upper_bar = make_path(me.aim)
                .moveTo(-1000,0).horizTo(-440)
                .moveTo(1000,0).horizTo(440);

            me.aim_lower_bar = me.aim.createChild("group");
            make_path(me.aim_lower_bar).moveTo(-1000,0).horizTo(-440).setStrokeDashArray([86,72]);
            make_path(me.aim_lower_bar).moveTo(1000,0).horizTo(440).setStrokeDashArray([86,72]);

            make_path(me.aim).moveTo(-440,0).vert(30).moveTo(440,0).vert(30);

            # Text label
            me.text = make_text(me.group).setTranslation(-400, -20).setAlignment("left-bottom");
            me.text.enableUpdate();

            me.set_aim_mode(FALSE);
        },

        set_aim_mode: func(aim) {
            if (aim == me.aim_mode) return;
            me.aim_mode = aim;

            me.aim.setVisible(aim);
            me.nav.setVisible(!aim);
            me.text.setTranslation(aim ? -580 : -400, -20);
        },

        update: func(pitch) {
            if (me.aim_mode) {
                me.aim_upper_bar.setVisible(pitch >= 0);
                me.aim_lower_bar.setVisible(pitch < 0);
            } else {
                me.nav_upper_bar.setVisible(pitch > 0);
                me.nav_horizon.setVisible(pitch == 0);
                me.nav_lower_bar.setVisible(pitch < 0);
            }

            me.text.updateText(sprintf("%+d", pitch));
        },

        show: func { me.group.show(); },
        hide: func { me.group.hide(); },
    },

    new: func(parent) {
        var m = { parents: [Horizon], parent: parent, mode: -1, };
        m.initialize();
        return m;
    },

    initialize: func {
        me.roll_group = me.parent.createChild("group", "roll");
        me.group = me.roll_group.createChild("group");

        me.lower_bar = Horizon.PitchBar.new(me.group, 0, 500);
        me.center_bar = Horizon.PitchBar.new(me.group, 0, 0);
        me.upper_bar = Horizon.PitchBar.new(me.group, 0, -500);

        me.landing_horizon = make_path(me.group).moveTo(-1000,0).horizTo(1000);
        me.gs_pos = [0,286];    # Nominal glidslope angle: 2.86deg (5% slope)
        me.glideslope = me.group.createChild("group")
            .setTranslation(me.gs_pos[0], me.gs_pos[1]);
        make_path(me.glideslope)
            .moveTo(-600,0).horizTo(-100)
            .moveTo(700,0).horizTo(650).moveTo(380,0).horizTo(100);
        make_dot(me.glideslope, 0, 0, opts.line_width*2);
    },

    set_mode: func(mode) {
        me.mode = mode;
        if (me.mode == HUD.MODE_FINAL_NAV or me.mode == HUD.MODE_FINAL_OPT) {
            me.lower_bar.hide();
            me.center_bar.hide();
            me.upper_bar.set_aim_mode(FALSE);
            me.upper_bar.update(5);
            me.landing_horizon.show();
            me.glideslope.show();
        } else {
            me.lower_bar.show();
            me.center_bar.show();
            me.lower_bar.set_aim_mode(me.mode == HUD.MODE_AIM);
            me.center_bar.set_aim_mode(me.mode == HUD.MODE_AIM);
            me.upper_bar.set_aim_mode(me.mode == HUD.MODE_AIM);
            me.landing_horizon.hide();
            me.glideslope.hide();
        }
    },

    # Warning, parameter fpv_heading (or track angle) is completely wrong it high pitch angles.
    # It is only used for ILS indication, which are not displayed at high angles anyway.
    update: func(fpv_roll, fpv_pitch, fpv_heading) {
        # Position of pitch scale.
        me.roll_group.setRotation(-fpv_roll * D2R);

        if (me.mode == HUD.MODE_FINAL_NAV or me.mode == HUD.MODE_FINAL_OPT) {
            # Glideslope position
            # Horizontal
            me.gs_pos[0] = 0;
            if (me.mode == HUD.MODE_FINAL_NAV and input.nav_lock.getBoolValue()
                and (land.has_waypoint < 1 or (land.has_waypoint > 1 and land.ils))) {
                # TILS. Extremely basic 'flight director' (proportional command)
                var ils_rdl = input.nav_rdl.getValue();
                me.gs_pos[0] = ils_rdl + input.nav_defl.getValue()*2 - fpv_heading;
                me.gs_pos[0] = geo.normdeg180(me.gs_pos[0]);
                me.gs_pos[0] = math.clamp(me.gs_pos[0], -6, 6);
                me.gs_pos[0] *= 100;
            }
            # Vertical
            me.gs_pos[1] = 286; # default
            if (me.mode == HUD.MODE_FINAL_OPT) {
                # If sufficiently low, switch to landing flare mode. Threshold is lower if RHM is used.
                if (input.rad_alt_ready.getBoolValue()) {
                    var flare = input.rad_alt.getValue() < 15;
                } else {
                    var flare = input.alt.getValue() < 35;
                }
                # During flare, glideslope moves up to indicate maximal acceptable vertical speed (2.8m/s)
                if (flare) {
                    var groundspeed = input.groundspeed.getValue() * KT2MPS;
                    me.gs_pos[1] = math.min(math.atan2(2.8, groundspeed) * R2D * 100, 286);
                }
            }

            # Note: horizontally, the entire artificial moves with the glideslope.
            me.glideslope.setTranslation(0, me.gs_pos[1]);
            me.group.setTranslation(me.gs_pos[0], fpv_pitch * 100);
        } else {
            # Pitch of center bar.
            var center_bar = math.round(fpv_pitch, 5);
            center_bar = math.clamp(center_bar, -85, 85);

            # Update bars position
            me.group.setTranslation(0, (fpv_pitch - center_bar) * 100);

            # Update pitch displayed by the 3 bars.
            me.lower_bar.update(center_bar-5);
            me.center_bar.update(center_bar);
            me.upper_bar.update(center_bar+5);
        }
    },

    get_roll_group: func { return me.roll_group; },
    get_gs_pos: func { return me.gs_pos; },
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
        if (me.mode == HUD.MODE_FINAL_NAV or me.mode == HUD.MODE_FINAL_OPT) {
            # 1:1 heading scale presentation. Use heading of FPV marker (which is clamped).
            # so that the heading scale matches the real world.
            var track = fpv_heading;
        } else {
            # Otherwise use real track angle.
            var track = input.fpv_track.getValue() - input.head_true.getValue() + input.heading.getValue();
        }

        var center_mark = math.round(track, 5);

        me.marker_grp.setTranslation((center_mark - track) * me.scale_factor, 0);
        # update() required: otherwise show()/hide() applies immediately,
        # while other changes wait for the next frame.
        me.marker_grp.update();

        forindex (var i; me.markers) {
            var hdg = geo.normdeg(center_mark + (i-2) * 5);
            var long = math.mod(hdg, 10) == 0;
            me.markers[i].update(hdg, long);
        }

        if (me.mode != HUD.MODE_FINAL_NAV and me.mode != HUD.MODE_FINAL_OPT) {
            if (input.rm_active.getBoolValue()
                and me.mode != HUD.MODE_TAKEOFF_ROLL and me.mode != HUD.MODE_TAKEOFF_ROTATE) {
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
            me.move_up_landing(FALSE);
        }
        if (me.mode == HUD.MODE_AIM) {
            me.text.setTranslation(0, 400);
        } else {
            me.text.setTranslation(0, 490);
        }
    },

    move_up_landing: func(up) {
        if (up == me.moved_up) return;

        me.moved_up = up;
        me.text.setTranslation(0, up ? 300 : 490);
    },

    update: func {
        if (me.mode == HUD.MODE_FINAL_NAV or me.mode == HUD.MODE_FINAL_OPT) {
            # At landing, move airspeed up when alpha is 8.5deg.
            var alpha = -input.fpv_up.getValue();
            if (alpha >= 8.5) me.move_up_landing(TRUE);
            elsif (alpha <= 5.5) me.move_up_landing(FALSE);
        }

        var mach = input.mach.getValue();
        if (mach >= 0.5) {
            me.text.updateText(displays.sprintdec(mach, 2));
            me.text.show();
        } elsif (displays.metric) {
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

        update: func(pos, alt, long, show_text) {
            me.group.setTranslation(0, pos);

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
                me.text.updateText(displays.sprintalt(alt, TRUE));  # second arg disables conversion
                me.text.show();
            }

            # update() required: otherwise show()/hide() applies immediately,
            # while other changes wait for the next frame.
            me.group.update();
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

        if (displays.metric) {
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

        var ac_alt = input.alt.getValue();
        if (!displays.metric) ac_alt *= M2FT;
        me.set_ac_alt(ac_alt);

        # Markers for the linear part of the scale.
        var spacing = displays.metric ? 50 : 100;
        var center_mark = math.round(me.ac_alt, spacing);
        var mark_limit = displays.metric ? 200 : 500;

        var i = 0;
        for (var alt = center_mark - mark_limit; alt <= center_mark + mark_limit; alt += spacing) {
            var pos = me.lin_alt2pos(alt);
            # Too high or too low
            if (alt <= 0 or pos < me.upper_limit) {
                me.lin_markers[i].hide();
            } else {
                if (displays.metric) {
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

                me.lin_markers[i].update(pos, alt, long_mark, show_text);
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
        if (me.ac_alt <= (displays.metric ? 100 : 200)) {
            var spacing = displays.metric ? 10 : 20;
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

            var pos = me.lin_alt2pos(displays.metric ? 75 : 150);
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
            var rad_alt = input.rad_alt.getValue();
            if (!displays.metric) rad_alt *= M2FT;
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
        if (displays.metric) return me.scale_factor;
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
            .setTranslation(600, 0)
            .setAlignment("right-bottom");
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

    update: func(fpv_mode) {
        if (me.mode != HUD.MODE_AIM) return;

        me.text.updateText(displays.sprintalt(input.alt.getValue()));

        if (fpv_mode == FPV.MODE_AG and fire_control.is_firing()) {
            # Manual: in A/G mode, altitude moves to the right when firing.
            me.text.setTranslation(-500,0);
        } else {
            me.text.setTranslation(600,0);
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
            var alt = input.rad_alt.getValue();
            if (!displays.metric) alt *= M2FT;
            alt = math.round(alt);
            if (alt < (displays.metric ? 100 : 300)) me.shown = TRUE;
            elsif (alt >= (displays.metric ? 110 : 350)) me.shown = FALSE;
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

    set_mode: func(mode) {
        me.mode = mode;
        if (me.mode == HUD.MODE_AIM) {
            me.text.setTranslation(-300, 200);
        } else {
            me.text.setTranslation(-300, 300);
        }
    },

    update: func(fpv_mode) {
        if (input.qfe_warning.getBoolValue()) {
            me.text.updateText("QFE");
            me.text.setVisible(input.twoHz.getBoolValue());
        } elsif (modes.landing and (land.mode == 2 or land.mode == 3)
                 and (input.tils_steady.getBoolValue() or input.tils_blink.getBoolValue())) {
            me.text.updateText("TILS");
            if (input.tils_blink.getBoolValue() and !input.fourHz.getBoolValue()) {
                me.text.hide();
            } else {
                me.text.show();
            }
        } elsif (!modes.takeoff_30s_inhibit and fire_control.weapon_ready()
                 and (me.mode == HUD.MODE_NAV or me.mode == HUD.MODE_AIM)
                 # Exception: hide AKAN in A/A gunsight mode (there is no ambiguity in this mode anyway).
                 and fpv_mode != FPV.MODE_AA_GUN) {
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
        if (me.mode == HUD.MODE_AIM) {
            # Aiming mode is special in that alt hold boxes are displayed fixed,
            # simply as an indication that altitude hold is on.
            me.alt_bars.hide();
            me.tils_bars_2.hide();
            me.tils_bars_3.hide();
            me.alt_boxes.setTranslation(0, 0);
            if (input.APmode.getValue() == 3
                and (!input.alt_bars_flash.getBoolValue() or input.twoHz.getBoolValue())) {
                me.alt_boxes.show();
            } else {
                me.alt_boxes.hide();
            }
        } elsif (!show_horizon) {
            me.alt_bars.hide();
            me.alt_boxes.hide();
            me.tils_bars_2.hide();
            me.tils_bars_3.hide();
            return;
        } elsif (me.mode == HUD.MODE_FINAL_NAV) {
            # TILS final, only TILS guidance bars are displayed.
            me.alt_bars.hide();
            me.alt_boxes.hide();
            # Glideslope indication
            if ((land.has_waypoint < 1 or (land.has_waypoint > 1 and land.ils))
                and input.nav_has_gs.getBoolValue() and input.nav_gs_lock.getBoolValue()) {
                var defl = math.clamp(-input.nav_gs_defl.getValue(), -0.5, 1);
                me.tils_bars_2.setTranslation(0, 286 + defl*200);
                me.tils_bars_3.setTranslation(0, 286 + defl*300);
                me.tils_bars_2.show();
                me.tils_bars_3.show();
            } else {
                me.tils_bars_2.hide();
                me.tils_bars_3.hide();
            }
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
            # Altitude bars. On below 1000m, except on final or aiming mode.
            if (alt <= 1000 and me.mode != HUD.MODE_FINAL_OPT and me.mode != HUD.MODE_AIM) {
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
        me.index = me.group.createChild("group");
        me.index_norm = make_path(me.index).lineTo(25,-25).lineTo(0,-50).lineTo(-25,-25).lineTo(0,0);
        me.index_fire = make_path(me.index).lineTo(25,-35).moveTo(0,0).lineTo(-25,-35);
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

    set_mode: func(mode) {
        me.mode = mode;
        if (me.mode == HUD.MODE_TAKEOFF_ROLL) {
            # Line indicates rotation speed
            me.group.show();
            me.line.show();
            me.index.setTranslation(0,0).show();
            me.index_norm.show();
            me.index_fire.hide();
            me.cursorL.setTranslation(200,0).show();
            me.cursorM.setTranslation(200,0).show();
            me.cursorR.setTranslation(200,0).show();
            me.dist.hide();
        } elsif (me.mode == HUD.MODE_NAV or me.mode == HUD.MODE_AIM or me.mode == HUD.MODE_FINAL_NAV) {
            # Multiple functionalities.
            me.group.show();

            if (me.mode == HUD.MODE_AIM) me.group.setTranslation(-150, 200);
            else me.group.setTranslation(-150, 300);
        } else {
            me.group.hide();
        }
    },

    update: func(fpv_mode) {
        if (me.mode == HUD.MODE_TAKEOFF_ROLL) {
            var rotation_speed = input.rotation_speed.getValue();
            # The length of the distance scale corresponds to 144kph (manual) (96 before cursor, 48 after).
            var pos = extrapolate(input.speed.getValue(), rotation_speed - 96, rotation_speed + 48, 0, 300);
            pos = math.clamp(pos, 0, 300);
            me.index.setTranslation(pos, 0);
        } elsif (me.mode == HUD.MODE_AIM and fpv_mode == FPV.MODE_AA_GUN) {
            # A/A cannon sight has a special distance scale.
            me.group.hide();
        } elsif (me.mode == HUD.MODE_AIM and fpv_mode == FPV.MODE_AG) {
            # Show distance to ground.

            # dist is a vector [target dist, minimum dist, optimal dist], or nil
            var dist = sight.AGsight.get_dist();

            if (fire_control.get_type() == "M70 ARAK") {
                var scale_dist = 8000; # Maximum displayed distance
                var max_dist = 6000;   # Maximum firing range (made up)
            } else { # M75 AKAN
                var scale_dist = 8000; # Maximum displayed distance
                var max_dist = 5000;   # Maximum firing range (made up)
            }

            if (dist != nil and dist[0] <= scale_dist) {
                me.group.show();
                me.line.show();
                me.index.show();
                me.cursorL.show();
                me.cursorM.show();
                me.cursorR.show();
                me.dist.show();
                me.cursorL.setTranslation(dist[1] / scale_dist * 300, 0);
                me.cursorM.setTranslation(dist[2] / scale_dist * 300, 0);
                me.cursorR.setTranslation(max_dist / scale_dist * 300, 0);
                me.index.setTranslation(dist[0] / scale_dist * 300, 0);
                me.dist.updateText(displays.sprintdist(dist[0]/1000, 1));

                if (dist[0] >= dist[1] and dist[0] <= max_dist) {
                    me.index_norm.hide();
                    me.index_fire.show();
                } else {
                    me.index_norm.show();
                    me.index_fire.hide();
                }
            } else {
                me.group.hide();
            }
        } elsif ((me.mode == HUD.MODE_NAV or me.mode == HUD.MODE_AIM) and radar_logic.selection != nil) {
            # Display distance to target.
            me.group.show();
            me.line.show();
            me.index.show();
            me.cursorL.hide();
            me.cursorM.setTranslation(0,0).show();
            me.cursorR.hide();
            me.dist.show();

            if (fire_control.is_armed() and fire_control.get_weapon() != nil
                and (var dlz = fire_control.get_weapon().getDLZ(TRUE)) != nil and size(dlz) > 0) {
                # Cursors indicate missile dynamic launch zone.
                var max_dist = dlz[0];
                me.index.setTranslation(math.clamp(dlz[4] / max_dist * 300, 0, 300), 0);
                me.cursorL.setTranslation(dlz[3] / max_dist * 300, 0).show();
                me.cursorM.setTranslation(dlz[1] / max_dist * 300, 0);
                me.cursorR.setTranslation(dlz[2] / max_dist * 300, 0).show();

                if (dlz[4] >= dlz[3] and dlz[4] <= dlz[2]) {
                    me.index_norm.hide();
                    me.index_fire.show();
                } else {
                    me.index_norm.show();
                    me.index_fire.hide();
                }

                # Convert scale to Km (or NM) for numerical display
                if (displays.metric) max_dist *= NM2M / 1000;
            } else {
                # Line length indicates radar range.
                var max_dist = input.radar_range.getValue();
                var range = math.clamp(radar_logic.selection.get_range()*NM2M, 0, max_dist);
                me.index.setTranslation(range / max_dist * 300, 0);
                me.index_norm.show();
                me.index_fire.hide();

                # Convert scale to Km (or NM) for numerical display.
                if (displays.metric) max_dist /= 1000;
                else max_dist *= M2NM;
            }

            # Print with 0 or 1 decimal places. Disable conversion, it is already done.
            me.dist.updateText(displays.sprintdist(max_dist, max_dist>=10 ? 0 : 1, TRUE));
        } elsif ((me.mode == HUD.MODE_NAV or me.mode == HUD.MODE_FINAL_NAV) and input.rm_active.getBoolValue()) {
            var dist = displays.metric ? input.wp_dist.getValue() : input.wp_dist_nm.getValue();
            dist = math.round(dist);

            if (dist < 1000) {
                me.group.show();
                me.index.setTranslation(300,0).show();
                me.index_norm.show();
                me.index_fire.hide();
                me.dist.updateText(sprintf("%d", dist));
                me.dist.show();
                me.line.hide();
                me.cursorL.hide();
                me.cursorM.hide();
                me.cursorR.hide();
            } else {
                me.group.hide();
            }
        } else {
            me.group.hide();
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


var Targets = {
    # Generic target marker. Used for actual target, IR seeker,...
    # It consists of a main group (to which the appropriate symbol can be added).
    # The symbol is clamped around the FPV, and is extended
    # by a line if the target is outside the clamp area.
    Target: {
        new: func(parent) {
            var t = { parents: [Targets.Target], parent: parent, };
            t.initialize();
            return t;
        },

        initialize: func {
            me.group = me.parent.createChild("group");
            me.line_rot = me.group.createChild("group");
            me.line = make_path(me.line_rot).horiz(1000);
            me.line.hide();
        },

        # Update to display a target at HUD coordinates (x,y).
        update: func(x, y, fpv_pos) {
            x -= fpv_pos[0];
            y -= fpv_pos[1];
            var radius = math.sqrt(x*x + y*y);
            # Clamping at 3 degrees from center
            if (radius <= 300) {
                me.line.hide();
                me.group.setTranslation(x,y);
            } else {
                # Switch to polar coordinates.
                me.group.setTranslation(x/radius*300, y/radius*300);
                me.line_rot.setRotation(math.atan2(y,x));
                var line_length = math.min(radius - 300, 1000);
                me.line.setScale(line_length / 1000, 1);
                me.line.show();
            }
        },

        get_symbol_group: func { return me.group; },
        show: func { me.group.show(); },
        hide: func { me.group.hide(); },
    },

    new: func(parent) {
        var m = { parents: [Targets], parent: parent, mode: -1, };
        m.initialize();
        return m;
    },

    initialize: func {
        me.group = me.parent.createChild("group");
        # Radar target: upper circle
        me.tgt = Targets.Target.new(me.group);
        me.tgt_symbol = make_path(me.tgt.get_symbol_group())
            .moveTo(-50,0).arcSmallCWTo(50,50,0,50,0);
        me.tgt_iff = make_path(me.tgt.get_symbol_group())
            .moveTo(-50,-50).lineTo(50,50)
            .moveTo(-50,50).lineTo(50,-50);
        # IR seeker: lower circle
        me.seeker = Targets.Target.new(me.group);
        make_path(me.seeker.get_symbol_group()).moveTo(-50,0).arcSmallCCWTo(50,50,0,50,0);
    },

    set_mode: func(mode) {
        me.mode = mode;
        if (me.mode != HUD.MODE_NAV and me.mode != HUD.MODE_AIM) {
            me.group.hide();
            return;
        } else {
            me.group.show();
        }
    },

    update: func(fpv_pos) {
        if (radar_logic.selection != nil) {
            var pos = radar_logic.selection.get_cartesian();
            me.tgt.update(pos[0]*100, pos[1]*100, fpv_pos);
            me.tgt.show();
            me.tgt_iff.setVisible(radar_logic.selection.getIFF());
        } else {
            me.tgt.hide();
        }

        # Use ["is_IR"] instead of .is_IR because it is not always a member of fire_control.selected.
        # And yes I'm defining variables in the condition, you can't stop me.
        if (fire_control.is_armed() and fire_control.selected["is_IR"]
            and (var weapon = fire_control.get_weapon()) != nil
            and (var pos = weapon.getSeekerInfo()) != nil
            and (weapon.status == armament.MISSILE_LOCK or !weapon.isCaged() or !weapon.command_tgt)) {
            me.seeker.update(pos[0]*100, pos[1]*-100, fpv_pos);
            me.seeker.show();
        } else {
            me.seeker.hide();
        }
    },
};


# Simple fixed reticle for gun/rocket in nav mode.
var Reticle = {
    new: func(parent) {
        var m = { parents: [Reticle], parent: parent, mode: -1, };
        m.initialize();
        return m;
    },

    initialize: func {
        me.reticle = make_path(me.parent)
            .moveTo(-30,0).horizTo(30).moveTo(0,-30).vertTo(30);
    },


    set_mode: func(mode) {
        me.mode = mode;
    },

    update: func {
        if (me.mode == HUD.MODE_NAV and fire_control.is_armed()
            and (fire_control.get_type() == "M75 AKAN" or fire_control.get_type() == "M70 ARAK")) {
            me.reticle.show();
        } else {
            me.reticle.hide();
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

        # Roll stabilized group for alt/speed/heading scales.
        # In AIM mode, it is no longer roll stabilized.
        me.scales_roll_grp = me.fpv.get_group().createChild("group");
        # Scales (altitude, speed, ...) group. In general, centered on FPV, roll stabilized.
        me.scales_grp = me.scales_roll_grp.createChild("group");
        # Altitude bars. Horizon fixed.
        me.alt_bars_grp = me.scales_roll_grp.createChild("group");
        # Heading scale group. Same as scales_grp except in landing mode, where on the horizon.
        me.hdg_scale_grp = me.scales_roll_grp.createChild("group");

        me.heading = Heading.new(me.hdg_scale_grp);
        me.speed = Speed.new(me.scales_grp);
        me.alt_scale = Altitude.new(me.scales_grp);
        me.dig_alt = DigitalAltitude.new(me.scales_grp);
        me.rad_alt = RadarAltitude.new(me.root);
        me.text = TextMessage.new(me.scales_grp);
        me.dist = Distance.new(me.scales_grp);
        me.gpw = GPW.new(me.horizon.get_roll_group());
        me.alt_bars = AltitudeBars.new(me.alt_bars_grp);

        me.targets = Targets.new(me.fpv.get_group());
        me.reticle = Reticle.new(me.root);

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
            me.targets.set_mode(mode);
            me.reticle.set_mode(mode);
        }
    },

    update_mode: func {
        # Whether or not the horizon line is shown. Used to decide to hide some HUD elements.
        # Values of previous loop are used. Hopefully it won't be too much of an issue.
        me.show_horizon = me.fpv_pitch <= 7.5 and me.fpv_pitch >= -7.5;

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
        } elsif (modes.main_ja == modes.AIMING) {
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
        me.update_mode();
        if (me.mode == HUD.MODE_STBY) return;

        me.fpv.update();
        me.compute_fpv_pitch_hdg(me.fpv.get_pos());

        me.horizon.update(me.roll * R2D, me.fpv_pitch, me.fpv_heading);
        var gs_pos = me.horizon.get_gs_pos();

        # Update positions of various groups.
        if (me.mode == HUD.MODE_AIM) {
            me.scales_roll_grp.setRotation(0);
        } else {
            me.scales_roll_grp.setRotation(-me.roll);
        }
        if (me.mode == HUD.MODE_FINAL_NAV or me.mode == HUD.MODE_FINAL_OPT) {
            me.scales_grp.setTranslation(gs_pos[0], me.fpv_pitch * 100 + gs_pos[1]);
            me.hdg_scale_grp.setTranslation(0, me.fpv_pitch * 100);
            me.alt_bars_grp.setTranslation(gs_pos[0], me.fpv_pitch * 100);
        } else {
            me.scales_grp.setTranslation(0, 0);
            me.hdg_scale_grp.setTranslation(0, 0);
            if (me.mode != HUD.MODE_AIM) {
                me.alt_bars_grp.setTranslation(0, me.fpv_pitch * 100);
            } else {
                me.alt_bars_grp.setTranslation(0, 0);
            }
        }

        me.heading.update(me.fpv_heading);
        me.speed.update();
        me.alt_scale.update(me.fpv_pitch);
        me.dig_alt.update(me.fpv.get_fpv_mode());
        me.rad_alt.update();
        me.text.update(me.fpv.get_fpv_mode());
        me.dist.update(me.fpv.get_fpv_mode());
        me.alt_bars.update(me.alt_scale.get_scale_factor(), me.show_horizon);
        me.gpw.update();
        me.targets.update(me.fpv.get_pos());
        me.reticle.update();
    },
};



### Backup sight (orange).
#
# Manual says it is a 'fixed illuminated pattern [...] activated by the knob RES'.
# Pattern itself is completely made up.
var BackupSight = {
    new: func(root) {
        var m = { parents: [BackupSight], };
        m.initialize(root);
        return m;
    },

    initialize: func(root) {
        var group = root.createChild("group");

        make_dot(group, 0, 0, opts.line_width*2);
        make_path(group).moveTo(-100,0).horizTo(-25).moveTo(100,0).horizTo(25);

        var line_start = 40*MIL2HUD;
        var line_end = 80*MIL2HUD;
        var grad = 10*MIL2HUD;
        var grad_w = 3*MIL2HUD;
        var line_bot_angle = math.pi/6;
        var arc_angle = line_bot_angle+0.1;
        var arc1_rad = 75*MIL2HUD;
        var arc2_rad = 100*MIL2HUD;

        var path = make_path(group)
            .moveTo(-line_start, 0).horizTo(-line_end)
            .moveTo(line_start, 0).horizTo(line_end)
            .moveTo(0, -line_start).vertTo(-line_end)
            .moveTo(-line_start, 0).arcSmallCWTo(line_start, line_start, 0, line_start, 0);

        for (var i=1; i<= 5; i+=1) {
            path.moveTo(-grad_w*i, grad*i).horizTo(grad_w*i);
        }
        path.moveTo(0, grad).vertTo(arc2_rad+grad);

        path.moveTo(arc1_rad*math.sin(arc_angle), arc1_rad*math.cos(arc_angle))
            .arcSmallCWTo(arc1_rad, arc1_rad, 0, -arc1_rad*math.sin(arc_angle), arc1_rad*math.cos(arc_angle));
        path.moveTo(arc2_rad*math.sin(arc_angle), arc2_rad*math.cos(arc_angle))
            .arcSmallCWTo(arc2_rad, arc2_rad, 0, -arc2_rad*math.sin(arc_angle), arc2_rad*math.cos(arc_angle));

        path.moveTo(line_start*math.sin(line_bot_angle), line_start*math.cos(line_bot_angle))
            .lineTo(arc2_rad*math.sin(line_bot_angle), arc2_rad*math.cos(line_bot_angle));
        path.moveTo(-line_start*math.sin(line_bot_angle), line_start*math.cos(line_bot_angle))
            .lineTo(-arc2_rad*math.sin(line_bot_angle), arc2_rad*math.cos(line_bot_angle));
    },
};
