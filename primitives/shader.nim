import std/[times, math]

import opengl

import ../utils/blas
import ../utils/bogls
import ../game/camera
import light

type
  ShaderId* = int
  Shader* = ref object
    shaderId*: ShaderId
    program*: GLuint
    projMatrixLocation*: GLuint
    modelMatrixLocation*: GLuint
    lightMatrixLocation*: GLuint
    timeLocation*: GLint
    projMatrix*: Mat4
    lightMatrix*: Mat4

proc newShader*(vertexShaderPath, fragmentShaderPath: string, shaderId: ShaderId): Shader =
  result = new Shader
  result.shaderId = shaderId
  result.program = compileShaders(vertexShaderPath, fragmentShaderPath)
  # TODO: Better way to handle uniforms
  result.projMatrixLocation = cast[GLuint](glGetUniformLocation(result.program, "projMatrix"))
  result.modelMatrixLocation = cast[GLuint](glGetUniformLocation(result.program, "modelMatrix"))
  result.lightMatrixLocation = cast[GLuint](glGetUniformLocation(result.program, "lightMatrix"))
  result.timeLocation = cast[GLint](glGetUniformLocation(result.program, "time"))
  # TODO: Add error if one returns 0
  # TODO: Replace with bind for shared uniforms
  echo "Shader ", vertexShaderPath, ". Light: ", result.lightMatrixLocation, " Proj:", result.projMatrixLocation

proc loadShader*(name: string, shaderId: ShaderId): Shader = newShader(name & "_vert.glsl", name & "_frag.glsl", shaderId)

proc toGpu*(shader: Shader, playerCamera: Camera, light: Light, resolution: Resolution) =
  var m = [
    [1'f32, 0, 0, 0],
    [0, 1, 0, 0],
    [0, 0, 1, 0],
    [0, 0, 0, 1]
  ]
  var p = playerCamera.cameraMatrix(resolution) # Move to scene
  shader.projMatrix = p
  shader.lightMatrix = light.lightMatrix(resolution)
  var epoch = epochTime() / 100
  var time: GLfloat = (epoch - floor(epoch)) * 100

  glUseProgram(shader.program)
  # Error below means the uniform location wasn't found in newShader: Either it doesn't exist or it was removed by compiler because unused
  # And that can happend across shaders.
  if shader.shaderId != 3:
    glUniformMatrix4fv(GLint(shader.projMatrixLocation), 1, true, cast[ptr GLFloat](shader.projMatrix.addr)) # Move to model
  if shader.shaderId == 3 or shader.shaderId == 0:
    glUniformMatrix4fv(GLint(shader.lightMatrixLocation), 1, true, cast[ptr GLFloat](shader.lightMatrix.addr)) # Move to model

  glUniform1f(shader.timeLocation, time)
