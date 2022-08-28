#### JA 37D PS-46/A radar
#
# Based on Nikolai V. Chr. F-16 radar

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
    fieldOfRegardMinElev: -60,
    instantFoVradius: 2.0,
    instantVertFoVradius: 2.5,  # unused (could be used by ground mapper)
    instantHoriFoVradius: 1.5,  # unused
    rcsRefDistance: 40,
    rcsRefValue: 3.2,
    timeToKeepBleps: 13,
    tiedIFF: TRUE,
    IFFFoVradius: 5.0,

    # If radar get turned off by WoW (or failure) it stays off.
    isEnabled: func {
        return me.enabled and displays.common.radar_on and input.radar_serv.getBoolValue()
          and !input.nose_wow.getBoolValue() and power.prop.hyd1Bool.getBoolValue()
          and power.prop.dcSecondBool.getBoolValue() and power.prop.acSecondBool.getBoolValue();
    },

    enable: func {
        if (me.enabled) return;
        me.enabled = 1;
        # Check if the conditions to turn on are met.
        me.enabled = me.isEnabled();
        if (me.enabled) {
            ecmLog.push("Radar switched active");
        }
    },
    disable: func {
        if (me.enabled) {
            ecmLog.push("Radar switched silent");
        }
        me.enabled = 0;
    },
    toggle: func {
        if (me.enabled) me.disable();
        else me.enable();
    },

    getTiltKnob: func {
        return input.antenna_angle.getValue() * 20;
    },

    # Similar to setCurrentMode, but remembers current target and range
    setMode: func(newMode, priority=nil, old_priority=0) {
        newMode.setRange(me.currentMode.getRange());
        if (priority == nil and old_priority) priority = me.currentMode["priorityTarget"];
        me.currentMode.leaveMode();
        me.setCurrentMode(newMode, priority);
    },

    getRangeM: func {
        return me.currentMode.getRangeM();
    },

    getTracks: func {
        return me.currentMode.getTracks();
    },

    isTracking: func(contact) {
        return me.currentMode.isTracking(contact);
    },

    isPrimary: func(contact) {
        return contact.equals(me.getPriorityTarget());
    },

    runIFF: func(contact) {
        var friendly = faf.is_friend(contact.getCallsign()) or iff.interrogate(contact.prop);
        contact.iff_time = me.elapsed;
        contact.iff = friendly ? 1 : -1;
        if (me.isTracking(contact)) {
            contact.last_tracking = me.elapsed;
            contact.stored_iff = contact.iff;
        }
    },

    updateStoredIFF: func(contact, tracking) {
        if (!tracking) {
            contact.stored_iff = 0;
            return;
        }

        if (!contains(contact, "last_tracking") or me.elapsed - contact.last_tracking > 10) {
            contact.stored_iff = 0; # lost track
        }
        contact.last_tracking = me.elapsed;
    },
};


### Parent class for radar modes

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

    rcsFactor: 1,

    timeToFadeBleps: 13,
    pulse: DOPPLER,

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

    isTracking: func(contact) {
        return 0;
    },

    # Must be defined by each mode, used to set azimuth / elevation offset
    preStep: func {
        me.azimuthTilt = me.cursorAz;
        me.constrainAz();
        me.elevationTilt = me.radar.getTiltKnob();
    },

    # type of information given by this mode
    # [dist, groundtrack, deviations, speed, closing-rate, altitude]
    getSearchInfo: func (contact) {
        ps46.updateStoredIFF(contact, 0);
        return [1,0,1,0,0,1];
    },

    getTracks: func {
        var prio = me.getPriority();
        return prio != nil ? [prio] : [];
    },
};


var ScanMode = {
    parents: [PS46Mode],

    shortName: "Scan",
    longName: "Wide Scan",

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
    barHeight: 0.8,
    barPatternMin: [-3],
    barPatternMax: [3],


    designate: func (contact) {
        if (contact == nil) return;
        STT_contact(contact);
    },

    designatePriority: func (contact) {
        me.designate(contact);
    },

    undesignate: func {},

    preStep: func {
        me.azimuthTilt = 0;
        me.elevationTilt = me.radar.getTiltKnob();
    },
};


var TWSMode = {
    parents: [PS46Mode],

    shortName: "TWS",
    longName: "Track While Scan",

    az: 30,
    discSpeed_dps: 60,

    bars: 1,
    barPattern: [ [[1,0],[-1,0],[-1,2],[1,2],[1,0],[-1,0],[-1,-2],[1,-2]] ],
    barHeight: 0.8,
    barPatternMin: [-2],
    barPatternMax: [2],

    max_scan_interval: 6.5,
    priorityTarget: nil,
    # Tracks, sorted from oldest to newest
    tracks: [],
    priority_index: -1,
    max_tracks: 4,


    _removeTrack: func(contact) {
        forindex (var i; me.tracks) {
            if (contact.equals(me.tracks[i])) {
                me._removeTrackIndex(i);
                return;
            }
        }
    },

    _removeTrackIndex: func(i) {
        if (i >= size(me.tracks)) return;
        me.tracks = subvec(me.tracks, 0, i) ~ subvec(me.tracks, i+1);

        if (i == me.priority_index) me.undesignate();
        elsif (i < me.priority_index) me.priority_index -= 1;
    },

    designate: func(contact) {
        if (contact == nil) return;

        forindex (var i; me.tracks) {
            if (contact.equals(me.tracks[i])) {
                me.priorityTarget = me.tracks[i];
                me.priority_index = i;
                return;
            }
        }

        lockLog.push(sprintf("Radar lock on to %s", contact.getCallsign()));

        if (size(me.tracks) == me.max_tracks) {
            me._removeTrackIndex(0);    # remove oldest
        }

        me.priority_index = size(me.tracks);
        me.priorityTarget = contact;
        append(me.tracks, contact);
        return;
    },

    designatePriority: func(contact) {
        me.designate(contact);
    },

    undesignate: func {
        me.priorityTarget = nil;
        me.priority_index = -1;
    },

    prunedContact: func(contact) {
        if (contact.equals(me.priorityTarget)) {
            me.priorityTarget = nil;
            me.priority_index = -1;
        }
        me._removeTrack(contact);
    },

    leaveMode: func {
        me.tracks = [];
        me.priority_index = -1;
        me.priorityTarget = nil;
    },

    cycleDesignate: func {
        if (size(me.tracks) == 0) return;

        if (me.priorityTarget == nil) {
            me.priority_index = 0;
        } else {
            me.priority_index += 1;
            if (me.priority_index >= size(me.tracks)) me.priority_index = 0;
        }

        me.priorityTarget = me.tracks[me.priority_index];
    },

    preStep: func {
        var lastBlep = nil;

        # Retrieve last target info, or remove priority target
        if (me.priorityTarget != nil) {
            lastBlep = me.priorityTarget.getLastBlep();
            if (lastBlep == nil) me.priorityTarget = nil;
        }

        if (me.priorityTarget != nil) {
            var range = lastBlep.getRangeNow() * M2NM;

            me.azimuthTilt = lastBlep.getAZDeviation();
            me.elevationTilt = lastBlep.getElev(); # tilt here is in relation to horizon
            me.constrainAz();

            me.cursorAz = me.azimuthTilt;
            me.cursorNm = range;
        } else {
            me.azimuthTilt = me.cursorAz;
            me.elevationTilt = me.radar.getTiltKnob();
            me.constrainAz();
        }
    },

    isTracking: func(contact) {
        foreach (var track; me.tracks) {
            if (contact.equals(track)) return 1;
        }
        return 0;
    },

    # type of information given by this mode
    # [dist, groundtrack, deviations, speed, closing-rate, altitude]
    getSearchInfo: func (contact) {
        foreach (var track; me.tracks) {
            if (contact.equals(track) and me.radar.elapsed - contact.getLastBlepTime() < me.max_scan_interval) {
                ps46.updateStoredIFF(contact, 1);
                return [1,1,1,1,1,1];
            }
        }
        ps46.updateStoredIFF(contact, 0);
        return [1,0,1,0,0,1];
    },

    getTracks: func {
        return me.tracks;
    },
};


var DiskSearchMode = {
    parents: [PS46Mode],

    shortName: "Disk",
    longName: "Disk Search",

    rangeM: 15000,

    discSpeed_dps: 90,
    rcsFactor: 0.9,

    # scan patterns (~ 20x20 deg disk)
    az: 10,
    bars: 1,
    barPattern: [ [[-1,1],[1,1],[0.8,3],[-0.8,3],[-0.5,5],[0.5,5],[0.5,-5],[-0.5,-5],[-0.8,-3],[0.8,-3],[1,-1],[-1,-1]] ],
    barHeight: 0.9,
    barPatternMin: [-5],
    barPatternMax: [5],

    preStep: func {
        me.radar.horizonStabilized = 0;
        me.azimuthTilt = 0;
        me.elevationTilt = -5;
    },

    designate: func (contact) {},

    designatePriority: func (contact) {},

    undesignate: func {},

    increaseRange: func {
        return 0;
    },
    decreaseRange: func {
        return 0;
    },
    setRange: func {
        return 0;
    },

    getSearchInfo: func (contact) {
        # This gets called as soon as the radar finds something -> autolock
        STT_contact(contact);
        ps46.updateStoredIFF(contact, 1);
        return [1,1,1,1,1,1];
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
    timeToFadeBleps: 5,
    painter: 1,
    priorityTarget: nil,

    parent_mode: nil,

    preStep: func {
        if (me.priorityTarget == nil or me.priorityTarget.getLastBlep() == nil
            or !me.radar.containsVectorContact(me.radar.vector_aicontacts_bleps, me.priorityTarget))
        {
            me.undesignate();
            return;
        }

        var lastBlep = me.priorityTarget.getLastBlep();
        var range = lastBlep.getRangeNow() * M2NM;

        me.azimuthTilt = lastBlep.getAZDeviation();
        me.elevationTilt = lastBlep.getElev(); # tilt here is in relation to horizon
        me.constrainAz();

        me.cursorAz = me.azimuthTilt;
        me.cursorNm = range;
    },

    designate: func (contact) {},

    designatePriority: func (contact) {
        me.priorityTarget = contact;
        lockLog.push(sprintf("Radar lock on to %s", contact.getCallsign()));
    },

    undesignate: func {
        me.priorityTarget = nil;
        me.radar.setMode(me.parent_mode);
    },

    # Cursor is ignored (internal cursor = target)
    setCursorDistance: func(nm) {},
    setCursorDeviation: func(az) {},

    isTracking: func(contact) {
        return contact.equals(me.priorityTarget);
    },

    # type of information given by this mode
    # [dist, groundtrack, deviations, speed, closing-rate, altitude]
    getSearchInfo: func (contact) {
        if (me.priorityTarget != nil and contact.equals(me.priorityTarget)) {
            ps46.updateStoredIFF(contact, 1);
            return [1,1,1,1,1,1];
        } else {
            ps46.updateStoredIFF(contact, 0);
            return nil;
        }
    },
};



# Conditions to report as friendly (for displays)
var test_iff = func(contact) {
    if (!contains(contact, "iff") or !contains(contact, "iff_time")
        or elapsedProp.getValue() - contact.iff_time > 10)
        return 0;
    else
        return contact.iff;
}

var stored_iff = func(contact) {
    if (!contains(contact, "stored_iff") or !contains(contact, "last_tracking")
        or elapsedProp.getValue() - contact.last_tracking > 10)
        return 0;
    else
        return contact.stored_iff;
}



### Array of main mode, each being an array of submodes.

var ps46_modes = [
    [ScanMode],
    [TWSMode],
    [DiskSearchMode],
    [STTMode],
];

var ps46 = nil;



### Controls

# Parent mode is the current mode calling STT.
# STT mode will return to parent when losing lock.
# STT mode also uses the parent mode logic for range.
var STT_contact = func(contact) {
    STTMode.parent_mode = ps46.currentMode;
    ps46.setMode(STTMode, contact);
}


# Throttle buttons

var scan = func {
    ps46.setMode(ScanMode);
}

var TWS = func {
    ps46.setMode(TWSMode, nil, TRUE);   # keep track from previous mode
}

var toggle_STT_TWS = func {
    # Toggle STT / TWS. When there is no primary target,
    # this toggles the mode which will be obtain after designation.
    if (radar.ps46.getPriorityTarget() != nil) {
        if (radar.ps46.getMode() == "TWS") {
            STT_contact(radar.ps46.getPriorityTarget());
        } else {
            TWS();
        }
    } else {
        MI.mi.toggleCursorMode();
    }
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
    if (input.gear_pos.getValue() > 0) return;

    modes.main_ja = modes.AIMING;
    ps46.enable();
    ps46.setMode(DiskSearchMode);
}

var cycle_target = func {
    ps46.cycleDesignate();
}

var increaseRange = func {
    ps46.increaseRange();
}

var decreaseRange = func {
    ps46.decreaseRange();
}


var iff_timer = maketimer(10, func {
    iffProp.setBoolValue(FALSE);
});
iff_timer.singleShot = TRUE;
iff_timer.simulatedTime = TRUE;

var IFF = func(on) {
    if (!on) return;
    if (!ps46.enabled) return;
    iffProp.setBoolValue(TRUE);
    iff_timer.restart(10);
}


### TI stuff
var lockLog  = events.LogBuffer.new(echo: 0);
var ecmLog = events.LogBuffer.new(echo: 0);


### Initialization

var init = func {
    init_generic();
    ps46 = AirborneRadar.newAirborne(ps46_modes, PS46);
}
