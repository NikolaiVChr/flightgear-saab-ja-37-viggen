#### AJS navigation system / route manager

var TRUE = 1;
var FALSE = 0;

var input = {
    wp_active:      "instrumentation/waypoint-indicator/active",
    wp_dist:        "instrumentation/waypoint-indicator/dist-km",
    wp_bearing:     "instrumentation/waypoint-indicator/true-bearing-deg",
    # excluding popup points
    tgt_dist:       "instrumentation/waypoint-indicator/tgt-dist-km",
    tgt_bearing:    "instrumentation/waypoint-indicator/tgt-true-bearing-deg",
    heading:        "instrumentation/heading-indicator/indicated-heading-deg",
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

    if ((idx & WPT.type_mask) == WPT.B)
        update_popup(idx);
}

var unset_wpt = func(idx) {
    delete(wpt_table, idx);

    if ((idx & WPT.type_mask) == WPT.B)
        unset_tgt(idx);
}

var unset_type = func(type) {
    for (var i=0; i<=9; i+=1) {
        unset_wpt(type | i);
    }
}

var unset_all_wpt = func {
    wpt_table = {};
    tgt_wpt = {};
}

var is_set = func(idx) {
    return wpt_table[idx] != nil;
}


## Target waypoints
var tgt_wpt = {};

var set_tgt = func(idx) {
    if (!is_tgt(idx))
        tgt_wpt[idx] = { heading: nil, dist: nil, };
}

var unset_tgt = func(idx) {
    delete(tgt_wpt, idx);
    update_popup(idx);
}

var is_tgt = func(idx) {
    return tgt_wpt[idx] != nil;
}

var set_popup = func(idx, heading, dist) {
    if (!is_tgt(idx)) return;

    tgt_wpt[idx].heading = heading;
    tgt_wpt[idx].dist = dist;

    update_popup(idx);
}

var has_popup = func(idx) {
    return is_tgt(idx) and tgt_wpt[idx].heading != nil and tgt_wpt[idx].dist != nil;
}

var popup_to_tgt = func(idx) {
    if ((idx & WPT.type_mask) != WPT.U)
        return idx;
    else
        return WPT.B | (idx & WPT.nb_mask);
}

var tgt_to_popup = func(idx) {
    return WPT.U | (idx & WPT.nb_mask);
}

# Recompute popup point position.
var update_popup = func(idx) {
    if (!is_set(idx) or !has_popup(idx)) {
        unset_wpt(tgt_to_popup(idx));
        return;
    }

    var wp = get_wpt(idx);
    var heading = tgt_wpt[idx].heading;
    var dist = tgt_wpt[idx].dist;
    # For popup waypoints, heading is the target approach heading.
    # So waypoint offset is opposite of that.
    var popup = Waypoint.offset_copy(wp, heading+180, dist);

    set_wpt(tgt_to_popup(idx), popup);
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
    if ((idx & WPT.nb_mask) == 1 and !is_set(idx)) {
        idx = WPT.LS;
    }
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
        if (type == WPT.U) {
            type = WPT.B;
        } else {
            type = WPT.U;
            nb += 1;
        }

        if (nb > 9) return WPT.L1;

        idx = nb | type;
        if (!resolve or is_set(idx)) return idx;
    }
}


# Test if current mode allows waypoint sequencing
var sequencing_enabled = func {
    return modes.selector_ajs != modes.COMBAT and modes.selector_ajs != modes.RECO
        and !fix_mode_active();
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
    set_display_fp_wpt(idx);
    stop_fix_mode();
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
    var bearing = ac_pos.course_to(wp_pos);
    var dist = ac_pos.distance_to(wp_pos);

    input.wp_active.setBoolValue(TRUE);
    input.wp_bearing.setDoubleValue(bearing);
    input.wp_dist.setDoubleValue(dist / 1000.0);

    if ((current & WPT.type_mask) == WPT.U) {
        # For popup points, some instruments need distance/bearing to corresponding target.
        var tgt_pos = get_wpt(popup_to_tgt(current)).coord;
        input.tgt_bearing.setDoubleValue(ac_pos.course_to(tgt_pos));
        input.tgt_dist.setDoubleValue(ac_pos.distance_to(tgt_pos) / 1000.0);
    } else {
        input.tgt_bearing.setDoubleValue(bearing);
        input.tgt_dist.setDoubleValue(dist / 1000.0);
    }


    # Sequencing
    if (!sequencing_enabled() or !can_sequence(current)) return;

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
        # First waypoint "after B0".
        set_current(find_next(WPT.B));
}

var callback_fp_changed = func {
    reload_current();
    write_display_fp();
    route_dialog.Dialog.update_legs();
}


### Target fix mode

var fix_mode = FALSE;
var fix_idx = nil;
var fix_wpt = nil;
# Temporary position during fix, and azimuth / distance.
var fix_tmp_pos = nil;
var fix_azi = nil;
var fix_dist = nil;

var start_fix_mode = func {
    var type = current & WPT.type_mask;
    if (type != WPT.B and type != WPT.U)
        return FALSE;
    if (type == WPT.B and !is_tgt(current))
        return FALSE;

    fix_mode = TRUE;
    fix_idx = popup_to_tgt(current);
    fix_wpt = get_wpt(fix_idx);
    fix_tmp_pos = geo.Coord.new(fix_wpt.coord);
    return TRUE;
}

var stop_fix_mode = func {
    fix_mode = FALSE;
}

var fix_mode_active = func {
    return fix_mode;
}

var confirm_fix_pos = func {
    fix_wpt.coord.set(fix_tmp_pos);
    fix_wpt.ghost = nil;    # waypoint ghost no longer matches position
    update_popup(fix_idx);
    callback_fp_changed();
}

var update_fix_mode = func(cursor_deltas) {
    if (cursor_deltas[2] == 2)
        confirm_fix_pos();

    var ac_pos = geo.aircraft_position();
    var heading = input.heading.getValue();

    # Convert position to azimuth/distance
    fix_azi = geo.normdeg180(ac_pos.course_to(fix_tmp_pos) - heading);
    fix_dist = ac_pos.distance_to(fix_tmp_pos);
    # Adjust azimuth/distance
    fix_azi += cursor_deltas[0] * 50;
    fix_dist -= cursor_deltas[1] * radar.ps37.getRangeM() / 2;
    fix_azi = math.clamp(fix_azi, -ci.PPI_half_angle, ci.PPI_half_angle);
    fix_dist = math.clamp(fix_dist, 0, ci.azimuth_range(fix_azi, radar.ps37.getRangeM(), 0));
    # Convert back to coordinate
    fix_tmp_pos.set(ac_pos);
    fix_tmp_pos.apply_course_distance(fix_azi + heading, fix_dist);
}


### Read-only, nice looking flightplan for FlightGear (used by map, etc.)

var display_fp = createFlightplan();
var display_fp_idx_table = {};          # waypoint to flightplan index table

var append_display_fp = func(wpt) {
    if (is_set(wpt)) {
        var wp = get_wpt(wpt);
        display_fp.appendWP(wp.to_wp_ghost());
    }

    display_fp_idx_table[wpt] = display_fp.getPlanSize()-1;
}

var write_display_fp = func {
    # reset all
    display_fp.cleanPlan();
    display_fp.departure = nil;
    display_fp.destination = nil;

    # Set airbases if possible
    # Note: fp ghost will 'do the right thing' when writing to 'departure',
    # or 'destination', whether it is an airport, a runway, or something invalid.
    var dep = resolve(WPT.LS);
    if (dep != nil)
        display_fp.departure = dep.ghost;
    # If we failed to set departure, try to add it as a regular waypoint
    if (display_fp.departure == nil)
        append_display_fp(WPT.LS);

    # Add waypoints
    for (var i = 1; i <= 9; i += 1) {
        append_display_fp(WPT.B | i);
    }

    var dest = resolve(WPT.L1);
    if (dest != nil)
        display_fp.destination = dest.ghost;
    if (display_fp.destination == nil)
        append_display_fp(WPT.L1);

    display_fp.activate();
    set_display_fp_wpt(current);
}

var set_display_fp_wpt = func(idx) {
    display_fp.current = display_fp_idx_table[idx] or -1;
}

var get_display_fp_ghost = func {
    return display_fp;
}

# Import FG flightplan
var load_fp = func(plan) {
    unset_type(WPT.L);
    unset_type(WPT.B);

    if (plan.departure != nil) {
        var dep = Airbase.from_ghost(plan.departure);

        if (plan.departure_runway != nil) {
            set_wpt(WPT.LS, dep.runways[plan.departure_runway.id]);
        } else {
            set_wpt(WPT.LS, dep);
        }
    }

    if (plan.destination != nil) {
        var dest = Airbase.from_ghost(plan.destination);

        if (plan.destination_runway != nil) {
            set_wpt(WPT.L1, dest.runways[plan.destination_runway.id]);
        } else {
            set_wpt(WPT.L1, dest);
        }
    }

    # output waypoint number (for the AJS system)
    var wp_idx = 1;
    var skipped_complex = FALSE;

    for (var i=0; i<plan.getPlanSize(); i+=1) {
        var wp = plan.getWP(i);

        # If first / last waypoints are departure/destination, skip them.
        if (i == 0 and navigation.departure_set(plan))
            continue;
        if (i == plan.getPlanSize()-1 and navigation.destination_set(plan))
            continue;

        if (!navigation.wp_has_position(wp)) {
            # Waypoint does not have a meaningfull position (e.g. heading to alt instructions).
            # AJS can't do anything with it, skip it.
            skipped_complex = TRUE;
            logprint(LOG_INFO, "Skipping complex flightplan instructions for waypoint "~wp.id);
            continue;
        }

        if (wp_idx > 9) {
            var msg = sprintf("Flightplan truncated at waypoint %s. AJS is limited 9 waypoints.", wp.id);
            logprint(LOG_ALERT, msg);
            screen.log.write(msg, 1, 0, 0);
            break;
        }

        set_wpt(WPT.B | wp_idx, Waypoint.from_ghost(wp));
        wp_idx += 1;
    }

    if (skipped_complex)
        screen.log.write("Some complex flightplan legs were skipped.", 1, 0.5, 0);

    callback_fp_changed();
}

# Create FG flightplan from waypoints of a given type.
#
# Unlike the "nice" display flightplan above, this avoids any information loss.
# Waypoint indices are respected, discontinuities are added for unset waypoints.
var get_wpts_as_fp = func(type) {
    var fp = createFlightplan();

    var skipped = 0;

    for (var i = 1; i <= 9; i += 1) {
        if (!is_set(type | i)) {
            skipped += 1;
            continue;
        }
        # We have a waypoint, pad with discontinuities to preserve indices.
        for (var j=0; j<skipped; j+=1)
            fp.appendWP(createDiscontinuity());

        skipped = 0;

        # And add the actual waypoint
        fp.appendWP(get_wpt(type | i).to_wp_ghost());
    }

    return fp;
}

# Load waypoints of a given type from FG flightplan.
#
# This is the inverse of get_wpts_as_fp(), waypoint indices are respected.
var load_wpts_from_fp = func(type, plan) {
    unset_type(type);
    for (var i=0; i<plan.getPlanSize() and i<9; i+=1) {
        var wp = plan.getWP(i);
        if (navigation.wp_has_position(wp))
            set_wpt(type | (i+1), Waypoint.from_ghost(wp));
    }

    callback_fp_changed();
}




var loop = func {
    update();
    wpt_ind.set_wp_indicator(current);
}

var init = func {
    set_current(WPT.LS);
    write_display_fp();
}
