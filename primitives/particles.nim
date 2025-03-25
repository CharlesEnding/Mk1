import std/[enumerate, options, random, times]

import opengl

import ../utils/[blas, bogls]
import texture

const NUM_PARTICLES_PER_EMITTER = 200
const VERTICES_PER_PARTICLE = 6
const BUFFER_REPLICATION = 3

type
  ParticleVertex* {.packed.} = object
    position*: Vec3
    texCoord*: Vec2
    color*: Vec3
    life, scale: float32

  Particle = array[VERTICES_PER_PARTICLE, ParticleVertex]

  ParticleBuffers = ptr array[NUM_PARTICLES_PER_EMITTER*VERTICES_PER_PARTICLE*BUFFER_REPLICATION, ParticleVertex]

  ParticleContainer* = object
    particleMesh, vertexLayout, bufferStore: GpuId
    texture: TextureOnGpu
    gpuBuffers: ParticleBuffers
    cpuBuffer:  array[NUM_PARTICLES_PER_EMITTER, Particle]
    currentIndex, bufferInUse: int
    fence: array[BUFFER_REPLICATION, Option[GLSync]]

  ParticleContainerRef* = ref ParticleContainer

  InitParticleVertex   = proc (emitter: ParticleEmitter, index: int): ParticleVertex
  UpdateParticleVertex = proc (emitter: ParticleEmitter, index: int): ParticleVertex

  ParticleEmitter* = object
    translation*: Vec3
    life*, scale*: float32
    interval: Duration = initDuration(seconds=10)
    lastEmission: Time
    isEnabled*: bool
    container*: ParticleContainerRef
    init: InitParticleVertex
    update: UpdateParticleVertex

proc initParticle(): Particle =
  assert VERTICES_PER_PARTICLE == 6, "Change prototype mesh if changing vertices per particle."
  [
    ParticleVertex(position: [-0.5'f32,  0.5, 0], texCoord: [0.0'f32, 0.0], life: 10.0, scale: 1.0),
    ParticleVertex(position: [ 0.5'f32,  0.5, 0], texCoord: [1.0'f32, 0.0], life: 10.0, scale: 1.0),
    ParticleVertex(position: [-0.5'f32, -0.5, 0], texCoord: [0.0'f32, 1.0], life: 10.0, scale: 1.0),
    ParticleVertex(position: [-0.5'f32, -0.5, 0], texCoord: [0.0'f32, 1.0], life: 10.0, scale: 1.0),
    ParticleVertex(position: [ 0.5'f32,  0.5, 0], texCoord: [1.0'f32, 0.0], life: 10.0, scale: 1.0),
    ParticleVertex(position: [ 0.5'f32, -0.5, 0], texCoord: [1.0'f32, 1.0], life: 10.0, scale: 1.0)
  ]

proc initParticleContainer*(): ParticleContainerRef =
  result = new ParticleContainer

  # Create layout for shader
  glCreateVertexArrays(1, result.vertexLayout.addr)
  glBindVertexArray(result.vertexLayout)

  # Create permanent storage for the particle info that changes every frame
  glCreateBuffers(1, result.bufferStore.addr)
  discard setupArrayLayout(ParticleVertex(), result.bufferStore)
  var flags = GL_MAP_WRITE_BIT or GL_MAP_PERSISTENT_BIT or GL_MAP_COHERENT_BIT;
  var bufferSize = NUM_PARTICLES_PER_EMITTER * VERTICES_PER_PARTICLE * BUFFER_REPLICATION * sizeof(ParticleVertex)
  glNamedBufferStorage(result.bufferStore, bufferSize, cast[pointer](0), flags)
  var buffers: pointer = glMapNamedBufferRange(result.bufferStore, 0, bufferSize, flags)
  result.gpuBuffers = cast[ParticleBuffers](buffers)

  glBindVertexArray(0)

proc add(container: ParticleContainerRef, particle: Particle) =
  container.cpuBuffer[container.currentIndex] = particle
  container.currentIndex = (container.currentIndex+1) mod NUM_PARTICLES_PER_EMITTER

proc emit(emitter: ParticleEmitter): ParticleEmitter =
  result = emitter
  result.lastEmission = getTime()
  var particle = initParticle()
  var ty = rand(1..3).float32
  var tz = rand(1..3).float32
  for i, v in enumerate(particle):
    var vertex = v
    vertex.position = vertex.position + [0'f32, ty+3, tz].Vec3 #+ result.translation
    vertex.life  = result.life
    vertex.scale = result.scale
    particle[i] = vertex
  result.container.add(particle)

proc update*(emitter: ParticleEmitter): ParticleEmitter =
  result = emitter
  var now: Time = getTime()
  if result.isEnabled and (now - result.lastEmission) > result.interval:
    result = result.emit()

proc update*(container: ParticleContainerRef) =
  for i in 0..<NUM_PARTICLES_PER_EMITTER:
    for j in 0..<VERTICES_PER_PARTICLE:
      container.cpuBuffer[i][j].life = max(container.cpuBuffer[i][j].life - 0.01, 0)

proc lock(container: ParticleContainerRef) =
  var maybeFence = container.fence[container.bufferInUse]
  if maybeFence.isSome():
    glDeleteSync(maybeFence.get())
  container.fence[container.bufferInUse] = glFenceSync(GL_SYNC_GPU_COMMANDS_COMPLETE, 0.GLbitfield).some()

proc wait(container: ParticleContainerRef) =
  if container.fence[container.bufferInUse].isSome():
    while true:
      var result = glClientWaitSync(container.fence[container.bufferInUse].get(), GL_SYNC_FLUSH_COMMANDS_BIT, 1)
      if result == GL_ALREADY_SIGNALED or result == GL_CONDITION_SATISFIED:
        return

proc draw*(container: ParticleContainerRef) =
  container.wait()

  var bufferStart: int = container.bufferInUse * NUM_PARTICLES_PER_EMITTER * VERTICES_PER_PARTICLE
  var gpuIndex: int = 0
  for i in 0..<NUM_PARTICLES_PER_EMITTER:
    if container.cpuBuffer[i][0].life > 0:
      for j in 0..<VERTICES_PER_PARTICLE:
        container.gpuBuffers[gpuIndex*VERTICES_PER_PARTICLE + j + bufferStart] = container.cpuBuffer[i][j]
      gpuIndex += 1

  glEnableVertexAttribArray(0)
  glBindVertexArray(container.vertexLayout)
  glBindBuffer(GL_ARRAY_BUFFER, container.bufferStore)
  glDrawArrays(GL_TRIANGLES, bufferStart.GLint, (gpuIndex * VERTICES_PER_PARTICLE).GLsizei)

  container.lock()

  container.bufferInUse = (container.bufferInUse + 1) mod BUFFER_REPLICATION
  glBindVertexArray(0)
