#version 120

varying vec3 filter_color;
varying mat2 PPI_beam_mat;

uniform sampler2D texture;
uniform float time_norm;
uniform int display_mode;


// Index of metadata strips
#define INFO_TIME           0
#define INFO_RANGE          1
#define INFO_LINE_DEV       2
#define INFO_RANGE_MARKS    3
#define INFO_CROSS_RANGE    4
#define INFO_CROSS_AZI      5
// 67 are padding
#define N_INFO_STRIPS       8

#define SAMPLE_Y(index) (((index) + 0.5) / N_INFO_STRIPS)


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
#define COLOR_BG        1.0     // radar background
#define COLOR_RADAR     0.0     // radar echo
#define COLOR_BOTTOM    1.5     // below radar picture
#define COLOR_ORIGIN    0.5     // origin of PPI, never erased
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
        + max(1.0 - pow((beam_pos.x - BEAM_OFFSET) / BEAM_HALF_WIDTH, 2), 0.0);     // bright line at beam_offset
}


// transmission factor to neighbours
float decay(float age)
{
    return pow(0.1, age);
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

// PPI bounds, to check against abs(PPI_coord()) with proper swizzling.
#define PPI_LIMIT_xzw vec3(PPI_SIDE, PPI_RADIUS, PPI_HALF_ANGLE)

// Lookup radar echo strength for a given position.
// Argument PPI_pos as given by PPI_coord().
//
float radar_texture_PPI(vec4 PPI_pos)
{
    vec2 radar_pos = PPI_pos.wz * vec2(1.0 / PPI_ANGLE, 1.0 / PPI_RADIUS) + vec2(0.5, 0.0);
    radar_pos = clamp(radar_pos, 0.0, 1.0);
    return texture2D(texture, radar_pos).g;
}

float get_metadata(vec4 PPI_pos, int index)
{
    vec2 radar_pos = vec2(PPI_pos.w * (1.0 / PPI_ANGLE) + 0.5, SAMPLE_Y(index));
    radar_pos = clamp(radar_pos, 0.0, 1.0);
    return texture2D(texture, radar_pos).b;
}


// A small area around origin is never erased

#define LEFTMOST_BEAM_NORMAL vec2(cos(PPI_HALF_ANGLE), sin(PPI_HALF_ANGLE))

bool not_erased(vec4 PPI_pos)
{
    if (length(PPI_pos.xy) < BEAM_OFFSET - BEAM_HALF_WIDTH)
        return true;    // too close to the center to be erased

    if (abs(PPI_pos.w) >= radians(90.0) - PPI_HALF_ANGLE)
        // There is a moment where PPI_ORIGIN -> PPI_pos is orthogonal to the beam,
        // thus the previous test was tight.
        return false;

    // For the remaining points, the only thing which matters is the erasing beam position at the two extreme angles.
    return dot(abs(PPI_pos.xy), LEFTMOST_BEAM_NORMAL) < BEAM_OFFSET - BEAM_HALF_WIDTH;
}


// Range and azimuth lines
#define LINE_HALF_WIDTH 0.004

#define SIDE_LINE_ANGLE     radians(30)
#define LINE_LEFT_NORMAL    vec2(cos(SIDE_LINE_ANGLE), sin(SIDE_LINE_ANGLE))
#define LINE_RIGHT_NORMAL   vec2(cos(SIDE_LINE_ANGLE), -sin(SIDE_LINE_ANGLE))

#define RANGE_ARC_1 (PPI_RADIUS * 10.0 / 120.0)
#define RANGE_ARC_2 (PPI_RADIUS * 20.0 / 120.0)
#define RANGE_ARC_3 (PPI_RADIUS * 40.0 / 120.0)
#define RANGE_ARC_4 (PPI_RADIUS * 80.0 / 120.0)

float get_lines_PPI(vec4 PPI_pos, float range)
{
    if (range < 0.125) return 0.0;

    // normalized distance to closest line
    float dist = abs(PPI_pos.x);

    dist = min(dist, abs(dot(PPI_pos.xy, LINE_LEFT_NORMAL)));
    dist = min(dist, abs(dot(PPI_pos.xy, LINE_RIGHT_NORMAL)));

    // range arcs
    dist = min(dist, distance(PPI_pos.z, RANGE_ARC_4));
    if (range > 0.375)
        dist = min(dist, distance(PPI_pos.z, RANGE_ARC_3));
    if (range > 0.625)
        dist = min(dist, distance(PPI_pos.z, RANGE_ARC_2));
    if (range > 0.875)
        dist = min(dist, distance(PPI_pos.z, RANGE_ARC_1));

    if (dist > LINE_HALF_WIDTH)
        return 0.0;
    else
        return 1.0 - pow(dist / LINE_HALF_WIDTH, 3);
}


vec4 CI_screen_color() {
    vec2 pos = gl_TexCoord[0].st;

    float intensity = 0.0;

    if (display_mode == 1) {
        // PPI display
        vec4 PPI_pos = PPI_coord(pos);
        float beam_int = beam_int(PPI_pos);

        if (abs(PPI_pos.w) >= PPI_HALF_ANGLE) {
            intensity = max(COLOR_BOTTOM, beam_int);
        } else if (not_erased(PPI_pos)) {
            intensity = COLOR_ORIGIN;
        } else if (!all(lessThan(abs(PPI_pos.xzw), PPI_LIMIT_xzw))) {
            intensity = beam_int - COLOR_BG;    // erasing beam is dim in this area
        } else {
            // (strength, age)
            float radar = radar_texture_PPI(PPI_pos);
            float time = get_metadata(PPI_pos, INFO_TIME);
            float age = fract(time_norm - time);
            // noise
            radar = clamp(radar + 0.2 * noise1(vec3(PPI_pos.xy, time) * 200), 0.0, 1.0);

            float range = get_metadata(PPI_pos, INFO_RANGE);
            radar = max(radar, get_lines_PPI(PPI_pos, range));

            radar *= decay(age);

            intensity = mix(COLOR_BG, COLOR_RADAR, radar);
            intensity = max(intensity, beam_int);
        }
    } else if (display_mode == 2) {
        // B-scope
    }

    // Symbols overlay (red component of texture)
    float symbols = texture2D(texture, pos).r;
    intensity = mix(intensity, COLOR_SYMBOLS, symbols);

    return vec4(clamp(filter_color * intensity, 0.0, 1.0), 1.0);
}
