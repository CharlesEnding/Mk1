import std/times
import std/hotcodereloading

from std/strutils import formatFloat, ffDecimal, `%`

# We use https://github.com/johnnovak/nim-glfw
import glfw

import utils/blas
import camera
import primitives/light
import game/player
import physics/collision

# import player

var
  playerCamera: Camera
  # character: Player
  lastMove: float
  mainLight: Light
  mplayer: Player
  collider: CollisionSystem
  # import times
  # setup table of key to time started pressing
  # in keyCb define start time on kaDown and kaRepeat
  # pass delta since last time on karepeat only


# proc keyCb(w: Window, key: Key, scanCode: int32, action: KeyAction,
#     mods: set[ModifierKey]) =
#   echo "Key: $1 (scan code: $2): $3 - $4" % [$key, $scanCode, $action, $mods]

proc keyCb(w: Window, key: Key, scanCode: int32, action: KeyAction,
    mods: set[ModifierKey]) =

  var delta: Vec3
  if $action == "down" or $action == "repeat":
    case $key:
      of "up":    delta =  playerCamera.w * mplayer.speed
      of "down":  delta = -playerCamera.w * mplayer.speed
      of "left":  delta = -playerCamera.u * mplayer.speed
      of "right": delta =  playerCamera.u * mplayer.speed
    mplayer.position = mplayer.position + delta
    mplayer.position = [mplayer.position.x, collider.getHeight(mplayer.position).y, mplayer.position.z]

  echo "Delta: ", delta
  echo "Position: ", mplayer.position
  # if $key == "i" and ($action == "down" or $action == "repeat"):
  #   mainLight.position = [mainLight.position.x + 5, mainLight.position.y, mainLight.position.z]
  # if $key == "k" and ($action == "down" or $action == "repeat"):
  #   mainLight.position = [mainLight.position.x - 5, mainLight.position.y, mainLight.position.z]
  # if $key == "j" and ($action == "down" or $action == "repeat"):
  #   mainLight.position = [mainLight.position.x, mainLight.position.y, mainLight.position.z + 5]
  # if $key == "L" and ($action == "down" or $action == "repeat"):
  #   mainLight.position = [mainLight.position.x, mainLight.position.y, mainLight.position.z - 5]
  # if $key == "y" and ($action == "down" or $action == "repeat"):
  #   mainLight.position = [mainLight.position.x, mainLight.position.y + 2, mainLight.position.z]
  # if $key == "h" and ($action == "down" or $action == "repeat"):
  #   mainLight.position = [mainLight.position.x, mainLight.position.y - 2, mainLight.position.z]
  # mainLight.direction = norm([0'f32, 0, 0].Vec3 - mainLight.position)

  # if $key == "i" and $action == "down":
  #   mainLight.position = [mainLight.position.x + 5, mainLight.position.y, mainLight.position.z]
  # if $key == "k" and $action == "down":
  #   mainLight.position = [mainLight.position.x - 5, mainLight.position.y, mainLight.position.z]
  # if $key == "j" and $action == "down":
  #   mainLight.position = [mainLight.position.x, mainLight.position.y, mainLight.position.z + 5]
  # if $key == "L" and $action == "down":
  #   mainLight.position = [mainLight.position.x, mainLight.position.y, mainLight.position.z - 5]
  # if $key == "y" and $action == "down":
  #   mainLight.position = [mainLight.position.x, mainLight.position.y + 2, mainLight.position.z]
  # if $key == "h" and $action == "down":
  #   mainLight.position = [mainLight.position.x, mainLight.position.y - 2, mainLight.position.z]
  echo action
  echo key


# proc keyCb(win: Window, key: Key, scanCode: int32, action: KeyAction, modKeys: set[ModifierKey]) =
#   if key == keyEscape and action == kaDown:
#     win.shouldClose = true
#   let orientation = norm([playerCamera.w.x, 0, playerCamera.w.z])
#   if action == kaDown:
#     lastMove = epochTime()

#     if key == keyR:
#       echo "Origin: ", playerCamera.origin
#       echo "Target: ", playerCamera.center
#       echo "U: ", playerCamera.u
#       echo "V: ", playerCamera.v
#       echo ">: ", playerCamera.w

#   if action == kaRepeat:
#     let direction = case key:
#       of keyA: sdLeft
#       of keyD: sdRight
#       of keyW: sdForward
#       of keyS: sdBackward
#       of keyQ: sdUp
#       of keyE: sdDown
#       else: sdDown
#     player.move(character, orientation, direction, (epochTime()-lastMove)*0.25)
#     playerCamera.center = character.position
#     playerCamera.updateOrbitalBasis(playerCamera.center)
#     lastMove = epochTime()

  # if key == keyQ and action == kaDown:
  #   character.move(orientation, sdLeft, )
  # if key == keyE and action == kaDown:
  #   playerCamera.move("vback")
  # if key == keyW and action == kaDown:
  #   playerCamera.move("forward")
  # if key == keyS and action == kaDown:
  #   playerCamera.move("back")
  # if key == keyA and action == kaDown:
  #   playerCamera.move("left")
  # if key == keyD and action == kaDown:
  #   playerCamera.move("right")

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
    playerCamera.moveDelta(deltaX) # For horizontal movement alone
    # echo playerCamera.origin
    # echo playerCamera.u
    # echo playerCamera.v
    # echo playerCamera.w
  lastMouseY = pos.y
  lastMouseX = pos.x

proc zoomCallback(window: Window, offset: tuple[x,y: float64]) =
  playerCamera.zoomDelta(offset.y)

# proc setup*(window: Window, cam: Camera, chara: Player) =
proc setup*(window: Window, cam: Camera, light: Light, mmplayer: Player, mcollision: CollisionSystem) =
  playerCamera = cam
  mainLight = light
  mplayer = mmplayer
  collider = mcollision
  window.keyCb            = keyCb
  window.mouseButtonCb    = mouseClickCallback
  window.cursorPositionCb = mouseMoveCallback
  window.scrollCb         = zoomCallback
