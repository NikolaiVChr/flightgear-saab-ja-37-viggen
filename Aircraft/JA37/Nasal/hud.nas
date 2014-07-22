# ==============================================================================
# Head up display
#
# stole some code from the buccaneer and the wiki example
#
# ==============================================================================

var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }
var pow2 = func(x) { return x * x; };
var vec_length = func(x, y) { return math.sqrt(pow2(x) + pow2(y)); };
var round0 = func(x) { return math.abs(x) > 0.01 ? x : 0; };
var deg2rads = math.pi/180.0;
var blinking = 0; # how many updates the speed vector symbol has been turned off for blinking (convert to time when less lazy)
var alt_scale_mode = 0;
var QFE = 0;
var countQFE = 0;
var centerOffset = 275;
var pixelPerDegree = 50; #vertical axis

print("making HUD");

var HUDnasal = {
  canvas_settings: {
    "name": "HUDnasal",
    "size": [2048, 2048],#width of texture to be replaced
	  "view": [1024, 1024],#width of canvas
    "mipmapping": 0
  },
  new: func(placement)
  {
    var m = {
      parents: [HUDnasal],
      canvas: canvas.new(HUDnasal.canvas_settings),
      text_style: {
        'font': "LiberationFonts/LiberationMono-Regular.ttf",
#		'font': "LiberationFonts/LiberationSerif-Regular.ttf",
#		'font': "LiberationFonts/LiberationSans-Regular.ttf",
        'character-size': 100,
        
      }
    };
 
    m.canvas.addPlacement(placement);
    m.canvas.setColorBackground(0.36, 1, 0.3, 0.02);
    m.root = m.canvas.createGroup();
    var slant = 35; #degrees the HUD is slanted towards the pilot
    m.root.setScale(math.sin(slant*deg2rads), 1);
    m.root.setTranslation(512, 512);
 
    # Heading
    m.hdg = m.root.createChild("text");
    #m.hdg._node.setValues(m.text_style);
    #m.hdg.setDrawMode(3);
    #m.hdg.setPadding(2);
    m.hdg.setColor(0, 1, 0);
    m.hdg.setColorFill(0.36, 1, 0.3);
    m.hdg.setAlignment("center-top");
    m.hdg.setTranslation(0, -400);
    m.hdg.setFontSize(50, 0.9);

		var w = 10;
		var r = 0.0;
		var g = 1.0;
		var b = 0.0;
		var a = 0.8;
	
	# airspeed kts/mach	
	m.airspeed = m.root.createChild("text")
		.setText("000")
		.setFontSize(75, 0.9)
		.setColor(0, 1, 0)
		.setAlignment("center-center")
		.setTranslation(0 , 400);

	#m.Vr_group = m.root.createChild("group");
	#m.Vr_trans = m.Vr_group.createTransform();
	#m.Vr_pointer = m.Vr_group.createChild("path")
#		.moveTo(-640,-290)
#		.vert(20)
#		.setStrokeLineWidth(w)
#		.setColor(r, g, b, a);

	# Altitude

    #m.altitude_group = m.root.createChild("group");
    #m.alt_trans = m.altitude_group.createTransform();

  # scale high
    m.alt_scale_high=m.root.createChild("path")
      .moveTo(0, -1000)
      .horiz(50)
      .moveTo(0, -800)
      .horiz(75)
      .moveTo(0, -600)
      .horiz(50)
      .moveTo(0, -400)
      .horiz(75)
      .moveTo(0, -200)
      .horiz(50)           
      .moveTo(0, 0)
      .horiz(75)
      .setStrokeLineWidth(w)
      .setColor(0,0,0, 0);

  # scale medium
    m.alt_scale_med=m.root.createChild("path")
      .moveTo(0, -1000)
      .horiz(50)
      .moveTo(0, -800)
      .horiz(75)
      .moveTo(0, -600)
      .horiz(50)
      .moveTo(0, -400)
      .horiz(75)
      .moveTo(0, -320)
      .horiz(25)
      .moveTo(0, -240)
      .horiz(25)           
      .moveTo(0, -160)
      .horiz(25)
      .moveTo(0, -80)
      .horiz(25)           
      .moveTo(0, 0)
      .horiz(75)
      .setStrokeLineWidth(w)
      .setColor(0,0,0, 0);

	# scale low
		m.alt_scale_low=m.root.createChild("path")
			.moveTo(0, -500)
      .horiz(50)
      .moveTo(0, -400)
      .horiz(75)
      .moveTo(0,-320)
      .horiz(25)
      .moveTo(0, -240)
      .horiz(25)
			.moveTo(0, -160)
			.horiz(25)					 
			.moveTo(0,-80)
			.horiz(25)
			.moveTo(0, 0)
			.horiz(75)
			.setStrokeLineWidth(w)
			.setColor(0,0,0, 0);
# low
    m.alt_low = m.root.createChild("text")
      .setText(".")
      .setFontSize(50, 0.9)
      .setColor(0,0,1,1)
      .setAlignment("left-center")
      .setTranslation(1, 0);
# middle	
		m.alt_med = m.root.createChild("text")
			.setText(".")
      .setFontSize(50, 0.9)
      .setColor(0,0,1,1)
			.setAlignment("left-center")
      .setTranslation(1, 0);
# high			 
		m.alt_high = m.root.createChild("text")
			.setText(".")
      .setFontSize(50, 0.9)
      .setColor(0,0,1,1)
			.setAlignment("left-center")
      .setTranslation(1, 0);

# higher     
    m.alt_higher = m.root.createChild("text")
      .setText(".")
      .setFontSize(50, 0.9)
      .setColor(0,0,1,1)
      .setAlignment("left-center")
      .setTranslation(1, 0);
		
		m.alt_pointer = m.root.createChild("text")
			.setText(">")
      .setFontSize(75, 0.9)
			.setColor(0,1,0, 1)
      .setAlignment("left-center")
      .setTranslation(300, 0);

    # Groundspeed
    #m.groundspeed = m.root.createChild("text");
    #m.groundspeed._node.setValues(m.text_style);
    #m.groundspeed.setColor(0.36, 1, 0.3);
    #m.groundspeed.setAlignment("left-center");
    #m.groundspeed.setTranslation(-220, 90);
  
    # QFE warning (inhg not properly set, is being adjusted)
    m.qfe = m.root.createChild("text");
    m.qfe.setText("QFE");
    m.qfe.setColor(0, 0, 0, 0);
    m.qfe.setAlignment("center-center");
    m.qfe.setTranslation(-500, 200);
    m.qfe.setFontSize(65, 0.9);

    # Altitude number (Not shown in landing/takeoff mode. Radar at less than 100 feet)
    m.alt = m.root.createChild("text");
    m.alt.setColor(0, 1, 0, 1);
    m.alt.setAlignment("center-center");
    m.alt.setTranslation(-500, 300);
    m.alt.setFontSize(70, 0.9);
 
    # Waterline / Pitch indicator
    #m.root.createChild("path")
    #      .moveTo(-24, 0)
    #      .horizTo(-8)
    #      .lineTo(-4, 6)
    #      .lineTo(0, 0)
    #      .lineTo(4, 6)
    #      .lineTo(8, 0)
    #      .horizTo(24)
    #      .setStrokeLineWidth(w)
    #      .setColor(0.36, 1, 0.3, a);
 
    # Flightpath/Velocity vector
    m.vec_vel =
      m.root.createChild("path")
      .setColor(0,0,0)
      .moveTo(-60, 0) # draw this symbol in flight when no weapons selected (always as for now)
      .lineTo(-30, 0)
      .lineTo(0, 30)
      .lineTo(30, 0)
      .lineTo(60, 0)
      .setStrokeLineWidth(w);
 
    m.takeoff_symbol = m.root.createChild("path")
      .moveTo(120, 0)
      .lineTo(90, 0)
      .moveTo(60, 0)
      .lineTo(30, 0)
      .arcSmallCCW(30, 30, 0, -60, 0)
      .arcSmallCCW(30, 30, 0,  60, 0)
      .close()
      .moveTo(-30, 0)
      .lineTo(-60, 0)
      .moveTo(-90, 0)
      .lineTo(-120, 0)
      .setStrokeLineWidth(w)
      .setStrokeLineCap("round")
      .setColor(0,1,0, 1);

    # Horizon
    m.horizon_group = m.root.createChild("group");
    m.horizon_group2 = m.horizon_group.createChild("group");
    #m.h_trans = m.horizon_group.createTransform();
    m.h_rot   = m.horizon_group.createTransform();
 
    # pitch lines
    var distance = pixelPerDegree * 10;
    for(var i = -9; i <= 9; i += 1)
      m.horizon_group2.createChild("path")
                     .moveTo(200, -i * distance)
                     .horiz(50)
                     .moveTo(300, -i * distance)
                     .horiz(50)
                     .moveTo(400, -i * distance)
                     .horiz(50)
                     .moveTo(500, -i * distance)
                     .horiz(50)
                     .moveTo(600, -i * distance)
                     .horiz(50)

                     .moveTo(-200, -i * distance)
                     .horiz(-50)
                     .moveTo(-300, -i * distance)
                     .horiz(-50)
                     .moveTo(-400, -i * distance)
                     .horiz(-50)
                     .moveTo(-500, -i * distance)
                     .horiz(-50)
                     .moveTo(-600, -i * distance)
                     .horiz(50)
                     
                     .setStrokeLineWidth(w)
                     .setColor(0,1,0, 1);
 
    #Horizon line
    m.horizon =
      m.horizon_group2.createChild("path")
                     .moveTo(-650, 0)
                     .horizTo(650)
                     .setStrokeLineWidth(w)
                     .setColor(0,1,0, 1);
 
    m.input = {
      pitch:    "/orientation/pitch-deg",
			roll:     "/orientation/roll-deg",
			hdg:      "/orientation/heading-deg",
      speed_n:  "velocities/speed-north-fps",
      speed_e:  "velocities/speed-east-fps",
      speed_d:  "velocities/speed-down-fps",
      alpha:    "/orientation/alpha-deg",
      beta:     "/orientation/side-slip-deg",
      ias:      "/velocities/airspeed-kt",
      gs:       "/velocities/groundspeed-kt",
      vs:       "/velocities/vertical-speed-fps",
      rad_alt:  "position/altitude-agl-ft",#/instrumentation/radar-altimeter/radar-altitude-ft",
      alt_ft:   "/instrumentation/altimeter/indicated-altitude-ft",
      wow_nlg:  "/gear/gear[0]/wow",
      Vr:       "/controls/switches/HUDnasal_rotation_speed",
	    Bright:   "/controls/switches/HUDnasal_brightness",
      Dir_sw:   "/controls/switches/HUDnasal_director", 
	    H_sw:     "/controls/switches/HUDnasal_height", 
	    Speed_sw: "/controls/switches/HUDnasal_speed", 
	    Test_sw:  "/controls/switches/HUDnasal_test",
	    fdpitch:  "/autopilot/settings/fd-pitch-deg",
	    fdroll:   "/autopilot/settings/fd-roll-deg",
	    fdspeed:  "/autopilot/settings/target-speed-kt"

    };
 
    foreach(var name; keys(m.input))
      m.input[name] = props.globals.getNode(m.input[name], 1);
 
    return m;
    },
    setColorBackground: func () { 
  		#me.texture.getNode('background', 1).setValue(_getColor(arg)); 
  		me; 
  		},
    update: func()
    {
      var mach = me.input.ias.getValue() * 0.0015;
      if (mach >= 0.5) 
      {
        me.airspeed.setText(sprintf("%.2f", mach));
      } else {
        me.airspeed.setText(sprintf("%03d", me.input.ias.getValue() * 0.54));
      }
      
      var in_ias = me.input.ias.getValue() or 0;
      #in_ias = clamp(in_ias, 300, 600);
      #me.a_trans.setTranslation(0.6 * (in_ias - 300), 0);
      #var in_Vr = me.input.Vr.getValue() or 0;
      #me.Vr_trans.setTranslation(4 * in_Vr,0);

      #me.vertical_speed.setText(sprintf("%.1f", me.input.vs.getValue() * 60.0 / 1000));
   
      me.hdg.setText(sprintf("%02d", me.input.hdg.getValue()/10));
      
  	  #var in_pitch = me.input.pitch.getValue() or 0;
  	  #me.h_trans.setTranslation(0, 12.5 * in_pitch);
   
      #var rot = -me.input.roll.getValue() * math.pi / 180.0;
      #me.h_rot.setRotation(rot);

			#var bright = me.input.Bright.getValue() or 0.8;
			#var sw_d = me.input.Dir_sw.getValue() or 0;	
			#var sw_h = me.input.H_sw.getValue() or 0;
			#var sw_s = me.input.Speed_sw.getValue() or 0;	
			#var sw_t = me.input.Test_sw.getValue() or 0;

			#var G = bright;
			#var A = 0.65 * bright;
			#var Gd = bright * sw_d;
			#var Ad = 0.65 * bright * sw_d;
			#var Gh = bright * sw_h;
			#var Ah = 0.65 * bright * sw_h;
			#var Gs = bright * sw_s;
			#var As = 0.65 * bright * sw_s;

			#me.airspeed_scale.setColor(0.0,Gs,0.0,As);		
			#me.airspeed_pointer.setColor(0.0,Gs,0.0,As);	
			#me.Vr_pointer.setColor(0.0,Gs,0.0,As);

      var alt = me.input.alt_ft.getValue() * 0.305;
      var radAlt = me.input.rad_alt.getValue() * 0.305;
      # determine which scale to use
      if (alt_scale_mode == 0) {
        if (alt < 45) {
          alt_scale_mode = 0;
        } else {
          alt_scale_mode = 1;
        }
      } elsif (alt_scale_mode == 1) {
        if (alt < 90 and alt >= 40) {
          alt_scale_mode = 1;
        } else if (alt >= 90) {
          alt_scale_mode = 2;
        } else if (alt < 40) {
          alt_scale_mode = 0;
        } else {
          alt_scale_mode = 1;
        }
      } elsif (alt_scale_mode == 2) {
        if (alt >= 85) {
          alt_scale_mode = 2;
        } else {
          alt_scale_mode = 1;
        }
      }
      #place the scale
      if (alt_scale_mode == 0) {
        hide(me.alt_scale_med);
        hide(me.alt_scale_high);
        show(me.alt_scale_low);
        hide(me.alt_higher);
        show(me.alt_high);
        hide(me.alt_med);
        show(me.alt_low);
        var offset = 400/50 * alt;
        me.alt_scale_low.setTranslation(380 , offset);
        me.alt_low.setTranslation(460 , offset);
        me.alt_high.setTranslation(460 , offset-400);
        me.alt_low.setText("0");
        me.alt_high.setText("50");
        #print("alt " ~ sprintf("%3d", alt) ~ " placing low " ~ sprintf("%3d", offset));
      } elsif (alt_scale_mode == 1) {
        show(me.alt_scale_med);
        hide(me.alt_scale_high);
        hide(me.alt_scale_low);
        hide(me.alt_higher);
        show(me.alt_high);
        show(me.alt_med);
        show(me.alt_low);
        var offset = 800/100 * alt;
        me.alt_scale_med.setTranslation(380 , offset);
        me.alt_low.setTranslation(460 , offset);
        me.alt_med.setTranslation(460 , offset-400);
        me.alt_high.setTranslation(460 , offset-800);
        me.alt_low.setText("0");
        me.alt_med.setText("50");
        me.alt_high.setText("100");
        #print("alt " ~ sprintf("%3d", alt) ~ " placing med " ~ sprintf("%3d", offset));
      } elsif (alt_scale_mode == 2) {
        hide(me.alt_scale_med);
        show(me.alt_scale_high);
        #show(me.alt_scale_high2);
        hide(me.alt_scale_low);
        show(me.alt_higher);
        show(me.alt_high);
        show(me.alt_med);
        show(me.alt_low);
        var fact = int(alt / 100) * 100;
        var factor = alt - fact + 100;
        var offset = 800/200 * factor;
        me.alt_scale_high.setTranslation(380 , offset);
        #me.alt_scale_high2.setTranslation(380 , offset-800);
        me.alt_low.setTranslation(460 , offset);
        me.alt_med.setTranslation(460 , offset-400);
        me.alt_high.setTranslation(460 , offset-800);
        me.alt_higher.setTranslation(460 , offset-1200);
        var low = fact - 100;
        if(low > 1000) {
          me.alt_low.setText(sprintf("%.1f", low/1000));
        } else {
          me.alt_low.setText(low);
        }
        var med = fact;
        if(med > 1000) {
          me.alt_med.setText(sprintf("%.1f", med/1000));
        } else {
          me.alt_med.setText(med);
        }
        var high = fact + 100;
        if(high > 1000) {
          me.alt_high.setText(sprintf("%.1f", high/1000));
        } else {
          me.alt_high.setText(high);
        }
        var higher = fact + 200;
        if(higher > 1000) {
          me.alt_higher.setText(sprintf("%.1f", higher/1000));
        } else {
          me.alt_higher.setText(higher);
        }
        #print("alt " ~ sprintf("%3d", alt) ~ " offset:" ~ sprintf("%3d", offset) ~ " factor:" ~ sprintf("%3d", factor)~ " fact:" ~ sprintf("%3d", fact));
      }

      # digital altitude
      if (radAlt == nil) {
        me.alt.setText("");
      } elsif (radAlt < 100) {
        me.alt.setText("R " ~ sprintf("%3d", clamp(radAlt, 0, 100)));
        # check for QFE warning
        var diff = radAlt - alt;
        if (countQFE == 0 and (diff > 25 or diff < -25)) {
          #print("QFE warning " ~ countQFE);
          countQFE = 1;          
        }
      } else {
        countQFE = 0;
        QFE = 0;
        me.alt.setText(sprintf("%4d", clamp(alt, 0, 9999)));
      }

      # display and adjust QFE
      if (countQFE != 0) {
        # QFE is shown
        if(countQFE == 1) {
          countQFE = 2;
        }
        if(countQFE < 10) {
           # blink the QFE
          if (QFE < 1 and QFE != -10) {
              hide(me.qfe);
              QFE = QFE -1;
              #print("blink off");
          } elsif (QFE > 0) {
            if (QFE == 10) {
              QFE = -1;
              countQFE = countQFE + 1;
              #print("blink count")
            } else {
              QFE = QFE + 1;
            }
            show(me.qfe);
            #print("blink  on");
          } else {
              if (QFE == -10) {
                QFE = 0;
              }
              show(me.qfe);
              QFE = QFE + 1;
              #print("blink  on");
          }
        } elsif (countQFE == 10) {
          # QFE is adjusting the altimeter
          var inhg = getprop("environment/pressure-inhg");
          setprop("instrumentation/altimeter/setting-inhg", inhg);
          countQFE = 11;
          #print("QFE adjusted " ~ inhg);
        } elsif (countQFE < 70) {
          # QFE is steady
          countQFE = countQFE + 1;
          show (me.qfe);
          #print("steady on");
        } else {
          countQFE = 0;
          #print("off");
        }
      } else {
        hide(me.qfe);
        #print("hide  off");
      }
    #print("QFE count " ~ countQFE);

      # Sights/crosshairs
    if(getprop("gear/gear/position-norm") != nil and getprop("gear/gear/position-norm") == 0) {
      hidePath(me.takeoff_symbol);
      # flight path vector (FPV)
      var vel_gx = me.input.speed_n.getValue();
      var vel_gy = me.input.speed_e.getValue();
      var vel_gz = me.input.speed_d.getValue();
   
      var yaw = me.input.hdg.getValue() * math.pi / 180.0;
      var roll = me.input.roll.getValue() * math.pi / 180.0;
      var pitch = me.input.pitch.getValue() * math.pi / 180.0;
   
      var sy = math.sin(yaw);   var cy = math.cos(yaw);
      var sr = math.sin(roll);  var cr = math.cos(roll);
      var sp = math.sin(pitch); var cp = math.cos(pitch);
   
      var vel_bx = vel_gx * cy * cp
                 + vel_gy * sy * cp
                 + vel_gz * -sp;
      var vel_by = vel_gx * (cy * sp * sr - sy * cr)
                 + vel_gy * (sy * sp * sr + cy * cr)
                 + vel_gz * cp * sr;
      var vel_bz = vel_gx * (cy * sp * cr + sy * sr)
                 + vel_gy * (sy * sp * cr - cy * sr)
                 + vel_gz * cp * cr;
   
      var dir_y = math.atan2(round0(vel_bz), math.max(vel_bx, 0.001)) * 180.0 / math.pi;
      var dir_x  = math.atan2(round0(vel_by), math.max(vel_bx, 0.001)) * 180.0 / math.pi;
   
      me.vec_vel.setTranslation(clamp(dir_x * 40, -450-centerOffset, 450-centerOffset), clamp(dir_y * 40, -450-centerOffset, 450-centerOffset)+centerOffset);
      if (dir_y > 8) {
        # blink the flight vector cross hair if alpha is high
        if (blinking < 1 and blinking != -5) {
            hidePath(me.vec_vel);
            blinking = blinking -1;
        } elsif (blinking > 0) {
          if (blinking == 5) {
            blinking = -1;
          } else {
            blinking = blinking + 1;
          }
          showPath(me.vec_vel);
        } else {
            if (blinking == -5) {
              blinking = 0;
            }
            showPath(me.vec_vel);
            blinking = blinking + 1;
        }
      } else {
        showPath(me.vec_vel);
        blinking = 0;
      }
    } else {
      hidePath(me.vec_vel);
      showPath(me.takeoff_symbol);
      
      #move takeoff/landing symbol according to side wind:
      var wind_heading = getprop("environment/wind-from-heading-deg");
      var wind_speed = getprop("environment/wind-speed-kt");
      var heading = me.input.hdg.getValue();
      #var speed = me.input.ias.getValue();
      var angle = (wind_heading -heading) * (math.pi / 180.0); 
      var wind_side = math.sin(angle) * wind_speed;
      #print((wind_heading -heading) ~ " " ~ wind_side);
      me.takeoff_symbol.setTranslation(clamp(-wind_side * 80, -450, 450), 300);
    }

    # artificial horizon and pitch lines
    me.horizon_group2.setTranslation(0, pixelPerDegree * me.input.pitch.getValue());
    me.horizon_group.setTranslation(0, centerOffset);
    var rot = -me.input.roll.getValue() * deg2rads;
    me.h_rot.setRotation(rot);


    if (getprop("fcs/fbw-override") == 1) #tmp debug stuff
     {
	     #?
		   print("HUD removed");
	   } else {
		   #print("HUD repainted");
	     settimer(func me.update(), 0);
       setprop("sim/hud/visibility[1]", 0);
	   }
  }
};
 
var hide=func(elem)
  {
    elem.setColor(0,0,0,0);
    elem.setColorFill(0, 0, 0,0);
  }

  var show=func(elem)
  {
    elem.setColor(0,1,0,1);
    elem.setColorFill(0, 1, 0,1);
  }

  var hidePath=func(elem)
  {
    elem.setColor(0,0,0,0);
    elem.setTranslation(10000, 0); # workaround:  two canvas paths intersecting, will reveal some of the hidden one.
    #elem.setColorFill(0, 0, 0,0);
  }

  var showPath=func(elem)
  {
    elem.setColor(0,1,0,1);
    #elem.setColorFill(0, 0, 0,1);
  }

var init = setlistener("/sim/signals/fdm-initialized", func() {
  removelistener(init); # only call once
  var hud_pilot = HUDnasal.new({"node": "HUDobject", "texture": "hud.png"});
  setprop("sim/hud/visibility[1]", 0);
  print("HUD initialized.");
  hud_pilot.update();
});

var init2 = setlistener("/sim/signals/reinit", func() {
  setprop("sim/hud/visibility[1]", 0);
});