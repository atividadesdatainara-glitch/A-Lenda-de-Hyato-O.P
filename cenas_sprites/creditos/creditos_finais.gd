extends Control

# Isso faz aparecer um campo no Inspector para você arrastar a cena do Menu
@export var cena_do_menu : PackedScene 

var velocidade_de_rolagem := 20
var tempo_para_acabar_os_creditos := 120

func _ready():
	# Verifica se você lembrou de colocar o menu no Inspector antes de ligar o timer
	if cena_do_menu:
		get_tree().create_timer(tempo_para_acabar_os_creditos).timeout.connect(voltar_para_o_menu)
	else:
		print("Aviso: Você esqueceu de arrastar a cena do menu no Inspector!")

func _process(delta: float) -> void:
	$Label.position.y -= velocidade_de_rolagem * delta

func _input(event):
	if event is InputEventKey and event.is_pressed():
		voltar_para_o_menu()

func voltar_para_o_menu():
	if cena_do_menu:
		# Mudança de cena usando a variável que você instanciou no Inspector
		get_tree().change_scene_to_packed(cena_do_menu)
