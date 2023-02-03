# Sometimes, half of the code everywhere breaks because
# something somewhere overwrites the function 'globals.str()'
# (probably due to some shitty code with a missing 'var').
#
# I checked throughout the Viggen, and found nothing like that.
# Also, the issue is rare and hard to reproduce, which makes me
# think it might be triggered by nasal code in an MP model,
# or something in that style.
#
# This is a very stupid way to try to gather more information about this.

var warning_window = screen.window.new(x:nil, y:nil, autoscroll:0);

var check_str_loop = func {
    if (typeof(str) == "func")
        return;

    logprint(LOG_ALERT, "In namespace 'str_debug', function 'str()' has been overwritten by (dump below): "~str);
    debug.dump(str);

    # Correct the function, I'm not a monster.
    globals.str = func(x) { return ""~x; }

    # But big old warning because I don't want this to go unnoticed.
    warning_window.write("Function 'globals.str' has been overwritten by some shitty code.", 1, 0, 0);
    warning_window.write("Please report this bug with the log file.", 1, 0, 0);
    settimer(func { warning_window.clear(); }, 10);

    # Because MP models are one of my suspects
    logprint(LOG_ALERT, "Context: MP models");
    foreach (var node; props.globals.getNode("ai/models").getChildren("multiplayer")) {
        logprint(LOG_ALERT, "   "~node.getValue("sim/model/path"));
    }
    logprint(LOG_ALERT, "End of MP list");

    logprint(LOG_ALERT, "Context: radar contacts");
    foreach (var contact; radar.get_complete_list()) {
        logprint(LOG_ALERT, "   "~contact.getModel());
    }
    logprint(LOG_ALERT, "End of radar list");

    # And addons are another
    logprint(LOG_ALERT, "Context: loaded addons");
    foreach (var id; keys(addons._modules)) {
        logprint(LOG_ALERT, "    "~id);
    }
    logprint(LOG_ALERT, "End of addons list");
}

var t = maketimer(1, check_str_loop);
t.start();
