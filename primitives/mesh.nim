import opengl

import ../utils/blas
import ../utils/bogls

type
  MeshVertex* = object
    position*: Vec3
    normal*: Vec3
    texCoord*: Vec2
  MeshVertices* = VertexBuffer[MeshVertex]
  IndexedMeshVertices* = IndexedBuffer[MeshVertex]
  Mesh* = ref object
    indexedVertices*: IndexedMeshVertices
    bufferAddr*: IndexedBufferAddr
    vao*: GpuAddr

proc newMesh*(meshVertices: IndexedMeshVertices): Mesh =
  result = Mesh()
  result.indexedVertices = meshVertices
  result.bufferAddr = result.indexedVertices.toGpu(8)
  glGenVertexArrays(1, result.vao.addr)
  glBindVertexArray(result.vao)
  setupArrayLayout(@[3, 3, 2])
  glBindVertexArray(0)

proc draw*(mesh: Mesh) =
  glEnableVertexAttribArray(0);
  glBindVertexArray(mesh.vao)
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, mesh.bufferAddr.ebo);
  glDrawElements(GL_TRIANGLES, mesh.indexedVertices.ebo.len.GLint, GL_UNSIGNED_INT, nil)
  glBindVertexArray(0)

#TODO: Move to character module
proc getFeet*(mesh: Mesh): Vec3 =
  var minx, miny, minz, maxx, maxz: float
  minx = 1000
  miny = 1000
  minz = 1000
  maxx = -1000
  maxz = -1000

  for i in 0..<mesh.indexedVertices.ebo.len:
    let
      vertexIndex = mesh.indexedVertices.ebo[i]
      vertex = mesh.indexedVertices.vbo[vertexIndex].position
    if vertex.x < minx: minx = vertex.x
    if vertex.y < miny: miny = vertex.y
    if vertex.z < minz: minz = vertex.z
    if vertex.x > maxx: maxx = vertex.x
    if vertex.z > maxz: maxz = vertex.z
  var
    centerx: float32 = (maxx - minx) / 2.0 + minx
    centerz = (maxz - minz) / 2.0 + minz
  return [centerx, miny, centerz].Vec3
