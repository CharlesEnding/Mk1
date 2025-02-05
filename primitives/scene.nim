import std/[tables, strutils, sequtils]

import ../game/camera
import ../utils/gltf
import material
import mesh
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
  result.models.add  loadObj("assets/MacAnu", "MacAnu.glb")
  # result.models.add  loadObj("assets/MacAnu", "MacAnu.obj")
  # loadMtl("assets/MacAnu", "MacAnu.mtl", result.models[^1])
  result.shaders.add loadShader("shaders/lit", 0.ShaderId)
  result.shaders.add loadShader("shaders/water", 1.ShaderId)
  result.shaders.add loadShader("shaders/basic", 2.ShaderId)
  result.shaders.add loadShader("shaders/shadow", 3.ShaderId)
  result.shaders.add loadShader("shaders/refraction", 4.ShaderId)
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
    # elif "TEX_sr1roa2" in materialId:
    #   result.models[^1].materials[materialId].init(result.shaders[2].program, "albedo")
    #   result.models[^1].materials[materialId].shaderIds = @[2]
    else:
      result.models[^1].materials[materialId].init(result.shaders[0].program, "albedo")
      result.models[^1].materials[materialId].shaderIds = @[0]

proc draw*(scene: Scene, playerCamera: Camera, light: Light, depthTarget, refractionTarget: RenderTarget) =
  for shader in scene.shaders[0..<3]:
    shader.toGpu(playerCamera, light)
    if shader.shaderId == 0:
      var samplerAddr = cast[GLint](glGetUniformLocation(shader.program, "shadowMap"))
      glActiveTexture(GL_TEXTURE1)
      glBindTexture(GL_TEXTURE_2D, depthTarget.textureAddr)
      glUniform1i(samplerAddr, 1.GLint)
    if shader.shaderId == 1:
      var samplerAddr = cast[GLint](glGetUniformLocation(shader.program, "refraction"))
      glActiveTexture(GL_TEXTURE1)
      glBindTexture(GL_TEXTURE_2D, refractionTarget.textureAddr)
      glUniform1i(samplerAddr, 1.GLint)
    for model in scene.models:
      model.toGpu(shader.modelMatrixLocation)
      model.draw(shader.shaderId)
  glUseProgram(0)

proc drawRefraction*(scene: Scene, playerCamera: Camera, light: Light, refractionMaterial: Material) =
  scene.shaders[4].toGpu(playerCamera, light)
  scene.models[0].toGpu(scene.shaders[4].modelMatrixLocation)

  for i, (mesh, materialId) in zip(scene.models[0].meshes, scene.models[0].materialIds):
    if "TEX_sr1roa2" in materialId:
      refractionMaterial.toGpu()
      mesh.draw()
  glUseProgram(0)

proc drawDepth*(scene: Scene, playerCamera: Camera, light: Light) =
  scene.shaders[3].toGpu(playerCamera, light)
  for model in scene.models:
    model.draw(scene.shaders[3].shaderId, drawWithMaterial=false)
  glUseProgram(0)

