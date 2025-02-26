#version 330
uniform sampler2D iChannel0;
uniform float time;
uniform float scanSpeed = 0.35; // Default value that can be modified
in vec2 uv;
#define PI 3.14159265358979323846

vec2 deformUv(vec2 uv) 
{
    // Removed curvature deformation, now just returns the original UV
    return uv;
}

float edgeIntensity(vec2 uv)
{
    // Softer edge darkening
    vec2 edge = smoothstep(0.0, 0.15, uv) * smoothstep(1.0, 0.85, uv);
    return edge.x * edge.y * 0.6 + 0.4;  // Reduced contrast
}

float random(vec2 st) {
    return fract(sin(dot(st.xy, vec2(12.9898,78.233))) * 43758.5453123);
}

float scanLines(vec2 uv, float time)
{
    // More transparent scanning lines
    float lineCount = 620.0;
    float speed = scanSpeed; // Use the tweakable uniform
    float intensity = 0.22;  // Reduced intensity
    
    float phase = (uv.y * lineCount - time * speed);
    float lines = smoothstep(0.48, 0.52, sin(phase * PI) * 0.5 + 0.5);
    
    // Increased transparency
    float transparency = mix(0.9, 1.1, sin(time * 0.3) * 0.5 + 0.2);
    return mix(1.0, 1.0 - intensity * transparency, lines);
}

void main()
{
    // Fixed inversion by using proper UV orientation
    vec2 correctedUv = vec2(uv.x, 1.0 - uv.y);  // Flip vertical coordinate
    
    vec2 deformedUv = deformUv(correctedUv);
    
    // RGB separation with corrected UVs
    float chromaOffset = 0.0015;
    vec3 color;
    color.r = texture(iChannel0, vec2(deformedUv.x - chromaOffset, deformedUv.y)).r;
    color.g = texture(iChannel0, deformedUv).g;
    color.b = texture(iChannel0, vec2(deformedUv.x + chromaOffset, deformedUv.y)).b;
    
    // Apply effects
    color *= edgeIntensity(correctedUv);
    color *= scanLines(deformedUv, time);
    
    // Removed the curvature effect entirely
    
    // Final output
    gl_FragColor = vec4(pow(color, vec3(1.08)), 1.0);
}