extends Node

## Papel de un enemigo en su grupo (EnemyData.role). Lo agrega enemi.gd como
## hijo del enemigo y mira cada tanto que hacer, sin costo por cuadro:
## HEALER: cura al compañero mas herido y, peleando, los enardece (mas daño).
## LEADER: al ver al jugador lanza un grito de guerra que llama a los suyos, y
##   los cercanos pegan mas fuerte y corren mas mientras el viva.
## NECROMANCER: levanta a los esqueletos y no-muertos que cayeron cerca (los
##   huesos vuelan a juntarse) y, si no hay, saca esqueletos de la tierra.

const ENEMY_SCENE_PATH := "res://enemi.tscn"
const SUMMON_DATA_PATH := "res://enemies/types/esqueleto.tres"
## Cada cuanto se revisa (segundos).
const THINK: float = 0.5

const HEAL_RANGE: float = 900.0
const HEAL_COOLDOWN: float = 5.0
## Cura esta parte de la vida maxima del compañero.
const HEAL_AMOUNT: float = 0.3
const HEAL_BELOW: float = 0.75
const EMPOWER_RANGE: float = 800.0
const EMPOWER_COOLDOWN: float = 12.0
const EMPOWER_TIME: float = 8.0
const EMPOWER_DAMAGE: float = 1.25

const LEADER_RANGE: float = 900.0
const LEADER_DAMAGE: float = 1.2
const LEADER_SPEED: float = 1.15
const WAR_CRY_RANGE: float = 1500.0

const RAISE_RANGE: float = 1500.0
const RAISE_COOLDOWN: float = 7.0
## Cuanto tardan los huesos en juntarse antes de levantarse.
const RAISE_TIME: float = 0.8
const MAX_SUMMONS: int = 2
const HEAL_COLOR := Color(0.45, 1.0, 0.5)
const EMPOWER_COLOR := Color(1.0, 0.45, 0.2)
const NECRO_COLOR := Color(0.65, 0.35, 1.0)

## El enemigo dueño de este rol (enemi.gd; sin tipo porque ese script no
## tiene class_name).
var enemy

var _think: float = 0.0
var _cooldown: float = 2.0
var _empower_cooldown: float = 3.0
var _war_cry_done: bool = false
var _summons: Array[Node] = []


func _physics_process(delta: float) -> void:
	if enemy.dead or enemy.is_inactive():
		return
	_cooldown -= delta
	_empower_cooldown -= delta
	_think -= delta
	if _think > 0.0:
		return
	_think = THINK
	match enemy.data.role:
		EnemyData.Role.HEALER:
			_healer()
		EnemyData.Role.LEADER:
			_leader()
		EnemyData.Role.NECROMANCER:
			_necromancer()


func _fighting() -> bool:
	return enemy.in_combat()


# Compañeros vivos (enemigos que no son fauna) a menos de range_limit.
func _allies(range_limit: float) -> Array:
	var result: Array = []
	for other in enemy.get_tree().get_nodes_in_group("enemies"):
		if other.dead or other.data.passive:
			continue
		if other.global_position.distance_to(enemy.global_position) <= range_limit:
			result.append(other)
	return result


# --- Curandero ------------------------------------------------------------------

func _healer() -> void:
	if _cooldown <= 0.0:
		var worst: Node = null
		var worst_ratio: float = HEAL_BELOW
		for ally in _allies(HEAL_RANGE):
			var ratio: float = ally.current_health / ally.max_health
			if ratio < worst_ratio:
				worst_ratio = ratio
				worst = ally
		if worst:
			_cooldown = HEAL_COOLDOWN
			_heal(worst)
			return
	if _fighting() and _empower_cooldown <= 0.0:
		_empower_cooldown = EMPOWER_COOLDOWN
		_empower()


func _heal(ally: Node) -> void:
	enemy.cast(0.9)
	_face(ally)
	await enemy.get_tree().create_timer(0.6, false).timeout
	if enemy.dead or not is_instance_valid(ally) or ally.dead:
		return
	var amount: float = ally.max_health * HEAL_AMOUNT
	ally.heal(amount)
	floating_text.spawn(ally.global_position + Vector3.UP * (ally.head_height() + 60.0), "+%d" % roundi(amount), HEAL_COLOR, 20)
	Effects.aura(ally.get_parent(), ally.global_position, HEAL_COLOR)
	sfx.play_at("success", ally.global_position, -6.0)


# Los compañeros cercanos pegan mas fuerte un rato (un sigilo rojo bajo cada uno).
func _empower() -> void:
	enemy.cast(0.9)
	await enemy.get_tree().create_timer(0.5, false).timeout
	if enemy.dead:
		return
	sfx.play_at("damage_boost", enemy.global_position, -6.0)
	for ally in _allies(EMPOWER_RANGE):
		ally.apply_buff(EMPOWER_DAMAGE, 1.0, EMPOWER_TIME)
		Effects.ground_glow(ally.get_parent(), ally.global_position, Effects.SIGIL, Color(EMPOWER_COLOR, 0.8), ally.body_radius() * 4.0, 1.2, 0.5)


# --- Lider ------------------------------------------------------------------------

func _leader() -> void:
	if not _fighting():
		return
	if not _war_cry_done:
		_war_cry_done = true
		_war_cry()
	for ally in _allies(LEADER_RANGE):
		if ally != enemy:
			ally.apply_buff(LEADER_DAMAGE, LEADER_SPEED, THINK * 3.0)


# Grito de guerra: todos los suyos cercanos van por el jugador.
func _war_cry() -> void:
	enemy.cast(1.0)
	floating_text.spawn(enemy.global_position + Vector3.UP * (enemy.head_height() + 120.0), "¡A ellos!", Color(1.0, 0.5, 0.3), 24, 1.4)
	Effects.shockwave(enemy.get_parent(), enemy.global_position, Color(1.0, 0.35, 0.15), 600.0, 0.6)
	if not enemy.data.aggro_sound.is_empty():
		sfx.play_at(enemy.data.aggro_sound, enemy.global_position, 2.0, 0.02)
	for ally in _allies(WAR_CRY_RANGE):
		if ally != enemy:
			ally._enter_chase()


# --- Nigromante ---------------------------------------------------------------------

func _necromancer() -> void:
	if _cooldown > 0.0:
		return
	var player: Node3D = enemy.player
	var near_player: bool = is_instance_valid(player) and player.global_position.distance_to(enemy.global_position) < enemy.data.detection_range * 1.3
	if not _fighting() and not near_player:
		return
	# Sin filter con tipo: un invocado ya borrado no se puede pasar como Node.
	for i in range(_summons.size() - 1, -1, -1):
		if not is_instance_valid(_summons[i]) or _summons[i].dead:
			_summons.remove_at(i)
	var corpse: Dictionary = enemy.claim_fallen(RAISE_RANGE)
	if not corpse.is_empty():
		_cooldown = RAISE_COOLDOWN
		_raise(corpse.position, corpse.data, corpse.level, corpse.corpse.get_ref())
	elif _fighting() and _summons.size() < MAX_SUMMONS:
		_cooldown = RAISE_COOLDOWN * 1.4
		var angle: float = randf() * TAU
		var point: Vector3 = enemy.global_position + Vector3(cos(angle), 0.0, sin(angle)) * randf_range(250.0, 400.0)
		point = NavigationServer3D.map_get_closest_point(enemy.get_world_3d().navigation_map, point)
		_raise(point, load(SUMMON_DATA_PATH), enemy.level - 1, null)


# Conjuro sobre el lugar: brillo violeta en el piso, los huesos (si quedan) se
# juntan y el muerto se levanta del suelo con su animacion.
func _raise(point: Vector3, data: EnemyData, level: int, corpse: Node) -> void:
	enemy.cast(RAISE_TIME + 0.4)
	_face_point(point)
	var parent: Node = enemy.get_parent()
	Effects.ground_glow(parent, point, Effects.SIGIL, Color(NECRO_COLOR, 0.9), 380.0, RAISE_TIME + 1.0, 1.0)
	Effects.spirit_wisps(parent, point + Vector3.UP * 60.0, NECRO_COLOR, 14, 120.0)
	sfx.play_at("unknown_spell", point, -4.0)
	if is_instance_valid(corpse) and corpse.has_method("reassemble"):
		corpse.reassemble(RAISE_TIME)
	await enemy.get_tree().create_timer(RAISE_TIME, false).timeout
	if enemy.dead or not enemy.is_inside_tree():
		return
	var risen: CharacterBody3D = load(ENEMY_SCENE_PATH).instantiate()
	risen.data = data
	risen.level = maxi(level, 1)
	risen.summoned = true
	risen.despawns = true
	risen.position = point
	risen.rotation.y = randf() * TAU
	parent.add_child(risen)
	_summons.append(risen)
	Effects.flash(parent, point + Vector3.UP * 120.0, NECRO_COLOR, 3.0, 600.0, 0.5)


func _face(target: Node3D) -> void:
	_face_point(target.global_position)


func _face_point(point: Vector3) -> void:
	var dir: Vector3 = point - enemy.global_position
	if Vector2(dir.x, dir.z).length() > 1.0:
		enemy.rotation.y = atan2(dir.x, dir.z)
