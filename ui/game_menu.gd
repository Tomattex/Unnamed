extends PanelContainer

## Menu del juego (Esc sin otro panel abierto): continuar, guardar, cargar,
## partida nueva con eleccion de clase y dificultad, opciones, volver a la
## pantalla de titulo y salir. Sin pantalla de titulo y sin partida guardada
## arranca directo en la partida nueva.
## Se ve como un ARPG clasico: el juego queda atras borroso y oscuro, y el
## panel tiene titulo con adornos, los datos del personaje y de donde esta,
## y botones de tablon con puntas (texturas del RPG GUI kit, ver
## ui/theme/textures/build_textures.gd).

const OptionsPanel := preload("res://ui/options_panel.gd")
const BACKDROP_SHADER := preload("res://ui/theme/menu_backdrop.gdshader")
const GOLD_RULE := preload("res://ui/theme/textures/gold_rule.png")
const TIP_LEFT := preload("res://ui/theme/textures/tip_left.png")
const TIP_RIGHT := preload("res://ui/theme/textures/tip_right.png")
## Nombre de cada zona de music.zone_at (los mismos del mapa).
const REGION_NAMES := {
	"aldea": "Aldea del Vado", "bosque": "Bosque Umbrío", "cementerio": "Camposanto Hundido",
	"ruinas": "Ruinas de Kael", "pradera": "Prados del Sur", "pantano": "Ciénaga de los Ahogados",
	"montana": "Cumbres Heladas", "costa": "Costa de los Naufragios", "desierto": "Mar de Arena",
}
const GOLD := Color(0.95, 0.8, 0.48)
const MENU_WIDTH: float = 440.0
const OPEN_TIME: float = 0.2

var _backdrop: ColorRect
var _backdrop_material: ShaderMaterial
var _open_tween: Tween
## Escala para que el panel entre en la pantalla (1 = tamaño normal).
var _fit: float = 1.0
## Cuanto entro el menu (0 recien abierto, 1 del todo): lo anima un tween y
## _process lo aplica a la escala, la transparencia y el fondo.
var _appear: float = 1.0
var _main_box: VBoxContainer
var _difficulty_box: VBoxContainer
var _options_box: VBoxContainer
var _hero_icon: TextureRect
var _hero_label: Label
var _difficulty_label: Label
var _place_label: Label
var _load_button: Button
var _back_button: Button
var _warning: Label
var _advance_button: Button
var _extreme_check: CheckButton
var _difficulty_buttons: Array[Button] = []
var _difficulty_descriptions: Array[Label] = []
var _class_buttons: Dictionary = {}
var _class_description: Label
var _chosen_class: String = PlayerClasses.DEFAULT
## Primera partida: hay que elegir dificultad (no se puede volver con Esc).
var _choosing_first: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_to_group("pause_panels")
	theme_type_variation = &"OrnatePanel"
	custom_minimum_size = Vector2(MENU_WIDTH, 0)
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	_build_backdrop.call_deferred()
	visibility_changed.connect(_on_visibility_changed)

	var root := VBoxContainer.new()
	add_child(root)
	_main_box = _build_main()
	_difficulty_box = _build_difficulty()
	_options_box = _build_options()
	root.add_child(_main_box)
	root.add_child(_difficulty_box)
	root.add_child(_options_box)
	# Los textos con autoajuste cambian de alto al acomodarse: se recentra.
	minimum_size_changed.connect(_recenter)

	if not save_game.has_save():
		# Unos frames sin pausa para que el HUD de atras termine de dibujarse.
		await get_tree().create_timer(0.1).timeout
		# Con la pantalla de titulo, la partida nueva se elige ahi.
		if get_tree().get_first_node_in_group("title_screen") == null:
			_choosing_first = true
			open_difficulty()


# El fondo (juego borroso) va justo detras del panel, ocupando la pantalla.
func _build_backdrop() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "GameMenuBackdrop"
	_backdrop.process_mode = Node.PROCESS_MODE_ALWAYS
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop_material = ShaderMaterial.new()
	_backdrop_material.shader = BACKDROP_SHADER
	_backdrop_material.set_shader_parameter("amount", 0.0)
	_backdrop.material = _backdrop_material
	_backdrop.visible = visible
	get_parent().add_child(_backdrop)
	get_parent().move_child(_backdrop, get_index())


func _build_main() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.add_child(_title_row("Pausa"))
	box.add_child(_rule())

	# Quien es y donde esta.
	var hero_row := HBoxContainer.new()
	hero_row.alignment = BoxContainer.ALIGNMENT_CENTER
	hero_row.add_theme_constant_override("separation", 8)
	_hero_icon = TextureRect.new()
	_hero_icon.custom_minimum_size = Vector2(26, 26)
	_hero_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hero_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero_row.add_child(_hero_icon)
	_hero_label = Label.new()
	_hero_label.add_theme_font_override("font", get_theme_font("font", &"TitleLabel"))
	_hero_label.add_theme_font_size_override("font_size", 22)
	_hero_label.add_theme_color_override("font_color", Color(0.93, 0.87, 0.74))
	_hero_label.add_theme_constant_override("outline_size", 5)
	hero_row.add_child(_hero_label)
	box.add_child(hero_row)
	_difficulty_label = _centered_label(15)
	box.add_child(_difficulty_label)
	_place_label = _centered_label(15)
	_place_label.add_theme_color_override("font_color", Color(0.8, 0.74, 0.62))
	box.add_child(_place_label)
	box.add_child(_rule())

	var buttons := VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 2)
	buttons.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(buttons)
	_add_button(buttons, "Continuar", close)
	_add_button(buttons, "Guardar partida", func() -> void:
		close()
		save_game.quick_save(), "F5")
	_load_button = _add_button(buttons, "Cargar última partida", func() -> void:
		close()
		save_game.reload_last_save(), "F9")
	# Con la dificultad completada (un campeon en cada region) se puede pasar
	# a la siguiente con el mismo personaje.
	_advance_button = _add_button(buttons, "", func() -> void:
		close()
		save_game.advance_difficulty())
	_add_button(buttons, "Personaje nuevo", open_difficulty)
	_add_button(buttons, "Opciones", _show_options)
	_add_button(buttons, "Menú principal", func() -> void:
		save_game.save()
		TitleScreen.show_on_next_load = true
		get_tree().paused = false
		get_tree().reload_current_scene())
	_add_button(buttons, "Salir del juego", func() -> void:
		save_game.save()
		get_tree().quit())

	box.add_child(_rule())
	var keys := Label.new()
	keys.text = "I inventario · C personaje y pasivas · B bestiario · Tab mapa · N mapa encima
K combo · M montura · Q poción · W E R T cinturón · F juntar"
	keys.theme_type_variation = &"DimLabel"
	keys.add_theme_font_size_override("font_size", 12)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(keys)

	# Atribucion que piden las licencias CC-BY (detalle en el menu principal y CREDITS.md).
	var credits := Label.new()
	credits.text = "Interfaz: Matjaž Lamut (CC-BY 3.0) · Íconos: game-icons.net (CC BY 3.0)"
	credits.theme_type_variation = &"DimLabel"
	credits.add_theme_font_size_override("font_size", 11)
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(credits)
	return box


func _build_difficulty() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.add_child(_title_row("Personaje nuevo", 36))
	box.add_child(_rule())

	var class_info := Label.new()
	class_info.text = "Elegí la clase del personaje:"
	class_info.theme_type_variation = &"DimLabel"
	box.add_child(class_info)
	var class_row := HBoxContainer.new()
	class_row.add_theme_constant_override("separation", 8)
	var group := ButtonGroup.new()
	for class_id in PlayerClasses.ORDER:
		var info_class: Dictionary = PlayerClasses.get_info(class_id)
		var button := _plain_button(class_row, info_class.name, _choose_class.bind(class_id))
		button.toggle_mode = true
		button.button_group = group
		button.icon = load(info_class.icon)
		button.expand_icon = false
		button.add_theme_constant_override("icon_max_width", 22)
		button.add_theme_color_override("icon_normal_color", info_class.color)
		button.add_theme_color_override("icon_pressed_color", info_class.color.lightened(0.3))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_class_buttons[class_id] = button
	box.add_child(class_row)
	_class_description = Label.new()
	_class_description.theme_type_variation = &"DimLabel"
	_class_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_class_description.custom_minimum_size.x = 420
	box.add_child(_class_description)
	_choose_class(_chosen_class)

	var info := Label.new()
	info.text = "Elegí la dificultad. Las siguientes se desbloquean completando la anterior."
	info.theme_type_variation = &"DimLabel"
	box.add_child(info)

	_warning = Label.new()
	_warning.add_theme_color_override("font_color", Color(0.95, 0.35, 0.3))
	_warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warning.custom_minimum_size.x = 420
	box.add_child(_warning)

	_extreme_check = CheckButton.new()
	_extreme_check.text = "Modo extremo: una sola vida (al morir se pierde el personaje)"
	_extreme_check.add_theme_color_override("font_color", Color(0.9, 0.5, 0.4))
	box.add_child(_extreme_check)

	for i in difficulty.LEVELS.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var button := _add_button(row, difficulty.get_level_name(i), _on_difficulty_chosen.bind(i))
		button.custom_minimum_size = Vector2(170, 44)
		button.add_theme_color_override("font_color", difficulty.get_color(i))
		button.add_theme_color_override("font_hover_color", difficulty.get_color(i).lightened(0.3))
		_difficulty_buttons.append(button)
		var description := Label.new()
		_difficulty_descriptions.append(description)
		description.text = difficulty.LEVELS[i].description
		description.theme_type_variation = &"DimLabel"
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(description)
		box.add_child(row)

	box.add_child(_rule())
	_back_button = _add_button(box, "Volver", _show_main)
	_back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return box


func _build_options() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.add_child(_title_row("Opciones", 36))
	box.add_child(_rule())
	box.add_child(OptionsPanel.new())
	var back := _add_button(box, "Volver", _show_main)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return box


func _show_options() -> void:
	_main_box.visible = false
	_difficulty_box.visible = false
	_options_box.visible = true
	_recenter.call_deferred()


# Titulo con la fuente decorativa entre dos puntas de bronce.
func _title_row(title_text: String, font_size: int = 46) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	var left := TextureRect.new()
	left.texture = TIP_LEFT
	left.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	var title := Label.new()
	title.text = title_text
	title.theme_type_variation = &"TitleLabel"
	title.add_theme_font_size_override("font_size", font_size)
	var right := TextureRect.new()
	right.texture = TIP_RIGHT
	right.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	row.add_child(left)
	row.add_child(title)
	row.add_child(right)
	return row


# Barra dorada del kit, a lo ancho.
func _rule() -> TextureRect:
	var rule := TextureRect.new()
	rule.texture = GOLD_RULE
	rule.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rule.stretch_mode = TextureRect.STRETCH_SCALE
	rule.custom_minimum_size = Vector2(0, 9)
	rule.modulate = Color(1, 1, 1, 0.85)
	return rule


func _centered_label(font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	return label


# Boton de tablon con puntas; hint es la tecla rapida (va chica a la derecha).
func _add_button(parent: Control, text: String, action: Callable, hint: String = "") -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = &"OrnateButton"
	button.custom_minimum_size = Vector2(340, 41)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(func() -> void:
		sfx.play("click", -6.0)
		action.call())
	button.mouse_entered.connect(func() -> void:
		if not button.disabled:
			sfx.play("click", -20.0, 0.15))
	if not hint.is_empty():
		var key := Label.new()
		key.text = hint
		key.theme_type_variation = &"DimLabel"
		key.add_theme_font_size_override("font_size", 12)
		key.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		key.offset_left = -86.0
		key.offset_right = -54.0
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		key.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(key)
	parent.add_child(button)
	return button


func _plain_button(parent: Control, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 36
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if visible:
		if not _choosing_first:
			if _difficulty_box.visible or _options_box.visible:
				_show_main()
			else:
				close()
		get_viewport().set_input_as_handled()
	elif not _any_panel_open():
		open()
		get_viewport().set_input_as_handled()


func open() -> void:
	_show_main()
	visible = true
	sfx.play("page")
	_update_pause()


func open_difficulty() -> void:
	_main_box.visible = false
	_options_box.visible = false
	_difficulty_box.visible = true
	var full: bool = save_game.free_slot() == -1
	_warning.text = "No hay lugar para otro personaje: borrá uno desde el menú principal (Personajes)." if full \
			else "Se guarda el personaje actual y se crea uno nuevo."
	_warning.visible = full or save_game.has_save()
	for i in _difficulty_buttons.size():
		var locked: bool = i > save_game.unlocked_difficulty
		_difficulty_buttons[i].disabled = locked or full
		_difficulty_descriptions[i].text = difficulty.LEVELS[i].description if not locked \
				else "Bloqueada: completá %s (un campeón en cada región)." % difficulty.get_level_name(i - 1)
	_back_button.visible = not _choosing_first
	if not visible:
		visible = true
		_update_pause()
	_recenter.call_deferred()


func close() -> void:
	visible = false
	sfx.play("page")
	_update_pause()


func _show_main() -> void:
	_main_box.visible = true
	_difficulty_box.visible = false
	_options_box.visible = false
	_refresh_info()
	_load_button.disabled = not save_game.has_save() or save_game.hardcore
	var next: int = difficulty.current + 1
	_advance_button.visible = next < difficulty.LEVELS.size() and next <= save_game.unlocked_difficulty \
			and bestiary.regions_cleared.size() >= bestiary.REGIONS.size()
	if _advance_button.visible:
		_advance_button.text = "Pasar a %s" % difficulty.get_level_name(next)
		_advance_button.tooltip_text = "Con el mismo personaje"
	_recenter.call_deferred()


# Clase y nivel, dificultad, lugar, dia y clima, oro.
func _refresh_info() -> void:
	var info: Dictionary = PlayerClasses.get_info(player_stats.class_id)
	_hero_icon.texture = load(info.icon)
	_hero_icon.modulate = info.color
	_hero_label.text = "%s · nivel %d" % [info.name, player_stats.level]
	var extreme: String = "  ·  Modo extremo" if save_game.hardcore else ""
	_difficulty_label.text = "Dificultad %s%s  ·  %d de %d regiones liberadas" % [difficulty.get_level_name(), extreme,
			bestiary.regions_cleared.size(), bestiary.REGIONS.size()]
	_difficulty_label.add_theme_color_override("font_color", difficulty.get_color())
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var place: String = ""
	if player:
		place = REGION_NAMES.get(music.zone_at(player.global_position), "") + "  ·  "
	_place_label.text = "%sDía %d, %s  ·  %s  ·  %d de oro" % [place, world_time.day, world_time.get_clock_text(),
			weather.get_state_name(), player_stats.gold]


# El panel cambia de alto entre las vistas: se vuelve a centrar con su
# tamaño minimo. Si no entra en la pantalla (ventana chica), se achica.
func _recenter() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	pivot_offset = size / 2.0
	_fit = minf(1.0, (get_viewport_rect().size.y - 24.0) / maxf(size.y, 1.0))


func _process(_delta: float) -> void:
	if not visible:
		return
	scale = Vector2.ONE * _fit * lerpf(0.97, 1.0, _appear)
	modulate.a = _appear
	if _backdrop_material:
		_backdrop_material.set_shader_parameter("amount", _appear)


func _on_visibility_changed() -> void:
	if _backdrop:
		_backdrop.visible = visible
	if _open_tween:
		_open_tween.kill()
	if not visible:
		return
	# Entra con el fondo que se oscurece y el panel que se asienta.
	_recenter.call_deferred()
	_appear = 0.0
	_process(0.0)
	_open_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(self, "_appear", 1.0, OPEN_TIME)


func _choose_class(class_id: String) -> void:
	_chosen_class = class_id
	_class_buttons[class_id].button_pressed = true
	# El tema dibuja igual el boton apretado: las otras clases se oscurecen.
	for id in _class_buttons:
		_class_buttons[id].modulate = Color.WHITE if id == class_id else Color(0.55, 0.55, 0.55)
	_class_description.text = PlayerClasses.get_info(class_id).description
	_recenter.call_deferred()


func _on_difficulty_chosen(index: int) -> void:
	_choosing_first = false
	close()
	save_game.new_game(index, _chosen_class, _extreme_check.button_pressed)


func _any_panel_open() -> bool:
	return get_tree().get_nodes_in_group("pause_panels").any(
		func(panel: Control) -> bool: return panel.visible)


func _update_pause() -> void:
	get_tree().paused = _any_panel_open()
