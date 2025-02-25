#version 330 core

layout(location = 0) out vec4 fragmentColor;

in vec3 position;
in vec3 normal;
in vec2 UV;
in vec4 positionLightSpace;
in vec4 V_EyeSpacePos;
in vec4 jointColor;

uniform sampler2D albedo;
uniform sampler2D shadowMap;

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
  // vec3 lightPosition = vec3(70, 107, -60);
  // vec3 lightColor = vec3(0.88, 0.57, 0.31);
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
  // fragmentColor = vec4(linearColor, 1.0);
  // fragmentColor = vec4(diffuse, 1.0) * (1 - 0.0001 * shadow);
  // fragmentColor = vec4(attenuation*diffuse, 1.0);
  // fragmentColor = vec4(ambient, 1.0);
  // fragmentColor = surfaceColor;
  // fragmentColor = vec4(normal*2-1, 1.0);
  // fragmentColor = vec4((normal+1)/2.0, 1.0);
  // fragmentColor = vec4(normal, 1.0);
  // fragmentColor = vec4(position, 1.0);


  // vec3 projCoords = positionLightSpace.xyz / positionLightSpace.w;
  // projCoords = projCoords * 0.5 + 0.5;
  // fragmentColor = texture(shadowMap, projCoords.xy);
  // fragmentColor = vec4(shadow, shadow, shadow, 1.0);
  // fragmentColor = vec4(projCoords, 1.0);

  // Slope
  // float color = abs(normal.y) > 0.5 ? 1.0 : 0.0;
  // fragmentColor = vec4(1.0, color, 0.0, 1.0) * (1 - 0.0001 * shadow);
  float U_FogStart = 25;
  float U_FogEnd = 120;
  float fogAlpha=(abs(V_EyeSpacePos.z / V_EyeSpacePos.w)-U_FogStart)/(U_FogEnd-U_FogStart);
   //clamp cross-border processing to obtain the value in the middle of the three parameters
  fogAlpha=1.0-clamp(fogAlpha,0.0,0.8);
  vec3 U_FogColor = vec3(0.40, 0.25, 0.10);
  linearColor = mix(U_FogColor, linearColor, fogAlpha);


  // final color (after gamma correction)
  vec3 gamma = vec3(1.0/1.05);
  fragmentColor = vec4(pow(linearColor, gamma), surfaceColor.a);// * 0.01 + vec4(jointColor.x, 0, 0, 1.0) ;
}

