extends Camera2D

@export var player: Node2D
@export var room_position: Vector2 = Vector2.ZERO
@export var room_size: Vector2 = Vector2(1920, 1080)
@export var follow_speed: float = 5.0

func _ready():
	if player == null:
		push_error("Camera2D: Player não definido!")

func _process(delta):
	if player == null:
		return

	# Posição desejada baseada na posição do player
	var target_position := player.global_position

	# Suaviza o movimento da câmera
	global_position = global_position.lerp(target_position, follow_speed * delta)

	# Calcula os limites da câmera com base no tamanho da viewport
	var half_viewport := get_viewport_rect().size * 0.5
	var min_limit := room_position + half_viewport
	var max_limit := room_position + room_size - half_viewport

	# Limita a posição da câmera dentro da sala
	global_position.x = clamp(global_position.x, min_limit.x, max_limit.x)
	global_position.y = clamp(global_position.y, min_limit.y, max_limit.y)
