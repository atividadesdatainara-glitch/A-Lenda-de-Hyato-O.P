extends StaticBody2D

# Aqui você arrasta o Boss da fase direto pelo Inspetor da Godot
@export var boss_da_fase : CharacterBody2D 

# Aqui você pode arrastar o Prêmio correspondente, se quiser liberar ele visualmente
@export var premio_da_fase : Node2D 

func _ready():
	# Desativamos o processamento normal, só precisamos do _process se o boss existir
	if not boss_da_fase:
		print("Aviso: Nenhum boss foi atribuído a esta barreira!")
		set_process(false)

func _process(_delta):
	# O segredo está aqui: if !is_instance_valid(boss_da_fase) verifica se o Boss deixou de existir
	if not is_instance_valid(boss_da_fase):
		liberar_caminho()

func liberar_caminho():
	print("O Boss morreu! Liberando a barreira e o prêmio.")
	
	# Se você colocou um prêmio, podemos fazer ele aparecer ou ficar coletável aqui
	if premio_da_fase:
		premio_da_fase.visible = true 
		# Se o prêmio tiver um CollisionShape2D para ser coletado, você ativa aqui:
		# premio_da_fase.get_node("CollisionShape2D").disabled = false

	# Deleta a barreira para o player poder passar
	queue_free()
