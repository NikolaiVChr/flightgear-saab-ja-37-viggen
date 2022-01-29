#### JA 37D PS/46A radar

var FALSE = 0;
var TRUE = 1;

var input = {
    radar_serv:         "instrumentation/radar/serviceable",
    antenna_angle:      "instrumentation/radar/antenna-angle-norm",
    nose_wow:           "fdm/jsbsim/gear/unit[0]/WOW",
    gear_pos:           "gear/gear/position-norm",
};

foreach(var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
};


### Radar parameters (used as subclass of AirborneRadar from radar.nas)

var PS46 = {
    # need source for all of these
    fieldOfRegardMaxAz: 60,     # to match MI
    fieldOfRegardMaxElev: 60,
    instantFoVradius: 2.0,
    instantVertFoVradius: 2.5,  # unused (could be used by ground mapper)
    instantHoriFoVradius: 1.5,  # unused
    rcsRefDistance: 40,
    rcsRefValue: 3.2,
    maxTilt: 60,

    # If radar get turned off by WoW (or failure) it stays off.
    isEnabled: func {
        return me.enabled and input.radar_serv.getBoolValue()
          and !input.nose_wow.getBoolValue() and power.prop.hyd1Bool.getBoolValue()
          and power.prop.dcSecondBool.getBoolValue() and power.prop.acSecondBool.getBoolValue();
    },

    enable: func {
        me.enabled = 1;
        me.enabled = me.isEnabled();
    },
    disable: func {
        me.enabled = 0;
    },
    toggle: func {
        if (me.enabled) me.disable();
        else me.enable();
    },

    getTiltKnob: func {
        return input.antenna_angle.getValue() * 10;
    },

    # Similar to setCurrentMode, but remembers current target and range
    setMode: func(newMode, priority=nil, old_priority=0) {
        newMode.setRange(me.currentMode.getRange());
        if (priority == nil and old_priority) priority = me.currentMode["priorityTarget"];
        me.currentMode.leaveMode();
        me.setCurrentMode(newMode, priority);
    },
};


### Parent class for PS/46 modes

var PS46Mode = {
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

    az: 60,             # width of search (matches MI)
    discSpeed_dps: 60,  # sweep speed (estimated from MI video)

    # scan patterns
    bars: 1,            # pattern index (1 based)
    # A point is a pair [azimuth, height]. azimuth unit is me.az, height unit is me.barHeight * instantFoVradius
    # A pattern is a vector of points
    # This is a vector of patterns (one per "scan mode")
    #
    # From a MI video, the vertical scan is around 1/10 radian ~= 6deg
    barPattern: [ [[1,3],[-1,3],[-1,1],[1,1],[1,-1],[-1,-1],[-1,-3],[1,-3]] ],
    barHeight: 0.75,
    barPatternMin: [-3],
    barPatternMax: [3],

    timeToKeepBleps: 13,

    rcsFactor: 1,

    rootName: "PS46",
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

    setCursorDistance: func(nm) {
        me.cursorNm = math.clamp(nm, 0, me.getRange());
        return 0;
    },

    # Must be defined by each mode, used to set azimuth / elevation offset
    preStep: func {
        var az_limit = me.radar.fieldOfRegardMaxAz - me.az;
        me.azimuthTilt = math.clamp(me.cursorAz, -az_limit, az_limit);
        me.elevationTilt = me.radar.getTiltKnob();
    },

    # type of information given by this mode
    # [dist, groundtrack, deviations, speed, closing-rate, altitude]
    getSearchInfo: func (contact) {
        return [1,0,1,0,0,1];
    },
};


var ScanMode = {
    parents: [PS46Mode],

    shortName: "Scan",
    longName: "Wide Scan",

    designate: func (contact) {
        if (contact == nil) return;
        STT(contact);
    },

    designatePriority: func (contact) {
        me.designate(contact);
    },

    undesignate: func {},
};


var TWSMode = {
    parents: [PS46Mode],

    shortName: "TWS",
    longName: "Track While Scan",

    az: 30,
    priorityTarget: nil,
    tracks: [],
    max_tracks: 4,

    designate: func (contact) {
    },

    designatePriority: func (contact) {
    },

    undesignate: func {
    },

    # type of information given by this mode
    # [dist, groundtrack, deviations, speed, closing-rate, altitude]
    getSearchInfo: func (contact) {
        return [1,0,1,0,0,1];
    },
};


var DiskSearchMode = {
    parents: [PS46Mode],

    shortName: "Disk",
    longName: "Disk Search",

    rangeM: 15000,
    minRangeM: 15000,
    maxRangeM: 15000,

    discSpeed_dps: 90,
    rcsFactor: 0.9,

    # scan patterns (~ 20x20 deg square)
    bars: 1,            # pattern index (1 based)
    # A point is a pair [azimuth, height]. azimuth unit is me.az, height unit is me.barHeight * instantFoVradius
    # A pattern is a vector of points
    # This is a vector of patterns (one per "scan mode")
    barPattern: [ [[-1,5],[1,5],[1,3],[-1,3],[-1,1],[1,1],[1,-1],[-1,-1],[-1,-3],[1,-3],[1,-5],[-1,-5]] ],
    barHeight: 0.9,
    barPatternMin: [-5],
    barPatternMax: [5],

    preStep: func {
        me.radar.horizonStabilized = 0;
        me.azimuthTilt = 0;
        me.elevationTilt = -7;
    },

    designate: func (contact) {
    },

    designatePriority: func (contact) {
    },

    undesignate: func {
    },

    getSearchInfo: func (contact) {
        return nil;
    },
};


var STTMode = {
    parents: [PS46Mode],

    shortName: "STT",
    longName: "Single Target Track",

    rcsFactor: 1.1,
    az: PS46.instantFoVradius * 0.8,

    discSpeed_dps: 90,

    # scan patterns
    bars: 1,            # pattern index (1 based)
    # A point is a pair [azimuth, height]. azimuth unit is me.az, height unit is me.barHeight * instantFoVradius
    # A pattern is a vector of points
    # This is a vector of patterns (one per "scan mode")
    barPattern: [ [[-1,-1],[1,-1],[1,1],[-1,1]] ],
    barHeight: 0.8,
    barPatternMin: [-1],
    barPatternMax: [1],

    minimumTimePerReturn: 0.10,
    timeToKeepBleps: 5,
    painter: 1,
    priorityTarget: nil,

    preStep: func {
        if (me.priorityTarget == nil or me.priorityTarget.getLastBlep() == nil
            or !me.radar.containsVectorContact(me.radar.vector_aicontacts_bleps, me.priorityTarget))
        {
            me.undesignate();
            return;
        }

        var lastBlep = me.priorityTarget.getLastBlep();
        var range = lastBlep.getRangeNow() * M2NM;
        if (range > me.getRange()) {
            me.undesignate();
            return;
        }

        me.azimuthTilt = lastBlep.getAZDeviation();
        me.elevationTilt = lastBlep.getElev(); # tilt here is in relation to horizon

        me.cursorAz = me.azimuthTilt;
        me.cursorNm = range;

        var az_limit = me.radar.fieldOfRegardMaxAz - me.az;
        me.azimuthTilt = math.clamp(me.azimuthTilt, -az_limit, az_limit);
    },

    designate: func (contact) {},

    designatePriority: func (contact) {
        me.priorityTarget = contact;
    },

    undesignate: func {
        me.priorityTarget = nil;
        quit_STT();
    },

    # Cursor is ignored (internal cursor = target)
    setCursorDistance: func(nm) {},
    setCursorDeviation: func(az) {},

    # type of information given by this mode
    # [dist, groundtrack, deviations, speed, closing-rate, altitude]
    getSearchInfo: func (contact) {
        if (me.priorityTarget != nil and contact.equals(me.priorityTarget)) {
            return [1,1,1,1,1,1];
        }
        return nil;
    },
};



### Array of main mode, each being an array of submodes.

var ps46_modes = [
    [ScanMode],
    [TWSMode],
    [DiskSearchMode],
    [STTMode],
];

var ps46 = nil;



### Controls

var tws = FALSE;   # Rember last main mode (Scan or TWS)


# Used for designate() / undesignate()
var STT = func(contact) {
    ps46.setMode(STTMode, contact);
}

var quit_STT = func {
    if (tws) TWS();
    else scan();
}

# Throttle buttons

var scan = func {
    tws = FALSE;
    ps46.setMode(ScanMode);
}

var TWS = func {
    tws = TRUE;
    ps46.setMode(TWSMode, nil, TRUE);   # keep track from previous mode
}

var toggle_radar_on = func {
    if (modes.main_ja == modes.AIMING) {
        # In aiming mode, this button turns radar off instead
        ps46.disable();
    } else {
        ps46.toggle();
    }
}

var disk_search = func {
    # aiming mode, radar on, disk search
    if (modes.main_ja != modes.NAV or modes.main_ja != modes.AIMING) return;
    if (input.gear_pos.getValue() > 0) return;

    modes.main_ja = modes.AIMING;
    ps46.enable();
    ps46.setMode(DiskSearchMode);
}



var increaseRange = func {
    ps46.increaseRange();
}

var decreaseRange = func {
    ps46.decreaseRange();
}



### Initialization

var init = func {
    init_generic();
    ps46 = AirborneRadar.newAirborne(ps46_modes, PS46);
}
