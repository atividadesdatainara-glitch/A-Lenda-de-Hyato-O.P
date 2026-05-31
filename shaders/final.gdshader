shader_type canvas_item;

uniform float threshold : hint_range(0.0, 1.0) = 0.0;
uniform vec4 fade_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);

void fragment() {
	COLOR = fade_color;
	COLOR.a = threshold;
}