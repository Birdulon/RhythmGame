shader_type canvas_item;
render_mode blend_premul_alpha;

const float TAU = 6.283185307;
const float PI = 3.1415926536;

const vec4 dbg_color = vec4(1.0, 0.0, 0.0, 1.0);

uniform int num_receptors = 8;
uniform float receptor_offset = 0.0;
uniform vec4 line_color : hint_color = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 dot_color : hint_color = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 shadow_color : hint_color = vec4(0.0, 0.0, 0.0, 0.57);
//uniform float bps = 1.0;
uniform float line_thickness = 0.006;
uniform float dot_radius = 0.033;
uniform float shadow_thickness = 0.01;
uniform float px = 0.002;  // Represents 1px in UV space, for AA purposes
uniform float px2 = 0.004;  // Represents 2px in UV space, for AA purposes

//void vertex() {
//}

float angle_diff(float a, float b) {
	float d = mod((a - b), TAU);
	if (d > PI) d = TAU - d;
	return d;
}

vec2 line_alpha(float dist) {
	// Returns [line, shadow]
	float d = abs(dist - 1.0) - line_thickness;
	return clamp(vec2(-1.0 - d/px, 1.0 - d/shadow_thickness), 0.0, 1.0);
}

vec2 dot_alpha(vec2 uv) {
	// Returns [dot, shadow]
	vec2 output = vec2(0.0);
	// Iterate over all the receptors and check distance to them
	float receptor_spacing = TAU/float(num_receptors);
	for (float rads=receptor_offset; rads<TAU; rads+=receptor_spacing){
		// Check for dot distance
		vec2 dot_uv = vec2(cos(rads), -sin(rads));
		float d = distance(uv, dot_uv) - dot_radius;
		output = clamp(vec2(-1.0 - d/px, 1.0 - d/shadow_thickness), output, vec2(1.0));
	}
	return output;
}

void fragment() {
	if (COLOR.rgba != dbg_color) {  // Can't use return in fragment() function
	COLOR.rgba = vec4(0.0);
	lowp float dist = distance(UV, vec2(0.0));
	lowp float angle = atan(-UV.y, UV.x);
	vec3 lds_alpha = vec3(0.0);
	
	lds_alpha.yz = dot_alpha(UV);
	lds_alpha.xz = clamp(line_alpha(dist), vec2(0.0, lds_alpha.z), vec2(1.0-lds_alpha.y));
	lds_alpha = clamp(lds_alpha, 0.0, 1.0);
	lds_alpha.z *= 1.0-min(dot(lds_alpha.xy, vec2(1.0)), 1.0);
	lds_alpha.z *= shadow_color.a;

	COLOR.rgb = (line_color.rgb*lds_alpha.x) + (dot_color.rgb*lds_alpha.y) + (shadow_color.rgb*lds_alpha.z);
	COLOR.a = lds_alpha.y + lds_alpha.x*(1.0-lds_alpha.y);
	COLOR.a += lds_alpha.z*(1.0-COLOR.a);
	COLOR = clamp(COLOR, 0.0, 1.0); }
}