import std/[enumerate, json, math, options, paths, sequtils, streams, strformat, tables]

import ../primitives/[model, mesh, material, shader, texture, animation]
import blas
import bogls

type
  GlbHeader {.packed.} = object
    magic, version, length: uint32

  ChunkHeader {.packed.} = object
    length, ctype: uint32

  Chunk {.packed.} = object
    header: ChunkHeader
    data: string

  ResourceIndex = int
  AccessorIndex = ResourceIndex

  RenderingMode = enum rmPoints, rmLines, rmLineLoop, rmLineStrip, rmTriangles, rmTriangleStrip, rmTriangleFan

  Primitive = object
    mode: Option[int] = some(rmTriangles.int)
    indices, material: Option[ResourceIndex]
    attributes: Table[string, AccessorIndex]

  Mesh = object
    name: string
    primitives: seq[Primitive]

  Buffer = object
    byteLength: int
    uri: Option[string]

  BufferView = object
    buffer: ResourceIndex
    byteOffset, byteLength, byteStride, target: Option[int]

  Accessor = object
    bufferView: ResourceIndex
    byteOffset: Option[int]
    `type`: string
    componentType, count: int
    `min`, `max`: Option[seq[float]]

  TextureReference = object
    index, texCoords: Option[ResourceIndex]
    scale, strength: Option[float]

  PBR = object
    baseColorTexture, metallicRoughnessTexture: TextureReference
    baseColorFactor: Option[Vec4]
    metallicFactor, roughnessFactor: Option[float]

  Material = object
    name: Option[string]
    pbrMetallicRoughness: PBR
    normalTexture, occlusionTexture, emissiveTexture: TextureReference
    emissiveFactor: Option[Vec3]

  Texture = object
    name: Option[string]
    source, sampler: ResourceIndex

  Image = object
    name, uri, mimeType: Option[string]
    bufferView: Option[ResourceIndex]

  Node = object
    name:     Option[string]
    children: Option[seq[ResourceIndex]]
    camera, skin, mesh: Option[ResourceIndex]
    translation, scale: Option[Vec3]
    rotation: Option[Vec4]
    weights:  Option[seq[float]]
    matrix:   Option[array[16, float]]

  Skin = object
    inverseBindMatrices: Option[AccessorIndex]
    skeleton: Option[int]
    joints: seq[int]
    name: Option[string]

  AnimationChannelTarget = object
    node: ResourceIndex # Only optional when using extensions. Extensions not supported -> Not optional.
    path: string

  AnimationChannel = object
    sampler: ResourceIndex
    target:  AnimationChannelTarget

  AnimationSampler = object
    input, output: AccessorIndex
    interpolation: Option[string] = some("LINEAR")

  Animation = object
    name: Option[string]
    channels: seq[AnimationChannel]
    samplers: seq[AnimationSampler]

  Context = ref object
    accessors:   seq[Accessor]
    bufferViews: seq[BufferView]
    buffers:     seq[Buffer]
    materials:   seq[Material]
    meshes:      seq[Mesh]
    nodes:       seq[Node]
    images:      Option[seq[Image]]
    textures:    Option[seq[Texture]]
    animations:  Option[seq[Animation]]
    skins:       Option[seq[Skin]]

  LoadedMesh = object
    positions, normals: Option[seq[Vec3]]
    joints: Option[seq[array[4, uint16]]]
    weights:    Option[seq[Vec4]]
    texCoords: Option[seq[Vec2]]
    indices:   Option[seq[uint16]]


proc readGlbHeader(  stream: Stream): GlbHeader   = discard stream.readData(addr(result), sizeof(result))
proc readChunkHeader(stream: Stream): ChunkHeader = discard stream.readData(addr(result), sizeof(result))

proc readNextChunk(stream: Stream): Chunk =
  var
    header: ChunkHeader = readChunkHeader(stream)
    data: string = stream.readStr(header.length.int)
  return Chunk(header: header, data: data)

proc readBuffer(context: Context, bufferView: BufferView, buffer: Chunk): seq[byte] =
  var bufferSegment = buffer.data[bufferView.byteOffset.get()..<(bufferView.byteOffset.get()+bufferView.byteLength.get())]
  return cast[seq[byte]](bufferSegment)

#TODO: Replace asserts with errors
proc readBuffer[T](context: Context, id: AccessorIndex, buffer: Chunk): seq[T] =
  var accessor   = context.accessors[id]
  var bufferView = context.bufferViews[accessor.bufferView]
  var bufferInfo = context.buffers[bufferView.buffer]
  assert buffer.header.length.int == bufferInfo.byteLength, "Binary buffer length should be the same as indicated in the buffer info."
  assert bufferView.byteOffset.isSome(), "All buffer views should have byte offsets."
  assert bufferView.byteLength.isSome(), "All buffer views should have byte lengths."

  var bufferSegment = buffer.data[bufferView.byteOffset.get()..<(bufferView.byteOffset.get()+bufferView.byteLength.get())]
  assert bufferSegment.len() == bufferView.byteLength.get()
  if accessor.byteOffset.isSome():
    bufferSegment = bufferSegment[accessor.byteOffset.get()..^1]

  if bufferView.byteStride.isSome():
    var unstridedBuffer: string = ""
    var cursor: int = 0
    var itemSize: int = sizeof(T)
    while cursor < bufferSegment.len() and (cursor+itemSize) <= bufferSegment.len():
      unstridedBuffer &= bufferSegment[cursor..<(cursor+itemSize)]
      cursor += bufferView.byteStride.get()
    bufferSegment = unstridedBuffer

  # TODO: Read T from component type and return mapIt converted buffer
  var strm = newStringStream(bufferSegment)
  var data: T
  while not strm.atEnd() and result.len < accessor.count:
    strm.read(data)
    result.add data

proc calcNormals(positions: seq[Vec3]): seq[Vec3] =
  result.setLen(positions.len)
  for i in 0..<(positions.len div 3):
    let k = i * 3
    var normal: Vec3 = (positions[k + 1] - positions[k + 0]).cross(positions[k + 2] - positions[k + 0]).norm()
    result[k+0] = normal
    result[k+1] = normal
    result[k+2] = normal

proc readMesh(context: Context, primitive: Primitive, binBuffer: Chunk): LoadedMesh =
  var attributes = primitive.attributes
  for attr in attributes.keys(): assert attr in ["POSITION", "NORMAL", "JOINTS_0", "WEIGHTS_0", "TEXCOORD_0"], &"Attribute not implemented: {attr}."
  assert "NORMAL" in attributes or primitive.indices.isNone(), "Indexed mesh must have precalculated normals."
  var isAnimated: bool = "JOINTS_0" in attributes or "WEIGHTS_0" in attributes
  result.positions = readBuffer[Vec3](context, attributes["POSITION"], binBuffer).some()
  result.normals   = if "NORMAL"     in attributes: readBuffer[Vec3](context, attributes["NORMAL"], binBuffer).some() else: calcNormals(result.positions.get()).some()
  result.texCoords = if "TEXCOORD_0" in attributes: readBuffer[Vec2](context, attributes["TEXCOORD_0"], binBuffer).mapIt([it[0], 1-it[1]].Vec2).some() else: newSeq[Vec2](result.positions.get().len()).some()
  result.joints    = if isAnimated: readBuffer[array[4, uint16]](context, attributes["JOINTS_0" ], binBuffer).mapIt([it[0].uint16+2, it[1].uint16+2, it[2].uint16+2, it[3].uint16+2]).some() else: none(seq[array[4, uint16]])
  result.weights   = if isAnimated: readBuffer[Vec4](context, attributes["WEIGHTS_0"], binBuffer).some() else: none(seq[Vec4])
  result.indices   = if primitive.indices.isSome(): readBuffer[uint16](context, primitive.indices.get(), binBuffer).some() else: none(seq[uint16])

proc interlace[T](t: T, mesh: LoadedMesh): VertexBuffer[T] =
  for i in 0..<mesh.positions.get().len():
    var vertex: T = T(position: mesh.positions.get()[i], normal: mesh.normals.get()[i], texCoord: mesh.texCoords.get()[i])
    when T is animation.AnimatedMeshVertex:
      var joints = [mesh.joints.get()[i][0].float32, mesh.joints.get()[i][1].float32, mesh.joints.get()[i][2].float32, mesh.joints.get()[i][3].float32].Vec4

      vertex.jointIds = joints
      vertex.weights  = mesh.weights.get()[i]
    result.add vertex

proc readTexture(context: Context, materialId: ResourceIndex, buffer: Chunk): seq[byte] =
  var texId = context.materials[materialId].pbrMetallicRoughness.baseColorTexture.index
  var image = context.images.get()[context.textures.get()[texId.get()].source]
  assert image.bufferView.isSome(), "Expects a bufferView in image reference."
  var bufferView = context.bufferViews[image.bufferView.get()]
  return context.readBuffer(bufferView, buffer)

proc maybeFindNode(context: Context, name: string): Option[ResourceIndex] =
  for i, node in enumerate(context.nodes):
    if node.name.isSome() and node.name.get() == name: return some(i)
  none(ResourceIndex)

proc readInverseBindMatrix(context: Context, buffer: Chunk): seq[Mat4] =
  var accessor: AccessorIndex = context.skins.get()[0].inverseBindMatrices.get()
  return readBuffer[Mat4](context, accessor, buffer)

proc calcJointMatrix(node: Node): Mat4 = IDENTMAT4 * translationMatrix(get(node.translation, NO_TRANSLATION)) * rotationMatrix(get(node.rotation, NO_ROTATION)) * scaleMatrix(get(node.scale, NO_SCALE))

proc readJointHierarchy(context: Context, node: Node, count: var int, nodeId: ResourceIndex, matrices: Table[ResourceIndex, Mat4]): Joint =
  var inverseBindTransform: Mat4 = IDENTMAT4
  if matrices.hasKey(nodeId):
    inverseBindTransform = matrices[nodeId]
  result = Joint(id: nodeId, name: get(node.name, &"Joint{count}"), transform: node.calcJointMatrix())#, inverseBindTransform: inverseBindTransform)
  count += 1
  result.children = get(node.children, @[]).mapIt(context.readJointHierarchy(context.nodes[it], count, it, matrices))

proc fillModelWithPrimitives[T](model: var Model[T], context: Context, binChunk: Chunk) =
  for meshIndex, m in enumerate(context.meshes):
    for primitiveIndex, primitive in enumerate(m.primitives):
      var loadedMesh = context.readMesh(primitive, binChunk)
      var interlaced: VertexBuffer[T] = interlace[T](T(), loadedMesh)
      var materialId  = context.materials[primitive.material.get()].name.get()
      when T is mesh.MeshVertex:
        var shaderId = 0
      else:
        var shaderId = 5
      case materialId:
        of "TEX_sr1wat1": shaderId = 1 # TODO: make part of epack format
        of "TEX_sr1sky1": shaderId = 2
        of "TEX_sr1fen1": shaderId = 0
        # of "TEX_sr1roa2": shaderId = 2
      var meshMaterial = material.Material(id: materialId, shaderId: shaderId)
      if context.textures.isSome() and context.textures.get().len != 0:
        var textureBuffer: seq[byte] = context.readTexture(primitive.material.get(), binChunk)
        var texture = texture.Texture(name: context.materials[primitive.material.get()].name.get($primitive.material.get()), kind: tkBuffer, buffer: textureBuffer)
        var uniform = shader.Uniform(name: "albedo", kind: ukSampler)
        meshMaterial.textures[uniform] = texture

      var uniqueName: string = m.name & $meshIndex & $primitiveIndex
      if model.meshes.hasKey(uniqueName): raise newException(KeyError, "Model already has a mesh with that name.")
      if loadedMesh.indices.isSome():
        var newIndices: seq[uint32] = loadedMesh.indices.get().mapIt(it.uint32)
        var newMesh = IndexedBuffer[T](vertices: interlaced, indices: newIndices)
        addMesh[T](model, uniqueName, (IndexedMesh[T])newMesh, meshMaterial)
      else:
        addMesh[T](model, uniqueName, interlaced, meshMaterial)

      if materialId == "TEX_sr1etc1" or materialId == "TEX_sr1etc2" or materialId == "TEX_sr1roo1":
        var shadowMaterial = material.Material(id: materialId & "_shadow", shaderId: 3)
        model.materials[uniqueName].add(shadowMaterial)

      if uniqueName == "Mesh0027":
        var refractionMaterial: material.Material = material.Material()
        var uRefraction = shader.Uniform(name: "albedo", kind: ukSampler)
        var refractionTexture = texture.Texture(name: materialId, kind: tkPath, path: "assets/MacAnu/sr1roa2.png".Path)
        refractionMaterial.textures[uRefraction] = refractionTexture
        refractionMaterial.shaderId = 4
        model.materials[uniqueName].add(refractionMaterial)

proc echoHierarchy(joint: animation.Joint, depth: int = 0) =
  var printout: string = ""
  for i in 0..<depth:
    printout = printout & "\t"
  echo printout, joint.name
  for child in joint.children:
    echoHierarchy(child, depth+1)

proc loadObj*[T](path: string, t: T): Model[T] =
  #TODO: Add file existence check
  let stream = newFileStream(path, fmRead)
  defer: stream.close()

  let header = readGlbHeader(stream)
  assert header.magic   == 0x46_54_6C_67, "Wrong magic number in GLB header."
  assert header.version == 2, "Wrong version, parser only supports version 2."

  var jsonChunk = stream.readNextChunk()
  var binChunk  = stream.readNextChunk()
  assert jsonChunk.header.ctype == 0x4E_4F_53_4A, "First header doesn't have expected JSON type."
  let jsonObj = jsonChunk.data.parseJson()
  var context = jsonObj.to(Context)

  var rootNodeId: Option[ResourceIndex] = context.maybeFindNode("root")

  var model: Model[T]
  var root: Joint
  var count: int = 0
  if rootNodeId.isSome():
    var matrixTable: Table[ResourceIndex, Mat4]
    if context.skins.isSome():
      var matrices: seq[Mat4] = context.readInverseBindMatrix(binChunk)
      for i, jid in enumerate(context.skins.get()[0].joints):
        matrixTable[jid] = matrices[i]
    root = context.readJointHierarchy(context.nodes[rootNodeId.get()], count, rootNodeId.get(), matrixTable)
    model.animationComponent = some(AnimationComponent(skeletonRoot: root))
    for i, gltfAnim in enumerate(context.animations.get()):
      var engineAnimation: animation.Animation = animation.Animation(name: get(gltfAnim.name, &"Anim{i}"))
      var duration: float = 0
      for channel in gltfAnim.channels:
        var jointId: JointId = channel.target.node
        var sampler: AnimationSampler = gltfAnim.samplers[channel.sampler]
        var timestamps: seq[float32] = readBuffer[float32](context, sampler.input, binChunk)
        duration = max(max(timestamps), duration)
        case channel.target.path:
        of "translation":
          var frames: seq[Vec3] = readBuffer[Vec3](context, sampler.output, binChunk)
          for ti in 0..<timestamps.len:
            if not engineAnimation.translations.hasKey(jointId):
              engineAnimation.translations[jointId] = newSeq[JointTransform]()
            engineAnimation.translations[jointId].add JointTransform(jointId: jointId, timestamp: timestamps[ti], kind: tkTranslation, translation: frames[ti])
        of "rotation":
          var frames: seq[Vec4] = readBuffer[Vec4](context, sampler.output, binChunk)
          for ti in 0..<timestamps.len:
            if not engineAnimation.rotations.hasKey(jointId):
              engineAnimation.rotations[jointId] = newSeq[JointTransform]()
            engineAnimation.rotations[jointId].add JointTransform(jointId: jointId, timestamp: timestamps[ti], kind: tkRotation, rotation: frames[ti])
      engineAnimation.duration = duration
      model.animations.add(engineAnimation)

  fillModelWithPrimitives[T](model, context, binChunk)

  return model
