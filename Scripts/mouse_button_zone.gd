extends Area3D
## Зона клика на ЛКМ физической мыши.
## Когда рука/палец/луч контроллера давит на ЛКМ — шлём click() в virtual_mouse.gd.
## Работает и с лучом FunctionPointer (pointer_event от XRTools), и с прямым
## касанием рукой (body_entered от CollisionObject руки).

signal lkm_pressed

@export var mouse_path: NodePath = ^".."


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var parent_mouse: Node = get_node_or_null(mouse_path)
	if parent_mouse != null and parent_mouse.has_signal("mouse_clicked"):
		lkm_pressed.connect(parent_mouse.click)


func _on_body_entered(_body: Node3D) -> void:
	lkm_pressed.emit()
