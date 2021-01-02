shader_type canvas_item;
render_mode blend_premul_alpha;

const float TAU = 6.283185307;
const float PI = 3.1415926536;
const float EPS = 0.00001;

uniform vec4 line_color : hint_color = vec4(0.8, 0.8, 1.0, 0.8);
uniform vec4 line_color_double : hint_color = vec4(1.0, 1.0, 0.6, 0.9);
uniform vec4 dot_color : hint_color = vec4(1.0, 1.0, 1.0, 0.8);
uniform float bps = 1.0;
uniform float line_thickness = 0.012;
uniform float line_thickness_min = 0.0;
uniform float dot_thickness = 0.033;
uniform float dot_fullbright_thickness = 0.013;
uniform float max_angle = 1.5708; //1.0708; //3.14159*0.5; //radians(90.0);
uniform float max_dist = 1.25;

// GLES2 clamps our color values that we send as makeshift arrays, so we need to divide them in code and multiply them in our shader
uniform vec3 array_postmul = vec3(2.0, 8.0, 6.283185307);

//void vertex() {
//}

float angle_diff(float a, float b) {
	float d = mod((a - b), TAU);
	if (d > PI) d = TAU - d;
	return d;
}

//vec4 blend_over(vec4 a, vec4 b) {
//	// Blend a over b, preserving transparency
//	vec4 color;
////	color.rgb = (a.rgb*a.a + b.rgb*b.a*(1.0-a.a))/(a.a + b.a*(1.0-a.a));
////	color.a = min(a.a + b.a*(1.0-a.a), 1.0);
//	color.a = min(mix(a.a, 1.0, b.a), 1.0);
//	color.rgb = (a.rgb*a.a + b.rgb*b.a*(1.0-a.a))/color.a;
//	return color;
//}
//vec4 blend_additive(vec4 a, vec4 b) {
//	// Blend a over b, preserving transparency
//	vec4 color;
//	color.a = min(mix(a.a, 1.0, b.a), 1.0);
//	color.rgb = mix(a.rgb, vec3(1.0), b.rgb*b.a*(1.0-a.a));
//	return color;
//}

uniform int array_sidelen = 16;
uniform int array_size = 256;  // Remember to set both of these when using different sizes!
vec3 array_get(sampler2D tex, int index) {
	// GLES3 only
	//return texelFetch(TEXTURE, ivec2(index%array_sidelen, index/array_sidelen), 0).xyz;
	// GLES2 workaround
	float x = float(index%array_sidelen)/float(array_sidelen);
	float y = float(index/array_sidelen)/float(array_sidelen);
	return texture(tex, vec2(x, y), -100.0).xyz * array_postmul;
}

float get_fringe_alpha(float radial_dist, float angular_dist) {  // Branchless edition :)
	float thickness = mix(line_thickness, line_thickness_min, angular_dist/max_angle) * float(angular_dist < max_angle);
	return max(thickness-radial_dist, 0.0)/line_thickness;
}

void fragment() {
	float dist = distance(UV, vec2(0.0));
	float angle = atan(-UV.y, UV.x);
	float line_alpha = 0.0;
	float line_double_alpha = 0.0;
	float dot_alpha = 0.0;
	
	// Iterate over all the notes and check distance to them
	bool last_double = false;
	int i_end = array_size - array_sidelen - 2;
	for (int i=0; i<i_end; i++){
		// x, y, z = radial distance, column, column_radians
		vec3 sample = array_get(TEXTURE, i).xyz;
		if (sample == vec3(0.0)) break;
		// Short-circuit out if our radial difference is too high to matter in any case.
		// Assume dot_thickness is thickest uniform
		float radial_dist = abs(dist - sample.x);
		if (radial_dist > dot_thickness) continue;
		
		// Check for dot distance
		vec2 uv = sample.x * vec2(cos(sample.z), -sin(sample.z));
		float dist2 = distance(UV, uv);
		if (dist2 < dot_thickness){
			//dot_alpha += (dot_thickness-dist2)/dot_thickness;
			float w = dot_thickness - dot_fullbright_thickness;
			dot_alpha += (w-max(dist2-dot_fullbright_thickness, 0.0))/w;
		}
		
		if (last_double){  // Already processed lines in last sample
			last_double = false;
			continue;
		}
		
		float diff_a = angle_diff(angle, sample.z);
		// Check if this note is a double with the next one
		vec3 sample2 = array_get(TEXTURE, (i+1)).xyz;
		if (sample.x == sample2.x){
			// This note is a double!
			last_double = true;
			float double_diff = angle_diff(sample.z, sample2.z);
			// Find the smallest arc between them, make it fully thick. If they are directly opposite, this will go 360°
			float diff_a2 = angle_diff(angle, sample2.z);
			bool fullthick = (diff_a+diff_a2-EPS) <= min(double_diff, PI+EPS); // Branchless logic
			line_double_alpha += ((line_thickness-radial_dist)/line_thickness) * float(radial_dist < line_thickness) * float(fullthick);
			line_double_alpha += get_fringe_alpha(radial_dist, min(diff_a, diff_a2)) * float(!fullthick);
		} else { // Just a regular single, fringing line only
			line_alpha += get_fringe_alpha(radial_dist, diff_a);
		}
	}
	
	// Draw release dots
	for (int i=array_size - array_sidelen; i<array_size; i++){
		vec3 sample = array_get(TEXTURE, i).xyz;
		if (sample == vec3(0.0)) break;
		vec2 uv = sample.x * vec2(cos(sample.z), -sin(sample.z));
		float dist2 = distance(UV, uv);
		if (dist2 < dot_thickness){
			float w = dot_thickness - dot_fullbright_thickness;
			dot_alpha += (w-max(dist2-dot_fullbright_thickness, 0.0))/w;
		}
	}
	
	line_alpha = min(line_alpha, 1.0) * line_color.a;
	line_double_alpha = min(line_double_alpha, 1.0) * line_color_double.a;
	dot_alpha = min(dot_alpha, 1.0) * dot_color.a;
	COLOR.rgb = (line_color_double.rgb*line_double_alpha) + (line_color.rgb*line_alpha) + (dot_color.rgb*dot_alpha);
	COLOR.a = 0.0;
//	COLOR.rgb = (line_color_double.rgb*line_double_alpha + line_color.rgb*line_alpha*(1.0-line_double_alpha))/(line_double_alpha + line_alpha*(1.0-line_double_alpha));
//	COLOR.a = min(line_double_alpha + line_alpha*(1.0-line_double_alpha), 1.0);
	if (dist > 1.0){
		float fade = 1.0 - clamp((max_dist - dist)/(max_dist - 1.0), 0.0, 1.0);
		COLOR.rgb = mix(COLOR.rgb, vec3(0.0), fade);
	}
}