extends Area2D

func _on_body_entered(body: Node2D) -> void:
	# Verifica se quem entrou na área foi o Player
	if body.name == "Player" and body.has_method("definir_novo_checkpoint"):
		# Passa a posição global deste checkpoint para o Player salvar
		body.definir_novo_checkpoint(global_position)
		
		# Desativa a colisão para o player não ficar ativando o mesmo checkpoint
		# toda vez que andar de um lado para o outro perto da árvore
		$CollisionShape2D.queue_free()
