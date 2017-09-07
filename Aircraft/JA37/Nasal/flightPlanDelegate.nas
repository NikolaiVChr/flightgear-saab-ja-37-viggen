# route_manager.nas -  FlightPlan delegate(s) corresponding to the built-
# in route-manager dialog and GPS. Intended to provide a sensible Viggen behaviour.

var RouteManagerDelegate = {
    new: func(fp) {
        var m = { parents: [RouteManagerDelegate] };
        m.flightplan = fp;
        return m;
    },

    departureChanged: func
    {
        printlog('info', 'saw departure changed');
        me.flightplan.clearWPType('sid');
        if (me.flightplan.departure == nil)
            return;

        if (me.flightplan.departure_runway == nil) {
        # no runway, only an airport, use that
            var wp = createWPFrom(me.flightplan.departure);
            wp.wp_role = 'sid';
            me.flightplan.insertWP(wp, 0);
            return;
        }
    # first, insert the runway itself
        var wp = createWPFrom(me.flightplan.departure_runway);
        wp.wp_role = 'sid';
        me.flightplan.insertWP(wp, 0);
        if (me.flightplan.sid == nil)
            return;

    # and we have a SID
        var sid = me.flightplan.sid;
        printlog('info', 'routing via SID ' ~ sid.id);
        me.flightplan.insertWaypoints(sid.route(me.flightplan.departure_runway), 1);
    },

    arrivalChanged: func
    {
        printlog('info', 'saw arrival changed');
        me.flightplan.clearWPType('star');
        me.flightplan.clearWPType('approach');
        if (me.flightplan.destination == nil)
            return;

        if (me.flightplan.destination_runway == nil) {
        # no runway, only an airport, use that
            var wp = createWPFrom(me.flightplan.destination);
            wp.wp_role = 'approach';
            me.flightplan.appendWP(wp);
            return;
        }

        var initialApproachFix = nil;
        if (me.flightplan.star != nil) {
            printlog('info', 'routing via STAR ' ~ me.flightplan.star.id);
            var wps = me.flightplan.star.route(me.flightplan.destination_runway);
            me.flightplan.insertWaypoints(wps, -1);

            initialApproachFix = wps[-1]; # final waypoint of STAR
        }

        if (me.flightplan.approach != nil) {
            var wps = me.flightplan.approach.route(initialApproachFix);

             if ((initialApproachFix != nil) and (wps == nil)) {
             # current GUI allows selected approach then STAR; but STAR
             # might not be possible for the approach (no transition).
             # since fixing the GUI flow is hard, let's route assuming no
             # IAF. This will likely cause an ugly direct leg, but that's
             # what the user asked for.

                 printlog('info', "couldn't route approach based on specified IAF "
                  ~ initialApproachFix.wp_name);
                 wps = me.flightplan.approach.route(nil);
             }

            if (wps == nil) {
                printlog('warn', 'routing via approach ' ~ me.flightplan.approach.id
                    ~ ' failed entirely.');
            } else {
                printlog('info', 'routing via approach ' ~ me.flightplan.approach.id);
                me.flightplan.insertWaypoints(wps, -1);
            }
        } else {
            printlog('info', 'routing direct to runway ' ~ me.flightplan.destination_runway.id);
            # no approach, just use the runway waypoint
            var wp = createWPFrom(me.flightplan.destination_runway);
            wp.wp_role = 'approach';
            me.flightplan.appendWP(wp);
        }
    },

    cleared: func
    {
        printlog('info', "saw active flightplan cleared, deactivating");
        # see http://https://code.google.com/p/flightgear-bugs/issues/detail?id=885
        fgcommand("activate-flightplan", props.Node.new({"activate": 0}));
    },

    endOfFlightPlan: func
    {
        printlog('info', "end of flight-plan, deactivating");
        fgcommand("activate-flightplan", props.Node.new({"activate": 0}));
        settimer(func me._endOfFlightPlan(me.flightplan),1);
    },

    _endOfFlightPlan: func (plan) {
        printlog('info', "end of flight-plan, reactivating last waypoint");
        #plan.cleanPlan();
        route.Polygon._finishedPrimary();
    },
};

registerFlightPlanDelegate(RouteManagerDelegate.new);