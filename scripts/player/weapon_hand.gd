extends Node3D

## Muestra lo equipado en el modelo del jugador: el arma (o la ballesta, que
## es con lo que se ataca) en la mano derecha, el arco en la izquierda, el
## escudo en el brazo izquierdo (o la segunda arma en la mano izquierda), el
## casco en la cabeza y el peto como textura del cuerpo. Los
## personajes de 0 A.D. traen huesos para eso; los modelos de las armas
## (item/models/) y de los cascos (assets/characters/oad/props/) estan hechos
## para ir pegados a esos huesos tal cual. Sin casco se ve el tocado de tela
## de la clase (pañuelo o capucha; el casco de metal del guerrero no, asi se
## nota cuando se pone uno) y sin peto, su ropa.
## Tambien prende las llamas del aura de fuego de los unicos y los brillos
## del equipo encantado (scripts/items/enchant_fx.gd): el del arma, el
## escudo y el casco en sus mallas, el de la mejor pieza de armadura en el
## cuerpo y, con un set completo, motas que suben alrededor del personaje.

const HAND_BONE := "prop-weapon_R"
const LEFT_HAND_BONE := "prop-weapon_L"
const BOW_BONE := "prop-weapon_bow"
const SHIELD_BONE := "prop-shield"
const HELMET_BONE := "prop-helmet"
## Llamitas en el piso alrededor del personaje mientras tiene aura de fuego.
const AURA_RADIUS: float = 260.0
const WeaponGlow := preload("res://scripts/player/weapon_glow.gd")

var _hand: BoneAttachment3D
var _left_hand: BoneAttachment3D
var _bow: BoneAttachment3D
var _shield: BoneAttachment3D
var _helmet: BoneAttachment3D
## Lo que el modelo de la clase trae en la cabeza (se esconde con un casco).
var _class_headgear: Array[Node3D] = []
var _body: MeshInstance3D
var _body_material: Material
var _aura: CPUParticles3D
var _set_aura: CPUParticles3D


func _ready() -> void:
	# El modelo lo arma player_1.gd en su _ready (que corre despues de este).
	await get_tree().process_frame
	var skeleton: Skeleton3D = get_parent().find_child("Skeleton3D", true, false)
	if skeleton == null:
		return
	_hand = _attachment(skeleton, HAND_BONE)
	_left_hand = _attachment(skeleton, LEFT_HAND_BONE)
	_bow = _attachment(skeleton, BOW_BONE)
	_shield = _attachment(skeleton, SHIELD_BONE)
	_helmet = _attachment(skeleton, HELMET_BONE)
	for child in skeleton.get_children():
		if child is BoneAttachment3D and child.bone_name == HELMET_BONE and child != _helmet:
			_class_headgear.append(child)
	_body = skeleton.get_node_or_null("Body") as MeshInstance3D
	if _body:
		_body_material = _body.get_active_material(0)
	inventory_data.equipment_changed.connect(_on_equipment_changed)
	_refresh()


func _attachment(skeleton: Skeleton3D, bone: String) -> BoneAttachment3D:
	var attachment := BoneAttachment3D.new()
	attachment.name = "Equipo_" + bone
	attachment.bone_name = bone
	skeleton.add_child(attachment)
	return attachment


func _on_equipment_changed(_equip_index: int) -> void:
	_refresh()


func _refresh() -> void:
	var melee: Itemdata = inventory_data.get_equipped(inventory_data.MELEE_EQUIP)
	var special: Itemdata = inventory_data.get_equipped(inventory_data.SPECIAL_EQUIP)
	var ranged: Itemdata = special if special and special.is_ranged() else null
	var in_hand: Itemdata = ranged if ranged and not ranged.bow else melee
	var offhand: Itemdata = special if special and special.item_type == Itemdata.ItemType.MELEE_WEAPON else null
	var on_arm: Itemdata = special if special and ranged == null and offhand == null else null
	# Con arco, la mano derecha queda libre para la flecha.
	_show(_hand, null if ranged and ranged.bow else in_hand)
	_show(_bow, ranged if ranged and ranged.bow else null)
	_show(_left_hand, offhand)
	_show(_shield, on_arm, "shield")

	var helmet: Itemdata = inventory_data.get_equipped(inventory_data.HELMET_EQUIP)
	var has_helmet: bool = helmet != null and helmet.model_3d != null
	_show(_helmet, helmet if has_helmet else null, "armor")
	for headgear in _class_headgear:
		for mesh in headgear.get_children():
			mesh.visible = not has_helmet and mesh.name != "Helmet"

	if _body:
		var chest: Itemdata = inventory_data.get_equipped(inventory_data.CHEST_EQUIP)
		_body.set_surface_override_material(0, _armor_material(chest.body_texture) if chest and chest.body_texture else null)
		_refresh_body_glow()
	_refresh_aura()
	_refresh_set_aura()


## kind: "weapon", "shield" o "armor" (cambia cuanto brilla).
func _show(attachment: BoneAttachment3D, item: Itemdata, kind: String = "weapon") -> void:
	for child in attachment.get_children():
		child.queue_free()
	if item == null or item.model_3d == null:
		return
	var model: Node3D = item.model_3d.instantiate()
	attachment.add_child(model)
	var info: Dictionary = EnchantFx.dress(model, item, kind != "weapon")
	if kind != "armor" and WeaponGlow.wanted(info, kind == "shield"):
		var glow := WeaponGlow.new()
		glow.name = "Brillo"
		attachment.add_child(glow)
		glow.setup(attachment, model, info, kind == "shield")


# El cuerpo brilla segun la mejor pieza de armadura puesta (las que no se ven
# en el modelo tambien cuentan).
func _refresh_body_glow() -> void:
	var best: Itemdata = null
	for item in inventory_data.get_equipped_items():
		if item.is_armor() and (best == null or item.rarity > best.rarity):
			best = item
	EnchantFx.undress(_body)
	if best:
		EnchantFx.dress(_body, best, true)


# Con todas las piezas de un set puestas, motas de su color suben alrededor
# del personaje.
func _refresh_set_aura() -> void:
	var equipped: Array[Itemdata] = inventory_data.get_equipped_items()
	var complete: bool = false
	for item in equipped:
		var info: Dictionary = ItemSets.get_set(item.set_id)
		if not info.is_empty() and ItemSets.count_equipped(item.set_id, equipped) >= info.pieces.size():
			complete = true
			break
	if complete and _set_aura == null:
		var color: Color = EnchantFx.GLOW_COLORS[Itemdata.Rarity.SET]
		_set_aura = Effects.particles(Effects.FLARE, true, 1, 22, 1.8, 40.0)
		_set_aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		_set_aura.emission_ring_axis = Vector3.UP
		_set_aura.emission_ring_radius = AURA_RADIUS * 0.75
		_set_aura.emission_ring_inner_radius = AURA_RADIUS * 0.45
		_set_aura.emission_ring_height = 60.0
		_set_aura.direction = Vector3.UP
		_set_aura.spread = 12.0
		_set_aura.initial_velocity_min = 90.0
		_set_aura.initial_velocity_max = 170.0
		_set_aura.gravity = Vector3.ZERO
		_set_aura.damping_min = 20.0
		_set_aura.damping_max = 50.0
		_set_aura.scale_amount_min = 0.5
		_set_aura.scale_amount_max = 1.1
		_set_aura.scale_amount_curve = Effects.curve([Vector2(0, 0.0), Vector2(0.15, 1.0), Vector2(0.7, 0.8), Vector2(1, 0.0)])
		_set_aura.color_ramp = Effects.ramp([Color(color, 0.0), Color(color.lightened(0.5), 0.9), Color(color, 0.6), Color(color, 0.0)])
		_set_aura.position.y = 30.0
		# Sigue al personaje pero las motas quedan donde salieron.
		get_parent().get_parent().add_child(_set_aura)
	if _set_aura:
		_set_aura.emitting = complete


# El material del cuerpo de la clase con la textura de la armadura (el mismo
# mapa UV sirve para todos los cuerpos de 0 A.D.).
func _armor_material(texture: Texture2D) -> Material:
	var material: Material = _body_material.duplicate() if _body_material else StandardMaterial3D.new()
	if material is StandardMaterial3D:
		(material as StandardMaterial3D).albedo_texture = texture
	return material


func _refresh_aura() -> void:
	var burning: bool = player_stats.get_special("aura_fuego") > 0.0
	if burning and _aura == null:
		_aura = Effects.particles(Effects.FLAME, true, Effects.STRIP_FRAMES, 18, 0.7, 70.0)
		_aura.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
		_aura.emission_ring_axis = Vector3.UP
		_aura.emission_ring_radius = AURA_RADIUS
		_aura.emission_ring_inner_radius = AURA_RADIUS * 0.8
		_aura.emission_ring_height = 0.0
		_aura.direction = Vector3.UP
		_aura.spread = 10.0
		_aura.initial_velocity_min = 40.0
		_aura.initial_velocity_max = 90.0
		_aura.gravity = Vector3(0.0, 60.0, 0.0)
		_aura.scale_amount_curve = Effects.curve([Vector2(0, 0.5), Vector2(0.3, 1.0), Vector2(1, 0.1)])
		_aura.color_ramp = Effects.fire_ramp()
		_aura.position.y = 20.0
		# Sigue al personaje pero las llamas quedan donde salieron.
		get_parent().get_parent().add_child(_aura)
	if _aura:
		_aura.emitting = burning
