import std/[math, options, paths, rationals, tables, times]
import opengl, glfw
import ../controller
import ../primitives/[scene, renderable, shader, model, animation, mesh, light, material]
import ../utils/[blas, bogls, geometry]
import ../game/camera

var
  fulcrum: Fulcrum = Fulcrum(near: 0.1, far: 10, fov: 35, aspectRatio: 1280 // 800)
  cam: ThirdPersonCamera
  mainLight: Light = light.init([60'f32, 80, -80].Vec3, [0.98'f32, 0.77, 0.51].Vec3, 700.0)
  scn: Scene
  kiteModel: RenderableBehaviourRef
  spurModel: RenderableBehaviourRef
  inputs: InputController = InputController()
  showSpurs = false
  animPaused = false
  selectedBone = 0
  selectedAnim = 0

proc initWindow(): Window =
  glfw.initialize()
  loadExtensions()
  var cfg = DefaultOpenglWindowConfig
  cfg.forwardCompat = true
  cfg.size = (w: 1280, h: 800)
  cfg.title = "Animation Viewer"
  cfg.resizable = true
  cfg.version = glv44
  cfg.profile = opCoreProfile
  var win = newWindow(cfg)
  glfw.swapInterval(1)
  glEnable(GL_DEPTH_TEST)
  glDepthFunc(GL_LESS)
  glEnable(GL_BLEND)
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
  glClearDepth(1.0f)
  glClearColor(0.2f, 0.2f, 0.2f, 1.0f)
  enableAutoGLerrorCheck(true)
  return win

proc countAllJoints(joint: Joint): int =
  result = 1
  for child in joint.children:
    result += countAllJoints(child)

proc buildSpurModel(animComp: AnimationComponent, upToId: int): ModelOnGpu =
  # Build spur geometry from skeleton hierarchy
  proc collectSpurs(joint: Joint, parent: Mat4, verts: var seq[AnimatedMeshVertex], depth: int = 0) =
    if joint.id > upToId: return
    var transform = parent * joint.transform
    var pos = transform.translationVector()
    for child in joint.children:
      if child.id > upToId: continue
      var childTransform = transform * child.transform
      var childPos = childTransform.translationVector()
      var spurVerts = spur(pos, childPos)
      for v in spurVerts:
        verts.add AnimatedMeshVertex(
          position: v.position,
          normal: v.normal,
          texCoord: v.texCoord,
          jointIds: [joint.id.float32, 0, 0, 0].Vec4,
          weights: [1.0'f32, 0, 0, 0].Vec4
        )
      collectSpurs(child, transform, verts, depth + 1)
  
  var vertices: seq[AnimatedMeshVertex] = @[]
  collectSpurs(animComp.skeletonRoot, IDENTMAT4, vertices)
  
  var cpuModel: Model[AnimatedMeshVertex]
  cpuModel.animationComponent = some(animComp)
  cpuModel.transform = IDENTMAT4
  
  var mat = material.Material(id: "spurMaterial", shaderId: 5)
  cpuModel.addMesh("spurs", vertices, mat)
  
  return cpuModel.toGpu()

proc setupScene() =
  scn = new Scene
  scn.sun = mainLight
  
  var uAlbedo = Uniform(name: "albedo", kind: ukSampler)
  var uProjection = Uniform(name:"projMatrix", kind:ukValues)
  var uView = Uniform(name:"viewMatrix", kind:ukValues)
  var uSun = Uniform(name:"lightMatrix", kind:ukValues)
  var uModel = Uniform(name:"modelMatrix", kind:ukValues)
  var uJoints = Uniform(name:"jointTransforms", kind:ukValues)
  
  scn.addShader Shader(id: 2.ShaderId, path: "shaders".Path, name: "basic", uniforms: @[uProjection, uView, uModel, uAlbedo])
  scn.addShader Shader(id: 5.ShaderId, path: "shaders".Path, name: "anim", uniforms: @[uProjection, uView, uModel, uSun, uJoints, uAlbedo])
  
  kiteModel = load("assets/kite.glb".Path, animated=true)
  scn.renderables.add kiteModel
  
  cam = newThirdPersonCamera(target=[0'f32, 2, 0].Vec3, position=[0'f32, 2, 5].Vec3, minDistance=3.0, maxDistance=20.0, fulcrum=fulcrum)
  if kiteModel.model.animationComponent.isSome():
    echo "Loaded ", kiteModel.model.animationComponent.get().animations.len, " animations"
    for i, anim in kiteModel.model.animationComponent.get().animations:
      echo i, ": ", anim.name
    var totalJoints = countAllJoints(kiteModel.model.animationComponent.get().skeletonRoot)
    selectedBone = totalJoints - 1  # Show all bones by default
    echo "Total joints: ", totalJoints
    
    # Create spur model
    spurModel = RenderableBehaviourRef()
    spurModel.animated = true
    spurModel.path = "".Path
    spurModel.model = buildSpurModel(kiteModel.model.animationComponent.get(), selectedBone)
    scn.renderables.add spurModel

proc getJointAtIndex(joint: Joint, idx: int, current: var int): Option[Joint] =
  if current == idx: return some(joint)
  current += 1
  for child in joint.children:
    var res = getJointAtIndex(child, idx, current)
    if res.isSome(): return res
  return none(Joint)

proc rebuildSpurModel() =
  if not kiteModel.model.animationComponent.isSome(): return
  var animComp = kiteModel.model.animationComponent.get()
  spurModel.model = buildSpurModel(animComp, selectedBone)

proc printSelectedBonePosition() =
  if not kiteModel.model.animationComponent.isSome(): return
  var animComp = kiteModel.model.animationComponent.get()
  var current = 0
  var maybeJoint = getJointAtIndex(animComp.skeletonRoot, selectedBone, current)
  if maybeJoint.isNone(): return
  var joint = maybeJoint.get()
  
  proc getAbsPos(j: Joint, parent: Mat4): Vec3 =
    var transform = parent * j.transform
    if j.id == joint.id: return transform.translationVector()
    for child in j.children:
      var res = getAbsPos(child, transform)
      if res != [0'f32, 0, 0].Vec3: return res
    return [0'f32, 0, 0].Vec3
  
  var pos = getAbsPos(animComp.skeletonRoot, IDENTMAT4)
  echo "Bone '", joint.name, "' (", joint.id, ") at: ", pos

proc update(win: Window, dt: float) =
  if kiteModel.model.animationComponent.isSome():
    var animComp = kiteModel.model.animationComponent.get()
    animComp.playingId = selectedAnim
    kiteModel.model.animationComponent = some(animComp)
    if spurModel != nil:
      spurModel.model.animationComponent = some(animComp)
  
  var orbitDelta = inputs.consumeCameraOrbitDelta()
  cam.orbit(orbitDelta)
  var zoomOffset = inputs.consumeCameraZoomOffset()
  cam.zoom(zoomOffset)
  
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
  if showSpurs:
    # Only draw spurs, not kite model
    var shader = scn.shaders["anim"]
    shader.use()
    scn.use(cam.Camera, shader)
    spurModel.model.draw(shader)
  else:
    # Draw kite model
    var shader = scn.shaders["anim"]
    shader.use()
    scn.use(cam.Camera, shader)
    kiteModel.model.draw(shader)

proc setupInput(win: Window) =
  proc noop() = discard
  inputs.setup(win, noop)
  
  var originalKeyCb = win.keyCb
  win.keyCb = proc(w: Window, key: Key, scanCode: int32, action: KeyAction, mods: set[ModifierKey]) =
    originalKeyCb(w, key, scanCode, action, mods)
    if action != kaDown: return
    case key
    of keyS: showSpurs = not showSpurs
    of keySpace: animPaused = not animPaused; echo "Animation ", (if animPaused: "paused" else: "playing")
    of keyRight:
      if kiteModel.model.animationComponent.isSome():
        selectedAnim = (selectedAnim + 1) mod kiteModel.model.animationComponent.get().animations.len
        var animComp = kiteModel.model.animationComponent.get()
        animComp.playingId = selectedAnim
        kiteModel.model.animationComponent = some(animComp)
        echo "Animation: ", kiteModel.model.animationComponent.get().animations[selectedAnim].name
    of keyLeft:
      if kiteModel.model.animationComponent.isSome():
        selectedAnim = (selectedAnim - 1 + kiteModel.model.animationComponent.get().animations.len) mod kiteModel.model.animationComponent.get().animations.len
        var animComp = kiteModel.model.animationComponent.get()
        animComp.playingId = selectedAnim
        kiteModel.model.animationComponent = some(animComp)
        echo "Animation: ", kiteModel.model.animationComponent.get().animations[selectedAnim].name
    of keyUp:
      if kiteModel.model.animationComponent.isSome():
        var totalJoints = countAllJoints(kiteModel.model.animationComponent.get().skeletonRoot)
        selectedBone = (selectedBone + 1) mod totalJoints
        rebuildSpurModel()
        printSelectedBonePosition()
    of keyDown:
      if kiteModel.model.animationComponent.isSome():
        var totalJoints = countAllJoints(kiteModel.model.animationComponent.get().skeletonRoot)
        selectedBone = (selectedBone - 1 + totalJoints) mod totalJoints
        rebuildSpurModel()
        printSelectedBonePosition()
    of keyP: printSelectedBonePosition()
    else: discard

proc main() =
  var win = initWindow()
  setupScene()
  setupInput(win)
  var lastTime = epochTime()
  while not win.shouldClose:
    var currentTime = epochTime()
    var dt = currentTime - lastTime
    lastTime = currentTime
    update(win, dt)
    glfw.swapBuffers(win)
    glfw.pollEvents()
  glfw.terminate()

main()
