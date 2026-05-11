extends CharacterBody2D

const SPEED_AR = 160.0
const SPEED_CHAO = 120.0
const ATTACK_HIT_RANGE_X = 160.0
const ATTACK_HIT_RANGE_Y = 55.0

const DIST_ATAQUE = 105.0
const DIST_RECUO_ALVO = 220.0
const ALTURA_FLUTUACAO = -150.0
const TEMPO_FLUTUANDO = 2.0
const TEMPO_NO_CHAO = 4.0      # quanto tempo fica andando no chão antes de voltar a voar

var health = 10
var is_dead = false
var is_attacking = false
var is_taking_damage = false
var pode_atacar = true
var boss_ativado = false
var modo_chao = false           # alterna entre voar e andar

var altura_base_chao = 0.0
var flutuacao_tempo = 0.0
var flutuacao_offset = 0.0
var flutuacao_vel_x = 0.0      # velocidade X suavizada para flutuar mais leve

enum Estado { ESPERANDO, APROXIMANDO, ATACANDO, RECUANDO, FLUTUANDO }
var estado_atual = Estado.ESPERANDO
var timer_estado = 0.0
var timer_modo = 0.0            # controla troca entre chão e ar

@onready var sprite = $AnimatedSprite2D
@onready var player = get_tree().current_scene.find_child("Player", true, false)

func _ready():
	add_to_group("boss")
	sprite.play("floating")
	sprite.flip_h = true
	if player:
		altura_base_chao = player.global_position.y

func _physics_process(delta):
	if is_dead: return

	flutuacao_tempo += delta
	# Oscilação mais lenta e suave
	flutuacao_offset = sin(flutuacao_tempo * 1.2) * 14.0

	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_taking_damage:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var inimigos_vivos = get_tree().get_nodes_in_group("inimigos")
	if inimigos_vivos.size() > 0:
		boss_ativado = false
		estado_atual = Estado.ESPERANDO
		velocity.x = 0
		velocity.y = (altura_base_chao + ALTURA_FLUTUACAO - global_position.y) * 4.0
		if sprite.animation != "floating": sprite.play("floating")
		move_and_slide()
		return
	else:
		if not boss_ativado:
			boss_ativado = true
			estado_atual = Estado.APROXIMANDO
			modo_chao = false

	if not player:
		move_and_slide()
		return

	if player.is_on_floor():
		altura_base_chao = player.global_position.y

	# Aplica gravidade quando no chão
	if modo_chao and not is_on_floor():
		velocity.y += 980 * delta

	timer_estado += delta
	timer_modo += delta

	# Alterna modo chão/ar a cada ciclo de FLUTUANDO
	# (só troca quando está flutuando, pra não interromper ataque)
	if estado_atual == Estado.FLUTUANDO and timer_modo >= TEMPO_NO_CHAO:
		modo_chao = !modo_chao
		timer_modo = 0.0

	match estado_atual:
		Estado.APROXIMANDO:
			_estado_aproximando(delta)
		Estado.RECUANDO:
			_estado_recuando(delta)
		Estado.FLUTUANDO:
			_estado_flutuando(delta)

	move_and_slide()

func _estado_aproximando(delta):
	var diff_x = player.global_position.x - global_position.x
	var dist_x = abs(diff_x)
	var direction = sign(diff_x)

	if dist_x > 20:
		sprite.flip_h = direction < 0

	var speed = SPEED_CHAO if modo_chao else SPEED_AR

	if dist_x > DIST_ATAQUE + 8:
		# Suaviza o movimento horizontal no ar
		if modo_chao:
			velocity.x = direction * speed
		else:
			flutuacao_vel_x = lerp(flutuacao_vel_x, direction * speed, delta * 3.0)
			velocity.x = flutuacao_vel_x
	elif dist_x < DIST_ATAQUE - 8:
		if modo_chao:
			velocity.x = -direction * speed
		else:
			flutuacao_vel_x = lerp(flutuacao_vel_x, -direction * speed, delta * 3.0)
			velocity.x = flutuacao_vel_x
	else:
		flutuacao_vel_x = lerp(flutuacao_vel_x, 0.0, delta * 4.0)
		velocity.x = flutuacao_vel_x

	if modo_chao:
		# No chão: anda normalmente
		if sprite.animation != "walk": sprite.play("walk")
	else:
		# No ar: desce suavemente em direção ao player
		var altura_alvo = altura_base_chao - 40 + flutuacao_offset
		velocity.y = lerp(velocity.y, (altura_alvo - global_position.y) * 6.0, delta * 4.0)
		if sprite.animation != "floating": sprite.play("floating")

	if dist_x <= DIST_ATAQUE and pode_atacar:
		executar_ataque_boss()

func _estado_recuando(delta):
	var diff_x = player.global_position.x - global_position.x
	var direction = sign(diff_x)
	var dist_x = abs(diff_x)

	# Recuo sempre no ar
	flutuacao_vel_x = lerp(flutuacao_vel_x, -direction * SPEED_AR * 1.2, delta * 5.0)
	velocity.x = flutuacao_vel_x

	var altura_alvo = altura_base_chao + ALTURA_FLUTUACAO + flutuacao_offset
	velocity.y = lerp(velocity.y, (altura_alvo - global_position.y) * 7.0, delta * 4.0)

	sprite.flip_h = velocity.x < 0
	if sprite.animation != "floating": sprite.play("floating")

	if dist_x >= DIST_RECUO_ALVO:
		timer_estado = 0.0
		estado_atual = Estado.FLUTUANDO

func _estado_flutuando(delta):
	var diff_x = player.global_position.x - global_position.x
	var direction = sign(diff_x)

	sprite.flip_h = direction < 0

	# Balanço leve no ar enquanto flutua
	var balanco = sin(flutuacao_tempo * 1.0) * 25.0
	flutuacao_vel_x = lerp(flutuacao_vel_x, balanco, delta * 1.5)
	velocity.x = flutuacao_vel_x

	var altura_alvo = altura_base_chao + ALTURA_FLUTUACAO + flutuacao_offset
	velocity.y = lerp(velocity.y, (altura_alvo - global_position.y) * 4.0, delta * 2.0)

	if sprite.animation != "floating": sprite.play("floating")

	if timer_estado >= TEMPO_FLUTUANDO:
		timer_estado = 0.0
		flutuacao_vel_x = 0.0
		estado_atual = Estado.APROXIMANDO

func executar_ataque_boss():
	is_attacking = true
	pode_atacar = false
	estado_atual = Estado.ATACANDO
	velocity = Vector2.ZERO
	flutuacao_vel_x = 0.0

	var diff_x = player.global_position.x - global_position.x
	sprite.flip_h = diff_x < 0

	sprite.play("attack1")
	sprite.frame = 0

	await espera_frame_especifico(4)

	if is_instance_valid(player) and not is_dead and is_attacking:
		var diff_x_now = player.global_position.x - global_position.x
		var diff_y_now = player.global_position.y - global_position.y
		var player_na_frente = (sprite.flip_h and diff_x_now < 0) or (not sprite.flip_h and diff_x_now > 0)

		if player_na_frente and abs(diff_x_now) <= ATTACK_HIT_RANGE_X and abs(diff_y_now) <= ATTACK_HIT_RANGE_Y:
			player.levar_dano_do_boss()

	await get_tree().create_timer(0.8).timeout

	is_attacking = false
	if is_dead: return

	timer_estado = 0.0
	estado_atual = Estado.RECUANDO

	await get_tree().create_timer(1.2).timeout
	pode_atacar = true

func espera_frame_especifico(frame_alvo):
	var timeout = 0
	while is_instance_valid(sprite) and sprite.animation == "attack1":
		if sprite.frame >= frame_alvo: return
		await get_tree().process_frame
		timeout += 1
		if timeout > 60: break

func tomar_dano():
	if is_dead: return
	health -= 1

	if health <= 0:
		morrer()
		return

	sprite.modulate = Color(10, 0, 0)
	await get_tree().create_timer(0.08).timeout
	sprite.modulate = Color(1, 1, 1)

	if not is_attacking and not is_taking_damage:
		is_taking_damage = true
		estado_atual = Estado.RECUANDO
		timer_estado = 0.0
		flutuacao_vel_x = 0.0
		sprite.play("hurt")
		await get_tree().create_timer(0.5).timeout
		is_taking_damage = false

func morrer():
	is_dead = true
	is_attacking = false
	velocity = Vector2.ZERO
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	sprite.modulate = Color(1, 1, 1)
	sprite.play("death")
	await get_tree().create_timer(1.5).timeout
	queue_free()
