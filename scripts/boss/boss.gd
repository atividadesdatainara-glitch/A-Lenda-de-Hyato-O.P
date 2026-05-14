extends CharacterBody2D

const SPEED_AR = 160.0
const SPEED_CHAO = 120.0
const ATTACK_HIT_RANGE_X = 160.0
const ATTACK_HIT_RANGE_Y = 55.0

const DIST_ATAQUE = 105.0
const DIST_RECUO_ALVO = 220.0
const DIST_RECUO_CURTO = 110.0       # Recuo Curto: metade do recuo normal
const ALTURA_FLUTUACAO = -150.0
const TEMPO_FLUTUANDO = 2.0
const TEMPO_NO_CHAO = 4.0

# Cooldowns de ataque separados por padrão
const COOLDOWN_NORMAL = 1.2
const COOLDOWN_DUPLO = 1.8           # Ataque Duplo: mais longo pois são 2 golpes
const COOLDOWN_PRESSAO = 0.4         # Pressão por HP: bem curto
const COOLDOWN_TRIPLO = 2.2          # Ataque Triplo: mais longo pois são 3 golpes
const COOLDOWN_ARCO = 1.5            # Ciclo de Pressão Aérea

const SPEED_AVANCO = 340.0           # Avanço Rápido: dobro da velocidade normal
const TEMPO_PARADO_REATIVO = 1.0     # Ataque Reativo: tempo que player fica parado

var health = 50
var is_dead = false
var is_attacking = false
var is_taking_damage = false
var pode_atacar = true
var boss_ativado = false
var modo_chao = false

var altura_base_chao = 0.0
var flutuacao_tempo = 0.0
var flutuacao_offset = 0.0
var flutuacao_vel_x = 0.0

# Controle de padrões
var ultimo_ataque = ""              # guarda qual padrão foi usado por último
var recuo_invertido_ativo = false   # flag do Recuo Invertido
var recuo_curto_ativo = false       # flag do Recuo Curto
var avanco_ativo = false            # flag do Avanço Rápido
var timer_player_parado = 0.0      # Ataque Reativo: acumula tempo que player fica parado
var last_player_pos_x = 0.0        # Ataque Reativo: posição anterior do player
var arco_fase = 0                   # Ciclo de Pressão Aérea: 0=subindo, 1=cruzando

enum Estado { ESPERANDO, APROXIMANDO, ATACANDO, RECUANDO, FLUTUANDO }
var estado_atual = Estado.ESPERANDO
var timer_estado = 0.0
var timer_modo = 0.0

@onready var sprite = $AnimatedSprite2D
@onready var player = get_tree().current_scene.find_child("Player", true, false)
@onready var barra = $lifebar

func _ready():
	add_to_group("boss")
	sprite.play("floating")
	sprite.flip_h = true
	if player:
		altura_base_chao = player.global_position.y

func _physics_process(delta):
	if is_dead: return

	flutuacao_tempo += delta
	flutuacao_offset = sin(flutuacao_tempo * 1.2) * 14.0

	if is_attacking:
		if is_instance_valid(player):
			var diff_x = player.global_position.x - global_position.x
			var direction = sign(diff_x)
			var speed = SPEED_CHAO if modo_chao else SPEED_AR
			flutuacao_vel_x = lerp(flutuacao_vel_x, direction * speed * 0.8, delta * 4.0)
			velocity.x = flutuacao_vel_x
			if modo_chao:
				if not is_on_floor():
					velocity.y += 980 * delta
			else:
				var altura_alvo = altura_base_chao - 40 + flutuacao_offset
				velocity.y = lerp(velocity.y, (altura_alvo - global_position.y) * 6.0, delta * 4.0)
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

	if modo_chao and not is_on_floor():
		velocity.y += 980 * delta

	timer_estado += delta
	timer_modo += delta

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

	# Ataque Reativo: detecta se player ficou parado tempo suficiente
	if abs(player.global_position.x - last_player_pos_x) < 5.0:
		timer_player_parado += delta
	else:
		timer_player_parado = 0.0
	last_player_pos_x = player.global_position.x

	if timer_player_parado >= TEMPO_PARADO_REATIVO and pode_atacar and dist_x <= DIST_ATAQUE * 2.5:
		timer_player_parado = 0.0
		_escolher_ataque()
		return

	# Avanço Rápido: se player estiver muito longe, dobra a velocidade por um burst
	var speed = SPEED_CHAO if modo_chao else SPEED_AR
	if dist_x > DIST_ATAQUE * 3.0 and not avanco_ativo and pode_atacar:
		avanco_ativo = true
		get_tree().create_timer(1.0).timeout.connect(func(): avanco_ativo = false)

	if avanco_ativo:
		speed = SPEED_AVANCO

	if dist_x > DIST_ATAQUE + 8:
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
		if sprite.animation != "walk": sprite.play("walk")
	else:
		var altura_alvo = altura_base_chao - 40 + flutuacao_offset
		velocity.y = lerp(velocity.y, (altura_alvo - global_position.y) * 6.0, delta * 4.0)
		if sprite.animation != "floating": sprite.play("floating")

	# --- Ataque em Movimento: player chegou perto demais durante a aproximação ---
	if dist_x < DIST_ATAQUE * 0.6 and pode_atacar:
		_escolher_ataque()
		return

	if dist_x <= DIST_ATAQUE and pode_atacar:
		_escolher_ataque()

func _estado_recuando(delta):
	var diff_x = player.global_position.x - global_position.x
	var direction = sign(diff_x)
	var dist_x = abs(diff_x)

	flutuacao_vel_x = lerp(flutuacao_vel_x, -direction * SPEED_AR * 1.2, delta * 5.0)
	velocity.x = flutuacao_vel_x

	var altura_alvo = altura_base_chao + ALTURA_FLUTUACAO + flutuacao_offset
	velocity.y = lerp(velocity.y, (altura_alvo - global_position.y) * 7.0, delta * 4.0)

	sprite.flip_h = velocity.x < 0
	if sprite.animation != "floating": sprite.play("floating")

	# Recuo Curto: para mais cedo e já vai atacar de novo
	var dist_alvo = DIST_RECUO_CURTO if recuo_curto_ativo else DIST_RECUO_ALVO

	if dist_x >= dist_alvo:
		recuo_curto_ativo = false
		timer_estado = 0.0
		estado_atual = Estado.FLUTUANDO

func _estado_flutuando(delta):
	var diff_x = player.global_position.x - global_position.x
	var direction = sign(diff_x)

	sprite.flip_h = direction < 0

	# Perseguição Agressiva: se player chegar perto, cancela o float
	var dist_x = abs(diff_x)
	if dist_x < DIST_ATAQUE * 1.3 and pode_atacar:
		timer_estado = 0.0
		flutuacao_vel_x = 0.0
		estado_atual = Estado.APROXIMANDO
		return

	var balanco = sin(flutuacao_tempo * 1.0) * 25.0
	flutuacao_vel_x = lerp(flutuacao_vel_x, balanco, delta * 1.5)
	velocity.x = flutuacao_vel_x

	var altura_alvo = altura_base_chao + ALTURA_FLUTUACAO + flutuacao_offset
	velocity.y = lerp(velocity.y, (altura_alvo - global_position.y) * 4.0, delta * 2.0)

	if sprite.animation != "floating": sprite.play("floating")

	# Pausa Falsa: para completamente por um instante antes de avançar de repente
	if timer_estado >= TEMPO_FLUTUANDO - 0.5 and timer_estado < TEMPO_FLUTUANDO:
		flutuacao_vel_x = lerp(flutuacao_vel_x, 0.0, delta * 8.0)
		velocity.x = flutuacao_vel_x

	if timer_estado >= TEMPO_FLUTUANDO:
		timer_estado = 0.0
		flutuacao_vel_x = 0.0
		estado_atual = Estado.APROXIMANDO

# --- Escolha de padrão de ataque ---
func _escolher_ataque():
	# Pressão por HP: abaixo de 5 HP, força ataque rápido sempre
	if health <= 20:
		_executar_ataque_pressao()
		return

	# Sorteio dos padrões disponíveis, evita repetir o mesmo duas vezes seguidas
	var opcoes = ["normal", "duplo", "recuo_invertido", "recuo_curto", "triplo", "flanquear", "arco_aereo"]
	opcoes.erase(ultimo_ataque)  # remove o último usado pra não repetir

	# Triplo só abaixo de 3 HP
	if health > 10:
		opcoes.erase("triplo")

	var escolha = opcoes[randi() % opcoes.size()]
	ultimo_ataque = escolha

	match escolha:
		"normal":
			executar_ataque_boss()
		"duplo":
			_executar_ataque_duplo()
		"recuo_invertido":
			_executar_recuo_invertido()
		"recuo_curto":
			recuo_curto_ativo = true
			executar_ataque_boss()
		"triplo":
			_executar_ataque_triplo()
		"flanquear":
			_executar_flanqueamento()
		"arco_aereo":
			_executar_arco_aereo()

# --- Padrão: Ataque Normal (original) ---
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

	var cooldown = COOLDOWN_PRESSAO if health <= 5 else COOLDOWN_NORMAL
	await get_tree().create_timer(cooldown).timeout
	pode_atacar = true

# --- Padrão: Ataque Duplo (dois golpes seguidos) ---
func _executar_ataque_duplo():
	is_attacking = true
	pode_atacar = false
	estado_atual = Estado.ATACANDO
	velocity = Vector2.ZERO
	flutuacao_vel_x = 0.0

	var diff_x = player.global_position.x - global_position.x
	sprite.flip_h = diff_x < 0

	# Primeiro golpe
	sprite.play("attack1")
	sprite.frame = 0
	await espera_frame_especifico(4)

	if is_instance_valid(player) and not is_dead and is_attacking:
		var diff_x_now = player.global_position.x - global_position.x
		var diff_y_now = player.global_position.y - global_position.y
		var player_na_frente = (sprite.flip_h and diff_x_now < 0) or (not sprite.flip_h and diff_x_now > 0)
		if player_na_frente and abs(diff_x_now) <= ATTACK_HIT_RANGE_X and abs(diff_y_now) <= ATTACK_HIT_RANGE_Y:
			player.levar_dano_do_boss()

	await get_tree().create_timer(0.3).timeout
	if is_dead: return

	# Segundo golpe (mais curto, mais rápido)
	sprite.play("attack1")
	sprite.frame = 0
	await espera_frame_especifico(4)

	if is_instance_valid(player) and not is_dead and is_attacking:
		var diff_x_now = player.global_position.x - global_position.x
		var diff_y_now = player.global_position.y - global_position.y
		var player_na_frente = (sprite.flip_h and diff_x_now < 0) or (not sprite.flip_h and diff_x_now > 0)
		if player_na_frente and abs(diff_x_now) <= ATTACK_HIT_RANGE_X and abs(diff_y_now) <= ATTACK_HIT_RANGE_Y:
			player.levar_dano_do_boss()

	await get_tree().create_timer(0.6).timeout

	is_attacking = false
	if is_dead: return

	timer_estado = 0.0
	estado_atual = Estado.RECUANDO

	await get_tree().create_timer(COOLDOWN_DUPLO).timeout
	pode_atacar = true

# --- Padrão: Recuo Invertido (não recua, ataca de novo na hora) ---
func _executar_recuo_invertido():
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

	await get_tree().create_timer(0.5).timeout

	is_attacking = false
	if is_dead: return

	# Não recua: volta direto pra APROXIMANDO com cooldown curto
	timer_estado = 0.0
	estado_atual = Estado.APROXIMANDO

	await get_tree().create_timer(0.5).timeout
	pode_atacar = true

# --- Padrão: Pressão por HP (ataque acelerado abaixo de 5 HP) ---
func _executar_ataque_pressao():
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

	await get_tree().create_timer(0.5).timeout

	is_attacking = false
	if is_dead: return

	timer_estado = 0.0
	# Pressão: alterna entre não recuar e recuo curto pra manter pressão constante
	if randi() % 2 == 0:
		estado_atual = Estado.APROXIMANDO
	else:
		recuo_curto_ativo = true
		estado_atual = Estado.RECUANDO

	await get_tree().create_timer(COOLDOWN_PRESSAO).timeout
	pode_atacar = true

# --- Padrão: Ataque Triplo (só abaixo de 3 HP) ---
func _executar_ataque_triplo():
	is_attacking = true
	pode_atacar = false
	estado_atual = Estado.ATACANDO
	velocity = Vector2.ZERO
	flutuacao_vel_x = 0.0

	var diff_x = player.global_position.x - global_position.x
	sprite.flip_h = diff_x < 0

	for i in 3:
		if is_dead: return
		sprite.play("attack1")
		sprite.frame = 0
		await espera_frame_especifico(4)

		if is_instance_valid(player) and not is_dead and is_attacking:
			var diff_x_now = player.global_position.x - global_position.x
			var diff_y_now = player.global_position.y - global_position.y
			var player_na_frente = (sprite.flip_h and diff_x_now < 0) or (not sprite.flip_h and diff_x_now > 0)
			if player_na_frente and abs(diff_x_now) <= ATTACK_HIT_RANGE_X and abs(diff_y_now) <= ATTACK_HIT_RANGE_Y:
				player.levar_dano_do_boss()

		if i < 2:
			await get_tree().create_timer(0.25).timeout

	await get_tree().create_timer(0.6).timeout

	is_attacking = false
	if is_dead: return

	timer_estado = 0.0
	estado_atual = Estado.RECUANDO

	await get_tree().create_timer(COOLDOWN_TRIPLO).timeout
	pode_atacar = true

# --- Padrão: Flanqueamento (passa pelo player e ataca de trás) ---
func _executar_flanqueamento():
	is_attacking = true
	pode_atacar = false
	estado_atual = Estado.ATACANDO
	flutuacao_vel_x = 0.0

	if not is_instance_valid(player) or is_dead:
		is_attacking = false
		estado_atual = Estado.RECUANDO
		return

	# Fase 1: avança rápido passando pelo player
	var diff_x = player.global_position.x - global_position.x
	var direction = sign(diff_x)
	sprite.flip_h = direction < 0
	if sprite.animation != "floating": sprite.play("floating")

	var tempo_cruzando = 0.0
	while tempo_cruzando < 0.4 and not is_dead:
		flutuacao_vel_x = lerp(flutuacao_vel_x, direction * SPEED_AVANCO, 0.016 * 10.0)
		velocity.x = flutuacao_vel_x
		var altura_alvo = altura_base_chao - 40 + flutuacao_offset
		velocity.y = lerp(velocity.y, (altura_alvo - global_position.y) * 6.0, 0.016 * 4.0)
		move_and_slide()
		await get_tree().process_frame
		tempo_cruzando += get_process_delta_time()

	if is_dead: return

	# Fase 2: vira pro lado oposto e ataca
	sprite.flip_h = not sprite.flip_h
	flutuacao_vel_x = 0.0
	velocity.x = 0.0

	sprite.play("attack1")
	sprite.frame = 0
	await espera_frame_especifico(4)

	if is_instance_valid(player) and not is_dead and is_attacking:
		var diff_x_now = player.global_position.x - global_position.x
		var diff_y_now = player.global_position.y - global_position.y
		# hitbox invertida: agora ataca quem estiver atrás
		if abs(diff_x_now) <= ATTACK_HIT_RANGE_X and abs(diff_y_now) <= ATTACK_HIT_RANGE_Y:
			player.levar_dano_do_boss()

	await get_tree().create_timer(0.6).timeout

	is_attacking = false
	if is_dead: return

	timer_estado = 0.0
	estado_atual = Estado.RECUANDO

	await get_tree().create_timer(COOLDOWN_NORMAL).timeout
	pode_atacar = true

# --- Padrão: Ciclo de Pressão Aérea (arco pelo alto, ataca pelo outro lado, recua normalmente) ---
func _executar_arco_aereo():
	is_attacking = true
	pode_atacar = false
	estado_atual = Estado.ATACANDO
	flutuacao_vel_x = 0.0

	if not is_instance_valid(player) or is_dead:
		is_attacking = false
		estado_atual = Estado.RECUANDO
		return

	var diff_x = player.global_position.x - global_position.x
	var direction = sign(diff_x)

	# Fase 1: sobe rápido pra bem acima do player
	var tempo_subindo = 0.0
	var altura_arco = altura_base_chao + ALTURA_FLUTUACAO - 80.0
	if sprite.animation != "floating": sprite.play("floating")

	while tempo_subindo < 0.5 and not is_dead:
		flutuacao_vel_x = lerp(flutuacao_vel_x, direction * SPEED_AR * 1.5, 0.016 * 5.0)
		velocity.x = flutuacao_vel_x
		velocity.y = lerp(velocity.y, (altura_arco - global_position.y) * 8.0, 0.016 * 5.0)
		move_and_slide()
		await get_tree().process_frame
		tempo_subindo += get_process_delta_time()

	if is_dead: return

	# Fase 2: cruza por cima e desce do outro lado atacando
	var tempo_cruzando = 0.0
	while tempo_cruzando < 0.5 and not is_dead:
		flutuacao_vel_x = lerp(flutuacao_vel_x, direction * SPEED_AVANCO, 0.016 * 6.0)
		velocity.x = flutuacao_vel_x
		var altura_alvo = altura_base_chao - 40 + flutuacao_offset
		velocity.y = lerp(velocity.y, (altura_alvo - global_position.y) * 6.0, 0.016 * 4.0)
		move_and_slide()
		await get_tree().process_frame
		tempo_cruzando += get_process_delta_time()

	if is_dead: return

	# Fase 3: ataca ao chegar do outro lado
	sprite.flip_h = not (direction < 0)
	flutuacao_vel_x = 0.0
	velocity.x = 0.0

	sprite.play("attack1")
	sprite.frame = 0
	await espera_frame_especifico(4)

	if is_instance_valid(player) and not is_dead and is_attacking:
		var diff_x_now = player.global_position.x - global_position.x
		var diff_y_now = player.global_position.y - global_position.y
		if abs(diff_x_now) <= ATTACK_HIT_RANGE_X and abs(diff_y_now) <= ATTACK_HIT_RANGE_Y:
			player.levar_dano_do_boss()

	await get_tree().create_timer(0.6).timeout

	is_attacking = false
	if is_dead: return

	# Recua normalmente após o arco
	timer_estado = 0.0
	estado_atual = Estado.RECUANDO

	await get_tree().create_timer(COOLDOWN_ARCO).timeout
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
	barra.atualizar_barra(health, 50)

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
