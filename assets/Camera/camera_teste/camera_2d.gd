extends Camera2D

var max_difference : int = 50
var sync_y : bool = true

func _process(delta: float) -> void:
	global_position.x = move_toward(global_position.x, $"../Player/Follow_Point".global_position.x, delta * 300)
		
	if sync_y == true:
		global_position.y = move_toward(global_position.y, $"../Player/Follow_Point".global_position.y, delta * 500)
		
	print(sync_y)
