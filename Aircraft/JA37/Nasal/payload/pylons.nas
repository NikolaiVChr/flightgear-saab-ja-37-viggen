var TRUE = 1;
var FALSE = 0;


var input = {
    ctrl_arm:   "/controls/armament",
    inertia:    "/fdm/jsbsim/inertia",
    station:    "/payload/armament/station",
};

foreach (var prop; keys(input)) {
    input[prop] = props.globals.getNode(input[prop], 1);
}


# pylon names
var STATIONS = {
    KCA: 0, # Internal gun mount
    V7V: 1, # Left wing
    S7V: 2, # Left fuselage
    V7H: 3, # Right wing
    S7H: 4, # Right fuselage
    R7V: 5, # Left outer wing
    R7H: 6, # Right outer wing
    C7: 7,  # Center, only used for drop tank
};


var can_fire = func {
    return TRUE;
}

var can_jettison = func {
    return TRUE;
}


var make_M70 = func(pylon) {
    return stations.SubModelWeapon.new(
        "M70 ARAK", 100, 6, [4+pylon], [],
        input.ctrl_arm.getChild("station", pylon).getChild("trigger-m70"),
        TRUE, can_fire);
}

var make_M55 = func(pylon) {
    return stations.SubModelWeapon.new(
        "M55 AKAN", 0.5, 150, [4+pylon], [],
        input.ctrl_arm.getChild("station", pylon).getChild("trigger-m70"),
        TRUE, can_fire);
}

var M75 = stations.SubModelWeapon.new(
    "M75 AKAN", 1, 146, [3,4], [2],
    input.ctrl_arm.getNode("station[0]/trigger"),
    FALSE, can_fire);


var tank = stations.FuelTank.new("Drop tank", "tank", 8, 275, "/payload/weight[6]/drop-tank");



# Pylon load options.
var load_options_table = {
    none: {name: "none", content: [], fireOrder: [], launcherMass: 0, launcherDragArea: 0.0, launcherJettisonable: 0, showLongTypeInsteadOfCount: 1},
    tank: {name: "Drop tank", content: [tank], fireOrder: [0], launcherMass: 211.64, launcherDragArea: 0.0, launcherJettisonable: 1, showLongTypeInsteadOfCount: 1},
    m75: {name: "M75 AKAN", content: [M75], fireOrder: [0], launcherMass: 0, launcherDragArea: 0.0, launcherJettisonable: 0, showLongTypeInsteadOfCount: 1},
    rb24: {name: "RB 24 Sidewinder", content: ["rb-24"], fireOrder: [0], launcherMass: 86, launcherDragArea: 0.0, launcherJettisonable: 0, showLongTypeInsteadOfCount: 1},
    rb24j: {name: "RB 24J Sidewinder", content: ["rb-24j"], fireOrder: [0], launcherMass: 86, launcherDragArea: 0.0, launcherJettisonable: 0, showLongTypeInsteadOfCount: 1},
    rb74: {name: "RB 74 Sidewinder", content: ["rb-74"], fireOrder: [0], launcherMass: 86, launcherDragArea: 0.0, launcherJettisonable: 0, showLongTypeInsteadOfCount: 1},
    rb71: {name: "RB 71 Skyflash", content: ["rb-71"], fireOrder: [0], launcherMass: 100, launcherDragArea: 0.0, launcherJettisonable: 0, showLongTypeInsteadOfCount: 1},
    rb99: {name: "RB 99 AMRAAM", content: ["rb-99"], fireOrder: [0], launcherMass: 90, launcherDragArea: 0.0, launcherJettisonable: 0, showLongTypeInsteadOfCount: 1},
    rb04: {name: "RB 04E Attackrobot", content: ["rb-04e"], fireOrder: [0], launcherMass: 80, launcherDragArea: 0.0, launcherJettisonable: 0, showLongTypeInsteadOfCount: 1},
    rb15: {name: "RB 15F Attackrobot", content: ["rb-15f"], fireOrder: [0], launcherMass: 80, launcherDragArea: 0.0, launcherJettisonable: 0, showLongTypeInsteadOfCount: 1},
    rb05: {name: "RB 05A Attackrobot", content: ["rb-05a"], fireOrder: [0], launcherMass: 80, launcherDragArea: 0.0, launcherJettisonable: 0, showLongTypeInsteadOfCount: 1},
    rb75: {name: "RB 75 Maverick", content: ["rb-05a"], fireOrder: [0], launcherMass: 100, launcherDragArea: 0.0, launcherJettisonable: 0, showLongTypeInsteadOfCount: 1},
    m90: {name: "M90 Bombkapsel", content: ["m90"], fireOrder: [0], launcherMass: 80, launcherDragArea: 0.0, launcherJettisonable: 0, showLongTypeInsteadOfCount: 1},
    m71: {name: "M71 Bomblavett", content: ["m71","m71","m71","m71"], fireOrder: [0,1,2,3], launcherMass: 275, launcherDragArea: 0.0, launcherJettisonable: 1, showLongTypeInsteadOfCount: 1},
    m71r: {name: "M71 Bomblavett (Retarded)", content: ["m71r","m71r","m71r","m71r"], fireOrder: [0,1,2,3], launcherMass: 275, launcherDragArea: 0.0, launcherJettisonable: 1, showLongTypeInsteadOfCount: 1},
    m70: func(pylon) {
        return {name: "M70 ARAK", content: [make_M70(pylon)], fireOrder: [0], launcherMass: 230, launcherDragArea: 0.0, launcherJettisonable: 1, showLongTypeInsteadOfCount: 1};
    },
    m55: func(pylon) {
        return {name: "M55 AKAN", content: [make_M55(pylon)], fireOrder: [0], launcherMass: 725, launcherDragArea: 0.0, launcherJettisonable: 1, showLongTypeInsteadOfCount: 1};
    },
};

# Function, to resolve the special submodel weapons in the above table.
var load_options = func(pylon, name) {
    if (name == "m70" or name == "m55") {
        return load_options_table[name](pylon);
    } else {
        return load_options_table[name];
    }
}


# Load option available on each pylon.
var sets = {};

# Use indices for load_options to define sets.
sets[STATIONS.C7] = ["none", "tank"];

if (getprop("/ja37/systems/variant") == 0) {
    sets[STATIONS.V7V] = sets[STATIONS.V7H] = ["none", "rb24j", "rb74", "rb71", "rb99", "m70"];
    sets[STATIONS.S7V] = sets[STATIONS.S7H] = ["none", "rb24j", "rb74", "rb99", "m70"];
    sets[STATIONS.R7V] = sets[STATIONS.R7H] = ["none", "rb24j", "rb74"];
} elsif (getprop("/ja37/systems/variant") == 1) {
    sets[STATIONS.V7V] = sets[STATIONS.V7H] = ["none", "rb04", "m55", "m70", "m71", "m71r"];
    sets[STATIONS.S7V] = sets[STATIONS.S7H] = ["none", "rb24", "rb24j", "rb05", "rb75", "m70", "m71", "m71r"];
    sets[STATIONS.R7V] = sets[STATIONS.R7H] = ["none"];
} else {
    sets[STATIONS.V7V] = sets[STATIONS.V7H] = ["none", "rb24", "rb24j", "rb74", "rb04", "rb15", "rb75", "m55", "m70", "m71", "m71r", "m90"];
    sets[STATIONS.S7V] = sets[STATIONS.S7H] = ["none", "rb24", "rb24j", "rb74", "rb05", "rb75", "m70", "m71", "m71r"];
    sets[STATIONS.R7V] = sets[STATIONS.R7H] = ["none", "rb24", "rb24j"];
}

# Lookup actual values in load_options.
foreach(var pylon_name; keys(STATIONS)) {
    if (pylon_name == "KCA") continue;
    var id = STATIONS[pylon_name];

    forindex(var i; sets[id]) {
        var name = sets[id][i];
        if (typeof(name) != "scalar") continue;

        sets[id][i] = load_options(id, name);
    }
}


# Pylon objects.
var pylon_names = {};
pylon_names[STATIONS.V7V] = "Left wing pylon";
pylon_names[STATIONS.V7H] = "Right wing pylon";
pylon_names[STATIONS.S7V] = "Left fuselage pylon";
pylon_names[STATIONS.S7H] = "Right fuselage pylon";
pylon_names[STATIONS.R7V] = "Left outer wing pylon";
pylon_names[STATIONS.R7H] = "Right outer wing pylon";
pylon_names[STATIONS.C7] = "Center fuselage pylon";

var pylons = {};

foreach(var name; keys(STATIONS)) {
    if (name == "KCA") continue;
    var id = STATIONS[name];

    pylons[id] = stations.Pylon.new(
        pylon_names[id], id,
        [input.ctrl_arm.getChild("station", id).getValue("offsets/x-m"),
         input.ctrl_arm.getChild("station", id).getValue("offsets/y-m"),
         input.ctrl_arm.getChild("station", id).getValue("offsets/z-m")],
        sets[id], id-1,
        input.inertia.getChild("pointmass-weight-lbs", id, 1),
        input.inertia.getChild("pointmass-dragarea-sqft", id, 1),
        can_fire);
}

if (getprop("/ja37/systems/variant") == 0) {
    var M75station = stations.InternalStation.new("M75 AKAN", 0, [load_options_table.m75],
        input.inertia.getChild("pointmass-weight-lbs", 8, 1), can_fire);
}



# Weapon ID number for model/MP
var weapon_id = {
    "none": 0,
    # Same model for all sidewinders
    "RB 24 Sidewinder": 1,
    "RB 24J Sidewinder": 1,
    "RB 74 Sidewinder": 1,
    "RB 71 Skyflash": 2,
    "RB 99 AMRAAM": 3,
    "RB 04E Attackrobot": 4,
    "RB 15F Attackrobot": 5,
    "RB 05A Attackrobot": 6,
    "RB 75 Maverick": 7,
    "M90 Bombkapsel": 8,
    "M71 Bomblavett": 9,
    "M71 Bomblavett (Retarded)": 10,
    "M70 ARAK": 11,
    "M55 AKAN": 12,
};

var make_weapon_id_listener = func(pylon) {
    return func {
        var set = input.station.getValue("id-"~pylon~"-set");
        var id = contains(weapon_id, set) ? weapon_id[set] : 0;
        input.station.setValue("id-"~pylon~"-set-id", id);
    };
};

foreach(var pylon; [STATIONS.V7V, STATIONS.V7H, STATIONS.S7V, STATIONS.S7H]) {
    setlistener(input.station.getNode("id-"~pylon~"-set"), make_weapon_id_listener(pylon), 1, 0);
}
