
Legend = {}; 

############################################################
##
## All members of Legend.
##

# use: Legend.new(parent) parent needed to call-back
# menu is bound to canvas, multiple can exist
Legend.new = func (x) {
   var me = { parents : [Legend] ,
      _Caller: 0, # need to reset _Legend, double menu prevention.
      _Cl: 0,     # Curent line
      _Width: 0,
      _Height: 0,
      _Dialog: 0,
      _Canvas: 0,
      _Transp: 1,
      _Root: 0,
      _Above: 0,
      _Below: 0,
      _Listener: [0,0,0,0,0,0],  # 6 Listener possible for 6 lines
      # Objects == buttons textfields etc.
#      _Obns: [0,0,0,0,0,0,0,0,0,0,0,0,0],
      _Oprop: [0,0,0,0,0,0],     # 6 proprty fields
      _Ofact: [0,0,0,0,0,0],     # 6 proprty Top editfields
      _Helper: 0,                # handle to helper functions
      _t: 0                      # handle to legend timer
   };
   me._Caller = x;
   return me;
}

Legend.init = func () {
   me._Width = 308;
   me._Height = 6*24+8;
   me._Helper = Helper.new();
   me._Dialog=canvas.Window.new([me._Width,me._Height]);
   me._Canvas=me._Dialog.createCanvas()
                        .setColorBackground(0.3,0.3,0.3,me._Transp);
   me._Root=me._Canvas.createGroup();
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
   # Legend Area must be movable
   (func {
      #var i = me.Indx; # capture i in the local scope of 
                        # this anonymous function
      me._Canvas.addEventListener("drag", func (e) { me._Dialog.move(e.deltaX, e.deltaY); });
   })();
   # Legend Area must be deleteble
   (func {
      me._Canvas.addEventListener("dblclick", func (e) { me.Del(e.button); });
   })();
   # place window a little right/down parent
   var Sx = me._Caller._Dialog.get("tf/t[0]");
   var Sy = me._Caller._Dialog.get("tf/t[1]");
   me._Dialog.set("tf/t[0]",Sx + 100);
   me._Dialog.set("tf/t[1]",Sy + 50);
   return me;
}; 

Legend.Setup = func () {
   var offset = 8; # border width
   for( var slot = 0 ; slot < 6 ; slot += 1) { # Slots 0-5
      #printf("creating slot %d for line %d",slot,slot);
      # Add a Factor field 
      var a = Text.new().Setup(me._Root,8,offset+(slot*24),10,15,slot);
      if(me._Caller._Lns[slot].GetStatus() == 1)
         a.SlotColor(me._Caller,slot);
      else
         a.SetColor(2);
#      a.SlotColor(me._Caller,slot);
      me._Ofact[slot] = Text.new().Setup(me._Root,30,offset+(slot*24),60,15,"-1");
#      me._Ofact[slot].SlotColor(me._Caller,slot);
      var a = "1";
      if((slot) < me._Caller._LineCnt ){ # _Lns start at 0 !
        a = me._Caller._Lns[slot].GetTop();
      };
      me._Ofact[slot].Settext(s#printf("%8.2e",a)); # Should change in e-factor ?
   };
   # Text output chosen property
   for( var slot = 0 ; slot < 6 ; slot += 1) { # Slots 0-5
#      var a = Text.new().Setup(me._Root,100,offset+(slot*24),10,20,slot);
#      a.SlotColor(me._Caller,slot);
      me._Oprop[slot] = Text.new().Setup(me._Root,100,offset+(slot*24),200,15,"Test Text.");
      var a = "-";
      if((slot) < me._Caller._LineCnt ){ # _Lns start at 0 !
        a = me._Caller._Lns[slot].GetProperty();
      };
      me._Oprop[slot].Settext(me._Helper.FitString(a,30));
   };
   var Delete = func {
      me.Del(0);
   };
#   var _t = settimer(Delete,5);
# Using maketimer reduses 1 error when legend is forcely removed
# settimer can't be removed or stopped ?
   me._t = maketimer(5,Delete);
   me._t.singleShot = 1;
   me._t.start();
   #printf("Timerid %d",me._t);
   return me;
};

# Toggle enable/disable drawing of line.
Legend.EnaDisa = func (l) {
   return me;
};

Legend.ChFactor = func (b,x,c,s) {
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
Legend.TextIn = func (but,l) {
   var ONumber = me._Caller._Lns[l].GetTop();
   me._Ofact[l].Settext(s#printf("%8.2e",ONumber));
   var Number = 0;
   if(but == 0){ # input when left mouse
   me._Ofact[l].SetColor(1);
   #print("Legend.TextIn active.");
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
   #print("Legend.TextIn Inactive.");
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
 
Legend.OpenChsr = func (x) {
   gui.popupTip(s#printf("Legend.OpenChsr for line %d",x),2);
   # Open only if previous line exist, There is always 1 line
   if((x == 0) or (me._Caller._Lns[x-1] != 0)){
      me._Oprop[x].SetColor(1);
      # Make new line if not exist
      if(me._Caller._LineCnt == x)me._Caller.AddLine();
      me._Cl = x;
      var newprop = Chooser.new(me,x).init().run(nil);
   };
   return me;
};

Legend.SetProp = func (x,newprop) {
   me._Oprop[x].Settext(me._Helper.FitString(newprop,30));
   me._Caller._Lns[x].SetProperty(newprop);
   me._Oprop[x].SetColor(0);
   return me;
};

#Legend.FitString = func (s,n) {
#   #printf("Legend.FitString called with %s",s);    
#   if ( size(str(s)) < n ) return s;
#   var l = substr(s, 0, (n - 2) / 3);
#   var r = substr(s, size(s) + size(l) + 3 - n);
#   return l ~ "..." ~ r;
#};
 
Legend.Start = func () {
   me._Caller.Run();
   return me;
};

Legend.Stop = func () {
   me._Caller.Stop();
   return me;
};

Legend.Trnsp = func () {
   me._Caller.SetTransp();
   return me;
};

Legend.Del = func (bt) {
   if(bt == 0){ 
      me._Caller._Legend = 0;
      me._t.stop();
      me._Dialog.del();
   };
   return me;
};
