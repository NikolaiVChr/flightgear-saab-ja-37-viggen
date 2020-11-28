var FALSE = 0;
var TRUE = 1;

var input = {
    elev_pri:   "/instrumentation/gunsight/elevation-mil",
    azi_pri:    "/instrumentation/gunsight/azimuth-mil",
    elev_sec:   "/instrumentation/gunsight/secondary-elevation-mil",
    azi_sec:    "/instrumentation/gunsight/secondary-azimuth-mil",
    dist:       "/instrumentation/gunsight/distance-m",
    dist_tgt:   "/instrumentation/gunsight/target-distance-m",
    use_tgt:    "/instrumentation/gunsight/use-target-distance",
    rho:        "/fdm/jsbsim/atmosphere/rho-slugs_ft3",
    vel_x:      "/fdm/jsbsim/velocities/u-fps",
    vel_y:      "/fdm/jsbsim/velocities/v-fps",
    vel_z:      "/fdm/jsbsim/velocities/w-fps",
    vel_aero_x: "/fdm/jsbsim/velocities/u-aero-fps",
    vel_aero_y: "/fdm/jsbsim/velocities/v-aero-fps",
    vel_aero_z: "/fdm/jsbsim/velocities/w-aero-fps",
    pitch_rad:  "/fdm/jsbsim/attitude/pitch-rad",
    roll_rad:   "/fdm/jsbsim/attitude/roll-rad",
    alt:        "/instrumentation/altimeter/indicated-altitude-meter",
    roll:       "/instrumentation/attitude-indicator/roll-deg",
    grd_speed:  "/velocities/groundspeed-kt",
    fpv_pitch:  "/instrumentation/fpv/pitch-deg",
};

foreach (var prop; keys(input)) {
    input[prop] = props.globals.getNode(input[prop]);
}


### Nasal interface to the AFALCOS A/A gunsight implemented in JSBSim
var AAsight = {
    # Update loop, simply to feed distance to the JSBSim system.
    update: func {
        if (radar_logic.selection != nil) {
            input.use_tgt.setValue(1);
            input.dist_tgt.setValue(radar_logic.selection.get_range() * NM2M);
        } else {
            input.use_tgt.setValue(0);
        }
    },

    # Position of aiming reticles in mils [right,down].
    get_pos: func {
        return [input.azi_pri.getValue(), -input.elev_pri.getValue()];
    },

    # Secondary position, given by a second AFALCOS which overestimates distance by 100m. Used for the trace line.
    get_pos_sec: func {
        return [input.azi_sec.getValue(), -input.elev_sec.getValue()];
    },
};



# Return pitch angle (in world frame) of vector traj (given in body frame).
traj_pitch = func(traj) {
    var pitch = input.pitch_rad.getValue();
    var roll = input.roll_rad.getValue();
    # Apply roll
    traj = [
        traj[0],
        traj[1]*math.cos(roll) - traj[2]*math.sin(roll),
        traj[1]*math.sin(roll) + traj[2]*math.cos(roll),
    ];
    # Apply pitch
    traj = [
        traj[0]*math.cos(pitch) + traj[2]*math.sin(pitch),
        traj[1],
        -traj[0]*math.sin(pitch) + traj[2]*math.cos(pitch),
    ];
    # Project on vertical plane
    traj = [
        math.sqrt(traj[0]*traj[0] + traj[1]*traj[1]),
        traj[2],
    ];
    return math.atan2(-traj[1], traj[0])*R2D;
}


### A/G ballistic computer.
#
# Call x the projectile velocity axis when firing, y the axis orthogonal to x on the vertical plane.
# The simplifying assumption used is that motion equations can be solved for the x-axis independently of the y-axis.
#
# Time of flight is obtained by solving the position equation for the x-axis, with drag only.
# As a by-product, we obtain the x-axis speed as function of time.
#
# After this, drop distance is obtained by solving the position equation for the y axis
# with gravity and drag. Magnitude of drag is obtained from the x-axis speed only.
#
# Vectors are in JSBSim body frame, i.e. [forward,right,down]
# Units are metric.
var AG_computer = {
    # Projectile parameters: (SI)
    # mass:         kg
    # muzzle_vel:   m/s
    # drag_coef:    dimensionless
    # drag_area:    m^2
    # gun_angle:    rad, positive up
    new: func(mass, muzzle_vel, drag_coef, drag_area, gun_angle, max_dist) {
        return {
            parents: [AG_computer],
            mass: mass,
            drag_coef: drag_coef,
            drag_area: drag_area,
            muzzle_vel: muzzle_vel,
            # Gun normalized vector.
            gun_vec: [math.cos(gun_angle), 0, -math.sin(gun_angle)],

            # Max distances used to compute sight position.
            max_dist: max_dist,

            # Defined here because used as feedback. Values are not really important.
            dist: 1000,     # Target distance, m.
            time: 1,        # Predicted flight time, sec.
            drop_dist: 0,   # Drop due to gravity
            traj: [1,0,0],  # Vector to predicted impact point in body frame, normalized.

            i: 0,
        };
    },

    # Just for conversion
    rho: func {
        # slug/ft^3 to kg/m^3
        return 515.37882 * input.rho.getValue();
    },

    # Drag all-in-one coefficient, so that drag deceleration is v^2 * drag_acc_coef()
    drag_acc_coef: func(init_vel, rho) {
        # Adjust drag coefficient by Mach number.
        var mach = init_vel/330;    # Rough estimate.
        # Standard curve for high mach number.
        var drag_coef_mach = me.drag_coef + 0.2965 * math.pow(mach, -1.1506);

        return rho * drag_coef_mach * me.drag_area / me.mass / 2;
    },

    # Projectile flight time to cover a given distance, assuming drag is the only relevant force.
    flight_time: func(dist, init_vel, drag) {
        # Math: we assume drag is the only force on the x axis.
        # thus  a = - drag v^2
        # solving with v(0) = init_vel gives
        #   v(t) = 1 / (drag*t + 1/init_vel)
        # integrating gives the position
        #   x(t) = 1/drag log(drag*init_vel*t + 1)
        # inverting it gives
        #   t = (e^(drag*x) - 1) / (drag * init_vel)
        return (math.exp(drag * dist) - 1) / drag / init_vel;
    },

    # Drop distance.
    gravity_drop: func(time, init_vel, drag) {
        # Math: first we approximate horizontal velocity by neglecting gravity.
        # as stated in flight_time(), this solves as
        #   v(t) = 1 / (drag*t + 1/init_vel)
        # We use this horizontal velocity to compute the drag force on the vertical axis
        # (which is not neglectable).
        # Total drag deceleration is drag * v^2.
        # Thus drag deceleration projected on the vertical axis is
        #   drag*v^2 * (v_y/v) = drag * v * v_y
        # where v_y is vertical speed.
        # Vertical acceleration is thus
        #
        #   a_y(t) = - drag * v(t) * v_y(t) + g
        #
        # This is a first order linear equation.
        #
        # Let u(t) = exp(\int -drag * v(t) dt). We have
        #   u(t) = exp(-drag * \int v(t) dt)
        #        = exp(-drag * 1/drag log(drag*init_vel*t + 1))     (cf. x(t) = \int v(t) in flight_time)
        #        = exp(- log(drag*init_vel*t + 1))
        #        = 1/(drag*init_vel*t + 1)
        # u(t) is solution of the homogeneous diff. eq. a_y = -drag*v * v_y
        # A solution of the full equation is then
        #   v_y(t) = f(t) u(t)
        # with
        #   f(t) = \int g * 1/u(t) dt
        #        = g \int drag*init_vel*t + 1  dt
        #        = g * t * (drag*init_vel*t/2 + 1)
        # thus
        #   v_y(t) = g * t * (drag*init_vel*t/2 + 1) / (drag*init_vel*t + 1)
        # Note that v_y(0) = 0 is the correct initial condition, so this is the desired solution.
        # Developing:
        #   v_y(t) = g * [(drag*init_vel*t + 1) * (t/2 + 1/(2*drag*init_vel)) - 1/(2*drag*init_vel)]
        #               / [drag*init_vel*t + 1]
        #          = gt/2 + g/(2*drag*init_vel) - g/[2 * drag * init_vel * (drag*init_vel*t + 1)]
        # Finally, vertical position is
        #   y(t) = \int v_y(t) dt
        #        = gt^2/4 + gt/(2*drag*init_vel)
        #           - g/(2*drag*init_vel) * \int 1 / (drag*init_vel*t + 1) dt
        #        = gt^2/4 + gt/(2*drag*init_vel) - g/(2*drag^2*init_vel^2) log(drag*init_vel*t + 1)
        # Note y(0) = 0 as desired.
        var dv = drag * init_vel;
        return 9.81 * (time*time/4 + time/2/dv - 1/2/dv/dv * math.ln(dv*time + 1));
    },

    # In JSBSim body frame
    wind_vector: func {
        return [
            (input.vel_x.getValue() - input.vel_aero_x.getValue()) * FT2M,
            (input.vel_y.getValue() - input.vel_aero_y.getValue()) * FT2M,
            (input.vel_z.getValue() - input.vel_aero_z.getValue()) * FT2M,
        ];
    },

    # In JSBSim body frame, bullet air velocity vector
    init_vel_vector: func {
        return [
            input.vel_aero_x.getValue() * FT2M + me.muzzle_vel * me.gun_vec[0],
            input.vel_aero_y.getValue() * FT2M + me.muzzle_vel * me.gun_vec[1],
            input.vel_aero_z.getValue() * FT2M + me.muzzle_vel * me.gun_vec[2],
        ];
    },

    # Compute projectile trajectory over a given distance.
    #
    # Returns [trajectory vector, flight time, gravity drop distance]
    # Optional arguments time_estimate and drop_dist_estimate
    # can be used to feedback result of previous calls to improve accuracy.
    # (It works fine without them too)
    get_traj: func(dist, time_estimate=0, drop_dist_estimate=0) {
        dist = math.clamp(dist, 50, me.max_dist);   # Set a minimum distance to avoid weird behaviours.

        var pitch = input.pitch_rad.getValue();
        var roll = input.roll_rad.getValue();
        var down_vector = [
            -math.sin(pitch),
            math.cos(pitch) * math.sin(roll),
            math.cos(pitch) * math.cos(roll),
        ];

        var wind = me.wind_vector();

        var init_vel = me.init_vel_vector();
        var init_speed = vector.Math.magnitudeVector(init_vel);
        var init_dir = vector.Math.product(1/init_speed, init_vel);

        # Compensate distance for wind and gravity drop, using flight time from previous iteration.
        dist -= vector.Math.dotProduct(wind, init_dir) * time_estimate
            + vector.Math.dotProduct(down_vector, init_dir) * drop_dist_estimate;

        # Update flight time.
        var drag = me.drag_acc_coef(init_speed, me.rho());
        var time = me.flight_time(dist, init_speed, drag);
        var drop_dist = me.gravity_drop(time, init_speed, drag);

        # Final vector from aircraft to computed impact point.
        var traj = vector.Math.plus(vector.Math.product(dist, init_dir), vector.Math.product(time, wind));
        traj = vector.Math.plus(traj, vector.Math.product(drop_dist, down_vector));
        traj = vector.Math.normalize(traj);
        return [traj, time, drop_dist];
    },
};

# The various guns and rockets.
var M75AGsight = AG_computer.new(0.36, 1030, 0.193, 0.000126677, 0, 8000);
var M55sight = AG_computer.new(0.22, 741, 0.193, 0.00012667701, -0.0265, 8000);
var M70sight = AG_computer.new(45.4, 600, 0.0001, 0.005, 0.0677, 8000);



var DistanceComputer = {
    ranging_enabled: FALSE,
    default_dist: 1400,     # AJS SFI part 3

    # Triangulated distance
    # Assumes that 'pitch' is the pitch angle to the target, and altimeter # is calibrated to target QFE.
    triang_dist: func(pitch) {
        return input.alt.getValue() / math.sin(-pitch*D2R);
    },

    # Mesure distance to ground along vector traj.
    radar_dist: func(traj) {
        var pos = aircraftToCart({x:0, y:0, z:0});
        # Factor 1000 to avoid floating point issues (make the vector large enough).
        var dir = aircraftToCart({x:traj[0]*1000, y:traj[1]*1000, z:traj[2]*1000});
        dir.x -= pos.x;
        dir.y -= pos.y;
        dir.z -= pos.z;
        var hit = get_cart_ground_intersection(pos, dir);

        if (hit == nil) return nil;
        else {
            var hit_coord = geo.Coord.new();
            hit_coord.set_latlon(hit.lat, hit.lon, hit.elevation);
            var pos_coord = geo.Coord.new();
            pos_coord.set_xyz(pos.x, pos.y, pos.z);
            return pos_coord.direct_distance_to(hit_coord);
        }
    },

    # Takes a trajectory in aircraft body frame along which to compute distance.
    # Returns [distance, ranging_used, radar_used]
    # - ranging_used is false when ranging was not performed, and a fixed distance was returned.
    # - radar_used is true if radar was used to compute range.
    update: func(traj) {
        var pitch = traj_pitch(traj);

        # AJS SFI part 3: triangulation ranging enabled at 5deg down, disabled at 3deg (hysteresis).
        if (pitch < -5) me.ranging_enabled = TRUE;
        elsif (pitch > -3) me.ranging_enabled = FALSE;
        if (!me.ranging_enabled) return [me.default_dist, FALSE, FALSE];

        # To simplify, JA always uses radar distance.
        if (variant.JA) {
            var dist = me.radar_dist(traj);
            if (dist != nil) return [dist, TRUE, TRUE];
            else return [me.default_dist, FALSE, FALSE];
        }

        var trg_dist = me.triang_dist(pitch);
        var roll = input.roll.getValue();
        # AJS uses radar when range is <7km. Additionally, roll must be <45, or trigger unsafe.
        if (dist <= 7000 and (fire_control.is_armed() or (roll <= 45 and roll >= -45))) {
            var rdr_dist = me.radar_dist(traj);
            if (rdr_dist != nil) return [rdr_dist, TRUE, TRUE];
        }
        return [trg_dist, TRUE, FALSE];
    },

    reset: func { me.ranging_enabled = FALSE; },
};



# Computes minimum firing distance.
var FiringDistanceComputer = {
    # Safety distance is the radius around the target which we do not want to enter
    # (to avoid explosion/fragments...). Weapon dependent.
    # Values from AJS SFI part 3 sec 3.
    # Should also depend on the safety distance switch (ground crew weapon panel).
    safety_dist: {
        "M75 AKAN": 200,
        "M55 AKAN": 200,
        "M70 ARAK": 440,
    },

    # Load factor for evading. Should be 4g for bombs.
    pull_up_factor: {
        "M75 AKAN": 5,
        "M55 AKAN": 5,
        "M70 ARAK": 5,
    },

    # Time before the desired load factor is reached. Should be 1.9s for bombs.
    pull_up_time: {
        "M75 AKAN": 2.5,
        "M55 AKAN": 2.5,
        "M70 ARAK": 2.5,
    },

    # Planned salvo length.
    firing_time: {
        "M75 AKAN": 2.15,
        "M55 AKAN": 2.15,
        "M70 ARAK": 1.65,
    },

    # Solves the following geometric problem:
    # T is the target position
    # A is the aircraft position
    # Consider a circle of radius safety_radius around T
    # Consider a circle of radius pull_up_radius above A, intersecting A,
    # and such that its tangent at A has an angle flight_path_angle to the line A T.
    # (This tangent represents the aircraft flight path vector.
    #   Angle is positive when it is above the aiming line A T.)
    #
    # For which distance A T are these circles tangent?
    #
    # Distances in m, angle in deg.
    pull_up_dist: func(safety_radius, pull_up_radius, flight_path_angle) {
        flight_path_angle *= D2R;
        # Distance between centers of the two circles.
        var centers_dist = safety_radius + pull_up_radius;
        # Distance from second circle center to aiming line A T.
        var center_height = math.cos(flight_path_angle)*pull_up_radius;

        # Distance from T to center of circle 2 projected on line A T (Pytharogas)
        return math.sqrt(centers_dist*centers_dist - center_height*center_height)
            # Distance from A to center of circle 2 projected on line A T
            - math.sin(flight_path_angle)*pull_up_radius;
    },

    # [minimum pull up distance, minimum firing distance]
    firing_distance: func(type, traj, radar_dist) {
        var speed = input.grd_speed.getValue() * KT2MPS;
        # Turn radius for the G-load specified by pull_up_factor.
        # (correct for the bottom of the circle, which is the worse case).
        var pull_up_rad = speed*speed/(me.pull_up_factor[type]-1)/9.81;

        var aiming_pitch = traj_pitch(traj);
        var fpv_pitch = input.fpv_pitch.getValue();

        var pull_up_dist = me.pull_up_dist(me.safety_dist[type], pull_up_rad, fpv_pitch-aiming_pitch);

        var tolerance = radar_dist ? 75 : 43 / math.sin(-aiming_pitch*D2R);

        var safe_pull_up_dist = pull_up_dist + me.pull_up_time[type]*speed + tolerance;

        return [safe_pull_up_dist, safe_pull_up_dist + me.firing_time[type]*speed];
    },
};



# Main A/G sight loop for JA
var AGsightJA = {
    # Previous results, for feedback.
    traj: nil,
    dist: nil,
    time: 0,
    drop_dist: 0,
    has_range: FALSE,
    # Previous weapon type, to reset state appropriately.
    last_type: nil,
    active: FALSE,
    # Computed firing distance (minimum distance for safe evasion).
    min_dist: 0,
    opt_dist: 0,

    reset: func {
        me.traj = nil;
        me.dist = nil;
        me.time = 0;
        me.drop_dist = 0;
        me.has_range = FALSE;
        me.last_type = nil;
        DistanceComputer.reset();
    },

    # Background reset loop. Not very costly.
    reset_loop: func {
        if (!me.active) return;
        var type = fire_control.get_type();
        if (modes.main_ja != modes.AIMING or (type != "M70 ARAK" and type != "M75 AKAN")) {
            me.reset();
            me.active = FALSE;
        }
    },

    update: func {
        me.active = TRUE;

        var type = fire_control.get_type();
        if (type == "M70 ARAK") {
            var sight = M70sight;
        } else {
            var sight = M75AGsight;
        }

        if (type != me.last_type) {
            me.reset();
            me.last_type = type;
        }

        # After reset, initialize computed trajectory with projectile initial trajectory.
        if (me.traj == nil) {
            me.traj = sight.init_vel_vector();
            me.traj = vector.Math.normalize(me.traj);
        }

        # Compute distance using trajectory from previous loop (feedback).
        var res = DistanceComputer.update(me.traj);
        me.dist = res[0];
        me.has_range = res[1];
        # Compute trajectory.
        res = sight.get_traj(me.dist, me.time, me.drop_dist);
        me.traj = res[0];
        me.time = res[1];
        me.drop_dist = res[2];
        # Compute firing distance.
        if (me.has_range) {
            res = FiringDistanceComputer.firing_distance(type, me.traj, TRUE);
            me.min_dist = res[0];
            me.opt_dist = res[1];
        }
    },

    # Returns reticle position in mils [right,down].
    get_pos: func {
        return [math.atan2(me.traj[1], me.traj[0])*1000, math.atan2(me.traj[2], me.traj[0])*1000];
    },

    # Returns [target distance, minimum evasion distance, minimum firing distance]
    # or 'nil' if the target distance could not be obtained (too shallow pitch angle).
    get_dist: func {
        if (!me.has_range) return nil;
        return [me.dist, me.min_dist, me.opt_dist];
    },
};



var loopJA = func {
    AGsightJA.reset_loop();
}

var loopAJS = func {
}

var loop = variant.JA ? loopJA : loopAJS;
