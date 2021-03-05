var TRUE = 1;
var FALSE = 0;

var input = {
    alt:            "/instrumentation/altimeter/indicated-altitude-m",
    rad_alt:        "instrumentation/radar-altimeter/radar-altitude-ft",
    rad_alt_ready:  "instrumentation/radar-altimeter/ready",
    gear_pos:       "/gear/gear/position-norm",
};

foreach (var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
};



# Pattern direction
var LEFT = 0;
var RIGHT = 1;


### Compute positions of the various landing waypoints.

# Headings are true, distances in m
var runway = nil;
var runway_pos = nil;
var runway_heading = nil;        # True heading
var final_short = FALSE;
var final_length = 20000;        # normal: 20km, short: 10km
var pattern_side = LEFT;         # Pattern direction
var final_start = nil;           # Begining of final (final_length km from threshold)
var circle_center = nil;         # Approach circle (tangent to final);
var circle_radius = 4100;
var target_descent_angle = 4;    # For AJS, descent prior to LB (if alt > 600m) with 4deg flight path angle.
var descent_end_margin = 1000;   # End of decent at this distance from LB.

# (Re)-initialize state, set target runway.
# Must be called before any other operation.
var init_runway = func (rw) {
    runway = rw;
    runway_pos = geo.Coord.new().set_latlon(rw.lat, rw.lon);
    runway_heading = rw.heading;
    final_short = FALSE;
    final_length = 20000;
    pattern_side = LEFT;

    compute_circle();
}

var set_short_final: func (short) {
    if (short == final_short) return;

    final_short = short;
    final_length = short ? 10000 : 20000;
    compute_circle();
}

var set_pattern_side = func (side) {
    if (side == pattern_side) return;

    pattern_side = side;
    compute_circle();
}

# Decide pattern side from aircraft position.
var choose_pattern_side = func (ac_pos) {
    var bearing = ac_pos.course_to(runway_pos);
    set_pattern_side(geo.normdeg180(bearing - runway_heading) >= 0 ? LEFT : RIGHT);
}

# Approach circle position
var compute_circle = func {
    final_start = geo.Coord.new(runway_pos);
    final_start.apply_course_distance(runway_heading+180, final_length);

    circle_center = geo.Coord.new(final_start);
    circle_center.apply_course_distance(runway_heading + (pattern_side == LEFT ? -90 : 90), circle_radius);
}


### Steering orders for the different modes.

# Heading to arrive tangent to the approach circle (LB).
var tangent_steering = func (ac_pos) {
    # Distance and bearing to the center of the circle
    var circle_dist = ac_pos.distance_to(circle_center);
    var circle_bearing = ac_pos.course_to(circle_center);

    if (circle_dist >= circle_radius) {
        # If 'a' is the difference between circle_bearing and the desired bearing,
        # sin(a) is circle_radius/circle_dist
        var bearing_offset = math.asin(circle_radius/circle_dist) * R2D;
        # Choose correct side for the tangent.
        if (pattern_side == RIGHT) bearing_offset = -bearing_offset;
        return geo.normdeg(circle_bearing + bearing_offset);
    } else {
        # We are inside the approach circle, the tangent is not defined.
        # Make a nice curve to get back on the circle.

        # 'Out' angle of up to 20deg, reduces once within 600m from the circle.
        var approach_angle = math.clamp((circle_radius - circle_dist)/30 , 20, 0);
        # This is the difference between the desired angle and the bearing to the center.
        approach_angle += 90;
        # Choose correct side for the tangent.
        if (pattern_side == RIGHT) approach_angle = -approach_angle;
        return geo.normdeg(circle_bearing + approach_angle);
    }
},

# Return the distance until arriving tangent to the approach circle (LB).
var tangent_dist = func (ac_pos) {
    var circle_dist = ac_pos.distance_to(circle_center);

    if (circle_dist >= circle_radius) {
        return math.sqrt(circle_dist * circle_dist - circle_radius * circle_radius);
    } else {
        return 0;
    }
},

# Return the distance to the approach circle. 0 if inside the circle.
var circle_dist = func (ac_pos) {
    return math.max(ac_pos.distance_to(circle_center) - circle_radius, 0);
}

# Descent to reach LB at 500m, with a bit of margin.
var descent_angle = func (ac_pos, alt) {
    alt -= 500;
    var dist = tangent_dist(ac_pos) - descent_margin.
    if (dist < 0) dist = 0;
    return math.atan2(alt, dist) * R2D;
},





### Landing mode/phase.

var active = FALSE;

# Landing phase 1: waypoint LB (tangent to approach circle).
# Descent submode for AJS, engaged if alt>600m when entering landing mode.
var BEFORE_DESCENT = 1;
var DESCENT = 2;
var TANGENT = 3;
# Landing phase 2: waypoint LF (start of final).
var CIRCLE = 4;
var INTERCEPT = 5;
# Landing phase 3: final
var FINAL = 6;
var OPTICAL = 7;
var FLARE = 8;      # Indicate maximum descent rate for touchdown.

var mode = 0;


# Landing mode activation.
#
# Selects the landing runway from the flightplan.
# Returns true if landing runway was selected, false if no landing runway was found.
# In the latter case, OPT mode is engaged.
var activate_landing_mode = {
    # Do nothing if already active.
    # Changing the runway requires to exit landing mode.
    if (active) return (runway != nil);

    active = TRUE;

    var rw = nil;
    if (variant.JA) {
        # JA
        if (route.Polygon.activateLandingBase()) {
            rw = route.Polygon.primary.baseRwy;
        } else {
            route.Polygon.stopPrimary();
        }
    } else {
        # AJS
        rw = flightplan().destination_runway;
    }

    if (rw != nil) {
        init_runway(rw);
        return TRUE;
    } else {
        mode = OPTICAL;
        return FALSE;
    }
}



### Manual mode selection.

# JA landing mode selection functions.
var LB = func {
    if (activate_landing_mode()) {
        mode = TANGENT;
        set_short_final(FALSE);
    }
}

var LF = func {
    if (activate_landing_mode()) {
        mode = TANGENT;
        set_short_final(TRUE);
    }
}

var OPT = func {
    if (active or input.gear_pos.getValue() == 1) {
        activate_landing_mode();
        mode = OPTICAL;
    }
}

# AJS landing mode selection.
var LANDING_NAV = func {
    if (activate_landing_mode()) {
        mode = BEFORE_DESCENT;
    }
}

var LANDING_PO = func {
    if (activate_landing_mode()) {
        set_short_final(TRUE);
    }
    mode = OPTICAL;
}

# Exit landing mode.
var stop_landing = func {
    active = FALSE;
}



### Automatic mode changes
var update_mode = func {
    if (!active or runway == nil) return;

    var ac_pos = geo.aircraft_position();
    var alt = input.alt.getValue();
    var rad_alt = input.rad_alt_ready.getBoolValue() ? input.rad_alt.getValue() : nil;

    # Descent mode (for AJS). Start descent at the moment giving a 4deg descent angle.
    if (mode == BEFORE_DESCENT and descent_angle(ac_pos, alt) >= target_descent_angle) {
        mode = DESCENT;
    }
    # Exit descent mode below 600m.
    if ((mode == DESCENT or mode == BEFORE_DESCENT) and alt < 600) {
        mode = TANGENT;
    }
    # Exit landing phase 1 upon reaching the approach circle.
    if (mode == TANGENT and circle_dist(ac_pos) < 100) {
        mode = CIRCLE;
    }

    if (mode == FINAL and (alt < 35 or (alt < 60 and rad_alt != nil and rad_alt < 15))) {
        mode = OPTICAL;
    }

    if (mode == OPTICAL or mode == FLARE) {
        # Switch from OPTICAL to FLARE when sufficiently low.
        if ((rad_alt != nil and rad_alt < 15) or (rad_alt == nil and alt < 35)) {
            mode = FLARE;
        } else {
            mode = OPTICAL;
        }
    }
}



### Indications for landing mode displays (TI and CI).
var show_waypoint_circle = FALSE;
var show_approach_circle = FALSE;
var show_runway_line     = FALSE;

# Simplified phases, for the AJS waypoint indicator, and TI visuals
# (not used in landing logic)
var PHASE_LB = 1;       # 'phase 1', displays LB
var PHASE_LF = 2;       # 'phase 2', displays LF
var PHASE_FINAL = 4;    # 'phase 3', still LF
var PHASE_OPT = 5;
var phase = 0;

var update_display = func {
    show_approach_circle = active and (mode <= TANGENT);
    show_waypoint_circle = active and (mode > TANGENT);
    show_runway_line = active;

    if (!active) phase = 0;
    elsif (mode <= TANGENT and !short_approach) phase = PHASE_LB;
    elsif (mode < FINAL) phase = PHASE_LF;
    elsif (mode == FINAL) phase = PHASE_FINAL;
    else phase = PHASE_OPT;
}
