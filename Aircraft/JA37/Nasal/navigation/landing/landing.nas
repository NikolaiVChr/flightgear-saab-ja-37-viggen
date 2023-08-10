#### Viggen landing mode
#
# This is the main file, all other files in this directory are included in the same namespace.

var TRUE = 1;
var FALSE = 0;


var input = utils.property_map({
    heading:        "instrumentation/heading-indicator/indicated-heading-deg",
    alt_aal:        "instrumentation/altimeter/indicated-altitude-aal-meter",
    rad_alt:        "instrumentation/radar-altimeter/radar-altitude-m",
    rad_alt_ready:  "instrumentation/radar-altimeter/ready",
});


# Aircraft position / true heading.
# We'll use these a lot, so better update them only once per frame.
var ac_pos = nil;
var heading = nil;
var altitude = nil;

var update_ac_pos = func {
    ac_pos = geo.aircraft_position();
    heading = input.heading.getValue();
    altitude = input.alt_aal.getValue();
}


# Absolute value of angle.
var abs_angle = func(angle) {
    return math.abs(geo.normdeg180(angle));
}
