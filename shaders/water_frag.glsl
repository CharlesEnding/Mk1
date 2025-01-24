#version 330 core

layout(location = 0) out vec4 fragmentColor;

in vec2 UV;
in float out_time;
in vec4 V_EyeSpacePos;

uniform sampler2D albedo;

vec3 distort(vec2 uvs, float time, float phaseOffset) {
  float progress = fract(time/10.0 + phaseOffset);
  vec2 distortedUVs = uvs - progress * 0.05; //vec2(flowSample.r * time + uvs.r, flowSample.g * time + uvs.g);
  float blendWeight = 1 - abs(1 - 2 * progress);
  return vec3(distortedUVs.x, distortedUVs.y, blendWeight);
}

float CalculateLinearFog(float distance)
{
  float U_FogStart = 100;
  float U_FogEnd = 400;
  float fogAlpha=(distance-U_FogStart)/(U_FogEnd-U_FogStart);
   //clamp cross-border processing to obtain the value in the middle of the three parameters
  fogAlpha=1.0-clamp(fogAlpha,0.0,1.0);
  return fogAlpha;
}



void main()
{
  vec3 flowStep1 = distort(UV, out_time, 0);
  vec3 flowStep2 = distort(UV, out_time, 0.5);

  vec4 texSample1 = texture(albedo, flowStep1.rg) * flowStep1.z;
  vec4 texSample2 = texture(albedo, flowStep2.rg) * flowStep2.z;

  // fragmentColor = texSample1 + texSample2;
  //fragmentColor = texSample1;
  //float blendWeight = 1 - abs(1 - 2 * fract(timeOut));
  //fragmentColor = mix(texSample2, texSample1, blendWeight);
  //fragmentColor = vec4(flow.r, flow.g, 0.0, 1.0);
  //fragmentColor = texSample1;

  vec4 sample1 = 0.25*texture(albedo, vec2(UV.x, UV.y + out_time*0.2));
  vec4 sample2 = 0.25*texture(albedo, vec2(UV.x - out_time*0.1, UV.y));


  float U_FogStart = 25;
  float U_FogEnd = 120;
  float fogAlpha=(abs(V_EyeSpacePos.z / V_EyeSpacePos.w)-U_FogStart)/(U_FogEnd-U_FogStart);
   //clamp cross-border processing to obtain the value in the middle of the three parameters
  fogAlpha=1.0-clamp(fogAlpha,0.0,0.8);
  vec4 U_FogColor = vec4(0.40, 0.25, 0.10, 1.0);
  vec4 linearColor = mix(U_FogColor, sample1+sample2, fogAlpha);


  fragmentColor = linearColor;
  //fragmentColor = vec4(UV.x, UV.y, 0.0, 1.0);
  //fragmentColor = mix(gLowColour, gHighColour, height);
}
