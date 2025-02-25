import ../utils/blas

type
  Player* = ref object
    position*, speed*, feet*: Vec3
    maxSpeed*: float = 35.0 / 100

proc move*(player: Player) = player.position = player.position + player.speed

proc newPlayer*(): Player =
  result = new Player
  result.position = [0'f32, 0, 0].Vec3
  result.speed    = [0'f32, 0, 0].Vec3
  result.feet     = [0'f32, 0, 0].Vec3
