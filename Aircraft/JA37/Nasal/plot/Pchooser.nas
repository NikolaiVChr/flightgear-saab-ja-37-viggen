Chooser = {};

############################################################
##
## All members of Choosser.
##

# use: Chooser.new(parent,Linenumber)
 # Bound to the calling menu, multiple can exist
Chooser.new = func(x,l) {
   var me = {parents : [Chooser],
      _Caller: 0,    # remember caller
      _Line: 0,      # remember line
      _Dialog: 0,
      _Canvas: 0,
      _Root: 0,
      _Width: 275,
      _Height: 16*28+10+10+20,
      _Light: "#FFFFFF",
      _Dark: "#000000",
      _Field: 0,
      _List: [],   # Found items
      _Obns: [0],
      _items: 0,   # Amount of items
      _Show: 0,	   # current item as 0 in textfields
      _Cur: 0,     # Current path
      _Path: "/",  # Path displayed in head
      _Txf: [],   # Textfields in Field
      _Transp: 1,
      _Helper: 0,  # Handle to helper functions
   };
   me._Caller = x;
   me._Line = l;
   return me;
};

Chooser.init = func() {
   #printf("Chooser.init called");
   me._Helper = Helper.new();
   me._Dialog=canvas.Window.new([me._Width,me._Height]);
   me._Canvas=me._Dialog.createCanvas()
                        .setColorBackground(0.3,0.3,0.3,me._Transp);
   me._Root=me._Canvas.createGroup();
   # Chooser Area must be movable
   (func {
      me._Canvas.addEventListener("drag", func (e) { me._Dialog.move(e.deltaX, e.deltaY); });
   })();
#   # Chooser Area must be deleteble
#   (func {
#      me._Canvas.addEventListener("dblclick", func () { me._Dialog.del(); });
#   })();
   # Chooser Area must click for chosen value
   (func {
      me._Canvas.addEventListener("click", func (e) { me.Chose(e.clientY,e.button); });
   })();
   # Chooser Area must be scrollable
   (func {
      me._Canvas.addEventListener("wheel", func (e) { me.Filltext(e.deltaY); });
   })();
   var x = 0;
   var y = 0;
   var w = me._Width;
   var h = me._Height;
   # 3-D Effect line
   me._Above = me._Root.createChild("path", "data")
              .set("stroke-width", 1)
              .setColor(me._Light)
              .moveTo(x,h+y)
              .lineTo(x,y)
              .lineTo(x+w,y);
   # 3-D Effect line
   me._Below = me._Root.createChild("path", "data")
              .set("stroke-width", 1)
              .setColor(me._Dark)
              .moveTo(x,h+y)
              .lineTo(x+w,h+y)
              .lineTo(x+w,y);
   me._Path = me._Root.createChild("text","")
              .set("font","Helvetica.txf")
              .setFontSize(16, 1)
              .setColor("#00FF00")
              .setText(me._Line ~":"~ me._Path)
              .setTranslation(10, 20);
#              .setAlignment("center")
   # Exit button 
   me._Obns[0] = Button.new().Setup(me._Root,me._Width-22,8,15,15,"X");
   var a = me._Obns[0].getGlass();
   (func {
      # Delete on any mouse button
      a.addEventListener("click", func (e) { me._Del(); });
   })();
   var x = 10;
   var y = 30;
   var w = me._Width - 20;    # Width - 2*Border
   var h = me._Height - 40;   # Height - Border+Header
   var th = 20;               # Height of textfield
   var ts = 2;                # Spacing textfields
   var tsh = th + ts;
   #printf("Expect textfields = %d ",h/tsh);
##
## WARNING, When spacing is to small, colors become waterpaintcolor
##          Strange artifacts.
   var j = 0;
   for( var i = 0 ; i < 16 ; i += 1 ){  # 10 ==border 30 ==border+header
      append(me._Txf, Text.new().Setup(me._Root,10,j*28+30,w,20));
      me._Txf[j].Settext("+");
      j += 1;
      #printf("textfields = %d",(i / tsh));
   };
   return me;
};

Chooser.run = func(n) {
   #printf("Chooser.run called");
   #printf("size(me._Txf) == %d",size(me._Txf));
   # get children and put in list 
   me.Filllist(n);
   #printf("size(me._Txf) == %d",size(me._Txf));
   # Clear textfields
   me.clr();
   # get items and put in Text 
   me.Filltext(0);
   return me;
};

# Interupt function on click
Chooser.Chose = func(y,b) {
   #printf("Chooser.Chose called %d",y);
   if( b == 0 ){     
      var selected = int((y-22) /28);
      var item = selected + me._Show;
#      gui.popupTip(s#printf("Chosen == %s",me._List[item]),1);
      t = "NONE";
      if(me._List[item] != "..")
        var t = props.globals.getNode(me._List[item]).getType();
      gui.popupTip(s#printf("Chosen == %s type %s",me._List[item],t),1);
      #printf("Chosen == %s",t);
      #printf("Number shown %d Number in list %d",int((y-22) /28),item);
      if(t == "NONE"){ # must be a dir chosen
         var n = me._List[item];
         if(n == "..") n = io.dirname(me._Cur);
         me._Cur = n;
         me._Path.setText(me._Line ~":"~ me._Helper.FitString(me._Cur,25));
         me.run(me._Cur);
      }else{ # valid prop chosen
         me._Txf[selected].SetColor(1);
         me._Caller.SetProp(me._Line,me._List[item]);
         settimer(func () { me._Txf[selected].SetColor(0)} , 0.5);
      };
   };
   return me;
};

Chooser.clr = func () {
   #printf("Chooser.clr called");
   # clear fields
   ##printf("size(me._Txf) == %d",size(me._Txf));
   me._Txf[0].Settext("..");
   for(i = 1 ; i < size(me._Txf) ; i += 1) me._Txf[i].Settext(" - ");
   return me;
};

# Put a batch of items in the text-fields and scoll routine
Chooser.Filltext = func (s) {
   #printf("Chooser.Filltext called, scroll %f",s);
   #printf("me._Txf[0] == %s",me._Txf[0]);
   var cnt = size(me._Txf);
   me._Show -= s;
   if(me._Show < 0)me._Show = 0;   # Up movement
   if(size(me._List) < (cnt+me._Show))me._Show += s;
   if(size(me._List) <= cnt)me._Show = 0;
   for( var i = 0 ; i < (cnt) ; i += 1){
         #printf("i %d cnt % d items %d",i,cnt,me._items);
      if(i < me._items){
         me._Txf[i].SetColor(0);
         me._Txf[i].Settext(io.basename(me._List[me._Show+i]));
      };
   };
   return me;
};

# Get all item in this path into the list
Chooser.Filllist = func (n) {
   #printf("Chooser.Filllist called");
   me._List = [];
   append(me._List,"..");
   #printf("New fill 1-e == %s",me._List[0]);
   me._items = 1;
   # get node name of path
   if( n == nil ){
      var node = props.globals;
   }else {
      if(n == "..") n = io.dirname(me._Cur);
      #printf("Brows => %s ",n);
      var node = props.globals.getNode(n);
   };
   # get children and put in list and on screen
   var children = node.getChildren();
   foreach(c; children) { 
     if( c != nil ) {
       #printf("type %s size %d ", typeof(c), size(c) ); 
       t = c.getType();
       # Only plottable values
       #printf("Type %s == ", t ); 
       if(t == "NONE"){
          append(me._List,c.getPath() ~ "/");
          me._items += 1;
       };
       if(t == "DOUBLE" or t == "INT" or t == "BOOL" or
          t == "double" or t == "int" or t == "bool" ){
          append(me._List,c.getPath());
          me._items += 1;
       };
     };
   };
   me._Show = 0;
   #printf("Items found == %d",me._items);
   return me;
};

## Fitstring in 3 classes ! should be more general helper function
#Chooser.FitString = func (s,n) {
#   #printf("Chooser.FitString called with %s",s);
#   if ( size(""~s~"") < n ) return s;
#   var l = substr(s, 0, (n - 2) / 3);
#   var r = substr(s, size(s) + size(l) + 3 - n);
#   return l ~ "..." ~ r;
#};

Chooser._Del = func () {
   me._Caller.Deselect(me._Line);  
   me._Dialog.del();
   return me;
};
