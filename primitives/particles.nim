import std/[enumerate, options, random, times]

import opengl

import ../utils/[blas, bogls]
import texture

const NUM_PARTICLES_PER_EMITTER = 200
const BUFFER_REPLICATION = 3

type
  Particle* {.packed.} = object
    position*: Vec3
    texCoord*, texSize*: Vec2
    color*: Vec3
    life*, scale*: float32

  ParticleBuffers = ptr array[NUM_PARTICLES_PER_EMITTER*BUFFER_REPLICATION, Particle]

  ParticleContainer* = object
    particleMesh, vertexLayout, bufferStore: GpuId
    texture*: TextureOnGpu
    gpuBuffers: ParticleBuffers
    cpuBuffer:  array[NUM_PARTICLES_PER_EMITTER, Particle]
    currentIndex, bufferInUse: int
    fence: array[BUFFER_REPLICATION, Option[GLSync]]

  ParticleContainerRef* = ref ParticleContainer

  InitParticle   = proc (emitter: ParticleEmitter): Particle
  UpdateParticle = proc (emitter: ParticleEmitter, vertex: Particle): Particle

  ParticleEmitter* = object
    translation*: Vec3
    life*, scale*: float32
    interval*: Duration = initDuration(seconds=10)
    lastEmission: Time
    isEnabled*: bool
    container*: ParticleContainerRef
    initParticle*: InitParticle
    updateParticle*: UpdateParticle

proc initParticleContainer*(texture: Texture): ParticleContainerRef =
  result = new ParticleContainer
  result.texture = texture.toGpuCached()

  # Create layout for shader
  glCreateVertexArrays(1, result.vertexLayout.addr)
  glBindVertexArray(result.vertexLayout)

  # Create permanent storage for the particle info that changes every frame
  glCreateBuffers(1, result.bufferStore.addr)
  discard setupArrayLayout(Particle(), result.bufferStore)
  var flags = GL_MAP_WRITE_BIT or GL_MAP_PERSISTENT_BIT or GL_MAP_COHERENT_BIT;
  var bufferSize = NUM_PARTICLES_PER_EMITTER * BUFFER_REPLICATION * sizeof(Particle)
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
  var particle = emitter.initParticle(emitter)
  result.container.add(particle)

proc update*(emitter: ParticleEmitter): ParticleEmitter =
  result = emitter
  var now: Time = getTime()
  if result.isEnabled and (now - result.lastEmission) > result.interval:
    result = result.emit()

proc update*(container: ParticleContainerRef, emitter: ParticleEmitter) =
  for i in 0..<NUM_PARTICLES_PER_EMITTER:
    if container.cpuBuffer[i].life > 0:
      container.cpuBuffer[i] = emitter.updateParticle(emitter, container.cpuBuffer[i])

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

  var bufferStart: int = container.bufferInUse * NUM_PARTICLES_PER_EMITTER
  var gpuIndex: int = 0
  for i in 0..<NUM_PARTICLES_PER_EMITTER:
    if container.cpuBuffer[i].life > 0:
      container.gpuBuffers[bufferStart + gpuIndex] = container.cpuBuffer[i]
      gpuIndex += 1

  glEnableVertexAttribArray(0)
  glBindVertexArray(container.vertexLayout)
  glBindBuffer(GL_ARRAY_BUFFER, container.bufferStore)
  glDrawArrays(GL_POINTS, bufferStart.GLint, gpuIndex.GLsizei)

  container.lock()

  container.bufferInUse = (container.bufferInUse + 1) mod BUFFER_REPLICATION
  glBindVertexArray(0)
