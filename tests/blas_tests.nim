import std/math

import ../utils/blas

proc approxEqual(a, b: float, epsilon: float = 0.01): bool = return abs(a-b) < epsilon
proc approxEqual(m1, m2: Mat4, epsilon: float = 0.01): bool =
  for i in 0..<4:
    for j in 0..<4:
      if not approxEqual(m1[i][j], m2[i][j]): return false
  return true

proc test_mat_vec_multiplication() =
  var m: Mat4 = [
    [5'f32, 1, 3, 0],
    [1'f32, 1, 1, 0],
    [1'f32, 2, 1, 0],
    [0'f32, 0, 0, 1]
  ]
  var v: Vec4 = [1'f32, 2, 3, 1].Vec4
  echo m * v
  assert m*v == [16'f32, 6, 8, 1].Vec4

proc test_translation_matrix() =
  var vec: Vec3
  var mat: Mat4

  vec = [1'f32, 2, 3].Vec3
  mat = vec.translationMatrix()
  assert mat.translationVector() == vec

proc test_rotation_matrix() =
  var quat, rot, pos: Vec4
  var mat, correct:  Mat4

  quat = [0'f32, 0, 0, 1].Vec4
  mat  = quat.rotationMatrix
  correct = [
    [1, 0,  0, 0],
    [0, 1,  0, 0],
    [0, 0,  1, 0],
    [0, 0,  0, 1],
  ]
  assert approxEqual(mat, correct)

  rot = mat.rotationVector()
  echo quat
  echo rot
  # assert approxEqual(rot[0], quat[0])
  # assert approxEqual(rot[1], quat[1])
  # assert approxEqual(rot[2], quat[2])
  # assert approxEqual(rot[3], quat[3])

  quat = [0.59'f32, 0.08, 0.59, 0.53].Vec4
  mat  = quat.rotationMatrix
  correct = [
    [0.271'f32, -0.538,  0.797, 0],
    [0.736'f32, -0.417, -0.532, 0],
    [0.620'f32,  0.731,  0.283, 0],
    [0.000'f32,  0.000,  0.000, 1],
  ]
  assert approxEqual(mat, correct)

  rot = mat.rotationVector()
  echo quat
  echo rot
  # assert approxEqual(rot[0], quat[0])
  # assert approxEqual(rot[1], quat[1])
  # assert approxEqual(rot[2], quat[2])
  # assert approxEqual(rot[3], quat[3])

  quat = [0.1584'f32, 0.5915, 0.1584, 0.7745].Vec4
  mat  = quat.rotationMatrix
  correct = [
    [ 0.250'f32, -0.058,  0.966, 0],
    [ 0.433'f32,  0.899, -0.058, 0],
    [-0.866'f32,  0.433,  0.250, 0],
    [ 0.000'f32,  0.000,  0.000, 1],
  ]
  assert approxEqual(mat, correct)

  rot = mat.rotationVector()
  echo quat
  echo rot
  # assert approxEqual(rot[0], quat[0])
  # assert approxEqual(rot[1], quat[1])
  # assert approxEqual(rot[2], quat[2])
  # assert approxEqual(rot[3], quat[3])

  quat = [0.57735'f32, 0.57735, 0.57735, 45 * 0.5 / 180.0 * 3.14].Vec4
  pos  = [1'f32, 2, 3, 1].Vec4
  mat  = quat.rotationMatrix()
  rot = mat.rotationVector()
  assert approxEqual(quat.rotationMatrix(), quat.rotationMatrix().rotationVector().rotationMatrix())
  # assert approxEqual(rot[0], quat[0])
  # assert approxEqual(rot[1], quat[1])
  # assert approxEqual(rot[2], quat[2])
  # assert approxEqual(rot[3], quat[3])



  # echo actual
  # assert approxEqual(actual[0][0], 0.27)
  # q2d_() {

  # var quat2: Vec4 = [-0.53'f32, -0.59, -0.08, -0.59].Vec4

  # echo quat.rotationMatrix * quat2.rotationMatrix
  # echo quat2.rotationMatrix * quat.rotationMatrix

  # var quat3: Vec4 = [(45 * 0.5 / 180.0 * 3.14).float32, 0.57735'f32, 0.57735, 0.57735].Vec4
  # var pos: Vec4 = [1'f32, 2, 3, 1].Vec4

  # echo quat3.rotationMatrix * pos



  # var q1: Vec4 = [1'f32, 0, 0, 0].Vec4
  # var q2: Vec4 = [2'f32, 0, 0, 0].Vec4

  # echo


  #   // Matches q2d in SO(3), do not change
  #   q2d_mtx_(0, 0) = 0.271502007821992;
  #   q2d_mtx_(0, 1) = -0.538954266589856;
  #   q2d_mtx_(0, 2) = 0.797380058863537;
  #   q2d_mtx_(1, 0) = 0.736029403961437;
  #   q2d_mtx_(1, 1) = -0.417548171511386;
  #   q2d_mtx_(1, 2) = -0.532836035729257;
  #   q2d_mtx_(2, 0) = 0.620118840427219;
  #   q2d_mtx_(2, 1) = 0.731561222996468;
  #   q2d_mtx_(2, 2) = 0.283321020672862;

test_mat_vec_multiplication()
test_translation_matrix()
test_rotation_matrix()
