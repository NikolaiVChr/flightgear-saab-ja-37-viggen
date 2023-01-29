# Test if departure/destination are set in a flightplan.
#
# Departure/destination are only recognised if they are the first/last WP respectively.

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

# Test if a waypoint ghost has a well defined position
var wp_has_position = func(wp) {
    var type = wp.wp_type;

    if (type == "vectors" or type == "discontinuity" or type == "hdgToAlt"
        or type == "dmeIntercept" or type == "radialIntercept")
        return 0;

    return 1;
}
