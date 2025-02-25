import opengl

import ../utils/[blas, bogls]

type
  MeshVertex* {.packed.} = object
    position*: Vec3
    normal*:   Vec3
    texCoord*: Vec2

  Mesh*[T] = VertexBuffer[T]

  IndexedMesh*[T] = distinct IndexedBuffer[T]

  MeshOnGpu* = object
    numIndices*: int
    bufferRef*: IndexedBufferGpuId
    vertexLayoutId*: GpuId

proc toGpu*[T](indexedMesh: IndexedMesh[T]): MeshOnGpu =
  result.numIndices = IndexedBuffer[T](indexedMesh).indices.len()
  result.bufferRef  = IndexedBuffer[T](indexedMesh).toGpu()
  glCreateVertexArrays(1, result.vertexLayoutId.addr)
  glBindVertexArray(result.vertexLayoutId)
  setupArrayLayout(T(), result.bufferRef.verticesId, result.bufferRef.indicesId)
  glBindVertexArray(0)

proc draw*(gpuMesh: MeshOnGpu) =
  glEnableVertexAttribArray(0)
  glBindVertexArray(gpuMesh.vertexLayoutId)
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, gpuMesh.bufferRef.indicesId)
  glDrawElements(GL_TRIANGLES, gpuMesh.numIndices.GLint, GL_UNSIGNED_INT, nil)
  glBindVertexArray(0)
