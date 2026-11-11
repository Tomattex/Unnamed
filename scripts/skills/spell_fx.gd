class_name SpellFx

## Efectos de los hechizos: el destello al lanzar (sigilo en el piso y luz en
## las manos), el orbe arcano y su impacto, el cuerpo y la explosion de la
## bola de fuego y del meteoro, la ola de llamas del anillo, la marca del
## meteoro, la burbuja de los escudos y el aura de las mejoras.
## Arma todo con las piezas de Effects (texturas del Kenney Particle Pack,
## materiales aditivos sin luz) y luces que se apagan solas. Con el
## renderizador Mobile no hay transparencia por nodo: lo que se desvanece lo
## hace por el alfa del material o del degradado.

const SHIELD_SHADER := preload("res://scripts/skills/arcane_shield.gdshader")
const STRIP := Effects.STRIP_FRAMES
## Altura de las manos del personaje (lanza desde ahi) y cuanto adelante.
const HANDS_HEIGHT: float = 260.0
const HANDS_FORWARD: float = 70.0
const SHIELD_NAME := "BurbujaDeEscudo"
const AURA_NAME := "AuraDeMejora"

static var _pattern: NoiseTexture2D


## Sacude la camara (si la camara tiene shake, ver scripts/camera/camera_rig.gd).
static func shake(node: Node, strength: float, duration: float) -> void:
	var camera: Camera3D = node.get_viewport().get_camera_3d()
	if camera and camera.get_parent().has_method("shake"):
		camera.get_parent().shake(strength, duration)


# --- Al lanzar ---------------------------------------------------------------

## Sigilo que gira bajo los pies, chispas que suben en espiral hasta las manos
## y un destello en las manos. power agranda todo (hechizos grandes).
static func cast(character: Node3D, color: Color, power: float = 1.0) -> void:
	var parent: Node = character.get_parent()
	var feet: Vector3 = character.global_position
	var hands: Vector3 = feet + Vector3.UP * HANDS_HEIGHT + character.global_transform.basis.z * HANDS_FORWARD
	Effects.ground_glow(parent, feet, Effects.SIGIL, Color(color, 0.75), 420.0 * power, 1.0, 0.7)
	Effects.ground_glow(parent, feet, Effects.RING, Color(color, 0.6), 300.0 * power, 0.7, -0.4)

	var motes: CPUParticles3D = Effects.particles(Effects.SPARK, true, STRIP, int(40 * power), 0.65, 46.0)
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	motes.emission_ring_axis = Vector3.UP
	motes.emission_ring_radius = 170.0 * power
	motes.emission_ring_inner_radius = 120.0 * power
	motes.emission_ring_height = 6.0
	motes.direction = Vector3.UP
	motes.spread = 6.0
	motes.initial_velocity_min = 260.0
	motes.initial_velocity_max = 440.0
	motes.gravity = Vector3.ZERO
	# Se cierran hacia el centro mientras suben, girando.
	motes.radial_accel_min = -520.0
	motes.radial_accel_max = -380.0
	motes.tangential_accel_min = 380.0
	motes.tangential_accel_max = 520.0
	motes.angle_min = -180.0
	motes.angle_max = 180.0
	motes.scale_amount_curve = Effects.curve([Vector2(0, 0.3), Vector2(0.4, 1.0), Vector2(1, 0.2)])
	motes.color_ramp = Effects.ramp([Color(color.lightened(0.4), 0.0), Color(color.lightened(0.15), 0.95), Color(color.darkened(0.2), 0.0)])
	Effects.emit_once(parent, motes, feet + Vector3.UP * 20.0, 0.55)

	var core: CPUParticles3D = _still(Effects.particles(Effects.FLARE, true, 1, 2, 0.35, 170.0 * power))
	core.color_ramp = Effects.ramp([Color(1, 1, 1, 0.9), Color(color.lightened(0.4), 0.5), Color(color, 0.0)])
	Effects.emit_once(parent, core, hands, 1.0)
	var halo: CPUParticles3D = _still(Effects.particles(Effects.GLOW, true, 1, 1, 0.45, 300.0 * power))
	halo.color_ramp = Effects.ramp([Color(color, 0.0), Color(color, 0.3), Color(color, 0.0)])
	Effects.emit_once(parent, halo, hands, 1.0)
	Effects.flash(parent, hands, color.lightened(0.2), 1.0 * power, 600.0 * power, 0.4)


# --- Orbe arcano ---------------------------------------------------------------

## Arma el orbe arcano sobre un proyectil (bolt.gd con orb): nucleo blanco,
## halo que late, chispas que chisporrotean, estela y luz. Devuelve los
## sistemas de la estela (al chocar se sueltan para que se apaguen solos).
static func arcane_orb(projectile: Node3D, color: Color, size: float = 1.0) -> Array[CPUParticles3D]:
	var core: CPUParticles3D = _still(Effects.particles(Effects.FLARE, true, 1, 4, 0.16, 120.0 * size))
	core.local_coords = true
	core.angle_min = -180.0
	core.angle_max = 180.0
	core.color_ramp = Effects.ramp([Color(1, 1, 1, 0.95), Color(color.lightened(0.5), 0.85)])
	projectile.add_child(core)
	var halo: CPUParticles3D = _still(Effects.particles(Effects.GLOW, true, 1, 3, 0.22, 300.0 * size))
	halo.local_coords = true
	halo.scale_amount_min = 0.8
	halo.scale_amount_max = 1.2
	halo.color_ramp = Effects.ramp([Color(color, 0.42), Color(color, 0.28)])
	projectile.add_child(halo)
	var crackle: CPUParticles3D = Effects.particles(Effects.SPARK, true, STRIP, 14, 0.18, 46.0 * size)
	crackle.local_coords = true
	crackle.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	crackle.emission_sphere_radius = 26.0 * size
	crackle.spread = 180.0
	crackle.initial_velocity_min = 120.0
	crackle.initial_velocity_max = 260.0
	crackle.gravity = Vector3.ZERO
	crackle.angle_min = -180.0
	crackle.angle_max = 180.0
	crackle.color_ramp = Effects.ramp([Color(1, 1, 1), color.lightened(0.3), Color(color, 0.0)])
	projectile.add_child(crackle)

	# Estela en el mundo: jirones que quedan atras y se achican.
	var trail: CPUParticles3D = Effects.particles(Effects.SOFT, true, 1, 70, 0.35, 95.0 * size)
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 14.0 * size
	trail.spread = 180.0
	trail.initial_velocity_min = 10.0
	trail.initial_velocity_max = 50.0
	trail.gravity = Vector3.ZERO
	trail.angle_min = -180.0
	trail.angle_max = 180.0
	trail.scale_amount_curve = Effects.curve([Vector2(0, 1.0), Vector2(1, 0.0)])
	trail.color_ramp = Effects.ramp([Color(color, 0.55), Color(color.darkened(0.1), 0.35), Color(color.darkened(0.4), 0.0)])
	projectile.add_child(trail)
	var streak: CPUParticles3D = Effects.particles(Effects.SOFT, true, 1, 40, 0.22, 70.0 * size)
	streak.spread = 0.0
	streak.initial_velocity_min = 0.0
	streak.initial_velocity_max = 0.0
	streak.gravity = Vector3.ZERO
	streak.scale_amount_curve = Effects.curve([Vector2(0, 1.0), Vector2(1, 0.1)])
	streak.color_ramp = Effects.ramp([Color(color.lightened(0.5), 0.75), Color(color, 0.0)])
	projectile.add_child(streak)

	var light := OmniLight3D.new()
	light.light_color = color.lightened(0.2)
	light.light_energy = 1.4 * size
	light.omni_range = 520.0 * size
	light.omni_attenuation = 0.0
	projectile.add_child(light)
	return [trail, streak]


## Impacto del orbe: destello corto, rayitos que salen disparados, un anillo
## que se abre, estrellitas y brillo en el piso.
static func arcane_impact(parent: Node, position: Vector3, color: Color, size: float = 1.0) -> void:
	var core: CPUParticles3D = _still(Effects.particles(Effects.FLARE, true, 1, 2, 0.16, 190.0 * size))
	core.color_ramp = Effects.ramp([Color(1, 1, 1, 0.9), Color(color, 0.5), Color(color, 0.0)])
	Effects.emit_once(parent, core, position, 1.0)
	var bolts: CPUParticles3D = Effects.particles(Effects.SPARK, true, STRIP, int(26 * size), 0.3, 44.0 * size)
	bolts.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	bolts.emission_sphere_radius = 20.0 * size
	bolts.spread = 180.0
	bolts.initial_velocity_min = 700.0
	bolts.initial_velocity_max = 1300.0
	bolts.damping_min = 1800.0
	bolts.damping_max = 2600.0
	bolts.gravity = Vector3.ZERO
	bolts.angle_min = -180.0
	bolts.angle_max = 180.0
	bolts.scale_amount_curve = Effects.curve([Vector2(0, 1.0), Vector2(1, 0.0)])
	bolts.color_ramp = Effects.ramp([Color(1, 1, 1), Color(color.lightened(0.2), 0.9), Color(color, 0.0)])
	Effects.emit_once(parent, bolts, position, 1.0)
	var ring: CPUParticles3D = _still(Effects.particles(Effects.RING, true, 1, 1, 0.28, 150.0 * size))
	ring.scale_amount_curve = Effects.curve([Vector2(0, 0.3), Vector2(1, 2.4)])
	ring.color_ramp = Effects.ramp([Color(color.lightened(0.5), 0.9), Color(color, 0.55), Color(color, 0.0)])
	Effects.emit_once(parent, ring, position, 1.0)
	var stars: CPUParticles3D = Effects.particles(Effects.STAR, true, 1, int(8 * size), 0.6, 50.0 * size)
	stars.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	stars.emission_sphere_radius = 90.0 * size
	stars.spread = 180.0
	stars.initial_velocity_min = 40.0
	stars.initial_velocity_max = 140.0
	stars.gravity = Vector3(0, 60.0, 0)
	stars.angular_velocity_min = -200.0
	stars.angular_velocity_max = 200.0
	stars.scale_amount_curve = Effects.curve([Vector2(0, 0.2), Vector2(0.3, 1.0), Vector2(1, 0.0)])
	stars.color_ramp = Effects.ramp([Color(1, 1, 1), color.lightened(0.3), Color(color, 0.0)])
	Effects.emit_once(parent, stars, position, 0.8)
	Effects.ground_glow(parent, Vector3(position.x, 0.0, position.z), Effects.GLOW, Color(color, 0.45), 320.0 * size, 0.45)
	Effects.flash(parent, position, color, 1.3 * size, 650.0 * size, 0.3)


## Suelta sistemas de particulas de un nodo que se va a borrar: pasan al padre
## en el mismo lugar, dejan de emitir y se borran al apagarse.
static func release(node: Node3D, systems: Array) -> void:
	var parent: Node = node.get_parent()
	if parent == null:
		return
	for system in systems:
		if not is_instance_valid(system) or system.get_parent() != node:
			continue
		var at: Transform3D = system.global_transform
		node.remove_child(system)
		parent.add_child(system)
		system.global_transform = at
		system.emitting = false
		system.get_tree().create_timer(system.lifetime + 0.1, false).timeout.connect(system.queue_free)


# --- Fuego -----------------------------------------------------------------------

## Cuerpo de la bola de fuego (y del meteoro, con power mas grande): nucleo al
## rojo blanco, halo, llamas que giran, estela de fuego, humo y brasas, y una
## luz. Devuelve {"core": [...], "trails": [...], "light": OmniLight3D}.
static func fire_body(ball: Node3D, direction: Vector3, power: float = 1.0) -> Dictionary:
	var core: Array[CPUParticles3D] = []
	var trails: Array[CPUParticles3D] = []
	var hot: CPUParticles3D = _still(Effects.particles(Effects.FLARE, true, 1, 4, 0.14, 150.0 * power))
	hot.local_coords = true
	hot.angle_min = -180.0
	hot.angle_max = 180.0
	hot.color_ramp = Effects.ramp([Color(1, 0.85, 0.55, 0.75), Color(1, 0.62, 0.28, 0.6)])
	core.append(hot)
	var halo: CPUParticles3D = _still(Effects.particles(Effects.GLOW, true, 1, 3, 0.25, 330.0 * power))
	halo.local_coords = true
	halo.scale_amount_min = 0.85
	halo.scale_amount_max = 1.15
	halo.color_ramp = Effects.ramp([Color(1.0, 0.5, 0.12, 0.35), Color(1.0, 0.32, 0.06, 0.22)])
	core.append(halo)
	var flames: CPUParticles3D = Effects.particles(Effects.FLAME, true, STRIP, int(30 * power), 0.3, 190.0 * power)
	flames.local_coords = true
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	flames.emission_sphere_radius = 26.0 * power
	flames.spread = 180.0
	flames.initial_velocity_min = 40.0
	flames.initial_velocity_max = 110.0
	flames.gravity = Vector3.ZERO
	flames.angle_min = -180.0
	flames.angle_max = 180.0
	flames.angular_velocity_min = -300.0
	flames.angular_velocity_max = 300.0
	flames.scale_amount_curve = Effects.curve([Vector2(0, 0.6), Vector2(0.3, 1.0), Vector2(1, 0.3)])
	flames.color_ramp = hot_ramp()
	core.append(flames)

	# Estela: fuego que queda atras, una veta brillante, humo y brasas.
	var trail: CPUParticles3D = Effects.particles(Effects.FIRE, true, STRIP, int(90 * power), 0.5, 170.0 * power)
	trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	trail.emission_sphere_radius = 30.0 * power
	trail.direction = -direction
	trail.spread = 20.0
	trail.initial_velocity_min = 80.0
	trail.initial_velocity_max = 240.0
	trail.gravity = Vector3(0, 220.0, 0)
	trail.angle_min = -180.0
	trail.angle_max = 180.0
	trail.angular_velocity_min = -120.0
	trail.angular_velocity_max = 120.0
	trail.scale_amount_curve = Effects.curve([Vector2(0, 1.0), Vector2(1, 0.15)])
	trail.color_ramp = hot_ramp()
	trails.append(trail)
	var streak: CPUParticles3D = Effects.particles(Effects.SOFT, true, 1, 50, 0.25, 110.0 * power)
	streak.spread = 0.0
	streak.initial_velocity_min = 0.0
	streak.initial_velocity_max = 0.0
	streak.gravity = Vector3.ZERO
	streak.scale_amount_curve = Effects.curve([Vector2(0, 1.0), Vector2(1, 0.2)])
	streak.color_ramp = Effects.ramp([Color(1, 0.78, 0.42, 0.7), Color(1, 0.45, 0.1, 0.45), Color(1, 0.3, 0.05, 0.0)])
	trails.append(streak)
	# Sin humo: con el renderizador Mobile el humo (que se mezcla, no brilla)
	# salia como manchas negras encima del fuego.
	var embers: CPUParticles3D = Effects.particles(Effects.SPARK, true, STRIP, int(30 * power), 0.8, 38.0 * power)
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 34.0 * power
	embers.spread = 180.0
	embers.initial_velocity_min = 60.0
	embers.initial_velocity_max = 240.0
	embers.gravity = Vector3(0, -700.0, 0)
	embers.scale_amount_curve = Effects.curve([Vector2(0, 1.0), Vector2(1, 0.0)])
	embers.color_ramp = Effects.ramp([Color(1, 0.95, 0.65), Color(1, 0.5, 0.12), Color(0.7, 0.15, 0.03, 0.0)])
	trails.append(embers)

	for system in core + trails:
		ball.add_child(system)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.58, 0.22)
	light.light_energy = 2.0 * power
	light.omni_range = 900.0 * power
	light.omni_attenuation = 0.0
	ball.add_child(light)
	return {"core": core, "trails": trails, "light": light}


## Explosion de fuego grande: bola de llamas, nucleo al rojo, una columna de
## fuego que sube, una ola de llamas a ras del piso, piedritas que vuelan,
## brasas, humo que sube despues (no tapa el fuego), fuego que queda ardiendo
## un rato, quemadura y sacudon de camara. power: 1 la bola de fuego, ~1.8 el
## meteoro.
static func fire_blast(parent: Node, position: Vector3, radius: float, power: float = 1.0) -> void:
	var ground := Vector3(position.x, 0.0, position.z)
	var fire: CPUParticles3D = Effects.particles(Effects.FIRE, true, STRIP, int(36 * power), 0.6, radius * 0.75)
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = radius * 0.15
	fire.spread = 180.0
	fire.initial_velocity_min = radius * 1.3
	fire.initial_velocity_max = radius * 2.6
	fire.damping_min = radius * 3.2
	fire.damping_max = radius * 4.6
	fire.gravity = Vector3(0, 260.0, 0)
	fire.angle_min = -180.0
	fire.angle_max = 180.0
	fire.angular_velocity_min = -90.0
	fire.angular_velocity_max = 90.0
	fire.scale_amount_min = 0.9
	fire.scale_amount_max = 1.5
	fire.scale_amount_curve = Effects.curve([Vector2(0, 0.5), Vector2(0.2, 1.0), Vector2(1, 0.35)])
	fire.color_ramp = hot_ramp()
	Effects.emit_once(parent, fire, position, 1.0)
	var core: CPUParticles3D = _still(Effects.particles(Effects.FLARE, true, 1, 2, 0.24, radius * 1.7))
	core.color_ramp = Effects.ramp([Color(1, 0.9, 0.65, 0.6), Color(1, 0.55, 0.18, 0.4), Color(1, 0.35, 0.08, 0.0)])
	Effects.emit_once(parent, core, position + Vector3.UP * 40.0, 1.0)

	# Sin humo (ver fire_body): en su lugar, un brillo naranja tenue que sube.
	var haze: CPUParticles3D = Effects.particles(Effects.GLOW, true, 1, int(8 * power), 1.0, radius * 1.4)
	haze.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	haze.emission_sphere_radius = radius * 0.3
	haze.direction = Vector3.UP
	haze.spread = 50.0
	haze.initial_velocity_min = radius * 0.4
	haze.initial_velocity_max = radius * 0.8
	haze.damping_min = radius * 0.5
	haze.damping_max = radius * 0.8
	haze.gravity = Vector3.ZERO
	haze.color_ramp = Effects.ramp([Color(1.0, 0.45, 0.1, 0.0), Color(1.0, 0.4, 0.08, 0.3), Color(0.8, 0.2, 0.04, 0.0)])
	Effects.emit_once(parent, haze, position + Vector3.UP * 80.0, 0.8)

	var embers: CPUParticles3D = Effects.particles(Effects.SPARK, true, STRIP, int(46 * power), 1.0, 40.0)
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	embers.emission_sphere_radius = 40.0
	embers.spread = 180.0
	embers.initial_velocity_min = 500.0
	embers.initial_velocity_max = 1200.0 * power
	embers.damping_min = 300.0
	embers.damping_max = 500.0
	embers.gravity = Vector3(0, -1300.0, 0)
	embers.scale_amount_curve = Effects.curve([Vector2(0, 1.0), Vector2(1, 0.0)])
	embers.color_ramp = Effects.ramp([Color(1, 0.92, 0.6), Color(1, 0.5, 0.12), Color(0.8, 0.2, 0.05, 0.0)])
	Effects.emit_once(parent, embers, position, 1.0)
	# La quemadura aparece cuando baja el fuego: de entrada se veia como un
	# agujero negro en medio de la explosion.
	parent.get_tree().create_timer(0.35, false).timeout.connect(func() -> void:
		if is_instance_valid(parent):
			Effects.scorch(parent, ground, radius * 0.6 * power, Color(0.06, 0.04, 0.03, 0.6), 6.0))

	var column: CPUParticles3D = Effects.particles(Effects.FIRE, true, STRIP, int(26 * power), 0.7, radius * 0.9)
	column.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	column.emission_sphere_radius = radius * 0.2
	column.direction = Vector3.UP
	column.spread = 22.0
	column.initial_velocity_min = radius * 1.6
	column.initial_velocity_max = radius * 3.0 * power
	column.damping_min = radius * 2.0
	column.damping_max = radius * 3.0
	column.gravity = Vector3(0, 200.0, 0)
	column.angle_min = -180.0
	column.angle_max = 180.0
	column.scale_amount_curve = Effects.curve([Vector2(0, 0.4), Vector2(0.25, 1.0), Vector2(1, 0.5)])
	column.color_ramp = hot_ramp()
	Effects.emit_once(parent, column, ground + Vector3.UP * 40.0, 0.9)

	var debris: CPUParticles3D = Effects.particles(Effects.SOFT, false, 1, int(22 * power), 1.0, 26.0)
	debris.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	debris.emission_sphere_radius = radius * 0.25
	debris.direction = Vector3.UP
	debris.spread = 60.0
	debris.initial_velocity_min = 700.0
	debris.initial_velocity_max = 1300.0 * power
	debris.gravity = Vector3(0, -2600.0, 0)
	debris.scale_amount_min = 0.6
	debris.scale_amount_max = 1.6
	debris.color_ramp = Effects.ramp([Color(0.2, 0.14, 0.1), Color(0.12, 0.09, 0.07), Color(0.1, 0.08, 0.06, 0.0)])
	Effects.emit_once(parent, debris, ground + Vector3.UP * 30.0, 1.0)

	flame_wave(parent, ground, radius * 1.05, 0.3, int(12 + 6 * power))
	Effects.shockwave(parent, ground, Color(1.0, 0.85, 0.55, 0.8), radius * 1.5 * power, 0.28)
	Effects.ground_glow(parent, ground, Effects.GLOW, Color(1.0, 0.45, 0.1, 0.9), radius * 2.6 * power, 0.9)
	lingering_fire(parent, ground, radius * 0.7, 1.2 + 0.8 * power, int(8 * power))
	Effects.flash(parent, position + Vector3.UP * 220.0, Color(1.0, 0.6, 0.25), 2.4 * power, radius * 4.0 * power, 0.7)
	shake(parent, 9.0 * power * power, 0.22 + 0.12 * power)


## Ola de llamas que sale del centro hasta radius a ras del piso: emisores
## repartidos en circulo que se abren y van dejando fuego atras.
static func flame_wave(parent: Node, center: Vector3, radius: float, duration: float = 0.35, emitters: int = 18) -> void:
	var rig := Node3D.new()
	Effects.add_at(parent, rig, center)
	for i in emitters:
		var angle: float = TAU * i / emitters + randf_range(-0.08, 0.08)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		var flames: CPUParticles3D = Effects.particles(Effects.FLAME, true, STRIP, 10, 0.45, 150.0)
		flames.direction = Vector3.UP
		flames.spread = 14.0
		flames.initial_velocity_min = 120.0
		flames.initial_velocity_max = 260.0
		flames.gravity = Vector3(0, 200.0, 0)
		flames.scale_amount_curve = Effects.curve([Vector2(0, 0.6), Vector2(0.25, 1.0), Vector2(1, 0.1)])
		flames.color_ramp = hot_ramp()
		flames.position = dir * radius * 0.12 + Vector3.UP * 20.0
		rig.add_child(flames)
		flames.emitting = true
		var tween := flames.create_tween()
		tween.tween_property(flames, "position", dir * radius + Vector3.UP * 20.0, duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(func() -> void: flames.emitting = false)
	rig.get_tree().create_timer(duration + 0.6, false).timeout.connect(rig.queue_free)


## Fuego que queda ardiendo en el piso un rato (llamas sueltas en el area).
static func lingering_fire(parent: Node, center: Vector3, radius: float, duration: float, amount: int = 10) -> void:
	var flames: CPUParticles3D = Effects.particles(Effects.FLAME, true, STRIP, amount, 0.6, 110.0)
	# Caja chata: las llamas nacen a ras del piso.
	flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	flames.emission_box_extents = Vector3(radius, 5.0, radius)
	flames.direction = Vector3.UP
	flames.spread = 10.0
	flames.initial_velocity_min = 60.0
	flames.initial_velocity_max = 150.0
	flames.gravity = Vector3(0, 120.0, 0)
	flames.scale_amount_curve = Effects.curve([Vector2(0, 0.5), Vector2(0.3, 1.0), Vector2(1, 0.1)])
	flames.color_ramp = hot_ramp()
	Effects.add_at(parent, flames, center + Vector3.UP * 15.0)
	flames.emitting = true
	var tween := flames.create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(func() -> void: flames.emitting = false)
	tween.tween_interval(flames.lifetime + 0.1)
	tween.tween_callback(flames.queue_free)


## Anillo de llamas: ola de fuego desde el lanzador, onda, brillo y marca en
## el piso, brasas y un sacudon.
static func flame_nova(parent: Node, center: Vector3, radius: float) -> void:
	var ground := Vector3(center.x, 0.0, center.z)
	flame_wave(parent, ground, radius, 0.32, 22)
	Effects.shockwave(parent, ground, Color(1.0, 0.55, 0.2, 0.9), radius * 1.15, 0.35)
	Effects.shockwave(parent, ground, Color(1.0, 0.9, 0.6, 0.6), radius * 0.7, 0.22)
	Effects.ground_glow(parent, ground, Effects.SIGIL, Color(1.0, 0.45, 0.12, 0.9), radius * 1.6, 0.8, -0.5)
	Effects.ground_glow(parent, ground, Effects.GLOW, Color(1.0, 0.4, 0.1, 0.5), radius * 2.2, 0.7)
	var embers: CPUParticles3D = Effects.particles(Effects.SPARK, true, STRIP, 50, 0.9, 42.0)
	embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	embers.emission_ring_axis = Vector3.UP
	embers.emission_ring_radius = radius * 0.5
	embers.emission_ring_inner_radius = radius * 0.2
	embers.emission_ring_height = 10.0
	embers.direction = Vector3.UP
	embers.spread = 50.0
	embers.initial_velocity_min = 300.0
	embers.initial_velocity_max = 750.0
	embers.radial_accel_min = 300.0
	embers.radial_accel_max = 600.0
	embers.gravity = Vector3(0, -900.0, 0)
	embers.scale_amount_curve = Effects.curve([Vector2(0, 1.0), Vector2(1, 0.0)])
	embers.color_ramp = Effects.ramp([Color(1, 0.95, 0.7), Color(1, 0.55, 0.15), Color(0.8, 0.2, 0.05, 0.0)])
	Effects.emit_once(parent, embers, ground + Vector3.UP * 30.0, 0.9)
	Effects.scorch(parent, ground, radius * 0.95, Color(0.05, 0.03, 0.02, 0.55), 5.0)
	Effects.flash(parent, ground + Vector3.UP * 200.0, Color(1.0, 0.55, 0.25), 2.6, radius * 3.5, 0.6)
	shake(parent, 7.0, 0.22)


## Marca del meteoro: un sigilo de fuego que gira y se agranda, un anillo que
## se cierra sobre el area y brasas que suben, durante delay segundos.
static func meteor_mark(parent: Node, center: Vector3, radius: float, delay: float) -> void:
	var ground := Vector3(center.x, 0.0, center.z)
	var color := Color(1.0, 0.42, 0.1)
	Effects.ground_glow(parent, ground, Effects.SIGIL, Color(color, 0.8), radius * 2.1, delay + 0.25, 0.8)
	Effects.ground_glow(parent, ground, Effects.GLOW, Color(color, 0.35), radius * 2.0, delay + 0.2)
	# Anillo que se cierra del doble del area hasta el borde del area.
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(2.0, 2.0)
	plane.material = Effects._flat_material(Effects.RING, Color(1.0, 0.7, 0.35, 0.0), true)
	mesh.mesh = plane
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.scale = Vector3.ONE * radius * 2.0
	Effects.add_at(parent, mesh, ground + Vector3.UP * 14.0)
	var tween := mesh.create_tween().set_parallel(true)
	tween.tween_property(mesh, "scale", Vector3.ONE * radius * 1.05, delay).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(plane.material, "albedo_color:a", 0.95, delay * 0.6)
	tween.chain().tween_property(plane.material, "albedo_color:a", 0.0, 0.15)
	tween.chain().tween_callback(mesh.queue_free)
	var rising: CPUParticles3D = Effects.particles(Effects.SPARK, true, STRIP, 26, 0.8, 40.0)
	rising.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	rising.emission_ring_axis = Vector3.UP
	rising.emission_ring_radius = radius
	rising.emission_ring_inner_radius = radius * 0.6
	rising.emission_ring_height = 5.0
	rising.direction = Vector3.UP
	rising.spread = 8.0
	rising.initial_velocity_min = 200.0
	rising.initial_velocity_max = 420.0
	rising.gravity = Vector3.ZERO
	rising.color_ramp = Effects.ramp([Color(1, 0.9, 0.6), Color(1, 0.5, 0.12), Color(0.8, 0.2, 0.05, 0.0)])
	Effects.add_at(parent, rising, ground + Vector3.UP * 10.0)
	rising.emitting = true
	var stop := rising.create_tween()
	stop.tween_interval(maxf(delay - 0.1, 0.1))
	stop.tween_callback(func() -> void: rising.emitting = false)
	stop.tween_interval(rising.lifetime + 0.1)
	stop.tween_callback(rising.queue_free)
	# Luz que crece hasta el golpe.
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.0
	light.omni_range = radius * 3.0
	light.omni_attenuation = 0.0
	Effects.add_at(parent, light, ground + Vector3.UP * 260.0)
	var grow := light.create_tween()
	grow.tween_property(light, "light_energy", 0.7, delay).set_ease(Tween.EASE_IN)
	grow.tween_callback(light.queue_free)


# --- Mejoras -----------------------------------------------------------------------

## Burbuja de escudo alrededor del personaje mientras dura la mejora (Escudo
## Arcano, Piel de Piedra): esfera con brillo en el borde, runas que orbitan,
## circulo en el piso y chispas. stone = mas quieta y opaca (piedra).
static func protection_bubble(character: Node3D, color: Color, duration: float, stone: bool = false) -> void:
	var old: Node = character.get_node_or_null(SHIELD_NAME)
	if old:
		old.queue_free()
	var rig := Node3D.new()
	rig.name = SHIELD_NAME
	character.add_child(rig)

	var material := ShaderMaterial.new()
	material.shader = SHIELD_SHADER
	material.set_shader_parameter("color", color.lightened(0.15))
	material.set_shader_parameter("pattern", _cells())
	material.set_shader_parameter("pattern_strength", 0.6 if stone else 0.35)
	material.set_shader_parameter("flow_speed", 0.3 if stone else 1.0)
	material.set_shader_parameter("intensity", 0.0)
	var sphere := SphereMesh.new()
	sphere.radius = 230.0
	sphere.height = 520.0
	sphere.radial_segments = 32
	sphere.rings = 16
	var bubble := MeshInstance3D.new()
	bubble.mesh = sphere
	bubble.material_override = material
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bubble.position.y = 220.0
	rig.add_child(bubble)

	# Runas que giran alrededor, a distintas alturas.
	var orbit := Node3D.new()
	rig.add_child(orbit)
	for i in 3:
		var rune := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(70.0, 70.0)
		var rune_material: StandardMaterial3D = Effects._flat_material(Effects.SIGIL, Color(color.lightened(0.4), 0.9), true)
		rune_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		quad.material = rune_material
		rune.mesh = quad
		rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var angle: float = TAU * i / 3.0
		rune.position = Vector3(cos(angle) * 250.0, 120.0 + i * 110.0, sin(angle) * 250.0)
		orbit.add_child(rune)
	var spin := orbit.create_tween().set_loops()
	spin.tween_property(orbit, "rotation:y", TAU, 4.0 if stone else 2.6).from(0.0)

	var circle := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(560.0, 560.0)
	var circle_material: StandardMaterial3D = Effects._flat_material(Effects.SIGIL, Color(color, 0.0), true)
	plane.material = circle_material
	circle.mesh = plane
	circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	circle.position.y = 10.0
	rig.add_child(circle)
	var turn := circle.create_tween().set_loops()
	turn.tween_property(circle, "rotation:y", -TAU, 9.0).from(0.0)

	var motes: CPUParticles3D = Effects.particles(Effects.MAGIC if not stone else Effects.SOFT, true, STRIP if not stone else 1, 18, 1.2, 40.0)
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	motes.emission_sphere_radius = 220.0
	motes.direction = Vector3.UP
	motes.spread = 20.0
	motes.initial_velocity_min = 30.0
	motes.initial_velocity_max = 90.0
	motes.gravity = Vector3.ZERO
	motes.color_ramp = Effects.ramp([Color(color.lightened(0.5), 0.0), Color(color.lightened(0.3), 0.8), Color(color, 0.0)])
	motes.position.y = 220.0
	rig.add_child(motes)
	motes.emitting = true

	# Entra, dura y se apaga. Al final, un destello avisa que se termino.
	var fade := rig.create_tween()
	fade.tween_method(func(value: float) -> void:
		material.set_shader_parameter("intensity", value)
		circle_material.albedo_color.a = value * 0.5, 0.0, 1.0, 0.3)
	fade.tween_interval(maxf(duration - 1.0, 0.1))
	fade.tween_callback(func() -> void: motes.emitting = false)
	fade.tween_method(func(value: float) -> void:
		material.set_shader_parameter("intensity", value)
		circle_material.albedo_color.a = value * 0.5, 1.0, 0.0, 0.7)
	fade.tween_callback(rig.queue_free)


## Aura de una mejora de daño (Furia, Ojo de Halcon) mientras dura: chispas y
## llamitas del color que suben alrededor de los pies.
static func power_aura(character: Node3D, color: Color, duration: float) -> void:
	var old: Node = character.get_node_or_null(AURA_NAME)
	if old:
		old.queue_free()
	var rising: CPUParticles3D = Effects.particles(Effects.FLAME, true, STRIP, 26, 0.7, 90.0)
	rising.name = AURA_NAME
	rising.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	rising.emission_ring_axis = Vector3.UP
	rising.emission_ring_radius = 120.0
	rising.emission_ring_inner_radius = 80.0
	rising.emission_ring_height = 10.0
	rising.direction = Vector3.UP
	rising.spread = 6.0
	rising.initial_velocity_min = 180.0
	rising.initial_velocity_max = 320.0
	rising.gravity = Vector3.ZERO
	rising.scale_amount_curve = Effects.curve([Vector2(0, 0.4), Vector2(0.3, 1.0), Vector2(1, 0.1)])
	rising.color_ramp = Effects.ramp([Color(color.lightened(0.5), 0.0), Color(color.lightened(0.2), 0.75), Color(color, 0.0)])
	character.add_child(rising)
	rising.position.y = 15.0
	rising.emitting = true
	var stop := rising.create_tween()
	stop.tween_interval(duration)
	stop.tween_callback(func() -> void: rising.emitting = false)
	stop.tween_interval(rising.lifetime + 0.1)
	stop.tween_callback(rising.queue_free)


# --- Piezas ------------------------------------------------------------------------

## Degradado de fuego de los hechizos: naranja fuerte y rojo, casi sin blanco
## (con luz de dia el blanco aditivo se lava).
static func hot_ramp() -> Gradient:
	return Effects.ramp([Color(1.0, 0.85, 0.5, 0.0), Color(1.0, 0.68, 0.28, 0.95), Color(1.0, 0.38, 0.08, 0.85), Color(0.55, 0.1, 0.02, 0.0)])


# Particula que nace quieta en el centro (nucleos y halos).
static func _still(system: CPUParticles3D) -> CPUParticles3D:
	system.spread = 0.0
	system.initial_velocity_min = 0.0
	system.initial_velocity_max = 0.0
	system.gravity = Vector3.ZERO
	system.angle_min = -180.0
	system.angle_max = 180.0
	return system


# Trama celular sin costuras para la burbuja (se arma una sola vez).
static func _cells() -> NoiseTexture2D:
	if _pattern == null:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise.frequency = 0.04
		noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		_pattern = NoiseTexture2D.new()
		_pattern.noise = noise
		_pattern.width = 256
		_pattern.height = 256
		_pattern.seamless = true
		_pattern.generate_mipmaps = true
	return _pattern
