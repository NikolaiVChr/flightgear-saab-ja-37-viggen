var TRUE = 1;
var FALSE = 0;

var input = {
    radio_mode:         "instrumentation/radio/mode",
    freq_sel_10mhz:     "instrumentation/fr22/frequency-10mhz",
    freq_sel_1mhz:      "instrumentation/fr22/frequency-1mhz",
    freq_sel_100khz:    "instrumentation/fr22/frequency-100khz",
    freq_sel_1khz:      "instrumentation/fr22/frequency-1khz",
    fr22_button:        "instrumentation/fr22/button-selected",
    fr22_group:         "instrumentation/fr22/group",
    fr22_group_dig1:    "instrumentation/fr22/group-digit[1]",
    fr22_group_dig10:   "instrumentation/fr22/group-digit[0]",
    fr22_base:          "instrumentation/fr22/base",
    fr22_base_gen:      "instrumentation/fr22/base-gen",
    fr22_base_knob:     "instrumentation/fr22/base-knob",
    fr22_base_dig1:     "instrumentation/fr22/base-digit[1]",
    fr22_base_dig10:    "instrumentation/fr22/base-digit[0]",
    kv1_freq:           "instrumentation/kv1/button-mhz",
    kv1_group:          "instrumentation/kv1/button-nr",
    kv1_base:           "instrumentation/kv1/button-bas",
    kv1_button:         "instrumentation/kv1/button-selected",
    kv3_channel:        "instrumentation/datalink/channel",
    kv3_ident:          "instrumentation/datalink/ident",
    preset_file:        "ja37/radio/channels-file",
    preset_group_file:  "ja37/radio/group-channels-file",
    preset_base_file:   "ja37/radio/base-channels-file",
    gui_file:           "sim/gui/dialogs/comm-channels/channels-file",
    gui_group_file:     "sim/gui/dialogs/comm-channels/group-channels-file",
    gui_base_file:      "sim/gui/dialogs/comm-channels/base-channels-file",
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
        {min: 110000, max:147000, sep: 50},     # src: Militär flygradio 1916-1990, Lars V Larsson
        nil);
}



#### Channels preset file parser

## Character type functions.

var is_digit = func(c) {
    # nasal characters are numbers (ASCII code)...
    # I don't know a way to make this more readable.
    return c >= 48 and c <= 57;
}

# Space or tab
var is_whitespace = func(c) {
    return c == 32 or c == 9;
}


var Channels = {
    ## Channels table
    channels: {
        # Global fixed channels.
        # Randomly chosen, no idea what were the historical channels.
        E: 127000,
        F: 118500,
        G: 125500,
        # Guard, don't change this one.
        H: 121500,
    },


    ## Channel names

    # Suffixes for airbase channel names
    base_channel_names: ["A", "B", "C", "C2", "D"],
    # Global configurable channels
    special_channels: ["M", "L", "S1", "S2", "S3"],

    # ASCII characters for prefixes
    base_prefix: 66,    # 'B'
    group_prefix: 78,   # 'N'

    # Test if 'str' is a valid group channel name. Also include the special channels.
    is_group_channel: func(str) {
        foreach (var channel; me.special_channels) {
            if (str == channel) return TRUE;
        }

        if (size(str) != 4) return FALSE;
        if (str[0] != me.group_prefix) return FALSE;
        for (var i=1; i<4; i+=1) {
            if (!is_digit(str[i])) return FALSE;
        }
        return TRUE;
    },

    # Test if 'str' is a valid airbase channel name.
    is_base_channel: func(str) {
        if (size(str) != 4 and size(str) != 5) return FALSE;
        if (str[0] != me.base_prefix) return FALSE;
        for (var i=1; i<3; i+=1) {
            if (!is_digit(str[i])) return FALSE;
        }

        var suffix = substr(str, 3);
        foreach (var channel; me.base_channel_names) {
            if (suffix == channel) return TRUE;
        }
        return FALSE;
    },

    # Test if 'str' is an airbase or group name, which should be silently ignored
    # in the radio config file (used to add 'comments' for airbases or groups).
    is_comment_key: func(str) {
        return size(str) == 3
            and (str[0] == me.group_prefix or str[0] == me.base_prefix)
            and is_digit(str[1]) and is_digit(str[2]);
    },


    ## Parser

    # Parse a line, extract key (first whitespace separated token) and value (rest of line).
    # Comments starting with '#' are allowed.
    # Returns nil if the line is blank, [key,val] otherwise.
    # 'key' is a non-empty string without whitespace.
    # 'val' is a possibly empty string with whitespace stripped at both ends.
    parse_key_val: func(line) {
        # Strip comments
        var comment = find("#", line);
        if (comment >= 0) line = substr(line, 0, comment);
        var len = size(line);

        # Start of key
        var key_s = 0;
        while (key_s < len and is_whitespace(line[key_s])) key_s += 1;
        if (key_s >= len) return nil;
        # End of key
        var key_e = key_s;
        while (key_e < len and !is_whitespace(line[key_e])) key_e += 1;
        var key = substr(line, key_s, key_e-key_s);

        # Start of value
        var val_s = key_e;
        while (val_s < len and is_whitespace(line[val_s])) val_s += 1;
        if (val_s >= len) return [key, ""];
        # End of value
        var val_e = len;
        while (is_whitespace(line[val_e-1])) val_e -= 1;
        var val = substr(line, val_s, val_e-val_s);

        return [key,val];
    },

    # Parse a frequency string, return its value in KHz, or nil if it is invalid.
    # Frequencies are rounded to the nearest KHz.
    parse_freq: func(str) {
        var f = num(str);
        if (f == nil) return nil;
        else return math.round(f * 1000.0);
    },

    # Clear channels table
    reset_channels: func(reset_group_channels=1, reset_base_channels=1) {
        foreach (var channel; keys(me.channels)) {
            if ((reset_group_channels and me.is_group_channel(channel))
                or (reset_base_channels and me.is_base_channel(channel))) {
                delete(me.channels, channel);
            }
        }
    },

    # Load a radio channels configuration file.
    read_file: func(path, load_group_channels=1, load_base_channels=1) {
        var file = nil;
        call(func { file = io.open(path, "r"); }, nil, nil, nil, var err = []);
        if (size(err)) {
            debug.printerror(err);
            printf("Failed to load radio channels file: %s\n", path);
            if (file != nil) io.close(file);
            return;
        }
        printf("Reading radio channels file %s\n", path);

        # Memorize loaded file paths, for GUI only.
        var short_path = path;
        if (size(short_path) > 50) {
            short_path = "... "~substr(short_path, size(short_path)-46);
        }
        if (load_group_channels and load_base_channels) {
            input.gui_file.setValue(short_path);
            input.gui_group_file.clearValue();
            input.gui_base_file.clearValue();
        } elsif (load_group_channels) {
            input.gui_group_file.setValue(short_path);
            if (input.gui_base_file.getValue() == nil and input.gui_file.getValue() != nil) {
                input.gui_base_file.setValue(input.gui_file.getValue());
            }
            input.gui_file.clearValue();
        } elsif (load_base_channels) {
            input.gui_base_file.setValue(short_path);
            if (input.gui_group_file.getValue() == nil and input.gui_file.getValue() != nil) {
                input.gui_group_file.setValue(input.gui_file.getValue());
            }
            input.gui_file.clearValue();
        }


        me.reset_channels(load_group_channels, load_base_channels);

        # Variables for me.parser_log
        var line_no = 0;

        while ((var line = io.readln(file)) != nil) {
            # Extract key and value from line
            line_no += 1;
            var res = me.parse_key_val(line);
            if (res == nil) continue;

            # 'Comment' key, skip
            if (me.is_comment_key(res[0])) continue;

            var is_group = me.is_group_channel(res[0]);
            var is_base = me.is_base_channel(res[0]);

            # Invalid channel name
            if (!is_group and !is_base) {
                printf("%s:%d: Warning: Ignoring unexpected channel name: %s", path, line_no, res[0]);
                continue;
            }
            # Skipped channel type.
            if ((is_group and !load_group_channels) or (is_base and !load_base_channels)) {
                printf("%s:%d: Skipping %s channel %s (only loading %s channels)",
                       path, line_no, is_group ? "group" : "base", res[0], is_group ? "base" : "group");
                continue;
            }
            # Warnings for redefined channels.
            if (contains(me.channels, res[0])) {
                printf("%s:%d: Warning: Redefinition of channel %s", path, line_no, res[0]);
            }
            # Parse and assign new frequency.
            var freq = me.parse_freq(res[1]);
            if (freq == nil) {
                printf("%s:%d: Warning: Ignoring invalid frequency: %s", path, line_no, res[1]);
                continue;
            }
            me.channels[res[0]] = freq;
        }

        io.close(file);
    },

    read_group_file: func(path) {
        me.read_file(path:path, load_base_channels:0);
    },

    read_base_file: func(path) {
        me.read_file(path:path, load_group_channels:0);
    },

    ## Channel access functions

    get: func(channel) {
        if (contains(me.channels, channel)) return me.channels[channel];
        else return 0;
    },

    get_group: func(channel) {
        return me.get("N"~channel);
    },

    get_base: func(channel) {
        return me.get("B"~channel);
    },

    guard: func() {
        return me.get("H");
    },
};



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
        var b = { parents: [RadioButtons], };
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


if (variant.AJS) {
    RadioButtons.new("instrumentation/fr22/button", input.fr22_button, 20);
} else {
    RadioButtons.new([input.kv1_freq, input.kv1_group, input.kv1_base], input.kv1_button);
}



#### JA radio selector displays logic

### Keypad shared between several input controllers.
#
# Each controller can take_focus(), after which calls to Keypad.button()
# are redirected to this controller button() method, until it calls Keypad.release(),
# or another controller calls take_focus(),
# When a controller looses focus, this controller on_focus_lost() method is called.
#
# Arg: no_focus_callback: if non nil, called instead of controller.button() when no controller has focus.
var Keypad = {
    new: func(no_focus_callback=nil) {
        var k = { parents: [Keypad], };
        k.controller = nil;
        k.no_focus_callback = no_focus_callback;
        return k;
    },

    take_focus: func(c) {
        if (me.controller != nil) {
            me.controller.on_focus_lost();
        }
        me.controller = c;
    },

    release: func {
        me.controller = nil;
    },

    button: func(n) {
        if (me.controller != nil) me.controller.button(n);
        elsif (me.no_focus_callback != nil) me.no_focus_callback(n);
    },
};

var InputScreen = {
    # Arguments:
    # - digit_base_prop, n_digits: specify the properties used to display digits.
    #   The index of digit_base_prop if any is dropped, and the digit properties become
    #   digit_base_prop[0 to n_digits-1]
    # - keypad: keypad object used to input on this screen.
    # - digit_offset, blank, waiting, error: values to assign to the digit properties
    #   for the various symbols.
    # - input_callback: called on the array of values whenever a new full, valid input is done.
    # - validate (optional): called on the array of values for each new partial input.
    # - edit_last (default false): if true, pressing a button when input is complete will edit the last symbol.
    new: func(digit_base_prop, n_digits, keypad,
              digit_offset, blank, waiting, error,
              input_callback, validate=nil, edit_last=0) {
        var s = {
            parents: [InputScreen],
            digit_base_prop: digit_base_prop,
            n_digits: n_digits,
            keypad: keypad,
            digit_offset: digit_offset,
            blank: blank,
            waiting: waiting,
            error: error,
            input_callback: input_callback,
            validate: validate,
            edit_last: edit_last,
        };
        s.init();
        return s;
    },

    init: func {
        me.focused = FALSE;

        # Initialize digit properties
        me.digit_base_prop = ensure_prop(me.digit_base_prop);
        var parent_prop = me.digit_base_prop.getParent();
        var prop_name = me.digit_base_prop.getName();
        me.digits = [];
        setsize(me.digits, me.n_digits);
        forindex (var i; me.digits) {
            me.digits[i] = parent_prop.getChild(prop_name, i, 1);
            me.digits[i].setValue(me.blank);
        }

        me.last_input = [];
        setsize(me.last_input, me.n_digits);
        forindex (var i; me.last_input) {
            me.last_input[i] = me.blank;
        }

        me.current_input = [];
        me.pos = 0;

        me.blink_timer = maketimer(me.blink_period, me, me.blink);
        me.blink_timer.simulatedTime = TRUE;

        me.start_blink_timer = maketimer(me.blink_delay, me, me.start_blink);
        me.start_blink_timer.simulatedTime = TRUE;
        me.start_blink_timer.singleShot = TRUE;
    },

    # Button press handling
    button: func(n) {
        if (me.pos >= me.n_digits) return;

        # Reset blinking timer
        if (me.focused) me.queue_blink();

        # Check input
        append(me.current_input, n);
        if (me.validate != nil and !me.validate(me.current_input)) {
            # Release focus on error.
            me.release_focus();
            # Append error symbol (must be after release_focus(), otherwise the symbol is overwritten).
            me.digits[me.pos].setValue(me.error);
            # Remove erronous digit from current input, so that it can be corrected later.
            pop(me.current_input);
            return;
        }

        # Update screen
        me.digits[me.pos].setValue(n+me.digit_offset);

        me.pos += 1;
        if (me.pos >= me.n_digits) {
            # End of input, and valid. Remember it, and call input_callback.
            forindex (var i; me.current_input) {
                me.last_input[i] = me.current_input[i];
            }
            me.input_callback(me.last_input);
            me.release_focus();

            if (me.edit_last) {
                # Get ready to edit the last digit on the next button press.
                pop(me.current_input);
                me.pos = me.n_digits - 1;
            }
        }
    },

    take_focus: func {
        me.keypad.take_focus(me);
        me.focused = TRUE;
    },

    release_focus: func {
        me.stop_blink();
        if (!me.focused) return;
        me.keypad.release();
        me.focused = FALSE;
    },

    # Clear field and take focus
    clear: func {
        # First call take_focus, because it will call reset() if we already had focus.
        me.take_focus();

        me.current_input = [];
        me.pos = 0;
        foreach (var dig; me.digits) dig.setValue(me.blank);

        me.queue_blink();
    },

    # Reset to last programmed value
    reset: func {
        me.release_focus();

        # Restore last input on screen
        forindex (var i; me.last_input) {
            me.digits[i].setValue(me.last_input[i]);
        }

        if (me.edit_last) {
            # get ready to edit last digit
            setsize(me.current_input, me.n_digits-1);
            forindex (var i; me.current_input) {
                me.current_input[i] = me.last_input[i];
            }
            me.pos = me.n_digits-1;
        } else {
            # no edit possible until clearing
            me.pos = me.n_digits;
        }
    },

    on_focus_lost: func {
        me.focused = FALSE;
        me.reset();
    },

    # Blinking when waiting for input.
    blink_period: 0.5,  # Blinking
    blink_delay: 9,     # Delay before blinking starts.

    # Set any empty position to minus (if 'b' is true) or blank (if 'b' is false).
    set_blink: func(b) {
        var symbol = b ? me.waiting : me.blank;
        for (var i=me.pos; i<me.n_digits; i+=1) {
            me.digits[i].setValue(symbol);
        }
    },

    blink: func {
        me.last_blink = !me.last_blink;
        me.set_blink(me.last_blink);
    },

    start_blink: func {
        me.last_blink = FALSE;
        me.blink();
        me.blink_timer.start();
    },

    _stop_blink: func {
        me.blink_timer.stop();
        me.set_blink(FALSE);
    },

    stop_blink: func {
        me._stop_blink();
        me.start_blink_timer.stop();
    },

    queue_blink: func {
        me._stop_blink();
        me.start_blink_timer.restart(me.blink_delay);
    },
};


if (variant.JA) {
    ### KV1 channel selector logic

    ## current frequency / channels
    var kv1_freq = 0;
    var kv1_group = "";
    var kv1_base = "";

    ## Convert input (vector of digits) to frequency or channel.

    # Frequencies

    var kv1_freq_input_validate = func(digits) {
        if (size(digits) == 5) {
            # Last digit is limited for 25KHz separation.
            if (digits[4] != 0 and digits[4] != 2 and digits[4] != 5 and digits[4] != 7) return FALSE;
        }

        # Compute (partial) frequency
        var freq = 0;
        var pow = 100000;
        foreach (var digit; digits) {
            freq += pow * digit;
            pow /= 10;
        }
        # Maximum frequency that can be input with the current partial input (actually 1 more than the max).
        var max_freq = freq + pow*10;

        # Check that it is in range.
        if (freq <= fr28.vhf.max and max_freq > fr28.vhf.min) return TRUE;
        if (freq <= fr28.uhf.max and max_freq > fr28.uhf.min) return TRUE;
        return FALSE;
    }

    var kv1_input_to_freq = func(digits) {
        var freq = 0;
        # Sum digits. Leftmost is 100MHz
        var pow = 100000;
        foreach (var digit; digits) {
            freq += pow * digit;
            pow /= 10;
        }
        # Convert to 25KHz separation
        if (digits[4] == 2 or digits[4] == 7) {
            freq += 5;
        }
        return freq;
    }

    var kv1_set_new_freq = func(digits) {
        kv1_freq = kv1_input_to_freq(digits);
        update_fr29_freq();
    }

    # Group channel (000 to 429)

    var kv1_group_input_validate = func(digits) {
        var channel = 0;
        var pow = 100;
        foreach (var digit; digits) {
            channel += pow * digit;
            pow /= 10;
        }
        return channel < 430;
    }

    var kv1_input_to_group = func(digits) {
        # Just concatenate the digits
        return "N"~digits[0]~digits[1]~digits[2];
    }

    var kv1_set_new_group = func(digits) {
        kv1_group = kv1_input_to_group(digits);
        update_fr29_freq();
    }

    # Airbase channel

    var kv1_base_input_validate = func(digits) {
        # Button 'X', not allowed for last position (used for testing).
        return size(digits) != 3 or digits[2] != 9;
    }

    var base_channels_letters = ["A", "B", "C", "C2", "D", "E", "F", "G", "H"];

    var kv1_input_to_base = func(digits) {
        if (digits[2] >= 5) {
            # global channels
            return base_channels_letters[digits[2]];
        } else {
            return "B"~digits[0]~digits[1]~base_channels_letters[digits[2]];
        }
    }

    var kv1_set_new_base = func(digits) {
        kv1_base = kv1_input_to_base(digits);
        update_fr29_freq();
    }

    # Datalink channel

    var kv3_input_to_channel = func(digits) {
        # Just concatenate the digits
        return digits[0]~digits[1]~digits[2]~digits[3];
    }

    var kv3_set_new_channel = func(digits) {
        var channel = num(digits[1]~digits[2]~digits[3]);
        var ident = num(digits[0]);

        input.kv3_channel.setValue(channel);
        input.kv3_ident.setValue(ident);
    }


    ## KV1 input screens

    # Positions of symbols on texture
    var KV1_DIGIT_OFFSET = 0;
    var KV1_MINUS = 10;
    var KV1_ERROR = 11;
    var KV1_BLANK = 12;

    var KV3_DIGIT_OFFSET = 0;
    var KV3_BLANK = 10;
    var KV3_MINUS = 11;

    # Function called when a button is pressed while no screen has taken the focus (with 'clear' button).
    # Simply transmit it to the screen selected with the BAS/NR/MHz buttons.
    var kv1_pad_no_focus_callback = func(n) {
        if (input.kv1_freq.getBoolValue())     kv1_freq_input.button(n);
        elsif (input.kv1_group.getBoolValue()) kv1_group_input.button(n);
        elsif (input.kv1_base.getBoolValue())  kv1_base_input.button(n);
    }

    var kv1_pad = Keypad.new(kv1_pad_no_focus_callback);

    var kv1_freq_input = InputScreen.new("instrumentation/kv1/digit-mhz", 5, kv1_pad,
        KV1_DIGIT_OFFSET, KV1_BLANK, KV1_MINUS, KV1_ERROR,
        kv1_set_new_freq, kv1_freq_input_validate, FALSE);

    var kv1_group_input = InputScreen.new("instrumentation/kv1/digit-nr", 3, kv1_pad,
        KV1_DIGIT_OFFSET, KV1_BLANK, KV1_MINUS, KV1_ERROR,
        kv1_set_new_group, kv1_group_input_validate, TRUE);

    var kv1_base_input = InputScreen.new("instrumentation/kv1/digit-bas", 3, kv1_pad,
        KV1_DIGIT_OFFSET, KV1_BLANK, KV1_MINUS, KV1_ERROR,
        kv1_set_new_base, kv1_base_input_validate, TRUE);

    var kv3_input = InputScreen.new("instrumentation/kv3/digit", 4, kv1_pad,
        KV3_DIGIT_OFFSET, KV3_BLANK, KV3_MINUS, 0,
        kv3_set_new_channel, nil, FALSE);

    # Reset a display to last programmed value when selecting it.
    setlistener(input.kv1_freq, func (node) {
        if (node.getBoolValue()) kv1_freq_input.reset()
    }, 0, 0);
    setlistener(input.kv1_group, func (node) {
        if (node.getBoolValue()) kv1_group_input.reset()
    }, 0, 0);
    setlistener(input.kv1_base, func (node) {
        if (node.getBoolValue()) kv1_base_input.reset()
    }, 0, 0);
}




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


### Frequency update functions.

if (variant.AJS) {
    # Callback for FR22 panel knobs.
    setlistener(input.fr22_group, func(node) {
        var grp = node.getValue();
        input.fr22_group_dig1.setValue(math.mod(grp, 10));
        input.fr22_group_dig10.setValue(math.floor(grp/10));
    }, 1, 0);

    setlistener(input.fr22_base_knob, func(node) {
        var base = node.getValue();
        # Every sixth position is ALLM (global channels)
        var gen = (math.mod(base, 6) == 5);
        # Actual base number
        base = math.mod(base, 6) + math.floor(base/6)*5;
        input.fr22_base_gen.setBoolValue(gen);
        input.fr22_base.setValue(base);
        input.fr22_base_dig1.setValue(math.mod(base, 10));
        input.fr22_base_dig10.setValue(math.floor(base/10));
    }, 1, 0);

    # FR22 channels panel buttons indices (for input.fr22_button)
    var FR22_BUTTONS = {
        GROUP_START: 0,
        GROUP_END: 9,

        BASE_START: 10,
        BASE_END: 14,

        SPECIAL_START: 15,
        SPECIAL_END: 19,

        BASE: {
            A: 10,
            B: 11,
            C: 12,
            C2: 13,
            D: 14,
        },
        BASE_GEN: {
            G: 10,
            F: 12,
            E: 14,
        },

        SPECIAL: {
            H: 15,
            S1: 16,
            S2: 17,
            S3: 18,
            FREQ: 19,
        },
    };

    # FR22 frequency update logic.
    var update_fr22_freq = func {
        var button = input.fr22_button.getValue();

        var channel = nil;

        if (button >= FR22_BUTTONS.GROUP_START and button <= FR22_BUTTONS.GROUP_END) {
            # Group button pressed
            var channel = sprintf("N%.2d%d", input.fr22_group.getValue(), button - FR22_BUTTONS.GROUP_START);
        } elsif (button >= FR22_BUTTONS.BASE_START and button <= FR22_BUTTONS.BASE_END) {
            # Airbase button pressed
            if (input.fr22_base_gen.getValue()) {
                # Base knob in position ALLM
                foreach (var chan; keys(FR22_BUTTONS.BASE_GEN)) {
                    if (button == FR22_BUTTONS.BASE_GEN[chan]) {
                        channel = chan;
                        break;
                    }
                }
            } else {
                # Normal airbase channel usage
                foreach (var chan; keys(FR22_BUTTONS.BASE)) {
                    if (button == FR22_BUTTONS.BASE[chan]) {
                        channel = sprintf("B%.2d%s", input.fr22_base.getValue(), chan);
                        break;
                    }
                }
            }
        } elsif (button >= FR22_BUTTONS.SPECIAL_START and button <= FR22_BUTTONS.SPECIAL_END) {
            # Special button pressed
            foreach (var chan; keys(FR22_BUTTONS.SPECIAL)) {
                if (button == FR22_BUTTONS.SPECIAL[chan]) {
                    channel = chan;
                    break;
                }
            }
        }

        if (channel == nil) {
            # No valid channel
            fr22.set_freq(0);
        } elsif (channel == "FREQ") {
            # Use frequency selector
            fr22.set_freq(input.freq_sel_10mhz.getValue() * 10000
                         + input.freq_sel_1mhz.getValue() * 1000
                         + input.freq_sel_100khz.getValue() * 100
                         + input.freq_sel_1khz.getValue());
        } else {
            # Query channel
            fr22.set_freq(Channels.get(channel));
        }
    }

    setlistener(input.freq_sel_10mhz, update_fr22_freq, 0, 0);
    setlistener(input.freq_sel_1mhz, update_fr22_freq, 0, 0);
    setlistener(input.freq_sel_100khz, update_fr22_freq, 0, 0);
    setlistener(input.freq_sel_1khz, update_fr22_freq, 0, 0);
    setlistener(input.fr22_button, update_fr22_freq, 0, 0);
    setlistener(input.fr22_group, update_fr22_freq, 0, 0);
    setlistener(input.fr22_base, update_fr22_freq, 0, 0);
    setlistener(input.fr22_base_gen, update_fr22_freq, 0, 0);


    # FR24 frequency is controlled by the FR24 mode knob
    var update_fr24_freq = func {
        var mode = input.radio_mode.getValue();
        var freq = 0;

        if (mode == MODE.NORM_LARM) {
            freq = Channels.guard();
        } else {
            foreach (var chan; ["E", "F", "G", "H"]) {
                if (mode == MODE[chan]) freq = Channels.get(chan);
            }
        }

        fr24.set_freq(freq);
    }

    setlistener(input.radio_mode, update_fr24_freq, 0, 0);

} else {
    # JA
    var update_fr29_freq = func {
        var mode = input.radio_mode.getValue();
        var freq = 0;

        if (mode == MODE.NORM_LARM or mode == MODE.NORM) {
            # Use frequency from KV1 selector
            if (input.kv1_freq.getBoolValue())     freq = kv1_freq;
            elsif (input.kv1_group.getBoolValue()) freq = Channels.get(kv1_group);
            elsif (input.kv1_base.getBoolValue())  freq = Channels.get(kv1_base);
        } else {
            foreach (var chan; ["E", "F", "G", "H", "M", "L"]) {
                if (mode == MODE[chan]) freq = Channels.get(chan);
            }
        }

        fr28.set_freq(freq);
    }

    # update_fr29_freq is called when kv1_{freq,group,base} changes
    setlistener(input.radio_mode, update_fr29_freq);
    setlistener(input.kv1_button, update_fr29_freq);
}




### Various linking of volume/frequencies/...
#
# Remark: I use listeners rather than aliases to make the link one-way only.
# I would not want e.g. weird stuff on the nav radio side to affect the comm radio.

# Set a listener, copying values from 'target' to 'link'.
var prop_link = func(target, link) {
    link = ensure_prop(link);
    return setlistener(target, func (node) {
        link.setValue(node.getValue());
    }, 1, 0);
}

if (variant.JA) {
    # Link FR28 backup receiver volume.
    prop_link("instrumentation/comm[0]/volume", "instrumentation/comm[2]/volume");
} else {
    # AJS uses the same volume knob for FR22 and FR24.
    prop_link("instrumentation/comm[0]/volume", "instrumentation/comm[1]/volume");
}

# Link nav[2-3] to comm[0-1] (volume, frequency, power button).
# These are fake nav radios used to listen to VOR identifiers on the comm radio.
prop_link("instrumentation/comm[0]/volume", "instrumentation/nav[2]/volume");
prop_link("instrumentation/comm[0]/power-btn", "instrumentation/nav[2]/power-btn");
prop_link("instrumentation/comm[0]/frequencies/selected-mhz", "instrumentation/nav[2]/frequencies/selected-mhz");
prop_link("instrumentation/comm[1]/volume", "instrumentation/nav[3]/volume");
prop_link("instrumentation/comm[1]/power-btn", "instrumentation/nav[3]/power-btn");
prop_link("instrumentation/comm[1]/frequencies/selected-mhz", "instrumentation/nav[3]/frequencies/selected-mhz");



### Initialisation

var default_group_channels = getprop("/sim/aircraft-dir")~"/Nasal/channels-default.txt";

var init = func {
    # Load channels configuration files
    var path = input.preset_file.getValue();
    var group_path = input.preset_group_file.getValue();
    var base_path = input.preset_base_file.getValue();

    # Load default channels configuration
    if (path == nil and group_path == nil) {
        Channels.read_group_file(default_group_channels);
    }
    # Load custom ones
    if (path != nil and (group_path == nil or base_path == nil)) {
        Channels.read_file(path);
    }
    if (group_path != nil) {
        Channels.read_group_file(group_path);
    }
    if (base_path != nil) {
        Channels.read_base_file(base_path);
    }

    # Initial frequencies update.
    if (variant.AJS) {
        update_fr22_freq();
        update_fr24_freq();
    } else {
        update_fr29_freq();
    }
}
