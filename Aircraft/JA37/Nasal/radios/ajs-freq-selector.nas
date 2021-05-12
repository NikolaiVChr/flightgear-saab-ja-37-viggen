#### AJS comm radios

var TRUE = 1;
var FALSE = 0;

var input = {
    fr24_knob:          "instrumentation/radio/mode",
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
};

foreach (var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}



### Callbacks for FR22 panel knobs to update displays.
setlistener(input.fr22_group, func(node) {
    var grp = node.getValue();
    input.fr22_group_dig1.setValue(math.mod(grp, 10));
    input.fr22_group_dig10.setValue(math.floor(grp/10));
}, 1, 0);

setlistener(input.fr22_base_knob, func(node) {
    var base = node.getValue();
    # Every sixth position is ALLM (global channels)
    # Exception for position 0, which is also ALLM (so that ALLM is at both ends of the knob range).
    var gen = (math.mod(base, 6) == 5) or base == 0;
    # Actual base number
    base = math.mod(base, 6) + math.floor(base/6)*5;
    input.fr22_base_gen.setBoolValue(gen);
    input.fr22_base.setValue(base);
    input.fr22_base_dig1.setValue(math.mod(base, 10));
    input.fr22_base_dig10.setValue(math.floor(base/10));
}, 1, 0);



### FR22 channels panel buttons indices (for input.fr22_button)
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

# Start radio buttons logic.
radio_buttons.RadioButtons.new("instrumentation/fr22/button", input.fr22_button, 20);



### FR22 frequency update logic.
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
                    channel = sprintf("B%.3d%s", input.fr22_base.getValue(), chan);
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
        comm.fr22.set_freq(0);
    } elsif (channel == "FREQ") {
        # Use frequency selector
        comm.fr22.set_freq(input.freq_sel_10mhz.getValue() * 10000
                     + input.freq_sel_1mhz.getValue() * 1000
                     + input.freq_sel_100khz.getValue() * 100
                     + input.freq_sel_1khz.getValue());
    } else {
        # Query channel
        comm.fr22.set_freq(channels.get(channel));
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



### FR24 frequency update

# Positions of the FR24 knob for which the FR24 is active (not counting guard receiver).
var FR24_KNOB = {
    E: 2,
    F: 3,
    G: 4,
    H: 5,
};

var update_fr24_freq = func {
    var mode = input.fr24_knob.getValue();
    var freq = 0;
    foreach (var chan; ["E", "F", "G", "H"]) {
        if (mode == FR24_KNOB[chan]) freq = channels.get(chan);
    }
    comm.fr24.set_freq(freq);
}

setlistener(input.fr24_knob, update_fr24_freq, 0, 0);



var channel_update_callback = func {
    update_fr22_freq();
    update_fr24_freq();
}
