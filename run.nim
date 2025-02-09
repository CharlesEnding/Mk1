import std/rationals
import std/math
import std/tables
import std/options

import opengl
import glfw

import controller
import primitives/[scene, rendertarget, light, material, mesh, model]
import utils/blas
import physics/collision
import game/[player, camera, timing]
import utils/gltf

var
  fulcrum: Fulcrum = Fulcrum(near: 0.1, far: 10, fov: 35, aspectRatio: 1280 // 800)
  # playerCamera: Camera = newCamera([60'f32, 95, 50], [0'f32, 0, 0], [0'f32, 1, 0], fulcrum)
  # playerCamera: Camera = newCamera([-30'f32, 2, -20], [0'f32, 0, 0], [0'f32, 1, 0], fulcrum)
  # playerCamera: Camera = newCamera([35'f32, 2, -20], [0'f32, 0, 0], [0'f32, 1, 0], fulcrum)
  # playerCamera: Camera = newCamera([43'f32, 3, -23], [0'f32, 0, 0], [0'f32, 1, 0], fulcrum) # Test water and light
  # playerCamera: Camera = newCamera([-20'f32, 125, -6], [0'f32, 0, 0], [0'f32, 1, 0], fulcrum) # Test shadows
  # playerCamera: Camera = newThirdPersonCamera([-20'f32, 125, -6], [0'f32, 0, 0], [0'f32, 1, 0], fulcrum) # Test shadows
  # playerCamera: Camera = newCamera([-30'f32, 20, -30], [0'f32, 0, 0], [0'f32, 1, 0], fulcrum)
  # playerCamera: Camera = newCamera([-20'f32, 4, -4], [0'f32, 0, 0], [0'f32, 1, 0], fulcrum)
  playerCamera: ThirdPersonCamera
  resolution = Resolution(nx: 1280, ny: 800)
  # mainLight: Light = newLight([90'f32, 70, -110].Vec3, [0.98'f32, 0.77, 0.51].Vec3, 700.0)
  mainLight: Light = newLight([60'f32, 80, -80].Vec3, [0.98'f32, 0.77, 0.51].Vec3, 700.0)
  rootScene: Scene
  mplayer: Player
  BVH: Node
  refractionMaterial: Material = new Material
  mtiming: Timing

proc init(): Window =
  glfw.initialize()
  loadExtensions()

  var cfg = DefaultOpenglWindowConfig
  cfg.forwardCompat = true
  cfg.size      = (w: 1280, h: 800)
  cfg.title     = "Mac Anu"
  cfg.resizable = true
  cfg.version   = glv33
  cfg.profile   = opCoreProfile

  var win = newWindow(cfg)

  glfw.swapInterval(1)

  # Must be enabled after context has been created (probably newWindow)
  glEnable(GL_DEPTH_TEST);
  glDepthFunc(GL_LESS);
  glPolygonMode(GL_FRONT_AND_BACK, GL_FILL);
  glEnable(GL_BLEND);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  # glCullFace(GL_BACK)
  # glAlphaFunc(GL_GREATER, 0.5);
  # glEnable(GL_ALPHA_TEST);
  #glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);

  glClearDepth(1.0f)
  # glClearColor(0.98f, 0.77f, 0.51f, 1.0f)
  glClearColor(0f, 0f, 0f, 1.0f)

  enableAutoGLerrorCheck(true)

  mtiming = newTiming()
  mplayer = newPlayer()
  proc mplayerHook(numTicks: int) =
    for i in 0..<numTicks:
      mplayer.move()
  mtiming.register(mplayerHook)

  rootScene = newScene()

  refractionMaterial.texturePath = some("assets/MacAnu/sr1roa2.png")
  refractionMaterial.init(rootScene.shaders[4].program, "albedo")

  # rootScene.models.add  loadObj("assets/Mistral", "Mistral.obj")
  rootScene.models.add  gltf.loadObj("assets/Mistral", "Mistral.glb")
  # rootScene.models.add  gltf.loadObj("assets", "Fox.glb")
  # loadMtl("assets/Mistral", "Mistral.mtl", rootScene.models[^1])
  for materialId in rootScene.models[^1].materialIds:
    rootScene.models[^1].materials[materialId].init(rootScene.shaders[0].program, "albedo")
    rootScene.models[^1].materials[materialId].shaderIds = @[0]

  rootScene.models[^1].transform = translationMatrix([0'f32, 10, 0].Vec3)

  var collisionModel: Model = gltf.loadObj("assets/MacAnu", "MacAnu_collison.glb")
  BVH = buildTree(collisionModel, 10)
  mplayer.feet = rootScene.models[^1].meshes[0].getFeet()
  mplayer.position = BVH.getHeight(mplayer.feet)
  # mplayer.speed = [1'f32, 0, 1].Vec3
  rootScene.models[^1].transform = translationMatrix(mplayer.position-mplayer.feet)

  playerCamera = newThirdPersonCamera(
    target      = mplayer.position + [0'f32, 1.6, 0].Vec3,
    position    = [0'f32, 5.15, -4].Vec3,
    minDistance = 3.0,
    maxDistance = 20.0,
    fulcrum     = fulcrum
  )

  controller.setup(win, playerCamera, mainLight, mplayer)#, collisionSystem)

  return win

proc update(win: Window, depthTarget, refractionTarget: RenderTarget) =


  mplayer.position = BVH.getHeight(mplayer.position)
  rootScene.models[^1].transform = translationMatrix(mplayer.position-mplayer.feet)
  # playerCamera.updateOrbitalBasis(playerCamera.origin, mplayer.position + [0'f32, 1.6, 0].Vec3)
  # playerCamera.origin = [0'f32, 5, -4].Vec3
  # playerCamera.updateOrbitalBasis(playerCamera.origin, mplayer.position + [0'f32, 1.6, 0].Vec3)

  # echo mplayer.position
  playerCamera.followPlayer(mplayer.position + [0'f32, 1.6, 0].Vec3)

  # TODO: Only do this on player or camera movement
  var savedCameraDistance = playerCamera.distance
  var ray: Ray = Ray(origin: mplayer.position + [0'f32, 1.6, 0].Vec3, direction: playerCamera.w)
  var closest = none(Intersection)
  closest = ray.findIntersection(BVH, closest)
  if closest.isSome():
    if closest.get().distance < playerCamera.distance:
      playerCamera.distance = closest.get().distance
      playerCamera.updatePosition()
  ##################################################

  # Render depth for shadow map
  glViewport(0, 0, GLsizei(2560), GLsizei(1600))
  target(depthTarget)
  glClear(GL_DEPTH_BUFFER_BIT)
  glEnable(GL_CULL_FACE)
  glCullFace(GL_FRONT)
  rootScene.drawDepth(playerCamera.Camera, mainLight)
  glCullFace(GL_BACK)
  glDisable(GL_CULL_FACE)

  # Render riverbed for water refraction
  # https://cgvr.cs.uni-bremen.de/teaching/cg_literatur/frame_buffer_objects.html
  glViewport(0, 0, GLsizei(1280), GLsizei(800))
  target(refractionTarget)
  glClear(GL_DEPTH_BUFFER_BIT)
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
  rootScene.drawRefraction(playerCamera.Camera, mainLight, refractionMaterial)

  # Render full scene
  glViewport(0, 0, GLsizei(1280), GLsizei(800))
  targetDefault()
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
  rootScene.draw(playerCamera.Camera, mainLight, depthTarget, refractionTarget)

  playerCamera.distance = savedCameraDistance
  playerCamera.updatePosition()

  mtiming.frameTick()

  glfw.swapBuffers(win)
  glfw.pollEvents()

proc destroy() =
  glfw.terminate()

proc main() =
  var window: Window = init()
  var depthTarget: RenderTarget = newRenderTarget(Resolution(nx: 2560, ny:1600), rtkDepth)
  var refractionTarget: RenderTarget = newRenderTarget(Resolution(nx: 1280, ny:800), rtkColor)
  while not window.shouldClose:
    update(window, depthTarget, refractionTarget)
  destroy()

main()
