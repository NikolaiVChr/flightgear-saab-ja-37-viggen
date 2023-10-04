# forward and up are vectors defining a 3D frame.
# Compute azimuth and elevation of 'vector' in this frame.
#
# remarks: unpredictable result if up / forward are not orthogonal.
# Azimuth and elevation are in radian.
# Elevation is the angle (vector, up), 90 if vector and up are aligned, = -90 if opposed.
# Azimuth is the angle (vector, forward) after projection orthogonally to 'up'.
#
Math.vectorAziElevInFwdUpFrame = func(vec, forward, up) {
    me.elev = 90 - me.angleBetweenVectors(vec, up);
    vec = me.projVectorOnPlane(up, vec);
    if (me.magnitudeVector(vec) < 0.0001) {
        me.azi = 0;
    } else {
        me.azi = me.angleBetweenVectors(vec, forward);
        me.sign = me.dotProduct(up, me.crossProduct(vec, forward));
        if (me.sign < 0) me.azi = -me.azi;
    }
    return [me.azi, me.elev];
}

### Own aircraft position and attitude, stored as XYZ vectors.
#
# This allows to compute quickly azimuth / elevation in local frame to a coordinate.

var AircraftPosition = {
    time_prop: props.globals.getNode("sim/time/elapsed-sec"),
    last_time: -1,

    update: func {
        me.ac_pos = geo.aircraft_position();
        var tmp = aircraftToCart({x: 1000, y: 0, z: 0, });
        me.xyz_vec_fwd = [
            tmp.x - me.ac_pos.x(),
            tmp.y - me.ac_pos.y(),
            tmp.z - me.ac_pos.z(),
        ];
        tmp = aircraftToCart({x: 0, y: 0, z: -1000, });
        me.xyz_vec_up = [
            tmp.x - me.ac_pos.x(),
            tmp.y - me.ac_pos.y(),
            tmp.z - me.ac_pos.z(),
        ];
    },

    coordToLocalAziElev: func(coord) {
        me.time = me.time_prop.getValue();
        if (me.time != me.last_time) {
            me.update();
            me.last_time = me.time;
        }

        me.vec = Math.minus(coord.xyz(), me.ac_pos.xyz());
        return Math.vectorAziElevInFwdUpFrame(me.vec, me.xyz_vec_fwd, me.xyz_vec_up);
    },
};
