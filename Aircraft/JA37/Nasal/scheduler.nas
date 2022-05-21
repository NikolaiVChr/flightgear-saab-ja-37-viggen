var input = {
    time:   "sim/time/elapsed-sec",
};

foreach (var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}


# Period of the scheduler loop.
# All other loop periods are a multiple of this.
var SCHEDULER_RATE = 0.033;  # 30 Hz

# Scheduled loops. A loop is a hash with members
#   period:     the loop period (unit SCHEDULER_RATE)
#   offset:     time offset to run this loop, with 0 <= offset < period (unit SCHEDULER_RATE)
#   function:   the actual loop, a function object
#   self:       (optional) 'me' reference for function call
#   arg_dt:     (default 0) bool, if true the function receives a single argument
#               which is the time (sec) since its last execution
#   name:       (optional) a name used for debugging
#
# Within the same scheduler loop, functions to be executed are run in the order of the following array.

# Array is created in init_loops() (it can't be done at load time as all other files need to be loaded first).
var loops = [];

var init_loops = func {
    # Loops are organised in cycles of 32 iterations.
    # -- 15Hz each
    # |- all fast loops
    # |--- 3.75Hz each
    #   |- generic medium + modes + displays common + sight + testing + landing mode
    #   |- MI
    #   |- TI
    #   |--- ~2Hz each
    #     |- flightplans
    #     |--- ~1Hz each
    #       |- generic slow
    #       |- datapanel, datalink, failure
    #
    loops = [
        { period: 2, offset: 0, function: ja37.saab37.speed_loop, self: ja37.saab37, name: "ja37-fast", },
        { period: 2, offset: 0, function: displays.common.loopFast, self: displays.common, name: "common-fast", },
        { period: 2, offset: 0, function: hud.update, name: "HUD", },
        { period: 8, offset: 1, function: ja37.saab37.update_loop, self: ja37.saab37, name: "ja37-medium", },
        { period: 8, offset: 1, function: modes.update, name: "modes", },
        { period: 8, offset: 1, function: displays.common.loop, self: displays.common, name: "common-slow", },
        { period: 8, offset: 1, function: land.lander.loop, self: land.lander, name: "landing-mode", },
        { period: 8, offset: 1, function: testing.loop, name: "test", },
        { period: 32, offset: 15, function: ja37.saab37.slow_loop, self: ja37.saab37, name: "ja37-slow", arg_dt: 1, },
        { period: 32, offset: 31, function: failureSys.loop_fire, name: "Failure", },
        { period: 32, offset: 31, function: hud.loop_slow, name: "HUD-slow", },
    ];

    if (variant.JA) {
        append(loops,
            { period: 2, offset: 0, function: TI.ti.loopFast, self: TI.ti, name: "TI-fast", },
            { period: 2, offset: 0, function: MI.mi.loopFast, self: MI.mi, name: "MI-fast", },
            { period: 8, offset: 1, function: sight.loop, name: "sight", },
            { period: 8, offset: 3, function: MI.mi.loop, self: MI.mi, name: "MI", },
            { period: 8, offset: 5, function: TI.ti.loop, self: TI.ti, name: "TI", },
            { period: 16, offset: 7, function: route.Polygon.loop, self: route.Polygon, name: "Plans", },
            { period: 32, offset: 31, function: dap.loop_main, name: "DAP", },
            { period: 32, offset: 31, function: fighterlink.loop, name: "datalink", },
            { period: 2048, offset: 0, function: TI.ti.loopSlow, self: TI.ti, name: "TI-slow", }
        );
    } else {
        append(loops,
            { period: 1, offset: 0, function: ci.loop, name: "CI", },
            { period: 4, offset: 3, function: radar.loop, name: "PS37", }
        );
    }
};


var iteration = 0;

var scheduler_loop = func {
    # Timing code
    #var g_t1 = systime();

    var time = input.time.getValue();
    var args = [];
    var self = nil;
    var err = [];

    foreach (var loop; loops) {
        # Timing code
        #var t1 = systime();

        if (math.mod(iteration, loop.period) != loop.offset) continue;

        if (loop["arg_dt"]) {
            if (contains(loop, "last_time")) {
                args = [time - loop.last_time];
            } else {
                # Fake dt for first loop
                args = [SCHEDULER_RATE * loop.period];
            }
            loop.last_time = time;
        } else {
            args = nil;
        }

        self = contains(loop, "self") ? loop.self : nil;
        err = [];
        call(loop.function, args, self, nil, err);
        if (size(err)) {
            debug.printerror(err);
        }

        # Timing code
        #var t2 = systime();
        #time = (t2-t1) * 1000;
        #setprop("timings/now-"~loop.name, time);
        #setprop("timings/avg-"~loop.name, 0.1*time + 0.9*(getprop("timings/avg-"~loop.name) or 0));
    }

    iteration += 1;

    # Timing code
    #var g_t2 = systime();
    #printf("scheduler loop %2d, time %4.1f", math.mod(iteration, 32), (g_t2-g_t1)*1000);
}

var scheduler_timer = maketimer(SCHEDULER_RATE, scheduler_loop);


var start = func {
    init_loops();
    scheduler_timer.start();
};
