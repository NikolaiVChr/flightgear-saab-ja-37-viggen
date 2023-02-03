# Keep a list of friends from a node (/ja37/faf/) with children friend[i]

var max_friends = 10;

# Create friend property nodes
var faf_node = props.globals.getNode("ja37/faf", 1);

for (var i=0; i<max_friends; i+=1) {
    # Create nodes and add to saved data.
    var node = faf_node.getChild("friend", i, 1);
    aircraft.data.add(node);
}

# Nasal friend table
var friends = {};

var is_friend = func(callsign) {
    return contains(friends, callsign);
}

var update_lists = func() {
    # Re-read the entire lists if an update is needed.
    # This is lazy coding, but it's not like the lists are changed frequently.
    friends = {};
    foreach(friend; faf_node.getChildren("friend")) {
        var callsign = friend.getValue();
        if(callsign != nil and callsign != "") friends[callsign] = 1;
    }
}

setlistener(faf_node, update_lists, 1, 2);


# Procedural friends dialog
var Dialog = {
    init: func {
        me.prop = props.globals.getNode("/sim/gui/dialogs/faf/dialog", 1);
        me.path = "Aircraft/JA37/gui/dialogs/faf.xml";
        me.state = 0;
        me.listener = setlistener("/sim/signals/reinit-gui", func me.init_dialog(), 1);
    },

    init_dialog: func {
        var state = me.state;
        if (state) me.close();

        me.prop.removeChildren();
        io.read_properties(me.path, me.prop);
        me.prop.setValue("dialog-name", "faf");

        me.table = nil;
        me.table_name = "procedural_table";
        foreach(var group; me.prop.getChildren("group")) {
            if(group.getValue("name") == me.table_name) {
                me.table = group;
                break;
            }
        }
        if(me.table == nil) {
            logprint(LOG_ALERT, "Failed to initialize JA 37 IFF dialog: missing element '", me.table_name, "' in ", me.path);
            return;
        }
        me.setup_table();

        fgcommand("dialog-new", me.prop);

        if (state) me.open();
    },

    setup_table: func {
        me.table_cols = 2;
        me.table_lines = max_friends/me.table_cols;

        var col = 0;
        var line = 0;
        for(var i=0; i<max_friends; i+=1) {
            me.add_table_entry(col, line, i);
            line += 1;
            if(line >= me.table_lines) {
                line = 0;
                col += 1;
            }
        }
    },

    add_table_entry: func(col, line, i) {
        var input = me.table.addChild("input");
        input.setValue("row", line);
        input.setValue("col", 2*col+1);
        input.setDoubleValue("pref-width", 120);
        input.setValue("property", "ja37/faf/friend["~i~"]");
        input.setBoolValue("live", 1);
        input.addChild("binding").setValue("command", "dialog-apply");

        var color = input.addChild("color");
        color.setDoubleValue("red", 0.5);
        color.setDoubleValue("green", 1);
        color.setDoubleValue("blue", 0.5);
    },

    open: func() {
        if(me.state) return;
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
