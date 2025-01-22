import std/[sequtils, strutils, sugar, tables]
import fusion/matching

import blas
import ../primitives/mesh
import ../primitives/model
import ../primitives/material

proc parseVec[N](data: seq[string]): Vec[N, float32] =
  let parsed = data.filterIt(not isEmptyOrWhitespace(it)).mapIt(parseFloat(it).float32)
  for i in 0..<N: result[i] = parsed[i]
proc parseFace(data: seq[string]): seq[seq[int]] = data.filterIt(not isEmptyOrWhitespace(it)).mapIt(it.split("/").map(v => parseInt(v)-1))
proc parseScalar(data : seq[string]): float32 = parseFloat(data[0]).float32

proc loadMtl*(path, filename: string, model: Model) =
  var material: Material

  for line in lines(path & "/" & filename):
    [@keyword, all @values] := line.split(" ")
    case keyword
    of "newmtl":
      material = new Material
      material.materialId = values[0]
      model.materials[material.materialId] = material #TODO: Remove this and return table instead
    of "Ns": material.ns = parseScalar(values)
    of "Ka": material.ka = parseVec[3](values)
    of "Kd": material.kd = parseVec[3](values)
    of "Ks": material.ks = parseVec[3](values)
    of "Ke": material.ke = parseVec[3](values)
    of "Ni": material.ni = parseScalar(values)
    of "d":  material.d  = parseScalar(values)
    of "illum": material.illum = parseScalar(values)
    of "map_Kd": material.texturePath = path & "/" & values[0]

proc loadObj*(path, filename: string): Model =
  var
    vertices, normals: seq[Vec3]
    texCoords: seq[Vec2]
    faces: seq[seq[seq[int]]]
    model = new Model

  model.transform = IDENTMAT4

  proc addMeshIfPresent() =
    if faces.len == 0: return
    var mesh: MeshVertices
    for f in faces:
      for v in f: # A face vertex is composed of three indices pointing respectively to the vertices, normals and texCoords sequences.
        var vertex = MeshVertex(position: vertices[v[0]], normal: normals[v[2]], texCoord: texCoords[v[1]])
        mesh.add(vertex)
    model.addMesh(mesh)
    faces = newSeq[seq[seq[int]]]()

  for line in lines(path & "/" & filename):
    [@keyword, all @values] := line.split(" ")
    case keyword
    of "v":
      vertices .add parseVec[3](values)
      # if "Mistral" in filename:
      #   echo "v ", vertices[^1][0] / 100.0, " ", vertices[^1][1] / 100.0, " ", vertices[^1][2] / 100.0
    of "vn": normals  .add parseVec[3](values) #TODO: The normals are off by one mby, error in parsing farses splitting by space
    of "vt": texCoords.add parseVec[2](values)
    of "f":  faces    .add parseFace(values)
    of "o":  addMeshIfPresent()
    of "usemtl": # Start of new mesh with different material
      addMeshIfPresent()
      model.materialIds.add(values[0])

  addMeshIfPresent() # To add the last mesh in the buffer

  return model
