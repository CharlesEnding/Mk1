import std/random

import ../utils/blas
import ../primitives/particles

proc initDirt*(emitter: ParticleEmitter): Particle =
  # Choose one texture out of 4 on billboard, arranged in a square
  var offsetX = rand(0..1).float32 * 0.5
  var offsetY = rand(0..1).float32 * 0.5
  var offset: Vec2 = [offsetX.float32, offsetY.float32].Vec2
  var UVsize: Vec2 = [0.5'f32, 0.5'f32].Vec2

  # Create particle vertex
  Particle(position: emitter.translation, texCoord: offset, texSize: UVsize, life: emitter.life, scale: emitter.scale)

proc updateDirt*(emitter: ParticleEmitter, vertex: Particle): Particle =
  result = vertex
  result.life = max(vertex.life - 0.1, 0)
  var percent = result.life / emitter.life
  result.scale = emitter.scale * (2 - percent) # Goes from x1 to x2
