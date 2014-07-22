###############################################################################
## Select configuration dialog.
## Partly based on Till Bush's multiplayer dialog

var CONFIG_DLG = 0;
var prop = "/sim/gui/dialogs/route-manager/";
var setPath = {sid:"departure/sid", star:"/destination/star"};

var dialog = {
#################################################################
	init : func (x = nil, y = nil) {
		me.x = x;
		me.y = y;
		me.bg = [0, 0, 0, 0.3];	   # background color
		me.fg = [[1.0, 1.0, 1.0, 1.0]];
		#
		# "private"
		me.title = "select";
		me.basenode = props.globals.getNode("/environment/select");
		me.dialog = nil;
		me.namenode = props.Node.new({"dialog-name" : me.title });
		me.listeners = [];
	},
#################################################################
	create : func(type) {
		if (me.dialog != nil)
			me.close();

		me.dialog = gui.Widget.new();
		me.dialog.set("name", type ~ me.title);
		if (me.x != nil) {
			me.dialog.set("x", me.x);
		}
		if (me.y != nil) {
			me.dialog.set("y", me.y);
		}
		me.dialog.set("layout", "vbox");
		me.dialog.set("resizable", 1);

		var titlebar = me.dialog.addChild("group");
		titlebar.set("layout", "hbox");
		titlebar.addChild("empty").set("stretch", 1);
		titlebar.addChild("text").set("label", "Select");
		titlebar.addChild("empty").set("stretch", 1);
		var close = titlebar.addChild("button");
		close.set("pref-width", 16);
		close.set("pref-height", 16);
		close.set("legend", "");
		close.set("default", 1);
		close.set("keynum", 27);
		close.set("border", 2);
		close.setBinding("nasal", "select.dialog.destroy();");
		close.setBinding("dialog-close");
		me.dialog.addChild("hrule");

		var content = me.dialog.addChild("group");
		content.set("layout", "hbox");

		var list = content.addChild("list");
		list.node.setValues({"pref-width"	: 150,
							 "pref-height"	: 175,
							 "halign"		: "center",
							 "name"			: type,
							 "stretch"		: 1,
							 "property"		: prop ~ setPath[type],
							 "properties"	: prop ~ type ~"s"});
		list.setBinding("dialog-apply", type);
		list.setBinding("nasal","setprop(/autopilot/route-manager/departure/"" ~ type ~ "","" ~ prop ~ "")");

		fgcommand("dialog-new", me.dialog.prop());
		fgcommand("dialog-show", me.namenode);
	},
#################################################################
	close : func {
		fgcommand("dialog-close", me.namenode);
	},
#################################################################
	destroy : func {
		CONFIG_DLG = 0;
		me.close();
		foreach(var l; me.listeners)
			removelistener(l);
		delete(gui.dialog, "\"" ~ me.title ~ "\"");
	},
#################################################################
	show : func(type) {
		if (!CONFIG_DLG) {
			CONFIG_DLG = 1;
			me.init();
			me.create(type);
		}
	}
}
###############################################################################