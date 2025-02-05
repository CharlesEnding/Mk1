import std/[options]

import opengl

import ../utils/blas
import ../utils/bogls
import shader

type
  TexturePath* = string
  TextureAddr* = GpuAddr
  SamplerAddr* = GLint
  MaterialId* = string
  Material* = ref object
    shaderIds*: seq[ShaderId]
    materialId*: MaterialId
    ns*, ni*, d*, illum*: float32
    ka*, kd*, ks*, ke*: Vec3
    texturePath*: Option[TexturePath]
    textureBuffer*: Option[seq[byte]]
    textureAddr*: TextureAddr
    samplerAddr*: SamplerAddr

proc init*(material: Material, programAddr: GpuAddr, samplerName: string) =
  material.samplerAddr = cast[GLint](glGetUniformLocation(programAddr, samplerName))
  # TODO: catch error, for all opens
  if material.texturePath.isSome():
    loadTexture(material.texturePath.get(), material.textureAddr)
  elif material.textureBuffer.isSome():
    loadTextureFromBuffer(material.textureBuffer.get(), material.textureAddr)


proc toGpu*(material: Material) =
  glActiveTexture(GL_TEXTURE0)
  glBindTexture(GL_TEXTURE_2D, material.textureAddr)
  glUniform1i(material.samplerAddr, 0.GLint)
