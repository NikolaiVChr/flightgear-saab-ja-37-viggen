var optionDLG_RUNNING = 0;
var DIALOG_WIDTH = 580;
var DIALOG_HEIGHT = 400;
var TOPLOGO_HEIGHT = 0;#logo don't work atm
var SIDELOGO_WIDTH = 100;

var Dialog = {
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
          titlebar.addChild("text").set("label", "Saab JA-37 Viggen Options");
          titlebar.addChild("empty").set("stretch", 1);
          var w = titlebar.addChild("button");
            w.node.setValues({ "pref-width": 16, "pref-height": 16, legend: "", default: 0 });
            # "Esc" causes dialog-close
            w.set("key", "Esc");
            w.setBinding("nasal", "ja37.Dialog.del()");

        me.dialog.addChild("hrule");
        me.dialog.addChild("hrule");

        #####   Top logo   #####
        #var topLogo = me.dialog.addChild("group");
        #topLogo.set("layout", "hbox");
        #topLogo.set("halign", "fill");
        #topLogo.set("valign", "top");
        #topLogo.set("pref-height", TOPLOGO_HEIGHT);
        #topLogo.set("row", 0);
        #topLogo.set("col", 0);

        #var canvas_settings = {
        #  "name": "LogoNasal",
        #  "size": [256, 64],# width of texture to be replaced
        #  "view": [512, 128],# width of canvas
        #  "mipmapping": 0
        #};
        
        #var canvasLogo = canvas.new(canvas_settings);
        #canvasLogo.addPlacement({"parent": canvasWidget.prop()});
        #canvasLogo.setSize(512, 128);
        #var root = canvasLogo.createGroup();
        #var splash = root.createChild("image");
        #splash.setFile("Aircraft/JA37/viggen-logo.png");
        #splash.setSize(512, 128);
        #splash.setTranslation(0,0);
        #splash.setSourceRect(0, 0, 1, 1, 1);
        
        #canvasLogo._node.addChild("pref-width").setValue(100);
        #canvasLogo._node.addChild("pref-height").setValue(100);
        #var canvasWidget = me.dialog.addChild("canvas");
        #canvasWidget.prop().addChild(canvasLogo._node);

        #me.dialog.addChild("hrule");

        #####   Main Area   #####
        var mainArea = me.dialog.addChild("group");
          mainArea.set("layout", "hbox");
          mainArea.set("valign", "top");##adjusted fill
          mainArea.set("halign", "fill");
          mainArea.set("pref-height", DIALOG_HEIGHT - 62 - TOPLOGO_HEIGHT);
          mainArea.setColor(1, 0, 0, 0);
          
          #####   Side logo   #####
          var sideLogo = mainArea.addChild("group");
            sideLogo.set("layout", "vbox");
            sideLogo.set("pref-width", SIDELOGO_WIDTH);
            sideLogo.set("pref-height", DIALOG_HEIGHT - 62 - TOPLOGO_HEIGHT + 0);
            sideLogo.set("valign", "top");
            mainArea.addChild("vrule");
            sideLogo.setColor(0, 0, 1, 0);

          #####   Work Area   #####
          var workArea = mainArea.addChild("group");
            workArea.set("layout", "vbox");
            workArea.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
            workArea.set("pref-height", DIALOG_HEIGHT - 62 - TOPLOGO_HEIGHT + 0);
            workArea.set("valign", "top");##adjusted fill
            workAreaNode = workArea.node;
            workArea.setColor(0, 1, 0, 0);

            #######################
            #####   Content   #####
            #######################

          
          var topRow = workArea.addChild("group");
          topRow.set("layout", "vbox");
          topRow.set("pref-height", 150);
          topRow.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          topRow.set("valign", "top");
          topRow.set("stretch", "false");
          #topRow.addChild("empty").set("stretch", 1);
          
          ######   break button   #####
          var breakRow = topRow.addChild("group");
          breakRow.set("layout", "hbox");
          breakRow.set("pref-height", 25);
          breakRow.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          #breakRow.set("valign", "center");
          
          breakRow.addChild("text")
          .set("label", "Structural break due to G-forces:");
          breakRow.addChild("empty").set("stretch", 1);
          me.dialog.breakButton = breakRow.addChild("button");
          me.dialog.breakButton.set("halign", "right");
          me.dialog.breakButton.node.setValues({ "pref-width": 75, "pref-height": 25, legend: " x ", default: 0 });
          #topRow.addChild("empty").set("stretch", 1);
          me.dialog.breakButton.setBinding("nasal", "ja37.Dialog.breakToggle()");

          ######   reverse button   #####
          var reverseRow = topRow.addChild("group");
          reverseRow.set("layout", "hbox");
          reverseRow.set("pref-height", 25);
          reverseRow.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          #reverseRow.set("valign", "center");
          
          var reverseText = reverseRow.addChild("text").set("label", "Automatic reverse thrust at touchdown:");
          reverseRow.addChild("empty").set("stretch", 1);
          me.dialog.reverseButton = reverseRow.addChild("button");
          me.dialog.reverseButton.set("halign", "right");
          me.dialog.reverseButton.node.setValues({ "pref-width": 75, "pref-height": 25, legend: " x ", default: 0 });
          #topRow.addChild("empty").set("stretch", 1);
          me.dialog.reverseButton.setBinding("nasal", "ja37.Dialog.reverseToggle()");

          ######   hud button   #####
          var hudRow = topRow.addChild("group");
          hudRow.set("layout", "hbox");
          hudRow.set("pref-height", 25);
          hudRow.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          #hudRow.set("valign", "center");
          
          var reverseText = hudRow.addChild("text").set("label", "Custom JA-37 specific HUD:");
          hudRow.addChild("empty").set("stretch", 1);
          me.dialog.hudButton = hudRow.addChild("button");
          me.dialog.hudButton.set("halign", "right");
          me.dialog.hudButton.node.setValues({ "pref-width": 75, "pref-height": 25, legend: " x ", default: 0 });
          #topRow.addChild("empty").set("stretch", 1);
          me.dialog.hudButton.setBinding("nasal", "ja37.Dialog.hudToggle()");

          ######   radar button   #####
          var radarRow = topRow.addChild("group");
          radarRow.set("layout", "hbox");
          radarRow.set("pref-height", 25);
          radarRow.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          #radarRow.set("valign", "center");
          
          var radarText = radarRow.addChild("text").set("label", "Radar instrument and radar tracks in custom HUD:");
          radarRow.addChild("empty").set("stretch", 1);
          me.dialog.radarButton = radarRow.addChild("button");
          me.dialog.radarButton.set("halign", "right");
          me.dialog.radarButton.node.setValues({ "pref-width": 75, "pref-height": 25, legend: " x ", default: 0 });
          #topRow.addChild("empty").set("stretch", 1);
          me.dialog.radarButton.setBinding("nasal", "ja37.Dialog.radarToggle()");

          ######   missile msg button   #####
          var rb24msgRow = topRow.addChild("group");
          rb24msgRow.set("layout", "hbox");
          rb24msgRow.set("pref-height", 25);
          rb24msgRow.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          #rb24msgRow.set("valign", "center");
          
          var rb24msgText = rb24msgRow.addChild("text").set("label", "Display MP message when hitting opponent with missile:");
          rb24msgRow.addChild("empty").set("stretch", 1);
          me.dialog.rb24msgButton = rb24msgRow.addChild("button");
          me.dialog.rb24msgButton.set("halign", "right");
          me.dialog.rb24msgButton.node.setValues({ "pref-width": 75, "pref-height": 25, legend: " x ", default: 0 });
          me.dialog.rb24msgButton.setBinding("nasal", "ja37.Dialog.rb24msgToggle()");

          #HUD brightness
          var hudRow = workArea.addChild("group");
          hudRow.set("layout", "hbox");
          hudRow.set("pref-height", 25);
          hudRow.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          hudRow.set("valign", "center");
                    
          hudRow.addChild("text").set("label", "HUD color:");
          me.dialog.hudLight = hudRow.addChild("button");
          me.dialog.hudMedium = hudRow.addChild("button");
          me.dialog.hudDark = hudRow.addChild("button");
          me.dialog.hudLight.node.setValues({ "pref-width": 100, "pref-height": 25, legend: "Light", default: 0 });
          me.dialog.hudMedium.node.setValues({ "pref-width": 100, "pref-height": 25, legend: "Medium", default: 0 });
          me.dialog.hudDark.node.setValues({ "pref-width": 100, "pref-height": 25, legend: "Dark", default: 0 });
          me.dialog.hudLight.setBinding("nasal", "ja37.Dialog.light()");
          me.dialog.hudMedium.setBinding("nasal", "ja37.Dialog.medium()");
          me.dialog.hudDark.setBinding("nasal", "ja37.Dialog.dark()");

          #  mention hangar
          var hangar = workArea.addChild("group");
          hangar.set("layout", "vbox");
          hangar.set("pref-height", 50);
          hangar.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          hangar.set("valign", "center");

          hangar.addChild("hrule");#.set("valign", "bottom");
          var ad1 = hangar.addChild("text");
          ad1.set("label", "Download the newest version from:");
          ad1.set("halign", "center");
          ad1.set("valign", "bottom");
          ad1.node.setValues({ "pref-height": 25});
          var ad2 = hangar.addChild("text");
          ad2.set("label", "https://sites.google.com/site/fghangar");
          ad2.set("halign", "center");
          ad2.set("valign", "bottom");
          ad2.node.setValues({ "pref-height": 25});
          
          me.dialog.addChild("hrule");
          #var me.dialog.crashButton = topRow.addChild("button");
          #me.dialog.crashButton.node.setValues({ "pref-width": 80, "pref-height": 25, legend: "Crash", default: 0 });
          #topRow.addChild("empty").set("stretch", 1);
          #crashButton.setBinding("nasal", "ja37.dialog.crash()");
  
####  The table will be filled from the current page after doing some sort
####  of combination of wizard.pui and the nasal code in wizard.xml

        ######   Bottom Row Buttons   #####
        #me.dialog.addChild("hrule");
        #var bottomRow = me.dialog.addChild("group");
        #  bottomRow.set("layout", "hbox");
        #  bottomRow.set("pref-height", 40);
        #  bottomRow.set("pref-width", DIALOG_WIDTH);
        #  bottomRow.set("valign", "bottom");
        #  bottomRow.addChild("empty").set("stretch", 1);
        #  var testButton = bottomRow.addChild("button");
        #     testButton.node.setValues({ "pref-width": 80, "pref-height": 25, legend: "Prev", default: 0 });
        #  bottomRow.addChild("empty").set("stretch", 1);
        #  var secondButton = bottomRow.addChild("button");
        #     secondButton.node.setValues({ "pref-width": 80, "pref-height": 25, legend: "Next", default: 0 });
        #  bottomRow.addChild("empty").set("stretch", 1);

        me.refreshButtons();
        fgcommand("dialog-new", me.dialog.prop());
        fgcommand("dialog-show", me.dialog.prop());
    },

    close: func {
        fgcommand("dialog-close", me.dialog.prop());
    },

    breakToggle: func {
      var enabled = getprop("sim/ja37/damage/enabled");
      setprop("sim/ja37/damage/enabled", !enabled);
      me.refreshButtons();
    },

    reverseToggle: func {
      var enabled = getprop("sim/ja37/autoReverseThrust");
      setprop("sim/ja37/autoReverseThrust", !enabled);
      me.refreshButtons();
    },

    hudToggle: func {
      var enabled = getprop("sim/ja37/hud/mode");
      setprop("sim/ja37/hud/mode", !enabled);
      me.refreshButtons();
    },  

    radarToggle: func {
      var enabled = getprop("sim/ja37/radar/enabled");
      setprop("sim/ja37/radar/enabled", !enabled);
      me.refreshButtons();
    },

    rb24msgToggle: func {
      var enabled = getprop("sim/ja37/armament/msg");
      setprop("sim/ja37/armament/msg", !enabled);
      me.refreshButtons();
    },    

    light: func {
      canvas_HUD.r = 0.0;
      canvas_HUD.g = 1.0;
      canvas_HUD.b = 0.0;
      canvas_HUD.a = 1.0;
      canvas_HUD.w = 10;
      #canvas_HUD.fs = 1;
      canvas_HUD.reinit();
    },

    medium: func {
      canvas_HUD.r = 0.0;
      canvas_HUD.g = 0.6;
      canvas_HUD.b = 0.0;
      canvas_HUD.a = 1.0;      
      canvas_HUD.w = 11;
      #canvas_HUD.fs = 1.1;
      canvas_HUD.reinit();
    },

    dark: func {
      canvas_HUD.r = 0.0;
      canvas_HUD.g = 0.3;
      canvas_HUD.b = 0.0;
      canvas_HUD.a = 1.0;
      canvas_HUD.w = 12;
      #canvas_HUD.fs = 1.2;
      canvas_HUD.reinit();
    },

    refreshButtons: func {
      # update break button
      var enabled = getprop("sim/ja37/damage/enabled");
      var legend = "";
      if(enabled == 1) {
        legend = "Enabled";
      } else {
        legend = "Disabled";
      }
      me.dialog.breakButton.node.setValues({"legend": legend});

      enabled = getprop("sim/ja37/autoReverseThrust");
      if(enabled == 1) {
        legend = "Enabled";
      } else {
        legend = "Disabled";
      }
      me.dialog.reverseButton.node.setValues({"legend": legend});

      enabled = getprop("sim/ja37/hud/mode");
      if(enabled == 1) {
        legend = "Enabled";
      } else {
        legend = "Disabled";
      }
      me.dialog.hudButton.node.setValues({"legend": legend});

      enabled = getprop("sim/ja37/radar/enabled");
      if(enabled == 1) {
        legend = "Enabled";
      } else {
        legend = "Disabled";
      }
      me.dialog.radarButton.node.setValues({"legend": legend});

      enabled = getprop("sim/ja37/armament/msg");
      if(enabled == 1) {
        legend = "Enabled";
      } else {
        legend = "Disabled";
      }
      me.dialog.rb24msgButton.node.setValues({"legend": legend});
      
      #props.dump(me.dialog.prop()); # handy command, don't forget it.

      # this is commented out cause it needs a trigger (e.g. button to activate):
      # me.dialog.setBinding("dialog-close", props.Node.new({"dialog-name": "JA-37 Options"}));
      # me.dialog.setBinding("dialog-show",  props.Node.new({"dialog-name": "JA-37 Options"}));
      # this does the same, refresh the dialog:
      fgcommand("dialog-close", props.Node.new({"dialog-name": "JA-37 Options"}));
      fgcommand("dialog-show", props.Node.new({"dialog-name": "JA-37 Options"}));
    },

    del: func {
        #optionDLG_RUNNING = 0;
        me.close();
#        foreach (var l; me.listeners)
#            removelistener(l);
        #delete(gui.dialog, me.name);
    },

    show: func {
      var versionString = getprop("sim/version/flightgear");
      var version = split(".", versionString);
      if (version[0] == "0" or version[0] == "1" or version[0] == "2") {
        gui.popupTip("Options is only supported in Flightgear version 3.0 and upwards.");
      } elsif (!optionDLG_RUNNING) {
        optionDLG_RUNNING = 1;
        me.init();
        me.create();
      } else {
        me.refreshButtons();
        fgcommand("dialog-show", me.dialog.prop());
      }
    },
};