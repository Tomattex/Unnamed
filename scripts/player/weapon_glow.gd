extends Node3D

## Lo que acompaña al arma (o al escudo) encantada y no va pegado a la malla:
## el destello de la punta, las motas y el halo de los unicos y de set, y las
## particulas del elemento. Es hijo del hueso donde va el arma (asi se borra
## con ella) pero se mueve por su cuenta, sin la escala del modelo: los
## tamaños van en unidades del mundo y las particulas quedan en el mundo, asi
## dejan estela al pegar. Ver scripts/items/enchant_fx.gd.

## Parte del largo del arma donde salen las particulas (desde el mango).
const BLADE_FROM: float = 0.3
## Grosor de la zona de las particulas, en partes del ancho del arma.
const BLADE_THICKNESS: float = 0.45
const GLINT_SIZE: float = 120.0

var _attachment: Node3D


## info: lo que devuelve EnchantFx.dress() para el modelo. shield = solo
## motas (sin halo ni destello).
func setup(attachment: Node3D, model: Node3D, info: Dictionary, shield: bool = false) -> void:
	_attachment = attachment
	top_level = true
	var scale_factor: float = attachment.global_basis.get_scale().x
	var to_attachment: Transform3D = model.transform
	var start: Vector3 = to_attachment * info.start * scale_factor
	var tip: Vector3 = to_attachment * info.tip * scale_factor
	var box: AABB = info.box
	var width: float = minf(box.size[box.size.min_axis_index()], box.size[_middle_axis(box.size)]) * scale_factor
	width = maxf(width * BLADE_THICKNESS, 8.0)
	var from: Vector3 = start.lerp(tip, 0.0 if shield else BLADE_FROM)
	var color: Color = info.color
	var tier: int = info.tier
	if tier >= EnchantFx.Tier.RARE and not shield:
		var star: MeshInstance3D = EnchantFx.glint(info, GLINT_SIZE * (1.25 if tier == EnchantFx.Tier.EPIC else 1.0))
		star.position = tip
		add_child(star)
	if tier == EnchantFx.Tier.EPIC:
		_add(_motes(color, 9 if shield else 12), from, tip, width)
		if not shield:
			_add(_halo(color), from, tip, width)
	elif tier == EnchantFx.Tier.RARE and not shield:
		_add(_motes(color, 4), from, tip, width)
	match info.element:
		Damage.Type.FIRE:
			_add(_flames(), from, tip, width)
			_add(_embers(), from, tip, width)
		Damage.Type.POISON:
			_add(_drips(), from, tip, width)
			_add(_mist(), from, tip, width)
		Damage.Type.MAGIC:
			_add(_arcs(), from, tip, width)
			_add(_motes(EnchantFx.element_color(Damage.Type.MAGIC), 8), from, tip, width)
	# Se mueve apenas el esqueleto pone la pose (despues del hueso), asi las
	# particulas salen de donde esta la hoja y no de donde estaba.
	var skeleton := attachment.get_parent() as Skeleton3D
	if skeleton:
		skeleton.skeleton_updated.connect(_follow)
	_follow()


## Si un item con esta calidad lleva efectos al lado (si no, alcanza con el
## brillo de la malla).
static func wanted(info: Dictionary, shield: bool) -> bool:
	if info.is_empty():
		return false
	if shield:
		return info.tier == EnchantFx.Tier.EPIC
	return info.tier >= EnchantFx.Tier.RARE or info.element != -1


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	if not is_instance_valid(_attachment):
		return
	var xf: Transform3D = _attachment.global_transform
	global_transform = Transform3D(xf.basis.orthonormalized(), xf.origin)


func _middle_axis(size: Vector3) -> int:
	var long: int = size.max_axis_index()
	var short: int = size.min_axis_index()
	return 3 - long - short if long != short else long


# Emisor a lo largo del arma (una caja del largo de la hoja y el grueso dado).
func _add(system: CPUParticles3D, from: Vector3, to: Vector3, width: float) -> void:
	var along: Vector3 = to - from
	system.position = (from + to) / 2.0
	if along.length() > 0.01:
		system.basis = _basis_along(along.normalized())
	system.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	system.emission_box_extents = Vector3(width / 2.0, along.length() / 2.0, width / 2.0)
	system.emitting = true
	add_child(system)


# Base con el eje Y apuntando hacia dir.
func _basis_along(dir: Vector3) -> Basis:
	var other: Vector3 = Vector3.FORWARD if absf(dir.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x: Vector3 = other.cross(dir).normalized()
	return Basis(x, dir, x.cross(dir).normalized()).orthonormalized()


# --- Particulas -----------------------------------------------------------------

# Puntitos de luz que flotan alrededor de la hoja y se apagan titilando.
func _motes(color: Color, amount: int) -> CPUParticles3D:
	var system: CPUParticles3D = Effects.particles(Effects.FLARE, true, 1, amount, 1.1, 34.0)
	system.direction = Vector3.UP
	system.spread = 180.0
	system.initial_velocity_min = 8.0
	system.initial_velocity_max = 30.0
	system.gravity = Vector3(0.0, 45.0, 0.0)
	system.damping_min = 10.0
	system.damping_max = 20.0
	system.scale_amount_min = 0.5
	system.scale_amount_max = 1.2
	system.scale_amount_curve = Effects.curve([Vector2(0, 0.0), Vector2(0.2, 1.0), Vector2(0.6, 0.7), Vector2(1, 0.0)])
	system.color_ramp = Effects.ramp([Color(1, 1, 1, 0.0), Color(color.lightened(0.5), 1.0), Color(color, 0.9), Color(color, 0.0)])
	return system


# Halo suave pegado a la hoja: quieta la rodea de luz, al pegar deja estela.
func _halo(color: Color) -> CPUParticles3D:
	var system: CPUParticles3D = Effects.particles(Effects.SOFT, true, 1, 18, 0.28, 95.0)
	system.direction = Vector3.UP
	system.spread = 180.0
	system.initial_velocity_min = 0.0
	system.initial_velocity_max = 6.0
	system.gravity = Vector3.ZERO
	system.scale_amount_min = 0.7
	system.scale_amount_max = 1.1
	system.scale_amount_curve = Effects.curve([Vector2(0, 0.6), Vector2(0.3, 1.0), Vector2(1, 0.4)])
	system.color_ramp = Effects.ramp([Color(color, 0.0), Color(color, 0.22), Color(color, 0.12), Color(color, 0.0)])
	return system


func _flames() -> CPUParticles3D:
	var system: CPUParticles3D = Effects.particles(Effects.FLAME, true, Effects.STRIP_FRAMES, 16, 0.35, 40.0)
	system.direction = Vector3.UP
	system.spread = 25.0
	system.initial_velocity_min = 10.0
	system.initial_velocity_max = 40.0
	system.gravity = Vector3(0.0, 260.0, 0.0)
	system.scale_amount_min = 0.5
	system.scale_amount_max = 1.0
	system.scale_amount_curve = Effects.curve([Vector2(0, 0.4), Vector2(0.25, 1.0), Vector2(1, 0.1)])
	system.color_ramp = Effects.fire_ramp()
	return system


func _embers() -> CPUParticles3D:
	var system: CPUParticles3D = Effects.particles(Effects.FLARE, true, 1, 10, 0.9, 22.0)
	system.direction = Vector3.UP
	system.spread = 60.0
	system.initial_velocity_min = 30.0
	system.initial_velocity_max = 90.0
	system.gravity = Vector3(0.0, 150.0, 0.0)
	system.damping_min = 20.0
	system.damping_max = 40.0
	system.scale_amount_min = 0.4
	system.scale_amount_max = 1.0
	system.color_ramp = Effects.ramp([Color(1.0, 0.95, 0.6), Color(1.0, 0.6, 0.15), Color(0.9, 0.2, 0.05, 0.0)])
	return system


# Gotas de veneno que caen de la hoja.
func _drips() -> CPUParticles3D:
	var system: CPUParticles3D = Effects.particles(Effects.SOFT, true, 1, 10, 0.75, 20.0)
	system.direction = Vector3.DOWN
	system.spread = 15.0
	system.initial_velocity_min = 0.0
	system.initial_velocity_max = 20.0
	system.gravity = Vector3(0.0, -520.0, 0.0)
	system.scale_amount_min = 0.5
	system.scale_amount_max = 1.0
	system.scale_amount_curve = Effects.curve([Vector2(0, 0.3), Vector2(0.2, 1.0), Vector2(1, 0.6)])
	system.color_ramp = Effects.ramp([Color(0.7, 1.0, 0.4, 0.0), Color(0.5, 1.0, 0.2, 1.0), Color(0.3, 0.8, 0.1, 0.8), Color(0.2, 0.6, 0.05, 0.0)])
	return system


# Vaho verde que se levanta de la hoja.
func _mist() -> CPUParticles3D:
	var system: CPUParticles3D = Effects.particles(Effects.SMOKE, false, Effects.STRIP_FRAMES, 8, 1.0, 70.0)
	system.direction = Vector3.UP
	system.spread = 40.0
	system.initial_velocity_min = 10.0
	system.initial_velocity_max = 30.0
	system.gravity = Vector3(0.0, 40.0, 0.0)
	system.scale_amount_curve = Effects.curve([Vector2(0, 0.4), Vector2(0.4, 1.0), Vector2(1, 1.3)])
	system.color_ramp = Effects.ramp([Color(0.5, 0.95, 0.3, 0.0), Color(0.45, 0.9, 0.25, 0.35), Color(0.3, 0.6, 0.15, 0.0)])
	return system


# Chispas arcanas que chisporrotean sobre la hoja.
func _arcs() -> CPUParticles3D:
	var system: CPUParticles3D = Effects.particles(Effects.SPARK, true, Effects.STRIP_FRAMES, 10, 0.22, 60.0)
	system.direction = Vector3.UP
	system.spread = 180.0
	system.initial_velocity_min = 0.0
	system.initial_velocity_max = 10.0
	system.gravity = Vector3.ZERO
	system.angle_min = 0.0
	system.angle_max = 360.0
	system.scale_amount_min = 0.6
	system.scale_amount_max = 1.1
	system.color_ramp = Effects.ramp([Color(0.9, 0.85, 1.0), Color(0.7, 0.5, 1.0), Color(0.45, 0.3, 1.0, 0.0)])
	return system
