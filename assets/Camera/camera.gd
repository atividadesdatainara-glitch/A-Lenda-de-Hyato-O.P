extends Camera2D

var target: CharacterBody2D
var offset_x = 0.0

func _ready() -> void:
	get_targert()

func _process(_delta):

	if target:

		if target.velocity.x > 0:
			offset_x = lerp(offset_x, 40.0, 0.05)

		elif target.velocity.x < 0:
			offset_x = lerp(offset_x, -40.0, 0.05)

		else:
			offset_x = lerp(offset_x, 0.0, 0.01)

		position = target.position + Vector2(offset_x, 0)

func get_targert():

	var nodes = get_tree().get_nodes_in_group("Player")

	if nodes.size() == 0:
		push_error("Player nao encontrado")
		return

	target = nodes[0]
