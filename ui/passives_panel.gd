extends VBoxContainer

## Pasivas, como pestaña de la pantalla de personaje (tecla C): las que tiene
## el personaje con su nivel y efecto, el boton para subirlas con un punto, y
## las que se pueden elegir cuando hay un lugar libre (se abren en los niveles
## de Passives.SLOT_LEVELS). Los entrenadores de la aldea las suben por oro
## (ui/trainer_panel.gd).

const ICON_SIZE := Vector2(38, 38)
const GOLD := Color(0.95, 0.8, 0.48)
const TEXT := Color(0.88, 0.82, 0.68)

var _info: Label
var _known: VBoxContainer
var _choices_title: Label
var _choices: VBoxContainer
var _message: Label


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	_info = Label.new()
	_info.add_theme_color_override("font_color", GOLD)
	_info.add_theme_font_size_override("font_size", 14)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_info)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var lists := VBoxContainer.new()
	lists.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lists.add_theme_constant_override("separation", 6)
	scroll.add_child(lists)
	_known = VBoxContainer.new()
	_known.add_theme_constant_override("separation", 6)
	lists.add_child(_known)
	_choices_title = Label.new()
	_choices_title.add_theme_color_override("font_color", GOLD)
	lists.add_child(_choices_title)
	_choices = VBoxContainer.new()
	_choices.add_theme_constant_override("separation", 6)
	lists.add_child(_choices)

	_message = Label.new()
	_message.add_theme_color_override("font_color", Color(0.95, 0.35, 0.3))
	_message.add_theme_font_size_override("font_size", 13)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_message)

	var footer := Label.new()
	footer.text = "Cada nivel da un punto para subir una pasiva. El Maestro de armas y el Sabio de la aldea también las entrenan, por oro."
	footer.theme_type_variation = &"DimLabel"
	footer.add_theme_font_size_override("font_size", 12)
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(footer)

	player_stats.passives_changed.connect(func() -> void:
		if is_visible_in_tree():
			refresh())
	visibility_changed.connect(func() -> void:
		if is_visible_in_tree():
			_message.text = ""
			refresh())


## Hay algo para hacer (puntos para gastar o una pasiva nueva para elegir).
static func has_pending() -> bool:
	return player_stats.free_passive_slots() > 0 or (player_stats.passive_points > 0 and not player_stats.passives.is_empty())


func refresh() -> void:
	for child in _known.get_children() + _choices.get_children():
		child.queue_free()
	var free_slots: int = player_stats.free_passive_slots()
	var next: int = Passives.next_slot_level(player_stats.level)
	var info: String = "Puntos para subir: %d" % player_stats.passive_points
	if free_slots > 0:
		info += "  ·  Podés elegir %d nueva%s" % [free_slots, "s" if free_slots > 1 else ""]
	elif next > 0:
		info += "  ·  La próxima se elige en el nivel %d" % next
	_info.text = info

	if player_stats.passives.is_empty():
		var none := Label.new()
		none.text = "Todavía no tenés ninguna. La primera se elige en el nivel %d." % Passives.SLOT_LEVELS[0]
		none.theme_type_variation = &"DimLabel"
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_known.add_child(none)
	for id in player_stats.passives:
		var level: int = player_stats.passive_level(id)
		var detail: String = "Nivel %d · %s" % [level, Passives.describe(id, level)]
		if level < Passives.MAX_LEVEL:
			detail += "\nNivel %d: %s" % [level + 1, Passives.describe(id, level + 1)]
		var button := _row(_known, id, detail, "Subir")
		var problem: String = player_stats.passive_raise_problem(id)
		button.disabled = player_stats.passive_points <= 0 or not problem.is_empty()
		button.tooltip_text = problem if not problem.is_empty() else ("No tenés puntos" if player_stats.passive_points <= 0 else "Gasta 1 punto")
		button.pressed.connect(_on_raise.bind(id))

	_choices_title.visible = free_slots > 0
	_choices_title.text = "Elegí una nueva:"
	if free_slots <= 0:
		return
	for id in Passives.available_for(player_stats.class_id):
		if player_stats.passives.has(id):
			continue
		var button := _row(_choices, id, Passives.describe(id, 1), "Aprender")
		button.pressed.connect(_on_learn.bind(id))


# Fila: icono, nombre y detalle, y un boton a la derecha (que se devuelve).
func _row(parent: VBoxContainer, id: String, detail: String, action: String) -> Button:
	var info: Dictionary = Passives.get_info(id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"SlotPanel"
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var icon := TextureRect.new()
	icon.texture = load(info.icon)
	icon.custom_minimum_size = ICON_SIZE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.add_child(icon)
	row.add_child(frame)
	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	var name_label := Label.new()
	name_label.text = info.name
	name_label.add_theme_color_override("font_color", GOLD)
	name_label.add_theme_font_size_override("font_size", 15)
	texts.add_child(name_label)
	var detail_label := Label.new()
	detail_label.text = detail
	detail_label.add_theme_color_override("font_color", TEXT)
	detail_label.add_theme_font_size_override("font_size", 13)
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(detail_label)
	row.add_child(texts)
	var button := Button.new()
	button.text = action
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(84, 30)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(button)
	parent.add_child(row)
	return button


func _on_learn(id: String) -> void:
	_show_result(player_stats.learn_passive(id), "new_skill")


func _on_raise(id: String) -> void:
	_show_result(player_stats.raise_passive(id), "levelup")


func _show_result(problem: String, sound: String) -> void:
	_message.text = problem
	sfx.play(sound if problem.is_empty() else "stuck")
	refresh()
