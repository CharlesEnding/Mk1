#version 330 core

layout(location = 0) in vec3 in_Position;
layout(location = 1) in vec3 in_Normal;
layout(location = 2) in vec2 in_UV;

uniform float time;
uniform mat4 projMatrix;
uniform mat4 modelMatrix;
uniform mat4 lightMatrix;

out vec3 position;
out vec3 normal;
out vec2 UV;
out vec4 positionLightSpace;

void main()
{
  gl_Position = projMatrix * modelMatrix * vec4(in_Position, 1.0);
  UV = vec2(in_UV.x, -in_UV.y);; //vec2(in_Position.x, in_Position.y);
  position = in_Position;
  normal = in_Normal;
  positionLightSpace = lightMatrix * vec4(in_Position, 1.0);
}
