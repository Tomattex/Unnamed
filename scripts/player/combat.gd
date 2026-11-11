extends Node

## Ataque basico y habilidades del jugador. Movement.gd lo llama cuando el
## objetivo esta en rango; aca se controla el ritmo de golpes y se aplica el daño.
## Las habilidades pegan segun su nivel (skill_book). Con un arma en cada mano
## los ataques basicos se alternan entre la derecha y la izquierda.

signal attack_started(interval: float)
signal skill_animation(anim_name: String, speed: float)

const FIREBALL := preload("res://scripts/skills/fireball.gd")
const BOLT := preload("res://scripts/skills/bolt.gd")
## Tras usar una habilidad, el ataque basico espera al menos este tiempo.
const SKILL_LOCKOUT: float = 0.5
## Pausa entre las habilidades de un combo.
const COMBO_STEP_DELAY: float = 0.55

## Momento del impacto dentro del intervalo de ataque (0 = inicio, 1 = fin).
const HIT_MOMENT: float = 0.45
## Margen extra de alcance al momento del impacto (el enemigo se puede alejar un poco).
const REACH_TOLERANCE: float = 1.3
## Color del rayo arcano del ataque basico del mago.
const ARCANE_COLOR := Color(0.55, 0.65, 1.0)
## Altura desde la que caen la lluvia de virotes y el meteoro.
const RAIN_HEIGHT: float = 1400.0

@onready var character: CharacterBody3D = get_parent()

var _cooldown: float = 0.0
## El proximo golpe basico con dos armas es de la mano izquierda.
var _offhand_next: bool = false


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func can_attack() -> bool:
	return _cooldown <= 0.0 and not player_stats.dead


func try_attack(target: Node3D) -> bool:
	if not can_attack():
		return false
	var interval: float = 1.0 / player_stats.get_attack_speed()
	_cooldown = interval
	var offhand: bool = _offhand_next and player_stats.is_dual_wielding()
	_offhand_next = not offhand and player_stats.is_dual_wielding()
	attack_started.emit(interval)
	_deliver_hit(target, interval * HIT_MOMENT, offhand)
	return true


## Usa la habilidad del slot indicado. aim_point es el punto del mouse en el
## piso y target el enemigo marcado (puede ser null segun la habilidad).
func use_skill(index: int, aim_point: Vector3, target: Node3D) -> bool:
	var skill: SkillData = skill_book.get_skill(index)
	if skill == null or not skill_book.is_ready(index) or player_stats.dead:
		return false
	skill_book.start_cooldown(index)
	_perform(skill, skill_book.get_level(index), aim_point, target)
	return true


## Ejecuta el combo armado: sus habilidades una detras de otra, con su propia
## recarga (no gasta la recarga de cada habilidad por separado).
func use_combo(aim_point: Vector3, target: Node3D) -> bool:
	if not skill_book.is_combo_ready() or player_stats.dead:
		return false
	skill_book.start_combo_cooldown()
	_run_combo(skill_book.combo.duplicate(), aim_point, target)
	return true


func _run_combo(indices: Array, aim_point: Vector3, target: Node3D) -> void:
	for i in indices.size():
		if player_stats.dead:
			return
		var skill: SkillData = skill_book.get_skill(indices[i])
		# Si el objetivo murio a mitad del combo, los golpes se saltean.
		var target_ok: bool = is_instance_valid(target) and not target.dead
		if skill.kind != SkillData.Kind.STRIKE or target_ok:
			var aim: Vector3 = target.global_position if target_ok else aim_point
			_perform(skill, skill_book.get_level(indices[i]), aim, target if target_ok else null)
		if i < indices.size() - 1:
			await get_tree().create_timer(COMBO_STEP_DELAY, false).timeout


func _perform(skill: SkillData, level: int, aim_point: Vector3, target: Node3D) -> void:
	_cooldown = maxf(_cooldown, SKILL_LOCKOUT)
	skill_animation.emit(skill.animation, skill.animation_speed)
	if not skill.sound.is_empty():
		sfx.play_at(skill.sound, character.global_position)
	# Los hechizos se ven al lanzarlos: sigilo en el piso y luz en las manos.
	if skill.spell:
		SpellFx.cast(character, skill.effect_color, 1.35 if skill.kind == SkillData.Kind.RAIN else 1.0)
	match skill.kind:
		SkillData.Kind.STRIKE:
			_strike(skill, level, target)
		SkillData.Kind.WHIRLWIND:
			_whirlwind(skill, level)
		SkillData.Kind.PROJECTILE:
			_fireball(skill, level, aim_point)
		SkillData.Kind.BUFF:
			_buff(skill, level)
		SkillData.Kind.VOLLEY:
			_volley(skill, level, aim_point)
		SkillData.Kind.RAIN:
			_rain(skill, level, aim_point)


func _strike(skill: SkillData, level: int, target: Node3D) -> void:
	await get_tree().create_timer(0.25, false).timeout
	if not is_instance_valid(target) or target.dead or player_stats.dead:
		return
	target.take_hit(_roll_skill_hit(skill, level))
	sfx.play_at("hit", target.global_position, 3.0)
	Effects.heavy_impact(character.get_parent(), target.global_position, skill.effect_color)


func _whirlwind(skill: SkillData, level: int) -> void:
	if skill.damage_type == Damage.Type.FIRE and not skill.spin:
		# Anillo de llamas: una ola de fuego que sale del lanzador.
		SpellFx.flame_nova(character.get_parent(), character.global_position, skill.radius)
	else:
		Effects.ring(character.get_parent(), character.global_position, skill.effect_color, skill.radius)
	if skill.spin:
		Effects.whirl(character, skill.effect_color, skill.radius * 0.8)
	elif skill.damage_type != Damage.Type.FIRE:
		Effects.shockwave(character.get_parent(), character.global_position, skill.effect_color, skill.radius, 0.45)
		Effects.dust_puff(character.get_parent(), character.global_position, skill.radius * 0.7)
	await get_tree().create_timer(0.2, false).timeout
	if player_stats.dead:
		return
	var hit_any: bool = false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector3 = enemy.global_position - character.global_position
		offset.y = 0.0
		if offset.length() <= skill.radius + enemy.body_radius():
			enemy.take_hit(_roll_skill_hit(skill, level))
			hit_any = true
	if hit_any:
		sfx.play_at("hit", character.global_position, 2.0)


func _fireball(skill: SkillData, level: int, aim_point: Vector3) -> void:
	var direction: Vector3 = aim_point - character.global_position
	direction.y = 0.0
	if direction.length() < 1.0:
		direction = character.global_transform.basis.z
	direction = direction.normalized()
	character.rotation.y = atan2(direction.x, direction.z)
	await get_tree().create_timer(0.2, false).timeout
	if player_stats.dead:
		return
	var ball: Node3D = FIREBALL.new()
	ball.direction = direction
	ball.skill = skill
	ball.skill_level = level
	ball.color = skill.effect_color
	Effects.add_at(character.get_parent(), ball, character.global_position + Vector3.UP * 220.0 + direction * 80.0)


# Virotes (o rayos) en abanico hacia el mouse; cada uno daña al primero que toca.
func _volley(skill: SkillData, level: int, aim_point: Vector3) -> void:
	var direction: Vector3 = aim_point - character.global_position
	direction.y = 0.0
	if direction.length() < 1.0:
		direction = character.global_transform.basis.z
	direction = direction.normalized()
	character.rotation.y = atan2(direction.x, direction.z)
	await get_tree().create_timer(0.15, false).timeout
	if player_stats.dead:
		return
	var count: int = skill.count_at(level)
	for i in count:
		var offset: float = 0.0 if count == 1 else lerpf(-skill.spread_deg, skill.spread_deg, float(i) / (count - 1)) / 2.0
		var bolt: Node3D = _make_bolt(direction.rotated(Vector3.UP, deg_to_rad(offset)), _roll_skill_hit(skill, level), skill.max_range)
		if skill.damage_type != Damage.Type.PHYSICAL:
			bolt.glow = skill.effect_color
		# Los hechizos (rayo arcano) son orbes de energia, no virotes.
		if skill.spell:
			bolt.orb = true
			bolt.orb_size = 1.3
			bolt.speed = 2100.0
		Effects.add_at(character.get_parent(), bolt, character.global_position + Vector3.UP * 230.0 + bolt.direction * 60.0)
	if not skill.spell:
		sfx.play_at("bow_shoot", character.global_position)


# Se marca el lugar, y al rato cae: virotes o un meteoro, con daño en area.
func _rain(skill: SkillData, level: int, aim_point: Vector3) -> void:
	var center := Vector3(aim_point.x, 0.0, aim_point.z)
	var parent: Node = character.get_parent()
	if skill.damage_type == Damage.Type.FIRE:
		SpellFx.meteor_mark(parent, center, skill.radius, skill.delay)
	else:
		Effects.ring(parent, center, skill.effect_color, skill.radius)
		Effects.ground_glow(parent, center + Vector3.UP * 4.0, Effects.GLOW, skill.effect_color, skill.radius * 2.0, skill.delay + 0.3)
	if skill.damage_type == Damage.Type.FIRE:
		# Meteoro: la bola de fuego cae desde arriba y explota al tocar el piso.
		var ball: Node3D = FIREBALL.new()
		# Entra en diagonal desde el fondo de la pantalla: asi se lo ve cruzar.
		ball.direction = (Vector3.DOWN * RAIN_HEIGHT + Vector3(-250.0, 0.0, -750.0)).normalized()
		ball.skill = skill
		ball.skill_level = level
		ball.color = skill.effect_color
		ball.travel = RAIN_HEIGHT / absf(ball.direction.y)
		ball.speed = ball.travel / maxf(skill.delay, 0.1)
		Effects.add_at(parent, ball, center - ball.direction * ball.travel)
		return
	# Lluvia de virotes: caen de a poco en el area y el daño entra todo junto.
	for i in skill.count_at(level):
		var spot: Vector2 = Vector2.from_angle(randf() * TAU) * sqrt(randf()) * skill.radius
		var bolt: Node3D = _make_bolt(Vector3(0.12, -1.0, 0.08).normalized(), {}, RAIN_HEIGHT * 1.02)
		bolt.harmless = true
		bolt.speed = RAIN_HEIGHT / maxf(skill.delay, 0.1)
		Effects.add_at(parent, bolt, center + Vector3(spot.x, 0.0, spot.y) - bolt.direction * RAIN_HEIGHT)
	await get_tree().create_timer(skill.delay, false).timeout
	if player_stats.dead:
		return
	Effects.dust_puff(parent, center, skill.radius * 0.6)
	var hit_any: bool = false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector3 = enemy.global_position - center
		offset.y = 0.0
		if not enemy.dead and offset.length() <= skill.radius + enemy.body_radius():
			enemy.take_hit(_roll_skill_hit(skill, level))
			hit_any = true
	if hit_any:
		sfx.play_at("hit", center, 2.0)


func _make_bolt(direction: Vector3, hit: Dictionary, max_range: float) -> Node3D:
	var bolt: Node3D = BOLT.new()
	bolt.direction = direction
	bolt.hit = hit
	bolt.max_range = max_range if max_range > 0.0 else character.ranged_attack_range + 400.0
	return bolt


## Tirada de daño de una habilidad a su nivel: hechizo o golpe con el arma.
func _roll_skill_hit(skill: SkillData, level: int) -> Dictionary:
	return player_stats.roll_skill(skill, level)


func _buff(skill: SkillData, level: int) -> void:
	player_stats.add_buff(skill.name, {
		"name": skill.name,
		"icon": skill.icon,
		"duration": skill.buff_duration_at(level),
		"damage_mult": skill.buff_damage_at(level),
		"attack_speed_mult": skill.buff_speed_at(level),
		"defense": skill.buff_defense_at(level),
		"resist": skill.buff_resistance_at(level),
	})
	Effects.aura(character.get_parent(), character.global_position, skill.effect_color)
	floating_text.spawn(character.global_position + Vector3.UP * 450.0, skill.name, skill.effect_color, 22)
	# Mientras dura: burbuja si protege (Escudo Arcano, Piel de Piedra) o un
	# aura si da mas daño (Furia, Ojo de Halcon).
	var duration: float = skill.buff_duration_at(level)
	if skill.buff_defense_at(level) > 0 or skill.buff_resistance_at(level) > 0.0:
		SpellFx.cast(character, skill.effect_color, 1.2)
		SpellFx.protection_bubble(character, skill.effect_color, duration, skill.buff_resistance_at(level) < skill.buff_defense_at(level))
	elif skill.buff_damage_at(level) > 1.0 or skill.buff_speed_at(level) > 1.0:
		SpellFx.power_aura(character, skill.effect_color, duration)


func _deliver_hit(target: Node3D, delay: float, offhand: bool = false) -> void:
	# process_always = false: si se pausa el juego, el golpe tambien espera.
	await get_tree().create_timer(delay, false).timeout
	if not is_instance_valid(target) or target.dead or player_stats.dead:
		return
	var to_target: Vector3 = target.global_position - character.global_position
	to_target.y = 0.0
	var hit: Dictionary = player_stats.roll_basic_attack(offhand)
	if player_stats.is_ranged():
		_shoot_bolt(to_target.normalized(), hit)
		return
	if to_target.length() > character.attack_range * REACH_TOLERANCE + character.extra_reach(target):
		return
	target.take_hit(hit)
	sfx.play_at(target.hit_sound() if target.has_method("hit_sound") else "hit", target.global_position)


func _shoot_bolt(direction: Vector3, hit: Dictionary) -> void:
	var bolt: Node3D = _make_bolt(direction, hit, 0.0)
	var spell: bool = player_stats.uses_spell_attack()
	if spell:
		bolt.glow = ARCANE_COLOR
		bolt.orb = true
		bolt.orb_size = 0.8
	var weapon: Itemdata = player_stats.get_weapon()
	if weapon and weapon.bow:
		bolt.arrow = true
	Effects.add_at(character.get_parent(), bolt, character.global_position + Vector3.UP * 230.0 + direction * 60.0)
	sfx.play_at("unknown_spell" if spell else "bow_shoot", character.global_position, -6.0 if spell else 0.0)
