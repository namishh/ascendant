#version 330

// Raylib-provided uniforms
uniform vec2 resolution; // Screen resolution (like iResolution.xy)
uniform float time;      // Time in seconds (like iTime)

// Input from vertex shader (not used here, but required for completeness)
in vec2 fragTexCoord;
in vec4 fragColor;

// Output
out vec4 finalColor;

// Configuration constants
#define SPIN_ROTATION -2.0
#define SPIN_SPEED 2.0
#define OFFSET vec2(0.0)
#define COLOUR_1 vec4(0.788, 0.149, 0.290, 1.0)
#define COLOUR_2 vec4(0.250, 0.670, 0.509, 1.0)
#define COLOUR_3 vec4(0.1, 0.1, 0.1, 1.0)
#define CONTRAST 3.5
#define LIGTHING 0.4
#define SPIN_AMOUNT 0.25
#define PIXEL_FILTER 325.0
#define SPIN_EASE 1.0
#define PI 3.14159265359
#define IS_ROTATE false

// Core effect function
vec4 effect(vec2 screenSize, vec2 screen_coords) {
    float pixel_size = length(screenSize.xy) / PIXEL_FILTER;
    vec2 uv = (floor(screen_coords.xy * (1.0 / pixel_size)) * pixel_size - 0.5 * screenSize.xy) / length(screenSize.xy) - OFFSET;
    float uv_len = length(uv);
    
    float speed = (SPIN_ROTATION * SPIN_EASE * 0.2);
    if (IS_ROTATE) {
        speed = time * speed;
    }
    speed += 252.2;
    float new_pixel_angle = atan(uv.y, uv.x) + speed - SPIN_EASE * 10.0 * (1.0 * SPIN_AMOUNT * uv_len + (1.0 - 2.0 * SPIN_AMOUNT));
    vec2 mid = (screenSize.xy / length(screenSize.xy)) / 2.0;
    uv = vec2((uv_len * cos(new_pixel_angle) + mid.x), (uv_len * sin(new_pixel_angle) + mid.y)) - mid;
    
    uv *= 30.0;
    speed = time * SPIN_SPEED;
    vec2 uv2 = vec2(uv.x + uv.y);
    
    for (int i = 0; i < 5; i++) {
        uv2 += sin(max(uv.x, uv.y)) + uv;
        uv -= 0.5 * vec2(sin(5.1123314 + 0.353 * uv2.y + speed * 0.131121), sin(uv2.x - 0.113 * speed));
        uv += 1.0 * cos(uv.x + uv.y) - 1.0 * sin(uv.x * 0.711 - uv.y);
    }
    
    float contrast_mod = (0.25 * CONTRAST + 0.5 * SPIN_AMOUNT + 1.2);
    float paint_res = min(2.0, max(0.0, length(uv) * (0.035) * contrast_mod));
    float c1p = max(0.0, 1.0 - contrast_mod * abs(1.0 - paint_res));
    float c2p = max(0.0, 1.0 - contrast_mod * abs(paint_res));
    float c3p = 1.0 - min(1.0, c1p + c2p) + 0.5;
    float light = (LIGTHING - 0.2) * max(c1p * 5.0 - 4.0, 0.0) + LIGTHING * max(c2p * 5.0 - 4.0, 0.0);
    
    return (0.3 / CONTRAST) * COLOUR_1 + (1.0 - 0.3 / CONTRAST) * (COLOUR_1 * c1p + COLOUR_2 * c2p + vec4(c3p * COLOUR_3.rgb, c3p * COLOUR_1.a)) + light;
}

void main() {
    vec2 uv = gl_FragCoord.xy / resolution.xy;
    finalColor = effect(resolution, uv * resolution);
}