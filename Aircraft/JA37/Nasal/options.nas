var optionDLG_RUNNING = 0;
var DIALOG_WIDTH = 580;
var DIALOG_HEIGHT = 675;
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
          topRow.set("pref-height", 375);
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
          .set("label", "Crash and stress damage system:");
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
          
          var radarText = radarRow.addChild("text").set("label", "Radar screen:");
          radarRow.addChild("empty").set("stretch", 1);
          me.dialog.radarButton = radarRow.addChild("button");
          me.dialog.radarButton.set("halign", "right");
          me.dialog.radarButton.node.setValues({ "pref-width": 75, "pref-height": 25, legend: " x ", default: 0 });
          #topRow.addChild("empty").set("stretch", 1);
          me.dialog.radarButton.setBinding("nasal", "ja37.Dialog.radarToggle()");

          ######   HUD radar tracks button   #####
          var tracksRow = topRow.addChild("group");
          tracksRow.set("layout", "hbox");
          tracksRow.set("pref-height", 25);
          tracksRow.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          #tracksRow.set("valign", "center");
          
          var tracksText = tracksRow.addChild("text").set("label", "Radar:");
          tracksRow.addChild("empty").set("stretch", 1);
          me.dialog.tracksButton = tracksRow.addChild("button");
          me.dialog.tracksButton.set("halign", "right");
          me.dialog.tracksButton.node.setValues({ "pref-width": 75, "pref-height": 25, legend: " x ", default: 0 });
          #topRow.addChild("empty").set("stretch", 1);
          me.dialog.tracksButton.setBinding("nasal", "ja37.Dialog.tracksToggle()");

          ######   HUD bank indicator button   #####
          var bankRow = topRow.addChild("group");
          bankRow.set("layout", "hbox");
          bankRow.set("pref-height", 25);
          bankRow.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          #tracksRow.set("valign", "center");
          
          var bankText = bankRow.addChild("text").set("label", "HUD turn coordinator: (not authentic)");
          bankRow.addChild("empty").set("stretch", 1);
          me.dialog.bankButton = bankRow.addChild("button");
          me.dialog.bankButton.set("halign", "right");
          me.dialog.bankButton.node.setValues({ "pref-width": 75, "pref-height": 25, legend: " x ", default: 0 });
          #topRow.addChild("empty").set("stretch", 1);
          me.dialog.bankButton.setBinding("nasal", "ja37.Dialog.bankToggle()");

          ######   Yaw damper button   #####
          var yawRow = topRow.addChild("group");
          yawRow.set("layout", "hbox");
          yawRow.set("pref-height", 25);
          yawRow.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          #tracksRow.set("valign", "center");
          
          var yawText = yawRow.addChild("text").set("label", "Yaw damper:");
          yawRow.addChild("empty").set("stretch", 1);
          me.dialog.yawButton = yawRow.addChild("button");
          me.dialog.yawButton.set("halign", "right");
          me.dialog.yawButton.node.setValues({ "pref-width": 75, "pref-height": 25, legend: " x ", default: 0 });
          #topRow.addChild("empty").set("stretch", 1);
          me.dialog.yawButton.setBinding("nasal", "ja37.Dialog.yawToggle()");

          ######   Pitch damper button   #####
          var pitchRow = topRow.addChild("group");
          pitchRow.set("layout", "hbox");
          pitchRow.set("pref-height", 25);
          pitchRow.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          #tracksRow.set("valign", "center");
          
          var pitchText = pitchRow.addChild("text").set("label", "Pitch damper:");
          pitchRow.addChild("empty").set("stretch", 1);
          me.dialog.pitchButton = pitchRow.addChild("button");
          me.dialog.pitchButton.set("halign", "right");
          me.dialog.pitchButton.node.setValues({ "pref-width": 75, "pref-height": 25, legend: " x ", default: 0 });
          #topRow.addChild("empty").set("stretch", 1);
          me.dialog.pitchButton.setBinding("nasal", "ja37.Dialog.pitchToggle()");

          ######   Roll damper button   #####
          var rollRow = topRow.addChild("group");
          rollRow.set("layout", "hbox");
          rollRow.set("pref-height", 25);
          rollRow.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          #tracksRow.set("valign", "center");
          
          var rollText = rollRow.addChild("text").set("label", "Roll damper:");
          rollRow.addChild("empty").set("stretch", 1);
          me.dialog.rollButton = rollRow.addChild("button");
          me.dialog.rollButton.set("halign", "right");
          me.dialog.rollButton.node.setValues({ "pref-width": 75, "pref-height": 25, legend: " x ", default: 0 });
          #topRow.addChild("empty").set("stretch", 1);
          me.dialog.rollButton.setBinding("nasal", "ja37.Dialog.rollToggle()");

          ######   Roll limiter button   #####
          var rollLimitRow = topRow.addChild("group");
          rollLimitRow.set("layout", "hbox");
          rollLimitRow.set("pref-height", 25);
          rollLimitRow.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          #tracksRow.set("valign", "center");
          
          var rollLimitText = rollLimitRow.addChild("text").set("label", "Roll limiter:");
          rollLimitRow.addChild("empty").set("stretch", 1);
          me.dialog.rollLimitButton = rollLimitRow.addChild("button");
          me.dialog.rollLimitButton.set("halign", "right");
          me.dialog.rollLimitButton.node.setValues({ "pref-width": 75, "pref-height": 25, legend: " x ", default: 0 });
          #topRow.addChild("empty").set("stretch", 1);
          me.dialog.rollLimitButton.setBinding("nasal", "ja37.Dialog.rollLimitToggle()");

          ######   Elevator gearing button   #####
          var elevatorRow = topRow.addChild("group");
          elevatorRow.set("layout", "hbox");
          elevatorRow.set("pref-height", 25);
          elevatorRow.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          #tracksRow.set("valign", "center");
          
          var elevatorText = elevatorRow.addChild("text").set("label", "Elevator gearing:");
          elevatorRow.addChild("empty").set("stretch", 1);
          me.dialog.elevatorButton = elevatorRow.addChild("button");
          me.dialog.elevatorButton.set("halign", "right");
          me.dialog.elevatorButton.node.setValues({ "pref-width": 75, "pref-height": 25, legend: " x ", default: 0 });
          #topRow.addChild("empty").set("stretch", 1);
          me.dialog.elevatorButton.setBinding("nasal", "ja37.Dialog.elevatorToggle()");

          ######   Aileron gearing button   #####
          var aileronRow = topRow.addChild("group");
          aileronRow.set("layout", "hbox");
          aileronRow.set("pref-height", 25);
          aileronRow.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          #tracksRow.set("valign", "center");
          
          var yawText = aileronRow.addChild("text").set("label", "Aileron gearing:");
          aileronRow.addChild("empty").set("stretch", 1);
          me.dialog.aileronButton = aileronRow.addChild("button");
          me.dialog.aileronButton.set("halign", "right");
          me.dialog.aileronButton.node.setValues({ "pref-width": 75, "pref-height": 25, legend: " x ", default: 0 });
          #topRow.addChild("empty").set("stretch", 1);
          me.dialog.aileronButton.setBinding("nasal", "ja37.Dialog.aileronToggle()");

          ######   Rudder gearing button   #####
          var rudderRow = topRow.addChild("group");
          rudderRow.set("layout", "hbox");
          rudderRow.set("pref-height", 25);
          rudderRow.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          #tracksRow.set("valign", "center");
          
          var yawText = rudderRow.addChild("text").set("label", "Rudder gearing:");
          rudderRow.addChild("empty").set("stretch", 1);
          me.dialog.rudderButton = rudderRow.addChild("button");
          me.dialog.rudderButton.set("halign", "right");
          me.dialog.rudderButton.node.setValues({ "pref-width": 75, "pref-height": 25, legend: " x ", default: 0 });
          #topRow.addChild("empty").set("stretch", 1);
          me.dialog.rudderButton.setBinding("nasal", "ja37.Dialog.rudderToggle()");                    

          ######   Mouse optimized button   #####
          #var mouseRow = topRow.addChild("group");
          #mouseRow.set("layout", "hbox");
          #mouseRow.set("pref-height", 25);
          #mouseRow.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          #tracksRow.set("valign", "center");
          
          #var mouseText = mouseRow.addChild("text").set("label", "Optimize for mouse flying:");
          #mouseRow.addChild("empty").set("stretch", 1);
          #me.dialog.mouseButton = mouseRow.addChild("button");
          #me.dialog.mouseButton.set("halign", "right");
          #me.dialog.mouseButton.node.setValues({ "pref-width": 75, "pref-height": 25, legend: " x ", default: 0 });
          #topRow.addChild("empty").set("stretch", 1);
          #me.dialog.mouseButton.setBinding("nasal", "ja37.Dialog.mouseToggle()");

          ######   Cannon spread button   #####
          var cannonRow = topRow.addChild("group");
          cannonRow.set("layout", "hbox");
          cannonRow.set("pref-height", 25);
          cannonRow.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          #tracksRow.set("valign", "center");
          
          var mouseText = cannonRow.addChild("text").set("label", "Cannon spread (10 degs) :");
          cannonRow.addChild("empty").set("stretch", 1);
          me.dialog.cannonButton = cannonRow.addChild("button");
          me.dialog.cannonButton.set("halign", "right");
          me.dialog.cannonButton.node.setValues({ "pref-width": 75, "pref-height": 25, legend: " x ", default: 0 });
          #topRow.addChild("empty").set("stretch", 1);
          me.dialog.cannonButton.setBinding("nasal", "ja37.Dialog.cannonToggle()");

          ######   annunciation button   #####
          var annunRow = topRow.addChild("group");
          annunRow.set("layout", "hbox");
          annunRow.set("pref-height", 25);
          annunRow.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          #tracksRow.set("valign", "center");
          
          var mouseText = annunRow.addChild("text").set("label", "Annunciation (in english):");
          annunRow.addChild("empty").set("stretch", 1);
          me.dialog.annunButton = annunRow.addChild("button");
          me.dialog.annunButton.set("halign", "right");
          me.dialog.annunButton.node.setValues({ "pref-width": 75, "pref-height": 25, legend: " x ", default: 0 });
          #topRow.addChild("empty").set("stretch", 1);
          me.dialog.annunButton.setBinding("nasal", "ja37.Dialog.annunToggle()");

          ######   missile msg button   #####
          var rb24msgRow = topRow.addChild("group");
          rb24msgRow.set("layout", "hbox");
          rb24msgRow.set("pref-height", 25);
          rb24msgRow.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          #rb24msgRow.set("valign", "center");
          
          var rb24msgText = rb24msgRow.addChild("text").set("label", "Display MP message when hitting opponent:");
          rb24msgRow.addChild("empty").set("stretch", 1);
          me.dialog.rb24msgButton = rb24msgRow.addChild("button");
          me.dialog.rb24msgButton.set("halign", "right");
          me.dialog.rb24msgButton.node.setValues({ "pref-width": 75, "pref-height": 25, legend: " x ", default: 0 });
          me.dialog.rb24msgButton.setBinding("nasal", "ja37.Dialog.rb24msgToggle()");

          #HUD line thickness
          var lineRow = workArea.addChild("group");
          lineRow.set("layout", "hbox");
          lineRow.set("pref-height", 25);
          lineRow.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          #lineRow.set("valign", "center");
                    
          lineRow.addChild("text").set("label", "HUD line width:");
          lineRow.addChild("empty").set("stretch", 1);
          me.dialog.hudMinus = lineRow.addChild("button");
          me.dialog.hudDefault = lineRow.addChild("button");
          me.dialog.hudPlus = lineRow.addChild("button");
          me.dialog.hudPlus.node.setValues({ "pref-width": 100, "pref-height": 25, legend: "Thicker", default: 0 });
          me.dialog.hudDefault.node.setValues({ "pref-width": 100, "pref-height": 25, legend: "Default", default: 0 });
          me.dialog.hudMinus.node.setValues({ "pref-width": 100, "pref-height": 25, legend: "Thinner", default: 0 });
          me.dialog.hudPlus.setBinding("nasal", "ja37.Dialog.thicker()");
          me.dialog.hudDefault.setBinding("nasal", "ja37.Dialog.defaultThickness()");
          me.dialog.hudMinus.setBinding("nasal", "ja37.Dialog.thinner()");

          #HUD brightness
          var hudRow = workArea.addChild("group");
          hudRow.set("layout", "hbox");
          hudRow.set("pref-height", 25);
          hudRow.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          #hudRow.set("valign", "center");
                    
          hudRow.addChild("text").set("label", "HUD color:");
          hudRow.addChild("empty").set("stretch", 1);
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
          hangar.set("pref-height", 60);
          hangar.set("pref-width", DIALOG_WIDTH - SIDELOGO_WIDTH - 12);
          #hangar.set("valign", "center");

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
      var version = getprop("sim/ja37/supported/crash-system");
      var enabled = version==0?getprop("sim/ja37/damage/enabled"):crash1.crashCode.isStarted();
      if(enabled == 1) {
        version==0?setprop("sim/ja37/damage/enabled", 0):crash1.crashCode.stop();
      } else {
        version==0?setprop("sim/ja37/damage/enabled", 1):crash1.crashCode.start();
      }
      me.refreshButtons();
    },

    reverseToggle: func {
      ja37.click();
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
      ja37.click();
      var enabled = getprop("sim/ja37/radar/enabled");
      setprop("sim/ja37/radar/enabled", !enabled);
      me.refreshButtons();
    },

    tracksToggle: func {
      ja37.click();
      var enabled = getprop("sim/ja37/hud/tracks-enabled");
      setprop("sim/ja37/hud/tracks-enabled", !enabled);
      me.refreshButtons();
    },

    bankToggle: func {
      var enabled = getprop("sim/ja37/hud/bank-indicator");
      setprop("sim/ja37/hud/bank-indicator", !enabled);
      me.refreshButtons();
    },

    rudderToggle: func {
      ja37.click();
      var enabled = getprop("fdm/jsbsim/fcs/rudder/gearing-enable");
      setprop("fdm/jsbsim/fcs/rudder/gearing-enable", !enabled);
      me.refreshButtons();
    },

    aileronToggle: func {
      ja37.click();
      var enabled = getprop("fdm/jsbsim/fcs/aileron/gearing-enable");
      setprop("fdm/jsbsim/fcs/aileron/gearing-enable", !enabled);
      me.refreshButtons();
    },

    elevatorToggle: func {
      ja37.click();
      var enabled = getprop("fdm/jsbsim/fcs/elevator/gearing-enable");
      setprop("fdm/jsbsim/fcs/elevator/gearing-enable", !enabled);
      me.refreshButtons();
    },

    yawToggle: func {
      ja37.click();
      var enabled = getprop("fdm/jsbsim/fcs/yaw-damper/enable");
      setprop("fdm/jsbsim/fcs/yaw-damper/enable", !enabled);
      me.refreshButtons();
    },    

    pitchToggle: func {
      ja37.click();
      var enabled = getprop("fdm/jsbsim/fcs/pitch-damper/enable");
      setprop("fdm/jsbsim/fcs/pitch-damper/enable", !enabled);
      me.refreshButtons();
    },

    rollToggle: func {
      ja37.click();
      var enabled = getprop("fdm/jsbsim/fcs/roll-damper/enable");
      setprop("fdm/jsbsim/fcs/roll-damper/enable", !enabled);
      me.refreshButtons();
    },

    rollLimitToggle: func {
      ja37.click();
      var enabled = getprop("fdm/jsbsim/fcs/roll-limiter/enable");
      setprop("fdm/jsbsim/fcs/roll-limiter/enable", !enabled);
      me.refreshButtons();
    },

    mouseToggle: func {
      var enabled = getprop("fdm/jsbsim/fcs/mouse-optimized");
      setprop("fdm/jsbsim/fcs/mouse-optimized", !enabled);
      me.refreshButtons();
    },    

    cannonToggle: func {
      var enabled = getprop("ai/submodels/submodel[3]/random");
      setprop("ai/submodels/submodel[2]/random", !enabled);
      setprop("ai/submodels/submodel[3]/random", !enabled);
      me.refreshButtons();
    },    

    annunToggle: func {
      var enabled = getprop("sim/ja37/sound/annunciation-enabled");
      setprop("sim/ja37/sound/annunciation-enabled", !enabled);
      me.refreshButtons();
    },

    rb24msgToggle: func {
      var enabled = getprop("sim/ja37/armament/msg");
      setprop("sim/ja37/armament/msg", !enabled);
      me.refreshButtons();
    },    

    light: func {
      canvas_HUD.r = 0.6;
      canvas_HUD.g = 1.0;
      canvas_HUD.b = 0.6;
      #canvas_HUD.a = 1.0;
      #canvas_HUD.w = 10;
      #canvas_HUD.fs = 1;
      canvas_HUD.reinit();
    },

    medium: func {
      canvas_HUD.r = 0.0;
      canvas_HUD.g = 0.8;
      canvas_HUD.b = 0.0;
      #canvas_HUD.a = 1.0;      
      #canvas_HUD.w = 11;
      #canvas_HUD.fs = 1.1;
      canvas_HUD.reinit();
    },

    dark: func {
      canvas_HUD.r = 0.0;
      canvas_HUD.g = 0.4;
      canvas_HUD.b = 0.0;
      #canvas_HUD.a = 1.0;
      #canvas_HUD.w = 12;
      #canvas_HUD.fs = 1.2;
      canvas_HUD.reinit();
    },

    thicker: func {
      setprop("sim/ja37/hud/stroke-linewidth", getprop("sim/ja37/hud/stroke-linewidth") + 0.5);
      canvas_HUD.reinit();
    },

    defaultThickness: func {
      setprop("sim/ja37/hud/stroke-linewidth", 4);
      canvas_HUD.reinit();
    },    

    thinner: func {
      var w = getprop("sim/ja37/hud/stroke-linewidth");
      w = w - 0.5;
      if(w < 0.5) w = 0.5;
      setprop("sim/ja37/hud/stroke-linewidth", w);
      canvas_HUD.reinit();
    },

    refreshButtons: func {
      # update break button
      var version = getprop("sim/ja37/supported/crash-system");
      var enabled = version==0?getprop("sim/ja37/damage/enabled"):crash1.crashCode.isStarted();
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

      enabled = getprop("sim/ja37/hud/tracks-enabled");
      if(enabled == 1) {
        legend = "Enabled";
      } else {
        legend = "Disabled";
      }
      me.dialog.tracksButton.node.setValues({"legend": legend});

      enabled = getprop("sim/ja37/hud/bank-indicator");
      if(enabled == 1) {
        legend = "Enabled";
      } else {
        legend = "Disabled";
      }
      me.dialog.bankButton.node.setValues({"legend": legend});

      enabled = getprop("fdm/jsbsim/fcs/yaw-damper/enable");
      if(enabled == 1) {
        legend = "Enabled";
      } else {
        legend = "Disabled";
      }
      me.dialog.yawButton.node.setValues({"legend": legend});

      enabled = getprop("fdm/jsbsim/fcs/pitch-damper/enable");
      if(enabled == 1) {
        legend = "Enabled";
      } else {
        legend = "Disabled";
      }
      me.dialog.pitchButton.node.setValues({"legend": legend});

      enabled = getprop("fdm/jsbsim/fcs/roll-damper/enable");
      if(enabled == 1) {
        legend = "Enabled";
      } else {
        legend = "Disabled";
      }
      me.dialog.rollButton.node.setValues({"legend": legend});

      enabled = getprop("fdm/jsbsim/fcs/roll-limiter/enable");
      if(enabled == 1) {
        legend = "Enabled";
      } else {
        legend = "Disabled";
      }
      me.dialog.rollLimitButton.node.setValues({"legend": legend});

      enabled = getprop("fdm/jsbsim/fcs/rudder/gearing-enable");
      if(enabled == 1) {
        legend = "Enabled";
      } else {
        legend = "Disabled";
      }
      me.dialog.rudderButton.node.setValues({"legend": legend});

      enabled = getprop("fdm/jsbsim/fcs/aileron/gearing-enable");
      if(enabled == 1) {
        legend = "Enabled";
      } else {
        legend = "Disabled";
      }
      me.dialog.aileronButton.node.setValues({"legend": legend});

      enabled = getprop("fdm/jsbsim/fcs/elevator/gearing-enable");
      if(enabled == 1) {
        legend = "Enabled";
      } else {
        legend = "Disabled";
      }
      me.dialog.elevatorButton.node.setValues({"legend": legend});

      #enabled = getprop("fdm/jsbsim/fcs/mouse-optimized");
      #if(enabled == 1) {
      #  legend = "Enabled";
      #} else {
      #  legend = "Disabled";
      #}
      #me.dialog.mouseButton.node.setValues({"legend": legend});

      enabled = getprop("ai/submodels/submodel[3]/random");
      if(enabled == 1) {
        legend = "Enabled";
      } else {
        legend = "Disabled";
      }
      me.dialog.cannonButton.node.setValues({"legend": legend});

      enabled = getprop("sim/ja37/sound/annunciation-enabled");
      if(enabled == 1) {
        legend = "Enabled";
      } else {
        legend = "Disabled";
      }
      me.dialog.annunButton.node.setValues({"legend": legend});

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
        ja37.popupTip("Options is only supported in Flightgear version 3.0 and upwards.");
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