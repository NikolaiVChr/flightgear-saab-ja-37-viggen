canvas.Text._lastText2 = "";
canvas.Text.setText = func (text)
  {
      if (text == me._lastText2) {return me;}
      me._lastText2 = text;
      me.set("text", typeof(text) == 'scalar' ? text : "");
      me;
  };
canvas.Element._lastVisible = 1;
canvas.Element.show = func ()
  {
      if (1 == me._lastVisible) {return me;}
      me._lastVisible = 1;
      me.setBool("visible", 1);
    };
canvas.Element.hide = func ()
  {
      if (0 == me._lastVisible) {return me;}
      me._lastVisible = 0;
      me.setBool("visible", 0);
    };