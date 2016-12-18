
Mark = {};

############################################################
##
## All members of Mark.
## functions to set the tickmark and frequency
##

Mark.new = func (c) {
   var me = { parents : [Mark] ,
   _Caller: 0,  # adress of the caller ( Pmenu ) .
   _Dialog: 0,
   _Canvas: 0,
   _Root: 0,
   _Width: 0,
   _Height: 0,
   _Above:0,
   _Below:0,
   _Transp: 0.8,
   _Butt:0,
   _Cnt:0,
   _Txt: [0,0,0],
   _Listener: 0,
   };
   me._Caller = c;
   #printf("Mark.new called with number %d",me._Caller);
   return me;
}

# This does the mayor initializations
Mark.init = func (cnt) {
   me._Width = 170;
   me._Height = 225;
   me._Helper = Helper.new();
   me._Cnt = cnt; # for which graph.
   me._Dialog=canvas.Window.new([me._Width,me._Height]);
   me._Canvas=me._Dialog.createCanvas()
                        .setColorBackground(0.3,0.3,0.3,me._Transp);
   me._Root=me._Canvas.createGroup();
   me._Mnm = me._Root.createChild("text", "")
              .set("font","Helvetica.txf")
              .setFontSize(16, 1)
              .setTranslation(10, 20)
              .setColor(1,0,0) # Text color
              .setText(me._Cnt);
   me._Mnm = me._Root.createChild("text", "")
              .set("font","Helvetica.txf")
              .setFontSize(16, 1)
              .setTranslation(10, 40)
              .setColor(1,1,1) # Text color
              .setText("Tickmark on if above 0 
and set per 0.1 sec.");
   me._Mnm = me._Root.createChild("text", "")
              .set("font","Helvetica.txf")
              .setFontSize(16, 1)
              .setTranslation(10, 105)
              .setColor(1,1,1) # Text color
              .setText("Sample Frequency:
1 Sample per N*0.1 sec.");
   me._Mnm = me._Root.createChild("text", "")
              .set("font","Helvetica.txf")
              .setFontSize(16, 1)
              .setTranslation(10, 170)
              .setColor(1,1,1) # Text color
              .setText("Plot speed:
Stepsize N per 0.1 sec.");
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
   # Yes, a text input
   me._Txt[0] = Text.new().Setup(me._Root,(me._Width/2)-25,65,50,20,0);
   a = me._Txt[0].getGlass();
   (func {
         a.addEventListener("click", func (e) { me.TextIn(e.button,0); });
   })();
   me._Txt[1] = Text.new().Setup(me._Root,(me._Width/2)-25,130,50,20,0);
   a = me._Txt[1].getGlass();
   (func {
         a.addEventListener("click", func (e) { me.TextIn(e.button,1); });
   })();
   me._Txt[2] = Text.new().Setup(me._Root,(me._Width/2)-25,190,50,20,0);
   a = me._Txt[2].getGlass();
   (func {
         a.addEventListener("click", func (e) { me.TextIn(e.button,2); });
   })();
   # Exit button 
   me._Butt = Button.new().Setup(me._Root,me._Width-20,5,15,15,"X");
   var a = me._Butt.getGlass();
   (func {
      # Delete on any mouse button
      a.addEventListener("click", func (e) { me.Del(); });
   })();
   # place window a little right/down parent
   var Sx = me._Dialog.get("tf/t[0]");
   var Sy = me._Dialog.get("tf/t[1]");
   me._Dialog.set("tf/t[0]",Sx + 25);
   me._Dialog.set("tf/t[1]",Sy + 25);
   return me;
};

Mark.TextIn = func (mb,f) {
   me._Txt[f].SetColor(1);
   var Number =0;
   var ONumber =0; # This number should be taken from Pgraph !
   if( mb == 0 ){
      #print("Mark.TextIn called.");
      if(me._Listener ==  0){
          me._Listener = setlistener("/devices/status/keyboard/event", func(event) {
                if (!event.getNode("pressed").getValue())
                    return;
                var key = event.getNode("key");
                var C = key.getValue();
                key.setValue(-1);           # drop key event
                #printf("code %d == %s",C,chr(C));
                if(C == 8){
                   Number = "";
                   me._Txt[f].Settext(s#printf("%8.2e",Number));
                   return me;
                };
                if(C == 10){  #Return pressed
                   removelistener(me._Listener);
                   #print("Mark.TextIn Inactive.");
                   me._Listener =0;
                   if(Number<0 or Number == "")Number=ONumber;
                   #me._Ofact[l].Settext(Number);
                   me._Txt[f].Settext(s#printf("%8.2e",Number));
                   me._Txt[f].SetColor(0);
                   if(f == 0) me._Caller.SetTick(Number);
                   if(f == 1) me._Caller.SetUpdsdp(Number);
                   if(f == 2) me._Caller.SetStep(Number);
                   return me;
                }
                if((C >= 48 and C <= 57) or C == 46){
                   #var shift = event.getNode("modifier/shift").getValue();
                   #if (handle_key(key.getValue(), shift))
                   Number = Number ~ chr(C);

                   #me._Ofact[l].Settext(Number);
                   me._Txt[f].Settext(s#printf("%8.2e",Number));
                   #printf("code %d == %s result == %d",C,chr(C),Number);
                   return me;
                };
             });
      };
   };
   return me;
}

Mark.Del = func () {
   gui.popupTip(s#printf("Mark.Del called"),2);
   me._Caller._Marker = 0;
   me._Dialog.del();
};
