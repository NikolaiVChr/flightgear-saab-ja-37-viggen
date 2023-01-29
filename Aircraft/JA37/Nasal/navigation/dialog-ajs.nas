var TRUE = 1;
var FALSE = 0;


## Edits callbacks

# Run function while inhibiting update of flightplan from dialog fields.
# Arguments are with_input_inhibit(func, args, me, locals),
# same as in call() minus the errors. This rethrows any error.
# This function is reentrant.
#
var with_input_inhibit = func(f, args=nil, m=nil, locals=nil) {
    if (typeof(f) != "func")
        die("Non-callable argument to with_input_inhibit()");

    var previous = inhibit_input_callback;
    inhibit_input_callback = TRUE;

    call(f, args, m, locals, var err = []);

    inhibit_input_callback = previous;

    if (size(err)) die(err);
}

# NEVER touch this variable directly, use wrapper above.
# Otherwise any runtime error will lock up the dialog.
var inhibit_input_callback = FALSE;


var make_wpt_input_listener = func(wp_id) {
    return func(node) {
        if (inhibit_input_callback) return;

        var wp = route.Waypoint.parse(node.getValue());
        if (wp != nil)
            route.set_wpt(wp_id, wp);
        else
            route.unset_wpt(wp_id);

        route.callback_fp_changed();
    }
}

var make_target_input_listener = func(wp_id) {
    return func(node) {
        if (inhibit_input_callback) return;
        if (!route.is_set(wp_id)) return;

        if (node.getBoolValue())
            route.set_tgt(wp_id);
        else
            route.unset_tgt(wp_id);

        route.callback_fp_changed();
    }
}

var make_airbase_input_listener = func(apt_name) {
    return func(node) {
        if (inhibit_input_callback) return;

        var apt_id = route.WPT[apt_name];
        var apt = route.Airbase.fromICAO(node.getValue());
        if (apt != nil)
            route.set_wpt(apt_id, apt);
        else
            route.unset_wpt(apt_id);

        route.callback_fp_changed();
        Dialog.update_runways(apt_name);
    }
}

var make_runway_input_listener = func(apt_name) {
    return func(node) {
        if (inhibit_input_callback) return;

        var apt_id = route.WPT[apt_name];
        var apt = route.as_airbase(route.get_wpt(apt_id));
        if (apt == nil) return;

        var rwy = apt.runways[node.getValue()];
        if (rwy != nil)
            route.set_wpt(apt_id, rwy);
        else
            route.unset_wpt(apt_id);

        route.callback_fp_changed();
    }
}


## Load/save fgfp files

var save_fp = func(path_prop) {
    var path = path_prop.getValue();
    var res = FALSE;
    call(func { res = route.get_fp_ghost().save(path); }, nil, nil, nil, var err = []);
    if (size(err) or !res) {
        logprint(LOG_ALERT, "Failed to save flightplan to: "~path);
        gui.showDialog("savefail");
    }
}

var load_fp = func(path_prop) {
    var path = path_prop.getValue();
    var plan = nil;
    call(func { plan = createFlightplan(path); }, nil, nil, nil, var err = []);
    if (size(err) or plan == nil) {
        logprint(LOG_ALERT, "Failed to load flightplan from: "~path);
        return;
    }

    # Load new route
    with_input_inhibit(func {
        route.unset_all_wpt();

        if (plan.departure != nil) {
            Dialog.data.LS.icao.setValue(plan.departure.id);
            Dialog.update_runways("LS");
            var dep = route.Airbase.from_ghost(plan.departure);
            route.set_wpt(route.WPT.LS, dep);

            if (plan.departure_runway != nil) {
                Dialog.data.LS.runway.setValue(plan.departure_runway.id);
                route.set_wpt(route.WPT.LS, dep.runways[plan.departure_runway.id]);
            }
        } else {
            Dialog.data.LS.icao.setValue("");
            Dialog.update_runways("LS");
        }

        if (plan.destination != nil) {
            Dialog.data.L1.icao.setValue(plan.destination.id);
            Dialog.update_runways("L1");
            var dest = route.Airbase.from_ghost(plan.destination);
            route.set_wpt(route.WPT.L1, dest);

            if (plan.destination_runway != nil) {
                Dialog.data.L1.runway.setValue(plan.destination_runway.id);
                route.set_wpt(route.WPT.L1, dest.runways[plan.destination_runway.id]);
            }
        } else {
            Dialog.data.L1.icao.setValue("");
            Dialog.update_runways("L1");
        }

        # FG flightplans don't have alternates.
        Dialog.data.L2.icao.setValue("");
        Dialog.update_runways("L2");

        # output waypoint number (for the AJS system)
        var wp_idx = 1;
        var skipped_complex = FALSE;

        for (var i=0; i<plan.getPlanSize(); i+=1) {
            var wp = plan.getWP(i);

            # If first / last waypoints are departure/destination, skip them.
            if (i == 0 and navigation.departure_set(plan))
                continue;
            if (i == plan.getPlanSize()-1 and navigation.destination_set(plan))
                continue;

            if (!navigation.wp_has_position(wp)) {
                # Waypoint does not have a meaningfull position (e.g. heading to alt instructions).
                # AJS can't do anything with it, skip it.
                skipped_complex = TRUE;
                logprint(LOG_INFO, "Skipping complex flightplan instructions for waypoint "~wp.id);
                continue;
            }

            if (wp_idx > 9) {
                var msg = sprintf("Flightplan truncated at waypoint %s. AJS is limited 9 waypoints.", wp.id);
                logprint(LOG_ALERT, msg);
                screen.log.write(msg, 1, 0, 0);
                break;
            }

            Dialog.data.B[wp_idx].input.setValue(wp.id);
            route.set_wpt(route.WPT.B | wp_idx, route.Waypoint.from_ghost(wp));

            wp_idx += 1;
        }

        if (skipped_complex)
            screen.log.write("Some complex flightplan legs were skipped.", 1, 0.5, 0);

        # Clear remaining waypoints
        for (; wp_idx<=9; wp_idx+=1) {
            Dialog.data.B[wp_idx].input.setValue("");
        }
    });

    route.callback_fp_changed();
}


## Custom route manager dialog for AJS
var Dialog = {
    init: func {
        var prop = props.globals.getNode("/sim/gui/dialogs/route-manager-ajs", 1);
        me.dialog_prop = prop.getNode("dialog", 1);
        me.data_root = prop.getNode("data", 1);
        me.setup_data_props();

        me.path = "Aircraft/JA37/gui/dialogs/route-manager-ajs.xml";
        me.listeners = [];
        me.state = 0;

        me.reinit_listener = setlistener("/sim/signals/reinit-gui", func me.init_dialog(), 1);
    },

    init_dialog: func {
        var state = me.state;
        if (state) me.close();

        # cleanup
        foreach (var listener; me.listeners) removelistener(listener);
        me.listeners = [];

        # Load dialog xml file
        me.dialog_prop.removeChildren();
        io.read_properties(me.path, me.dialog_prop);
        me.dialog_prop.setValue("dialog-name", "route-manager-ajs");

        # Fill table
        me.table = nil;
        me.table_name = "procedural_table";
        foreach(var group; me.dialog_prop.getChildren("group")) {
            if(group.getValue("name") == me.table_name) {
                me.table = group;
                break;
            }
        }
        if(me.table == nil) {
            logprint(LOG_ALERT, "Failed to initialize AJS 37 route manager dialog: missing element '", me.table_name, "' in ", me.path);
            return;
        }
        me.runway_fields = {};
        me.setup_table();

        # Register
        fgcommand("dialog-new", me.dialog_prop);

        # Use this dialog instead of the default one.
        gui.menuBind("route-manager", "route_dialog.Dialog.open();");
        gui.menuEnable("previous-waypoint", 0);
        gui.menuEnable("next-waypoint", 0);

        if (state) me.open();
    },

    # Table column indices
    COL: {
        APT_NAME: 1,
        APT_ICAO: 2,
        APT_RWY: 3,
        WPT_NAME: 5,
        WPT: 6,
        HEAD: 7,
        DIST: 8,
        TGT: 9,
        POPUP_HEAD: 10,
        POPUP_DIST: 11,
        #WPT_X_NAME: 13,
        #WPT_X: 14,
        #POLY_NAME: 16,
        #POLY: 17,
    },

    airbase_desc: {
        "LS": "dep.",
        "L1": "dest.",
        "L2": "alt.",
    },

    # Big hash table to simplify properties access.
    # data: {
    #   node: (root)
    #   LS: { node, icao, runway },
    #   idem L1,L2
    #   B: [
    #     { node, input, valid, leg_head, leg_dist, target, popup_head, popup_dist },
    #     ...
    #   ],
    # }
    setup_data_props: func {
        me.data = { node: me.data_root, };

        foreach (var apt; keys(me.airbase_desc)) {
            var node = me.data.node.getNode(apt, 1);
            me.data[apt] = {
                node: node,
                icao: node.getNode("icao", 1),
                runway: node.getNode("runway", 1),
            };
        }

        me.data.B = [nil];
        for (var i=1; i<=9; i+=1) {
            var node = me.data.node.getChild("B", i, 1);
            append(me.data.B, {
                node: node,
                input: node.getNode("input", 1),
                valid: node.getNode("valid", 1),
                leg_head: node.getNode("leg-heading", 1),
                leg_dist: node.getNode("leg-dist", 1),
                target: node.getNode("target", 1),
                popup_head: node.getNode("popup-heading", 1),
                popup_dist: node.getNode("popup-dist", 1),
            });
        }
    },

    setup_airbase: func(apt_name, row) {
        me.table.addChild("text").setValues({
            "col":      me.COL.APT_NAME,
            "row":      row,
            "halign":   "left",
            "label":    sprintf(" %s (%s)", apt_name, me.airbase_desc[apt_name]),
        });

        var prop = me.data[apt_name].icao;
        var name = apt_name~"-icao";
        me.table.addChild("input").setValues({
            "col":          me.COL.APT_ICAO,
            "row":          row,
            "name":         name,
            "pref-width":   70,
            "property":     prop.getPath(),
            "live":         TRUE,
            "binding": {
                "command":      "dialog-apply",
                "object-name":  name,
            },
        });
        append(me.listeners, setlistener(prop, make_airbase_input_listener(apt_name), 0, 0));

        var prop = me.data[apt_name].runway;
        var name = apt_name~"-runway";
        me.runway_fields[apt_name] = me.table.addChild("combo");
        me.runway_fields[apt_name].setValues({
            "col":          me.COL.APT_RWY,
            "row":          row,
            "name":         name,
            "pref-width":   70,
            "property":     prop.getPath(),
            "live":         TRUE,
            "binding": {
                "command":      "dialog-apply",
                "object-name":  name,
            },
        });
        me.update_runways(apt_name);
        append(me.listeners, setlistener(prop, make_runway_input_listener(apt_name), 0, 0));
    },

    setup_waypoint: func(i, row) {
        var wp_name = "B"~i;
        var wp_idx = route.WPT.B | i;

        me.table.addChild("text").setValues({
            "col":      me.COL.WPT_NAME,
            "row":      row,
            "halign":   "left",
            "label":    wp_name,
        });

        var prop = me.data.B[i].input;
        var name = "B"~i~"-input";
        me.table.addChild("input").setValues({
            "col":          me.COL.WPT,
            "row":          row,
            "name":         name,
            "pref-width":   180,
            "property":     prop.getPath(),
            "live":         TRUE,
            "binding": {
                "command":      "dialog-apply",
                "object-name":  name,
            },
        });
        append(me.listeners, setlistener(prop, make_wpt_input_listener(wp_idx), 0, 0));

        me.table.addChild("text").setValues({
            "col":      me.COL.HEAD,
            "row":      row,
            "label":    "000",
            "property": me.data.B[i].leg_head.getPath(),
            "live":     TRUE,
        });

        me.table.addChild("text").setValues({
            "col":      me.COL.DIST,
            "row":      row,
            "label":    "999km",
            "halign":   "right",
            "property": me.data.B[i].leg_dist.getPath(),
            "live":     TRUE,
        });

        var prop = me.data.B[i].target;
        prop.setBoolValue(FALSE);
        var name = "B"~i~"-target";
        me.table.addChild("checkbox").setValues({
            "col":          me.COL.TGT,
            "row":          row,
            "name":         name,
            "property":     prop.getPath(),
            "live":         TRUE,
            "enable": {
                "property": me.data.B[i].valid.getPath(),
            },
            "binding": {
                "command":      "dialog-apply",
                "object-name":  name,
            },
        });
        append(me.listeners, setlistener(prop, make_target_input_listener(wp_idx), 0, 0));

        #var prop = me.data.B[i].popup_head;
        #var name = "B"~i~"-popup-heading";
        #me.table.addChild("input").setValues({
        #    "col":          me.COL.POPUP_HEAD,
        #    "row":          row,
        #    "name":         name,
        #    "pref-width":   50,
        #    "property":     prop.getPath(),
        #    "live":         TRUE,
        #    "enable": {
        #        "property": me.data.B[i].valid.getPath(),
        #        "property": me.data.B[i].target.getPath(),
        #    },
        #    "binding": {
        #        "command":      "dialog-apply",
        #        "object-name":  name,
        #    },
        #});

        #var prop = me.data.B[i].popup_dist;
        #var name = "B"~i~"-popup-dist";
        #me.table.addChild("input").setValues({
        #    "col":          me.COL.POPUP_DIST,
        #    "row":          row,
        #    "name":         name,
        #    "pref-width":   40,
        #    "property":     prop.getPath(),
        #    "live":         TRUE,
        #    "enable": {
        #        "property": me.data.B[i].valid.getPath(),
        #        "property": me.data.B[i].target.getPath(),
        #    },
        #    "binding": {
        #        "command":      "dialog-apply",
        #        "object-name":  name,
        #    },
        #});
    },

    setup_table: func {
        # Airbases
        for (var i=0; i<=2; i+=1) {
            var apt_name = i==0 ? "LS" : "L"~i;
            var row = i+2;
            me.setup_airbase(apt_name, row);
        }

        # Waypoints
        for (var i=1; i<=9; i+=1) {
            var row = i+1;
            me.setup_waypoint(i, row);
        }

        me.update_legs();
    },

    update_runways: func(apt_name) {
        var apt_id = route.WPT[apt_name];
        var apt = route.as_airbase(route.get_wpt(apt_id));
        var apt = route.get_wpt(apt_id);
        var combo = me.runway_fields[apt_name];

        with_input_inhibit(func { me.data[apt_name].runway.setValue(""); });

        combo.removeChildren("value");
        if (apt != nil) {
            foreach (var runway; apt.runway_list) {
                combo.addChild("value").setValue(runway.name);
            }
        }

        gui.dialog_update("route-manager-ajs", apt_name~"-runway");
    },

    update_legs: func {
        var last_wp = route.get_wpt(route.WPT.LS);

        for (var i=1; i<=9; i+=1) {
            var wp = route.get_wpt(route.WPT.B | i);

            me.data.B[i].leg_head.setValue("");
            me.data.B[i].leg_dist.setValue("");

            if (wp != nil) 
            {
                # waypoint correct
                if (last_wp != nil) {
                    # valid leg
                    me.data.B[i].leg_head.setValue(sprintf("%03.f", geo.normdeg(last_wp.coord.course_to(wp.coord))));
                    me.data.B[i].leg_dist.setValue(sprintf("%3.fkm", last_wp.coord.distance_to(wp.coord) / 1000));
                }
                last_wp = wp;
                with_input_inhibit(func { me.data.B[i].valid.setBoolValue(TRUE); });
            }
            else
            {
                var input = me.data.B[i].input.getValue();
                if (input != nil and input != "") {
                    # input parse error
                    head_prop.setValue("err");
                    dist_prop.setValue("");
                }

                # Clear and disable other input fields
                with_input_inhibit(func {
                    me.data.B[i].valid.setBoolValue(FALSE);
                    me.data.B[i].target.setBoolValue(FALSE);
                });
            }
        }
    },

    open: func {
        if(me.state) return;
        fgcommand("dialog-show", me.dialog_prop);
        me.state = 1;
    },
    close: func {
        if(!me.state) return;
        fgcommand("dialog-close", me.dialog_prop);
        me.state = 0;
    },
    toggle: func {
        me.state ? me.close() : me.open();
    },
    is_open: func {
        return me.state;
    },
};

Dialog.init();
