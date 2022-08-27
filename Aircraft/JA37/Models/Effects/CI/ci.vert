#version 120

uniform float polaroid_filter;
uniform float beam_pos;
uniform int beam_dir;

// These are actually uniform.
varying vec3 filter_color;
varying mat2 PPI_beam_mat;

const vec3 color_bright = vec3(0.3, 1.0, 0.3);
const vec3 color_dim = vec3(1.0, 0.0, 0.0);

const float PPI_half_angle = radians(61.5);


void CI_screen_prepare() {
    filter_color = mix(color_dim, color_bright, polaroid_filter) * polaroid_filter;

    float beam_angle = beam_pos * PPI_half_angle;
    PPI_beam_mat = mat2(
        beam_dir * cos(beam_angle), sin(beam_angle),
        -beam_dir * sin(beam_angle), cos(beam_angle)
    );
}
