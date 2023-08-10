#### Radio buttons logic for 3D model

var TRUE = 1;
var FALSE = 0;


# Controls an array of button boolean properties, ensuring that at most one of them is true at a time.
# An additional control property indicates the index of the true property (-1 if none).
# Both the button and control properties can be written, with the expected effect.
# The value of the control property is used to initialise all button properties.
var RadioButtons = {
    # Args:
    # - button_props:
    #   * Either an array of properties/property paths corresponding to the buttons.
    #     In this case values of 'control_prop' refer to the index in this array.
    #
    #   * Or a single property/property path, in which case the button properties are
    #     button_props[0] .. button_props[n_buttons-1]
    #     If button_props already has an index, say button_props[i],
    #     then it is used as an offset, i.e. the button properties are
    #     button_props[i] .. button_props[i+n_buttons-1]
    #     In this case values of 'control_prop' refer to property indices,
    #     i.e. will range from i to i+n_buttons-1 in the last example.
    #
    # - control_prop: The control property or property path.
    # - n_buttons: The number of button properties, only used if button_props is a single property.
    #              (if button_props is an array, the size of this array is used instead).
    new: func(button_props, control_prop, n_buttons=nil) {
        var b = { parents: [RadioButtons], };
        b.init(button_props, control_prop, n_buttons);
        return b;
    },

    init: func(button_props, control_prop, n_buttons) {
        me.control_prop = utils.ensure_prop(control_prop);

        if (typeof(button_props) == "vector") {
            me.n_buttons = size(button_props);
            me.control_prop_offset = 0;
            me.button_props = [];
            setsize(me.button_props, me.n_buttons);
            forindex (var i; me.button_props) me.button_props[i] = utils.ensure_prop(button_props[i]);
        } else {
            me.n_buttons = n_buttons;
            button_props = utils.ensure_prop(button_props);
            var parent = button_props.getParent();
            var name = button_props.getName();
            me.control_prop_offset = button_props.getIndex();
            me.button_props = [];
            setsize(me.button_props, me.n_buttons);
            forindex (var i; me.button_props) {
                me.button_props[i] = parent.getChild(name, i+me.control_prop_offset, 1);
            }
        }

        foreach (var button; me.button_props) button.setBoolValue(FALSE);
        me.current_button = -1;

        # Property to break callbacks triggering further callbacks.
        me.inhibit_callback = FALSE;


        # Setup all the listeners
        me.button_listeners = [];
        setsize(me.button_listeners, me.n_buttons);
        forindex (var i; me.button_listeners) {
            me.button_listeners[i] = me.make_button_listener(i);
        }

        me.control_listener = setlistener(me.control_prop, func (node) {
            me.control_callback(node.getValue());
        }, 0, 0);

        # Trigger callback to set initial state
        var val = int(me.control_prop.getValue());
        if (val == nil) val = -1;
        me.control_callback(val);
    },

    del: func {
        foreach (var l; me.button_listeners) removelistener(l);
        removelistener(me.control_listener);
    },

    make_button_listener: func(idx) {
        return setlistener(me.button_props[idx], func (node) {
            me.button_callback(idx, node.getValue());
        }, 0, 0);
    },

    control_callback: func(val) {
        if (me.inhibit_callback) return;

        # Remove offset, normalise to -1 if not in range.
        var idx = val - me.control_prop_offset;
        if (idx < 0 or idx >= me.n_buttons) idx = -1;

        if (idx == me.current_button) return;

        me.inhibit_callback = TRUE;

        # Release old button if any
        if (me.current_button >= 0) me.button_props[me.current_button].setBoolValue(FALSE);
        me.current_button = idx;
        # Press new button
        if (idx >= 0) me.button_props[val].setBoolValue(TRUE);

        # Correct control property to -1 if needed.
        if (idx == -1 and val != -1) me.control_prop.setValue(-1);

        me.inhibit_callback = FALSE;
    },

    button_callback: func(idx, val) {
        if (me.inhibit_callback) return;

        # Button unchanged
        if (val and idx == me.current_button) return;
        if (!val and idx != me.current_button) return;

        me.inhibit_callback = TRUE;
        if (val) {
            # New button pressed. Release old one and update control property.
            if (me.current_button >= 0) me.button_props[me.current_button].setBoolValue(FALSE);
            me.current_button = idx;
            me.control_prop.setValue(idx + me.control_prop_offset);
        } else {
            # Current button released. Set control property to -1.
            me.current_button = -1;
            me.control_prop.setValue(-1);
        }
        me.inhibit_callback = FALSE;
    },

    set_button: func(idx) {
        me.control_prop.setValue(idx);
    },
};
