# Test if departure/destination are set in a flightplan.
#
# Departure/destination are only recognised if they are the first/last WP respectively.
# (the WP indicator logic is not designed for this)

var wp_match_airport = func(wp, airport) {
    return airport != nil and wp.id == airport.id;
}

var wp_match_runway = func(wp, airport, runway) {
    return airport != nil and runway != nil and wp.id == airport.id~"-"~runway.id;
}

var departure_set = func(fp) {
    if (fp.getPlanSize() <= 0) return 0;
    var wp = fp.getWP(0);

    return wp.wp_role == "sid" and
        (wp_match_airport(wp, fp.departure) or wp_match_runway(wp, fp.departure, fp.departure_runway));
}

var destination_set = func(fp) {
    if (fp.getPlanSize() <= 0) return 0;
    var wp = fp.getWP(fp.getPlanSize()-1);

    return wp.wp_role == "approach" and
        (wp_match_airport(wp, fp.destination) or wp_match_runway(wp, fp.destination, fp.destination_runway));
}

# duplicate of Polygon.getSteerpoint(), for AJS
var get_wp_for_landing_mode = func(fp) {
    #instance:
    # Return a vector with curent steerpoint. If runway [runway, airport]. If airport [airport]. Else [leg].
    #
    if (fp.current == fp.getPlanSize()-1 and fp.destination_runway != nil and fp.destination != nil) {
        return [fp.destination_runway, fp.destination];
    }
    if (fp.current == fp.getPlanSize()-1 and fp.destination != nil) {
        return [fp.destination];
    }
    return [fp.currentWP()];
}


### Waypoint selection buttons for AJ(S)

# Select the nth waypoint.
# The first and last waypoints of the flightplan can not be selected through
# this function if they are runways (ls_button and l_button should be used).
# If that is the case, numbering is offset so that '1' corresponds to the
# first waypoint after the starting base.
var nav_button = func(n) {
    var fp = flightplan();
    var last = fp.getPlanSize() - 1;
    if (last < 0) return;

    # Offset if departure base is not set.
    if (!departure_set(fp)) n -= 1;

    if (n < last or (n == last and !destination_set(fp))) {
        fp.current = n;
    }
}

# Select the starting base, which is the first waypoint, provided it is a runway.
var ls_button = func {
    var fp = flightplan();
    if (fp.getPlanSize() > 0 and departure_set(fp)) {
        fp.current = 0;
    }
}

# Select the landing base, which is the last waypoint, provided it is a runway.
var l_button = func {
    var fp = flightplan();
    var last = fp.getPlanSize() - 1;
    if (last >= 1 and destination_set(fp)) {
        fp.current = last;
    }
}
