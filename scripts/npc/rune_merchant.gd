extends "res://scripts/npc/npc.gd"

## Comerciante de runas: cambia una runa de otra clase por una de la clase
## del personaje, a elegir, cobrando un poco de oro. El panel es
## ui/rune_panel.gd.

## Precio del cambio: base mas un tanto por nivel que ya tiene la habilidad pedida.
const BASE_PRICE: int = 60
const PRICE_PER_LEVEL: int = 25


func _ready() -> void:
	super()
	add_to_group("rune_merchants")


## Runas de otras clases que hay en la mochila (una entrada por runa distinta).
static func tradeable_runes() -> Array[Itemdata]:
	var result: Array[Itemdata] = []
	for slot in inventory_data.slots:
		var item: Itemdata = slot.item_data
		if item and item.is_rune() and skill_book.rune_index(item) < 0 and item not in result:
			result.append(item)
	return result


static func price_for(skill_index: int) -> int:
	return BASE_PRICE + PRICE_PER_LEVEL * skill_book.get_level(skill_index)


## Cambia la runa give (de otra clase) por la de la habilidad skill_index de
## la clase. Devuelve el motivo si no se pudo ("" si salio bien).
func exchange(give: Itemdata, skill_index: int) -> String:
	if give == null or not give.is_rune() or skill_book.rune_index(give) >= 0:
		return "Elegí una runa de otra clase"
	var skill: SkillData = skill_book.get_skill(skill_index)
	if skill == null:
		return "Elegí qué runa querés"
	if inventory_data.count_item(give) <= 0:
		return "Ya no tenés esa runa"
	var price: int = price_for(skill_index)
	if player_stats.gold < price:
		return "No te alcanza el oro"
	var wanted: Itemdata = Runes.rune_for(skill.resource_path)
	if wanted == null:
		return "No tengo esa runa"
	inventory_data.remove_item(give, 1)
	if not inventory_data.add_item(wanted, 1):
		inventory_data.add_item(give, 1)
		return "No hay lugar en el inventario"
	player_stats.add_gold(-price)
	return ""
