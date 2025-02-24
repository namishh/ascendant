#version 330
// Input vertex attributes (from vertex shader)
in vec2 fragTexCoord;
in vec4 fragColor;
// Output fragment color
out vec4 finalColor;
// Uniform inputs
uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float iTime;
uniform vec2 iResolution;
uniform vec4 iMouse;

// Simplex noise implementation
vec3 mod289(vec3 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}
vec2 mod289(vec2 x) {
  return x - floor(x * (1.0 / 289.0)) * 289.0;
}
vec3 permute(vec3 x) {
  return mod289(((x*34.0)+1.0)*x);
}
float snoise(vec2 v) {
  const vec4 C = vec4(0.211324865405187,  // (3.0-sqrt(3.0))/6.0
                      0.366025403784439,  // 0.5*(sqrt(3.0)-1.0)
                     -0.577350269189626,  // -1.0 + 2.0 * C.x
                      0.024390243902439); // 1.0 / 41.0
  // First corner
  vec2 i  = floor(v + dot(v, C.yy) );
  vec2 x0 = v -   i + dot(i, C.xx);
  // Other corners
  vec2 i1;
  i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;
  // Permutations
  i = mod289(i); // Avoid truncation effects in permutation
  vec3 p = permute( permute( i.y + vec3(0.0, i1.y, 1.0 ))
        + i.x + vec3(0.0, i1.x, 1.0 ));
  vec3 m = max(0.5 - vec3(dot(x0,x0), dot(x12.xy,x12.xy), dot(x12.zw,x12.zw)), 0.0);
  m = m*m;
  m = m*m;
  // Gradients: 41 points uniformly over a line, mapped onto a diamond.
  vec3 x = 2.0 * fract(p * C.www) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;
  // Normalize gradients implicitly by scaling m
  m *= 1.79284291400159 - 0.85373472095314 * ( a0*a0 + h*h );
  // Compute final noise value at P
  vec3 g;
  g.x  = a0.x  * x0.x  + h.x  * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
  return 130.0 * dot(m, g);
}

float rand(vec2 co) {
   return fract(sin(dot(co.xy,vec2(12.9898,78.233))) * 43758.5453);
}

void main() {
    vec2 uv = fragTexCoord.xy;
    vec2 fragCoord = uv * iResolution;
    float time = iTime * 2.0;
    float glitchIntensity = 0.5 + 0.5 * (iMouse.x / iResolution.x);
    
    // Create large, incidental noise waves
    float noise = max(0.0, snoise(vec2(time, uv.y * 0.3)) - 0.3) * (1.0 / 0.7);
    noise *= glitchIntensity;
    
    // Offset by smaller, constant noise waves
    noise = noise + (snoise(vec2(time*10.0, uv.y * 2.4)) - 0.5) * 0.15 * glitchIntensity;
    
    // Apply the noise as x displacement for every line
    float xpos = uv.x - noise * noise * 0.25;
    
    // Sample the texture with the glitch offset
    vec4 color = texture(texture0, vec2(xpos, uv.y));
    
    // Mix in some random interference for lines
    color.rgb = mix(color.rgb, vec3(rand(vec2(uv.y * time))), noise * 0.3 * glitchIntensity);
    
    // Apply a line pattern (scanlines)
    if (floor(mod(fragCoord.y * 0.25, 2.0)) == 0.0) {
        color.rgb *= 1.0 - (0.15 * noise);
    }
    
    // Shift green/blue channels (chromatic aberration)
    color.g = mix(color.r, texture(texture0, vec2(xpos + noise * 0.05, uv.y)).g, 0.25 * glitchIntensity);
    color.b = mix(color.r, texture(texture0, vec2(xpos - noise * 0.05, uv.y)).b, 0.25 * glitchIntensity);
    
    // Apply color diffuse from Raylib
    finalColor = color * colDiffuse;
}