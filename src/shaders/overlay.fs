#version 330

in vec2 fragTexCoord;
out vec4 fragColor;

uniform vec2 resolution;
uniform float opacity;
uniform vec2 position;
uniform vec4 color1; // Uniform color

void main() {
    fragColor = color1; // Use uniform color directly
}
