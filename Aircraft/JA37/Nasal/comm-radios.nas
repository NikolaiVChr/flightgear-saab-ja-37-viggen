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


if (variant.JA) {
    # FR28 tranciever for FR29 main radio
    var fr28 = comm_radio.new(
        "instrumentation/comm[0]",
        # Values from JA37D SFI chap 19
        {min: 103000, max:159975, sep: 25},
        {min: 225000, max:399950, sep: 25});    # stops at 399.950MHz and 25KHz separation, not a typo
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



### FR29 / FR22 mode knob
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


### Special channels
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
