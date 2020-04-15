### Logic for loadout quick-select menu

var TRUE = 1;
var FALSE = 0;

### Parameters

# Shortcuts for weapon names
var load_option_names = {
    none: "none",
    rb24: "RB 24 Sidewinder",
    rb24j: "RB 24J Sidewinder",
    rb74: "RB 74 Sidewinder",
    rb71: "RB 71 Skyflash",
    rb99: "RB 99 Amraam",
    rb04: "RB 04E Attackrobot",
    rb15: "RB 15F Attackrobot",
    rb05: "RB 05A Attackrobot",
    rb75: "RB 75 Maverick",
    m55: "M55 AKAN",
    m70: "M70 ARAK",
    m71: "M71 Bomblavett",
    m71r: "M71 Bomblavett (Retarded)",
    m90: "M90 Bombkapsel",
    tank: "Drop tank",
};

# A loadout is specified as an array of six weapon names, corresponding to the
# six pylons (excluding the center one).
# The order of pylons is the one in the '*-set.xml' files, that is:
var n_pylons = 6;
var pylons = {
    R7V: 4, # Left outer wing
    V7V: 0, # Left wing
    S7V: 1, # Left fuselage
    S7H: 3, # Right fuselage
    V7H: 2, # Right wing
    R7H: 5, # Right outer wing
    C7: 6,  # Center, only used for drop tank
};

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


### Input properties
var input = {
    payload: "payload",
    fuel: "consumables/fuel",
    fuel_request: "payload/fuel-requested-percent",
    mpmsg: "payload/armament/msg",
    wow: "fdm/jsbsim/gear/unit[0]/WOW",
    wheelspd: "fdm/jsbsim/gear/unit[0]/wheel-speed-fps",
};

foreach(name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}


### Internal reload functions.

# Reload all the internal stuff: gun (for JA) and flares
var reload_internal = func() {
    if(getprop("ja37/systems/variant") == 0) {
        setprop("ai/submodels/submodel[3]/count", 146);
        setprop("ai/submodels/submodel[4]/count", 146);
    }

    setprop("ai/submodels/submodel[0]/count", 60);
    setprop("ai/submodels/submodel[1]/count", 60);
};

var get_full_name = func(name) {
    if(contains(load_option_names, name)) return load_option_names[name];
    else return name;
}

# Load a pylon. 'pylon' is the pylon number (see above), and 'option' is the
# loadout option name (weapon).
# 'option' can either be the full name, or a short name as defined in 'load_option_names'
var load_pylon = func(pylon, option) {
    option = get_full_name(option);
    input.payload.getChild("weight", pylon).setValue("selected", option);
}

# Select a loadout
var set_loadout = func(loadout) {
    forindex(i; loadout) {
        var name = load_pylon(i, loadout[i]);
    };
};


var on_ground = func() {
    return input.wow.getBoolValue() and (input.wheelspd.getValue() < 1);
};

var reload_allowed = func() {
    if(input.mpmsg.getBoolValue() and !on_ground()) {
        screen.log.write("Please land and stop in order to reload/refuel.");
        return FALSE;
    }
    return TRUE;
};


### Screen messages
var loaded_gun_flares_message = func {
    if(getprop("/ja37/systems/variant") == 0) {
        screen.log.write("146 cannon rounds loaded", 0.0, 1.0, 0.0);
    }
    screen.log.write("60 flares loaded", 0.0, 1.0, 0.0);
}

var loaded_loadout_message = func {
    var loaded = {};
    foreach(pylon; input.payload.getChildren("weight")) {
        var name = pylon.getValue("selected");
        if(name == nil or name == "none" or name == "Drop tank") continue;

        if(contains(loaded, name)) loaded[name] += 1;
        else loaded[name] = 1;
    }

    foreach(name; keys(loaded)) {
        var msg = sprintf("%sx %s loaded", loaded[name], name);
        screen.log.write(msg, 0.0, 1.0, 0.0);
    }
    if(size(loaded) == 0) {
        screen.log.write("All external weapons removed", 0.0, 1.0, 0.0);
    }
}


### Final reload functions, for the GUI

var reload_loadout = func(loadout_name) {
    if(!reload_allowed()) return;

    var loadout = loadouts[loadout_name];

    reload_internal();
    set_loadout(loadout);
    loaded_gun_flares_message();
    loaded_loadout_message();
}

var reload_gun_flares = func {
    if(!reload_allowed()) return;
    reload_internal();
    loaded_gun_flares_message();
}

var reload_clean = func {
    reload_loadout("clean");
}


### Procedural loadout dialog
#
#
var Dialog = {
    init: func {
        me.prop = props.globals.getNode("/sim/gui/dialogs/loadout/dialog", 1);
        me.path = "Aircraft/JA37/gui/dialogs/loadout.xml";
        if(getprop("/ja37/systems/variant") == 0) {
            me.loadouts = JA_loadouts;
        } else {
            me.loadouts = AJS_loadouts;
        }
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
        foreach(group; me.prop.getChildren("group")) {
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
        foreach(name; me.loadouts) {
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

        var binding = button.addChild("binding");
        binding.setValue("command", "nasal");
        var script = sprintf("loadout.reload_loadout(\"%s\");", name);
        binding.setValue("script", script);

        var group = me.table.addChild("group");
        group.setIntValue("row", line);
        group.setIntValue("col", 2*col+1);
        group.setValue("layout", "hbox");
        group.addChild("text").setValue("label", name);
        group.addChild("empty").setValue("stretch", 1);
    },

    open: func() {
        if(!reload_allowed()) return;
        fgcommand("dialog-show", me.prop);
        me.state = 1;
    },
    close: func() {
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
