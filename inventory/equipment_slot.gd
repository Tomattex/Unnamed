extends PanelContainer

## Slot de equipo del inventario (arma, escudo o una parte de la armadura).
## Clic con un item agarrado (o soltarlo encima al arrastrar): lo equipa y
## queda agarrado lo que habia. Clic sin nada: agarra lo equipado (y se puede
## arrastrar manteniendo el clic). Clic derecho: lo pasa a la mochila. Vacio
## muestra el dibujo de lo que va ahi. Con un item agarrado encima se marca
## verde si va ahi y rojo si no.

const ItemDrag := preload("res://inventory/item_drag.gd")
const CELL: int = 40
const FIT_COLOR := Color(0.35, 0.85, 0.35, 0.22)
const BLOCKED_COLOR := Color(0.9, 0.25, 0.2, 0.25)
## El dibujo del lugar vacio: tenue, del color de la madera.
const EMPTY_ICON_COLOR := Color(0.85, 0.75, 0.55, 0.22)

var equip_index: int = -1
var slot_name: String = ""

var _icon: TextureRect
var _empty_icon: TextureRect
var _hover: bool = false


## cells: tamaño en casillas (puede tener decimales); empty_icon: el dibujo
## que se ve mientras no hay nada equipado.
func setup(index: int, cells: Vector2, type_name: String, empty_icon: Texture2D) -> void:
	equip_index = index
	slot_name = type_name
	theme_type_variation = &"SlotPanel"
	custom_minimum_size = cells * CELL
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("item_drop_targets")

	var holder := Control.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	_empty_icon = TextureRect.new()
	_empty_icon.texture = empty_icon
	_empty_icon.modulate = EMPTY_ICON_COLOR
	_empty_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_empty_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_empty_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var inset: float = minf(cells.x, cells.y) * CELL * 0.14
	_empty_icon.offset_left = inset
	_empty_icon.offset_top = inset
	_empty_icon.offset_right = -inset
	_empty_icon.offset_bottom = -inset
	_empty_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_empty_icon)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(_icon)

	mouse_entered.connect(func() -> void:
		_hover = true
		queue_redraw())
	mouse_exited.connect(func() -> void:
		_hover = false
		queue_redraw())
	inventory_data.equipment_changed.connect(update.unbind(1))
	inventory_data.held_changed.connect(queue_redraw)
	item_icons.icon_ready.connect(update.unbind(1))
	player_stats.stats_changed.connect(update)
	update()


func update() -> void:
	var item: Itemdata = inventory_data.get_equipped(equip_index)
	# Vacio, el tooltip comun dice que va ahi.
	tooltip_text = " " if item else slot_name
	_empty_icon.visible = item == null
	_icon.visible = item != null
	if item:
		var icon: Texture2D = item_icons.get_icon(item)
		_icon.texture = icon
		_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if icon == item.texture \
				else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		self_modulate = Color.WHITE.lerp(item.get_rarity_color(), 0.3) if item.rarity != Itemdata.Rarity.NORMAL else Color.WHITE
		# Puesto sin cumplir los requisitos (por ejemplo, de una partida vieja).
		_icon.modulate = Color.WHITE if item.meets_requirements() else Color(1.0, 0.45, 0.4)
	else:
		self_modulate = Color.WHITE
	queue_redraw()


func _process(_delta: float) -> void:
	# Al arrastrar manteniendo el clic no llegan mouse_entered/exited: el
	# marco se decide por la posicion del mouse.
	if inventory_data.held != null and is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	var held: Slotdata = inventory_data.held
	if held == null or not (_hover or get_global_rect().has_point(get_global_mouse_position())):
		return
	var fits: bool = inventory_data.fits_slot(held.item_data, equip_index) and held.item_data.meets_requirements()
	var color: Color = FIT_COLOR if fits else BLOCKED_COLOR
	var rect := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	draw_rect(rect, color)
	draw_rect(rect, Color(color, 0.9), false, 2.0)


func _make_custom_tooltip(_for_text: String) -> Object:
	var item: Itemdata = inventory_data.get_equipped(equip_index)
	if item == null or inventory_data.held != null:
		return null
	return ItemTooltip.build(item, 1, "Clic o arrastrar: mover · Clic derecho: sacar a la mochila", false)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		ItemDrag.motion(event.global_position)
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return
	if not mouse_event.pressed:
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and ItemDrag.release(self, mouse_event.global_position):
			accept_event()
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		var picking: bool = inventory_data.held == null and inventory_data.equipment[equip_index] != null
		if inventory_data.held:
			accept_drop()
		else:
			_pick()
		if picking:
			ItemDrag.begin(mouse_event.global_position)
		accept_event()
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		if inventory_data.held:
			inventory_data.return_held()
		# Clic derecho: desequipa directo a la grilla.
		elif inventory_data.unequip(equip_index):
			sfx.play("drag_weapon")
		accept_event()


## Equipa aca el item agarrado (clic con algo en la mano o fin de un arrastre).
func accept_drop(_position: Vector2 = Vector2.ZERO) -> void:
	var moving: Slotdata = inventory_data.held
	if moving == null:
		return
	inventory_data.on_equipment_clicked(equip_index)
	if inventory_data.held != moving:
		sfx.play_item(moving.item_data)


func _pick() -> void:
	var moving: Slotdata = inventory_data.equipment[equip_index]
	inventory_data.on_equipment_clicked(equip_index)
	if moving:
		sfx.play_item(moving.item_data)
