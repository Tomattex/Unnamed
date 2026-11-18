class_name EnchantFx

## Brillos del equipo segun su calidad, en escalones que se reconocen de lejos:
## - Normal: nada.
## - Magico: un borde suave del color de la rareza (fresnel).
## - Raro: ademas una franja de luz que barre el objeto cada pocos segundos
##   (el "sheen") y un destello en estrella cuando llega a la punta.
## - Unico (dorado) y de set (verde): franja mas fuerte, pulso, motas de luz y
##   un halo que deja estela al pegar (ver scripts/player/weapon_glow.gd).
## - Con daño de fuego, veneno o magia (afijos o gemas), sea cual sea la
##   rareza: llamitas y brasas, gotas verdes o chispas arcanas, y la franja y
##   la estela del golpe toman ese color.
## La armadura usa los mismos efectos mas suaves (no tiene que tapar la pelea).
## Todo va como material_overlay: los materiales de los modelos no se tocan.

const OVERLAY_SHADER := preload("res://scripts/items/enchant_overlay.gdshader")
const GLINT_SHADER := preload("res://scripts/items/enchant_glint.gdshader")
const BEAM_SHADER := preload("res://scripts/items/enchant_beam.gdshader")

enum Tier { NONE, MAGIC, RARE, EPIC }

## Color del brillo de cada rareza (Itemdata.Rarity): un poco mas saturados
## que los del texto; el unico, dorado.
const GLOW_COLORS := [
	Color(0.9, 0.88, 0.82),
	Color(0.4, 0.62, 1.0),
	Color(1.0, 0.82, 0.28),
	Color(1.0, 0.62, 0.12),
	Color(0.3, 1.0, 0.38),
]
## Fuerza de cada efecto por escalon (Tier): borde, tinte parejo, franja y pulso.
const WEAPON_LOOK := [
	{"rim": 0.0, "base": 0.0, "sheen": 0.0, "pulse": 0.0},
	{"rim": 1.35, "base": 0.05, "sheen": 0.0, "pulse": 0.0},
	{"rim": 1.3, "base": 0.06, "sheen": 1.8, "pulse": 0.0},
	{"rim": 1.7, "base": 0.1, "sheen": 2.6, "pulse": 0.4},
]
const ARMOR_LOOK := [
	{"rim": 0.0, "base": 0.0, "sheen": 0.0, "pulse": 0.0},
	{"rim": 0.28, "base": 0.0, "sheen": 0.0, "pulse": 0.0},
	{"rim": 0.34, "base": 0.0, "sheen": 0.4, "pulse": 0.0},
	{"rim": 0.42, "base": 0.0, "sheen": 0.55, "pulse": 0.22},
]
## Borde (exponente: mas = mas finito), ancho de la franja y cuanto del pulso
## llena las caras de frente. La armadura y los escudos son grandes y planos:
## borde y franja mas finos y el pulso solo en el borde.
const WEAPON_SHAPE := {"power": 2.4, "width": 0.14, "fill": 0.35}
const ARMOR_SHAPE := {"power": 3.6, "width": 0.07, "fill": 0.0}
## Arma comun con daño elemental: solo un borde del color del elemento.
const ELEMENT_ONLY_RIM: float = 0.55
## Segundos entre pasadas de la franja (en el cuerpo, mas lenta).
const WEAPON_SHEEN_PERIOD: float = 3.2
const ARMOR_SHEEN_PERIOD: float = 5.5
## Inclinacion de la franja (en partes del ancho del objeto).
const SHEEN_TILT: float = 0.35


## Escalon de brillo del item (Tier).
static func tier_of(item: Itemdata) -> int:
	if item == null:
		return Tier.NONE
	match item.rarity:
		Itemdata.Rarity.MAGIC:
			return Tier.MAGIC
		Itemdata.Rarity.RARE:
			return Tier.RARE
		Itemdata.Rarity.UNIQUE, Itemdata.Rarity.SET:
			return Tier.EPIC
	return Tier.NONE


## Elemento con el que pega el arma (Damage.Type) o -1: el de mas daño entre
## afijos y gemas; si no tiene, el de su efecto especial (aura de fuego,
## rayo en cadena).
static func element_of(item: Itemdata) -> int:
	if item == null or not item.has_damage():
		return -1
	var best: int = -1
	var best_value: float = 0.0
	for type in Damage.ELEMENTS:
		var value: float = item.get_bonus(Damage.damage_key(type))
		if value > best_value:
			best = type
			best_value = value
	if best == -1:
		match item.special:
			"aura_fuego":
				best = Damage.Type.FIRE
			"cadena":
				best = Damage.Type.MAGIC
	return best


static func glow_color(item: Itemdata) -> Color:
	return GLOW_COLORS[item.rarity] if item else Color.WHITE


## Color de cada elemento para los brillos (mas vivos que los del texto).
static func element_color(type: int) -> Color:
	match type:
		Damage.Type.FIRE:
			return Color(1.0, 0.45, 0.08)
		Damage.Type.POISON:
			return Color(0.42, 1.0, 0.18)
		Damage.Type.MAGIC:
			return Color(0.62, 0.42, 1.0)
	return Color.WHITE


## Si el item lleva algun brillo.
static func has_glow(item: Itemdata) -> bool:
	return tier_of(item) != Tier.NONE or element_of(item) != -1


## Color de la estela del golpe con el arma: la del elemento, la de la
## rareza en los buenos, o null (la de siempre).
static func trail_color(item: Itemdata) -> Variant:
	var element: int = element_of(item)
	if element != -1:
		return Color(element_color(element), 0.32)
	match tier_of(item):
		Tier.EPIC:
			return Color(glow_color(item), 0.34)
		Tier.RARE:
			return Color(Color.WHITE.lerp(glow_color(item), 0.55), 0.3)
		Tier.MAGIC:
			return Color(Color.WHITE.lerp(glow_color(item), 0.35), 0.28)
	return null


## Pone el brillo en todas las mallas de model segun el item. armor = efectos
## mas suaves. Devuelve lo que necesitan los efectos de afuera
## (weapon_glow.gd): caja y punta del modelo (en su espacio), eje, colores y el
## desfase de tiempo que comparte con el destello. Vacio si no brilla.
static func dress(model: Node3D, item: Itemdata, armor: bool = false) -> Dictionary:
	var tier: int = tier_of(item)
	var element: int = -1 if armor else element_of(item)
	if tier == Tier.NONE and element == -1:
		return {}
	var box: AABB = model_box(model)
	if box.size == Vector3.ZERO:
		return {}
	var axis: Dictionary = _axis_of(box)
	var color: Color = glow_color(item) if tier != Tier.NONE else element_color(element)
	var sheen: Color = Color.WHITE.lerp(color, 0.45)
	if element != -1:
		sheen = element_color(element).lightened(0.35)
	var look: Dictionary = (ARMOR_LOOK if armor else WEAPON_LOOK)[tier]
	var shape: Dictionary = ARMOR_SHAPE if armor or tier == Tier.NONE else WEAPON_SHAPE
	var info := {
		"tier": tier, "element": element, "color": color, "sheen_color": sheen,
		"box": box, "tip": axis.tip, "start": axis.start,
		"period": ARMOR_SHEEN_PERIOD if armor else WEAPON_SHEEN_PERIOD,
		"offset": randf() * 10.0,
	}
	var rim: float = look.rim if tier != Tier.NONE else ELEMENT_ONLY_RIM
	for mesh in _meshes(model):
		var material := ShaderMaterial.new()
		material.shader = OVERLAY_SHADER
		material.set_shader_parameter("glow_color", color)
		material.set_shader_parameter("sheen_color", sheen)
		material.set_shader_parameter("rim_strength", rim)
		material.set_shader_parameter("rim_power", shape.power)
		material.set_shader_parameter("base_glow", look.base)
		material.set_shader_parameter("sheen_strength", look.sheen)
		material.set_shader_parameter("sheen_width", shape.width)
		material.set_shader_parameter("pulse_strength", look.pulse)
		material.set_shader_parameter("pulse_fill", shape.fill)
		material.set_shader_parameter("sheen_period", info.period)
		material.set_shader_parameter("time_offset", info.offset)
		_set_axis(material, mesh, model, axis)
		mesh.material_overlay = material
	return info


## Saca el brillo que le haya puesto dress().
static func undress(model: Node3D) -> void:
	for mesh in _meshes(model):
		if mesh.material_overlay is ShaderMaterial and mesh.material_overlay.shader == OVERLAY_SHADER:
			mesh.material_overlay = null


## Destello en estrella que acompaña a la franja (ponerlo en la punta).
static func glint(info: Dictionary, size: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	var material := ShaderMaterial.new()
	material.shader = GLINT_SHADER
	material.set_shader_parameter("star_texture", Effects.STAR)
	material.set_shader_parameter("color", info.sheen_color)
	material.set_shader_parameter("sheen_period", info.period)
	material.set_shader_parameter("time_offset", info.offset)
	quad.material = material
	var mesh := MeshInstance3D.new()
	mesh.name = "Destello"
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


## Haz de luz vertical (items buenos en el piso). La base queda en el origen.
static func beam(color: Color, height: float, width: float, strength: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(width, height)
	quad.center_offset = Vector3(0.0, height / 2.0, 0.0)
	var material := ShaderMaterial.new()
	material.shader = BEAM_SHADER
	material.set_shader_parameter("color", color)
	material.set_shader_parameter("strength", strength)
	material.set_shader_parameter("time_offset", randf() * 10.0)
	quad.material = material
	var mesh := MeshInstance3D.new()
	mesh.name = "Haz"
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


## Mancha de luz redonda acostada en el piso.
static func ground_glow(color: Color, size: float) -> MeshInstance3D:
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.orientation = PlaneMesh.FACE_Y
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.albedo_texture = Effects.SOFT
	material.albedo_color = color
	quad.material = material
	var mesh := MeshInstance3D.new()
	mesh.name = "Resplandor"
	mesh.mesh = quad
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mesh


## Caja de todas las mallas de model, en el espacio de model (no hace falta
## que este en el arbol).
static func model_box(model: Node3D) -> AABB:
	var box := AABB()
	var first: bool = true
	for mesh in _meshes(model):
		var aabb: AABB = mesh.get_aabb()
		var xf: Transform3D = _relative(mesh, model)
		for i in 8:
			var corner: Vector3 = xf * (aabb.position + aabb.size * Vector3(i & 1, (i >> 1) & 1, (i >> 2) & 1))
			if first:
				box = AABB(corner, Vector3.ZERO)
				first = false
			else:
				box = box.expand(corner)
	return box


static func _meshes(model: Node3D) -> Array:
	var result: Array = model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D:
		result.push_front(model)
	return result


# Transformacion de node al espacio de root (root tiene que ser un ancestro).
static func _relative(node: Node3D, root: Node3D) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var current: Node = node
	while current != root and current is Node3D:
		xf = (current as Node3D).transform * xf
		current = current.get_parent()
	return xf


# Eje largo de la caja: arranca en la punta mas cercana al origen (el mango o
# los pies) y termina en la otra (la punta de la hoja o la cabeza). Tambien el
# segundo eje mas largo, para inclinar la franja.
static func _axis_of(box: AABB) -> Dictionary:
	var size: Vector3 = box.size
	var long: int = size.max_axis_index()
	var side: int = (long + 1) % 3
	if size[(long + 2) % 3] > size[side]:
		side = (long + 2) % 3
	var center: Vector3 = box.get_center()
	var low: Vector3 = center
	var high: Vector3 = center
	low[long] = box.position[long]
	high[long] = box.end[long]
	var start: Vector3 = low
	var tip: Vector3 = high
	if absf(box.position[long]) > absf(box.end[long]):
		start = high
		tip = low
	var side_vector := Vector3.ZERO
	side_vector[side] = maxf(size[side], 0.001)
	return {"start": start, "tip": tip, "side": side_vector, "center": center}


# Pasa el eje (en el espacio del modelo) al espacio de la malla: along =
# dot(VERTEX - origen, eje) da 0 en el arranque y 1 en la punta.
static func _set_axis(material: ShaderMaterial, mesh: MeshInstance3D, model: Node3D, axis: Dictionary) -> void:
	var to_model: Transform3D = _relative(mesh, model)
	var along: Vector3 = axis.tip - axis.start
	var transposed: Basis = to_model.basis.transposed()
	material.set_shader_parameter("axis_origin", to_model.affine_inverse() * axis.start)
	material.set_shader_parameter("axis_scale", transposed * (along / maxf(along.length_squared(), 0.000001)))
	var side: Vector3 = axis.side
	material.set_shader_parameter("tilt_scale", transposed * (side / side.length_squared()) * SHEEN_TILT)
