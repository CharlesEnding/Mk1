import std/rationals
import std/math

import ../utils/blas

type
  FieldOfView* = range[1..180]
  AspectRatio* = Rational[int]
  Resolution* = object
    nx*, ny*: range[1..high(int)]

  Fulcrum* = object
    near*, far*: float32
    fov*: FieldOfView
    aspectRatio*: AspectRatio # Replace resolution with this

  Camera* = ref object of RootObj
    position*, u*, v*, w*: Vec3
    fulcrum*: Fulcrum

  ThirdPersonCamera* = ref object of Camera
    target*: Vec3
    distance*, minDistance*, maxDistance*, requestedDistance*: float

const UP: Vec3 = [0'f32, 1, 0].Vec3

proc viewportMatrix*(res: Resolution): Mat4 =
  [
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

proc viewMatrix*(c: Camera): Mat4 = # TODO: Modify to work with collider imposed position
  [
    [c.u.x, c.u.y, c.u.z, 0],
    [c.v.x, c.v.y, c.v.z, 0],
    [c.w.x, c.w.y, c.w.z, 0],
    [    0,     0,     0, 1],
  ].Mat4 * translationMatrix(-c.position)

proc cameraMatrix*(c: Camera): Mat4 =  projectionMatrix(c) * viewMatrix(c)

proc newThirdPersonCamera*(target, position: Vec3, minDistance, maxDistance: float, fulcrum: Fulcrum): ThirdPersonCamera =
  assert target != position, "Bad camera configuration."
  assert norm(position - target) != UP, "Bad camera configuration."
  let
    w = norm(position - target)
    u = norm(cross(UP, w)) # u points right, v points up
    v = norm(cross(w, u)) # v points up
    distance = length(position-target)
  ThirdPersonCamera(position: position, u: u, v: v, w: w, fulcrum: fulcrum, target: target, distance: distance, minDistance: minDistance, maxDistance: maxDistance)

proc updatePosition*(c: var ThirdPersonCamera) = c.position = c.target + c.w * c.distance

proc orbit*(c: var ThirdPersonCamera, dx: float) =
  let previousWY = c.w.y
  c.position = c.position + c.u * dx * c.distance
  c.w = norm(c.position - c.target)
  c.w = [c.w.x, previousWY, c.w.z] # Fix errors introduced by numerical imprecision
  c.u = cross(UP, c.w).norm()
  c.v = cross(c.w, c.u).norm()
  c.updatePosition()

proc zoom*(c: var ThirdPersonCamera, dw: float) =
  let newDistance = c.distance - dw
  if newDistance < c.distance and newDistance <= c.minDistance: return # Don't get closer if we're maximally close already
  if newDistance > c.distance and newDistance >= c.maxDistance: return # Don't get farther if we're maximally far already
  c.distance = newDistance
  c.updatePosition()

proc followPlayer*(c: var ThirdPersonCamera, player: Vec3) =
  c.target = player
  c.updatePosition()
