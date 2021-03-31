### Logic for loadout quick-select menu

var TRUE = 1;
var FALSE = 0;


var input = {
    payload:    "payload",
    fuel:       "consumables/fuel",
    drop_tank:  "consumables/fuel/tank[8]/mounted",
    fuel_ratio: "fdm/jsbsim/instruments/fuel/true-ratio",
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
    "4x RB 99, 2x RB 74": ["RB-99", "RB-99", "RB-99", "RB-99", "RB-74", "RB-74"],
    "2x RB 99, 4x RB 74": ["RB-99", "RB-74", "RB-99", "RB-74", "RB-74", "RB-74"],
    "2x RB 99, 2x RB 74": ["RB-99", "RB-74", "RB-99", "RB-74", "none", "none"],
    "1x RB 99, 1x RB 74": ["none", "RB-74", "none", "RB-99", "none", "none"],
    "2x RB 71, 4x RB 74": ["RB-71", "RB-74", "RB-71", "RB-74", "RB-74", "RB-74"],
    "2x RB 71, 4x RB 24J": ["RB-71", "RB-24J", "RB-71", "RB-24J", "RB-24J", "RB-24J"],
    "24x ARAK, 2x RB 74": ["M70", "M70", "M70", "M70", "RB-74", "RB-74"],
    "12x ARAK, 2x RB 74": ["RB-74", "M70", "RB-74", "M70", "none", "none"],
    "24x ARAK, 2x RB 24J": ["M70", "M70", "M70", "M70", "RB-24J", "RB-24J"],
    # AJS
    "2x RB 05":             ["none", "RB-05A", "none", "RB-05A", "none", "none"],
    "2x RB 05, 2x AKAN":    ["M55", "RB-05A", "M55", "RB-05A", "none", "none"],
    "2x RB 75":             ["none", "RB-75", "none", "RB-75", "none", "none"],
    "4x RB 75":             ["RB-75", "RB-75", "RB-75", "RB-75", "none", "none"],
    "2x RB 75, 2x AKAN":    ["M55", "RB-75", "M55", "RB-75", "none", "none"],
    "2x AKAN":              ["M55", "none", "M55", "none", "none", "none"],
    "4x RB 74":             ["RB-74", "RB-74", "RB-74", "RB-74", "none", "none"],
    "2x RB 04":             ["RB-04E", "none", "RB-04E", "none", "none", "none"],
    "2x RB 15":             ["RB-15F", "none", "RB-15F", "none", "none", "none"],
    "12x ARAK":             ["none", "M70", "none", "M70", "none", "none"],
    "24x ARAK":             ["M70", "M70", "M70", "M70", "none", "none"],
    "8x m/71":              ["none", "M71", "none", "M71", "none", "none"],
    "16x m/71":             ["M71", "M71", "M71", "M71", "none", "none"],
    "8x m/71 (high drag)":  ["none", "M71R", "none", "M71R", "none", "none"],
    "16x m/71 (high drag)": ["M71R", "M71R", "M71R", "M71R", "none", "none"],
    "2x m/90":              ["M90", "none", "M90", "none", "none", "none"],
};

# List of loadouts to include in the dialogs.
var loadout_list = variant.JA ? [
    # JA loadouts
    "4x RB 99, 2x RB 74",
    "2x RB 99, 4x RB 74",
    "2x RB 99, 2x RB 74",

    "1x RB 99, 1x RB 74",
    "2x RB 71, 4x RB 74",
    "2x RB 71, 4x RB 24J",

    "24x ARAK, 2x RB 74",
    "12x ARAK, 2x RB 74",
    "24x ARAK, 2x RB 24J",
] : [
    # AJS loadouts
    "2x AKAN",
    "2x RB 05",
    "2x RB 05, 2x AKAN",
    "2x RB 75",
    "4x RB 75",
    "2x RB 75, 2x AKAN",

    "12x ARAK",
    "24x ARAK",
    "8x m/71",
    "16x m/71",
    "8x m/71 (high drag)",
    "16x m/71 (high drag)",

    "2x RB 04",
    "2x RB 15",
    "2x m/90",
    "4x RB 74",
];



### Internal reload functions.

# Load a pylon. 'pylon' is the pylon number (see above), and 'option' is the
# loadout option name (weapon), as defined in pylons.load_options
var load_pylon = func(idx, option) {
    pylons.pylons[idx].loadSet(pylons.load_options_pylon(idx, option));
}

# Select a loadout
var set_loadout = func(loadout) {
    forindex(i; loadout) {
        var name = load_pylon(i+1, loadout[i]);
    }
}

# Reload internal stuff
var reload_internal = func() {
    if(variant.JA) {
        pylons.M75station.reloadCurrentSet();
    }

    setprop("ai/submodels/submodel[0]/count", 60);
    setprop("ai/submodels/submodel[1]/count", 60);
}

# Reload previous weapon selection.
var reload_current = func() {
    foreach(var i; keys(pylons.pylons)) pylons.pylons[i].reloadCurrentSet();
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
var internal_cap_norm = 0;
var external_cap_norm = 0;
var total_cap_norm = 0;

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

    internal_cap_norm = internal_cap * fuel_M32norm;
    external_cap_norm = external_cap * fuel_M32norm;
    total_cap_norm = total_cap * fuel_M32norm;
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

    if(variant.JA) {
        var cannon_rounds = getprop("ai/submodels/submodel[3]/count");
        screen.log.write(cannon_rounds ~ " cannon rounds loaded", 0.0, 1.0, 0.0);
    }

    var flares = getprop("ai/submodels/submodel[0]/count") + getprop("ai/submodels/submodel[1]/count");
    screen.log.write(flares ~ " flares loaded", 0.0, 1.0, 0.0);
}


### Final reload functions, for the GUI

var load_loadout = func(loadout) {
    if(!ja37.reload_allowed(must_land_msg)) return;

    set_loadout(loadout);
    reload_internal();
    print_reload_message();
}

var reload = func {
    if(!ja37.reload_allowed(must_land_msg)) return;

    reload_current();
    reload_internal();
    print_reload_message();
}

var load_clean = func() {
    load_loadout(loadouts["clean"]);
}



### Custom Fuel and Payload dialog
#
# Most of the dialog is defined in gui/dialog/loadout.xml,
# but the table of available loadouts is procedurally generated.
var Dialog = {
    # Object initialisation, only called once.
    init: func {
        me.prop = props.globals.getNode("/sim/gui/dialogs/loadout/dialog", 1);
        me.path = "Aircraft/JA37/gui/dialogs/loadout.xml";
        me.state = 0;
        me.listener = setlistener("/sim/signals/reinit-gui", func me.init_dialog(), 1);
    },

    # Dialog initialisation, can be called again to reload the dialog.
    init_dialog: func {
        var state = me.state;
        if(state) me.close();

        # Load the dialog xml file.
        me.prop.removeChildren();
        io.read_properties(me.path, me.prop);
        me.prop.setValue("dialog-name", "loadout");

        # Some elements are to be removed for the JA 37.
        # They are marked with <ajs-only/> (only recognised at dialog top-level)
        if (variant.JA) {
            foreach (var node; me.prop.getChildren()) {
                if (node.getChild("ajs-only") != nil) node.remove();
            }
        }

        # Look for the group used as pylons / loadout list.
        me.pylons_table = nil;
        me.loadout_table = nil;
        foreach(var group; me.prop.getChildren("group")) {
            if(group.getValue("name") == "pylons_table") me.pylons_table = group;
            if(group.getValue("name") == "loadout_table") me.loadout_table = group;
        }
        if(me.loadout_table == nil or me.pylons_table == nil) {
            printlog("warn", "Failed to initialize Saab 37 loadout dialog.");
            return;
        }

        # Fill the loadout list.
        me.setup_pylons_table();
        me.setup_loadout_table();
        me.setup_props();
        me.setup_fuel_slider();

        # Register the dialog.
        fgcommand("dialog-new", me.prop);

        if(state) me.open();
    },

    setup_props: func() {
        # Fuel
        me.fuel_prop = me.prop.getNode("fuel/request-percent", 1);

        # AJS loadout options
        me.outer_rb24j_prop = me.prop.getNode("loadout/load-outer-rb24j", 1);
        me.outer_rb24j_prop.setBoolValue(FALSE);
        me.rb74_prop = me.prop.getNode("loadout/load-rb74", 1);
        me.rb74_prop.setValue("None");
    },

    ### Nasal generated parts of the dialog.

    ## List of pylons

    pylons_order: ["R7V", "V7V", "S7V", "S7H", "V7H", "R7H"],

    setup_pylons_table: func() {
        forindex(var i; me.pylons_order) {
            # Index of the pylon in /payload/weight[i]/
            var weight_id = pylons.STATIONS[me.pylons_order[i]]-1;

            # Add label
            me.pylons_table.addChild("text").setValues({
                "row": 0,
                "col": i,
                "label": me.pylons_order[i],
            });
            # Add load selector
            var combo = me.pylons_table.addChild("combo");
            combo.setValues({
                "row": 1,
                "col": i,
                "pref-width": 130,
                "property": "/payload/weight["~weight_id~"]/selected",
                "enable": "/ja37/reload-allowed",
                "live": "true",
                "binding": { "command": "dialog-apply", },
            });
            # Add values to load selector
            foreach (var opt; props.globals.getNode("payload").getChild("weight", weight_id).getChildren("opt")) {
                combo.addChild("value").setValue(opt.getValue("name"));
            }
        }
    },

    ## List of loadout presets

    setup_loadout_table: func() {
        var table_cols = 3;
        var table_lines = size(loadout_list) / table_cols;

        var col = 0;
        var line = 0;
        foreach(var name; loadout_list) {
            me.add_loadout_entry(col, line, name);
            line += 1;
            if(line >= table_lines) {
                line = 0;
                col += 1;
            }
        }
    },

    add_loadout_entry: func(col, line, name) {
        me.loadout_table.addChild("button").setValues({
            "row": line,
            "col": 2*col,
            "pref-width": 55,
            "pref-height": 25,
            "legend": "load",
            "enable": "/ja37/reload-allowed",
            "binding": {
                "command": "nasal",
                "script": "loadout.Dialog.apply_loadout(\"" ~ name ~ "\")",
            },
        });
        me.loadout_table.addChild("text").setValues({
            "row": line,
            "col": 2*col+1,
            "halign": "left",
            "label": name,
        });
    },

    ### Canvas loadout preview

    # Convert weapon names used in loadouts to weapon names used in the SVG for loadout preview.
    wpn_to_svg_name: {
        "RB-24": "rb24",
        "RB-24J": "rb24",
        "RB-74": "rb74",
        "RB-71": "rb71",
        "RB-99": "rb99",
        "RB-04E": "rb04",
        "RB-15F": "rb15",
        "RB-05A": "rb05",
        "RB-75": "rb75",
        "M90": "m90",
        "M71": "m71",
        "M71R": "m71",
        "M70": "ARAK",
        "M55": "AKAN",
    },

    setup_canvas: func() {
        me.canvas = canvas.get(me.prop.getChild("canvas"));
        me.canvas.setColorBackground(0.2,0.2,0.2,1);

        me.root = me.canvas.createGroup();
        canvas.parsesvg(me.root, "Aircraft/JA37/Nasal/payload/loadout.svg");

        me.cvs_text = [];
        setsize(me.cvs_text, 6);
        foreach(var pylon; keys(pylons.STATIONS)) {
            me.cvs_text[pylons.STATIONS[pylon]-1] = me.root.getElementById("text_"~pylon);
        }

        me.cvs_wpns = {};
        foreach (var pylon; keys(pylons.STATIONS)) {
            me.cvs_wpns[pylon] = {};
            foreach (var type; ["rb24", "rb74", "rb71", "rb99", "rb04", "rb15",
                                "rb05", "rb75", "m71", "m90", "ARAK", "AKAN"]) {
                var elt = me.root.getElementById(type~"_"~pylon);
                if (elt != nil) {
                    elt.hide();
                    me.cvs_wpns[pylon][type] = elt;
                }
            }
        }

        me.cvs_tank_JA = me.root.getElementById("JA_tank");
        me.cvs_tank_AJS = me.root.getElementById("AJS_tank");
        me.cvs_tank_JA.hide();
        me.cvs_tank_AJS.hide();

        # Set update listener
        me.cvs_listeners = {};
        foreach (var pylon; keys(pylons.STATIONS)) {
            var weight_id = pylons.STATIONS[pylon] - 1;
            me.cvs_listeners[pylon] = setlistener("/payload/weight["~weight_id~"]/selected", func {
                Dialog.update_canvas();
            }, 0, 0);
        }
        me.cvs_listeners["tank"] = setlistener(input.drop_tank, func {
            Dialog.show_droptank();
        }, 0, 0);
    },

    destroy_canvas: func() {
        foreach (idx; keys(me.cvs_listeners)) {
            removelistener(me.cvs_listeners[idx]);
        }
        me.cvs_listeners = {};
    },

    update_canvas: func() {
        foreach (var pylon; keys(pylons.STATIONS)) {
            # Hide all
            foreach (var t; keys(me.cvs_wpns[pylon])) {
                me.cvs_wpns[pylon][t].hide();
            }

            # Show selected
            var type = pylons.station_by_id(pylons.STATIONS[pylon]).singleName;
            if (contains(me.wpn_to_svg_name, type)) {
                type = me.wpn_to_svg_name[type];
                me.cvs_wpns[pylon][type].show();
            }
        }
    },

    show_droptank: func() {
        me.cvs_tank_JA.setVisible(variant.JA and input.drop_tank.getBoolValue());
        me.cvs_tank_AJS.setVisible(variant.AJS and input.drop_tank.getBoolValue());
    },

    ### Fuel stuff

    # When touching the fuel slider, refuelling is done with a small delay.
    refuel_delay: 0.2,
    # Rate of update of fuel slider
    fuel_update_delay: 0.5,

    setup_fuel_slider: func() {
        me.refuel_timer = maketimer(me.refuel_delay, func {
            var level = me.fuel_prop.getValue() / 100;
            level = refuel(level);  # returns actual fuel level after refuel
            me.fuel_prop.setValue(level * 100);
        });
        me.refuel_timer.singleShot = 1;

        me.fuel_update_timer = maketimer(me.fuel_update_delay, func {
            Dialog.update_fuel_slider();
        });
        me.fuel_update_timer.simulatedTime = 1;
    },

    update_fuel_slider: func() {
        if (me.refuel_timer.isRunning) return;
        me.fuel_prop.setDoubleValue(input.fuel_ratio.getValue() * 100);
    },

    fuel_slider_callback: func() {
        me.refuel_timer.restart(me.refuel_delay);
    },

    droptank_callback: func() {
        set_droptank(input.drop_tank.getBoolValue());
    },

    ### Loadout presets

    apply_AJS_loadout_options: func(loadout) {
        # Copy loadout vector
        var res = [];
        setsize(res, 6);
        forindex(var i; res) res[i] = loadout[i];

        if (me.outer_rb24j_prop.getBoolValue()) {
            res[4] = "RB-24J";
            res[5] = "RB-24J";
        }

        # Load RB 74 on main pylons. Load on empty pylon if possible.
        # If there is a choice, load on fuselage pylon.
        var rb74 = me.rb74_prop.getValue();
        if (streq(rb74, "Left") or streq(rb74, "Both")) {
            if (res[1] == "none") res[1] = "RB-74";
            elsif (res[0] == "none") res[0] = "RB-74";
            else res[1] = "RB-74";
        }
        if (streq(rb74, "Right") or streq(rb74, "Both")) {
            if (res[3] == "none") res[3] = "RB-74";
            elsif (res[2] == "none") res[2] = "RB-74";
            else res[3] = "RB-74";
        }

        return res;
    },

    apply_loadout: func(name) {
        var loadout = loadouts[name];
        if (variant.AJS) {
            loadout = me.apply_AJS_loadout_options(loadout);
        }
        load_loadout(loadout);
    },

    open: func() {
        if(me.state) return;
        if(!ja37.reload_allowed(must_land_msg)) return;
        fgcommand("dialog-show", me.prop);
        me.setup_canvas();
        me.update_canvas();
        me.show_droptank();
        me.update_fuel_slider();
        me.fuel_update_timer.start();
        me.state = 1;
    },
    close: func() {
        if(!me.state) return;
        me.destroy_canvas();
        me.fuel_update_timer.stop();
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
