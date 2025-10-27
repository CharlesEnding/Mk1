import std/[math, tables, times]

import ../game/camera
import ../utils/bogls
import model
import shader
import light
import rendertarget
import renderable

import opengl

type
  Scene* {.requiresInit.} = ref object
    # models*:  seq[ModelOnGpu]
    renderables*: seq[RenderableBehaviourRef]
    shaders*: Table[ShaderName, ShaderOnGpu]
    previousPasses*: seq[RenderTarget]
    sun*: Light

proc addShader*(scene: Scene, shader: Shader) =
  scene.shaders[shader.name] = shader.toGpu()

proc reloadShader*(scene: Scene, name: ShaderName) =
  scene.shaders[name] = scene.shaders[name].source.toGpu()

const PROJECTION_MATRIX_UNIFORM = Uniform(name:"projMatrix", kind:ukValues)
const VIEW_MATRIX_UNIFORM = Uniform(name:"viewMatrix",  kind:ukValues)
const SUN_MATRIX_UNIFORM  = Uniform(name:"lightMatrix", kind:ukValues)
const TIME_UNIFORM  = Uniform(name:"time", kind:ukValues)

proc use*(scene: Scene, playerCamera: Camera, shader: ShaderOnGpu) =
  assert gleGetActiveProgram() != 0, "Program needs to be bound before scene is used."
  var p = playerCamera.projectionMatrix()
  var v = playerCamera.viewMatrix()
  var l = scene.sun.lightMatrix()
  var epoch = epochTime() / 100
  var time: GLfloat = (epoch - floor(epoch)) * 100
  if shader.uniforms.hasKey(PROJECTION_MATRIX_UNIFORM): glUniformMatrix4fv(shader.uniforms[PROJECTION_MATRIX_UNIFORM].GLint, 1, true, glePointer(p.addr))
  if shader.uniforms.hasKey(VIEW_MATRIX_UNIFORM):       glUniformMatrix4fv(shader.uniforms[VIEW_MATRIX_UNIFORM].GLint,       1, true, glePointer(v.addr))
  if shader.uniforms.hasKey(SUN_MATRIX_UNIFORM):        glUniformMatrix4fv(shader.uniforms[SUN_MATRIX_UNIFORM].GLint,        1, true, glePointer(l.addr))
  if shader.uniforms.hasKey(TIME_UNIFORM): glUniform1f(shader.uniforms[TIME_UNIFORM].GLint, time)

proc draw*(scene: Scene, playerCamera: Camera, shadersToDraw: seq[ShaderName] = @[]) =
  for name, shader in scene.shaders.pairs():
    if shadersToDraw.len > 0 and name notin shadersToDraw: continue
    shader.use()
    scene.use(playerCamera, shader)

    for pass in scene.previousPasses: # TODO: Find a more elegant way to manage render targets
      if shader.uniforms.hasKey(pass.sampler):
        pass.useTexture(shader.uniforms)

    for renderable in scene.renderables:
      renderable.model.draw(shader)

    gleResetActiveTextureCount()
  glUseProgram(0)
