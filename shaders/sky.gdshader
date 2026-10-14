// Cielo procedural de CyberCity: degradado, disco y halo del sol, nubes y estrellas.
// No usa TIME, así Godot recalcula la luz ambiental solo cuando cambian los parámetros.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.18, 0.43, 0.75);
uniform vec3 horizon_color : source_color = vec3(0.66, 0.82, 0.94);
uniform vec3 ground_color : source_color = vec3(0.24, 0.32, 0.2);
uniform vec3 cloud_light : source_color = vec3(1.0);
uniform vec3 cloud_shadow : source_color = vec3(0.62, 0.68, 0.76);
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.55;
uniform float night : hint_range(0.0, 1.0) = 0.0;
uniform float energy = 1.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon_color, top_color, smoothstep(0.0, 0.55, h));
	} else {
		col = mix(horizon_color, ground_color, smoothstep(0.0, 0.12, -h));
	}
	// Sol: disco nítido y halo suave
	if (LIGHT0_ENABLED) {
		float sd = max(dot(d, LIGHT0_DIRECTION), 0.0);
		float e = min(LIGHT0_ENERGY, 1.5);
		col += LIGHT0_COLOR * e * (smoothstep(0.9993, 0.9997, sd) * 6.0 + pow(sd, 90.0) * 0.45 + pow(sd, 8.0) * 0.1);
	}
	// Estrellas
	if (night > 0.0 && h > 0.0) {
		vec3 g = floor(d * 380.0);
		float s = hash(g.xy + g.z * 17.13);
		col += vec3(step(0.9972, s) * night * smoothstep(0.0, 0.25, h) * 1.6);
	}
	// Nubes proyectadas en una cúpula
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.3);
		float n = fbm(uv * 2.6 + vec2(3.1, 1.7));
		float c = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + 0.35, n) * smoothstep(0.0, 0.2, h);
		vec3 cc = mix(cloud_shadow, cloud_light, smoothstep(0.35, 0.9, n));
		col = mix(col, cc, c * 0.9);
	}
	COLOR = col * energy;
}
