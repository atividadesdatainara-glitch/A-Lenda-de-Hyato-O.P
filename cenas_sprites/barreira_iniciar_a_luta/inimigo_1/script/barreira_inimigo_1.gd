extends Area2D

var ativado : bool = false
@onready var gatilho = $CollisionShape2D
@onready var player = get_tree().current_scene.find_child("Player", true, false)

func _physics_process(_delta):
	if ativado or not is_instance_valid(player): return
	
	if player.global_position.x > global_position.x:
		ativar_bloqueio()

func colocar_parede():
	var nova_parede = StaticBody2D.new()
	nova_parede.name = "ParedeCriadaFisica"
	var formato_colisao = CollisionShape2D.new()
	
	formato_colisao.shape = gatilho.shape
	nova_parede.add_child(formato_colisao)
	add_child(nova_parede)

func ativar_bloqueio():
	ativado = true
	colocar_parede()
	
	var fase_atual = get_tree().current_scene
	var boss = fase_atual.find_child("Inimigo 1", true, false)
	if not boss:
		boss = fase_atual.get_node_or_null("Inimigo 1")
		
	if boss and boss.has_method("surgir_na_arena"):
		boss.surgir_na_arena()
	
	set_physics_process(false)

func resetar_barreira():
	ativado = false
	var parede_velha = get_node_or_null("ParedeCriadaFisica")
	if parede_velha:
		parede_velha.free() # Remove imediatamente da árvore de nós
	set_physics_process(true)
