import std/[sequtils, tables]

import opengl

import mesh
import material
import shader

import ../utils/blas
import ../utils/bogls

type
  Model* = ref object
    meshes*: seq[Mesh]
    materials*: Table[MaterialId, Material]
    materialIds*: seq[MaterialId]
    transform*: Mat4

proc toGpu*(model: Model, transformAddr: GpuAddr) =
  glUniformMatrix4fv(GLint(transformAddr), 1, true, cast[ptr GLFloat](model.transform.addr))

proc addMesh*(model: Model, vertices: MeshVertices) =
  # Correcting vertices. Should instead fix obj files.
  var newVertices: MeshVertices
  for i in 0..<(vertices.len div 3):
    let k = i * 3
    var normal: Vec3 = (vertices[k + 1].position - vertices[k + 0].position).cross(vertices[k + 2].position - vertices[k + 0].position)
    if normal.length == 0:
      normal = vertices[k].normal
    normal = norm(normal)
    for j in 0..<3:
      newVertices.add MeshVertex(position: vertices[k+j].position, normal: normal, texCoord: vertices[k+j].texCoord)

  var indexedVertices: IndexedMeshVertices = newVertices.indexVertices()
  model.meshes.add(newMesh(indexedVertices))

proc draw*(model: Model, shaderId: ShaderId, drawWithMaterial: bool = true) =#, cameraMatrix: Mat4) =
  # var projectionMatrix = cameraMatrix * diag([1'f32, 0, 0, 0].Vec4)
  for i, (mesh, materialId) in zip(model.meshes, model.materialIds):
    let material = model.materials[materialId]
    if shaderId in material.shaderIds:
      if drawWithMaterial:
        material.toGpu()
      mesh.draw()

proc draw*(model: Model) =#, cameraMatrix: Mat4) =
  # var projectionMatrix = cameraMatrix * diag([1'f32, 0, 0, 0].Vec4)
  for i, (mesh, materialId) in zip(model.meshes, model.materialIds):
    let material = model.materials[materialId]
    material.toGpu()
    mesh.draw()
