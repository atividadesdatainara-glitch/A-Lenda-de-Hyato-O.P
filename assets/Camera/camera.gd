extends Camera2D

var target: Node2D # aqui vai seguir o player

func _ready() -> void:
	get_targert()
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if target:
		position = target.position #aqui copia o movimento do player ou seja vai segui-lo
	
func get_targert(): # quando nao achar o player
	var nodes = get_tree().get_nodes_in_group("Player") # Os nos do grupo pleyer
	if nodes.size() == 0: 
		push_error("Player nao encontrado")
		return
		
	target = nodes[0]
	
