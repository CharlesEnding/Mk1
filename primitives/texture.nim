import std/[paths, tables]

import opengl

import ../utils/bogls

type
  TextureKind* = enum tkPath, tkBuffer

  TextureName* = string

  Texture* = object
    name*: TextureName
    case kind*: TextureKind
    of tkPath:   path*: Path
    of tkBuffer: buffer*: seq[byte]

  TextureOnGpu* = object
    name*: string
    id*: GpuId

var gpuCache: Table[TextureName, TextureOnGpu]

proc toGpu*(texture: Texture): TextureOnGpu =
  var id: GpuId = case texture.kind:
  of tkPath:   loadTexture(texture.path.string)
  of tkBuffer: loadTextureFromBuffer(texture.buffer)
  return TextureOnGpu(name: texture.name, id: id)

proc toGpuCached*(texture: Texture): TextureOnGpu =
  assert texture.name != "", "Found texture with empty name. Cache will break."
  if gpuCache.hasKey(texture.name): return gpuCache[texture.name]
  result = texture.toGpu()
  gpuCache[texture.name] = result

proc clearCache*() = discard # Destroy all textures in cache then overwrite table

proc use*(texture: TextureOnGpu, samplerId: GpuId) =
  let i: GLint = gleNextActiveTexture()
  glActiveTexture((GL_TEXTURE0.GLint + i).GLenum)
  glBindTexture(GL_TEXTURE_2D, texture.id)
  glUniform1i(samplerId.GLint, i)
