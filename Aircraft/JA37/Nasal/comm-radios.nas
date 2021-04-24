var TRUE = 1;
var FALSE = 0;

var input = {
    freq_sel_10mhz:     "instrumentation/radio/frequency-selector/frequency-10mhz",
    freq_sel_1mhz:      "instrumentation/radio/frequency-selector/frequency-1mhz",
    freq_sel_100khz:    "instrumentation/radio/frequency-selector/frequency-100khz",
    freq_sel_1khz:      "instrumentation/radio/frequency-selector/frequency-1khz",
    comm_mhz:           "instrumentation/comm/frequencies/selected-mhz",
    # For FGCom-mumble
    comm_pwr:           "instrumentation/comm/tx-power",
};

foreach(var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}


# Frequency bands (limits inclusive, all KHz). From AJS and JA37D SFI part 1.
var VHF_min = 103000;
var VHF_max = variant.JA ? 159975 : 155975;
var VHF_sep = 25;
var VHF_power = variant.JA ? 50 : 20;

var UHF_min = 225000;
var UHF_max = 399950;
var UHF_sep = variant.JA ? 25 : 50;
var UHF_power = variant.JA ? 30 : 10;

# Check if a frequency (in khz) is valid, i.e. in the VHF or UHF band, with appropriate separation.
var is_VHF = func(khz) {
    return khz >= VHF_min and khz <= VHF_max;
}

var is_UHF = func(khz) {
    return khz >= UHF_min and khz <= UHF_max
}

var is_valid_freq = func(khz) {
    if (is_VHF(khz)) return math.mod(khz, VHF_sep) == 0;
    elsif (is_UHF(khz)) return math.mod(khz, UHF_sep) == 0;
    else return FALSE;
}

# Set a frequency for radio comm[0].
#
# This takes care of checking the frequency validity (sets freq=0 if invalid)
# and updating the radio power depending on the band (VHF/UHF).
var set_comm_freq = func(khz) {
    if (!is_valid_freq(khz)) {
        input.comm_mhz.setValue(0);
        return
    }

    input.comm_mhz.setValue(khz/1000.0);
    input.comm_pwr.setValue(is_VHF(khz) ? VHF_power : UHF_power);
}


# Set comm frequency from AJS frequency selector panel.
if (variant.AJS) {
    var update_AJS_freq = func {
        set_comm_freq(
            input.freq_sel_10mhz.getValue() * 10000
            + input.freq_sel_1mhz.getValue() * 1000
            + input.freq_sel_100khz.getValue() * 100
            + input.freq_sel_1khz.getValue());
    }

    setlistener(input.freq_sel_10mhz, update_AJS_freq, 0, 0);
    setlistener(input.freq_sel_1mhz, update_AJS_freq, 0, 0);
    setlistener(input.freq_sel_100khz, update_AJS_freq, 0, 0);
    setlistener(input.freq_sel_1khz, update_AJS_freq, 0, 0);
    update_AJS_freq();
}
