shader_type canvas_item;
//render_mode unshaded;

uniform float bps;
uniform vec4 star_color : hint_color;
uniform vec4 held_color : hint_color;
uniform vec2 screen_size;

//void vertex() {
//}

void fragment() {
	vec4 sample = texture(TEXTURE, UV);
	
	//Not sure if this helps or hurts performance
	//if (sample.a <= 0.0) discard;
	
	float color_scale = sample.r;
	float bright_scale = (sample.g+sample.b)/2.0;
	float dist = distance(FRAGCOORD.xy, screen_size/2.0);
	float dist_norm = dist*1.8 / screen_size.y;
	if (COLOR.rgb == star_color.rgb){
		// Star ripple
		COLOR.rg += dist_norm*0.33;
		COLOR.rgb *= mix(abs(0.5-mod(TIME*bps*2.0+dist_norm, 1.0)), 1.0, 0.75);
		COLOR.rgb *= color_scale;  // Preserve black outlines
		COLOR.rgb = mix(COLOR.rgb, vec3(1.0), bright_scale);  // Preserve white outlines
	} else if (COLOR.rgb == held_color.rgb){
		// Hold note being held, flashy effects
		COLOR.b *= mix(2.0*abs(0.5-mod(TIME*bps*2.0+dist_norm, 1.0)), 1.0, 0.35);
		COLOR.g *= mix(1.0 - 2.0*abs(0.5-mod(TIME*bps*0.5+dist_norm, 1.0)), 0.0, 0.35);
		COLOR.r *= mix(abs(0.5-mod(TIME*bps, 1.0)), 1.0, 0.85);
		if (color_scale < 0.5){ // Make black outlines shine
			COLOR.rgb = mix(COLOR.rgb, vec3(mix(dist_norm, abs(0.5-mod(TIME*bps*8.0, 1.0)), 0.33)), 1.0-(color_scale*2.0));
		}
		COLOR.rgb = mix(COLOR.rgb, vec3(1.0), 0.33);  // brighten overall
		COLOR.rgb = mix(COLOR.rgb, vec3(0.25), bright_scale);  // Invert white outlines
	} else {
		COLOR.gb += 0.1;
		COLOR.rgb *= mix(abs(0.5-mod(TIME*bps, 1.0)), 1.0, 0.85);
		COLOR.rgb *= color_scale;  // Preserve black outlines
		COLOR.rgb = mix(COLOR.rgb, vec3(1.0), bright_scale);  // Preserve white outlines
	}
	
	COLOR.a = clamp(COLOR.a*texture(TEXTURE, UV).a, 0.0, 1.0);
}