// Bear Shop fur colours: recolours the bear sprite (see skins.gd).
shader_type canvas_item;
uniform float hue = 0.0;
uniform float sat = 1.0;
uniform float val = 1.0;
uniform float rainbow = 0.0;
uniform float shine = 0.0;
varying vec4 tint;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1.0e-10)), d / (q.x + 1.0e-10), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec3 c = tex.rgb;
	float lo = min(c.r, min(c.g, c.b));
	float hi = max(c.r, max(c.g, c.b));
	// the white outline and the black eyes stay as they are
	if (lo < 0.95 && hi > 0.04) {
		vec3 h = rgb2hsv(c);
		h.x = fract(h.x + hue + rainbow * (TIME * 0.35 + FRAGCOORD.y * 0.006));
		h.y = clamp(h.y * sat, 0.0, 1.0);
		h.z = clamp(h.z * val, 0.0, 1.0);
		c = hsv2rgb(h);
		if (shine > 0.0) {
			float band = smoothstep(0.9, 1.0, sin((FRAGCOORD.x + FRAGCOORD.y) * 0.035 - TIME * 3.0));
			c = min(c + band * shine, vec3(1.0));
		}
	}
	COLOR = vec4(c, tex.a) * tint;
}
