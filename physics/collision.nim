import std/[options, sequtils]

import ../utils/blas
import ../primitives/model

type
  Box = ref object
    minv: Vec3 = [Inf.float32, Inf, Inf].Vec3
    maxv: Vec3 = [-Inf.float32, -Inf, -Inf].Vec3

  Triangle = seq[Vec3]

  Node* {.acyclic.} = ref object
    left, right: Option[Node]
    box: Box = Box(minv: [Inf.float32, Inf, Inf].Vec3, maxv: [-Inf.float32, -Inf, -Inf].Vec3)
    triangles: seq[Triangle]

  Intersection* = ref object
    triangle: Triangle
    distance*: float

  Ray* = ref object
    origin*, direction*: Vec3

const NUMTESTS: int = 5

proc isLeaf(node: Node): bool = node.left.isNone() and node.right.isNone()

# https://github.com/SebLague/Ray-Tracing/blob/main/Assets/Scripts/Shaders/RayTracer.shader
# https://stackoverflow.com/questions/42740765/intersection-between-line-and-triangle-in-3d/42752998#42752998
proc findIntersection(ray: Ray, triangle: Triangle): Option[Intersection] =
  var
    edgeAB = triangle[1] - triangle[0]
    edgeAC = triangle[2] - triangle[0]
    normal = cross(edgeAB, edgeAC)
    ao = ray.origin - triangle[0]
    dao = cross(ao, ray.direction)
    determinant = -dot(ray.direction, normal)
    invDet = 1.0 / determinant
    distance = dot(ao, normal) * invDet
    u =  dot(edgeAC, dao) * invDet
    v = -dot(edgeAB, dao) * invDet
    w = 1 - u - v

  if determinant >= 1E-8 and distance >= 0 and u >= 0 and v >= 0 and w >= 0:
    result = some(Intersection(triangle: triangle, distance: distance))
  else:
    result = none(Intersection)

# https://tavianator.com/2015/ray_box_nan.html
proc findIntersection(ray: Ray, box: Box): Option[float32] =
  var
    invDir = [1.0'f32 / ray.direction.x, 1.0'f32 / ray.direction.y, 1.0'f32 / ray.direction.z].Vec3
    tmin = (box.minv - ray.origin) * invDir
    tmax = (box.maxv - ray.origin) * invDir
    t1 = min(tmin, tmax)
    t2 = max(tmin, tmax)
    far  = min(min(t2.x, t2.y), t2.z)
    near = max(max(t1.x, t1.y), t1.z)
  result = if far >= near and far > 0: some(near) else: none(float32)

proc findIntersection*(ray: Ray, node: Node, closest: var Option[Intersection]): Option[Intersection] =
  var boxHit = ray.findIntersection(node.box)
  if boxHit.isSome() and (closest.isNone() or closest.get().distance > boxHit.get()):
    if node.isLeaf():
      for triangle in node.triangles:
        var hit = ray.findIntersection(triangle)
        if hit.isSome() and (closest.isNone() or closest.get().distance > hit.get().distance): closest = hit
    else:
      if node.left.isSome():  closest = ray.findIntersection(node.left.get(),  closest)
      if node.right.isSome(): closest = ray.findIntersection(node.right.get(), closest)
  return closest

proc encompass(box: var Box, v: Vec3) =
  box.minv = min(v, box.minv)
  box.maxv = max(v, box.maxv)

proc encompass(node: Node, triangle: Triangle) =
  for v in triangle: node.box.encompass(v)
  node.triangles.add(triangle)

proc cost(box: Box, numTriangles: int): float =
  var
    size = (box.maxv - box.minv)
    halfArea = size.x * (size.y + size.z) + size.y * size.z
  return halfArea * numTriangles.float

proc evaluate(node: Node, axis: int, position: float): float =
  var boxLeft = new Box
  var boxRight = new Box
  var numLeft, numRight: int

  for triangle in node.triangles:
    var center  = (triangle[0] + triangle[1] + triangle[2]) / 3
    if center[axis] < position:
      numLeft += 1
      for v in triangle: boxLeft.encompass(v)
    else:
      numRight += 1
      for v in triangle: boxRight.encompass(v)

  return cost(boxLeft, numLeft) + cost(boxRight, numRight)

proc split(node: Node, depth, maxDepth: int) =
  if depth == maxDepth: return
  var left  = new Node
  var right = new Node

  var boxSize   = (node.box.maxv - node.box.minv)
  var positions = mapIt(1..NUMTESTS, node.box.minv + boxSize * it.float / (NUMTESTS.float+1))
  var
    bestPosition: float
    bestCost: float = Inf
    bestAxis: int
  for position in positions:
    for axis in 0..<3:
      var cost = evaluate(node, axis, position[axis])
      if cost < bestCost:
        bestCost = cost
        bestAxis = axis
        bestPosition = position[axis]

  for triangle in node.triangles:
    var center  = (triangle[0] + triangle[1] + triangle[2]) / 3
    var hisNode = if center[bestAxis] < bestPosition: left else: right
    hisNode.encompass(triangle)

  if left .triangles.len > 5: left.split(depth+1, maxDepth)
  if left .triangles.len > 0: node.left = some(left)
  if right.triangles.len > 5: right.split(depth+1, maxDepth)
  if right.triangles.len > 0: node.right = some(right)

proc buildTree*(model: Model, depth: int): Node =
  result = new Node

  for mesh in model.meshes:
    for i in 0..<mesh.indexedVertices.ebo.len:
      if i mod 3 != 0: continue
      let vertex1 = mesh.indexedVertices.vbo[mesh.indexedVertices.ebo[i+0]].position
      let vertex2 = mesh.indexedVertices.vbo[mesh.indexedVertices.ebo[i+1]].position
      let vertex3 = mesh.indexedVertices.vbo[mesh.indexedVertices.ebo[i+2]].position
      result.encompass @[vertex1, vertex2, vertex3]

  result.split(depth=0, maxDepth=depth)

proc getHeight*(tree: Node, position: Vec3): Vec3 =
  var
    origin: Vec3    = [position.x, 1000, position.z].Vec3
    direction: Vec3 = [0'f32, -1, 0].Vec3
    ray = Ray(origin: origin, direction: direction)
    closest = none(Intersection)
  closest = ray.findIntersection(tree, closest)
  if closest.isSome():
    return [position.x, (origin+direction*closest.get().distance).y, position.z].Vec3
  else:
    return position
