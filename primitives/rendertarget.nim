import std/[strformat, tables]

import opengl

import ../game/camera
import ../utils/bogls
import shader
import texture

type
  RenderTarget* = object
    name*: string
    frameBuffer*, renderBuffer*: GpuId
    texture*:  TextureOnGpu
    sampler*:  Uniform
  RenderTargetKind* = enum rtkColor, rtkDepth, rtkStencil

proc target*(renderTarget: RenderTarget) = glBindFramebuffer(GL_FRAMEBUFFER, renderTarget.frameBuffer)

proc targetDefault*() = glBindFramebuffer(GL_FRAMEBUFFER, 0)

proc useTexture*(target: RenderTarget, samplerIds: Table[Uniform, GpuId]) = # Named "useResult" because calling it "use" would lead to confusion with "target"
  if not samplerIds.hasKey(target.sampler): raise newException(KeyError, &"Shader doesn't have required uniform for {target.name} render target: {target.sampler.name}.")
  target.texture.use(samplerIds[target.sampler])

proc init*(name: string, sampler: Uniform, resolution: Resolution, targetKind: RenderTargetKind): RenderTarget =
  result.name = name
  result.sampler  = sampler
  result.texture  = TextureOnGpu(name: "rt" & name)

  glGenFramebuffers(1, result.frameBuffer.addr)
  target(result)
  glGenTextures(1, result.texture.id.addr)
  glBindTexture(GL_TEXTURE_2D, result.texture.id)
  case targetKind
  of rtkColor:
    # Add a render buffer for depth
    glGenRenderbuffersEXT(1, result.renderBuffer.addr)
    glBindRenderbufferEXT(GL_RENDERBUFFER_EXT, result.renderBuffer)
    glRenderbufferStorageEXT(GL_RENDERBUFFER_EXT, GL_DEPTH_COMPONENT, resolution.nx.GLint, resolution.ny.int32)
    glFramebufferRenderbufferEXT(GL_FRAMEBUFFER_EXT, GL_DEPTH_ATTACHMENT_EXT, GL_RENDERBUFFER_EXT, result.renderBuffer)
    # Add a texture
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB.int32, resolution.nx.GLint, resolution.ny.int32, 0, GL_RGB, GL_UNSIGNED_BYTE, nil)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
    glFramebufferTexture2DEXT(GL_FRAMEBUFFER_EXT, GL_COLOR_ATTACHMENT0_EXT, GL_TEXTURE_2D, result.texture.id, 0)
    # glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, result.texture.id, 0)
  of rtkDepth:
    glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT.int32, resolution.nx.int32, resolution.ny.int32, 0, GL_DEPTH_COMPONENT, cGL_FLOAT, nil)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT)
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, result.texture.id, 0)
    glDrawBuffer(GL_NONE)
    glReadBuffer(GL_NONE)
  of rtkStencil:
    discard
  targetDefault()




