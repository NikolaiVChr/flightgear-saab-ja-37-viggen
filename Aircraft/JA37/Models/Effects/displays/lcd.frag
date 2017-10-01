// Author: Nikolai V. Chr.
// License: GPL v2
#version 120

varying vec3    VNormal;
varying vec3    eyeVec;

uniform sampler2D BaseTex;
uniform float innerAngle;//inside this angle the display is perfect
uniform float outerAngle;//from inner to outer the display gets more color distorted.
uniform float blackAngle;//from outer to this angle the display gets more black. From this angle to 90 the display stays black.
uniform int use_als;

const vec4  kRGBToYPrime = vec4 (0.299, 0.587, 0.114, 0.0);
const vec4  kRGBToI     = vec4 (0.596, -0.275, -0.321, 0.0);
const vec4  kRGBToQ     = vec4 (0.212, -0.523, 0.311, 0.0);

const vec4  kYIQToR   = vec4 (1.0, 0.956, 0.621, 0.0);
const vec4  kYIQToG   = vec4 (1.0, -0.272, -0.647, 0.0);
const vec4  kYIQToB   = vec4 (1.0, -1.107, 1.704, 0.0);

vec3 filter_combined (in vec3 color) ;

vec3 toHsl (in vec3 texel) {
    // Convert RGB to Hue, Saturation and Lightness
    float var_min = min(min(texel.r,texel.g),texel.b);
    float var_max = max(max(texel.r,texel.g),texel.b);
    float del_max = var_max - var_min;

    float l = (var_max + var_min) / 2;
    float h = 0;
    float s = 0;

    if (del_max != 0) {
        if (l < 0.5) {
                s = del_max / (var_max + var_min);
        } else {
                s = del_max / (2 - var_max - var_min);
        }

        vec3 del = (((var_max - texel) / 6) + (del_max / 2)) / del_max;

        if (texel.r == var_max) {
                h = del.b - del.g;
        } else if (texel.g == var_max) {
                h = (1 / 3) + del.r - del.b;
        } else if (texel.b == var_max) {
                h = (2 / 3) + del.g - del.r;
        }

        if (h < 0) {
                h += 1;
        }

        if (h > 1) {
                h -= 1;
        }
    }
    return vec3(h,s,l);
}

float oppositeHue (in float hue) {
    // get the complementary hue
    float h2 = hue + 0.5;

    if (h2 > 1) {
        h2 -= 1;
    }
    return h2;
}

float hue2rgb(in float v1,in float v2,in float vh) {
    // helper method
    if (vh < 0) {
            vh += 1;
    }

    if (vh > 1) {
            vh -= 1;
    }

    if ((6 * vh) < 1) {
            return v1 + (v2 - v1) * 6 * vh;
    }

    if ((2 * vh) < 1) {
            return v2;
    }

    if ((3 * vh) < 2) {
            return v1 + (v2 - v1) * ((2 / 3 - vh) * 6);
    }

    return v1;
}

vec3 hslOpposite (in float h, in float s, in float l) {
    // convert from HSL to RGB
    vec3 opposite = vec3(l,l,l);
    if (s != 0) {
        float var_2 = 0.0;
        if (l < 0.5) {
            var_2 = l * (1 + s);
        } else {
            var_2 = (l + s) - (s * l);
        }

        float var_1 = 2 * l - var_2;
        opposite.r = hue2rgb(var_1,var_2,h + (1 / 3));
        opposite.g = hue2rgb(var_1,var_2,h);
        opposite.b = hue2rgb(var_1,var_2,h - (1 / 3));
    }
    return opposite;
}

vec3 rotateHue (in vec4 color) {
    // Convert to YIQ
    float   YPrime  = dot (color, kRGBToYPrime);
    float   I      = dot (color, kRGBToI);
    float   Q      = dot (color, kRGBToQ);

    // Calculate the hue and chroma
    float   hue     = atan (Q, I);
    float   chroma  = sqrt (I * I + Q * Q);

    // Make the adjustment
    hue += radians(180.0);
    YPrime = 1 - YPrime;
    //if (hue > 1) {
    //    hue -= 1;
    //}

    // Convert back to YIQ
    Q = chroma * sin (hue);
    I = chroma * cos (hue);

    // Convert back to RGB
    vec4    yIQ   = vec4 (YPrime, I, Q, 0.0);
    color.r = dot (yIQ, kYIQToR);
    color.g = dot (yIQ, kYIQToG);
    color.b = dot (yIQ, kYIQToB);
    return color.rgb;
}

// todo:
// lightning including emission
// ALS filters

void main (void) {
    vec3 gamma      = vec3(1.0/2.2);// standard monitor gamma correction
    vec3 gammaInv   = vec3(2.2);
    vec4 texel      = texture2D(BaseTex, gl_TexCoord[0].st);
    

    vec3 eye = normalize(-eyeVec);
    vec3 N  = normalize(VNormal);
    float angle = degrees(acos(dot(N,eye)));//angle between normal and viewer
    vec3 color = vec3(0.0,0.0,0.0);
    if (angle <= innerAngle) {
        color = texel.rgb;
    } else if (angle <= outerAngle) {
        vec3 hsl = rotateHue(texel);//toHsl(texel.rgb);
        //hsl.x = oppositeHue(hsl.x);
        //hsl = hslOpposite(hsl.x,hsl.y,hsl.z);
        float amount = (angle - innerAngle)/(outerAngle-innerAngle);//(value - min) / (max - min);
        color = mix(texel.rgb, hsl, amount);
    } else if (angle <= blackAngle) {
        vec3 hsl = rotateHue(texel);//toHsl(texel.rgb);
        //hsl.x = oppositeHue(hsl.x);
        //hsl = hslOpposite(hsl.x,hsl.y,hsl.z);
        float amount = (angle - outerAngle)/(blackAngle-outerAngle);//(value - min) / (max - min)
        color = mix(hsl, vec3(0,0,0), amount);
    }
    color = pow(color, gammaInv);
    color = color * gl_FrontMaterial.emission.rgb;

    float phong = 0.0;
    vec3 Lphong = normalize(gl_LightSource[0].position.xyz);// - eyeVec
    if (dot(N, Lphong) > 0.0) {
        // lightsource is not behind
        vec3 Rphong = normalize(-reflect(Lphong,N));
        phong = pow(max(dot(Rphong,eye),0.0),gl_FrontMaterial.shininess);
        phong = clamp(phong, 0.0, 1.0);
    }
    vec4 specular = gl_FrontMaterial.specular * gl_LightSource[0].diffuse * phong;
    vec3 ambient = gl_FrontMaterial.ambient.rgb * gl_LightSource[0].ambient.rgb * gl_LightSource[0].ambient.rgb * 2;
    vec3 diffuse = gl_FrontMaterial.diffuse.rgb * gl_LightSource[0].diffuse.rgb;
    color = clamp(color+specular.rgb+ambient+diffuse, 0, 1);

    if (use_als > 0) {
        gl_FragColor = vec4(filter_combined(pow(color,gamma)), 0.0);
    } else {
        gl_FragColor = vec4(pow(color,gamma), 0.0);
    }
}