extends Node3D

## Region de enemigos, como en Sacred: mientras el jugador anda por la zona,
## los enemigos aparecen en grupos alrededor suyo, fuera de lo que ve la
## camara, y desaparecen cuando el jugador se aleja (ver enemi.gd). Asi solo
## existen los que estan cerca y el resto del mapa no cuesta nada.
## Ademas de los tipos de la escena, cada zona suma los de EXTRA_TYPES segun
## su nombre (algunos solo de noche), su fauna (con cupo aparte) y, con los
## bandidos, grupos que patrullan los caminos o esperan escondidos al costado.

## Distancia al jugador a la que aparecen los grupos (afuera de la pantalla).
const SPAWN_MIN_DISTANCE := 1900.0
const SPAWN_MAX_DISTANCE := 3000.0
## Intentos por tanda para encontrar un lugar valido.
const SPAWN_TRIES := 10
## Separacion entre los integrantes de un grupo.
const PACK_SPREAD := 170.0
## Un punto vale si el piso caminable mas cercano esta a menos de esto.
const NAVMESH_TOLERANCE := 60.0
## Probabilidad de que un grupo venga con un campeon al frente (de noche, el doble).
const CHAMPION_CHANCE := 0.1
## Radio en el que se cuentan los enemigos que ya hay cerca del jugador
## (de cualquier zona, asi en los bordes entre zonas no se suman).
const NEARBY_RANGE := 4500.0
const TYPES_DIR := "res://enemies/types/%s.tres"
## Tipos que se suman a cada zona segun como empieza su nombre (las zonas las
## arma world/build_world.gd): [tipo, peso de dia, peso de noche]. Con peso 0
## de dia, solo salen de noche.
const EXTRA_TYPES := {
	"Bosque": [["oso", 1.0, 0.8], ["jabali", 1.5, 1.0], ["lobo_alfa", 0.7, 1.0], ["murcielago", 0.0, 1.8], ["espectro", 0.0, 0.8]],
	"Pradera": [["jabali", 2.0, 1.0], ["murcielago", 0.0, 1.2]],
	"Cementerio": [["esqueleto_chaman", 1.0, 1.4], ["nigromante", 0.5, 1.5], ["espectro", 0.0, 2.0], ["murcielago", 0.0, 1.5]],
	"Ruinas": [["jefe_bandido", 1.2, 1.0], ["espectro", 0.0, 1.0], ["murcielago", 0.0, 1.0]],
	"Pantano": [["esqueleto_chaman", 1.0, 1.2], ["nigromante", 0.6, 1.2], ["espectro", 0.4, 2.0], ["murcielago", 0.5, 1.8], ["jabali", 1.0, 0.5]],
	"Costa": [["jefe_bandido", 1.2, 1.0], ["espectro", 0.0, 1.2], ["murcielago", 0.0, 1.0]],
	"Desierto": [["esqueleto_chaman", 1.2, 1.2], ["jefe_bandido", 0.8, 0.6], ["espectro", 0.0, 1.0]],
	"Montaña": [["oso", 1.5, 1.2], ["lobo_alfa", 1.2, 1.5], ["espectro", 0.0, 1.0]],
}
## Animales pacificos de cada zona: [tipo, peso]. Tienen su propio cupo.
const FAUNA := {
	"Bosque": [["ciervo", 2.0], ["conejo", 1.5]],
	"Pradera": [["ciervo", 1.5], ["conejo", 2.5]],
	"Cementerio": [["conejo", 1.0]],
	"Pantano": [["conejo", 1.0]],
	"Costa": [["ciervo", 1.0], ["conejo", 1.5]],
	"Montaña": [["ciervo", 2.0]],
}
const FAUNA_LIMIT := 5
const FAUNA_INTERVAL := 5.0
## Bandidos (EnemyData.roads): parte de los grupos patrulla un camino y otra
## parte espera escondida al costado, adelante de por donde va el jugador.
const PATROL_CHANCE := 0.35
const AMBUSH_CHANCE := 0.3
const ROAD_SPACING := 450.0
## Distancia al jugador del escondite de una emboscada, y cuanto se corren
## del centro del camino.
const AMBUSH_MIN_DISTANCE := 1300.0
const AMBUSH_MAX_DISTANCE := 2600.0
const AMBUSH_SIDE := Vector2(280.0, 420.0)
## Los caminos casi no entran a las zonas (las Ruinas estan al final de uno):
## los bandidos tambien usan el tramo que llega, hasta esto afuera de la caja.
const ROAD_MARGIN := 1500.0

@export var enemy_scene: PackedScene
@export var spawn_interval := 3.0
## Cuantos enemigos puede haber a la vez cerca del jugador en esta zona.
@export var max_enemies := 10
## Nivel de los enemigos de esta zona (escala vida, daño y experiencia).
@export var level := 1
## Tipos que pueden aparecer. Si se deja vacio usa esqueleto, zombi y guerrero.
@export var enemy_types: Array[EnemyData] = []
## Peso de cada tipo (mismo orden que enemy_types). Vacio = todos igual de probables.
@export var type_weights: Array[float] = []
## Tamaño de la zona (si no es cero reemplaza la caja de la escena; lo usa
## world/build_world.gd para que cada zona tenga su propia caja).
@export var zone_size := Vector3.ZERO

@onready var zone_shape: CollisionShape3D = $Area3D/CollisionShape3D
@onready var timer: Timer = $Timer

var enemies_alive := 0
var _player: Node3D
## Pesos de dia y de noche de cada tipo (mismo orden que enemy_types).
var _day_weights: Array[float] = []
var _night_weights: Array[float] = []
var _fauna_types: Array[EnemyData] = []
var _fauna_weights: Array[float] = []
var _fauna_timer: Timer

func _ready():
	# El mapa grande marca las zonas peligrosas ya exploradas.
	add_to_group("enemy_zones")
	if zone_size != Vector3.ZERO:
		var box := BoxShape3D.new()
		box.size = zone_size
		zone_shape.shape = box
	if enemy_types.is_empty():
		enemy_types = [
			load("res://enemies/types/esqueleto.tres"),
			load("res://enemies/types/zombie.tres"),
			load("res://enemies/types/esqueleto_guerrero.tres"),
		]
		type_weights = [5.0, 3.0, 1.0]
	_setup_types()
	timer.wait_time = spawn_interval
	timer.timeout.connect(_spawn_enemy)
	timer.start()
	if not _fauna_types.is_empty():
		_fauna_timer = Timer.new()
		_fauna_timer.wait_time = FAUNA_INTERVAL
		_fauna_timer.timeout.connect(_spawn_fauna)
		add_child(_fauna_timer)
		_fauna_timer.start()

# Suma los tipos extra y la fauna que le tocan a esta zona por su nombre.
func _setup_types() -> void:
	for i in enemy_types.size():
		var weight: float = type_weights[i] if type_weights.size() == enemy_types.size() else 1.0
		_day_weights.append(weight)
		_night_weights.append(weight)
	for prefix in EXTRA_TYPES:
		if not String(name).begins_with(prefix):
			continue
		for entry in EXTRA_TYPES[prefix]:
			enemy_types.append(load(TYPES_DIR % entry[0]))
			_day_weights.append(entry[1])
			_night_weights.append(entry[2])
	for prefix in FAUNA:
		if not String(name).begins_with(prefix):
			continue
		for entry in FAUNA[prefix]:
			_fauna_types.append(load(TYPES_DIR % entry[0]))
			_fauna_weights.append(entry[1])

func _spawn_enemy():
	# De noche aparecen mas enemigos, mas seguido y un nivel mas fuertes.
	var night: bool = world_time.is_night()
	timer.wait_time = spawn_interval * (0.6 if night else 1.0)
	var limit: int = roundi(max_enemies * (1.5 if night else 1.0))
	if not _player_in_zone():
		return
	var nearby: int = _enemies_near_player()
	if nearby >= limit:
		return

	var data: EnemyData = _pick(enemy_types, _night_weights if night else _day_weights)
	if data == null:
		return
	var with_champion: bool = randf() < CHAMPION_CHANCE * (2.0 if night else 1.0)
	var members: Array[EnemyData] = _group_for(data, with_champion)
	members.resize(mini(members.size(), limit - nearby))
	if data.roads:
		var roll: float = randf()
		if roll < AMBUSH_CHANCE and _spawn_ambush(members, night, with_champion):
			return
		if roll < AMBUSH_CHANCE + PATROL_CHANCE and _spawn_patrol(members, night, with_champion):
			return
	var spot = _find_spot()
	if spot == null:
		return
	_spawn_group(members, spot, night, with_champion)

# Quienes forman el grupo: los que tienen escolta (lider, chaman, nigromante)
# vienen con sus compañeros; el resto, en manada de su tamaño.
func _group_for(data: EnemyData, with_champion: bool) -> Array[EnemyData]:
	var members: Array[EnemyData] = []
	var count: int = randi_range(data.pack_size.x, data.pack_size.y)
	for i in count:
		members.append(data)
	if not data.escorts.is_empty():
		for i in randi_range(data.escort_count.x, data.escort_count.y):
			members.append(data.escorts.pick_random())
	elif with_champion:
		members.append(data)
	return members

# El primero va en el centro (y es el campeon si lo hay); los demas alrededor.
func _spawn_group(members: Array[EnemyData], spot: Vector3, night: bool, with_champion: bool, setup: Callable = Callable()) -> void:
	var count: int = members.size()
	for i in count:
		var offset := Vector3.ZERO
		if i > 0:
			var angle: float = TAU * i / count + randf_range(-0.4, 0.4)
			offset = Vector3(cos(angle), 0.0, sin(angle)) * PACK_SPREAD * randf_range(0.8, 1.3)
		var point = _on_navmesh(spot + offset)
		if point == null:
			point = spot
		_spawn_one(members[i], point, night, with_champion and i == 0, setup)

func _spawn_one(data: EnemyData, point: Vector3, night: bool, champion: bool = false, setup: Callable = Callable()) -> void:
	var enemy = enemy_scene.instantiate()
	enemy.data = data
	enemy.champion = champion
	enemy.level = level + (1 if night else 0)
	enemy.despawns = true
	enemy.position = point
	enemy.rotation.y = randf() * TAU
	if setup.is_valid():
		setup.call(enemy)
	get_parent().add_child(enemy)

	enemies_alive += 1
	enemy.tree_exited.connect(func(): enemies_alive -= 1)

# Enemigos (no fauna) cerca del jugador, contando los que esperan escondidos.
func _enemies_near_player() -> int:
	var count := 0
	for group in ["enemies", "ambushers"]:
		for enemy in get_tree().get_nodes_in_group(group):
			if enemy.data.passive:
				continue
			if enemy.global_position.distance_to(_player.global_position) < NEARBY_RANGE:
				count += 1
	return count

func _player_in_zone() -> bool:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
		if _player == null:
			return false
	# Lejos de la zona no se hace nada.
	return _contains(_player.global_position, SPAWN_MAX_DISTANCE)

## Un punto alrededor del jugador, dentro de la zona, sobre piso caminable y
## que la camara no este viendo. null si no encontro ninguno.
func _find_spot():
	for i in SPAWN_TRIES:
		var angle: float = randf() * TAU
		var distance: float = randf_range(SPAWN_MIN_DISTANCE, SPAWN_MAX_DISTANCE)
		var candidate: Vector3 = _player.global_position + Vector3(cos(angle), 0.0, sin(angle)) * distance
		if not _contains(candidate, 0.0):
			continue
		var point = _on_navmesh(candidate)
		if point == null or _on_camera(point):
			continue
		return point
	return null

func _on_camera(point: Vector3) -> bool:
	var camera: Camera3D = get_viewport().get_camera_3d()
	return camera != null and (camera.is_position_in_frustum(point) or camera.is_position_in_frustum(point + Vector3.UP * 400.0))

## Si el punto esta dentro de la caja de la zona (agrandada en margin).
func _contains(point: Vector3, margin: float) -> bool:
	var local: Vector3 = zone_shape.global_transform.affine_inverse() * point
	var half: Vector3 = zone_shape.shape.size / 2.0
	return absf(local.x) <= half.x + margin and absf(local.z) <= half.z + margin

## El punto apoyado en el piso caminable, o null si cae fuera (agua, rocas...).
func _on_navmesh(point: Vector3):
	var map: RID = get_world_3d().navigation_map
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(map, point)
	var flat := Vector2(closest.x - point.x, closest.z - point.z)
	if flat.length() > NAVMESH_TOLERANCE:
		return null
	return closest

## Uno de la lista segun su peso (peso 0 = no sale). null si todos pesan 0.
func _pick(types: Array[EnemyData], weights: Array[float]) -> EnemyData:
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return null
	var roll := randf() * total
	for i in types.size():
		roll -= weights[i]
		if roll <= 0.0 and weights[i] > 0.0:
			return types[i]
	return types.back()

# --- Fauna ---------------------------------------------------------------------

func _spawn_fauna() -> void:
	if not _player_in_zone():
		return
	var animals := 0
	for enemy in get_tree().get_nodes_in_group("prey"):
		if enemy.global_position.distance_to(_player.global_position) < NEARBY_RANGE:
			animals += 1
	if animals >= FAUNA_LIMIT:
		return
	var spot = _find_spot()
	if spot == null:
		return
	var data: EnemyData = _pick(_fauna_types, _fauna_weights)
	var members: Array[EnemyData] = []
	for i in mini(randi_range(data.pack_size.x, data.pack_size.y), FAUNA_LIMIT - animals):
		members.append(data)
	_spawn_group(members, spot, false, false)

# --- Bandidos en los caminos ------------------------------------------------------

# Puntos de los caminos que caen dentro de la zona o cerca (cada ROAD_SPACING).
func _road_points() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var paths: Array[PackedVector3Array] = Roads.sampled(ROAD_SPACING)
	for p in paths.size():
		var path: PackedVector3Array = paths[p]
		for i in path.size():
			if _contains(path[i], ROAD_MARGIN):
				result.append({"path": p, "index": i, "point": path[i]})
	return result

# Emboscada: el grupo espera escondido al costado del camino, adelante de por
# donde viene el jugador. Devuelve false si no hay un lugar que sirva.
func _spawn_ambush(members: Array[EnemyData], night: bool, with_champion: bool) -> bool:
	var heading: Vector3 = _player.velocity if "velocity" in _player else Vector3.ZERO
	heading.y = 0.0
	var candidates: Array[Dictionary] = []
	for road in _road_points():
		var to_point: Vector3 = road.point - _player.global_position
		to_point.y = 0.0
		var d: float = to_point.length()
		if d < AMBUSH_MIN_DISTANCE or d > AMBUSH_MAX_DISTANCE:
			continue
		# Si camina, solo adelante suyo; quieto, cualquiera.
		if heading.length() > 50.0 and to_point.normalized().dot(heading.normalized()) < 0.3:
			continue
		candidates.append(road)
	candidates.shuffle()
	for road in candidates:
		var path: PackedVector3Array = Roads.sampled(ROAD_SPACING)[road.path]
		var along: Vector3 = path[mini(road.index + 1, path.size() - 1)] - path[maxi(road.index - 1, 0)]
		var side: Vector3 = Vector3(-along.z, 0.0, along.x).normalized() * (1.0 if randf() < 0.5 else -1.0)
		var spot = _on_navmesh(road.point + side * randf_range(AMBUSH_SIDE.x, AMBUSH_SIDE.y))
		if spot == null or _on_camera(spot):
			continue
		_spawn_group(members, spot, night, with_champion, func(enemy: Node) -> void: enemy.ambush = true)
		return true
	return false

# Patrulla: aparece sobre un camino, fuera de camara, y lo recorre ida y vuelta
# por un tramo de unos cuantos puntos.
func _spawn_patrol(members: Array[EnemyData], night: bool, with_champion: bool) -> bool:
	var candidates: Array[Dictionary] = []
	for road in _road_points():
		var d: float = road.point.distance_to(Vector3(_player.global_position.x, 0.0, _player.global_position.z))
		if d >= AMBUSH_MIN_DISTANCE and d <= SPAWN_MAX_DISTANCE and not _on_camera(road.point):
			candidates.append(road)
	if candidates.is_empty():
		return false
	var start: Dictionary = candidates.pick_random()
	var spot = _on_navmesh(start.point)
	if spot == null:
		return false
	var path: PackedVector3Array = Roads.sampled(ROAD_SPACING)[start.path]
	var route := PackedVector3Array()
	for i in range(maxi(start.index - 3, 0), mini(start.index + 4, path.size())):
		if _contains(path[i], ROAD_MARGIN):
			route.append(path[i])
	if route.size() < 2:
		return false
	var first: int = route.find(start.point)
	_spawn_group(members, spot, night, with_champion, func(enemy: Node) -> void:
		enemy.patrol = route
		enemy.patrol_offset = Vector3(randf_range(-130.0, 130.0), 0.0, randf_range(-130.0, 130.0))
		enemy._patrol_index = maxi(first, 0)
		enemy._patrol_step = 1 if randf() < 0.5 else -1)
	return true
