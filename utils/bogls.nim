# Basic OpenGL Subprograms
import macros
import std/[enumerate, paths, strformat, tables]

import opengl
import stb_image/read as stbi
import stb_image/write as stbiw

import blas


type
  VertexBuffer*[T]  = seq[T]

  IndexBuffer*      = seq[uint32]

  IndexedBuffer*[T] = object
    vertices*: VertexBuffer[T]
    indices*:  IndexBuffer

  GpuId* = GLuint
  IndexedBufferGpuId* = object
    verticesId*, indicesId*: GpuId

var activeTexture: GLint = 0

proc glePointer*[T](data: ptr T): ptr GLfloat = cast[ptr GLFloat](data)

proc gleNextActiveTexture*(): GLint = result = activeTexture; activeTexture += 1

proc gleResetActiveTextureCount*() = activeTexture = 0.GLint

proc gleGetUniformId*(programId: GpuId, uniformName, shaderName: string): GpuId {.inline.} =
  var maybeUniformId = glGetUniformLocation(programId, uniformName)
  if maybeUniformId == -1: raise newException(KeyError, &"Uniform '{uniformName}' not found in {shaderName} shader.")
  return maybeUniformId.GLuint

proc gleGetActiveProgram*(): GLint {.inline.} = glGetIntegerv(GL_CURRENT_PROGRAM, result.addr)

proc indexVertices*[T](vertices: VertexBuffer[T]): IndexedBuffer[T] {.inline.} = # T is a vertex type like MeshVertex
  # I tried a bunch of optimizations with orderedsets and such, this is the best I could do.
  var vertexToIndex = initTable[T, uint32]()
  for v in vertices:
    if not vertexToIndex.hasKeyOrPut(v, len(vertexToIndex).uint32): result.vertices.add(v)
    result.indices.add(vertexToIndex[v])

proc toGpu*[T](indexedBuffer: IndexedBuffer[T]): IndexedBufferGpuId {.inline.} =
  assert indexedBuffer.vertices.len > 0 and indexedBuffer.indices.len > 0, "Empty index buffer."
  glCreateBuffers(1, result.verticesId.addr)
  glNamedBufferData(result.verticesId, indexedBuffer.vertices.len * sizeof(T),    indexedBuffer.vertices[0].addr, GL_STATIC_DRAW)
  glCreateBuffers(1, result.indicesId.addr)
  glNamedBufferData(result.indicesId,  indexedBuffer.indices.len * sizeof(GLUint), indexedBuffer.indices[0].addr,  GL_STATIC_DRAW)

proc setupArrayLayout*[T](vertex: T, verticesId, indicesId: GpuId) =
  var offset: int = 0
  glBindBuffer(GL_ARRAY_BUFFER, verticesId)
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, indicesId)
  for i, fname, field in enumerate(vertex.fieldPairs()):
    assert field is array, "Implement non-array types for vertex fields. Use 'when field is array:...'."
    var itemType: GLenum = when field[0].type is float32: cGL_FLOAT else: cGL_UNSIGNED_SHORT #uint16
    glEnableVertexAttribArray(i.GLuint)
    glVertexAttribPointer(i.GLuint, field.len().GLint, itemType, GL_FALSE, sizeof(vertex).GLsizei, cast[pointer](offset))
    offset += sizeof(field)

proc checkStatus*(objectId: GLuint, objectType: Glenum) {.inline.} =
  var success, logSize: GLint
  var objectInterface = case objectType:
    of GL_SHADER:  (getInfo: glGetShaderiv,  getLog: glGetShaderInfoLog,  status: GL_COMPILE_STATUS, name: "Shader")
    of GL_PROGRAM: (getInfo: glGetProgramiv, getLog: glGetProgramInfoLog, status: GL_LINK_STATUS,    name: "Program")
    else: raise newException(ValueError, "GL object type not implemented.")
  objectInterface.getInfo(objectId, objectInterface.status, success.addr)
  if success == 0:
    echo objectInterface.name & " preparation failed. Reason:"
    objectInterface.getInfo(objectId, GL_INFO_LOG_LENGTH, logSize.addr)
    var
      logStr = cast[cstring](alloc(logSize*10))
      logLen: GLsizei
    glGetShaderInfoLog(objectId, logSize.GLsizei, logLen.addr, logStr)
    echo logStr
    dealloc(logStr)
  else:
    echo objectInterface.name  & " preparation successful."

proc compileShader*(shaderText: string, shaderType: GLenum): GpuId {.inline.} =
  result = glCreateShader(shaderType)
  let cshaderText = shaderText.cstring
  var shaderSource = cast[cstringarray](cshaderText.addr)
  glShaderSource(result, 1, shaderSource, nil)
  glCompileShader(result)
  checkStatus(result, GL_SHADER)

proc compileShaders*(vertexShaderPath, fragmentShaderPath: Path): GpuId {.inline.} =
  let vertexShaderText   = readFile(vertexShaderPath.string)
  let fragmentShaderText = readFile(fragmentShaderPath.string)

  var vertexShader   = compileShader(vertexShaderText,   GL_VERTEX_SHADER)
  var fragmentShader = compileShader(fragmentShaderText, GL_FRAGMENT_SHADER)

  result = glCreateProgram()
  glAttachShader(result, vertexShader)
  glAttachShader(result, fragmentShader)
  glLinkProgram(result)

proc loadTexture*(data: seq[byte]; width, height: int): GpuId {.inline.} =
  glGenTextures(1, result.addr)
  glBindTexture(GL_TEXTURE_2D, result)

  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S,     GL_REPEAT)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T,     GL_REPEAT)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR)

  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8.int32, width.int32, height.int32, 0, GL_RGBA, GL_UNSIGNED_BYTE, data[0].addr)
  glGenerateMipmap(GL_TEXTURE_2D)
  glBindTexture(GL_TEXTURE_2D, 0)

proc loadTextureFromBuffer*(buffer: seq[byte]): GpuId {.inline.} =
  var width, height, channels: int
  let data: seq[byte] = loadFromMemory(buffer, width, height, channels, 4)
  loadTexture(data, width, height)

proc loadTexture*(filepath: string): GpuId {.inline.} =
  var width, height, channels: int
  let data: seq[byte] = stbi.load(filepath, width, height, channels, 4)
  loadTexture(data, width, height)
