extends Node3D

## Marca en el piso de adonde va el jugador (ver Movement.gd): un glifo que
## gira (click_marker.gdshader), con una onda y unas chispas al clickear.
## Verde para caminar; dorada para ir a juntar algo o a hablar con alguien.
## Mantener el clic apretado la va corriendo sin repetir la entrada, y al
## llegar se apaga de a poco.

enum Kind { MOVE, INTERACT }

const SHADER := preload("res://scripts/player/click_marker.gdshader")
const COLORS := {
	Kind.MOVE: Color(0.42, 1.0, 0.58),
	Kind.INTERACT: Color(1.0, 0.8, 0.38),
}
## Diametro del glifo (el personaje mide ~400).
const SIZE: float = 320.0
## Altura sobre el piso (que no pelee con el terreno).
const LIFT: float = 4.0
## Escala con la que aparece y se achica hasta 1.
const POP_SCALE: float = 1.35
const POP_TIME: float = 0.22
const FADE_TIME: float = 0.3
const SPARKS: int = 14

var _material: ShaderMaterial
var _age: float = 10.0
var _fade: float = 1.0
var _leaving: bool = false


func _ready() -> void:
	for child in get_children():
		child.queue_free()
	_material = ShaderMaterial.new()
	_material.shader = SHADER
	_material.render_priority = 1
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	var glyph := MeshInstance3D.new()
	glyph.name = "Glifo"
	glyph.mesh = plane
	glyph.material_override = _material
	glyph.position.y = LIFT
	glyph.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glyph)
	hide()


## Pone la marca en point. Con burst (un clic nuevo) repite la entrada: la
## onda, las flechas que llegan y las chispas; sin burst solo la corre.
func mark(point: Vector3, kind: int = Kind.MOVE, burst: bool = true) -> void:
	global_position = point
	var color: Color = COLORS[kind]
	_material.set_shader_parameter("tint", color)
	_leaving = false
	_fade = 1.0
	if burst or not visible:
		_age = 0.0
		scale = Vector3.ONE * POP_SCALE
		_spark_burst(point, color)
	show()


## Mueve la marca sin repetir la entrada (el camino termino en otro lado).
func follow(point: Vector3) -> void:
	global_position = point


## El jugador llego: se apaga de a poco.
func arrive() -> void:
	if visible:
		_leaving = true


## Se borra en el acto (por ejemplo, al marcar un enemigo).
func clear() -> void:
	_leaving = false
	hide()


# Chispas que saltan del anillo; van sueltas en el mundo, asi no se cortan
# si la marca se apaga o se mueve.
func _spark_burst(point: Vector3, color: Color) -> void:
	var sparks: CPUParticles3D = Effects.particles(Effects.STAR, true, 1, SPARKS, 0.7, 34.0)
	sparks.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	sparks.emission_ring_axis = Vector3.UP
	sparks.emission_ring_radius = SIZE * 0.32
	sparks.emission_ring_inner_radius = SIZE * 0.25
	sparks.emission_ring_height = 1.0
	sparks.direction = Vector3.UP
	sparks.spread = 18.0
	sparks.initial_velocity_min = 140.0
	sparks.initial_velocity_max = 260.0
	sparks.gravity = Vector3(0, -260.0, 0)
	sparks.damping_min = 60.0
	sparks.damping_max = 120.0
	sparks.angle_max = 180.0
	sparks.scale_amount_curve = Effects.curve([Vector2(0, 1.0), Vector2(1, 0.0)])
	sparks.color_ramp = Effects.ramp([Color(1, 1, 1), color.lightened(0.25), Color(color, 0.0)])
	Effects.emit_once(get_parent(), sparks, point + Vector3.UP * (LIFT + 6.0), 0.9)


func _process(delta: float) -> void:
	if not visible:
		return
	_age += delta
	if _age < POP_TIME:
		var t: float = _age / POP_TIME
		scale = Vector3.ONE * lerpf(POP_SCALE, 1.0, 1.0 - pow(1.0 - t, 3.0))
	elif scale.x != 1.0:
		scale = Vector3.ONE
	if _leaving:
		_fade -= delta / FADE_TIME
		if _fade <= 0.0:
			_leaving = false
			hide()
			return
	_material.set_shader_parameter("age", _age)
	_material.set_shader_parameter("fade", _fade)
