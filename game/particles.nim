import std/random

import ../utils/blas
import ../primitives/particles

proc initDirt*(emitter: ParticleEmitter): Particle =
  # Choose one texture out of 4 on billboard, arranged in a square
  var offsetX = rand(0..1)
  var offsetY = rand(0..1)
  var offset: Vec2 = [offsetX.float32, offsetY.float32].Vec2
  # Create particle mesh
  [
    ParticleVertex(position: [-0.5'f32,  0.5, 0], translation: emitter.translation, texCoord: ([0.0'f32, 0.0] + offset) * 0.5, life: emitter.life, scale: emitter.scale),
    ParticleVertex(position: [ 0.5'f32,  0.5, 0], translation: emitter.translation, texCoord: ([1.0'f32, 0.0] + offset) * 0.5, life: emitter.life, scale: emitter.scale),
    ParticleVertex(position: [-0.5'f32, -0.5, 0], translation: emitter.translation, texCoord: ([0.0'f32, 1.0] + offset) * 0.5, life: emitter.life, scale: emitter.scale),
    ParticleVertex(position: [-0.5'f32, -0.5, 0], translation: emitter.translation, texCoord: ([0.0'f32, 1.0] + offset) * 0.5, life: emitter.life, scale: emitter.scale),
    ParticleVertex(position: [ 0.5'f32,  0.5, 0], translation: emitter.translation, texCoord: ([1.0'f32, 0.0] + offset) * 0.5, life: emitter.life, scale: emitter.scale),
    ParticleVertex(position: [ 0.5'f32, -0.5, 0], translation: emitter.translation, texCoord: ([1.0'f32, 1.0] + offset) * 0.5, life: emitter.life, scale: emitter.scale)
  ]

proc updateDirt*(emitter: ParticleEmitter, vertex: ParticleVertex, index: int): ParticleVertex =
  result = vertex
  result.life = max(vertex.life - 0.1, 0)
  var percent = result.life / emitter.life
  result.scale = emitter.scale * (2 - percent) # Goes from x1 to x2
