import std/[options, paths, times]

import ../utils/blas
import ../primitives/renderable

import movement

type
  Character* = object
    name*: string
    spatial*:    Option[SpatialBehaviour]
    movement*:   Option[MovementBehaviour]
    following*:  Option[FollowingBehaviour]
    grounded*:   Option[GroundedBehaviour]
    renderable*: Option[RenderableBehaviourRef]

proc createNpc*(): Character =
  var route1: Route = @[
    RoutePoint(position: [  0.0'f32, 0.0,  40.0], idling: initDuration(seconds=0)),
    RoutePoint(position: [  3.5'f32, 0.0,  -3.9], idling: initDuration(seconds=0)),
    RoutePoint(position: [ 22.0'f32, 0.0,  -3.9], idling: initDuration(seconds=0)),
    RoutePoint(position: [ 24.0'f32, 0.0,  -0.9], idling: initDuration(seconds=5)),
    RoutePoint(position: [ 20.5'f32, 0.0,  -3.7], idling: initDuration(seconds=0)),
    RoutePoint(position: [  1.0'f32, 0.0,  -3.7], idling: initDuration(seconds=0)),
    RoutePoint(position: [  3.5'f32, 0.0, -75.2], idling: initDuration(seconds=0)),
    RoutePoint(position: [ -1.9'f32, 0.0, -75.2], idling: initDuration(seconds=0)),
    RoutePoint(position: [ -1.9'f32, 0.0, -41.7], idling: initDuration(seconds=0)),
    RoutePoint(position: [-22.5'f32, 0.0, -42.9], idling: initDuration(seconds=5)),
    RoutePoint(position: [ -2.5'f32, 0.0, -40.8], idling: initDuration(seconds=0)),
    RoutePoint(position: [ -3.3'f32, 0.0,  -4.3], idling: initDuration(seconds=0)),
    RoutePoint(position: [ -1.7'f32, 0.0,  40.9], idling: initDuration(seconds=0))
  ]
  result.name = "NPC"
  result.spatial = SpatialBehaviour(size: [0.01'f32, 0.01, 0.01].Vec3).some()
  result.movement = MovementBehaviour(baseSpeed: 0.05).some()
  result.grounded = GroundedBehaviour(height: 1.6).some()
  result.following = FollowingBehaviour(route: route1).some()
  result.renderable = load("assets/Fox.glb".Path, animated=true).some()

proc createPlayer*(): Character =
  result.name = "Player"
  result.spatial = SpatialBehaviour(size: [0.01'f32, 0.01, 0.01].Vec3).some()
  result.movement = MovementBehaviour(baseSpeed: 0.5).some()
  result.grounded = GroundedBehaviour(height: 1.6).some()
  result.renderable = load("assets/Fox.glb".Path, animated=true).some()

proc update*(character: Character): Character =
  result = character
  if result.spatial.isSome() and result.movement.isSome():
    if result.following.isSome():
      result.following = follow(result.following.get(), result.spatial.get()).some()
      result.movement  = updateSpeed(result.movement.get(), result.spatial.get(), result.following.get()).some()
    result.spatial = move(result.spatial.get(), result.movement.get()).some()

    if result.renderable.isSome():
      let s = result.spatial.get()
      result.renderable = result.renderable.get().updateTransform(s.position, s.orientation, s.size).some()

      if result.movement.get().speed.length < 0.02:
        result.renderable = result.renderable.get().updateAnimation(newState=0).some()
      else:
        result.renderable = result.renderable.get().updateAnimation(newState=2).some()
