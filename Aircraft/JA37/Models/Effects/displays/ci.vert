#version 120

uniform float polaroid_filter;

varying vec3 VNormal;
varying vec3 eyeVec;

// These are actually uniform.
varying vec3 filter_color;

const vec3 color_bright = vec3(0.3, 1.0, 0.3);
const vec3 color_dim = vec3(1.0, 0.0, 0.0);

void main() {
    vec4 ecPosition = gl_ModelViewMatrix * gl_Vertex;
    eyeVec = ecPosition.xyz;

    VNormal = normalize(gl_NormalMatrix * gl_Normal);

    filter_color = mix(color_dim, color_bright, polaroid_filter) * polaroid_filter;

    gl_Position = ftransform();
    gl_ClipVertex = ecPosition;
    gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
}
