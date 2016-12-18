
Menu = {};

############################################################
##
## All members of Menu.
##

# use: Menu.new(parent) parent needed to call-back
# menu is bound to canvas, multiple can exist
Menu.new = func (x,cnt) {
   var me = { parents : [Menu] ,
      _Caller: 0, # need to reset _Menu, double menu prevention.
      _Cl: 0,     # Curent line
      _Width: 0,
      _Height: 0,
      _Dialog: 0,
      _Canvas: 0,
      _Transp: 1,
      _Root: 0,
      _Cnt: 0,  # Number to correspond withe graph number
      _Mnm: 0,
      _Above: 0,
      _Below: 0,
      _Listener: [0,0,0,0,0,0],  # 6 Listener possible for 6 lines
      # Objects == buttons textfields etc.
      _Otbns: [0,0,0,0,0,0,0,0,0,0], # 9 button slots
      _Oprop: [0,0,0,0,0,0],     # 6 proprty fields
      _Opbtn: [0,0,0,0,0,0],     # 6 proprty buttons
      _Odbtn: [0,0,0,0,0,0],     # 6 delete proprty/line buttons
      _Ofact: [0,0,0,0,0,0],     # 6 proprty Top editfields
      _Oena: [0,0,0,0,0,0],     # 6 enable/disable buttons
      _Oftxt: [0,0,0,0,0,0],     # 6 factor indicator fields
      _Otxt: [0,0,0,0,0,0],     # 6 text indicator fields
      _Helper: 0,               # handle to helper functions
      _Marker: 0,               # Handle to set markers and speed
   };
   me._Caller = x;
   me._Cnt = cnt;
   #printf("Menu.new called with number %d",me._Cnt);
   return me;
}

# This does the mayor initializations
Menu.init = func () {
   me._Width = 270;
   me._Height = 13*28+15;
   me._Helper = Helper.new();
   me._Dialog=canvas.Window.new([me._Width,me._Height]);
   me._Canvas=me._Dialog.createCanvas()
                        .setColorBackground(0.3,0.3,0.3,me._Transp);
   me._Root=me._Canvas.createGroup();
   me._Mnm = me._Root.createChild("text", "")
              .set("font","Helvetica.txf")
              .setFontSize(16, 1)
              .setTranslation(10, 25)
              .setColor(1,0,0) # Text color
              .setText(me._Cnt);
   # 3-D Effect line
   var x = 0;
   var y = 0;
   var h = me._Height;
   var w = me._Width;
   me._Above = me._Root.createChild("path", "data")
              .set("stroke-width", 1)
              .setColor("#FFFFFF")
              .moveTo(x,h+y)
              .lineTo(x,y)
              .lineTo(x+w,y);
   # 3-D Effect line
   me._Below = me._Root.createChild("path", "data")
              .set("stroke-width", 1)
              .setColor("#000000")
              .moveTo(x,h+y)
              .lineTo(x+w,h+y)
              .lineTo(x+w,y);
   # Menu Area must be movable
   (func {
      #var i = me.Indx; # capture i in the local scope of 
                        # this anonymous function
      me._Canvas.addEventListener("drag", func (e) { me._Dialog.move(e.deltaX, e.deltaY); });
   })();
   # place window a little right/down parent
   var Sx = me._Caller._Dialog.get("tf/t[0]");
   var Sy = me._Caller._Dialog.get("tf/t[1]");
   me._Dialog.set("tf/t[0]",Sx + 125);
   me._Dialog.set("tf/t[1]",Sy + 25);
   return me;
}; 

# This does some more initialization and could be concatenated to init()
Menu.Setup = func () {
   var offset = 10; # border width
   # Start button
   me._Otbns[0] = Button.new().Setup(me._Root,30,offset,20,20,">");
   var a = me._Otbns[0].getGlass();
   (func {
      a.addEventListener("click", func () { me.Start(); });
   })();
   # Stop button
   me._Otbns[1] = Button.new().Setup(me._Root,60,offset,20,20,"=");
   var a = me._Otbns[1].getGlass();
   (func {
      a.addEventListener("click", func () { me.Stop(); });
   })();
   # Transparency button
   me._Otbns[2] = Button.new().Setup(me._Root,me._Width-30,offset+28,20,20,"T");
   var a = me._Otbns[2].getGlass();
   (func {
      a.addEventListener("click", func () { me.Trnsp(); });
   })();
   # Centerline button
   me._Otbns[3] = Button.new().Setup(me._Root,me._Width-30,offset+56,20,20,"C");
   var a = me._Otbns[3].getGlass();
   (func {
      a.addEventListener("click", func () { me.Center(); });
   })();
   # TickMark ans speeds button
   me._Otbns[7] = Button.new().Setup(me._Root,me._Width-30,offset+84,20,20,"M");
   var a = me._Otbns[7].getGlass();
   (func {
      a.addEventListener("click", func () { me.Marker(); });
   })();
#   # LineSpeed button
#   me._Otbns[8] = Button.new().Setup(me._Root,me._Width-30,offset+112,20,20,"U");
#   var a = me._Otbns[8].getGlass();
#   (func {
#      a.addEventListener("click", func () { me.UpdSpd(); });
#   })();
   # Save button 
   me._Otbns[4] = Button.new().Setup(me._Root,me._Width-90,offset,20,20,"S");
   var a = me._Otbns[4].getGlass();
   (func {
      # Delete on any mouse button
      a.addEventListener("click", func () { me._Caller.Save(); });
   })();
   # Re/Load button 
   me._Otbns[5] = Button.new().Setup(me._Root,me._Width-60,offset,20,20,"R");
   var a = me._Otbns[5].getGlass();
   (func {
      # Delete on any mouse button
      a.addEventListener("click", func (e) { me._Caller.Load(); });
   })();
   # Exit button 
   me._Otbns[6] = Button.new().Setup(me._Root,me._Width-30,offset,20,20,"X");
   var a = me._Otbns[6].getGlass();
   (func {
      # Delete on any mouse button
      a.addEventListener("click", func (e) { me.Del(1); });
   })();
   offset += 28;
   for( var slot = 0 ; slot < 6 ; slot += 1) { # Slots 0-5
      #printf("creating slot %d for line %d",slot,slot);
      # Add a Factor field 
      me._Oftxt[slot] = Text.new().Setup(me._Root,10,offset+(slot*28),10,20,slot);
      if(me._Caller._Lns[slot].GetStatus() == 1)
         me._Oftxt[slot].SlotColor(me._Caller,slot);
      else
         me._Oftxt[slot].SetColor(2);
      me._Ofact[slot] = Text.new().Setup(me._Root,30,offset+(slot*28),60,20,"-1");
      var a = "1";
      if((slot) < me._Caller.GetLineCnt() ){ # _Lns start at 0 !
        a = me._Caller._Lns[slot].GetTop();
      };
      me._Ofact[slot].Settext(s#printf("%8.2e",a)); # Should change in e-factor ?
      a = me._Ofact[slot].getGlass();
      (func {
       var b = slot;
         #a.addEventListener("wheel", func (e) { me.ChFactor(b,e.deltaY,e.ctrlKey,e.shiftKey); });
         a.addEventListener("click", func (e) { me.TextIn(e.button,b); });
      })();
   };
   # Add a enable/disable button  and erase prop/line
   for( var slot = 0 ; slot < 6 ; slot += 1) { # Slots 0-5
      me._Oena[slot] = Button.new().Setup(me._Root,100,offset+(slot*28),60,20,"Disable");
      var a = me._Oena[slot].getGlass();
      (func {
         var b = slot;
         a.addEventListener("click", func () { me.EnaDisa(b); });
      })();
#      me._Odbtn[slot] = Button.new().Setup(me._Root,me._Width-40,offset+(slot*28),30,20,"Del");
      me._Odbtn[slot] = Button.new().Setup(me._Root,170,offset+(slot*28),30,20,"Del");
      var a = me._Odbtn[slot].getGlass();
      (func {
         var b = slot;
         a.addEventListener("click", func () { me.ErDel(b); });
      })();
   };
   offset += 6*28;
   # Text output chosen property
   for( var slot = 0 ; slot < 6 ; slot += 1) { # Slots 0-5
      me._Otxt[slot] = Text.new().Setup(me._Root,10,offset+(slot*28),10,20,slot);
      if(me._Caller._Lns[slot].GetStatus() == 1)
         me._Otxt[slot].SlotColor(me._Caller,slot);
      else{
         me._Otxt[slot].SetColor(2);
         me._Oena[slot].SetText("Enable");
      };
      me._Oprop[slot] = Text.new().Setup(me._Root,30,offset+(slot*28),200,20,"Test Text.");
      var a = "-";
      if((slot) < me._Caller.GetLineCnt() ){ # _Lns start at 0 !
        a = me._Caller._Lns[slot].GetProperty();
      };
      me._Oprop[slot].Settext(me._Helper.FitString(a,30));
   };
   # Add a button 
   for( var slot = 0 ; slot < 6 ; slot += 1) { # Slots 0-5
      me._Opbtn[slot] = Button.new().Setup(me._Root,me._Width-30,offset+(slot*28),20,20,"C");
      var a = me._Opbtn[slot].getGlass();
      (func {
         var b = slot;
         a.addEventListener("click", func () { me.OpenChsr(b); });
      })();
   };
   return me;
};

# Toggle enable/disable drawing of line.
Menu.EnaDisa = func (l) {
   me._Caller.EnaDisa(l);
   if(me._Caller._Lns[l].GetStatus() == 1 and me._Caller._Lns[l]._Plottable){
      me._Otxt[l].SlotColor(me._Caller,l);
      me._Oftxt[l].SlotColor(me._Caller,l);
      me._Oena[l].SetText("Disable");
   }else{
      me._Otxt[l].SetColor(2);
      me._Oftxt[l].SetColor(2);
      me._Oena[l].SetText("Enable");
   };
   return me;
};

# Function to display re-loaded values from saved file
Menu.RePopulate = func () {
   for( var slot = 0 ; slot < 6 ; slot += 1) { # Slots 0-5
      me._Oprop[slot].Settext(me._Caller._Lns[slot]._Property);
      me._Otxt[slot].SetColor(me._Caller._Lns[slot]._Color);
      me._Ofact[slot].Settext(me._Caller._Lns[slot]._Factor);
  };
   return me;
};
 
# disable. delete erase property
Menu.ErDel = func (l) {
   if(me._Caller.Lexist(l) == 1 ){
      if(me._Caller.Lstatus(1) == 1)me._Caller.EnaDisa(l);
      # Linewidth to 0 after it is off, else a ghost remain
      me._Caller.SetLineWidth(l,0);
      me._Caller.SetProperty(l,"");
      me._Caller.SetTop(l,1);
      me._Oprop[l].Settext("");
      me._Otxt[l].SetColor(2);
      me._Ofact[l].Settext(s#printf("%8.2e",1)); # Should change in e-factor ?
      me._Oftxt[l].SetColor(2);
      me._Oena[l].SetText("Enable");
      # Now, how to remove line from graphfield, if needed??
   };
   return me;
};

# Old function for wheel-factor setting, can be deleted...
# Now it is done by typing a number in the corresponding field
Menu.ChFactor = func (b,x,c,s) {
   #printf("line %d x %d c %d s %d",b,x,c,s);
   #printf("Current factor %f",me._Caller._Lns[b].GetFactor());
   var f = me._Caller._Lns[b].GetFactor();
   if(c == 1){
      if(x > 0) 
        f = f * 2;
      else
        f = f / 2;
   }else{
      if(s == 1){
         if(x > 0) 
           f = f * 5;
         else
           f = f / 5;
      } else{
        f = f + x;
      };
   };
   if(f>=0)f=-0.0001;
   me._Caller._Lns[b].SetFactor(-f);
   me._Ofact[b].Settext(f);
   return me;
};

# Called TextIn, but does only numbers in !
Menu.TextIn = func (but,l) {
   var ONumber = me._Caller._Lns[l].GetTop();
   me._Ofact[l].Settext(s#printf("%8.2e",ONumber));
   var Number = 0;
   if(but == 0){ # input when left mouse
   me._Ofact[l].SetColor(1);
   #print("Menu.TextIn active.");
      if(me._Listener[l] ==  0){
      me._Listener[l] = setlistener("/devices/status/keyboard/event", func(event) {
                if (!event.getNode("pressed").getValue())
                    return;
                var key = event.getNode("key");
                var C = key.getValue();
                key.setValue(-1);           # drop key event
                #printf("code %d == %s",C,chr(C));
                if(C == 8){
                   Number = "";
                   me._Ofact[l].Settext(s#printf("%8.2e",Number));
                   return me;
                };
                if(C == 10){  #Return pressed
                   removelistener(me._Listener[l]);
   #print("Menu.TextIn Inactive.");
                   me._Listener[l] =0;
                   if(Number==0 or Number == "")Number=ONumber;
                   #me._Ofact[l].Settext(Number);
                   me._Ofact[l].Settext(s#printf("%8.2e",Number));
                   me._Ofact[l].SetColor(0);
                   me._Caller._Lns[l].SetTop(Number);
                   return me;
                }    
                if((C >= 48 and C <= 57) or C == 46){
                   #var shift = event.getNode("modifier/shift").getValue();
                   #if (handle_key(key.getValue(), shift))
                   Number = Number ~ chr(C);
                   #me._Ofact[l].Settext(Number);
                   me._Ofact[l].Settext(s#printf("%8.2e",Number));
                   #printf("code %d == %s result == %d",C,chr(C),Number);
                   return me;
                };
             });
      };
   };
   return me;
};
 
# This opens a listbox to choose a property from
Menu.OpenChsr = func (x) {
   gui.popupTip(s#printf("Menu.OpenChsr for line %d",x),2);
   # Open only if previous line exist, There is always 1 line
   if((x == 0) or (me._Caller._Lns[x-1] != 0)){
      me._Oprop[x].SetColor(1);
      # Make new line if not exist
      if(me._Caller.GetLineCnt() == x)me._Caller.AddLine();
      me._Cl = x;
      var newprop = Chooser.new(me,x).init().run(nil);
   };
   return me;
};

# switches color back to not-selected-color
Menu.Deselect = func (x) {
   me._Oprop[x].SetColor(0);
   return me;
};

# Sets selected property, and reports to the caller
Menu.SetProp = func (x,newprop) {
   me._Oprop[x].Settext(me._Helper.FitString(newprop,30));
   me._Caller._Lns[x].SetProperty(newprop);
   me.Deselect(x);
   return me;
};

# This report to caller to start the plot loop
Menu.Start = func () {
   me._Caller.Run();
   return me;
};

# This report to caller to stop the plot loop
Menu.Stop = func () {
   me._Caller.Stop();
   return me;
};

# This report to caller to change transparency
Menu.Trnsp = func () {
   me._Caller.SetTransp();
   return me;
};

# This report to caller to change Centerline position
Menu.Center = func () {
   me._Caller.SetCenterLine();
   return me;
};

# This menu to change tickmarks ans speeds
Menu.Marker = func () {
   if(me._Marker != 0) return me;
   me._Marker = Mark.new(me);
   me._Marker.init(me._Cnt);
   #gui.popupTip(s#printf("Menu.Marker Placeholder for TickMarker." ),2);
   return me;
};

## This menu to change updatespeed
#Menu.UpdSpd = func () {
#   if(me._Upd != 0) return me;
#   me._Upd = Updspd.new(me);
#   me._Upd.init(me._Cnt);
#   #gui.popupTip(s#printf("Menu.OpenChsr Placeholder for Update speed set." ),2);
#   return me;
##};

# To set the tickmark and tick speed in Pgraph
Menu.SetTick = func (t) {
   me._Caller.SetTick(t);
};

# To set the update/sample speed in Pgraph
Menu.SetUpdspd = func (t) {
   me._Caller.SetUpdSpd(t);
};

# To set the stepsize in Pgraph
Menu.SetStep = func (t) {
   me._Caller.SetStep(t);
};

# This will report caller menu is gone, and deletes it
Menu.Del = func (bt) {
   if(bt == 1){ # as if middle mouse is clicked ( Historical )
#      if(me._Caller._Legend != 0)me._Caller._Legend.Del(0);
#      me._Caller._Legend = 0;
      if( me._Marker != 0 ) me._Marker.Del();
      me._Caller._Menu = 0;
      me._Dialog.del();
   };
   return me;
};
