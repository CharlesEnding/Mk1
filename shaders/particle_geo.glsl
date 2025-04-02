#version 440 core

layout (points) in;
layout (triangle_strip)   out;
layout (max_vertices = 4) out;

in Vertex {
  float life;
  float scale;
  vec2 UV_offset;
  vec2 UV_size;
} vertex[];

out float life;
out vec2 UV;

uniform mat4 projMatrix;

void main (void)
{
  vec4 position = gl_in[0].gl_Position;

  // Bottom left
  vec2 va = position.xy + vec2(-0.5, -0.5) * vertex[0].scale;
  gl_Position = projMatrix * vec4(va, position.zw);
  life = vertex[0].life;
  UV = vec2(0.0, 1.0) * vertex[0].UV_size + vertex[0].UV_offset;
  EmitVertex();

  // Top left
  vec2 vb = position.xy + vec2(-0.5, 0.5) * vertex[0].scale;
  gl_Position = projMatrix * vec4(vb, position.zw);
  life = vertex[0].life;
  UV = vec2(0.0, 0.0) * vertex[0].UV_size + vertex[0].UV_offset;
  EmitVertex();

  // Bottom right
  vec2 vd = position.xy + vec2(0.5, -0.5) * vertex[0].scale;
  gl_Position = projMatrix * vec4(vd, position.zw);
  life = vertex[0].life;
  UV = vec2(1.0, 1.0) * vertex[0].UV_size + vertex[0].UV_offset;
  EmitVertex();

  // Top right
  vec2 vc = position.xy + vec2(0.5, 0.5) * vertex[0].scale;
  gl_Position = projMatrix * vec4(vc, position.zw);
  life = vertex[0].life;
  UV = vec2(1.0, 0.0) * vertex[0].UV_size + vertex[0].UV_offset;
  EmitVertex();

  EndPrimitive();
}
