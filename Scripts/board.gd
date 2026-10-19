extends Node3D

## Доска объявлений («ВАШИ ИДЕИ И ПРЕДЛОЖЕНИЯ»).
##
## Механика прикрепления (как в Job Simulator):
##   1. Игрок берёт стикер или распечатку (XRToolsPickable) в руку.
##   2. Подносит к доске и отпускает внутри AdhesiveZone → объект
##      выравнивается по плоскости доски и фиксируется (freeze = true).
##   3. Чтобы снять объект — хватаем его рукой; при захвате он отклеивается.
##
## Работает через коллизию Area3D (AdhesiveZone) и сигналы
## picked_up / dropped у XRToolsPickable — без собственной физики.
## Ось объекта с наименьшим размером («лицо») разворачивается по нормали
## доски, поэтому и стикеры, и листы ложатся на поверхность плашмя.

## Группы объектов, разрешённых для приклеивания.
@export var pin_groups: Array[String] = ["paper_res", "sticker"]
## Период сканирования новых объектов (сек). Нужен для объектов,
## появившихся динамически (например, результат печати принтером).
@export var scan_interval: float = 0.5

var _tracked: Dictionary = {}   # объект -> true (на него подписаны сигналы)
var _pinned: Dictionary = {}    # объект -> true (приклеен к доске)
var _scan_timer: float = 0.0

@onready var _zone: Area3D = $AdhesiveZone
@onready var _board: StaticBody3D = $Board


func _ready() -> void:
	if _zone == null or _board == null:
		push_error("Board: нужны дочерние узлы AdhesiveZone и Board.")
		return
	_zone.body_entered.connect(_on_zone_body_entered)
	_scan()


func _physics_process(delta: float) -> void:
	# Периодически ищем новые объекты (спавн paper_res и т.п.)
	_scan_timer += delta
	if _scan_timer >= scan_interval:
		_scan_timer = 0.0
		_scan()

	# Непрерывная проверка: свободный объект в зоне доски — приклеиваем.
	# Работает независимо от тайминга сигналов dropped/overlaps.
	for obj: XRToolsPickable in _tracked.keys():
		if not is_instance_valid(obj):
			_tracked.erase(obj)
			continue
		if _pinned.has(obj) or obj.is_picked_up():
			continue
		if _zone.overlaps_body(obj):
			_pin(obj)


func _scan() -> void:
	for group in pin_groups:
		for obj in get_tree().get_nodes_in_group(group):
			_track(obj)


func _on_zone_body_entered(body: Node) -> void:
	_track(body)


## Подписаться на сигналы объекта, если он подходит по группе и типу.
func _track(obj: Node) -> void:
	if not is_instance_valid(obj) or _tracked.has(obj):
		return
	if not obj is XRToolsPickable:
		return
	if not _belongs(obj):
		return

	_tracked[obj] = true
	var pickable := obj as XRToolsPickable
	pickable.picked_up.connect(_on_picked_up)
	pickable.dropped.connect(_on_dropped)

	# Если объект уже лежит внутри зоны (например, при старте сцены) — приклеиваем.
	if not pickable.is_picked_up() and _zone.overlaps_body(obj):
		_pin(pickable)


func _belongs(obj: Node) -> bool:
	for group in pin_groups:
		if obj.is_in_group(group):
			return true
	return false


func _on_picked_up(pickable: XRToolsPickable) -> void:
	# Взяли объект рукой — отклеиваем от доски.
	if _pinned.has(pickable):
		_unpin(pickable)


func _on_dropped(pickable: XRToolsPickable) -> void:
	if _pinned.has(pickable):
		return
	# Бросили в зоне доски — приклеиваем. Мимо — явно размораживаем,
	# чтобы объект упал, а не завис в точке броска (страховка поверх release_mode).
	if _zone.overlaps_body(pickable):
		_pin(pickable)
	else:
		pickable.freeze = false


## Приклеить объект к доске: выровнять по плоскости доски и заморозить.
func _pin(obj: XRToolsPickable) -> void:
	var stats := _visual_stats(obj)
	if stats.is_empty():
		return

	var board_basis := _board.global_transform.basis.orthonormalized()
	var normal: Vector3 = board_basis.z.normalized()

	# Передняя грань доски (лицо).
	var board_shape := (_board.get_node("CollisionShape3D") as CollisionShape3D).shape
	var board_depth := (board_shape as BoxShape3D).size.z
	var face_point: Vector3 = _board.global_position + normal * (board_depth * 0.5)

	# Проекция объекта на плоскость доски: X/Y остаются там, где отпустили.
	var obj_pos: Vector3 = obj.global_position
	var on_face: Vector3 = obj_pos - normal * (obj_pos - face_point).dot(normal)

	# Разворачиваем объект: тонкая ось («лицо») смотрит по нормали доски.
	var thin_axis: int = stats["axis"]
	var extra: Basis
	match thin_axis:
		2:
			extra = Basis.IDENTITY                  # тонкий по Z (стикер) — уже лицом
		1:
			extra = Basis(Vector3.RIGHT, PI / 2.0)   # тонкий по Y (листы) → вертикально
		_:
			extra = Basis(Vector3.UP, PI / 2.0)      # тонкий по X (редкий случай)

	# Лёгкая «житейская» кривизна: каждый объект ложится под своим углом,
	# как настоящая наклейка — а не идеально ровно по осям доски.
	var yaw := Basis(normal, randf_range(-0.42, 0.42))          # ±24° в плоскости доски
	var tilt := Basis(board_basis.x, randf_range(-0.07, 0.07))   # ±4° крен края
	var new_basis := (yaw * tilt * board_basis * extra).orthonormalized()

	# Сдвигаем объект так, чтобы визуальный центр лёг на поверхность доски,
	# а спинка прижалась вплотную (полутолщина объекта по нормали).
	var local_center: Vector3 = stats["center"]
	var world_offset: Vector3 = new_basis * local_center
	var thin_size: float = (stats["size"] as Vector3)[thin_axis]
	var target_center: Vector3 = on_face + normal * (thin_size * 0.5)

	obj.global_transform = Transform3D(new_basis, target_center - world_offset)
	obj.freeze = true
	obj.add_to_group("pinned")
	_pinned[obj] = true


## Отклеить объект от доски.
func _unpin(obj: XRToolsPickable) -> void:
	obj.remove_from_group("pinned")
	_pinned.erase(obj)
	obj.freeze = false


## Локальный AABB всех мешей объекта + ось с наименьшим размером —
## это и есть «лицо» объекта, которое ляжет на доску.
func _visual_stats(body: Node3D) -> Dictionary:
	var min_v := Vector3(INF, INF, INF)
	var max_v := Vector3(-INF, -INF, -INF)
	var found := false
	var to_body: Transform3D = body.global_transform.affine_inverse()

	for node in body.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		var aabb := mesh_node.get_aabb()
		var xform: Transform3D = to_body * mesh_node.global_transform
		for i in 8:
			var corner := aabb.position + Vector3(
				aabb.size.x if (i & 1) else 0.0,
				aabb.size.y if (i & 2) else 0.0,
				aabb.size.z if (i & 4) else 0.0)
			var p: Vector3 = xform * corner
			min_v = min_v.min(p)
			max_v = max_v.max(p)
		found = true

	if not found:
		return {}

	var size: Vector3 = max_v - min_v
	var axis := 1
	if size.x <= size.y and size.x <= size.z:
		axis = 0
	elif size.y <= size.z:
		axis = 1
	else:
		axis = 2

	return {"center": (min_v + max_v) * 0.5, "size": size, "axis": axis}
