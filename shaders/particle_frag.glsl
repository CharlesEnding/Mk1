#version 440 core

layout(location = 0) out vec4 fragmentColor;

uniform sampler2D albedo;

in float life;
in vec2 UV;

void main()
{
  vec4 albSample = texture(albedo, UV);
  fragmentColor = vec4(albSample.xyz, albSample.w*life/10.0*2);
}
