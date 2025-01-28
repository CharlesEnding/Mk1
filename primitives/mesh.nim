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

proc getFeet*(mesh: Mesh): Vec3 = #TODO: Move to character module
  var mini: Vec3 = [ Inf.float32,  Inf,  Inf].Vec3
  var maxi: Vec3 = [-Inf.float32, -Inf, -Inf].Vec3

  for i in 0..<mesh.indexedVertices.ebo.len:
    let
      vertexIndex = mesh.indexedVertices.ebo[i]
      vertex = mesh.indexedVertices.vbo[vertexIndex].position
    mini = min(mini, vertex)
    maxi = max(maxi, vertex)
  var center: Vec3 = (maxi - mini) / 2.0 + mini
  return [center.x, mini.y, center.z].Vec3
