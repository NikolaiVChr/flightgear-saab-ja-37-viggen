var TRUE = 1;
var FALSE = 0;


### RWR logic: gather incoming radar signals


# Number of distinct sectors for the RWR
var sectors_n = 12;
var sector_width = 360/sectors_n;
# Types of RWR signals (give different warning sounds/lights)
# Numbers represent priority
var RWR_SQUAWK = 1; # Fairly confident this is not realistic
var RWR_SCAN = 2;
var RWR_LOCK = 3;
var RWR_APPROACH = 4;   # Not used yet
var RWR_LAUNCH = 5;
var RWR_SIGNAL_MIN = RWR_SQUAWK;
var RWR_SIGNAL_MAX = RWR_LAUNCH;


var bearing_to_sector = func(bearing) {
    return int(geo.normdeg(bearing + (sector_width/2)) / sector_width);
}


var RWRSignal = {
    signal_persist_time: 3, # Time for which a signal is displayed after disappearing, in sec

    new: func(UID, type, bearing) {
        var m = { parents: [RWRSignal] };
        m.UID = UID;
        m.delete_timer = maketimer(m.signal_persist_time, m, m.del);
        m.delete_timer.singleShot = TRUE;
        m.delete_timer.simulatedTime = TRUE;
        m.delete_timer.start();
        m.registered = FALSE;
        m.bearing = bearing;
        m.type = type;
        m.register();
        return m;
    },
    # The 'sectors_table' counts the number of signals in each sector.
    # Each RWRSignal increments/decrements appropriately.
    # The 'registered' flag indicates whether or not the present object
    # has been counted in the table.
    register: func() {
        if (me.registered) return;
        me.registered = TRUE;
        sectors_table[me.type][bearing_to_sector(me.bearing)] += 1;
    },
    unregister: func() {
        if (!me.registered) return;
        me.registered = FALSE;
        sectors_table[me.type][bearing_to_sector(me.bearing)] -= 1;
    },
    refresh: func(type, bearing) {
        if(bearing != me.bearing or type != me.type) {
            # Unregister from previous sector
            me.unregister();
            me.bearing = bearing;
            me.type = type;
            # Register in the new one
            me.register();
        }
        me.delete_timer.restart(me.signal_persist_time);
    },
    del: func() {
        me.delete_timer.stop();
        me.unregister();
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


# For each sector and signal type, indicates the number of signals coming from this sector
var sectors_table = [];
# Initialization
setsize(sectors_table, RWR_SIGNAL_MAX+1);
for(var i=RWR_SIGNAL_MIN; i<=RWR_SIGNAL_MAX; i+=1) {
    sectors_table[i] = [];
    setsize(sectors_table[i], sectors_n);
    for(var j=0; j<sectors_n; j+=1) {
        sectors_table[i][j] = FALSE;
    }
}

# Get the highest priority signal type in a given sector.
var get_highest_signal = func(sector) {
    for(var type=RWR_SIGNAL_MAX; type>=RWR_SIGNAL_MIN; type-=1) {
        if(sectors_table[type][sector]) return type;
    }
    return 0;
}
