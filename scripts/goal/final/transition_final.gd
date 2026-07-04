extends CanvasLayer

@onready var color_rect = $color_rect

func _ready():
	show_new_scene()

# Transição normal (fase 1 -> 2, fase 2 -> 3)
func change_scene(path, delay = 0.1):
	var scene_transition = get_tree().create_tween()

	scene_transition.tween_property(
		color_rect.material,
		"shader_parameter/threshold",
		1.5,
		1.0
	).set_delay(delay)

	await scene_transition.finished

	get_tree().change_scene_to_file(path)

# Transição especial para os créditos
func change_to_credits(path, delay = 0.1):

	# Desliga o shader
	color_rect.material = null

	# Tela preta invisível
	color_rect.color = Color.BLACK
	color_rect.modulate.a = 0.0

	var tween = create_tween()

	# Escurece devagar
	tween.tween_property(
		color_rect,
		"modulate:a",
		1.0,
		3.0
	).set_delay(delay)

	await tween.finished

	get_tree().change_scene_to_file(path)

func show_new_scene():
	var show_transition = get_tree().create_tween()

	show_transition.tween_property(
		color_rect.material,
		"shader_parameter/threshold",
		0.0,
		1.5
	).from(0.5)
