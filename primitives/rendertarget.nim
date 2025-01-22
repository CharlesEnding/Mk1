import ../game/camera
import ../utils/bogls

import opengl

type
  RenderTarget* = ref object
    fbo*: GpuAddr
    textureAddr*: GpuAddr
  RenderTargetKind* = enum rtkColor, rtkDepth, rtkStencil

proc target*(renderTarget: RenderTarget) =
  glBindFramebuffer(GL_FRAMEBUFFER, renderTarget.fbo)

proc targetDefault*() = glBindFramebuffer(GL_FRAMEBUFFER, 0)

proc newRenderTarget*(resolution: Resolution, targetKind: RenderTargetKind): RenderTarget =
  result = new RenderTarget
  glGenFramebuffers(1, result.fbo.addr)
  target(result)
  glGenTextures(1, result.textureAddr.addr);
  glBindTexture(GL_TEXTURE_2D, result.textureAddr);
  case targetKind
  of rtkColor:
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB.int32, resolution.nx.GLint, resolution.ny.int32, 0, GL_RGB, GL_UNSIGNED_BYTE, nil);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, result.textureAddr, 0);
  of rtkDepth:
    glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT.int32, resolution.nx.int32, resolution.ny.int32, 0, GL_DEPTH_COMPONENT, cGL_FLOAT, nil);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, result.textureAddr, 0);
    glDrawBuffer(GL_NONE);
    glReadBuffer(GL_NONE);
  of rtkStencil:
    discard
  targetDefault()


