extends Node2D

# Esse é o slot que você vai preencher no Inspetor arrastando o arquivo .tscn
@export var inimigo2_scene : PackedScene 

func _ready():
	# Conecta o sinal que criamos no Autoload
	GameEvents.spawn_inimigo2.connect(_on_spawn_inimigo)

func _on_spawn_inimigo(posicao_morte):
	if inimigo2_scene:
		var i2 = inimigo2_scene.instantiate()
		add_child(i2) # Adiciona ele na fase
		
		# Coloca ele exatamente onde o Inimigo 1 morreu, 
		# mas um pouco mais alto (-100) para ele cair
		i2.global_position = posicao_morte + Vector2(0, -100)
		
		print("Inimigo 2 criado com sucesso na posição: ", i2.global_position)
	else:
		print("ERRO: Você esqueceu de arrastar o arquivo inimigo_2.tscn para o Inspetor do nó Tudo!")
