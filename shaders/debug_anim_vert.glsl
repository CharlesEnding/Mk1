#version 330 core

layout(location = 0) in vec3  in_Position;
layout(location = 1) in vec3  in_Normal;
layout(location = 2) in vec2  in_UV;
layout(location = 3) in vec4  in_JointIds;
layout(location = 4) in vec4  in_Weights;

uniform float time;
uniform mat4 projMatrix;
uniform mat4 viewMatrix;
uniform mat4 modelMatrix;
uniform mat4 lightMatrix;

const int MAX_JOINTS = 100;
uniform mat4 jointTransforms[MAX_JOINTS];

out vec3 position;
out vec3 normal;
out vec2 UV;
out vec4 positionLightSpace;
out vec4 V_EyeSpacePos;
out float mostInfluentialJoint;
out vec4 jointWeights;

void main()
{
  mat4 skinMatrix = in_Weights.x * jointTransforms[int(in_JointIds.x)] +
                    in_Weights.y * jointTransforms[int(in_JointIds.y)] +
                    in_Weights.z * jointTransforms[int(in_JointIds.z)] +
                    in_Weights.w * jointTransforms[int(in_JointIds.w)];

  // Find the most influential joint (highest weight)
  mostInfluentialJoint = in_JointIds.x;
  float maxWeight = in_Weights.x;
  if (in_Weights.y > maxWeight) {
    mostInfluentialJoint = in_JointIds.y;
    maxWeight = in_Weights.y;
  }
  if (in_Weights.z > maxWeight) {
    mostInfluentialJoint = in_JointIds.z;
    maxWeight = in_Weights.z;
  }
  if (in_Weights.w > maxWeight) {
    mostInfluentialJoint = in_JointIds.w;
    maxWeight = in_Weights.w;
  }

  jointWeights = in_Weights;
  
  gl_Position = projMatrix * viewMatrix * modelMatrix * skinMatrix * vec4(in_Position, 1.0);
  UV = vec2(in_UV.x, -in_UV.y);
  position = (modelMatrix * vec4(in_Position, 1.0)).xyz;
  normal = normalize((modelMatrix * skinMatrix * vec4(in_Normal, 0.0)).xyz);
  positionLightSpace = lightMatrix * modelMatrix * skinMatrix * vec4(in_Position, 1.0);
  V_EyeSpacePos = viewMatrix * modelMatrix * vec4(in_Position, 1.0);
}
