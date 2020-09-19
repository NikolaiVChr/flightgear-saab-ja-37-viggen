###############################################################################
# dialog.nas by Tatsuhiro Nishioka
# - A dialog window for Performance Monitor
# 
# Copyright (C) 2009 Tatsuhiro Nishioka (tat dot fgmacosx at gmail dot com)
# This file is licensed under the GPL version 2 or later.
# 
###############################################################################

#
# MonitorDialog for systems monitor
#
var MonitorDialog = { _instance : nil };
MonitorDialog.instance = func() {
  if (MonitorDialog._instance == nil) {
    MonitorDialog._instance = { parents : [MonitorDialog], properties : [] };
  }
  return MonitorDialog._instance;
}

MonitorDialog.init = func (x = nil, y = nil) {
  me.x = x;
  me.y = y;
  me.bg = [0, 0, 0, 0.3];
  me.fg = [[0.9, 0.9, 0.2, 1],[1.0, 1.0, 1.0, 1.0]];
  me.name = "Systems Monitor";
  me.namenode = props.Node.new({"dialog-name" : me.name });
  me.dialog = nil;
  me.node = props.globals.getNode("/sim/gui/dialogs/systems-monitor");
  
  me.listeners=[];
  append(me.listeners, setlistener("/sim/startup/xsize", func { me._redraw() }, 0, 0));
  append(me.listeners, setlistener("/sim/startup/ysize", func { me._redraw() }, 0, 0));
}

MonitorDialog.addProperty = func(propHash) {
  append(me.properties, propHash);
}

MonitorDialog.create = func {
  if (me.dialog != nil)
    me.close();
  
  me.dialog = gui.Widget.new();
  me.dialog.set("name", me.name);
  if (me.x != nil)
    me.dialog.set("x", me.x);
  if (me.y != nil)
    me.dialog.set("y", me.y);
  
  me.dialog.set("layout", "vbox");
  me.dialog.set("default-padding", 0);
  
  me.dialog.setColor(me.bg[0], me.bg[1], me.bg[2], me.bg[3]);
  
  var titlebar=me.dialog.addChild("group");
  titlebar.set("layout", "hbox");
  
  #var reset = titlebar.addChild("button");
  #reset.node.setValues({"pref-width": 40, "pref-height": 16, legend: "Reset"});
  #reset.setBinding("nasal", "monitor2.SystemsMonitor.instance().reinit()");

  titlebar.addChild("empty").set("stretch", 1);
  titlebar.addChild("text").set("label", "Systems Monitor");
  
  var w = titlebar.addChild("button");
  w.node.setValues({"pref-width": 16, "pref-height": 16, legend: "", default: 0}); # key: "esc" is no good
  w.setBinding("nasal", "monitor2.MonitorDialog.instance().destroy()");
  
  me.dialog.addChild("hrule");
  
  var content = me.dialog.addChild("group");
  content.set("layout", "table");
  content.set("default-padding", 1);
  var row = 0;
  
  foreach (var property; me.properties) {
    var col = 0;
    foreach (var column; ["name", "property", "unit"]) {
      var w = content.addChild("text");
      if (column == "property") {
        w.node.setValues({row: row, col: col, label: "--------", live : 1, 
                          format : property.format, halign : property.halign,
                          property: me.node.getPath() ~ "/" ~ property.property});
      } else {
        var label = property[column]; 
        w.node.setValues({row: row, col: col, label : label, format : "%s", halign : "left"});
      }
      if (property["red"] != nil and property["green"] != nil and property["blue"] != nil) {
        var color = w.node.getNode("color", 1);
        color.setValues({"red": property.red, "green": property.green, "blue": property.blue});
      }
      col += 1;
    }
    row += 1;
  }
  
  fgcommand("dialog-new", me.dialog.prop());
  fgcommand("dialog-show", me.namenode);
}

MonitorDialog._redraw = func {
  if (me.dialog != nil) {
    me.close();
    me.create();
  }
}

MonitorDialog.close = func {
  fgcommand("dialog-close", me.namenode);
}

MonitorDialog.destroy = func {
  me.close();
  foreach(var l; me.listeners)
    removelistener(l);
  delete(gui.dialog, "\"" ~ me.name ~ "\"");
}

MonitorDialog.show = func {
  me.init(2, -100);
  me.create();
}
