extends Node3D

## Принтер (задача 2 — «Распечатать отчёт»).
##
## Механика:
##   1. Нажать кнопку включения (PrintButton, луч контроллера) — принтер «взводится».
##   2. Положить чистый лист (paper, группа [member paper_group]) в область
##      приёмки (IntakeZone, Area3D).
##   3. Когда принтер включён И в лотке есть бумага — стартует печать:
##        • чистый лист из приёмника исчезает,
##        • мигают индикаторные лампы (Lamp1/Lamp2),
##        • через [member print_duration] сек. в области выдачи (OutputSlot)
##          появляется распечатанный лист (paper_res).
##
## Порядок «сначала кнопка, потом бумага» и наоборот — не важен: печать
## запускается, как только выполнены оба условия. Вся логика приёма/выдачи
## построена на коллизиях (Area3D), кнопка переиспользует button.gd.

## Сцена распечатанного листа (результат). Назначить в инспекторе.
@export var paper_res_scene: PackedScene
## Длительность печати в секундах.
@export var print_duration: float = 3.0
## Группа чистых листов, которые можно загружать в принтер.
@export var paper_group: String = "paper_doc"

var _armed := false        # Нажата ли кнопка включения
var _has_paper := false    # Лежит ли бумага в приёмнике
var _printing := false     # Идёт ли печать
var _loaded_paper: Node3D = null
var _blink_time := 0.0

@onready var _button: Area3D = $PrintButton
@onready var _intake: Area3D = $IntakeZone
@onready var _output: Marker3D = $OutputSlot
@onready var _status: Label3D = $Status
@onready var _lamp1: MeshInstance3D = $Lamp1
@onready var _lamp2: MeshInstance3D = $Lamp2
@onready var _sound: AudioStreamPlayer3D = get_node_or_null("PrintSound") as AudioStreamPlayer3D


func _ready() -> void:
	if _button and _button.has_signal("activated"):
		_button.activated.connect(_on_button_activated)
	else:
		push_warning("Printer: кнопка PrintButton не найдена.")

	if paper_res_scene == null:
		push_warning("Printer: не назначен paper_res_scene — результат печати не появится.")

	_update_status()


func _physics_process(delta: float) -> void:
	# --- Ищем бумагу в области приёмки ---
	_has_paper = false
	_loaded_paper = null
	if _intake:
		for body in _intake.get_overlapping_bodies():
			if body is Node3D and body.is_in_group(paper_group):
				_has_paper = true
				_loaded_paper = body
				break

	# --- Мигание ламп во время печати ---
	if _printing:
		_blink_time += delta
		var on := fmod(_blink_time, 0.4) < 0.2
		if _lamp1:
			_lamp1.visible = on
		if _lamp2:
			_lamp2.visible = not on

	# --- Запуск печати: включён + бумага в лотке + ещё не печатает ---
	if _armed and _has_paper and not _printing:
		_start_print()

	_update_status()


func _on_button_activated() -> void:
	_armed = true
	_update_status()


func _start_print() -> void:
	_printing = true
	_armed = false  # Кнопка отработала — разблокируем для следующего листа.

	# Убираем чистый лист из приёмника.
	if is_instance_valid(_loaded_paper):
		_loaded_paper.queue_free()
	_loaded_paper = null
	_has_paper = false

	if _sound:
		_sound.play()

	# Ждём окончания печати, затем выдаём результат.
	await get_tree().create_timer(print_duration).timeout
	_spawn_result()
	_printing = false
	_update_status()


func _spawn_result() -> void:
	if paper_res_scene == null or _output == null:
		return

	var res := paper_res_scene.instantiate()
	get_tree().current_scene.add_child(res)
	res.global_position = _output.global_position
	res.global_rotation = _output.global_rotation

	# Чтобы лист висел в лотке выдачи, пока его не возьмут.
	if res is RigidBody3D:
		res.freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC


func _update_status() -> void:
	if _status == null:
		return
	if _printing:
		_status.text = "Печать..."
	elif _has_paper and _armed:
		_status.text = "Готов к печати"
	elif _has_paper:
		_status.text = "Бумага в лотке\nНажмите «ВКЛ»"
	elif _armed:
		_status.text = "Принтер готов\nПоложите лист в лоток"
	else:
		_status.text = "Нажмите «ВКЛ»"
