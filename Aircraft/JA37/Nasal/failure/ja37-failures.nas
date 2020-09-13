
var install_failures = func {
    # random failure code:
    # put in 3.5+ failure handling code here
    var lsnr = setlistener("sim/signals/fdm-initialized", func {
        if(getprop("sim/signals/fdm-initialized") == 1) {
            #print("installing new failures B "~lsnr);
            removelistener(lsnr);
            #_failmgr.init();

            # Load legacy failure modes for backwards compatibility
            #io.load_nasal(getprop("/sim/fg-root") ~
            #              "/Aircraft/Generic/Systems/compat_failure_modes.nas");

            install_failures();
            #print("installing new failures C");
        }
    }, 0, 1);
}

var install_failures = func {
    #print("3.5+ failures being processed.");
    #io.include("Aircraft/Generic/Systems/failures.nas");

    ##
    # Trigger object that will fire when aircraft air-speed is over
    # min, specified in knots. Probability of failing will
    # be 0% at min speed and 100% at max speed and beyond.
    # When the specified property is 0 there is zero chance of failing.
    var RandSpeedTrigger = {

        parents: [FailureMgr.Trigger],
        requires_polling: 1,
        type: "RandSpeed",

        new: func(min, max, prop) {
            if(min == nil or max == nil)
                die("RandSpeedTrigger.new: min and max must be specified");

            if(min >= max)
                die("RandSpeedTrigger.new: min must be less than max");

            if(min < 0 or max <= 0)
                die("RandSpeedTrigger.new: min must be positive or zero and max larger than zero");

            if(prop == nil or prop == "")
                die("RandSpeedTrigger.new: prop must be specified");

            var m = FailureMgr.Trigger.new();
            m.parents = [RandSpeedTrigger];
            m.params["min-speed-kt"] = min;
            m.params["max-speed-kt"] = max;
            m.params["property"] = prop;
            m._speed_prop = "/velocities/airspeed-kt";
            return m;
        },

        to_str: func {
            sprintf("Increasing probability of fails between %d and %d kt air-speed when deployed",
                int(me.params["min-speed-kt"]), int(me.params["max-speed-kt"]))
        },

        update: func {
            if(getprop(me.params["property"]) != 0) {
                var speed = getprop(me._speed_prop);
                var min = me.params["min-speed-kt"];
                var max = me.params["max-speed-kt"];
                var speed_d =  0;
                if(speed > min) {
                    speed_d = speed-min;
                    var delta_factor = 1/(max - min);
                    var factor = speed <= max ? delta_factor*speed_d : 1;
                    if(rand() < factor) {
                        return me.fired = 1;
                    }
                }
            }
            return me.fired = 0;
        }
    };


    ##
    # Returns an actuator object that will set a property at
    # a value when triggered.
    var set_value = func(path, value) {

        var default = getprop(path);

        return {
            parents: [FailureMgr.FailureActuator],
            set_failure_level: func(level) setprop(path, level > 0 ? value : default),
            get_failure_level: func { getprop(path) == default ? 0 : 1 }
        }
    }

    #setprop("/sim/failure-manager/display-on-screen", 1);
    var failure_root = "/sim/failure-manager";



    #gears

    var prop = "gear/gear[0]/position-norm";
    var trigger_gear0 = RandSpeedTrigger.new(350, 500, prop);
    var actuator_gear0 = set_value("fdm/jsbsim/gear/unit[0]/z-position", 0.001);
    FailureMgr.add_failure_mode("controls/gear0", "Front gear locking mechanism", actuator_gear0);
    FailureMgr.set_trigger("controls/gear0", trigger_gear0);
    trigger_gear0.arm();

    prop = "gear/gear[1]/position-norm";
    var trigger_gear1 = RandSpeedTrigger.new(350, 500, prop);
    var actuator_gear1 = set_value("fdm/jsbsim/gear/unit[1]/z-position", 0.001);
    FailureMgr.add_failure_mode("controls/gear1", "Left gear locking mechanism", actuator_gear1);
    FailureMgr.set_trigger("controls/gear1", trigger_gear1);
    trigger_gear1.arm();

    prop = "gear/gear[2]/position-norm";
    var trigger_gear2 = RandSpeedTrigger.new(350, 500, prop);
    var actuator_gear2 = set_value("fdm/jsbsim/gear/unit[2]/z-position", 0.001);
    FailureMgr.add_failure_mode("controls/gear2", "Right gear locking mechanism", actuator_gear2);
    FailureMgr.set_trigger("controls/gear2", trigger_gear2);
    trigger_gear2.arm();

    #canopy

    prop = "/fdm/jsbsim/fcs/canopy";
    var trigger_canopy = RandSpeedTrigger.new(250, 400, prop~"/pos-norm");
    var actuator_canopy = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Canopy motor", actuator_canopy);
    FailureMgr.set_trigger(prop, trigger_canopy);
    trigger_canopy.arm();

    var prop_hinges = "/fdm/jsbsim/fcs/canopy/hinges";
    var trigger_canopy_hinges = RandSpeedTrigger.new(400, 600, prop~"/pos-norm");
    var actuator_canopy_hinges = compat_failure_modes.set_unserviceable(prop_hinges);
    FailureMgr.add_failure_mode(prop_hinges, "Canopy hinges", actuator_canopy_hinges);
    FailureMgr.set_trigger(prop_hinges, trigger_canopy_hinges);
    trigger_canopy_hinges.arm();

    #some actuators initialized with empty triggers

    prop = "/instrumentation/head-up-display";
    var actuator_hud = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Head Up Display", actuator_hud);

    prop = "/instrumentation/instrumentation-light";
    var actuator_instr_light = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Instrument lights", actuator_instr_light);

    prop = "/instrumentation/radar";
    var actuator_radar = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Radar", actuator_radar);

    #prop = "systems/generator";
    #var actuator_generator = compat_failure_modes.set_unserviceable(prop);
    #FailureMgr.add_failure_mode(prop, "Generator", actuator_generator);

    prop = "systems/generator-reserve";
    var trigger_rg = RandSpeedTrigger.new(631.8, 660, "fdm/jsbsim/systems/electrical/generator-reserve-pos-norm");
    var actuator_generator_reserve = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Reserve Generator", actuator_generator_reserve);
    FailureMgr.set_trigger(prop, trigger_rg);
    trigger_rg.arm();

    prop = "controls/engines/engine/reverse-system";
    var actuator_reverser = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Thrust reverser", actuator_reverser);

    prop = "fdm/jsbsim/fcs/yaw-damper";
    var actuator_damper = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Yaw damper", actuator_damper);

    prop = "fdm/jsbsim/fcs/pitch-damper";
    var actuator_damperp = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Pitch damper", actuator_damperp);

    prop = "fdm/jsbsim/fcs/roll-damper";
    var actuator_damperr = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Roll damper", actuator_damperr);

    prop = "fdm/jsbsim/fcs/roll-limiter";
    var actuator_limiterr = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Roll limiter", actuator_limiterr);

    prop = "fdm/jsbsim/gear/unit[0]/nose-wheel-steering";
    var actuator_steering = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Nose wheel steering", actuator_steering);

    prop = "fdm/jsbsim/systems/hydraulics/system1/main";
    var actuator_pump1 = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Hydraulic 1", actuator_pump1);

    prop = "fdm/jsbsim/systems/hydraulics/system2/main";
    var actuator_pump2 = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Hydraulic 2", actuator_pump2);

    prop = "fdm/jsbsim/systems/hydraulics/system2/reserve";
    var actuator_pumpR = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Hydraulic reserve", actuator_pumpR);    

    prop = "fdm/jsbsim/systems/fuel/pneumatics";
    var actuator_air = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Pneumatic", actuator_air);

    prop = "fdm/jsbsim/systems/fuel/fuel-pumps";
    var actuator_fuel_pumps = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Electric fuel pumps", actuator_fuel_pumps);

    prop = "fdm/jsbsim/systems/fuel/fuel-flow";
    var actuator_fuel_distr = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Fuel flow distributor", actuator_fuel_distr);

    prop = "instrumentation/comm[0]";
    var actuator_comm1 = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Comm 1", actuator_comm1);

    prop = "instrumentation/comm[1]";
    var actuator_comm2 = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Comm 2", actuator_comm2);

    prop = "instrumentation/transponder";
    var actuator_transponder = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Transponder", actuator_transponder);

    prop = "engines/engine[0]/fire";
    var actuator_engine_fire = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Engine fire", actuator_engine_fire);

    prop = "engines/engine/afterburner";
    var actuator_afterburner = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Afterburner", actuator_afterburner);

    prop = "ja37/avionics/annunciator";
    var actuator_annunciator = compat_failure_modes.set_unserviceable(prop);
    FailureMgr.add_failure_mode(prop, "Annunciator", actuator_annunciator);

    if (getprop("/ja37/systems/variant") != 0) {
        prop = "sim/failure-manager/controls/flight/speedbrake";
        var actuator_speedbrake = compat_failure_modes.set_unserviceable(prop);
        FailureMgr.add_failure_mode("controls/flight/speedbrakes", "Speedbrakes", actuator_speedbrake);
    }

    # replace actuators on control surfaces due to jsbsim takes care of jamming

#    prop = "controls/flight/aileron";
#    var actuator_aileron = compat_failure_modes.set_unserviceable("fdm/jsbsim/fcs/aileron-serviceable");
#    FailureMgr.remove_failure_mode(prop);
#    FailureMgr.add_failure_mode(prop, "Aileron", actuator_aileron);
#    var trigger_aileron = compat_failure_modes.McbfTrigger.new(prop, 0);
#    FailureMgr.set_trigger(prop, trigger_aileron);

#    prop = "controls/flight/elevator";
#    var actuator_elevator = compat_failure_modes.set_unserviceable("fdm/jsbsim/fcs/elevator-serviceable");
#    FailureMgr.remove_failure_mode(prop);
#    FailureMgr.add_failure_mode(prop, "Elevator", actuator_elevator);
#    var trigger_elev = compat_failure_modes.McbfTrigger.new(prop, 0);
#    FailureMgr.set_trigger(prop, trigger_elev);

#    prop = "controls/flight/rudder";
#    var actuator_rudder = compat_failure_modes.set_unserviceable("fdm/jsbsim/fcs/rudder-serviceable");
#    FailureMgr.remove_failure_mode(prop);
#    FailureMgr.add_failure_mode(prop, "Rudder", actuator_rudder);
#    var trigger_rudder = compat_failure_modes.McbfTrigger.new(prop, 0);
#    FailureMgr.set_trigger(prop, trigger_rudder);

#    prop = "controls/flight/flaps";
#    var actuator_flaps = compat_failure_modes.set_unserviceable("fdm/jsbsim/fcs/flaps-serviceable");
#    FailureMgr.remove_failure_mode(prop);
#    FailureMgr.add_failure_mode(prop, "Flaps", actuator_flaps);
#    var trigger_flaps = compat_failure_modes.McbfTrigger.new(prop, 0);
#    FailureMgr.set_trigger(prop, trigger_flaps);

    ##
    # Returns an actuator object that will set the serviceable property at
    # the given node to zero when the level of failure is > 0.
    # it will also fail additionally failure modes.

    var set_empty = func(path, flow_paths) {

        return {
            parents: [FailureMgr.FailureActuator],
            paths: flow_paths,
            set_failure_level: func(level) {
                level = level == 0?0:1;

                foreach(var flow_path ; me.paths) {
                    setprop(flow_path, level==0?0:-75);
                }
            },
            get_failure_level: func {
                getprop(me.paths[0]) == -75? 1 : 0;
            }
        }
    }

    ##
    # Returns an actuator object that will set the serviceable property at
    # the given node to zero when the level of failure is > 0.
    # it will also fail additionally failure modes.

    var set_unserviceable_cascading = func(path, casc_paths) {

        var prop = path ~ "/serviceable";

        if (props.globals.getNode(prop) == nil)
            props.globals.initNode(prop, 1, "BOOL");

        return {
            parents: [FailureMgr.FailureActuator],
            mode_paths: casc_paths,
            set_failure_level: func(level) {
                setprop(prop, level > 0 ? 0 : 1);
                foreach(var mode_path ; me.mode_paths) {
                    FailureMgr.set_failure_level(mode_path, level);
                }
            },
            get_failure_level: func { getprop(prop) ? 0 : 1 }
        }
    }

    #prop = "consumables/fuel/wing-tanks";
    #var actuator_wing_tanks = set_empty(prop, ["fdm/jsbsim/propulsion/tank[4]/external-flow-rate-pps", "fdm/jsbsim/propulsion/tank[5]/external-flow-rate-pps", "fdm/jsbsim/propulsion/tank[6]/external-flow-rate-pps", "fdm/jsbsim/propulsion/tank[7]/external-flow-rate-pps"]);
    #FailureMgr.add_failure_mode(prop, "Wing tanks", actuator_wing_tanks);

    #prop = "fdm/jsbsim/fcs/wings";
    #var actuator_wings = set_unserviceable_cascading(prop, ["controls/gear1", "controls/gear2", "controls/flight/aileron", "controls/flight/elevator", "consumables/fuel/wing-tanks"]);
    #FailureMgr.add_failure_mode(prop, "Delta wings", actuator_wings);
    
    

    

    ## test stuff: ##

    #Canopy
#    var prop = "/fdm/jsbsim/fcs/canopy";
#    var actuator_canopy = set_unserviceable(prop);
#    var trigger_canopy = MtbfTrigger.new(60);

#    FailureMgr.add_failure_mode("canopy", "Canopy", actuator_canopy);
#    FailureMgr.set_trigger("canopy", trigger_canopy);


    # test of mcbf
#    prop = "fdm/jsbsim/fcs/rudder-pos-norm";
#    var trigger_rudder = McbfTrigger.new("surface-positions/rudder-pos-norm", 2000);
    #var actuator_rudder = set_readonly(prop);

    #FailureMgr.add_failure_mode("controls/flight/rudder", "Rudder", actuator_rudder);
#    FailureMgr.set_trigger("controls/flight/rudder", trigger_rudder);#replace

    #test of altitude
#    prop = "gear/gear[1]/position-norm";
#    var trigger_gear1 = AltitudeTrigger.new(5000, 10000);
#    var actuator_gear1 = set_readonly(prop);

#    FailureMgr.add_failure_mode("gear1", "Left gear", actuator_gear1);
#    FailureMgr.set_trigger("gear1", trigger_gear1);

    # test of timeout
#    prop = "gear/gear[2]/position-norm";
#    var trigger_gear2 = TimeoutTrigger.new(60);
#    var actuator_gear2 = set_readonly(prop);

#    FailureMgr.add_failure_mode("gear2", "Right gear", actuator_gear2);
#    FailureMgr.set_trigger("gear2", trigger_gear2);
    setprop("ja37/failures/installed", 1);
}

var _init = func {
        removelistener(lsnr_s);
        install_failures();
    }

var lsnr_s = setlistener("ja37/supported/initialized", _init, 0, 0);

var armAllTriggers = func () {
    # TODO: loop over all failure modes and set triggers to armed.
    var failure_modes = FailureMgr._failmgr.failure_modes; # hash with the failure modes
    var mode_list = keys(failure_modes);#values()?

    foreach(var failure_mode_id; mode_list) {
        var trigger = failure_modes[failure_mode_id].trigger;
        if (trigger != nil and trigger.type == "RandSpeed") {
            trigger.arm();
            #print("arming "~failure_mode_id~" : "~trigger.to_str());
        }
    }
}
