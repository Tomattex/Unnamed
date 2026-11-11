extends Node3D

## Sonido del agua cerca del jugador: la correntada de los rios y las olas
## del mar. Dos sonidos de fondo (no posicionales) que suben y bajan con la
## distancia a la orilla mas cercana; asi no hacen falta decenas de fuentes
## 3D a lo largo de los rios. Los tramos los pone world/build_world.gd.

const RIVER := "res://sounds/ambient/water/rio.wav"
const SURF := "res://sounds/ambient/water/olas.wav"
## Distancia a la que el sonido esta al maximo y a la que deja de oirse.
const NEAR: float = 350.0
const FAR: float = 2200.0
const RIVER_DB: float = -10.0
const SURF_DB: float = -8.0
const CHECK_INTERVAL: float = 0.25
const FADE_SPEED: float = 1.5

## Tramos de los rios, de a pares (a, b).
@export var river_segments := PackedVector2Array()
## Puntos de la orilla del mar.
@export var shore := PackedVector2Array()

var _river: AudioStreamPlayer
var _surf: AudioStreamPlayer
var _river_target: float = 0.0
var _surf_target: float = 0.0
var _river_level: float = 0.0
var _surf_level: float = 0.0
var _check: float = 0.0


func _ready() -> void:
	_river = _player(RIVER)
	_surf = _player(SURF)


func _process(delta: float) -> void:
	_check -= delta
	if _check <= 0.0:
		_check = CHECK_INTERVAL
		var player: Node3D = get_tree().get_first_node_in_group("player")
		if player:
			var p := Vector2(player.global_position.x, player.global_position.z)
			_river_target = _closeness(_distance_to_pairs(p))
			_surf_target = _closeness(_distance_to_line(p, shore))
	_river_level = move_toward(_river_level, _river_target, FADE_SPEED * delta)
	_surf_level = move_toward(_surf_level, _surf_target, FADE_SPEED * delta)
	_apply(_river, _river_level, RIVER_DB)
	_apply(_surf, _surf_level, SURF_DB)


## Volumen (0 a 1) del rio y del mar en este momento (para las pruebas).
func levels() -> Vector2:
	return Vector2(_river_target, _surf_target)


func _closeness(distance: float) -> float:
	return 1.0 - smoothstep(NEAR, FAR, distance)


func _distance_to_pairs(p: Vector2) -> float:
	var best: float = INF
	for i in range(0, river_segments.size() - 1, 2):
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, river_segments[i], river_segments[i + 1])))
	return best


func _distance_to_line(p: Vector2, line: PackedVector2Array) -> float:
	var best: float = INF
	for i in line.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1])))
	return best


func _player(path: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = &"Ambiente"
	player.volume_db = -80.0
	if ResourceLoader.exists(path):
		var stream: AudioStream = load(path)
		if stream is AudioStreamWAV:
			stream = stream.duplicate()
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
		player.stream = stream
	add_child(player)
	return player


func _apply(player: AudioStreamPlayer, level: float, max_db: float) -> void:
	if player.stream == null:
		return
	if level <= 0.01:
		if player.playing:
			player.stop()
		return
	player.volume_db = max_db + linear_to_db(level)
	if not player.playing:
		player.play(randf() * 8.0)
