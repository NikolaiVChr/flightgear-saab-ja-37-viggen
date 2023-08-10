#### Approach pattern geometry

# This file defines the positions of the various landing waypoints.
# Headings are true, distances in m.


# Pattern direction
var LEFT = 1;
var RIGHT = -1;

# Approach length
var FINAL_LENGTH_LONG = 20000;
var FINAL_LENGTH_SHORT = 10000;
# Size of approach circle
var CIRCLE_RADIUS = 4100;
# For AJS, descent prior to LB (if alt > 600m) with 4deg flight path angle, finishing at 1km from LB.
var DESCENT_ANGLE = 4;
var DESCENT_MARGIN = 1000;


### State

## Manually updated
# Ideally this should be center of runway. Threshold should be fine too.
var runway_pos = nil;
var runway_heading = nil;
# Some ILS (or more properly: IGS) are not aligned with the runway.
var ils_pos = nil;
var ils_heading = nil;
# Copy of ILS pos if defined, and of runway pos otherwise. Defines the approach line.
var appch_pos = nil;
var appch_heading = nil;

var final_short = FALSE;
var final_length = FINAL_LENGTH_LONG;

## Rarely updated
var pattern_side = LEFT;    # +/-1. Assume left-hand pattern, and multiply by this to swap directions.
var circle_center = nil;    # approach circle

## Continuously updated
var center_dist = nil;      # distance aircraft <-> circle_center
var circle_dist = nil;      # distance aircraft <-> border of circle
var tangent_dist = nil;     # distance aircraft <-> tangent point 'LB'
var center_bearing = nil;   # bearing from aircraft to circle_center
var tangent_bearing = nil;  # bearing from aircraft to tangent point 'LB'


### State update functions

# Set runway, and optionally ILS.
var set_runway = func(rwy_pos, rwy_heading, _ils_pos=nil, _ils_heading=nil) {
    if (rwy_pos and rwy_heading) {
        runway_pos = geo.Coord.new(rwy_pos);
        runway_heading = rwy_heading;
    } else {
        runway_pos = nil;
        runway_heading = nil;
    }

    if (runway_pos and _ils_pos and _ils_heading) {
        ils_pos = geo.Coord.new(_ils_pos);
        ils_heading = _ils_heading;
    } else {
        ils_pos = nil;
        ils_heading = nil;
    }

    appch_pos = ils_pos ? ils_pos : runway_pos;
    appch_heading = ils_pos ? ils_heading : runway_heading;

    _update_circle();
}

var unset_runway = func {
    set_runway(nil, nil);
}


# Set short/long final.
var set_short_final = func(short) {
    if (short == final_short) return;

    final_short = short;
    final_length = final_short ? FINAL_LENGTH_SHORT : FINAL_LENGTH_LONG;
    _update_circle();
}

# Internal, update position of approach circle center.
var _update_circle = func {
    if (appch_pos == nil) {
        circle_center = nil;
        return;
    }

    circle_center = geo.Coord.new(appch_pos);
    circle_center.apply_course_distance(appch_heading + 180, final_length);
    circle_center.apply_course_distance(appch_heading - 90 * pattern_side, CIRCLE_RADIUS);
}

# Choose pattern side based on aircraft position.
var update_pattern_side = func {
    if (appch_pos == nil) return;

    var bearing = ac_pos.course_to(appch_pos);
    var side = geo.normdeg180(bearing - appch_heading) >= 0 ? LEFT : RIGHT;

    if (side == pattern_side) return;

    pattern_side = side;
    _update_circle();
}

# Update aircraft relative distances and bearings.
var update_tangent = func {
    if (!circle_center) {
        center_dist = nil;
        circle_dist = nil;
        tangent_dist = nil;
        center_bearing = nil;
        tangent_bearing = nil;
        return;
    }

    center_dist = ac_pos.distance_to(circle_center);
    circle_dist = math.max(center_dist - CIRCLE_RADIUS, 0);
    center_bearing = ac_pos.course_to(circle_center);

    if (center_dist >= CIRCLE_RADIUS) {
        tangent_dist = math.sqrt(center_dist * center_dist - CIRCLE_RADIUS * CIRCLE_RADIUS);
        # If 'a' is the angle between center_bearing and the tangent_bearing,
        # then sin(a) is CIRCLE_RADIUS / center_dist
        var angle = math.asin(CIRCLE_RADIUS / center_dist) * R2D;
        tangent_bearing = geo.normdeg(center_bearing + angle * pattern_side);
    } else {
        # Aircraft is inside the circle, tangent point is not defined.
        # Set sensible default values.
        tangent_dist = 0;
        tangent_bearing = center_bearing + 90 * pattern_side;   # heading tangent to circle
    }
}
