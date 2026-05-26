extends CharacterBody2D

# ── Velocidades ──────────────────────────────────────────────
const SPEED_AR       = 140.0
const SPEED_CHAO     = 115.0
const SPEED_AVANCO   = 280.0

# ── Hitbox ───────────────────────────────────────────────────
const ATTACK_HIT_RANGE_X = 140.0
const ATTACK_HIT_RANGE_Y = 60.0

# ── Distâncias ───────────────────────────────────────────────
const DIST_ATAQUE      = 115.0
const DIST_RECUO_ALVO  = 175.0
const DIST_RECUO_CURTO = 85.0

# ── Flutuação ────────────────────────────────────────────────
const ALTURA_FLUTUACAO = -130.0

# ── Timings ──────────────────────────────────────────────────
const TEMPO_FLUTUANDO      = 1.6
const TEMPO_NO_CHAO        = 8.0
const COOLDOWN_NORMAL      = 1.1
const COOLDOWN_DUPLO       = 1.6
const COOLDOWN_TRIPLO      = 2.2
const COOLDOWN_ARCO        = 1.6
const TEMPO_PARADO_REATIVO = 1.6
const DELAY_ENTRADA        = 2.0

# ── Estado ───────────────────────────────────────────────────
enum Estado { ESPERANDO, APROXIMANDO, ATACANDO, RECUANDO, FLUTUANDO }
var estado_atual = Estado.ESPERANDO

var health          = 10
var is_dead         = false
var is_attacking    = false
var is_taking_damage= false
var pode_atacar     = true
var boss_ativado    = false
var modo_chao       = false
var morte_em_andamento = false

var altura_base_chao = 0.0
var flutuacao_tempo  = 0.0
var flutuacao_offset = 0.0
var flutuacao_vel_x  = 0.0

var ultimo_ataque        = ""
var recuo_curto_ativo    = false
var avanco_ativo         = false
var timer_player_parado  = 0.0
var last_player_pos_x    = 0.0
var delay_ativo          = false
var timer_delay          = 0.0
var timer_estado         = 0.0
var timer_modo           = 0.0

# Suavização de entrada nos estados
var vel_x_suave = 0.0

@onready var sprite = $AnimatedSprite2D
@onready var player = get_tree().current_scene.find_child("Player", true, false)
@onready var barra  = $lifebar

# ═══════════════════════════════════════════════════════════════
func _ready():
	add_to_group("boss")
	visible      = false
	process_mode = Node.PROCESS_MODE_DISABLED

func surgir_na_arena():
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	if player and is_instance_valid(player):
		altura_base_chao = player.global_position.y
	sprite.play("floating")
	sprite.flip_h = true
	modo_chao     = false
	barra.modulate.a = 0
	delay_ativo   = true
	timer_delay   = 0.0
	estado_atual  = Estado.ESPERANDO

# ═══════════════════════════════════════════════════════════════
func _physics_process(delta):

	# ── Morte: cai pela gravidade até o TileMap ──────────────
	if morte_em_andamento:
		if not is_on_floor():
			velocity.y += 980.0 * delta
		else:
			velocity.y = 0.0
		velocity.x = 0.0
		move_and_slide()
		return

	if is_dead: return

	# ── Flutuação senoidal ───────────────────────────────────
	flutuacao_tempo  += delta
	flutuacao_offset  = sin(flutuacao_tempo * 0.9) * 12.0

	# ── Rastreia altura do chão pelo player ─────────────────
	if player and is_instance_valid(player) and player.is_on_floor():
		if boss_ativado:
			altura_base_chao = lerp(altura_base_chao, player.global_position.y, delta * 2.0)
		else:
			altura_base_chao = player.global_position.y

	# ── Delay de entrada ────────────────────────────────────
	if delay_ativo:
		_fase_delay(delta)
		return

	# ── Recebendo dano ──────────────────────────────────────
	if is_taking_damage:
		velocity.x = lerp(velocity.x, 0.0, delta * 6.0)
		velocity.y = lerp(velocity.y, 0.0, delta * 4.0)
		move_and_slide()
		return

	# ── Durante ataque: deriva suavemente em direção ao player
	if is_attacking:
		_deriva_durante_ataque(delta)
		move_and_slide()
		return

	if not boss_ativado or not is_instance_valid(player):
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if modo_chao and not is_on_floor():
		velocity.y += 980.0 * delta

	timer_estado += delta
	timer_modo   += delta

	# Alterna modo chão/ar
	if estado_atual == Estado.FLUTUANDO and timer_modo >= TEMPO_NO_CHAO:
		modo_chao  = !modo_chao
		timer_modo = 0.0

	# Timer de player parado (só no APROXIMANDO)
	if estado_atual == Estado.APROXIMANDO:
		if abs(player.global_position.x - last_player_pos_x) < 5.0:
			timer_player_parado += delta
		else:
			timer_player_parado = 0.0
		last_player_pos_x = player.global_position.x
	else:
		timer_player_parado   = 0.0
		last_player_pos_x     = player.global_position.x

	match estado_atual:
		Estado.APROXIMANDO: _estado_aproximando(delta)
		Estado.RECUANDO:    _estado_recuando(delta)
		Estado.FLUTUANDO:   _estado_flutuando(delta)
		Estado.ATACANDO:
			if not is_attacking:
				timer_estado = 0.0
				estado_atual = Estado.RECUANDO

	move_and_slide()

# ── Delay de entrada na arena ────────────────────────────────
func _fase_delay(delta):
	timer_delay += delta
	var altura_alvo = altura_base_chao + ALTURA_FLUTUACAO + flutuacao_offset
	velocity.x = lerp(velocity.x, 0.0, delta * 3.0)
	velocity.y = lerp(velocity.y, (altura_alvo - global_position.y) * 3.0, delta * 2.0)
	if sprite.animation != "floating": sprite.play("floating")
	move_and_slide()
	if timer_delay >= DELAY_ENTRADA:
		delay_ativo  = false
		boss_ativado = true
		estado_atual = Estado.APROXIMANDO
		var tween = create_tween()
		tween.tween_property(barra, "modulate:a", 1.0, 1.0)

# ── Deriva leve enquanto está atacando ──────────────────────
func _deriva_durante_ataque(delta):
	if not is_instance_valid(player): return
	var diff_x  = player.global_position.x - global_position.x
	var dir     = sign(diff_x)
	flutuacao_vel_x = lerp(flutuacao_vel_x, dir * SPEED_AR * 0.3, delta * 1.5)
	velocity.x = flutuacao_vel_x
	if not modo_chao:
		var altura_alvo = altura_base_chao - 40.0 + flutuacao_offset
		velocity.y = lerp(velocity.y, (altura_alvo - global_position.y) * 3.5, delta * 2.5)

# ═══════════════════════════════════════════════════════════════
func _estado_aproximando(delta):
	if not is_instance_valid(player): return
	var diff_x = player.global_position.x - global_position.x
	var dist_x = abs(diff_x)
	var dir    = sign(diff_x)

	if dist_x > 30:
		sprite.flip_h = dir < 0

	# Ataque reativo se player ficou parado
	if timer_player_parado >= TEMPO_PARADO_REATIVO and pode_atacar and dist_x <= DIST_ATAQUE * 2.0:
		timer_player_parado = 0.0
		_escolher_ataque()
		return

	# Velocidade base
	var speed = SPEED_CHAO if modo_chao else SPEED_AR

	# Avanço rápido se muito distante
	if dist_x > DIST_ATAQUE * 3.0 and not avanco_ativo and pode_atacar:
		avanco_ativo = true
		get_tree().create_timer(1.0).timeout.connect(func(): avanco_ativo = false)
	if avanco_ativo:
		speed = SPEED_AVANCO

	# Velocidade alvo suavizada
	var vel_alvo = 0.0
	if dist_x > DIST_ATAQUE + 15.0:
		vel_alvo = dir * speed
	elif dist_x < DIST_ATAQUE - 15.0:
		vel_alvo = -dir * speed * 0.5

	if modo_chao:
		velocity.x = lerp(velocity.x, vel_alvo, delta * 5.0)
		if sprite.animation != ("walk" if vel_alvo != 0.0 else "floating"):
			sprite.play("walk" if vel_alvo != 0.0 else "floating")
	else:
		# No ar: suavização extra para parecer mais orgânico
		flutuacao_vel_x = lerp(flutuacao_vel_x, vel_alvo, delta * 2.0)
		velocity.x = flutuacao_vel_x
		var altura_alvo = altura_base_chao - 50.0 + flutuacao_offset
		velocity.y = lerp(velocity.y, (altura_alvo - global_position.y) * 4.0, delta * 2.5)
		if sprite.animation != "floating": sprite.play("floating")

	if dist_x <= DIST_ATAQUE and pode_atacar:
		_escolher_ataque()

# ═══════════════════════════════════════════════════════════════
func _estado_recuando(delta):
	if not is_instance_valid(player): return
	var diff_x = player.global_position.x - global_position.x
	var dir    = sign(diff_x)
	var dist_x = abs(diff_x)

	# Recua oposto ao player com curva suave
	flutuacao_vel_x = lerp(flutuacao_vel_x, -dir * SPEED_AR * 1.2, delta * 3.5)
	velocity.x      = flutuacao_vel_x
	var altura_alvo = altura_base_chao + ALTURA_FLUTUACAO + flutuacao_offset
	velocity.y      = lerp(velocity.y, (altura_alvo - global_position.y) * 4.5, delta * 2.5)
	sprite.flip_h   = dir < 0
	if sprite.animation != "floating": sprite.play("floating")

	var dist_alvo = DIST_RECUO_CURTO if recuo_curto_ativo else DIST_RECUO_ALVO
	if dist_x >= dist_alvo:
		recuo_curto_ativo = false
		timer_estado      = 0.0
		estado_atual      = Estado.FLUTUANDO

# ═══════════════════════════════════════════════════════════════
func _estado_flutuando(delta):
	if not is_instance_valid(player): return
	var diff_x = player.global_position.x - global_position.x
	var dir    = sign(diff_x)
	var dist_x = abs(diff_x)

	sprite.flip_h = dir < 0

	if dist_x < DIST_ATAQUE * 1.2 and pode_atacar:
		timer_estado    = 0.0
		flutuacao_vel_x = 0.0
		estado_atual    = Estado.APROXIMANDO
		return

	# Balanço suave de espera
	var balanco = sin(flutuacao_tempo * 0.7) * 15.0
	flutuacao_vel_x = lerp(flutuacao_vel_x, balanco, delta * 1.0)
	velocity.x      = flutuacao_vel_x
	var altura_alvo = altura_base_chao + ALTURA_FLUTUACAO + flutuacao_offset
	velocity.y      = lerp(velocity.y, (altura_alvo - global_position.y) * 3.0, delta * 2.0)
	if sprite.animation != "floating": sprite.play("floating")

	# Desacelera antes de acabar o tempo
	if timer_estado >= TEMPO_FLUTUANDO - 0.5:
		flutuacao_vel_x = lerp(flutuacao_vel_x, 0.0, delta * 10.0)
		velocity.x      = flutuacao_vel_x

	if timer_estado >= TEMPO_FLUTUANDO:
		timer_estado    = 0.0
		flutuacao_vel_x = 0.0
		estado_atual    = Estado.APROXIMANDO

# ═══════════════════════════════════════════════════════════════
func _escolher_ataque():
	if not pode_atacar or is_attacking: return
	pode_atacar = false

	var opcoes = ["normal", "duplo", "recuo_invertido", "flanquear"]
	opcoes.erase(ultimo_ataque)
	if health <= 5:
		opcoes.append("triplo")
		opcoes.append("arco_aereo")

	var escolha = opcoes[randi() % opcoes.size()]
	ultimo_ataque = escolha

	match escolha:
		"normal":          executar_ataque_boss()
		"duplo":           _executar_ataque_duplo()
		"recuo_invertido": _executar_recuo_invertido()
		"flanquear":       _executar_flanqueamento()
		"triplo":          _executar_ataque_triplo()
		"arco_aereo":      _executar_arco_aereo()

# ── Prepara qualquer ataque ──────────────────────────────────
func _preparar_ataque():
	is_attacking    = true
	pode_atacar     = false
	estado_atual    = Estado.ATACANDO
	flutuacao_vel_x = 0.0
	# Não zera velocity abruptamente — deixa desacelerar no _deriva
	if is_instance_valid(player):
		sprite.flip_h = (player.global_position.x - global_position.x) < 0

# ── Checagem de hit corrigida (flip_h = true → olhando esquerda)
func _checar_hit():
	if not is_instance_valid(player) or is_dead or not is_attacking: return
	var dx = player.global_position.x - global_position.x
	var dy = player.global_position.y - global_position.y
	var olhando_direita  = not sprite.flip_h
	var player_na_frente = (olhando_direita and dx > 0) or (not olhando_direita and dx < 0)
	if player_na_frente and abs(dx) <= ATTACK_HIT_RANGE_X and abs(dy) <= ATTACK_HIT_RANGE_Y:
		player.levar_dano_do_boss()

func _encerrar_ataque(proximo_estado: int):
	is_attacking = false
	if is_dead: return
	timer_estado = 0.0
	estado_atual = proximo_estado

func espera_frame_especifico(frame_alvo):
	var timeout = 0
	while is_instance_valid(sprite):
		if sprite.animation != "attack1": break
		if sprite.frame >= frame_alvo: return
		await get_tree().process_frame
		timeout += 1
		if timeout > 120: break

# ═══════════════════════════════════════════════════════════════
# ── ATAQUES ─────────────────────────────────────────────────
# ═══════════════════════════════════════════════════════════════

func executar_ataque_boss():
	_preparar_ataque()
	# Pequena pausa antes de atacar (antecipação)
	await get_tree().create_timer(0.12).timeout
	sprite.play("attack1")
	sprite.frame = 0
	await espera_frame_especifico(4)
	_checar_hit()
	await get_tree().create_timer(0.7).timeout
	_encerrar_ataque(Estado.RECUANDO)
	await get_tree().create_timer(COOLDOWN_NORMAL).timeout
	if not is_dead: pode_atacar = true

func _executar_ataque_duplo():
	_preparar_ataque()
	await get_tree().create_timer(0.1).timeout
	for i in 2:
		if is_dead or not is_attacking: break
		sprite.play("attack1")
		sprite.frame = 0
		await espera_frame_especifico(4)
		_checar_hit()
		if i < 1:
			await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(0.55).timeout
	_encerrar_ataque(Estado.RECUANDO)
	await get_tree().create_timer(COOLDOWN_DUPLO).timeout
	if not is_dead: pode_atacar = true

func _executar_recuo_invertido():
	_preparar_ataque()
	await get_tree().create_timer(0.1).timeout
	sprite.play("attack1")
	sprite.frame = 0
	await espera_frame_especifico(4)
	_checar_hit()
	await get_tree().create_timer(0.45).timeout
	_encerrar_ataque(Estado.APROXIMANDO)
	await get_tree().create_timer(0.6).timeout
	if not is_dead: pode_atacar = true

func _executar_ataque_triplo():
	_preparar_ataque()
	await get_tree().create_timer(0.1).timeout
	for i in 3:
		if is_dead or not is_attacking: break
		sprite.play("attack1")
		sprite.frame = 0
		await espera_frame_especifico(4)
		_checar_hit()
		if i < 2:
			await get_tree().create_timer(0.25).timeout
	await get_tree().create_timer(0.55).timeout
	_encerrar_ataque(Estado.RECUANDO)
	await get_tree().create_timer(COOLDOWN_TRIPLO).timeout
	if not is_dead: pode_atacar = true

func _executar_flanqueamento():
	_preparar_ataque()
	if not is_instance_valid(player) or is_dead:
		_encerrar_ataque(Estado.RECUANDO)
		await get_tree().create_timer(0.4).timeout
		if not is_dead: pode_atacar = true
		return

	var diff_x  = player.global_position.x - global_position.x
	var dir     = sign(diff_x)
	sprite.flip_h = dir < 0
	if sprite.animation != "floating": sprite.play("floating")

	# Aceleração progressiva até passar o player
	var tempo = 0.0
	while tempo < 0.4 and not is_dead and is_attacking:
		var d = get_process_delta_time()
		flutuacao_vel_x = lerp(flutuacao_vel_x, dir * SPEED_AVANCO, d * 12.0)
		velocity.x = flutuacao_vel_x
		var altura_alvo = altura_base_chao - 40.0 + flutuacao_offset
		velocity.y = lerp(velocity.y, (altura_alvo - global_position.y) * 5.0, d * 3.0)
		move_and_slide()
		await get_tree().process_frame
		tempo += d

	if is_dead: return

	# Vira e ataca
	sprite.flip_h   = not sprite.flip_h
	flutuacao_vel_x = 0.0
	velocity.x      = 0.0
	sprite.play("attack1")
	sprite.frame = 0
	await espera_frame_especifico(4)
	if is_instance_valid(player) and not is_dead and is_attacking:
		var dx = player.global_position.x - global_position.x
		var dy = player.global_position.y - global_position.y
		var olhando_direita  = not sprite.flip_h
		var player_na_frente = (olhando_direita and dx > 0) or (not olhando_direita and dx < 0)
		if player_na_frente and abs(dx) <= ATTACK_HIT_RANGE_X and abs(dy) <= ATTACK_HIT_RANGE_Y:
			player.levar_dano_do_boss()

	await get_tree().create_timer(0.55).timeout
	_encerrar_ataque(Estado.RECUANDO)
	await get_tree().create_timer(COOLDOWN_NORMAL).timeout
	if not is_dead: pode_atacar = true

func _executar_arco_aereo():
	_preparar_ataque()
	if not is_instance_valid(player) or is_dead:
		_encerrar_ataque(Estado.RECUANDO)
		await get_tree().create_timer(0.4).timeout
		if not is_dead: pode_atacar = true
		return

	var diff_x    = player.global_position.x - global_position.x
	var dir       = sign(diff_x)
	var altura_arco = altura_base_chao + ALTURA_FLUTUACAO - 60.0
	if sprite.animation != "floating": sprite.play("floating")

	# Sobe em arco
	var tempo = 0.0
	while tempo < 0.5 and not is_dead and is_attacking:
		var d = get_process_delta_time()
		flutuacao_vel_x = lerp(flutuacao_vel_x, dir * SPEED_AR * 1.3, d * 5.0)
		velocity.x = flutuacao_vel_x
		velocity.y = lerp(velocity.y, (altura_arco - global_position.y) * 7.0, d * 5.0)
		move_and_slide()
		await get_tree().process_frame
		tempo += d

	if is_dead: return

	# Mergulha em direção ao player
	tempo = 0.0
	while tempo < 0.5 and not is_dead and is_attacking:
		var d = get_process_delta_time()
		flutuacao_vel_x = lerp(flutuacao_vel_x, dir * SPEED_AVANCO, d * 6.0)
		velocity.x = flutuacao_vel_x
		var altura_alvo = altura_base_chao - 40.0 + flutuacao_offset
		velocity.y = lerp(velocity.y, (altura_alvo - global_position.y) * 6.0, d * 4.0)
		move_and_slide()
		await get_tree().process_frame
		tempo += d

	if is_dead: return

	sprite.flip_h   = not (dir < 0)
	flutuacao_vel_x = 0.0
	velocity.x      = 0.0
	sprite.play("attack1")
	sprite.frame = 0
	await espera_frame_especifico(4)
	if is_instance_valid(player) and not is_dead and is_attacking:
		var dx = player.global_position.x - global_position.x
		var dy = player.global_position.y - global_position.y
		var olhando_direita  = not sprite.flip_h
		var player_na_frente = (olhando_direita and dx > 0) or (not olhando_direita and dx < 0)
		if player_na_frente and abs(dx) <= ATTACK_HIT_RANGE_X and abs(dy) <= ATTACK_HIT_RANGE_Y:
			player.levar_dano_do_boss()

	await get_tree().create_timer(0.55).timeout
	_encerrar_ataque(Estado.RECUANDO)
	await get_tree().create_timer(COOLDOWN_ARCO).timeout
	if not is_dead: pode_atacar = true

# ═══════════════════════════════════════════════════════════════
func tomar_dano():
	if is_dead or morte_em_andamento: return
	health -= 1
	barra.atualizar_barra(health, 10)
	if health <= 0:
		morrer()
		return

	sprite.modulate = Color(10, 0, 0)
	await get_tree().create_timer(0.08).timeout
	if not is_dead: sprite.modulate = Color(1, 1, 1)

	if not is_attacking and not is_taking_damage and not is_dead:
		is_taking_damage = true
		timer_estado     = 0.0
		flutuacao_vel_x  = 0.0
		sprite.play("hurt")
		await get_tree().create_timer(0.4).timeout
		is_taking_damage = false
		if not is_attacking and not is_dead:
			estado_atual = Estado.RECUANDO

# ═══════════════════════════════════════════════════════════════
func morrer():
	if is_dead: return
	is_dead            = true
	is_attacking       = false
	pode_atacar        = false
	is_taking_damage   = false
	morte_em_andamento = true

	# ── Mantém apenas colisão com o TileMap (layer 1 e 2 na mask)
	# Remove layer própria para não interagir com outros
	set_collision_layer_value(3, false)  # tira da layer do boss
	# Mantém mask 1 e 2 para detectar o TileMap/chão
	set_collision_mask_value(3, false)   # não precisa mais interagir com outros inimigos
	# mask 1 e 2 já estavam ativas — o TileMap físico responde a elas

	var tween = create_tween()
	tween.tween_property(barra, "modulate:a", 0.0, 0.4)

	sprite.modulate = Color(1, 1, 1)
	velocity.x = 0.0
	velocity.y = 0.0

	# Aguarda pousar no TileMap com timeout de segurança
	var t = 0
	while not is_on_floor() and t < 300:
		await get_tree().process_frame
		t += 1

	morte_em_andamento = false
	velocity = Vector2.ZERO
	sprite.play("death")
	await sprite.animation_finished
	await get_tree().create_timer(0.5).timeout
	queue_free()
