# This is a small script that adjusts autopilot target values to track
# (fly in formation with) an AI or Multiplayer aircraft.

# Quick start instructions:
#
#
# 1. Copy this file into $FGROOT/data/Nasal (along with the other 
#    system nasal scripts.)
#
# 2. Start up FlightGear selecting an airplane with a reasonably configured
#    autopilot that responds to and works with the standard autopilot 
#    dialog box (F11).  The MiG 15 is one that works, the 777-200 works,
#    the Citation Bravo does not work, the default c172 probably does not
#    work, etc.
#
# 3. Take off and establish stable flight.
#
# 4. Open the property browser (File->Browse Internal Properties) and navigate
#    to /ai/models/  Choose one of the available aircraft[] or multiplayer[]
#    entries.  You can look at all those subtrees to find the call sign you
#    want.  Also note that the subtree for each entity has a radar area that
#    will show range and offset from your current heading.
#
# 5. Open a second property browser window (upper left click box in the first
#    property browser window.)  Navigate to /autopilot/target-tracking/
#
# 6. Set "/autopilot/target-tracking/target-root" to point to the entity
#    path you discovered in step #4.  For instance, this should be set to
#    something like /ai/models/multiplayer[2] or /ai/models/aircraft[0]
#
# 7. Set "/autopilot/target-tracking/goal-range-nm" to the follow distance
#    you want.
#
# 8. Set "/autopilot/target-tracking/enable" = 1, this will turn on the radar
#    computation for each ai/multiplayer entity and will tell the tracking
#    script to start updating the autopilot settings.
#
# 9. Open up the autopilot configuration window (F11) and activate any of the
#    heading, pitch, and speed axes.  The script will begin updating the heading
#    bug angle, the "speed with throttle" value, and the "altitude hold" value.
#
# 10. You can choose to mix and match any of the autopilot modes you want, i.e.
#     you could turn off the heading control and turn manually while the system
#     holds speed and altitude for you.
#
# 11. It always helps to have a sensible target arcraft to chase.  You are
#     flying within the turn radius and climb rate limits of your autopilot.
#
#     Don't forget you are pilot in command and at all times responsible for
#     maintaining safe airspeed and altitude.
#
#     Enjoy the ride!


# print("Target Tracking script loading ...");

# script defaults (configurable if you like)
var default_update_period = 0.05;
var default_goal_range_nm = 0.05;
var default_target_root = "/ai/models/aircraft[0]";
var default_min_speed_kt = 120;

# master enable switch
var target_tracking_enable = 0;

# update period
var update_period = default_update_period;

# goal range to acheive when following target
var goal_range_nm = 0;

# minimum speed so we don't drop out of the sky
var min_speed_kt = 0;

# Target property tree root
var target_root = "";

# Loop identifier
var tracker_loop_id = 0;

# Initialize target tracking
var TrackInit = func {
    if (props.globals.getNode("autopilot") == nil)
        return;

    props.globals.initNode("/autopilot/target-tracking-ja37/enable", 0, "BOOL");
    props.globals.initNode("/autopilot/target-tracking-ja37/update-period", default_update_period, "DOUBLE");
    props.globals.initNode("/autopilot/target-tracking-ja37/goal-range-nm", default_goal_range_nm, "DOUBLE");
    props.globals.initNode("/autopilot/target-tracking-ja37/min-speed-kt", default_min_speed_kt, "DOUBLE");
    props.globals.initNode("/autopilot/target-tracking-ja37/target-root", default_target_root, "STRING");

    setlistener("/autopilot/target-tracking-ja37/enable", func { startTimer();} , 0, 0);
}

# If enabled, update our AP target values based on the target range,
# bearing, and speed
var TrackUpdate = func(loop_id) {
    # avoid running multiple concurrent timers
    if (tracker_loop_id != loop_id)
        return;

    if (props.globals.getNode("autopilot") == nil)
        return;

    target_tracking_enable = getprop("/autopilot/target-tracking-ja37/enable");

    if ( target_tracking_enable == 1 and getprop(getprop("/autopilot/target-tracking-ja37/target-root")~"/valid") == 1) {
        update_period = getprop("/autopilot/target-tracking-ja37/update-period");

        # refresh user configurable values
        goal_range_nm = getprop("/autopilot/target-tracking-ja37/goal-range-nm");
        target_root = getprop("/autopilot/target-tracking-ja37/target-root");
        min_speed_kt = getprop("/autopilot/target-tracking-ja37/min-speed-kt");

        # force radar debug-mode on (forced radar calculations even if
        # no radar instrument and ai aircraft are out of range
        setprop("/instrumentation/radar/debug-mode", 1);

        my_hdg_prop = sprintf("/orientation/heading-magnetic-deg" );
        my_hdg = getprop(my_hdg_prop);

        my_hdg_true_prop = sprintf("/orientation/heading-deg" );
        my_hdg_true = getprop(my_hdg_true_prop);

        var alt_prop = sprintf("%s/position/altitude-ft", target_root );
        var alt = getprop(alt_prop);
        if ( alt == nil ) {
            print("bad property path: ", alt_prop);
            return;
        }

        var myalt_true = getprop("position/altitude-ft");
        var myalt = getprop("instrumentation/altimeter/indicated-altitude-ft");
        var alt_diff = myalt_true - myalt;
        #print(alt~" "~alt_diff~" "~myalt~" "~myalt_true);
        alt = alt - alt_diff;

        var speed_prop = sprintf("%s/velocities/true-airspeed-kt", target_root );
        #correct by local IAS/TAS ratio, because autopilot uses IAS
        #I need to calculate my TAS, not taking wind into account (MP velocities/true-airspeed-kt does not as well)
        var northSpeed = getprop("/velocities/speed-north-fps");
        var eastSpeed = getprop("/velocities/speed-east-fps");
        var downSpeed = getprop("/velocities/speed-down-fps");
        var true_airspeed = FPS2KT * math.sqrt(northSpeed*northSpeed + eastSpeed*eastSpeed + downSpeed*downSpeed);
        #take target TAS and multiply it by my own IAS/TAS ratio to get target IAS
        var speedTAS = getprop(speed_prop);
        if ( speedTAS == nil ) {
            print("bad property path: ", speed_prop);
            return;
        }
        var speed = speedTAS * (getprop("/velocities/airspeed-kt") / true_airspeed);

        var range_prop = sprintf("%s/radar/range-nm", target_root );
        var range = getprop(range_prop);
        if ( range == nil ) {
            print("bad property path: ", range_prop);
            return;
        }
    
        var h_offset_prop = sprintf("%s/radar/h-offset", target_root );
        var h_offset = getprop(h_offset_prop);
        if ( h_offset == nil ) {
            print("bad property path: ", h_offset_prop);
            return;
        }

        if ( h_offset > -90 and h_offset < 90 ) {
            # in front of us
            var range_error = range - goal_range_nm;
        } else {
            # behind us
            var range_error = goal_range_nm - range;
        }

        #var myspeed = getprop("velocities/airspeed-kt");
        #var myspeed_true = getprop("fdm/jsbsim/velocities/vtrue-kts");
        #var diff = myspeed_true-myspeed;

        var target_speed = speed + range_error * 100.0;
        #var ds = speed-diff;
        #print("speed: "~ds);
        #print(" err: "~range_error~" targ: "~target_speed);

        var speed_indicated = speed;# - diff;

        #setprop("/autopilot/target-tracking-ja37/speed_indicated_target", speed_indicated);
        #setprop("/autopilot/target-tracking-ja37/speed_indicated_myself", myspeed);
        setprop("/autopilot/target-tracking-ja37/range", range_error);
        #setprop("/autopilot/target-tracking-ja37/myspeed_true", myspeed_true);
        

        # if close, obey speed limits:
        if(range_error < 0.25) {
          target_speed = math.min(target_speed, speed_indicated+50);
        } elsif(range_error < 2) {
          target_speed = math.min(target_speed, speed_indicated+100);
        } elsif(range_error < 5) {
          target_speed = math.min(target_speed, speed_indicated+250);
        } elsif(range_error < 10) {
          target_speed = math.min(target_speed, speed_indicated+400);
        } else {
          #target_speed = math.max(target_speed, speed_indicated+25);
        }
        if ( !debug.isnan(target_speed) and target_speed < min_speed_kt ) {
            target_speed = min_speed_kt;
        }
        #print(" targ: "~target_speed);

        setprop( "/autopilot/settings/target-altitude-ft", alt );
        setprop( "/autopilot/settings/heading-bug-deg", my_hdg + h_offset );
        setprop( "/autopilot/settings/true-heading-deg",
                 my_hdg_true + h_offset );

        if( !debug.isnan(target_speed) ) setprop( "/autopilot/settings/target-speed-kt", target_speed ); #isnan check because I divide by TAS before

        # only keep the timer running when the feature is really enabled
        settimer(func() { TrackUpdate(loop_id); }, update_period );
    } else {
        if (getprop(getprop("/autopilot/target-tracking-ja37/target-root")~"/valid") != 1) {
            ja37.lostfollow();
            #print(getprop("/autopilot/target-tracking-ja37/target-root"));
            #print(getprop(getprop("/autopilot/target-tracking-ja37/target-root")~"/valid"));
        }
    }
}

# create and start a new timer to cause our update function to be called periodially
startTimer = func {
    tracker_loop_id += 1;
    TrackUpdate(tracker_loop_id);
 }

settimer(TrackInit, 0);

