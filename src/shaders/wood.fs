#version 330

in vec2 fragTexCoord;
out vec4 fragColor;

uniform vec2 resolution;
uniform float opacity;
uniform vec2 position;

#define R resolution
#define sat(x)	clamp(x, 0.0, 1.0)
#define S(a, b, c)	smoothstep(a, b, c)
#define S01(a)	S(0.0, 1.0, a)

float sum2(vec2 v) { return dot(v, vec2(1.0)); }

///////////////////////////////////////////////////////////////////////////////

float h31(vec3 p3) {
	p3 = fract(p3 * 0.1031);
	p3 += dot(p3, p3.yzx + 333.3456);
	return fract(sum2(p3.xy) * p3.z);
}

float h21(vec2 p) { return h31(vec3(p, 0.0)); }

float n31(vec3 p) {
	const vec3 s = vec3(7.0, 157.0, 113.0);

	// Thanks Shane - https://www.shadertoy.com/view/lstGRB
	vec3 ip = floor(p);
	p = fract(p);
	p = p * p * (3.0 - 2.0 * p);
	vec4 h = vec4(0.0, s.yz, sum2(s.yz)) + dot(ip, s);
	h = mix(fract(sin(h) * 43758.545), fract(sin(h + s.x) * 43758.545), p.x);
	h.xy = mix(h.xz, h.yw, p.y);
	return mix(h.x, h.y, p.z);
}

// roughness: (0.0, 1.0], default: 0.5
// Returns unsigned noise [0.0, 1.0]
float fbm(vec3 p, int octaves, float roughness) {
	float sum = 0.0;
	float amp = 1.0;
	float tot = 0.0;
	roughness = sat(roughness);
	for (int i = 0; i < octaves; i++) {
		sum += amp * n31(p);
		tot += amp;
		amp *= roughness;
		p *= 2.0;
	}
	return sum / tot;
}

vec3 randomPos(float seed) {
	vec4 s = vec4(seed, 0.0, 1.0, 2.0);
	return vec3(h21(s.xy), h21(s.xz), h21(s.xw)) * 1e2 + 1e2;
}

// Returns unsigned noise [0.0, 1.0]
float fbmDistorted(vec3 p) {
	p += (vec3(n31(p + randomPos(0.0)), n31(p + randomPos(1.0)), n31(p + randomPos(2.0))) * 2.0 - 1.0) * 1.12;
	return fbm(p, 8, 0.5);
}

// vec3: detail(/octaves), dimension(/inverse contrast), lacunarity
// Returns signed noise.
float musgraveFbm(vec3 p, float octaves, float dimension, float lacunarity) {
	float sum = 0.0;
	float amp = 1.0;
	float m = pow(lacunarity, -dimension);
	for (float i = 0.0; i < octaves; i++) {
		float n = n31(p) * 2.0 - 1.0;
		sum += n * amp;
		amp *= m;
		p *= lacunarity;
	}
	return sum;
}

// Wave noise along X axis.
vec3 waveFbmX(vec3 p) {
	float n = p.x * 20.0;
	n += 0.4 * fbm(p * 3.0, 3, 3.0);
	return vec3(sin(n) * 0.5 + 0.5, p.yz);
}

///////////////////////////////////////////////////////////////////////////////
// Math
float remap01(float f, float in1, float in2) { return sat((f - in1) / (in2 - in1)); }

///////////////////////////////////////////////////////////////////////////////
// Wood material.
vec3 matWood(vec3 p) {
	float n1 = fbmDistorted(p * vec3(7.8, 1.17, 1.17));
	n1 = mix(n1, 1.0, 0.2);
	float n2 = mix(musgraveFbm(vec3(n1 * 4.6), 8.0, 0.0, 2.5), n1, 0.85);
	float dirt = 1.0 - musgraveFbm(waveFbmX(p * vec3(0.01, 0.15, 0.15)), 15.0, 0.26, 2.4) * 0.4;
	float grain = 1.0 - S(0.2, 1.0, musgraveFbm(p * vec3(500.0, 6.0, 1.0), 2.0, 2.0, 2.5)) * 0.2;
	n2 *= dirt * grain;

	return mix(mix(vec3(0.03, 0.012, 0.003), vec3(0.25, 0.11, 0.04), remap01(n2, 0.19, 0.56)), vec3(0.52, 0.32, 0.19), remap01(n2, 0.56, 1.0));
}

void main() {
    vec2 fc = gl_FragCoord.xy;
    vec3 p = vec3((fc - 0.5 * R.xy) / R.y, 0.0); // Removed time and made static
    vec4 woodColor = vec4(pow(matWood(p), vec3(0.4545)), 1.0); // Set alpha to 1.0 for opaque border
    fragColor = woodColor * opacity;
}