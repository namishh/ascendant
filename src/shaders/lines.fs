#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

// Output fragment color
out vec4 finalColor;

// Uniform inputs
uniform vec4 colOne = vec4(0.058, 0.015, 0.027, 0.8);    // First color (default: red)
uniform vec4 colTwo = vec4(0.015, 0.058, 0.043, 0.8);    // Second color (default: blue)
uniform float time;                                 // Time in seconds

void main()
{
    float angle = radians(55.0);
    vec2 scaledCoord = fragTexCoord * 25000.0;
    scaledCoord.y += time * 1.0;
    float rotatedCoord = scaledCoord.x * cos(angle) - scaledCoord.y * sin(angle);
    float pattern = mod(rotatedCoord, 2.0);
    finalColor = pattern < 1.0 ? colOne : colTwo;
}