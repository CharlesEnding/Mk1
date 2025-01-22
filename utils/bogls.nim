# Basic OpenGL Subprograms
import macros
import std/enumerate
import std/tables
import std/sequtils

import opengl
import stb_image/read as stbi
import stb_image/write as stbiw

import blas


type
  VertexBuffer*[T]  = seq[T]
  IndexBuffer*      = seq[uint32]
  IndexedBuffer*[T] = ref object
    vbo*: VertexBuffer[T]
    ebo*: IndexBuffer
  GpuAddr* = GLuint
  IndexedBufferAddr* = ref object
    vbo*, ebo*: GpuAddr


proc indexVertices*[T](vbo: VertexBuffer[T]): IndexedBuffer[T] = # T is a vertex type (e.g: Vec3[float32]).
  # I tried a bunch of optimizations with orderedsets and such, this is the best I could do.
  result = new IndexedBuffer[T]
  var vertices = initTable[T, uint32]()
  for v in vbo:
    if not vertices.hasKeyOrPut(v, len(vertices).uint32): result.vbo.add(v)
    result.ebo.add(vertices[v])


proc toGpu*[T](indexedBuffer: var IndexedBuffer[T], vertexSize: int): IndexedBufferAddr =
  assert indexedBuffer.vbo.len > 0 and indexedBuffer.ebo.len > 0, "Empty index buffer."
  result = new IndexedBufferAddr
  glGenBuffers(1, result.vbo.addr)
  glBindBuffer(GL_ARRAY_BUFFER, result.vbo)
  glBufferData(GL_ARRAY_BUFFER, indexedBuffer.vbo.len * sizeof(GLFloat) * vertexSize, indexedBuffer.vbo[0].addr, GL_STATIC_DRAW)

  glGenBuffers(1, result.ebo.addr)
  glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, result.ebo)
  glBufferData(GL_ELEMENT_ARRAY_BUFFER, indexedBuffer.ebo.len * sizeof(GLUint), indexedBuffer.ebo[0].addr, GL_STATIC_DRAW)


proc setupArrayLayout*(fieldSizes: seq[int]) =
  let vertexSize: int = fieldSizes.foldl(a + b)
  var offset: int = 0
  for i, fieldSize in enumerate(fieldSizes):
    glEnableVertexAttribArray(i.GLuint)
    glVertexAttribPointer(i.GLuint, fieldSize.GLint, cGL_FLOAT, GL_FALSE, (vertexSize*sizeof(GLFloat)).GLsizei, cast[pointer](offset*sizeof(GLfloat)))
    offset += fieldSize


macro layoutVertexArray*(t: typedesc, vertexArray: untyped, meshVertex: untyped): untyped =
  result = newStmtList()
  result.add quote do:
    var stride = sizeof(`t`)
    glGenVertexArrays(1, `vertexArray`.addr)
    glBindVertexArray(`vertexArray`)

  var tTypeImpl = t.getImpl
  # TypeDef
  #   > Sym "MyTypeName", Empty, ObjectTy
  #                                > Empty, Empty, RecList
  #                                                  > IdentDefs
  #                                                    > Postfix
  #                                                     > Ident "*", Ident "MyFirstFieldName"
  tTypeImpl = tTypeImpl[2][2] # -> ObjectTy -> RecList
  echo tTypeImpl.treeRepr
  for i, child in enumerate(tTypeImpl.children):
    assert child.kind == nnkIdentDefs, "Unexpected type AST."
    let field = child[0][1]
    echo field
    result.add quote do:
      glEnableVertexAttribArray(`i`.GLuint)
      glVertexAttribPointer(`i`, `meshVertex`.`field`.len, cGL_FLOAT, GL_FALSE, stride, cast[pointer](offsetof(`t`, `meshVertex`.`field`)))

  result.add quote do:
    glBindVertexArray(0)


proc checkStatus*(objectId: GLuint, objectType: Glenum) =
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


proc compileShader*(shaderText: string, shaderType: GLenum): GLuint {.inline.} =
  result = glCreateShader(shaderType)
  let cshaderText = shaderText.cstring
  var shaderSource = cast[cstringarray](cshaderText.addr)
  glShaderSource(result, 1, shaderSource, nil)
  glCompileShader(result)
  checkStatus(result, GL_SHADER)


proc compileShaders*(vertexShaderPath, fragmentShaderPath: string): GLuint =
  let vertexShaderText   = readFile(vertexShaderPath)
  let fragmentShaderText = readFile(fragmentShaderPath)

  var vertexShader   = compileShader(vertexShaderText,   GL_VERTEX_SHADER)
  var fragmentShader = compileShader(fragmentShaderText, GL_FRAGMENT_SHADER)

  result = glCreateProgram()
  glAttachShader(result, vertexShader)
  glAttachShader(result, fragmentShader)
  glLinkProgram(result)


proc loadTexture*(data: seq[byte]; width, height: int; textureID: var GLUint) {.inline.} =
  glGenTextures(1, textureID.addr)
  glBindTexture(GL_TEXTURE_2D, textureID)

  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S,     GL_REPEAT)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T,     GL_REPEAT)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
  glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR)

  glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8.int32, width.int32, height.int32, 0, GL_RGBA, GL_UNSIGNED_BYTE, data[0].addr)
  glGenerateMipmap(GL_TEXTURE_2D)
  glBindTexture(GL_TEXTURE_2D, 0)


proc loadTexture*(filepath: string, textureID: var GLUint) {.inline.} =
  var width, height, channels: int
  let data: seq[byte] = stbi.load(filepath, width, height, channels, 4)
  loadTexture(data, width, height, textureID)


# Interface:
  # Pass camera transform
  # Pass model transform
  # Texture.toGpu()
