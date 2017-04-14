// -*-C++-*-

#version 120

// doing directionality is surprisingly complicated - with just the vector and the eye we can't
// do a spherical billboard, but the animation itself operates before the shader, so
// the model-coordinate to eye relationship is always the same
// thus we need to use pitch, yaw and roll to get the current model space coordinates

uniform	float pitch;
uniform	float roll;
uniform	float hdg;


varying vec3 vertex;
varying vec3 relPos;
varying vec3 normal;



void main()
{

vec4 ep = gl_ModelViewMatrixInverse * vec4(0.0,0.0,0.0,1.0);

  vec4 l  = gl_ModelViewMatrixInverse * vec4(0.0,0.0,1.0,1.0);
  vec3 u = normalize(ep.xyz - l.xyz);

  vec3 absu = abs(u);
  vec3 r = normalize(vec3(-u.y, u.x, 0.0));
  vec3 w = cross(u, r);

vertex = gl_Vertex.xyz;
relPos = vertex - ep.xyz;
normal = gl_NormalMatrix * gl_Normal;

  gl_Position = vec4(0.0, 0.0, 0.0, 1.0);
  gl_Position.xyz = gl_Vertex.x * u;
  gl_Position.xyz += gl_Vertex.y * r;
  gl_Position.xyz += gl_Vertex.z * w;
  gl_Position = gl_ModelViewProjectionMatrix * gl_Position;

//gl_Position = ftransform();
gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;

gl_FrontColor = vec4 (1.0,1.0,1.0,1.0);
gl_BackColor = gl_FrontColor;
}

/*

void rotationMatrixPR(in float sinRx, in float cosRx, in float sinRy, in float cosRy, out mat4 rotmat)
{
	rotmat = mat4(	cosRy ,	sinRx * sinRy ,	cosRx * sinRy,	0.0,
									0.0   ,	cosRx        ,	-sinRx * cosRx,	0.0,
									-sinRy,	sinRx * cosRy,	cosRx * cosRy ,	0.0,
									0.0   ,	0.0          ,	0.0           ,	1.0 );
}

void rotationMatrixH(in float sinRz, in float cosRz, out mat4 rotmat)
{
	rotmat = mat4(	cosRz,	-sinRz,	0.0,	0.0,
									sinRz,	cosRz,	0.0,	0.0,
									0.0  ,	0.0  ,	1.0,	0.0,
									0.0  ,	0.0  ,	0.0,	1.0 );
}

//prepare rotation matrix
mat4 RotMatPR;
mat4 RotMatH;
float _roll = roll;
if (_roll>90.0 || _roll < -90.0) {_roll = -_roll;}
float cosRx = cos(radians(_roll));
float sinRx = sin(radians(_roll));
float cosRy = cos(radians(-pitch));
float sinRy = sin(radians(-pitch));
float cosRz = cos(radians(hdg));
float sinRz = sin(radians(hdg));
rotationMatrixPR(sinRx, cosRx, sinRy, cosRy, RotMatPR);
rotationMatrixH(sinRz, cosRz, RotMatH);

vec3 model_x = (RotMatH * RotMatPR * vec4 (1.0, 0.0, 0.0, 0.0)).xyz;
vec3 model_y = (RotMatH * RotMatPR * vec4 (0.0, 1.0, 0.0, 0.0)).xyz;
vec3 model_z = (RotMatH * RotMatPR * vec4 (0.0, 0.0, 1.0, 0.0)).xyz;

vec3 pointingVec = normalize(pointing_x * model_x + pointing_y * model_y + pointing_z * model_z);
pointing_angle = dot (viewDir, pointingVec);*/
