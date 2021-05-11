#### JA comm radios

var TRUE = 1;
var FALSE = 0;

var input = {
    fr29_knob:          "instrumentation/radio/mode",
    kv1_freq:           "instrumentation/kv1/button-mhz",
    kv1_group:          "instrumentation/kv1/button-nr",
    kv1_base:           "instrumentation/kv1/button-bas",
    kv1_button:         "instrumentation/kv1/button-selected",
    kv3_channel:        "instrumentation/datalink/channel",
    kv3_ident:          "instrumentation/datalink/ident",
};

foreach (var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}



# Convert a string to a prop. Do nothing if the input is not a string.
var ensure_prop = func(path) {
    if (typeof(path) == "scalar") return props.globals.getNode(path, 1);
    else return path;
}


### KV1 channel selector logic

# Keypad shared between several input controllers.
#
# Each controller can take_focus(), after which calls to Keypad.button()
# are redirected to this controller button() method, until it calls Keypad.release(),
# or another controller calls take_focus(),
# When a controller looses focus, this controller on_focus_lost() method is called.
#
# Arg: no_focus_callback: if non nil, called instead of controller.button() when no controller has focus.
var KV1Keypad = {
    controller: nil,

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
        else {
            # Fallback logic when no controller has explicitly taken focus.
            # Send to screen corresponding to currently active mode.
            if (input.kv1_freq.getBoolValue())     kv1_freq_input.button(n);
            elsif (input.kv1_group.getBoolValue()) kv1_group_input.button(n);
            elsif (input.kv1_base.getBoolValue())  kv1_base_input.button(n);
        }
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

radio_buttons.RadioButtons.new([input.kv1_freq, input.kv1_group, input.kv1_base], input.kv1_button);


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
    if (freq <= comm.fr28.vhf.max and max_freq > comm.fr28.vhf.min) return TRUE;
    if (freq <= comm.fr28.uhf.max and max_freq > comm.fr28.uhf.min) return TRUE;
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
        return "B0"~digits[0]~digits[1]~base_channels_letters[digits[2]];
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

var kv1_freq_input = InputScreen.new("instrumentation/kv1/digit-mhz", 5, KV1Keypad,
    KV1_DIGIT_OFFSET, KV1_BLANK, KV1_MINUS, KV1_ERROR,
    kv1_set_new_freq, kv1_freq_input_validate, FALSE);

var kv1_group_input = InputScreen.new("instrumentation/kv1/digit-nr", 3, KV1Keypad,
    KV1_DIGIT_OFFSET, KV1_BLANK, KV1_MINUS, KV1_ERROR,
    kv1_set_new_group, kv1_group_input_validate, TRUE);

var kv1_base_input = InputScreen.new("instrumentation/kv1/digit-bas", 3, KV1Keypad,
    KV1_DIGIT_OFFSET, KV1_BLANK, KV1_MINUS, KV1_ERROR,
    kv1_set_new_base, kv1_base_input_validate, TRUE);

var kv3_input = InputScreen.new("instrumentation/kv3/digit", 4, KV1Keypad,
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


# Radio control panel power.
var fr29_on = func {
    return power.prop.dcBatt2Bool.getValue();
}

# Wrappers to check that the radio is on.
var kv1_button = func(n) {
    if (fr29_on()) KV1Keypad.button(n);
}
var kv1_clear_freq = func {
    if (fr29_on()) kv1_freq_input.clear();
}
var kv1_clear_group = func {
    if (fr29_on()) kv1_group_input.clear();
}
var kv1_clear_base = func {
    if (fr29_on()) kv1_base_input.clear();
}
var kv3_clear = func {
    if (fr29_on()) kv3_input.clear();
}

# Reset inputs on power on
setlistener(power.prop.dcBatt2Bool, func (node) {
    if (node.getBoolValue()) {
        kv1_freq_input.reset();
        kv1_group_input.reset();
        kv1_base_input.reset();
        kv3_input.reset();
    }
}, 1, 0);


# FR29 channel selection
var FR29_KNOB = {
    NORM_LARM: 0,
    NORM: 1,
    E: 2,
    F: 3,
    G: 4,
    H: 5,
    M: 6,
    L: 7,
};

var update_fr29_freq = func {
    var mode = input.fr29_knob.getValue();
    var freq = 0;

    if (mode == FR29_KNOB.NORM_LARM or mode == FR29_KNOB.NORM) {
        # Use frequency from KV1 selector
        if (input.kv1_freq.getBoolValue())     freq = kv1_freq;
        elsif (input.kv1_group.getBoolValue()) freq = channels.get(kv1_group);
        elsif (input.kv1_base.getBoolValue())  freq = channels.get(kv1_base);
    } else {
        foreach (var chan; ["E", "F", "G", "H", "M", "L"]) {
            if (mode == FR29_KNOB[chan]) freq = channels.get(chan);
        }
    }

    comm.fr28.set_freq(freq);
}

# update_fr29_freq is called when kv1_{freq,group,base} changes
setlistener(input.fr29_knob, update_fr29_freq);
setlistener(input.kv1_button, update_fr29_freq);


### FR31 channel / frequency selection logic
var me31 = {
    MODE: {
        FREQ: 0,
        GROUP: 1,
        BASE: 2,
    },

    # Number of input characters for each mode
    input_sizes: [5, 3, 4],
    # For current mode
    input_size: 5,

    # Symbols positions on texture
    DIGITS_OFFSET: 0,
    BLANK: 12,
    DIGIT_TO_LETTER: ["X", "A", "B", "C", "C2", "D", "E", "F", "G", "H"],
    LETTER_TO_DIGIT: {
        A: 1,
        B: 2,
        C: 3,
        C2: 4,
        E: 5,
        H: 9,
    },

    init: func {
        # Screen is controlled by properties letter[i] (toggles between
        # digits and letters) and digit[i] (select the digit / letter).
        me.node = props.globals.getNode("instrumentation/fr31");
        me.digits = [];
        me.is_letter = [];
        setsize(me.digits, 5);
        setsize(me.is_letter, 5);
        forindex (var i; me.digits) {
            me.digits[i] = me.node.getChild("digit", i, 1);
            me.digits[i].setValue(me.BLANK);
            me.is_letter[i] = me.node.getChild("letter", i, 1);
            me.is_letter[i].setBoolValue(FALSE);
        }

        me.mode = me.MODE.FREQ;
        me.presel_mode = me.MODE.FREQ;

        me.pos = -1;
    },

    validate: func(digits) {
        # Compute the value corresponding to the current (partial) input.
        var pow = math.pow(10, me.input_size-1);
        var val = 0;
        foreach (var digit; digits) {
            val += pow * digit;
            pow /= 10;
        }
        # Mode dependent check
        if (me.mode == me.MODE.FREQ) {
            # Check last digit for 25KHz separation
            if (size(digits) == me.input_size) {
                var last_dig = digits[me.input_size-1];
                if (last_dig != 0 and last_dig != 2 and last_dig != 5 and last_dig != 7) return FALSE;
            }

            # One above the maximum frequency that can be reached with the current partial input.
            var max_val = val + pow*10;
            # Convert values to to KHz
            val *= 10;
            max_val *= 10;
            # Check range
            if (val <= comm.fr31.vhf.max and max_val > comm.fr31.vhf.min) return TRUE;
            if (val <= comm.fr31.uhf.max and max_val > comm.fr31.uhf.min) return TRUE;
            return FALSE;
        } elsif (me.mode == me.MODE.GROUP) {
            # Channels up to 119.
            return val < 120;
        } elsif (me.mode == me.MODE.BASE) {
            # Check last character
            if (size(digits) == me.input_size) {
                var last_char = digits[me.input_size-1];
                if (last_char < me.LETTER_TO_DIGIT["A"] or last_char > me.LETTER_TO_DIGIT["E"]) return FALSE;
            }
            # Base numbers up to 169.
            return (val/10) < 170;
        }
    },

    set_freq: func(digits) {
        if (me.mode == me.MODE.FREQ) {
            var pow = 100000;
            var freq = 0;
            foreach (var digit; digits) {
                freq += pow * digit;
                pow /= 10;
            }
            # Convert to 25KHz separation
            if (digits[4] == 2 or digits[4] == 7) {
                freq += 5;
            }
            comm.fr31.set_freq(freq);
        } elsif (me.mode == me.MODE.GROUP) {
            var channel = "N"~digits[0]~digits[1]~digits[2];
            comm.fr31.set_freq(channels.get(channel));
        } elsif (me.mode == me.MODE.BASE) {
            var channel = "B"~digits[0]~digits[1]~digits[2]~me.DIGIT_TO_LETTER[digits[3]];
            comm.fr31.set_freq(channels.get(channel));
        }
    },

    # Buttons
    button: func(n) {
        if (!me.power()) return;

        # Input inactive
        if (me.pos < 0) return;

        # Guard channel when pressing H as first input, regardless of mode.
        # (none of the modes allow '9' as first digit).
        if (me.pos == 0 and n == me.LETTER_TO_DIGIT["H"]) {
            me.digits[0].setValue(me.LETTER_TO_DIGIT["H"]);
            me.is_letter[0].setBoolValue(TRUE);
            me.pos = -1;
            comm.fr31.set_freq(channels.get("H"));
            return;
        }

        # Check input
        append(me.current_input, n);
        if (!me.validate(me.current_input, me.mode)) {
            # Ignore invalid input
            pop(me.current_input);
            return;
        }

        # Update screen
        me.digits[me.pos].setValue(n+me.DIGITS_OFFSET);
        # Special logic to display the 'C2' channel, last position in BAS mode.
        if (me.mode == me.MODE.BASE and me.pos == me.input_size-1) {
            if (n == me.LETTER_TO_DIGIT["C2"]) {
                me.digits[me.pos].setValue(me.LETTER_TO_DIGIT["C"]);
                me.digits[me.pos+1].setValue(2 + me.DIGITS_OFFSET);
            } else {
                me.digits[me.pos+1].setValue(me.BLANK);
            }
        }

        me.pos += 1;
        if (me.pos >= me.input_size) {
            # End of input
            me.set_freq(me.current_input, me.mode);

            if (me.mode == me.MODE.GROUP or me.mode == me.MODE.BASE) {
                # Get ready to edit the last digit on the next button press
                pop(me.current_input);
                me.pos -= 1;
            } else {
                # end of input
                me.pos = -1;
            }
        }
    },

    clear: func {
        if (!me.power()) return;

        # The MHz/NR/BAS buttons only preselect a mode, which activates when clearing.
        me.mode = me.presel_mode;
        me.input_size = me.input_sizes[me.mode];

        forindex (var i; me.digits) {
            me.digits[i].setValue(me.BLANK);
            me.is_letter[i].setBoolValue(FALSE);
        }
        # Last character in mode BAS is the channel letter.
        if (me.mode == me.MODE.BASE) me.is_letter[me.input_size-1].setBoolValue(TRUE);

        me.current_input = [];
        me.pos = 0;
    },

    mhz: func {
        if (!me.power()) return;
        me.presel_mode = me.MODE.FREQ;
    },

    nr: func {
        if (!me.power()) return;
        me.presel_mode = me.MODE.GROUP;
    },

    bas: func {
        if (!me.power()) return;
        me.presel_mode = me.MODE.BASE;
    },

    # Power condition
    power: func {
        return power.prop.dcSecondBool.getValue();
    },
};

me31.init();



var channel_update_callback = func {
    update_fr29_freq();
    # todo FR31
}
