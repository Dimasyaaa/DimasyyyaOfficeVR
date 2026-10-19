extends XRToolsPickable

## Степлер (задача 3 — «Организовать документы»).
##
## Механика: игрок берёт степлер (XRToolsPickable) и опускает/ударяет им по
## разбросанным листам. Пока степлер в руке, его дочерняя Area3D [StapleZone]
## отслеживает overlap с объектами группы [member staple_group]. При попадании
## листа в зону удара (и с учётом кулдауна):
##   • проигрывается анимация нажатия крышки (твин),
##   • бумага помечается как скреплённая (повторно по ней не бьём),
##   • над бумагой всплывает подсказка «✓ Скреплено»,
##   • испускается сигнал [signal stapled].
##
## Area3D выбрана вместо body_entered, т как при захвате степлер управляется
## кинематически, а листы заморожены — overlap надёжнее физического контакта.
##
## Звук скобы подключается к узлу StapleSound, если он есть в сцене.

signal stapled(target: Node)

## Группа объектов, которые можно скреплить (листы документов).
@export var staple_group: String = "paper_doc"
## Кулдаун между ударами, чтобы один взмах не скрепил всё подряд.
@export var staple_cooldown: float = 0.45

var _stapled: Dictionary = {}
var _cooldown_left: float = 0.0
var _top_rest_y: float = 0.0

@onready var _top: MeshInstance3D = $Top
@onready var _zone: Area3D = $StapleZone
@onready var _sound: AudioStreamPlayer3D = get_node_or_null("StapleSound") as AudioStreamPlayer3D


func _ready() -> void:
	super._ready()

	_top_rest_y = _top.position.y

	if _sound == null:
		push_warning("Stapler: узел StapleSound не найден (звук скобы отключён).")
	if _zone == null:
		push_warning("Stapler: узел StapleZone не найден — механика удара не будет работать!")


func _physics_process(_delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left -= _delta
		return

	# Бить можно только когда степлер в руке и зона удара существует.
	if not is_picked_up() or _zone == null:
		return

	# Ищем первый нескреплённый лист, попавший в зону удара.
	for body in _zone.get_overlapping_bodies():
		if body is Node3D and body.is_in_group(staple_group):
			_perform_staple(body)
			return


func _perform_staple(paper: Node) -> void:
	_cooldown_left = staple_cooldown

	var first_time := not _stapled.has(paper)
	_stapled[paper] = true

	_animate_press()

	if _sound and not _sound.playing:
		_sound.play()

	stapled.emit(paper)
	_spawn_feedback(paper, first_time)


## Анимация «хлопка» крышки: опускаем и возвращаем на место.
func _animate_press() -> void:
	var tween := create_tween()
	tween.tween_property(_top, "position:y", _top_rest_y - 0.012, 0.06)
	tween.tween_property(_top, "position:y", _top_rest_y, 0.09)


## Всплывающая надпись над бумагой (визуальный фидбек).
func _spawn_feedback(paper: Node, first_time: bool) -> void:
	if not (paper is Node3D):
		return

	var label := Label3D.new()
	label.text = "✓ Скреплено" if first_time else "✓"
	label.font_size = 56
	label.pixel_size = 0.0016
	label.outline_size = 10
	label.outline_modulate = Color(0, 0, 0, 1)
	label.modulate = Color(0.4, 1.0, 0.5)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 1

	get_tree().current_scene.add_child(label)
	label.global_position = (paper as Node3D).global_position + Vector3.UP * 0.13

	var fade_tween := create_tween()
	fade_tween.tween_interval(1.1)
	fade_tween.tween_property(label, "modulate:a", 0.0, 0.4)
	fade_tween.tween_callback(label.queue_free)
