class_name Loot

## Generacion de botin: que suelta un enemigo al morir y como se arma un
## item aleatorio (rareza, bonificaciones y nombre).

# La escena del pickup se carga recien al usarla: pickup.gd usa autoloads y
# precargarla aca la compilaria antes de que existan.
const PICKUP_SCENE_PATH := "res://item/pickup.tscn"
const GOLD := preload("res://item/items/gold.tres")
const POTION := preload("res://item/items/potion_of_health.tres")
## Consumibles que no son la pocion de vida, con su probabilidad de caer.
const CONSUMABLES := {
	"res://item/items/antidoto.tres": 0.04,
	"res://item/items/pocion_fuego.tres": 0.03,
	"res://item/items/pocion_regeneracion.tres": 0.03,
	"res://item/items/pergamino_retorno.tres": 0.02,
}
## Parte del botin de equipo que es armadura (el resto, armas y escudos).
const ARMOR_SHARE: float = 0.55

## Armas, escudos y ballestas base que pueden aparecer como botin.
const BASE_ITEMS := [
	"res://item/items/espada_ligera.tres",
	"res://item/items/long_sword.tres",
	"res://item/items/hacha_grande.tres",
	"res://item/items/martillo_grande.tres",
	"res://item/items/mandoble.tres",
	"res://item/items/hacha_de_guerra.tres",
	"res://item/items/maza_de_guerra.tres",
	"res://item/items/escudo_ligero.tres",
	"res://item/items/escudo_mid.tres",
	"res://item/items/escudo_pesado.tres",
	"res://item/items/ballesta_de_madera.tres",
	"res://item/items/ballesta_pesada.tres",
	"res://item/items/arco_corto.tres",
	"res://item/items/arco_largo.tres",
	"res://item/items/arco_de_guerra.tres",
]
## Partes de armadura base que pueden aparecer como botin.
const ARMOR_ITEMS := [
	"res://item/items/capucha_cuero.tres",
	"res://item/items/capucha_lino.tres",
	"res://item/items/yelmo_hierro.tres",
	"res://item/items/armadura_cuero.tres",
	"res://item/items/jubon_acolchado.tres",
	"res://item/items/cota_malla.tres",
	"res://item/items/guantes_cuero.tres",
	"res://item/items/brazales_hierro.tres",
	"res://item/items/perneras_cuero.tres",
	"res://item/items/grebas_hierro.tres",
	"res://item/items/botas_cuero.tres",
	"res://item/items/botas_hierro.tres",
	"res://item/items/cinturon_cuero.tres",
	"res://item/items/cinturon_tachonado.tres",
	"res://item/items/anillo_oro.tres",
	"res://item/items/anillo_gema.tres",
	"res://item/items/amuleto_plata.tres",
	"res://item/items/collar_cuentas.tres",
]
## La defensa de la armadura sube este tanto por nivel del item.
const ARMOR_DEFENSE_PER_LEVEL: float = 0.06

## Probabilidad de que un enemigo suelte una gema (los elite, un poco mas).
const GEM_CHANCE: float = 0.05
## Probabilidad de que un enemigo suelte una runa (ver Runes).
const RUNE_CHANCE: float = 0.06

## Peso de cada rareza (normal, magico, raro, unico, set).
const RARITY_WEIGHTS := [60.0, 28.0, 10.0, 2.0, 3.0]
## Cantidad de bonificaciones por rareza.
const BONUS_COUNT := [Vector2i(0, 0), Vector2i(1, 2), Vector2i(3, 4), Vector2i(4, 4)]
## Mejora de daño/defensa base por rareza.
const BASE_STAT_MULT := [1.0, 1.1, 1.2, 1.35]
const VALUE_MULT := [1.0, 2.0, 4.0, 8.0]

## clave -> [minimo, maximo a nivel 1, crecimiento por nivel, sufijo del nombre].
const AFFIXES := {
	"fuerza": [1, 3, 0.5, "del Toro"],
	"destreza": [1, 3, 0.5, "del Halcón"],
	"vitalidad": [1, 3, 0.5, "del Oso"],
	"concentracion": [1, 3, 0.5, "del Sabio"],
	"vida": [5, 15, 3.0, "de la Vida"],
	"defensa": [3, 8, 1.5, "de Hierro"],
	"daño_pct": [5, 15, 1.0, "de la Furia"],
	"velocidad_pct": [4, 10, 0.5, "del Viento"],
	"critico": [1, 4, 0.3, "de la Precisión"],
	"regeneracion": [0.3, 1.0, 0.15, "de la Sanación"],
	"daño_magia": [2, 5, 1.0, "del Arcano"],
	"daño_veneno": [3, 7, 1.4, "de la Víbora"],
	"daño_fuego": [2, 5, 1.0, "de las Llamas"],
	"res_magia": [5, 12, 0.8, "del Hechicero"],
	"res_veneno": [5, 12, 0.8, "de la Serpiente"],
	"res_fuego": [5, 12, 0.8, "de la Salamandra"],
}
## Bonificaciones que solo salen en items que pegan (armas y ballestas).
const WEAPON_ONLY_AFFIXES := ["daño_magia", "daño_veneno", "daño_fuego"]
## Los unicos que pegan traen siempre uno de estos, mas fuerte.
const UNIQUE_ELEMENTS := ["daño_magia", "daño_veneno", "daño_fuego"]



## Lo que suelta un enemigo: lista de {item, quantity}. gold_mult y
## magic_find vienen de la dificultad.
static func roll_enemy_drops(data: EnemyData, level: int, gold_mult: float = 1.0, magic_find: float = 0.0) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	if randf() < 0.7:
		var amount: int = roundi(randi_range(data.gold_min, data.gold_max) * (1.0 + 0.2 * (level - 1)) * gold_mult)
		drops.append({"item": GOLD, "quantity": maxi(1, amount)})
	if randf() < 0.15:
		drops.append({"item": POTION, "quantity": 1})
	for path in CONSUMABLES:
		if randf() < CONSUMABLES[path]:
			drops.append({"item": load(path), "quantity": 1})
	# Los enemigos con mas experiencia (elites) sueltan equipo mas seguido.
	var item_chance: float = clampf((0.12 + data.xp_reward / 200.0) * (1.0 + magic_find), 0.0, 0.6)
	if randf() < item_chance:
		drops.append({"item": generate_item(level, -1, magic_find), "quantity": 1})
	if randf() < GEM_CHANCE * (1.0 + data.xp_reward / 100.0) * (1.0 + magic_find):
		var gem: Itemdata = Gems.roll_gem(level)
		if gem:
			drops.append({"item": gem, "quantity": 1})
	if randf() < RUNE_CHANCE * (1.0 + data.xp_reward / 100.0) * (1.0 + magic_find):
		var rune: Itemdata = Runes.roll()
		if rune:
			drops.append({"item": rune, "quantity": 1})
	return drops


## Lo que hay en un cofre del mundo: siempre oro, a veces pociones, uno o dos
## items con mas chance de ser buenos y, a veces, una gema. quality 1 = cofre
## bueno (mas items y gemas).
static func roll_chest_drops(level: int, quality: int, gold_mult: float = 1.0, magic_find: float = 0.0) -> Array[Dictionary]:
	var drops: Array[Dictionary] = []
	var gold: int = roundi(randi_range(15, 40) * (1.0 + 0.25 * (level - 1)) * (1.0 + quality) * gold_mult)
	drops.append({"item": GOLD, "quantity": gold})
	if randf() < 0.5:
		drops.append({"item": POTION, "quantity": randi_range(1, 2)})
	if randf() < 0.35:
		drops.append({"item": load(CONSUMABLES.keys().pick_random()), "quantity": 1})
	for i in 1 + quality:
		drops.append({"item": generate_item(level, -1, magic_find + 0.5 * (quality + 1)), "quantity": 1})
	if randf() < 0.25 + 0.2 * quality:
		var gem: Itemdata = Gems.roll_gem(level + 2 * quality)
		if gem:
			drops.append({"item": gem, "quantity": 1})
	if randf() < 0.35 + 0.2 * quality:
		var rune: Itemdata = Runes.roll()
		if rune:
			drops.append({"item": rune, "quantity": 1})
	return drops


## Crea un item aleatorio de nivel item_level a partir de un item base.
static func generate_item(item_level: int, forced_rarity: int = -1, magic_find: float = 0.0) -> Itemdata:
	var rarity: int = forced_rarity if forced_rarity >= 0 else _roll_rarity(magic_find)
	if rarity == Itemdata.Rarity.SET:
		var piece: Itemdata = ItemSets.generate_piece(item_level)
		_set_requirements(piece, item_level)
		return piece
	var base_path: String = (ARMOR_ITEMS if randf() < ARMOR_SHARE else BASE_ITEMS).pick_random()
	var item: Itemdata = load(base_path).duplicate()
	item.base_path = base_path
	# Los anillos y amuletos sin bonificaciones no sirven: salen al menos magicos.
	if rarity == Itemdata.Rarity.NORMAL and (item.item_type == Itemdata.ItemType.RING or item.item_type == Itemdata.ItemType.AMULET):
		rarity = Itemdata.Rarity.MAGIC
	item.rarity = rarity

	var mult: float = BASE_STAT_MULT[rarity]
	item.min_damage = roundi(item.min_damage * mult)
	item.max_damage = roundi(item.max_damage * mult)
	var level_mult: float = 1.0 + ARMOR_DEFENSE_PER_LEVEL * (item_level - 1) if item.is_armor() else 1.0
	item.defense = roundi(item.defense * mult * level_mult)

	var bonuses: Dictionary = {}
	var keys: Array = AFFIXES.keys().filter(func(key: String) -> bool:
		return item.has_damage() or key not in WEAPON_ONLY_AFFIXES)
	keys.shuffle()
	var count: int = randi_range(BONUS_COUNT[rarity].x, BONUS_COUNT[rarity].y)
	var strength: float = 1.5 if rarity == Itemdata.Rarity.UNIQUE else 1.0
	if rarity == Itemdata.Rarity.UNIQUE and item.has_damage():
		var element: String = UNIQUE_ELEMENTS.pick_random()
		keys.erase(element)
		bonuses[element] = _roll_affix(element, item_level, 2.0)
	for i in count:
		var key: String = keys[i]
		bonuses[key] = _roll_affix(key, item_level, strength)
	item.bonuses = bonuses

	if rarity == Itemdata.Rarity.UNIQUE:
		UniqueItems.apply(item, UniqueItems.pick(item.get_slot_kind()), item_level)
	elif count > 0:
		item.suffix = AFFIXES[keys[0]][3]
	item.value = roundi(item.value * VALUE_MULT[rarity] * (1.0 + 0.1 * (item_level - 1)))
	item.sockets = Gems.roll_sockets(rarity)
	item.gems = PackedStringArray()
	_set_requirements(item, item_level)
	return item


## Requisitos del item generado: nivel (un poco por debajo del de la zona) y
## los atributos del item base, que suben con el nivel.
static func _set_requirements(item: Itemdata, item_level: int) -> void:
	var margin: int = 3 if item.rarity == Itemdata.Rarity.NORMAL else 1
	item.required_level = maxi(item.required_level, item_level - margin)
	if item.required_level <= 1:
		item.required_level = 0
	var attributes: Dictionary = {}
	for key in item.required_attributes:
		attributes[key] = int(item.required_attributes[key]) + roundi(0.5 * (item_level - 1))
	item.required_attributes = attributes


static func _roll_affix(key: String, item_level: int, strength: float) -> float:
	var affix: Array = AFFIXES[key]
	var growth: float = affix[2] * (item_level - 1)
	var value: float = randf_range(affix[0] + growth, affix[1] + growth) * strength
	return snappedf(value, 0.1) if key == "regeneracion" else float(maxi(1, roundi(value)))


## magic_find multiplica el peso de todas las rarezas mejores que normal.
static func _roll_rarity(magic_find: float = 0.0) -> int:
	var weights: Array[float] = []
	var total: float = 0.0
	for i in RARITY_WEIGHTS.size():
		weights.append(RARITY_WEIGHTS[i] * (1.0 if i == 0 else 1.0 + magic_find))
		total += weights[i]
	var roll: float = randf() * total
	for i in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return 0


## Deja un item en el piso cerca de position (en un lugar libre, ver
## drop_spot). Con "pop" salta un poco antes de caer.
static func spawn_pickup(parent: Node, position: Vector3, item: Itemdata, quantity: int = 1, pop: bool = true) -> Node3D:
	var pickup: Node3D = load(PICKUP_SCENE_PATH).instantiate()
	pickup.item_data = item
	pickup.quantity = quantity
	var spot: Vector3 = drop_spot(parent, position)
	parent.add_child(pickup)
	pickup.global_position = Vector3(spot.x, 5.0, spot.z)
	if pop:
		pickup.pop_from(Vector3(position.x, 5.0, position.z))
	return pickup


## Donde cae lo que se suelta (un item, el botin de un cofre o de un
## enemigo): a 60-170 unidades de origin, alrededor.
const DROP_MIN: float = 60.0
const DROP_MAX: float = 170.0
const DROP_TRIES: int = 24
## Lo que mide un item tirado (para que no quede adentro de nada).
const DROP_ITEM_RADIUS: float = 32.0
## Mas lejos que esto del piso caminable es agua, un rincon cerrado o
## adentro de algo (la navegacion deja 60 de margen alrededor de lo solido).
const DROP_NAV_TOLERANCE: float = 75.0
## Separacion entre items tirados (si se puede).
const DROP_SPACING: float = 55.0


## Un punto del piso cerca de origin donde un item no queda adentro de una
## roca, un barril, un muro o el agua, ni del otro lado de una pared. Prueba
## alrededor, cada vez un poco mas lejos; si no encuentra ninguno, el punto
## caminable mas cercano a origin.
static func drop_spot(source: Node, origin: Vector3) -> Vector3:
	var flat_origin := Vector3(origin.x, 0.0, origin.z)
	if source == null or not source.is_inside_tree():
		return flat_origin
	var world: World3D = source.get_viewport().find_world_3d()
	var space: PhysicsDirectSpaceState3D = world.direct_space_state
	var map: RID = world.navigation_map
	var nav_ready: bool = NavigationServer3D.map_get_iteration_id(map) > 0
	var shape := SphereShape3D.new()
	shape.radius = DROP_ITEM_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	var others: Array[Node] = source.get_tree().get_nodes_in_group("pickups")
	for attempt in DROP_TRIES:
		var reach: float = lerpf(DROP_MIN, DROP_MAX, minf(float(attempt) / (DROP_TRIES * 0.6), 1.0))
		var angle: float = randf() * TAU
		var candidate: Vector3 = flat_origin + Vector3(cos(angle), 0.0, sin(angle)) * reach * randf_range(0.75, 1.0)
		if nav_ready:
			var closest: Vector3 = NavigationServer3D.map_get_closest_point(map, candidate)
			if Vector2(closest.x - candidate.x, closest.z - candidate.z).length() > DROP_NAV_TOLERANCE:
				continue
		# Algo solido donde caeria (la esfera va arriba del piso: no lo toca).
		query.transform = Transform3D(Basis.IDENTITY, candidate + Vector3.UP * (DROP_ITEM_RADIUS + 12.0))
		if _hits_static(space.intersect_shape(query, 8)):
			continue
		# Una pared o una roca entre el origen y el lugar.
		var ray := PhysicsRayQueryParameters3D.create(flat_origin + Vector3.UP * 60.0, candidate + Vector3.UP * 60.0, 1)
		var hit: Dictionary = space.intersect_ray(ray)
		if not hit.is_empty() and hit.collider is StaticBody3D:
			continue
		# Los primeros intentos, ademas, lejos de los items que ya hay.
		if attempt < DROP_TRIES / 2 and _crowded(candidate, others):
			continue
		return candidate
	if nav_ready:
		var closest: Vector3 = NavigationServer3D.map_get_closest_point(map, flat_origin)
		return Vector3(closest.x, 0.0, closest.z)
	return flat_origin


static func _hits_static(results: Array[Dictionary]) -> bool:
	for result in results:
		if result.collider is StaticBody3D:
			return true
	return false


static func _crowded(point: Vector3, pickups: Array[Node]) -> bool:
	for pickup in pickups:
		if is_instance_valid(pickup) and Vector2(pickup.global_position.x - point.x, pickup.global_position.z - point.z).length() < DROP_SPACING:
			return true
	return false
