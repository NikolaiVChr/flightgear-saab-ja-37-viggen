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
      "mipmapping": 1
    });
    
    # ... and place it on the object called Screen
    m.canvas.addPlacement({"node": "Screen"});
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
    m.no_blip=30;
    m.radarRange=20000;#feet?
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
         .moveTo(0, 0)
         .lineTo(0, -904)
         .close()
         .setStrokeLineWidth(28)
         .setColor(0.1, grn, 0.1));
       append(m.tfstroke, m.stroke[i].createTransform());
       m.tfstroke[i].setTranslation(512, 904);
       m.stroke[i].hide();
     }

    m.blip = [];
    m.blip_alpha=[];
    m.tfblip=[];
    for(var i=0; i < m.no_blip; i = i+1) {
        append(m.blip,
         g.createChild("path")
         .moveTo(-6, -6)
         .lineTo(-6, 6)
         .lineTo(6, 6)
         .lineTo(6, -6)
         .lineTo(-6, -6)
         .close()
         .setStrokeLineWidth(12)
         .setColor(0.0,1.0,0.0, 1.0));
       append(m.tfblip, m.blip[i].createTransform());
       m.tfblip[i].setTranslation(0, 0);
       m.blip[i].hide();
       append(m.blip_alpha, 1);
     }
     
    m.antennay=g.createChild("path")
                .moveTo(900, 512)
                .lineTo(920, 512)
                .close()
                .setStrokeLineWidth(18)
                .setColor(0.6,0.7,1.0, 1.0);
    m.antennay.hide();
    m.tfantennay=m.antennay.createTransform();

    m.glide=g.createChild("path")
                .moveTo(10, 512)
                .lineTo(1000, 512)
                .close()
                .setStrokeLineWidth(18)
                .setColor(0.96,0.74,0.20, 1.0);
    m.tfglide=m.glide.createTransform();
    m.tfglide.setTranslation(0, 500);
    m.glide.hide();

    m.course=g.createChild("path")
                .moveTo(512, 10)
                .lineTo(512, 1000)
                .close()
                .setStrokeLineWidth(18)
                .setColor(0.96,0.74,0.20, 1.0);
    m.tfcourse=m.course.createTransform();
    m.tfcourse.setTranslation(500, 0);
    m.course.hide();
    #m.scale=g.createChild("image")
     #        .setFile("Models/Instruments/Radar/scale.png")
      #       .setSourceRect(0,0,1,1)
       #      .setSize(1024,1024)
        #     .setTranslation(0,0);

    return m;
  },

  update: func()
  {
  #Modes 0=Off, 1=Autoscan, 2=Manual, 5=Course guide, 6=Course and glide
    var rmode=1;#getprop("instrumentation/radar/mode");
    if (getprop("sim/current-view/view-number") == 0 and getprop("systems/electrical/outputs/radar") != nil and getprop("systems/electrical/outputs/radar") > 28 and getprop("instrumentation/radar/serviceable") > 0 and getprop("sim/ja37/radar/enabled") == 1) {
      g.show();
      me.radarRange=getprop("instrumentation/radar/range") * 3.2808; #convert to feet
      forindex (i; me.stroke) me.stroke[i].show();
      var te = getprop("sim/time/elapsed-sec");
      
      #Stroke animation
      if (te == nil) {
        te = 5;
      }            
      # compute new stroke angle
      me.stroke_angle=30.0*math.sin(te*2);
      #convert to radians
      var curr_angle = me.stroke_angle * 0.0175; 
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
        var self = geo.aircraft_position();
        var myPitch=getprop("orientation/pitch-deg")*0.0174533;
        var myRoll=-getprop("orientation/roll-deg")*0.0174533;
        var groundAlt=getprop("position/altitude-ft")*0.305;
        var myHeading=getprop("orientation/heading-deg");
        var b_i=0;
        var index = 0;
        #var shortestDistance = 1000000;
        #var shortestAC = -1;
        #var isShortestMP = -1;
        #do the multiplayers
        foreach (var mp; multiplayer.model.list) {
            var n = mp.node;
            var x = n.getNode("position/global-x").getValue();
            var y = n.getNode("position/global-y").getValue();
            var z = n.getNode("position/global-z").getValue();
            var aircraftPos = geo.Coord.new().set_xyz(x, y, z);
            var distance = nil;
            call(func distance = self.distance_to(aircraftPos), nil, var err = []);
            if ((size(err))or(distance==nil) or n.getNode("valid").getValue() == 0) {
                # Oops, have errors. Bogus position data (and distance==nil).
                    print("Received invalid position data: " ~ debug._error(mp.callsign));
            }
            else
             {

                # Node with valid position data (and "distance!=nil").
                var aircraftAlt=n.getNode("position/altitude-ft").getValue()*0.305; #altitude in meters
                #ground angle
                var yg_rad=math.atan2((aircraftAlt-groundAlt), distance)-myPitch; 
                var xg_rad=(self.course_to(aircraftPos)-myHeading)*0.0174533;
                if (xg_rad > math.pi) xg_rad=xg_rad-2*math.pi;
                #aircraft angle
                var ya_rad=xg_rad*math.sin(myRoll)+yg_rad*math.cos(myRoll);
                var xa_rad=xg_rad*math.cos(myRoll)-yg_rad*math.sin(myRoll);
                #make blip
                if (ya_rad > -0.5 and ya_rad < 0.5 and xa_rad > -1 and xa_rad < 1) {
                  #if(distance < shortestDistance) {
                  #      shortestDistance = distance;
                  #      shortestAC = index;
                  #      isShortestMP = 1;
                  #    }
                  if (b_i < me.no_blip and distance < me.radarRange ){#and alt-100 > getprop("/environment/ground-elevation-m")){
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
                        var pixelDistance = -distance*(750/me.radarRange); #distance in pixels
                        
                        #translate from polar coords to cartesian coords
                        var pixelX =  pixelDistance * math.cos(xa_rad + 1.5708) + 512;
                        var pixelY =  pixelDistance * math.sin(xa_rad + 1.5708) + 904;
                        #print("pixel blip ("~pixelX~", "~pixelY);
                        me.tfblip[b_i].setTranslation(pixelX, pixelY); 
                      } else {
                        #aircraft is not near the stroke, fade it
                        me.blip_alpha[b_i] = me.blip_alpha[b_i]*0.96;
                      }
                      me.blip[b_i].show();
                      me.blip[b_i].setColor(0.0,1.0,0.0, me.blip_alpha[b_i]);
                      b_i=b_i+1;
                  }
                }
            }
            index += 1;
        }
        var b_j = index;
        #do the AI
        foreach (var mp; props.globals.getNode("/ai/models").getChildren("aircraft")) {
            var distance = nil;
            var x = mp.getNode("position/global-x").getValue();
            var y = mp.getNode("position/global-y").getValue();
            var z = mp.getNode("position/global-z").getValue();
            var aircraftPos = geo.Coord.new().set_xyz(x, y, z);
            call(func distance = self.distance_to(aircraftPos), nil, var err = []);
            if ((size(err))or(distance==nil) or mp.getNode("valid").getValue() == 0) {
                # Oops, have errors. Bogus position data (and distance==nil).
                    #print("Received invalid position data: " ~ debug._error(mp.callsign));
            }
            else
            {
                # Node with valid position data (and "distance!=nil").
                var aircraftAlt=mp.getNode("position/altitude-ft").getValue()*0.305; #altitude in meters
                #ground angle
                var yg_rad=math.atan2((aircraftAlt-groundAlt), distance)-myPitch; 
                var xg_rad=(self.course_to(aircraftPos)-myHeading)*0.0174533;
                if (xg_rad > math.pi) xg_rad=xg_rad-2*math.pi;
                #aircraft angle
                var ya_rad=xg_rad*math.sin(myRoll)+yg_rad*math.cos(myRoll);
                var xa_rad=xg_rad*math.cos(myRoll)-yg_rad*math.sin(myRoll);
                #make blip
                if (ya_rad > -1 and ya_rad < 1 and xa_rad > -1 and xa_rad < 1) {
                  #if(distance < shortestDistance) {
                  #      shortestDistance = distance;
                  #      shortestAC = index-b_j;
                  #      isShortestMP = 0;
                        #print(shortestAC~" shortest "~shortestDistance~" distance "~mp.getNode("callsign").getValue());
                  #    }     
                  if (b_i < me.no_blip and distance < me.radarRange ){#and alt-100 > getprop("/environment/ground-elevation-m")){
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
                        var pixelDistance = -distance*(750/me.radarRange); #distance in pixels
                        
                        #translate from polar coords to cartesian coords
                        var pixelX =  pixelDistance * math.cos(xa_rad + 1.5708) + 512;
                        var pixelY =  pixelDistance * math.sin(xa_rad + 1.5708) + 904;
                        #print("pixel blip ("~pixelX~", "~pixelY);
                        me.tfblip[b_i].setTranslation(pixelX, pixelY); 
                      } else {
                        #aircraft is not near the stroke, fade it
                        me.blip_alpha[b_i] = me.blip_alpha[b_i]*0.96;
                      }
                      me.blip[b_i].show();
                      me.blip[b_i].setColor(0.0,1.0,0.0, me.blip_alpha[b_i]);
                      b_i=b_i+1;
                  }
                }
            }
            index += 1;
        }
        #setprop("sim/ja37/radar/selected", shortestAC);
        #setprop("sim/ja37/radar/selectedMP", isShortestMP);
        #print("selected "~shortestAC~" MP "~isShortestMP);
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
