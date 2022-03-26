#### Ground mapping functions for AJS-37 PS-37/A radar
#
# This file implements ground mapping and the associated signal processing.
# For the radar controller (modes, antenna position, etc.) see radar/ps37.nas


var FALSE = 0;
var TRUE = 1;

var input = {
    heading:        "orientation/heading-deg",
    range:          "instrumentation/radar/range",
    mode:           "instrumentation/radar/mode",
    alt:            "instrumentation/altimeter/displays-altitude-meter",
    wow:            "fdm/jsbsim/gear/unit[0]/WOW",
    quality:        "instrumentation/radar/ground-radar-quality",
};

foreach(var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}


### geodinfo() helpers

# Call geodinfo() at a given azimuth and distance from the given position.
var geodinfo_at = func(ac_pos, heading, azimuth, distance) {
    var pos = geo.Coord.new(ac_pos);
    pos.apply_course_distance(heading+azimuth, distance);
    return geodinfo(pos.lat(), pos.lon());
}

# Extract altitude from geodinfo()
var geodinfo_to_alt = func(info) {
    return info==nil ? 0 : info[0];
}

# Angle from horizon
var elevation = func(ac_pos, distance, alt) {
    return math.atan2(alt - ac_pos.alt(), distance) * R2D;
}

## Terrain info

var is_water = func(info) {
    return info==nil or (info[1] != nil and !info[1].solid);
}

var is_urban = func(info) {
    # placeholder
    return FALSE;
}

var bumpiness = func(info) {
    if (info == nil or info[1] == nil or !contains(info[1], "bumpiness")) {
        return 0;
    }
    return info[1].bumpiness;
}

var refl_factor = func(info) {
    if (is_water(info)) {
        # would be nice to account for waves
        return 0.15;
    } elsif (is_urban(info)) {
        return 1; # ??
    } else {
        return 0.5 + bumpiness(info);
    }
}


### Radar terrain queries

# Simulate radar returns along a given azimuth.
#
# ac_pos, heading:  aircraft position
# azimuth:          direction of radar beam relative to aircraft forward axis
# {min,max}_elev:   vertical angular limits of radar beam
#
# Fills 'buffer' with radar echo strength function of distance, sampled uniformly from min_range to max_range.
# Returned values are "normalized" against the quartic signal falloff with range,
# i.e. proportional to the angular size of the target.
#
# It is normalized so that returned values average to 1 when
# - the entire radar beam is reflected between min_range and max_range
# - and the terrain reflecting has refl_factor() = 1
var radar_query = func(ac_pos, heading, azimuth, min_elev, max_elev, min_range, max_range, buffer, buf_size)
{
    var range_step = (max_range - min_range) / buf_size;
    var norm_factor = buf_size / (max_elev - min_elev);

    var range = min_range;

    var info = geodinfo_at(ac_pos, heading, azimuth, range);
    var last_elev = math.clamp(elevation(ac_pos, range, geodinfo_to_alt(info)), min_elev, max_elev);
    var last_refl_factor = refl_factor(info);

    var next_elev = 0;
    var next_refl_factor = 1;

    forindex (var i; buffer) {
        range += range_step;
        info = geodinfo_at(ac_pos, heading, azimuth, range);
        next_elev = math.clamp(elevation(ac_pos, range, geodinfo_to_alt(info)), last_elev, max_elev);
        next_refl_factor = refl_factor(info);

        buffer[i] = (next_elev - last_elev) * (next_refl_factor + last_refl_factor) / 2 * norm_factor;

        last_elev = next_elev;
        last_refl_factor = next_refl_factor;
    }

    return buffer;
}
