#version 330 core

layout(location = 0) out vec4 fragmentColor;

in vec2 UV;

uniform sampler2D albedo;

void main()
{
  fragmentColor = texture(albedo, UV);
}
