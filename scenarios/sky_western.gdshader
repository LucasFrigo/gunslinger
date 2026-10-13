shader_type sky;
// Same gradient as ProceduralSkyMaterial (so the fog still meets `ground_horizon`), plus
// a hard sun disc, a halo, optional flat bands, and cel clouds. No TIME: an animated sky
// re-renders the radiance map every frame.

uniform vec3 sky_top : source_color = vec3(0.25, 0.15, 0.3);
uniform vec3 sky_horizon : source_color = vec3(0.95, 0.5, 0.25);
uniform float sky_curve = 0.15;
uniform vec3 ground_bottom : source_color = vec3(0.72, 0.4, 0.2);
uniform vec3 ground_horizon : source_color = vec3(0.95, 0.55, 0.28);
uniform float ground_curve = 0.02;
// 0 leaves the gradient smooth. 5 to 8 gives poster bands.
uniform float bands = 0.0;
// Radians. The real sun is 0.0046; a poster sun is 0.05 to 0.12.
uniform float sun_radius = 0.015;
uniform float sun_halo = 0.35;
uniform sampler2D cloud_tex : filter_linear, repeat_enable, hint_default_black;
uniform float cloud_cover = 0.35;
uniform float cloud_scale = 0.25;
uniform vec2 cloud_offset = vec2(0.0);
uniform vec3 cloud_color : source_color = vec3(1.0, 0.78, 0.62);

void sky() {
	float angle = acos(clamp(EYEDIR.y, -1.0, 1.0));
	float up = 1.0 - angle / (PI * 0.5);
	float sky_mix = clamp(1.0 - pow(1.0 - max(up, 0.0), 1.0 / sky_curve), 0.0, 1.0);
	if (bands > 0.0) {
		sky_mix = floor(sky_mix * bands + 0.5) / bands;
	}
	vec3 color = mix(sky_horizon, sky_top, sky_mix);
	if (EYEDIR.y < 0.0) {
		float down = clamp(1.0 - pow(1.0 + min(up, 0.0), 1.0 / ground_curve), 0.0, 1.0);
		color = mix(ground_horizon, ground_bottom, down);
	} else if (!AT_CUBEMAP_PASS) {
		// A flat deck far overhead, faded out before it reaches the horizon line.
		vec2 deck = EYEDIR.xz / (EYEDIR.y + 0.12) * cloud_scale + cloud_offset;
		float cloud = step(1.0 - cloud_cover, texture(cloud_tex, deck).r);
		color = mix(color, cloud_color, cloud * smoothstep(0.03, 0.2, EYEDIR.y) * 0.85);
		if (LIGHT0_ENABLED) {
			float sun = acos(clamp(dot(LIGHT0_DIRECTION, EYEDIR), -1.0, 1.0));
			float halo = 1.0 - smoothstep(sun_radius, sun_radius + sun_halo, sun);
			color += LIGHT0_COLOR * halo * halo * 0.25;
			color = mix(color, LIGHT0_COLOR * LIGHT0_ENERGY, 1.0 - step(sun_radius, sun));
		}
	}
	COLOR = color;
}
