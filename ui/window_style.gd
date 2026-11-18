extends RefCounted

## Estilo comun de las ventanas del juego (inventario, personaje, tienda,
## baul, herreria, runista, entrenadores, bestiario, mapa grande y combo),
## para que todas hablen el mismo idioma que el menu de pausa
## (ui/game_menu.gd): marco doble de madera oscura (WindowPanel), fila de
## titulo con las puntas de bronce y la fuente de titulos (WindowTitle),
## boton de cerrar (CloseButton), regla dorada debajo, una entrada corta al
## abrir y el sonido del menu en los botones.

const TIP_LEFT := preload("res://ui/theme/textures/tip_left.png")
const TIP_RIGHT := preload("res://ui/theme/textures/tip_right.png")
const GOLD_RULE := preload("res://ui/theme/textures/gold_rule.png")
const BACKDROP_SHADER := preload("res://ui/theme/menu_backdrop.gdshader")
const TIP_SIZE := Vector2(22, 24)
const OPEN_TIME: float = 0.15
## Cuanto se nota el fondo de las ventanas grandes (el menu de pausa usa 1).
const BACKDROP_AMOUNT: float = 0.8


## Marco de ventana y entrada animada cada vez que se muestra.
static func setup(window: Control) -> void:
	if window is PanelContainer:
		window.theme_type_variation = &"WindowPanel"
	window.visibility_changed.connect(_on_visibility_changed.bind(window))


# Solo se funde (sin escala: no mueve los lugares donde se sueltan items).
static func _on_visibility_changed(window: Control) -> void:
	if not window.visible:
		return
	wire_sounds(window)
	window.modulate.a = 0.0
	var tween := window.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(window, "modulate:a", 1.0, OPEN_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Fila de titulo: punta, titulo, punta, lo que agregue cada ventana (con
## add_to_header) y el boton de cerrar a la derecha. close_tip es el tooltip
## del boton (la tecla que tambien cierra).
static func header(title_text: String, close: Callable, close_tip: String = "Cerrar (Esc)") -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "WindowHeader"
	row.add_theme_constant_override("separation", 6)
	row.add_child(_tip(TIP_LEFT))
	var title := Label.new()
	title.name = "Title"
	title.text = title_text
	title.theme_type_variation = &"WindowTitle"
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)
	row.add_child(_tip(TIP_RIGHT))
	var fill := Control.new()
	fill.name = "Fill"
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(fill)
	var close_button := Button.new()
	close_button.name = "Close"
	close_button.text = "X"
	close_button.theme_type_variation = &"CloseButton"
	close_button.custom_minimum_size = Vector2(30, 30)
	close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.tooltip_text = close_tip
	close_button.pressed.connect(close)
	row.add_child(close_button)
	return row


## El titulo de una fila hecha con header().
static func title_of(row: HBoxContainer) -> Label:
	return row.get_node("Title")


## Agrega algo a la fila de titulo, antes del espacio que empuja el boton de cerrar.
static func add_to_header(row: HBoxContainer, control: Control, after_fill: bool = false) -> void:
	row.add_child(control)
	var fill: Node = row.get_node("Fill")
	row.move_child(control, fill.get_index() + (1 if after_fill else 0))


## Cambia una fila de titulo armada a mano (en una escena) por la del estilo.
static func replace_header(old: Control, title_text: String, close: Callable, close_tip: String = "Cerrar (Esc)") -> HBoxContainer:
	var row := header(title_text, close, close_tip)
	var parent: Node = old.get_parent()
	parent.add_child(row)
	parent.move_child(row, old.get_index())
	parent.remove_child(old)
	old.queue_free()
	return row


## Fondo de las ventanas que tapan el juego (bestiario, mapa, entrenadores,
## runista): lo de atras queda borroso y oscuro, como detras del menu de pausa.
static func backdrop() -> ColorRect:
	var rect := ColorRect.new()
	rect.name = "Backdrop"
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material := ShaderMaterial.new()
	material.shader = BACKDROP_SHADER
	material.set_shader_parameter("amount", BACKDROP_AMOUNT)
	rect.material = material
	return rect


## Barra dorada del kit, a lo ancho (debajo del titulo y entre secciones).
static func rule() -> TextureRect:
	var rule_rect := TextureRect.new()
	rule_rect.texture = GOLD_RULE
	rule_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rule_rect.stretch_mode = TextureRect.STRETCH_SCALE
	rule_rect.custom_minimum_size = Vector2(0, 7)
	rule_rect.modulate = Color(1, 1, 1, 0.8)
	rule_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule_rect


## Pone el sonido del menu (pasar y apretar) en los botones de root que
## todavia no lo tienen. Se llama al abrir la ventana: los botones que se
## arman despues lo reciben la proxima vez.
static func wire_sounds(root: Node) -> void:
	for node in root.find_children("*", "BaseButton", true, false):
		if node.has_meta("ui_sound"):
			continue
		node.set_meta("ui_sound", true)
		var button: BaseButton = node
		button.mouse_entered.connect(func() -> void:
			if not button.disabled:
				sfx.play("click", -20.0, 0.15))
		button.pressed.connect(func() -> void: sfx.play("click", -9.0))


static func _tip(texture: Texture2D) -> TextureRect:
	var tip := TextureRect.new()
	tip.texture = texture
	tip.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tip.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tip.custom_minimum_size = TIP_SIZE
	tip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tip
