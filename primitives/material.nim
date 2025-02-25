import std/[strformat, tables]

import ../utils/bogls
import shader
import texture

type
  MaterialId* = string

  Material* = object
    id*: MaterialId
    shaderId*: ShaderId
    textures*: Table[Uniform, Texture]

  MaterialOnGpu* = object
    id*: MaterialId
    shaderId*: ShaderId
    textures*: Table[Uniform, TextureOnGpu]

proc toGpu*(material: Material): MaterialOnGpu =
  result = MaterialOnGpu(id: material.id, shaderId: material.shaderId)
  for uniform, texture in material.textures.pairs():
    result.textures[uniform] = texture.toGpuCached()

proc use*(material: MaterialOnGpu, samplerIds: Table[Uniform, GpuId]) =
  for uniform in material.textures.keys():
    if not samplerIds.hasKey(uniform): raise newException(KeyError, &"Shader doesn't have required uniform for texture: {uniform.name}.")
    material.textures[uniform].use(samplerIds[uniform])
