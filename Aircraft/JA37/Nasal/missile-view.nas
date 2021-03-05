#### Missile following view - only used for ejection seat.

var missile_view_name = "Ejection view";
var missile_view_index = 111;
var missile_view_config_node =
    props.globals.getNode("/sim", 1)
    .getChild("view", missile_view_index, 1)
    .getNode("config", 1);


# Set the view to follow an AI model.
# Argument: the path to this AI model root property as a string.
var setup_missile_view = func(ai_path) {
    missile_view_config_node.setValues({
      "eye-heading-deg-path": ai_path ~ "/orientation/true-heading-deg",
      "target-lat-deg-path": ai_path ~ "/position/latitude-deg",
      "target-lon-deg-path": ai_path ~ "/position/longitude-deg",
      "target-alt-ft-path": ai_path ~ "/position/altitude-ft",
      "target-heading-deg-path": ai_path ~ "/orientation/true-heading-deg",
      "target-pitch-deg-path": ai_path ~ "/orientation/pitch-deg",
      "target-roll-deg-path": ai_path ~ "/orientation/roll-deg",
    });
}

var view_firing_missile = func(missile) {
    setup_missile_view(missile.ai.getPath());
    view.setViewByIndex(missile_view_index);
}
