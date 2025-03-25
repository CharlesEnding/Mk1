import std/[math, options, os, paths, rationals, tables]

import opengl
import glfw

import controller
import game/[camera, movement, timing, character]
import physics/collision
import primitives/[scene, renderable, rendertarget, light, material, mesh, model, shader, texture, animation, particles]
import utils/[blas, gltf, bogls]

var
  fulcrum: Fulcrum = Fulcrum(near: 0.1, far: 10, fov: 35, aspectRatio: 1280 // 800)
  playerCamera: ThirdPersonCamera
  mainLight: Light = light.init([60'f32, 80, -80].Vec3, [0.98'f32, 0.77, 0.51].Vec3, 700.0)
  rootScene: Scene
  BVH: Node
  mtiming: Timing
  inputs: InputController = InputController()
  playerChar, npc1: Character
  dirtContainer: ParticleContainerRef
  dirtEmitter: ParticleEmitter

const PROJECTION_MATRIX_UNIFORM = Uniform(name:"projMatrix", kind:ukValues)
const VIEW_MATRIX_UNIFORM = Uniform(name:"viewMatrix",  kind:ukValues)

proc init(): Window =
  glfw.initialize()
  loadExtensions()

  var cfg = DefaultOpenglWindowConfig
  cfg.forwardCompat = true
  cfg.size      = (w: 1280, h: 800)
  cfg.title     = "Mac Anu"
  cfg.resizable = true
  cfg.version   = glv44
  cfg.profile   = opCoreProfile

  var win = newWindow(cfg)

  glfw.swapInterval(1)

  # Must be enabled after context has been created (probably newWindow)
  glEnable(GL_DEPTH_TEST)
  glDepthFunc(GL_LESS)
  glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

  glClearDepth(1.0f)
  glClearColor(0f, 0f, 0f, 1.0f)

  enableAutoGLerrorCheck(true)

  mtiming = newTiming()
  # proc mplayerHook(numTicks: int) =
  #   for i in 0..<numTicks:
  #     mplayer.move()
  # mtiming.register(mplayerHook)

  rootScene = new Scene
  rootScene.sun = mainLight

  # Uniforms
  var uAlbedo     = Uniform(name: "albedo",     kind: ukSampler)
  var uRefraction = Uniform(name: "refraction", kind: ukSampler)
  var uShadowMap  = Uniform(name: "shadowMap",  kind: ukSampler)
  var uProjection = Uniform(name:"projMatrix",  kind: ukValues)
  var uTime   = Uniform(name:"time",        kind: ukValues)
  var uView   = Uniform(name:"viewMatrix",  kind: ukValues)
  var uSun    = Uniform(name:"lightMatrix", kind: ukValues)
  var uModel  = Uniform(name:"modelMatrix", kind: ukValues)
  var uJoints = Uniform(name:"jointTransforms", kind: ukValues)

  rootScene.shaders.add Shader(id: 0.ShaderId, path: "shaders".Path, name: "lit",        uniforms: @[uProjection, uView, uModel, uSun, uAlbedo, uShadowMap]).toGpu()
  rootScene.shaders.add Shader(id: 1.ShaderId, path: "shaders".Path, name: "water",      uniforms: @[uTime, uProjection, uView, uModel, uAlbedo, uRefraction]).toGpu()
  rootScene.shaders.add Shader(id: 2.ShaderId, path: "shaders".Path, name: "basic",      uniforms: @[uProjection, uView, uModel, uAlbedo]).toGpu()
  rootScene.shaders.add Shader(id: 3.ShaderId, path: "shaders".Path, name: "shadow",     uniforms: @[uSun]).toGpu()
  rootScene.shaders.add Shader(id: 4.ShaderId, path: "shaders".Path, name: "refraction", uniforms: @[uTime, uProjection, uView, uModel, uAlbedo]).toGpu()
  rootScene.shaders.add Shader(id: 5.ShaderId, path: "shaders".Path, name: "anim",       uniforms: @[uProjection, uView, uModel, uSun, uJoints, uAlbedo, uShadowMap]).toGpu()
  rootScene.shaders.add Shader(id: 6.ShaderId, path: "shaders".Path, name: "particle",   uniforms: @[uProjection, uView]).toGpu()

  # var map: Model[MeshVertex] = gltf.loadObj[MeshVertex]("assets/MacAnu", "MacAnu.glb", MeshVertex())

  var map: RenderableBehaviourRef = load("assets/MacAnu/MacAnu.glb".Path, animated=false)
  rootScene.renderables.add map

  playerChar = createPlayer()
  rootScene.renderables.add playerChar.renderable.get()

  # var dirtMesh: VertexBuffer[ParticleVertex] = @[
  #   ParticleVertex(position: [-0.5f32, 0.0, -0.5]),
  #   ParticleVertex(position: [ 0.5f32, 0.0, -0.5]),
  #   ParticleVertex(position: [-0.5f32, 0.0,  0.5]),
  #   ParticleVertex(position: [ 0.5f32, 0.0,  0.5]),
  # ]
  # dirtContainer = initParticleContainer(dirtMesh)
  dirtContainer = initParticleContainer()
  dirtEmitter = ParticleEmitter(translation: [0.0'f32, 5, 0], life: 10.0'f32, scale: 1.0'f32, isEnabled: true, container: dirtContainer)

  npc1 = createNpc()
  rootScene.renderables.add npc1.renderable.get()
  # var characterModel: Model[MeshVertex] = gltf.loadObj[MeshVertex]("assets/Mistral", "Mistral.glb", MeshVertex())
  # var characterModel: Model[AnimatedMeshVertex] = gltf.loadObj[AnimatedMeshVertex]("assets", "Fox.glb", AnimatedMeshVertex())
  # rootScene.models.add characterModel.toGpu()

  var collisionModel: Model[MeshVertex] = gltf.loadObj[MeshVertex]("assets/MacAnu/MacAnu_collison.glb", MeshVertex())
  BVH = buildTree(collisionModel, 10)
  # mplayer.feet = [0'f32, 0, 0].Vec3
  # mplayer.position = BVH.getHeight(mplayer.feet)
  # rootScene.models[^1].transform = translationMatrix(mplayer.position-mplayer.feet)

  playerCamera = newThirdPersonCamera(
    # target      = mplayer.position + [0'f32, 1.6, 0].Vec3,
    target      = BVH.getHeight([0'f32, 0, 0]) + [0'f32, 1.6, 0].Vec3,
    position    = [0'f32, 5.15, -4].Vec3,
    minDistance = 3.0,
    maxDistance = 20.0,
    fulcrum     = fulcrum
  )

  inputs.setup(win)#, collisionSystem)

  return win

proc update(win: Window, depthTarget, refractionTarget: RenderTarget) =

  dirtEmitter = dirtEmitter.update()
  dirtContainer.update()

  var dir: Vec3 = inputs.pollDirection(playerCamera)
  playerChar.movement = playerChar.movement.get().updateSpeed(dir).some()
  playerChar = playerChar.update()
  playerChar.spatial = playerChar.spatial.get().updateHeight(playerChar.grounded.get(), BVH).some()

  npc1 = npc1.update()
  npc1.spatial = npc1.spatial.get().updateHeight(npc1.grounded.get(), BVH).some()

  if inputs.consumePrintDebug():
    echo playerChar.spatial.get().position
  # mplayer.position = BVH.getHeight(mplayer.position)
  # rootScene.models[^1].transform = translationMatrix(mplayer.position-mplayer.feet) * scaleMatrix([0.01'f32, 0.01, 0.01])

  var orbitDelta: float = inputs.consumeCameraOrbitDelta()
  playerCamera.orbit(orbitDelta)
  var zoomOffset: float = inputs.consumeCameraZoomOffset()
  playerCamera.zoom(zoomOffset)

  playerCamera.followPlayer(playerChar.spatial.get().position + [0'f32, 1.6, 0].Vec3)

  var savedCameraDistance = playerCamera.distance
  var ray: Ray = Ray(origin: playerChar.spatial.get().position + [0'f32, 1.6, 0].Vec3, direction: playerCamera.w)
  var closest = none(Intersection)
  closest = ray.findIntersection(BVH, closest)
  if closest.isSome():
    if closest.get().distance < playerCamera.distance:
      playerCamera.distance = closest.get().distance
      playerCamera.updatePosition()

  rootScene.previousPasses = @[]
  # Render depth for shadow map
  glViewport(0, 0, GLsizei(2560), GLsizei(1600))
  target(depthTarget)
  glClear(GL_DEPTH_BUFFER_BIT)
  glEnable(GL_CULL_FACE)
  glCullFace(GL_FRONT)
  rootScene.draw(playerCamera.Camera, @[3])
  glCullFace(GL_BACK)
  glDisable(GL_CULL_FACE)

  # Render riverbed for water refraction
  # https://cgvr.cs.uni-bremen.de/teaching/cg_literatur/frame_buffer_objects.html
  glViewport(0, 0, GLsizei(1280), GLsizei(800))
  target(refractionTarget)
  glClear(GL_DEPTH_BUFFER_BIT)
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
  rootScene.draw(playerCamera.Camera, @[4])

  rootScene.previousPasses.add(depthTarget)
  rootScene.previousPasses.add(refractionTarget)
  # Render full scene
  glViewport(0, 0, GLsizei(1280), GLsizei(800))
  targetDefault()
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
  rootScene.draw(playerCamera.Camera, @[0, 1, 2, 5]) #, mainLight, depthTarget, refractionTarget)

  var shader6 = rootScene.shaders[^1]
  shader6.use()
  var p = playerCamera.projectionMatrix()
  var v = playerCamera.viewMatrix()
  glUniformMatrix4fv(shader6.uniforms[PROJECTION_MATRIX_UNIFORM].GLint, 1, true, glePointer(p.addr))
  glUniformMatrix4fv(shader6.uniforms[VIEW_MATRIX_UNIFORM].GLint,       1, true, glePointer(v.addr))
  dirtContainer.draw()


  playerCamera.distance = savedCameraDistance
  playerCamera.updatePosition()

  mtiming.frameTick()

  glfw.swapBuffers(win)
  glfw.pollEvents()
  sleep(int(1000 / 120))

proc destroy() =
  glfw.terminate()

proc main() =
  var window: Window = init()
  var uDepth: Uniform = Uniform(name: "shadowMap", kind: ukSampler)
  var depthTarget: RenderTarget = init("shadows", uDepth, Resolution(nx: 2560, ny:1600), rtkDepth)
  var uRefraction = Uniform(name: "refraction", kind: ukSampler)
  var refractionTarget: RenderTarget = init("refraction", uRefraction, Resolution(nx: 1280, ny:800), rtkColor)
  while not window.shouldClose:
    update(window, depthTarget, refractionTarget)
  destroy()

main()
