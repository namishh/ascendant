#version 330

// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;

// Output fragment color
out vec4 finalColor;

// Uniform inputs
uniform vec2 resolution;     // Toast dimensions
uniform float opacity;       // Toast opacity
uniform vec2 position;       // Toast position on screen
uniform vec4 color1;        // First checkerboard color
uniform vec4 color2;        // Second checkerboard color
uniform float scale;        // Size of checkerboard squares

void main()
{
    // Convert from screen coordinates to local toast coordinates
    vec2 uv = (gl_FragCoord.xy - position) / scale;
    
    // Create checkerboard pattern
    float pattern = mod(floor(uv.x) + floor(uv.y), 2.0);
    
    // Mix between the two colors based on pattern
    vec4 color = mix(color1, color2, pattern);
    
    // Apply opacity
    color.a *= opacity;
    
    finalColor = color;
}