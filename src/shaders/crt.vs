#version 330

in vec3 vertexPosition;
in vec2 vertexTexCoord;

out vec2 uv;

uniform mat4 mvp;

void main()
{
    gl_Position = mvp * vec4(vertexPosition, 1.0);
    uv = vertexTexCoord;
}