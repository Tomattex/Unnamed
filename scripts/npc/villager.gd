extends "res://scripts/npc/walker.gd"

## Aldeano (los pone world/build_world.gd): de dia va de un lugar de la aldea
## a otro y se queda un rato en cada uno; de noche vuelve a su casa y entra
## hasta que amanece. Si el jugador pasa cerca, a veces le dice algo.

const SPEED: float = 230.0
## Segundos que se queda en cada lugar.
const WAIT := Vector2(4.0, 12.0)
## Si tarda mas que esto en llegar (trabado), elige otro lugar.
const GIVE_UP_TIME: float = 30.0
const SPOT_SPREAD: float = 160.0
const TALK_RANGE: float = 520.0
const TALK_COOLDOWN := Vector2(45.0, 100.0)
const LINES := [
	"Buen día, forastero.",
	"Dicen que en la ciénaga se oyen voces de noche.",
	"Cuidado en los caminos: hay bandidos.",
	"El herrero sabe lo que hace.",
	"Por suerte hicieron los puentes sobre el río.",
	"En las cumbres hace un frío que corta.",
	"Los muertos no descansan en el camposanto.",
	"Al este, más allá de la costa, solo hay mar.",
	"Mi primo se fue al desierto y no volvió.",
	"Que los dioses lo acompañen.",
	"Con la muralla dormimos más tranquilos.",
]

@export var model_path: String = "res://assets/characters/oad/characters/merchant.glb"
@export var tint: Color = Color.WHITE
## Puerta de su casa (ahi entra de noche).
@export var home: Vector3
## Lugares de la aldea a los que va de dia.
@export var spots := PackedVector3Array()

var _target: Vector3
var _wait: float = 0.0
var _walking_for: float = 0.0
var _inside: bool = false
var _talk_cooldown: float = 0.0


func _ready() -> void:
	add_to_group("villagers")
	setup(model_path, tint)
	_target = global_position
	_wait = randf_range(0.0, WAIT.x)
	_talk_cooldown = randf_range(5.0, TALK_COOLDOWN.x)
	if world_time.is_night():
		_go_inside()
	else:
		play("idle")


func _physics_process(delta: float) -> void:
	var night: bool = world_time.is_night()
	if _inside:
		if not night:
			_come_out()
		return
	_talk_cooldown -= delta
	if night:
		_target = home
	# walk_to mide hasta el final del camino: si la puerta o el lugar quedan
	# adentro de algo, llega a lo mas cercano y listo.
	if _walking_for < GIVE_UP_TIME and walk_to(_target, SPEED, delta) > 40.0:
		_walking_for += delta
		play("walk")
		_try_talk(false, delta)
		return
	_walking_for = 0.0
	if night:
		_go_inside()
		return
	play("idle")
	_try_talk(true, delta)
	_wait -= delta
	if _wait <= 0.0:
		_wait = randf_range(WAIT.x, WAIT.y)
		_target = _pick_spot()


func _pick_spot() -> Vector3:
	if spots.is_empty():
		return home
	var spot: Vector3 = spots[randi() % spots.size()] + Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * SPOT_SPREAD
	var closest: Vector3 = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, spot)
	return Vector3(closest.x, 0.0, closest.z) if closest != Vector3.ZERO else spot


func _try_talk(standing: bool, delta: float) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > TALK_RANGE:
		return
	if standing:
		face(to_player, delta, 4.0)
	if _talk_cooldown <= 0.0:
		_talk_cooldown = randf_range(TALK_COOLDOWN.x, TALK_COOLDOWN.y)
		say(LINES.pick_random())


func _go_inside() -> void:
	_inside = true
	visible = false
	global_position = home
	velocity = Vector3.ZERO


func _come_out() -> void:
	_inside = false
	visible = true
	global_position = home
	_target = home
	_wait = randf_range(0.0, WAIT.x)
