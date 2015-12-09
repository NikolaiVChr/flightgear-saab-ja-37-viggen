# ==============================================================================
# Radar
# ==============================================================================

var abs = func(n) { n < 0 ? -n : n }
var sgn = func(n) { n < 0 ? -1 : 1 }
var g = nil;

var radar = {
  new: func()
  {
    #print("Powering up radar...");

    var m = { parents: [radar] };
    
    # create a new canvas...
    m.canvas = canvas.new({
      "name": "RADAR",
      "size": [1024, 1024],
      "view": [1024, 1024],
      "mipmapping": 0
    });
    
    g2 = m.canvas.createGroup();
    g2.createChild("path")
                .moveTo(0,0)
                .lineTo(1024,0)
                .lineTo(1024,1024)
                .lineTo(0,1024)
                .setStrokeLineWidth(2)
                .setColor(0, 0, 0);
    g2.show();

    # ... and place it on the object called Screen
    m.canvas.addPlacement({"node": "radarScreen", "texture": "radar-canvas.png"});
    m.canvas.setColorBackground(0.10,0.20,0.10);
    g = m.canvas.createGroup();
    
    var g_tf = g.createTransform();

    m.oldmode=0;
    m.glide_pos=1000; #Actual position
    m.course_pos=1000; #Actual position
    m.glide_target=1000; #Target position
    m.course_target=1000; #Target position
    m.stroke_mode=120;
    m.antenna_pitch=0;
    m.stroke_angle=0; #center yaw -80 to 80 mode=2    
    m.stroke_dir = [6];
    m.no_stroke = 9;
    m.no_blip=50;
    m.radarRange=20000;#feet?
    m.strokeOriginY = 975;
    m.strokeTopY = 100;
    m.stroke_pos= [];

    

    for(var i=0; i < m.no_stroke; i = i+1) {
      append(m.stroke_pos, 0);
    }
    for(var i=0; i < m.no_stroke; i = i+1) {
      append(m.stroke_dir, 0);
    }

    m.stroke = [];
    m.tfstroke=[];
    for(var i=0; i < m.no_stroke; i = i+1) {
        # var grn = 0.2 + (0.8 / m.no_stroke)*(i+1);
        var grn = 0.15+((m.no_stroke / ((m.no_stroke+0.0001)-(i)))/m.no_stroke)*0.85;
        append(m.stroke,
         g.createChild("path")
         #.setStrokeLineCap("butt")
         .moveTo(0, 0)
         .lineTo(0, -(m.strokeOriginY-m.strokeTopY))
         .close()
         .setStrokeLineWidth(28)
         .setColor(0.1, grn, 0.1));
       append(m.tfstroke, m.stroke[i].createTransform());
       m.tfstroke[i].setTranslation(512, m.strokeOriginY);
       m.stroke[i].hide();
     }

    m.blip = [];
    m.blip_alpha=[];
    m.tfblip=[];
    for(var i=0; i < m.no_blip; i = i+1) {
        append(m.blip,
         g.createChild("path")
         .moveTo(0, 0)
         .arcSmallCW(12, 12, 0, -24, 0)
         .arcSmallCW(12, 12, 0,  24, 0)
         .close()
         .setColorFill(0.0,1.0,0.0, 1.0)
         .setStrokeLineWidth(2)
         .setColor(0.0,1.0,0.0, 1.0));
       append(m.tfblip, m.blip[i].createTransform());
       m.tfblip[i].setTranslation(0, 0);
       m.blip[i].hide();
       append(m.blip_alpha, 1);
     }
     

    #m.scale=g.createChild("image")
     #        .setFile("Models/Instruments/Radar/scale.png")
      #       .setSourceRect(0,0,1,1)
       #      .setSize(1024,1024)
        #     .setTranslation(0,0);

    m.input = {
      viewNumber:     "sim/current-view/view-number",
      radarVoltage:   "systems/electrical/outputs/ac-main-voltage",
      radarScreenVoltage:   "systems/electrical/outputs/dc-voltage",
      radarServ:      "instrumentation/radar/serviceable",
      screenEnabled:  "sim/ja37/radar/enabled",
      radarEnabled:   "sim/ja37/hud/tracks-enabled",
      radarRange:     "instrumentation/radar/range",
      timeElapsed:    "sim/time/elapsed-sec",
      hydrPressure:   "fdm/jsbsim/systems/hydraulics/system1/pressure",
    };

    # setup property nodes for the loop
    foreach(var name; keys(m.input)) {
        m.input[name] = props.globals.getNode(m.input[name], 1);
    }

    return m;
  },


  update: func()
  {
  #Modes 0=Off, 1=Autoscan, 2=Manual, 5=Course guide, 6=Course and glide
    var rmode=1;#getprop("instrumentation/radar/mode");
    if ((me.input.viewNumber.getValue() == 0 or me.input.viewNumber.getValue() == 13) and me.input.radarVoltage.getValue() != nil
        and me.input.radarScreenVoltage.getValue() > 23 and me.input.radarVoltage.getValue() > 170
        and me.input.radarServ.getValue() > 0 and me.input.screenEnabled.getValue() == 1 and me.input.radarEnabled.getValue() == 1) {
      g.show();
      me.radarRange = me.input.radarRange.getValue();
      
      var dt = me.input.timeElapsed.getValue();
      
      #Stroke animation
      if (dt == nil) {
        dt = 5;
      }            
      # compute new stroke angle if has hydr pressure
      if(me.input.hydrPressure.getValue() == 1) {
        me.stroke_angle = math.sin(dt);
        forindex (i; me.stroke) me.stroke[i].show();
      } else {
        forindex (i; me.stroke) me.stroke[i].hide();
      }
      #convert to radians
      var curr_angle = me.stroke_angle;# * 0.0175; 
      # animate fading stroke angles
      for(var i=0; i < me.no_stroke-1; i = i+1) {
        me.tfstroke[i].setRotation(me.stroke_dir[i+1]);
        #print("dir "~i~" = "~me.stroke_dir[i+1]);
        me.stroke_dir[i] = me.stroke_dir[i+1];
      }
      #animate the stroke
      me.tfstroke[me.no_stroke-1].setRotation(curr_angle);
      #print("dir 5 = "~curr_angle);
      var prev_angle = me.stroke_dir[me.no_stroke-1];
      me.stroke_dir[me.no_stroke-1] = curr_angle;

      #Update blips
      me.update_blip(curr_angle, prev_angle);
    
      settimer(
        #func debug.benchmark("rad loop", 
          func me.update()
       #   )
        , 0.05);
    } else {
      g.hide();
      settimer(func me.update(), 1);
    }
  },
  
  update_blip: func(curr_angle, prev_angle) {
        var b_i=0;

        foreach (var mp; radar_logic.tracks) {
          # Node with valid position data (and "distance!=nil").

          # mp
          #
          # 0 - x position
          # 1 - y position
          # 2 - direct distance in meter
          # 3 - distance in radar screen plane
          # 4 - horizontal angle from aircraft in rad
          # 5 - identifier
          # 6 - node
          # 7 - carrier

          var distance = mp[3];
          var xa_rad = mp[4];

          #make blip
          if (b_i < me.no_blip and distance != nil and distance < me.radarRange ){#and alt-100 > getprop("/environment/ground-elevation-m")){
              #aircraft is within the radar ray cone
              
              if(curr_angle < prev_angle) {
                var crr_angle = curr_angle;
                curr_angle = prev_angle;
                prev_angle = crr_angle;
              }
              if (xa_rad > prev_angle and xa_rad < curr_angle) {
                #aircraft is between the current stroke and the previous stroke position
                me.blip_alpha[b_i]=1;
                # plot the blip on the radar screen
                var pixelDistance = -distance*((me.strokeOriginY-me.strokeTopY)/me.radarRange); #distance in pixels
                
                #translate from polar coords to cartesian coords
                var pixelX =  pixelDistance * math.cos(xa_rad + math.pi/2) + 512;
                var pixelY =  pixelDistance * math.sin(xa_rad + math.pi/2) + me.strokeOriginY;
                #print("pixel blip ("~pixelX~", "~pixelY);
                me.tfblip[b_i].setTranslation(pixelX, pixelY); 
              } else {
                #aircraft is not near the stroke, fade it
                me.blip_alpha[b_i] = me.blip_alpha[b_i]*0.96;
              }
              me.blip[b_i].show();
              me.blip[b_i].setColor(0.0,1.0,0.0, me.blip_alpha[b_i]);
              me.blip[b_i].setColorFill(0.0,1.0,0.0, me.blip_alpha[b_i]);
              b_i=b_i+1;
          }
        }

        for (i = b_i; i < me.no_blip; i=i+1) me.blip[i].hide();
    },
};

var calc_c_target= func(crs, trg) {
  var diff=trg-crs;
  if (diff>180) diff=diff-360;
  if (diff<-180) diff=360+diff;
  diff=7.1667*diff;
  if (diff > 430) diff=430;
  else if (diff < -430) diff=-430;
  return diff;
}

var theinit = setlistener("sim/ja37/supported/initialized", func {
  if(getprop("sim/ja37/supported/radar") == 1) {
    removelistener(theinit);
    var scope = radar.new();
    scope.update();
  }
}, 1, 0);
