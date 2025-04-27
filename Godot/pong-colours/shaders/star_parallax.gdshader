// res://shaders/star_parallax.gdshader
shader_type canvas_item;

// CORRECTED: Removed hint_range from vec2 uniform
uniform vec2 scroll_speed = vec2(0.01, 0.005); // Slow diagonal scroll (Edit X/Y in Inspector)
uniform float star_density : hint_range(0.9, 0.999) = 0.985;
uniform float base_brightness : hint_range(0.1, 1.0) = 0.6;
uniform float time_scale : hint_range(0.0, 0.5) = 0.05; // Twinkling speed

// Simple pseudo-random number generator
float rand(vec2 co){
	// Prevent issues with negative coordinates if parallax pushes UV < 0
	vec2 abs_co = abs(co);
	return fract(sin(dot(abs_co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
	// Use SCREEN_UV to ensure the effect covers the whole screen regardless of rect size
	vec2 base_uv = SCREEN_UV;
	vec3 final_color = vec3(0.0); // Start with black background

	// Calculate the base time-driven scroll offset
	vec2 time_offset = scroll_speed * TIME;

	// Layer 1: Slowest, smallest/dimmest stars (most distant)
	float parallax_factor1 = 0.3;
	// Apply time offset scaled by parallax factor
	vec2 uv1 = base_uv + time_offset * parallax_factor1;
	float scale1 = 90.0;
	float star_value1 = rand(floor(uv1 * scale1));
	if (star_value1 > star_density) {
		 float twinkle = 0.6 + 0.4 * sin(TIME * time_scale * 50.0 + star_value1 * 500.0);
		final_color += vec3(base_brightness * 0.7 * twinkle);
	}

	// Layer 2: Medium speed, slightly larger/brighter stars
	float parallax_factor2 = 0.6;
	// Apply time offset scaled by parallax factor
	vec2 uv2 = base_uv + time_offset * parallax_factor2;
	float scale2 = 60.0;
	float star_value2 = rand(floor(uv2 * scale2));
	if (star_value2 > star_density + 0.001) { // Slightly less dense
		 float twinkle = 0.7 + 0.3 * sin(TIME * time_scale * 70.0 + star_value2 * 600.0);
		final_color += vec3(base_brightness * 0.85 * twinkle);
	}

	// Layer 3: Fastest, largest/brighter stars (closest)
	float parallax_factor3 = 1.0;
	// Apply time offset scaled by parallax factor
	vec2 uv3 = base_uv + time_offset * parallax_factor3;
	float scale3 = 35.0;
	float star_value3 = rand(floor(uv3 * scale3));
	if (star_value3 > star_density + 0.002) { // Even less dense
		 float twinkle = 0.8 + 0.2 * sin(TIME * time_scale * 100.0 + star_value3 * 700.0);
		 final_color += vec3(base_brightness * 1.0 * twinkle);
	}

	// Set the final color
	COLOR.rgb = final_color;
	COLOR.a = 1.0; // Keep background opaque
}