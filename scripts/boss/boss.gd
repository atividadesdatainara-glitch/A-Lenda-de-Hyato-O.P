extends CharacterBody2D

# Configurações do Boss
const SPEED = 45.0
const ATTACK_RANGE = 130.0 # Range maior para o Boss
var health = 50
var is_dead = false
var is_attacking = false
var is_taking_damage = false
var pode_atacar = true
var boss_ativado = false

@onready var sprite = $AnimatedSprite2D
@onready var player = get_tree().current_scene.find_child("Player", true, false)

func _ready():
	# O Boss fica no seu próprio grupo
	add_to_group("boss")
	# Ele começa no estado flutuante
	sprite.play("floating")

func _physics_process(delta):
	if is_dead or is_taking_damage:
		return

	# REGRA DE ATIVAÇÃO:
	# O Boss verifica se ainda existem nós no grupo "inimigos"
	# (Certifica-te que os scripts do Inimigo 1 e 2 têm: add_to_group("inimigos"))
	var inimigos_vivos = get_tree().get_nodes_in_group("inimigos")
	
	if inimigos_vivos.size() > 0:
		boss_ativado = false
		sprite.play("floating") # Fica apenas a observar
		return
	else:
		if not boss_ativado:
			boss_ativado = true
			print("Inimigos derrotados! O Boss entrou na luta!")

	# LÓGICA DE COMBATE (Só corre se boss_ativado for true)
	if is_attacking:
		move_and_slide()
		return

	# Gravidade
	if not is_on_floor():
		velocity.y += 980 * delta

	if player:
		var dist = global_position.distance_to(player.global_position)
		var direction = sign(player.global_position.x - global_position.x)
		
		sprite.flip_h = direction > 0

		if dist <= ATTACK_RANGE and pode_atacar:
			velocity.x = 0
			executar_ataque_boss()
		elif dist > ATTACK_RANGE:
			velocity.x = direction * SPEED
			sprite.play("idle") # Ou "walk" se tiveres essa animação
		else:
			velocity.x = 0
			sprite.play("idle")

	move_and_slide()

func executar_ataque_boss():
	is_attacking = true
	pode_atacar = false
	sprite.play("attack1")
	
	# Sincronia: Ajusta o frame (ex: 10) para quando o golpe do Boss deve dar dano
	await espera_frame_especifico(10)
	
	if player and not is_dead:
		var dist_no_impacto = global_position.distance_to(player.global_position)
		if dist_no_impacto <= ATTACK_RANGE + 30:
			if player.has_method("levar_dano_do_inimigo"):
				player.levar_dano_do_inimigo()
	
	await sprite.animation_finished
	is_attacking = false
	
	# Tempo de espera entre ataques do Boss (3 segundos)
	await get_tree().create_timer(3.0).timeout
	pode_atacar = true

func espera_frame_especifico(frame_alvo):
	while sprite.animation == "attack1" and sprite.frame < frame_alvo and is_attacking:
		await get_tree().process_frame
		if sprite.animation != "attack1":
			break

func tomar_dano():
	if is_dead or not boss_ativado: return
	
	health -= 1
	is_taking_damage = true
	sprite.play("hurt")
	
	if health <= 0:
		morrer()
	else:
		await sprite.animation_finished
		is_taking_damage = false

func morrer():
	is_dead = true
	velocity.x = 0
	$CollisionShape2D.set_deferred("disabled", true)
	sprite.play("death")
	await sprite.animation_finished
	queue_free()
