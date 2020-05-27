var TRUE = 1;
var FALSE = 0;


var input = {
    time: "sim/time/elapsed-sec",
    snd_low_prf: "instrumentation/rwr/sound/sound[0]",
    snd_med_prf: "instrumentation/rwr/sound/sound[1]",
    snd_high_prf: "instrumentation/rwr/sound/high-prf",
    snd_incoming: "instrumentation/rwr/sound/incoming",
};
foreach (var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}

input.ja_lights = props.globals.getNode("instrumentation/rwr/ja-lights").getChildren("sector");
input.ajs_lights = props.globals.getNode("instrumentation/rwr/ajs-lights").getChildren("sector");

var is_ja = (getprop("/ja37/systems/variant") == 0);


### RWR Signals logic

# Types of RWR signals (give different warning sounds/lights)
# Numbers represent priority
var RWR_SQUAWK = 1; # Fairly confident this is not realistic
var RWR_SCAN = 2;
var RWR_LOCK = 3;
var RWR_LAUNCH = 4;
var RWR_MISSILE = 5;   # Not used yet
var RWR_SIGNAL_MIN = RWR_SQUAWK;
var RWR_SIGNAL_MAX = RWR_MISSILE;


var RWRSignal = {
    new: func(UID, type, bearing, lifetime) {
        var m = { parents: [RWRSignal] };
        m.UID = UID;
        m.lifetime = lifetime;
        m.delete_timer = maketimer(m.lifetime, m, m.del);
        m.delete_timer.singleShot = TRUE;
        m.delete_timer.simulatedTime = TRUE;
        m.delete_timer.start();
        m.bearing = bearing;
        m.type = type;
        return m;
    },
    refresh: func(type, bearing, lifetime) {
        me.bearing = bearing;
        me.type = type;
        me.lifetime = lifetime;
        me.delete_timer.restart(me.lifetime);
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
var signal = func(UID, type, bearing, lifetime=2) {
    if(contains(signals_list, UID)) {
        var s = signals_list[UID];
        s.refresh(type, bearing, lifetime);
        return s;
    } else {
        var s = RWRSignal.new(UID, type, bearing, lifetime);
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

# JA incoming warning (lights on MI display): 4 overlapping sectors
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


# The AJS RWR displays the 'raw radar signal'.
# A scan signal is periodic, hence should be seen as a periodic 'beep'.
# The beeps have a fixed period and random offset.

# period/length of scan signals (ideally should depend on the radar type)
var scan_period = 2.0;
var scan_length = 0.5;

var scan_signal_active = func(signal, time) {
    # UID is a random float in [0,1]. It is used to add a random shift to the periodic signal.
    var period_shift = signal.UID * scan_period;
    return math.mod(time + period_shift, scan_period) < scan_length;
}

# Sounds:
# The frequency of RWR sounds should correspond to the PRF of the radar signal.
# The current (very simplistic) has 3 frequencies for scan, lock, missile lock,
# plus a sound for missile launch warning (technically not part of RWR).
var sound_low_prf = FALSE;
var sound_med_prf = FALSE;
var sound_high_prf = FALSE;
var sound_incoming = FALSE;


### Update loop for lights/sounds
var update_rwr = func() {
    var time = input.time.getValue();
    forindex (var i; ja_rwr_sectors) ja_rwr_sectors[i] = 0;
    forindex (var i; ja_msl_sectors) ja_msl_sectors[i] = FALSE;
    forindex (var i; ajs_rwr_sectors) ajs_rwr_sectors[i] = FALSE;
    sound_low_prf = FALSE;
    sound_med_prf = FALSE;
    sound_high_prf = FALSE;
    sound_incoming = FALSE;

    foreach (var UID; keys(signals_list)) {
        var signal = signals_list[UID];

        # JA missile warning
        if (signal.type >= RWR_LAUNCH) {
            foreach (var i; bearing_to_ja_msl_sectors(signal.bearing)) {
                ja_msl_sectors[i] = TRUE;
            }
        }

        # JA RWR
        var level = 0;
        if (signal.type >= RWR_LOCK) level = 2;
        elsif (signal.type >= RWR_SCAN) level = 1;
        if (level > 0) {
            foreach (var i; bearing_to_ja_rwr_sectors(signal.bearing)) {
                ja_rwr_sectors[i] = math.max(ja_rwr_sectors[i], level);
            }
        }

        # AJS RWR
        if ((signal.type == RWR_SCAN and scan_signal_active(signal, time))
            or (signal.type >= RWR_LOCK and signal.type != RWR_LAUNCH)) {
            foreach (var i; bearing_to_ajs_rwr_sectors(signal.bearing)) {
                ajs_rwr_sectors[i] = TRUE;
            }
        }

        # Sounds
        if (signal.type == RWR_LAUNCH) sound_incoming = is_ja; # missile launch, JA only
        elsif (signal.type == RWR_MISSILE) sound_high_prf = TRUE;
        elsif (signal.type == RWR_LOCK) sound_med_prf = TRUE;
        elsif (signal.type == RWR_SCAN and scan_signal_active(signal, time)) sound_low_prf = TRUE;
    }

    forindex (var i; ja_msl_sectors) input.ja_lights[i].setBoolValue(ja_msl_sectors[i]);
    forindex (var i; ajs_rwr_sectors) input.ajs_lights[i].setBoolValue(ajs_rwr_sectors[i]);
    input.snd_low_prf.setBoolValue(sound_low_prf);
    input.snd_med_prf.setBoolValue(sound_med_prf);
    input.snd_high_prf.setBoolValue(sound_high_prf);
    input.snd_incoming.setBoolValue(sound_incoming);
}
