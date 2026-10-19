extends XRToolsPickable

## Стакан, который можно наполнять водой из кулера и пить.
## Уровень воды хранится в переменной fill_level (0.0 — пустой, 1.0 — полный).
## Когда стакан в руке и близко к камере игрока — вода исчезает (пьётся).

@export_range(0.0, 1.0, 0.01) var fill_level := 0.0
@export var sip_rate := 0.35  # Скорость питья (в секунду)

var _drinking := false        # Нажата ли кнопка действия
var _camera_cache: XRCamera3D = null

@onready var sip_audio: AudioStreamPlayer3D = $SipSound
@onready var amount_label: Label3D = $Amount

func _ready() -> void:
	super._ready()
	
	_find_camera()
	
	# Проверяем наличие необходимых узлов
	if not sip_audio:
		push_warning("WaterCup: Узел SipSound не найден!")
	if not amount_label:
		push_warning("WaterCup: Узел Amount не найден!")
	
	# При нажатии кнопки действия начинаем пить
	action_pressed.connect(func(_cup): _drinking = true)
	# При отпускании — прекращаем
	action_released.connect(func(_cup): _drinking = false)
	
	_update_water()

## Найти камеру игрока
func _find_camera() -> void:
	_camera_cache = XRHelpers.get_xr_camera(self)
	
	if not _camera_cache:
		_camera_cache = get_tree().root.find_child("XRCamera3D", true, false)
	
	if not _camera_cache:
		_camera_cache = get_viewport().get_camera_3d()
	
	if not _camera_cache:
		push_error("WaterCup: Камера не найдена!")

func _process(delta: float) -> void:
	if not _camera_cache:
		_find_camera()
	
	# Проверяем условия для питья
	var is_held := is_picked_up()
	var has_controller := get_picked_up_by_controller() != null
	var distance := 999.0
	var is_close := false
	
	if _camera_cache:
		distance = _camera_cache.global_position.distance_to(global_position)
		is_close = distance < 0.3  # Стакан ближе 30 см к камере
	
	var sipping := _drinking and is_held and has_controller and _camera_cache and is_close
	
	if sipping and fill_level > 0.001:
		# Уменьшаем уровень воды
		fill_level = maxf(0.0, fill_level - delta * sip_rate)
		
		# Запускаем звук питья, если ещё не играет
		if sip_audio and not sip_audio.playing:
			sip_audio.play()
	else:
		# Останавливаем звук
		if sip_audio and sip_audio.playing:
			sip_audio.stop()
	
	_update_water()

## Добавить воду в стакан (вызывается кулером при наливании)
func add_water(amount: float) -> void:
	fill_level = clampf(fill_level + amount, 0.0, 1.0)
	_update_water()

## Обновить визуальное отображение уровня воды
func _update_water() -> void:
	if not has_node("Water"):
		return
	# Показываем/скрываем меш воды
	$Water.visible = fill_level > 0.005
	# Масштабируем по высоте в зависимости от уровня
	$Water.scale.y = maxf(0.001, fill_level)
	$Water.position.y = 0.012 + fill_level * 0.055
	# Обновляем текст с объёмом в мл (250 мл — полный стакан)
	if amount_label:
		amount_label.text = "%d мл" % roundi(fill_level * 250.0)
