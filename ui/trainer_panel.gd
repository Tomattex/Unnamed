extends Control

## Panel de los entrenadores de la aldea (scripts/npc/trainer.gd): las
## pasivas de su rama, con el nivel que tiene el personaje, lo que da el
## siguiente y el precio. Las que todavia no sabe se eligen en Pasivas (P).

const ICON_SIZE := Vector2(44, 44)
const GOLD := Color(0.95, 0.8, 0.48)
const TEXT := Color(0.88, 0.82, 0.68)
const DIM := Color(0.6, 0.55, 0.46)

var trainer: Node3D = null
var _title: Label
var _list: VBoxContainer
var _message: Label
var _gold: Label


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
	panel.custom_minimum_size = Vector2(700, 470)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	var header := HBoxContainer.new()
	_title = Label.new()
	_title.theme_type_variation = &"HeaderLabel"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	var hint := Label.new()
	hint.text = "Esc: cerrar"
	hint.theme_type_variation = &"DimLabel"
	header.add_child(hint)
	box.add_child(header)

	var info := Label.new()
	info.text = "Por oro te entreno lo que ya sabés. Ninguna pasiva puede pasar tu nivel."
	info.theme_type_variation = &"DimLabel"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(info)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_list)

	_message = Label.new()
	_message.add_theme_color_override("font_color", Color(0.95, 0.35, 0.3))
	box.add_child(_message)
	_gold = Label.new()
	_gold.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	_gold.add_theme_font_size_override("font_size", 18)
	_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(_gold)

	player_stats.gold_changed.connect(func(_amount: int) -> void:
		if visible:
			_refresh())
	_connect_trainers.call_deferred()


func _connect_trainers() -> void:
	for npc in get_tree().get_nodes_in_group("trainers"):
		if not npc.interacted.is_connected(open_for):
			npc.interacted.connect(open_for)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open_for(new_trainer: Node3D) -> void:
	trainer = new_trainer
	_title.text = trainer.display_name.to_upper()
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
	for child in _list.get_children():
		child.queue_free()
	_gold.text = "%d de oro" % player_stats.gold
	if trainer == null:
		return
	for id in trainer.get_passives():
		var info: Dictionary = Passives.get_info(id)
		var level: int = player_stats.passive_level(id)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var frame := PanelContainer.new()
		frame.theme_type_variation = &"SlotPanel"
		var icon := TextureRect.new()
		icon.texture = load(info.icon)
		icon.custom_minimum_size = ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color.WHITE if level > 0 else Color(0.45, 0.45, 0.45)
		frame.add_child(icon)
		row.add_child(frame)
		var texts := VBoxContainer.new()
		texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		texts.add_theme_constant_override("separation", 0)
		var name_label := Label.new()
		name_label.text = info.name + ("  ·  nivel %d" % level if level > 0 else "")
		name_label.add_theme_color_override("font_color", GOLD if level > 0 else DIM)
		texts.add_child(name_label)
		var detail := Label.new()
		detail.add_theme_font_size_override("font_size", 14)
		detail.add_theme_color_override("font_color", TEXT if level > 0 else DIM)
		detail.text = "Nivel %d: %s" % [level + 1, Passives.describe(id, level + 1)] if level > 0 \
				else "No la sabés: elegila en Pasivas (P) cuando tengas un lugar libre"
		texts.add_child(detail)
		row.add_child(texts)
		if level > 0:
			var price: int = Passives.train_price(level + 1)
			var button := Button.new()
			button.text = "Entrenar · %d oro" % price
			button.custom_minimum_size = Vector2(190, 36)
			button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			var problem: String = player_stats.passive_raise_problem(id)
			button.disabled = not problem.is_empty() or player_stats.gold < price
			button.tooltip_text = problem if not problem.is_empty() else ("No te alcanza el oro" if player_stats.gold < price else "")
			button.pressed.connect(_on_train.bind(id))
			row.add_child(button)
		_list.add_child(row)


func _on_train(id: String) -> void:
	var problem: String = trainer.train(id)
	_message.text = problem
	sfx.play("levelup" if problem.is_empty() else "stuck")
	_refresh()


func _update_pause() -> void:
	get_tree().paused = get_tree().get_nodes_in_group("pause_panels").any(
		func(panel: Control) -> bool: return panel.visible)
