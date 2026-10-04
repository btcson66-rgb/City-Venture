shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform int mode = 0;
void fragment() {
	vec4 c = texture(screen_texture, SCREEN_UV);
	// Palette assistance: separate red/green along a blue axis, or blue/yellow along red.
	// Text and +/- signs remain the authoritative meaning; this is not a medical simulation.
	if (mode == 1) c.rgb = vec3(c.r * 0.65 + c.g * 0.35, c.g, c.b * 0.55 + c.r * 0.45);
	if (mode == 2) c.rgb = vec3(c.r * 0.55 + c.b * 0.45, c.g, c.b * 0.65 + c.g * 0.35);
	if (mode == 3) c.rgb = clamp((c.rgb - vec3(0.5)) * 1.5 + vec3(0.5), vec3(0.0), vec3(1.0));
	COLOR = c;
}
