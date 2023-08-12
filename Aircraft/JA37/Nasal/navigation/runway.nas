#### Misc runway related stuff

var FALSE = 0;
var TRUE = 1;


### Simple access to the current runway, used by displays and landing mode.

var has_wpt = FALSE;
var has_rwy = FALSE;

var icao = "";
# Following is only valid if has_rwy is true.
var rwy = nil;  # waypoint object, type differs between JA and AJS!
var rwy_coord = geo.Coord.new();
var rwy_heading = nil;
var ils = nil;
var rwy_name = "";


var rwy_update_ja = func {
    var wp = route.Polygon.primary.getSteerpoint();

    has_wpt = route.Polygon.isPrimaryActive() and wp != nil and wp[0] != nil;
    has_rwy = has_wpt and route.Polygon.primary.type == route.TYPE_RTB and ghosttype(wp[0]) == "runway";

    if (has_rwy) {
        rwy = wp[0];
        rwy_coord.set_latlon(rwy.lat, rwy.lon);
        rwy_heading = rwy.heading;
        rwy_name = rwy.id;
        ils = rwy.ils_frequency_mhz;
        icao = wp[1].id;
    } elsif (has_wpt and ghosttype(wp[0]) == "airport") {
        icao = wp[0].id;
    } else {
        icao = "";
    }
}

var rwy_update_ajs = func {
    var idx = route.get_current_idx();
    rwy = route.get_current_wpt();

    has_wpt = (idx != nil and rwy != nil);
    has_rwy = has_wpt and (idx & route.WPT.type_mask) == route.WPT.L and rwy.type == route.TYPE.RUNWAY;

    if (has_rwy) {
        rwy_coord.set(rwy.coord);
        rwy_heading = rwy.heading;
        rwy_name = rwy.name or "";
        ils = rwy.freq;
        icao = rwy.parent.name or "";
    } else {
        icao = "";
    }
}


var rwy_update = variant.JA ? rwy_update_ja : rwy_update_ajs;
