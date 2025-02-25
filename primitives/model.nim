import std/[options, tables]

import opengl

import animation
import mesh
import material
import shader

import ../utils/[blas, bogls]

type
  MeshName = string

  Model*[T] = object
    meshes*:    Table[MeshName, IndexedMesh[T]]
    materials*: Table[MeshName, seq[Material]]
    animationComponent*: Option[AnimationComponent]
    transform*: Mat4

  ModelOnGpu* = object
    meshes*:    Table[MeshName, MeshOnGpu]
    materials*: Table[MeshName, seq[MaterialOnGpu]]
    animationComponent*: Option[AnimationComponent]
    transform*: Mat4

const MODEL_MATRIX_UNIFORM = Uniform(name: "modelMatrix", kind: ukValues)

proc addMesh*[T](model: var Model[T], name: MeshName, mesh: IndexedMesh[T], material: Material) =
  model.meshes[name]    = mesh
  model.materials[name] = @[material]

proc addMesh*[T](model: var Model[T], name: MeshName, mesh: Mesh[T], material: Material) =
  var newMesh: IndexedMesh[T] = (IndexedMesh[T])mesh.indexVertices()
  addMesh[T](model, name, newMesh, material)

proc addMesh*(model: var ModelOnGpu, name: MeshName, mesh: MeshOnGpu, material: MaterialOnGpu) =
  model.meshes[name]    = mesh
  model.materials[name] = @[material]

proc animations*(model: var Model):      var seq[Animation] {.inline.} = model.animationComponent.get().animations
proc animations*(model: var ModelOnGpu): var seq[Animation] {.inline.} = model.animationComponent.get().animations

# A Model can be defined then transformed into a ModelOnGpu,
# or the resource manager can handle passing the meshes and materials to the GPU and create a ModelOnGpu from scratch.
proc toGpu*[T](model: Model[T]): ModelOnGpu =
  result.transform = IDENTMAT4 # TODO: Should be I/O once we have a good format.
  result.animationComponent = model.animationComponent
  for name, mesh in model.meshes.pairs():
    result.meshes[name] = toGpu[T](mesh)
    result.materials[name] = @[]
    for material in model.materials[name]:
      result.materials[name].add material.toGpu()

proc draw*(model: ModelOnGpu, shader: ShaderOnGpu) =
  if shader.uniforms.hasKey(MODEL_MATRIX_UNIFORM):
    glUniformMatrix4fv(shader.uniforms[MODEL_MATRIX_UNIFORM].GLint, 1, true, glePointer(model.transform.addr))
  if model.animationComponent.isSome():
    model.animationComponent.get().use(shader)
  for name, mesh in model.meshes.pairs:
    for material in model.materials[name]:
      if shader.id != material.shaderId: continue
      material.use(shader.uniforms)
      mesh.draw()
