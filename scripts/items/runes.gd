class_name Runes

## Runas: un item por habilidad (item/items/runas/runa_<habilidad>.tres) que
## al leerlo la enseña o la sube un nivel (skill_book.read_rune). Caen de los
## enemigos y de los cofres, mas seguido las de la clase del personaje; las de
## otras clases se cambian en el comerciante de runas.

const DIR := "res://item/items/runas/"
## Parte de las runas que caen que son de la clase del personaje.
const OWN_CLASS_SHARE: float = 0.7


## Ruta del .tres de la runa de una habilidad (res://skills/<id>.tres).
static func path_for(skill_path: String) -> String:
	return DIR + "runa_" + skill_path.get_file().get_basename() + ".tres"


static func rune_for(skill_path: String) -> Itemdata:
	var path: String = path_for(skill_path)
	return load(path) if ResourceLoader.exists(path) else null


## Una runa al azar: de la clase del personaje la mayoria de las veces.
static func roll() -> Itemdata:
	var own: String = _class_id()
	var pool: Array = []
	if randf() < OWN_CLASS_SHARE:
		pool = PlayerClasses.get_info(own).skills
	else:
		for class_id in PlayerClasses.ORDER:
			if class_id != own:
				pool.append_array(PlayerClasses.get_info(class_id).skills)
	return rune_for(pool.pick_random())


# El personaje se busca en el arbol (Loot se compila antes que los autoloads).
static func _class_id() -> String:
	var tree := Engine.get_main_loop() as SceneTree
	var stats: Node = tree.root.get_node_or_null("player_stats") if tree else null
	return stats.class_id if stats else PlayerClasses.DEFAULT
