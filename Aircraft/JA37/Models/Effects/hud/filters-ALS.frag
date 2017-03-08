// -*-C++-*-

// This is a library of filter functions

// Thorsten Renk 2016

#version 120

uniform float gamma;
uniform float brightness;
uniform float delta_T;
uniform float osg_SimulationTime;
uniform float fact_grey;
uniform float fact_black;

uniform bool use_filtering;
uniform bool use_night_vision;
uniform bool use_IR_vision;

uniform int display_xsize;
uniform int display_ysize;

float Noise2D(in vec2 coord, in float wavelength);

vec3 gamma_correction (in vec3 color) {


float value = length(color)/1.732;
return pow(value, gamma) * color;

}

vec3 brightness_adjust (in vec3 color) {

return clamp(brightness * color, 0.0, 1.0);

}

vec3 night_vision (in vec3 color) {

float value = length(color)/1.732;

vec2 center = vec2 (float(display_xsize) * 0.5, float(display_ysize) * 0.5);
float noise = Noise2D( vec2 (gl_FragCoord.x + 100.0 * osg_SimulationTime, gl_FragCoord.y + 300.0 * osg_SimulationTime), 4.0);

float fade = 1.0 - smoothstep( 0.3 * display_ysize, 0.55 * display_ysize, length(gl_FragCoord.xy -center));

return vec3 (0.0, 1.0, 0.0) * value * (0.5 + 0.5 * noise) * fade;

}


vec3 IR_vision (in vec3 color) {

float value = length(color)/1.732;
value = 1.0 - value;

float T_mapped = smoothstep(-10.0, 10.0, delta_T);

float gain = mix(T_mapped, value, 0.5);
//float gain = 0.2 * T_mapped + 0.8 * value * T_mapped;
if (delta_T < -10.0) {gain = 0.0;}


return vec3 (0.7, 0.7, 0.7) * gain;

}



vec3 g_force (in vec3 color) {

vec2 center = vec2 (float(display_xsize) * 0.5, float(display_ysize) *  0.5);

float greyout_band_width = 0.2;
float blackout_band_width = 0.3;

float f_grey = 1.0 - fact_grey;

float greyout = smoothstep( f_grey * display_ysize, (f_grey + greyout_band_width) * display_ysize, length(gl_FragCoord.xy -center));

float tgt_brightness = (1.0 - 0.5 * greyout);

float noise = Noise2D( vec2 (gl_FragCoord.x + 100.0 * osg_SimulationTime,  
gl_FragCoord.y + 300.0 * osg_SimulationTime), 8.0);

float f_black = 1.0 - fact_black;

noise *= (1.0 - smoothstep(0.0, 0.5, f_black));

color = mix(color, vec3 (1.0, 1.0, 1.0) * mix(length(color),  
tgt_brightness, greyout)  , 0.9* greyout + 0.6 * noise);
color *= tgt_brightness;

float blackout = 1.0 - smoothstep( f_black * display_ysize, (f_black + blackout_band_width) * display_ysize, length(gl_FragCoord.xy -center));

color *= blackout;

return color;

}

vec3 filter_combined (in vec3 color) {

if (use_filtering == false)
	{
	return color;
	}

color = g_force(color);


if (use_night_vision)
	{
	color = brightness_adjust(color);
	color = night_vision(color);
	}

else if (use_IR_vision)
	{
	float IR_brightness = min(1.0/(brightness+0.01), 5.0);
	color = clamp(IR_brightness * color, 0.0, 1.0);
	color = IR_vision(color);
	}
else
	{
	color = brightness_adjust(color);
	}	

return gamma_correction (color);

}


