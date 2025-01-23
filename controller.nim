import std/times
import std/hotcodereloading

from std/strutils import formatFloat, ffDecimal, `%`

# We use https://github.com/johnnovak/nim-glfw
import glfw

import utils/blas
import game/camera
import primitives/light
import game/player
# import physics/collision


var
  playerCamera: ThirdPersonCamera
  lastMove: float
  mainLight: Light
  mplayer: Player
  # collider: CollisionSystem

proc keyCb(w: Window, key: Key, scanCode: int32, action: KeyAction,
    mods: set[ModifierKey]) =

  var delta: Vec3
  if $action == "down" or $action == "repeat":
    case $key:
      of "up":    delta = -playerCamera.w * mplayer.speed
      of "down":  delta =  playerCamera.w * mplayer.speed
      of "left":  delta = -playerCamera.u * mplayer.speed
      of "right": delta =  playerCamera.u * mplayer.speed
    mplayer.position = mplayer.position + delta
    # mplayer.position = [mplayer.position.x, collider.getHeight(mplayer.position).y, mplayer.position.z]

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
      deltaY = -(pos.y-lastMouseY) / 20.0

    # # Move light
    # let
    #   w = -mainLight.direction
    #   #TODO: This will be nan if up == w: FIX!
    #   u = norm(cross([0'f32, 1, 0], w)) # u points right, v points up
    #   v = norm(cross(w, u)) # v points up
    #   distance = length(mainLight.position)
    # mainLight.position = mainLight.position + u * deltaX + v * deltaY
    # mainLight.direction = norm([0'f32, 0, 0].Vec3 - mainLight.position)
    # mainLight.position = -mainLight.direction * distance
    # echo mainLight.position

    # Move camera
    # playerCamera.moveDelta(deltaX, deltaY) # For vertical and horizontal movement
    playerCamera.orbit(deltaX) # For horizontal movement alone
    # echo playerCamera.origin
    # echo playerCamera.u
    # echo playerCamera.v
    # echo playerCamera.w
  lastMouseY = pos.y
  lastMouseX = pos.x

proc zoomCallback(window: Window, offset: tuple[x,y: float64]) =
  # playerCamera.zoomDelta(offset.y)
  playerCamera.zoom(offset.y)

# proc setup*(window: Window, cam: Camera, chara: Player) =
proc setup*(window: Window, cam: ThirdPersonCamera, light: Light, mmplayer: Player)=#, mcollision: CollisionSystem) =
  playerCamera = cam
  mainLight = light
  mplayer = mmplayer
  # collider = mcollision
  window.keyCb            = keyCb
  window.mouseButtonCb    = mouseClickCallback
  window.cursorPositionCb = mouseMoveCallback
  window.scrollCb         = zoomCallback
