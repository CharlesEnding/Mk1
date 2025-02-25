# We use https://github.com/johnnovak/nim-glfw
import glfw

import utils/blas
import game/camera
import primitives/light
import game/player

var
  playerCamera: ThirdPersonCamera
  mainLight: Light
  mplayer: Player
  activeKeys: set[Key] = {}

proc updatePlayerSpeed() =
  var speed = [0'f32, 0, 0].Vec3
  if keyUp    in activeKeys: speed = speed + -playerCamera.w * [1'f32, 0, 1].Vec3
  if keyDown  in activeKeys: speed = speed +  playerCamera.w * [1'f32, 0, 1].Vec3
  if keyLeft  in activeKeys: speed = speed + -playerCamera.u * [1'f32, 0, 1].Vec3
  if keyRight in activeKeys: speed = speed +  playerCamera.u * [1'f32, 0, 1].Vec3
  speed = norm(speed) * mplayer.maxSpeed
  mplayer.speed = speed

proc keyCb(w: Window, key: Key, scanCode: int32, action: KeyAction,
    mods: set[ModifierKey]) =
  if $action == "down": activeKeys.incl(key)
  elif $action == "up": activeKeys.excl(key)
  updatePlayerSpeed()

var
  lastMouseX: float64 = 0
  lastMouseY: float64 = 0
  buttonDown: bool = false

proc mouseClickCallback(window: Window, button: MouseButton, pressed: bool, modKeys: set[ModifierKey]) =
  buttonDown = pressed

proc mouseMoveCallback(window: Window, pos: tuple[x,y: float64]) =
  if buttonDown:
    var
      deltaX =  (pos.x-lastMouseX) / 20.0
    playerCamera.orbit(deltaX) # For horizontal movement alone
  lastMouseY = pos.y
  lastMouseX = pos.x

proc zoomCallback(window: Window, offset: tuple[x,y: float64]) =
  playerCamera.zoom(offset.y)

proc setup*(window: Window, cam: ThirdPersonCamera, light: Light, mmplayer: Player)=#, mcollision: CollisionSystem) =
  playerCamera = cam
  mainLight = light
  mplayer = mmplayer
  window.keyCb            = keyCb
  window.mouseButtonCb    = mouseClickCallback
  window.cursorPositionCb = mouseMoveCallback
  window.scrollCb         = zoomCallback
