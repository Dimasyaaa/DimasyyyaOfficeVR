extends Control

## Диэгетический рабочий стол на мониторе компьютера (виртуальная ОС).
## Нажата иконка «Почта»; opening=true — окно открыто, false — закрыто.
signal mail_clicked(opening: bool)

## Нажата иконка «Задания»; opening=true — окно открыто, false — закрыто.
signal tasks_clicked(opening: bool)

## Частота мигания иконки «Задания», Гц.
@export var blink_hz: float = 1.6

const MAIL_EMPTY_TEXT: String = "Писем пока нет."

const SFX_CLICK: AudioStream = preload("res://Sound/mouse_click.mp3")
const SFX_TYPING: AudioStream = preload("res://Sound/keyboard_typing.mp3")
const SFX_LAUGH: AudioStream = preload("res://Sound/laugh.mp3")

var _blink_enabled: bool = true
var _blink_time: float = 0.0
var _clock_accum: float = 0.0
var _sfx_click: AudioStreamPlayer = null
var _sfx_typing: AudioStreamPlayer = null
var _sfx_laugh: AudioStreamPlayer = null

@onready var _mail_icon: Button = %MailIcon
@onready var _tasks_icon: Button = %TasksIcon
@onready var _mail_window: Panel = %MailWindow
@onready var _task_window: Panel = %TaskWindow
@onready var _end_window: Panel = %EndWindow
@onready var _mail_body: RichTextLabel = %MailBody
@onready var _task_text: Label = %TaskText
@onready var _clock: Label = %Clock


func _ready() -> void:
	_mail_icon.pressed.connect(_on_mail_pressed)
	_tasks_icon.pressed.connect(_on_tasks_pressed)
	(%MailClose as Button).pressed.connect(_on_mail_close_pressed)
	(%TaskClose as Button).pressed.connect(_on_task_close_pressed)
	_setup_sfx()
	_update_clock()


## Создать плееры интерфейсных звуков (клик мыши, печать, смех).
func _setup_sfx() -> void:
	_sfx_click = AudioStreamPlayer.new()
	_sfx_click.stream = SFX_CLICK
	_sfx_click.volume_db = -6.0
	add_child(_sfx_click)
	_sfx_typing = AudioStreamPlayer.new()
	_sfx_typing.stream = SFX_TYPING
	_sfx_typing.volume_db = -10.0
	add_child(_sfx_typing)
	_sfx_laugh = AudioStreamPlayer.new()
	_sfx_laugh.stream = SFX_LAUGH
	_sfx_laugh.volume_db = -14.0
	add_child(_sfx_laugh)


func _process(delta: float) -> void:
	if _blink_enabled:
		_blink_time += delta
		var pulse: float = 0.5 + 0.5 * sin(_blink_time * TAU * blink_hz)
		_tasks_icon.self_modulate = Color(1.0, 1.0, 1.0, 0.35 + 0.65 * pulse)
	_clock_accum += delta
	if _clock_accum >= 0.5:
		_clock_accum = 0.0
		_update_clock()


## Открыть или закрыть окно почты программно.
func open_mail(opening: bool) -> void:
	if _mail_window == null:
		return
	close_windows()
	_mail_window.visible = opening


## Открыть или закрыть окно заданий программно.
func open_tasks(opening: bool) -> void:
	if _task_window == null:
		return
	close_windows()
	_task_window.visible = opening


## Закрыть все окна.
func close_windows() -> void:
	if _mail_window != null:
		_mail_window.visible = false
	if _task_window != null:
		_task_window.visible = false


## Включить или выключить мигание иконки «Задания».
func set_blinking(enabled: bool) -> void:
	_blink_enabled = enabled
	if not enabled and _tasks_icon != null:
		_tasks_icon.self_modulate = Color.WHITE


## Записать текст текущего задания в окно «Задания».
func set_task_text(text: String) -> void:
	if _task_text != null:
		_task_text.text = text


## Добавить письмо в окно «Почта».
func append_mail(text: String) -> void:
	if _mail_body == null:
		return
	if _mail_body.text.is_empty() or _mail_body.text == MAIL_EMPTY_TEXT:
		_mail_body.text = text
	else:
		_mail_body.text += "\n\n" + text


## Показать финальное окно «Рабочий день окончен!».
func show_end_window() -> void:
	if _end_window == null:
		return
	close_windows()
	set_blinking(false)
	_end_window.visible = true


func _on_mail_pressed() -> void:
	var opening: bool = not _mail_window.visible
	close_windows()
	_mail_window.visible = opening
	_play_click()
	if opening:
		_play_typing_and_laugh()
	mail_clicked.emit(opening)


func _on_tasks_pressed() -> void:
	var opening: bool = not _task_window.visible
	close_windows()
	_task_window.visible = opening
	_play_click()
	tasks_clicked.emit(opening)


func _on_mail_close_pressed() -> void:
	_mail_window.visible = false
	_play_click()
	mail_clicked.emit(false)


func _on_task_close_pressed() -> void:
	_task_window.visible = false
	_play_click()
	tasks_clicked.emit(false)


## Клик мыши по элементам рабочего стола.
func _play_click() -> void:
	if _sfx_click != null:
		_sfx_click.play()


## Открытие почты: короткая «печать» и почти неслышный смех — письма шуточные.
func _play_typing_and_laugh() -> void:
	if _sfx_typing != null:
		_sfx_typing.play()
	if _sfx_laugh != null:
		# Смех начинается с задержкой — как будто игрок дочитал письмо.
		get_tree().create_timer(1.4).timeout.connect(
			func() -> void:
				if is_instance_valid(_sfx_laugh):
					_sfx_laugh.play()
		)


func _update_clock() -> void:
	_clock.text = Time.get_time_string_from_system()
