// res://shaders/star_parallax.gdshader
shader_type canvas_item;

// Uniforms (parameters you can set from GDScript)
uniform vec2 ball_position_normalized = vec2(0.5, 0.5); // Ball position (0.0 to 1.0)
uniform float parallax_strength : hint_range(0.0, 0.2) = 0.05; // How much stars move
uniform float star_density : hint_range(0.9, 0.999) = 0.995; // Controls how many stars appear
uniform float base_brightness : hint_range(0.1, 1.0) = 0.5;
uniform float time_scale : hint_range(0.0, 0.5) = 0.05; // Twinkling speed

// Simple pseudo-random number generator
float rand(vec2 co){
    return fract(sin(dot(co.xy ,vec2(12.9898,78.233))) * 43758.5453);
}

void fragment() {
    vec2 base_uv = SCREEN_UV; // Use SCREEN_UV for full-screen effect

    vec3 final_color = vec3(0.0); // Start with black

    // Layer 1: Slowest, smallest stars (most distant)
    float parallax_factor1 = 0.3;
    vec2 uv1 = base_uv + (ball_position_normalized - 0.5) * parallax_strength * parallax_factor1;
    float star_value1 = rand(floor(uv1 * 200.0)); // Adjust scale (200.0) for star size/spacing
    if (star_value1 > star_density) {
         float twinkle = 0.6 + 0.4 * sin(TIME * time_scale * 50.0 + star_value1 * 500.0); // Time-based twinkle
        final_color += vec3(base_brightness * 0.7 * twinkle); // Dimmer stars
    }

    // Layer 2: Medium speed, slightly larger/brighter stars
    float parallax_factor2 = 0.6;
    vec2 uv2 = base_uv + (ball_position_normalized - 0.5) * parallax_strength * parallax_factor2;
    float star_value2 = rand(floor(uv2 * 120.0)); // Adjust scale (120.0)
    if (star_value2 > star_density + 0.001) { // Slightly less dense
         float twinkle = 0.7 + 0.3 * sin(TIME * time_scale * 70.0 + star_value2 * 600.0);
        final_color += vec3(base_brightness * 0.85 * twinkle); // Slightly brighter
    }

    // Layer 3: Fastest, largest/brightest stars (closest)
    float parallax_factor3 = 1.0;
    vec2 uv3 = base_uv + (ball_position_normalized - 0.5) * parallax_strength * parallax_factor3;
    float star_value3 = rand(floor(uv3 * 70.0)); // Adjust scale (70.0)
    if (star_value3 > star_density + 0.002) { // Even less dense
         float twinkle = 0.8 + 0.2 * sin(TIME * time_scale * 100.0 + star_value3 * 700.0);
         final_color += vec3(base_brightness * 1.0 * twinkle); // Brightest
    }

    COLOR.rgb = final_color;
    COLOR.a = 1.0; // Keep background opaque
}