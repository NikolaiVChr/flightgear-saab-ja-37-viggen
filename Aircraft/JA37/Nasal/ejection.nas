var eject = func () {
    if (getprop("ja37/done")==1) {
        return;
    }
    setprop("ja37/done",1);
    var es = armament.AIM.new(10, "es", "gamma");
    setprop("fdm/jsbsim/fcs/canopy/hinges/serviceable", 0);
    es.releaseAtNothing();
    view.view_firing_missile(es);
    #setprop("sim/view[0]/enabled",0);
    settimer(func {crash.exp();},3.5);
}

var n_repeat = 3;
var repeat = 0;

var repeat_timer = maketimer(1, func { repeat = 0; });
repeat_timer.singleShot = 1;

var eject_key = func () {
    repeat += 1;
    repeat_timer.start();
    if(repeat >= n_repeat) eject();
}
