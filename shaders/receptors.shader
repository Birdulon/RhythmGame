shader_type canvas_item;
render_mode blend_premul_alpha;

const float TAU = 6.283185307;
const float PI = 3.1415926536;

uniform int num_receptors = 8;
uniform float receptor_offset = 0.0;
uniform vec4 line_color : hint_color = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 dot_color : hint_color = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 shadow_color : hint_color = vec4(0.0, 0.0, 0.0, 1.0);
//uniform float bps = 1.0;
uniform float line_thickness = 0.006;
uniform float dot_radius = 0.033;
uniform float shadow_thickness = 0.01;
uniform float shadow_thickness_taper = 0.33;
uniform float px = 0.002;  // Represents 1px in UV space, for AA purposes

//void vertex() {
//}

float angle_diff(float a, float b) {
	float d = mod((a - b), TAU);
	if (d > PI) d = TAU - d;
	return d;
}

void fragment() {
	if (COLOR.rgba != vec4(1.0, 0.0, 0.0, 1.0)) {
	COLOR.rgba = vec4(0.0);
	lowp float dist = distance(UV, vec2(0.0));
	lowp float angle = atan(-UV.y, UV.x);
	float line_alpha = 0.0;
	float dot_alpha = 0.0;
	float shadow_alpha = 0.0;
	float px2 = px/2.0;
	
	float diff = abs(dist - 1.0);
	float d2 = diff - line_thickness;
	if (d2 < -px2){
		line_alpha = 1.0;
	} else if (d2 < shadow_thickness){
		if (d2 < px2)
			line_alpha = 1.0 - (d2 + px2)/px;
		shadow_alpha = 1.0 - min((d2 - shadow_thickness*shadow_thickness_taper)/(shadow_thickness*(1.0-shadow_thickness_taper)), 1.0);
	}
	
	// Iterate over all the receptors and check distance to them
	float receptor_spacing = TAU/float(num_receptors);
	for (float rads=receptor_offset; rads<TAU; rads+=receptor_spacing){
		// Check for dot distance
		vec2 uv = vec2(cos(rads), -sin(rads));
		float dist2 = distance(UV, uv);
		float diff2 = dist2 - dot_radius;
		if (diff2 < -px2){
			dot_alpha = 1.0;
		} else if (diff2 < shadow_thickness){
			if (diff2 < px2)
				dot_alpha = 1.0 - (diff2 + px2)/px;
			shadow_alpha = max(shadow_alpha, 1.0-min((diff2 - shadow_thickness*shadow_thickness_taper)/(shadow_thickness*(1.0-shadow_thickness_taper)), 1.0));
		}
	}
	line_alpha = max(line_alpha - dot_alpha, 0.0);

	COLOR.rgb = (dot_color.rgb*dot_alpha) + (line_color.rgb*line_alpha) + (shadow_color.rgb*shadow_alpha);
	COLOR.a = dot_alpha + line_alpha*(1.0-dot_alpha);
	COLOR.a = COLOR.a + shadow_alpha*(1.0-COLOR.a);
	COLOR.a = clamp(COLOR.a, 0.0, 1.0); }
}