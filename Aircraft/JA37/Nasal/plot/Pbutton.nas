Button = {};

############################################################
##
## All members of Button.
##

Button.new = func () {
   var me = {parents : [Button],
      _Caller: 0,
      _Enabled: 1,
      _Text: 0,
      _Butt: 0,
      _Above: 0,
      _Below: 0,
      _Light: "#FFFFFF",
      _Dark: "#000000",
      _Glass: 0,
      _x: 0,
      _y: 0,
      _w: 0,
      _h: 0,
   };
   return me;
};
 
Button.Setup = func (r,x,y,w,h,t) {
   me._x = x;
   me._y = y;
   me._w = w;
   me._h = h;
   me._Caller = r;
   var ox = x+((w - (7 * size(t))) /2);
   var oy = y+(h-((h-9)/2));
   me._Text = r.createChild("text", "")
              .set("font","Helvetica.txf")
              .setFontSize(16, 1)
              .setColor("#FFFFFF")
              .setTranslation(ox, oy)
              .setAlignment("center")
              .setText(t);
   me._Butt = r.createChild("path", "data")
              .setColor("#999999")
              .set("stroke-width", 1)
              .moveTo(x,y)
              .lineTo(x,h+y)
              .lineTo(x+w,h+y)
              .lineTo(x+w,y)
              .close();
   # 3-D Effect line
   me._Above = r.createChild("path", "data")
              .set("stroke-width", 1)
              .setColor(me._Light)
              .moveTo(x,h+y)
              .lineTo(x,y)
              .lineTo(x+w,y);
   # 3-D Effect line
   me._Below = r.createChild("path", "data")
              .set("stroke-width", 1)
              .setColor(me._Dark)
              .moveTo(x,h+y)
              .lineTo(x+w,h+y)
              .lineTo(x+w,y);
   # Clickable field
   me._Glass = r.createChild("path", "data")
              .setColor("#00000000") # just transparent
              .set("stroke-width", 0)
              .moveTo(x,y)
              .lineTo(x,h+y)
              .lineTo(x+w,h+y)
              .lineTo(x+w,y)
              .close();
   (func {
      #var a = me._Down();
      me._Glass.addEventListener("mousedown", func (e) { me._Down(); })
   })();
   (func {
      #var a = me._Up();
      me._Glass.addEventListener("mouseup", func (e) { me._Up(); })
   })();
#   (func {
#      var a = f;
#      me._Glass.addEventListener("click", func (e) { f(e.button); })
#   })();
   return me;
}

Button.SetText = func (t) {
   var ox = me._x+((me._w - (7 * size(t))) /2);
   var oy = me._y+(me._h-((me._h-9)/2));
   me._Text.setText(t).setTranslation(ox, oy);
   return me;
};

Button.getGlass = func () {
   return me._Glass;
};

Button._Down = func () {
   me._Below.setColor(me._Light);
   me._Above.setColor(me._Dark);
   if(me._Enabled)me._Text.setColor("#FFFF00");
};

Button._Up = func () {
   me._Above.setColor(me._Light);
   me._Below.setColor(me._Dark);
   me._Text.setColor(me._Light);
};

