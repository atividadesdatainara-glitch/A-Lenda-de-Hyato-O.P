extends CharacterBody2D

const SPEED = 50.0          
const ATTACK_RANGE = 100.0 
var health = 20             
var is_dead = false
var is_emerging = true
var is_attacking = false
var is_taking_damage = false 
var pode_atacar = true 

@onready var sprite = $AnimatedSprite2D
@onready var player = get_tree().current_scene.find_child("Player", true, false)

func _ready():
	add_to_group("inimigos")
	is_dead = false
	is_emerging = true
	
	# Garante que a gravidade comece do zero e limpa qualquer trava de escala
	velocity = Vector2.ZERO
	
	if sprite.sprite_frames.has_animation("emerging"):
		sprite.play("emerging")
		if not sprite.animation_finished.is_connected(_on_emerging_finished):
			sprite.animation_finished.connect(_on_emerging_finished)

func _on_emerging_finished():
	if sprite.animation == "emerging":
		is_emerging = false

func _physics_process(delta):
	if is_dead: return 

	# 1. GRAVIDADE BRUTA E DIAGNÓSTICO
	# Aumentei a gravidade para 3000 para garantir que ele caia rápido
	if not is_on_floor():
		velocity.y += 3000 * delta
	else:
		velocity.y = 10 # Pressão no chão

	# PRINT DE TESTE: Se ele estiver parado, veja se esses números mudam no Output
	if Engine.get_frames_drawn() % 60 == 0:
		print("Inimigo 2 - Pos Y: ", global_position.y, " | No chão: ", is_on_floor())

	# 2. LOGICA DE MOVIMENTO
	if is_emerging:
		velocity.x = 0
		# Durante o emerging, o move_and_slide PRECISA rodar sozinho
	elif is_taking_damage or is_attacking:
		velocity.x = 0
	elif player:
		var dist_x = abs(global_position.x - player.global_position.x)
		var direction = sign(player.global_position.x - global_position.x)
		if direction != 0: sprite.flip_h = direction > 0 

		if dist_x <= ATTACK_RANGE and pode_atacar:
			executar_ataque_inimigo()
		elif dist_x > ATTACK_RANGE:
			velocity.x = direction * SPEED
			if sprite.animation != "walk": sprite.play("walk")
		else:
			velocity.x = 0
			if sprite.animation != "idle": sprite.play("idle")

	# 3. O COMANDO QUE FAZ CAIR (Movido para o final para garantir execução)
	move_and_slide()

# --- Funções de Combate ---
func executar_ataque_inimigo():
	is_attacking = true
	pode_atacar = false 
	sprite.play("attack1")
	await espera_frame_especifico(9) 
	if is_attacking and not is_dead and player:
		if abs(global_position.x - player.global_position.x) <= ATTACK_RANGE + 30:
			player.levar_dano_do_inimigo()
	if sprite.animation == "attack1":
		await sprite.animation_finished
	is_attacking = false
	await get_tree().create_timer(2.0).timeout
	pode_atacar = true

func espera_frame_especifico(frame_alvo):
	while is_instance_valid(sprite) and sprite.animation == "attack1" and sprite.frame < frame_alvo and is_attacking:
		await get_tree().process_frame

func tomar_dano():
	if is_dead or is_emerging: return
	health -= 1
	is_attacking = false
	is_taking_damage = true
	sprite.modulate = Color(10, 10, 10) 
	if health <= 0:
		morrer()
		return
	await get_tree().create_timer(0.2).timeout
	sprite.modulate = Color(1, 1, 1)
	is_taking_damage = false

func morrer():
	if is_dead: return
	is_dead = true
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	sprite.play("death")
	await sprite.animation_finished
	queue_free()
