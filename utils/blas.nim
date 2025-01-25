# Basic Linear Algebra Subprograms

import math
#import sugar
#import std/sequtils
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

var IDENTMAT4*: Mat4 = [
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
#proc r*[N, T](v: Vec[N, T]): T = v[0]
#proc g*[N, T](v: Vec[N, T]): T = v[1]
#proc b*[N, T](v: Vec[N, T]): T = v[2]
#proc a*[N, T](v: Vec[N, T]): T = v[3]

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

proc `@`*[N, T](a, b: Vec[N, T]): T {.inline.} =
  for i in 0..<N:
    result += a[i]*b[i]

proc dot*[N, T](a, b: Vec[N, T]): T {.inline.} =
  a @ b

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
  if len == 0: return [0'f32, 0, 0]
  for i in 0..<N:
    result[i] = v[i] / len

proc lerp*[N, T](v0, v1: Vec[N, T], t: T): Vec[N, T] {.inline.} =
  return (1 - t) * v0 + t * v1

proc min*[N, T](v0, v1: Vec[N, T]): Vec[N, T] {.inline.} =
  for i in 0..<N:
    result[i] = min(v0[i], v1[i])

proc max*[N, T](v0, v1: Vec[N, T]): Vec[N, T] {.inline.} =
  for i in 0..<N:
    result[i] = max(v0[i], v1[i])


#proc pad*[N, T](v: Vec[N, T]): Vec[N+1, T] {.inline.} =
#  for i in 0..<N:
#    result[i] = v[i]

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
      let truncLen = if m[i][j] >= 0: 6 else: 7 # Negative numbers are allowed an extra char before truncation: the minus sign
      if m[i][j] >= 0: result &= " " # Adding a space in front of non-negatives so they always align to negatives
      let l = min(truncLen, len($m[i][j])-1)
      result &= ($m[i][j])[0..l] & repeat("...", int(len($m[i][j]) > truncLen)) & repeat(" ", trunclen-l) & "  \t"
    if i == N-1: result &= "⎦\n" else: result &= "⎥\n"

proc ravelIndex*(index, numCols: int): array[2, int] = [index div  numCols, index mod numCols]
proc unravelIndex*(index: array[2, int], numCols: int): int = index[0] * numCols + index[1]


# TRANSFORMATIONS

proc translationMatrix*(v: Vec3): Mat4 {.inline.} =
  [
    [1, 0, 0, v[0]],
    [0, 1, 0, v[1]],
    [0, 0, 1, v[2]],
    [0, 0, 0,    1]
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
