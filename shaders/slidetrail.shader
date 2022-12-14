shader_type canvas_item;
//render_mode blend_premul_alpha;

uniform float trail_progress = 0.0;
uniform float base_alpha = 0.88;
uniform float bps = 1.0;

// The idea here is to create a static mesh for each slide trail at scorefile load.
// Since we need to be able to hide parts of the trail that we have passed,
// we need to do that in this shader.
// We don't need vertex alpha normally so we can just set that to large whole numbers
// on each arrow (1.0, 2.0, 3.0, ... 50.0) and then use a uniform progress float.
void vertex() {
//	COLOR.a = clamp(COLOR.a-trail_progress, 0.0, 1.0);
	if (COLOR.a<trail_progress)
		COLOR.a = 0.0;
	else
		COLOR.a = 1.0;
}

void fragment() {
	vec4 sample = texture(TEXTURE, UV);
	COLOR.rgb *= sample.r;
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), (sample.g+sample.b)/2.0);
//	if (sample.rgb == vec3(1.0)) COLOR.rgb = vec3(1.0);
	COLOR.a *= sample.a * base_alpha;
}