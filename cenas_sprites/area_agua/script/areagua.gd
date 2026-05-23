extends Area2D

func _on_body_entered(body: Node2D) -> void:
	# Isso vai printar no console embaixo o nome de QUALQUER coisa que cair na água
	print("Algo caiu na água: ", body.name)
	
	if body.name == "Player" and body.has_method("cair_na_agua"):
		print("O Player foi reconhecido! Chamando função...")
		body.cair_na_agua()
