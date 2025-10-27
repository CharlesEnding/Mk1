import std/options

# We use https://github.com/johnnovak/nim-glfw
import glfw

import utils/blas
import game/camera

type InputController* = ref object
  activeKeys: set[Key] = {}
  movingCamera: bool = false
  lastMousePosition: float
  cameraOrbitDelta, cameraZoomOffset: Option[float]
  printDebug: bool = false

proc pollDirection*(input: InputController, camera: Camera): Vec3 =
  result = [0'f32, 0, 0].Vec3
  if keyUp    in input.activeKeys: result = result + -camera.w * [1'f32, 0, 1].Vec3
  if keyDown  in input.activeKeys: result = result +  camera.w * [1'f32, 0, 1].Vec3
  if keyLeft  in input.activeKeys: result = result + -camera.u * [1'f32, 0, 1].Vec3
  if keyRight in input.activeKeys: result = result +  camera.u * [1'f32, 0, 1].Vec3
  return norm(result)

proc consumeCameraOrbitDelta*(input: InputController): float =
  result = input.cameraOrbitDelta.get(0)
  input.cameraOrbitDelta = none(float)

proc consumeCameraZoomOffset*(input: InputController): float =
  result = input.cameraZoomOffset.get(0)
  input.cameraZoomOffset = none(float)

proc consumePrintDebug*(input: InputController): bool =
  if input.printDebug:
    input.printDebug = false
    return true
  return false

proc setup*(input: InputController, window: Window, reloadShaderCb: proc ()) =

  proc keyCb(w: Window, key: Key, scanCode: int32, action: KeyAction, mods: set[ModifierKey]) =
    if $action == "down": input.activeKeys.incl(key)
    elif $action == "up": input.activeKeys.excl(key)
    if key == keySpace:   input.printDebug = true
    if key == keyF5: reloadShaderCb()

  proc mouseClickCallback(w: Window, button: MouseButton, pressed: bool, modKeys: set[ModifierKey]) =
    input.movingCamera = pressed

  proc mouseMoveCallback(w: Window, pos: tuple[x,y: float64]) =
    if input.movingCamera:
      input.cameraOrbitDelta = some((pos.x.float - input.lastMousePosition) / 20.0)
    input.lastMousePosition = pos.x.float

  proc zoomCallback(w: Window, offset: tuple[x,y: float64]) =
    input.cameraZoomOffset = offset.y.float.some()

  window.keyCb            = keyCb
  window.mouseButtonCb    = mouseClickCallback
  window.cursorPositionCb = mouseMoveCallback
  window.scrollCb         = zoomCallback
