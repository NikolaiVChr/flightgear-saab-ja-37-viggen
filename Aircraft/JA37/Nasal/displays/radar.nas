# ==============================================================================
# Radar
# ==============================================================================

var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }

var FALSE = 0;
var TRUE  = 1;

var abs = func(n) { n < 0 ? -n : n }
var sgn = func(n) { n < 0 ? -1 : 1 }
var g = nil;
var pixels_max = 512;

# radar canon color
var black_r = 0.0;
var black_g = 0.2;
var black_b = 0.0;

# symbol canon color
var white_r = 0.7;
var white_g = 1.0;
var white_b = 0.7;

# background color
var green_r = 0.2;
var green_g = 0.65;
var green_b = 0.2;

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
    m.canvas.set("font", "LiberationFonts/LiberationMono-Regular.ttf");
    g = m.canvas.createGroup();
    
    var g_tf = g.createTransform();

    m.strokeOriginY = (900/1024) * pixels_max;
    m.strokeTopY = (150/1024) * pixels_max;
    m.strokeHeight = (m.strokeOriginY - m.strokeTopY);

    m.lineGroup = g.createChild("group")
                   .setTranslation(pixels_max/2, m.strokeOriginY)
                   .set("z-index", 4);
    m.horzGroup = g.createChild("group")
                   .setTranslation(pixels_max/2, pixels_max/2)
                   .set("z-index", 5);

    ##############################
    # white artificial horizon   #
    ##############################

    m.horzLines = m.horzGroup.createChild("path")
               .moveTo(-(50/1024)*pixels_max, 0)
               .lineTo(-(512/1024)*pixels_max, 0)
               .moveTo((50/1024)*pixels_max, 0)
               .lineTo((512/1024)*pixels_max, 0)
               .setStrokeLineWidth((8/1024)*pixels_max)
               .setColor(white_r, white_g, white_b)
               .set("z-index", 5);

    m.horzRef = g.createChild("path")
               .moveTo(pixels_max/2-(25/1024)*pixels_max, pixels_max/2-(16/1024)*pixels_max)
               .lineTo(pixels_max/2-(75/1024)*pixels_max, pixels_max/2-(16/1024)*pixels_max)
               .moveTo(pixels_max/2+(25/1024)*pixels_max, pixels_max/2-(16/1024)*pixels_max)
               .lineTo(pixels_max/2+(75/1024)*pixels_max, pixels_max/2-(16/1024)*pixels_max)
               .setStrokeLineWidth((8/1024)*pixels_max)
               .setColor(white_r, white_g, white_b)
               .set("z-index", 5);

    m.desired_lines3 = m.horzGroup.createChild("path")
               .moveTo(-(375/1024)*pixels_max, 0)
               .lineTo(-(375/1024)*pixels_max, (100/1024)*pixels_max)
               .moveTo((375/1024)*pixels_max, 0)
               .lineTo((375/1024)*pixels_max, (100/1024)*pixels_max)
               .setStrokeLineWidth((8/1024)*pixels_max)
               .setColor(white_r, white_g, white_b)
               .set("z-index", 5);

    # altitude boxes
    m.desired_boxes = m.horzGroup.createChild("path")
                     .moveTo(-(380/1024)*pixels_max, 0)
                     .vert((50/1024)*pixels_max)
                     .horiz((10/1024)*pixels_max)
                     .vert(-(50/1024)*pixels_max)
                     .horiz(-(10/1024)*pixels_max)
                     .moveTo((380/1024)*pixels_max, 0)
                     .vert((50/1024)*pixels_max)
                     .horiz(-(10/1024)*pixels_max)
                     .vert(-(50/1024)*pixels_max)
                     .horiz((10/1024)*pixels_max)
                     .setStrokeLineWidth((8/1024)*pixels_max)
                     .setColor(white_r, white_g, white_b)
                     .set("z-index", 5);

    ####################
    # black antennae   #
    ####################

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
               .setColor(black_r, black_g, black_b)
               .set("z-index", 10);


    #####################
    # white destination #
    #####################

    m.dest = g.createChild("group")
                .hide()
                .set("z-index", 8);
    m.dest_runway = m.dest.createChild("path")
               .moveTo(0, 0)
               .lineTo(0, -50)
               .setStrokeLineWidth((8/1024)*pixels_max)
               .setColor(white_r, white_g, white_b)
               .hide()
               .set("z-index", 8);
    m.dest_circle = m.dest.createChild("path")
               .moveTo(-m.strokeHeight*0.075, 0)
               .arcSmallCW(m.strokeHeight*0.075, m.strokeHeight*0.075, 0, m.strokeHeight*0.15, 0)
               .arcSmallCW(m.strokeHeight*0.075, m.strokeHeight*0.075, 0, -m.strokeHeight*0.15, 0)
               .setStrokeLineWidth((8/1024)*pixels_max)
               .setColor(white_r, white_g, white_b)
               .set("z-index", 8);
    m.approach_circle = g.createChild("path")
               .moveTo(-150, 0)
               .arcSmallCW(150, 150, 0, 300, 0)
               .arcSmallCW(150, 150, 0, -300, 0)
               .setStrokeLineWidth((16/1024)*pixels_max)
               .setColor(white_r, white_g, white_b)
               .set("z-index", 8);
               

    ###############
    # black lines #
    ###############

    
    # center vertical
    m.lineGroup.createChild("path")
     .moveTo(0, 0)
     .lineTo(0, -(m.strokeOriginY - m.strokeTopY))
     .close()
     .setStrokeLineWidth((8/1024)*pixels_max)
     .setColor(black_r, black_g, black_b)
     .set("z-index", 4);

    # right 30 deg vertical
    m.lineGroup.createChild("path")
     .moveTo(0, 0)
     .lineTo(m.strokeHeight * 0.5 * 0.87881711, m.strokeHeight*-0.87881711)
     .close()
     .setStrokeLineWidth((8/1024)*pixels_max)
     .setColor(black_r, black_g, black_b)
     .set("z-index", 4);
    
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
     .setColor(black_r, black_g, black_b)
     .set("z-index", 4);

    # right 61.5 deg
    m.lineGroup.createChild("path")
     .moveTo(0, 0)
     .lineTo(m.strokeHeight * 0.5 * 0.87881711, m.strokeHeight * 0.5 * -0.47715876)
     .close()
     .setStrokeLineWidth((8/1024)*pixels_max)
     .setColor(black_r, black_g, black_b)
     .set("z-index", 4);
    
    # left 61.5 deg
    m.lineGroup.createChild("path")
     .moveTo(0, 0)
     .lineTo(m.strokeHeight * 0.5 * -0.87881711, m.strokeHeight * 0.5 * -0.47715876)
     .close()
     .setStrokeLineWidth((8/1024)*pixels_max)
     .setColor(black_r, black_g, black_b)
     .set("z-index", 4);

    # left vert
    m.lineGroup.createChild("path")
     .moveTo(m.strokeHeight * 0.5 * -0.87881711, m.strokeHeight * 0.5 * -0.47715876)
     .lineTo(m.strokeHeight * 0.5 * -0.87881711, m.strokeHeight * -0.8982873)
     .close()
     .setStrokeLineWidth((8/1024)*pixels_max)
     .setColor(black_r, black_g, black_b)
     .set("z-index", 4);

    # right vert
    m.lineGroup.createChild("path")
     .moveTo(m.strokeHeight * 0.5 * 0.87881711, m.strokeHeight * 0.5 * -0.47715876)
     .lineTo(m.strokeHeight * 0.5 * 0.87881711, m.strokeHeight * -0.8982873)
     .close()
     .setStrokeLineWidth((8/1024)*pixels_max)
     .setColor(black_r, black_g, black_b)
     .set("z-index", 4);

    # range text
    m.rangeText = m.lineGroup.createChild("text")
      .setText("120")
      .setAlignment("center-center")
      .setFontSize((64/1024)*pixels_max, 1.0)
      .setTranslation((280/1024)*pixels_max, (-80/1024)*pixels_max)
      .setColor(black_r, black_g, black_b)
      .set("z-index", 4);

    # upper arc
    m.lineGroup.createChild("path")
               .moveTo(m.strokeHeight * 0.5 * -0.87881711, m.strokeHeight * -0.8982873)
               .arcSmallCW(m.strokeHeight, m.strokeHeight, 0,  m.strokeHeight * 0.87881711, 0)
               #.close()
               .setStrokeLineWidth((8/1024)*pixels_max)
               .setColor(black_r, black_g, black_b)
               .set("z-index", 4);


    # 66.6% arc
    # x = cos(deg) x 0.66 = cos(28.5)*0.5 --> acos((cos(28.5)*0.5)/0.66) = deg --> y = sin(deg)*0.66 = 0.5012741
    m.lineGroup.createChild("path")
               .moveTo(m.strokeHeight * 0.5 * -0.87881711, m.strokeHeight * -0.5012741)
               .arcSmallCW(m.strokeHeight*0.6666, m.strokeHeight*0.6666, 0,  m.strokeHeight * 0.87881711, 0)
               #.close()
               .setStrokeLineWidth((8/1024)*pixels_max)
               .setColor(black_r, black_g, black_b)
               .set("z-index", 4);

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
               .setColor(black_r, black_g, black_b)
               .set("z-index", 4);

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
               .setColor(black_r, black_g, black_b)
               .set("z-index", 4);

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
               .setColor(black_r, black_g, black_b)
               .set("z-index", 4);

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
         .setColor(white_r, grn, white_b)
         .set("z-index", 3));
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
         .setColor(black_r, black_g, black_b, opaque)
         .set("z-index", 9));
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
      alt_ft:               "instrumentation/altimeter/indicated-altitude-ft",
      APmode:               "fdm/jsbsim/autoflight/mode",
      #APTgtAgl:             "autopilot/settings/target-agl-ft",
      APTgtAlt:             "fdm/jsbsim/autoflight/pitch/alt/target",
      heading:              "instrumentation/heading-indicator/indicated-heading-deg",
      rad_alt:              "instrumentation/radar-altimeter/radar-altitude-ft",
      rad_alt_ready:        "instrumentation/radar-altimeter/ready",
      radarEnabled:         "ja37/hud/tracks-enabled",
      radarRange:           "instrumentation/radar/range",
      radarServ:            "instrumentation/radar/serviceable",
      rmActive:             "autopilot/route-manager/active",
      rmDist:               "autopilot/route-manager/wp/dist",
      rmId:                 "autopilot/route-manager/wp/id",
      rmTrueBearing:        "autopilot/route-manager/wp/true-bearing-deg",
      RMCurrWaypoint:       "autopilot/route-manager/current-wp",
      roll:                 "instrumentation/attitude-indicator/indicated-roll-deg",
      screenEnabled:        "ja37/radar/enabled",
      timeElapsed:          "sim/time/elapsed-sec",
      viewNumber:           "sim/current-view/view-number",
      headTrue:             "orientation/heading-deg",
      headMagn:             "orientation/heading-magnetic-deg",
      twoHz:                "ja37/blink/two-Hz/state",
    };

    # setup property nodes for the loop
    foreach(var name; keys(m.input)) {
        m.input[name] = props.globals.getNode(m.input[name], 1);
    }

    return m;
  },


  update: func()
  {
    if ((me.input.viewNumber.getValue() == 0 or me.input.viewNumber.getValue() == 13) and power.prop.acSecond.getValue()
        and me.input.radarServ.getValue() > 0 and me.input.screenEnabled.getValue() == 1 and me.input.radarEnabled.getValue() == 1 and testing.ongoing == FALSE
        and getprop("ja37/radar/active") == TRUE) {
      g.show();
      me.radarRange = me.input.radarRange.getValue();
      me.rangeText.setText(sprintf("%3d",me.radarRange/1000));
      me.dt = me.input.timeElapsed.getValue();
      
      #Stroke animation
      if (me.dt == nil) {
        me.dt = 5;
      }            
      # compute new stroke angle if has hydr pressure
      if(power.prop.hyd1Bool.getValue()) {
        # AJ37 manual: 110 degrees per second: 1.0733775 x 1radian= 123 degrees. 123deg = 2.14675498 rad for full scan.
        me.stroke_angle = math.sin(me.dt*2.14675498)*1.0733775;
        forindex (i; me.stroke) me.stroke[i].show();
      } else {
        forindex (i; me.stroke) me.stroke[i].hide();
      }
      #convert to radians
      me.curr_angle = me.stroke_angle;# * 0.0175; 
      # animate fading stroke angles
      for(var i=0; i < me.no_stroke-1; i = i+1) {
        me.tfstroke[i].setRotation(me.stroke_dir[i+1]);
        #print("dir "~i~" = "~me.stroke_dir[i+1]);
        me.stroke_dir[i] = me.stroke_dir[i+1];
      }
      #animate the stroke
      me.tfstroke[me.no_stroke-1].setRotation(me.curr_angle);
      #print("dir 5 = "~curr_angle);
      me.prev_angle = me.stroke_dir[me.no_stroke-1];
      me.stroke_dir[me.no_stroke-1] = me.curr_angle;

      #Update blips
      me.update_blip(me.curr_angle, me.prev_angle);

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

      
      if (land.show_waypoint_circle == TRUE or land.show_runway_line == TRUE) {
          me.x = math.cos(-(land.runway_bug-90) * D2R) * (land.runway_dist/(me.radarRange * M2NM)) * me.strokeHeight;
          me.y = math.sin(-(land.runway_bug-90) * D2R) * (land.runway_dist/(me.radarRange * M2NM)) * me.strokeHeight;

          me.dest.setTranslation(pixels_max/2+me.x, me.strokeOriginY-me.y);
          

          if (land.show_waypoint_circle == TRUE) {
              me.dest_circle.show();
          } else {
              me.dest_circle.hide();
          }

          if (land.show_runway_line == TRUE) {
            # 10 20 20 40 Km long line, depending on radar setting, as per AJ manual.
            me.runway_l = land.line*1000;
    #        if (me.radarRange == 120000 or me.radarRange == 180000) {
    #          me.runway_l = 40000;
    #        } elsif (me.radarRange == 60000) {
    #          me.runway_l = 20000;
    #        } elsif (me.radarRange == 30000) {
    #          me.runway_l = 20000;
    #        }
            me.scale = (me.runway_l/me.radarRange) * me.strokeHeight/50;
            me.dest_runway.setScale(1, me.scale);
            me.heading = me.input.heading.getValue();#true
            me.dest.setRotation((180+land.head-me.heading)*D2R);
            me.dest_runway.show();
            if (land.show_approach_circle == TRUE) {
              me.scale = (4100/me.radarRange) * me.strokeHeight/150;
              me.approach_circle.setStrokeLineWidth(((8/me.scale)/1024)*pixels_max);
              me.approach_circle.setScale(me.scale);
              me.acir = radar_logic.ContactGPS.new("circle", land.approach_circle);
              me.distance = me.acir.get_polar()[0];
              me.xa_rad   = me.acir.get_polar()[1];
              me.pixelDistance = -me.distance*((me.strokeOriginY-me.strokeTopY)/me.radarRange); #distance in pixels
              #translate from polar coords to cartesian coords
              me.pixelX =  me.pixelDistance * math.cos(me.xa_rad + math.pi/2) + pixels_max/2;
              me.pixelY =  me.pixelDistance * math.sin(me.xa_rad + math.pi/2) + me.strokeOriginY;
              me.approach_circle.setTranslation(me.pixelX, me.pixelY);
              me.approach_circle.show();
            } else {
              me.approach_circle.hide();#pitch.......1x.......................................................
            }            
          } else {
            me.dest_runway.hide();
            me.approach_circle.hide();
          }
          me.dest.show();
      } else {
        me.dest_circle.hide();
        me.dest_runway.hide();
        me.approach_circle.hide();
      }
      
      


      # show antanea height
      if (canvas_HUD.air2air == TRUE) {
        if (radar_logic.selection != nil) {
          me.elev = radar_logic.selection.getElevation();
          me.elev = clamp(me.elev, -10, 10)/10;
          me.xx = me.strokeHeight*0.18*me.elev;
          me.ant_cursor.setTranslation(me.xx, 0);
          me.ant_cursor.show();
        } else {
          me.ant_cursor.hide();
        }
        me.ant.show();
      } else {
        me.ant_cursor.hide();
        me.ant.hide();
      }
    
      # show horizon lines
      me.horzGroup.setRotation(-me.input.roll.getValue()*D2R);
      me.showBoxes = FALSE;
      me.showLines = TRUE;
      me.desired_alt_delta_ft = nil;
      if(canvas_HUD.mode == canvas_HUD.TAKEOFF) {
        me.desired_alt_delta_ft = (500*M2FT)-me.input.alt_ft.getValue();
      } elsif (me.input.APmode.getValue() == 3 and me.input.APTgtAlt.getValue() != nil) {
        me.desired_alt_delta_ft = me.input.APTgtAlt.getValue()-me.input.alt_ft.getValue();
        me.showBoxes = TRUE;
        if (me.input.alt_ft.getValue() * FT2M > 1000) {
          me.showLines = FALSE;
        }
      } elsif(canvas_HUD.mode == canvas_HUD.LANDING and land.mode < 3 and land.mode > 0) {
        me.desired_alt_delta_ft = (500*M2FT)-me.input.alt_ft.getValue();
      #} elsif (me.input.APLockAlt.getValue() == "agl-hold" and me.input.APTgtAgl.getValue() != nil) {
      #  me.desired_alt_delta_ft = me.input.APTgtAgl.getValue()-me.input.rad_alt.getValue();
      } elsif(me.input.rmActive.getValue() == 1 and me.input.RMCurrWaypoint.getValue() != nil and me.input.RMCurrWaypoint.getValue() >= 0) {
        me.i = me.input.RMCurrWaypoint.getValue();
        me.rt_alt = getprop("autopilot/route-manager/route/wp["~me.i~"]/altitude-ft");
        if(me.rt_alt != nil and me.rt_alt > 0) {
          me.desired_alt_delta_ft = me.rt_alt - me.input.alt_ft.getValue();
        }
      }# elsif (getprop("autopilot/locks/altitude") == "gs1-hold") {
      if(me.desired_alt_delta_ft != nil) {
        me.pos_y = clamp(-(me.desired_alt_delta_ft*FT2M)/10, -(50/1024)*pixels_max, (100/1024)*pixels_max);#500 m up, 1000 m down

        me.desired_lines3.setTranslation(0, me.pos_y);
        me.desired_boxes.setTranslation(0, me.pos_y);
        if (me.showLines == TRUE) {
          me.desired_lines3.show();
        } else {
          me.desired_lines3.hide();
        }
        if (me.showBoxes == TRUE and (getprop("fdm/jsbsim/systems/indicators/flashing-alt-bars") == FALSE or me.input.twoHz.getValue())) {
          me.desired_boxes.show();
        } else {
          me.desired_boxes.hide();
        }
      } else {
        me.desired_lines3.hide();
        me.desired_boxes.hide();
      }




      #settimer(
        #func debug.benchmark("rad loop", 
      #    func me.update()
       #   )
      #  , 0.05);
    } else {
      g.hide();
      #settimer(func me.update(), 1);
    }
  },
  
  update_blip: func(curr_angle, prev_angle) {
        me.b_i=0;
        me.anyLock = FALSE;
        me.currSelect = radar_logic.selection != nil?radar_logic.selection.getUnique():-1;
        foreach (var mp; radar_logic.tracks) {
          # Node with valid position data (and "distance!=nil").

          me.distance = mp.get_polar()[0];
          me.xa_rad = mp.get_polar()[1];

          #make blip
          if (me.b_i < me.no_blip and me.distance != nil and me.distance < me.radarRange ){#and alt-100 > getprop("/environment/ground-elevation-m")){
              #aircraft is within the radar ray cone
              me.locked = FALSE;
              if (mp.getUnique() == me.currSelect) {
                me.anyLock = TRUE;
                me.locked = TRUE;
              }
              if(curr_angle < prev_angle) {
                me.crr_angle = curr_angle;
                curr_angle = prev_angle;
                prev_angle = me.crr_angle;
              }
              if (me.xa_rad > prev_angle and me.xa_rad < curr_angle) {
                #aircraft is between the current stroke and the previous stroke position
                me.blip_alpha[me.b_i]=1;
                # plot the blip on the radar screen
                me.pixelDistance = -me.distance*((me.strokeOriginY-me.strokeTopY)/me.radarRange); #distance in pixels
                
                #translate from polar coords to cartesian coords
                me.pixelX =  me.pixelDistance * math.cos(me.xa_rad + math.pi/2) + pixels_max/2;
                me.pixelY =  me.pixelDistance * math.sin(me.xa_rad + math.pi/2) + me.strokeOriginY;
                #print("pixel blip ("~pixelX~", "~pixelY);
                me.tfblip[me.b_i].setTranslation(me.pixelX, me.pixelY); 
                if (me.locked == TRUE) {
                  pixelXL = me.pixelX;
                  pixelYL = me.pixelY;
                }
              } else {
                #aircraft is not near the stroke, fade it
                me.blip_alpha[me.b_i] = me.blip_alpha[me.b_i]*0.90;
              }
              me.blip[me.b_i].show();
              me.blip[me.b_i].setColor(black_r, black_g, black_b, me.blip_alpha[me.b_i]);
              me.blip[me.b_i].setColorFill(black_r, black_g, black_b, me.blip_alpha[me.b_i]);
              me.b_i=me.b_i+1;
          }
        }
        if (me.anyLock == FALSE) {
          me.lock.hide();
        } else {
          me.lock.setTranslation(pixelXL, pixelYL);
          me.lock.show();
        }
        for (var i = me.b_i; i < me.no_blip; i=i+1) me.blip[i].hide();
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
var scope = nil;
#var theinit = setlistener("ja37/supported/initialized", func {
#  removelistener(theinit);
#  scope = radar.new();
#  scope.update();
#}, 1, 0);
