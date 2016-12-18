
Save = {};

############################################################
##
## All members of Save.
##

# use: Save.new(parent) parent needed to call-back
Save.new = func (x,cnt) {
   var me = { parents : [Save] ,
      _Caller: 0, # need to reset _Save, double menu prevention.
      _Cl: 0,     # Curent line
      _Width: 0,
      _Height: 0,
      _Dialog: 0,
      _Canvas: 0,
      _Transp: 1,
      _Root: 0,
      _Cnt: 0,  # Number to correspond withe graph number
      _Show: 0, # Position for scrolllist
      _Mnm: [],
      _Light: "#FFFFFF",
      _Dark: "#000000",
      _Above: [0,1],
      _Below: [0,1],
      _Box: 0,
      _Listener: [0],           # 1 keyboard listener
      _ToRead: [],
      # Objects == buttons textfields etc.
      _Obns: [0,0],
      _Rtxt: [],     # files in directory
      _Otxt: [0,0,0,0,0,0],     # Input text/Selected text
      _Helper: 0,               # handle to helper functions
   };
   me._Caller = x;
   me._Cnt = cnt;
   #printf("Save.new called with number %d",me._Cnt);
   return me;
}

Save.init = func () {
   me._Width = 150;
   me._Height = 10*20+70;
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
   me._Above[0] = me._Root.createChild("path", "data")
              .set("stroke-width", 1)
              .setColor(me._Light)
              .moveTo(x,h+y)
              .lineTo(x,y)
              .lineTo(x+w,y);
   # 3-D Effect line
   me._Below[0] = me._Root.createChild("path", "data")
              .set("stroke-width", 1)
              .setColor(me._Dark)
              .moveTo(x,h+y)
              .lineTo(x+w,h+y)
              .lineTo(x+w,y);
   # Save Area must be movable
   (func {
      me._Canvas.addEventListener("drag", func (e) { me._Dialog.move(e.deltaX, e.deltaY); });
   })();
   # Serial indicator
   append(me._Mnm, me._Root.createChild("text", "")
              .set("font","Helvetica.txf")
              .setFontSize(16, 1)
              .setTranslation(10, 20)
              .setColor(1,0,0) # Text color
              .setText(me._Cnt)
   );
   # Saving indicator
   append(me._Mnm , me._Root.createChild("text", "")
              .set("font","Helvetica.txf")
              .setFontSize(16, 1)
              .setTranslation(35, 20)
              .setColor(0,1,0) # Text color
              .setText("Saving.")
   );
   # Input textfield or selected text ( filename )
   me._Otxt[0] = Text.new().Setup(me._Root,10,30,me._Width-20,20);
   var a = me._Otxt[0].getGlass();
   (func {
      a.addEventListener("click", func (e) { me.TextIn(e.button,e.deltaY,e.deltaX); });
   })();
   var offset = 10;
   # Go Save button 
   me._Obns[0] = Button.new().Setup(me._Root,me._Width-50,offset,15,15,">");
   var a = me._Obns[0].getGlass();
   (func {
      a.addEventListener("click", func (e) { me.Go(); });
   })();
   # Exit button 
   me._Obns[1] = Button.new().Setup(me._Root,me._Width-25,offset,15,15,"X");
   var a = me._Obns[1].getGlass();
   (func {
      # Delete on any mouse button
      a.addEventListener("click", func (e) { me.Del(1); });
   })();
   # Box for filenames
   me._Box = me._Root.createChild("path", "data")
              .setColorFill("#FFA500")
              .set("stroke-width", 1)
              .moveTo(x+10,y+60)
              .lineTo(x+10,h-10)
              .lineTo(w-10,h-10)
              .lineTo(w-10,y+60)
              .close();
   # 3-D Effect line
   me._Above[1] = me._Root.createChild("path", "data")
              .set("stroke-width", 1)
              .setColor(me._Dark)
              .moveTo(x+10,h-10)
              .moveTo(x+10,y+60)
              .lineTo(w-10,y+60);
   # 3-D Effect line
   me._Below[1] = me._Root.createChild("path", "data")
              .set("stroke-width", 1)
              .setColor(me._Light)
              .moveTo(x+10,h-10)
              .lineTo(w-10,h-10)
              .lineTo(w-10,y+60);
   offset = 75;
   # Files for filenames from directory
   for(i = 0 ; i < 10 ; i += 1){
      append( me._Rtxt, me._Root.createChild("text", "")
              .set("font","Helvetica.txf")
              .setFontSize(16, 1)
              .setTranslation(15, offset)
              .setColor(0,0,0) # Text color
              .setText("")
      );
      offset += 20;
   };
   # The whole box is clickable as 1
   me._Glass = me._Root.createChild("path", "data")
              .setColor("#FFFFFFFF")
              .set("stroke-width", 0)
              .moveTo(x+10,y+60)
              .lineTo(x+10,h-10)
              .lineTo(w-10,h-10)
              .lineTo(w-10,y+60)
              .close();
   # Save Box has text to select
   (func {
      me._Glass.addEventListener("click", func (e) { me.Choice(e.clientY,e.button,e.deltaY,e.deltaX)});
   })();
   # Save Box has maybe more text
   (func {
      me._Glass.addEventListener("wheel", func (e) { me.Scroll(e.deltaY)});
   })();
   # place window a little right/down parent
   var Sx = me._Caller._Dialog.get("tf/t[0]");
   var Sy = me._Caller._Dialog.get("tf/t[1]");
   me._Dialog.set("tf/t[0]",Sx + 125);
   me._Dialog.set("tf/t[1]",Sy + 25);
   return me;
}; 

# Saves props etc into the proptree, to save with io.write_prop
Save.run = func () {
   for( var i = 0 ; i < 6 ; i += 1) {
      setprop("/sim/fgplot2/Lns["~i~"]",me._Caller._Lns[i]._Property);
      setprop("/sim/fgplot2/Color["~i~"]",me._Caller._Lns[i]._Color);
      setprop("/sim/fgplot2/Factor["~i~"]",me._Caller._Lns[i]._Factor);
      setprop("/sim/fgplot2/Width["~i~"]",me._Caller._Lns[i]._Width);
   };
   var FgHome = getprop("/sim/fg-home");
   var Files = directory(FgHome~"/state/");
#   var Files = directory(FgHome);  # just $FGHOME
   var pos =0;
   foreach(var a; Files){
      #printf("file: %s",a);
      pos = find(".xml",a);
      if(size(a)-4 == pos) {    # All with "\.xml$"
            append(me._ToRead, a);
      };
   };
   #printf("Found files == %d",size(me._ToRead));
   me._Cnt = size(me._ToRead); # Double used...
   var i = 0;
   foreach(var a; me._ToRead){
      #printf("Valid file %s",a);
      me._Rtxt[i].setText(a);
      i +=1 ;
      if(i == 10)break;
   };
   return me;
};

# Scroll the contend
Save.Scroll = func (y) {
   if(me._Cnt < 11) return me;  # nothing to scroll
   me._Show -= y;
   if(me._Show < 0)me._Show = 0;
   if(size(me._ToRead) < (10+me._Show))me._Show += y;
   if(size(me._ToRead) <= 10)me._Show = 0;
   for( var i = 0 ; i < (9) ; i += 1){
      me._Rtxt[i].setText(me._ToRead[me._Show+i]);
   };
   return me;
};

# select existing file y-Position, mousebutton and NO drag !?
# box is hard designed for 10 items.
Save.Choice = func (y,b,X,Y) {
   if((Y != 0) or ( X != 0) or (b != 0))return;
   var i = int((y-60)/20);
   #printf("position %d y == %d",i,y);
   me._Otxt[0].Settext(me._ToRead[i+me._Show]);
   return me;
};

#Save
Save.Go = func () {
   #printf("Props will be saved in %s",me._Otxt[0].Gettext());
   var FgHome = getprop("/sim/fg-home");
   var f = me._Otxt[0].Gettext();
   var filename = substr(f,0,size(f)-4);
   io.write_properties( FgHome~"/state/"~filename, "/sim/fgplot2" ); 
   me.Del(1);
   return me;
};

# Called TextIn, but does only numbers in !
Save.TextIn = func (but,x,y) {
   var Number = "";
   if((but == 0) and (x == 0) and (y == 0)){ # input when left mouse and no drag !?
   me._Otxt[0].SetColor(1);
   #print("Save.TextIn active.");
      if(me._Listener[0] ==  0){
      me._Listener[0] = setlistener("/devices/status/keyboard/event", func(event) {
                if (!event.getNode("pressed").getValue())
                    return;
                var key = event.getNode("key");
                var C = key.getValue();
                key.setValue(-1);           # drop key event
                #printf("code %d == %s",C,chr(C));
                if(C == 8){
                   Number = "";
                   me._Otxt[0].Settext(s#printf("%s.xml",Number));
                   return me;
                };
                if(C == 10){  #Return pressed
                   removelistener(me._Listener[0]);
   #print("Save.TextIn Inactive.");
                   me._Listener[0] =0;
                   me._Otxt[0].Settext(s#printf("%s.xml",Number));
                   me._Otxt[0].SetColor(0);
#                   me._Caller._Lns[l].SetTop(Number);
                   return me;
                }    
                if((C >= 13 and C <= 127) ){
                   #var shift = event.getNode("modifier/shift").getValue();
                   #if (handle_key(key.getValue(), shift))
                   Number = Number ~ chr(C);
                   me._Otxt[0].Settext(s#printf("%s.xml",Number));
                   #printf("code %d == %s result == %s",C,chr(C),Number);
                   return me;
                };
             });
      };
   };
   return me;
};
 
Save.Del = func (bt) {
   if(bt == 1){ # as if middle mouse is clicked ( Historical )
      me._Caller._Save = 0;
      me._Dialog.del();
   };
   return me;
};
