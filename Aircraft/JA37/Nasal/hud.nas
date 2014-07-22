# ==============================================================================
# Head up display
# ==============================================================================

var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }
var pow2 = func(x) { return x * x; };
var vec_length = func(x, y) { return math.sqrt(pow2(x) + pow2(y)); };
var round0 = func(x) { return math.abs(x) > 0.01 ? x : 0; };
var deg2rads = math.pi/180;

var HUDnasal = {
  canvas_settings: {
    "name": "HUDnasal",
    "size": [128, 128],#width of texture to be replaced
	"view": [1024, 1024]#width of canvas
    #"mipmapping": 0
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
        'character-size': 18,
        'character-aspect-ration': 0.9
      }
    };
 
    m.canvas.addPlacement(placement);
    #m.canvas.setColorBackground(0.36, 1, 0.3, 1);
    m.root = m.canvas.createGroup();
 
    m.root.setScale(1, 1/math.cos(25 * math.pi/180));
    m.root.setTranslation(512, 512);
 
    # Heading
    m.hdg = m.root.createChild("text");
    m.hdg._node.setValues(m.text_style);
    m.hdg.setDrawMode(3);
    m.hdg.setPadding(2);
    m.hdg.setColor(0.36, 1, 0.3);
    m.hdg.setColorFill(0.36, 1, 0.3);
    m.hdg.setAlignment("center-top");
    m.hdg.setTranslation(0, -140);
 
		var w = 6;
		var r = 0.0;
		var g = 1.0;
		var b = 0.0;
		var a = 0.65;

	# Airspeed
	# 100-220 kts scale
	m.airspeed_scale = m.root.createChild("path")
		.moveTo(-240,-290)
		.vert(10)
		.moveTo(-160,-290)
		.vert(4)
		.moveTo(-80,-290)
		.vert(4)
		.moveTo(0,-290)
		.vert(4)
		.moveTo(80,-290)
		.vert(4)
		.moveTo(160,-290)
		.vert(4)					 
		.moveTo(240,-290)
		.vert(4)
		.setStrokeLineWidth(4)
		.setColor(0,1,0, 0.65);
	# 100 kts	
	m.airspeed_100 = m.root.createChild("text")
		.setText(sprintf("%d", 1))
		.setFontSize(50, 0.9)
		.setColor(0.36, 1, 0.3)
		.setAlignment("right-center")
		.setTranslation(-160,-320);
	# 200 kts				 
	m.airspeed_200 = m.root.createChild("text")
		.setText(sprintf("%d", 2))
		.setFontSize(50, 0.9)
		.setColor(0.36, 1, 0.3)
		.setAlignment("right-center")
		.setTranslation(240,-320);

	# 300-600 kts scale
		var p = 230;
		var h = 6;
		m.airspeed_scale = m.root.createChild("path")
			.moveTo(-90, p)
			.vert(h)
			.moveTo(-30, p)
			.vert(h)
			.moveTo(30, p)
			.vert(h)
			.moveTo(90, p)
			.vert(h)
			.setStrokeLineWidth(w)
			.setStrokeLineCap("round")
			.setColor(r, g, b, a);

	m.airspeed_group = m.root.createChild("group");
	m.a_trans = m.airspeed_group.createTransform();
	m.airspeed_pointer = m.airspeed_group.createChild("path")
		.moveTo(-90, p + 2 * h)
		.vert(h)
		.setStrokeLineWidth(w)
		.setColor(r, g, b, a);

	m.Vr_group = m.root.createChild("group");
	m.Vr_trans = m.Vr_group.createTransform();
	m.Vr_pointer = m.Vr_group.createChild("path")
		.moveTo(-640,-290)
		.vert(20)
		.setStrokeLineWidth(w)
		.setColor(r, g, b, a);

	# Altitude
	# 0 - 1600 ft scale
		m.alt_scale=m.root.createChild("path")
			.moveTo(-410,240)
			.horiz(5)
			.moveTo(-410,170)
			.horiz(5)
			.moveTo(-410,110)
			.horiz(5)
			.moveTo(-410,40)
			.horiz(5)
			.moveTo(-410,-30)
			.horiz(5)					 
			.moveTo(-410,-100)
			.horiz(5)
			.moveTo(-410,-180)
			.horiz(5)					 
			.moveTo(-410,-240)
			.horiz(5)
			.setStrokeLineWidth(5)
			.setColor(0,1,0, 0.65);
# 0 ft	
		m.alt_0 = m.root.createChild("text")
			.setText(sprintf("%d", 0))
			.setFontSize(50, 0.9)
			.setColor(0.36, 1, 0.3)
			.setAlignment("right-center")
			.setTranslation(-280,250);
# 1000 ft				 
		m.alt_1000 = m.root.createChild("text")
			.setText(sprintf("%d", 10))
			.setFontSize(50, 0.9)
			.setColor(0.36, 1, 0.3)
			.setAlignment("right-center")
			.setTranslation(-230,-100);

		m.altitude_group = m.root.createChild("group");
		m.alt_trans = m.altitude_group.createTransform();
		m.alt_pointer = m.altitude_group.createChild("path")
			.moveTo(-460,240)
			.horiz(40)
			.setStrokeLineWidth(3)
			.setColor(0,1,0, 0.65);

# A/C Bore sight symbol
		m.boresight=
			m.root.createChild("path")
			.moveTo(30, 0)
			.arcSmallCCW(30, 30, 0, -60, 0)
			.arcSmallCCW(30, 30, 0,  60, 0)
			.close()
			.moveTo(-30, 0)
			.horiz(-30)
			.moveTo(30, 0)
			.horiz(30)
			.setStrokeLineWidth(2)
			.setColor(0,1,0, 0.65);

 
#    # Groundspeed
#    m.groundspeed = m.root.createChild("text");
#    m.groundspeed._node.setValues(m.text_style);
#    m.groundspeed.setColor(0.36, 1, 0.3);
#    m.groundspeed.setAlignment("left-center");
#    m.groundspeed.setTranslation(-220, 90);
 
    # Vertical speed
    m.vertical_speed = m.root.createChild("text");
    m.vertical_speed._node.setValues(m.text_style);
    m.vertical_speed.setColor(0.36, 1, 0.3);
    m.vertical_speed.setFontSize(10, 0.9);
    m.vertical_speed.setAlignment("right-center");
    m.vertical_speed.setTranslation(205, 50);
 
    # Radar altidude
    m.rad_alt = m.root.createChild("text");
    m.rad_alt._node.setValues(m.text_style);
    m.rad_alt.setColor(0.36, 1, 0.3);
    m.rad_alt.setAlignment("right-center");
    m.rad_alt.setTranslation(220, 70);
 
    # Waterline / Pitch indicator
    m.root.createChild("path")
          .moveTo(-24, 0)
          .horizTo(-8)
          .lineTo(-4, 6)
          .lineTo(0, 0)
          .lineTo(4, 6)
          .lineTo(8, 0)
          .horizTo(24)
          .setStrokeLineWidth(0.9)
          .setColor(0.36, 1, 0.3, 0.8);
 
    # Flightpath/Velocity vector
    m.vec_vel =
      m.root.createChild("path")
            .moveTo(8, 0)
            .arcSmallCCW(8, 8, 0, -16, 0)
            .arcSmallCCW(8, 8, 0,  16, 0)
            .close()
            .moveTo(-8, 0)
            .horiz(-16)
            .moveTo(8, 0)
            .horiz(16)
            .setStrokeLineWidth(0.9)
            .setColor(0.36, 1, 0.3, 0.8);
 
    # Horizon
    m.horizon_group = m.root.createChild("group");
    m.h_trans = m.horizon_group.createTransform();
    m.h_rot   = m.horizon_group.createTransform();
 
    for(var i = 5; i <= 10; i += 5)
      m.horizon_group.createChild("path")
                     .moveTo(24, -i * 18)
                     .horiz(48)
                     .vert(7)
                     .moveTo(-24, -i * 18)
                     .horiz(-48)
                     .vert(7)
                     .setStrokeLineWidth(1.5)
                     .setColor(0,1,0, 0.65);
 
    # Horizon line
    m.horizon =
      m.horizon_group.createChild("path")
                     .moveTo(-500, 0)
                     .horizTo(500)
                     .setStrokeLineWidth(1.5)
                     .setColor(0,1,0, 0.65);
 
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
      rad_alt:  "/instrumentation/radar-altimeter/radar-altitude-ft",
      wow_nlg:  "/gear/gear[0]/wow",
Vr:       "/controls/switches/HUDnasal_rotation_speed",
			Bright:   "/controls/switches/HUDnasal_brightness",
Dir_sw: "/controls/switches/HUDnasal_director", 
			H_sw:   "/controls/switches/HUDnasal_height", 
			Speed_sw:    "/controls/switches/HUDnasal_speed", 
			Test_sw:     "/controls/switches/HUDnasal_test",
			fdpitch:     "/autopilot/settings/fd-pitch-deg",
			fdroll:      "/autopilot/settings/fd-roll-deg",
			fdspeed:     "/autopilot/settings/target-speed-kt"

    };
 
    foreach(var name; keys(m.input))
      m.input[name] = props.globals.getNode(m.input[name], 1);
 
    return m;
  },
  setColorBackground: func () { 
		me.texture.getNode('background', 1).setValue(_getColor(arg)); 
		me; 
		},
  update: func()
  {
    me.airspeed_200.setText(sprintf("%d", me.input.ias.getValue()));
    
    var in_ias = me.input.ias.getValue() or 0;
    in_ias = clamp(in_ias, 300, 600);
    me.a_trans.setTranslation(0.6 * (in_ias - 300), 0);
    var in_Vr = me.input.Vr.getValue() or 0;
    me.Vr_trans.setTranslation(4 * in_Vr,0);

    me.vertical_speed.setText(sprintf("%.1f", me.input.vs.getValue() * 60.0 / 1000));
 
    var rad_alt = me.input.rad_alt.getValue();
    if( rad_alt and rad_alt < 5000 ) # Only show below 5000AGL
      rad_alt = sprintf("R %4d", rad_alt);
    else
      rad_alt = nil;
    me.rad_alt.setText(rad_alt);
 
    me.hdg.setText(sprintf("%03d", me.input.hdg.getValue()));
    
	var in_pitch = me.input.pitch.getValue() or 0;
	me.h_trans.setTranslation(0, 12.5 * in_pitch);
 
    var rot = -me.input.roll.getValue() * math.pi / 180.0;
    me.h_rot.setRotation(rot);

var bright = me.input.Bright.getValue() or 0;
			var sw_d = me.input.Dir_sw.getValue() or 0;	
			var sw_h = me.input.H_sw.getValue() or 0;
			var sw_s = me.input.Speed_sw.getValue() or 0;	
			var sw_t = me.input.Test_sw.getValue() or 0;

			var G = bright;
			var A = 0.65 * bright;
			var Gd = bright * sw_d;
			var Ad = 0.65 * bright * sw_d;
			var Gh = bright * sw_h;
			var Ah = 0.65 * bright * sw_h;
			var Gs = bright * sw_s;
			var As = 0.65 * bright * sw_s;

			me.airspeed_scale.setColor(0.0,Gs,0.0,As);		
			me.airspeed_pointer.setColor(0.0,Gs,0.0,As);	
			me.Vr_pointer.setColor(0.0,Gs,0.0,As);	
 
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
 
    var dir_y = math.atan2(round0(vel_bz), math.max(vel_bx, 0.01)) * 180.0 / math.pi;
    var dir_x  = math.atan2(round0(vel_by), math.max(vel_bx, 0.01)) * 180.0 / math.pi;
 
    me.vec_vel.setTranslation(dir_x * 18, dir_y * 18);
 
    settimer(func me.update(), 0);
  }
};
 
var init = setlistener("/sim/signals/fdm-initialized", func() {
  removelistener(init); # only call once
  var hud_pilot = HUDnasal.new({"node": "HUDobject", "texture": "hud.png"});
  print("HUD initialized.");
  hud_pilot.update();
});