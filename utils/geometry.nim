import sequtils

import ../primitives/mesh
import blas, bogls

const UP: Vec3 = [0'f32, 1, 0].Vec3

proc spur*(p0, p1: Vec3): VertexBuffer[MeshVertex] =
  # New basis
  var w: Vec3 = (p1 - p0).norm() # w points forward along the line
  var u: Vec3 = cross(UP, w).norm() # u points right, v points up
  var v: Vec3 = cross(w,  u).norm()

  var length: float32 = (p1 - p0).length()
  var halfwidth: float32 = length * 0.2 * 0.5
  var splitPoint: Vec3 = lerp(p0, p1, 0.2)

  # Square at split point, going clockwise, starting topleft
  var a: Vec3 = splitPoint - halfwidth * u + halfwidth * v
  var b: Vec3 = splitPoint + halfwidth * u + halfwidth * v
  var c: Vec3 = splitPoint + halfwidth * u - halfwidth * v
  var d: Vec3 = splitPoint - halfwidth * u - halfwidth * v

  var pyramids = @[p1, a, b,  p1, b, c,  p1, c, d,  p1, d, a, # First pyramid
                   p0, a, b,  p0, b, c,  p0, c, d,  p0, d, a] # Second pyramid

  var normals: seq[Vec3]
  normals.setLen(pyramids.len)
  for i in 0..<(pyramids.len div 3):
    let k = i * 3
    var normal: Vec3 = (pyramids[k + 1] - pyramids[k + 0]).cross(pyramids[k + 2] - pyramids[k + 0]).norm()
    normals[k+0] = normal
    normals[k+1] = normal
    normals[k+2] = normal

  for i, (pos, normal) in zip(pyramids, normals):
    result.add MeshVertex(position: pos, normal: normal, texCoord: [0'f32, 0].Vec2)

