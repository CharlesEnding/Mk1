import std/[options, paths, tables]

import opengl

import ../utils/bogls

type
  UniformKind* = enum ukSampler, ukValues
  Uniform* = object
    name*: string
    kind*: UniformKind

  ShaderId* = int

  ShaderName* = string

  Shader* = object
    id*: ShaderId
    path*: Path
    name*: ShaderName
    uniforms*: seq[Uniform]
    hasGeo*: bool = false

  ShaderOnGpu* = object
    id*: ShaderId
    name*: ShaderName
    source*: Shader
    programId*: GpuId # RESOLVE: Should this be fused with id?
    # Uniforms can come from the scene (lights, camera, render targets), the model (model transform), or materials (textures and mesh specific values)
    uniforms*:  Table[Uniform, GpuId]

proc toGpu*(shader: Shader): ShaderOnGpu =
  result.id  = shader.id
  result.name = shader.name
  var geoPath: Option[Path] = if shader.hasGeo: some(shader.path / Path(shader.name.string & "_geo.glsl")) else: none(Path)
  result.programId = compileShaders(shader.path / Path(shader.name.string & "_vert.glsl"), shader.path / Path(shader.name.string & "_frag.glsl"), geoPath)
  for uniform in shader.uniforms:
    result.uniforms[uniform] = gleGetUniformId(result.programId, uniform.name, shader.name.string)
  result.source = shader

proc use*(shader: ShaderOnGpu) = glUseProgram(shader.programId)
