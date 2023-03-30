#### Pylons loading/jettison logic, implemented with station-manager.nas

var TRUE = 1;
var FALSE = 0;


var input = {
    ctrl_arm:   "/controls/armament",
    inertia:    "/fdm/jsbsim/inertia",
    station:    "/payload/armament/station",
    wings_on:   "/fdm/jsbsim/structural/wings/serviceable",
    wow1:       "fdm/jsbsim/gear/unit[1]/WOW",
    xtank_load: "/payload/weight[6]",
    xtank_fuel: "/consumables/fuel/tank[8]",
    sound_tank: "/ja37/sound/jettison-tank",
    sound_jett: "/ja37/sound/jettison-stores",
};

foreach (var prop; keys(input)) {
    input[prop] = props.globals.getNode(input[prop], 1);
}


### Pylon names and station numbers.
# Station numbers correspond to /controls/armament/station[i]
# and are used as id in station-manager.nas
var STATIONS = {
    V7V: 1, # Left wing
    S7V: 2, # Left fuselage
    V7H: 3, # Right wing
    S7H: 4, # Right fuselage
    R7V: 5, # Left outer wing
    R7H: 6, # Right outer wing
};

# JA internal cannon
var INT_AKAN = 0;

var stations_list = [];
foreach(var pylon; keys(STATIONS)) {
    append(stations_list, STATIONS[pylon]);
}
if (variant.JA) append(stations_list, INT_AKAN);



### Operation conditions for stations.

# Does not decide if the station is armed etc. (this is in fire_control.nas),
# just if its not broken/has power.
var operable = func {
    return power.prop.acSecondBool.getBoolValue();
}

# Weapon jettison conditions.
var can_jettison = func {
    return power.prop.dcMainBool.getBoolValue() and !input.wow1.getBoolValue();;
}


### Submodel based weapons
var make_M70 = func(pylon) {
    return stations.SubModelWeapon.new(
        "M70", 100, 6, [4+pylon], [],
        input.ctrl_arm.getChild("station", pylon).getChild("trigger-m70"),
        TRUE, operable, FALSE,
        [pylon+12], input.ctrl_arm.getChild("station", pylon).getChild("jettison-pod"));
}

var make_M55 = func(pylon) {
    return stations.SubModelWeapon.new(
        "M55", 0.5, 150, [9+pylon], [8+pylon],
        input.ctrl_arm.getChild("station", pylon).getChild("trigger-m55"),
        TRUE, operable, FALSE,
        [(pylon == STATIONS.V7V) ? 17 : 18], input.ctrl_arm.getChild("station", pylon).getChild("jettison-pod"));
}

var make_M5555 = func(pylon) {
    return stations.SubModelWeapon.new(
        "M5555", 0.5, 1000, [9+pylon], [8+pylon],
        input.ctrl_arm.getChild("station", pylon).getChild("trigger-m55"),
        TRUE, operable, FALSE,
        [(pylon == STATIONS.V7V) ? 17 : 18], input.ctrl_arm.getChild("station", pylon).getChild("jettison-pod"));
}

var M75 = stations.SubModelWeapon.new(
    "M75", 1, 146, [3], [2,4],
    input.ctrl_arm.getNode("station[0]/trigger"),
    FALSE, operable);



### Pylon load options.
var load_options = {
    "none": {name: "none", content: [], launcherMass: 0, launcherDragArea: 0.0, launcherJettisonable: 0, showNameInsteadOfCount: 1},
    "M75": {name: "m/75 AKAN", content: [M75], launcherMass: 0, launcherDragArea: 0.0, launcherJettisonable: 0, showNameInsteadOfCount: 1},
    "RB-24": {name: "RB 24 Sidewinder", content: ["RB-24"], launcherMass: 86, launcherDragArea: 0.0, launcherJettisonable: 0, showNameInsteadOfCount: 1},
    "RB-24J": {name: "RB 24J Sidewinder", content: ["RB-24J"], launcherMass: 86, launcherDragArea: 0.0, launcherJettisonable: 0, showNameInsteadOfCount: 1},
    "RB-74": {name: "RB 74 Sidewinder", content: ["RB-74"], launcherMass: 86, launcherDragArea: 0.0, launcherJettisonable: 0, showNameInsteadOfCount: 1},
    "RB-71": {name: "RB 71 Skyflash", content: ["RB-71"], launcherMass: 100, launcherDragArea: 0.0, launcherJettisonable: 0, showNameInsteadOfCount: 1},
    "RB-99": {name: "RB 99 AMRAAM", content: ["RB-99"], launcherMass: 90, launcherDragArea: 0.0, launcherJettisonable: 0, showNameInsteadOfCount: 1},
    "RB-04E": {name: "RB 04E", content: ["RB-04E"], launcherMass: 80, launcherDragArea: 0.0, launcherJettisonable: 0, showNameInsteadOfCount: 1},
    "RB-15F": {name: "RB 15F", content: ["RB-15F"], launcherMass: 80, launcherDragArea: 0.0, launcherJettisonable: 0, showNameInsteadOfCount: 1},
    "RB-05A": {name: "RB 05A", content: ["RB-05A"], launcherMass: 80, launcherDragArea: 0.0, launcherJettisonable: 0, showNameInsteadOfCount: 1},
    "RB-5005X": {name: "RB 5005X Torpedo", content: ["RB-5005X"], launcherMass: 80, launcherDragArea: 0.0, launcherJettisonable: 0, showNameInsteadOfCount: 1},
    "RB-75": {name: "RB 75 Maverick", content: ["RB-75"], launcherMass: 100, launcherDragArea: 0.0, launcherJettisonable: 0, showNameInsteadOfCount: 1},
    "M90": {name: "m/90", content: ["M90"], launcherMass: 80, launcherDragArea: 0.0, launcherJettisonable: 0, showNameInsteadOfCount: 1},
    "M71": {name: "m/71 x4", content: ["M71","M71","M71","M71"], launcherMass: 275, launcherDragArea: 0.15, launcherJettisonable: 0, showNameInsteadOfCount: 1},
    "M71R": {name: "m/71 x4 (high drag)", content: ["M71R","M71R","M71R","M71R"], launcherMass: 275, launcherDragArea: 0.15, launcherJettisonable: 0, showNameInsteadOfCount: 1},
    "M70": func(pylon) {
        return {name: "m/70 ARAK", content: [make_M70(pylon)], launcherMass: 230, launcherDragArea: 0.4, launcherJettisonable: 1, showNameInsteadOfCount: 1};
    },
    "M55": func(pylon) {
        return {name: "m/55 AKAN", content: [make_M55(pylon)], launcherMass: 725, launcherDragArea: 0.3, launcherJettisonable: 1, showNameInsteadOfCount: 1};
    },
    "M5555": func(pylon) {
        return {name: "m/5555 ABLA", content: [make_M5555(pylon)], launcherMass: 725, launcherDragArea: 0.3, launcherJettisonable: 1, showNameInsteadOfCount: 1};
    },
};

# Function to resolve the special submodel weapons in the above table.
var load_options_pylon = func(pylon, name) {
    var res = load_options[name];
    # For some load options are factories instead of constants.
    if (typeof(res) == "func") res = res(pylon);
    return res;
}


### Load options available on each pylon.
var sets = {};

# sets are defined using the indices in load_options (above)
if (variant.JA) {
    sets[STATIONS.V7V] = ["none", "RB-74", "RB-71", "RB-99"];
    sets[STATIONS.V7H] = ["none", "RB-74", "RB-71", "RB-99"];
    sets[STATIONS.S7V] = ["none", "RB-74", "RB-99"];
    sets[STATIONS.S7H] = ["none", "RB-74", "RB-99"];
    sets[STATIONS.R7V] = ["none", "RB-74"];
    sets[STATIONS.R7H] = ["none", "RB-74"];
} elsif (variant.SPAJS) {
    sets[STATIONS.V7V] = ["none", "RB-5005X", "M5555"];
    sets[STATIONS.V7H] = ["none", "RB-5005X", "M5555"];
    sets[STATIONS.S7V] = ["none", "RB-5005X"];
    sets[STATIONS.S7H] = ["none", "RB-5005X"];
    sets[STATIONS.R7V] = ["none"];
    sets[STATIONS.R7H] = ["none"];
} else {
    sets[STATIONS.V7V] = ["none", "RB-24J", "RB-74", "RB-04E", "RB-15F", "RB-75", "M55", "M70", "M71", "M71R", "M90"];
    sets[STATIONS.V7H] = ["none", "RB-24J", "RB-74", "RB-04E", "RB-15F", "RB-75", "M55", "M70", "M71", "M71R", "M90"];
    sets[STATIONS.S7V] = ["none", "RB-24", "RB-24J", "RB-74", "RB-05A", "RB-75", "M70", "M71", "M71R"];
    sets[STATIONS.S7H] = ["none", "RB-24", "RB-24J", "RB-74", "RB-05A", "RB-75", "M70", "M71", "M71R"];
    sets[STATIONS.R7V] = ["none", "RB-24J"];
    sets[STATIONS.R7H] = ["none", "RB-24J"];
}

# Lookup actual values in load_options.
foreach(var pylon_name; keys(STATIONS)) {
    var id = STATIONS[pylon_name];

    forindex(var i; sets[id]) {
        var name = sets[id][i];
        if (typeof(name) != "scalar") continue;

        sets[id][i] = load_options_pylon(id, name);
    }
}


### Pylon objects.
var pylons = {};

foreach(var name; keys(STATIONS)) {
    var id = STATIONS[name];

    pylons[id] = stations.Pylon.new(
        name, id,
        [input.ctrl_arm.getChild("station", id).getValue("offsets/x-m"),
         input.ctrl_arm.getChild("station", id).getValue("offsets/y-m"),
         input.ctrl_arm.getChild("station", id).getValue("offsets/z-m")],
        sets[id], id-1,
        input.inertia.getChild("pointmass-weight-lbs", id, 1),
        input.inertia.getChild("pointmass-dragarea-sqft", id, 1),
        operable);
}

if (variant.JA) {
    var M75station = stations.InternalStation.new("M75", 0, [load_options["M75"]],
        input.inertia.getChild("pointmass-weight-lbs", 8, 1), operable);
}


# Pylon lookup functions

# Arg: station number
# Returns corresponding station/pylon object.
var station_by_id = func(id) {
    if (id == INT_AKAN) return M75station;
    else return pylons[id];
}

# Arg: station number
# Returns a string representing the current load:
# "" for empty pylon, or a weapon type as used in 'missile.nas'
var get_pylon_load = func(pylon) {
    return station_by_id(pylon).singleName;
}

# Arg: pylon: station number, types: array of weapon types
# Returns true if the pylon is loaded with one of these weapons.
var is_loaded_with = func(pylon, types) {
    var load = get_pylon_load(pylon);
    foreach (var type; types) if (load == type) return TRUE;
    return FALSE;
}

# Arg: types: array of weapon types, order: array of station numbers, first: index in 'order'
# Find the first pylon in 'order' loaded with a weapon in 'types'.
# If 'first' is defined, start from order[first] instead, and continue in cyclic order until order[first-1].
var find_pylon_by_types = func(types, order, first=0) {
    var i = first;
    var looped = FALSE;
    while (i < first or !looped) {
        if (is_loaded_with(order[i], types)) return order[i];

        i += 1;
        if (i >= size(order)) {
            i = 0;
            looped = TRUE;
        }
    }
    return nil;
}

# Arg: array of weapon types.
# Returns an array of pylon numbers, containing all pylons loaded with one of these types.
var find_all_pylons_by_types = func(types) {
    var res = [];
    foreach(var pylon; stations_list) {
        if (is_loaded_with(pylon, types)) {
            append(res, pylon);
        }
    }
    return res;
}


# Total ammunition of a given type.
var get_ammo = func(type) {
    var count = 0;
    foreach(var pylon; stations_list) {
        count += station_by_id(pylon).getAmmo(type);
    }
    return count;
}



### Weapon ID number for 3D model of weapons on pylons (including over MP).
var weapon_id = {
    "none": 0,
    # Same model for all sidewinders
    "RB-24": 1,
    "RB-24J": 1,
    "RB-74": 1,
    "RB-71": 2,
    "RB-99": 3,
    "RB-04E": 4,
    "RB-15F": 5,
    "RB-05A": 6,
    "RB-5005X": 6,
    "RB-75": 7,
    "M90": 8,
    "M71": 9,
    "M71R": 10,
    "M70": 11,
    "M55": 12,
    "M5555": 12,
};

var make_weapon_id_listener = func(pylon) {
    return func {
        var type = input.station.getValue("id-"~pylon~"-type");
        var id = contains(weapon_id, type) ? weapon_id[type] : 0;

        # Override to show the M71 mounting after jettison.
        var set = input.station.getValue("id-"~pylon~"-set");
        if (set == load_options["M71"].name) {
            id = weapon_id["M71"];
        } elsif (set == load_options["M71R"].name) {
            id = weapon_id["M71R"];
        }

        input.station.setValue("id-"~pylon~"-type-id", id);
    };
};

foreach(var pylon; [STATIONS.V7V, STATIONS.V7H, STATIONS.S7V, STATIONS.S7H]) {
    setlistener(input.station.getNode("id-"~pylon~"-set"), make_weapon_id_listener(pylon), 1, 0);
    setlistener(input.station.getNode("id-"~pylon~"-type"), make_weapon_id_listener(pylon), 1, 0);
}


### Drop tank logic
var xtank_props = {
    weight_lb:  input.xtank_load.getNode("weight-lb", 1),
    selected:   input.xtank_load.getNode("selected", 1),
    fuel_sel:   input.xtank_fuel.getNode("selected", 1),
    jettisoned: input.xtank_fuel.getNode("jettisoned", 1),
    mounted:    input.xtank_fuel.getNode("mounted", 1),
    lvl_norm:   input.xtank_fuel.getNode("level-norm", 1),
};

var drop_tank_weight = getprop("/payload/weight[6]/opt[1]/lbs");

var update_droptank = func (node) {
    var droptank = (node.getValue() == "Drop tank");

    xtank_props.weight_lb.setValue(droptank ? drop_tank_weight : 0);
    xtank_props.fuel_sel.setBoolValue(droptank);
    xtank_props.jettisoned.setBoolValue(!droptank);
    xtank_props.mounted.setBoolValue(droptank);
    if (!droptank) xtank_props.lvl_norm.setValue(0);
}

setlistener(xtank_props.selected, update_droptank, 1, 1);

var set_droptank = func (b) {
    xtank_props.selected.setValue(b ? "Drop tank" : "none");
}


### Jettison
var jettison_pylon = func (pylon) {
    pylon = pylons[pylon];
    if (pylon.currentSet != nil and
        (pylon.currentSet.name == load_options["M71"].name
         or pylon.currentSet.name == load_options["M71R"].name)) {
        # m71 drop in two step, diagonally.
        foreach(var i; [0,2]) {
            if (pylon.weapons[i] != nil) {
                pylon.weapons[i].eject();
                pylon.weapons[i] = nil;
                pylon.calculateMass();
                pylon.calculateFDM();
                pylon.setGUI();
            }
        }

        settimer(func { pylon.jettisonAll(); }, 0.5, 1);
    } else {
        # Anything else is simple
        pylon.jettisonAll();
    }
}

var jettison_tank = func {
    ja37.click();
    if (!can_jettison()) return;
    if (xtank_props.jettisoned.getBoolValue()) return;

    set_droptank(FALSE);
    input.sound_tank.setBoolValue(TRUE);
    settimer(func { input.sound_tank.setBoolValue(FALSE); }, 1.0);
}

var jettison_stores = func {
    ja37.click();
    if (!can_jettison()) return;

    jettison_tank();

    # Do not jettison outer pylons.
    var released = FALSE;
    foreach(var pylon; [STATIONS.V7V, STATIONS.V7H, STATIONS.S7V, STATIONS.S7H]) {
        if (get_pylon_load(pylon) != '') released = TRUE;
        jettison_pylon(pylon);
    }

    if (released) {
        input.sound_jett.setBoolValue(TRUE);
        settimer(func { input.sound_jett.setBoolValue(FALSE); }, 1.0);
    }
}
