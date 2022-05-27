#version 120

varying vec3    VNormal;
varying vec3    eyeVec;

uniform sampler2D texture;
uniform float polaroid_filter;
uniform float time_norm;
uniform int display_mode;


// Shape off radar picture area, cf. displays/ci.nas
const float canvas_size = 144.0;
const vec2 center = vec2(canvas_size * 0.5, canvas_size * 0.5);

const vec2 PPI_origin = center + vec2(0, -64.0);
// From bottom point to top arc
const float PPI_radius = 120.0;
const float PPI_half_angle = radians(61.5);
// Length of the two bottom sides = maximum range at the limit angle
const float PPI_bottom_length = 60.0;
// Corners
const float PPI_side = sin(PPI_half_angle) * PPI_bottom_length;
const float PPI_side_bot = cos(PPI_half_angle) * PPI_bottom_length;
const float PPI_side_top = sqrt(PPI_radius * PPI_radius - PPI_side * PPI_side);   // is there a good builtin for that?
const vec2 PPI_bot_left = PPI_origin + vec2(-PPI_side, PPI_side_bot);
const vec2 PPI_top_left = PPI_origin + vec2(-PPI_side, PPI_side_top);
const vec2 PPI_bot_right = PPI_origin + vec2(PPI_side, PPI_side_bot);
const vec2 PPI_top_right = PPI_origin + vec2(PPI_side, PPI_side_top);
const float PPI_corner_angle = asin(PPI_side / PPI_radius);


const vec3 bg_color = vec3(0.3, 1.0, 0.3);
const vec3 rdr_color = vec3(0.0, 0.0, 0.0);
const vec3 symb_color = vec3(0.9, 1.0, 0.9);


void main() {
    vec2 pos = gl_TexCoord[0].st;
    vec3 color = vec3(0.0, 0.0, 0.0);

    if (display_mode == 1) {
        // PPI display
        vec2 PPI_pos = (pos * canvas_size) - PPI_origin;
        float dist = length(PPI_pos);
        float angle = atan(PPI_pos.x, PPI_pos.y);   // 0 = up axis, positive is right

        if (abs(angle) >= PPI_half_angle) {
            color = bg_color;
        } else if (abs(PPI_pos.x) < PPI_side && dist < PPI_radius) {
            vec2 radar_pos = vec2(
                angle / PPI_half_angle * 0.5 + 0.5,
                dist / PPI_radius
            );
            radar_pos = clamp(radar_pos, 0.0, 1.0);
            float radar = texture2D(texture, radar_pos).g;

            color = mix(bg_color, rdr_color, radar);
        }
    } else if (display_mode == 2) {
        // B-scope
    }

    // Symbols overlay (red component of texture)
    float symbols = texture2D(texture, pos).r;
    color = mix(color, symb_color, symbols);

    gl_FragColor.rgb = color;
    gl_FragColor.a = 1.0;
}
