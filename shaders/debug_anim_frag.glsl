#version 330 core

layout(location = 0) out vec4 fragmentColor;

in vec3 position;
in vec3 normal;
in vec2 UV;
in vec4 positionLightSpace;
in vec4 V_EyeSpacePos;
in float mostInfluentialJoint;
in vec4 jointWeights;

uniform sampler2D albedo;
uniform sampler2D shadowMap;
uniform int highlightJointId;
uniform int maxJointCount;

vec3 hsv2rgb(vec3 c) {
  vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
  vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
  return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec3 getJointColor(float jointId, int maxJoints) {
  float hue = fract(jointId * 0.61803398875);
  float val = 0.5 + 0.5 * fract(jointId / float(maxJoints));
  return hsv2rgb(vec3(hue, 1.0, val));
}

float ShadowCalculation(vec4 posLightSpace)
{
    // perform perspective divide
    vec3 projCoords = posLightSpace.xyz / posLightSpace.w;
    // transform to [0,1] range
    projCoords = projCoords * 0.5 + 0.5;
    // get closest depth value from light's perspective (using [0,1] range fragPosLight as coords)
    float closestDepth = texture(shadowMap, projCoords.xy).r;
    // get depth of current fragment from light's perspective
    float currentDepth = projCoords.z;
    // check whether current frag pos is in shadow
    float shadow = currentDepth > closestDepth  ? 1.0 : 0.0;

    return shadow;
}

void main()
{
  float ambientCoefficient = 0.2;

  vec3 lightPosition = vec3(90, 70, -110);
  vec3 lightColor = vec3(0.98, 0.77, 0.51);
  float lightAttenuation = 0.03;

  vec4 surfaceColor = texture(albedo, UV);
  vec3 surfaceToLight = normalize(lightPosition - position);

  //ambient
  vec3 ambient = ambientCoefficient * surfaceColor.rgb * lightColor;

  //diffuse
  float diffuseCoefficient = max(0.0, dot(normal, surfaceToLight));
  vec3 diffuse = diffuseCoefficient * surfaceColor.rgb * lightColor;

  //attenuation
  float distanceToLight = length(lightPosition - position);
  float attenuation = 700.0 / (1.0 + lightAttenuation * pow(distanceToLight, 2));

  //shadows
  float shadow = ShadowCalculation(positionLightSpace);

  //linear color (color before gamma correction)
  vec3 linearColor = (ambient + (1.0 - shadow) * attenuation*diffuse);

  // Debug visualization
  vec3 debugColor;
  int jointId = int(mostInfluentialJoint);
  
  // Check if this is the highlighted joint
  if (jointId == highlightJointId) {
    debugColor = vec3(0.0, 1.0, 0.0);  // Bright green for highlighted joint
  } else {
    debugColor = getJointColor(mostInfluentialJoint, maxJointCount);
  }

  // Mix debug color with lighting (keep some lighting for depth perception)
  linearColor = mix(linearColor * 0.3, debugColor, 0.85);

  // Fog
  float U_FogStart = 25;
  float U_FogEnd = 120;
  float fogAlpha=(abs(V_EyeSpacePos.z / V_EyeSpacePos.w)-U_FogStart)/(U_FogEnd-U_FogStart);
  fogAlpha=1.0-clamp(fogAlpha,0.0,0.8);
  vec3 U_FogColor = vec3(0.40, 0.25, 0.10);
  linearColor = mix(U_FogColor, linearColor, fogAlpha);

  // final color (after gamma correction)
  vec3 gamma = vec3(1.0/1.05);
  fragmentColor = vec4(pow(linearColor, gamma), surfaceColor.a);
}
