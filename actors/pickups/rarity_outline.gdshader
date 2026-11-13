shader_type canvas_item;
// Draws the shape of a sprite in one flat colour. Four copies of a weapon sprite,
// shifted by a pixel left, right, up and down and drawn behind it, make an outline
// in the colour of the weapon's rarity.

uniform vec4 color : source_color = vec4(1.0);

void fragment() {
	COLOR = vec4(color.rgb, color.a * texture(TEXTURE, UV).a);
}
