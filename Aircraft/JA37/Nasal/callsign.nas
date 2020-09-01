var signText = nil;
var callInit = func {
  canvasCallsign = canvas.new({
        "name": "Callsign",
        "size": [128, 16],
        "view": [128, 16],
        "mipmapping": 1
  });
      
  canvasCallsign.addPlacement({"node": "Callsign", "texture": "alu.png"});
  canvasCallsign.setColorBackground(0.10, 0.10, 0.10, 1.00);

  callsignGroup = canvasCallsign.createGroup();
  callsignGroup.show();

  signText = callsignGroup.createChild("text")
        .setFontSize(15, 1)
        .setColor(0.85,0.85,0.85, 1)
        .setAlignment("center-center")
        .setTranslation(64, 8);
};

var loop_callsign = func {

    var callsignTxt = props.globals.getNode("/sim/multiplay/callsign").getValue();

    if (callsignTxt != "callsign") {
      signText.setText(callsignTxt);
    } else {
      signText.setText("");
    }
};
