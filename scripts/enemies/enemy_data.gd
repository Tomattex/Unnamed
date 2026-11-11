extends Resource

class_name EnemyData

## De que esta hecho el cuerpo: cambia las marcas en el piso, las particulas
## y el sonido de los golpes. SPIRIT = espectros (no sangran: se deshacen).
enum Body { FLESH, BONE, INSECT, UNDEAD, SPIRIT }
## Papel en su grupo (ver scripts/enemies/enemy_role.gd): el curandero cura y
## potencia a los suyos, el lider los enardece y el nigromante levanta a los
## esqueletos caidos.
enum Role { NONE, HEALER, LEADER, NECROMANCER }

## Tipo de enemigo: modelo, animaciones y stats base (a nivel 1).
## Cada tipo es un .tres en enemies/types/.

@export var name: String = "Enemigo"

@export_group("Modelo")
@export var model: PackedScene
@export var model_scale: float = 1.0
## Cuanto se sube el modelo para que los pies apoyen en el piso (a escala 1).
@export var model_offset_y: float = 290.0
## Color que multiplica la textura (blanco = sin cambio). Sirve para variantes.
@export var tint: Color = Color.WHITE
@export var collision_radius: float = 60.0
## Cuantos aparecen juntos (minimo, maximo) cuando una zona crea un grupo.
@export var pack_size: Vector2i = Vector2i(1, 3)

@export_group("Animaciones")
@export var idle_animation: String = ""
@export var walk_animations: Array[String] = []
@export var attack_animations: Array[String] = []
## Velocidad de la animacion de caminar (para bichos que solo traen una lenta).
@export var walk_animation_speed: float = 1.0
@export var death_animation: String = ""
## Si es true, la animacion de muerte se reproduce al reves (sirve cuando el
## modelo solo tiene una animacion de "levantarse del suelo").
@export var death_reversed: bool = false
## Animaciones al recibir un golpe (se elige una). Vacio = solo se sacude.
@export var hit_animations: Array[String] = []
## Otras muertes posibles ademas de death_animation (se elige una al azar).
@export var extra_death_animations: Array[String] = []
## Animacion al aparecer (ej: salir del suelo). Mientras dura, el enemigo no se mueve.
@export var spawn_animation: String = ""
@export var spawn_animation_speed: float = 1.0
## Al perseguir o huir (vacio = las de caminar, mas rapido).
@export var run_animation: String = ""
@export var run_animation_speed: float = 1.0
## Al curar, potenciar o levantar muertos (roles).
@export var cast_animation: String = ""

@export_group("Comportamiento")
## Pacifico (fauna): nunca ataca; huye del jugador y de los enemigos que se le
## acercan a menos de flee_range. Se puede cazar.
@export var passive: bool = false
@export var flee_range: float = 900.0
## Si es mayor que 0, se aleja cuando el jugador se le acerca a menos de esto
## (arqueros, magos) y vuelve a tirar desde lejos.
@export var keep_distance: float = 0.0
@export var role: Role = Role.NONE
## Compañeros con los que aparece (el lider con su banda, el chaman con sus
## esqueletos). Se elige al azar de la lista para cada uno.
@export var escorts: Array[EnemyData] = []
@export var escort_count: Vector2i = Vector2i(2, 3)
## Solo aparece de noche y se desvanece al amanecer.
@export var night_only: bool = false
## Vuela: el modelo se mece arriba y abajo (model_offset_y da la altura).
@export var hover_bob: float = 0.0
## Al perseguir zigzaguea (murcielagos).
@export var erratic: bool = false
## Fantasmal: semitransparente, con brillo en los bordes de este color.
@export var ghostly: bool = false
@export var ghost_color: Color = Color(0.55, 0.8, 1.0)
## Caza animales pacificos (y aldeanos) que tenga cerca si el jugador no esta.
@export var hunts_animals: bool = false
## Anda por los caminos: a veces su grupo patrulla uno o espera escondido al
## costado para emboscar (bandidos).
@export var roads: bool = false
## Color de sus conjuros (proyectiles magicos, curas).
@export var spell_color: Color = Color.TRANSPARENT

@export_group("Cuerpo")
@export var body: Body = Body.FLESH
## Al morir se desarma en huesos sueltos (esqueletos).
@export var crumbles: bool = false

@export_group("Stats")
@export var max_health: float = 60.0
@export var min_damage: int = 5
@export var max_damage: int = 9
@export var defense: int = 0
@export var speed: float = 260.0
## Segundos entre ataques.
@export var attack_cooldown: float = 1.6
@export var attack_range: float = 230.0
@export var detection_range: float = 1200.0
## Parte del daño del ataque que es de otro tipo (ej: el zombi envenena).
@export var attack_damage_type: Damage.Type = Damage.Type.PHYSICAL
@export_range(0.0, 1.0) var attack_conversion: float = 0.0
## Ataca de lejos: en el momento del golpe tira una flecha hacia donde esta el
## jugador (se puede esquivar moviendose) en vez de pegar cuerpo a cuerpo.
@export var shoots: bool = false
@export var projectile_speed: float = 1800.0

@export_group("Resistencias")
## En %. Negativo = debilidad (recibe mas daño). El fisico se reduce con la defensa.
@export_range(-100, 75) var resist_magic: float = 0.0
@export_range(-100, 75) var resist_poison: float = 0.0
@export_range(-100, 75) var resist_fire: float = 0.0

@export_group("Sonidos")
## Nombres de scripts/audio/sfx.gd ("" = sin sonido).
@export var aggro_sound: String = ""
@export var attack_sound: String = ""
@export var death_sound: String = ""

@export_group("Recompensas")
@export var xp_reward: int = 20
@export var gold_min: int = 2
@export var gold_max: int = 10


func get_resistances() -> Dictionary:
	return {
		Damage.Type.MAGIC: resist_magic,
		Damage.Type.POISON: resist_poison,
		Damage.Type.FIRE: resist_fire,
	}
