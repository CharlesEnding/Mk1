import ../utils/blas

type
  Light* = object
    position*, direction*, color*: Vec3
    radiantPower*: float32

proc init*(position, color: Vec3, radiantPower: float): Light =
  var direction = norm([0'f32, 0, 0].Vec3 - position)
  Light(position: position, direction: direction, color: color, radiantPower: radiantPower)

proc projectionMatrix*(light: Light): Mat4 =
  let far = 200.0
  # let size = 320.0
  let
    a: float32 = 1.0 / 80
    b = 1.0 / 80
    c = -2.0 / (far-1.0)
    d = - (far + 1.0) / (far - 1.0)
  [
    [a, 0, 0, 0],
    [0, b, 0, 0],
    [0, 0, c, d],
    [0, 0, 0, 1]
  ]

proc viewMatrix*(l: Light): Mat4 =
  var
    w = -l.direction
    u = norm(cross([0'f32, 1, 0].Vec3, w)) # u points right, v points up
    v = norm(cross(w, u)) # v points up
  [
    [u.x, u.y, u.z, 0],
    [v.x, v.y, v.z, 0],
    [w.x, w.y, w.z, 0],
    [  0,   0,   0, 1],
  ].Mat4 * translationMatrix(-l.position)

proc lightMatrix*(l: Light): Mat4 =  projectionMatrix(l) * viewMatrix(l)
