var TRUE = 1;
var FALSE = 0;

var input = {
    time: "sim/time/elapsed-sec",
    heading: "orientation/heading-deg",
};

foreach(var name; keys(input)) {
    input[name] = props.globals.getNode(input[name], 1);
}




### Radar data buffer and update thread.

## Radar data for terrain query along a given azimuth.
#
# API:
# Initialize with init().
# Call update() to perform terrain query along a given azimuth.
#
# After update(), the results can be obtained as a normalized radar echo density,
# function of distance.
# Call start_density_queries(), then perform a sequence of queries with
# _increasing_ distances, using get_density_incr().

var AzimuthData = {
    # Density returned by get_density_incr if distances are uniformly distributed.
    avg_density: 0.25,

    new: func {
        var m = { parents: [AzimuthData], };
    },

    init: func(vert_res, beam_width, range) {
        me.dists = [];
        me.d_dists = [];
        setsize(me.dists, vert_res);
        setsize(me.d_dists, vert_res+1);

        me.elev_step = beam_width / (vert_res-1);
        me.elev_start_offset = beam_width / 2;
        me.max_range = range;
        me.last_dist = me.max_range;
    },

    # Radar return along given azimuth/elevation
    #
    # Wrapper for get_cart_ground_intersection. Arguments:
    #   ac_pos:     radar position, as geo.Coord object.
    #   heading:    aircraft true heading
    #   azimuth:    radar azimuth (relative to aircraft heading)
    #   elevation:  radar elevation
    # Returns distance to ground along radar beam.
    get_distance: func(ac_pos, heading, azimuth, elevation) {
        var end = geo.Coord.new(ac_pos);
        end.apply_course_distance(heading+azimuth, 100);
        end.set_alt(end.alt() + 100 * math.tan(elevation*D2R));

        var pos = {"x": ac_pos.x(), "y": ac_pos.y(), "z": ac_pos.z()};
        var dir = {"x": end.x()-ac_pos.x(), "y": end.y()-ac_pos.y(), "z": end.z()-ac_pos.z()};
        var terrain = get_cart_ground_intersection(pos, dir);
        if (terrain == nil) return me.max_range;

        end.set_latlon(terrain.lat, terrain.lon, terrain.elevation);
        return ac_pos.direct_distance_to(end);
    },

    # Update distance data along a given azimuth.
    #
    # This performs a number of distance queries with elevation varying around
    # the radar beam center (at most beam_width/2 elevation difference).
    #   ac_pos:     radar position, as geo.Coord object.
    #   heading:    aircraft true heading
    #   azimuth:    radar azimuth (relative to aircraft heading)
    #   elevation:  radar beam center elevation
    update: func(ac_pos, heading, azimuth, elevation) {
        var elev = elevation - me.elev_start_offset;
        forindex (var i; me.dists) {
            me.dists[i] = me.get_distance(ac_pos, heading, azimuth, elev);
            elev += me.elev_step;
        }

        # Update derivative of distances, used to compute density.
        forindex (var i; me.dists) {
            if (i > 0) me.d_dists[i] = me.dists[i] - me.dists[i-1];
        }
        me.d_dists[0] = me.d_dists[1];
        me.d_dists[size(me.dists)] = me.d_dists[size(me.dists)-1];
    },

    start_density_queries: func {
        me.last_dist = 0;
        me.segment_id = 0;  # me.last_dist is between me.dists[me.segment_id-1] and me.dists[me.segment_id]
    },

    get_density_incr: func(dist) {
        if (dist < me.last_dist) {
            print("Error: decreasing distances in AzimuthData.get_density_incr(), returning 0");
            return 0;
        }
        me.last_dist = dist;
        # Find the interval of me.dists in which the query is located.
        while (me.segment_id < size(me.dists) and dist > me.dists[me.segment_id]) {
            me.segment_id += 1;
        }
        # Too far/close
        if (me.segment_id <= 0 or me.segment_id >= size(me.dists)) return 0;

        # Density is the inverse of the derivative of the distance, function of elevation.
        # Quadratic interpolation of the derivative:

        # Interpolation parameter
        var t = (dist - me.dists[me.segment_id-1])
            / (me.dists[me.segment_id] - me.dists[me.segment_id-1]);
        var d = me.d_dists[me.segment_id] * (0.5 + t - t*t)
            + me.d_dists[me.segment_id-1] * (1-t) * (1-t)
            + me.d_dists[me.segment_id+1] * t  * t;
        if (d < 0.001) d = 0.001;   # Let's not divide by 0
        # Density is 1/4 if distances are uniformly distributed.
        d = me.avg_density * me.max_range / (size(me.dists)-1) / d;

        return math.clamp(d, 0, 1);
    },
};


## Ground radar
#
# This object implements terrain queries and computations of radar picture.
#
var GroundRadar = {
    # Radar parameters
    range: 60000,       # meters
    hor_res: 128,       # Radar FOV is split into that many azimuths
    vert_res: 32,       # Number of terrain queries for a given azimuth
    half_angle: 61.5,   # Centerline-limit angle, degrees
    half_period: 1.12,  # Half period (full sweep in one direction, but not the return), seconds
    beam_width: 4,      # Max angle from the radar beam centerline.
    # Manual says 3.6, but it isn't a precise limit. Make it 4, and the ends of the beam are made weaker.
    elevation: -1.5,


    ac_pos: nil,
    heading: nil,
    ac_info_lock: thread.newlock(),

    # Terrain queries run in a background thread.
    # This is the size of the buffer it uses to communicate its data,
    # in number of azimuth steps (half_angle*2 / hor_res).
    #
    # It restricts how much advance the terrain queries thread can have  compared
    # to the rendering thread. At low FPS, it effectively restricts the number of
    # azimuth steps updated in one frame.
    buffer_size: 16,
    buffer: [],
    buffer_azimuths: [],

    # Read / write positions in the buffer
    read_ind: 0,
    write_ind: 0,

    # Buffer update thread controls
    buffer_free: nil,
    buffer_filled: 0,
    buffer_filled_lock: thread.newlock(),
    stop_radar: FALSE,
    thread_running: thread.newlock(),

    # Radar antenna position
    radar_step: 0,  # From 0 to hor_res-1
    radar_dir: 1,   # 1: left-to-right, -1: right-to-left

    init: func {
        setsize(me.buffer, me.buffer_size);
        setsize(me.buffer_azimuths, me.buffer_size);
        forindex(var i; me.buffer) {
            me.buffer[i] = AzimuthData.new();
            me.buffer[i].init(me.vert_res, me.beam_width, me.range);
        }

        me.read_ind = 0;
        me.write_ind = 0;
        me.buffer_free = thread.newsem();
        me.buffer_filled = 0;
        for (var i=1; i<me.buffer_size; i+=1) thread.semup(me.buffer_free);
        me.stop_radar = FALSE;

        thread.newthread(func {

            call(me.update_loop, nil, me, nil, var err = []);
            if (size(err)) {
                print("Nasal error in ground radar thread:");
                debug.printerror(err);
            }
        });
    },

    destroy: func {
        me.stop_radar = TRUE;

        thread.lock(me.thread_running);
        thread.unlock(me.thread_running);
    },

    set_ac_info: func(ac_pos, heading) {
        thread.lock(me.ac_info_lock);
        me.ac_pos = ac_pos;
        me.heading = heading;
        thread.unlock(me.ac_info_lock);
    },

    update_loop: func {
        thread.lock(me.thread_running);

        var ac_pos = geo.Coord.new();
        var heading = 0;
        var azimuth = 0;

        while (1) {
            if (me.stop_radar) return;

            thread.semdown(me.buffer_free);

            # Obtain aircraft postion from main thread.
            thread.lock(me.ac_info_lock);
            ac_pos.set(me.ac_pos);
            heading = me.heading;
            thread.unlock(me.ac_info_lock);

            # Compute next azimuth
            if (me.radar_step <= 0 and me.radar_dir == -1) me.radar_dir = 1;
            elsif (me.radar_step >= me.hor_res - 1 and me.radar_dir == 1) me.radar_dir = -1;
            me.radar_step += me.radar_dir;

            azimuth = me.half_angle * (me.radar_step / (me.hor_res-1) * 2 - 1);
            me.buffer_azimuths[me.write_ind] = azimuth;

            # Query terrain
            me.buffer[me.write_ind].update(ac_pos, heading, azimuth, me.elevation);

            # Move to next buffer position
            me.write_ind += 1;
            if (me.write_ind >= me.buffer_size) me.write_ind = 0;

            thread.lock(me.buffer_filled_lock);
            me.buffer_filled += 1;
            thread.unlock(me.buffer_filled_lock);
        }

        thread.unlock(me.thread_running);
    },

    # Request next radar data from buffer.
    #
    # Returns a pair [azimuth, AzimuthData].
    # When called, it is assumed that the results of the _previous_ call to
    # get_next_azimuth_data are no longer used. They will be reused/modified.
    # Copy them first if necessary.
    get_next_azimuth_data: func {
        var empty = FALSE;
        thread.lock(me.buffer_filled_lock);
        if (me.buffer_filled <= 0) empty = TRUE;
        else me.buffer_filled -= 1;
        thread.unlock(me.buffer_filled_lock);

        if (empty) return nil;

        var res = [me.buffer_azimuths[me.read_ind], me.buffer[me.read_ind]];
        me.read_ind += 1;
        if (me.read_ind >= me.buffer_size) me.read_ind = 0;
        thread.semup(me.buffer_free);

        return res;
    },
};




### Display

var cvs = canvas.new({
    "name": "CI",
    "size": [512,512],
    "view": [512,512],
    "mipmapping": 0,
});

cvs.addPlacement({"node": "radarScreen", "texture": "radar-canvas.png"});
cvs.setColorBackground(0,0,0);

var root = cvs.createGroup();

# B-scope, to simplify
var scope = root.createChild("group")
    .setTranslation(256,384);

var res = 128;

var image = scope.createChild("image")
    .setTranslation(-128,-256)
    .setScale(2)
    .set("size", "[128,128]")
    .set("fill", "#33cc33")
    .set("src", "Aircraft/JA37/Nasal/displays/ci.png");
image.fillRect([0,0,res,res], "#ffffff");



var azi_to_x = func(azi) {
    return res * (azi / GroundRadar.half_angle * 0.5 + 0.5);
}

var y_to_dist = func(y) {
    return y / res * GroundRadar.range;
}

var update_image = func(azimuth, data) {
    var x = azi_to_x(azimuth);
    data.start_density_queries();

    for (var y=0; y<res; y+=1) {
        var dist = y_to_dist(y);
        var color = 1 - data.get_density_incr(dist);
        image.setPixel(x, y, [color,color,color,1]);
    }
}


var last_time = 0;

var loop = func {
    GroundRadar.set_ac_info(geo.aircraft_position(), input.heading.getValue());

    var time = input.time.getValue();
    var dt = time - last_time;
    var steps = int(dt / GroundRadar.half_period * res);

    while (steps > 0) {
        var res = GroundRadar.get_next_azimuth_data();
        # Radar thread is slower than us! Stop here, we don't want to block.
        if (res == nil) break;

        #update_image(res[0], res[1]);
        steps -= 1;
    }

    #image.dirtyPixels();

    last_time = time;
}

var timer = maketimer(0, loop);
timer.simulatedTime = 1;

var init = func {
    GroundRadar.set_ac_info(geo.aircraft_position(), input.heading.getValue());
    GroundRadar.init();
    timer.start();
}

var exit = func {
    timer.stop();
    GroundRadar.destroy();
}


setlistener("/sim/signals/fdm-initialized", init);
setlistener("/sim/signals/exit", exit);
