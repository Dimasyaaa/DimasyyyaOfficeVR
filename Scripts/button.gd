extends XRToolsInteractableArea

## Интерактивная кнопка кулера.
## Отправляет сигналы activated/deactivated при нажатии и отпускании
## через XR-указатель (pointer).

signal activated
signal deactivated

@export var caption := "КНОПКА"
@export var enabled := true

var _pressing: Dictionary = {}  # Указатели, которые сейчас нажимают кнопку
var _hovering: Dictionary = {}  # Указатели, которые находятся над кнопкой
var _material: StandardMaterial3D

@onready var face: MeshInstance3D = $Face
@onready var label: Label3D = $Face/Caption

func _ready() -> void:
	label.text = caption
	# Дублируем материал, чтобы не менять оригинал
	_material = face.mesh.material.duplicate()
	face.material_override = _material
	# Подключаем обработчик событий указателя
	pointer_event.connect(_on_pointer_event)

func _process(_delta: float) -> void:
	# Если контроллер отключён во время нажатия — сбрасываем кнопку
	for pointer in _pressing.keys():
		if not is_instance_valid(pointer) or not pointer.can_process():
			_release(pointer)

func _on_pointer_event(event: XRToolsPointerEvent) -> void:
	match event.event_type:
		XRToolsPointerEvent.Type.ENTERED:
			_hovering[event.pointer] = true

		XRToolsPointerEvent.Type.EXITED:
			_hovering.erase(event.pointer)
			_release(event.pointer)

		XRToolsPointerEvent.Type.PRESSED:
			# Игнорируем нажатия, если кнопка отключена или указатель невалиден
			if not enabled or not is_instance_valid(event.pointer):
				return
			# Ограничение по расстоянию (4.2 метра)
			if event.pointer.global_position.distance_to(global_position) > 4.2:
				return
			# Если в руке есть объект с FunctionPickup — игнорируем нажатие
			var pickup = event.pointer.get_parent().get_node_or_null("FunctionPickup")
			if pickup and is_instance_valid(pickup.picked_up_object):
				return
			# Регистрируем нажатие
			if not _pressing.has(event.pointer):
				var first := _pressing.is_empty()
				_pressing[event.pointer] = true
				# Отправляем сигнал только при первом нажатии
				if first:
					activated.emit()

		XRToolsPointerEvent.Type.RELEASED:
			_release(event.pointer)

	_refresh()

## Сбросить нажатие от конкретного указателя
func _release(pointer) -> void:
	if _pressing.has(pointer):
		_pressing.erase(pointer)
		# Отправляем сигнал, когда все указатели отпущены
		if _pressing.is_empty():
			deactivated.emit()
	_refresh()

## Визуально вдавить/отпустить кнопку
func _refresh() -> void:
	if not is_instance_valid(face):
		return
	face.position.z = -0.012 if not _pressing.is_empty() else 0.0
