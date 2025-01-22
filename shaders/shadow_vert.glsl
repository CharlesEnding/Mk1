#version 330 core

layout(location = 0) in vec3 in_Position;
layout(location = 1) in vec3 in_Normal;
layout(location = 2) in vec2 in_UV;

uniform float time;
uniform mat4 projMatrix;
uniform mat4 modelMatrix;
uniform mat4 lightMatrix;

void main()
{
    gl_Position = lightMatrix * vec4(in_Position, 1.0);
}
