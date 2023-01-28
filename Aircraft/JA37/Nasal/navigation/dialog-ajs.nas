var TRUE = 1;
var FALSE = 0;


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



### Custom route manager dialog for AJS
var Dialog = {
    init: func {
        var prop = props.globals.getNode("/sim/gui/dialogs/route-manager-ajs", 1);
        me.dialog_prop = prop.getNode("dialog", 1);
        me.data_prop = prop.getNode("data", 1);
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

    get_wpt_prop: func(wpt_name) {
        var type = substr(wpt_name, 0, 1);
        if (substr(wpt_name, 0, 1) == "L") {
            # airbase
            return me.data_prop.getNode(wpt_name, 1);
        } else {
            # waypoint
            var number = int(substr(wpt_name, 1, 1));
            return me.data_prop.getChild(type, number, 1)
        }
    },

    update_runways: func(apt_name) {
        var apt_id = route.WPT[apt_name];
        var apt = route.as_airbase(route.get_wpt(apt_id));
        var combo = me.runway_fields[apt_name];
        var prop = me.get_wpt_prop(apt_name).getNode("runway");

        inhibit_input_callback = TRUE;
        prop.setValue("");
        inhibit_input_callback = FALSE;

        combo.removeChildren("value");
        if (apt != nil) {
            foreach (var runway; apt.runway_list) {
                combo.addChild("value").setValue(runway.name);
            }
        }

        gui.dialog_update("route-manager-ajs", apt_name~"-runway");
    },

    setup_table: func {
        # Airbases
        for (var i=0; i<=2; i+=1) {
            var apt_name = i==0 ? "LS" : "L"~i;
            var wpt_prop = me.get_wpt_prop(apt_name);
            var row = i+2;

            me.table.addChild("text").setValues({
                "col":      me.COL.APT_NAME,
                "row":      row,
                "halign":   "left",
                "label":    sprintf(" %s (%s)", apt_name, me.airbase_desc[apt_name]),
            });

            var prop = wpt_prop.getNode("icao", 1);
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

            var prop = wpt_prop.getNode("runway", 1);
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
        }

        # Waypoints
        for (var i=1; i<=9; i+=1) {
            var wpt_prop = me.get_wpt_prop("B"~i);
            var row = i+1;

            me.table.addChild("text").setValues({
                "col":      me.COL.WPT_NAME,
                "row":      row,
                "halign":   "left",
                "label":    "B"~i,
            });

            var prop = wpt_prop.getNode("input", 1);
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
            append(me.listeners, setlistener(prop, make_wpt_input_listener(route.WPT.B | i), 0, 0));

            me.table.addChild("text").setValues({
                "col":      me.COL.HEAD,
                "row":      row,
                "label":    "000",
            });

            me.table.addChild("text").setValues({
                "col":      me.COL.DIST,
                "row":      row,
                "label":    "999km",
            });

            #var prop = wpt_prop.getNode("target", 1);
            #prop.setBoolValue(FALSE);
            #var name = "B"~i~"-target";
            #me.table.addChild("checkbox").setValues({
            #    "col":          me.COL.TGT,
            #    "row":          row,
            #    "name":         name,
            #    "property":     prop.getPath(),
            #    "live":         TRUE,
            #    "binding": {
            #        "command":      "dialog-apply",
            #        "object-name":  name,
            #    },
            #});

            #var prop = wpt_prop.getNode("popup-heading", 1);
            #var name = "B"~i~"-popup-heading";
            #me.table.addChild("input").setValues({
            #    "col":          me.COL.POPUP_HEAD,
            #    "row":          row,
            #    "name":         name,
            #    "pref-width":   50,
            #    "property":     prop.getPath(),
            #    "live":         TRUE,
            #    "binding": {
            #        "command":      "dialog-apply",
            #        "object-name":  name,
            #    },
            #});

            #var prop = wpt_prop.getNode("popup-dist", 1);
            #var name = "B"~i~"-popup-dist";
            #me.table.addChild("input").setValues({
            #    "col":          me.COL.POPUP_DIST,
            #    "row":          row,
            #    "name":         name,
            #    "pref-width":   40,
            #    "property":     prop.getPath(),
            #    "live":         TRUE,
            #    "binding": {
            #        "command":      "dialog-apply",
            #        "object-name":  name,
            #    },
            #});
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
