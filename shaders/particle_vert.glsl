#version 440 core

layout(location = 0) in vec3 in_Position;
layout(location = 1) in vec2 in_UV_offset;
layout(location = 2) in vec2 in_UV_size;
layout(location = 3) in vec3 in_Color;
layout(location = 4) in float in_Life;
layout(location = 5) in float in_Scale;

out Vertex {
  float life;
  float scale;
  vec2 UV_offset;
  vec2 UV_size;
} vertex;

uniform mat4 viewMatrix;

void main()
{
  gl_Position = viewMatrix * vec4(in_Position.x, in_Position.y, in_Position.z, 1.0);
  vertex.life = in_Life;
  vertex.scale = in_Scale;
  vertex.UV_offset = in_UV_offset;
  vertex.UV_size = in_UV_size;
}
