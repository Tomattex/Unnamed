extends CharacterBody3D

## Base de la gente que camina sola (guardias, aldeanos, viajeros de los
## eventos del camino): carga su modelo de 0 A.D., sigue caminos de la
## navegacion y cambia de animacion. No bloquea al jugador ni a los enemigos
## (capa 0): solo choca con el mundo para no atravesar paredes.

const MODEL_SCALE: float = 225.0
const REPATH_INTERVAL: float = 0.5
## Distancia a la que un punto del camino cuenta como alcanzado.
const POINT_REACHED: float = 30.0
const LABEL_RANGE: float = 900.0
## Atascos: cada STUCK_CHECK segundos mira si avanzo al menos STUCK_DISTANCE;
## si no, recalcula el camino con un paso al costado y, si sigue trabado y
## nadie lo ve, aparece en el punto siguiente del camino.
const STUCK_CHECK: float = 0.5
const STUCK_DISTANCE: float = 20.0
const STUCK_SIDESTEP: float = 1.0
const STUCK_TELEPORT: float = 3.0

var _anim: AnimationPlayer
var _model: Node3D
var _label: Label3D
var _path := PackedVector3Array()
var _path_index: int = 0
var _repath: float = 0.0
var _label_check: float = 0.0
var _stuck_timer: float = 0.0
var _stuck_for: float = 0.0
var _stuck_from := Vector3.INF
var _sidestep := Vector3.ZERO


## Arma el cuerpo: colision, modelo (con la ropa teñida de tint) y nombre.
func setup(model_path: String, tint: Color = Color.WHITE, display_name: String = "") -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 340.0
	# Mas finito que el radio de la navegacion (60): asi no roza las esquinas.
	capsule.radius = 42.0
	shape.shape = capsule
	shape.position.y = 185.0
	add_child(shape)
	_model = load(model_path).instantiate()
	_model.scale = Vector3.ONE * MODEL_SCALE
	add_child(_model)
	if tint != Color.WHITE:
		_tint_clothes(_model, tint)
	_anim = _model.find_child("AnimationPlayer", true, false)
	for anim_name in _anim.get_animation_list():
		if anim_name.begins_with("idle") or anim_name.begins_with("walk") or anim_name.begins_with("run"):
			_anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	if not display_name.is_empty():
		_label = _name_label(display_name)
		add_child(_label)


func play(anim_name: String, blend: float = 0.2) -> void:
	if _anim and _anim.current_animation != anim_name and _anim.has_animation(anim_name):
		_anim.play(anim_name, blend)


## Camina hacia goal por la navegacion. Devuelve la distancia que falta hasta
## el final del camino (si goal no se puede alcanzar, el lugar mas cercano).
func walk_to(goal: Vector3, speed: float, delta: float) -> float:
	_repath -= delta
	if _repath <= 0.0 or _path_index >= _path.size():
		_repath = REPATH_INTERVAL
		_path = NavigationServer3D.map_get_path(get_world_3d().navigation_map, global_position + _sidestep, goal, true)
		_path_index = 1 if _path.size() > 1 else 0
	if not _path.is_empty():
		goal = _path[_path.size() - 1]
	_check_stuck(goal, delta)
	var next: Vector3 = goal
	while _path_index < _path.size():
		var point: Vector3 = _path[_path_index]
		if Vector2(point.x - global_position.x, point.z - global_position.z).length() > POINT_REACHED:
			next = point
			break
		_path_index += 1
	var dir: Vector3 = next - global_position
	dir.y = 0.0
	if dir.length() > 1.0:
		velocity = dir.normalized() * speed
		move_and_slide()
		global_position.y = 0.0
		face(dir, delta, 10.0)
	var left: Vector3 = goal - global_position
	left.y = 0.0
	return left.length()


func _check_stuck(goal: Vector3, delta: float) -> void:
	_stuck_timer -= delta
	if _stuck_timer > 0.0:
		return
	_stuck_timer = STUCK_CHECK
	var moved: float = INF if not _stuck_from.is_finite() else Vector2(global_position.x - _stuck_from.x, global_position.z - _stuck_from.z).length()
	_stuck_from = global_position
	var left: float = Vector2(goal.x - global_position.x, goal.z - global_position.z).length()
	if moved >= STUCK_DISTANCE or left < POINT_REACHED * 2.0:
		_stuck_for = 0.0
		_sidestep = Vector3.ZERO
		return
	_stuck_for += STUCK_CHECK
	if _stuck_for >= STUCK_SIDESTEP:
		# Probar desde un costado (el camino nuevo arranca de otro lado de la esquina).
		_sidestep = Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() * 80.0
		_repath = 0.0
	if _stuck_for >= STUCK_TELEPORT and _path_index < _path.size() and not _on_screen():
		global_position = Vector3(_path[_path_index].x, 0.0, _path[_path_index].z)
		_stuck_for = 0.0
		_repath = 0.0


func _on_screen() -> bool:
	var camera: Camera3D = get_viewport().get_camera_3d()
	return camera != null and camera.is_position_in_frustum(global_position + Vector3.UP * 200.0)


func face(dir: Vector3, delta: float, turn_speed: float = 6.0) -> void:
	if Vector2(dir.x, dir.z).length() > 1.0:
		rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), turn_speed * delta)


## Muestra el nombre solo con el jugador cerca (si no, la aldea se llena de carteles).
func update_label(delta: float) -> void:
	if _label == null:
		return
	_label_check -= delta
	if _label_check > 0.0:
		return
	_label_check = 0.3
	var player: Node3D = get_tree().get_first_node_in_group("player")
	_label.visible = player != null and global_position.distance_to(player.global_position) < LABEL_RANGE


## Un texto que dice (sube y se desvanece arriba de la cabeza).
func say(text: String, color: Color = Color(0.95, 0.9, 0.75)) -> void:
	floating_text.spawn(global_position + Vector3.UP * 460.0, text, color, 17, 0.6)


func _name_label(text: String) -> Label3D:
	var label := Label3D.new()
	label.name = "NameLabel"
	label.position.y = 440.0
	label.layers = 2
	label.pixel_size = 0.0016
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = true
	label.render_priority = 10
	label.outline_render_priority = 9
	label.modulate = Color(0.85, 0.85, 0.78)
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.text = text
	label.font_size = 26
	label.outline_size = 10
	label.visible = false
	return label


# Tiñe la ropa (las texturas "body" de 0 A.D.), no la cara ni las manos.
func _tint_clothes(node: Node, tint: Color) -> void:
	for mesh_instance in node.find_children("*", "MeshInstance3D", true, false):
		var mesh: Mesh = mesh_instance.mesh
		if mesh == null:
			continue
		for i in mesh.get_surface_count():
			var material := mesh_instance.get_active_material(i) as StandardMaterial3D
			if material == null or material.albedo_texture == null or not material.albedo_texture.resource_path.contains("_body_"):
				continue
			var copy: StandardMaterial3D = material.duplicate()
			copy.albedo_color = material.albedo_color * tint
			mesh_instance.set_surface_override_material(i, copy)
