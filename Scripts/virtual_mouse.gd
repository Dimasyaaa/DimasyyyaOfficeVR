extends XRToolsPickable
## Виртуальная мышь: движение физической мыши двигает курсор по экрану,
## поднятие/удар по ЛКМ = клик. Курсор рисуется внутри desktop_ui.
##
## Логика: запоминаем стартовую позицию мыши на столе, смещение мыши
## в плоскости стола маппим в координаты вьюпорта (0..1152, 0..648).

signal mouse_clicked(pos: Vector2)

## Размер вьюпорта desktop_ui (см. pc_with_ui.tscn).
@export var viewport_size: Vector2 = Vector2(1152.0, 648.0)
## Насколько далеко надо сдвинуть мышь (в метрах) чтобы пройти весь экран.
@export var travel: Vector2 = Vector2(0.25, 0.18)
## Инверсия осей (подобрать при показе преподавателю).
@export var invert_x: bool = false
@export var invert_y: bool = false

var cursor_pos: Vector2 = Vector2(576.0, 324.0)
var _grab_offset: Vector3 = Vector3.ZERO
var _grabbing: bool = false
var _ui: Control = null
var _screen: Node = null
var _cursor_rect: ColorRect = null

@onready var _lkm: MeshInstance3D = $LKM


func _ready() -> void:
	super._ready()
	picked_up.connect(_on_picked_up)
	dropped.connect(_on_dropped)
	action_pressed.connect(func(_p: XRToolsPickable) -> void: click())
	action_released.connect(func(_p: XRToolsPickable) -> void: pass)


func _on_picked_up(_pickable: XRToolsPickable) -> void:
	_grabbing = true
	_grab_offset = global_position


func _on_dropped(_pickable: XRToolsPickable) -> void:
	_grabbing = false


## GameManager связывает мышь с экраном.
func bind_ui(ui: Control) -> void:
	_ui = ui
	_cursor_rect = ui.get_node_or_null("Cursor") as ColorRect
	_move_cursor(cursor_pos)


## Привязка к новому pc_simple (SubViewport напрямую, без битого XRTools).
func bind_screen(screen: Node) -> void:
	_screen = screen
	if screen != null and screen.has_method("get_desktop"):
		bind_ui(screen.call("get_desktop") as Control)


func _process(_delta: float) -> void:
	if not _grabbing or _ui == null:
		return
	# Смещение мыши от точки захвата в локальных осях стола.
	var d: Vector3 = global_position - _grab_offset
	var nx: float = clampf(d.x / travel.x + 0.5, 0.0, 1.0)
	var nz: float = clampf(d.z / travel.y + 0.5, 0.0, 1.0)
	if invert_x:
		nx = 1.0 - nx
	if invert_y:
		nz = 1.0 - nz
	_move_cursor(Vector2(nx * viewport_size.x, nz * viewport_size.y))


func _move_cursor(p: Vector2) -> void:
	cursor_pos = p
	if _cursor_rect != null:
		_cursor_rect.position = p - _cursor_rect.size * 0.5


## Клик: вызываем когда игрок бьёт по ЛКМ (Area3D на кнопке мыши) или
## жмёт триггер держа мышь. Простейшее: клик по триггеру пока мышь в руке.
func click() -> void:
	if _screen != null and _screen.has_method("click_at"):
		mouse_clicked.emit(cursor_pos)
		_screen.call("click_at", cursor_pos)
		_flash_lkm()
		return
	if _ui == null:
		return
	mouse_clicked.emit(cursor_pos)
	_click_at(cursor_pos)
	_flash_lkm()


func _click_at(p: Vector2) -> void:
	_send_mouse_button(p, true)
	_send_mouse_button(p, false)


func _send_mouse_button(p: Vector2, pressed: bool) -> void:
	var vp: Viewport = _ui.get_viewport()
	if vp == null:
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = p
	ev.global_position = p
	vp.push_input(ev)


func hover(p: Vector2) -> void:
	var vp: Viewport = _ui.get_viewport()
	if vp == null:
		return
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	ev.relative = Vector2.ZERO
	vp.push_input(ev)


func _flash_lkm() -> void:
	if _lkm == null:
		return
	var tw := create_tween()
	tw.tween_property(_lkm, "position:y", 0.012, 0.06)
	tw.tween_property(_lkm, "position:y", 0.0222, 0.09)
