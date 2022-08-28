// -*-C++-*-

// CI effect
// This is FG 2020.4 Shaders/default.vert with a call to CI shader plugged in.

// Ambient term comes in gl_Color.rgb.
#version 120

varying vec4 diffuse_term;
varying vec3 normal;
varying vec2 orthoTexCoord;
varying vec4 ecPosition;

uniform sampler2D texture;
uniform sampler2D orthophotoTexture;

////fog "include" /////
uniform int fogType;

uniform bool orthophotoAvailable;

vec3 fog_Func(vec3 color, int type);
//////////////////////

float getShadowing();
vec3 getClusteredLightsContribution(vec3 p, vec3 n, vec3 texel);

//// CI code include
vec4 CI_screen_color();
////

float luminance(vec3 color)
{
    return dot(vec3(0.212671, 0.715160, 0.072169), color);
}

void main()
{
    vec3 n;
    float NdotL, NdotHV, fogFactor;
    vec4 color = gl_Color;
    vec3 lightDir = gl_LightSource[0].position.xyz;
    vec3 halfVector = gl_LightSource[0].halfVector.xyz;
    vec4 texel;
    vec4 fragColor;
    vec4 specular = vec4(0.0);

    // If gl_Color.a == 0, this is a back-facing polygon and the
    // normal should be reversed.
    n = (2.0 * gl_Color.a - 1.0) * normal;
    n = normalize(n);

    NdotL = dot(n, lightDir);
    if (NdotL > 0.0) {
        float shadowmap = getShadowing();
        color += diffuse_term * NdotL * shadowmap;
        NdotHV = max(dot(n, halfVector), 0.0);
        if (gl_FrontMaterial.shininess > 0.0)
            specular.rgb = (gl_FrontMaterial.specular.rgb
                            * gl_LightSource[0].specular.rgb
                            * pow(NdotHV, gl_FrontMaterial.shininess)
                            * shadowmap);
    }
    color.a = diffuse_term.a;
    // This shouldn't be necessary, but our lighting becomes very
    // saturated. Clamping the color before modulating by the texture
    // is closer to what the OpenGL fixed function pipeline does.
    color = clamp(color, 0.0, 1.0);

    // CI code insert (this should be the only difference with the standard shader)
    texel = CI_screen_color();

    fragColor = color * texel + specular;
    fragColor.rgb += getClusteredLightsContribution(ecPosition.xyz, n, texel.rgb);

    fragColor.rgb = fog_Func(fragColor.rgb, fogType);
    gl_FragColor = fragColor;
}
