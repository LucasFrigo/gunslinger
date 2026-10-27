shader_type canvas_item;
// Runtime duel-card lettering (`TitleCardLettering`). Glyph edges are cut hard so Nearest
// scaling shows whole pixels, and pure white (the face copy) takes the card's colour bands
// by local y. The outline and extrusion copies keep the colour they were drawn in.

uniform vec4 band_top : source_color = vec4(1.0, 0.941, 0.722, 1.0);
uniform vec4 band_mid : source_color = vec4(1.0, 0.784, 0.227, 1.0);
uniform vec4 band_low : source_color = vec4(1.0, 0.541, 0.165, 1.0);
// Local y where the middle and the low band start.
uniform float mid_from = 0.0;
uniform float low_from = 0.0;
uniform float alpha_cut = 0.5;

varying float local_y;

void vertex() {
	local_y = VERTEX.y;
}

void fragment() {
	vec4 color = COLOR;
	if (color.r > 0.99 && color.g > 0.99 && color.b > 0.99) {
		color.rgb = local_y < mid_from ? band_top.rgb : (local_y < low_from ? band_mid.rgb : band_low.rgb);
	}
	color.a = step(alpha_cut, color.a);
	COLOR = color;
}
