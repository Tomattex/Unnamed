extends "res://scripts/npc/npc.gd"

## Entrenador de la aldea: sube por oro las pasivas que el personaje ya sabe
## (ver scripts/player/passives.gd). Cada uno enseña las de su rama: "armas"
## (el maestro de armas) o "saber" (el sabio). El panel es ui/trainer_panel.gd.

@export_enum("armas", "saber") var teaches: String = "armas"


func _ready() -> void:
	super()
	add_to_group("trainers")


## Pasivas de su rama que la clase del personaje puede tener.
func get_passives() -> Array[String]:
	var result: Array[String] = []
	for id in Passives.available_for(player_stats.class_id):
		if Passives.LIST[id].trainer == teaches:
			result.append(id)
	return result


## Sube la pasiva un nivel cobrando. Devuelve el motivo si no se pudo.
func train(id: String) -> String:
	if id not in get_passives():
		return "Eso no lo enseño yo"
	var problem: String = player_stats.passive_raise_problem(id)
	if not problem.is_empty():
		return problem
	var price: int = Passives.train_price(player_stats.passive_level(id) + 1)
	if player_stats.gold < price:
		return "No te alcanza el oro"
	player_stats.add_gold(-price)
	return player_stats.raise_passive(id, false)
