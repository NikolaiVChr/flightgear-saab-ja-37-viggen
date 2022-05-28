#version 120

varying vec3 VNormal;
varying vec3 eyeVec;

varying vec3 filter_color;
varying mat2 PPI_beam_mat;

uniform sampler2D texture;
uniform float time_norm;
uniform int display_mode;


// Shape off radar picture area, cf. displays/ci.nas
const float canvas_size = 144.0;
const vec2 center = vec2(0.5, 0.5);

const vec2 PPI_origin = center + vec2(0, -64.0 / canvas_size);
// From bottom point to top arc
const float PPI_radius = 120.0 / canvas_size;
const float PPI_half_angle = radians(61.5);
const float PPI_angle = PPI_half_angle * 2.0;
// Length of the two bottom sides = maximum range at the limit angle
const float PPI_bottom_length = 60.0 / canvas_size;
// Corners
const float PPI_side = sin(PPI_half_angle) * PPI_bottom_length;
const float PPI_side_bot = cos(PPI_half_angle) * PPI_bottom_length;
const float PPI_side_top = sqrt(PPI_radius * PPI_radius - PPI_side * PPI_side);   // is there a good builtin for that?
const vec2 PPI_bot_left = PPI_origin + vec2(-PPI_side, PPI_side_bot);
const vec2 PPI_top_left = PPI_origin + vec2(-PPI_side, PPI_side_top);
const vec2 PPI_bot_right = PPI_origin + vec2(PPI_side, PPI_side_bot);
const vec2 PPI_top_right = PPI_origin + vec2(PPI_side, PPI_side_top);
const float PPI_corner_angle = asin(PPI_side / PPI_radius);


// Intensity for various parts of image
const float bg_color = 1.0;         // radar background
const float rdr_color = 0.0;        // radar echo
const float bot_color = 1.5;        // below radar picture
const float origin_color = 0.5;     // origin of PPI, never erased
const float symb_color = 3.0;       // bright symbol overlay


// Sweeping beam
// Consists of two electron canons: one erasing (very bright line), and one drawing.
// The drawing one is aligned with PPI_origin, the erasing one is offset forward.
const float beam_offset = 0.045;        // offset of erasing canon
const float beam_half_width = 0.005;    // width of bright line produced by erasing canon

float beam_int (vec2 beam_pos)
{
    if (beam_pos.x < 0.0 || beam_pos.x > beam_offset + beam_half_width || beam_pos.y < 0.0)
        return 0.0;

    return bg_color + 1.2 * pow(beam_pos.x / beam_offset, 2.0)                      // band down to bg_color
        + max(1.0 - pow((beam_pos.x - beam_offset) / beam_half_width, 2), 0.0);     // bright line at beam_offset
}


// Neighbour sampling for image decay
const int n_samples = 4;
const float sample_dist = 0.005;
const vec2 sample_offset[n_samples] = vec2[](
    vec2(0.0, sample_dist),
    vec2(0.0, -sample_dist),
    vec2(sample_dist, 0.0),
    vec2(-sample_dist, 0.0)
);

// transmission factor to neighbours
float decay(float age)
{
    return pow(0.1, age);
}

float neighbour_trans(float age)
{
    return 0.4 - 0.4 * pow(0.1, age*50.0);
}

float decay_coef(float age)
{
    return decay(age) * (1.0 - neighbour_trans(age));
}

float decay_neighbour_coef(float age)
{
    return decay(age) * neighbour_trans(age) * 0.25;
}

// PPI coordonates.
// xy = PPI cartesian coordinates
// zw = PPI polar coordinates (with angle=0 -> up axis, positive right)
//
vec4 PPI_coord(vec2 pos)
{
    vec4 res;
    res.xy = pos - PPI_origin;
    res.z = length(res.xy);
    res.w = atan(res.x, res.y);
    return res;
}

// PPI bounds, to check against abs(PPI_coord()) with proper swizzling.
const vec3 PPI_limit_xzw = vec3(PPI_side, PPI_radius, PPI_half_angle);

// Convert PPI polar coordinates (dist, angle) to texture position to query for radar data.
vec2 radar_texture_coord(vec2 PPI_polar_coord)
{
    vec2 radar_pos = PPI_polar_coord.yx * vec2(1.0/PPI_angle, 1.0/PPI_radius) + vec2(0.5, 0.0);
    return clamp(radar_pos, 0.0, 1.0);
}

// Lookup radar echo for a given position.
// Argument PPI_pos as given by PPI_coord().
// Returns vec2(strength, age)
//
vec2 radar_texture_PPI(vec4 PPI_pos)
{
    vec2 data = texture2D(texture, radar_texture_coord(PPI_pos.zw)).gb;
    data.x = clamp(0.2 * noise1(vec3(PPI_pos.xy, data.y) * 200) + data.x, 0.0, 1.0);
    data.y = fract(time_norm - data.y);
    return data;
}


// A small area around origin is never erased
//
const vec2 leftmost_beam_orth = vec2(cos(PPI_half_angle), sin(PPI_half_angle));

bool not_erased(vec4 PPI_pos)
{
    if (length(PPI_pos.xy) < beam_offset - beam_half_width)
        return true;    // too close to the center to be erased

    if (abs(PPI_pos.w) >= radians(90.0) - PPI_half_angle)
        // There is a moment where PPI_origin -> PPI_pos is orthogonal to the beam,
        // thus the previous test was tight.
        return false;

    // For the remaining points, the only thing which matters is the erasing beam position at the two extreme angles.
    return dot(abs(PPI_pos.xy), leftmost_beam_orth) < beam_offset - beam_half_width;
}


void main()
{
    vec2 pos = gl_TexCoord[0].st;
    float intensity = 0.0;

    if (display_mode == 1) {
        // PPI display
        vec4 PPI_pos = PPI_coord(pos);
        float beam_int = beam_int(PPI_beam_mat * PPI_pos.xy);

        if (abs(PPI_pos.w) >= PPI_half_angle) {
            intensity = max(bot_color, beam_int);
        } else if (not_erased(PPI_pos)) {
            intensity = origin_color;
        } else if (!all(lessThan(abs(PPI_pos.xzw), PPI_limit_xzw))) {
            intensity = beam_int - bg_color;    // erasing beam is dim in this area
        } else {
            // (strength, age)
            vec2 radar = radar_texture_PPI(PPI_pos);
            float radar_str = radar.x * decay_coef(radar.y);

            // Sample neighbour pixels.
            float neighbours_str;
            for (int i=0; i<n_samples; i++) {
                vec2 sample_pos = pos + sample_offset[i];
                vec4 PPI_sample_pos = PPI_coord(sample_pos);
                if (!all(lessThan(abs(PPI_sample_pos.xzw), PPI_limit_xzw)))
                    continue;

                radar = radar_texture_PPI(PPI_sample_pos);
                radar_str += radar.x * decay_neighbour_coef(radar.y);
            }

            radar_str = min(radar_str, 1.0);
            intensity = mix(bg_color, rdr_color, radar_str);
            intensity = max(intensity, beam_int);
        }
    } else if (display_mode == 2) {
        // B-scope
    }

    // Symbols overlay (red component of texture)
    float symbols = texture2D(texture, pos).r;
    intensity = mix(intensity, symb_color, symbols);

    gl_FragColor.rgb = clamp(filter_color * intensity, 0.0, 1.0);
    gl_FragColor.a = 1.0;
}
