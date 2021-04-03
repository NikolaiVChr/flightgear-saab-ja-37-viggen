var FALSE = 0;
var TRUE = 1;

var input = {
    flaps_setting:      "/controls/flight/flaps-up-position",
    wpn_sel_knob:       "/controls/armament/ground-panel/weapon-selector-knob",
    wpn_sel_switch:     "/controls/armament/ground-panel/weapon-selector-switch",
    wpn_number:         "/controls/armament/ground-panel/weapon-count",
    wpn_operational:    "/controls/armament/ground-panel/operational",
    safety_dist:        "/controls/armament/safety-distance",
    cm_loaded:          "/controls/armament/ground-panel/cm-pod-loaded",
    start_left:         "/controls/armament/ground-panel/start-left",
    swedish_labels:     "/ja37/effect/swedish-labels",
    tooltip_delay_msec: "/sim/mouse/tooltip-delay-msec",
    auto_ground_panel:  "/controls/armament/ground-panel/automatic-settings",
};

foreach (var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}



#### Ground panel logic

# Weapon selector knob positions
var WPN_SEL = {
    IR_RB: 0,
    AKAN: 1,
    AK_05: 2,
    RB05: 3,
    LYSB: 4,
    BOMB: 5,
    RB04: 6,
    ARAK: 7,
};


### Ground panel settings check

# Meta remark: this is supposed to represent the ground crew checking and
# correcting loadout and settings, not some aircraft computer logic.
# For instance, combining high and low drag bombs is reported as invalid,
# even if I the weapon computer is likely not able to tell the difference.

# Loadout, as an array of size 6. Same indices as in loadout.nas
var get_current_loadout = func {
    var res = [];
    setsize(res, 6);
    forindex (var i; res) {
        res[i] = pylons.get_pylon_load(i+1);
    }
}

# Error codes for the check function.
var SETTING_ERROR = {
    CORRECT: 0,         # Correct ground panel settings.
    WRONG_LOADOUT: 1,   # Invalid loadout, auto_correct skipped
    # The following errors can not occur with auto_correct=1
    # They are given in this priority order.
    WRONG_SELECTION: 2, # Incorrect weapon selection knob / switch position.
    WRONG_COUNT: 3,     # Incorrect weapon count knob position.
    WRONG_FLAPS: 4,     # Incorrect flaps lever position.
};

# Valid selector knob settings.
# For each weapon type, there is an array of acceptable settings.
# The first value is the 'most correct' one (e.g. for AKAN,
# both 'AKAN' and 'AKAN + RB 05' are valid, but the former is preferred).
var valid_knob_settings = {
    "M55": [WPN_SEL.AKAN, WPN_SEL.AK_05],
    "RB-05A": [WPN_SEL.RB05, WPN_SEL.AK_05],
    "M55+RB-05A": [WPN_SEL.AK_05],
    "RB-75": [WPN_SEL.RB05, WPN_SEL.AK_05],
    "M55+RB-75": [WPN_SEL.AK_05],
    "M71": [WPN_SEL.BOMB],
    "M71R": [WPN_SEL.BOMB],
    "RB-04E": [WPN_SEL.RB04],
    "RB-15F": [WPN_SEL.RB04],
    "M90": [WPN_SEL.RB04],
    "M70": [WPN_SEL.ARAK],
    "none": [WPN_SEL.IR_RB, "any"],
};

# Valid selector switch settings.
# If a weapon type is missing, the switch is irrelevant for this weapon.
var valid_switch_settings = {
    "RB-05A": FALSE,
    "M55+RB-05A": FALSE,
    "RB-75": TRUE,
    "M55+RB-75": TRUE,
    "M71": FALSE,
    "M71R": TRUE,
    "RB-04E": FALSE,
    "RB-15F": TRUE,
    "M90": TRUE,
};

# Weapon types for which -7deg flaps position is used.
# The -7deg flaps position is used precisely if a weapon of one of the
# following types is loaded under both wing pylons.
var flaps7_types = { "M55": 1, "M70": 1, };

# Check that the ground panel settings match a given loadout.
# If auto_correct is true, modify settings to make them correct, if possible.
# Returns an error code in SETTING_ERROR
# Incorrect settings which were corrected are not reported as error.
var check_settings = func(loadout, auto_correct=0, zealous_auto_correct=0) {
    # Compute weapon count
    var wpns = {};
    foreach (var type; loadout) {
        if (type == "") continue; # no load
        if (!contains(wpns, type)) wpns[type] = 0;
        wpns[type] += 1;
    }

    # Remove IR missiles from weapon count, as they are considered separately.
    # Do remember their number separately, however.
    var IR_count = 0;
    foreach (var type; ["RB-24", "RB-24J", "RB-74"]) {
        if (contains(wpns, type)) {
            IR_count += wpns[type];
            delete(wpns, type);
        }
    }

    # Weapon type string.
    var type = "";

    # To be valid, the loadout must contain only one weapon type (excluding IR missiles),
    # or one of the pairs AKAN + RB 05 or AKAN + RB 75.
    if (size(wpns) > 2) return SETTING_ERROR.WRONG_LOADOUT;
    elsif (size(wpns) == 2) {
        if (!contains(wpns, "M55")) return SETTING_ERROR.WRONG_LOADOUT;

        if (contains(wpns, "RB-05A")) {
            type = "M55+RB-05A";
        } elsif (contains(wpns, "RB-75")) {
            type = "M55+RB-75";
        } else {
            return SETTING_ERROR.WRONG_LOADOUT;
        }
    } elsif (size(wpns) == 1) {
        # This is a way to store the unique key of 'wpns' in 'type'.
        foreach(type; keys(wpns)) break;
    } else {
        type = "none";
    }

    # At this point, we know the loadout is correct,
    # we have calculated weapon count, and a string indicating the main weapon type.
    # Time to start checking and correcting the settings.

    # Check weapon selector knob setting.
    var sel_knob = input.wpn_sel_knob.getValue();
    var valid_settings = valid_knob_settings[type];
    var error = TRUE;
    foreach (var setting; valid_settings) {
        if (setting == "any" or setting == sel_knob) {
            error = FALSE;
            break;
        }
    }
    if (auto_correct) {
        if (error or zealous_auto_correct) {
            # Correct if an error occured. With zealous flag, select 'best'
            # setting even if previous setting was correct.
            input.wpn_sel_knob.setValue(valid_settings[0]);
        }
    } else {
        if (error) return SETTING_ERROR.WRONG_SELECTION;
    }

    # Check weapon selector switch setting.
    if (contains(valid_switch_settings, type)) {
        if (input.wpn_sel_switch.getBoolValue() != valid_switch_settings[type]) {
            if (auto_correct) {
                input.wpn_sel_switch.setBoolValue(valid_switch_settings[type]);
            } else {
                return SETTING_ERROR.WRONG_SELECTION;
            }
        }
    }

    # Check weapon count knob setting.
    # Weapon count ignores IR missiles, except if the selector knob is in IR-RB position.
    var count = 0;
    if (input.wpn_sel_knob.getValue() == WPN_SEL.IR_RB) {
        count = IR_count;
    }
    foreach (var wpn; keys(wpns)) count += wpns[wpn];
    # capped to 3
    count = math.min(count, 3);
    if (input.wpn_number.getValue() != count) {
        if (auto_correct) {
            input.wpn_number.setValue(count);
        } else {
            return SETTING_ERROR.WRONG_COUNT;
        }
    }

    # Check flaps position lever.
    # It should be -7deg if AKAN, ARAK, or KB pods are carried on both wing pylons, and -4deg otherwise.
    var flaps_desired_pos = contains(flaps7_types, loadout[0]) and contains(flaps7_types, loadout[2]);
    if (input.flaps_setting.getBoolValue() != flaps_desired_pos) {
        if (auto_correct) {
            input.flaps_setting.setBoolValue(flaps_desired_pos);
        } else {
            return SETTING_ERROR.WRONG_FLAPS;
        }
    }

    return SETTING_ERROR.CORRECT;
}



### Ground panel check timer.
# Checks are done with a 3sec delay, to avoid message spam while touching settings.

# Temporary override of auto_correct flag, set by queue_settings_check and read by run_settings_check.
var force_no_correct = FALSE;

# Settings check wrapper for error messages.
var run_settings_check = func {
    var auto_correct = input.auto_ground_panel.getBoolValue() and !force_no_correct;
    var error = check_settings(get_current_loadout(), auto_correct, TRUE);

    if (error == SETTING_ERROR.WRONG_LOADOUT) {
        screen.log.write("Invalid loadout! Weapons will not function correctly.", 1, 0, 0);
        screen.log.write("Consider using loadout presets in the Fuel and Payload dialog.", 1, 0, 0);
    } elsif (error == SETTING_ERROR.WRONG_SELECTION) {
        screen.log.write("Incorrect ground crew panel settings! Weapons will not function correctly.", 1, 0, 0);
        if (!force_no_correct) {
            # User is touching the ground crew panel, don't tell them to check it.
            screen.log.write("Check dialog AJS-37 > Ground Crew Panel, or enable the automatic ground crew settings option.", 1, 0, 0);
        }
    }
    # Ignore wrong count / flaps errors.
}

var settings_check_delay = 3;

var settings_check_timer = maketimer(settings_check_delay, run_settings_check);
settings_check_timer.singleShot = 1;

# Queue a ground panel settings check.
#
# Option:
# - force_no_correct: Disable automatic correction, even if the option is on
#                     (intended when a check is triggered by touching the ground crew panel).
var queue_settings_check = func (no_correct=0) {
    force_no_correct = no_correct;
    settings_check_timer.restart(settings_check_delay);
}


# Re-run settings check when the automatic settings option is enabled,
# provided access to the ground crew panel is allowed.
setlistener(input.auto_ground_panel, func (node) {
    if (node.getBoolValue() and ja37.reload_allowed()) {
        queue_settings_check();
    }
});



#### Ground crew panel canvas dialog


# Workaround bug in SVG parser (https://sourceforge.net/p/flightgear/codetickets/2569/ fixed as of 01/04/2021)
# Invert clockwise/counter-clockwise flag in all arcs.
var invert_arcs_dir = func (group) {
    foreach(var path; group.getChildrenOfType([canvas.Path])) {
        foreach(var cmd_node; path._node.getChildren("cmd")) {
            var cmd = cmd_node.getValue();
            if (cmd == canvas.Path.VG_SCWARC_TO_ABS)        cmd = canvas.Path.VG_SCCWARC_TO_ABS;
            elsif (cmd == canvas.Path.VG_SCWARC_TO_REL)     cmd = canvas.Path.VG_SCCWARC_TO_REL;
            elsif (cmd == canvas.Path.VG_SCCWARC_TO_ABS)    cmd = canvas.Path.VG_SCWARC_TO_ABS;
            elsif (cmd == canvas.Path.VG_SCCWARC_TO_REL)    cmd = canvas.Path.VG_SCWARC_TO_REL;
            elsif (cmd == canvas.Path.VG_LCWARC_TO_ABS)     cmd = canvas.Path.VG_LCCWARC_TO_ABS;
            elsif (cmd == canvas.Path.VG_LCWARC_TO_REL)     cmd = canvas.Path.VG_LCCWARC_TO_REL;
            elsif (cmd == canvas.Path.VG_LCCWARC_TO_ABS)    cmd = canvas.Path.VG_LCWARC_TO_ABS;
            elsif (cmd == canvas.Path.VG_LCCWARC_TO_REL)    cmd = canvas.Path.VG_LCWARC_TO_REL;
            cmd_node.setValue(cmd);
        }
    }
}

## Interaction with canvas elements.

# This class implements tooltips in canvas windows.
var CanvasTooltip = {
    # Initialisation of static members.
    init: func {
        me.tooltip_delay_sec_listener = setlistener(input.tooltip_delay_msec, func (n) {
            CanvasTooltip.tooltip_delay_sec = n.getValue() / 1000.0;
        }, 1, 0);

        # Timer for actually displaying the tooltip.
        # Remarks:
        # - This timer is shared by all instances of this class, on purpose.
        #   There is only one tooltip to actually display, and only the last object
        #   to use this timer is relevant.
        # - The timer is never stopped. If the cursor leaves areas with tooltips,
        #   then "update-hover" is called, removing the tooltip
        #   (this must be done by calling setup_root_tooltip_listener on the canvas root).
        #   Calling "tooltip-timeout" after this is not an issue".
        me.tooltip_timer = maketimer(me.tooltip_delay_sec, func { fgcommand("tooltip-timeout"); });
        me.tooltip_timer.singleShot = 1;
    },

    # Add tooltips to a list of canvas elements.
    # setup_root_tooltip_listener() must be called on the root element of this
    # canvas for tooltips to work properly.
    #
    # args: elts: array of canvas elements
    #       tooltip_id: unique identifier of the tooltip
    #       tooltip: tooltip content
    # returns an array of canvas event listeners, matching the argument 'elts'
    # (same size, and the ith listener is for the ith element).
    add_tooltip: func(elts, tooltip_id, tooltip) {
        var tooltip_listeners = [];
        setsize(tooltip_listeners, size(elts));

        forindex(var i; elts) {
            # Tooltip event listeners. This tries to replicate the behaviour of FG tooltips.
            tooltip_listeners[i] = elts[i].addEventListener("mousemove", func (event) {
                # Set the tooltip. This does not show it yet.
                fgcommand("set-tooltip", {
                    "tooltip-id": tooltip_id,
                    "label": tooltip,
                    "x": event.screenX,
                    # Inverted for some reason. This property is what is used in tooltip.nas, so using it is correct.
                    "y": getprop('/sim/startup/ysize') - event.screenY,
                });

                # Start the (global) timer to show the tooltip.
                CanvasTooltip.tooltip_timer.restart(CanvasTooltip.tooltip_delay_sec);

                # Stop event from going to the canvas root,
                # which has a second listener to fadeout the tooltip.
                event.stopPropagation();
            });
        }

        return tooltip_listeners;
    },

    # Listener for the canvas, to clear tooltips appropriately.
    setup_canvas_tooltip_listener: func(canvas) {
        canvas.addEventListener("mousemove", func(e) {
            fgcommand("update-hover");
        });
    },
};

CanvasTooltip.init();


# Knob animation. Controls: LMB/MMB and wheel.
# Unlike the SG knob animation, this does not take care of actually rotating the element.
var CanvasKnobAnim = {
    new: func(elt, prop, min, max, callback=nil, tooltip_id=nil, tooltip="") {
        var m = {
            parents: [CanvasKnobAnim],
            elt: elt,
            prop: prop,
            min: min,
            max: max,
            callback: callback,
            tooltip_id: tooltip_id,
            tooltip: tooltip,
        };
        m.init();
        return m;
    },

    init: func{
        me.delay_timer = maketimer(0.5, me, func { me.move(me.step); me.repeat_timer.restart(0.1); });
        me.delay_timer.singleShot = 1;
        me.repeat_timer = maketimer(0.1, me, func { me.move(me.step); });

        me.click_listener = me.elt.addEventListener("mousedown", func(e) {
            me.delay_timer.stop();
            me.repeat_timer.stop();
            if (e.button == 2) return;

            me.step = (e.button == 1) ? -1 : 1;
            me.move(me.step);
            me.delay_timer.start();
        });
        me.release_listener = me.elt.addEventListener("mouseup", func(e) {
            me.delay_timer.stop();
            me.repeat_timer.stop();
        });
        me.wheel_listener = me.elt.addEventListener("wheel", func(e) {
            if (e.deltaY < 0) me.move(-1);
            elsif (e.deltaY > 0) me.move(1);
        });

        if (me.tooltip_id != nil and size(me.tooltip) > 0) {
            CanvasTooltip.add_tooltip([me.elt], me.tooltip_id, me.tooltip);
        }
    },

    move: func(step) {
        me.prop.setValue(math.clamp(me.prop.getValue() + step, me.min, me.max));
        if (me.callback != nil) me.callback();
    },
};

# Switch animation. Two hot zones, to move up or down.
# The switch may have more than two positions.
var CanvasSwitchAnim = {
    new: func(elt_up, elt_down, prop, min, max, callback=nil, tooltip_id=nil, tooltip="") {
        var m = {
            parents: [CanvasSwitchAnim],
            elt_up: elt_up,
            elt_down: elt_down,
            prop: prop,
            min: min,
            max: max,
            callback: callback,
            tooltip_id: tooltip_id,
            tooltip: tooltip,
        };
        m.init();
        return m;
    },

    init: func {
        me.up_listener = me.elt_up.addEventListener("mousedown", func(e) {
            if (e.button == 0) me.move(1);
        });
        me.down_listener = me.elt_down.addEventListener("mousedown", func(e) {
            if (e.button == 0) me.move(-1);
        });

        if (me.tooltip_id != nil and size(me.tooltip) > 0) {
            CanvasTooltip.add_tooltip([me.elt_up, me.elt_down], me.tooltip_id, me.tooltip);
        }
    },

    move: func(step) {
        me.prop.setValue(math.clamp(me.prop.getValue() + step, me.min, me.max));
        if (me.callback != nil) me.callback();
    },
};


var Dialog = {
    canvas_opts: {
        name: "ground crew panel",
        size: [1280, 1024], # 2x MSAA, otherwise the arcs and rotated text look really ugly.
        view: [640, 512],
    },
    svg_file: "Aircraft/JA37/Nasal/payload/ground-crew-panel.svg",
    window: nil,
    listeners: {},

    ## Property listeners to animate canvas elements.

    make_knob_listener: func(elt, prop, factor, offset) {
        return setlistener(prop, func(node) {
            elt.setRotation((node.getValue() * factor + offset) * D2R);
        }, 1, 0);
    },

    make_two_pos_switch_listener: func(elt, prop) {
        return setlistener(prop, func(node) {
            var rot = node.getValue() ? 0 : math.pi;
            elt.setRotation(rot);
        }, 1, 0);
    },

    make_three_pos_switch_listener: func(elt_side, elt_center, prop, offset=0) {
        return setlistener(prop, func(node) {
            var val = node.getValue() - offset;
            if (val == 1) {
                elt_side.hide();
                elt_center.show();
            } else {
                elt_side.show();
                elt_center.hide();
                var rot = val ? 0 : math.pi;
                elt_side.setRotation(rot);
            }
        }, 1, 0);
    },

    setup_listeners: func {
        me.destroy_listeners();

        me.listeners.knob_sel = me.make_knob_listener(me.knob_sel, input.wpn_sel_knob, 30, -195);
        me.listeners.knob_num = me.make_knob_listener(me.knob_number, input.wpn_number, 30, -105);
        me.listeners.flaps_lever = me.make_two_pos_switch_listener(me.flaps_lever, input.flaps_setting);
        me.listeners.switch_op = me.make_three_pos_switch_listener(
            me.switch_op, me.switch_op_center, input.wpn_operational, -1);
        me.listeners.switch_dist = me.make_three_pos_switch_listener(
            me.switch_dist, me.switch_dist_center, input.safety_dist);
        me.listeners.switch_cm = me.make_two_pos_switch_listener(me.switch_cm, input.cm_loaded);
        me.listeners.switch_sel = me.make_two_pos_switch_listener(me.switch_sel, input.wpn_sel_switch);
        me.listeners.switch_side = me.make_two_pos_switch_listener(me.switch_side, input.start_left);

        me.listeners.swedish = setlistener(input.swedish_labels, func (node) {
            me.text_SE.setVisible(node.getBoolValue());
            me.text_EN.setVisible(!node.getBoolValue());
        }, 1, 0);
    },

    destroy_listeners: func {
        foreach(var key; keys(me.listeners)) {
            removelistener(me.listeners[key]);
            delete(me.listeners, key);
        }
    },

    ## Canvas event listeners, for interaction.

    setup_events_listeners: func {
        CanvasKnobAnim.new(
            me.knob_sel_click, input.wpn_sel_knob, 0, 7,
            func { queue_settings_check(TRUE); },
            "knob_sel", "Loaded weapon type (not implemented)"
        );
        CanvasKnobAnim.new(
            me.knob_number_click, input.wpn_number, 0, 3, nil,
            "knob_num", "Number of loaded weapons (not implemented)"
        );
        CanvasSwitchAnim.new(
            me.flaps_lever_click_up, me.flaps_lever_click_down, input.flaps_setting, 0, 1, nil,
            "flaps_lever", "Flaps position upper limit"
        );
        CanvasSwitchAnim.new(
            me.switch_op_click_up, me.switch_op_click_down, input.wpn_operational, -1, 1, nil,
            "switch_op", "Training/operational weapons (not implemented)"
        );
        CanvasSwitchAnim.new(
            me.switch_dist_click_up, me.switch_dist_click_down, input.safety_dist, 0, 2, nil,
            "switch_dist", "Safety distance"
        );
        CanvasSwitchAnim.new(
            me.switch_cm_click_up, me.switch_cm_click_down, input.cm_loaded, 0, 1, nil,
            "switch_cm", "Flares/chaff/ECM pod loaded (not implemented)"
        );
        CanvasSwitchAnim.new(
            me.switch_sel_click_up, me.switch_sel_click_down, input.wpn_sel_switch, 0, 1,
            func { queue_settings_check(TRUE); },
            "switch_sel", "Loaded weapon type (not implemented)"
        );
        CanvasSwitchAnim.new(
            me.switch_side_click_up, me.switch_side_click_down, input.start_left, 0, 1, nil,
            "switch_side", "Firing sequence starting side"
        );

        CanvasTooltip.setup_canvas_tooltip_listener(me.canvas);

        me.canvas.addEventListener("keydown", func (event) {
            if (event.key == "Escape") Dialog.close();
        });
    },

    ## Lookup Canvas elements from the SVG file

    elt_keys: [
        "text_SE", "text_EN", "knob_number", "knob_number_click", "knob_sel", "knob_sel_click",
        "flaps_lever", "flaps_lever_click_up", "flaps_lever_click_down",
        "switch_op", "switch_op_center", "switch_op_click_up", "switch_op_click_down",
        "switch_dist", "switch_dist_center", "switch_dist_click_up", "switch_dist_click_down",
        "switch_cm", "switch_cm_click_up", "switch_cm_click_down",
        "switch_sel", "switch_sel_click_up", "switch_sel_click_down",
        "switch_side", "switch_side_click_up", "switch_side_click_down",
    ],

    lookup_elements: func {
        # Lookup animated canvas elements, loaded from SVG.
        foreach(var key; me.elt_keys) {
            me[key] = me.root.getElementById(key);
        }

        # Centers for rotation animations.
        me.knob_number.setCenter(258,182);
        me.knob_sel.setCenter(492,182);
        me.flaps_lever.setCenter(115,256);
        me.switch_op.setCenter(226, 356);
        me.switch_dist.setCenter(340, 356);
        me.switch_cm.setCenter(428, 356);
        me.switch_sel.setCenter(512, 356);
        me.switch_side.setCenter(582, 356);
    },

    open: func {
        if (me.window != nil) {
            me.window.setFocus();
            return;
        }

        if (!ja37.reload_allowed("Please land and stop in order to change ground crew settings.")) return;

        # Create our own canvas to set custom options.
        me.canvas = canvas.new(me.canvas_opts);
        me.canvas.setColorBackground(0.25, 0.25, 0.25, 1);
        me.root = me.canvas.createGroup("root");
        canvas.parsesvg(me.root, me.svg_file);

        # Work around SVG parser bug
        if (!getprop("/ja37/supported/canvas-arcs")) invert_arcs_dir(me.root);

        me.lookup_elements();
        me.setup_listeners();
        me.setup_events_listeners();

        # Create window
        me.window = canvas.Window.new([640,512], "Ground crew panel");
        # Hijack window destructor, that's the only way to add a close callback that I know of.
        me.window.del = func {
            Dialog.on_close();
            # Call parent method
            call(canvas.Window.del, [], me);
        };
        me.window.setTitle("Ground crew panel");
        me.window.setCanvas(me.canvas);
    },

    on_close: func {
        # Window destructor takes care of deleting the canvas.
        me.destroy_listeners();
        me.window = nil;
        me.canvas = nil;
    },

    close: func() {
        if (me.window == nil) return;
        me.window.del();
    },
};
