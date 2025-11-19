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
    inverseBindMatrix*: Option[Mat4]

  TransformKind* = enum tkTranslation, tkRotation, tkScale

  JointTransform* = object
    jointId*: JointId
    timestamp*: float
    case kind*: TransformKind
    of tkTranslation: translation*: Vec3
    of tkRotation:    rotation*:    Vec4
    of tkScale:       scale*:       Vec3

  Animation* = object
    name*: string
    duration*: float
    translations*, rotations*, scales*: Table[JointId, seq[JointTransform]]

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
    of tkScale: animation.scales[transform.jointId].add(transform)

proc indexOfClosestTransform*(animation: Animation, transforms: seq[JointTransform], time: float): int =
  for i in 0..<(transforms.len-1):
    if time < transforms[i+1].timestamp:
      return i

proc progress*(previousFrame, nextFrame, currentTime: float): float = (currentTime - previousFrame) / (nextFrame - previousFrame)

proc interpolate*(animation: Animation, jointId: JointId, jointTransform: Mat4, time: float): Mat4 =

  # var translation: Vec3 = IDENTMAT4.translationVector() # This isn't documented anywhere in GLTF, I don't know why we have to do this.
  var translation: Vec3 = jointTransform.translationVector() # This isn't documented anywhere in GLTF, I don't know why we have to do this.
  if animation.translations.hasKey(jointId):
    let translations: seq[JointTransform] = animation.translations[jointId]
    let ti: int = animation.indexOfClosestTransform(translations, time)
    let progressp: float = progress(translations[ti].timeStamp, translations[ti+1].timestamp, time)
    translation = lerp(translations[ti].translation, translations[ti+1].translation, progressp)

  # var rotation: Vec4 = IDENTMAT4.rotationVector()
  var rotation: Vec4 = jointTransform.rotationVector() # This isn't documented anywhere in GLTF, I don't know why we have to do this.
  if animation.rotations.hasKey(jointId):
    let rotations: seq[JointTransform] = animation.rotations[jointId]
    let ri: int = animation.indexOfClosestTransform(rotations, time)
    let progressr: float = progress(rotations[ri].timeStamp, rotations[ri+1].timestamp, time)
    rotation = slerp(rotations[ri].rotation, rotations[ri+1].rotation, progressr)

  
  # var scale: Vec3 = IDENTMAT4.scaleVector()
  var scale: Vec3 = jointTransform.scaleVector() # This isn't documented anywhere in GLTF, I don't know why we have to do this.
  if animation.scales.hasKey(jointId):
    let scales: seq[JointTransform] = animation.scales[jointId]
    let si: int = animation.indexOfClosestTransform(scales, time)
    let progresss: float = progress(scales[si].timeStamp, scales[si+1].timestamp, time)
    scale = lerp(scales[si].scale, scales[si+1].scale, progresss)

  return translation.translationMatrix() * rotation.rotationMatrix() * scale.scaleMatrix()

proc jointMatrices*(animation: Animation, time: float, joint: Joint, parentBindTransform, parentAnimTransform, rootBindTransform: Mat4, matrices: var array[MAX_NUM_JOINTS, Mat4]) =
  var localAnimTransform: Mat4 = animation.interpolate(joint.id, joint.transform, time)

  var bindTransform: Mat4 = parentBindTransform * get(joint.inverseBindMatrix)# joint.transform #get(joint.inverseBindMatrix, IDENTMAT4)# joint.transform
  var animTransform: Mat4 = parentAnimTransform * localAnimTransform
  matrices[joint.id] =   animTransform * rootBindTransform.inverse()# bindTransform# localAnimTransform * parentAnimTransform# animTransform * bindTransform.inverse #get(joint.inverseBindMatrix, IDENTMAT4) # * bindTransform#get(joint.inverseBindMatrix, bindTransform.inverse)
  
  # matrices[joint.id] =  animTransform * bindTransform.inverse #get(joint.inverseBindMatrix, IDENTMAT4) # * bindTransform#get(joint.inverseBindMatrix, bindTransform.inverse)

  for child in joint.children:
    animation.jointMatrices(time, child, bindTransform, animTransform, rootBindTransform, matrices)

proc use*(animationComponent: AnimationComponent, shader: ShaderOnGpu) =
  if shader.uniforms.hasKey(JOINT_MATRIX_UNIFORM):
    var jointMatrices: array[MAX_NUM_JOINTS, Mat4]
    for i in 0..<100:
      jointMatrices[i] = IDENTMAT4
    var playingAnim: Animation = animationComponent.animations[animationComponent.playingId]
    var rootBindTransform: Mat4 = IDENTMAT4
    if animationComponent.skeletonRoot.inverseBindMatrix.isSome():
      rootBindTransform = animationComponent.skeletonRoot.inverseBindMatrix.get()
    playingAnim.jointMatrices(epochTime() mod playingAnim.duration, animationComponent.skeletonRoot, IDENTMAT4, IDENTMAT4, rootBindTransform, jointMatrices)
    glUniformMatrix4fv(shader.uniforms[JOINT_MATRIX_UNIFORM].GLint, 100, true, glePointer(jointMatrices.addr))
