extends AnimatedSprite2D

var tween: Tween

func iniciar_cooldown(tempo_dash: float, tempo_recarga: float):
	# Cancela a animação anterior se o player der dash antes de terminar
	if tween and tween.is_running():
		tween.kill()
		
	tween = create_tween()
	
	# Passo 1: Esvazia a barra (vai do frame 0 ao 2) no tempo do dash
	tween.tween_method(atualizar_frame, 0.0, 2.0, tempo_dash)
	
	# Passo 2: Enche a barra (vai do frame 2 de volta ao 0) no tempo de recarga
	tween.tween_method(atualizar_frame, 2.0, 0.0, tempo_recarga)

# Função auxiliar para converter o valor decimal no frame exato
func atualizar_frame(valor: float):
	# Usamos round() em vez de int() direto. 
	# Isso garante que o frame 1 (metade) apareça direitinho durante o processo.
	frame = int(round(valor))
