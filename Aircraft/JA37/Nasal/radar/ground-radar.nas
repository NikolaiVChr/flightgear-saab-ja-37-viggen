#### Ground mapping functions for AJS-37 PS-37/A radar
#
# This file implements ground mapping and the associated signal processing.
# For the radar controller (modes, antenna position, etc.) see radar/ps37.nas


var FALSE = 0;
var TRUE = 1;


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

# Terrain characteristics
var is_water = func(info) {
    return info==nil or (info[1] != nil and !info[1].solid);
}

var urban_names = {
    "Urban": 1,
    "BuiltUpCover": 1,
    "Construction": 1,
    "Industrial": 1,
    "Port": 1,
    "Town": 1,
    "SubUrban": 1,
};

var is_urban = func(info) {
    if (info == nil or info[1] == nil or !contains(info[1], "names")) {
        return FALSE;
    }
    foreach (var name; info[1].names) {
        if (contains(urban_names, name)) return TRUE;
    }
    return FALSE;
}

var bumpiness = func(info) {
    if (info == nil or info[1] == nil or !contains(info[1], "bumpiness")) {
        return 0;
    }
    return info[1].bumpiness;
}



### Physical effects on radar beam
#
# /!\ Quartic signal falloff with range is ignored entirely.
# In reality it would be compensated during post-processing.
# For simulation it seems silly to add it and remove it later.

# Reflectance factor of terrain.
#
# A bit of info on how different terrain reflect radar waves:
# https://www.microimages.com/documentation/Tutorials/radar.pdf
# (no numbers though, values in the function are just picked to look nice)
#
var refl_factor = func(info) {
    if (is_water(info)) {
        # water absorbs a lot at this wavelength
        return 0.05;
    } elsif (is_urban(info)) {
        # buildings can act as corner reflectors, giving very strong echoes
        return 5.0;
    } else {
        # rough terrain scatters more, giving stronger echoes
        return 1 + bumpiness(info);
    }
}

# Signal strength function of object angular size.
#
# I'm using the following functions for signal strength factor function of angle off beam centerline:
# - wide beam (no Δ compensation):  1 - (x/4)**2    (= 1 - x**2 / 16)       range [-4:4]
# - narrow beam (Δ compensation):   1 - (x/2.5)**4  (= 1 - x**4 / 39.0625)  range [-2.5:2.5]
# (x = angle in degree)
# These are eyeballed to look a bit like fig. 6, AJS 37 SFI part 3 chapter 2 page 9.
#
# This gives integrals:
# - wide:   x - x**3 / 48
# - narrow: x - x**5 / 195.3125

var wide_beam_half_angle = 4;
var narrow_beam_half_angle = 2.5;

var wide_beam_signal_int = func(angle) {
    angle = math.clamp(angle, -wide_beam_half_angle, wide_beam_half_angle);
    return angle - math.pow(angle, 3) / 48;
}

var narrow_beam_signal_int = func(angle) {
    angle = math.clamp(angle, -narrow_beam_half_angle, narrow_beam_half_angle);
    return angle - math.pow(angle, 5) / 195.3125;
}

var wide_beam_signal = func(start_angle, end_angle) {
    return wide_beam_signal_int(end_angle) - wide_beam_signal_int(start_angle);
}

var narrow_beam_signal = func(start_angle, end_angle) {
    return narrow_beam_signal_int(end_angle) - narrow_beam_signal_int(start_angle);
}

# Total integral, used as normalisation factor
var wide_beam_signal_total = wide_beam_signal(-wide_beam_half_angle, wide_beam_half_angle);
var narrow_beam_signal_total = narrow_beam_signal(-narrow_beam_half_angle, narrow_beam_half_angle);



### Radar terrain queries

# Simulate radar returns along a given azimuth.
#
# ac_pos, heading:  aircraft position
# azimuth, elev:    direction of radar beam relative to aircraft forward axis (right, up, angles in degrees)
#
# Fills 'buffer' with radar echo strength function of distance, sampled uniformly from 0 to max_range.
# Returned values are "normalized" against the quartic signal falloff with range,
# i.e. proportional to the angular size of the target.
#
# It is normalized so that returned values average to 1 when
# - the entire radar beam is reflected between min_range and max_range
# - and the terrain reflecting has refl_factor() = 1
#
var radar_query = func(ac_pos, heading, azimuth, elev, max_range, narrow_beam, buffer, buf_size)
{
    var beam_half_angle = narrow_beam ? narrow_beam_half_angle : wide_beam_half_angle;
    var min_angle = -beam_half_angle;
    var max_angle = beam_half_angle;
    var beam_signal = narrow_beam ? narrow_beam_signal : wide_beam_signal;

    var range_step = max_range / buf_size;
    var range = 0;

    var info = geodinfo_at(ac_pos, heading, azimuth, range);
    var last_angle = math.clamp(elevation(ac_pos, range, geodinfo_to_alt(info)) - elev, min_angle, max_angle);
    var last_refl_factor = refl_factor(info);

    var next_angle = 0;
    var next_refl_factor = 1;

    for (var i = 0; i < buf_size; i += 1) {
        range += range_step;
        info = geodinfo_at(ac_pos, heading, azimuth, range);
        next_angle = math.clamp(elevation(ac_pos, range, geodinfo_to_alt(info)) - elev, last_angle, max_angle);
        next_refl_factor = refl_factor(info);

        buffer[i] = beam_signal(last_angle, next_angle) * (next_refl_factor + last_refl_factor) / 2;

        last_angle = next_angle;
        last_refl_factor = next_refl_factor;
    }

    return buffer;
}


### Signal processing

# Basic signal normalisation
#
# Assuming that the entire radar beam was reflected, and that terrain
# has reflectance = 1, this results in an average signal = 1.

var signal_norm_basic = func(buffer, buf_size, narrow_beam) {
    var norm_factor = buf_size / (narrow_beam ? narrow_beam_signal_total : wide_beam_signal_total);
    for (var i=0; i<buf_size; i+=1) {
        buffer[i] *= norm_factor;
    }
}

# Compensate for distance, so that the same terrain will give roughly the same.
#
# If the terrain is flat, with reflectance = 1, and altimeter is correct,
# the signal will be = 1 within the limits of the radar beam.

var signal_norm_distance = func(buffer, buf_size, range, alt) {
    # clamp (negative or null altitudes will cause errors)
    alt = math.max(alt, 50);

    # The point at distance 'dist' is seen at angle atan(dist / alt) * R2D from down axis.
    # buffer[i] corresponds to the signal between
    #   dist1 = range * i / buf_size
    #   dist2 = range * (i+1) / buf_size
    # that is the angle between these two points.
    #
    # It can be well approximated as the derivative w.r.t. 'dist'
    #   1 / (1 + (dist1 + dist2 / 2 / alt) ** 2) / alt * R2D
    # times the distance
    #   dist2 - dist1
    #
    # Normalisation factor is the inverse of that, which simplifies to
    #   (1 + ((i+0.5) * range / alt / buf_size) ** 2) * buf_size * alt / range * D2R

    var norm_factor = buf_size * alt / range;

    for (var i=0; i<buf_size; i+=1) {
        var angle_norm = (i + 0.5) / norm_factor;
        buffer[i] *= norm_factor * (1 + angle_norm * angle_norm) * D2R;
    }
}

# Apply final pilot-adjustable gain to signal, and log scale depending on setting.

var signal_gain = func(buffer, buf_size, gain, linear) {
    for (var i=0; i<buf_size; i+=1) {
        buffer[i] *= 0.4 * math.pow(4, gain);
        if (!linear) {
            buffer[i] = math.ln(1 + buffer[i] * 2) / 2;
        }
    }
}
