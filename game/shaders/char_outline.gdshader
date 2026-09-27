shader_type canvas_item;
// Clean 1-art-pixel outline around a whole layered character (applied to its CanvasGroup),
// matching the dark sprite outlines of the concept boards.
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform vec4 line_color : source_color = vec4(0.07, 0.08, 0.14, 0.92);
uniform float px_scale = 2.0;

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	vec2 o = SCREEN_PIXEL_SIZE * px_scale;
	float n = textureLod(screen_texture, SCREEN_UV + vec2(o.x, 0.0), 0.0).a;
	n = max(n, textureLod(screen_texture, SCREEN_UV - vec2(o.x, 0.0), 0.0).a);
	n = max(n, textureLod(screen_texture, SCREEN_UV + vec2(0.0, o.y), 0.0).a);
	n = max(n, textureLod(screen_texture, SCREEN_UV - vec2(0.0, o.y), 0.0).a);
	if (c.a < 0.5 && n > 0.5) {
		COLOR = line_color;
	} else {
		COLOR = c;
	}
}
