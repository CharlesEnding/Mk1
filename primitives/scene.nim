import std/[tables, strutils]

import ../camera
import ../utils/obj
import material
import model
import shader
import light
import rendertarget

import opengl

type
  Scene* = ref object
    models*:  seq[Model]
    shaders*: seq[Shader]

proc newScene*(): Scene =
  # TODO: scene description DSL? Resource manager to segregate I/O?
  result = new Scene
  result.models.add  loadObj("assets/MacAnu", "MacAnu.obj")
  loadMtl("assets/MacAnu", "MacAnu.mtl", result.models[^1])
  result.shaders.add loadShader("shaders/lit", 0.ShaderId)
  result.shaders.add loadShader("shaders/water", 1.ShaderId)
  result.shaders.add loadShader("shaders/basic", 2.ShaderId)
  result.shaders.add loadShader("shaders/shadow", 3.ShaderId)
  for materialId in result.models[^1].materialIds:
    if materialId == "TEX_sr1wat1":
      result.models[^1].materials[materialId].init(result.shaders[1].program, "albedo")
      result.models[^1].materials[materialId].shaderIds = @[1]
    elif materialId == "TEX_sr1sky1":
      result.models[^1].materials[materialId].init(result.shaders[2].program, "albedo")
      result.models[^1].materials[materialId].shaderIds = @[2]
    elif "TEX_sr1fen1" in materialId:
      result.models[^1].materials[materialId].init(result.shaders[0].program, "albedo")
      result.models[^1].materials[materialId].shaderIds = @[0]
    elif "TEX_sr1etc1" in materialId or "TEX_sr1etc2" in materialId or "TEX_sr1roo1" in materialId:
      result.models[^1].materials[materialId].init(result.shaders[0].program, "albedo")
      result.models[^1].materials[materialId].shaderIds = @[0, 3]
    else:
      result.models[^1].materials[materialId].init(result.shaders[0].program, "albedo")
      result.models[^1].materials[materialId].shaderIds = @[0]

proc draw*(scene: Scene, playerCamera: Camera, light: Light, resolution: Resolution, depthTarget: RenderTarget) =
  for shader in scene.shaders[0..<3]:
    shader.toGpu(playerCamera, light, resolution)
    if shader.shaderId == 0:
      var samplerAddr = cast[GLint](glGetUniformLocation(shader.program, "shadowMap"))
      glActiveTexture(GL_TEXTURE1)
      glBindTexture(GL_TEXTURE_2D, depthTarget.textureAddr)
      glUniform1i(samplerAddr, 1.GLint)
    for model in scene.models:
      model.toGpu(shader.modelMatrixLocation)
      model.draw(shader.shaderId)
  glUseProgram(0)


proc drawDepth*(scene: Scene, playerCamera: Camera, light: Light, resolution: Resolution) =
  scene.shaders[3].toGpu(playerCamera, light, resolution)
  for model in scene.models:
    model.draw(scene.shaders[3].shaderId, drawWithMaterial=false)
  glUseProgram(0)

