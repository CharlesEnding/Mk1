import std/[strformat, sequtils, streams, tables, json, options, math]

import ../primitives/[model, mesh, material]
import blas

type
  GlbHeader {.packed.} = object
    magic, version, length: uint32

  ChunkHeader {.packed.} = object
    length, ctype: uint32

  Chunk {.packed.} = object
    header: ChunkHeader
    data: string

  AccessorIndex = int
  MaterialIndex = int
  TextureIndex  = int
  TexCoordIndex = int
  BufferIndex   = int
  BufferViewIndex = int
  ImageIndex    = int
  SamplerIndex  = int

  Node = object
    matrix: array[16, float32]
    translation, scale: array[3, float32]
    rotation: array[4, float32]

  RenderingMode = enum rmPoints, rmLines, rmLineLoop, rmLineStrip, rmTriangles, rmTriangleStrip, rmTriangleFan

  Primitive = object
    mode:     Option[RenderingMode]
    indices:  Option[AccessorIndex]
    material: Option[MaterialIndex]
    attributes: Table[string, AccessorIndex]

  Mesh = object
    name: string
    primitives: seq[Primitive]

  Buffer = object
    byteLength: int
    uri: Option[string]

  BufferView = object
    buffer: BufferIndex
    byteOffset, byteLength, byteStride, target: Option[int]

  Accessor = object
    bufferView: BufferViewIndex
    byteOffset: Option[int]
    `type`: string
    componentType: int
    count: int
    `min`, `max`: Option[seq[float]]

  TextureReference = object
    index: Option[TextureIndex]
    texCoords: Option[TexCoordIndex]
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
    source:  ImageIndex
    sampler: SamplerIndex

  Image = object
    name: Option[string]
    uri: Option[string]
    bufferView: Option[BufferViewIndex]
    mimeType: Option[string]

  Context = ref object
    accessors:   seq[Accessor]
    bufferViews: seq[BufferView]
    buffers:    seq[Buffer]
    materials:  seq[Material]
    images:     seq[Image]
    textures:   seq[Texture]

  LoadedMesh = object
    positions, normals: Option[seq[Vec3]]
    joints, weights:    Option[seq[Vec4]]
    texCoords: Option[seq[Vec2]]
    indices: Option[seq[uint16]]

  # Repeated types so this works as a single file
  Vec[N: static[int]; T] = array[N, T]
  Vec2 = Vec[2, float32]
  Vec3 = Vec[3, float32]
  Vec4 = Vec[4, float32]
  Vertex1 = object
    position*, normal*: Vec3
    texCoords*: Vec2
  Vertex2 = object
    position*, normal*: Vec3
    texCoords*: Vec2
    joints*, weights*: Vec4
  Indices = seq[uint16]

# Repeated blas so this works as a single file
proc `-`*[N, T](v: Vec[N, T]): Vec[N, T] {.inline.} =
  for i in 0..<N:
    result[i] = -v[i]
proc `-`*[N, T](a, b: Vec[N, T]): Vec[N, T] {.inline.} =
  for i in 0..<N:
    result[i] = a[i] - b[i]
proc cross*[T](a, b: Vec[3, T]): Vec[3, T] {.inline.} =
  [
    a[1] * b[2] - a[2] * b[1],
    a[2] * b[0] - a[0] * b[2],
    a[0] * b[1] - a[1] * b[0]
  ]
proc length*[N, T](v: Vec[N, T]): float32 {.inline.} =
  for i in 0..<N:
    result += v[i]*v[i]
  result = sqrt(result)
proc norm*[N, T](v: Vec[N, T]): Vec[N, T] {.inline.} =
  let len = v.length
  if len == 0:
    for i in 0..<N:
      result[i] = 0
      return result
  for i in 0..<N:
    result[i] = v[i] / len


proc readGlbHeader(stream: Stream): GlbHeader =
  discard stream.readData(addr(result), sizeof(result))

proc readChunkHeader(stream: Stream): ChunkHeader =
  discard stream.readData(addr(result), sizeof(result))

proc readNextChunk(stream: Stream): Chunk =
  var
    header: ChunkHeader = readChunkHeader(stream)
    data: string = stream.readStr(header.length.int)
  return Chunk(header: header, data: data)

proc readBuffer(stream: Stream, bufferView: BufferView, context: Context, buffer: Chunk): seq[byte] =
  var bufferInfo = context.buffers[bufferView.buffer]
  var bufferSegment = buffer.data[bufferView.byteOffset.get()..<(bufferView.byteOffset.get()+bufferView.byteLength.get())]
  return cast[seq[byte]](bufferSegment)

#TODO: Replace asserts with errors
proc readBuffer[T](stream: Stream, id: AccessorIndex, context: Context, buffer: Chunk): seq[T] =
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
    var itemSize: int = case accessor.`type`:
      of "VEC2": 2*4
      of "VEC3": 3*4
      of "VEC4": 4*4
      else:
        assert false, &"Accessor type not implemented: {accessor.`type`}."
        0
    while cursor < bufferSegment.len() and (cursor+itemSize) < bufferSegment.len():
      unstridedBuffer &= bufferSegment[cursor..<(cursor+itemSize)]
      cursor += bufferView.byteStride.get()
    bufferSegment = unstridedBuffer

  # TODO: Read T from component type and return mapIt converted buffer
  var strm = newStringStream(bufferSegment)
  var data: T
  while not strm.atEnd():
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

proc readMesh(stream: Stream, primitive: Primitive, context: Context, binBuffer: Chunk): LoadedMesh =
  var attributes = primitive.attributes
  for attr in attributes.keys(): assert attr in ["POSITION", "NORMAL", "JOINTS_0", "WEIGHTS_0", "TEXCOORD_0"], &"Attribute not implemented: {attr}."
  assert "NORMAL" in attributes or primitive.indices.isNone(), "Indexed mesh must have precalculated normals."
  var isAnimated: bool = "JOINTS_0" in attributes or "WEIGHTS_0" in attributes

  result.positions = readBuffer[Vec3](stream, attributes["POSITION"], context, binBuffer).some()
  result.normals   = if "NORMAL"     in attributes: readBuffer[Vec3](stream, attributes["NORMAL"],     context, binBuffer).some() else: calcNormals(result.positions.get()).some()
  result.texCoords = if "TEXCOORD_0" in attributes: readBuffer[Vec2](stream, attributes["TEXCOORD_0"], context, binBuffer).mapIt([it[0], 1-it[1]].Vec2).some() else: newSeq[Vec2](result.positions.get().len()).some()
  result.joints    = if isAnimated: readBuffer[Vec4](stream, attributes["JOINTS_0" ], context, binBuffer).some() else: none(seq[Vec4])
  result.weights   = if isAnimated: readBuffer[Vec4](stream, attributes["WEIGHTS_0"], context, binBuffer).some() else: none(seq[Vec4])
  result.indices   = if primitive.indices.isSome(): readBuffer[uint16](stream, primitive.indices.get(), context, binBuffer).some() else: none(seq[uint16])

proc interlace(mesh: LoadedMesh): MeshVertices =
  for i in 0..<mesh.positions.get().len():
    result.add MeshVertex(position: cast[blas.Vec3](mesh.positions.get()[i]), normal: cast[blas.Vec3](mesh.normals.get()[i]), texCoord: cast[blas.Vec2](mesh.texCoords.get()[i]))

proc readTexture(stream: Stream, materialId: MaterialIndex, context: Context, buffer: Chunk): seq[byte] =
  var texId = context.materials[materialId].pbrMetallicRoughness.baseColorTexture.index
  var image = context.images[context.textures[texId.get()].source]
  assert image.bufferView.isSome(), "Expects a bufferView in image reference."
  var bufferView = context.bufferViews[image.bufferView.get()]
  return stream.readBuffer(bufferView, context, buffer)

proc loadContext(obj: JsonNode): Context =
  result = new Context
  result.accessors   = obj["accessors"].to(seq[Accessor])
  result.bufferViews = obj["bufferViews"].to(seq[BufferView])
  result.buffers   = obj["buffers"].to(seq[Buffer])
  result.materials = obj["materials"].to(seq[Material])
  if "textures" in obj:
    result.textures  = obj["textures"].to(seq[Texture])
    result.images    = obj["images"].to(seq[Image])

proc loadObj*(path, filename: string): Model =
  var model = new Model
  model.transform = IDENTMAT4
  #TODO: Add file existence check
  let stream = newFileStream(path & "/" & filename, fmRead)
  defer: stream.close()

  let header = readGlbHeader(stream)
  assert header.magic   == 0x46_54_6C_67, "Wrong magic number in GLB header."
  assert header.version == 2, "Wrong version, parser only supports version 2."

  var chunks: seq[Chunk]
  while not stream.atEnd():
    chunks.add stream.readNextChunk()
  assert chunks[0].header.ctype == 0x4E_4F_53_4A, "First header doesn't have expected JSON type."

  let jsonObj = chunks[0].data.parseJson()
  var context = loadContext(jsonObj)

  var meshes: seq[Mesh] = jsonObj["meshes"].to(seq[Mesh])
  for mesh in meshes:
    for primitive in mesh.primitives:
      var loadedMesh = stream.readMesh(primitive, context, chunks[1])
      var interlaced: MeshVertices = loadedMesh.interlace()
      if loadedMesh.indices.isSome():
        var newIndices: seq[uint32] = loadedMesh.indices.get().mapIt(it.uint32)
        var indexedMesh: IndexedMeshVertices = IndexedMeshVertices(vbo: interlaced, ebo: newIndices)
        model.addIndexedMesh(indexedMesh)
      else:
        model.addMesh(interlaced)
      model.materialIds.add context.materials[primitive.material.get()].name.get()

      if context.textures.len != 0:
        var material = new material.Material
        material.materialId  = context.materials[primitive.material.get()].name.get()
        material.textureBuffer = stream.readTexture(primitive.material.get(), context, chunks[1]).some()
        model.materials[material.materialId] = material

  return model
