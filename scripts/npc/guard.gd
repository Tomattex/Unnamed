extends "res://scripts/npc/walker.gd"

## Guardia de un porton de la muralla (lo pone world/build_world.gd mirando
## hacia afuera). Se queda en su puesto; si un enemigo se acerca a la aldea
## sale a pelearlo y despues vuelve. Los enemigos no lo atacan a el: esta
## para que la aldea sea un lugar seguro, no para pelear por el jugador.

const MODEL := "res://assets/characters/oad/characters/warrior.glb"
## Hasta donde sale a buscar enemigos (medido desde su puesto).
const GUARD_RANGE: float = 1500.0
const RUN_SPEED: float = 520.0
const WALK_SPEED: float = 240.0
const ATTACKS := ["attack_1h_a", "attack_1h_b", "attack_1h_c"]
## Segundos entre golpes, y en que momento del golpe pega.
const ATTACK_TIME: float = 1.1
const HIT_DELAY: float = 0.4
## Cada golpe saca esta parte de la vida maxima del enemigo.
const HIT_FRACTION: float = 0.16
const LOOK_INTERVAL: float = 0.3

var _post: Vector3
var _facing: float
var _target: Node3D
var _look: float = 0.0
var _attack_left: float = 0.0
var _hit_left: float = -1.0


func _ready() -> void:
	add_to_group("guards")
	_post = global_position
	_facing = rotation.y
	setup(MODEL, Color.WHITE, "Guardia")
	play("idle")


func _physics_process(delta: float) -> void:
	update_label(delta)
	_attack_left -= delta
	if _hit_left >= 0.0:
		_hit_left -= delta
		if _hit_left < 0.0:
			_land_hit()
	_look -= delta
	if _look <= 0.0:
		_look = LOOK_INTERVAL
		_target = _find_enemy()
	# Mientras dura el golpe no se mueve.
	if _attack_left > ATTACK_TIME - 0.6:
		return
	if is_instance_valid(_target) and not _target.dead:
		var to_target: Vector3 = _target.global_position - global_position
		to_target.y = 0.0
		if to_target.length() <= 160.0 + _target.body_radius():
			face(to_target, delta, 12.0)
			if _attack_left <= 0.0:
				_attack()
			elif not _anim.is_playing():
				play("idle_combat")
			return
		walk_to(_target.global_position, RUN_SPEED, delta)
		play("run_combat")
		return
	if walk_to(_post, WALK_SPEED, delta) > 25.0:
		play("walk")
	else:
		rotation.y = lerp_angle(rotation.y, _facing, 4.0 * delta)
		play("idle")


func _find_enemy() -> Node3D:
	var best: Node3D = null
	# El que ya persigue sigue valiendo un poco mas lejos (no cambia a cada rato).
	var best_distance: float = GUARD_RANGE
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.dead:
			continue
		var distance: float = Vector2(enemy.global_position.x - _post.x, enemy.global_position.z - _post.z).length()
		if enemy == _target:
			distance -= 300.0
		if distance < best_distance:
			best_distance = distance
			best = enemy
	return best


func _attack() -> void:
	_attack_left = ATTACK_TIME
	_hit_left = HIT_DELAY
	_anim.play(ATTACKS.pick_random(), 0.1)
	_anim.seek(0.0, true)


func _land_hit() -> void:
	if not is_instance_valid(_target) or _target.dead:
		return
	if global_position.distance_to(_target.global_position) > 320.0 + _target.body_radius():
		return
	_target.take_hit({"parts": {Damage.Type.PHYSICAL: _target.max_health * HIT_FRACTION}})
