extends Node3D

## Ajustes a un personaje importado (GLB de 0 A.D.) sin tocar el archivo:
## colores por pieza, piezas ocultas y piezas extra colgadas de sus puntos de
## anclaje. Corre en _ready, antes de que enemi.gd junte las mallas.

## Nombre de la malla -> color que multiplica su textura.
@export var tints: Dictionary = {}
## Mallas que no se ven (ej: la vincha del bandido debajo del casco).
@export var hidden: PackedStringArray = []
## Nombre del BoneAttachment3D -> escena que se le cuelga (casco, capucha).
@export var attach: Dictionary = {}


func _ready() -> void:
	for mesh in find_children("*", "MeshInstance3D", true, false):
		if String(mesh.name) in hidden:
			mesh.visible = false
		elif tints.has(String(mesh.name)):
			_tint(mesh, tints[String(mesh.name)])
	for point in attach:
		var holder: Node = find_child(point, true, false)
		if holder:
			holder.add_child(load(attach[point]).instantiate())


func _tint(mesh: MeshInstance3D, color: Color) -> void:
	for i in mesh.get_surface_override_material_count():
		var base: Material = mesh.get_active_material(i)
		if base is BaseMaterial3D:
			var tinted: BaseMaterial3D = base.duplicate()
			tinted.albedo_color = tinted.albedo_color * color
			mesh.set_surface_override_material(i, tinted)
