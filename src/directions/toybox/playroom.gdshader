// WoodLogic. Copyright 2026 Play, Inc.
// Free software under the GNU GPL v3 with additional terms: see LICENSE and NOTICE.

// Toybox background: a bright sky gradient with big soft polka dots on a slow diagonal grid.
// One full screen pass, no texture: a gradient and one distance per pixel.
shader_type canvas_item;

uniform vec2 size = vec2(360.0, 800.0);
uniform vec4 top : source_color = vec4(0.33, 0.78, 0.93, 1.0);
uniform vec4 bottom : source_color = vec4(0.2, 0.58, 0.86, 1.0);
uniform vec4 dot_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float pitch = 64.0;
uniform float dot_radius = 13.0;
uniform float dot_alpha = 0.12;

varying vec2 lp;

void vertex() {
	lp = VERTEX;
}

void fragment() {
	float px = max(length(vec2(dFdx(lp.x), dFdy(lp.x))), 0.0001);
	vec3 c = mix(top.rgb, bottom.rgb, smoothstep(0.0, 1.0, lp.y / size.y));
	vec2 g = lp;
	float row = floor(g.y / pitch);
	g.x += mod(row, 2.0) * pitch * 0.5;
	vec2 cell = mod(g, vec2(pitch)) - vec2(pitch * 0.5);
	float d = length(cell) - dot_radius;
	c = mix(c, dot_color.rgb, dot_alpha * (1.0 - smoothstep(-px, px, d)));
	COLOR = vec4(c, 1.0);
}
