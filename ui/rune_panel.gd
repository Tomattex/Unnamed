extends Control

## Panel del comerciante de runas (scripts/npc/rune_merchant.gd): a la
## izquierda las runas de otras clases que hay en la mochila, a la derecha
## las habilidades de la clase; se elige una de cada lado y se cambia por oro.

const ICON_SIZE := Vector2(40, 40)
const GOLD := Color(0.95, 0.8, 0.48)
const DIM := Color(0.6, 0.55, 0.46)

var merchant: Node3D = null
var _give: VBoxContainer
var _want: VBoxContainer
var _price: Label
var _trade: Button
var _message: Label
var _gold: Label
var _give_item: Itemdata = null
var _want_index: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("pause_panels")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 480)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "RUNISTA"
	title.theme_type_variation = &"HeaderLabel"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var hint := Label.new()
	hint.text = "Esc: cerrar"
	hint.theme_type_variation = &"DimLabel"
	header.add_child(hint)
	box.add_child(header)

	var info := Label.new()
	info.text = "Las runas de otras clases no te sirven, pero a mí sí: te las cambio por una de las tuyas."
	info.theme_type_variation = &"DimLabel"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(columns)
	_give = _column(columns, "Tu runa de otra clase")
	_want = _column(columns, "La runa que querés")

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 12)
	_price = Label.new()
	_price.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_price.add_theme_color_override("font_color", GOLD)
	bottom.add_child(_price)
	_trade = Button.new()
	_trade.text = "Cambiar"
	_trade.custom_minimum_size = Vector2(170, 40)
	_trade.pressed.connect(_on_trade)
	bottom.add_child(_trade)
	box.add_child(bottom)

	_message = Label.new()
	_message.add_theme_color_override("font_color", Color(0.95, 0.35, 0.3))
	box.add_child(_message)
	_gold = Label.new()
	_gold.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_gold.add_theme_font_size_override("font_size", 18)
	_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_gold)
	_connect_merchants.call_deferred()


func _column(parent: HBoxContainer, title_text: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	var title := Label.new()
	title.text = title_text
	title.add_theme_color_override("font_color", GOLD)
	column.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	parent.add_child(column)
	return list


func _connect_merchants() -> void:
	for npc in get_tree().get_nodes_in_group("rune_merchants"):
		if not npc.interacted.is_connected(open_for):
			npc.interacted.connect(open_for)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open_for(new_merchant: Node3D) -> void:
	merchant = new_merchant
	_give_item = null
	_want_index = -1
	_message.text = ""
	visible = true
	sfx.play("page")
	_refresh()
	_update_pause()


func close() -> void:
	visible = false
	sfx.play("page")
	_update_pause()


func _refresh() -> void:
	for child in _give.get_children() + _want.get_children():
		child.queue_free()
	var runes: Array[Itemdata] = merchant.tradeable_runes() if merchant else []
	if _give_item not in runes:
		_give_item = runes[0] if not runes.is_empty() else null
	if runes.is_empty():
		var none := Label.new()
		none.text = "No tenés runas de otras clases."
		none.theme_type_variation = &"DimLabel"
		_give.add_child(none)
	var group := ButtonGroup.new()
	for rune in runes:
		var count: int = inventory_data.count_item(rune)
		var button := _choice(_give, group, rune.texture, "%s%s" % [rune.name.trim_prefix("Runa: "), " x%d" % count if count > 1 else ""],
				PlayerClasses.name_of(rune.rune_class()))
		button.button_pressed = rune == _give_item
		button.pressed.connect(func() -> void:
			_give_item = rune
			_refresh())
	var want_group := ButtonGroup.new()
	for i in skill_book.skills.size():
		var skill: SkillData = skill_book.get_skill(i)
		var level: int = skill_book.get_level(i)
		var button := _choice(_want, want_group, Runes.rune_for(skill.resource_path).texture, skill.name,
				"Nivel %d" % level if level > 0 else "Sin aprender")
		button.button_pressed = i == _want_index
		button.pressed.connect(func() -> void:
			_want_index = i
			_refresh())
	var can_trade: bool = _give_item != null and _want_index >= 0
	var price: int = merchant.price_for(_want_index) if can_trade else 0
	_price.text = "Precio del cambio: %d oro" % price if can_trade else "Elegí una runa de cada lado."
	_trade.disabled = not can_trade or player_stats.gold < price
	_gold.text = "%d de oro" % player_stats.gold


# Boton con icono, nombre y una linea chica (seleccionable dentro del grupo).
func _choice(parent: VBoxContainer, group: ButtonGroup, icon: Texture2D, title: String, detail: String) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.button_group = group
	button.custom_minimum_size = Vector2(0, 50)
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.icon = icon
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", int(ICON_SIZE.x))
	button.text = "%s\n%s" % [title, detail]
	parent.add_child(button)
	return button


func _on_trade() -> void:
	var problem: String = merchant.exchange(_give_item, _want_index)
	_message.text = problem
	sfx.play("coins" if problem.is_empty() else "stuck")
	if problem.is_empty():
		_message.add_theme_color_override("font_color", Color(0.55, 0.85, 0.5))
		_message.text = "Listo: ahora tenés la runa de %s" % skill_book.get_skill(_want_index).name
	else:
		_message.add_theme_color_override("font_color", Color(0.95, 0.35, 0.3))
	_refresh()


func _update_pause() -> void:
	get_tree().paused = get_tree().get_nodes_in_group("pause_panels").any(
		func(panel: Control) -> bool: return panel.visible)
