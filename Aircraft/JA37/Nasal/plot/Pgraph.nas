# Class Fgp,  plotter class

# This is all, as a quick approach.
# Some functions should exist in another class, and a 
# function for updating, in the other ...
# i.e. settext belong to text ...

Area = {};

Fgp = {};

############################################################
##
## All members of Area.
##

Area.new = func (x){
   var me = { parents : [Area] ,
      _Dialog: 0,
      _AR: 0,    # Autoresize by dialog window.
      _Canvas: 0,
      _Transp: 0.5,
      _Root: 0,
      _Above: 0,
      _Below: 0,
      _Pctx: 0,
      _Cpos: 0,
      _CP: 0,   #Position toggler
      _Lns: [0,0,0,0,0,0],
      _Path: [0,0,0,0,0,0],
      _TickMark:0,  # is like a line !
      _LineCnt: 0,
      _Color: ["#FF0000","#00FF00","#0000FF","#00FFFF","#FF00FF","#FFFF00"],
      _Cur_x: 0,
      _Max_x: 0,
      _Tick:20,     # Default Tickmark enabled and speed
      _TickC:0,     # Tickmark counter
      _UpdSpd:1,    # Default 1 * 0.1 sec update
      _Step:1,      # Step size per sample
      _Xt: 0,
      _MenuEnabled: 1, # popupmenu or not
      _Run: 0,
      _Drag: 0, # prevent stack overflow
      _Pnm: 0,
      _cnt: 0,
      _w: 0,
      _h: 0,
      _Menu: 0,   # handle to menu popup
      _Legend: 0, # handle to legend popup
      _MyTimeout: 0,
      _DoPlot: 0,
      _t: 0,  # handle to timer/ timer until popup
   };
   me._cnt=x;
   #printf("Area.new with count %d",me._cnt);
   return me;
};

# This created the window and the canvas e.a. to plot on
Area.init = func (w,h,r) {
   me._w=w;
   me._h=h;
   me._AR=r;
# A window is only needed for a standalone applic.
# But then what about resizing ? resizing is efectuated at the Dialog ?
   me._Dialog=canvas.Window.new([w,h]);
   if(me._AR == 1)me._Dialog.set("resize", me._AR);
   me._Max_x = w;
   me._Canvas=me._Dialog.createCanvas()
                        .setColorBackground(0.5,0.5,0.5,me._Transp);
   me._Canvas.set("name","Area_"~me._cnt);
   me._Root=me._Canvas.createGroup();
   # 3-D Effect line
   var x = 0;
   var y = 0;
   var h = me._h;
   var w = me._w;
   me._Above = me._Root.createChild("path", "data")
              .set("stroke-width", 1)
              .setColor("#000000")
              .moveTo(x,h+y)
              .lineTo(x,y)
              .lineTo(x+w,y);
   # 3-D Effect line
   me._Below = me._Root.createChild("path", "data")
              .set("stroke-width", 1)
              .setColor("#FFFFFF")
              .moveTo(x,h+y)
              .lineTo(x+w,h+y)
              .lineTo(x+w,y);
   me._Pctx=me._Root.createChild("path", "data");
   # Serial number indicator
   me._Pnm=me._Root.createChild("text", "")
              .set("font","Helvetica.txf")
              .setFontSize(16, 1)
              .setTranslation(2, 12)
              .setColor(1,0,0) # Text color
              .setText(me._cnt);
   # Tickmark created default.
   me._TickMark = Lines.new(me).SetColor("#FFFFFF").SetFactor(-1);
   me._TickMark.SetWidth(1);
   # Plotting Area must be movable if not done automatic
   if(me._AR == 0) {
   (func {
      #var i = me.Indx; # capture i in the local scope of 
                        # this anonymous function
      me._Canvas.addEventListener("drag", func (e) { e.stopPropagation();me.DragOrMove(e.deltaX, e.deltaY,e.buttons); });
    })();
    };
   # Plotting Area must be deletable
   (func {
      #var i = me.Indx; # capture i in the local scope of 
                        # this anonymous function
      me._Canvas.addEventListener("dblclick", func (e) { e.stopPropagation() ; me.Del(e.button); });
   })();
    # Plotting Area must have a menu to add lines/properties...
   (func {
      #var i = me.Indx; # capture i in the local scope of 
                        # this anonymous function
                        # should be right mouse key !
      me._Canvas.addEventListener("click", func (e) { e.stopPropagation() ; me.Menu(e.button,e.click_count); });
   })();
    # Plotting Area popup - legent
   (func {
      me._Canvas.addEventListener("mouseenter", func () { me.LegendDelay(); });
   })();
   (func {
      me._Canvas.addEventListener("mouseleave", func () { me._t.stop(); });
   })();
   me._t = maketimer(2, func () { me.Legend(1) });
   me._t.singleShot = 2;
   return me;
};

# delta X, delta Y , Mousekey
Area.DragOrMove = func (X,Y,M) {
   # No popup when dragging !
   me._t.stop();
   # Only 1 drag at a time 
   if((me._Drag == 1) or (M == 4))return me; # ! event cache overrun
   gui.popupTip("Area.DragOrMove called",1);
   me._Drag = 1;
   # When resizing plotting has to be stopped, or FG will crash
   # almost immidiatly, but otherwise also when continues resizing
   var OldRun = me._Run;
     # #printf("Resizing ... X %d Y %d M %d ",X,Y,M);
   if(M == 2){
   # resize ! linewidth is also resized ! ?
      me._Run = 0;
      #printf("Resizing ... X %d Y %d M %d ",X,Y,M);
      var cx = me._Dialog.get("content-size[0]") +X;
      var cy = me._Dialog.get("content-size[1]") +Y;
#      var fx = me._w / cx;
      var fx = 1;
      var fy = cy / me._h ;
      # works rather well, but you should keep the aspect ratio.
#      fx = math.sqrt((fx*fx)+(fy*fy));
      fx = 1/fy;
      # Don't go negative ! You'r toast
      if(cx<125)cx=125;
      if(cy<61)cy=61;
      me._Dialog.setInt("content-size[0]",cx);
      me._Dialog.setInt("content-size[1]",cy);
#      me._Dialog.setInt("size[0]",cx); # Needed ???
#      me._Dialog.setInt("size[1]",cy); # Needed ???
      me._Above.set("stroke-width", int(0.9+1*fx));
      me._Below.set("stroke-width", int(0.9+1*fx));
#      me._Canvas.set("size[0]",cx*2);
#      me._Canvas.set("size[1]",cy*2);
      for(var i = 0 ; i < 6 ; i += 1){
         #printf("Line i %d width %f",i,int(0.9+fx*me._Lns[i].GetWidth()));
         me._Lns[i]._Path.set("stroke-width",int(0.9+fx*me._Lns[i].GetWidth()));
      };
      me._Pctx.set("stroke-width", int(0.9+1*fx));
#      me._Canvas.set("view[0]",cx);
#      me._Canvas.set("view[1]",cy);
      #printf("Schalen fertig");
      # Plotting to old status.
      me._Run = OldRun;
   } else { 
   # just move
      #printf("Moving ... X %d Y %d M %d ",X,Y,M);
      me._Dialog.move(X,Y);
      #printf("Verschieben fertig");
   };
   me._Drag = 0;
   return me;
};
 
# Does line exist (i)
Area.Lexist = func (l) {
   if(me._Lns[l] != 0)
      return 1;
   else
      return 0;
};

# Is line (l) enabled or not
Area.Lstatus = func (l) {
   if(me.Lexist(l) == 1){
      if(me._Lns[l].GetStatus() == 1)
         return 1;
   };
   return 0;
};

# Toggel Enabled from line (l)
Area.EnaDisa = func (l) {
   if(me._Lns[l] != 0){
      if(me._Lns[l].GetStatus() == 1)
         me._Lns[l].Enable(0);
      else
         me._Lns[l].Enable(1);
         if(me._Lns[l].GetWidth() == 0)me._Lns[l].SetWidth(1);
   };
   return me;
}

# Centerline position set by parent/calling program
Area.Centerline = func (pos) {
   # position is totalheight - pos.
   me._Cpos=me._h-pos; 
   me._Pctx.set("stroke", "#FFFFFF").set("stroke-width", 1)
           .moveTo(0,me._Cpos)
           .lineTo(me._w-1,me._Cpos);
};

# Centerline position set by toggle button
Area.SetCenterLine = func () {
   me._Cpos=(me._h/4)*me._CP ;
#   me._Pctx.setTranslation(0,me._Cpos);
   me._Pctx.pop_front();
   me._Pctx.pop_front();
   me._Pctx.moveTo(0,me._Cpos)
           .lineTo(me._w-1,me._Cpos);
   me._CP+=1;
   if(me._CP >= 5) me._CP=0;
   return me;
}

# Cpos is in fact the top of the positive area
Area.GetCpos = func () {
   return me._Cpos;
};

# No nervous popping
Area.LegendDelay = func {
   me._t.start(2);
   return me;
};

# Legent shows properties in use
# maby it should remain in sight until leave ...
Area.Legend = func (x) {
   if(x == 1){ # mousebutton 1
     #printf("Area.Legend popup");
     gui.popupTip("Area.ShowLegend
popup",2);
     if(me._Legend == 0) # No double legend
        me._Legend = Legend.new(me).init().Setup();
   } else #printf("Area.Legend popdown");  
   return me;
};

# show the legend
#Area.ShowLegend = func () {
#   gui.popupTip("Area.ShowLegend
#popup",2);  
#   if(me._Legend == 0)
#      me._Legend = Legend.new(me).init().Setup();
#   return me;
#};

# add a new line to the graph , at a max of 6 lines
Area.AddLine = func () {
   if(me._LineCnt<6){
      me._Lns[me._LineCnt] = Lines.new(me).SetColor(me._Color[me._LineCnt]).SetFactor(-1);
      me._Lns[me._LineCnt].SetWidth(1);
      me._LineCnt+=1;
   };
   return me;
};
 
# returns the _Linecount of lines in this graph.
Area.GetLineCnt = func () {
   return me._LineCnt;
};

Area.SetLineWidth = func (l,w) {
   me._Lns[l].SetWidth(w);
   return me;
};

Area.SetLineColor = func (l,c) {
   me._Lns[l].SetColor(c);
   return me;
};

# Remove this plotting window
Area.Del = func (bt) {
   if(bt == 1){
# also delete legend and menu ...
      me._t.stop();
      if(me._Legend > 0)me._Legend.Del(0);
      if(me._Menu != 0) me._Menu.Del(1);
      me._Dialog.del();
   };
   return me;
};

# Enables or disables the buildin menu
Area.MenuEnable = func (e) {
   me._MenuEnabled = e;  # 0 disables, 1 enables
};

# popup a menu to control properties
Area.Menu = func (bt,n) {
   if(me._MenuEnabled == 1){
      if((bt == 2) and (n == 1) and (me._Menu == 0)){
         gui.popupTip(s#printf("This is going to be a menu "),2);
         me._Menu = Menu.new(me,me._cnt).init().Setup();
      };
   };
   return me;
};
   
# This starts the whole plotting loop for active lines
Area.Run = func () {
   # Start loop, ploting all enabled lines with property
   #printf("Start plotting is called");
   if(me._Run == 1){
      gui.popupTip("Plot already running",2);
      return me;
   };
   me._Run = 1;
   me.DoTick = func(){
#        #printf("Tick ... \n");
      if(me._TickC == 0){
      me._TickMark._Path.moveTo(me._Cur_x,-50);
      me._TickMark._Path.lineTo(me._Cur_x,50);
      me._TickC=me._Tick;
      } 
      me._TickC-=1;
#      me._TickMark._Path.moveTo(me._Cur_x,50);
#      me._TickMark._Path.lineTo(me._Cur_x,0);
   };
   me._DoPlot = func(){
      #gui.popupTip("Plot running",1);
      # plot lines, popfront
      var y = 0;
      var p = "";
      for(var i = 0; i < me._LineCnt ; i += 1 ){
         if(me._Lns[i]._Plottable == 1){
#            p = me._Lns[i].GetProperty();
#            y = getprop(p);
#            #printf("prop %s == %d, %d %d ",p,y,me._Cur_x, y);
           if( me._Cur_x == 0 )
             me._Lns[i]._Path.moveTo(me._Cur_x,0+ getprop(me._Lns[i].GetProperty()));
           else 
             me._Lns[i]._Path.lineTo(me._Cur_x,0+ getprop(me._Lns[i].GetProperty())*me._Lns[i]._Factor);
           me._Xt = me._Max_x - me._Cur_x;
           me._Lns[i]._Path.setTranslation(me._Xt, me._Cpos);
           if(me._Lns[i]._Path.getNumSegments() > (me._Max_x+1))
               me._Lns[i]._Path.pop_front();
         };
      };
      # add a tickmark if enabled
      if(me._Tick > 0){
        me.DoTick();
        me._TickMark._Path.setTranslation(me._Xt, me._Cpos);
        if(me._TickMark._Path.getNumSegments() > (me._Max_x+1))
           me._TickMark._Path.pop_front();
      };
      me._Cur_x += 1*me._Step;
      if(me._Run == 1 ){
         settimer(me._DoPlot,0.1);
      };
   };
   me._DoPlot();
   return me;
};

# Set the update speed
Area.SetUpdSpd = func (t){
   me._UpdSpd = t;
   return me;
};

# Set the tickmark frequency
Area.SetTick = func (t){
   me._Tick = t;
   return me;
};

# Set the stepsize
Area.SetStep = func (t){
   me._Step = t;
   return me;
};

# set transparency in 3 steps ;))
# Currently color of canvas is only grey !
Area.SetTransp = func () {
   if(me._Transp == 1)me._Transp = 0;
   else if(me._Transp == 0.5)me._Transp = 1;
   else if(me._Transp == 0)me._Transp = 0.5;
   me._Canvas.setColorBackground(0.5,0.5,0.5,me._Transp);
   return me;
};

# Sets the property for line l
Area.SetProperty = func (l,p) {
   me._Lns[l].SetProperty(p);
   return me;
};

# Sets the top-value for line l
Area.SetTop = func (l,v) {
   me._Lns[l].SetTop(v);
   return me;
};

# Stop the plotting loop.
Area.Stop = func () {
   #printf("Stop plotting is called");
   me._Run = 0;
   return me;
};

# cp properties to /fgplot/save and save in xml
Area.Save = func () {
   if(me._MenuEnabled == 1)
      Save.new(me,me._cnt).init().run();
#   var FgHome = getprop("/sim/fg-home");
#   io.write_properties(FgHome~"/state/fgplot2","/sim/fgplot2");
   return me;
};

# cp properties back from xml
Area.Load = func () {
   if(me._MenuEnabled == 1)
      Load.new(me,me._cnt).init().run();
   return me;
};
############################################################
##
## All members of Fgp.
##
## Just to create a new plotting area
##

Fgp.new = func (w,h,r) {
   var me = { parents : [Fgp] ,
      _Area: 0,
      _cnt: 0,
      _Width: 0,
      _Height: 0,
      _AutoResize: 0,
   };
   me._cnt=getprop("/sim/Fgp-serial") or 0; # serial start with 0
   setprop("/sim/Fgp-serial",me._cnt+1);    
   me._Width=w;
   me.Height=h;
   me._AutoResize = r;
   #printf("Fgp.new was called");
   return me;
};

Fgp.init = func {
   #printf("Count == %d",me._cnt);
   #printf("instances started == %d",me._cnt+1);
# This creates the plotting area and set the center (0) line
# at 5 points from the bottom
   me._Area=Area.new(me._cnt);
   me._Area.init(me._Width,me.Height,me._AutoResize).Centerline(5);
# Ad a line to the plotting area
   me._Area.AddLine();
# Set the properteetree property
   me._Area.SetProperty(0,"/sim/frame-rate");
# Set Top/Max value of plotting line
   me._Area.SetTop(0,65);
   me._Area.AddLine();
   me._Area.SetProperty(1,"/sim/frame-rate-worst");
   me._Area.SetTop(1,60);
   me._Area.AddLine();
   me._Area.SetProperty(2,"/sim/frame-latency-max-ms");
   me._Area.SetTop(2,100);
# Set the width of the line apart from the default (1)
   me._Area.SetLineWidth(2,4);
# Set the color of a line apart from de default.(indexed)
   me._Area.SetLineColor(2,"#000000");
   me._Area.AddLine();
   me._Area.AddLine();
   me._Area.SetProperty(3,"/velocities/airspeed-kt");
   me._Area.SetProperty(4,"/velocities/groundspeed-kt");
   me._Area.SetTop(3,45);
   me._Area.SetTop(4,45);
   me._Area.AddLine();
   me._Area.SetProperty(5,"/environment/wind-speed-kt");
   me._Area.SetTop(5,45);
   return me;
};
