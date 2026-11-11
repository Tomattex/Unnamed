extends Resource

class_name SkillData

## Habilidad del jugador. No usan mana: cada una tiene un tiempo de recarga
## que se acorta con Concentracion. Cada habilidad es un .tres en skills/.
## Se aprenden y suben de nivel leyendo runas (ver skill_book.gd): cada nivel
## pega mas fuerte (o dura y protege mas, las mejoras) pero tarda mas en
## recargarse. Los valores de los .tres son los del nivel 1.

enum Kind {
	STRIKE,      # golpe fuerte a un enemigo (camina hasta el si esta lejos)
	WHIRLWIND,   # daño a todos los enemigos alrededor
	PROJECTILE,  # proyectil hacia el mouse que explota en area
	BUFF,        # mejora temporal del personaje
	VOLLEY,      # uno o varios virotes en abanico hacia el mouse
	RAIN,        # lluvia sobre el punto del mouse: cae al rato y daña en area
}

@export var name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var kind: Kind = Kind.STRIKE
## Ya no se usa para aprenderla (eso es con runas): sirve para ordenar las
## habilidades de la clase y para las partidas de antes de las runas.
@export var unlock_level: int = 1
## Segundos de recarga con Concentracion 0.
@export var base_cooldown: float = 5.0

@export_group("Daño")
@export var damage_multiplier: float = 1.0
@export var radius: float = 0.0
## Distancia maxima del proyectil.
@export var max_range: float = 0.0
## Tipo de daño de la habilidad: esa parte del daño fisico del arma pasa a ese tipo.
@export var damage_type: Damage.Type = Damage.Type.PHYSICAL
@export_range(0.0, 1.0) var damage_conversion: float = 0.0
## Hechizo: el daño base sale del nivel y la Concentracion, no del arma.
@export var spell: bool = false
## VOLLEY: cantidad de virotes y apertura del abanico (en grados).
@export var count: int = 1
@export var spread_deg: float = 0.0
## RAIN: segundos desde que se marca el lugar hasta que cae.
@export var delay: float = 0.6
## WHIRLWIND: el personaje gira (el anillo de llamas sale sin girar).
@export var spin: bool = true

@export_group("Mejora temporal")
@export var buff_duration: float = 0.0
@export var buff_damage_multiplier: float = 1.0
@export var buff_attack_speed_multiplier: float = 1.0
@export var buff_defense: int = 0
## Suma a las resistencias a magia, veneno y fuego (en %).
@export var buff_resistance: float = 0.0

@export_group("Presentacion")
@export var sound: String = ""
@export var animation: String = ""
@export var animation_speed: float = 1.0
@export var effect_color: Color = Color.WHITE


## Cuanto suma cada nivel de la habilidad (sobre los valores del nivel 1).
const DAMAGE_PER_LEVEL: float = 0.2
const COOLDOWN_PER_LEVEL: float = 0.08
const BUFF_PER_LEVEL: float = 0.15
const DURATION_PER_LEVEL: float = 0.1
## Las rafagas de virotes suman uno cada tantos niveles (hasta EXTRA_COUNT_MAX).
const LEVELS_PER_EXTRA_COUNT: int = 4
const EXTRA_COUNT_MAX: int = 3


## Multiplicador de daño a ese nivel de la habilidad.
func damage_at(level: int) -> float:
	return damage_multiplier * (1.0 + DAMAGE_PER_LEVEL * (maxi(level, 1) - 1))


## Recarga a ese nivel, sin la Concentracion (base_cooldown es la del nivel 1).
func base_cooldown_at(level: int) -> float:
	return base_cooldown * (1.0 + COOLDOWN_PER_LEVEL * (maxi(level, 1) - 1))


func get_cooldown(level: int = 1) -> float:
	return base_cooldown_at(level) * player_stats.get_cooldown_multiplier()


## Virotes que tira a ese nivel (rafagas y lluvia).
func count_at(level: int) -> int:
	return maxi(count, 1) + mini((maxi(level, 1) - 1) / LEVELS_PER_EXTRA_COUNT, EXTRA_COUNT_MAX)


func buff_duration_at(level: int) -> float:
	return buff_duration * (1.0 + DURATION_PER_LEVEL * (maxi(level, 1) - 1))


## Mejora temporal a ese nivel: crece lo que suma (no el valor entero).
func buff_damage_at(level: int) -> float:
	return 1.0 + (buff_damage_multiplier - 1.0) * (1.0 + BUFF_PER_LEVEL * (maxi(level, 1) - 1))


func buff_speed_at(level: int) -> float:
	return 1.0 + (buff_attack_speed_multiplier - 1.0) * (1.0 + BUFF_PER_LEVEL * (maxi(level, 1) - 1))


func buff_defense_at(level: int) -> int:
	return roundi(buff_defense * (1.0 + BUFF_PER_LEVEL * (maxi(level, 1) - 1)))


func buff_resistance_at(level: int) -> float:
	return buff_resistance * (1.0 + BUFF_PER_LEVEL * (maxi(level, 1) - 1))


## Tooltip con el nivel actual y lo que cambia en el siguiente (level 0 =
## todavia no se aprendio: muestra el nivel 1).
func get_tooltip(level: int = 0) -> String:
	var lines := PackedStringArray([name if level <= 0 else "%s · nivel %d" % [name, level], description])
	if damage_conversion > 0.0 and damage_type != Damage.Type.PHYSICAL:
		lines.append("Daño: %d%% %s" % [roundi(damage_conversion * 100.0), Damage.NAMES[damage_type].to_lower()])
	if spell:
		lines.append("Hechizo: crece con el nivel y la Concentración")
	var shown: int = maxi(level, 1)
	for row in compare_lines(shown, shown + 1 if level > 0 else shown):
		lines.append(row)
	if level <= 0:
		lines.append("Se aprende leyendo su runa")
	else:
		lines.append("Una runa más la sube al nivel %d" % (level + 1))
	return "\n".join(lines)


## Lineas "Daño: 250% → 300%" entre dos niveles (iguales = sin flecha).
func compare_lines(from: int, to: int) -> PackedStringArray:
	# Array (y no PackedStringArray): la lambda lo tiene que modificar.
	var rows: Array[String] = []
	var arrow := func(label: String, a: String, b: String) -> void:
		rows.append("%s: %s" % [label, a] if a == b else "%s: %s → %s" % [label, a, b])
	if kind == Kind.BUFF:
		arrow.call("Duración", "%.0f s" % buff_duration_at(from), "%.0f s" % buff_duration_at(to))
		if buff_damage_multiplier != 1.0:
			arrow.call("Daño", "+%d%%" % roundi((buff_damage_at(from) - 1.0) * 100.0), "+%d%%" % roundi((buff_damage_at(to) - 1.0) * 100.0))
		if buff_attack_speed_multiplier != 1.0:
			arrow.call("Velocidad de ataque", "+%d%%" % roundi((buff_speed_at(from) - 1.0) * 100.0), "+%d%%" % roundi((buff_speed_at(to) - 1.0) * 100.0))
		if buff_defense != 0:
			arrow.call("Defensa", "+%d" % buff_defense_at(from), "+%d" % buff_defense_at(to))
		if buff_resistance != 0.0:
			arrow.call("Resistencias", "+%d%%" % roundi(buff_resistance_at(from)), "+%d%%" % roundi(buff_resistance_at(to)))
	else:
		arrow.call("Daño", "%d%%" % roundi(damage_at(from) * 100.0), "%d%%" % roundi(damage_at(to) * 100.0))
		if kind == Kind.VOLLEY or kind == Kind.RAIN:
			arrow.call("Virotes", str(count_at(from)), str(count_at(to)))
	arrow.call("Recarga", "%.1f s" % get_cooldown(from), "%.1f s" % get_cooldown(to))
	return PackedStringArray(rows)
