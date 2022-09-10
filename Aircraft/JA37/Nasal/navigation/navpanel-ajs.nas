### Waypoint selection buttons for AJ(S)

var nav_button = func(n) {
    route.set_current(route.WPT.B | n);
}

var ls_button = func {
    route.set_current(route.WPT.LS);
}

var l_button = func {
    if (route.get_current_idx() == route.WPT.L1) {
        route.set_current(route.WPT.L2);
    } else {
        route.set_current(route.WPT.L1);
    }
}
