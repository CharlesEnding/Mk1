import std/[paths, tables]

import opengl

import ../utils/bogls

type
  UniformKind* = enum ukSampler, ukValues
  Uniform* = object
    name*: string
    kind*: UniformKind

  ShaderId* = int

  Shader* = object
    id*: ShaderId
    path*: Path
    name*: string
    uniforms*: seq[Uniform]

  ShaderOnGpu* = object
    id*: ShaderId
    name*: string
    programId*: GpuId # RESOLVE: Should this be fused with id?
    # Uniforms can come from the scene (lights, camera, render targets), the model (model transform), or materials (textures and mesh specific values)
    uniforms*:  Table[Uniform, GpuId]

proc toGpu*(shader: Shader): ShaderOnGpu =
  result.id  = shader.id
  result.name = shader.name
  result.programId = compileShaders(shader.path / Path(shader.name & "_vert.glsl"), shader.path / Path(shader.name & "_frag.glsl"))
  for uniform in shader.uniforms:
    result.uniforms[uniform] = gleGetUniformId(result.programId, uniform.name, shader.name)

proc use*(shader: ShaderOnGpu) = glUseProgram(shader.programId)
