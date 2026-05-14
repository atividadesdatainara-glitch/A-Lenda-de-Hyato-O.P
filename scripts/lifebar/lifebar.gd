extends AnimatedSprite2D

func atualizar_barra(hp_atual: int, hp_maximo: int):
	# Garante que não divida por zero
	if hp_maximo <= 0: return
	
	# Calcula a porcentagem (0.0 a 1.0)
	var porcentagem = float(hp_atual) / float(hp_maximo)
	
	# Frame 0 é cheio (100%), Frame 10 é vazio (0%)
	# Usamos (1.0 - porcentagem) para inverter a lógica
	var frame_alvo = int((1.0 - porcentagem) * 10)
	
	# Trava o valor entre 0 e 10 para não dar erro
	frame = clampi(frame_alvo, 0, 10)
