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
