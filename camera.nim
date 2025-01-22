import std/rationals
import std/math

import utils/blas

type
  FieldOfView* = range[1..180]

  AspectRatio* = Rational[int]

  Resolution* = object
    nx*, ny*: range[1..high(int)]

  Fulcrum* = ref object
    near*, far*: float32
    fov*: FieldOfView
    aspectRatio*: AspectRatio # Replace resolution with this

  Camera* = ref object
    origin*, center*, u*, v*, w*: Vec3
    fulcrum*: Fulcrum
    minDistance*, maxDistance*: float


proc viewportMatrix*(res: Resolution): Mat4 =
  result = [
    [(res.nx / 2).float32, 0, 0, ((res.nx - 1) / 2)],
    [0, (res.ny / 2), 0, ((res.ny - 1) / 2)],
    [0, 0, 1, 0],
    [0, 0, 0, 1]
  ]

proc projectionMatrix*(camera: Camera): Mat4 =
  let
    radians: float32 = arccos(-1.0'f32) / 180
    top   = camera.fulcrum.near * tan(camera.fulcrum.fov.float / 2 * radians)
    right = top * camera.fulcrum.aspectRatio.toFloat.float32
    a: float32 = camera.fulcrum.near / right
    b = camera.fulcrum.near / top
    c = -2 * camera.fulcrum.near
  [
    [a, 0,  0, 0],
    [0, b,  0, 0],
    [0, 0, -1, c],
    [0, 0, -1, 0]
  ]

proc viewMatrix*(c: Camera): Mat4 =
  [
    [c.u.x, c.u.y, c.u.z, 0],
    [c.v.x, c.v.y, c.v.z, 0],
    [c.w.x, c.w.y, c.w.z, 0],
    [    0,     0,     0, 1],
  ].Mat4 * translationMatrix(-c.origin)

proc cameraMatrix*(c: Camera, r: Resolution): Mat4 =  projectionMatrix(c) * viewMatrix(c)

proc newCamera*(origin: Vec3, target: Vec3, up: Vec3, fulcrum: Fulcrum): Camera =
  let
    w = norm(origin - target)
    #TODO: This will be nan if up == w: FIX!
    u = norm(cross(up, w)) # u points right, v points up
    v = norm(cross(w, u)) # v points up
  Camera(origin: origin, center: target, u: u, v: v, w: w, fulcrum: fulcrum)

proc updateOrbitalBasis*(c: var Camera, origin, target: Vec3) =
  let distance = length(c.origin - c.center)
  c.origin = origin
  c.center = target
  c.w = norm(c.origin - target)
  # We need to get the cross of c.w with the world up to get an orbiting c.u that won't yaw the camera
  # but when crossing the poles c.w and the world up align perfectly and as the camera becomes upside down
  # their cross product inverses the direction on c.u and therefore turns the camera the opposite direction
  # so the camera will turn 180 degrees and going up will go back the way we came to the pole
  # and as we get near the pole, turn again and so on, spazzing out.
  # When near the pole we instead get the cross of c.v and c.w to avoid this issue, then once we've crossed the bad area
  # we go back to crossing with world up but if we're upside down we cross with the inverse of world up so the direction
  # of c.u won't change.
  # Sorry, I know I won't understand any of this in a month but I tried.
  if length(cross(c.w, [0'f32, 1, 0])) < 0.05:
    c.u = norm(cross(c.v, c.w))
  else:
    if c.v.y < 0:
      c.u = norm(cross(-[0'f32, 1, 0].Vec3, c.w))
    else:
      c.u = norm(cross([0'f32, 1, 0].Vec3, c.w))
  #c.u = norm(cross(c.v, c.w))
  c.v = norm(cross(c.w, c.u))

  # Restore distance
  c.origin = c.center + c.w * distance

proc moveDelta*(c: var Camera, dx, dy: float64) =
  # let distance = length(c.origin - c.center)
  # c.origin = c.origin + c.u * dx + c.v * dy
  c.updateOrbitalBasis(c.origin + c.u * dx + c.v * dy, c.center)
  # c.origin = c.center + c.w * distance

proc moveDelta*(c: var Camera, dx: float64) =
  let previousY = c.origin.y
  c.moveDelta(dx, 0)
  # let distance = length(c.origin - c.center)
  # c.origin = c.origin + c.u * dx
  # c.updateOrbitalBasis(c.center)
  # c.origin = c.center + c.w * distance
  c.origin = [c.origin.x, previousY, c.origin.z].Vec3

proc zoomDelta*(c: var Camera, dt: float64) =
  let
    currentDistance = length(c.origin - c.center)
    newOrigin = c.origin - c.w * dt
    nextDistance = length(newOrigin - c.center)

  if nextDistance < currentDistance and nextDistance <= c.minDistance: return
  if nextDistance > currentDistance and nextDistance >= c.maxDistance: return
  c.origin = c.origin - c.w * dt
  #c.updateOrbitalBasis(c.center)


proc move*(c: var Camera, m: string) =

  #case m:
  #of "forward":  c.origin = c.origin - c.w * 2
  #of "back":     c.origin = c.origin + c.w * 2
  #of "left":     c.origin = c.origin + c.u * 2
  #of "right":    c.origin = c.origin - c.u * 2
  #of "vfor":     c.origin = c.origin + c.v * 2
  #of "vback":    c.origin = c.origin - c.v * 2
  #c.updateOrbitalBasis([0'f32, 0, 0].Vec3)
  case m:
  of "forward":  c.origin = c.origin - [1'f32, 0, 0] * 2
  of "back":     c.origin = c.origin + [1'f32, 0, 0] * 2
  of "left":     c.origin = c.origin + [0'f32, 0, 1] * 2
  of "right":    c.origin = c.origin - [0'f32, 0, 1] * 2
  of "vfor":     c.origin = c.origin + [0'f32, 1, 0] * 2
  of "vback":    c.origin = c.origin - [0'f32, 1, 0] * 2
