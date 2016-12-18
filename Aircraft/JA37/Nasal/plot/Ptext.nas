Text = {};

############################################################
##
## All members of Text.
##

Text.new = func () {
   var me = {parents : [Text],
      _Text: 0,
      _Contend: "",
      _Field: 0,
      _Glass: 0, # To make it clickable
      _Above: 0,
      _Below: 0,
      _Light: "#FFFFFF",
      _Dark: "#000000",
   };
   return me;
};

Text.Setup = func (r,x,y,w,h,t = "----") {
#   var ox = x+((w - 10 * size(t)) /2);
   var ox = x+2;
   var oy = y+(h-((h-9)/2));
   me._Field = r.createChild("path", "data")
              .setColorFill("#FFA500")
              .set("stroke-width", 1)
              .moveTo(x,y)
              .lineTo(x,h+y)
              .lineTo(x+w,h+y)
              .lineTo(x+w,y)
              .close();
   # 3-D Effect line
   me._Above = r.createChild("path", "data")
              .set("stroke-width", 1)
              .setColor(me._Dark)
              .moveTo(x,h+y)
              .lineTo(x,y)
              .lineTo(x+w,y);
   # 3-D Effect line
   me._Below = r.createChild("path", "data")
              .set("stroke-width", 1)
              .setColor(me._Light)
              .moveTo(x,h+y)
              .lineTo(x+w,h+y)
              .lineTo(x+w,y);
   me._Text = r.createChild("text", "")
              .set("font","Helvetica.txf")
              .setFontSize(16, 1)
              .setColor("#000000")
              .setTranslation(ox, oy)
              .setAlignment("center")
              .setText(t);
   # Clickable field
   me._Glass = r.createChild("path", "data")
              .setColorFill("#FFFFFF00")
              .set("stroke-width", 1)
              .moveTo(x,y)
              .lineTo(x,h+y)
              .lineTo(x+w,h+y)
              .lineTo(x+w,y)
              .close();
   return me;
};

Text.getGlass = func () {
   return me._Glass;
};

Text.Settext = func (x) {
   #printf("Text.Settext called == %s",x);
   me._Text.setText(x);
   me._Contend = x;
   return me;
};

Text.Gettext = func () {
   return me._Contend;
};

# Give background the colr of the line
Text.SlotColor = func (c,x) {
   #printf("Text.SlotColor called == %d",x);
   me._Field.setColorFill(c._Lns[x].GetColor());
   return me;
};

# Highlight
Text.SetColor = func (x) {
   #printf("Text.SetColor called == %d",x);
   if(x == 0) me._Field.setColorFill("#FFA500");
   if(x == 1) me._Field.setColorFill("#00A500");
   if(x == 2) me._Field.setColorFill("#555555");
   return me;
};


