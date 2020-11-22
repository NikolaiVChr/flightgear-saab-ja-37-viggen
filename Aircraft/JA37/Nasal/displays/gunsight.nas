#### Nasal interface to the AFALCOS gunsight implemented in JSBSim

var input = {
    elev_pri:   "/instrumentation/gunsight/elevation-mil",
    azi_pri:    "/instrumentation/gunsight/azimuth-mil",
    elev_sec:   "/instrumentation/gunsight/secondary-elevation-mil",
    azi_sec:    "/instrumentation/gunsight/secondary-azimuth-mil",
    dist:       "/instrumentation/gunsight/distance-m",
    dist_tgt:   "/instrumentation/gunsight/target-distance-m",
    use_tgt:    "/instrumentation/gunsight/use-target-distance",
};

foreach (var prop; keys(input)) {
    input[prop] = props.globals.getNode(input[prop]);
}

# Update loop, simply to feed distance to the JSBSim system.
var loop = func {
    if (radar_logic.selection != nil) {
        input.use_tgt.setValue(1);
        input.dist_tgt.setValue(radar_logic.selection.get_range() * NM2M);
    } else {
        input.use_tgt.setValue(0);
    }
}

var get_position = func {
    return [input.azi_pri.getValue(), -input.elev_pri.getValue()];
}

var get_secondary_position = func {
    return [input.azi_sec.getValue(), -input.elev_sec.getValue()];
}
