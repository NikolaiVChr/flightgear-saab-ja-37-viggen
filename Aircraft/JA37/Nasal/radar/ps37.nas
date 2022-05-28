#### AJS 37 PS-37/A radar
#
# References: mostly AJS37 SFI part III
#

### Beam angle
#
# Normal search modes:
# range     altitude    pitch angle
#   15km    -           -3.0°
#   30km    > 600m      -3.0°
#   30km    < 600m      -1.5°
#   60km    > 600m      -1.0°
#   60km    < 600m      -0.5°
#   120km   -           -0.5°
#
# air target : +1.5°
# terrain avoidance : 0.0°
#
# In all search modes, modulable ±10° using potentiometer at the base of radar stick.

### Search pattern
#
# Wide: 61.5° half angle at 110°/s  (PPI)
# Narrow: 32° half angle at 60°/s   (B-scope)
# Search is centered straight ahead in all cases.
#
# For ranging / air target lock, radar is steered by the computer.
#
# Remark: While narrow mode is 32° wide, B-scope seems to display only 20° (centered straight ahead).

### Radar beam
#
# Frequency: 8.6-9.5GHz (microwaves, X-band)
#
# The radar has 4 transceivers in the antenna, in a square pattern
#  1 2
#  3 4
# They are combined in a sum signal Σ = 1+2+3+4,
# and difference signals, lateral Δk = (1+3) - (2+4), vertical Δj = (1+2) - (3+4)
# Δ-signals react most strongly to signals sligtly offset from the beam center,
# thus subtracting them from Σ improves the lateral resolution of the radar.
#
# In practice, only Δk or Δj is used at any time :
# Δk normally, Δj for terrain avoidance and air target modes
#
# Angle from beam centerline giving 10dB below centerline return strength, from diagrams:
#   Σ alone : around 3-4°
#   Σ - Δ   : around 2-3° (and sharper falloff)

### Signal processing
#
# LOG/LIN: LOG mode is "more nuanced" (preferred mode).
# Need to figure out the math here for that to make sense.
#
# MKR: potentiometer to manually adjust signal strength.
#
# adjustement: based on altitude, antenna angle, distance, to have targets at all range give the same signal.



var FALSE = 0;
var TRUE = 1;

var input = {
    radar_serv:         "instrumentation/radar/serviceable",
    range:              "instrumentation/radar/range",
    antenna_angle:      "instrumentation/radar/antenna-angle-norm",
    gear_pos:           "gear/gear/position-norm",
    quality:            "instrumentation/radar/ground-radar-quality",
    linear_gain:        "ja37/radar/panel/linear",
    gain:               "ja37/radar/panel/gain",
    filter:             "ja37/radar/panel/filter",
    display_alt:        "instrumentation/altimeter/displays-altitude-meter",
};

foreach(var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
};


### Radar parameters (used as subclass of AirborneRadar from radar.nas)

var PS37 = {
    # 65°, pointing 5.5° down
    fieldOfRegardMaxAz: 65,
    fieldOfRegardMaxElev: 59.5,
    fieldOfRegardMinElev: -70.5,
    # instantFoVradius * overlapHorizontal is the radar picture resolution in azimuth
    instantFoVradius: 4.0,
    overlapHorizontal: 0.5,
    rcsRefDistance: 40,
    rcsRefValue: 3.2,
    timeToKeepBleps: 5,

    # Tests if the radar is serviceable, not if it is on.
    isEnabled: func {
        return input.radar_serv.getBoolValue() and power.prop.hyd1Bool.getBoolValue()
          and power.prop.dcSecondBool.getBoolValue() and power.prop.acSecondBool.getBoolValue();
    },

    getTiltKnob: func {
        return input.antenna_angle.getValue() * 10;
    },

    getRangeM: func {
        return me.currentMode.getRangeM();
    },

    isNarrowBeam: func {
        return me.currentMode.isNarrowBeam();
    },

    useDistanceNorm: func {
        return me.currentMode.useDistanceNorm();
    },

    # Similar to setCurrentMode, but remembers current range and calls leaveMode()
    setMode: func(newMode) {
        newMode.setRange(me.currentMode.getRange());
        me.currentMode.leaveMode();
        me.setCurrentMode(newMode);
    },
};


### Radar ground mapper
#
# Called by the generic radar to run custom ground radar logic.

var PS37Map = {
    buffer: [],
    buffer_size: 64,

    init: func(radar) {
        me.radar = radar;
        me.radar.installMapper(me);

        me.angle_res = me.radar.instantFoVradius * me.radar.overlapHorizontal;

        setsize(me.buffer, me.buffer_size);
    },

    scanGM: func(azimuth, elevation, vert_radius, horiz_radius, contacts) {
        # Restrict range to what can be displayed on the CI.
        var clipped_buf_size = math.ceil(ci.azimuth_range(abs(azimuth) - me.angle_res/2, me.buffer_size, FALSE));
        var range = me.radar.getRangeM() * clipped_buf_size / me.buffer_size;
        var narrow = me.radar.isNarrowBeam();

        # Ground returns
        gnd_rdr.radar_query(self.getCoord(), self.getHeading(), azimuth, elevation,
                            range, narrow, me.buffer, clipped_buf_size);

        for (var i = clipped_buf_size; i < me.buffer_size; i+=1) {
            me.buffer[i] = 0.0;
        }

        # Aircraft returns
        gnd_rdr.aircraft_returns(azimuth, elevation, range, narrow, me.buffer, clipped_buf_size, contacts);

        # Signal normalisation
        # Do not use clipped range / buffer size here, it affects normalisation

        if (me.radar.useDistanceNorm()) {
            gnd_rdr.signal_norm_distance(me.buffer, me.buffer_size, me.radar.getRangeM(), input.display_alt.getValue());
        } else {
            gnd_rdr.signal_norm_basic(me.buffer, me.buffer_size, narrow);
        }

        gnd_rdr.signal_gain(me.buffer, me.buffer_size, input.gain.getValue(), input.linear_gain.getBoolValue());

        ci.ci.draw_radar_data(azimuth, me.angle_res, me.buffer);
    },

    clear_image: func {
        ci.ci.clear_radar_image();
    },

    # required by AirborneRadar, unused
    clear: func {},
};


### Radar modes

# Parent class: handles range

var PS37Mode = {
    parents: [RadarMode],

    radar: nil,

    # ranges in meter (unlike generic RadarMode)
    minRangeM: 15000,
    maxRangeM: 120000,
    rangeM: 60000,
    # make sure these are never used
    minRange: nil,
    maxRange: nil,
    range: nil,

    rcsFactor: 1,

    timeToFadeBleps: 5,
    pulse: MONO,
    detectSURFACE: 1,
    detectMARINE: 1,

    # Allow a contact to register twice in the same sweep due to beam overlap.
    minimumTimePerReturn: 0.0,

    rootName: "PS37",
    shortName: "",
    longName: "",

    setRangeM: func (range) {
        if (range < me.minRangeM or range > me.maxRangeM or math.mod(range, me.minRangeM) != 0) return 0;

        me.rangeM = range;
        return 1;
    },
    getRangeM: func {
        return me.rangeM;
    },

    # These _must_ be in NM (used by the rest of the code)
    setRange: func (range) {
        me.setRangeM(int(range * NM2M));
    },
    getRange: func {
        return me.rangeM * M2NM;
    },

    _increaseRange: func {
        if (me.rangeM <= me.maxRangeM/2) {
            me.rangeM *= 2;
            return 1;
        } else {
            return 0;
        }
    },
    _decreaseRange: func {
        if (me.rangeM >= me.minRangeM*2) {
            me.rangeM /= 2;
            return 1;
        } else {
            return 0;
        }
    },
    increaseRange: func {
        return me._increaseRange();
    },
    decreaseRange: func {
        return me._decreaseRange();
    },

    designate: func (contact) {},
    designatePriority: func (contact) {},
    undesignate: func {},

    # type of information given by this mode
    # [dist, groundtrack, deviations, speed, closing-rate, altitude]
    getSearchInfo: func (contact) {
        return me.active ? [1,0,1,0,0,1] : nil;
    },
};


# Main scan mode

var ScanMode = {
    parents: [PS37Mode],

    # scan patterns
    bars: 1,            # pattern index (1 based)
    # A point is a pair [azimuth, height]. azimuth unit is me.az, height unit is me.barHeight * instantFoVradius
    # A pattern is a vector of points
    # This is a vector of patterns (one per "scan mode")
    barPattern: [ [[1,0],[-1,0]] ],
    barHeight: 1,
    barPatternMin: [0],
    barPatternMax: [0],

    shortName: "Scan",
    longName: "Scan",

    # Submodes (affect antenna angle, beam width, filters)
    MODE_NORMAL: 1,
    MODE_TERRAIN: 2,
    MODE_RB04: 3,
    MODE_AIR: 4,

    mode: 1,

    set_submode: func(submode) { me.mode = submode; },
    get_submode: func { return me.mode; },

    # Beam elevation for normal search mode. Indexed by [range][alt > 600]
    normal_elev: {
        15000: [-3.0, -3.0],
        30000: [-1.5, -3.0],
        60000: [-0.5, -1.0],
        120000: [-0.5, -0.5],
    },

    # Must be defined by each mode, used to set azimuth / elevation offset
    preStep: func {
        me.azimuthTilt = 0;

        if (me.mode == me.MODE_AIR)
            me.elevationTilt = 1.5;
        elsif (me.mode == me.MODE_TERRAIN)
            me.elevationTilt = 0.0;
        else
            me.elevationTilt = me.normal_elev[me.getRangeM()][input.display_alt.getValue() > 600];

        me.elevationTilt += me.radar.getTiltKnob();
    },

    # Return true if radar beam is narrow in height (terrain / air mode),
    # false if it is narrow in width (default).
    isNarrowBeam: func {
        return me.mode == me.MODE_TERRAIN or me.mode == me.MODE_AIR;
    },

    # Indicates if radar returns strength should be normalised based on distance and altitude
    # ('styrd dämpning' in the manual)
    useDistanceNorm: func {
        if (me.mode == me.MODE_TERRAIN) return TRUE;

        var filter = input.filter.getBoolValue();
        if (me.mode == me.MODE_AIR) {
            return (filter == 1 or filter == 2 or filter == 7);
        } elsif (me.mode == me.MODE_RB04) {
            return (filter == 1 or filter == 2);
        } else {
            return (filter <= 2 or filter == 7);
        }
    },
};

# Subclasses for narrow/wide scan
var WideScanMode = {
    parents: [ScanMode],
    az: 61.5,           # width of search
    discSpeed_dps: 110, # sweep speed
};

var NarrowScanMode = {
    parents: [ScanMode],
    az: 32,             # width of search
    discSpeed_dps: 60,  # sweep speed
};


# Standby / special modes

var StandbyMode = {
    # Radar off, antenna parked
    parents: [PS37Mode],

    shortName: "RX",
    longName: "Standby",
    active: FALSE,

    az: 61.5,
    discSpeed_dps: 110,

    bars: 1,
    barPattern: [[[0,0]]],
    barHeight: 1,
    barPatternMin: [0],
    barPatternMax: [0],

    preStep: func {
        me.horizonStabilized = 0;
        me.azimuthTilt = 0;
        me.elevationTilt = 50;    # AJS37 SFI part 3 chap 6 sec 5.6 page 20
    },
};

var GroundRangingMode = {
    # Radar off, antenna centered. Actual ground ranging is simulated separately.
    parents: [PS37Mode],

    shortName: "RFX",
    longName: "Ground Ranging",
    active: FALSE,

    az: 61.5,           # width of search
    discSpeed_dps: 110, # sweep speed

    bars: 1,
    barPattern: [[[0,0]]],
    barHeight: 1,
    barPatternMin: [0],
    barPatternMax: [0],
};

var PassiveMode = {
    parents: [WideScanMode],

    shortName: "RBX",
    longName: "Passive Scan",
    active: FALSE,
};

var LockMode = {
    parents: [PS37Mode],
    # TODO
};


### Array of main mode, each being an array of submodes (not used except for initialization)
var ps37_modes = [[
    StandbyMode,
    PassiveMode,
    GroundRangingMode,
    WideScanMode,
    NarrowScanMode,
    LockMode,
]];

var ps37 = nil;


# Set PS37 mode based on controller RADAR_MODE output.

# Table of [mode, submode]. Indices match ps37_mode.RADAR_MODE.
var update_mode_table = [
    [StandbyMode, nil],                     # STBY
    [PassiveMode, nil],                     # PASSIVE
    [GroundRangingMode, nil],               # GND_RNG
    [WideScanMode, ScanMode.MODE_NORMAL],   # NORMAL
    [WideScanMode, ScanMode.MODE_TERRAIN],  # TERRAIN
    [WideScanMode, ScanMode.MODE_RB04],     # RB04
    [WideScanMode, ScanMode.MODE_AIR],      # AIR
    [LockMode, nil],                        # AIR_RNG
];

var update_mode = func {
    var new_mode = update_mode_table[ps37_mode.radar_mode][0];
    if (new_mode == WideScanMode and ps37_mode.scan_mode == ps37_mode.SCAN_MODE.NARROW)
        new_mode = NarrowScanMode;

    if (new_mode != ps37.currentMode)
        ps37.setMode(new_mode);

    var submode =  update_mode_table[ps37_mode.radar_mode][1];
    if (submode != nil and submode != new_mode.get_submode())
        new_mode.set_submode(submode);
}


## Controls

var increaseRange = func {
    ps37.increaseRange();
    input.range.setValue(ps37.getRangeM());
}

var decreaseRange = func {
    ps37.decreaseRange();
    input.range.setValue(ps37.getRangeM());
}

var terrain_mode = func {
    ps37_mode.terrain_mode();
}

var memory_mode = func {
    ps37_mode.memory_mode();
}

### Initialization

var init = func {
    init_generic();
    ps37 = AirborneRadar.newAirborne(ps37_modes, PS37);
    PS37Map.init(ps37);
    input.range.setValue(ps37.getRangeM());
}

var loop = func {
    # Mode selection logic in ps37_mode.nas
    ps37_mode.update_state();
    # Transmit to radar code
    update_mode();
}
