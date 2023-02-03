### Waypoint selection buttons for AJ(S)

var reset_input = func {
    bx_pendig = 0;
}

# Regular waypoints

var nav_button = func(n) {
    reset_input();

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

# Extra waypoints

var bx_pending = 0;

var bx_button = func {
    bx_pending = 1;
}

var dp_button = func(n) {
    if (!bx_pending) return;
    reset_input();

    if (n < 1 or n > 5) return;

    route.set_current(route.WPT.BX | n);
}

# Airbases

var ls_button = func {
    reset_input();

    route.set_current(route.WPT.LS);
}

var l_button = func {
    reset_input();

    if (route.get_current_idx() == route.WPT.L1) {
        route.set_current(route.WPT.L2);
    } else {
        route.set_current(route.WPT.L1);
    }
}
