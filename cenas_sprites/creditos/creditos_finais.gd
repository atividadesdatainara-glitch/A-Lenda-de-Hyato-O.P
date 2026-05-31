extends Control

var velocidade_de_rolagem := 20.0
var tempo_para_acabar_os_creditos := 10.0 #em segundos

func _process(delta: float) -> void:
	$Label.position.y -= velocidade_de_rolagem * delta
	await get_tree().create_timer(tempo_para_acabar_os_creditos, false).timeout
