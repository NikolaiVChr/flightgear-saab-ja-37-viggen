# FG route manager control property
var rm_cmd = props.globals.getNode("autopilot/route-manager/input", 1);

var TYPE = {
    WAYPOINT: 1,
    AIRBASE: 2,
    RUNWAY: 3,
};

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
            type: TYPE.WAYPOINT,
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
#
# members:
# - name
# - coord
# - runway_list
# - runways (hash table)
#
var Airbase = {
    # Create object for real ICAO airport
    fromICAO: func(ICAO) {
        var info = airportinfo(ICAO);
        if (info == nil) return nil;

        var apt = {
            parents: [Airbase],
            type: TYPE.AIRBASE,
            coord: geo.Coord.new().set_latlon(info.lat, info.lon, info.elevation),
            name: ICAO,
            runways: {},
            runway_list: [],
        };

        foreach (var rwy_name; keys(info.runways)) {
            var rwy = info.runways[rwy_name];
            append(apt.runway_list, Runway.new(
                parent: apt,
                heading: geo.normdeg(rwy.heading),
                coord:  geo.Coord.new().set_latlon(rwy.lat, rwy.lon, info.elevation),
                name: rwy_name,
                freq: rwy.ils_frequency_mhz
            ));
        }
        apt.runway_list = sort(apt.runway_list, Runway.compare_heading);

        foreach (var rwy; apt.runway_list) {
            apt.runways[rwy.name] = rwy;
        }

        return apt;
    },

    # Create airport anywhere from coordinate and heading (incl reciprocal runway).
    fromCoord: func(coord, heading, freq=nil) {
        var coord = geo.Coord.new(coord);

        var apt = {
            parents: [Airbase],
            type: TYPE.AIRBASE,
            coord: coord,
            name: "",
        };
        apt.runway_list = [
            Runway.new(parent: apt, heading: geo.normdeg(heading), coord: coord, freq: freq),
            Runway.new(parent: apt, heading: geo.normdeg(heading + 180), coord: coord),
        ];

        foreach (var rwy; apt.runway_list) {
            apt.runways[rwy.name] = rwy;
        }

        return apt;
    },
};

## Runway objects
#
# members:
# - name (optional)
# - coord: threshold position
# - heading
# - freq: ILS frequency
# - parent: parent Airbase object
var Runway = {
    new: func(parent, coord, heading, name=nil, freq=nil) {
        return {
            parents: [Runway],
            type: TYPE.RUNWAY,
            parent: parent,
            name: name,
            coord: coord,
            heading: heading,
            freq: freq,
        };
    },

    # Cycling order for runways:
    # - sort by heading
    # - sort suffix: XX < XXL < XXC < XXR
    # fallback to lexicographic order if name is invalid
    compare_heading: func(rwy1, rwy2) {
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
        var idx1 = find(letter1, "LCR");
        var idx2 = find(letter1, "LCR");

        if (idx1 < 0 or idx2 < 0) return lex;

        return idx1 - idx2;
    },
};


var as_airbase = func(wpt) {
    if (wpt.type == TYPE.AIRBASE)
        return wpt;
    elsif (wpt.type == TYPE.RUNWAY)
        return wpt.parent;
    else
        return nil;
};
