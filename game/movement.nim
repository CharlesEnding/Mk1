import std/[options, times]

import ../utils/blas
import ../physics/collision

type
  SpatialBehaviour* = object
    position*, orientation*, size*: Vec3

  MovementBehaviour* = object
    baseSpeed*: float
    speed: Vec3 # Speed can be different from orientation (running backwards)

  RoutePoint* = object
    position*: Vec3
    idling*: Duration

  RoutePointIndex = int

  Route* = seq[RoutePoint]

  FollowingBehaviour* = object
    route*:   Route
    target:  RoutePointIndex
    arrival: Option[Time]

  CollisionBehaviour = object
    radius: float

  GroundedBehaviour* = object
    height*, heightOffTheFloor*: float

proc approxEqual(p1, p2: Vec3, epsilon: float = 0.1): bool = length([(p1-p2).x, (p1-p2).z]) < epsilon

proc idlingAtTarget(following: FollowingBehaviour):  bool = following.arrival.isSome()
proc idledLongEnough(following: FollowingBehaviour, arrival: Time): bool = (getTime() - arrival) >= following.route[following.target].idling

proc follow*(following: FollowingBehaviour, spatial: SpatialBehaviour): FollowingBehaviour =
  result = following
  if spatial.position.approxEqual(result.route[result.target].position):
    if not result.idlingAtTarget():
      result.arrival = getTime().some()

    if result.idledLongEnough(result.arrival.get):
      result.target  = (result.target + 1) mod (result.route.len - 1)
      result.arrival = none(Time)

proc updateSpeed*(movement: MovementBehaviour, direction: Vec3): MovementBehaviour =
  result = movement
  result.speed = direction.norm() * result.baseSpeed

proc updateSpeed*(movement: MovementBehaviour, spatial: SpatialBehaviour, following: FollowingBehaviour): MovementBehaviour =
  result = movement
  var vector: Vec3 = (following.route[following.target].position - spatial.position)
  vector = [vector.x, 0.0, vector.z].norm()
  if following.idlingAtTarget():
    result.speed = vector * 0
  else:
    result.speed = vector * result.baseSpeed

proc move*(spatial: SpatialBehaviour, movement: MovementBehaviour): SpatialBehaviour =
  result = spatial
  result.position = result.position + movement.speed
  if movement.speed != [0'f32, 0, 0].Vec3:
    result.orientation = movement.speed.norm()

proc updateHeight*(spatial: SpatialBehaviour, grounded: GroundedBehaviour, bvh: Node): SpatialBehaviour =
  result = spatial
  result.position = bvh.getHeight(result.position) + [0'f32, grounded.heightOffTheFloor, 0].Vec3
