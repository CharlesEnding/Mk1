import std/[math, options, tables, times]

import opengl

import shader
import ../utils/[blas, bogls]

const MAX_NUM_JOINTS* = 100
const JOINT_MATRIX_UNIFORM*  = Uniform(name:"jointTransforms", kind:ukValues)

type
  AnimatedMeshVertex* {.packed.} = object
    position*, normal*: Vec3
    texCoord*: Vec2
    jointIds*: Vec4
    weights*:  Vec4

  JointId* = int
  AnimationId* = int

  Joint* {.acyclic.} = ref object
    id*: JointId
    name*: string
    children*: seq[Joint]
    transform*: Mat4

  TransformKind* = enum tkTranslation, tkRotation

  JointTransform* = object
    jointId*: JointId
    timestamp*: float
    case kind*: TransformKind
    of tkTranslation: translation*: Vec3
    of tkRotation:    rotation*:    Vec4

  Animation* = object
    name*: string
    duration*: float
    translations*, rotations*: Table[JointId, seq[JointTransform]]

  AnimationComponent* = object
    skeletonRoot*: Joint # TODO: Use {.requiresInit.} when Nim fixes the seq warnings (issue #21350)
    animations*: seq[Animation]
    jointMatrices*: array[MAX_NUM_JOINTS, Mat4]
    playingId*: AnimationId = 2

proc add*(animationComponent: var AnimationComponent, animation: Animation) = animationComponent.animations.add(animation)

proc countJoints*(joint: Joint): int =
  var count = 1
  for child in joint.children:
    count += countJoints(child)
  return count

proc findJoint*(joint: Joint, jointId: JointId): Option[Joint] =
  if joint.id == jointId: return some(joint)
  for child in joint.children:
    let maybeJoint = child.findJoint(jointId)
    if maybeJoint.isSome(): return maybeJoint
  return none(Joint)

proc addTransform*(animation: var Animation, transform: JointTransform) =
  case transform.kind:
    of tkTranslation: animation.translations[transform.jointId].add(transform)
    of tkRotation: animation.rotations[transform.jointId].add(transform)

proc indexOfClosestTransform*(animation: Animation, transforms: seq[JointTransform], time: float): int =
  for i in 0..<(transforms.len-1):
    if time < transforms[i+1].timestamp:
      return i

proc progress*(previousFrame, nextFrame, currentTime: float): float = (currentTime - previousFrame) / (nextFrame - previousFrame)

proc interpolate*(animation: Animation, jointId: JointId, jointTransform: Mat4, time: float): Mat4 =
  var translation: Vec3 = jointTransform.translationVector() # This isn't documented anywhere in GLTF, I don't know why we have to do this.
  if animation.translations.hasKey(jointId):
    let translations: seq[JointTransform] = animation.translations[jointId]
    let ti: int = animation.indexOfClosestTransform(translations, time)
    let progressp: float = progress(translations[ti].timeStamp, translations[ti+1].timestamp, time)
    translation = lerp(translations[ti].translation, translations[ti+1].translation, progressp).norm()

  var rotation: Vec4 = jointTransform.rotationVector() # This isn't documented anywhere in GLTF, I don't know why we have to do this.
  if animation.rotations.hasKey(jointId):
    let rotations: seq[JointTransform] = animation.rotations[jointId]
    let ri: int = animation.indexOfClosestTransform(rotations, time)
    let progressr: float = progress(rotations[ri].timeStamp, rotations[ri+1].timestamp, time)
    rotation = slerp(rotations[ri].rotation, rotations[ri+1].rotation, progressr)

  return translation.translationMatrix() * rotation.rotationMatrix()

proc jointMatrices*(animation: Animation, time: float, joint: Joint, parentBindTransform, parentAnimTransform: Mat4, matrices: var array[MAX_NUM_JOINTS, Mat4]) =
  var localAnimTransform: Mat4 = animation.interpolate(joint.id, joint.transform, time)

  var bindTransform: Mat4 = parentBindTransform * joint.transform
  var animTransform: Mat4 = parentAnimTransform * localAnimTransform
  matrices[joint.id] = animTransform * bindTransform.inverse

  for child in joint.children:
    animation.jointMatrices(time, child, bindTransform, animTransform, matrices)

proc use*(animationComponent: AnimationComponent, shader: ShaderOnGpu) =
  if shader.uniforms.hasKey(JOINT_MATRIX_UNIFORM):
    var jointMatrices: array[MAX_NUM_JOINTS, Mat4]
    var playingAnim: Animation = animationComponent.animations[animationComponent.playingId]
    playingAnim.jointMatrices(epochTime() mod playingAnim.duration, animationComponent.skeletonRoot, IDENTMAT4, IDENTMAT4, jointMatrices)
    glUniformMatrix4fv(shader.uniforms[JOINT_MATRIX_UNIFORM].GLint, 100, true, glePointer(jointMatrices.addr))
