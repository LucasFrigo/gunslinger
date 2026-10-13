// Two-step diffuse shared by every lit surface. A flat-shaded low-poly face lands wholly
// in one band, so the terminator follows the facets.
// Declared in project.godot [shader_globals]; GameManager pushes F3 `band_low` / `band_soft`,
// so skin, hands, cavity, and the world share one value.
global uniform float band_soft;
// Share of the light the first band lets through.
global uniform float band_low;

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = smoothstep(0.0, band_soft, ndl) * band_low
			+ smoothstep(0.5, 0.5 + band_soft, ndl) * (1.0 - band_low);
	DIFFUSE_LIGHT += lit * ATTENUATION * LIGHT_COLOR / PI;
}
