var TRUE = 1;
var FALSE = 0;

var input = {
    radio_mode:         "instrumentation/radio/mode",
    freq_sel_10mhz:     "instrumentation/radio/frequency-selector/frequency-10mhz",
    freq_sel_1mhz:      "instrumentation/radio/frequency-selector/frequency-1mhz",
    freq_sel_100khz:    "instrumentation/radio/frequency-selector/frequency-100khz",
    freq_sel_1khz:      "instrumentation/radio/frequency-selector/frequency-1khz",
};

foreach (var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}


# Convert a string to a prop. Do nothing if the input is not a string.
var ensure_prop = func(path) {
    if (typeof(path) == "scalar") return props.globals.getNode(path, 1);
    else return path;
}



#### API for comm radio frequency properties.

### Interface to set frequency for a comm radio.
#
# Takes care of
# - validating the frequency (band and separation checks)
# - updating the 'uhf' property, in turned used by JSBSim for transmission power.
var comm_radio = {
    # Arguments:
    # - path:   Property or property path to the radio, typically "instrumentation/comm[i]".
    # - vhf:    A hash {min, max, sep} indicating VHF band parameters
    #           (min/max frequencies inclusive, and separation, all KHz).
    #           Can be nil if the VHF band is not supported.
    # - uhf:    Same as 'vhf' for the UHF band.
    new: func(node, vhf, uhf) {
        var r = { parents: [comm_radio], vhf: vhf, uhf: uhf, };
        r.node = ensure_prop(node);
        r.uhf_node = r.node.getNode("uhf", 1);
        r.freq_node = r.node.getNode("frequencies/selected-mhz", 1);
        return r;
    },

    # Test if frequency is correct for a band.
    # - freq: frequency in KHz
    # - band: band object or nil, cf. vhf/uhf in new().
    is_in_band: func(freq, band) {
        if (band == nil) return FALSE;
        if (freq < band.min or freq > band.max) return FALSE;
        return math.mod(freq, band.sep) == 0;
    },

    is_VHF: func(freq) { return me.is_in_band(freq, me.vhf); },
    is_UHF: func(freq) { return me.is_in_band(freq, me.uhf); },

    is_valid_freq: func(freq) { return me.is_VHF(freq) or me.is_UHF(freq); },

    set_freq: func(freq) {
        if (!me.is_valid_freq(freq)) {
            me.freq_node.setValue(-1);
            return;
        }

        me.freq_node.setValue(freq/1000.0);
        me.uhf_node.setValue(me.is_UHF(freq));
    }
};


### The radios for each variant.

if (variant.JA) {
    # FR28 tranciever for FR29 main radio
    var fr28 = comm_radio.new(
        "instrumentation/comm[0]",
        # Values from JA37D SFI chap 19
        {min: 103000, max:159975, sep: 25},
        {min: 225000, max:399975, sep: 25});
    # FR31 secondary radio
    var fr31 = comm_radio.new(
        "instrumentation/comm[1]",
        {min: 104000, max:161975, sep: 25},
        {min: 223000, max:407975, sep: 25});
} else {
    # FR22 main radio
    var fr22 = comm_radio.new(
        "instrumentation/comm[0]",
        {min: 103000, max:155975, sep: 25},     # VHF stops at 155.975MHz, not a typo
        {min: 225000, max:399950, sep: 50});
    # FR24 backup radio
    var fr24 = comm_radio.new(
        "instrumentation/comm[1]",
        {min: 118000, max:136975, sep: 25},     # Standard air band. Made up: FR24 only uses fixed channels anyway.
        nil);
}



#### Radio buttons system for 3D model
#
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
        var b = { parents: [radio_buttons], };
        b.init(button_props, control_prop, n_buttons);
        return b;
    },

    init: func(button_props, control_prop, n_buttons) {
        me.control_prop = ensure_prop(control_prop);

        if (typeof(button_props) == "vector") {
            me.n_buttons = size(button_props);
            me.control_prop_offset = 0;
            me.button_props = [];
            setsize(me.button_props, me.n_buttons);
            forindex (var i; me.button_props) me.button_props[i] = ensure_prop(button_props[i]);
        } else {
            me.n_buttons = n_buttons;
            button_props = ensure_prop(button_props);
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




# FR29 / FR22 mode knob
var MODE = {
    NORM_LARM: 0,
    NORM: 1,
    E: 2,
    F: 3,
    G: 4,
    H: 5,
    M: 6,
    L: 7,
};

# Special channels
var channels = {
    E: 0,       # Don't know what these should be
    F: 0,
    G: 0,
    H: 121500,  # guard
};


### Frequency update functions.

if (variant.AJS) {
    # FR22 frequency is controlled by the FR22 channel and frequency panels.
    # Currently only the latter exists.
    var update_fr22_freq = func {
        fr22.set_freq(
            input.freq_sel_10mhz.getValue() * 10000
            + input.freq_sel_1mhz.getValue() * 1000
            + input.freq_sel_100khz.getValue() * 100
            + input.freq_sel_1khz.getValue());
    }

    setlistener(input.freq_sel_10mhz, update_fr22_freq, 0, 0);
    setlistener(input.freq_sel_1mhz, update_fr22_freq, 0, 0);
    setlistener(input.freq_sel_100khz, update_fr22_freq, 0, 0);
    setlistener(input.freq_sel_1khz, update_fr22_freq, 0, 0);
    update_fr22_freq();

    # FR24 frequency is controlled by the FR24 mode knob
    var update_fr24_freq = func {
        var mode = input.radio_mode.getValue();
        var freq = 0;

        if (mode == MODE.NORM_LARM) {
            freq = channels.H;
        } else {
            foreach (var chan; ["E", "F", "G", "H"]) {
                if (mode == MODE[chan]) freq = channels[chan];
            }
        }

        fr24.set_freq(freq);
    }

    setlistener(input.radio_mode, update_fr24_freq, 1, 0);
}
