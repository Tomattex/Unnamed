extends Node3D

## Eventos del camino (los pone world/build_world.gd con los caminos del
## mundo). Cada tanto, cuando el jugador anda por un camino lejos de la
## aldea, aparece mas adelante, fuera de la vista, una de estas cosas:
##   - un viajero asaltado por bandidos: si el jugador los mata, el viajero
##     le paga con oro y a veces con un objeto;
##   - un carro volcado con bichos de la zona alrededor: lo que llevaba queda
##     tirado cuando no queda ninguno;
##   - un peregrino que va por el camino y bendice (cura y regenera) al que
##     se le acerca.
## Hay uno solo a la vez; si el jugador se aleja mucho, se desarma.

const ENEMY_SCENE := preload("res://enemi.tscn")
const WALKER := preload("res://scripts/npc/walker.gd")
const BANDIT := preload("res://enemies/types/bandido.tres")
const ARCHER := preload("res://enemies/types/bandido_arquero.tres")
const CART := "res://assets/props/village/qt_cart/qt_cart.glb"
const BLESSING_ICON := "res://assets/icons/game-icons/lorc/magic-swirl.svg"

enum Kind { TRAVELER, CART_WRECK, PILGRIM }

const CHECK_INTERVAL: float = 3.0
## Tiempo entre un evento y el siguiente (y antes del primero).
const COOLDOWN := Vector2(110.0, 210.0)
const FIRST_COOLDOWN := Vector2(40.0, 80.0)
## El jugador tiene que estar asi de cerca de un camino para que pase algo.
const ROAD_NEAR: float = 700.0
## A que distancia del jugador aparece (por el camino).
const SPAWN_DISTANCE := Vector2(2000.0, 2900.0)
const GIVE_UP_DISTANCE: float = 6500.0
const SAMPLE_STEP: float = 200.0
const HELP_RANGE: float = 2300.0
const BLESS_RANGE: float = 450.0
const PILGRIM_SPEED: float = 200.0

@export var roads: Array[PackedVector2Array] = []
## Lugares donde no puede pasar nada (los puentes).
@export var avoid_points := PackedVector2Array()
@export var village_center := Vector2.ZERO
## Medio lado del cuadrado de la aldea (donde no hay eventos).
@export var village_half: float = 3000.0

var _cooldown: float = 0.0
var _check: float = 0.0
var _samples := PackedVector2Array()

var _kind: int = -1
var _center: Vector3
var _level: int = 1
var _enemies: Array[Node3D] = []
var _npc: Node3D
var _prop: Node3D
var _seen: bool = false
var _rewarded: bool = false
var _shout: float = 0.0
var _route := PackedVector3Array()
var _route_index: int = 0


func _ready() -> void:
	add_to_group("road_events")
	_cooldown = randf_range(FIRST_COOLDOWN.x, FIRST_COOLDOWN.y)
	for road in roads:
		for i in road.size() - 1:
			var steps: int = maxi(1, ceili(road[i].distance_to(road[i + 1]) / SAMPLE_STEP))
			for k in steps:
				_samples.append(road[i].lerp(road[i + 1], float(k) / steps))


func _process(delta: float) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if _kind >= 0:
		_update_event(player, delta)
		return
	_cooldown -= delta
	_check -= delta
	if _cooldown > 0.0 or _check > 0.0:
		return
	_check = CHECK_INTERVAL
	if player_stats.dead or not _near_road(player.global_position):
		return
	var spot: Variant = _find_spot(player.global_position)
	if spot != null:
		start(randi() % Kind.size(), spot)


## Arranca un evento en spot (lo usan tambien las pruebas).
func start(kind: int, spot: Vector3) -> void:
	_finish()
	_kind = kind
	_center = spot
	_level = _level_at(spot)
	_seen = false
	_rewarded = false
	_shout = 0.0
	match kind:
		Kind.TRAVELER:
			_npc = _person("res://assets/characters/oad/characters/merchant.glb", Color(0.8, 0.7, 0.55), "Viajero", spot)
			_npc.play("idle")
			var count: int = 3 + (1 if _level >= 5 else 0)
			for i in count:
				_spawn_enemy(ARCHER if i == count - 1 else BANDIT, spot, i, count, 330.0)
		Kind.CART_WRECK:
			_prop = load(CART).instantiate()
			_prop.scale = Vector3.ONE * 380.0
			_prop.rotation = Vector3(0.0, randf() * TAU, 1.35)
			_prop.position = spot + Vector3.UP * 60.0
			add_child(_prop)
			var types: Array = _zone_types(spot)
			var count: int = randi_range(3, 4)
			for i in count:
				_spawn_enemy(types.pick_random(), spot, i, count, 380.0)
		Kind.PILGRIM:
			_npc = _person("res://assets/characters/oad/characters/priest.glb", Color(0.95, 0.92, 0.85), "Peregrino", spot)
			_route = _route_from(spot)
			_route_index = 0


func is_active() -> bool:
	return _kind >= 0


func _update_event(player: Node3D, delta: float) -> void:
	var distance: float = Vector2(player.global_position.x - _center.x, player.global_position.z - _center.z).length()
	if distance > GIVE_UP_DISTANCE:
		_finish()
		return
	for i in range(_enemies.size() - 1, -1, -1):
		if not is_instance_valid(_enemies[i]) or _enemies[i].dead:
			_enemies.remove_at(i)
	if _npc:
		_npc.update_label(delta)
	match _kind:
		Kind.TRAVELER:
			_update_traveler(player, distance, delta)
		Kind.CART_WRECK:
			if _enemies.is_empty() and not _rewarded:
				_rewarded = true
				for drop in Loot.roll_chest_drops(_level, 1, difficulty.get_value("gold"), difficulty.get_value("magic_find")):
					Loot.spawn_pickup(get_parent(), _center, drop.item, drop.quantity)
				floating_text.spawn(_center + Vector3.UP * 300.0, "Lo que quedó del carro", Color(1.0, 0.85, 0.45), 20)
		Kind.PILGRIM:
			_update_pilgrim(player, delta)


func _update_traveler(player: Node3D, distance: float, delta: float) -> void:
	if not _rewarded:
		_shout -= delta
		if distance < HELP_RANGE and _shout <= 0.0:
			_shout = 6.0
			_npc.say("¡Socorro! ¡Bandidos!" if _enemies.size() > 1 else "¡Ayuda, por favor!", Color(1.0, 0.75, 0.5))
		if _enemies.is_empty():
			_rewarded = true
			_npc.say("¡Gracias! Tome, es todo lo que llevo.")
			var gold: int = roundi(randi_range(40, 70) * (1.0 + 0.3 * (_level - 1)) * difficulty.get_value("gold"))
			Loot.spawn_pickup(get_parent(), _npc.global_position, Loot.GOLD, gold)
			if randf() < 0.6:
				Loot.spawn_pickup(get_parent(), _npc.global_position, Loot.generate_item(_level + 1, -1, difficulty.get_value("magic_find")), 1)
		return
	# Ya salvado: se va hacia la aldea por el camino.
	var to_village := Vector3(village_center.x, 0.0, village_center.y)
	if _npc.walk_to(to_village, PILGRIM_SPEED, delta) > 100.0:
		_npc.play("walk")
	else:
		_npc.play("idle")


func _update_pilgrim(player: Node3D, delta: float) -> void:
	var to_player: Vector3 = player.global_position - _npc.global_position
	to_player.y = 0.0
	if not _rewarded and to_player.length() < BLESS_RANGE and not player_stats.dead:
		_rewarded = true
		_npc.say("Que la luz te acompañe en el camino.")
		player_stats.heal(player_stats.get_max_health())
		player_stats.add_buff("peregrino", {"name": "Bendición del peregrino", "icon": load(BLESSING_ICON), "duration": 90.0, "regen": 5.0})
		Effects.aura(player.get_parent(), player.global_position, Color(1.0, 0.95, 0.7))
		floating_text.spawn(player.global_position + Vector3.UP * 450.0, "Bendición del peregrino", Color(1.0, 0.95, 0.7), 24, 1.8)
	# Se para a hablar con el jugador; si no, sigue su camino.
	if to_player.length() < BLESS_RANGE * 1.5 or _route_index >= _route.size():
		_npc.face(to_player, delta)
		_npc.play("idle")
		return
	if _npc.walk_to(_route[_route_index], PILGRIM_SPEED, delta) < 60.0:
		_route_index += 1
	_npc.play("walk")


func _finish() -> void:
	for enemy in _enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	_enemies.clear()
	for node in [_npc, _prop]:
		if is_instance_valid(node):
			node.queue_free()
	_npc = null
	_prop = null
	_route = PackedVector3Array()
	if _kind >= 0:
		_cooldown = randf_range(COOLDOWN.x, COOLDOWN.y)
	_kind = -1


func _person(model: String, tint: Color, display_name: String, spot: Vector3) -> Node3D:
	var person := CharacterBody3D.new()
	person.set_script(WALKER)
	person.name = display_name
	person.position = spot
	person.rotation.y = randf() * TAU
	add_child(person)
	person.setup(model, tint, display_name)
	return person


func _spawn_enemy(data: EnemyData, center: Vector3, index: int, count: int, radius: float) -> void:
	var angle: float = TAU * index / count + randf_range(-0.3, 0.3)
	var point: Vector3 = _on_navmesh(center + Vector3(cos(angle), 0.0, sin(angle)) * radius)
	var enemy: Node3D = ENEMY_SCENE.instantiate()
	enemy.data = data
	enemy.level = _level
	enemy.position = point
	# Mirando al centro (al viajero o al carro).
	enemy.rotation.y = atan2(center.x - point.x, center.z - point.z)
	get_parent().add_child(enemy)
	_enemies.append(enemy)


## Puntos del camino desde spot hacia adelante, para que el peregrino lo recorra.
func _route_from(spot: Vector3) -> PackedVector3Array:
	var best_road: PackedVector2Array
	var best_index: int = 0
	var best: float = INF
	for road in roads:
		for i in road.size():
			var d: float = road[i].distance_to(Vector2(spot.x, spot.z))
			if d < best:
				best = d
				best_road = road
				best_index = i
	var route := PackedVector3Array()
	# Va hacia la punta mas lejana de la aldea.
	var forward: bool = best_road[best_road.size() - 1].distance_to(village_center) > best_road[0].distance_to(village_center)
	var i: int = best_index
	while i >= 0 and i < best_road.size():
		route.append(_on_navmesh(Vector3(best_road[i].x, 0.0, best_road[i].y)))
		i += 1 if forward else -1
	return route


func _near_road(position: Vector3) -> bool:
	var p := Vector2(position.x, position.z)
	if _in_village(p, 0.0):
		return false
	for sample in _samples:
		if sample.distance_squared_to(p) < ROAD_NEAR * ROAD_NEAR:
			return true
	return false


func _in_village(point: Vector2, margin: float) -> bool:
	return absf(point.x - village_center.x) < village_half + margin and absf(point.y - village_center.y) < village_half + margin


## Un punto de algun camino a la distancia justa del jugador, fuera de la
## aldea, lejos de los puentes, sobre piso caminable y fuera de camara.
func _find_spot(player_position: Vector3) -> Variant:
	var p := Vector2(player_position.x, player_position.z)
	var camera: Camera3D = get_viewport().get_camera_3d()
	var candidates: Array[Vector2] = []
	for sample in _samples:
		var d: float = sample.distance_to(p)
		if d < SPAWN_DISTANCE.x or d > SPAWN_DISTANCE.y or _in_village(sample, 600.0):
			continue
		if Array(avoid_points).any(func(avoid: Vector2) -> bool: return avoid.distance_to(sample) < 1000.0):
			continue
		candidates.append(sample)
	candidates.shuffle()
	for sample in candidates.slice(0, 12):
		var point: Vector3 = _on_navmesh(Vector3(sample.x, 0.0, sample.y))
		if Vector2(point.x - sample.x, point.z - sample.y).length() > 120.0:
			continue
		if camera and (camera.is_position_in_frustum(point) or camera.is_position_in_frustum(point + Vector3.UP * 400.0)):
			continue
		return point
	return null


func _on_navmesh(point: Vector3) -> Vector3:
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, point)
	if closest == Vector3.ZERO and point.length() > 1.0:
		return point
	return Vector3(closest.x, 0.0, closest.z)


## Nivel de la zona de enemigos que contiene el punto (o la mas cercana).
func _level_at(point: Vector3) -> int:
	var zone: Node = _zone_at(point)
	return zone.level if zone else 1


func _zone_types(point: Vector3) -> Array:
	var zone: Node = _zone_at(point)
	if zone and not zone.enemy_types.is_empty():
		return zone.enemy_types
	return [BANDIT]


func _zone_at(point: Vector3) -> Node:
	var best: Node = null
	var best_distance: float = INF
	for zone in get_tree().get_nodes_in_group("enemy_zones"):
		if zone._contains(point, 0.0):
			return zone
		var distance: float = zone.global_position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = zone
	return best
