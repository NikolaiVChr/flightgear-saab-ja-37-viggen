var TRUE = 1;
var FALSE = 0;


var input = {
    time: "sim/time/elapsed-sec",
    sound_high_prf: "instrumentation/rwr/sound/high-prf",
    sound_incoming: "instrumentation/rwr/sound/incoming",
    heading:        "/orientation/heading-deg",
};
foreach (var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}

input.ja_lights = props.globals.getNode("instrumentation/rwr/ja-lights").getChildren("sector");
input.ajs_lights = props.globals.getNode("instrumentation/rwr/ajs-lights").getChildren("sector");
input.beeps = props.globals.getNode("instrumentation/rwr/sound").getChildren("beep");
input.beeps_freq = props.globals.getNode("instrumentation/rwr/sound").getChildren("freq");

var is_ja = (getprop("/ja37/systems/variant") == 0);



### Sounds
# Special sounds
var sound_high_prf = FALSE;
var sound_incoming = FALSE;

# Generic beep sounds, with adjustable frequency
var n_beeps = size(input.beeps);
var used_beeps = [];
setsize(used_beeps, n_beeps);
forindex(var i; used_beeps) used_beeps[i] = FALSE;

# Find an unused beep in the array.
var last_used = -1;
var find_free_beep = func() {
    for (var i=0; i<n_beeps; i+=1) {
        last_used += 1;
        if (last_used >= n_beeps) last_used = 0;
        if (!used_beeps[last_used]) return last_used;
    }
    return -1;
}

# Start a new beeping sound with the given frequency.
# Returns an index which identifies this sound, to be passed to 'stop_beep'.
# Returns a negative index if no free beeping sounds are available.
var start_beep = func(freq) {
    var i = find_free_beep();
    if (i < 0) return i;

    used_beeps[i] = TRUE;
    input.beeps[i].setBoolValue(TRUE);
    input.beeps_freq[i].setValue(freq);
    return i;
}

var stop_beep = func(i) {
    if (i < 0) return;
    input.beeps[i].setBoolValue(FALSE);
    used_beeps[i] = FALSE;
}



### Radars characteristics database.
# Most of the values are for much earlier radars with similar use.
# main source for values: https://www.radartutorial.eu
var radar_types = {
    # AJS37 SFI part 3 (475Hz and 1900Hz are actual frequency, but do not correspond to scan/lock)
    "AJS37-Viggen":     { scan_freq: 475, scan_period: 2.24, scan_length: 0.4, lock_freq: 1900, half_angle: 61.5 },
    "AJ37-Viggen":      "AJS37-Viggen",
    "JA37Di-Viggen":    "default",
    "f-14b":            "default",
    "F-15C":            "default",
    "F-15D":            "F-15C",
    "F-16":             "default",
    "YF-16":            "F-16",
    "m2000-5":          "default",
    "m2000-5B":         "m2000-5",
    "SU-27":            "default",
    "J-11A":            "SU-27",
    "daVinci_SU-34":    "SU-27",
    "Su-34":            "SU-27",
    "SU-37":            "SU-27",
    "MiG-29":           "default",
    "T-50":             "default",
    "MiG-21bis":        "default",
    "MiG-21MF-75":      "MiG-21bis",
    "Typhoon":          "default",
    "EF2000":           "default",
    "brsq":             "default",
    "FA-18C_Hornet":    "default",
    "FA-18D_Hornet":    "FA-18C_Hornet",
    "F-22-Raptor":      "default",
    "F-35A":            "default",
    "F-35B":            "F-35A",
    "F-35C":            "F-35A",
    "f-20A":            "default",
    "f-20C":            "f-20A",
    "f-20prototype":    "f-20A",
    "f-20bmw":          "f-20A",
    "f-20-dutchdemo":   "f-20A",
    "EC-137R":          { scan_freq: 450, scan_period: 4, scan_length: 0.5, lock_freq: 1900, half_angle: 180 },
    "EC-137D":          "EC-137R",
    # Scan: P-40, lock: SNR-125
    "buk-m2":           { scan_freq: 400, scan_period: 4, scan_length: 0.5, lock_freq: 1750, half_angle: 180 },
    # Scan: P-37, lock: SNR-75
    "s-300":            { scan_freq: 375, scan_period: 10, scan_length: 0.8, lock_freq: 1650, half_angle: 180 },
    # Scan: AN/SPS-49, lock: AN/SPG-60
    "frigate":          { scan_freq: 800, scan_period: 5, scan_length: 0.6, lock_freq: 1800, half_angle: 180 },
    "missile_frigate":  "frigate",
    "USS-NORMANDY":     "frigate",
    "USS-LakeChamplain":"frigate",
    "USS-OliverPerry":  "frigate",
    "USS-SanAntonio":   "frigate",
    "default":          { scan_freq: 600, scan_period: 2, scan_length: 0.4, lock_freq: 1900, half_angle: 60 },
};

# Resolve aliases
foreach(var key; keys(radar_types)) {
    var val = radar_types[key];
    while (typeof(val) == "scalar" and contains(radar_types, val)) {
        val = radar_types[val];
    }
    radar_types[key] = val;
}

var radar_info = func(model) {
    var res = radar_types[model];
    if (res == nil) res = radar_types["default"];
    return res;
}



### RWR Signals logic

# Types of RWR signals (give different warning sounds/lights)
# Numbers represent priority
var RWR_SQUAWK = 1; # Unused, fairly confident that it is not realistic
var RWR_SCAN = 2;
var RWR_LOCK = 3;
var RWR_LAUNCH = 4;
var RWR_MISSILE = 5; # Not used yet
var RWR_SIGNAL_MIN = RWR_SQUAWK;
var RWR_SIGNAL_MAX = RWR_MISSILE;


var RWRSignal = {
    new: func(UID, type, bearing, lifetime, aircraft) {
        var m = { parents: [RWRSignal] };
        m.UID = UID;
        m.lifetime = lifetime;
        m.delete_timer = maketimer(m.lifetime, m, m.del);
        m.delete_timer.singleShot = TRUE;
        m.delete_timer.simulatedTime = TRUE;
        m.delete_timer.start();
        m.bearing = bearing;
        m.type = type;
        m.aircraft = aircraft;
        m.radar_info = radar_info(aircraft);
        m.sound = nil;
        return m;
    },
    refresh: func(bearing, lifetime) {
        me.bearing = bearing;
        me.lifetime = lifetime;
        me.delete_timer.restart(me.lifetime);
    },
    del: func() {
        if (me.sound != nil and me.sound >= 0) {
            stop_beep(me.sound);
        }
        me.delete_timer.stop();
        if(me.UID != nil) delete(signals_list, me.UID);
    },
    # The AJS RWR displays the 'raw radar signal'.
    # A scan signal is periodic, hence should be seen as a periodic 'beep'.
    scan_active: func(time) {
        # UID is a random float in [0,1]. It is used to add a random shift to the periodic signal.
        var period_shift = me.UID * me.radar_info.scan_period;
        return math.mod(time + period_shift, me.radar_info.scan_period) < me.radar_info.scan_length;
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
var signal = func(UID, type, bearing, lifetime=2, aircraft="default") {
    if(contains(signals_list, UID)) {
        var s = signals_list[UID];
        if (s.type == type and s.aircraft == aircraft) {
            # Same signal characteristics, just refresh
            s.refresh(bearing, lifetime);
            return s;
        } else {
            # Delete old signal before creating a new one
            s.del();
        }
    }

    var s = RWRSignal.new(UID, type, bearing, lifetime, aircraft);
    signals_list[UID] = s;
    return s;
}

### Determine radar signals generated by an aircraft

# Radar lock is explicitly send through MP properties, as md5 hash of the callsign
var callsign_md5 = "";
var update_callsign_md5 = func(n) {
    callsign_md5 = ""~n.getValue(); # ensure that it is a string
    if(size(callsign_md5) > 7) callsign_md5 = left(callsign_md5, 7);
    callsign_md5 = left(md5(callsign_md5), 4);
}

setlistener("/sim/multiplay/callsign", update_callsign_md5, 1, 0);

var test_radar_lock = func(node) {
    var locked_md5 = node.getNode("sim/multiplay/generic/string[6]");
    if(locked_md5 == nil) return FALSE;
    locked_md5 = locked_md5.getValue();
    return (locked_md5 != nil and streq(locked_md5, callsign_md5));
}

# Tests if the aircrafts has its radar active and pointed roughly towards us.
var test_radar_scan = func(node, bearing, half_angle) {
    var radar = node.getNode("sim/multiplay/generic/int[2]");
    if (radar != nil and radar.getValue()) return FALSE;

    # Radar is active, test if it is pointed at us
    if (half_angle >= 180) return TRUE; # radar covers the horizon, no need to test
    var heading = node.getNode("orientation/true-heading-deg").getValue();
    # Relative bearing from the aircraft to us
    var angle_offset = math.abs(geo.normdeg180(bearing - 180 - heading));
    return angle_offset <= half_angle;
}

# Interface for radar system
var handle_aircraft = func(UID, node, model, aircraft_pos, self_pos) {
    if(!contains(radar_types, model)) return; # Other aircrafts are assumed not to have a radar

    var bearing = self_pos.course_to(aircraft_pos);
    var rel_bearing = bearing - input.heading.getValue();

    if (test_radar_lock(node)) {
        signal(UID, RWR_LOCK, rel_bearing, 2, model);
    } elsif (test_radar_scan(node, bearing, radar_types[model].half_angle)) {
        signal(UID, RWR_SCAN, rel_bearing, 2, model);
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
        if ((signal.type == RWR_SCAN and signal.scan_active(time))
            or (signal.type >= RWR_LOCK and signal.type != RWR_LAUNCH)) {
            foreach (var i; bearing_to_ajs_rwr_sectors(signal.bearing)) {
                ajs_rwr_sectors[i] = TRUE;
            }
        }

        # Sounds
        if (signal.type == RWR_LAUNCH) sound_incoming = is_ja; # missile launch, JA only
        elsif (signal.type == RWR_MISSILE) sound_high_prf = TRUE;
        elsif (signal.type == RWR_LOCK or (signal.type == RWR_SCAN and signal.scan_active(time))) {
            # Beep sound.
            if (signal.sound == nil or signal.sound < 0) {
                # start beeping
                var freq = (signal.type == RWR_LOCK) ? signal.radar_info.lock_freq : signal.radar_info.scan_freq;
                var i = start_beep(freq);
                if (i >= 0) signal.sound = i;
            }
        } else {
            # No sound, disable beep if required.
            if (signal.sound != nil and signal.sound >= 0) {
                stop_beep(signal.sound);
                signal.sound = nil;
            }
        }
    }

    forindex (var i; ja_msl_sectors) input.ja_lights[i].setBoolValue(ja_msl_sectors[i]);
    forindex (var i; ajs_rwr_sectors) input.ajs_lights[i].setBoolValue(ajs_rwr_sectors[i]);
    input.sound_high_prf.setBoolValue(sound_high_prf);
    input.sound_incoming.setBoolValue(sound_incoming);
}
