### Waypoint selection buttons for AJ(S)

var nav_button = func(n) {
    if (route.is_set(route.WPT.U | n)) {
        # There is a popup point defined here.
        # If we are before it in the route order, select it.

        var idx = route.get_current_idx();
        var nb = idx & route.WPT.nb_mask;
        var type = idx & route.WPT.type_mask;

        if (idx == route.WPT.LS or (nb < n and (type == route.WPT.B or type == route.WPT.U))) {
            route.set_current(route.WPT.U | n);
            return;
        }
    }

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
