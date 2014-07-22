# ==============================================================================
# Head up display
#
# Nicked some code from the buccaneer and the wiki example to get started
#
# Made for the JA-37 by Necolatis
# ==============================================================================

var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }
var pow2 = func(x) { return x * x; };
var vec_length = func(x, y) { return math.sqrt(pow2(x) + pow2(y)); };
var round0 = func(x) { return math.abs(x) > 0.01 ? x : 0; };
var roundabout = func(x) {
  var y = x - int(x);

  return y < 0.5 ? int(x) : 1 + int(x) ;
};
var deg2rads = math.pi/180.0;
var blinking = 0; # how many updates the speed vector symbol has been turned off for blinking (convert to time when less lazy)
var alt_scale_mode = 0; # the alt scale is not liniar, this indicates which part is showed
var QFE = 0;
var countQFE = 0;
var centerOffset = 102; #verical center of HUD. (in line from pilots eyes) 0.53m is height of HUD bottom. View is 0.57m. Height of HUD is 10 cm.
var pixelPerDegree = 100; #vertical axis
var radPointerProxim = 60; #when alt indicater is too close to radar ground indicator, hide indicator
var scalePlace = 380; #horizontal placement of alt scales
var numberOffset = 100; #alt scale numbers horizontal offset from scale 
var indicatorOffset = -10; #alt scale indicators horizontal offset from scale (must be high, due to bug #1054 in canvas) 
var headScalePlace = 300; # vert placement of alt scale
var altimeterScaleHeight = 300; # the height of the low alt scale. Also used in the other scales as a reference height.

print("Starting JA-37 HUD");

var HUDnasal = {
  canvas_settings: {
    "name": "HUDnasal",
    "size": [2048, 2048],# width of texture to be replaced
	  "view": [1024, 1024],# width of canvas
    "mipmapping": 1
  },
  new: func(placement)
  {
    var m = {
      parents: [HUDnasal],
      canvas: canvas.new(HUDnasal.canvas_settings),
      text_style: {
        'font': "LiberationFonts/LiberationMono-Regular.ttf", 
        'character-size': 100,
        
    }
  };
 
  m.canvas.addPlacement(placement);
  m.canvas.setColorBackground(0.36, 1, 0.3, 0.02);
  m.root = m.canvas.createGroup()
            .set("font", "LiberationFonts/LiberationMono-Regular.ttf");# If using default font, horizontal alignment is not accurate (bug #1054), also prettier char spacing. 
  var slant = 35; #degrees the HUD is slanted towards the pilot
  m.root.setScale(math.sin(slant*deg2rads), 1);
  m.root.setTranslation(512, 512);

  

	var w = 10;
	var r = 0.0;
	var g = 1.0;
	var b = 0.0;
	var a = 0.8;

# digital airspeed kts/mach	
  m.airspeed = m.root.createChild("text")
  	.setText("000")
  	.setFontSize(100, 0.9)
  	.setColor(0, 1, 0)
  	.setAlignment("center-center")
  	.setTranslation(0 , 400);

# scale heading ticks
  m.head_scale_grp = m.root.createChild("group");
  m.head_scale_grp.set("clip", "rect(62px, 587px, 262px, 437px)");#top,right,bottom,left
  m.head_scale_grp_trans = m.head_scale_grp.createTransform();
  m.head_scale = m.head_scale_grp.createChild("path")
      .moveTo(-100, 0)
      .vert(-60)
      .moveTo(0, 0)
      .vert(-60)
      .moveTo(100, 0)
      .vert(-60)
      .moveTo(-50, 0)
      .vert(-40)
      .moveTo(50, 0)
      .vert(-40)
      .setStrokeLineWidth(w)
      .setColor(0,1,0, 1);

# scale heading end ticks
  m.hdgLineL = m.head_scale_grp.createChild("path")
  .setStrokeLineWidth(w)
    .setColor(0,1,0, 1)
    .moveTo(-150, 0)
    .vert(-40)
    .close();

  m.hdgLineR = m.head_scale_grp.createChild("path")
  .setStrokeLineWidth(w)
    .setColor(0,1,0, 1)
    .moveTo(150, 0)
    .vert(-40)
    .close();

# headingindicator
  m.head_scale_indicator = m.root.createChild("path")
  .setColor(0,1,0, 1)
  .setStrokeLineWidth(w)
  .moveTo(-30, -headScalePlace+30)
  .lineTo(0, -headScalePlace)
  .lineTo(30, -headScalePlace+30);

# Heading middle number
  m.hdgM = m.head_scale_grp.createChild("text");
  m.hdgM.setColor(0, 1, 0, 1);
  m.hdgM.setAlignment("center-bottom");
  m.hdgM.setFontSize(50, 0.9);

# Heading left number
  m.hdgL = m.head_scale_grp.createChild("text");
  m.hdgL.setColor(0, 1, 0, 1);
  m.hdgL.setAlignment("center-bottom");
  m.hdgL.setFontSize(50, 0.9);

# Heading right number
  m.hdgR = m.head_scale_grp.createChild("text");
  m.hdgR.setColor(0, 1, 0, 1);
  m.hdgR.setAlignment("center-bottom");
  m.hdgR.setFontSize(50, 0.9);

# Altitude
  m.alt_scale_grp=m.root.createChild("group")
    .set("clip", "rect(150px, 1800px, 874px, 0px)");#top,right,bottom,left
  m.alt_scale_grp_trans = m.alt_scale_grp.createTransform();

# alt scale high
  m.alt_scale_high=m.alt_scale_grp.createChild("path")
    .moveTo(0, -6*altimeterScaleHeight/2)
    .horiz(75)
    .moveTo(0, -5*altimeterScaleHeight/2)
    .horiz(50)
    .moveTo(0, -2*altimeterScaleHeight)
    .horiz(75)
    .moveTo(0, -3*altimeterScaleHeight/2)
    .horiz(50)
    .moveTo(0, -altimeterScaleHeight)
    .horiz(75)
    .moveTo(0, -altimeterScaleHeight/2)
    .horiz(50)
    .moveTo(0, 0)
    .horiz(75)
    .setStrokeLineWidth(w)
    .setColor(0,1,0, 1);

# alt scale medium
  m.alt_scale_med=m.alt_scale_grp.createChild("path")
    .moveTo(0, -5*altimeterScaleHeight/2)
    .horiz(50)
    .moveTo(0, -2*altimeterScaleHeight)
    .horiz(75)
    .moveTo(0, -3*altimeterScaleHeight/2)
    .horiz(50)
    .moveTo(0, -altimeterScaleHeight)
    .horiz(75)
    .moveTo(0, -4*altimeterScaleHeight/5)
    .horiz(25)
    .moveTo(0, -3*altimeterScaleHeight/5)
    .horiz(25)           
    .moveTo(0, -2*altimeterScaleHeight/5)
    .horiz(25)
    .moveTo(0, -1*altimeterScaleHeight/5)
    .horiz(25)           
    .moveTo(0, 0)
    .horiz(75)
    .setStrokeLineWidth(w)
    .setColor(0,1,0, 1);

# alt scale low
		m.alt_scale_low = m.alt_scale_grp.createChild("path")
    .moveTo(0, -7*altimeterScaleHeight/4)
    .horiz(50)
    .moveTo(0, -6*altimeterScaleHeight/4)
    .horiz(75)
		.moveTo(0, -5*altimeterScaleHeight/4)
    .horiz(50)
    .moveTo(0, -altimeterScaleHeight)
    .horiz(75)
    .moveTo(0,-4*altimeterScaleHeight/5)
    .horiz(25)
    .moveTo(0, -3*altimeterScaleHeight/5)
    .horiz(25)
		.moveTo(0, -2*altimeterScaleHeight/5)
		.horiz(25)					 
		.moveTo(0,-1*altimeterScaleHeight/5)
		.horiz(25)
		.moveTo(0, 0)
		.horiz(75)
		.setStrokeLineWidth(w)
		.setColor(0,1,0, 1);
    
# vert line at zero alt if it is lower than radar zero
    m.alt_scale_line = m.alt_scale_grp.createChild("path")
    .moveTo(0, 30)
    .vert(-60)
    .setStrokeLineWidth(w)
    .setColor(0,1,0,1);
# low alt number
  m.alt_low = m.alt_scale_grp.createChild("text")
    .setText(".")
    .setFontSize(75, 0.9)
    .setColor(0,1,0,1)
    .setAlignment("left-center")
    .setTranslation(1, 0);
# middle alt number	
	m.alt_med = m.alt_scale_grp.createChild("text")
		.setText(".")
    .setFontSize(75, 0.9)
    .setColor(0,1,0,1)
		.setAlignment("left-center")
    .setTranslation(1, 0);
# high alt number			 
	m.alt_high = m.alt_scale_grp.createChild("text")
		.setText(".")
    .setFontSize(75, 0.9)
    .setColor(0,1,0,1)
		.setAlignment("left-center")
    .setTranslation(1, 0);

# higher alt number     
  m.alt_higher = m.alt_scale_grp.createChild("text")
    .setText(".")
    .setFontSize(75, 0.9)
    .setColor(0,1,0,1)
    .setAlignment("left-center")
    .setTranslation(1, 0);
# alt scale indicator
	m.alt_pointer = m.root.createChild("path")
    .setColor(0,1,0,1)
    .setStrokeLineWidth(w)
    .moveTo(0,0)
    .lineTo(-60,-60)
    .moveTo(0,0)
    .lineTo(-60,60)
    .setTranslation(scalePlace+indicatorOffset, 0);
# alt scale radar ground indicator
  m.rad_alt_pointer = m.alt_scale_grp.createChild("path")
    .setColor(0,1,0,1)
    .setStrokeLineWidth(w)
    .moveTo(0,0)
    .lineTo(-60,0)
    .moveTo(0,0)
    .lineTo(-30,50)
    .moveTo(-30,0)
    .lineTo(-60,50);
  
# QFE warning (inhg not properly set / is being adjusted)
  m.qfe = m.root.createChild("text");
  m.qfe.setText("QFE");
  m.qfe.setColor(0, 1, 0, 1);
  m.qfe.setAlignment("center-center");
  m.qfe.setTranslation(-450, 200);
  m.qfe.setFontSize(80, 0.9);

# Altitude number (Not shown in landing/takeoff mode. Radar at less than 100 feet)
  m.alt = m.root.createChild("text");
  m.alt.setColor(0, 1, 0, 1);
  m.alt.setAlignment("center-center");
  m.alt.setTranslation(-500, 300);
  m.alt.setFontSize(85, 0.9);

# Flightpath/Velocity vector
  m.vec_vel =
    m.root.createChild("path")
    .setColor(0,1,0,1)
    .moveTo(-90, 0) # draw this symbol in flight when no weapons selected (always as for now)
    .lineTo(-30, 0)
    .lineTo(0, 30)
    .lineTo(30, 0)
    .lineTo(90, 0)
    .setStrokeLineWidth(w);
# takeoff/landing symbol
  m.takeoff_symbol = m.root.createChild("path")
    .moveTo(210, 0)
    .lineTo(150, 0)
    .moveTo(90, 0)
    .lineTo(30, 0)
    .arcSmallCCW(30, 30, 0, -60, 0)
    .arcSmallCCW(30, 30, 0,  60, 0)
    .close()
    .moveTo(-30, 0)
    .lineTo(-90, 0)
    .moveTo(-150, 0)
    .lineTo(-210, 0)
    .setStrokeLineWidth(w)
    .setStrokeLineCap("round")
    .setColor(0,1,0, 1);

  # Horizon
    m.horizon_group = m.root.createChild("group");
    m.horizon_group2 = m.horizon_group.createChild("group");
    m.h_rot   = m.horizon_group.createTransform();

  # pitch lines
    var distance = pixelPerDegree * 5;
    for(var i = -18; i <= -1; i += 1)
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
                     .horiz(-50)
                     
                     .setStrokeLineWidth(w)
                     .setColor(0,1,0, 1);

    for(var i = 1; i <= 18; i += 1)
          m.horizon_group2.createChild("path")
                         .moveTo(650, -i * distance)
                         .horiz(-450)

                         .moveTo(-650, -i * distance)
                         .horiz(450)
                         
                         .setStrokeLineWidth(w)
                         .setColor(0,1,0, 1);

                    #pitch line numbers
                    for(var i = -18; i <= 0; i += 1)
                    m.horizon_group2.createChild("text")
                         .setText(i*5)
                         .setFontSize(75, 0.9)
                         .setAlignment("right-bottom")
                         .setTranslation(-200, -i * distance - 5)
                         .setColor(0,1,0, 1);
                    for(var i = 1; i <= 18; i += 1)
                    m.horizon_group2.createChild("text")
                         .setText("+" ~ i*5)
                         .setFontSize(75, 0.9)
                         .setAlignment("right-bottom")
                         .setTranslation(-200, -i * distance - 5)
                         .setColor(0,1,0, 1);
                 

  #Horizon line
    m.horizon = m.horizon_group2.createChild("path")
                     .moveTo(-850, 0)
                     .horiz(650)
                     .moveTo(-30, 5)#-35
                     .quadTo(-40, -5)
                     .moveTo(-100, 5)#-105
                     .quadTo(-110, -5)
                     .moveTo(-170, 5)#-175
                     .quadTo(-180, -5)
                     .moveTo(170, 5)#175
                     .quadTo(180, -5)
                     .moveTo(100, 5)#105
                     .quadTo(110, -5)
                     .moveTo(30, 5)#35
                     .quadTo(40, -5)
                     .moveTo(200, 0)
                     .horiz(650)
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
      # digital speed
      var mach = me.input.ias.getValue() * 0.0015;
      if (mach >= 0.5) 
      {
        me.airspeed.setText(sprintf("%.2f", mach));
      } else {
        me.airspeed.setText(sprintf("%03d", me.input.ias.getValue() * 0.54));
      }
            
      # heading scale
      var heading = me.input.hdg.getValue();
      var headOffset = heading/10 - int (heading/10);
      var headScaleOffset = headOffset;
      var middleText = roundabout(me.input.hdg.getValue()/10);
      if(middleText == 36) {
        middleText = 0;
      }
      var leftText = middleText == 0?35:middleText-1;
      var rightText = middleText == 35?0:middleText+1;
      if (headOffset > 0.5) {
        me.head_scale_grp_trans.setTranslation(-(headScaleOffset-1)*100, -headScalePlace);
        me.head_scale_grp.update();
        me.hdgLineL.show();
        #me.hdgLineR.hide();
      } else {
        me.head_scale_grp_trans.setTranslation(-headScaleOffset*100, -headScalePlace);
        me.head_scale_grp.update();
        me.hdgLineR.show();
        #me.hdgLineL.hide();
      }
      me.hdgR.setTranslation(100, -65);
      me.hdgR.setText(sprintf("%02d", rightText));
      me.hdgM.setTranslation(0, -65);
      me.hdgM.setText(sprintf("%02d", middleText));
      me.hdgL.setTranslation(-100, -65);
      me.hdgL.setText(sprintf("%02d", leftText));
      
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
      me.alt_pointer.setTranslation(scalePlace+indicatorOffset, 0);
      if (alt_scale_mode == 0) {
        me.alt_scale_med.hide();
        me.alt_scale_high.hide();
        me.alt_scale_low.show();
        me.alt_higher.hide();
        me.alt_high.show();
        me.alt_med.show();
        me.alt_low.show();
        var offset = altimeterScaleHeight/50 * alt;
        me.alt_scale_grp_trans.setTranslation(scalePlace , offset);
        me.alt_low.setTranslation(numberOffset, 0);
        me.alt_med.setTranslation(numberOffset, -altimeterScaleHeight);
        me.alt_high.setTranslation(numberOffset, -6*altimeterScaleHeight/4);
        me.alt_low.setText("0");
        me.alt_med.setText("50");
        me.alt_high.setText("100");
        if (radAlt < alt) {
          me.alt_scale_line.show();
        } else {
          me.alt_scale_line.hide();
        }
        # Show radar altimeter ground height
        var rad_offset = altimeterScaleHeight/50 * radAlt;
        me.rad_alt_pointer.setTranslation(indicatorOffset, rad_offset - offset);
        me.rad_alt_pointer.show();
        if (radPointerProxim < rad_offset - offset or rad_offset - offset < -radPointerProxim) {
          me.alt_pointer.show();
        } else {
          me.alt_pointer.hide();
        }
        me.alt_scale_grp.update();
        #print("alt " ~ sprintf("%3d", alt) ~ " radAlt:" ~ sprintf("%3d", radAlt) ~ " rad_offset:" ~ sprintf("%3d", rad_offset));
      } elsif (alt_scale_mode == 1) {
        me.alt_scale_med.show();
        me.alt_scale_high.hide();
        me.alt_scale_low.hide();
        me.alt_higher.hide();
        me.alt_high.show();
        me.alt_med.show();
        me.alt_low.show();
        var offset = 2*altimeterScaleHeight/100 * alt;
        me.alt_scale_grp_trans.setTranslation(scalePlace , offset);
        me.alt_low.setTranslation(numberOffset, 0);
        me.alt_med.setTranslation(numberOffset, -altimeterScaleHeight);
        me.alt_high.setTranslation(numberOffset, -altimeterScaleHeight*2);
        me.alt_low.setText("0");
        me.alt_med.setText("50");
        me.alt_high.setText("100");
        # Show radar altimeter ground height
        var rad_offset = 2*altimeterScaleHeight/100 * radAlt;
        me.rad_alt_pointer.setTranslation(indicatorOffset, rad_offset - offset);
        me.rad_alt_pointer.show();
        if (radAlt < alt) {
          me.alt_scale_line.show();
        } else {
          me.alt_scale_line.hide();
        }
        if (radPointerProxim > rad_offset - offset > -radPointerProxim) {
          me.alt_pointer.show();
        } else {
          me.alt_pointer.hide();
        }
        me.alt_scale_grp.update();
        #print("alt " ~ sprintf("%3d", alt) ~ " placing med " ~ sprintf("%3d", offset));
      } elsif (alt_scale_mode == 2) {
        me.alt_scale_med.hide();
        me.alt_scale_high.show();
        me.alt_scale_low.hide();
        me.alt_scale_line.hide();
        me.alt_higher.show();
        me.alt_high.show();
        me.alt_med.show();
        me.alt_low.show();
        var fact = int(alt / 100) * 100;
        var factor = alt - fact + 100;
        var offset = 2*altimeterScaleHeight/200 * factor;
        me.alt_scale_grp_trans.setTranslation(scalePlace , offset);
        me.alt_low.setTranslation(numberOffset , 0);
        me.alt_med.setTranslation(numberOffset , -altimeterScaleHeight);
        me.alt_high.setTranslation(numberOffset , -2*altimeterScaleHeight);
        me.alt_higher.setTranslation(numberOffset , -3*altimeterScaleHeight);
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
        # Show radar altimeter ground height
        var rad_offset = 2*altimeterScaleHeight/200 * (radAlt);
        me.rad_alt_pointer.setTranslation(scalePlace + indicatorOffset, rad_offset - offset);
        me.rad_alt_pointer.show();
        if (radPointerProxim > rad_offset - offset > -radPointerProxim) {
          me.alt_pointer.show();
        } else {
          me.alt_pointer.hide();
        }
        me.alt_scale_grp.update();
        #print("alt " ~ sprintf("%3d", alt) ~ " radAlt:" ~ sprintf("%3d", radAlt) ~ " rad_offset:" ~ sprintf("%3d", rad_offset));
      }

      # digital altitude
      if (radAlt == nil) {
        me.alt.setText("");
      } elsif (radAlt < 100) {
        me.alt.setText("R " ~ sprintf("%3d", clamp(radAlt, 0, 100)));
        # check for QFE warning
        var diff = radAlt - alt;
        if (countQFE == 0 and (diff > 10 or diff < -10)) {
          #print("QFE warning " ~ countQFE);
          countQFE = 1;          
        }
      } else {
        countQFE = 0;
        QFE = 0;
        me.alt.setText(sprintf("%4d", clamp(alt, 0, 9999)));
      }

      # display and adjust QFE
      if (countQFE > 0) {
        # QFE is shown
        if(countQFE == 1) {
          countQFE = 2;
        }
        if(countQFE < 10) {
           # blink the QFE
          if (QFE < 1 and QFE != -10) {
              me.qfe.hide();
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
            me.qfe.show();
            #print("blink  on");
          } else {
              if (QFE == -10) {
                QFE = 0;
              }
              me.qfe.show();
              QFE = QFE + 1;
              #print("blink  on");
          }
        } elsif (countQFE == 10) {
          if(me.input.ias.getValue() < 10) {
            # adjust the altimeter
            var inhg = getprop("systems/static/pressure-inhg");
            setprop("instrumentation/altimeter/setting-inhg", inhg);
            countQFE = 11;
            #print("QFE adjusted " ~ inhg);
          } else {
            countQFE = -100;
          }
        } elsif (countQFE < 70) {
          # QFE is steady
          countQFE = countQFE + 1;
          me.qfe.show();
          #print("steady on");
        } else {
          countQFE = -100;
          #print("off");
        }
      } else {
        me.qfe.hide();
        countQFE = clamp(countQFE+1, -101, 0);
        #print("hide  off");
      }
    #print("QFE count " ~ countQFE);

      # Sights/crosshairs
    if(getprop("gear/gear/position-norm") != nil and getprop("gear/gear/position-norm") == 0) {
      me.takeoff_symbol.hide();
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
   
      me.vec_vel.setTranslation(clamp(dir_x * pixelPerDegree, -450, 450), clamp(dir_y * pixelPerDegree, -450-centerOffset, 450-centerOffset)+centerOffset);
      if (dir_y > 8) {
        # blink the flight vector cross hair if alpha is high
        if (blinking < 1 and blinking != -5) {
            me.vec_vel.hide();
            blinking = blinking -1;
        } elsif (blinking > 0) {
          if (blinking == 5) {
            blinking = -1;
          } else {
            blinking = blinking + 1;
          }
          me.vec_vel.show();
        } else {
            if (blinking == -5) {
              blinking = 0;
            }
            me.vec_vel.show();
            blinking = blinking + 1;
        }
      } else {
        me.vec_vel.show();
        blinking = 0;
      }
    } else {
      me.vec_vel.hide();
      me.takeoff_symbol.show();
      
      #move takeoff/landing symbol according to side wind:
      var wind_heading = getprop("environment/wind-from-heading-deg");
      var wind_speed = getprop("environment/wind-speed-kt");
      var heading = me.input.hdg.getValue();
      #var speed = me.input.ias.getValue();
      var angle = (wind_heading -heading) * (math.pi / 180.0); 
      var wind_side = math.sin(angle) * wind_speed;
      #print((wind_heading -heading) ~ " " ~ wind_side);
      me.takeoff_symbol.setTranslation(clamp(-wind_side * 80, -450, 450), 125);
    }

    # artificial horizon and pitch lines
    me.horizon_group2.setTranslation(0, pixelPerDegree * me.input.pitch.getValue());
    me.horizon_group.setTranslation(0, centerOffset);
    var rot = -me.input.roll.getValue() * deg2rads;
    me.h_rot.setRotation(rot);


    if (getprop("fcs/fbw-override") == 1) 
     {
	     #tmp debug stuff
		   #print("HUD removed");
	   } else {
		   #print("HUD repainted");
	     settimer(func me.update(), 0);
       setprop("sim/hud/visibility[1]", 0);
	   }
  }
};
 
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