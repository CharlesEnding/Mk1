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
out vec4 jointColor;

void main()
{
  mat4 skinMatrix = in_Weights.x * jointTransforms[int(in_JointIds.x)] +
                    in_Weights.y * jointTransforms[int(in_JointIds.y)] +
                    in_Weights.z * jointTransforms[int(in_JointIds.z)] +
                    in_Weights.w * jointTransforms[int(in_JointIds.w)];

  jointColor = in_JointIds / 22.0;// * jointTransforms[0][1];;// / 2000.0; //skinMatrix[3];
  gl_Position = projMatrix * viewMatrix * modelMatrix * skinMatrix * vec4(in_Position, 1.0);
  UV = vec2(in_UV.x, -in_UV.y);; //vec2(in_Position.x, in_Position.y);
  position = in_Position;
  normal = in_Normal;
  positionLightSpace = lightMatrix * vec4(in_Position, 1.0);
  V_EyeSpacePos= viewMatrix * modelMatrix * vec4(in_Position, 1.0);
}
