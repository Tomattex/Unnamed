extends Node3D

## Proyectil de la Bola de Fuego (y del Meteoro, que cae desde arriba con
## travel fijo). Vuela en linea recta y explota al tocar un enemigo o al
## llegar a su distancia, dañando a todos los enemigos dentro del radio.
## Se ve como un nucleo al rojo blanco con halo y llamas que giran, estela de
## fuego, humo y brasas, y una luz que titila (ver SpellFx.fire_body); al
## explotar, SpellFx.fire_blast. El meteoro es mas grande en todo. Al explotar
## la estela no desaparece de golpe: deja de emitir y se apaga.

const HIT_RADIUS: float = 60.0
## Tiempo que queda el nodo despues de explotar para que la estela se apague.
const LINGER: float = 1.4
## Tamaño del meteoro respecto de la bola de fuego.
const METEOR_POWER: float = 1.8

var direction: Vector3 = Vector3.FORWARD
var speed: float = 1500.0
## Distancia que recorre antes de explotar (0 = la de la habilidad).
var travel: float = 0.0
## Habilidad que la lanzo (alcance, radio, multiplicador y tipo de daño).
var skill: SkillData
## Nivel de la habilidad al tirarla (mas daño).
var skill_level: int = 1
var color: Color = Color(1, 0.5, 0.12)

var _traveled: float = 0.0
var _exploded: bool = false
var _time: float = 0.0
var _power: float = 1.0
var _core: Array = []
var _trails: Array = []
var _light: OmniLight3D


func _ready() -> void:
	# Con travel fijo es el meteoro.
	_power = METEOR_POWER if travel > 0.0 else 1.0
	var body: Dictionary = SpellFx.fire_body(self, direction, _power)
	_core = body.core
	_trails = body.trails
	_light = body.light


func _process(delta: float) -> void:
	_time += delta
	if not _exploded:
		# Titila como fuego de verdad. El meteoro alumbra menos: viene de
		# arriba y con mucho alcance teñia toda la pantalla.
		var base: float = 1.8 if _power <= 1.0 else 1.0
		_light.light_energy = base + sin(_time * 31.0) * 0.3 + sin(_time * 17.0) * 0.25


func _physics_process(delta: float) -> void:
	if _exploded:
		return
	var step: float = speed * delta
	global_position += direction * step
	_traveled += step

	# Con travel fijo (el meteoro que cae) no explota en el aire al pasar
	# sobre un enemigo: llega al piso.
	if travel <= 0.0:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			var offset: Vector3 = enemy.global_position - global_position
			offset.y = 0.0
			if offset.length() <= HIT_RADIUS + enemy.body_radius():
				_explode()
				return
	if _traveled >= (travel if travel > 0.0 else skill.max_range):
		_explode()


func _explode() -> void:
	_exploded = true
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0.0
		if offset.length() <= skill.radius:
			enemy.take_hit(player_stats.roll_skill(skill, skill_level))
	sfx.play_at("hit", global_position, 2.0, 0.15)
	SpellFx.fire_blast(get_parent(), global_position, skill.radius, _power)

	# El nucleo desaparece; la estela deja de salir y se apaga sola.
	for system in _core:
		system.visible = false
		system.emitting = false
	for system in _trails:
		system.emitting = false
	_light.visible = false
	get_tree().create_timer(LINGER * _power, false).timeout.connect(queue_free)
