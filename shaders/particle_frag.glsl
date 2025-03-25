#version 440 core

layout(location = 0) out vec4 fragmentColor;

in float life;

void main()
{
  fragmentColor = vec4(1.0, 0, 0, life / 10.0);
}
