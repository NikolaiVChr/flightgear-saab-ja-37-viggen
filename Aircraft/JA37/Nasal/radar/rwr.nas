var TRUE = 1;
var FALSE = 0;


var input = {
    time: "sim/time/elapsed-sec",
};
foreach (var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}

input.ja_lights = props.globals.getNode("instrumentation/rwr").getChildren("ja-light");
input.ajs_lights = props.globals.getNode("instrumentation/rwr").getChildren("ajs-light");



### RWR Signals logic

# Types of RWR signals (give different warning sounds/lights)
# Numbers represent priority
var RWR_SQUAWK = 1; # Fairly confident this is not realistic
var RWR_SCAN = 2;
var RWR_LOCK = 3;
var RWR_LAUNCH = 4;
var RWR_APPROACH = 5;   # Not used yet
var RWR_SIGNAL_MIN = RWR_SQUAWK;
var RWR_SIGNAL_MAX = RWR_APPROACH;


var RWRSignal = {
    signal_persist_time: 2, # Time for which a signal is displayed after disappearing, in sec

    new: func(UID, type, bearing) {
        var m = { parents: [RWRSignal] };
        m.UID = UID;
        m.delete_timer = maketimer(m.signal_persist_time, m, m.del);
        m.delete_timer.singleShot = TRUE;
        m.delete_timer.simulatedTime = TRUE;
        m.delete_timer.start();
        m.bearing = bearing;
        m.type = type;
        return m;
    },
    refresh: func(type, bearing) {
        me.bearing = bearing;
        me.type = type;
        me.delete_timer.restart(me.signal_persist_time);
    },
    del: func() {
        me.delete_timer.stop();
        if(me.UID != nil) delete(signals_list, me.UID);
    },
};

# List of RWR signals indexed by their UID.
# Does not contain signals without UID
var signals_list = {};

# Register a RWR signal
#
# 'bearing' is the relative bearing in degrees
# 'type' is the type of radar signal
# If a previous signal was given with the same UID, then this signal is
# updated instead of creating a new one.
var signal = func(UID, type, bearing) {
    if(contains(signals_list, UID)) {
        var s = signals_list[UID];
        s.refresh(type, bearing);
        return s;
    } else {
        var s = RWRSignal.new(UID, type, bearing);
        signals_list[UID] = s;
        return s;
    }
}



### RWR displays

# Map a relative bearing to a sector number.
#
# The sectors are assumed to be equally distributed. Numbering is clockwise.
#   n_sectors: Number of sectors.
#   sector_offset: Bearing corresponding to the center of sector 0. Defaults to 0.
#   sector_width: Width of each sector in degrees. Defaults to 360/n_sectors.
var bearing_to_sectors = func(bearing, n_sectors, sector_offset=0, sector_width=nil) {
    var sector_spread = 360/n_sectors;
    if (sector_width == nil) sector_width = sector_spread;

    # First and last sectors
    bearing -= sector_offset;
    var min_sector = math.ceil((bearing - (sector_width/2)) / sector_spread);
    var max_sector = math.floor((bearing + (sector_width/2)) / sector_spread);
    var res = [];
    while (min_sector <= max_sector) {
        append(res, math.periodic(0, n_sectors, min_sector));
        min_sector += 1;
    }
    return res;
}

# Sector parameters
# JA RWR (on TI display): 12 non-overlapping sectors
var ja_rwr_n_sectors = 12;
var ja_rwr_sectors = [];
setsize(ja_rwr_sectors, ja_rwr_n_sectors);

var bearing_to_ja_rwr_sectors = func(bearing) {
    return bearing_to_sectors(bearing, ja_rwr_n_sectors);
}

# JA incoming warning (lights on MI display): 4 sectors with overlap
var ja_msl_n_sectors = 4;
var ja_msl_sector_width = 120;
var ja_msl_sector_offset = 30;
var ja_msl_sectors = [];
setsize(ja_msl_sectors, ja_msl_n_sectors);

var bearing_to_ja_msl_sectors = func(bearing) {
    return bearing_to_sectors(bearing, ja_msl_n_sectors, ja_msl_sector_offset, ja_msl_sector_width);
}

# AJS RWR: 6 overlapping sectors
var ajs_rwr_n_sectors = 6;
var ajs_rwr_sector_width = 90;
var ajs_rwr_sector_offset = 30;
var ajs_rwr_sectors = [];
setsize(ajs_rwr_sectors, ajs_rwr_n_sectors);

var bearing_to_ajs_rwr_sectors = func(bearing) {
    return bearing_to_sectors(bearing, ajs_rwr_n_sectors, ajs_rwr_sector_offset, ajs_rwr_sector_width);
}


# Decide whether or not a signal should be displayed.

# JA RWR has 3 display levels (green,yellow,red)
var ja_rwr_signal_level = func(signal) {
    if (signal.type >= RWR_LOCK) return 2; # High threat
    elsif (signal.type >= RWR_SCAN) return 1; # Regular threat
    else return 0; # Not displayed
}

# JA incoming warning
var ja_msl_signal_active = func(signal) {
    return (signal.type >= RWR_LAUNCH);
}

# AJS RWR is more complicated.
# Scan signals are seen as periodic 'beeps'.
# period/length of scan signals (ideally should depend on the radar type)
var scan_period = 1.8;
var scan_length = 0.5;

var ajs_rwr_signal_active = func(signal, time) {
    # Not detected
    if (signal.type == RWR_SQUAWK or signal.type == RWR_LAUNCH) return FALSE;
    # Continuous radar signals
    if (signal.type != RWR_SCAN) return TRUE;

    # Periodic scan signal. Result depends on time.
    # UID is a random float in [0,1]. It is used to add a random shift to the periodic signal.
    var period_shift = signal.UID * scan_period;
    return math.mod(time + period_shift, scan_period) < scan_length;
}


# Update the RWR sector lights
var update_ja_lights = func() {
    forindex (var i; ja_rwr_sectors) ja_rwr_sectors[i] = 0;
    forindex (var i; ja_msl_sectors) ja_msl_sectors[i] = FALSE;

    foreach (var UID; keys(signals_list)) {
        var signal = signals_list[UID];

        if (ja_msl_signal_active(signal)) {
            foreach (var i; bearing_to_ja_msl_sectors(signal.bearing)) {
                ja_msl_sectors[i] = TRUE;
            }
        }
        var level = ja_rwr_signal_level(signal);
        if (level == 0) continue;
        foreach (var i; bearing_to_ja_rwr_sectors(signal.bearing)) {
            ja_rwr_sectors[i] = math.max(ja_rwr_sectors[i], level);
        }
    }

    forindex (var i; ja_msl_sectors) input.ja_lights[i].setBoolValue(ja_msl_sectors[i]);
}

var update_ajs_lights = func() {
    var time = input.time.getValue();

    forindex (var i; ajs_rwr_sectors) {
        ajs_rwr_sectors[i] = FALSE;
    }

    foreach (var UID; keys(signals_list)) {
        var signal = signals_list[UID];
        if (!ajs_rwr_signal_active(signal, time)) continue;

        foreach (var i; bearing_to_ajs_rwr_sectors(signal.bearing)) {
            ajs_rwr_sectors[i] = TRUE;
        }
    }

    forindex (var i; ajs_rwr_sectors) {
        input.ajs_lights[i].setBoolValue(ajs_rwr_sectors[i]);
    }
}


var update_lights = getprop("/ja37/systems/variant") == 0 ? update_ja_lights : update_ajs_lights;
