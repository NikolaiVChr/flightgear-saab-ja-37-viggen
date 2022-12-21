#### AJS navigation system / route manager

var TRUE = 1;
var FALSE = 0;

var input = {
    wp_active:      "instrumentation/waypoint-indicator/active",
    wp_dist:        "instrumentation/waypoint-indicator/dist-km",
    wp_bearing:     "instrumentation/waypoint-indicator/true-bearing-deg",
};

foreach(var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}



### Waypoints reference numbers
var WPT = {
    nb_mask: 0x0f,
    type_mask: 0xf0,

    L:  0x10,
    B:  0x20,
    U:  0x30,
    BX: 0x40,
    R:  0x50,
    M:  0x60,
    S:  0x70,

    LS: 0x10,
    L1: 0x11,
    L2: 0x12,
};


### Waypoints list

var wpt_table = {};

var get_wpt = func(idx) {
    return wpt_table[idx];
}

var set_wpt = func(idx, wpt) {
    wpt_table[idx] = wpt;
}

var unset_wpt = func(idx) {
    delete(wpt_table, idx);
}

var is_set = func(idx) {
    return wpt_table[idx] != nil;
}


## Query waypoint with fallback rules
#
# LS is used as fallback position for L1.
# B(i-1) is used as fallbakc position for B(i)
#
var resolve = func(idx) {
    if (is_set(idx))
        return get_wpt(idx);

    if (idx == WPT.L1)
        return get_wpt(WPT.LS);

    if ((idx & WPT.type_mask) != WPT.B)
        # Other waypoints have no fallback
        return nil;

    while ((idx & WPT.nb_mask) > 1 and !is_set(idx)) {
        idx -= 1;
    }
    # Should LS be the fallback for B1?
    return get_wpt(idx);
}


# Test if the waypoint type is sequencing (should switch to next waypoint when passing it)
var can_sequence = func(idx) {
    var type = idx & WPT.type_mask;
    return (type == WPT.B or type == WPT.U)
}

## Find index of next waypoint in sequencing order
#
# If resolve is true (default), unset waypoints are skipped.
#
var find_next = func(idx, resolve=1) {
    var type = idx & WPT.type_mask;
    var nb = idx & WPT.nb_mask;

    if (!can_sequence(idx)) return idx;

    while (TRUE) {
        # increment
        #if (type == WPT.U) {
        #    type = WPT.B;
        #} else {
        #    type = WPT.U;
        #    nb += 1;
        #}
        nb += 1;

        if (nb > 9) return WPT.L1;

        idx = nb | type;
        if (!resolve or is_set(idx)) return idx;
    }
}


# Test if current mode allows waypoint sequencing
var sequencing_enabled = func {
    return modes.selector_ajs != modes.COMBAT and modes.selector_ajs != modes.RECO;
}


### Route manager

var current = WPT.LS;
var current_wpt = nil;

var get_current_idx = func { return current; }
var get_current_wpt = func { return current_wpt; }

var sequence_dist = 3000.0;    # AJS37 SFI part 3 sec 6.1.1.1
var last_dist = nil;

var aircraft_pos = geo.aircraft_position;


var set_current = func(idx) {
    current = idx;
    current_wpt = resolve(idx);
    last_dist = sequence_dist + 1.0;    # so that it doesn't immediately sequence
    update();
    wpt_ind.set_wp_indicator(idx);
    set_display_fp_wpt(idx);
}

# reload current waypoint (to be used the waypoint position changed)
var reload_current = func {
    return set_current(current);
}


var update = func {
    if (current_wpt == nil) {
        input.wp_active.setBoolValue(FALSE);
        return;
    }

    var ac_pos = aircraft_pos();
    var wp_pos = current_wpt.coord;

    input.wp_active.setBoolValue(TRUE);
    input.wp_bearing.setDoubleValue(ac_pos.course_to(wp_pos));
    var dist = ac_pos.distance_to(wp_pos);
    input.wp_dist.setDoubleValue(dist/1000.0);

    if (!sequencing_enabled() or !can_sequence(current)) return;

    # Sequencing

    if (last_dist < sequence_dist and last_dist < dist) {
        # remark: update is called from set_current(), but the sequencing condition
        # can not be triggered immediately again, so this will not recurse further.
        set_current(find_next(current));
    } else {
        last_dist = dist;
    }
}


var callback_takeoff = func {
    if (current == WPT.LS)
        set_current(WPT.B | 1);
}

var callback_fp_changed = func {
    reload_current();
    write_display_fp();
}


### Read-only flightplan for FlightGear (used by map, etc.)

var display_fp = createFlightplan();
var display_fp_idx_table = {};          # waypoint to flightplan index table

var append_display_fp = func(wpt) {
    if (is_set(wpt)) {
        var wp = get_wpt(wpt);
        display_fp.appendWP(createWP(wp.coord, wp.name));
    }

    display_fp_idx_table[wpt] = display_fp.getPlanSize()-1;
}

var write_display_fp = func {
    display_fp.cleanPlan();
    display_fp.departure = nil;
    display_fp.destination = nil;

    append_display_fp(WPT.LS);
    for (var i = 1; i <= 9; i += 1) {
        append_display_fp(WPT.B | i);
    }
    append_display_fp(WPT.L1);

    display_fp.activate();
    set_display_fp_wpt(current);
}

var set_display_fp_wpt = func(idx) {
    display_fp.current = display_fp_idx_table[idx] or -1;
}




var loop = func {
    update();
}

var init = func {
    set_current(WPT.LS);
    write_display_fp();
}
