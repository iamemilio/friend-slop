shader_type spatial;
// Unshaded: moonlight DirectionalLight would otherwise flatten whole clouds white.
render_mode unshaded, blend_mix, depth_draw_always, cull_disabled;

## Per-fragment moon glow so one cloud can be white nearest the moon disc
## and fade to grey toward its edges — tuned for looking up from the maze.

uniform vec3 moon_world_pos = vec3(0.0, 200.0, 0.0);
uniform vec4 albedo_near : source_color = vec4(0.95, 0.97, 1.0, 0.72);
## Soft mid grey so faces stay visible and stack translucently.
uniform vec4 albedo_far : source_color = vec4(0.48, 0.52, 0.60, 0.58);
## Half-angle of the bright core (degrees). Smaller = tighter hot spot like the photo.
uniform float glow_half_angle_deg : hint_range(2.0, 40.0) = 12.0;
## Soft outer halo beyond the core (degrees of extra falloff).
uniform float glow_soft_angle_deg : hint_range(2.0, 50.0) = 26.0;
uniform float glow_power : hint_range(1.0, 8.0) = 1.25;
## Mild world-distance gate so far banks stay darker even if angularly near.
uniform float glow_core_m : hint_range(20.0, 200.0) = 50.0;
uniform float glow_falloff_m : hint_range(40.0, 400.0) = 280.0;
uniform float emission_strength : hint_range(0.0, 4.0) = 0.45;
## Extra see-through when looking through the cloud toward the moon.
uniform float transmit_strength : hint_range(0.0, 1.0) = 0.4;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 view_to_pos = normalize(world_pos - cam);
	vec3 view_to_moon = normalize(moon_world_pos - cam);

	// Angular distance from the moon disc as seen from the player — this is what
	// creates white→grey *within* a cloud that crosses the moon.
	float cos_a = clamp(dot(view_to_pos, view_to_moon), -1.0, 1.0);
	float angle_deg = degrees(acos(cos_a));
	float core = max(glow_half_angle_deg, 0.01);
	float soft = max(glow_soft_angle_deg, 0.01);
	float angular = 1.0 - clamp((angle_deg - core * 0.35) / (core * 0.65 + soft), 0.0, 1.0);
	angular = pow(angular, glow_power);

	// Secondary: absolute distance to the moon node (banks far away stay muted).
	float dist = distance(world_pos, moon_world_pos);
	float radial = 1.0 - clamp((dist - glow_core_m) / max(glow_falloff_m, 0.001), 0.0, 1.0);
	radial = pow(radial, 1.4);

	// Mid-grey floor so faces don’t crush to black silhouettes.
	float t = clamp(angular * mix(0.45, 1.0, radial), 0.0, 1.0);

	vec4 alb = mix(albedo_far, albedo_near, t);

	// Soft transmission: looking toward the moon lightens and thins the cloud.
	float transmit = pow(clamp(cos_a, 0.0, 1.0), 3.0) * transmit_strength;
	ALBEDO = mix(alb.rgb, albedo_near.rgb, transmit * 0.5);
	ALPHA = mix(alb.a, alb.a * 0.55, transmit);
	EMISSION = albedo_near.rgb * ((t + transmit * 0.5) * emission_strength);
}
