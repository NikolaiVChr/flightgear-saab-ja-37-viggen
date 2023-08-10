#### Viggen landing mode
#
# This is the main file, all other files in this directory are included in the same namespace.

var TRUE = 1;
var FALSE = 0;


var input = utils.property_map({
    heading:        "instrumentation/heading-indicator/indicated-heading-deg",
});


# Aircraft position / true heading.
# We'll use these a lot, so better update them only once per frame.
var ac_pos = nil;
var heading = nil;

var update_ac_pos = func {
    ac_pos = geo.aircraft_position();
    heading = input.heading.getValue();
}
