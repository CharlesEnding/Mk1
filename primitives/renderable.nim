import std/[paths]

import ../utils/[blas, gltf]

import model, animation, mesh

type
  RenderableBehaviour* = object
    path*: Path
    model*: ModelOnGpu
    animated*: bool

  RenderableBehaviourRef* = ref RenderableBehaviour

proc load*(path: Path, animated: bool): RenderableBehaviourRef =
  result = RenderableBehaviourRef()
  result.path = path
  result.animated = animated

  if animated:
    var model: Model[AnimatedMeshVertex] = gltf.loadObj[AnimatedMeshVertex](path.string, AnimatedMeshVertex())
    result.model = model.toGpu()
  else:
    var model: Model[MeshVertex] = gltf.loadObj[MeshVertex](path.string, MeshVertex())
    result.model = model.toGpu()

proc updateTransform*(renderable: RenderableBehaviourRef, position, orientation, scale: Vec3): RenderableBehaviourRef =
  result = renderable
  result.model.transform = position.translationMatrix() * orientation.direction2quaternion().rotationMatrix() * scale.scaleMatrix()
  # result.model.transform = position.translationMatrix() * scale.scaleMatrix()
