#### JA 37 terrain profile

# JA has an elevation map of Sweden, with 12.5km resolution.
# This is simulated for the entire world.
# Elevations are precomputed from STRM data, stored in DEM/ja37.elev


# Resolution is 0.1 deg = 6 arcmin = 6 nm ~ 11 km (for latitude)
var D2G = 10;       # grid zones per degree of latitude
var G2D = 1/D2G;    # side of grid zone in degrees of latitude

# Precomputed map covers everything north of 60°S
var min_lon = -180;
var max_lon = 180;
var min_lat = -60;
var max_lat = 90;

var entry_per_row = (max_lon - min_lon) * D2G;

var elev_filename = getprop("/sim/aircraft-dir") ~ "/DEM/ja37.elev";
var elev_file = nil;
var buffer = bits.buf(1);

# Cache last query
var last_offset = -1;
var last_elev = 0;


var input = utils.property_map({
    elev: "/ja37/avionics/terrain-height-m",
});


var open_map = func {
    if (elev_file != nil) return;

    call(func { elev_file = io.open(elev_filename, "rb"); }, nil, nil, nil, var err = []);
    if (size(err)) {
        debug.printerror(err);
        printf("Failed to load elevation map: %s\n", path);
        close_map();
    }
}

var close_map = func {
    if (elev_file != nil) io.close(elev_file);
    elev_file = nil;
}


# See DEM/README.md
var decode_elev = func(byte) {
    if (byte >= 192) byte -= 256;
    return byte * 64;
}

# Convert coordinate to offset in ja37.elev
# Return -1 if outside of the map.
var coord_to_map_offset = func(coord) {
    if (coord.lat() < min_lat or coord.lat() > max_lat or coord.lon() < min_lon or coord.lon() > max_lon) {
        return -1;
    }

    var lat_idx = math.floor((coord.lat() - min_lat) * D2G);
    var lon_idx = math.floor((coord.lon() - min_lon) * D2G);
    # Data in row major order
    return lat_idx * entry_per_row + lon_idx;
}

# Read map elevation at a given offset.
var read_elev = func(offset) {
    if (elev_file == nil) return 0;

    io.seek(elev_file, offset, io.SEEK_SET);
    io.read(elev_file, buffer, 1);

    return decode_elev(buffer[0]);
}

var read_coord_elev = func(coord) {
    var offset = coord_to_map_offset(coord);
    if (offset < 0) return 0;
    if (offset == last_offset) return last_elev;

    last_offset = offset;
    last_elev = read_elev(offset);
    return last_elev;
}



var init = func {
    open_map();
}

var loop = func {
    if (power.prop.acMainBool.getBoolValue()) {
        input.elev.setValue(read_coord_elev(geo.aircraft_position()));
    } else {
        input.elev.setValue(0);
    }
}
