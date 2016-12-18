Lines = {};

############################################################
##
## All members of Lines.  Just This line !
##

# use: Lines.new(parent) parent to use for talk-back
Lines.new = func (x) {
   var me = { parents : [Lines] ,
      _Caller: 0,
      _Color: "#FF0000",
      _Width: 1,
      _Property: "/autopilot/settings/heading-bug-deg",
      _Factor: -1,
      _Max: 10,
      _Enabled: 1,
      _Plottable: 0, # Enabled and valid Property
      _Path: 0,
   };
   me._Caller = x;
   me._Max = (me._Caller.GetCpos());
   #printf("me._Max == %f",me._Max);
   me._Path = me._Caller._Root.createChild("path", "data");
   return me;
};

Lines.SetColor = func (x) {
   me._Path.set("stroke", x);
   me._Color=x;
   return me;
};

Lines.GetColor = func () {
   return me._Color;
};

Lines.SetWidth = func (x) {
   me._Path.set("stroke-width", x);
   me._Width=x;
   return me;
};

Lines.GetWidth = func () {
   return me._Width;
};

Lines.GetPath = func () {
   gui.popupTip("Lines.GetPath has been called",4);
   return me._Path;
};

Lines.SetProperty = func (x) {
# Add new line is neccessary , done in Menu.OpenChsr
#   if(me._Caller._LineCnt == x)me._Caller.AddLine();
   me._Property = x;
   if(size(me._Property)>1 and me._Enabled==1)
      me._Plottable = 1;
   else
      me._Plottable = 0;
   return me;
};

Lines.GetProperty = func () {
   return me._Property;
};

# This is a calculated factor,  Top versus +yRange
Lines.SetFactor = func (x) {
   me._Factor = x;
   return me;
};

Lines.GetFactor = func () {
   gui.popupTip("Lines.GetFactor called",1);
   return me._Factor;
};

Lines.SetTop = func (x) {
   me._Factor = -1*(me._Max/x);
   #printf("Lines.SetTop me._Max %f me._Factor %f",me._Max,me._Factor);
   return me;
};

Lines.GetTop = func () {
   gui.popupTip("Lines.GetTop called",1);
   return -1*(me._Max/me._Factor);
};

# Force this line on (1) or off (0)
Lines.Enable = func (x) {
   me._Enabled = x;
   if(size(me._Property)>1 and me._Enabled==1)
      me._Plottable = 1;
   else
      me._Plottable = 0;
   return me;
};

# This might have better be named as GetEnabled ?
Lines.GetStatus = func () {
   return me._Enabled;
};

