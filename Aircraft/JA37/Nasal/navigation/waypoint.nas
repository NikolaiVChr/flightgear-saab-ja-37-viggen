#### AJS Waypoint objects

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
var parse_wp = func(string, fp=nil) {
    if (fp != nil) {
        var saved_fp = flightplan();
        var saved_id = saved_fp.current;
        fp.activate();
    }

    var len = flightplan().getPlanSize();
    var wp = nil;

    # Append to flightplan.
    rm_cmd.setValue(string);

    if (flightplan().getPlanSize() > len) {
        # New waypoint was added successfully.
        # Read coordinate and delete from flightplan.
        wp = flightplan().getWP(len);
        if (!navigation.wp_has_position(wp))
            wp = nil;

        rm_cmd.setValue("@delete"~len);
    }

    # restore previous flightplan
    if (fp != nil) {
        saved_fp.activate();
        saved_fp.current = saved_id;
    }

    return wp;
}


## Waypoint objects (geo.Coord wrapper)
var Waypoint = {
    from_ghost: func(ghost) {
        var wpt = {
            parents: [Waypoint],
            type: TYPE.WAYPOINT,
            coord: geo.Coord.new().set_latlon(ghost.lat, ghost.lon),
            name: ghost.id,
            ghost: ghost,
        };
        return wpt;
    },

    from_coord: func(coord, name="") {
        var wpt = {
            parents: [Waypoint],
            type: TYPE.WAYPOINT,
            coord: geo.Coord.new(coord),
            name: name,
            ghost: nil,
        };
        return wpt;
    },

    offset_copy: func(wpt, heading, dist) {
        var wpt = Waypoint.from_coord(wpt.coord, wpt.name);
        wpt.move(heading, dist);
        return wpt;
    },

    move: func(heading, dist) {
        me.ghost = nil; # no longer valid
        me.coord.apply_course_distance(heading, dist*1000);
    },

    parse: func(string) {
        var wp = parse_wp(string);
        if (wp == nil)
            return nil;
        else
            return Waypoint.from_ghost(wp);
    },

    to_wp_ghost: func {
        if (me.ghost != nil)
            return me.ghost;
        else
            return createWP(me.coord, me.name);
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
        else return Airbase.from_ghost(info);
    },

    from_ghost: func (ghost) {
        var apt = {
            parents: [Airbase],
            type: TYPE.AIRBASE,
            coord: geo.Coord.new().set_latlon(ghost.lat, ghost.lon, ghost.elevation),
            name: ghost.id,
            ghost: ghost,
            runways: {},
            runway_list: [],
        };

        foreach (var rwy_name; keys(ghost.runways)) {
            var rwy = ghost.runways[rwy_name];
            append(apt.runway_list, Runway.from_ghost(apt, rwy));
        }
        apt.runway_list = sort(apt.runway_list, Runway.compare_heading);

        foreach (var rwy; apt.runway_list) {
            apt.runways[rwy.name] = rwy;
        }

        return apt;
    },

    # Create airport anywhere from coordinate and heading (incl reciprocal runway).
    from_coord: func(coord, heading, freq=nil) {
        var coord = geo.Coord.new(coord);

        var apt = {
            parents: [Airbase],
            type: TYPE.AIRBASE,
            coord: coord,
            name: "",
            ghost: nil,
            runways: {},
        };
        apt.runway_list = [
            Runway.from_coord(parent: apt, heading: geo.normdeg(heading), coord: coord, freq: freq),
            Runway.from_coord(parent: apt, heading: geo.normdeg(heading + 180), coord: coord),
        ];

        foreach (var rwy; apt.runway_list) {
            apt.runways[rwy.name] = rwy;
        }

        return apt;
    },

    to_wp_ghost: func {
        if (me.ghost != nil)
            return me.ghost;
        else
            return createWP(me.coord, me.name);
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
    from_ghost: func(parent, ghost) {
        return {
            parents: [Runway],
            type: TYPE.RUNWAY,
            parent: parent,
            name: ghost.id,
            ghost: ghost,
            # runway ghosts don't have elevations...
            coord: geo.Coord.new().set_latlon(ghost.lat, ghost.lon, parent.coord.alt()),
            heading: geo.normdeg(ghost.heading),
            freq: ghost.ils_frequency_mhz,
        };
    },

    from_coord: func(parent, coord, heading, name=nil, freq=nil) {
        return {
            parents: [Runway],
            type: TYPE.RUNWAY,
            parent: parent,
            name: name,
            ghost: nil,
            coord: coord,
            heading: heading,
            freq: freq,
        };
    },

    to_wp_ghost: func {
        if (me.ghost != nil)
            return me.ghost;
        else
            return createWP(me.coord, me.name);
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
    if (typeof(wpt) != "hash" or !contains(wpt, "type"))
        return nil;
    elsif (wpt.type == TYPE.AIRBASE)
        return wpt;
    elsif (wpt.type == TYPE.RUNWAY)
        return wpt.parent;
    else
        return nil;
};
