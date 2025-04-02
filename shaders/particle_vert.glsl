#version 440 core

layout(location = 0) in vec3 in_Position;
layout(location = 1) in vec2 in_UV;
layout(location = 2) in vec3 in_Color;
// layout(location = 3) in vec3 in_PositionDelta;
layout(location = 3) in float in_Life;
layout(location = 4) in float in_Scale;
layout(location = 5) in vec3 in_Translation;

out float life;
out vec2 UV;

uniform mat4 projMatrix;
uniform mat4 viewMatrix;

void main()
{
  gl_Position = projMatrix * viewMatrix * vec4(in_Position+in_Translation, 1.0);
  life = in_Life;
  UV = in_UV;
}
