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
};

foreach (var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}



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
    new: func(elt, prop, min, max, tooltip_id=nil, tooltip="") {
        var m = {
            parents: [CanvasKnobAnim],
            elt: elt,
            prop: prop,
            min: min,
            max: max,
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
    },
};

# Switch animation. Two hot zones, to move up or down.
# The switch may have more than two positions.
var CanvasSwitchAnim = {
    new: func(elt_up, elt_down, prop, min, max, tooltip_id=nil, tooltip="") {
        var m = {
            parents: [CanvasSwitchAnim],
            elt_up: elt_up,
            elt_down: elt_down,
            prop: prop,
            min: min,
            max: max,
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
            "knob_sel", "Loaded weapon type (not implemented)"
        );
        CanvasKnobAnim.new(
            me.knob_number_click, input.wpn_number, 0, 3,
            "knob_num", "Number of loaded weapons (not implemented)"
        );
        CanvasSwitchAnim.new(
            me.flaps_lever_click_up, me.flaps_lever_click_down, input.flaps_setting, 0, 1,
            "flaps_lever", "Flaps position upper limit"
        );
        CanvasSwitchAnim.new(
            me.switch_op_click_up, me.switch_op_click_down, input.wpn_operational, -1, 1,
            "switch_op", "Training/operational weapons (not implemented)"
        );
        CanvasSwitchAnim.new(
            me.switch_dist_click_up, me.switch_dist_click_down, input.safety_dist, 0, 2,
            "switch_dist", "Safety distance"
        );
        CanvasSwitchAnim.new(
            me.switch_cm_click_up, me.switch_cm_click_down, input.cm_loaded, 0, 1,
            "switch_cm", "Flares/chaff/ECM pod loaded (not implemented)"
        );
        CanvasSwitchAnim.new(
            me.switch_sel_click_up, me.switch_sel_click_down, input.wpn_sel_switch, 0, 1,
            "switch_sel", "Loaded weapon type (not implemented)"
        );
        CanvasSwitchAnim.new(
            me.switch_side_click_up, me.switch_side_click_down, input.start_left, 0, 1,
            "switch_side", "Firing sequence starting side (not implemented)"
        );

        CanvasTooltip.setup_canvas_tooltip_listener(me.canvas);
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
