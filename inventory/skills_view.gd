extends VBoxContainer

## Pestaña Habilidades del inventario: las habilidades de la clase en orden,
## con su tecla de la barra, si ya se aprendieron (y a que nivel) o en que
## nivel se aprenden solas, lo que da el nivel siguiente y un boton para leer
## su runa si hay una en la mochila (aprende la habilidad antes de tiempo o la
## sube un nivel). La barra es fija: la habilidad N va siempre en la tecla N.

const ICON_SIZE := Vector2(54, 54)
const GOLD := Color(0.95, 0.8, 0.48)
const TEXT := Color(0.88, 0.82, 0.68)
const DIM := Color(0.62, 0.57, 0.48)
const LEARNED := Color(0.55, 0.85, 0.5)
const LOCKED := Color(0.75, 0.62, 0.45)
const NEXT := Color(0.6, 0.82, 1.0)

var _rows: VBoxContainer
var _dirty: bool = true


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	var intro := Label.new()
	intro.text = "Cada habilidad se aprende sola al llegar a su nivel, o antes leyendo su runa. Las runas también las suben de nivel (hasta tu nivel). La habilidad N va en la tecla N de la barra."
	intro.theme_type_variation = &"DimLabel"
	intro.add_theme_font_size_override("font_size", 13)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(intro)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	# Margen a la derecha para la barra de desplazamiento.
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_right", 16)
	scroll.add_child(margin)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 8)
	margin.add_child(_rows)

	var mark := func() -> void:
		_dirty = true
	skill_book.skill_unlocked.connect(mark.unbind(1))
	skill_book.skill_leveled.connect(mark.unbind(2))
	inventory_data.inventory_changed.connect(mark.unbind(1))
	player_stats.leveled_up.connect(mark.unbind(1))
	player_stats.stats_changed.connect(mark)


func _process(_delta: float) -> void:
	if _dirty and is_visible_in_tree():
		_dirty = false
		refresh()


## Hay alguna runa en la mochila que se puede leer ahora.
static func has_pending() -> bool:
	for i in skill_book.skills.size():
		if skill_book.rune_count(i) > 0 and _rune_problem(i).is_empty():
			return true
	return false


static func _rune_problem(index: int) -> String:
	var rune: Itemdata = Runes.rune_for(skill_book._paths[index])
	return skill_book.rune_problem(rune) if rune else "No hay runa"


func refresh() -> void:
	for child in _rows.get_children():
		child.queue_free()
	for i in skill_book.skills.size():
		_rows.add_child(_row(i))


func _row(index: int) -> Control:
	var skill: SkillData = skill_book.get_skill(index)
	var level: int = skill_book.get_level(index)
	var learned: bool = level > 0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	# Icono con la tecla (gris si todavia no se aprendio).
	var frame := PanelContainer.new()
	frame.theme_type_variation = &"SlotPanel"
	frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	frame.tooltip_text = skill_book.get_tooltip(index)
	var holder := Control.new()
	holder.custom_minimum_size = ICON_SIZE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(holder)
	var icon := TextureRect.new()
	icon.texture = skill.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.modulate = Color.WHITE if learned else Color(0.3, 0.3, 0.3)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(icon)
	var key := Label.new()
	key.text = str(index + 1)
	key.position = Vector2(3, -1)
	key.add_theme_font_size_override("font_size", 14)
	key.add_theme_color_override("font_color", Color(1, 0.9, 0.6))
	key.add_theme_constant_override("outline_size", 5)
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(key)
	row.add_child(frame)

	var texts := VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	var title := HBoxContainer.new()
	var name_label := _label(skill.name, GOLD if learned else DIM, 16)
	title.add_child(name_label)
	var status := _label("", LEARNED if learned else LOCKED, 14)
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if learned:
		status.text = "Nivel %d · tecla %d" % [level, index + 1]
	else:
		status.text = "Se aprende en el nivel %d" % skill_book.learn_level(index)
	title.add_child(status)
	texts.add_child(title)
	var description := _label(skill.description, TEXT, 13)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(description)
	# Lo que da el siguiente nivel (o el primero, si falta aprenderla).
	var from: int = maxi(level, 1)
	var to: int = level + 1 if learned else 1
	var changes := _label(("Nivel %d: " % to if learned else "Al aprenderla: ") + " · ".join(skill.compare_lines(from, to)), NEXT, 12)
	changes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(changes)
	var hint := _label(skill_book.learn_hint(index), DIM, 12)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	texts.add_child(hint)
	row.add_child(texts)

	# Leer la runa desde aca (si hay en la mochila).
	var runes: int = skill_book.rune_count(index)
	var button := Button.new()
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(112, 34)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.text = ("Aprender" if not learned else "Subir") + (" (runa x%d)" % runes if runes > 1 else " (runa)")
	if runes <= 0:
		button.text = "Sin runa"
	var problem: String = _rune_problem(index) if runes > 0 else "No tenés su runa. Caen de enemigos y cofres; la Runista de la aldea cambia las de otras clases."
	button.disabled = not problem.is_empty()
	button.tooltip_text = problem
	button.visible = runes > 0 or not learned
	button.pressed.connect(_on_read.bind(index))
	row.add_child(button)
	return row


func _label(text: String, color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	return label


func _on_read(index: int) -> void:
	var problem: String = skill_book.read_rune_for(index)
	if problem.is_empty():
		sfx.play("new_skill")
	else:
		sfx.play("stuck", -6.0)
		inventory_data.equip_rejected.emit(problem)
	_dirty = true
