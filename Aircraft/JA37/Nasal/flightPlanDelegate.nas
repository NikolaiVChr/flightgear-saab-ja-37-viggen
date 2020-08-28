# Viggen custom route manager delegate.
#
# This delegate handles waypoint sequencing.
# It is a simplified version of the default sequencing behaviour (route_manager.DefaultGPSDelegate),
# with a few Viggen specific behaviours.


# Backward compatibility, for FG versions using printlog instead of logprint
if (!defined("logprint") or !defined("LOG_INFO")) {
    var logprint = printlog;
    var LOG_INFO = 'info';
}



var GPSPath = "/instrumentation/gps";
var GPSNode = props.globals.getNode(GPSPath, 1);

var Delegate = {
    new: func(fp) {
        var m = {
            parents: [Delegate],
            flightplan: fp,
            _modeProp: GPSNode.getNode("mode", 1)
        };

        logprint(LOG_INFO, 'creating Saab 37 flight plan delegate');

        # tell the GPS C++ code we will do sequencing ourselves, so it can disable
        # its legacy logic for this
        setprop(GPSPath ~ '/config/delegate-sequencing', 1);

        # make FlightPlan behaviour match GPS config state
        fp.followLegTrackToFix = getprop(GPSPath ~ '/config/follow-leg-track-to-fix') or 0;

        # similarly, make FlightPlan follow the performance category settings
        fp.aircraftCategory = getprop('/autopilot/settings/icao-aircraft-category') or 'D';

        return m;
    },

    _captureCurrentCourse: func {
        GPSNode.setValue("selected-course-deg", GPSNode.getValue("desired-course-deg"));
    },

    _selectMode: func (mode) {
        GPSNode.setValue("command", mode);
    },

    waypointsChanged: func {
    },

    activated: func {
        if (!me.flightplan.active)
            return;

        logprint(LOG_INFO,'flightplan activated, navigation set to LEG mode');
        me._selectMode("leg");

        if (getprop(GPSPath ~ '/wp/wp[1]/from-flag')) {
            logprint(LOG_INFO, '\tat GPS activation, already passed active WP, sequencing');
            me.sequence();
        }
    },

    _deactivate: func {
        if (me._modeProp.getValue() == 'leg') {
            logprint(LOG_INFO, 'navigation set to OBS mode');
            me._captureCurrentCourse();
            me._selectMode("obs");
        }
    },

    deactivated: func {
        logprint(LOG_INFO, 'flightplan deactivated');
        me._deactivate();
    },

    endOfFlightPlan: func {
        logprint(LOG_INFO, 'end of flightplan');
        me._deactivate();
    },

    cleared: func {
        if (!me.flightplan.active)
            return;

        logprint(LOG_INFO, 'flightplan cleared');
        me._deactivate();
    },

    sequence: func {
        if (!me.flightplan.active)
            return;

        if (me._modeProp.getValue() == 'leg') {
            var nextIndex = me.flightplan.current + 1;
            if (nextIndex >= me.flightplan.getPlanSize()) {
                # End of flightplan. Custom Viggen behaviour here, instead of finishing flightplan.
                me._deactivate();
                route.Polygon._finishedPrimary(me.flightplan);
            } else {
                logprint(LOG_INFO, "navigation sequencing to next WP");
                me.flightplan.current = nextIndex;
            }
        }
    },

    currentWaypointChanged: func {
        if (!me.flightplan.active)
            return;

        # Polygon._wpChanged() can enable landing mode, which can re-trigger waypoint change signals.
        # The 0 timer is a stupid way to avoid this from causing recursive / re-entering
        # calls to functions which are not designed for it.
        settimer(func {route.Polygon._wpChanged()}, 0);
    }
};

registerFlightPlanDelegate(Delegate.new);
