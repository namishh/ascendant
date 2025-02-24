#version 330

in vec2 fragTexCoord;
in vec4 fragColor;

// Output fragment color
out vec4 finalColor;

// Uniform inputs
uniform vec4 colOne = vec4(0.047, 0.129, 0.098, 0.95);    // First color (default: red)
uniform vec4 colTwo = vec4(0.149, 0.050, 0.092, 0.95);    // Second color (default: blue)
uniform float time;                                 // Time in seconds

void main()
{
    float angle = radians(45.0);
    vec2 scaledCoord = fragTexCoord * 2050.0;
    scaledCoord.y += time * 1.0;
    float rotatedCoord = scaledCoord.x * cos(angle) - scaledCoord.y * sin(angle);
    float pattern = mod(rotatedCoord, 2.0);
    finalColor = pattern < 1.0 ? colOne : colTwo;
}