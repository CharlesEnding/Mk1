#version 330 core

layout(location = 0) in vec3 in_Position;
layout(location = 1) in vec3 in_Normal;
layout(location = 2) in vec2 in_UV;

uniform float time;
uniform mat4 projMatrix;
uniform mat4 modelMatrix;
uniform mat4 lightMatrix;

out vec2 UV;
out float out_time;

void main()
{
  float speed = 5.0;
  float displacement = in_Position.y + (sin(in_Position.x*0.4 + time*speed) - sin(in_Position.z*0.4 + time*speed)) * 0.1 - 0.1;
  gl_Position = projMatrix * modelMatrix * vec4(in_Position.x, displacement, in_Position.z, 1.0);
  UV = in_Position.xz * 0.3;
  out_time = time;
}
