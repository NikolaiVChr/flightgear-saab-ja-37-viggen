#### AJS 37 PS-37/A radar

var FALSE = 0;
var TRUE = 1;

var input = {
    radar_serv:         "instrumentation/radar/serviceable",
    radar_mode:         "instrumentation/radar/mode",
    radar_range:        "instrumentation/radar/range",
    antenna_angle:      "instrumentation/radar/antenna-angle-norm",
    nose_wow:           "fdm/jsbsim/gear/unit[0]/WOW",
    gear_pos:           "gear/gear/position-norm",
};

foreach(var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
};


### Radar parameters (used as subclass of AirborneRadar from radar.nas)

var PS37 = {
    fieldOfRegardMaxAz: 61.5,
    fieldOfRegardMaxElev: 61.5,
    fieldOfRegardMinElev: -61.5,
    instantFoVradius: 3.0,
    instantVertFoVradius: 4.0,  # unused (could be used by ground mapper)
    instantHoriFoVradius: 2.0,  # unused
    rcsRefDistance: 40,
    rcsRefValue: 3.2,
    timeToKeepBleps: 5,

    isEnabled: func {
        return input.radar_mode.getBoolValue() and input.radar_serv.getBoolValue()
          and !input.nose_wow.getBoolValue() and power.prop.hyd1Bool.getBoolValue()
          and power.prop.dcSecondBool.getBoolValue() and power.prop.acSecondBool.getBoolValue();
    },

    getTiltKnob: func {
        return input.antenna_angle.getValue() * 10;
    },

    getRangeM: func {
        return me.currentMode.getRangeM();
    },
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

    rcsFactor: 1,

    timeToFadeBleps: 5,
    pulse: MONO,
    detectSURFACE: 1,
    detectMARINE: 1,

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

    # Must be defined by each mode, used to set azimuth / elevation offset
    preStep: func {
        me.azimuthTilt = 0;
        me.elevationTilt = me.radar.getTiltKnob();
    },

    # type of information given by this mode
    # [dist, groundtrack, deviations, speed, closing-rate, altitude]
    getSearchInfo: func (contact) {
        return [1,0,1,0,0,1];
    },
};


var ScanMode = {
    parents: [PS37Mode],

    shortName: "Scan",
    longName: "Wide Scan",

    # From AJS37 SFI part 3
    az: 61.5,           # width of search
    discSpeed_dps: 110, # sweep speed

    # scan patterns
    bars: 1,            # pattern index (1 based)
    # A point is a pair [azimuth, height]. azimuth unit is me.az, height unit is me.barHeight * instantFoVradius
    # A pattern is a vector of points
    # This is a vector of patterns (one per "scan mode")
    barPattern: [ [[1,0],[-1,0]] ],
    barHeight: 1,
    barPatternMin: [0],
    barPatternMax: [0],
};



### Array of main mode, each being an array of submodes.

var ps37_modes = [
    [ScanMode],
];

var ps37 = nil;



### Controls

var increaseRange = func {
    ps37.increaseRange();
    input.radar_range.setValue(ps37.getRangeM());
}

var decreaseRange = func {
    ps37.decreaseRange();
    input.radar_range.setValue(ps37.getRangeM());
}


### Initialization

var init = func {
    init_generic();
    ps37 = AirborneRadar.newAirborne(ps37_modes, PS37);
    input.radar_range.setValue(ps37.getRangeM());
}
