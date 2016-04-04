# ==============================================================================
# Radar
# ==============================================================================

var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }

var FALSE = 0;
var TRUE  = 1;

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


var pixelXL = 0;
var pixelYL = 0;

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

    m.lineGroup = g.createChild("group")
                   .setTranslation(pixels_max/2, m.strokeOriginY);

    ##############
    # antennae   #
    ##############

    m.ant = g.createChild("path")
               .moveTo(pixels_max/2-m.strokeHeight*0.02, m.strokeTopY-m.strokeHeight*0.06)
               .lineTo(pixels_max/2+m.strokeHeight*0.02, m.strokeTopY-m.strokeHeight*0.06)
               .moveTo(pixels_max/2-m.strokeHeight*0.16, m.strokeTopY-m.strokeHeight*0.06)
               .lineTo(pixels_max/2-m.strokeHeight*0.20, m.strokeTopY-m.strokeHeight*0.06)
               .moveTo(pixels_max/2+m.strokeHeight*0.16, m.strokeTopY-m.strokeHeight*0.06)
               .lineTo(pixels_max/2+m.strokeHeight*0.20, m.strokeTopY-m.strokeHeight*0.06)
               .setStrokeLineWidth((8/1024)*pixels_max)
               .setColor(black_r, black_g, black_b);

    m.ant_cursor = g.createChild("path")
               .moveTo(pixels_max/2, m.strokeTopY-m.strokeHeight*0.03)
               .lineTo(pixels_max/2, m.strokeTopY-m.strokeHeight*0.09)
               .setStrokeLineWidth((8/1024)*pixels_max)
               .setColor(black_r, black_g, black_b);

    ##############
    # black lock #
    ##############

    m.lock = g.createChild("path")
               .moveTo(-m.strokeHeight*0.04, 0)
               .lineTo(m.strokeHeight*0.04, 0)
               .moveTo(0, -m.strokeHeight*0.04)
               .lineTo(0, m.strokeHeight*0.04)
               .setStrokeLineWidth((8/1024)*pixels_max)
               .setColor(black_r, black_g, black_b);


    #####################
    # white destination #
    #####################

    m.dest = m.lineGroup.createChild("group").hide();
    m.dest_runway = m.dest.createChild("path")
               .moveTo(0, 0)
               .lineTo(0, -50)
               .setStrokeLineWidth((8/1024)*pixels_max)
               .setColor(white_r, white_g, white_b)
               .hide();
    m.dest_circle = m.dest.createChild("path")
               .moveTo(-m.strokeHeight*0.075, 0)
               .arcSmallCW(m.strokeHeight*0.075, m.strokeHeight*0.075, 0, m.strokeHeight*0.15, 0)
               .arcSmallCW(m.strokeHeight*0.075, m.strokeHeight*0.075, 0, -m.strokeHeight*0.15, 0)
               .setStrokeLineWidth((8/1024)*pixels_max)
               .setColor(white_r, white_g, white_b);
               

    ###############
    # black lines #
    ###############

    
    # center vertical
    m.lineGroup.createChild("path")
     .moveTo(0, 0)
     .lineTo(0, -(m.strokeOriginY - m.strokeTopY))
     .close()
     .setStrokeLineWidth((8/1024)*pixels_max)
     .setColor(black_r, black_g, black_b);

    # right 30 deg vertical
    m.lineGroup.createChild("path")
     .moveTo(0, 0)
     .lineTo(m.strokeHeight * 0.5 * 0.87881711, m.strokeHeight*-0.87881711)
     .close()
     .setStrokeLineWidth((8/1024)*pixels_max)
     .setColor(black_r, black_g, black_b);
    
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
     .setColor(black_r, black_g, black_b);

    # right 61.5 deg
    m.lineGroup.createChild("path")
     .moveTo(0, 0)
     .lineTo(m.strokeHeight * 0.5 * 0.87881711, m.strokeHeight * 0.5 * -0.47715876)
     .close()
     .setStrokeLineWidth((8/1024)*pixels_max)
     .setColor(black_r, black_g, black_b);
    
    # left 61.5 deg
    m.lineGroup.createChild("path")
     .moveTo(0, 0)
     .lineTo(m.strokeHeight * 0.5 * -0.87881711, m.strokeHeight * 0.5 * -0.47715876)
     .close()
     .setStrokeLineWidth((8/1024)*pixels_max)
     .setColor(black_r, black_g, black_b);

    # left vert
    m.lineGroup.createChild("path")
     .moveTo(m.strokeHeight * 0.5 * -0.87881711, m.strokeHeight * 0.5 * -0.47715876)
     .lineTo(m.strokeHeight * 0.5 * -0.87881711, m.strokeHeight * -0.8982873)
     .close()
     .setStrokeLineWidth((8/1024)*pixels_max)
     .setColor(black_r, black_g, black_b);

    # right vert
    m.lineGroup.createChild("path")
     .moveTo(m.strokeHeight * 0.5 * 0.87881711, m.strokeHeight * 0.5 * -0.47715876)
     .lineTo(m.strokeHeight * 0.5 * 0.87881711, m.strokeHeight * -0.8982873)
     .close()
     .setStrokeLineWidth((8/1024)*pixels_max)
     .setColor(black_r, black_g, black_b);

    # upper arc
    m.lineGroup.createChild("path")
               .moveTo(m.strokeHeight * 0.5 * -0.87881711, m.strokeHeight * -0.8982873)
               .arcSmallCW(m.strokeHeight, m.strokeHeight, 0,  m.strokeHeight * 0.87881711, 0)
               #.close()
               .setStrokeLineWidth((8/1024)*pixels_max)
               .setColor(black_r, black_g, black_b);


    # 66.6% arc
    # x = cos(deg) x 0.66 = cos(28.5)*0.5 --> acos((cos(28.5)*0.5)/0.66) = deg --> y = sin(deg)*0.66 = 0.5012741
    m.lineGroup.createChild("path")
               .moveTo(m.strokeHeight * 0.5 * -0.87881711, m.strokeHeight * -0.5012741)
               .arcSmallCW(m.strokeHeight*0.6666, m.strokeHeight*0.6666, 0,  m.strokeHeight * 0.87881711, 0)
               #.close()
               .setStrokeLineWidth((8/1024)*pixels_max)
               .setColor(black_r, black_g, black_b);

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
               .setColor(black_r, black_g, black_b);

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
               .setColor(black_r, black_g, black_b);

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
               .setColor(black_r, black_g, black_b);

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
         .moveTo(12/1024*pixels_max, 0)
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

      # draw destination
      #var freq = getprop("instrumentation/nav/frequencies/selected-mhz");
      #if (freq != nil) {
      #  var navaid = findNavaidByFrequency(freq);
      #  if(navaid != nil) print(navaid.type);
      #  if(navaid != nil and navaid.type == "runway") {
      #    print("id "~navaid.id);
      #    print("name "~navaid.name);
      #    var icao = navaid.id;
          #var airport = airportinfo(icao);
          #if (airport != nil) {

          #}
      #  }
      #}
      if (getprop("autopilot/route-manager/active") == TRUE) {
        var dist = getprop("autopilot/route-manager/wp/dist");        
        var bearing = getprop("autopilot/route-manager/wp/true-bearing-deg");#true
        var heading = getprop("instrumentation/heading-indicator/indicated-heading-deg");#true
        if (dist != nil and bearing != nil and heading != nil) {
          var bug = bearing - heading;

          var x = math.cos(-(bug-90) * D2R) * (dist/(me.radarRange * M2NM)) * me.strokeHeight;
          var y = math.sin(-(bug-90) * D2R) * (dist/(me.radarRange * M2NM)) * me.strokeHeight;

          me.dest.setTranslation(x, -y);

          me.dest.show();

          var name = getprop("autopilot/route-manager/wp/id");
          if (name != nil and size(split("-", name))>1) {
            #print(name~"="~dist~" "~me.strokeHeight~" "~(me.radarRange * M2NM));
            name = split("-", name);
            var icao = name[0];
            name = name[1];
            name = split("C", split("L", split("R", name)[0])[0])[0];
            name = num(name);
            if (name != nil and size(icao) == 4) {
              var head = 10 * name;
              # 10 20 20 40 Km long line, depending on radar setting, as per manual.
              var runway_l = 10000;
              if (me.radarRange == 120000 or me.radarRange == 180000) {
                runway_l = 40000;
              } elsif (me.radarRange == 60000) {
                runway_l = 20000;
              } elsif (me.radarRange == 30000) {
                runway_l = 20000;
              }
              var scale = (runway_l/me.radarRange) * me.strokeHeight/50;
              me.dest_runway.setScale(1, scale);
              me.dest.setRotation((180+head-heading)*D2R);
              me.dest_runway.show();
              } else {
                me.dest_runway.hide();
              }
          } else {
            me.dest_runway.hide();
          }
        } else {
          me.dest.hide();
        }
      } else {
        me.dest.hide();
      }


      # show antanea height
      var a2a = canvas_HUD.air2air;
      if (a2a == TRUE) {
        if (radar_logic.selection != nil) {
          var elev = radar_logic.selection.getElevation();
          elev = clamp(elev, -10, 10)/10;
          var x = me.strokeHeight*0.18*elev;
          me.ant_cursor.setTranslation(x, 0);
          me.ant_cursor.show();
        } else {
          me.ant_cursor.hide();
        }
        me.ant.show();
      } else {
        me.ant_cursor.hide();
        me.ant.hide();
      }
    
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
        var lock = FALSE;
        foreach (var mp; radar_logic.tracks) {
          # Node with valid position data (and "distance!=nil").

          var distance = mp.get_polar()[0];
          var xa_rad = mp.get_polar()[1];

          #make blip
          if (b_i < me.no_blip and distance != nil and distance < me.radarRange ){#and alt-100 > getprop("/environment/ground-elevation-m")){
              #aircraft is within the radar ray cone
              var locked = FALSE;
              if (mp.isPainted() == TRUE) {
                lock = TRUE;
                locked = TRUE;
              }
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
                if (locked == TRUE) {
                  pixelXL = pixelX;
                  pixelYL = pixelY;
                }
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
        if (lock == FALSE) {
          me.lock.hide();
        } else {
          me.lock.setTranslation(pixelXL, pixelYL);
          me.lock.show();
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
