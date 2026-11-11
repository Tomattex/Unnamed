extends Node

## Autoload con las habilidades del jugador: cuales tiene aprendidas, a que
## nivel y cuanto le falta a cada una para recargarse.
## Se aprenden y suben leyendo runas (items con rune_skill, ver Itemdata):
## la primera habilidad de la clase viene sabida; las demas, con su runa.
## Ninguna pasa del nivel del personaje. Las runas de otras clases se cambian
## en el comerciante de runas de la aldea (scripts/npc/rune_merchant.gd).
## La ejecucion de cada habilidad esta en scripts/player/combat.gd.

signal skill_unlocked(index: int)
signal skill_leveled(index: int, level: int)
signal skill_used(index: int)
signal combo_changed
signal combo_unlocked

## Nivel a partir del cual se pueden armar combos.
const COMBO_UNLOCK_LEVEL: int = 4
const COMBO_MAX_SKILLS: int = 3
## La recarga del combo es la suma de las recargas de sus habilidades por este factor.
const COMBO_COOLDOWN_FACTOR: float = 0.75
const MAX_SKILL_LEVEL: int = 30

var skills: Array[SkillData] = []
## Nivel de cada habilidad (0 = todavia no se aprendio).
var levels: Array[int] = []
var _paths: Array[String] = []
var _cooldown_left: Array[float] = []
var _cooldown_total: Array[float] = []
## Indices de las habilidades del combo, en orden de ejecucion.
var combo: Array[int] = []
var _combo_left: float = 0.0
var _combo_total: float = 1.0


func _ready() -> void:
	set_class(player_stats.class_id)
	player_stats.leveled_up.connect(_on_leveled_up)


## Carga las habilidades de la clase (ver scripts/player/player_classes.gd),
## con solo la primera aprendida.
func set_class(class_id: String) -> void:
	skills.clear()
	_paths.clear()
	_cooldown_left.clear()
	_cooldown_total.clear()
	for path in PlayerClasses.get_info(class_id).skills:
		skills.append(load(path))
		_paths.append(path)
		_cooldown_left.append(0.0)
		_cooldown_total.append(1.0)
	_reset_levels()


## Partida nueva: sin combo, todo recargado y solo la primera habilidad.
func reset() -> void:
	combo = []
	_combo_left = 0.0
	for i in _cooldown_left.size():
		_cooldown_left[i] = 0.0
	_reset_levels()


func _reset_levels() -> void:
	levels.clear()
	for i in skills.size():
		levels.append(1 if i == 0 else 0)


func _process(delta: float) -> void:
	for i in _cooldown_left.size():
		_cooldown_left[i] = maxf(_cooldown_left[i] - delta, 0.0)
	_combo_left = maxf(_combo_left - delta, 0.0)


func get_skill(index: int) -> SkillData:
	return skills[index] if index >= 0 and index < skills.size() else null


func get_level(index: int) -> int:
	return levels[index] if index >= 0 and index < levels.size() else 0


func is_unlocked(index: int) -> bool:
	return get_level(index) > 0


func is_ready(index: int) -> bool:
	return is_unlocked(index) and _cooldown_left[index] <= 0.0


func start_cooldown(index: int) -> void:
	var total: float = skills[index].get_cooldown(get_level(index))
	_cooldown_total[index] = total
	_cooldown_left[index] = total
	skill_used.emit(index)


func get_cooldown_left(index: int) -> float:
	return _cooldown_left[index]


## 1 = recien usada, 0 = lista.
func get_cooldown_ratio(index: int) -> float:
	return _cooldown_left[index] / maxf(_cooldown_total[index], 0.01)


func get_tooltip(index: int) -> String:
	var skill: SkillData = get_skill(index)
	return skill.get_tooltip(get_level(index)) if skill else ""


# --- Runas -----------------------------------------------------------------

## Indice de la habilidad de la clase que enseña la runa (-1 si es de otra clase).
func rune_index(rune: Itemdata) -> int:
	if rune == null or not rune.is_rune():
		return -1
	return _paths.find(rune.rune_skill)


## Motivo por el que no se puede leer la runa ("" si se puede).
func rune_problem(rune: Itemdata) -> String:
	var index: int = rune_index(rune)
	if index < 0:
		return "Es una runa de otra clase: cambiala en el comerciante de runas"
	var next: int = get_level(index) + 1
	if next > MAX_SKILL_LEVEL:
		return "%s ya está al máximo" % skills[index].name
	if next > player_stats.level:
		return "Necesitás nivel %d para subir %s al nivel %d" % [next, skills[index].name, next]
	return ""


## Lee una runa de la mochila: aprende la habilidad o la sube un nivel, y
## gasta la runa. Devuelve el motivo si no se pudo ("" si salio bien).
func read_rune(rune: Itemdata) -> String:
	var problem: String = rune_problem(rune)
	if not problem.is_empty():
		return problem
	if inventory_data.count_item(rune) <= 0:
		return "No tenés esa runa"
	var index: int = rune_index(rune)
	inventory_data.remove_item(rune, 1)
	levels[index] += 1
	if levels[index] == 1:
		skill_unlocked.emit(index)
	else:
		skill_leveled.emit(index, levels[index])
	player_stats.stats_changed.emit()
	return ""


# --- Guardado --------------------------------------------------------------

func to_save() -> Array[int]:
	return levels.duplicate()


## Niveles de una partida. Las de antes de las runas no los tienen: lo que ya
## estaba aprendido por nivel queda en nivel 1 (que es como pegaba).
func load_levels(saved: Variant, character_level: int) -> void:
	_reset_levels()
	if saved is Array and (saved as Array).size() == skills.size():
		for i in skills.size():
			levels[i] = clampi(int(saved[i]), 0, MAX_SKILL_LEVEL)
	else:
		for i in skills.size():
			if skills[i].unlock_level <= character_level:
				levels[i] = 1
	levels[0] = maxi(levels[0], 1)
	combo.assign(combo.filter(is_unlocked))


# --- Combo ---------------------------------------------------------------

func is_combo_unlocked() -> bool:
	return player_stats.level >= COMBO_UNLOCK_LEVEL


func set_combo(indices: Array) -> void:
	combo = []
	for index in indices:
		if is_unlocked(int(index)) and combo.size() < COMBO_MAX_SKILLS:
			combo.append(int(index))
	combo_changed.emit()


func get_combo_cooldown() -> float:
	var total: float = 0.0
	for index in combo:
		total += skills[index].get_cooldown(get_level(index))
	return total * COMBO_COOLDOWN_FACTOR


func is_combo_ready() -> bool:
	return is_combo_unlocked() and not combo.is_empty() and _combo_left <= 0.0


func start_combo_cooldown() -> void:
	_combo_total = maxf(get_combo_cooldown(), 0.01)
	_combo_left = _combo_total


func get_combo_cooldown_left() -> float:
	return _combo_left


func get_combo_cooldown_ratio() -> float:
	return _combo_left / _combo_total


func combo_has_strike() -> bool:
	for index in combo:
		if skills[index].kind == SkillData.Kind.STRIKE:
			return true
	return false


func _on_leveled_up(new_level: int) -> void:
	if new_level == COMBO_UNLOCK_LEVEL:
		combo_unlocked.emit()
