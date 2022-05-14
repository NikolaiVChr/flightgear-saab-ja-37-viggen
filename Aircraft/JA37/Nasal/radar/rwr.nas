var TRUE = 1;
var FALSE = 0;


var input = {
    time:           "sim/time/elapsed-sec",
    sound_high_prf: "instrumentation/rwr/sound/high-prf",
    sound_incoming: "instrumentation/rwr/sound/incoming",
    heading:        "/orientation/heading-deg",
    damage:         "/payload/armament/msg",
    spectator:      "/payload/armament/spectator",
    gear_pos:       "/gear/gear/position-norm",
};
foreach (var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}

input.ja_lights = props.globals.getNode("instrumentation/rwr/ja-lights").getChildren("sector");
input.ajs_lights = props.globals.getNode("instrumentation/rwr/ajs-lights").getChildren("sector");
input.beeps = props.globals.getNode("instrumentation/rwr/sound").getChildren("beep");
input.beeps_freq = props.globals.getNode("instrumentation/rwr/sound").getChildren("freq");
input.beeps_vol = props.globals.getNode("instrumentation/rwr/sound").getChildren("vol");



var RWR_enabled = func {
    if (!power.prop.acSecondBool.getBoolValue()) return FALSE;
    if (input.gear_pos.getValue() > 0) return FALSE;
    if (variant.AJS and modes.selector_ajs <= modes.STBY) return FALSE;
    return TRUE;
}


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

# Normalisation function applied to the beep volume.
# Compensate for higher frequencies being percieved far louder.
var volume_normalisation = func(freq) {
    return 300/freq + 0.25;
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
    input.beeps_vol[i].setValue(volume_normalisation(freq));
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
    "EC-137R":          { scan_freq: 450, scan_period: 4.2, scan_length: 0.5, lock_freq: 1900, half_angle: 180 },
    "EC-137D":          "EC-137R",
    # Scan: P-40, lock: SNR-125
    "buk-m2":           { scan_freq: 400, scan_period: 3.7, scan_length: 0.5, lock_freq: 1750, half_angle: 180 },
    # Scan: P-37, lock: SNR-75
    "S-75":             { scan_freq: 375, scan_period: 9.5, scan_length: 0.8, lock_freq: 1650, half_angle: 180 },
    "s-300":            "S-75",
    # Scan: AN/MPQ-35, lock: AN/
    "MIM104D":          { scan_freq: 800, scan_period: 7, scan_length: 0.8, lock_freq: 2000, half_angle: 180 },
    "ZSU-23-4M":        { scan_freq: 700, scan_period: 3, scan_length: 0.5, lock_freq: 2400, half_angle: 180 },
    # Scan: AN/SPS-49, lock: AN/SPG-60
    "frigate":          { scan_freq: 800, scan_period: 5.1, scan_length: 0.6, lock_freq: 1800, half_angle: 180 },
    "missile_frigate":  "frigate",
    "USS-NORMANDY":     "frigate",
    "USS-LakeChamplain":"frigate",
    "USS-OliverPerry":  "frigate",
    "USS-SanAntonio":   "frigate",
    "fleet":            "frigate",
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
var RWR_MISSILE = 5;
var RWR_SIGNAL_MIN = RWR_SQUAWK;
var RWR_SIGNAL_MAX = RWR_MISSILE;


var RWRSignal = {
    new: func(UID, type, bearing, pitch, lifetime, aircraft) {
        var m = { parents: [RWRSignal] };
        m.UID = UID;
        m.lifetime = lifetime;
        m.delete_timer = maketimer(m.lifetime, m, m.del);
        m.delete_timer.singleShot = TRUE;
        m.delete_timer.simulatedTime = TRUE;
        m.delete_timer.start();
        m.bearing = bearing;
        m.pitch = pitch;
        m.type = type;
        m.aircraft = aircraft;
        m.radar_info = radar_info(aircraft);
        m.sound = nil;
        # Random shift to the periodic signal.
        m.period_shift = rand() * m.radar_info.scan_period;
        return m;
    },

    refresh: func(bearing, pitch, lifetime) {
        me.bearing = bearing;
        me.pitch = pitch;
        me.lifetime = lifetime;
        me.delete_timer.restart(me.lifetime);
    },

    is_beeping: func {
        return me.sound != nil and me.sound >= 0;
    },

    start_beep: func {
        if (me.is_beeping()) return;
        if (me.type == RWR_LOCK) {
            var freq = me.radar_info.lock_freq;
        }  elsif (me.type == RWR_SCAN) {
            var freq = me.radar_info.scan_freq;
        } else return;

        me.sound = start_beep(freq);
    },

    stop_beep: func {
        if (!me.is_beeping()) return;
        stop_beep(me.sound);
        me.sound = nil;
    },

    del: func() {
        me.stop_beep();
        me.delete_timer.stop();
        if(me.UID != nil) delete(signals_list, me.UID);
    },
    # The AJS RWR displays the 'raw radar signal'.
    # A scan signal is periodic, hence should be seen as a periodic 'beep'.
    scan_active: func(time) {
        return math.mod(time + me.period_shift, me.radar_info.scan_period) < me.radar_info.scan_length;
    },
};


### Handling of incoming signals

# List of RWR signals indexed by their UID.
# Does not contain signals without UID
var signals_list = {};


# Register a RWR signal
#
# 'pos' is the source of the signal, as geo.Coord object.
# 'type' is the type of radar signal
# If a previous signal was given with the same UID, then this signal is
# updated instead of creating a new one.
var signal = func(UID, type, pos, lifetime=2, aircraft="default") {
    var angles = vector.AircraftPosition.coordToLocalAziElev(pos);

    if (contains(signals_list, UID)) {
        var s = signals_list[UID];
        if (s.type == type and s.aircraft == aircraft) {
            # Same signal characteristics, just refresh
            s.refresh(angles[0], angles[1], lifetime);
            return s;
        } else {
            # Delete old signal before creating a new one
            s.del();
        }
    }

    var s = RWRSignal.new(UID, type, angles[0], angles[1], lifetime, aircraft);
    signals_list[UID] = s;
    return s;
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
var ja_rwr_pitch_limit = 60;
setsize(ja_rwr_sectors, ja_rwr_n_sectors);

var bearing_to_ja_rwr_sectors = func(bearing) {
    return bearing_to_sectors(bearing, ja_rwr_n_sectors);
}

# JA incoming warning (lights on MI display): 4 overlapping sectors
var ja_msl_n_sectors = 4;
var ja_msl_sector_width = 120;
var ja_msl_sector_offset = 30;
var ja_msl_sectors = [];
var ja_msl_pitch_limit = 80;
setsize(ja_msl_sectors, ja_msl_n_sectors);

var bearing_to_ja_msl_sectors = func(bearing) {
    return bearing_to_sectors(bearing, ja_msl_n_sectors, ja_msl_sector_offset, ja_msl_sector_width);
}

# AJS RWR: 6 overlapping sectors
var ajs_rwr_n_sectors = 6;
var ajs_rwr_sector_width = 90;
var ajs_rwr_sector_offset = 30;
var ajs_rwr_sectors = [];
var ajs_rwr_pitch_limit = 60;
setsize(ajs_rwr_sectors, ajs_rwr_n_sectors);

var bearing_to_ajs_rwr_sectors = func(bearing) {
    return bearing_to_sectors(bearing, ajs_rwr_n_sectors, ajs_rwr_sector_offset, ajs_rwr_sector_width);
}



### Update loop for lights/sounds
var update_rwr = func() {
    if (!RWR_enabled()) {
        forindex (var i; ja_msl_sectors) input.ja_lights[i].setBoolValue(FALSE);
        forindex (var i; ajs_rwr_sectors) input.ajs_lights[i].setBoolValue(FALSE);
        input.sound_high_prf.setBoolValue(FALSE);
        input.sound_incoming.setBoolValue(FALSE);
        foreach (var uid; keys(signals_list)) signals_list[uid].stop_beep();
        return;
    }

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

        if (variant.JA) {
            var pitch_limit = signal.type == RWR_LAUNCH ? ja_msl_pitch_limit : ja_rwr_pitch_limit;
        } else {
            var pitch_limit = ajs_rwr_pitch_limit;
        }
        if (math.abs(signal.pitch) > pitch_limit) {
            signal.stop_beep();
            continue;
        }

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
        if (signal.type == RWR_LAUNCH) {
            sound_incoming = variant.JA; # missile launch, JA only
        } elsif (signal.type == RWR_MISSILE) {
            sound_high_prf = TRUE;
        } elsif (signal.type == RWR_LOCK or (signal.type == RWR_SCAN and signal.scan_active(time))) {
            signal.start_beep();
        } else {
            signal.stop_beep();
        }
    }

    forindex (var i; ja_msl_sectors) input.ja_lights[i].setBoolValue(ja_msl_sectors[i]);
    forindex (var i; ajs_rwr_sectors) input.ajs_lights[i].setBoolValue(ajs_rwr_sectors[i]);
    input.sound_high_prf.setBoolValue(sound_high_prf);
    input.sound_incoming.setBoolValue(sound_incoming);
}




### Radar system interface

# These functions override radar functions to determine radar angle limits.
var isOmniRadiating = func(model) {
    return getRadarFieldRadius(model) >= 180;
}

var getRadarFieldRadius = func(model) {
    var info = radar_types[model];
    return info == nil ? 0 : info.half_angle;
}


var handle_aircraft = func(contact) {
    var model = contact.getModel();
    if (!contains(radar_types, model)) return;

    var rwr_info = contact.getThreatStored();
    var radar = rwr_info[4];
    var lock = rwr_info[10];
    if (!radar and !lock) return;

    var coord = rwr_info[2];
    var UID = contact.getUnique();

    signal(UID, lock ? RWR_LOCK : RWR_SCAN, coord, 2, model);
}


var RWRRecipient = emesary.Recipient.new("RWRRadarRecipient");

RWRRecipient.Receive = func(notification) {
    if (notification.NotificationType != "OmniNotification") {
        return emesary.Transmitter.ReceiptStatus_NotProcessed;
    }

    foreach (var contact; notification.vector) {
        handle_aircraft(contact);
    }

    return emesary.Transmitter.ReceiptStatus_OK;
}



### Missile notifications

# Missile launch and radar warning, bit of code extracted from damage.nas

var callsign = "";
var update_callsign = func(n) {
    callsign = str(n.getValue());
    if(size(callsign) > 7) callsign = left(callsign, 7);
}
setlistener("/sim/multiplay/callsign", update_callsign, 1, 0);

var launched = {};
var mlw_max=getprop("payload/d-config/mlw_max");

var missileRecipient = emesary.Recipient.new("RWRMissileRecipient");

missileRecipient.Receive = func(notification) {
    if (!notification.FromIncomingBridge
        or notification.NotificationType != "ArmamentInFlightNotification"
        or notification.RemoteCallsign != callsign
        or (!input.damage.getBoolValue() and !input.spectator.getBoolValue())) {
        return emesary.Transmitter.ReceiptStatus_NotProcessed;
    }

    if (bits.test(notification.Flags, 0)) {
        # Missile radar on
        signal(notification.Callsign~notification.UniqueIdentity, RWR_MISSILE, notification.Position);
    }

    if (bits.test(notification.Flags, 1)) {
        # Motor on
        var launch = launched[notification.Callsign~notification.UniqueIdentity];
        var elapsed = input.time.getValue();

        if (launch == nil or elapsed - launch > 300) {
            launched[notification.Callsign~notification.UniqueIdentity] = elapsed;

            var ac_pos = geo.aircraft_position();
            if (notification.Position.direct_distance_to(ac_pos)*M2NM < mlw_max) {
                signal(rand(), RWR_LAUNCH, notification.Position);
                bearing = geo.normdeg(ac_pos.course_to(notification.Position) - input.heading.getValue());
                radar.ecmLog.push("Missile launch warning from %03d deg.", bearing);
            }
        }
    }

    return emesary.Transmitter.ReceiptStatus_OK;
}



var init = func {
    # override generic radar functions
    radar.isOmniRadiating = isOmniRadiating;
    radar.getRadarFieldRadius = getRadarFieldRadius;

    emesary.GlobalTransmitter.Register(RWRRecipient);
    emesary.GlobalTransmitter.Register(missileRecipient);
}

var loop = func {
    update_rwr();
}
