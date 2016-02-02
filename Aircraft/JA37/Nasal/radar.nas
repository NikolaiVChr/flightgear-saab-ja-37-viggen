# ==============================================================================
# Radar
# ==============================================================================

var abs = func(n) { n < 0 ? -n : n }
var sgn = func(n) { n < 0 ? -1 : 1 }
var g = nil;
var pixels_max = 256;

# radar canon color
var black_r = 0.0;
var black_g = 0.2;
var black_b = 0.0;

# symbol canon color
var white_r = 0.7;
var white_g = 1.0;
var white_b = 0.7;

# background color
var green_r = 0.4;
var green_g = 0.9;
var green_b = 0.4;

var opaque = 1.0;

var radar = {
  new: func()
  {
    #print("Powering up radar...");

    var m = { parents: [radar] };
    
    # create a new canvas...
    m.canvas = canvas.new({
      "name": "RADAR",
      "size": [pixels_max, pixels_max],
      "view": [pixels_max, pixels_max],
      "mipmapping": 0
    });
    
    # cannot remember what I made this for:
    #g2 = m.canvas.createGroup();
    #g2.createChild("path")
    #            .moveTo(0,0)
    #            .lineTo(pixels_max,0)
    #            .lineTo(pixels_max,pixels_max)
    #            .lineTo(0,pixels_max)
    #            .setStrokeLineWidth((2/1024)*pixels_max)
    #            .setColor(0, 0, 0);
    #g2.show();

    # ... and place it on the object called Screen
    m.canvas.addPlacement({"node": "radarScreen", "texture": "radar-canvas.png"});
    m.canvas.setColorBackground(green_r, green_g, green_b);
    g = m.canvas.createGroup();
    
    var g_tf = g.createTransform();

    m.strokeOriginY = (975/1024) * pixels_max;
    m.strokeTopY = (200/1024) * pixels_max;
    m.strokeHeight = (m.strokeOriginY - m.strokeTopY);

    ###############
    # white lines #
    ###############

    m.lineGroup = g.createChild("group")
                   .setTranslation(pixels_max/2, m.strokeOriginY);

    # center vertical
    m.lineGroup.createChild("path")
     .moveTo(0, 0)
     .lineTo(0, -(m.strokeOriginY - m.strokeTopY))
     .close()
     .setStrokeLineWidth((8/1024)*pixels_max)
     .setColor(white_r, white_g, white_b);

    # right 30 deg vertical
    m.lineGroup.createChild("path")
     .moveTo(0, 0)
     .lineTo(m.strokeHeight * 0.5 * 0.87881711, m.strokeHeight*-0.87881711)
     .close()
     .setStrokeLineWidth((8/1024)*pixels_max)
     .setColor(white_r, white_g, white_b);
    
     #x = cos(deg)*z
     #
     #y = sin(deg)*1
     #x = cos(deg)*1
     # upper left/right y:
     #x = cos(28.5)*0.5 = cos(deg) --> 63.933849203847021529501214794585 deg --> y=0.89828732631776655536438791677979

    # left 30 deg vertical
    m.lineGroup.createChild("path")
     .moveTo(0, 0)
     .lineTo(m.strokeHeight * 0.5 * -0.87881711, m.strokeHeight*-0.87881711)
     .close()
     .setStrokeLineWidth((8/1024)*pixels_max)
     .setColor(white_r, white_g, white_b);

    # right 61.5 deg
    m.lineGroup.createChild("path")
     .moveTo(0, 0)
     .lineTo(m.strokeHeight * 0.5 * 0.87881711, m.strokeHeight * 0.5 * -0.47715876)
     .close()
     .setStrokeLineWidth((8/1024)*pixels_max)
     .setColor(white_r, white_g, white_b);
    
    # left 61.5 deg
    m.lineGroup.createChild("path")
     .moveTo(0, 0)
     .lineTo(m.strokeHeight * 0.5 * -0.87881711, m.strokeHeight * 0.5 * -0.47715876)
     .close()
     .setStrokeLineWidth((8/1024)*pixels_max)
     .setColor(white_r, white_g, white_b);

    # left vert
    m.lineGroup.createChild("path")
     .moveTo(m.strokeHeight * 0.5 * -0.87881711, m.strokeHeight * 0.5 * -0.47715876)
     .lineTo(m.strokeHeight * 0.5 * -0.87881711, m.strokeHeight * -0.8982873)
     .close()
     .setStrokeLineWidth((8/1024)*pixels_max)
     .setColor(white_r, white_g, white_b);

    # right vert
    m.lineGroup.createChild("path")
     .moveTo(m.strokeHeight * 0.5 * 0.87881711, m.strokeHeight * 0.5 * -0.47715876)
     .lineTo(m.strokeHeight * 0.5 * 0.87881711, m.strokeHeight * -0.8982873)
     .close()
     .setStrokeLineWidth((8/1024)*pixels_max)
     .setColor(white_r, white_g, white_b);

    # upper arc
    m.lineGroup.createChild("path")
               .moveTo(m.strokeHeight * 0.5 * -0.87881711, m.strokeHeight * -0.8982873)
               .arcSmallCW(m.strokeHeight, m.strokeHeight, 0,  m.strokeHeight * 0.87881711, 0)
               #.close()
               .setStrokeLineWidth((8/1024)*pixels_max)
               .setColor(white_r, white_g, white_b);


    # 66.6% arc
    # x = cos(deg) x 0.66 = cos(28.5)*0.5 --> acos((cos(28.5)*0.5)/0.66) = deg --> y = sin(deg)*0.66 = 0.5012741
    m.lineGroup.createChild("path")
               .moveTo(m.strokeHeight * 0.5 * -0.87881711, m.strokeHeight * -0.5012741)
               .arcSmallCW(m.strokeHeight*0.6666, m.strokeHeight*0.6666, 0,  m.strokeHeight * 0.87881711, 0)
               #.close()
               .setStrokeLineWidth((8/1024)*pixels_max)
               .setColor(white_r, white_g, white_b);

    # 33.3% arc
    #
    # x = cos(28.5) * 0.33 = 0.2929
    # y = sin(28.5) * 0.33 = 0.1590
    #
    m.lineGroup.createChild("path")
               .moveTo(m.strokeHeight*-0.2929, m.strokeHeight*-0.1590)
               .arcSmallCW(m.strokeHeight*0.3333, m.strokeHeight*0.3333, 0, m.strokeHeight*0.2929*2, 0)
               #.close()
               .setStrokeLineWidth((8/1024)*pixels_max)
               .setColor(white_r, white_g, white_b);

    # 16.66% arc
    #
    # x = cos(28.5) * 0.1666 = 0.1464
    # y = sin(28.5) * 0.1666 = 0.0795
    #
    m.lineGroup.createChild("path")
               .moveTo(m.strokeHeight*-0.1464, m.strokeHeight*-0.0795)
               .arcSmallCW(m.strokeHeight*0.1666, m.strokeHeight*0.1666, 0, m.strokeHeight*0.1464*2, 0)
               #.close()
               .setStrokeLineWidth((8/1024)*pixels_max)
               .setColor(white_r, white_g, white_b);

    # 8.33% arc
    #
    # x = cos(28.5) * 0.0833 = 0.0732
    # y = sin(28.5) * 0.0833 = 0.0398
    #
    m.lineGroup.createChild("path")
               .moveTo(m.strokeHeight*-0.0732, m.strokeHeight*-0.0398)
               .arcSmallCW(m.strokeHeight*0.0833, m.strokeHeight*0.0833, 0, m.strokeHeight*0.0732*2, 0)
               #.close()
               .setStrokeLineWidth((8/1024)*pixels_max)
               .setColor(white_r, white_g, white_b);

    m.stroke_angle=0; #center yaw -80 to 80 mode=2    
    m.stroke_dir = [6];
    m.no_stroke = 1; # number of strokes, including primary
    m.no_blip=50; # max number of blips
    m.radarRange=20000;# meters
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
         .setStrokeLineWidth((28/1024)*pixels_max)
         .setColor(white_r, grn, white_b));
       append(m.tfstroke, m.stroke[i].createTransform());
       m.tfstroke[i].setTranslation(pixels_max/2, m.strokeOriginY);
       m.stroke[i].hide();
     }

    m.blip = [];
    m.blip_alpha=[];
    m.tfblip=[];
    for(var i=0; i < m.no_blip; i = i+1) {
        append(m.blip,
         g.createChild("path")
         .moveTo(0, 0)
         .arcSmallCW(12/1024*pixels_max, 12/1024*pixels_max, 0, -24/1024*pixels_max, 0)
         .arcSmallCW(12/1024*pixels_max, 12/1024*pixels_max, 0,  24/1024*pixels_max, 0)
         .close()
         .setColorFill(black_r, black_g, black_b, opaque)
         .setStrokeLineWidth((2/1024)*pixels_max)
         .setColor(black_r, black_g, black_b, opaque));
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
        # AJ37 manual: 110 degrees per second: 1.0733775 x 1radian= 123 degrees. 123deg = 2.14675498 rad for full scan.
        me.stroke_angle = math.sin(dt*2.14675498)*1.0733775;
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
                var pixelX =  pixelDistance * math.cos(xa_rad + math.pi/2) + pixels_max/2;
                var pixelY =  pixelDistance * math.sin(xa_rad + math.pi/2) + me.strokeOriginY;
                #print("pixel blip ("~pixelX~", "~pixelY);
                me.tfblip[b_i].setTranslation(pixelX, pixelY); 
              } else {
                #aircraft is not near the stroke, fade it
                me.blip_alpha[b_i] = me.blip_alpha[b_i]*0.90;
              }
              me.blip[b_i].show();
              me.blip[b_i].setColor(black_r, black_g, black_b, me.blip_alpha[b_i]);
              me.blip[b_i].setColorFill(black_r, black_g, black_b, me.blip_alpha[b_i]);
              b_i=b_i+1;
          }
        }

        for (i = b_i; i < me.no_blip; i=i+1) me.blip[i].hide();
    },
};

#var calc_c_target= func(crs, trg) {
#  var diff=trg-crs;
#  if (diff>180) diff=diff-360;
#  if (diff<-180) diff=360+diff;
#  diff=7.1667*diff;
#  if (diff > 430) diff=430;
#  else if (diff < -430) diff=-430;
#  return diff;
#}

var theinit = setlistener("sim/ja37/supported/initialized", func {
  if(getprop("sim/ja37/supported/radar") == 1) {
    removelistener(theinit);
    var scope = radar.new();
    scope.update();
  }
}, 1, 0);
