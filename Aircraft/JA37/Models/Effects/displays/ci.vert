#version 120

varying vec3 VNormal;
varying vec3 eyeVec;

void main() {
    vec4 ecPosition = gl_ModelViewMatrix * gl_Vertex;
    eyeVec = ecPosition.xyz;

    VNormal = normalize(gl_NormalMatrix * gl_Normal);

    gl_Position = ftransform();
    gl_ClipVertex = ecPosition;
    gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
}
