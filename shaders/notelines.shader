shader_type canvas_item;
render_mode blend_premul_alpha;

uniform vec4 line_color : hint_color = vec4(0.8, 0.8, 1.0, 0.8);
uniform vec4 line_color_double : hint_color = vec4(1.0, 1.0, 0.6, 0.9);
uniform vec4 dot_color : hint_color = vec4(1.0, 1.0, 1.0, 0.8);
uniform float bps = 1.0;
uniform float line_thickness = 0.012;
uniform float line_thickness_min = 0.0;
uniform float dot_thickness = 0.033;
uniform float dot_fullbright_thickness = 0.013;
uniform float max_angle = 1.0708; //3.14159*0.5; //radians(90.0);
uniform float max_dist = 1.25;

//void vertex() {
//}

float angle_diff(float a, float b) {
	float d = mod((a - b), 6.28318);
	if (d > 3.14159) d = 6.28318 - d;
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


void fragment() {
	float dist = distance(UV, vec2(0.0));
	float angle = atan(-UV.y, UV.x);
	float line_alpha = 0.0;
	float line_double_alpha = 0.0;
	float dot_alpha = 0.0;
	
	// Iterate over all the notes and check distance to them
	bool last_double = false;
	for (int i=0; i<238; i++){
		// x, y, z = distance, column, column_radians
		vec3 sample = texelFetch(TEXTURE, ivec2(i%16, i/16), 0).xyz;
		if (sample == vec3(0.0)) break;
		float diff = abs(dist - sample.x);
		// Short-circuit out if our radial difference is too high to matter in any case.
		// We need the diff value calculated anyway so shouldn't add any overhead
		// Assume dot_thickness is thickest uniform
		if (diff > dot_thickness) continue;
		
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
		vec3 sample2 = texelFetch(TEXTURE, ivec2((i+1)%16, (i+1)/16), 0).xyz;
		if (sample.x == sample2.x){
			// This note is a double!
			last_double = true;
			// Check for special case: directly opposite columns - full-thickness line 360°
			if (sample.y == mod(sample2.y+4.0, 8.0)){
				if (diff < line_thickness){
					line_double_alpha += (line_thickness-diff)/line_thickness;
				}
			} else {
				// Find the smallest arc between them, make it fully thick
				float diff_a2 = angle_diff(angle, sample2.z);
//				if ((diff_a<1.5708) && (diff_a2<1.5708)){
				if ((diff_a+diff_a2-0.0001) <= angle_diff(sample.z, sample2.z)){
					if (diff < line_thickness){
						line_double_alpha += (line_thickness-diff)/line_thickness;
					}
				} else {
					// Fringe
					float diff_amin = min(diff_a, diff_a2);
					if (diff_amin < max_angle){
						float thickness = mix(line_thickness, line_thickness_min, diff_amin/max_angle);
						if (diff < thickness){
							line_double_alpha += (thickness-diff)/line_thickness;
						}
					}
				}
			}
		} else {
			if (diff_a < max_angle){
				float thickness = mix(line_thickness, line_thickness_min, diff_a/max_angle);
				if (diff < thickness){
					line_alpha += (thickness-diff)/line_thickness;
				}
			}
		}
	}
	
	// Draw release dots
	for (int i=0; i<15; i++){
		vec3 sample = texelFetch(TEXTURE, ivec2(i, 15), 0).xyz;
		if (sample == vec3(0.0)) break;
		vec2 uv = sample.x * vec2(cos(sample.z), -sin(sample.z));
		float dist2 = distance(UV, uv);
		if (dist2 < dot_thickness){
			//dot_alpha += (dot_thickness-dist2)/dot_thickness;
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