var TRUE = 1;
var FALSE = 0;


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
        r.node = utils.ensure_prop(node);
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




### Various linking of volume/frequencies/...
#
# Remark: I use listeners rather than aliases to make the link one-way only.
# I would not want e.g. weird stuff on the nav radio side to affect the comm radio.

# Set a listener, copying values from 'target' to 'link'.
var prop_link = func(target, link) {
    link = utils.ensure_prop(link);
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
    prop_link("instrumentation/comm[0]/volume", "instrumentation/comm[2]/volume");
}

# Link nav[2-3] to comm[0-1] (volume, frequency, power button).
# These are fake nav radios used to listen to VOR identifiers on the comm radio.
prop_link("instrumentation/comm[0]/volume", "instrumentation/nav[2]/volume");
prop_link("instrumentation/comm[0]/power-btn", "instrumentation/nav[2]/power-btn");
prop_link("instrumentation/comm[0]/frequencies/selected-mhz", "instrumentation/nav[2]/frequencies/selected-mhz");
prop_link("instrumentation/comm[1]/volume", "instrumentation/nav[3]/volume");
prop_link("instrumentation/comm[1]/power-btn", "instrumentation/nav[3]/power-btn");
prop_link("instrumentation/comm[1]/frequencies/selected-mhz", "instrumentation/nav[3]/frequencies/selected-mhz");
