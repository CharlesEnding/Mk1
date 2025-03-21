# Basic Linear Algebra Subprograms

import math
import std/strutils

type
  Vec*[N: static[int]; T] = array[N, T]
  Mat*[N, M: static[int]; T] = array[N, Vec[M, T]]

  Vec2* = Vec[2, float32]
  Vec3* = Vec[3, float32]
  Vec4* = Vec[4, float32]
  Mat2* = Mat[2, 2, float32]
  Mat3* = Mat[3, 3, float32]
  Mat4* = Mat[4, 4, float32]

const IDENTMAT4*: Mat4 = [
  [1'f32, 0, 0, 0],
  [0,     1, 0, 0],
  [0,     0, 1, 0],
  [0,     0, 0, 1]
].Mat4

# VECTOR OPERATIONS
proc x*[N, T](v: Vec[N, T]): T {.inline.} = v[0]
proc y*[N, T](v: Vec[N, T]): T {.inline.} = v[1]
proc z*[N, T](v: Vec[N, T]): T {.inline.} = v[2]
proc w*[N, T](v: Vec[N, T]): T {.inline.} = v[3]

proc pretty*[N, T](v: Vec[N, T], epsilon: float = 0.02): string {.inline.} =
  result &= "["
  for i in 0..<N:
    if abs(v[i]) <= epsilon:
      result &= "0.0"
    else:
      let trunclen = log10(abs(v[i])).int + 3
      let l = min(trunclen, len($v[i])-1)
      result &= ($v[i])[0..l]
    if i < N-1: result &= ", "
  result &= "]"

proc `-`*[N, T](v: Vec[N, T]): Vec[N, T] {.inline.} =
  for i in 0..<N:
    result[i] = -v[i]

proc `*`*[N, T](v: Vec[N, T], s: T): Vec[N, T] {.inline.} =
  for i in 0..<N:
    result[i] = v[i] * s

proc `*`*[N, T](s: T, v: Vec[N, T]): Vec[N, T] {.inline.} = v * s

proc `/`*[N, T](v: Vec[N, T], s: T): Vec[N, T] {.inline.} =
  for i in 0..<N:
    result[i] = v[i] / s

proc `+`*[N, T](a, b: Vec[N, T]): Vec[N, T] {.inline.} =
  for i in 0..<N:
    result[i] = a[i] + b[i]

proc `+=`*[N, T](a, b: Vec[N, T]): Vec[N, T] {.inline.} =
  for i in 0..<N:
    result[i] = a[i] + b[i]

proc `-`*[N, T](a, b: Vec[N, T]): Vec[N, T] {.inline.} =
  for i in 0..<N:
    result[i] = a[i] - b[i]

proc `*`*[N, T](a, b: Vec[N, T]): Vec[N, T] {.inline.} =
  for i in 0..<N:
    result[i] = a[i] * b[i]

proc `/`*[N, T](a, b: Vec[N, T]): Vec[N, T] {.inline.} =
  for i in 0..<N:
    result[i] = a[i] / b[i]

proc dot*[N, T](a, b: Vec[N, T]): T {.inline.} =
  for i in 0..<N:
    result += a[i]*b[i]

proc `⊗`*[N, M, T](a: Vec[N, T], b: Vec[M, T]): Mat[N, M, T] {.inline.} =
  for i in 0..<N:
    for j in 0..<M:
      result[i][j] = a[i]*b[j]

proc diag*[N, T](v : Vec[N,T]): Mat[N,N,T] {.inline.} =
  for i in 0..(N-1):
    result[i][i] = v[i]

proc cross*[T](a, b: Vec[3, T]): Vec[3, T] {.inline.} =
  [
    a[1] * b[2] - a[2] * b[1],
    a[2] * b[0] - a[0] * b[2],
    a[0] * b[1] - a[1] * b[0]
  ]

proc length*[N, T](v: Vec[N, T]): float32 {.inline.} =
  for i in 0..<N:
    result += v[i]*v[i]
  result = sqrt(result)

proc norm*[N, T](v: Vec[N, T]): Vec[N, T] {.inline.} =
  let len = v.length
  if len == 0:
    for i in 0..<N:
      result[i] = 0
      return result
  for i in 0..<N:
    result[i] = v[i] / len

proc  lerp*[N, T](v0, v1: Vec[N, T], t: T): Vec[N, T] {.inline.} =
  return (1 - t) * v0 + t * v1

proc slerp*[N, T](v0, v1: Vec[N, T], t: T): Vec[N, T] {.inline.} =
  result = if dot(v0, v1) >= 0: lerp(v0, v1, t).norm() else: lerp(v0, -v1, t).norm()

proc min*[N, T](v0, v1: Vec[N, T]): Vec[N, T] {.inline.} =
  for i in 0..<N:
    result[i] = min(v0[i], v1[i])

proc max*[N, T](v0, v1: Vec[N, T]): Vec[N, T] {.inline.} =
  for i in 0..<N:
    result[i] = max(v0[i], v1[i])

# MATRIX OPERATIONS
proc `+`*[N, T](m1, m2: Mat[N, N, T]): Mat[N, N, T] {.inline.} =
  for i in 0..<N:
    for j in 0..<N:
      result[i][j] = m1[i][j] + m2[i][j]

proc `*`*[N, T](m1, m2: Mat[N, N, T]): Mat[N, N, T] {.inline.} =
  for i in 0..<N:
    for j in 0..<N:
      for k in 0..<N:
        result[i][j] += m1[i][k] * m2[k][j]

proc `*`*[N, T](m: Mat[N, N, T], v: Vec[N, T]): Vec[N, T] {.inline.} =
  for i in 0..<N:
    for j in 0..<N:
      result[i] += m[i][j] * v[j]

proc `*`*[N, M, T](s: T, m: Mat[N, M, T]): Mat[N, M, T] {.inline.} =
  for i in 0..<N:
    for j in 0..<M:
      result[i][j] = m[i][j] * s

proc Tr*[N, M, T](m: Mat[N, M, T]): Mat[M, N, T] {.inline.} =
  for i in 0..<N:
    for j in 0..<M:
      result[j][i] = m[i][j]

proc `$`*[N, M, T](m: Mat[N, M, T]): string {.inline.} =
  for i in 0..<N:
    if i == 0: result &= "⎡" else: result &= "⎢"
    for j in 0..<M:
      var value: float32 = if abs(m[i][j]) < 0.001: 0.0 else: m[i][j]
      let truncLen = if value >= 0: 6 else: 7 # Negative numbers are allowed an extra char before truncation: the minus sign
      if m[i][j] >= 0: result &= " " # Adding a space in front of non-negatives so they always align to negatives
      let l = min(truncLen, len($value)-1)
      result &= ($value)[0..l] & repeat("...", int(len($value) > truncLen)) & repeat(" ", trunclen-l) & "  \t"
    if i == N-1: result &= "⎦\n" else: result &= "⎥\n"

proc ravelIndex*(index, numCols: int): array[2, int] = [index div  numCols, index mod numCols]
proc unravelIndex*(index: array[2, int], numCols: int): int = index[0] * numCols + index[1]

proc inverse*(m: Mat4): Mat4 =
  let
    s0 = m[0][0] * m[1][1] - m[1][0] * m[0][1]
    s1 = m[0][0] * m[1][2] - m[1][0] * m[0][2]
    s2 = m[0][0] * m[1][3] - m[1][0] * m[0][3]
    s3 = m[0][1] * m[1][2] - m[1][1] * m[0][2]
    s4 = m[0][1] * m[1][3] - m[1][1] * m[0][3]
    s5 = m[0][2] * m[1][3] - m[1][2] * m[0][3]

    c5 = m[2][2] * m[3][3] - m[3][2] * m[2][3]
    c4 = m[2][1] * m[3][3] - m[3][1] * m[2][3]
    c3 = m[2][1] * m[3][2] - m[3][1] * m[2][2]
    c2 = m[2][0] * m[3][3] - m[3][0] * m[2][3]
    c1 = m[2][0] * m[3][2] - m[3][0] * m[2][2]
    c0 = m[2][0] * m[3][1] - m[3][0] * m[2][1]

    invDet = 1.0 / (s0 * c5 - s1 * c4 + s2 * c3 +
                    s3 * c2 - s4 * c1 + s5 * c0)

  assert invDet != 0.0

  result[0][0] = ( m[1][1] * c5 - m[1][2] * c4 + m[1][3] * c3) * invDet
  result[0][1] = (-m[0][1] * c5 + m[0][2] * c4 - m[0][3] * c3) * invDet
  result[0][2] = ( m[3][1] * s5 - m[3][2] * s4 + m[3][3] * s3) * invDet
  result[0][3] = (-m[2][1] * s5 + m[2][2] * s4 - m[2][3] * s3) * invDet

  result[1][0] = (-m[1][0] * c5 + m[1][2] * c2 - m[1][3] * c1) * invDet
  result[1][1] = ( m[0][0] * c5 - m[0][2] * c2 + m[0][3] * c1) * invDet
  result[1][2] = (-m[3][0] * s5 + m[3][2] * s2 - m[3][3] * s1) * invDet
  result[1][3] = ( m[2][0] * s5 - m[2][2] * s2 + m[2][3] * s1) * invDet

  result[2][0] = ( m[1][0] * c4 - m[1][1] * c2 + m[1][3] * c0) * invDet
  result[2][1] = (-m[0][0] * c4 + m[0][1] * c2 - m[0][3] * c0) * invDet
  result[2][2] = ( m[3][0] * s4 - m[3][1] * s2 + m[3][3] * s0) * invDet
  result[2][3] = (-m[2][0] * s4 + m[2][1] * s2 - m[2][3] * s0) * invDet

  result[3][0] = (-m[1][0] * c3 + m[1][1] * c1 - m[1][2] * c0) * invDet
  result[3][1] = ( m[0][0] * c3 - m[0][1] * c1 + m[0][2] * c0) * invDet
  result[3][2] = (-m[3][0] * s3 + m[3][1] * s1 - m[3][2] * s0) * invDet
  result[3][3] = ( m[2][0] * s3 - m[2][1] * s1 + m[2][2] * s0) * invDet

# TRANSFORMATIONS

const NO_TRANSLATION*: Vec3 = [0'f32, 0, 0].Vec3
proc translationMatrix*(v: Vec3): Mat4 {.inline.} =
  [
    [1, 0, 0, v[0]],
    [0, 1, 0, v[1]],
    [0, 0, 1, v[2]],
    [0, 0, 0,    1]
  ]
proc translationVector*(m: Mat4): Vec3 {.inline.} = [m[0][3], m[1][3], m[2][3]].Vec3

const NO_ROTATION*: Vec4 = [0'f32, 0, 0, 0].Vec4
proc rotationMatrix*(v: Vec4): Mat4 {.inline.} = # xyzw order for quaternions
  var nv = v.norm()
  [
    [1 - 2 * (nv.y^2    + nv.z^2),        2 * (nv.x*nv.y - nv.z*nv.w),     2 * (nv.x*nv.z + nv.y*nv.w), 0],
    [    2 * (nv.x*nv.y + nv.z*nv.w), 1 - 2 * (nv.x^2    + nv.z^2),        2 * (nv.y*nv.z - nv.x*nv.w), 0],
    [    2 * (nv.x*nv.z - nv.y*nv.w),     2 * (nv.y*nv.z + nv.x*nv.w), 1 - 2 * (nv.x^2    + nv.y^2),    0],
    [0, 0, 0, 1]
  ]
# https://math.stackexchange.com/questions/893984/conversion-of-rotation-matrix-to-quaternion
proc rotationVector*(mat: Mat4): Vec4 {.inline.} =
  var m: Mat4 = mat.Tr
  if m[2][2] <  0 and m[0][0] >   m[1][1]: return [1 + m[0][0] - m[1][1] - m[2][2],               m[0][1] + m[1][0],               m[2][0] + m[0][2],               m[1][2] - m[2][1]].Vec4 * 0.5 / sqrt(1 + m[0][0] - m[1][1] - m[2][2])
  if m[2][2] <  0 and m[0][0] <=  m[1][1]: return [              m[0][1] + m[1][0], 1 - m[0][0] + m[1][1] - m[2][2],               m[1][2] + m[2][1],               m[2][0] - m[0][2]].Vec4 * 0.5 / sqrt(1 - m[0][0] + m[1][1] - m[2][2])
  if m[2][2] >= 0 and m[0][0] <  -m[1][1]: return [              m[2][0] + m[0][2],               m[1][2] + m[2][1], 1 - m[0][0] - m[1][1] + m[2][2],               m[0][1] - m[1][0]].Vec4 * 0.5 / sqrt(1 - m[0][0] - m[1][1] + m[2][2])
  if m[2][2] >= 0 and m[0][0] >= -m[1][1]: return [              m[1][2] - m[2][1],               m[2][0] - m[0][2],               m[0][1] - m[1][0], 1 + m[0][0] + m[1][1] + m[2][2]].Vec4 * 0.5 / sqrt(1 + m[0][0] + m[1][1] + m[2][2])
proc eulerAngles*(mat: Mat4): Vec3 {.inline.} =
  var m: Mat4 = mat.Tr
  var sy: float32 = sqrt(m[0][0]^2 + m[0][1]^2)
  if sy < 0.00001:
    return [
      (arctan2(-m[2][1], m[1][1]) * 180 / 3.14).float32,
      arctan2(-m[0][2], sy) * 180 / 3.14,
      0
    ].Vec3
  else:
    return [
      (arctan2( m[1][2], m[2][2]) * 180 / 3.14).float32,
      arctan2(-m[0][2], sy)      * 180 / 3.14,
      arctan2( m[0][1], m[0][0]) * 180 / 3.14
    ].Vec3
proc euler2quaternion*(euler: Vec3): Vec4 {.inline.} =
  var cr: float = cos(euler.x * 0.5)
  var sr: float = sin(euler.x * 0.5)
  var cp: float = cos(euler.y * 0.5)
  var sp: float = sin(euler.y * 0.5)
  var cy: float = cos(euler.z * 0.5)
  var sy: float = sin(euler.z * 0.5)

  [
    (cr * cp * cy + sr * sp * sy).float32,
    (sr * cp * cy - cr * sp * sy).float32,
     cr * sp * cy + sr * cp * sy,
     cr * cp * sy - sr * sp * cy,
  ]
proc direction2quaternion*(direction: Vec3): Vec4 {.inline.} =
  var angle = arctan2(direction.x, direction.z)
  return [0'f32, 1*sin(angle/2.0), 0, cos(angle/2.0)]

const NO_SCALE*: Vec3 = [1'f32, 1, 1].Vec3
proc scaleMatrix*(v: Vec3): Mat4 {.inline.} =
  [
    [v.x,   0,   0, 0],
    [0,   v.y,   0, 0],
    [0,     0, v.z, 0],
    [0,     0,   0, 1]
  ]

proc rotate*(m: Mat4, angle: float32, axis: Vec3): Mat4 {.inline.} =
  # Rodrigues' Formula
  var axis = norm(axis)
  let
    c = cos(angle)
    s = sin(angle)
    temp = [
      [  0'f32, -axis.z,  axis.y],
      [ axis.z,       0, -axis.x],
      [-axis.y,  axis.x,       0]
    ].Mat3
    rotation3 = (1-c) * axis ⊗ axis + diag([c, c, c]) + s * temp

  var rotation4: Mat4
  for i in 0..<3:
    for j in 0..<3:
      rotation4[i][j] = rotation3[i][j]
  rotation4[3][3] = 1

  m * rotation4
