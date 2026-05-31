extends Area2D

var ativado : bool = false
@onready var gatilho = $CollisionShape2D
@onready var player = get_tree().current_scene.find_child("Player", true, false)

func _physics_process(_delta):
	if ativado or not is_instance_valid(player): return
	if player.global_position.x > global_position.x:
		ativar_bloqueio()

func colocar_parede():
	var cena_atual = get_tree().current_scene

	# Cria UMA única parede física universal
	var parede_universal = StaticBody2D.new()
	# Usa o nome do próprio nó da barreira para evitar que as paredes de outros chefes conflitem
	parede_universal.name = "ParedeInvisivelArena_" + self.name
	
	# Ativa as camadas de 1 a 4. Isso garante que bloqueia Player (1) e Boss (3)
	for i in range(1, 5):
		parede_universal.set_collision_layer_value(i, true)
	
	# Paredes estáticas não precisam rastrear máscaras (pode zerar todas)
	for i in range(1, 5):
		parede_universal.set_collision_mask_value(i, false)
	
	# Configura o formato baseado no seu gatilho do editor
	var formato = CollisionShape2D.new()
	formato.shape = gatilho.shape
	formato.global_position = gatilho.global_position
	
	parede_universal.add_child(formato)
	cena_atual.add_child(parede_universal) # Adiciona na raiz para estabilidade total

func ativar_bloqueio():
	ativado = true
	colocar_parede()
	
	var fase_atual = get_tree().current_scene
	var boss = fase_atual.find_child("Inimigo 3", true, false)
	if not boss:
		boss = fase_atual.get_node_or_null("Inimigo 3")
		
	if boss and boss.has_method("surgir_na_arena"):
		boss.surgir_na_arena()
	else:
		print("ERRO: Inimigo 3 não encontrado!")
	set_physics_process(false)

func resetar_barreira():
	ativado = false
	var cena_atual = get_tree().current_scene
	
	# Procura especificamente a parede criada por ESTA barreira
	var parede = cena_atual.get_node_or_null("ParedeInvisivelArena_" + self.name)
	if parede:
		parede.queue_free() # queue_free() evita crashes durante a simulação física
		
	set_physics_process(true)
