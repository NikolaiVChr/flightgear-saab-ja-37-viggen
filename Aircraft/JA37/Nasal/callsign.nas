var theInit = setlistener("sim/ja37/supported/initialized", func {
  if(getprop("sim/ja37/supported/radar") == 1) {
    removelistener(theInit);
    callInit();
  }
}, 1, 0);

var callInit = func {
  canvasCallsign = canvas.new({
        "name": "Callsign",
        "size": [128, 16],
        "view": [128, 16],
        "mipmapping": 0
  });
      
  canvasCallsign.addPlacement({"node": "Callsign", "texture": "button-empty.png"});
  canvasCallsign.setColorBackground(1.00, 1.00, 1.00, 0.00);

  callsignGroup = canvasCallsign.createGroup();
  callsignGroup.show();

  var signText = callsignGroup.createChild("text")
        .setText("")
        .setFontSize(15, 1)
        .setColor(1,1,1, 1)
        .setAlignment("center-center")
        .setTranslation(64, 8);

  var loop_callsign = func {

    var callsign = props.globals.getNode("/sim/multiplay/callsign").getValue();

    if (callsign != "callsign") {
      signText.setText(callsign);
    } else {
      signText.setText("");
    }

    settimer(loop_callsign, 1);
  }
  loop_callsign();
}