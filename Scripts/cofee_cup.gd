extends XRToolsPickable

## Чашка кофе. Механика: поднесение к камере при зажатой кнопке действия
## уменьшает уровень напитка. При полном опустошении показывает сообщение.

signal coffee_finished  # Сигнал для разблокировки следующих действий

@export_range(0.0, 1.0, 0.01) var fill_level := 1.0
@export var sip_rate := 0.35

var _drinking := false
var _finished := false
var _camera_cache: XRCamera3D = null

@onready var sip_audio: AudioStreamPlayer3D = $SipSound
@onready var amount_label: Label3D = $Amount
@onready var message_label: Label3D = $Message

func _ready() -> void:
	super._ready()
	
	if message_label:
		message_label.visible = false
	
	_find_camera()
	
	if not sip_audio:
		push_warning("CoffeeCup: Узел SipSound не найден!")
	if not amount_label:
		push_warning("CoffeeCup: Узел Amount не найден!")
	if not message_label:
		push_warning("CoffeeCup: Узел Message не найден!")
	
	action_pressed.connect(func(_cup): 
		_drinking = true
	)
	action_released.connect(func(_cup): 
		_drinking = false
	)
	
	_update_coffee()

func _find_camera() -> void:
	_camera_cache = XRHelpers.get_xr_camera(self)
	
	if not _camera_cache:
		_camera_cache = get_tree().root.find_child("XRCamera3D", true, false)
	
	if not _camera_cache:
		_camera_cache = get_viewport().get_camera_3d()
	
	if not _camera_cache:
		push_error("CoffeeCup: Камера не найдена!")

func _process(delta: float) -> void:
	if not _camera_cache:
		_find_camera()
	
	var is_held := is_picked_up()
	var has_controller := get_picked_up_by_controller() != null
	var distance := 999.0
	var is_close := false
	
	if _camera_cache:
		distance = _camera_cache.global_position.distance_to(global_position)
		is_close = distance < 0.35
	
	if _drinking and is_held and has_controller and _camera_cache and is_close:
		fill_level = maxf(0.0, fill_level - delta * sip_rate)
		
		if sip_audio and not sip_audio.playing:
			sip_audio.play()
		
		if fill_level <= 0.001 and not _finished:
			_finished = true
			_show_message("Кофе выпито!")
			coffee_finished.emit()
	else:
		if sip_audio and sip_audio.playing:
			sip_audio.stop()
	
	_update_coffee()

func _show_message(text: String) -> void:
	if message_label:
		message_label.text = text
		message_label.visible = true
		await get_tree().create_timer(3.0).timeout
		message_label.visible = false

func _update_coffee() -> void:
	if has_node("Cofee"):
		$Cofee.visible = fill_level > 0.005
		$Cofee.scale.y = maxf(0.001, fill_level)
		$Cofee.position.y = 0.012 + fill_level * 0.055
	
	if amount_label:
		amount_label.text = "%d мл" % roundi(fill_level * 250.0)
