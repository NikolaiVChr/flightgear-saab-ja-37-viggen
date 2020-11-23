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
};

foreach (var prop; keys(input)) {
    input[prop] = props.globals.getNode(input[prop]);
}


### Nasal interface to the AFALCOS A/A gunsight implemented in JSBSim
var AAsight = {
    # Update loop, simply to feed distance to the JSBSim system.
    loop: func {
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


### A/G gunsight
#
# Model.
# Call x the projectile velocity axis when firing, y the axis orthogonal to x on the vertical plane.
# Two simplifying assumptions are used:
# - Effect of gravity on the x axis is neglectable
# - Effect of drag on the y axis is neglectable
# Time of flight is obtained by solving the position equation for the x axis, with drag only.
# Drop distance is obtained by solving the position equation for the y axis, with gravity only.
#
# JSBSim body frame is [forward,right,down]
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
            # Gun normalized vector [forward, down]
            gun_vec: [math.cos(gun_angle), -math.sin(gun_angle)],

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
            input.vel_aero_y.getValue() * FT2M,
            input.vel_aero_z.getValue() * FT2M + me.muzzle_vel * me.gun_vec[1],
        ];
    },

    compute_dist: func {
        var pos = aircraftToCart({x:0, y:0, z:0});
        # Factor 1000 to for better accuracy.
        var dir = aircraftToCart({x:me.traj[0]*1000, y:me.traj[1]*1000, z:me.traj[2]*1000});
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

    loop: func {
        # The dist attribute is the real radar distance, stored for display.
        # The dist variable is the corrected distance used in the computation.
        me.dist = me.compute_dist();   # Computed using trajectory feedback.
        var dist = me.dist or me.max_dist;
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
        dist -= vector.Math.dotProduct(wind, init_dir) * me.time
            + vector.Math.dotProduct(down_vector, init_dir) * me.drop_dist;

        # Update flight time.
        var drag = me.drag_acc_coef(init_speed, me.rho());
        me.time = me.flight_time(dist, init_speed, drag);
        me.drop_dist = me.gravity_drop(me.time, init_speed, drag);

        # Final vector from aircraft to computed impact point.
        me.traj = vector.Math.plus(vector.Math.product(dist, init_dir), vector.Math.product(me.time, wind));
        me.traj = vector.Math.plus(me.traj, vector.Math.product(me.drop_dist, down_vector));
        me.traj = vector.Math.normalize(me.traj);
    },

    # Position of aiming reticles in mils [right,down].
    get_pos: func {
        return [math.atan2(me.traj[1], me.traj[0])*1000, math.atan2(me.traj[2], me.traj[0])*1000];
    },

    get_dist: func {
        if (me.dist != nil and me.dist <= me.max_dist) return me.dist;
        else return nil;
    },
};

var M75AGsight = AG_computer.new(0.36, 1030, 0.193, 0.000126677, 0, 8000);
var M70sight = AG_computer.new(45.4, 600, 0.0001, 0.005, 0, 8000);


# Main loop. Runs whatever sight is currently relevant.
var loop = func {
    if (modes.main_ja != modes.AIMING or fire_control.selected == nil) return;

    if (fire_control.selected.type == "M75 AKAN") {
        if (TI.ti.ModeAttack) {
            M75AGsight.loop();
        } else {
            AAsight.loop();
        }
    } elsif (fire_control.selected.type == "M70 ARAK") {
        M70sight.loop();
    }
}
