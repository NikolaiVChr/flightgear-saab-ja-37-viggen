# FG route manager control property
var rm_cmd = props.globals.getNode("autopilot/route-manager/input", 1);

## Coordinate parser
#
# Parse a waypoint specification using FG route manager.
# 'fp' is an optional flightplan used as context for waypoint disambiguation.
# If unset, the current flightplan is used.
#
var parse_coord = func(string, fp=nil) {
    if (fp != nil) {
        var saved_fp = flightplan();
        var saved_id = saved_fp.current;
        fp.activate();
    }

    var len = flightplan().getPlanSize();
    var coord = nil;

    # Append to flightplan.
    rm_cmd.setValue(string);

    if (flightplan().getPlanSize() > len) {
        # New waypoint was added successfully.
        # Read coordinate and delete from flightplan.
        var wp = flightplan().getWP(len);
        coord = geo.Coord.new().set_latlon(wp.lat, wp.lon);
        rm_cmd.setValue("@delete"~len);
    }

    # restore previous flightplan
    if (fp != nil) {
        saved_fp.activate();
        saved_fp.current = saved_id;
    }

    return coord;
}


## Waypoint objects (geo.Coord wrapper)
var Waypoint = {
    new: func(coord, name="") {
        var wpt = {
            parents: [Waypoint],
            coord: geo.Coord.new(coord),
            name: name,
        };
        return wpt;
    },

    parse: func(string) {
        var coord = parse_coord(string);
        if (coord == nil)
            return nil;
        else
            return Waypoint.new(coord, string);
    },
};


## Airbase objects
var Airbase = {
    fromICAO: func(ICAO) {
        var info = airportinfo(ICAO);
        if (info == nil) return nil;

        var apt = {
            parents: [Airbase],
            coord: geo.Coord.new().set_latlon(info.lat, info.lon, info.elevation),
            name: ICAO,
        };

        apt.runways = [];
        foreach (var rwy_name; keys(info.runways)) {
            var rwy = info.runways[rwy_name];
            append(apt.runways, {
                heading: geo.normdeg(rwy.heading),
                coord:  geo.Coord.new().set_latlon(rwy.lat, rwy.lon, info.elevation),
                name: rwy_name,
                freq: rwy.ils_frequency_mhz,
            });
        }
        apt.runways = sort(apt.runways, Airbase.compare_named_rwy);

        return apt;
    },

    fromCoord: func(coord, heading, freq=nil) {
        var coord = geo.Coord.new(coord);

        var apt = {
            parents: [Airbase],
            coord: coord,
            name: "",
            runways: [
                { heading: geo.normdeg(heading), coord: coord, name: nil, freq: freq, },
                { heading: geo.normdeg(heading+180), coord: coord, name: nil, freq: nil, }
            ],
        };
        return apt;
    },

    compare_named_rwy: func(rwy1, rwy2) {
        var lex = cmp(rwy1.name, rwy2.name);
        if (lex == 0) return 0;

        var size1 = size(rwy1.name);
        var size2 = size(rwy2.name);

        if (size1 < 2 or size1 > 3 or size2 < 2 or size2 > 3)
            # names are messed up
            return lex;

        var dir1 = int(left(rwy1.name, 2));
        var dir2 = int(left(rwy2.name, 2));

        if (dir1 == nil or dir2 == nil)
            # names are messed up
            return lex;

        if (dir1 != dir2)
            return dir1 - dir2;

        if (size1 != size2)
            # rwy without letters has priority
            return size1 - size2;

        var letter1 = substr(rwy1.name, 2, 1);
        var letter2 = substr(rwy2.name, 2, 1);
        var idx1 = !find(letter1, "LCR");
        var idx2 = !find(letter1, "LCR");

        if (idx1 < 0 or idx2 < 0) return lex;

        return idx1 - idx2;
    },
};
