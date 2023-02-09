#version 120

varying vec3 filter_color;
varying mat2 PPI_beam_mat;

uniform sampler2D texture;
uniform float current_time1;
uniform float current_time2;
uniform int display_mode;
uniform int beam_dir;


float Noise3D(vec3 coord, float wavelength);


// Pixel half-size in texture coordinates, for antialiasing.
float p_size = 0.0;

// Index of metadata strips
#define INFO_TIME1          0
#define INFO_TIME2          1
#define INFO_RANGE          2
#define INFO_AZIMUTH        3
#define INFO_DISTANCE       4
// 5--7 are padding
#define N_INFO_STRIPS       8

#define SAMPLE_Y(index) (((index) + 0.5) / N_INFO_STRIPS)

#define TIME1_FACTOR        60.0
#define TIME2_FACTOR        1920.0


// Shape off radar picture area, cf. displays/ci.nas
#define CANVAS_SIZE         144.0
#define CENTER              vec2(0.5, 0.5)

#define PPI_ORIGIN          (CENTER + vec2(0, -64.0 / CANVAS_SIZE))
// From bottom point to top arc
#define PPI_RADIUS          (120.0 / CANVAS_SIZE)
#define PPI_HALF_ANGLE      radians(61.5)
#define PPI_ANGLE           (2.0 * PPI_HALF_ANGLE)
// Length of the two bottom sides = maximum range at the limit angle
#define PPI_BOTTOM_LENGTH   (60.0 / CANVAS_SIZE)
// Distance left side / centerline
#define PPI_SIDE            (sin(PPI_HALF_ANGLE) * PPI_BOTTOM_LENGTH)


// Intensity for various parts of image
#define COLOR_BASE      0.4     // natural color, of area not illuminated by either electron cannon
#define COLOR_BG        1.0     // radar background
#define COLOR_RADAR     0.0     // radar echo
#define COLOR_BOTTOM    1.5     // below radar picture
#define COLOR_SYMBOLS   3.0     // bright symbol overlay


// Sweeping beam
// Consists of two electron canons: one erasing (very bright line), and one drawing.
// The drawing one is aligned with PPI_origin, the erasing one is offset forward.
#define BEAM_OFFSET     0.045   // offset of erasing canon
#define BEAM_HALF_WIDTH 0.005   // width of bright line produced by erasing canon

float beam_int(vec4 PPI_pos)
{
    vec2 beam_pos = PPI_beam_mat * PPI_pos.xy;

    if (beam_pos.x < 0.0 || beam_pos.x > BEAM_OFFSET + BEAM_HALF_WIDTH || beam_pos.y < 0.0)
        return 0.0;

    return COLOR_BG + 1.2 * pow(beam_pos.x / BEAM_OFFSET, 2.0)                      // band down to bg_color
        + max(1.0 - pow((beam_pos.x - BEAM_OFFSET) / BEAM_HALF_WIDTH, 2.0), 0.0);   // bright line at beam_offset
}


// transmission factor to neighbours
float decay(float age)
{
    return mix(pow(0.5, age/30.0), pow(0.9, pow(age * 2.0 - 1.0, 2.0)), 0.1);
}

// PPI coordonates.
// xy = PPI cartesian coordinates
// zw = PPI polar coordinates (with angle=0 -> up axis, positive right)
//
vec4 PPI_coord(vec2 pos)
{
    vec4 res;
    res.xy = pos - PPI_ORIGIN;
    res.z = length(res.xy);
    res.w = atan(res.x, res.y);
    return res;
}

// PPI bounds
//
// Returns a vector of distances to the different areas of the PPI.
// x: bottom (bright) part
// y: top (black) part
// z: origin (grey, never cleared) part
//
// For each coordinate, positive values are inside said area.
// If the vector is non-positive, the point is inside the PPI.

// Normal vectors to bottom two sides
#define PPI_BOTTOM_LEFT_NORMAL      vec2(-cos(PPI_HALF_ANGLE), -sin(PPI_HALF_ANGLE))
#define PPI_BOTTOM_RIGHT_NORMAL     vec2(cos(PPI_HALF_ANGLE), -sin(PPI_HALF_ANGLE))

vec3 PPI_bounds_dist(vec4 PPI_pos)
{
    float bot_dist = max(
        dot(PPI_pos.xy, PPI_BOTTOM_LEFT_NORMAL),
        dot(PPI_pos.xy, PPI_BOTTOM_RIGHT_NORMAL)
    );

    float top_dist = max(
        PPI_pos.z - PPI_RADIUS,
        abs(PPI_pos.x) - PPI_SIDE
    );

    // center area which is never erased, approximated as a circle.
    float origin_dist = BEAM_OFFSET - BEAM_HALF_WIDTH - PPI_pos.z;

    return vec3(bot_dist, top_dist, origin_dist);
}

// LOD bias for polar texture lookup (to be divided by PPI_pos.z)
// Otherwise GL built-in LOD estimate is messed up at the origin,
// due to the polar->cartesian transformation singularity.
#define POLAR_LOD_BIAS_FACTOR   (-10)

// Lookup radar echo strength for a given position.
// Argument PPI_pos as given by PPI_coord().

float radar_texture_PPI(vec4 PPI_pos)
{
    vec2 radar_pos = PPI_pos.wz * vec2(1.0 / PPI_ANGLE, 1.0 / PPI_RADIUS) + vec2(0.5, 0.0);
    radar_pos = clamp(radar_pos, 0.0, 1.0);
    return texture2D(texture, radar_pos, POLAR_LOD_BIAS_FACTOR / PPI_pos.z).g;
}

float get_metadata(vec4 PPI_pos, int index)
{
    vec2 radar_pos = vec2(PPI_pos.w * (1.0 / PPI_ANGLE) + 0.5, SAMPLE_Y(index));
    radar_pos = clamp(radar_pos, 0.0, 1.0);
    return texture2D(texture, radar_pos, POLAR_LOD_BIAS_FACTOR / PPI_pos.z).b;
}


// Range and azimuth lines
#define LINE_HALF_WIDTH 0.003

#define SIDE_LINE_ANGLE     radians(30.0)
#define LINE_LEFT_NORMAL    vec2(cos(SIDE_LINE_ANGLE), sin(SIDE_LINE_ANGLE))
#define LINE_RIGHT_NORMAL   vec2(cos(SIDE_LINE_ANGLE), -sin(SIDE_LINE_ANGLE))

#define RANGE_ARCS          (vec4(10.0, 20.0, 40.0, 80.0) * PPI_RADIUS / 120.0)
#define RANGE_MARKS         (vec2(12.0, 24.0) * PPI_RADIUS / 120.0)

#define RANGE_MARK_HALF_ANGLE   radians(9.0)

#define MIN_vec2(v)     min(v.x, v.y)
#define MIN_vec4(v)     min(min(v.x, v.y), min(v.z, v.w))

#define CURSOR_HALF_SIZE    (0.15 * PPI_RADIUS)

float get_lines_PPI(vec4 PPI_pos)
{
    // normalized distance to closest line
    float dist = CANVAS_SIZE;

    float range = get_metadata(PPI_pos, INFO_RANGE);

    if (range > 0.125) {
        // normal presentation

        // multiply RANGE_ARCS / RANGE_MARKS by this
        float range_factor = range > 0.625 ? (range > 0.875 ? 1.0 : 2.0) : (range > 0.375 ? 4.0 : 8.0);

        // azimuth lines
        // center (can move)
        float azi = get_metadata(PPI_pos, INFO_AZIMUTH) * 2.0 * PPI_HALF_ANGLE - PPI_HALF_ANGLE;
        vec2 normal = vec2(cos(azi), -sin(azi));
        dist = min(dist, abs(dot(PPI_pos.xy, normal)));
        // sides (fixed)
        dist = min(dist, abs(dot(PPI_pos.xy, LINE_LEFT_NORMAL)));
        dist = min(dist, abs(dot(PPI_pos.xy, LINE_RIGHT_NORMAL)));

        if (get_metadata(PPI_pos, INFO_DISTANCE) > 0.5) {
            // Rb04 aiming marks
            if (distance(PPI_pos.w, azi) <= RANGE_MARK_HALF_ANGLE) {
                vec2 marks_dist = abs(RANGE_MARKS * range_factor - PPI_pos.z);
                dist = min(dist, MIN_vec2(marks_dist));
            }
        }

        vec4 arcs_dist = abs(RANGE_ARCS * range_factor - PPI_pos.z);
        dist = min(dist, MIN_vec4(arcs_dist));
    } else {
        // Fix-taking mode

        // Cursor position
        float range = get_metadata(PPI_pos, INFO_DISTANCE) * PPI_RADIUS;
        float azi = get_metadata(PPI_pos, INFO_AZIMUTH) * 2.0 * PPI_HALF_ANGLE - PPI_HALF_ANGLE;

        // vertical line
        if (distance(PPI_pos.z, range) <= CURSOR_HALF_SIZE) {
            vec2 normal = vec2(cos(azi), -sin(azi));
            dist = min(dist, abs(dot(PPI_pos.xy, normal)));
        }
        // horizontal line
        float angle_size = CURSOR_HALF_SIZE / range;
        if (distance(PPI_pos.w, azi) <= angle_size) {
            dist = min(dist, distance(PPI_pos.z, range));
        }
    }

    return (1.0 - smoothstep(LINE_HALF_WIDTH - p_size, LINE_HALF_WIDTH + p_size, dist));
}


vec4 CI_screen_color() {
    vec2 pos = gl_TexCoord[0].st;

    // Pixel half-size
    p_size = length(vec4(dFdx(pos), dFdy(pos))) * 0.5;

    float intensity = 0.0;

    if (display_mode == 1) {
        // PPI display
        vec4 PPI_pos = PPI_coord(pos);

        // interpolation coefficients between the different PPI border areas
        vec3 coefs = smoothstep(-p_size, p_size, PPI_bounds_dist(PPI_pos));

        float bottom_coef = coefs.x;
        float border_coef = coefs.y;
        float top_coef = max(border_coef - bottom_coef, 0.0);
        float origin_coef = coefs.z;

        // Actual display area
        float radar = 0.0;
        float radar_decay = 0.0;
        if (all(lessThan(coefs, vec3(1.0, 1.0, 1.0)))) {
            radar = radar_texture_PPI(PPI_pos);
            float time1 = get_metadata(PPI_pos, INFO_TIME1);
            float time2 = get_metadata(PPI_pos, INFO_TIME2);
            float age = fract(current_time2 - time2) * TIME2_FACTOR;
            if (age <= TIME1_FACTOR * 0.9) {
                age = fract(current_time1 - time1) * TIME1_FACTOR;
            }
            radar_decay = decay(age);

            // noise from radar
            radar = clamp(radar + 0.12 * Noise3D(vec3(PPI_pos.xy, time1), 0.006) - 0.06, 0.0, 1.0);

            radar = max(radar, get_lines_PPI(PPI_pos));
        }

        // Combine radar picture color with different borders. Order is important.

        intensity = mix(COLOR_BG, COLOR_RADAR, radar);                                  // radar picture
        intensity = mix(COLOR_BASE, intensity, radar_decay);                            // time decay
        intensity = mix(intensity, COLOR_BASE, origin_coef);                            // origin (never cleared)
        intensity += 0.06 * Noise3D(vec3(PPI_pos.xy, -current_time1), 0.002) - 0.03;    // display noise
        intensity = mix(intensity, 0.0, border_coef);                                   // black top area
        intensity = mix(intensity, COLOR_BOTTOM, bottom_coef);                          // bright bottom area

        // Add beam sweep effect
        float beam_int = beam_dir == 0 ? 0.0 : beam_int(PPI_pos);

        beam_int -= beam_int * origin_coef;

        // beam is weaker in dark top area
        // (coefs.y represents a zone which also intersects the bottom area, which is why coefs.x is subtracted)
        beam_int -= COLOR_BG * top_coef;

        intensity = max(intensity, beam_int);
    } else if (display_mode == 2) {
        // B-scope
    }

    // Symbols overlay (red component of texture)
    float symbols = texture2D(texture, pos).r;
    intensity = mix(intensity, COLOR_SYMBOLS, symbols);

    return vec4(clamp(filter_color * intensity, 0.0, 1.0), 1.0);
}
