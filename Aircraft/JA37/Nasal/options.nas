var options = func {
	print("test!");
}

# Aircraft Design
# ===============
#
#  Still working on a way to display images
#  In the interim a vrule and an hrule have been added as demarcators
#     to check the layout.
#

# aircraft_design.dialog.show() -- displays aircraft design dialog
#

var AIRCRAFTDESIGNDLG_RUNNING = 0;
var DIALOG_WIDTH = 580;
var DIALOG_HEIGHT = 600;
var TOPLOGO_HEIGHT = 80;
var SIDELOGO_WIDTH = 100;

var dialog = {
    init: func(x = nil, y = nil) {
        me.x = x;
        me.y = y;
        me.bg = [0.3, 0.3, 0.3, 1];    # background color
        me.fg = [[0.9, 0.9, 0.2, 1], [1, 1, 1, 1], [1, 0.5, 0, 1]]; # alternative active & disabled color
        var font = { name: "FIXED_8x13" };

        me.dialog = nil;
        me.name = "JA-37 Options";

#        me.listeners=[];
#        append(me.listeners, setlistener("/sim/signals/reinit-gui", func me._redraw_()));
#        append(me.listeners, setlistener("/sim/signals/aircraft_design-updated", func me._redraw_()));
    },
    create: func {
        if (me.dialog != nil)
            me.close();

        me.dialog = gui.dialog[me.name] = gui.Widget.new();
        me.dialog.set("name", me.name);
        me.dialog.set("dialog-name", me.name);
        if (me.x != nil)
            me.dialog.set("x", me.x);
        if (me.y != nil)
            me.dialog.set("y", me.y);

        me.dialog.set("layout", "vbox");
        me.dialog.set("default-padding", 0);
        me.dialog.set("pref-width", DIALOG_WIDTH);
        me.dialog.set("pref-height", DIALOG_HEIGHT);

        me.dialog.setColor(me.bg[0], me.bg[1], me.bg[2], me.bg[3]);

        ######   Title Bar   #####
        var titlebar = me.dialog.addChild("group");
          titlebar.set("layout", "hbox");
          titlebar.set("pref-height", 32);
          titlebar.set("valign", "top");
          titlebar.set("pref-width", DIALOG_WIDTH);
          titlebar.addChild("empty").set("stretch", 1);
          titlebar.addChild("text").set("label", "bla bla");
          titlebar.addChild("empty").set("stretch", 1);
          var w = titlebar.addChild("button");
            w.node.setValues({ "pref-width": 16, "pref-height": 16, legend: "", default: 0 });
            # "Esc" causes dialog-close
            w.set("key", "Esc");
            w.setBinding("nasal", "ja37.dialog.del()");

        me.dialog.addChild("hrule");

        #####   Top logo   #####
        var topLogo = me.dialog.addChild("group");
        #topLogo.set("layout", "hbox");
        #topLogo.set("halign", "fill");
        #topLogo.set("valign", "top");
        #topLogo.set("pref-height", TOPLOGO_HEIGHT);
        #topLogo.set("row", 0);
        #topLogo.set("col", 0);

        var canvas_settings = {
          "name": "LogoNasal",
          "size": [512, 128],# width of texture to be replaced
          "view": [512, 128],# width of canvas
          "mipmapping": 0
        };
        var canvasLogo = canvas.new(canvas_settings);
        #canvasLogo.setSize(512, 128);
        var root = canvasLogo.createGroup();
        var splash = root.createChild("image");
        splash.setFile("viggen-logo.png");
        splash.setSize(512, 128);
        splash.setTranslation(0,0);
        #splash.setSourceRect(top:0, left:0, right:512, bottom: 128, normalized:0);

        me.dialog.addChild(splash);
        me.dialog.addChild("hrule");

        #####   Main Area   #####
        var mainArea = me.dialog.addChild("group");
          mainArea.set("layout", "hbox");
          mainArea.set("valign", "fill");
          mainArea.set("halign", "fill");
          mainArea.set("pref-height", DIALOG_HEIGHT - 72 - TOPLOGO_HEIGHT);

          #####   Side logo   #####
          var sideLogo = mainArea.addChild("group");
            sideLogo.set("layout", "vbox");
            sideLogo.set("pref-width", SIDELOGO_WIDTH);
            sideLogo.set("valign", "fill");
            mainArea.addChild("vrule");

          #####   Work Area   #####
          var workArea = mainArea.addChild("group");
            workArea.set("layout", "vbox");
            workArea.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
            workArea.set("valign", "fill");
            workAreaNode = workArea.node;

            #####   Content   #####
            #var content = interim.addChild("group");
             # content.set("layout", "table");
              #content.set("valign", "top");

####  The table will be filled from the current page after doing some sort
####  of combination of wizard.pui and the nasal code in wizard.xml

        ######   Bottom Row Buttons   #####
        me.dialog.addChild("hrule");
        var bottomRow = me.dialog.addChild("group");
          bottomRow.set("layout", "hbox");
          bottomRow.set("pref-height", 40);
          bottomRow.set("pref-width", DIALOG_WIDTH);
          bottomRow.set("valign", "bottom");
          bottomRow.addChild("empty").set("stretch", 1);
          var testButton = bottomRow.addChild("button");
             testButton.node.setValues({ "pref-width": 80, "pref-height": 25, legend: "Prev", default: 0 });
          bottomRow.addChild("empty").set("stretch", 1);
          var secondButton = bottomRow.addChild("button");
             secondButton.node.setValues({ "pref-width": 80, "pref-height": 25, legend: "Next", default: 0 });
          bottomRow.addChild("empty").set("stretch", 1);

####  Button bindings still to be done.
####  Other buttons still to be added.

        fgcommand("dialog-new", me.dialog.prop());
        fgcommand("dialog-show", me.dialog.prop());
    },

    close: func {
        fgcommand("dialog-close", me.dialog.prop());
    },

    del: func {
        AIRCRAFTDESIGNDLG_RUNNING = 0;
        me.close();
#        foreach (var l; me.listeners)
#            removelistener(l);
        delete(gui.dialog, me.name);
    },

    show: func {
        if (!AIRCRAFTDESIGNDLG_RUNNING) {
            AIRCRAFTDESIGNDLG_RUNNING = 1;
            me.init();
            me.create();
        }
    },
};