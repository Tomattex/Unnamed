extends SceneTree

## Arma el mundo (world/mundo.tscn) con los assets libres de assets/:
## piso con mapas de mezcla (caminos, adoquines, bosque, musgo, piedra, arena
## y nieve), las piezas de cada zona con su colision, las zonas de enemigos,
## los portales, los cofres, barriles y cajones rompibles, santuarios, luces
## de noche, el mapa del pasto, los nombres de cada lugar para el mapa y la
## navegacion horneada.
## En el centro estan la aldea (con muralla, portones, guardias y aldeanos),
## el bosque, el cementerio, las ruinas y las praderas; alrededor, cuatro
## regiones mas: la montaña nevada al norte, la costa y el mar al este, el
## desierto al sur y el pantano al oeste. Dos rios bajan de la montaña (al mar
## y al pantano) y se cruzan por puentes donde pasan los caminos. Los eventos
## del camino (scripts/world/road_events.gd) usan los caminos de aca.
## Es deterministico (semilla fija): correrlo de nuevo da el mismo mundo.
##
##   godot --headless --path . --script res://world/build_world.gd

const OUT_SCENE := "res://world/mundo.tscn"
const OUT_NAV := "res://world/mundo_nav.res"
const SPLAT_A := "res://world/terrain/splat_a.png"
const SPLAT_B := "res://world/terrain/splat_b.png"
## Pasto (r densidad, g sequedad) y tipo de suelo para los pasos (b: 0 pasto,
## 0.5 tierra, 1 piedra). Lo leen scripts/world/grass_field.gd y
## scripts/world/ground_surface.gd.
const GRASS_MASK := "res://world/terrain/grass_mask.png"
const SEED: int = 20261029

const SIZE: float = 36000.0
const HALF: float = SIZE / 2.0
## Hasta donde se puede caminar (mas alla hay bosque cerrado, el mar al este y
## paredes invisibles).
const WALK_LIMIT: float = 17200.0
const SPLAT_RES: int = 1536
const PATH_WIDTH: float = 230.0

const PROP_SCRIPT := preload("res://scripts/world/prop.gd")
const ZONE_SCENE := "res://zona_spawn.tscn"
const PORTAL_SCENE := "res://world/portal.tscn"
const ENEMY_SCENE := "res://enemi.tscn"
const CHEST_SCENE := "res://world/chest.tscn"
const SMITH_SCENE := "res://npc/blacksmith.tscn"
const BREAKABLE_SCRIPT := "res://scripts/world/breakable.gd"
const SHRINE_SCRIPT := "res://scripts/world/shrine.gd"
const NIGHT_LIGHT_SCRIPT := "res://scripts/world/night_light.gd"
const GRASS_SCRIPT := "res://scripts/world/grass_field.gd"
const WATER_SHADER := "res://world/terrain/water.gdshader"
const WATER_SOUNDS_SCRIPT := "res://scripts/world/water_sounds.gd"
const GUARD_SCRIPT := "res://scripts/npc/guard.gd"
const VILLAGER_SCRIPT := "res://scripts/npc/villager.gd"
const EVENTS_SCRIPT := "res://scripts/world/road_events.gd"

const N := "res://assets/nature/"
const P := "res://assets/props/"
const G := "res://assets/props/graveyard/"

# Modelos: ruta, escala (unidades del mundo por unidad del modelo), radio de
# colision relativo al ancho del modelo (0 = sin colision), estilo, tinte.
## Arboles, arbustos y helechos de 0 A.D. (assets/nature/oad/, ver CREDITS):
## vienen en metros, asi que 225 es su tamaño real en el mundo.
const O := "res://assets/nature/oad/"
const OAKS := [O + "roble_a.glb", O + "roble_b.glb", O + "roble_c.glb", O + "roble_d.glb", O + "roble_e.glb", O + "roble_f.glb"]
const AUTUMN_OAKS := [O + "roble_otono_a.glb", O + "roble_otono_b.glb", O + "roble_otono_c.glb", O + "roble_otono_d.glb"]
const ELMS := [O + "olmo_a.glb", O + "olmo_b.glb", O + "olmo_c.glb", O + "olmo_d.glb"]
const BIRCHES := [O + "abedul_a.glb", O + "abedul_b.glb", O + "abedul_c.glb", O + "abedul_d.glb"]
const FIRS := [O + "abeto_a.glb", O + "abeto_b.glb", O + "abeto_c.glb", O + "abeto_d.glb", O + "abeto_e.glb", O + "abeto_f.glb"]
const SNOW_FIRS := [O + "abeto_nieve_a.glb", O + "abeto_nieve_b.glb", O + "abeto_nieve_c.glb", O + "abeto_nieve_d.glb"]
const DEAD_TREES := [O + "muerto_a.glb", O + "muerto_b.glb", O + "roble_seco_b.glb", O + "roble_seco_c.glb", O + "roble_seco_d.glb",
		O + "roble_seco_f.glb", O + "olmo_seco_a.glb", O + "olmo_seco_b.glb", O + "olmo_seco_c.glb", O + "olmo_seco_d.glb"]
const WILLOWS := [O + "sauce_a.glb", O + "sauce_b.glb"]
const BUSHES := [O + "arbusto_a.glb", O + "arbusto_b.glb", O + "arbusto_c.glb", O + "arbusto_d.glb"]
const FERNS := [O + "helecho_a.glb", O + "helecho_b.glb"]
## Escala (minima, maxima) de cada tipo: robles y olmos de 7 a 9 metros,
## abetos de 6 a 8, abedules de 5 a 7.
const OAK_SCALE := Vector2(135.0, 175.0)
const ELM_SCALE := Vector2(130.0, 165.0)
const BIRCH_SCALE := Vector2(190.0, 240.0)
const FIR_SCALE := Vector2(200.0, 270.0)
const DEAD_SCALE := Vector2(120.0, 165.0)
const WILLOW_SCALE := Vector2(150.0, 190.0)
const BUSH_SCALE := Vector2(150.0, 210.0)
const FERN_SCALE := Vector2(130.0, 190.0)
## Lugar libre alrededor de cofres y santuarios (el botin y el sigilo).
const CHEST_CLEARANCE: float = 170.0
const SHRINE_CLEARANCE: float = 320.0
## Radio del circulo de menhires de cada santuario.
const MENHIR_RING: float = 470.0
## Lugar que ocupa un arbol para lo demas (fraccion del ancho de su copa).
const TREE_ROOM: float = 0.3
## Radio de la colision del tronco (unidades del mundo).
const TRUNK_RADIUS: float = 45.0
## Lo mas alto que esto (casas, muros, criptas, estatuas) no deja meter copas
## de arboles adentro.
const TALL_HEIGHT: float = 350.0
## Cuanto se entierran las rocas (fraccion de su alto): apoyadas justo en la
## base se ven sueltas.
const ROCK_SINK: float = 0.15
## Casas, granero, puestos, carros, pozo, cercos de piedra y menhires celtas de 0 A.D.
const C := "res://assets/props/oad/"
const ROCK_SET := N + "rock_moss_set_01/rock_moss_set_01_1k.gltf"
const ROCK_PIECES := ["rock_moss_set_01_rock01", "rock_moss_set_01_rock02", "rock_moss_set_01_rock03", "rock_moss_set_01_rock04", "rock_moss_set_01_rock05", "rock_moss_set_01_rock06"]
const BOULDERS := [N + "rock_07/rock_07_1k.gltf", N + "rock_09/rock_09_1k.gltf"]
const STUMP := N + "tree_stump_01/tree_stump_01_1k.gltf"
const FORT := P + "modular_fort_01/modular_fort_01_1k.gltf"
const FORGE := P + "forge/forge_doncarson.glb"
const FORGE_SCALE: float = 220.0
## Herreria: entre los cajones del oeste y el camino al porton norte, abierta
## hacia el camino (x, z, angulo). El herrero se para adelante.
const FORGE_SPOT := Vector3(-450, -1400, PI / 2.0)
const SMITH_DISTANCE: float = 420.0
const BARREL := P + "wine_barrel_01/wine_barrel_01_1k.gltf"
const CRATE := P + "wooden_crate_01/wooden_crate_01_1k.gltf"
const LANTERN := P + "wooden_lantern_01/wooden_lantern_01_1k.gltf"
const LANTERN_SCALE: float = 300.0
## Donde esta la lampara de los faroles del Graveyard Kit (en unidades del
## modelo, que se escala por 420); los dobles tienen otra en -z.
const LAMP_OFFSET := Vector3(0.0, 1.0, 0.26)
const TORCH_HEIGHT: float = 300.0
const GRAVESTONES := ["gravestone-bevel", "gravestone-broken", "gravestone-cross", "gravestone-cross-large", "gravestone-decorative", "gravestone-round", "gravestone-wide", "gravestone-roof"]

const FOLIAGE_TINT := Color(0.78, 0.82, 0.74)
const SNOW_TINT := Color(0.86, 0.9, 0.96)
const SWAMP_TINT := Color(0.55, 0.62, 0.48)
const SAND_TINT := Color(1.0, 0.84, 0.62)
const VILLAGE_TINT := Color(0.86, 0.82, 0.78)

var _rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _root: Node3D
var _props: Node3D
## Puntos ocupados (x, z, radio) para no encimar piezas. El centro es el de
## la pieza que se ve (no el origen del modelo).
var _occupied: Array[Vector3] = []
## Lo que tiene colision de caja (casas, muros, cercos, criptas): cajas giradas
## {"c": centro, "ax": eje x, "az": eje z, "half": medio largo en cada eje}.
var _boxes: Array[Dictionary] = []
## Lo alto (casas, muros, torres, criptas, estatuas), como cajas o circulos
## (Vector3): ahi no se pueden meter las copas de los arboles.
var _tall: Array = []
## Mientras _scatter llama a un generador, _prop no pone la pieza si su huella
## real se pisa con algo ya puesto y lo avisa en _rejected (asi _scatter
## prueba en otro lado).
var _strict: bool = false
var _rejected: bool = false
## Caja de cada modelo (ruta|malla) en sus coordenadas.
var _bounds_cache: Dictionary = {}
var _scene_cache: Dictionary = {}
var _splat_a: Image
var _splat_b: Image
## Lo nuevo (regiones de afuera, rios, gente) usa su propio generador, asi
## no cambia del todo lo que ya estaba.
var _rng2 := RandomNumberGenerator.new()
## Tramos de los caminos y de los rios repartidos en una grilla (las
## distancias se piden millones de veces al pintar el piso).
var _path_grid: Dictionary = {}
var _river_grid: Dictionary = {}
## Muestras de cada rio ya suavizado: [{"points": PackedVector2Array, "widths": PackedFloat32Array}].
var _river_lines: Array = []
## Puentes: centro (x, z), direccion del camino y largo.
var _bridges: Array = []
## Charcos del pantano: (x, z, radio).
var _pools: Array[Vector3] = []
## Portones de la muralla: centro, direccion a lo largo del muro y hacia afuera.
var _gates: Array = []
## Delante de la puerta de cada casa de la aldea.
var _house_doors: Array[Vector2] = []
## Arboles, plantas y rocas sueltas de cada region: se reparten despues de los
## cofres, campamentos y santuarios, que asi encuentran su claro.
var _vegetation: Array[Callable] = []

## Caminos de tierra: listas de puntos (x, z). Los usan tambien los bandidos
## (scripts/world/roads.gd).
const PATHS := [
	[Vector2(0, -200), Vector2(-1500, -500), Vector2(-3000, -900), Vector2(-4300, -1300), Vector2(-5600, -2000)],
	[Vector2(0, -200), Vector2(1500, -900), Vector2(2800, -1900), Vector2(3800, -3000), Vector2(4900, -3900)],
	[Vector2(0, -200), Vector2(200, -1800), Vector2(500, -3500), Vector2(-200, -5200), Vector2(-500, -6400), Vector2(0, -7300)],
	[Vector2(-4300, -1300), Vector2(-4000, -3400), Vector2(-3000, -5200), Vector2(-1600, -6300), Vector2(-500, -6400)],
	[Vector2(0, -200), Vector2(400, 1500), Vector2(-300, 3200), Vector2(600, 5200)],
	# Caminos a las regiones de afuera: montaña (norte), costa (este),
	# desierto (sur) y pantano (oeste), y dos sendas que cruzan los rios.
	[Vector2(0, -7300), Vector2(-300, -9300), Vector2(-900, -11200), Vector2(-600, -12700), Vector2(-500, -14200)],
	[Vector2(2800, -1900), Vector2(5200, -1100), Vector2(8000, -1300), Vector2(10500, -900), Vector2(12600, -700), Vector2(13900, -200)],
	[Vector2(600, 5200), Vector2(1300, 7600), Vector2(800, 10200), Vector2(1500, 12100), Vector2(1300, 13800)],
	[Vector2(-5600, -2000), Vector2(-8000, -700), Vector2(-10300, 500), Vector2(-12200, 1500), Vector2(-13400, 1900)],
	[Vector2(4900, -3900), Vector2(7600, -5200), Vector2(10300, -6100), Vector2(12600, -6600)],
	[Vector2(-4000, -3400), Vector2(-7200, -5600), Vector2(-10100, -6600), Vector2(-12800, -7400)],
]
var _paths: Array = PATHS

## Zonas: centro (x, z) y radio.
const VILLAGE := Vector3(0, -200, 2900)
const FOREST := Vector3(-6200, -2700, 3300)
const GRAVEYARD := Vector3(5600, -4800, 2100)
const RUINS := Vector3(0, -7800, 1900)
const SWAMP := Vector3(-13300, 1800, 3500)
const MOUNTAIN := Vector3(-500, -14000, 3600)
const COAST := Vector3(13000, -800, 3300)
const DESERT := Vector3(1400, 13600, 3600)
## Muralla de la aldea: cuadrado de este medio lado alrededor del centro.
const WALL_HALF: float = 2700.0
## Orilla del mar del este (x; ondula un poco con el ruido).
const SHORE_X: float = 15300.0
## Rios: ancho y puntos (x, z) desde la naciente, que empieza fuera de lo
## caminable para que no se pueda rodear.
const RIVERS := [
	{"name": "RioFrio", "width": 640.0, "points": [Vector2(5200, -17800), Vector2(6600, -13200), Vector2(9600, -10200), Vector2(10600, -6400), Vector2(9900, -3600), Vector2(10900, -1500), Vector2(13200, 1700), Vector2(15900, 2900)]},
	{"name": "RioTurbio", "width": 700.0, "points": [Vector2(-7200, -17800), Vector2(-9200, -12600), Vector2(-10300, -8200), Vector2(-10000, -3600), Vector2(-10400, 1200), Vector2(-11700, 4400), Vector2(-12600, 6400)]},
]
const BRIDGE_WIDTH: float = 440.0


func _initialize() -> void:
	# Que el guardado del jugador no se toque mientras se arma el mundo.
	root.get_node("save_game").save_path = "user://build_world_descartable.json"
	_rng.seed = SEED
	_rng2.seed = SEED + 7
	_noise.seed = SEED
	_noise.frequency = 0.0009
	_noise.fractal_octaves = 3

	_root = Node3D.new()
	_root.name = "Mundo"
	root.add_child(_root)
	_build_grids()
	_build_ground()
	_props = _node("Props", _root)
	_build_water()
	_build_portals()
	_build_village()
	# Lo fijo de cada region (ruinas, templo, faro, choza...).
	_build_forest()
	_build_graveyard()
	_build_ruins()
	_build_swamp()
	_build_mountain()
	_build_coast()
	_build_desert()
	_build_meadows()
	_build_border()
	# Cofres, campamentos y santuarios antes que los arboles: asi tienen su
	# claro y el botin cae en el piso libre.
	_build_chests()
	_build_camps()
	_build_shrines()
	for grow in _vegetation:
		grow.call()
	_build_zones()
	_build_labels()
	_paint_splats()
	_build_lights()
	_build_people()
	_build_events()
	# Ultimo: necesita todo lo que ocupa lugar.
	_paint_grass_mask()
	var grass := Node3D.new()
	grass.name = "Pasto"
	grass.set_script(load(GRASS_SCRIPT))
	_root.add_child(grass)
	# Los duenos se ponen ahora, antes de que corran los _ready: lo que las
	# piezas crean al cargar (llamas, piedras del portal) no se guarda.
	_set_owner(_root, _root)


# La navegacion se hornea en el primer cuadro: recien ahi la escena esta
# adentro del arbol.
func _process(_delta: float) -> bool:
	_bake_navigation()
	_save()
	return true


# --- Piso ------------------------------------------------------------------

func _build_ground() -> void:
	var body := StaticBody3D.new()
	body.name = "Suelo"
	_root.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(SIZE, 40.0, SIZE)
	shape.shape = box
	shape.position.y = -20.0
	body.add_child(shape)

	var mesh := MeshInstance3D.new()
	mesh.name = "Piso"
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	plane.subdivide_width = 16
	plane.subdivide_depth = 16
	var material := ShaderMaterial.new()
	material.shader = load("res://world/terrain/terrain.gdshader")
	for layer in ["grass", "dirt", "cobble", "forest", "moss", "rocky", "sand", "snow"]:
		material.set_shader_parameter(layer + "_albedo", load("res://assets/terrain/%s_albedo.jpg" % layer))
		material.set_shader_parameter(layer + "_normal", load("res://assets/terrain/%s_normal.jpg" % layer))
	material.set_shader_parameter("world_size", SIZE)
	material.set_shader_parameter("swamp_area", SWAMP)
	plane.material = material
	mesh.mesh = plane
	mesh.layers = 1 | PROP_SCRIPT.MAP_LAYER
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.set_script(load("res://world/terrain/ground.gd"))
	body.add_child(mesh)

	# Paredes invisibles en el borde.
	for side in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
		var wall := CollisionShape3D.new()
		var wall_box := BoxShape3D.new()
		wall_box.size = Vector3(200.0 if side.x != 0 else SIZE, 1200.0, 200.0 if side.z != 0 else SIZE)
		wall.shape = wall_box
		wall.position = side * (WALK_LIMIT + 400.0) + Vector3.UP * 600.0
		body.add_child(wall)


# --- Zonas -----------------------------------------------------------------

func _build_village() -> void:
	var village := _node("Aldea", _props)
	# Primero lo que no se mueve: la muralla, la herreria y la gente de la
	# escena principal (testmove.tscn), asi las casas no los pisan.
	_build_village_wall(village)
	_build_forge(village)
	for spot in VILLAGE_RESERVED:
		_occupied.append(spot)
	# La plaza: fogata, pozo, el puesto del comerciante y faroles alrededor.
	_prop(village, P + "stone_fire_pit/stone_fire_pit_1k.gltf", Vector3(380, 0, 220), 0.0, 300.0, 0.45, {"is_fire": true, "fire_height": 80.0})
	_prop(village, C + "pozo.glb", Vector3(-250, 0, 520), 0.4, 270.0, 0.45, {"style": PROP_SCRIPT.Style.TINT, "tint": VILLAGE_TINT})
	for stall in [["puesto.glb", Vector2(-1000, -250), 250.0], ["mesa.glb", Vector2(-850, -800), 260.0]]:
		_place_near(village, stall[1], 260.0, 1, func(parent: Node3D, pos: Vector3) -> void:
			_prop(parent, C + stall[0], pos, PI * 0.55, stall[2], 0.4, {"style": PROP_SCRIPT.Style.TINT, "tint": VILLAGE_TINT}, true), 0.0)
	_prop(village, P + "wooden_bucket_01/wooden_bucket_01_1k.gltf", Vector3(-120, 0, 600), 0.0, 270.0, 0.0)
	for wanted in [0.4, 1.9, 3.4, 4.9]:
		# Corrido por la ronda hasta que no quede sobre un camino.
		var angle: float = INF
		for k in 16:
			var candidate: float = wanted + (k + 1) / 2 * 0.07 * (1.0 if k % 2 == 0 else -1.0)
			var spot := Vector2(cos(candidate) * 850.0, -200 + sin(candidate) * 850.0)
			if _distance_to_paths(spot) > PATH_WIDTH * 0.5 + 90.0 and _is_free(spot, 70.0):
				angle = candidate
				break
		if not is_finite(angle):
			continue
		var pos := Vector3(cos(angle) * 850.0, 0, -200 + sin(angle) * 850.0)
		_prop(village, G + "lightpost-single.glb", pos, angle, 420.0, 0.25, {"style": PROP_SCRIPT.Style.IRON})
		_night_light(village, pos + Basis(Vector3.UP, angle) * LAMP_OFFSET * 420.0, {"energy": 1.3})
	# Casas celtas de techo de paja mirando a la plaza (el frente de los
	# modelos es +Z), un granero y un almacen: cada una busca lugar cerca de
	# donde se la pide, sin pisar la muralla, los caminos ni a las otras.
	for house in VILLAGE_BUILDINGS:
		_house(village, C + house[0], house[1], house[2])
	# En lo que queda: un corral con cerco de piedra, el carro de heno, leña,
	# otro carro, otro puesto y barriles y cajones al lado de las casas.
	_corral(village, Vector2(-1100, 1500))
	for extra in [["carro_heno.glb", Vector2(-1150, 250), 260.0], ["lena.glb", Vector2(-400, 2000), 260.0],
			["carro.glb", Vector2(1000, 1900), 320.0], ["puesto.glb", Vector2(1700, -700), 250.0]]:
		_place_near(village, extra[1], 450.0, 1, func(parent: Node3D, pos: Vector3) -> void:
			_prop(parent, C + extra[0], pos, _rng.randf() * TAU, extra[2], 0.4, {"style": PROP_SCRIPT.Style.TINT, "tint": VILLAGE_TINT}, true))
	for door in _house_doors:
		_place_near(village, door, 300.0, _rng.randi_range(1, 3), _crate_or_barrel.bind(1))
	for center in [Vector2(-700, -760), Vector2(-1250, 600)]:
		_place_near(village, center, 220.0, _rng.randi_range(2, 3), _crate_or_barrel.bind(1))
	# Arbustos afuera de la muralla.
	_vegetation.append(_scatter.bind(village, Vector3(VILLAGE.x, VILLAGE.y, 0.0), WALL_HALF * 1.4, WALL_HALF * 1.8, 18, _shrub))


## Casas de la aldea: modelo, lugar pedido (x, z) y escala. Las mas grandes
## primero (son las que menos lugar encuentran).
const VILLAGE_BUILDINGS := [
	["almacen.glb", Vector2(1800, 1600), 165.0],
	["granja.glb", Vector2(1950, 250), 175.0],
	["casa_a.glb", Vector2(-1750, -1500), 180.0],
	["casa_b.glb", Vector2(1250, -2000), 180.0],
	["casa_c.glb", Vector2(-1950, 1000), 180.0],
	["casa_b.glb", Vector2(-1900, 2000), 180.0],
	["casa_d.glb", Vector2(850, 2000), 180.0],
]
## Lugares de la aldea que no se pueden tapar (x, z, radio): el jugador al
## empezar, el comerciante, el baul, el runista, el maestro de armas y el
## sabio (todos en testmove.tscn).
const VILLAGE_RESERVED := [
	Vector3(0, 0, 200), Vector3(-650, -450, 170), Vector3(-380, -720, 170), Vector3(500, 600, 170),
	Vector3(850, -150, 170), Vector3(-600, 380, 170),
]
## Aire que deja cada casa: con la muralla, con los caminos y con lo demas
## (un pasillo para pasar).
const HOUSE_WALL_GAP: float = 40.0
const HOUSE_ROAD_GAP: float = 40.0
const HOUSE_GAP: float = 80.0


## Casa (o granero) de la aldea con la puerta hacia la plaza y colision de
## caja. Busca en anillos alrededor de wanted el primer lugar donde entra
## entera adentro de la muralla sin tocar los caminos ni lo ya puesto;
## primero derecha (paredes paralelas a la muralla) y si no, girada justo
## hacia la plaza.
func _house(parent: Node3D, path: String, wanted: Vector2, scale: float) -> void:
	var bounds: AABB = _bounds_of(path, "")
	var plaza := Vector2(VILLAGE.x, VILLAGE.y)
	for ring in 32:
		var steps: int = maxi(1, ring * 6)
		for i in steps:
			var spot: Vector2 = wanted + Vector2.from_angle(TAU * i / steps) * ring * 70.0
			var to_plaza: Vector2 = plaza - spot
			var exact: float = atan2(to_plaza.x, to_plaza.y)
			for angle in [snappedf(exact, PI * 0.5), exact]:
				var middle: Vector3 = Basis(Vector3.UP, angle) * (bounds.get_center() * scale)
				var footprint: Dictionary = _box(spot + Vector2(middle.x, middle.z), angle, Vector2(bounds.size.x, bounds.size.z) * scale * 0.5)
				if not _house_fits(footprint):
					continue
				_prop(parent, path, Vector3(spot.x, 0, spot.y), angle, scale, 0.42,
						{"style": PROP_SCRIPT.Style.TINT, "tint": VILLAGE_TINT, "fade_when_occluding": true}, true)
				_house_doors.append(footprint.c + footprint.az * (footprint.half.y + 120.0))
				return
	push_warning("No entro la casa %s cerca de %s" % [path, wanted])


func _house_fits(box: Dictionary) -> bool:
	var inner: float = WALL_HALF - WALL_THICKNESS / 2.0 - HOUSE_WALL_GAP
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var corner: Vector2 = box.c + box.ax * box.half.x * sx + box.az * box.half.y * sz
			if absf(corner.x - VILLAGE.x) > inner or absf(corner.y - VILLAGE.y) > inner:
				return false
	return not _box_on_road(box, HOUSE_ROAD_GAP) and _box_free(box, HOUSE_GAP)


## Si algun camino pasa a menos de margin de la caja (se recorre cada tramo
## cercano a pasos cortos).
func _box_on_road(box: Dictionary, margin: float) -> bool:
	var reach: float = box.half.length() + PATH_WIDTH + margin
	for path in _paths:
		for i in path.size() - 1:
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			if Geometry2D.get_closest_point_to_segment(box.c, a, b).distance_to(box.c) > reach:
				continue
			var steps: int = ceili(a.distance_to(b) / 40.0)
			for k in steps + 1:
				if _box_distance(box, a.lerp(b, float(k) / steps)) < PATH_WIDTH * 0.5 + margin:
					return true
	return false


## Corral de cerco de piedra (seis tramos, uno abierto hacia la plaza) en el
## primer lugar cerca de wanted donde entra entero.
func _corral(parent: Node3D, wanted: Vector2) -> void:
	var bounds: AABB = _bounds_of(C + "cerca_media.glb", "")
	var half := Vector2(bounds.size.x, bounds.size.z) * CORRAL_FENCE_SCALE * 0.46
	for ring in 24:
		var steps: int = maxi(1, ring * 6)
		for k in steps:
			var center: Vector2 = wanted + Vector2.from_angle(TAU * k / steps) * ring * 80.0
			var opening: float = (Vector2(VILLAGE.x, VILLAGE.y) - center).angle()
			var sides: Array = []
			var fits: bool = _is_free(center, CORRAL_RADIUS * 0.8)
			for i in 6:
				var angle: float = TAU * i / 6.0 + PI / 6.0
				if absf(wrapf(angle - opening, -PI, PI)) < PI / 6.0:
					continue
				var side: Vector2 = center + Vector2.from_angle(angle) * CORRAL_RADIUS
				var box: Dictionary = _box(side, PI * 0.5 - angle, half)
				if not fits or not _box_free(box, 40.0) or _box_on_road(box, 40.0) or not _inside_walls(side, -WALL_THICKNESS - 200.0):
					fits = false
					break
				sides.append([side, angle])
			if not fits:
				continue
			for side in sides:
				_prop(parent, C + "cerca_media.glb", Vector3(side[0].x, 0, side[0].y), PI * 0.5 - side[1], CORRAL_FENCE_SCALE, 0.9,
						{"style": PROP_SCRIPT.Style.TINT, "tint": VILLAGE_TINT}, true)
			_occupied.append(Vector3(center.x, center.y, CORRAL_RADIUS * 0.8))
			return
	push_warning("No entro el corral cerca de %s" % wanted)


const CORRAL_RADIUS: float = 420.0
const CORRAL_FENCE_SCALE: float = 108.0


## Pone count piezas con maker cerca de center (dentro de spread), cada una
## donde entra sin pisar nada; road_gap es el aire con el borde del camino.
func _place_near(parent: Node3D, center: Vector2, spread: float, count: int, maker: Callable, road_gap: float = 280.0) -> void:
	var placed: int = 0
	var was_strict: bool = _strict
	_strict = true
	for attempt in count * 25:
		if placed >= count:
			break
		var point: Vector2 = center + Vector2(_rng.randf_range(-spread, spread), _rng.randf_range(-spread, spread))
		# Lejos del camino (las piezas largas, como la leña, se metian).
		if _distance_to_paths(point) < PATH_WIDTH * 0.5 + road_gap:
			continue
		_rejected = false
		maker.call(parent, Vector3(point.x, 0, point.y))
		if not _rejected:
			placed += 1
	_rejected = false
	_strict = was_strict


func _build_forest() -> void:
	var forest := _node("Bosque", _props)
	_vegetation.append(_scatter.bind(forest, FOREST, 0.0, FOREST.z, 230, _forest_tree))
	_vegetation.append(_scatter.bind(forest, FOREST, 0.0, FOREST.z, 130, _fern))
	_vegetation.append(_scatter.bind(forest, FOREST, 0.0, FOREST.z, 55, _shrub))
	_vegetation.append(_scatter.bind(forest, FOREST, 0.0, FOREST.z, 35, _rock))
	_vegetation.append(_scatter.bind(forest, FOREST, 0.0, FOREST.z, 22, _stump))


func _build_graveyard() -> void:
	var yard := _node("Cementerio", _props)
	var center := Vector3(GRAVEYARD.x, 0, GRAVEYARD.y)
	# Reja de hierro alrededor (cuadrado con huecos para entrar).
	var half: float = 1300.0
	var step: float = 300.0
	for side in 4:
		var t: float = -half
		while t < half:
			var gap: bool = absf(t + step / 2.0) < 400.0 and side != 1
			var local := Vector3(t + step / 2.0, 0, -half) if side % 2 == 0 else Vector3(-half, 0, t + step / 2.0)
			if side >= 2:
				local = -local
			# Donde la cruza un camino, la reja se abre.
			if _distance_to_paths(Vector2(center.x + local.x, center.z + local.z)) < PATH_WIDTH * 0.5 + 200.0:
				gap = true
			if not gap and _rng.randf() > 0.12:
				var angle: float = 0.0 if side % 2 == 0 else PI * 0.5
				var piece: String = "iron-fence-damaged" if _rng.randf() < 0.25 else "iron-fence"
				_prop(yard, G + piece + ".glb", center + local, angle, 300.0, 1.0, {"style": PROP_SCRIPT.Style.IRON}, true)
			t += step
	# Criptas, obeliscos, columnas, braseros y faroles (antes que las tumbas,
	# que se acomodan alrededor).
	var first_room: int = _occupied.size()
	var first_box: int = _boxes.size()
	_prop(yard, G + "crypt-small.glb", center + Vector3(0, 0, -150), 0.0, 400.0, 0.5, {"style": PROP_SCRIPT.Style.STONE, "fade_when_occluding": true}, true)
	_prop(yard, G + "crypt.glb", center + Vector3(-900, 0, 700), 0.7, 420.0, 0.5, {"style": PROP_SCRIPT.Style.STONE, "fade_when_occluding": true}, true)
	_prop(yard, G + "crypt.glb", center + Vector3(850, 0, 800), -0.9, 420.0, 0.5, {"style": PROP_SCRIPT.Style.STONE, "fade_when_occluding": true}, true)
	for offset in [Vector3(-400, 0, 300), Vector3(420, 0, 300)]:
		_prop(yard, G + "pillar-obelisk.glb", _off_road(center + offset, 120.0), 0.0, 400.0, 0.4, {"style": PROP_SCRIPT.Style.STONE})
	for offset in [Vector3(-1080, 0, -1080), Vector3(1080, 0, -1080), Vector3(-1080, 0, 1080), Vector3(1080, 0, 1080)]:
		_prop(yard, G + "column-large.glb", _off_road(center + offset, 120.0), 0.0, 420.0, 0.45, {"style": PROP_SCRIPT.Style.STONE})
	for offset in [Vector3(-400, 0, -150), Vector3(400, 0, -150)]:
		_prop(yard, G + "fire-basket.glb", center + offset, 0.0, 420.0, 0.4, {"style": PROP_SCRIPT.Style.IRON, "is_fire": true, "fire_height": 40.0})
	for offset in [Vector3(-1350, 0, 0), Vector3(1350, 0, 400)]:
		_prop(yard, G + "lightpost-double.glb", center + offset, PI * 0.5, 420.0, 0.2, {"style": PROP_SCRIPT.Style.IRON})
		# Faroles del cementerio: luz fria.
		for side in [1.0, -1.0]:
			var lamp: Vector3 = Basis(Vector3.UP, PI * 0.5) * Vector3(LAMP_OFFSET.x, LAMP_OFFSET.y, LAMP_OFFSET.z * side) * 420.0
			_night_light(yard, center + offset + lamp, {"energy": 0.9, "color": Color(0.62, 0.78, 1.0), "light_range": 900.0})
	var landmark_rooms: Array[Vector3] = _occupied.slice(first_room)
	var landmark_boxes: Array[Dictionary] = _boxes.slice(first_box)
	# Tumbas en filas, algo desordenadas (menos donde hay otra cosa).
	for row in range(-4, 5):
		for col in range(-5, 6):
			if _rng.randf() < 0.3:
				continue
			var pos: Vector3 = center + Vector3(col * 210.0 + _rng.randf_range(-40, 40), 0, row * 260.0 + _rng.randf_range(-40, 40))
			if pos.distance_to(center) < 260.0 or _distance_to_paths(Vector2(pos.x, pos.z)) < PATH_WIDTH * 0.5 + 150.0:
				continue
			var spot := Vector2(pos.x, pos.z)
			if landmark_rooms.any(func(room: Vector3) -> bool: return spot.distance_to(Vector2(room.x, room.y)) < room.z + 60.0) \
					or landmark_boxes.any(func(box: Dictionary) -> bool: return _box_distance(box, spot) < 120.0):
				continue
			var stone: String = GRAVESTONES[_rng.randi() % GRAVESTONES.size()]
			# Colision fina: con el margen de la navegacion, mas gruesa cerraba las filas.
			_prop(yard, G + stone + ".glb", pos, _rng.randf_range(-0.25, 0.25), _rng.randf_range(280.0, 340.0), 0.2, {"style": PROP_SCRIPT.Style.STONE, "tint": Color(0.9, 0.9, 0.92)})
			if _rng.randf() < 0.35:
				_prop(yard, G + "grave.glb", pos + Vector3(0, 0, 170), 0.0, 280.0, 0.0, {"style": PROP_SCRIPT.Style.STONE, "tint": Color(0.7, 0.66, 0.6)})
	_vegetation.append(_scatter.bind(_node("CementerioArboles", yard), Vector3(GRAVEYARD.x, GRAVEYARD.y, 1500.0), 1500.0, 2300.0, 22, _dead_tree))
	_vegetation.append(_scatter.bind(yard, Vector3(GRAVEYARD.x, GRAVEYARD.y, 1300.0), 300.0, 1250.0, 10, _dead_tree))


func _build_ruins() -> void:
	var ruins := _node("Ruinas", _props)
	var c := Vector3(RUINS.x, 0, RUINS.y)
	# Torre redonda, muros gruesos rotos y una puerta en arco.
	_fort_piece(ruins, "modular_fort_01_tower_round", c + Vector3(620, 0, -620), 0.3, 80.0)
	_fort_piece(ruins, "modular_fort_01_wall_thick_straight_01", c + Vector3(-900, 0, -500), 0.0, 90.0)
	_fort_piece(ruins, "modular_fort_01_wall_thick_corner_01", c + Vector3(-1000, 0, -1150), 0.0, 90.0)
	_fort_piece(ruins, "modular_fort_01_wall_thick_end_02", c + Vector3(-650, 0, -1250), PI * 0.5, 90.0)
	_fort_piece(ruins, "modular_fort_01_wall_thin_gate_01", c + Vector3(-150, 0, 700), PI * 0.5, 95.0)
	_fort_piece(ruins, "modular_fort_01_wall_thin_straight_03", c + Vector3(-860, 0, 700), PI * 0.5, 95.0)
	_fort_piece(ruins, "modular_fort_01_wall_thick_end_01", c + Vector3(1000, 0, 400), -0.4, 90.0)
	_fort_piece(ruins, "modular_fort_01_wall_stairs_straight_01", c + Vector3(1450, 0, -100), PI, 90.0)
	_statue(ruins, _off_road(c + Vector3(0, 0, -150), 330.0), 230.0, {"style": PROP_SCRIPT.Style.STONE, "tint": Color(0.85, 0.84, 0.8)}, Color(0.78, 0.76, 0.72))
	_vegetation.append(_scatter.bind(ruins, Vector3(RUINS.x, RUINS.y, RUINS.z), 200.0, RUINS.z, 30, _rock))
	_vegetation.append(_scatter.bind(ruins, Vector3(RUINS.x, RUINS.y, RUINS.z), 600.0, RUINS.z + 400.0, 18, _dead_tree))
	_vegetation.append(_scatter.bind(ruins, Vector3(RUINS.x, RUINS.y, RUINS.z), 300.0, RUINS.z, 20, _shrub))


func _build_meadows() -> void:
	var meadows := _node("Praderas", _props)
	var world := Vector3(0, 0, WALK_LIMIT)
	_vegetation.append(_scatter.bind(meadows, world, 0.0, WALK_LIMIT, 420, _meadow_tree, true))
	_vegetation.append(_scatter.bind(meadows, world, 0.0, WALK_LIMIT, 240, _rock, true))
	_vegetation.append(_scatter.bind(meadows, world, 0.0, WALK_LIMIT, 300, _shrub, true))
	_vegetation.append(_scatter.bind(meadows, world, 0.0, WALK_LIMIT, 160, _fern, true))


# Bosque cerrado en el borde: tapa el fin del mundo.
func _build_border() -> void:
	var border := _node("Borde", _props)
	var t: float = -HALF
	while t < HALF:
		for depth in [WALK_LIMIT + 250.0, WALK_LIMIT + 650.0]:
			for pos in [Vector3(t, 0, -depth), Vector3(t, 0, depth), Vector3(-depth, 0, t)]:
				if pos.x > SHORE_X - 600.0 or _distance_to_rivers(Vector2(pos.x, pos.z)) < 250.0:
					continue
				pos += Vector3(_rng2.randf_range(-120, 120), 0, _rng2.randf_range(-120, 120))
				var snowy: bool = pos.z < -12000.0
				var fir: bool = _rng2.randf() < 0.6 or snowy
				var path: String = (SNOW_FIRS if snowy else FIRS).pick_random() if fir else OAKS.pick_random()
				var size: Vector2 = FIR_SCALE if fir else OAK_SCALE
				_prop(border, path, pos, _rng2.randf() * TAU, _rng2.randf_range(size.x, size.y) * 1.2, 0.0, {"style": PROP_SCRIPT.Style.TINT, "tint": FOLIAGE_TINT * 0.85})
		t += 480.0


# --- Generadores de cada tipo de pieza ------------------------------------

## Estatua parada sobre un pedestal de piedra de height de alto (antes
## flotaba a esa altura sin nada abajo).
func _statue(parent: Node3D, wanted: Vector3, height: float, options: Dictionary, stone_tint: Color) -> void:
	var pos: Vector3 = wanted
	var room: float = PEDESTAL_WIDTH * 0.75
	for ring in 16:
		var steps: int = maxi(1, ring * 6)
		var found: bool = false
		for i in steps:
			var spot: Vector2 = Vector2(wanted.x, wanted.z) + Vector2.from_angle(TAU * i / steps) * ring * 50.0
			if _is_free(spot, room) and _distance_to_paths(spot) > PATH_WIDTH * 0.5 + room:
				pos = Vector3(spot.x, wanted.y, spot.y)
				found = true
				break
		if found:
			break
	var pedestal := Node3D.new()
	pedestal.name = "Pedestal"
	pedestal.set_script(PROP_SCRIPT)
	pedestal.style = PROP_SCRIPT.Style.STONE
	pedestal.tint = stone_tint
	pedestal.position = pos
	parent.add_child(pedestal, true)
	var block := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(PEDESTAL_WIDTH, height, PEDESTAL_WIDTH)
	block.mesh = mesh
	block.position.y = height / 2.0
	pedestal.add_child(block)
	# Un escalon mas ancho abajo.
	var step := MeshInstance3D.new()
	var step_mesh := BoxMesh.new()
	step_mesh.size = Vector3(PEDESTAL_WIDTH + 90.0, 40.0, PEDESTAL_WIDTH + 90.0)
	step.mesh = step_mesh
	step.position.y = 20.0
	pedestal.add_child(step)
	var body := StaticBody3D.new()
	body.name = "Colision"
	pedestal.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(PEDESTAL_WIDTH + 90.0, height + 300.0, PEDESTAL_WIDTH + 90.0)
	shape.shape = box
	shape.position.y = box.size.y / 2.0
	body.add_child(shape)
	var footprint: Dictionary = _box(Vector2(pos.x, pos.z), 0.0, Vector2.ONE * (PEDESTAL_WIDTH + 90.0) / 2.0)
	_boxes.append(footprint)
	_tall.append(footprint)
	_prop(parent, P + "gothic_statue/gothic_statue_1k.gltf", pos + Vector3.UP * height, PI, 270.0, 0.0, options)


const PEDESTAL_WIDTH: float = 460.0


## Arbol de una lista con su rango de escala, tinte y colision de tronco.
func _tree(parent: Node3D, paths: Array, pos: Vector3, size: Vector2, tint: Color = FOLIAGE_TINT) -> void:
	_prop(parent, paths[_rng.randi() % paths.size()], pos, _rng.randf() * TAU, _rng.randf_range(size.x, size.y), 0.0,
			{"style": PROP_SCRIPT.Style.TINT, "tint": tint, "fade_when_occluding": true}, false, TRUNK_RADIUS)


# Bosque Umbrio: abetos y robles, algunos de otoño y algun roble seco.
func _forest_tree(parent: Node3D, pos: Vector3) -> void:
	var roll: float = _rng.randf()
	if roll < 0.08:
		_tree(parent, DEAD_TREES, pos, DEAD_SCALE, Color(0.62, 0.58, 0.54))
	elif roll < 0.5:
		_tree(parent, FIRS, pos, FIR_SCALE)
	elif roll < 0.82:
		_tree(parent, OAKS, pos, OAK_SCALE)
	else:
		_tree(parent, AUTUMN_OAKS, pos, OAK_SCALE, Color(0.92, 0.86, 0.8))


func _meadow_tree(parent: Node3D, pos: Vector3) -> void:
	# Al norte (cerca de la nieve) abetos nevados; cerca de la arena, secos.
	if pos.z < -11500.0:
		_tree(parent, SNOW_FIRS, pos, FIR_SCALE, Color.WHITE)
	elif pos.z > 10500.0 or pos.x > SHORE_X - 1800.0:
		_dead_tree(parent, pos)
	else:
		var roll: float = _rng.randf()
		if roll < 0.5:
			_tree(parent, OAKS, pos, OAK_SCALE)
		elif roll < 0.7:
			_tree(parent, BIRCHES, pos, BIRCH_SCALE)
		elif roll < 0.82:
			_tree(parent, ELMS, pos, ELM_SCALE)
		else:
			_tree(parent, FIRS, pos, FIR_SCALE)


func _dead_tree(parent: Node3D, pos: Vector3) -> void:
	_tree(parent, DEAD_TREES, pos, DEAD_SCALE, Color(0.78, 0.74, 0.7))


func _rock(parent: Node3D, pos: Vector3) -> void:
	if _rng.randf() < 0.7:
		var piece: String = ROCK_PIECES[_rng.randi() % ROCK_PIECES.size()]
		_prop(parent, ROCK_SET, pos, _rng.randf() * TAU, _rng.randf_range(90.0, 170.0), 0.38, {"keep_only": piece, "center": true, "sink": ROCK_SINK})
	else:
		_prop(parent, BOULDERS[_rng.randi() % 2], pos, _rng.randf() * TAU, _rng.randf_range(900.0, 1500.0), 0.4)


func _fern(parent: Node3D, pos: Vector3) -> void:
	_prop(parent, FERNS.pick_random(), pos, _rng.randf() * TAU, _rng.randf_range(FERN_SCALE.x, FERN_SCALE.y), 0.0, {"style": PROP_SCRIPT.Style.TINT, "tint": FOLIAGE_TINT})


func _shrub(parent: Node3D, pos: Vector3) -> void:
	_prop(parent, BUSHES.pick_random(), pos, _rng.randf() * TAU, _rng.randf_range(BUSH_SCALE.x, BUSH_SCALE.y), 0.0, {"style": PROP_SCRIPT.Style.TINT, "tint": FOLIAGE_TINT})


func _stump(parent: Node3D, pos: Vector3) -> void:
	_prop(parent, STUMP, pos, _rng.randf() * TAU, _rng.randf_range(220.0, 280.0), 0.35)


# --- Enemigos, portales y nombres -----------------------------------------

## Cada zona cubre todo su bioma, sin pisarse con las otras ni con la aldea:
## los enemigos aparecen alrededor del jugador mientras anda por ahi.
func _build_zones() -> void:
	var zones := _node("ZonasEnemigos", _root)
	var skeleton := "res://enemies/types/esqueleto.tres"
	var zombie := "res://enemies/types/zombie.tres"
	var warrior := "res://enemies/types/esqueleto_guerrero.tres"
	var wolf := "res://enemies/types/lobo.tres"
	var spider := "res://enemies/types/arana.tres"
	var bandit := "res://enemies/types/bandido.tres"
	var archer := "res://enemies/types/bandido_arquero.tres"
	_zone(zones, "Bosque1", Vector3(-4600, 0, -1700), Vector3(3000, 1, 3000), 2, [wolf, spider, skeleton, zombie], [5.0, 2.0, 2.0, 1.0], 8)
	_zone(zones, "Bosque2", Vector3(-7700, 0, -3600), Vector3(3200, 1, 4400), 3, [spider, wolf, zombie, warrior], [4.0, 3.0, 2.0, 1.0], 9)
	_zone(zones, "Pradera", Vector3(3600, 0, 3400), Vector3(4400, 1, 4400), 1, [skeleton, wolf], [2.0, 1.0], 6)
	_zone(zones, "Cementerio", Vector3(GRAVEYARD.x, 0, GRAVEYARD.y), Vector3(4200, 1, 4200), 4, [zombie, skeleton, warrior], [4.0, 3.0, 1.5], 10)
	_zone(zones, "Ruinas", Vector3(RUINS.x, 0, RUINS.y), Vector3(4000, 1, 3600), 6, [bandit, archer, warrior, skeleton], [4.0, 3.0, 2.0, 1.0], 10)
	_zone(zones, "Pantano", Vector3(SWAMP.x, 0, SWAMP.y), Vector3(SWAMP.z * 2.0, 1, SWAMP.z * 2.0), 5, [zombie, spider, skeleton], [4.0, 3.0, 1.0], 10)
	_zone(zones, "Costa", Vector3(COAST.x, 0, COAST.y), Vector3(COAST.z * 2.0, 1, COAST.z * 2.0), 7, [bandit, archer, skeleton], [4.0, 3.0, 2.0], 10)
	_zone(zones, "Desierto", Vector3(DESERT.x, 0, DESERT.y), Vector3(DESERT.z * 2.0, 1, DESERT.z * 2.0), 8, [spider, warrior, archer], [4.0, 3.0, 2.0], 10)
	_zone(zones, "Montaña", Vector3(MOUNTAIN.x, 0, MOUNTAIN.y), Vector3(MOUNTAIN.z * 2.0, 1, MOUNTAIN.z * 2.0), 9, [wolf, warrior, skeleton], [4.0, 3.0, 2.0], 10)


func _zone(parent: Node3D, zone_name: String, pos: Vector3, size: Vector3, level: int, types: Array, weights: Array, max_enemies: int) -> void:
	var zone: Node3D = load(ZONE_SCENE).instantiate()
	zone.name = zone_name
	zone.transform = Transform3D(Basis.IDENTITY, pos)
	zone.enemy_scene = load(ENEMY_SCENE)
	zone.level = level
	zone.max_enemies = max_enemies
	zone.zone_size = size
	var typed_types: Array[EnemyData] = []
	for path in types:
		typed_types.append(load(path))
	zone.enemy_types = typed_types
	var typed_weights: Array[float] = []
	typed_weights.assign(weights)
	zone.type_weights = typed_weights
	parent.add_child(zone)


func _build_portals() -> void:
	var portals := _node("Portales", _root)
	_portal(portals, "aldea", "Aldea del Vado", Vector3(650, 0, 750))
	_portal(portals, "bosque", "Bosque Umbrío", Vector3(-4400, 0, -1550))
	_portal(portals, "cementerio", "Camposanto Hundido", Vector3(3900, 0, -3100))
	_portal(portals, "ruinas", "Ruinas de Kael", Vector3(-700, 0, -6300))
	_portal(portals, "pantano", "Ciénaga de los Ahogados", Vector3(-12300, 0, 900))
	_portal(portals, "montana", "Cumbres Heladas", Vector3(-1500, 0, -12300))
	_portal(portals, "costa", "Costa de los Naufragios", Vector3(12900, 0, -1700))
	_portal(portals, "desierto", "Mar de Arena", Vector3(2300, 0, 12000))


func _portal(parent: Node3D, id: String, display_name: String, wanted: Vector3) -> void:
	# Al costado del camino, no encima (el anillo de piedras lo cortaba).
	var pos: Vector3 = _off_road(wanted, 380.0)
	var portal: Node3D = load(PORTAL_SCENE).instantiate()
	portal.name = "Portal_" + id
	portal.portal_id = id
	portal.display_name = display_name
	portal.transform = Transform3D(Basis.IDENTITY, pos)
	parent.add_child(portal)
	_occupied.append(Vector3(pos.x, pos.z, 420.0))


# Cofres con botin del nivel de cada zona; los de las ruinas y el cementerio,
# buenos.
func _build_chests() -> void:
	var chests := _node("Cofres", _root)
	var placed: int = 0
	# Las zonas estan llenas de piezas: mas intentos y menos margen que lo normal.
	placed += _scatter(chests, FOREST, 400.0, FOREST.z * 0.85, 5, _chest.bind(3, 0), false, 90.0, 600)
	placed += _scatter(chests, Vector3(3200, 3600, 2000), 0.0, 2000.0, 2, _chest.bind(1, 0), false, 90.0, 600)
	placed += _scatter(chests, Vector3(GRAVEYARD.x, GRAVEYARD.y, 1300.0), 300.0, 1250.0, 3, _chest.bind(4, 1), false, 90.0, 600)
	placed += _scatter(chests, RUINS, 300.0, RUINS.z * 0.9, 4, _chest.bind(6, 1), false, 90.0, 600)
	placed += _scatter(chests, SWAMP, 400.0, SWAMP.z * 0.85, 4, _chest.bind(5, 1), false, 90.0, 600)
	placed += _scatter(chests, MOUNTAIN, 400.0, MOUNTAIN.z * 0.85, 4, _chest.bind(9, 1), false, 90.0, 600)
	placed += _scatter(chests, COAST, 400.0, COAST.z * 0.85, 4, _chest.bind(7, 1), false, 90.0, 600)
	placed += _scatter(chests, DESERT, 400.0, DESERT.z * 0.85, 4, _chest.bind(8, 1), false, 90.0, 600)
	placed += _scatter(chests, Vector3(-12800, -7400, 1500), 0.0, 1500.0, 2, _chest.bind(6, 0), false, 90.0, 600)
	placed += _scatter(chests, Vector3(12600, -6600, 1500), 0.0, 1500.0, 2, _chest.bind(8, 0), false, 90.0, 600)
	print("cofres: %d de 34" % placed)


# Herreria de la aldea (el modelo esta abierto hacia +Z) con el herrero adelante.
func _build_forge(village: Node3D) -> void:
	var basis := Basis(Vector3.UP, FORGE_SPOT.z)
	var pos := Vector3(FORGE_SPOT.x, 0, FORGE_SPOT.y)
	var forge: Node3D = _prop(village, FORGE, pos, FORGE_SPOT.z, FORGE_SCALE, 1.0, {"fade_when_occluding": true}, true)
	forge.name = "Herreria"
	if ResourceLoader.exists(SMITH_SCENE):
		var smith: Node3D = load(SMITH_SCENE).instantiate()
		smith.name = "Herrero"
		smith.transform = Transform3D(basis, pos + basis * Vector3.BACK * SMITH_DISTANCE)
		_root.add_child(smith, true)
		var smith_spot: Vector3 = smith.position
		_occupied.append(Vector3(smith_spot.x, smith_spot.z, 170.0))


# Campamentos con barriles y cajones rompibles (botin del nivel de la zona).
func _build_camps() -> void:
	var camps := _node("Rompibles", _root)
	var placed: int = 0
	# Las zonas estan llenas de piezas: poco margen y muchos intentos.
	placed += _scatter(camps, RUINS, 300.0, RUINS.z * 0.9, 3, _camp.bind(6), false, 70.0, 900)
	placed += _scatter(camps, FOREST, 500.0, FOREST.z * 0.85, 2, _camp.bind(3), false, 70.0, 900)
	placed += _scatter(camps, Vector3(2600, 2400, 1800), 0.0, 1800.0, 2, _camp.bind(1), false, 150.0, 300)
	placed += _scatter(camps, Vector3(GRAVEYARD.x, GRAVEYARD.y, 1300.0), 400.0, 1250.0, 1, _camp.bind(4), false, 40.0, 900)
	placed += _scatter(camps, SWAMP, 500.0, SWAMP.z * 0.8, 2, _camp.bind(5), false, 70.0, 900)
	placed += _scatter(camps, MOUNTAIN, 500.0, MOUNTAIN.z * 0.8, 2, _camp.bind(9), false, 70.0, 900)
	placed += _scatter(camps, COAST, 500.0, COAST.z * 0.8, 3, _camp.bind(7), false, 70.0, 900)
	placed += _scatter(camps, DESERT, 500.0, DESERT.z * 0.8, 2, _camp.bind(8), false, 70.0, 900)
	print("campamentos: %d de 17" % placed)


## Barriles y cajones juntos en un claro (cada uno con su lugar: no se pisan).
func _camp(parent: Node3D, pos: Vector3, level: int) -> void:
	if not _is_free(Vector2(pos.x, pos.z), 200.0):
		_rejected = true
		return
	_scatter(parent, Vector3(pos.x, pos.z, 280.0), 0.0, 280.0, _rng.randi_range(3, 5), _crate_or_barrel.bind(level), false, 5.0, 60)


func _crate_or_barrel(parent: Node3D, pos: Vector3, level: int) -> void:
	if _rng.randf() < 0.55:
		_breakable(_prop(parent, BARREL, pos, _rng.randf() * TAU, 260.0, 0.5), level, "Barril")
	else:
		_breakable(_prop(parent, CRATE, pos, _rng.randf() * TAU, 280.0, 0.45), level, "Cajón")


## La colision de la pieza pasa a ser el barril o cajon que se rompe.
func _breakable(prop: Node3D, level: int, display_name: String) -> void:
	if prop == null:
		return
	var body: StaticBody3D = prop.get_node("Colision")
	body.set_script(load(BREAKABLE_SCRIPT))
	body.level = level
	body.display_name = display_name


# Un santuario por region, cada uno con su bendicion (shrine.gd: 0 fuerza,
# 1 sabiduria, 2 celeridad, 3 vida, 4 proteccion).
func _build_shrines() -> void:
	var shrines := _node("Santuarios", _root)
	for spot in [[Vector3(-5300, -3400, 1200), 3], [Vector3(3500, 2400, 900), 2], [Vector3(GRAVEYARD.x - 1900, GRAVEYARD.y + 1400, 1000), 1],
			[Vector3(RUINS.x + 1300, RUINS.y + 1400, 900), 0], [Vector3(-3400, 900, 700), 4],
			[Vector3(SWAMP.x + 600, SWAMP.y - 1500, 1400), 3], [Vector3(MOUNTAIN.x + 1400, MOUNTAIN.y + 900, 900), 4],
			[Vector3(COAST.x - 400, COAST.y - 1900, 900), 2], [Vector3(DESERT.x - 1500, DESERT.y - 600, 900), 0]]:
		if _scatter(shrines, spot[0], 0.0, spot[0].z, 1, _shrine.bind(spot[1]), false, 90.0, 1500) == 0:
			push_warning("No entro el santuario de %s" % spot[0])


func _shrine(parent: Node3D, pos: Vector3, blessing: int) -> void:
	# El sigilo del piso necesita su lugar libre.
	if not _is_free(Vector2(pos.x, pos.z), SHRINE_CLEARANCE):
		_rejected = true
		return
	var angle: float = _rng.randf() * TAU
	_prop(parent, G + "pillar-obelisk.glb", pos, angle, 460.0, 0.0, {"style": PROP_SCRIPT.Style.STONE, "tint": Color(0.86, 0.84, 0.9)})
	var shrine := StaticBody3D.new()
	shrine.name = "Santuario"
	shrine.set_script(load(SHRINE_SCRIPT))
	shrine.blessing = blessing
	shrine.transform = Transform3D(Basis(Vector3.UP, angle), pos)
	parent.add_child(shrine, true)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 80.0
	cylinder.height = 480.0
	shape.shape = cylinder
	shape.position.y = 240.0
	shrine.add_child(shape)
	# Un circulo de menhires alrededor (con lugar para pasar entre ellos); el
	# que caeria encima de algo no va.
	var was_strict: bool = _strict
	_strict = false
	for i in 6:
		var around: float = angle + TAU * i / 6.0
		var spot := Vector2(pos.x, pos.z) + Vector2.from_angle(around) * MENHIR_RING
		if _is_free(spot, 110.0) and _distance_to_paths(spot) > PATH_WIDTH * 0.5 + 120.0:
			_prop(parent, C + "menhir_%s.glb" % "abcde"[i % 5], Vector3(spot.x, -10.0, spot.y), -around + _rng.randf_range(-0.3, 0.3),
					_rng.randf_range(290.0, 340.0), 0.4, {"style": PROP_SCRIPT.Style.TINT, "tint": Color(0.82, 0.82, 0.86)})
	_strict = was_strict
	# Que no tape el sigilo del piso con pasto ni otras piezas.
	_occupied.append(Vector3(pos.x, pos.z, SHRINE_CLEARANCE))


# Antorchas y faroles que se prenden de noche (los faroles de hierro de la
# plaza y del cementerio ya tienen la suya).
func _build_lights() -> void:
	var village: Node3D = _props.get_node("Aldea")
	var plaza := Vector2(0, -200)
	var torches: Array = [Vector2(520, -1700), Vector2(-250, -1150)]
	# Una antorcha al lado de la puerta de cada casa.
	for door in _house_doors:
		torches.append(door + (plaza - door).normalized().orthogonal() * 260.0)
	for spot in torches:
		var free: Vector2 = _find_free(spot, 60.0)
		if free.is_finite():
			_torch(village, Vector3(free.x, 0, free.y))
	for spot in [Vector2(-850, -150), Vector2(-250, -830), Vector2(-400, 400)]:
		var free: Vector2 = _find_free(spot, 50.0)
		if free.is_finite():
			_lantern(village, Vector3(free.x, 0, free.y))
	var ruins: Node3D = _props.get_node("Ruinas")
	for spot in [Vector2(-450, -7050), Vector2(250, -7050), Vector2(-350, -7850), Vector2(350, -7850)]:
		var free: Vector2 = _find_free(spot, 60.0)
		if free.is_finite():
			_torch(ruins, Vector3(free.x, 0, free.y))
	# Antorchas en los portones de la muralla (afuera) y en los puentes.
	for gate in _gates:
		for side in [-1.0, 1.0]:
			var spot: Vector2 = gate.center + gate.normal * 260.0 + gate.along * side * 520.0
			var free: Vector2 = _find_free(spot, 50.0)
			if free.is_finite():
				_torch(village, Vector3(free.x, 0, free.y))
	for bridge in _bridges:
		var free: Vector2 = _find_free(bridge.center + bridge.dir * (bridge.length / 2.0 + 180.0) + bridge.dir.orthogonal() * 300.0, 50.0)
		if free.is_finite():
			_torch(_props, Vector3(free.x, 0, free.y))


## point corrido de costado lo justo para que quede a clearance (o mas) del
## borde del camino mas cercano.
func _off_road(point: Vector3, clearance: float) -> Vector3:
	var flat := Vector2(point.x, point.z)
	for i in 40:
		if _distance_to_paths(flat) >= PATH_WIDTH * 0.5 + clearance:
			break
		var away: Vector2 = flat - _closest_path_point(flat)
		flat += (away.normalized() if away.length() > 1.0 else Vector2.RIGHT) * 40.0
	return Vector3(flat.x, point.y, flat.y)


func _closest_path_point(p: Vector2) -> Vector2:
	var best := p
	var best_distance: float = INF
	for path in _paths:
		for i in path.size() - 1:
			var closest: Vector2 = Geometry2D.get_closest_point_to_segment(p, path[i], path[i + 1])
			if closest.distance_to(p) < best_distance:
				best_distance = closest.distance_to(p)
				best = closest
	return best


## Lugar libre lo mas cerca posible de point y fuera de los caminos (busca en
## anillos cada vez mas grandes). Vector2.INF si no hay.
func _find_free(point: Vector2, clearance: float) -> Vector2:
	for ring in 9:
		var steps: int = maxi(1, ring * 6)
		for i in steps:
			var angle: float = TAU * i / steps
			var candidate: Vector2 = point + Vector2(cos(angle), sin(angle)) * ring * 50.0
			if _distance_to_paths(candidate) > PATH_WIDTH * 0.8 and _is_free(candidate, clearance):
				return candidate
	return Vector2.INF


# Palo con un brasero chico arriba y la luz con llamas. Sin colision: es
# finito y el jugador (mas ancho que el margen de la navegacion) se trababa.
func _torch(parent: Node3D, pos: Vector3) -> void:
	var torch := Node3D.new()
	torch.name = "Antorcha"
	torch.position = pos
	parent.add_child(torch, true)
	var pole := MeshInstance3D.new()
	pole.name = "Palo"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 6.0
	cylinder.bottom_radius = 10.0
	cylinder.height = TORCH_HEIGHT
	cylinder.radial_segments = 7
	cylinder.rings = 1
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.24, 0.16, 0.1)
	wood.roughness = 0.95
	cylinder.material = wood
	pole.mesh = cylinder
	pole.position.y = TORCH_HEIGHT / 2.0
	torch.add_child(pole)
	var basket := Node3D.new()
	basket.name = "Brasero"
	basket.set_script(PROP_SCRIPT)
	basket.style = PROP_SCRIPT.Style.IRON
	basket.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 150.0), Vector3.UP * TORCH_HEIGHT)
	torch.add_child(basket)
	basket.add_child(_scene(G + "fire-basket.glb").instantiate())
	_night_light(torch, Vector3.UP * (TORCH_HEIGHT + 30.0), {"flames": true, "energy": 1.2, "light_range": 900.0, "glow_size": 120.0})
	_occupied.append(Vector3(pos.x, pos.z, 60.0))


# Farol de madera en el piso con una luz chica (sin colision, como las antorchas).
func _lantern(parent: Node3D, pos: Vector3) -> void:
	if _prop(parent, LANTERN, pos, _rng.randf() * TAU, LANTERN_SCALE, 0.0) == null:
		return
	_night_light(parent, pos + Vector3.UP * 0.2 * LANTERN_SCALE, {"energy": 0.8, "light_range": 650.0, "glow_size": 80.0})


## Luz que se prende de noche (night_light.gd). pos es relativa a parent (los
## nodos de cada zona estan en el origen del mundo).
func _night_light(parent: Node3D, pos: Vector3, options: Dictionary) -> void:
	var light := Node3D.new()
	light.name = "LuzDeNoche"
	light.set_script(load(NIGHT_LIGHT_SCRIPT))
	for key in options:
		light.set(key, options[key])
	light.position = pos
	parent.add_child(light, true)


## Cofre con lugar libre alrededor (el botin sale por adelante y cae cerca),
## mirando hacia el lado mas despejado.
func _chest(parent: Node3D, pos: Vector3, level: int, quality: int) -> void:
	var spot := Vector2(pos.x, pos.z)
	if not _is_free(spot, CHEST_CLEARANCE):
		_rejected = true
		return
	var best_angle: float = _rng.randf() * TAU
	var best_room: float = -INF
	for i in 12:
		var angle: float = TAU * i / 12.0
		var ahead: Vector2 = spot + Vector2(sin(angle), cos(angle)) * CHEST_CLEARANCE * 1.5
		var room: float = _room_at(ahead)
		if room > best_room + 1.0:
			best_room = room
			best_angle = angle
	var chest: Node3D = load(CHEST_SCENE).instantiate()
	chest.name = "Cofre"
	chest.level = level
	chest.quality = quality
	chest.transform = Transform3D(Basis(Vector3.UP, best_angle), pos)
	parent.add_child(chest, true)
	_occupied.append(Vector3(pos.x, pos.z, 150.0))


## Distancia de un punto a lo ocupado mas cercano (circulos y cajas).
func _room_at(point: Vector2) -> float:
	var room: float = INF
	for other in _occupied:
		room = minf(room, point.distance_to(Vector2(other.x, other.y)) - other.z)
	for box in _boxes:
		room = minf(room, _box_distance(box, point))
	return room


func _build_labels() -> void:
	var labels := _node("NombresDelMapa", _root)
	for entry in [["Aldea del Vado", Vector2(VILLAGE.x, VILLAGE.y)], ["Bosque Umbrío", Vector2(FOREST.x, FOREST.y)],
			["Camposanto Hundido", Vector2(GRAVEYARD.x, GRAVEYARD.y)], ["Ruinas de Kael", Vector2(RUINS.x, RUINS.y)],
			["Prados del Sur", Vector2(1500, 4500)], ["Ciénaga de los Ahogados", Vector2(SWAMP.x, SWAMP.y)],
			["Cumbres Heladas", Vector2(MOUNTAIN.x, MOUNTAIN.y)], ["Costa de los Naufragios", Vector2(COAST.x, COAST.y)],
			["Mar de Arena", Vector2(DESERT.x, DESERT.y)], ["Río Frío", Vector2(9300, -9800)], ["Río Turbio", Vector2(-9800, -9000)]]:
		var marker := Marker3D.new()
		marker.name = entry[0].replace(" ", "")
		marker.position = Vector3(entry[1].x, 0, entry[1].y)
		marker.set_meta("map_label", entry[0])
		marker.add_to_group("map_labels", true)
		labels.add_child(marker)


# --- Colocacion ------------------------------------------------------------

func _node(node_name: String, parent: Node) -> Node3D:
	var node := Node3D.new()
	node.name = node_name
	parent.add_child(node)
	return node


## Reparte count piezas al azar dentro del anillo [inner, outer] de la zona
## (x, z = centro). Evita caminos, la aldea y lo ya ocupado (a clearance de
## distancia). square = en vez de circulo, todo el cuadrado del mundo.
func _scatter(parent: Node3D, zone: Vector3, inner: float, outer: float, count: int, maker: Callable, square: bool = false,
		clearance: float = 160.0, tries_per_piece: int = 30) -> int:
	var placed: int = 0
	var tries: int = 0
	var center := Vector2(zone.x, zone.y)
	while placed < count and tries < count * tries_per_piece:
		tries += 1
		var point: Vector2
		if square:
			point = Vector2(_rng.randf_range(-outer, outer), _rng.randf_range(-outer, outer))
			if _in_any_zone(point):
				continue
		else:
			var angle: float = _rng.randf() * TAU
			var dist: float = sqrt(_rng.randf_range(inner * inner, outer * outer))
			point = center + Vector2(cos(angle), sin(angle)) * dist
			# Bordes de la zona irregulares.
			if dist > outer * (0.75 + 0.25 * _noise.get_noise_2dv(point * 3.0)):
				continue
		if absf(point.x) > WALK_LIMIT - 100.0 or absf(point.y) > WALK_LIMIT - 100.0:
			continue
		if _distance_to_paths(point) < PATH_WIDTH + 140.0:
			continue
		if zone != VILLAGE and _inside_walls(point, 250.0):
			continue
		if _distance_to_rivers(point) < 520.0 or point.x > _shore_x(point.y) - 350.0:
			continue
		if not _is_free(point, clearance):
			continue
		# El generador elige el modelo: recien ahi se sabe su huella real.
		var was_strict: bool = _strict
		_strict = true
		_rejected = false
		maker.call(parent, Vector3(point.x, 0, point.y))
		_strict = was_strict
		if _rejected:
			_rejected = false
			continue
		placed += 1
	return placed


func _in_any_zone(point: Vector2) -> bool:
	for zone in [VILLAGE, FOREST, GRAVEYARD, RUINS, SWAMP, MOUNTAIN, COAST, DESERT]:
		if point.distance_to(Vector2(zone.x, zone.y)) < zone.z + 300.0:
			return true
	return false


## Adentro de la muralla de la aldea (con margen).
func _inside_walls(point: Vector2, margin: float = 0.0) -> bool:
	return absf(point.x - VILLAGE.x) < WALL_HALF + margin and absf(point.y - VILLAGE.y) < WALL_HALF + margin


## x de la orilla del mar a la altura z.
func _shore_x(z: float) -> float:
	return SHORE_X + _noise.get_noise_2d(SHORE_X, z * 0.6) * 900.0


func _is_free(point: Vector2, radius: float) -> bool:
	for other in _occupied:
		if point.distance_to(Vector2(other.x, other.y)) < radius + other.z:
			return false
	for box in _boxes:
		if _box_distance(box, point) < radius:
			return false
	return true


## Si un circulo (la copa de un arbol) no se mete en nada alto.
func _crown_free(point: Vector2, radius: float) -> bool:
	for other in _tall:
		if other is Vector3:
			if point.distance_to(Vector2(other.x, other.y)) < radius + other.z:
				return false
		elif _box_distance(other, point) < radius:
			return false
	return true


## Si una caja girada no pisa nada de lo ya puesto (con margin de aire).
func _box_free(box: Dictionary, margin: float = 0.0) -> bool:
	for other in _occupied:
		if _box_distance(box, Vector2(other.x, other.y)) < other.z + margin:
			return false
	for other in _boxes:
		if _boxes_overlap(box, other, margin):
			return false
	return true


func _box(center: Vector2, angle: float, half: Vector2) -> Dictionary:
	# Basis(UP, angle) lleva el eje x local a (cos, -sin) y el z a (sin, cos) en (x, z).
	return {"c": center, "ax": Vector2(cos(angle), -sin(angle)), "az": Vector2(sin(angle), cos(angle)), "half": half}


## Distancia de un punto a una caja girada (negativa adentro).
func _box_distance(box: Dictionary, point: Vector2) -> float:
	var local: Vector2 = point - box.c
	var lx: float = absf(local.dot(box.ax)) - box.half.x
	var lz: float = absf(local.dot(box.az)) - box.half.y
	if lx > 0.0 or lz > 0.0:
		return Vector2(maxf(lx, 0.0), maxf(lz, 0.0)).length()
	return maxf(lx, lz)


## Si dos cajas giradas se pisan (ejes separadores: los de las dos cajas).
func _boxes_overlap(a: Dictionary, b: Dictionary, margin: float = 0.0) -> bool:
	for axis in [a.ax, a.az, b.ax, b.az]:
		var ra: float = a.half.x * absf(a.ax.dot(axis)) + a.half.y * absf(a.az.dot(axis))
		var rb: float = b.half.x * absf(b.ax.dot(axis)) + b.half.y * absf(b.az.dot(axis))
		if absf((b.c - a.c).dot(axis)) >= ra + rb + margin:
			return false
	return true


## Crea una pieza: un nodo con prop.gd, el modelo como hijo y, si collider > 0,
## una colision cilindrica de radio collider * ancho (o una caja si box = true).
## trunk_radius > 0 = colision fija de ese radio (troncos de arboles).
## El modelo queda apoyado en el piso: si su malla mas baja esta arriba del
## origen se baja hasta tocarlo (los de 0 A.D. traen el origen en el piso y
## algo enterrado: esos se dejan). Con options.center (piezas sueltas de un
## set de rocas, que vienen corridas del origen) se centra en pos y se apoya
## por su base; options.sink la entierra esa fraccion de su alto.
## Con _strict (desde _scatter) no la pone y devuelve null si su huella real
## pisa algo ya puesto.
func _prop(parent: Node3D, path: String, pos: Vector3, angle: float, scale: float, collider: float,
		options: Dictionary = {}, box: bool = false, trunk_radius: float = 0.0) -> Node3D:
	var keep_only: String = options.get("keep_only", "")
	var bounds: AABB = _bounds_of(path, keep_only)
	var shift := Vector3.ZERO
	var centered: bool = options.get("center", false)
	if centered:
		shift.x = -bounds.get_center().x
		shift.z = -bounds.get_center().z
	if centered or bounds.position.y * scale > 2.0:
		shift.y = -bounds.position.y
	shift.y -= bounds.size.y * options.get("sink", 0.0)
	bounds.position += shift

	var basis := Basis(Vector3.UP, angle)
	var middle: Vector3 = pos + basis * (bounds.get_center() * scale)
	var center := Vector2(middle.x, middle.z)
	var footprint: float = maxf(bounds.size.x, bounds.size.z) * scale
	var tall: bool = pos.y + bounds.end.y * scale > TALL_HEIGHT
	# Lo que es una caja (casas, muros, portones, cercos) ocupa su caja, tenga
	# colision o no (los muros la tienen aparte, de punta a punta).
	var solid_box: Dictionary = {}
	if box:
		solid_box = _box(center, angle, Vector2(bounds.size.x, bounds.size.z) * scale * 0.46)
	var solid_radius: float = trunk_radius if trunk_radius > 0.0 else maxf(bounds.size.x, bounds.size.z) * collider * scale
	if _strict and not _fits(Vector2(pos.x, pos.z), center, footprint, solid_box, solid_radius, trunk_radius > 0.0, collider > 0.0):
		_rejected = true
		return null

	var prop := Node3D.new()
	prop.set_script(PROP_SCRIPT)
	prop.name = path.get_file().get_basename().replace(".", "_")
	for key in options:
		if key != "sink" and key != "center":
			prop.set(key, options[key])
	prop.transform = Transform3D(basis.scaled(Vector3.ONE * scale), pos)
	parent.add_child(prop, true)
	var model: Node3D = _scene(path).instantiate()
	model.position += shift
	prop.add_child(model)

	if not solid_box.is_empty():
		_boxes.append(solid_box)
		if tall:
			_tall.append(solid_box)
	elif trunk_radius > 0.0:
		# Arbol: el tronco esta en el origen del modelo. Ocupa menos que su copa
		# (las de 0 A.D. son anchas): abajo queda lugar para cofres y claros.
		_occupied.append(Vector3(pos.x, pos.z, maxf(footprint * TREE_ROOM, 60.0)))
	else:
		_occupied.append(Vector3(center.x, center.y, maxf(footprint * 0.45, 60.0)))
		if tall and collider > 0.0:
			_tall.append(Vector3(center.x, center.y, solid_radius))

	if collider <= 0.0 and trunk_radius <= 0.0:
		return prop
	var body := StaticBody3D.new()
	body.name = "Colision"
	prop.add_child(body)
	var shape := CollisionShape3D.new()
	if box:
		var box_shape := BoxShape3D.new()
		box_shape.size = bounds.size * 0.92
		shape.shape = box_shape
		shape.position = bounds.get_center()
	else:
		var cylinder := CylinderShape3D.new()
		var radius: float = trunk_radius / scale if trunk_radius > 0.0 else maxf(bounds.size.x, bounds.size.z) * collider
		cylinder.radius = radius
		cylinder.height = maxf(bounds.size.y, 300.0 / scale)
		shape.shape = cylinder
		shape.position = Vector3(bounds.get_center().x if trunk_radius <= 0.0 else 0.0, cylinder.height / 2.0 + bounds.position.y, bounds.get_center().z if trunk_radius <= 0.0 else 0.0)
	body.add_child(shape)
	return prop


## Si una pieza que reparte _scatter entra donde cae: lo solido no puede
## pisar nada; la copa de un arbol no puede meterse en algo alto (casas,
## muros); lo que no tiene colision (arbustos, helechos) solo no puede quedar
## con el centro adentro de otra pieza.
func _fits(origin: Vector2, center: Vector2, footprint: float, solid_box: Dictionary, solid_radius: float, is_tree: bool, solid: bool) -> bool:
	if not solid_box.is_empty():
		return _box_free(solid_box, 20.0) and not _box_on_road(solid_box, 20.0)
	if is_tree:
		return _is_free(origin, solid_radius + 20.0) and _crown_free(center, footprint * 0.32)
	if solid:
		# Lo que se ve llega mas lejos que la colision (piezas largas, rocas).
		return _is_free(center, maxf(solid_radius, footprint * 0.4) + 10.0)
	return _is_free(center, footprint * 0.15)


## Caja del modelo en sus coordenadas (de la malla keep_only si se indica).
func _bounds_of(path: String, keep_only: String) -> AABB:
	var key: String = path + "|" + keep_only
	if not _bounds_cache.has(key):
		var model: Node3D = _scene(path).instantiate()
		_bounds_cache[key] = _model_bounds(model, keep_only)
		model.free()
	return _bounds_cache[key]


## Pieza del fuerte modular centrada en pos. Todas vienen en el mismo archivo,
## cada una corrida decenas de metros del origen: sin centrarlas, la torre de
## la montaña, el faro, las ruinas y el templo del desierto aparecian lejos de
## donde se los ponia (encima de caminos, rios y arboles).
## Los portones llevan colision solo en los costados, para pasar por el arco.
## Con settle (las piezas sueltas: ruinas, torres, templo) si donde se la pide
## pisa algo o un camino, se corre al lugar libre mas cercano; los portones
## si pueden quedar sobre el camino (se pasa por el arco).
func _fort_piece(parent: Node3D, piece: String, wanted: Vector3, angle: float, scale: float, collide: bool = true, settle: bool = true) -> Node3D:
	var is_gate: bool = piece.contains("gate")
	var pos: Vector3 = wanted
	if settle:
		var bounds: AABB = _bounds_of(FORT, piece)
		var half := Vector2(bounds.size.x, bounds.size.z) * scale * 0.46
		var found: bool = false
		for ring in 16:
			var steps: int = maxi(1, ring * 6)
			for i in steps:
				var spot: Vector2 = Vector2(wanted.x, wanted.z) + Vector2.from_angle(TAU * i / steps) * ring * 45.0
				var box: Dictionary = _box(spot, angle, half)
				var free: bool = _is_free(spot, half.x + 30.0) if piece.contains("tower_round") else _box_free(box, 30.0)
				if free and (is_gate or not _box_on_road(box, 30.0)):
					pos = Vector3(spot.x, wanted.y, spot.y)
					found = true
					break
			if found:
				break
		if not found:
			push_warning("La pieza %s no encontro lugar libre cerca de %s" % [piece, wanted])
	var prop: Node3D = _prop(parent, FORT, pos, angle, scale, 0.0 if is_gate or not collide else 1.0, {"keep_only": piece, "fade_when_occluding": true, "center": true}, true)
	if piece.contains("tower_round"):
		# Las torres son redondas: ocupan un circulo, no la caja (que en las
		# esquinas de la muralla tapaba lugar de mas).
		var square: Dictionary = _boxes.pop_back()
		_tall.erase(square)
		var round_room := Vector3(square.c.x, square.c.y, square.half.x)
		_occupied.append(round_room)
		_tall.append(round_room)
		# Y su colision tambien es redonda (las esquinas de la caja eran paredes invisibles).
		var body: Node = prop.get_node_or_null("Colision")
		var collision: CollisionShape3D = body.get_child(0) if body and body.get_child_count() > 0 else null
		if collision and collision.shape is BoxShape3D:
			var cylinder := CylinderShape3D.new()
			cylinder.radius = collision.shape.size.x / 2.0
			cylinder.height = collision.shape.size.y
			collision.shape = cylinder
	if not is_gate:
		return prop
	var bounds: AABB = _model_bounds(prop.get_child(0), piece)
	var body := StaticBody3D.new()
	body.name = "Colision"
	prop.add_child(body)
	for side in [0.0, 0.7]:
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(bounds.size.x, bounds.size.y, bounds.size.z * 0.3)
		shape.shape = box
		shape.position = Vector3(bounds.get_center().x, bounds.size.y / 2.0, bounds.position.z + bounds.size.z * (side + 0.15))
		body.add_child(shape)
	return prop


func _scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	return _scene_cache[path]


# Caja del modelo en sus coordenadas (solo la malla keep_only si se indica).
func _model_bounds(model: Node3D, keep_only: String) -> AABB:
	var bounds := AABB()
	var first: bool = true
	for mesh in model.find_children("*", "MeshInstance3D", true, false):
		if not keep_only.is_empty() and mesh.name != keep_only:
			continue
		var local: Transform3D = model.transform * _relative_transform(mesh, model)
		var box: AABB = local * (mesh as MeshInstance3D).get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	return bounds


func _relative_transform(node: Node3D, ancestor: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var current: Node = node
	while current != ancestor and current is Node3D:
		xf = (current as Node3D).transform * xf
		current = current.get_parent()
	return xf


# --- Mapas de mezcla del piso ----------------------------------------------

func _paint_splats() -> void:
	var a := Image.create(SPLAT_RES, SPLAT_RES, false, Image.FORMAT_RGBA8)
	var b := Image.create(SPLAT_RES, SPLAT_RES, false, Image.FORMAT_RGBA8)
	var detail := FastNoiseLite.new()
	detail.seed = SEED + 1
	detail.frequency = 0.004
	var tone := FastNoiseLite.new()
	tone.seed = SEED + 2
	tone.frequency = 0.00035
	tone.fractal_octaves = 4
	var px: float = SIZE / SPLAT_RES
	for y in SPLAT_RES:
		for x in SPLAT_RES:
			var p := Vector2((x + 0.5) * px - HALF, (y + 0.5) * px - HALF)
			var wobble: float = detail.get_noise_2dv(p)
			var path_dist: float = _distance_to_paths(p) + wobble * 70.0
			var dirt: float = 1.0 - smoothstep(PATH_WIDTH * 0.45, PATH_WIDTH, path_dist)
			var plaza: float = _area(p, Vector2(0, -200), 820.0, wobble) + _area(p, Vector2(RUINS.x, RUINS.y), 650.0, wobble)
			var forest: float = _area(p, Vector2(FOREST.x, FOREST.y), FOREST.z * 1.05, wobble * 3.0)
			var moss: float = _area(p, Vector2(GRAVEYARD.x, GRAVEYARD.y), GRAVEYARD.z, wobble * 2.0)
			var rocky: float = _area(p, Vector2(RUINS.x, RUINS.y), RUINS.z * 1.1, wobble * 2.0)
			# Pantano: barro del bosque y musgo (el shader lo oscurece).
			var swamp: float = _area(p, Vector2(SWAMP.x, SWAMP.y), SWAMP.z * 1.1, wobble * 3.0)
			forest = maxf(forest, swamp * 0.85)
			moss = maxf(moss, swamp * 0.55)
			# Arena en el desierto y la playa; nieve en la montaña y el norte.
			var sand: float = maxf(_area(p, Vector2(DESERT.x, DESERT.y), DESERT.z * 1.25, wobble * 3.0), smoothstep(-2000.0, -1000.0, p.x - _shore_x(p.y) + wobble * 260.0))
			sand = maxf(sand, smoothstep(12500.0, 15500.0, p.y + wobble * 500.0) * 0.8)
			var snow: float = maxf(_area(p, Vector2(MOUNTAIN.x, MOUNTAIN.y), MOUNTAIN.z * 1.25, wobble * 3.0), 1.0 - smoothstep(-15500.0, -12800.0, p.y + wobble * 500.0))
			rocky = maxf(rocky, _area(p, Vector2(MOUNTAIN.x, MOUNTAIN.y), MOUNTAIN.z * 1.3, wobble * 3.0) * smoothstep(0.55, 0.75, detail.get_noise_2dv(p * 0.5) * 0.5 + 0.5))
			# Orillas de los rios: tierra mojada.
			var bank: float = 1.0 - smoothstep(0.0, 260.0, _distance_to_rivers(p) + wobble * 60.0)
			# Manchas de piedra sueltas por el mundo.
			rocky = maxf(rocky, smoothstep(0.62, 0.72, detail.get_noise_2dv(p * 0.35 + Vector2(900, 400)) * 0.5 + 0.5))
			var plaza_weight: float = clampf(plaza, 0.0, 1.0)
			# El camino se pierde al entrar a la plaza.
			dirt *= 1.0 - plaza_weight * 0.8
			dirt = maxf(dirt, bank * 0.9)
			a.set_pixel(x, y, Color(dirt, plaza_weight, forest, moss))
			b.set_pixel(x, y, Color(rocky * (1.0 - plaza_weight), tone.get_noise_2dv(p) * 0.5 + 0.5, sand * (1.0 - snow), snow))
	# El piso los carga al abrir (world/terrain/ground.gd).
	a.save_png(ProjectSettings.globalize_path(SPLAT_A))
	b.save_png(ProjectSettings.globalize_path(SPLAT_B))
	_splat_a = a
	_splat_b = b


## Donde crece el pasto y que suelo hay para los pasos (ver GRASS_MASK): nada
## en caminos, adoquines ni piedra, poco en el bosque y algo en el musgo del
## cementerio (mas seco, como en las ruinas); nada debajo de lo que ocupa
## lugar (casas, rocas, arboles, cofres, santuarios).
func _paint_grass_mask() -> void:
	var mask := Image.create(SPLAT_RES, SPLAT_RES, false, Image.FORMAT_RGBA8)
	var patches := FastNoiseLite.new()
	patches.seed = SEED + 3
	patches.frequency = 0.0012
	var px: float = SIZE / SPLAT_RES
	for y in SPLAT_RES:
		for x in SPLAT_RES:
			var p := Vector2((x + 0.5) * px - HALF, (y + 0.5) * px - HALF)
			var a: Color = _splat_a.get_pixel(x, y)
			var b: Color = _splat_b.get_pixel(x, y)
			var kind: float = 0.0
			if a.g > 0.5 or b.r > 0.5:
				kind = 1.0
			elif a.r > 0.45 or a.b > 0.55:
				kind = 0.5
			var density: float = clampf(1.0 - maxf(maxf(a.r * 1.6, a.g * 2.0), b.r * 1.4), 0.0, 1.0)
			density *= (1.0 - a.b * 0.75) * (1.0 - a.a * 0.35)
			density *= clampf(1.0 - maxf(b.b, b.a) * 1.6, 0.0, 1.0)
			if p.x > _shore_x(p.y) - 200.0 or _distance_to_rivers(p) < 80.0:
				density = 0.0
			if b.b > 0.5 or b.a > 0.5:
				kind = 0.5
			# Manchas mas y menos tupidas.
			density *= clampf(0.55 + patches.get_noise_2dv(p) * 0.9, 0.15, 1.0)
			if absf(p.x) > WALK_LIMIT + 300.0 or absf(p.y) > WALK_LIMIT + 300.0:
				density = 0.0
			var dry: float = clampf(a.a * 0.9 + _area(p, Vector2(RUINS.x, RUINS.y), RUINS.z * 1.2, 0.0) * 0.7 + b.b * 0.8, 0.0, 1.0)
			mask.set_pixel(x, y, Color(density, dry, kind, 1.0))
	for other in _occupied:
		var radius: float = other.z * 0.7 / px
		var center := Vector2((other.x + HALF) / px, (other.y + HALF) / px)
		for y in range(maxi(floori(center.y - radius), 0), mini(ceili(center.y + radius) + 1, SPLAT_RES)):
			for x in range(maxi(floori(center.x - radius), 0), mini(ceili(center.x + radius) + 1, SPLAT_RES)):
				if Vector2(x + 0.5, y + 0.5).distance_to(center) <= radius:
					var color: Color = mask.get_pixel(x, y)
					color.r = 0.0
					mask.set_pixel(x, y, color)
	# Adentro de las cajas (casas, muros, cercos) tampoco.
	for box in _boxes:
		var reach: float = box.half.length() / px
		var middle := Vector2((box.c.x + HALF) / px, (box.c.y + HALF) / px)
		for y in range(maxi(floori(middle.y - reach), 0), mini(ceili(middle.y + reach) + 1, SPLAT_RES)):
			for x in range(maxi(floori(middle.x - reach), 0), mini(ceili(middle.x + reach) + 1, SPLAT_RES)):
				if _box_distance(box, Vector2((x + 0.5) * px - HALF, (y + 0.5) * px - HALF)) <= 0.0:
					var color: Color = mask.get_pixel(x, y)
					color.r = 0.0
					mask.set_pixel(x, y, color)
	mask.save_png(ProjectSettings.globalize_path(GRASS_MASK))


func _area(p: Vector2, center: Vector2, radius: float, wobble: float) -> float:
	var d: float = p.distance_to(center) + wobble * radius * 0.12
	return 1.0 - smoothstep(radius * 0.8, radius, d)


## Distancia al camino mas cercano (INF si no hay ninguno a menos de GRID_CELL).
func _distance_to_paths(p: Vector2) -> float:
	return _grid_distance(_path_grid, p)


## Distancia a la orilla del rio mas cercano (negativa adentro del agua; INF lejos).
func _distance_to_rivers(p: Vector2) -> float:
	return _grid_distance(_river_grid, p)


const GRID_CELL: float = 1200.0


func _grid_distance(grid: Dictionary, p: Vector2) -> float:
	var cell := Vector2i(floori(p.x / GRID_CELL), floori(p.y / GRID_CELL))
	var best: float = INF
	for segment in grid.get(cell, []):
		var closest: Vector2 = Geometry2D.get_closest_point_to_segment(p, segment[0], segment[1])
		best = minf(best, p.distance_to(closest) - segment[2])
	return best


# Cada tramo (a, b, medio ancho) va a todas las celdas que toca con un margen
# de una celda: asi una consulta mira solo su celda.
func _grid_add(grid: Dictionary, a: Vector2, b: Vector2, half_width: float) -> void:
	var low := Vector2i(floori((minf(a.x, b.x) - GRID_CELL) / GRID_CELL), floori((minf(a.y, b.y) - GRID_CELL) / GRID_CELL))
	var high := Vector2i(floori((maxf(a.x, b.x) + GRID_CELL) / GRID_CELL), floori((maxf(a.y, b.y) + GRID_CELL) / GRID_CELL))
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var cell := Vector2i(x, y)
			if not grid.has(cell):
				grid[cell] = []
			grid[cell].append([a, b, half_width])


func _build_grids() -> void:
	for path in _paths:
		for i in path.size() - 1:
			_grid_add(_path_grid, path[i], path[i + 1], 0.0)
	for river in RIVERS:
		var points: PackedVector2Array = _smooth(PackedVector2Array(river.points), 3)
		points = _resample(points, 260.0)
		var widths := PackedFloat32Array()
		for i in points.size():
			widths.append(river.width * (0.85 + 0.3 * (_noise.get_noise_2dv(points[i] * 2.0) * 0.5 + 0.5)))
		_river_lines.append({"name": river.name, "points": points, "widths": widths})
		for i in points.size() - 1:
			_grid_add(_river_grid, points[i], points[i + 1], (widths[i] + widths[i + 1]) * 0.25)


# --- Navegacion -------------------------------------------------------------

func _bake_navigation() -> void:
	var nav_mesh := NavigationMesh.new()
	nav_mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nav_mesh.geometry_collision_mask = 1
	nav_mesh.cell_size = 20.0
	nav_mesh.cell_height = 5.0
	nav_mesh.agent_height = 300.0
	nav_mesh.agent_radius = 60.0
	nav_mesh.agent_max_climb = 25.0
	nav_mesh.agent_max_slope = 40.0
	nav_mesh.region_min_size = 4.0
	nav_mesh.region_merge_size = 40.0
	nav_mesh.edge_max_length = 0.0
	nav_mesh.edge_max_error = 1.5
	nav_mesh.detail_sample_distance = 6.0
	nav_mesh.detail_sample_max_error = 1.0
	nav_mesh.filter_baking_aabb = AABB(Vector3(-WALK_LIMIT, -100.0, -WALK_LIMIT), Vector3(WALK_LIMIT * 2.0, 600.0, WALK_LIMIT * 2.0))
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(nav_mesh, source, _root)
	var start: int = Time.get_ticks_msec()
	NavigationServer3D.bake_from_source_geometry_data(nav_mesh, source)
	var removed: int = _keep_connected(nav_mesh, Vector3(VILLAGE.x, 0, VILLAGE.y))
	for region in {"pantano": SWAMP, "montaña": MOUNTAIN, "costa": COAST, "desierto": DESERT}:
		var c: Vector3 = {"pantano": SWAMP, "montaña": MOUNTAIN, "costa": COAST, "desierto": DESERT}[region]
		print("  %s conectado: %s" % [region, _has_polygon_near(nav_mesh, Vector2(c.x, c.y), 1500.0)])
	print("navegacion: %d poligonos en %d ms (%d sueltos sacados)" % [nav_mesh.get_polygon_count(), Time.get_ticks_msec() - start, removed])
	ResourceSaver.save(nav_mesh, OUT_NAV)
	var region := NavigationRegion3D.new()
	region.name = "Navegacion"
	region.navigation_mesh = load(OUT_NAV)
	_root.add_child(region)
	_root.move_child(region, 1)
	region.owner = _root


## Deja solo los poligonos conectados al piso de la aldea: saca las islas
## (techos de portales, cajas, rincones cerrados) a las que no se puede
## llegar. Si no, un clic cerca de una mandaba al jugador a cualquier lado y
## los enemigos podian aparecer arriba de un portal. Devuelve cuantos saco.
func _has_polygon_near(nav_mesh: NavigationMesh, point: Vector2, radius: float) -> bool:
	var vertices: PackedVector3Array = nav_mesh.get_vertices()
	for i in nav_mesh.get_polygon_count():
		var index: int = nav_mesh.get_polygon(i)[0]
		if Vector2(vertices[index].x, vertices[index].z).distance_to(point) < radius:
			return true
	return false


func _keep_connected(nav_mesh: NavigationMesh, seed_point: Vector3) -> int:
	var vertices: PackedVector3Array = nav_mesh.get_vertices()
	var polygons: Array[PackedInt32Array] = []
	for i in nav_mesh.get_polygon_count():
		polygons.append(nav_mesh.get_polygon(i))
	# Poligonos vecinos: los que comparten un borde (dos vertices).
	var by_edge: Dictionary = {}
	for i in polygons.size():
		var poly: PackedInt32Array = polygons[i]
		for k in poly.size():
			var a: int = poly[k]
			var b: int = poly[(k + 1) % poly.size()]
			var key := Vector2i(mini(a, b), maxi(a, b))
			if not by_edge.has(key):
				by_edge[key] = []
			by_edge[key].append(i)
	var start: int = 0
	var best: float = INF
	for i in polygons.size():
		var center := Vector3.ZERO
		for index in polygons[i]:
			center += vertices[index]
		center /= polygons[i].size()
		var distance: float = Vector2(center.x - seed_point.x, center.z - seed_point.z).length() + absf(center.y - seed_point.y) * 10.0
		if distance < best:
			best = distance
			start = i
	var keep: Dictionary = {start: true}
	var pending: Array[int] = [start]
	while not pending.is_empty():
		var current: int = pending.pop_back()
		var poly: PackedInt32Array = polygons[current]
		for k in poly.size():
			var a: int = poly[k]
			var b: int = poly[(k + 1) % poly.size()]
			for other in by_edge[Vector2i(mini(a, b), maxi(a, b))]:
				if not keep.has(other):
					keep[other] = true
					pending.append(other)
	nav_mesh.clear_polygons()
	for i in polygons.size():
		if keep.has(i):
			nav_mesh.add_polygon(polygons[i])
	return polygons.size() - keep.size()


# --- Guardar ---------------------------------------------------------------

func _save() -> void:
	var packed := PackedScene.new()
	var error: Error = packed.pack(_root)
	if error != OK:
		push_error("No se pudo empaquetar el mundo: %s" % error_string(error))
		return
	error = ResourceSaver.save(packed, OUT_SCENE)
	print("mundo guardado: %s (%d piezas)" % [error_string(error), _props.find_children("*", "Node3D", true, false).filter(func(n): return n.get_script() == PROP_SCRIPT).size()])


func _set_owner(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		# Lo de adentro de los modelos importados no se guarda: viene del archivo.
		if child.scene_file_path.is_empty():
			_set_owner(child, owner_node)


# --- Muralla de la aldea ------------------------------------------------------

## Cuadrado de muros con torres redondas en las esquinas y un porton donde
## cada camino cruza la muralla (los guardias se paran ahi).
func _build_village_wall(village: Node3D) -> void:
	var wall := _node("Muralla", village)
	var center := Vector2(VILLAGE.x, VILLAGE.y)
	var corners: Array[Vector2] = [center + Vector2(-WALL_HALF, -WALL_HALF), center + Vector2(WALL_HALF, -WALL_HALF),
			center + Vector2(WALL_HALF, WALL_HALF), center + Vector2(-WALL_HALF, WALL_HALF)]
	for corner in corners:
		_wall_piece(wall, "modular_fort_01_tower_round", corner, Vector2.DOWN, 75.0)
	var tower_radius: float = 15.84 * 75.0 * 0.45
	for side in 4:
		var start: Vector2 = corners[side]
		var finish: Vector2 = corners[(side + 1) % 4]
		var along: Vector2 = (finish - start).normalized()
		var outward: Vector2 = ((start + finish) / 2.0 - center).normalized()
		var length: float = start.distance_to(finish)
		# Donde lo cruzan los caminos (distancia desde start).
		var gate_spots: Array[float] = []
		for path in _paths:
			for i in path.size() - 1:
				var hit: Variant = Geometry2D.segment_intersects_segment(start, finish, path[i], path[i + 1])
				if hit != null:
					gate_spots.append(start.distance_to(hit))
		gate_spots.sort()
		var free_from: float = tower_radius
		for spot in gate_spots:
			_wall_run(wall, start, along, free_from, spot - GATE_LENGTH / 2.0, true)
			var gate_center: Vector2 = start + along * spot
			_wall_piece(wall, "modular_fort_01_wall_thin_gate_01", gate_center, along, 100.0, GATE_STRETCH)
			_gates.append({"center": gate_center, "along": along, "normal": outward})
			free_from = spot + GATE_LENGTH / 2.0
		_wall_run(wall, start, along, free_from, length - tower_radius, false)


## Largo de las piezas del fuerte (escala 100): el porton y la pared corta
## miden 741, la pared larga 1482. Los portones van estirados a lo largo para
## que el paso sea mas ancho (con 741 quedaba de un metro y poco).
const GATE_PIECE_LENGTH: float = 741.0
const GATE_STRETCH: float = 1.5
const GATE_LENGTH: float = GATE_PIECE_LENGTH * GATE_STRETCH
const WALL_LENGTH: float = 1482.0
const SHORT_WALL_LENGTH: float = 741.0
const WALL_THICKNESS: float = 235.0
const WALL_HEIGHT: float = 860.0


# Muro recto entre dos distancias del lado. Las piezas entran justas, una al
# lado de la otra y un poco estiradas o achicadas a lo largo: si se pisaran,
# las caras quedarian en el mismo plano y parpadearian. Se elige entre la
# pieza larga y la corta la que menos tenga que estirarse. La colision es una
# sola caja por tramo (las cajas de cada pieza dejaban rendijas entre si).
func _wall_run(parent: Node3D, start: Vector2, along: Vector2, from: float, to: float, gate_at_end: bool) -> void:
	var length: float = to - from
	if length < 60.0:
		return
	_wall_collider(parent, start + along * (from + to) / 2.0, along, length + 40.0)
	if length < SHORT_WALL_LENGTH * 0.7:
		# Muy corto: una pieza corta pegada al porton (lo que sobra se mete en la torre).
		var middle: float = to - SHORT_WALL_LENGTH / 2.0 if gate_at_end else from + SHORT_WALL_LENGTH / 2.0
		_wall_piece(parent, "modular_fort_01_wall_thin_straight_04", start + along * middle, along, 100.0, 1.0, false)
		return
	var best_piece: String = ""
	var best_length: float = 0.0
	var best_count: int = 0
	var best_error: float = INF
	for option in [["modular_fort_01_wall_thin_straight_01", WALL_LENGTH], ["modular_fort_01_wall_thin_straight_04", SHORT_WALL_LENGTH]]:
		var count: int = maxi(1, roundi(length / option[1]))
		var error: float = absf(length / (count * option[1]) - 1.0)
		if error < best_error - 0.02:
			best_error = error
			best_piece = option[0]
			best_length = option[1]
			best_count = count
	var stretch: float = length / (best_count * best_length)
	for i in best_count:
		var middle: float = from + best_length * stretch * (i + 0.5)
		_wall_piece(parent, best_piece, start + along * middle, along, 100.0, stretch, false)


func _wall_collider(parent: Node3D, center: Vector2, along: Vector2, length: float) -> void:
	var body := StaticBody3D.new()
	body.name = "ColisionMuro"
	body.transform = Transform3D(Basis(Vector3.UP, atan2(along.x, along.y)), Vector3(center.x, WALL_HEIGHT / 2.0, center.y))
	parent.add_child(body, true)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(WALL_THICKNESS, WALL_HEIGHT, length)
	shape.shape = box
	body.add_child(shape)
	var wall_box: Dictionary = _box(center, atan2(along.x, along.y), Vector2(WALL_THICKNESS / 2.0, length / 2.0))
	_boxes.append(wall_box)
	_tall.append(wall_box)


## Pieza del fuerte con el centro de su caja en center y su largo (eje z del
## modelo) a lo largo de along, estirado stretch veces.
func _wall_piece(parent: Node3D, piece: String, center: Vector2, along: Vector2, scale: float, stretch: float = 1.0, collide: bool = true) -> void:
	var angle: float = atan2(along.x, along.y)
	var prop: Node3D = _fort_piece(parent, piece, Vector3(center.x, 0, center.y), angle, scale, collide, false)
	if stretch != 1.0:
		prop.scale = Vector3(scale, scale, scale * stretch)


# --- Agua: rios, mar, charcos y puentes ---------------------------------------

func _build_water() -> void:
	var water := _node("Agua", _root)
	var river_material := ShaderMaterial.new()
	river_material.shader = load(WATER_SHADER)
	var segments := PackedVector2Array()
	for line in _river_lines:
		_river(water, line, river_material)
		var points: PackedVector2Array = line.points
		for i in points.size() - 1:
			segments.append(points[i])
			segments.append(points[i + 1])
	var shore := _build_sea(water)
	_build_pools(water)
	var sounds := Node3D.new()
	sounds.name = "SonidoDelAgua"
	sounds.set_script(load(WATER_SOUNDS_SCRIPT))
	sounds.river_segments = segments
	sounds.shore = shore
	water.add_child(sounds)


func _river(parent: Node3D, line: Dictionary, material: ShaderMaterial) -> void:
	var points: PackedVector2Array = line.points
	var widths: PackedFloat32Array = line.widths
	var river := _node(line.name, parent)
	# Puentes donde la cruzan los caminos.
	var crossings: Array = []
	for i in points.size() - 1:
		for path in _paths:
			for k in path.size() - 1:
				var hit: Variant = Geometry2D.segment_intersects_segment(points[i], points[i + 1], path[k], path[k + 1])
				if hit != null:
					var dir: Vector2 = (path[k + 1] - path[k]).normalized()
					var length: float = widths[i] / absf(dir.dot((points[i + 1] - points[i]).normalized().orthogonal())) + 520.0
					crossings.append({"center": hit, "dir": dir, "length": minf(length, widths[i] * 2.5)})
	for crossing in crossings:
		_bridges.append(crossing)
		_bridge(river, crossing.center, crossing.dir, crossing.length)
		_occupied.append(Vector3(crossing.center.x, crossing.center.y, crossing.length * 0.6))

	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var travelled: float = 0.0
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	var v := PackedFloat32Array()
	for i in points.size():
		var before: Vector2 = points[maxi(i - 1, 0)]
		var after: Vector2 = points[mini(i + 1, points.size() - 1)]
		var side: Vector2 = (after - before).normalized().orthogonal()
		if i > 0:
			travelled += points[i].distance_to(points[i - 1])
		left.append(Vector3(points[i].x + side.x * widths[i] / 2.0, WATER_Y, points[i].y + side.y * widths[i] / 2.0))
		right.append(Vector3(points[i].x - side.x * widths[i] / 2.0, WATER_Y, points[i].y - side.y * widths[i] / 2.0))
		v.append(travelled / 700.0)
	for i in points.size() - 1:
		_quad(tool, left[i], right[i], left[i + 1], right[i + 1], Vector2(0, v[i]), Vector2(1, v[i]), Vector2(0, v[i + 1]), Vector2(1, v[i + 1]))
	_water_mesh(river, tool, material)

	# Colision del cauce: cajas por tramo, menos donde estan los puentes.
	var body := StaticBody3D.new()
	body.name = "Cauce"
	river.add_child(body)
	for i in points.size() - 1:
		var width: float = (widths[i] + widths[i + 1]) / 2.0 * 0.82
		var middle: Vector2 = (points[i] + points[i + 1]) / 2.0
		var near_bridge: bool = crossings.any(func(crossing: Dictionary) -> bool: return middle.distance_to(crossing.center) < 900.0)
		var pieces: int = ceili(points[i].distance_to(points[i + 1]) / 40.0) if near_bridge else 1
		for k in pieces:
			var a: Vector2 = points[i].lerp(points[i + 1], float(k) / pieces)
			var b: Vector2 = points[i].lerp(points[i + 1], float(k + 1) / pieces)
			var center: Vector2 = (a + b) / 2.0
			if near_bridge and crossings.any(func(crossing: Dictionary) -> bool: return _on_deck(center, crossing)):
				continue
			var segment: Vector2 = b - a
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(width, 400.0, segment.length() + (10.0 if near_bridge else 40.0))
			shape.shape = box
			shape.transform = Transform3D(Basis(Vector3.UP, atan2(segment.x, segment.y)), Vector3(center.x, 200.0, center.y))
			body.add_child(shape)


# Sobre el pasillo de un puente (entre las barandas y a lo largo del tablero).
func _on_deck(point: Vector2, crossing: Dictionary) -> bool:
	var offset: Vector2 = point - crossing.center
	return absf(offset.dot(crossing.dir.orthogonal())) < BRIDGE_WIDTH / 2.0 + 25.0 and absf(offset.dot(crossing.dir)) < crossing.length / 2.0


const WATER_Y: float = 4.0


func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, ua: Vector2, ub: Vector2, uc: Vector2, ud: Vector2) -> void:
	for vertex in [[a, ua], [b, ub], [c, uc], [b, ub], [d, ud], [c, uc]]:
		tool.set_normal(Vector3.UP)
		tool.set_uv(vertex[1])
		tool.add_vertex(vertex[0])


func _water_mesh(parent: Node3D, tool: SurfaceTool, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = "Agua"
	mesh.mesh = tool.commit()
	mesh.material_override = material
	mesh.layers = 1 | PROP_SCRIPT.MAP_LAYER
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
	return mesh


## El mar del este: una franja ancha desde la orilla hasta mas alla del
## borde, con colision a lo largo de la orilla. Devuelve los puntos de la
## orilla (para el sonido de las olas).
func _build_sea(parent: Node3D) -> PackedVector2Array:
	var sea := _node("Mar", parent)
	var material := ShaderMaterial.new()
	material.shader = load(WATER_SHADER)
	material.set_shader_parameter("deep_color", Color(0.05, 0.18, 0.27))
	material.set_shader_parameter("shallow_color", Color(0.14, 0.36, 0.42))
	material.set_shader_parameter("foam_both_sides", false)
	material.set_shader_parameter("foam_width", 0.025)
	material.set_shader_parameter("wave_strength", 1.6)
	material.set_shader_parameter("flow_speed", 0.12)
	var shore := PackedVector2Array()
	var z: float = -HALF - 2000.0
	while z <= HALF + 2000.0:
		shore.append(Vector2(_shore_x(z), z))
		z += 400.0
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var far: float = HALF + 6000.0
	for i in shore.size() - 1:
		var a := Vector3(shore[i].x, WATER_Y, shore[i].y)
		var c := Vector3(shore[i + 1].x, WATER_Y, shore[i + 1].y)
		_quad(tool, a, Vector3(far, WATER_Y, shore[i].y), c, Vector3(far, WATER_Y, shore[i + 1].y),
				Vector2(0, shore[i].y / 700.0), Vector2(1, shore[i].y / 700.0), Vector2(0, shore[i + 1].y / 700.0), Vector2(1, shore[i + 1].y / 700.0))
	_water_mesh(sea, tool, material)
	var body := StaticBody3D.new()
	body.name = "Orilla"
	sea.add_child(body)
	for i in shore.size() - 1:
		var segment: Vector2 = shore[i + 1] - shore[i]
		var middle: Vector2 = (shore[i] + shore[i + 1]) / 2.0
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(900.0, 400.0, segment.length() + 40.0)
		shape.shape = box
		shape.transform = Transform3D(Basis(Vector3.UP, atan2(segment.x, segment.y)), Vector3(middle.x + 500.0, 200.0, middle.y))
		body.add_child(shape)
	return shore


## Charcos del pantano: manchas de agua con colision (no se pueden pisar).
func _build_pools(parent: Node3D) -> void:
	var pools := _node("Charcos", parent)
	var material := ShaderMaterial.new()
	material.shader = load(WATER_SHADER)
	material.set_shader_parameter("deep_color", Color(0.08, 0.12, 0.07))
	material.set_shader_parameter("shallow_color", Color(0.2, 0.25, 0.13))
	material.set_shader_parameter("foam_color", Color(0.45, 0.5, 0.32))
	material.set_shader_parameter("flow_speed", 0.04)
	material.set_shader_parameter("wave_strength", 0.4)
	var body := StaticBody3D.new()
	body.name = "Colision"
	pools.add_child(body)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var placed: int = 0
	var tries: int = 0
	while placed < 16 and tries < 600:
		tries += 1
		var angle: float = _rng.randf() * TAU
		var dist: float = sqrt(_rng.randf()) * SWAMP.z * 0.85
		var center := Vector2(SWAMP.x, SWAMP.y) + Vector2(cos(angle), sin(angle)) * dist
		var radius: float = _rng.randf_range(260.0, 620.0)
		if _distance_to_paths(center) < PATH_WIDTH + radius + 120.0 or _distance_to_rivers(center) < radius + 200.0 or not _is_free(center, radius + 150.0):
			continue
		_pools.append(Vector3(center.x, center.y, radius))
		_occupied.append(Vector3(center.x, center.y, radius + 60.0))
		var ring: int = 22
		var rim := PackedVector3Array()
		for k in ring:
			var a: float = TAU * k / ring
			var r: float = radius * (1.0 + 0.22 * _noise.get_noise_2d(center.x + cos(a) * 300.0, center.y + sin(a) * 300.0) * 2.0)
			rim.append(Vector3(center.x + cos(a) * r, WATER_Y, center.y + sin(a) * r))
		var middle := Vector3(center.x, WATER_Y, center.y)
		for k in ring:
			_quad(tool, rim[k], middle, rim[(k + 1) % ring], middle, Vector2(0, k), Vector2(0.5, k), Vector2(0, k + 1), Vector2(0.5, k + 1))
		var shape := CollisionShape3D.new()
		var cylinder := CylinderShape3D.new()
		cylinder.radius = radius * 0.78
		cylinder.height = 400.0
		shape.shape = cylinder
		shape.position = Vector3(center.x, 200.0, center.y)
		body.add_child(shape)
		placed += 1
	_water_mesh(pools, tool, material)


## Puente de tablones sobre el rio, a lo largo del camino (dir). El piso de
## abajo es el mismo (el mundo es plano): el cauce no tiene colision en el
## ancho del puente y las barandas no dejan bajar al agua.
func _bridge(parent: Node3D, center: Vector2, dir: Vector2, length: float) -> void:
	var bridge := Node3D.new()
	bridge.name = "Puente"
	bridge.transform = Transform3D(Basis(Vector3.UP, atan2(dir.x, dir.y)), Vector3(center.x, 0, center.y))
	parent.add_child(bridge, true)
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = load(P + "wooden_crate_01/textures/wooden_crate_01_diff_1k.jpg")
	wood.albedo_color = Color(0.9, 0.82, 0.74)
	wood.roughness = 0.9
	wood.uv1_scale = Vector3(0.6, 0.6, 0.6)
	var plank := BoxMesh.new()
	plank.size = Vector3(BRIDGE_WIDTH, 10.0, 54.0)
	plank.material = wood
	var planks := MultiMesh.new()
	planks.transform_format = MultiMesh.TRANSFORM_3D
	planks.mesh = plank
	var count: int = int(length / 62.0)
	planks.instance_count = count
	for i in count:
		var z: float = -length / 2.0 + 31.0 + i * 62.0
		var t: float = z / (length / 2.0)
		var rot := Basis(Vector3.UP, _rng.randf_range(-0.03, 0.03))
		planks.set_instance_transform(i, Transform3D(rot, Vector3(_rng.randf_range(-8.0, 8.0), 6.0 + 8.0 * (1.0 - t * t), z)))
	var deck := MultiMeshInstance3D.new()
	deck.name = "Tablones"
	deck.multimesh = planks
	deck.layers = 1 | PROP_SCRIPT.MAP_LAYER
	bridge.add_child(deck)
	# Postes y barandas a los dos costados.
	var post := CylinderMesh.new()
	post.top_radius = 14.0
	post.bottom_radius = 16.0
	post.height = 160.0
	post.radial_segments = 6
	post.material = wood
	var rail := BoxMesh.new()
	rail.size = Vector3(14.0, 14.0, length)
	rail.material = wood
	var body := StaticBody3D.new()
	body.name = "Barandas"
	bridge.add_child(body)
	for side in [-1.0, 1.0]:
		var x: float = side * (BRIDGE_WIDTH / 2.0 + 10.0)
		var posts: int = maxi(2, int(length / 280.0) + 1)
		for i in posts:
			var z: float = lerpf(-length / 2.0 + 20.0, length / 2.0 - 20.0, float(i) / (posts - 1))
			var mesh := MeshInstance3D.new()
			mesh.mesh = post
			mesh.position = Vector3(x, 80.0, z)
			mesh.layers = 1 | PROP_SCRIPT.MAP_LAYER
			bridge.add_child(mesh)
		for height in [70.0, 140.0]:
			var mesh := MeshInstance3D.new()
			mesh.mesh = rail
			mesh.position = Vector3(x, height, 0.0)
			bridge.add_child(mesh)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(40.0, 300.0, length + 120.0)
		shape.shape = box
		shape.position = Vector3(x + side * 20.0, 150.0, 0.0)
		body.add_child(shape)


# --- Regiones de afuera ---------------------------------------------------------

func _build_swamp() -> void:
	var swamp := _node("Pantano", _props)
	# Una choza hundida (antes que los arboles, que se acomodan alrededor) y
	# luces fatuas de noche.
	var hut := _find_free(Vector2(SWAMP.x - 900, SWAMP.y + 700), 500.0)
	if hut.is_finite():
		_prop(swamp, C + "casa_c.glb", Vector3(hut.x, -60, hut.y), 0.9, 215.0, 0.42, {"style": PROP_SCRIPT.Style.TINT, "tint": Color(0.5, 0.52, 0.42), "fade_when_occluding": true}, true)
	_vegetation.append(_scatter.bind(swamp, SWAMP, 0.0, SWAMP.z, 110, _swamp_tree))
	_vegetation.append(_scatter.bind(swamp, SWAMP, 0.0, SWAMP.z, 90, _swamp_plant))
	_vegetation.append(_scatter.bind(swamp, SWAMP, 0.0, SWAMP.z, 25, _stump))
	_vegetation.append(_scatter.bind(swamp, SWAMP, 0.0, SWAMP.z, 18, _rock))
	for i in 5:
		var spot := _find_free(Vector2(SWAMP.x, SWAMP.y) + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(600.0, SWAMP.z * 0.8), 40.0)
		if spot.is_finite():
			_night_light(swamp, Vector3(spot.x, 120.0, spot.y), {"energy": 0.7, "color": Color(0.55, 1.0, 0.6), "light_range": 700.0, "glow_size": 60.0})


func _swamp_tree(parent: Node3D, pos: Vector3) -> void:
	if _rng.randf() < 0.45:
		_tree(parent, WILLOWS, pos, WILLOW_SCALE, SWAMP_TINT * 0.95)
	else:
		_tree(parent, DEAD_TREES, pos, DEAD_SCALE, Color(0.5, 0.55, 0.45))


func _swamp_plant(parent: Node3D, pos: Vector3) -> void:
	var paths: Array = FERNS if _rng.randf() < 0.5 else BUSHES
	var size: Vector2 = FERN_SCALE if paths == FERNS else BUSH_SCALE
	_prop(parent, paths.pick_random(), pos, _rng.randf() * TAU, _rng.randf_range(size.x, size.y), 0.0, {"style": PROP_SCRIPT.Style.TINT, "tint": SWAMP_TINT})


func _build_mountain() -> void:
	var mountain := _node("Montaña", _props)
	# Riscos: rocas enormes alrededor, menos por donde entra el camino (sur).
	for i in 22:
		var angle: float = TAU * i / 22.0 + _rng.randf_range(-0.08, 0.08)
		if absf(wrapf(angle - PI * 0.5, -PI, PI)) < 0.35:
			continue
		var pos := Vector2(MOUNTAIN.x, MOUNTAIN.y) + Vector2.from_angle(angle) * MOUNTAIN.z * _rng.randf_range(0.88, 1.05)
		if _distance_to_paths(pos) < PATH_WIDTH + 700.0 or _distance_to_rivers(pos) < 900.0 or not _is_free(pos, 500.0):
			continue
		_prop(mountain, BOULDERS[_rng.randi() % 2], Vector3(pos.x, 0, pos.y), _rng.randf() * TAU, _rng.randf_range(2600.0, 4200.0), 0.38, {"style": PROP_SCRIPT.Style.TINT, "tint": Color(0.86, 0.9, 0.98)})
	# Atalaya en ruinas en la cima (antes que los pinos).
	var tower := _find_free(Vector2(MOUNTAIN.x + 700, MOUNTAIN.y - 1300), 700.0)
	if tower.is_finite():
		_fort_piece(mountain, "modular_fort_01_tower_round", Vector3(tower.x, 0, tower.y), 0.4, 70.0)
		_night_light(mountain, Vector3(tower.x, 600.0, tower.y), {"flames": true, "energy": 1.1, "light_range": 1100.0, "glow_size": 140.0})
	_vegetation.append(_scatter.bind(mountain, MOUNTAIN, 0.0, MOUNTAIN.z, 150, _snowy_pine))
	_vegetation.append(_scatter.bind(mountain, MOUNTAIN, 0.0, MOUNTAIN.z, 45, _snowy_rock))
	_vegetation.append(_scatter.bind(mountain, MOUNTAIN, 0.0, MOUNTAIN.z, 12, _dead_tree))


func _snowy_pine(parent: Node3D, pos: Vector3) -> void:
	_tree(parent, SNOW_FIRS, pos, FIR_SCALE, Color.WHITE)


func _snowy_rock(parent: Node3D, pos: Vector3) -> void:
	var piece: String = ROCK_PIECES[_rng.randi() % ROCK_PIECES.size()]
	_prop(parent, ROCK_SET, pos, _rng.randf() * TAU, _rng.randf_range(110.0, 200.0), 0.38, {"keep_only": piece, "center": true, "sink": ROCK_SINK, "style": PROP_SCRIPT.Style.TINT, "tint": Color(0.92, 0.95, 1.0)})


func _build_coast() -> void:
	var coast := _node("Costa", _props)
	# Faro (una torre con fuego arriba) en una punta de la costa.
	var light := _find_free(Vector2(_shore_x(-3600) - 800.0, -3600), 600.0)
	if light.is_finite():
		_fort_piece(coast, "modular_fort_01_tower_round", Vector3(light.x, 0, light.y), 0.0, 75.0)
		_night_light(coast, Vector3(light.x, 1050.0, light.y), {"flames": true, "energy": 1.6, "light_range": 1500.0, "glow_size": 220.0})
	# El barco naufragado, varado en la arena, y al lado los restos que se
	# salvaron: un campamento con cajones y una fogata.
	var hull := _find_free(Vector2(_shore_x(-1900) - 1100.0, -1900), 1000.0)
	if hull.is_finite():
		_prop(coast, C + "naufragio.glb", Vector3(hull.x, -40, hull.y), 0.25, 150.0, 0.4, {"style": PROP_SCRIPT.Style.TINT, "tint": Color(0.82, 0.78, 0.72), "fade_when_occluding": true}, true)
	var wreck := _find_free(Vector2(_shore_x(-2900) - 900.0, -2900), 300.0)
	if wreck.is_finite():
		_camp(coast, Vector3(wreck.x, 0, wreck.y), 7)
		var fire := _find_free(wreck + Vector2(420, 0), 120.0)
		if fire.is_finite():
			_prop(coast, P + "stone_fire_pit/stone_fire_pit_1k.gltf", Vector3(fire.x, 0, fire.y), 0.0, 300.0, 0.45, {"is_fire": true, "fire_height": 80.0})
	_vegetation.append(_scatter.bind(coast, COAST, 0.0, COAST.z, 60, _meadow_tree))
	_vegetation.append(_scatter.bind(coast, COAST, 0.0, COAST.z, 50, _shrub))
	_vegetation.append(_scatter.bind(coast, COAST, 0.0, COAST.z, 35, _rock))
	_vegetation.append(_beach.bind(coast))


# En la playa: rocas grandes y troncos secos que trajo el mar, a lo largo de
# toda la orilla.
func _beach(coast: Node3D) -> void:
	for i in 70:
		var z: float = _rng.randf_range(-WALK_LIMIT + 400.0, WALK_LIMIT - 400.0)
		var x: float = _shore_x(z) - _rng.randf_range(450.0, 1500.0)
		var point := Vector2(x, z)
		if _distance_to_paths(point) < PATH_WIDTH + 200.0 or _distance_to_rivers(point) < 500.0 or not _is_free(point, 160.0):
			continue
		_strict = true
		if _rng.randf() < 0.45:
			_prop(coast, BOULDERS[_rng.randi() % 2], Vector3(x, 0, z), _rng.randf() * TAU, _rng.randf_range(700.0, 1300.0), 0.4, {"style": PROP_SCRIPT.Style.TINT, "tint": Color(0.85, 0.82, 0.78)})
		else:
			_prop(coast, DEAD_TREES.pick_random(), Vector3(x, -40, z), _rng.randf() * TAU, _rng.randf_range(80.0, 110.0), 0.0, {"style": PROP_SCRIPT.Style.TINT, "tint": Color(0.82, 0.76, 0.68)}, false, TRUNK_RADIUS)
		_strict = false
		_rejected = false


func _build_desert() -> void:
	var desert := _node("Desierto", _props)
	# Templo enterrado en la arena: muros, columnas, la estatua y vasijas.
	var c := Vector2(DESERT.x + 900, DESERT.y + 900)
	var temple := {"style": PROP_SCRIPT.Style.TINT, "tint": SAND_TINT}
	# Las piezas del kit del cementerio, en piedra (como alla) teñida de arena.
	var temple_stone := {"style": PROP_SCRIPT.Style.STONE, "tint": SAND_TINT}
	_fort_piece(desert, "modular_fort_01_wall_thick_straight_01", Vector3(c.x - 700, -120, c.y - 300), 0.3, 90.0)
	_fort_piece(desert, "modular_fort_01_wall_thick_corner_01", Vector3(c.x + 600, -150, c.y - 700), 1.2, 90.0)
	_fort_piece(desert, "modular_fort_01_wall_thin_gate_01", Vector3(c.x - 100, -80, c.y + 650), PI * 0.5, 95.0)
	for offset in [Vector2(-350, -350), Vector2(350, -350), Vector2(-350, 350), Vector2(350, 350)]:
		if not _is_free(c + offset, 120.0):
			continue
		_prop(desert, G + "column-large.glb", Vector3(c.x + offset.x, -60, c.y + offset.y), 0.0, 420.0, 0.45, temple_stone)
	_statue(desert, Vector3(c.x, 0, c.y), 120.0, temple, Color(0.95, 0.85, 0.66))
	for i in 6:
		var urn := _find_free(c + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(500.0, 900.0), 40.0)
		if urn.is_finite():
			_prop(desert, G + "urn-round.glb", Vector3(urn.x, 0, urn.y), _rng.randf() * TAU, 380.0, 0.4, temple_stone)
	# Mesetas: rocas enormes del color de la arena.
	for i in 14:
		var pos := _find_free(Vector2(DESERT.x, DESERT.y) + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(1200.0, DESERT.z * 1.05), 900.0)
		if pos.is_finite() and _distance_to_paths(pos) > PATH_WIDTH + 900.0:
			_prop(desert, BOULDERS[_rng.randi() % 2], Vector3(pos.x, 0, pos.y), _rng.randf() * TAU, _rng.randf_range(2200.0, 3600.0), 0.38, {"style": PROP_SCRIPT.Style.TINT, "tint": SAND_TINT})
	# Huesos de los que no llegaron, medio tapados por la arena.
	for i in 9:
		var bones := _find_free(Vector2(DESERT.x, DESERT.y) + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(400.0, DESERT.z * 0.9), 60.0)
		if bones.is_finite() and _distance_to_paths(bones) > PATH_WIDTH:
			_prop(desert, C + ("esqueleto_a.glb" if _rng.randf() < 0.6 else "esqueleto_b.glb"), Vector3(bones.x, -4, bones.y), _rng.randf() * TAU, 230.0, 0.0, {"style": PROP_SCRIPT.Style.TINT, "tint": Color(1.0, 0.95, 0.85)})
	_vegetation.append(_scatter.bind(desert, DESERT, 0.0, DESERT.z, 45, _sand_rock))
	_vegetation.append(_scatter.bind(desert, DESERT, 0.0, DESERT.z, 28, _bleached_tree))


func _sand_rock(parent: Node3D, pos: Vector3) -> void:
	if _rng.randf() < 0.6:
		var piece: String = ROCK_PIECES[_rng.randi() % ROCK_PIECES.size()]
		_prop(parent, ROCK_SET, pos, _rng.randf() * TAU, _rng.randf_range(100.0, 190.0), 0.38, {"keep_only": piece, "center": true, "sink": ROCK_SINK, "style": PROP_SCRIPT.Style.TINT, "tint": SAND_TINT})
	else:
		_prop(parent, BOULDERS[_rng.randi() % 2], pos, _rng.randf() * TAU, _rng.randf_range(800.0, 1400.0), 0.4, {"style": PROP_SCRIPT.Style.TINT, "tint": SAND_TINT})


func _bleached_tree(parent: Node3D, pos: Vector3) -> void:
	_tree(parent, DEAD_TREES, pos, DEAD_SCALE * 0.9, Color(0.95, 0.88, 0.78))


# --- Gente de la aldea y eventos del camino -----------------------------------

const GUARD_MODEL := "res://assets/characters/oad/characters/warrior.glb"
## Aldeanos: modelo y color de la ropa (multiplica la textura).
const VILLAGER_LOOKS := [
	["res://assets/characters/oad/characters/merchant.glb", Color(1, 1, 1)],
	["res://assets/characters/oad/characters/priest.glb", Color(0.85, 0.82, 0.75)],
	["res://assets/characters/oad/characters/hunter.glb", Color(1, 1, 1)],
	["res://assets/characters/oad/characters/merchant.glb", Color(0.7, 0.8, 1.0)],
	["res://assets/characters/oad/characters/blacksmith.glb", Color(0.9, 0.8, 0.7)],
	["res://assets/characters/oad/characters/hunter.glb", Color(1.0, 0.85, 0.75)],
	["res://assets/characters/oad/characters/priest.glb", Color(1.0, 1.0, 1.0)],
	["res://assets/characters/oad/characters/merchant.glb", Color(0.85, 1.0, 0.8)],
]
## Lugares de la aldea donde andan los aldeanos de dia (x, z).
const VILLAGE_SPOTS := [Vector2(-100, 380), Vector2(-780, -120), Vector2(260, 50), Vector2(-450, -1000), Vector2(-900, 1250),
		Vector2(800, 1600), Vector2(1700, -250), Vector2(300, -900), Vector2(-1300, -500), Vector2(1100, 600), Vector2(-500, 1700), Vector2(1500, -1500)]


func _build_people() -> void:
	var people := _node("Gente", _root)
	# Dos guardias adentro de cada porton, mirando hacia afuera.
	for gate in _gates:
		for side in [-1.0, 1.0]:
			var spot: Vector2 = gate.center - gate.normal * 320.0 + gate.along * side * 420.0
			var guard := CharacterBody3D.new()
			guard.name = "Guardia"
			guard.set_script(load(GUARD_SCRIPT))
			guard.transform = Transform3D(Basis(Vector3.UP, atan2(gate.normal.x, gate.normal.y)), Vector3(spot.x, 0, spot.y))
			people.add_child(guard, true)
	# Los lugares de paseo que quedaron adentro o pegados a una casa o cerco no sirven.
	var free_spots: Array[Vector2] = []
	for spot in VILLAGE_SPOTS:
		if _boxes.all(func(box: Dictionary) -> bool: return _box_distance(box, spot) > 140.0):
			free_spots.append(spot)
	for i in VILLAGER_LOOKS.size():
		var villager := CharacterBody3D.new()
		villager.name = "Aldeano"
		villager.set_script(load(VILLAGER_SCRIPT))
		# Cada uno vive en una casa (se va a su puerta de noche).
		var door: Vector2 = _house_doors[i % _house_doors.size()]
		villager.model_path = VILLAGER_LOOKS[i][0]
		villager.tint = VILLAGER_LOOKS[i][1]
		villager.home = Vector3(door.x, 0, door.y)
		var spots := PackedVector3Array()
		for k in 3:
			var spot: Vector2 = free_spots[(i * 5 + k * 3) % free_spots.size()]
			spots.append(Vector3(spot.x, 0, spot.y))
		villager.spots = spots
		villager.position = Vector3(door.x, 0, door.y)
		people.add_child(villager, true)


func _build_events() -> void:
	var events := Node3D.new()
	events.name = "EventosDelCamino"
	events.set_script(load(EVENTS_SCRIPT))
	var roads: Array[PackedVector2Array] = []
	for path in _paths:
		roads.append(PackedVector2Array(path))
	events.roads = roads
	var avoid := PackedVector2Array()
	for bridge in _bridges:
		avoid.append(bridge.center)
	events.avoid_points = avoid
	events.village_center = Vector2(VILLAGE.x, VILLAGE.y)
	events.village_half = WALL_HALF + 900.0
	_root.add_child(events)


# --- Lineas suaves ------------------------------------------------------------

## Suaviza una linea (Chaikin) dejando fijos la primera y la ultima punta.
func _smooth(points: PackedVector2Array, passes: int) -> PackedVector2Array:
	for pass_index in passes:
		var result := PackedVector2Array([points[0]])
		for i in points.size() - 1:
			result.append(points[i].lerp(points[i + 1], 0.25))
			result.append(points[i].lerp(points[i + 1], 0.75))
		result.append(points[points.size() - 1])
		points = result
	return points


## Puntos cada step a lo largo de la linea.
func _resample(points: PackedVector2Array, step: float) -> PackedVector2Array:
	var result := PackedVector2Array([points[0]])
	var carry: float = 0.0
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var length: float = a.distance_to(b)
		var t: float = step - carry
		while t <= length:
			result.append(a.lerp(b, t / length))
			t += step
		carry = length - (t - step)
	if result[result.size() - 1].distance_to(points[points.size() - 1]) > step * 0.3:
		result.append(points[points.size() - 1])
	return result
