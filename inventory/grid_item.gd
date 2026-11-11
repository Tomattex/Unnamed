extends Control

## Un item dibujado en la grilla del inventario, del tamaño de su forma:
## fondo con el color de la rareza (rojo si no se cumplen sus requisitos),
## icono y cantidad. Los clics los maneja la grilla (inventory_grid.gd); este
## control solo da el tooltip.

const MISSING_COLOR := Color(0.9, 0.2, 0.15)

var slot_index: int = -1
var slot: Slotdata

var _icon: TextureRect
var _quantity: Label


func setup(index: int, slot_data: Slotdata, cell_size: int) -> void:
	slot_index = index
	slot = slot_data
	mouse_filter = Control.MOUSE_FILTER_PASS
	position = Vector2(slot.grid_pos * cell_size)
	size = Vector2(slot.item_data.get_footprint() * cell_size)
	tooltip_text = " "

	_icon = TextureRect.new()
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.offset_left = 3.0
	_icon.offset_top = 3.0
	_icon.offset_right = -3.0
	_icon.offset_bottom = -3.0
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	refresh_icon()

	if slot.quantity > 1:
		_quantity = Label.new()
		_quantity.text = str(slot.quantity)
		_quantity.add_theme_font_size_override("font_size", 14)
		_quantity.add_theme_constant_override("outline_size", 5)
		_quantity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_quantity.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		_quantity.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_quantity.offset_right = -4.0
		_quantity.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_quantity)


func refresh_icon() -> void:
	var icon: Texture2D = item_icons.get_icon(slot.item_data)
	_icon.texture = icon
	# Los iconos 2D de respaldo son pixel art: sin suavizado.
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if icon == slot.item_data.texture \
			else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS


func _draw() -> void:
	var rect := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	var color: Color = slot.item_data.get_rarity_color()
	var normal: bool = slot.item_data.rarity == Itemdata.Rarity.NORMAL
	if slot.item_data.is_equipment() and not slot.item_data.meets_requirements():
		draw_rect(rect, Color(MISSING_COLOR, 0.3))
	else:
		draw_rect(rect, Color(color, 0.06 if normal else 0.16))
	draw_rect(rect, Color(color, 0.18 if normal else 0.55), false, 1.0)


func _make_custom_tooltip(_for_text: String) -> Object:
	if inventory_data.held != null:
		return null
	if get_parent().get("grid") == inventory_data.stash:
		return ItemTooltip.build(slot.item_data, slot.quantity, "Clic o arrastrar: mover · Clic derecho: a la mochila")
	var item: Itemdata = slot.item_data
	var right_click: String = ""
	if inventory_data.stash_open:
		right_click = "guardar en el baúl"
	elif inventory_data.shop_mode:
		right_click = "vender (%d oro)" % (maxi(1, item.value / 4) * slot.quantity)
	elif item.is_equipment():
		right_click = "equipar"
	elif item.is_rune():
		right_click = "leer la runa"
	elif item.is_health_potion():
		right_click = "beber (o Q)"
	elif item.is_consumable():
		var key: int = inventory_data.belt.find(item.resource_path)
		right_click = "usar" + (" (o %s)" % ["W", "E", "R", "T"][key] if key >= 0 else "")
	var parts := PackedStringArray(["Clic o arrastrar: mover"])
	if not right_click.is_empty():
		parts.append("Clic derecho: " + right_click)
	if item.is_consumable() and not item.is_health_potion():
		parts.append("W E R T: al cinturón")
	parts.append("Soltar fuera de la ventana: tirar")
	return ItemTooltip.build(item, slot.quantity, " · ".join(parts))
