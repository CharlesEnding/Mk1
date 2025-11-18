import std/[math, options, paths, rationals, tables, times]
import opengl, glfw
import ../controller
import ../primitives/[scene, renderable, shader, model, animation, mesh, light]
import ../utils/[blas, bogls, geometry]
import ../game/camera

var
  fulcrum: Fulcrum = Fulcrum(near: 0.1, far: 10, fov: 35, aspectRatio: 1280 // 800)
  cam: ThirdPersonCamera
  mainLight: Light = light.init([60'f32, 80, -80].Vec3, [0.98'f32, 0.77, 0.51].Vec3, 700.0)
  scn: Scene
  kiteModel: RenderableBehaviourRef
  inputs: InputController = InputController()
  showSpurs = false
  animPaused = false
  animTime = 0.0
  selectedBone = 0
  selectedAnim = 0
  spurVao, spurVbo: GLuint
  spurVertCount = 0

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

proc getAbsoluteJointTransform(anim: Animation, joint: Joint, parentTransform: Mat4, time: float): Mat4 =
  var localTransform = anim.interpolate(joint.id, joint.transform, time)
  return parentTransform * localTransform

proc collectJointPositions(anim: Animation, joint: Joint, parentTransform: Mat4, time: float, upToId: int, positions: var seq[(Vec3, Vec3)]) =
  var currentTransform = getAbsoluteJointTransform(anim, joint, parentTransform, time)
  var currentPos = currentTransform.translationVector()
  if joint.id <= upToId:
    for child in joint.children:
      var childTransform = getAbsoluteJointTransform(anim, child, currentTransform, time)
      var childPos = childTransform.translationVector()
      positions.add((currentPos, childPos))
      if child.id <= upToId:
        collectJointPositions(anim, child, currentTransform, time, upToId, positions)

proc getJointAtIndex(joint: Joint, idx: int, current: var int): Option[Joint] =
  if current == idx: return some(joint)
  current += 1
  for child in joint.children:
    var res = getJointAtIndex(child, idx, current)
    if res.isSome(): return res
  return none(Joint)

proc updateSpurGeometry() =
  if not kiteModel.model.animationComponent.isSome(): return
  var animComp = kiteModel.model.animationComponent.get()
  if animComp.animations.len == 0: return
  var anim = animComp.animations[selectedAnim]
  var positions: seq[(Vec3, Vec3)] = @[]
  var totalJoints = countAllJoints(animComp.skeletonRoot)
  var upToId = min(selectedBone, totalJoints - 1)
  collectJointPositions(anim, animComp.skeletonRoot, IDENTMAT4, animTime, upToId, positions)
  var verts: seq[MeshVertex] = @[]
  for (p0, p1) in positions:
    var spurVerts = spur(p0, p1)
    verts.add spurVerts
  if verts.len == 0: return
  spurVertCount = verts.len
  if spurVao == 0:
    glGenVertexArrays(1, spurVao.addr)
    glGenBuffers(1, spurVbo.addr)
  glBindVertexArray(spurVao)
  glBindBuffer(GL_ARRAY_BUFFER, spurVbo)
  glBufferData(GL_ARRAY_BUFFER, verts.len * sizeof(MeshVertex), verts[0].addr, GL_DYNAMIC_DRAW)
  glEnableVertexAttribArray(0)
  glVertexAttribPointer(0.GLuint, 3.GLint, cGL_FLOAT, false.GLboolean, sizeof(MeshVertex).GLsizei, cast[pointer](0))
  glEnableVertexAttribArray(1)
  glVertexAttribPointer(1.GLuint, 3.GLint, cGL_FLOAT, false.GLboolean, sizeof(MeshVertex).GLsizei, cast[pointer](sizeof(Vec3)))
  glBindVertexArray(0)

proc drawSpurs(cam: Camera) =
  if spurVertCount == 0 or spurVao == 0: return
  var shader = scn.shaders["basic"]
  shader.use()
  var p = cam.projectionMatrix()
  var v = cam.viewMatrix()
  var m = IDENTMAT4
  glUniformMatrix4fv(shader.uniforms[Uniform(name:"projMatrix", kind:ukValues)].GLint, 1, true, glePointer(p.addr))
  glUniformMatrix4fv(shader.uniforms[Uniform(name:"viewMatrix", kind:ukValues)].GLint, 1, true, glePointer(v.addr))
  glUniformMatrix4fv(shader.uniforms[Uniform(name:"modelMatrix", kind:ukValues)].GLint, 1, true, glePointer(m.addr))
  glBindVertexArray(spurVao)
  glDrawArrays(GL_TRIANGLES, 0, spurVertCount.GLsizei)
  glBindVertexArray(0)

proc printSelectedBonePosition() =
  if not kiteModel.model.animationComponent.isSome(): return
  var animComp = kiteModel.model.animationComponent.get()
  var current = 0
  var maybeJoint = getJointAtIndex(animComp.skeletonRoot, selectedBone, current)
  if maybeJoint.isNone(): return
  var joint = maybeJoint.get()
  var anim = animComp.animations[selectedAnim]
  
  proc getAbsPos(j: Joint, parent: Mat4): Vec3 =
    var transform = getAbsoluteJointTransform(anim, j, parent, animTime)
    if j.id == joint.id: return transform.translationVector()
    for child in j.children:
      var res = getAbsPos(child, transform)
      if res != [0'f32, 0, 0].Vec3: return res
    return [0'f32, 0, 0].Vec3
  
  var pos = getAbsPos(animComp.skeletonRoot, IDENTMAT4)
  echo "Bone '", joint.name, "' (", joint.id, ") at: ", pos

proc update(win: Window, dt: float) =
  if not animPaused and kiteModel.model.animationComponent.isSome():
    var anim = kiteModel.model.animationComponent.get().animations[selectedAnim]
    animTime = (animTime + dt) mod anim.duration
    # Update the playingId in the model's animation component
    var animComp = kiteModel.model.animationComponent.get()
    animComp.playingId = selectedAnim
    kiteModel.model.animationComponent = some(animComp)
  
  var orbitDelta = inputs.consumeCameraOrbitDelta()
  cam.orbit(orbitDelta)
  var zoomOffset = inputs.consumeCameraZoomOffset()
  cam.zoom(zoomOffset)
  
  updateSpurGeometry()
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
  if showSpurs:
    drawSpurs(cam.Camera)
  else:
    scn.draw(cam.Camera, @["anim"])

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
        animTime = 0
        var animComp = kiteModel.model.animationComponent.get()
        animComp.playingId = selectedAnim
        kiteModel.model.animationComponent = some(animComp)
        echo "Animation: ", kiteModel.model.animationComponent.get().animations[selectedAnim].name
    of keyLeft:
      if kiteModel.model.animationComponent.isSome():
        selectedAnim = (selectedAnim - 1 + kiteModel.model.animationComponent.get().animations.len) mod kiteModel.model.animationComponent.get().animations.len
        animTime = 0
        var animComp = kiteModel.model.animationComponent.get()
        animComp.playingId = selectedAnim
        kiteModel.model.animationComponent = some(animComp)
        echo "Animation: ", kiteModel.model.animationComponent.get().animations[selectedAnim].name
    of keyUp:
      if kiteModel.model.animationComponent.isSome():
        var totalJoints = countAllJoints(kiteModel.model.animationComponent.get().skeletonRoot)
        selectedBone = (selectedBone + 1) mod totalJoints
        printSelectedBonePosition()
    of keyDown:
      if kiteModel.model.animationComponent.isSome():
        var totalJoints = countAllJoints(kiteModel.model.animationComponent.get().skeletonRoot)
        selectedBone = (selectedBone - 1 + totalJoints) mod totalJoints
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
