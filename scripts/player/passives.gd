class_name Passives

## Habilidades pasivas: lo que el personaje sabe hacer mejor con la practica
## (manejo de armas, equitacion, comercio...). Al llegar a los niveles de
## SLOT_LEVELS se elige una nueva; cada nivel del personaje da un punto para
## subir una que ya tenga, y los entrenadores de la aldea (scripts/npc/
## trainer.gd) las suben por oro. Ninguna pasa de MAX_LEVEL ni del nivel del
## personaje. El efecto lo aplica player_stats con passive_level().
##
## Cada entrada: name, description (con %s para el total del efecto),
## per_level (cuanto suma cada nivel), trainer (quien la enseña: "armas" el
## maestro de armas, "saber" la erudita) e icon.

const SLOT_LEVELS := [2, 4, 7, 10, 14, 18, 23, 28]
const MAX_LEVEL: int = 20
## Oro que pide un entrenador por subir una pasiva al nivel siguiente.
const TRAIN_BASE_PRICE: float = 120.0
const TRAIN_PRICE_GROWTH: float = 1.55

const LIST := {
	"manejo_armas": {
		"name": "Manejo de armas", "description": "+%s%% de daño con armas cuerpo a cuerpo",
		"per_level": 4.0, "trainer": "armas", "icon": "res://ui/icons/passives/manejo_armas.svg",
	},
	"ataque": {
		"name": "Ataque", "description": "+%s%% de velocidad de ataque",
		"per_level": 2.5, "trainer": "armas", "icon": "res://ui/icons/passives/ataque.svg",
	},
	"defensa": {
		"name": "Defensa", "description": "+%s%% de defensa",
		"per_level": 5.0, "trainer": "armas", "icon": "res://ui/icons/passives/defensa.svg",
	},
	"dos_manos": {
		"name": "Armas a dos manos", "description": "+%s%% de daño con armas a dos manos",
		"per_level": 6.0, "trainer": "armas", "icon": "res://ui/icons/passives/dos_manos.svg",
	},
	"dos_armas": {
		"name": "Combate con dos armas", "description": "+%s%% de velocidad de ataque con dos armas",
		"per_level": 4.0, "trainer": "armas", "icon": "res://ui/icons/passives/dos_armas.svg", "classes": ["guerrero"],
	},
	"tiro": {
		"name": "Tiro", "description": "+%s%% de daño con arcos y ballestas",
		"per_level": 5.0, "trainer": "armas", "icon": "res://ui/icons/passives/tiro.svg",
	},
	"constitucion": {
		"name": "Constitución", "description": "+%s%% de vida máxima",
		"per_level": 4.0, "trainer": "saber", "icon": "res://ui/icons/passives/constitucion.svg",
	},
	"concentracion": {
		"name": "Concentración", "description": "-%s%% de tiempo de recarga de las habilidades",
		"per_level": 3.0, "trainer": "saber", "icon": "res://ui/icons/passives/concentracion.svg",
	},
	"saber_arcano": {
		"name": "Saber arcano", "description": "+%s%% de daño mágico, de veneno y de fuego",
		"per_level": 5.0, "trainer": "saber", "icon": "res://ui/icons/passives/saber_arcano.svg",
	},
	"resistencia": {
		"name": "Resistencia", "description": "+%s%% a las resistencias a magia, veneno y fuego",
		"per_level": 2.5, "trainer": "saber", "icon": "res://ui/icons/passives/resistencia.svg",
	},
	"comercio": {
		"name": "Comercio", "description": "Comprás %s%% más barato y vendés más caro",
		"per_level": 3.0, "trainer": "saber", "icon": "res://ui/icons/passives/comercio.svg",
	},
	"equitacion": {
		"name": "Equitación", "description": "+%s%% de velocidad a caballo",
		"per_level": 4.0, "trainer": "saber", "icon": "res://ui/icons/passives/equitacion.svg",
	},
}
## Topes del efecto total (en %), para que ninguna rompa el juego.
const CAPS := {"concentracion": 50.0, "comercio": 40.0, "resistencia": 40.0}


static func get_info(id: String) -> Dictionary:
	return LIST.get(id, {})


## Las que puede aprender una clase (casi todas; alguna es de una sola).
static func available_for(class_id: String) -> Array[String]:
	var result: Array[String] = []
	for id in LIST:
		var classes: Array = LIST[id].get("classes", [])
		if classes.is_empty() or class_id in classes:
			result.append(id)
	return result


## Efecto total en % de una pasiva a ese nivel (con su tope).
static func effect(id: String, level: int) -> float:
	if level <= 0 or not LIST.has(id):
		return 0.0
	return minf(LIST[id].per_level * level, CAPS.get(id, INF))


static func describe(id: String, level: int) -> String:
	var value: float = effect(id, maxi(level, 1))
	var text: String = str(roundi(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value
	return LIST[id].description % text


## Cuantas pasivas distintas se pueden tener con ese nivel de personaje.
static func slots_for_level(character_level: int) -> int:
	var count: int = 0
	for level in SLOT_LEVELS:
		if character_level >= level:
			count += 1
	return count


## Nivel en el que se abre el proximo lugar (-1 si ya estan todos).
static func next_slot_level(character_level: int) -> int:
	for level in SLOT_LEVELS:
		if character_level < level:
			return level
	return -1


static func train_price(next_level: int) -> int:
	return roundi(TRAIN_BASE_PRICE * pow(next_level, TRAIN_PRICE_GROWTH) / 10.0) * 10
