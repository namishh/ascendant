#version 330
uniform float time;           // Time uniform
uniform vec2 resolution;      // Screen resolution
out vec4 fragColor;

void main() {
    // Create offset center point
    vec2 center = vec2(0.3, 0.3);
    
    vec2 uv = (gl_FragCoord.xy / resolution.xy) * 2.0 - 1.0;
    uv.x *= resolution.x / resolution.y;
    
    vec2 offsetUV = uv - center;
    float radius = length(offsetUV);
    float angle = atan(offsetUV.y, offsetUV.x);
    
    // Create multiple swirl patterns for layering
    float swirl1 = sin(radius * 5.0 - time * 2.0);
    float swirl2 = cos(radius * 4.0 - time * 1.5);
    
    // Define base colors
    vec3 color1 = vec3(1.0, 0.0, 0.0); // Red
    vec3 color2 = vec3(0.0, 0.0, 1.0); // Blue
    vec3 color3 = vec3(0.0, 1.0, 0.0); // Green
    
    // Create color mixing based on multiple angles and swirls
    float colorMix1 = sin(angle * 4.0 + swirl1 + time) * 0.5 + 0.5;
    float colorMix2 = cos(angle * 3.0 + swirl2 + time * 0.7) * 0.5 + 0.5;
    
    // Create striping effect
    float stripes = sin(radius * 20.0 + swirl1 * 2.0) * 0.5 + 0.5;
    stripes *= sin(angle * 8.0) * 0.5 + 0.5;
    
    // Mix colors with intermediate steps for better blending
    vec3 mixColor1 = mix(color1, color2, colorMix1); // Red to Blue = Purple
    vec3 mixColor2 = mix(mixColor1, color3, colorMix2); // Mix with Green
    
    // Add black stripes
    float stripeMask = smoothstep(0.4, 0.6, stripes);
    mixColor2 *= stripeMask;
    
    // Additional color variation
    float colorVar = sin(radius * 10.0 + time) * 0.5 + 0.5;
    mixColor2 = mix(mixColor2, mixColor2 * 0.5, colorVar);
    
    // Add black edges
    float edgeFade = smoothstep(0.0, 2.5, radius);
    mixColor2 = mix(mixColor2, vec3(0.0), edgeFade * 0.8);
    
    fragColor = vec4(mixColor2, 1.0);
}