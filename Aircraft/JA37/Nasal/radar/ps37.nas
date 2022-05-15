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
    mode:               "instrumentation/radar/mode",
    range:              "instrumentation/radar/range",
    antenna_angle:      "instrumentation/radar/antenna-angle-norm",
    nose_wow:           "fdm/jsbsim/gear/unit[0]/WOW",
    gear_pos:           "gear/gear/position-norm",
    quality:            "instrumentation/radar/ground-radar-quality",
    linear_gain:        "ja37/radar/panel/linear",
    gain:               "ja37/radar/panel/gain",
    filter:             "ja37/radar/panel/filter",
    passive_mode:       "ja37/radar/panel/passive",
    selector_ajs:       "ja37/mode/selector-ajs",
    wpn_knob:           "/controls/armament/weapon-panel/selector-knob",
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
    instantFoVradius: 2.0,
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

    terrainMode: func {
        me.currentMode.terrainMode();
    },

    memoryMode: func {
        me.currentMode.memoryMode();
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

        setsize(me.buffer, me.buffer_size);
    },

    scanGM: func(azimuth, elevation, vert_radius, horiz_radius) {
        # Restrict range to what can be displayed on the CI.
        var clipped_buf_size = math.ceil(ci.azimuth_range(abs(azimuth) - horiz_radius, me.buffer_size, FALSE));
        var range = me.radar.getRangeM() * clipped_buf_size / me.buffer_size;

        gnd_rdr.radar_query(self.getCoord(), self.getHeading(), azimuth, elevation,
                            range, me.radar.isNarrowBeam(), me.buffer, clipped_buf_size);

        for (var i = clipped_buf_size; i < me.buffer_size; i+=1) {
            me.buffer[i] = 0.0;
        }

        # Do not use clipped range / buffer size here, it affects normalisation

        if (me.radar.useDistanceNorm()) {
            gnd_rdr.signal_norm_distance(me.buffer, me.buffer_size, me.radar.getRangeM(), input.display_alt.getValue());
        } else {
            gnd_rdr.signal_norm_basic(me.buffer, me.buffer_size, me.radar.isNarrowBeam());
        }

        gnd_rdr.signal_gain(me.buffer, me.buffer_size, input.gain.getValue(), input.linear_gain.getBoolValue());

        ci.ci.draw_radar_data(azimuth, horiz_radius*2, me.buffer);
    },

    clear_image: func {
        ci.ci.clear_radar_image();
    },

    # required by AirborneRadar, unused
    clear: func {},
};


### Parent class for radar modes

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

    # scan patterns
    bars: 1,            # pattern index (1 based)
    # A point is a pair [azimuth, height]. azimuth unit is me.az, height unit is me.barHeight * instantFoVradius
    # A pattern is a vector of points
    # This is a vector of patterns (one per "scan mode")
    barPattern: [ [[1,0],[-1,0]] ],
    barHeight: 1,
    barPatternMin: [0],
    barPatternMax: [0],

    rcsFactor: 1,

    timeToFadeBleps: 5,
    pulse: MONO,
    detectSURFACE: 1,
    detectMARINE: 1,

    air_mode: FALSE,

    # Terrain avoidance submode
    has_terrain_mode: FALSE,    # whether terrain mode can be selected
    terrain_mode: FALSE,

    # Memory submode
    has_memory_mode: FALSE,     # whether memory mode can be selected

    rootName: "PS37",
    shortName: "",
    longName: "",

    # Beam elevation for normal search mode. Indexed by [range][alt > 600]
    normal_elev: {
        15000: [-3.0, -3.0],
        30000: [-1.5, -3.0],
        60000: [-0.5, -1.0],
        120000: [-0.5, -0.5],
    },

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

    # Must be defined by each mode, used to set azimuth / elevation offset
    preStep: func {
        me.azimuthTilt = 0;

        if (me.air_mode)
            me.elevationTilt = 1.5;
        elsif (me.terrain_mode)
            me.elevationTilt = 0.0;
        else
            me.elevationTilt = me.normal_elev[me.getRangeM()][input.display_alt.getValue() > 600];

        me.elevationTilt += me.radar.getTiltKnob();
    },

    # type of information given by this mode
    # [dist, groundtrack, deviations, speed, closing-rate, altitude]
    getSearchInfo: func (contact) {
        return [1,0,1,0,0,1];
    },

    # Return true if radar beam is narrow in height (terrain / air mode),
    # false if it is narrow in width (default).
    isNarrowBeam: func {
        return me.air_mode or me.terrain_mode;
    },

    # Indicates if radar returns strength should be normalised based on distance and altitude
    # ('styrd dämpning' in the manual)
    useDistanceNorm: func {
        # TODO
        return input.filter.getBoolValue();
    },

    terrainMode: func {
        if (!me.has_terrain_mode) return FALSE;

        me.terrain_mode = TRUE;
        return TRUE;
    },

    memoryMode: func {
        if (!me.has_memory_mode or me.terrain_mode) return FALSE;

        StandbyMode.memoryModeFrom(me);
        return TRUE;
    },

    enterMode: func {
        me.terrain_mode = FALSE;
    },
};

# Sweep parameters
var WideScanMode = {
    parents: [PS37Mode],
    az: 61.5,           # width of search
    discSpeed_dps: 110, # sweep speed
};

var NarrowScanMode = {
    parents: [PS37Mode],
    az: 32,             # width of search
    discSpeed_dps: 60,  # sweep speed
};


# Standby modes

var StandbyMode = {
    # Radar off, antenna parked
    parents: [PS37Mode],

    shortName: "RX",
    longName: "Standby",
    active: FALSE,

    az: 61.5,           # width of search
    discSpeed_dps: 110, # sweep speed
    barPattern: [[[-1,0]]],

    # calling mode, when used for memory mode
    parent_mode: nil,

    # Terrain mode overrides memory mode
    terrainMode: func {
        if (me.parent_mode == nil or !me.parent_mode.has_terrain_mode) return FALSE;

        me.radar.setMode(me.parent_mode);
        return me.parent_mode.terrainMode();
    },

    # Called by other modes when entering memory mode
    memoryModeFrom: func(parent_mode) {
        me.parent_mode = parent_mode;
        me.radar.setMode(me);
    },

    preStep: func {
        me.horizonStabilized = 0;
        me.azimuthTilt = 0;
        me.elevationTilt = 0;
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
    barPattern: [[[0,0]]],
};

var PassiveMode = {
    parents: [WideScanMode],

    shortName: "RBX",
    longName: "Passive Scan",
    active: FALSE,
};

# Normal scan modes (including terrain / memory submodes)

var NormalWideMode = {
    parents: [WideScanMode],

    shortName: "RBK",
    longName: "Wide Scan",
    has_terrain_mode: TRUE,
    has_memory_mode: TRUE,
};

var NormalNarrowMode = {
    parents: [NarrowScanMode],

    shortName: "RSK",
    longName: "Narrow Scan",
    has_terrain_mode: TRUE,
    has_memory_mode: FALSE,
};

# Some weapons use normal scan mode, but disable terrain submode.

var CombatWideMode = {
    parents: [NormalWideMode],

    shortName: "RBK-ANF",
    longName: "Wide Scan ANF",
    has_terrain_mode: FALSE,
};

var CombatNarrowMode = {
    parents: [NormalNarrowMode],

    shortName: "RSK-ANF",
    longName: "Narrow Scan ANF",
    has_terrain_mode: FALSE,
};

# A/A modes

var AirWideMode = {
    parents: [WideScanMode],

    shortName: "RBJR",
    longName: "A/A Wide Scan",
    air_mode: TRUE,
};

var AirNarrowMode = {
    parents: [NarrowScanMode],

    shortName: "RSJR",
    longName: "A/A Narrow Scan",
    air_mode: TRUE,
};

var LockMode = {
    parents: [PS37Mode],
    # TODO
};


### Array of main mode, each being an array of submodes (not used)
var ps37_modes = [[
    StandbyMode,
    GroundRangingMode,
    PassiveMode,
    NormalWideMode,
    NormalNarrowMode,
    CombatWideMode,
    CombatNarrowMode,
    AirWideMode,
    AirNarrowMode,
    LockMode,
]];

var ps37 = nil;



### Controls

var increaseRange = func {
    ps37.increaseRange();
    input.range.setValue(ps37.getRangeM());
}

var decreaseRange = func {
    ps37.decreaseRange();
    input.range.setValue(ps37.getRangeM());
}

var memory_mode = func {
    ps37.memoryMode();
}

var terrain_mode = func {
    ps37.terrainMode();
}


var current_mode = StandbyMode;

# This function returns the mode to be currently used.
var choose_current_mode = func {
    # Radar enable conditions
    if (input.nose_wow.getBoolValue() or modes.selector_ajs <= modes.STBY)
        return StandbyMode;

    var mode = NormalWideMode;

    # All the weird rules for weapon modes
    if (input.selector_ajs.getValue() == modes.COMBAT) {
        var type = fire_control.get_type();
        var wpn_knob = input.wpn_knob.getValue();

        if (type == "IR-RB"
            or (type == "M55" and wpn_knob == fire_control.WPN_SEL.AKAN_JAKT)
            or (type == "RB-05A" and wpn_knob == fire_control.WPN_SEL.RR_LUFT))
        {
            mode = (current_mode == LockMode) ? LockMode : AirWideMode;
        }
        elsif (type == "RB-04E" or type == "RB-15F" or type == "M90")
        {
            # Should be RB04 mode, which is slightly different.
            mode = CombatWideMode;
        }
        elsif ((type == "RB-05A" and wpn_knob == fire_control.WPN_SEL.PLAN_SJO)
               or (type == "M71" and wpn_knob == fire_control.WPN_SEL.RR_LUFT))
        {
            mode = CombatWideMode;
        }
        elsif (type == "M70" or type == "RB-75"
               or (type == "RB-05A" and wpn_knob == fire_control.WPN_SEL.DYK_MARK_RB75)
               or (type == "M55" and wpn_knob == fire_control.WPN_SEL.ATTACK)
               or (type == "M71" and wpn_knob != fire_control.WPN_SEL.RR_LUFT))
        {
            mode = GroundRangingMode;
        }
    }

    # Rest of the logic doesn't apply to the A/G ranging mode.
    if (mode == GroundRangingMode) return mode;

    # A0 gives standby or passive mode.
    if (input.mode.getValue() == 0) {
        return input.passive_mode.getBoolValue() ? PassiveMode : StandbyMode;
    }

    # Switch to corresponding narrow mode as required.
    if (input.mode.getValue() == 2) {
        if (mode == NormalWideMode) return NormalNarrowMode;
        if (mode == CombatWideMode) return CombatNarrowMode;
        if (mode == AirWideMode)    return AirNarrowMode;
    }
    return mode;
}

var update_current_mode = func {
    var mode = choose_current_mode();
    if (mode == current_mode) return;

    print("Radar mode "~mode.shortName);
    ps37.setMode(mode);
    current_mode = mode;
}


### Initialization

var init = func {
    init_generic();
    ps37 = AirborneRadar.newAirborne(ps37_modes, PS37);
    PS37Map.init(ps37);
    input.range.setValue(ps37.getRangeM());
    update_current_mode();
}

var loop = func {
    update_current_mode();
}
