extends Node3D
## GameManager: сценарий рабочего дня (задачи 1-4 + финал + песочница).
##
## Старт: этап 0 — игрок видит подсказку «Подойдите к ПК и откройте папку
##   «Задания»». Рабочий день начинается, когда игрок кликает иконку
##   «Задания» на виртуальном рабочем столе (сигнал tasks_clicked).
## Задача 1: выпить кофе (сигнал coffee_finished у CofeeCup) + открыть почту
##   (сигнал mail_clicked у desktop_ui).
## Задача 2: печать — принтер сам спавнит paper_res в OutputSlot; менеджер
##   ждёт пока игрок возьмёт распечатку в руку (is_picked_up).
## Задача 3: степлер — считаем staples_needed ударов (сигнал stapled).
## Задача 4: кулер — ждём fill_level стакана >= 0.99, затем выпивание (<= 0.05).
## Финал: show_end_window() («Рабочий день окончен! Поздравляем!») + песочница.

@export var coffee_path: NodePath = ^"CofeeCup"
@export var printer_path: NodePath = ^"Printer"
@export var stapler_path: NodePath = ^"Office/Cabins/Cabin5/Stapler"
@export var desktop_view_path: NodePath = ^"Office/Cabins/Cabin5/PCwithUI/DesktopView"
@export var mouse_path: NodePath = ^"Office/Cabins/Cabin5/Mouse"
@export var keyboard_path: NodePath = ^"Office/Cabins/Cabin5/Keyboard"

@export var staples_needed: int = 3

const INTRO_TEXT: String = "Подойдите к ПК и откройте папку «Задания».\nВсе задания дня — внутри."

const SFX_TYPING: AudioStream = preload("res://Sound/keyboard_typing.mp3")
const SFX_MOUSE_CLICK: AudioStream = preload("res://Sound/mouse_click.mp3")
const SFX_APPLAUSE: AudioStream = preload("res://Sound/applause.mp3")

var _stage: int = 0   # 0 — интро, 1..4 — задачи, 5 — песочница
var _coffee_done: bool = false
var _mail_done: bool = false
var _print_taken: bool = false
var _staples: int = 0
var _water_filled: bool = false
var _finished: bool = false

var _coffee: Node = null
var _printer: Node = null
var _stapler: Node = null
var _desktop: Control = null
var _mouse: Node = null
var _keyboard: Node = null
var _announce_label: Label3D = null
var _kbd_sfx: AudioStreamPlayer3D = null
var _mouse_sfx: AudioStreamPlayer3D = null
var _applause_sfx: AudioStreamPlayer = null


func _ready() -> void:
	_coffee = _resolve(coffee_path)
	_printer = _resolve(printer_path)
	_stapler = _resolve(stapler_path)
	_mouse = _resolve(mouse_path)
	_keyboard = _resolve(keyboard_path)
	_desktop = _find_desktop()
	_spawn_announce()
	_setup_ambient_sfx()
	_wire()
	_push_task_text()
	_announce("Подойдите к ПК и откройте папку «Задания»")


## Позиционные звуки клавиатуры/мыши + непозиционные аплодисменты финала.
func _setup_ambient_sfx() -> void:
	_applause_sfx = AudioStreamPlayer.new()
	_applause_sfx.stream = SFX_APPLAUSE
	_applause_sfx.volume_db = -4.0
	add_child(_applause_sfx)
	if _keyboard != null:
		_kbd_sfx = AudioStreamPlayer3D.new()
		_kbd_sfx.stream = SFX_TYPING
		_kbd_sfx.volume_db = -8.0
		_kbd_sfx.max_distance = 6.0
		_keyboard.add_child(_kbd_sfx)
		_keyboard.connect("picked_up", _on_keyboard_picked_up)
		_keyboard.connect("dropped", _on_keyboard_dropped)
		_keyboard.connect("action_pressed", _on_keyboard_action)
	if _mouse != null:
		_mouse_sfx = AudioStreamPlayer3D.new()
		_mouse_sfx.stream = SFX_MOUSE_CLICK
		_mouse_sfx.volume_db = -6.0
		_mouse_sfx.max_distance = 6.0
		_mouse.add_child(_mouse_sfx)
		_mouse.connect("action_pressed", _on_mouse_action)


## Клавиатуру взяли в руки — начали «печатать».
func _on_keyboard_picked_up(_pickable: Node) -> void:
	if _kbd_sfx != null and not _kbd_sfx.playing:
		_kbd_sfx.play()


## Клавиатуру отпустили — печать стоп.
func _on_keyboard_dropped(_pickable: Node) -> void:
	if _kbd_sfx != null:
		_kbd_sfx.stop()


## Кнопка действия у клавиатуры — короткий звук нажатия клавиш.
func _on_keyboard_action(_pickable: Node) -> void:
	if _kbd_sfx != null:
		_kbd_sfx.play()


## Кнопка действия у мыши — щелчок.
func _on_mouse_action(_pickable: Node) -> void:
	if _mouse_sfx != null:
		_mouse_sfx.play()


## Найти узел по NodePath из инспектора. Пути вида "CofeeCup"/"Office/..."
## трактуются как относительно родителя GameManager (как в сцене main).
func _resolve(path: NodePath) -> Node:
	if path.is_empty():
		return null
	var text_path: String = str(path)
	if text_path.begins_with("..") or text_path.begins_with("/"):
		return get_node_or_null(path)
	return get_parent().get_node_or_null(text_path)


func _find_desktop() -> Control:
	var desktop: Control = _desktop_from_view(_resolve(desktop_view_path))
	if desktop != null:
		return desktop
	# Ищем любой Viewport2DIn3D с нашим desktop_ui.
	for n in get_tree().get_nodes_in_group("desktop_ui_root"):
		if n is Control:
			return n as Control
	# Запасной вариант: глубокий поиск узла-экрана с десктопом.
	var view: Node = _find_view_with_get_desktop(get_tree().current_scene)
	return _desktop_from_view(view)


## Получить Control десктопа из узла экрана (поддержка разных сцен ПК).
func _desktop_from_view(view: Node) -> Control:
	if view == null:
		return null
	if view.has_method("get_desktop"):
		return view.call("get_desktop") as Control
	# XRToolsViewport2DIn3D: инстанс сцены десктопа.
	if view.has_method("get_scene_instance"):
		return view.call("get_scene_instance") as Control
	if "scene_node" in view:
		return view.get("scene_node") as Control
	return null


## Рекурсивно найти узел экрана с методом get_desktop()/get_scene_instance().
func _find_view_with_get_desktop(node: Node) -> Node:
	if node.has_method("get_desktop") or node.has_method("get_scene_instance"):
		return node
	for child in node.get_children():
		var found: Node = _find_view_with_get_desktop(child)
		if found != null:
			return found
	return null


func _spawn_announce() -> void:
	_announce_label = Label3D.new()
	_announce_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_announce_label.no_depth_test = true
	_announce_label.font_size = 64
	_announce_label.pixel_size = 0.002
	_announce_label.modulate = Color(1.0, 0.95, 0.6)
	_announce_label.outline_size = 12
	add_child(_announce_label)
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null:
		_announce_label.global_position = cam.global_position + -cam.global_transform.basis.z * 1.2


func _announce(text: String) -> void:
	if _announce_label != null:
		_announce_label.text = text
		_announce_label.visible = true
		await get_tree().create_timer(4.0).timeout
		if is_instance_valid(_announce_label):
			_announce_label.visible = false


func _wire() -> void:
	if _coffee != null and _coffee.has_signal("coffee_finished"):
		_coffee.connect("coffee_finished", _on_coffee_finished)
	if _stapler != null and _stapler.has_signal("stapled"):
		_stapler.connect("stapled", _on_stapled)
	# Почту и папку заданий ловим через сигналы desktop_ui.
	await get_tree().process_frame
	_desktop = _find_desktop()
	if _desktop == null:
		# Viewport инстансируется с задержкой — пробуем ещё раз.
		await get_tree().create_timer(0.5).timeout
		_desktop = _find_desktop()
	if _desktop != null:
		if _desktop.has_signal("mail_clicked"):
			_desktop.connect("mail_clicked", _on_mail_clicked)
		if _desktop.has_signal("tasks_clicked"):
			_desktop.connect("tasks_clicked", _on_tasks_clicked)
		var view: Node = _resolve(desktop_view_path)
		if _mouse != null and _mouse.has_method("bind_screen") and view != null and view.has_method("get_desktop"):
			_mouse.call("bind_screen", view)
		elif _mouse != null and _mouse.has_method("bind_ui"):
			_mouse.call("bind_ui", _desktop)
		if _mouse != null and _mouse.has_signal("mouse_clicked"):
			_mouse.connect("mouse_clicked", _on_virtual_click.bind(_desktop))
		_add_fun_mails()
		_push_task_text()
	# Следим за взятой распечаткой динамически в _process.


func _add_fun_mails() -> void:
	if _desktop != null and _desktop.has_method("append_mail"):
		_desktop.call("append_mail", "От: Босс\nТема: KPI\nУвеличить KPI на 200% к пятнице! Кофе — за свой счёт.")
		_desktop.call("append_mail", "От: Бухгалтерия\nТема: Премия\nПремия выдаётся объятиями и хорошим настроением.")
		_desktop.call("append_mail", "От: Сисадмин\nТема: Принтер\nПринтер снова зажевал отчёт. Он голоден. Покормите его бумагой.")


## Клик виртуальной мыши по иконкам: эмитим pressed, дальнейшую логику
## выполняют обработчики desktop_ui (открытие окна + сигнал mail/tasks_clicked).
func _on_virtual_click(pos: Vector2, ui: Control) -> void:
	if _finished or ui == null:
		return
	var mail_btn: Button = ui.get_node_or_null("MailIcon") as Button
	var task_btn: Button = ui.get_node_or_null("TasksIcon") as Button
	if mail_btn != null and mail_btn.get_global_rect().has_point(pos):
		mail_btn.pressed.emit()
		return
	if task_btn != null and task_btn.get_global_rect().has_point(pos):
		task_btn.pressed.emit()


func _on_coffee_finished() -> void:
	if _coffee_done:
		return
	_coffee_done = true
	_check_task1()


func _on_mail_clicked(opening: bool) -> void:
	if opening and not _mail_done:
		_mail_done = true
		_check_task1()


## Первое открытие папки «Задания» запускает рабочий день (этап 1).
func _on_tasks_clicked(opening: bool) -> void:
	if opening and _stage == 0:
		_stage = 1
		_push_task_text()
		_announce("Задача 1: выпей кофе и открой почту")
		_check_task1()


func _check_task1() -> void:
	if _stage != 1:
		return
	if _coffee_done and _mail_done:
		_advance("Задача 2: положи лист в принтер и нажми ПЕЧАТЬ")


func _on_stapled(_target: Node) -> void:
	if _stage != 3 or _finished:
		return
	_staples += 1
	if _staples >= staples_needed:
		_advance("Задача 4: налей воду из кулера и выпей")
	else:
		_push_task_text()


func _process(_delta: float) -> void:
	if _finished:
		return
	match _stage:
		2:
			# Ждём распечатку paper_res взятую в руку (печать уже сработала).
			for obj in get_tree().get_nodes_in_group("paper_res"):
				var o: Node = obj
				if o.has_method("is_picked_up") and o.call("is_picked_up"):
					_print_taken = true
					_advance("Задача 3: ударь степлером по листам %d раз(а)" % staples_needed)
					break
		4:
			for obj in get_tree().get_nodes_in_group("water_cup"):
				var cup: Node = obj
				var fill: float = float(cup.get("fill_level"))
				if fill >= 0.99:
					_water_filled = true
				if _water_filled and fill <= 0.05:
					_finish()
					break


func _advance(next_text: String) -> void:
	_stage += 1
	_push_task_text()
	_announce(next_text)


## Обновить текст окна «Задания» (интро-подсказка или чек-лист задач).
func _push_task_text() -> void:
	if _desktop == null or not _desktop.has_method("set_task_text"):
		return
	_desktop.call("set_task_text", _build_task_text())
	# Интро-этап: окно не открываем — игрок сам подходит и открывает папку.
	_desktop.call("open_tasks", _stage != 0)


## Собрать текст окна «Задания»: подсказка на старте или чек-лист дня.
func _build_task_text() -> String:
	if _stage == 0:
		return INTRO_TEXT
	var t1: bool = _coffee_done and _mail_done
	var t2: bool = _stage > 2
	var t3: bool = _stage > 3
	var t4: bool = _stage > 4
	var lines: Array[String] = []
	lines.append("Рабочий день:")
	lines.append("%s 1. Выпить кофе и просмотреть почту" % _mark(t1, _stage == 1))
	lines.append("%s 2. Распечатать отчёт" % _mark(t2, _stage == 2))
	lines.append("%s 3. Организовать документы (скобы %d/%d)" % [_mark(t3, _stage == 3), _staples, staples_needed])
	lines.append("%s 4. Сделать перерыв (кулер)" % _mark(t4, _stage == 4))
	if _stage == 5:
		lines.append("Все задачи выполнены!")
	return "\n".join(lines)


func _mark(done: bool, current: bool) -> String:
	if done:
		return "[✓]"
	return "->" if current else "[ ]"


func _finish() -> void:
	_finished = true
	_stage = 5
	if _desktop != null and _desktop.has_method("show_end_window"):
		_desktop.call("show_end_window")
	_push_task_text()
	_announce("Рабочий день окончен! Поздравляем! Дальше — песочница.")
