import std/[sequtils, tables, math]

import ../utils/[blas, obj]
import ../primitives/[model, mesh]

type
  Cell* = object
    x*, z*: int

  GridPartition* = Table[Cell, seq[Triangle]]
  Triangle* = seq[Vec3]

  CollisionSystem* = ref object
    cellSize*: Positive
    mesh*: seq[Triangle]
    walls*, floor*: GridPartition

# proc intersects(A, B, C, D: Vec2): bool =
proc intersects(p1, p2, p3, p4: Vec3): bool =
  var
    isIntersecting = false
    denominator = (p4.z - p3.z) * (p2.x - p1.x) - (p4.x - p3.x) * (p2.z - p1.z)

  if denominator != 0:
    var
      u_a = ((p4.x - p3.x) * (p1.z - p3.z) - (p4.z - p3.z) * (p1.x - p3.x)) / denominator
      u_b = ((p2.x - p1.x) * (p1.z - p3.z) - (p2.z - p1.z) * (p1.x - p3.x)) / denominator

    if u_a >= 0 and u_a <= 1 and u_b >= 0 and u_b <= 1:
      isIntersecting = true;

  return isIntersecting;

  # var
  #   CmP = C - A
  #   r   = B - A
  #   s   = D - C

  # var
  #   CmPxr = CmP.x * r.y - CmP.y * r.x
  #   CmPxs = CmP.x * s.y - CmP.y * s.x
  #   rxs = r.x * s.y - r.y * s.x

  # if CmPxr == 0: return ((CmP.x < 0) != (C.x - B.x < 0)) or ((CmP.y < 0) != (C.y - B.y < 0))
  # if rxs == 0: return false

  # var
  #   rxsr = 1.0 / rxs
  #   t = CmPxs * rxsr
  #   u = CmPxr * rxsr
  # return (t >= 0) and (t <= 1) and (u >= 0) and (u <= 1)

proc intersects*(triangle: Triangle, point: Vec3): bool =
    var s = (triangle[0].x - triangle[2].x) * (point.z - triangle[2].z) - (triangle[0].z - triangle[2].z) * (point.x - triangle[2].x)
    var t = (triangle[1].x - triangle[0].x) * (point.z - triangle[0].z) - (triangle[1].z - triangle[0].z) * (point.x - triangle[0].x)

    if (s < 0) != (t < 0) and s != 0 and t != 0:
        return false

    var d = (triangle[2].x - triangle[1].x) * (point.z - triangle[1].z) - (triangle[2].z - triangle[1].z) * (point.x - triangle[1].x)
    return d == 0 or (d < 0) == (s + t <= 0)

proc project*(triangle: Triangle, point: Vec3): Vec3 =
  var
    q1 = [0'f32, -100, 0].Vec3
    q2 = [0'f32,  100, 0].Vec3
    normal = cross(triangle[1]-triangle[0], triangle[2]-triangle[0])
    t = -dot(q1-triangle[0], normal) / dot(q2-q1, normal)
  return q1 + t * (q2-q1)

proc getCell*(collider: CollisionSystem, x, z: float): Cell = Cell(x: copySign(abs(x) / collider.cellSize.float, x).int, z: copySign(abs(z) / collider.cellSize.float, z).int)

proc getHeight*(collider: CollisionSystem, point: Vec3): Vec3 =
  var triangles: seq[Triangle] = collider.floor[collider.getCell(point.x, point.z)]
  # echo len(triangles)
  # echo point.x, ", ", point.z
  for triangle in triangles:
    # for v in triangle:
    #   echo v.x, ", ", v.z
    # echo (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0])

    # echo "---"
    if triangle.intersects(point):
      echo triangle.project(point)
      return triangle.project(point)
  assert false, "Gone outside of bounds, no intersection with floor vertices."

proc boundingBox*(collider: CollisionSystem, triangle: Triangle): seq[Cell] =
  var
    minx = min([triangle[0].x, triangle[1].x, triangle[2].x])
    minz = min([triangle[0].z, triangle[1].z, triangle[2].z])
    maxx = max([triangle[0].x, triangle[1].x, triangle[2].x])
    maxz = max([triangle[0].z, triangle[1].z, triangle[2].z])
  return @[collider.getCell(minx, minz), collider.getCell(minz, maxz)]

proc newCollisionSystem*(meshPath, meshName: string, cellSize: Positive): CollisionSystem =
  result = new CollisionSystem
  result.cellSize = cellSize
  var model: Model = loadObj(meshPath, meshName)
  assert model.meshes.len == 1, "Collision model should have exactly one mesh but doesn't."
  var mesh: Mesh = model.meshes[0]

  var angle, slope: float
  for i in 0..<(mesh.indexedVertices.ebo.len div 3):
    var triangle: Triangle
    var normal: Vec3
    for j in 0..<3: # Iterate over the vertices in the face.
      let
        k = i*3 + j
        vertexIndex = mesh.indexedVertices.ebo[k]
        vertex = mesh.indexedVertices.vbo[vertexIndex]
      triangle.add(vertex.position)
      if j == 0: normal = vertex.normal # Assuming all vertices share normals.
      assert normal == vertex.normal, "Breaking mesh assumption in collision system. Resolve unified normal."
    result.mesh.add(triangle)

    # We find every cell that intersects the triangle
    # And we add the triangle to the list associated with these cells
    # either in walls or floor depending on the slope of the triangle
    var cellBounds: seq[Cell] = result.boundingBox(triangle)
    for cx in cellBounds[0].x..cellBounds[1].x:
      for cz in cellBounds[0].x..cellBounds[1].z:
        # var
        #   A = [cx.float32, 0,     cz.float32].Vec3
        #   B = [cx.float32 + cellSize.float32, 0, cz.float32].Vec3
        #   C = [cx.float32 + cellSize.float32, 0, cz.float32 + cellSize.float32].Vec3
        #   D = [cx.float32, 0,    cz.float32 + cellSize.float32].Vec3

        #   E = triangle[0]
        #   F = triangle[1]
        #   G = triangle[2]

        # var reallyIntersects: bool = false
        # block lineChecks:
        #   if intersects(A, B, E, F): reallyIntersects = true; break lineChecks
        #   if intersects(A, B, F, G): reallyIntersects = true; break lineChecks
        #   if intersects(A, B, E, G): reallyIntersects = true; break lineChecks
        #   if intersects(B, C, E, F): reallyIntersects = true; break lineChecks
        #   if intersects(B, C, F, G): reallyIntersects = true; break lineChecks
        #   if intersects(B, C, E, G): reallyIntersects = true; break lineChecks
        #   if intersects(C, D, E, F): reallyIntersects = true; break lineChecks
        #   if intersects(C, D, F, G): reallyIntersects = true; break lineChecks
        #   if intersects(C, D, E, G): reallyIntersects = true; break lineChecks
        #   if intersects(D, A, E, F): reallyIntersects = true; break lineChecks
        #   if intersects(D, A, F, G): reallyIntersects = true; break lineChecks
        #   if intersects(D, A, E, G): reallyIntersects = true; break lineChecks

        # var
        #   A = [cx.float32,     cz.float32].Vec2
        #   B = [cx.float32 + cellSize.float32, cz.float32].Vec2
        #   C = [cx.float32 + cellSize.float32, cz.float32 + cellSize.float32].Vec2
        #   D = [cx.float32,     cz.float32 + cellSize.float32].Vec2

        #   E = [triangle[0].x, triangle[0].z].Vec2
        #   F = [triangle[1].x, triangle[1].z].Vec2
        #   G = [triangle[2].x, triangle[2].z].Vec2

        # if E == F: E = E - [0.001'f32, 0.001'f32].Vec2
        # if E == G: E = E - [0.001'f32, 0.001'f32].Vec2
        # if G == F: G = G - [0.001'f32, 0.001'f32].Vec2

        # var reallyIntersects: bool = false
        # block lineChecks:
        #   if intersects(A, B, E, F): reallyIntersects = true; break lineChecks
        #   if intersects(A, B, F, G): reallyIntersects = true; break lineChecks
        #   if intersects(A, B, E, G): reallyIntersects = true; break lineChecks
        #   if intersects(B, C, E, F): reallyIntersects = true; break lineChecks
        #   if intersects(B, C, F, G): reallyIntersects = true; break lineChecks
        #   if intersects(B, C, E, G): reallyIntersects = true; break lineChecks
        #   if intersects(C, D, E, F): reallyIntersects = true; break lineChecks
        #   if intersects(C, D, F, G): reallyIntersects = true; break lineChecks
        #   if intersects(C, D, E, G): reallyIntersects = true; break lineChecks
        #   if intersects(D, A, E, F): reallyIntersects = true; break lineChecks
        #   if intersects(D, A, F, G): reallyIntersects = true; break lineChecks
        #   if intersects(D, A, E, G): reallyIntersects = true; break lineChecks

        # if reallyIntersects:
        var cell = Cell(x:cx, z:cz)
        if abs(normal.y) < 0.4: # For a perfectly vertical triangle the y component would be 0
          discard result.walls.hasKeyOrPut(cell, newSeq[Triangle]())
          result.walls[cell].add(triangle)
        else:
          discard result.floor.hasKeyOrPut(cell, newSeq[Triangle]())
          result.floor[cell].add(triangle)


  echo "Collision info:"
  echo result.mesh.len
  echo result.walls.len
  echo result.floor.len
  var numTriangles = 0
  for i in result.walls.keys:
    numTriangles += result.walls[i].len
  echo numTriangles / result.walls.len
  numTriangles = 0
  for i in result.floor.keys:
    numTriangles += result.floor[i].len
  echo numTriangles / result.floor.len

