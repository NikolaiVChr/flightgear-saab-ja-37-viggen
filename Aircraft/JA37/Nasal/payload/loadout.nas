### Logic for loadout quick-select menu

var TRUE = 1;
var FALSE = 0;


var input = {
    payload:    "payload",
    fuel:       "consumables/fuel",
    drop_tank:  "consumables/fuel/tank[8]/mounted",
};

foreach(var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}



# A loadout is specified as an array of six weapon names, corresponding to the
# six pylons (excluding the center one).
# The order of pylons is:
#   0: left wing
#   1: left fuselage
#   2: right wing
#   3: right fuselage
#   4: left outer wing
#   5: right outer wing
# !! This is the same order as pylons.STATIONS, but shifted by 1.

# Weapon names are defined by 'pylons.load_options' (pylons.nas)

# Full list of known loadouts
var loadouts = {
    "clean": ["none", "none", "none", "none", "none", "none"],
    # JA
    "4x RB 99, 2x RB 74": ["rb99", "rb99", "rb99", "rb99", "rb74", "rb74"],
    "2x RB 99, 4x RB 74": ["rb99", "rb74", "rb99", "rb74", "rb74", "rb74"],
    "2x RB 99, 2x RB 74": ["rb99", "rb74", "rb99", "rb74", "none", "none"],
    "1x RB 99, 1x RB 74": ["none", "rb74", "none", "rb99", "none", "none"],
    "24x M 70, 2x RB 74": ["m70", "m70", "m70", "m70", "rb74", "rb74"],
    "A/A anno 1979": ["rb71", "rb24j", "rb71", "rb24j", "rb24j", "rb24j"],
    "A/A anno 1987": ["rb71", "rb74", "rb71", "rb74", "rb74", "rb74"],
    "A/G anno 1979": ["m70", "m70", "m70", "m70", "rb24j", "rb24j"],
    # AJS
    "2x RB 04, 1x RB 74": ["rb04", "rb74", "rb04", "none", "none", "none"],
    "2x RB 15, 2x RB 74": ["rb15", "rb74", "rb15", "rb74", "none", "none"],
    "2x RB 05, 2x RB 74, 2x RB 24J": ["rb74", "rb05", "rb74", "rb05", "rb24j", "rb24j"],
    "2x RB 05, 2x AKAN, 2x RB 24J": ["m55", "rb05", "m55", "rb05", "rb24j", "rb24j"],
    "1x RB 05, 1x RB 74, 2x AKAN": ["m55", "rb74", "m55", "rb05", "none", "none"],
    "4x RB 75, 2x RB 24J": ["rb75", "rb75", "rb75", "rb75", "rb24j", "rb24j"],
    "2x RB 75, 2x RB 74, 2x RB 24J": ["rb74", "rb75", "rb74", "rb75", "rb24j", "rb24j"],
    "1x RB 75, 1x RB 74, 2x AKAN": ["m55", "rb74", "m55", "rb75", "none", "none"],
    "4x RB 74, 2x RB 24J": ["rb74", "rb74", "rb74", "rb74", "rb24j", "rb24j"],
    "2x RB 74, 2x AKAN, 2x RB 24J": ["m55", "rb74", "m55", "rb74", "rb24j", "rb24j"],
    "24x M 70, 2x RB 24J": ["m70", "m70", "m70", "m70", "rb24j", "rb24j"],
    "18x M 70, 1x RB 74": ["m70", "rb74", "m70", "m70", "none", "none"],
    "16x M 71, 2x RB 24J": ["m71", "m71", "m71", "m71", "rb24j", "rb24j"],
    "12x M 71, 1x RB 74": ["m71", "rb74", "m71", "m71", "none", "none"],
    "16x M 71R, 2x RB 24J": ["m71r", "m71r", "m71r", "m71r", "rb24j", "rb24j"],
    "12x M 71R, 1x RB 74": ["m71r", "rb74", "m71r", "m71r", "none", "none"],
    "2x M 90, 2x RB 74": ["m90", "rb74", "m90", "rb74", "none", "none"],
    # AJ
    "2x RB 04, 1x RB 24J": ["rb04", "rb24j", "rb04", "none", "none", "none"],
    "2x RB 05, 2x AKAN": ["m55", "rb05", "m55", "rb05", "none", "none"],
    "1x RB 05, 1x RB 24J, 2x AKAN": ["m55", "rb24j", "m55", "rb05", "none", "none"],
    "2x RB 75, 2x AKAN": ["m55", "rb75", "m55", "rb75", "none", "none"],
    "1x RB 75, 1x RB 24J, 2x AKAN": ["m55", "rb24j", "m55", "rb75", "none", "none"],
    "2x RB 24J, 2x AKAN": ["m55", "rb24j", "m55", "rb24j", "none", "none"],
    "24x M 70": ["m70", "m70", "m70", "m70", "none", "none"],
    "18x M 70, 1x RB 24J": ["m70", "rb24j", "m70", "m70", "none", "none"],
    "16x M 71": ["m71", "m71", "m71", "m71", "none", "none"],
    "12x M 71, 1x RB 24J": ["m71", "rb24j", "m71", "m71", "none", "none"],
    "16x M 71R": ["m71r", "m71r", "m71r", "m71r", "none", "none"],
    "12x M 71R, 1x RB 24J": ["m71r", "rb24j", "m71r", "m71r", "none", "none"],
};

# List of loadouts to include in the dialogs.
var JA_loadouts = [
    "4x RB 99, 2x RB 74",
    "2x RB 99, 4x RB 74",
    "2x RB 99, 2x RB 74",
    "1x RB 99, 1x RB 74",
    "24x M 70, 2x RB 74",
    "A/A anno 1979",
    "A/A anno 1987",
    "A/G anno 1979",
];

var AJS_loadouts = [
    "2x RB 04, 1x RB 74",
    "2x RB 15, 2x RB 74",
    "2x RB 05, 2x RB 74, 2x RB 24J",
    "2x RB 05, 2x AKAN, 2x RB 24J",
    "1x RB 05, 1x RB 74, 2x AKAN",
    "4x RB 75, 2x RB 24J",
    "2x RB 75, 2x RB 74, 2x RB 24J",
    "1x RB 75, 1x RB 74, 2x AKAN",
    "4x RB 74, 2x RB 24J",
    "2x RB 74, 2x AKAN, 2x RB 24J",
    "24x M 70, 2x RB 24J",
    "18x M 70, 1x RB 74",
    "16x M 71, 2x RB 24J",
    "12x M 71, 1x RB 74",
    "16x M 71R, 2x RB 24J",
    "12x M 71R, 1x RB 74",
    "2x M 90, 2x RB 74",
];

var AJ_loadouts = [
    "2x RB 04, 1x RB 24J",
    "2x RB 05, 2x AKAN",
    "1x RB 05, 1x RB 24J, 2x AKAN",
    "2x RB 75, 2x AKAN",
    "1x RB 75, 1x RB 24J, 2x AKAN",
    "2x RB 24J, 2x AKAN",
    "24x M 70",
    "18x M 70, 1x RB 24J",
    "16x M 71",
    "12x M 71, 1x RB 24J",
    "16x M 71R",
    "12x M 71R, 1x RB 24J",
];


### Internal reload functions.

# Load a pylon. 'pylon' is the pylon number (see above), and 'option' is the
# loadout option name (weapon), as defined in pylons.load_options
var load_pylon = func(pylon, option) {
    pylons.pylons[pylon].loadSet(pylons.load_options_pylon(pylon, option));
}

# Select a loadout
var set_loadout = func(loadout) {
    forindex(i; loadout) {
        var name = load_pylon(i+1, loadout[i]);
    }
}

# Reload internal stuff
var reload_internal = func() {
    if(getprop("ja37/systems/variant") == 0) {
        pylons.M75station.reloadCurrentSet();
    }

    setprop("ai/submodels/submodel[0]/count", 60);
    setprop("ai/submodels/submodel[1]/count", 60);
}

# Reload previous weapon selection.
var reload_ammo = func() {
    for(var i=1; i<=6; i+=1) pylons.pylons[i].reloadCurrentSet();
}


### Fuel

# Compute fuel tank capacities
var tank_names = {
    "1": 0,
    "2": 1,
    "3V": 2,
    "3H": 3,
    "5V": 4,
    "5H": 5,
    "4V": 6,
    "4H": 7,
    "external": 8,
};

var tank_cap = nil;
var internal_cap = 0;
var external_cap = 0;
var total_cap = 0;
var fuel_norm2M3 = 1;
var fuel_M32norm = 1;

var compute_tank_cap = func {
    tank_cap = input.fuel.getChildren("tank");
    forindex(var i; tank_cap) {
        tank_cap[i] = tank_cap[i].getValue("capacity-m3");
    }

    internal_cap = 0;
    for(var i=0; i<=7; i+=1) {
        internal_cap += tank_cap[i];
    }
    external_cap = tank_cap[8];
    total_cap = internal_cap + external_cap;

    fuel_norm2M3 = total_cap/getprop("/instrumentation/fuel/indicated-ratio-factor");
    fuel_M32norm = 1/fuel_norm2M3;
}

# Load up to 'request_m3' fuel in the tanks listed in the array 'tanks'.
# Return the actual quantity loaded.
# Fuel is balanced between the tanks.
# In 'tanks', tank numbers may be replaced by their name in 'tank_names' above.
var balance_tanks = func(tanks, request_m3) {
    # Resolve tank names
    forindex(var i; tanks) {
        if(contains(tank_names, tanks[i])) tanks[i] = tank_names[tanks[i]];
    }
    # Compute total capacity of requested tanks
    var cap = 0;
    foreach(var tank; tanks) cap += tank_cap[tank];
    # Proportion to fill
    var norm = math.min(request_m3/cap, 1);
    # Refuel
    foreach(var tank; tanks) {
        input.fuel.getChild("tank", tank).setValue("level-norm", norm);
    }
    return norm * cap;
}


# fuel_norm corresponds to the fuel gauge (fuel_norm=1 -> 100%)
# Returns the actual fuel level after refueling, on the same scale.
var refuel = func(fuel_norm) {
    if(!ja37.reload_allowed(must_land_msg)) {
        return input.fuel.getValue("total-fuel-m3") * fuel_M32norm;
    }

    var fuel_request_m3 = fuel_norm * fuel_norm2M3;
    var fuel_loaded_m3 = 0;

    # According to manual: first tanks 1 and 5, then tanks 2,3,4
    fuel_loaded_m3 += balance_tanks(
        ["1", "5V", "5H"],
        fuel_request_m3 - fuel_loaded_m3
    );
    fuel_loaded_m3 += balance_tanks(
        ["2", "3V", "3H", "4V", "4H"],
        fuel_request_m3 - fuel_loaded_m3
    );
    if(input.drop_tank.getBoolValue()) {
        fuel_loaded_m3 += balance_tanks(["external"], fuel_request_m3 - fuel_loaded_m3);
    }

    return fuel_loaded_m3 * fuel_M32norm;
}

var set_droptank = func(b) {
    if(!ja37.reload_allowed(must_land_msg)) {
        return input.drop_tank.getBoolValue();
    }

    pylons.set_droptank(b);
    return b;
}


### Screen messages
var must_land_msg = "Please land and stop in order to refuel and reload.";

var print_reload_message = func {
    var loaded = {};
    foreach(var pylon; input.payload.getChildren("weight")) {
        var name = pylon.getValue("selected");
        if(name == nil or name == "none" or name == "Drop tank") continue;

        if(contains(loaded, name)) loaded[name] += 1;
        else loaded[name] = 1;
    }

    foreach(var name; keys(loaded)) {
        var msg = sprintf("%sx %s loaded", loaded[name], name);
        screen.log.write(msg, 0.0, 1.0, 0.0);
    }
    if(size(loaded) == 0) {
        screen.log.write("All external weapons removed", 0.0, 1.0, 0.0);
    }

    if(getprop("/ja37/systems/variant") == 0) {
        var cannon_rounds = getprop("ai/submodels/submodel[3]/count");
        screen.log.write(cannon_rounds ~ " cannon rounds loaded", 0.0, 1.0, 0.0);
    }

    var flares = getprop("ai/submodels/submodel[0]/count") + getprop("ai/submodels/submodel[1]/count");
    screen.log.write(flares ~ " flares loaded", 0.0, 1.0, 0.0);
}


### Final reload functions, for the GUI

var load_loadout = func(loadout_name) {
    if(!ja37.reload_allowed(must_land_msg)) return;

    var loadout = loadouts[loadout_name];

    set_loadout(loadout);
    reload_internal();
    print_reload_message();
}

var reload = func {
    if(!ja37.reload_allowed(must_land_msg)) return;
    reload_ammo();
    reload_internal();
    print_reload_message();
}

var load_clean = func() {
    load_loadout("clean");
}


### Procedural loadout dialog
#
#
var Dialog = {
    init: func {
        me.prop = props.globals.getNode("/sim/gui/dialogs/loadout/dialog", 1);
        me.path = "Aircraft/JA37/gui/dialogs/loadout.xml";
        var variant = getprop("/ja37/systems/variant");
        me.loadouts = (variant == 0) ? JA_loadouts : (variant == 2) ? AJS_loadouts : AJ_loadouts;
        me.state = 0;
        me.listener = setlistener("/sim/signals/reinit-gui", func me.init_dialog(), 1);
    },

    init_dialog: func {
        var state = me.state;
        if(state) me.close();

        me.prop.removeChildren();
        io.read_properties(me.path, me.prop);
        me.prop.setValue("dialog-name", "loadout");

        me.table = nil;
        foreach(var group; me.prop.getChildren("group")) {
            if(group.getValue("name") == "procedural_table") {
                me.table = group;
                break;
            }
        }
        if(me.table == nil) {
            printlog("warn", "Failed to initialize Saab 37 loadout dialog.");
            return;
        }

        me.setup_table();

        fgcommand("dialog-new", me.prop);

        if(state) me.open();
    },

    setup_table: func() {
        # Could be improved
        me.table_cols = 2;
        me.table_lines = size(me.loadouts)/me.table_cols;

        var col = 0;
        var line = 0;
        foreach(var name; me.loadouts) {
            me.add_table_entry(col, line, name);
            line += 1;
            if(line >= me.table_lines) {
                line = 0;
                col += 1;
            }
        }
    },

    add_table_entry: func(col, line, name) {
        var button = me.table.addChild("button");
        button.setIntValue("row", line);
        button.setIntValue("col", 2*col);
        button.setDoubleValue("pref-width", 55);
        button.setDoubleValue("pref-height", 25);
        button.setValue("legend", "reload");
        button.setValue("enable", "/ja37/reload-allowed");

        var binding = button.addChild("binding");
        binding.setValue("command", "nasal");
        var script = sprintf("loadout.load_loadout(\"%s\");", name);
        binding.setValue("script", script);

        var group = me.table.addChild("group");
        group.setIntValue("row", line);
        group.setIntValue("col", 2*col+1);
        group.setValue("layout", "hbox");
        group.addChild("text").setValue("label", name);
        group.addChild("empty").setValue("stretch", 1);
    },

    open: func() {
        if(me.state) return;
        if(!ja37.reload_allowed(must_land_msg)) return;
        fgcommand("dialog-show", me.prop);
        me.state = 1;
    },
    close: func() {
        if(!me.state) return;
        fgcommand("dialog-close", me.prop);
        me.state = 0;
    },
    toggle: func() {
        me.state ? me.close() : me.open();
    },
    is_open: func() {
        return me.state;
    },
};

Dialog.init();
compute_tank_cap();
