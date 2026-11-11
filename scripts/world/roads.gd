class_name Roads

## Caminos de tierra del mundo, como listas de puntos (x, z): los mismos que
## dibuja world/build_world.gd en el piso. Los usan las patrullas y
## emboscadas de bandidos (zona_spawn.gd).

const PATHS: Array = preload("res://world/build_world.gd").PATHS

static var _cache: Dictionary = {}


## Cada camino con un punto cada spacing unidades (en 3D, y = 0).
static func sampled(spacing: float) -> Array[PackedVector3Array]:
	if _cache.has(spacing):
		return _cache[spacing]
	var result: Array[PackedVector3Array] = []
	for path in PATHS:
		var points := PackedVector3Array()
		for i in path.size() - 1:
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var steps: int = maxi(1, ceili(a.distance_to(b) / spacing))
			for k in steps:
				var p: Vector2 = a.lerp(b, float(k) / steps)
				points.append(Vector3(p.x, 0.0, p.y))
		var last: Vector2 = path.back()
		points.append(Vector3(last.x, 0.0, last.y))
		result.append(points)
	_cache[spacing] = result
	return result
