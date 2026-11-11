extends RefCounted

## Arrastrar items manteniendo el clic (ademas de clic para agarrar y clic
## para soltar). Al apretar sobre un item, la grilla o el slot lo agarra y
## llama a begin(); si el mouse se mueve mas que THRESHOLD antes de soltar,
## es un arrastre: al soltar, el item va a donde quedo el mouse (lo que esta
## en el grupo "item_drop_targets", con accept_drop(posicion)). Soltado sobre
## una ventana de items (grupo "item_windows") pero fuera de un lugar valido,
## vuelve a donde estaba; soltado fuera de toda ventana (en el mundo), cae al
## piso. Sin moverse, queda agarrado como con un clic.
## La suelta llega siempre al control donde se apreto (Godot le manda los
## eventos del mouse hasta que se suelta el boton), por eso se resuelve aca.
## Las posiciones son las globales de los eventos (event.global_position).

const THRESHOLD: float = 8.0

static var _pressing: bool = false
static var _dragging: bool = false
static var _start := Vector2.ZERO


## Se apreto y se agarro un item en position.
static func begin(position: Vector2) -> void:
	_pressing = true
	_dragging = false
	_start = position


static func motion(position: Vector2) -> void:
	if _pressing and not _dragging and position.distance_to(_start) > THRESHOLD:
		_dragging = true


static func is_dragging() -> bool:
	return _pressing and _dragging


## Se solto el boton en position. Si era un arrastre, deja el item ahi y
## devuelve true (el control no tiene que hacer nada mas).
static func release(source: Control, position: Vector2) -> bool:
	motion(position)
	var was_drag: bool = _pressing and _dragging
	_pressing = false
	_dragging = false
	if not was_drag or inventory_data.held == null:
		return false
	var tree: SceneTree = source.get_tree()
	for target in tree.get_nodes_in_group("item_drop_targets"):
		var control := target as Control
		if control and control.is_visible_in_tree() and control.get_global_rect().has_point(position):
			control.accept_drop(position)
			return true
	for window in tree.get_nodes_in_group("item_windows"):
		var control := window as Control
		if control and control.is_visible_in_tree() and control.get_global_rect().has_point(position):
			inventory_data.return_held()
			return true
	inventory_data.drop_held()
	return true


## Se cancelo (se cerro el inventario o se cambio de pestaña).
static func cancel() -> void:
	_pressing = false
	_dragging = false
