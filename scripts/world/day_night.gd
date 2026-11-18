extends Node

## Parte visual del ciclo dia/noche: mueve el sol (de noche una luna azulada),
## cambia los colores del cielo y el volumen del ambiente segun world_time.
## Con el cielo cubierto (weather.overcast) el sol pierde fuerza y el cielo se
## pone gris. Tambien arma la imagen general (tonemap filmico, contraste y
## saturacion, un poco de brillo en las luces fuertes) y la tiñe apenas segun
## la region donde esta el jugador (el pantano verdoso, el desierto calido, la
## montaña fria, el cementerio apagado).

@export var sun_path: NodePath
@export var environment_path: NodePath
## Sonido de ambiente nocturno (grillos): sube de noche y baja de dia.
@export var ambience_path: NodePath

const SUN_MAX_ELEVATION: float = 65.0
const MOON_ELEVATION: float = 45.0

const DAY_SKY_TOP := Color(0.3, 0.5, 0.82)
const DAY_SKY_HORIZON := Color(0.74, 0.76, 0.76)
const DUSK_SKY_TOP := Color(0.32, 0.27, 0.42)
const DUSK_SKY_HORIZON := Color(0.95, 0.55, 0.3)
const NIGHT_SKY_TOP := Color(0.02, 0.03, 0.08)
const NIGHT_SKY_HORIZON := Color(0.06, 0.08, 0.16)

const SUN_COLOR := Color(1.0, 0.93, 0.8)
const DUSK_SUN_COLOR := Color(1.0, 0.58, 0.3)
const MOON_COLOR := Color(0.5, 0.62, 1.0)
## Energia del sol: al mediodia y cerca del horizonte; la luna.
const SUN_ENERGY := Vector2(0.55, 1.45)
const MOON_ENERGY: float = 0.32
## Luz ambiente (se mezcla con el color del cielo) de dia y de noche.
const AMBIENT_COLOR := Color(0.62, 0.58, 0.5)
const AMBIENT_ENERGY := Vector2(0.32, 0.62)
## Region (las de music.zone_at) -> tinte del sol y del ambiente y saturacion.
const REGION_GRADES := {
	"pantano": {"sun": Color(0.86, 0.94, 0.8), "ambient": Color(0.78, 0.9, 0.72), "saturation": 0.9},
	"montana": {"sun": Color(0.94, 0.97, 1.06), "ambient": Color(0.88, 0.94, 1.08), "saturation": 0.95},
	"desierto": {"sun": Color(1.08, 0.98, 0.84), "ambient": Color(1.06, 0.96, 0.8), "saturation": 1.08},
	"cementerio": {"sun": Color(0.86, 0.87, 0.95), "ambient": Color(0.82, 0.84, 0.94), "saturation": 0.82},
	"costa": {"sun": Color(1.02, 1.0, 0.97), "ambient": Color(0.95, 1.0, 1.06), "saturation": 1.05},
	"bosque": {"sun": Color(0.96, 1.0, 0.9), "ambient": Color(0.88, 0.96, 0.86), "saturation": 1.0},
}
const NO_GRADE := {"sun": Color.WHITE, "ambient": Color.WHITE, "saturation": 1.0}
## Que tan rapido pasa el tinte de una region a otra (por segundo).
const GRADE_SPEED: float = 0.4
const SATURATION: float = 1.12
const CONTRAST: float = 1.07
const OVERCAST_SKY_TOP := Color(0.42, 0.45, 0.5)
const OVERCAST_SKY_HORIZON := Color(0.58, 0.6, 0.63)

@onready var sun: DirectionalLight3D = get_node_or_null(sun_path)
@onready var world_environment: WorldEnvironment = get_node_or_null(environment_path)
@onready var ambience: AudioStreamPlayer = get_node_or_null(ambience_path)

var _sky: ProceduralSkyMaterial
var _grade_sun := Color.WHITE
var _grade_ambient := Color.WHITE
var _grade_saturation: float = 1.0
var _grade_check: float = 0.0
var _grade_target: Dictionary = NO_GRADE


func _ready() -> void:
	if world_environment and world_environment.environment:
		_setup_environment(world_environment.environment)
		if world_environment.environment.sky:
			_sky = world_environment.environment.sky.sky_material as ProceduralSkyMaterial
	_apply()


func _process(delta: float) -> void:
	_update_grade(delta)
	_apply()


func _setup_environment(environment: Environment) -> void:
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 1.0
	environment.tonemap_white = 6.0
	environment.adjustment_enabled = true
	environment.adjustment_contrast = CONTRAST
	environment.adjustment_saturation = SATURATION
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 0.55
	# Brillo suave alrededor de lo muy luminoso (fuego, hechizos, faroles).
	environment.glow_enabled = true
	environment.glow_intensity = 0.6
	environment.glow_strength = 0.9
	environment.glow_bloom = 0.0
	environment.glow_hdr_threshold = 1.1
	environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT


# El tinte de la region del jugador, que llega de a poco.
func _update_grade(delta: float) -> void:
	_grade_check -= delta
	if _grade_check <= 0.0:
		_grade_check = 0.5
		var player: Node3D = get_tree().get_first_node_in_group("player")
		_grade_target = REGION_GRADES.get(music.zone_at(player.global_position), NO_GRADE) if player else NO_GRADE
	var t: float = clampf(GRADE_SPEED * delta, 0.0, 1.0)
	_grade_sun = _grade_sun.lerp(_grade_target.sun, t)
	_grade_ambient = _grade_ambient.lerp(_grade_target.ambient, t)
	_grade_saturation = lerpf(_grade_saturation, _grade_target.saturation, t)


func _apply() -> void:
	var daylight: float = world_time.get_daylight()
	# Cerca del horizonte (amanecer/atardecer) los colores tiran a naranja.
	var dusk: float = clampf(1.0 - daylight * 1.6, 0.0, 1.0) if not world_time.is_night() else 0.0
	var cover: float = weather.overcast

	if sun:
		if world_time.is_night():
			var night_t: float = fposmod(world_time.hour - world_time.DUSK_HOUR, 24.0) / (24.0 - world_time.DUSK_HOUR + world_time.DAWN_HOUR)
			sun.rotation_degrees = Vector3(-MOON_ELEVATION * maxf(sin(night_t * PI), 0.2), night_t * 180.0 - 90.0, 0.0)
			sun.light_color = MOON_COLOR
			sun.light_energy = MOON_ENERGY
		else:
			var day_t: float = (world_time.hour - world_time.DAWN_HOUR) / (world_time.DUSK_HOUR - world_time.DAWN_HOUR)
			var elevation: float = maxf(sin(day_t * PI) * SUN_MAX_ELEVATION, 5.0)
			sun.rotation_degrees = Vector3(-elevation, day_t * 180.0 - 90.0, 0.0)
			sun.light_color = SUN_COLOR.lerp(DUSK_SUN_COLOR, dusk) * _grade_sun
			sun.light_energy = lerpf(SUN_ENERGY.x, SUN_ENERGY.y, daylight)
		sun.light_energy *= lerpf(1.0, 0.45, cover)
		sun.shadow_opacity = lerpf(1.0, 0.35, cover)

	if _sky:
		var top: Color = NIGHT_SKY_TOP.lerp(DAY_SKY_TOP, daylight)
		var horizon: Color = NIGHT_SKY_HORIZON.lerp(DAY_SKY_HORIZON, daylight)
		_sky.sky_top_color = top.lerp(DUSK_SKY_TOP, dusk * 0.6).lerp(OVERCAST_SKY_TOP * maxf(daylight, 0.12), cover * 0.85)
		_sky.sky_horizon_color = horizon.lerp(DUSK_SKY_HORIZON, dusk * 0.7).lerp(OVERCAST_SKY_HORIZON * maxf(daylight, 0.12), cover * 0.85)
		_sky.ground_horizon_color = _sky.sky_horizon_color
	if world_environment and world_environment.environment:
		var environment: Environment = world_environment.environment
		environment.ambient_light_energy = lerpf(AMBIENT_ENERGY.x, AMBIENT_ENERGY.y, daylight) * lerpf(1.0, 0.85, cover)
		environment.ambient_light_color = AMBIENT_COLOR * _grade_ambient
		environment.adjustment_saturation = SATURATION * _grade_saturation * lerpf(1.0, 0.85, cover)

	if ambience:
		# Con lluvia los grillos se callan.
		ambience.volume_db = lerpf(-8.0, -22.0, daylight) - weather.rain * 20.0
