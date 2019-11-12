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
	
	float scale = sample.r;
	float dist = distance(FRAGCOORD.xy, screen_size/2.0);
	float dist_norm = dist*1.8 / screen_size.y;
	if (COLOR.rgb == star_color.rgb){
		// Star ripple
		COLOR.rg += dist_norm*0.33;
		COLOR.rgb *= mix(abs(0.5-mod(TIME*bps*2.0+dist_norm, 1.0)), 1.0, 0.75);
		COLOR.rgb *= scale;  // Preserve black outlines
	} else if (COLOR.rgb == held_color.rgb){
		// Hold note being held, flashy effects
		COLOR.b *= mix(2.0*abs(0.5-mod(TIME*bps*2.0+dist_norm, 1.0)), 1.0, 0.35);
		COLOR.g *= mix(1.0 - 2.0*abs(0.5-mod(TIME*bps*0.5+dist_norm, 1.0)), 0.0, 0.35);
		COLOR.r *= mix(abs(0.5-mod(TIME*bps, 1.0)), 1.0, 0.85);
		if (scale < 0.1){ // Make outlines WHITE
			COLOR.rgb = vec3(mix(dist_norm, abs(0.5-mod(TIME*bps*8.0, 1.0)), 0.33));
		}
	} else {
		COLOR.gb += 0.1;
		COLOR.rgb *= mix(abs(0.5-mod(TIME*bps, 1.0)), 1.0, 0.85);
		COLOR.rgb *= scale;  // Preserve black outlines
	}
	
	COLOR.a = texture(TEXTURE, UV).a;
	if (sample.rgb == vec3(1.0)){
		COLOR.rgb = vec3(1.0);
	}
}