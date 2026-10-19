extends Node3D

## Кулер для воды. Управляет кнопкой налива, визуализацией струи
## и отслеживает стакан под соплом.

@export var remaining_liters := 4.0  # Остаток воды в бутыли (литры)
var _held := false                    # Зажата ли кнопка налива
var _held_seconds := 0.0              # Сколько секунд удерживается кнопка

@onready var nozzle: Marker3D = $Nozzle
@onready var stream_mesh: MeshInstance3D = $WaterStream
@onready var status: Label3D = $Status
@onready var water_audio: AudioStreamPlayer3D = $WaterSound

func _ready() -> void:
	# Подключаем сигналы кнопки налива
	if $WaterButton:
		$WaterButton.activated.connect(func():
			_held = true
			_held_seconds = 0.0
		)
		$WaterButton.deactivated.connect(func():
			_held = false
		)
	else:
		push_error("WaterButton не найден! Проверьте дерево сцены кулера.")

	# Настраиваем зацикливание звука воды
	if water_audio and water_audio.stream is AudioStreamWAV:
		water_audio.stream = water_audio.stream.duplicate()
		water_audio.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		water_audio.stream.loop_end = roundi(
			water_audio.stream.get_length() * water_audio.stream.mix_rate
		)

func _process(delta: float) -> void:
	# Считаем время удержания кнопки
	if _held:
		_held_seconds += delta

	# Проверяем, стоит ли стакан под соплом
	var cup = _cup_under_nozzle()

	# Условия для налива: кнопка зажата, не более 3 секунд подряд,
	# стакан есть, не полный, и в бутыли есть вода
	var pouring: bool = (
		_held
		and _held_seconds < 3.0
		and cup != null
		and cup.fill_level < 0.999
		and remaining_liters > 0.001
	)

	# Показываем/скрываем меш струи
	stream_mesh.visible = pouring

	if pouring:
		# Рассчитываем объём добавляемой воды
		var added: float = minf(
			delta * 0.65,
			minf(1.0 - cup.fill_level, remaining_liters / 0.25)
		)
		cup.add_water(added)
		remaining_liters = maxf(0.0, remaining_liters - added * 0.25)

		# Растягиваем меш струи от сопла до поверхности воды в стакане
		var end: Vector3 = cup.global_position + Vector3.UP * (0.012 + cup.fill_level * 0.11)
		var length := maxf(0.02, nozzle.global_position.y - end.y)
		stream_mesh.global_position = nozzle.global_position - Vector3.UP * length * 0.5
		stream_mesh.scale.y = length

		# Запускаем звук воды, если ещё не играет
		if not water_audio.playing:
			water_audio.play()
	else:
		water_audio.stop()

	# Обновляем текст статуса
	if remaining_liters <= 0.001:
		status.text = "Бутыль пуста"
	elif not cup:
		status.text = "Поставьте стакан под кран\nВода: %.1f л" % remaining_liters
	elif cup.fill_level >= 0.999:
		status.text = "Стакан наполнен\nВозьмите его кнопкой захвата"
	else:
		status.text = "Удерживайте «Вода»\nВода: %.1f л" % remaining_liters

## Найти стакан, стоящий под соплом кулера.
## Проверяет все узлы в группе "water_cup" и возвращает тот,
## который находится в нужном диапазоне расстояний от сопла.
func _cup_under_nozzle() -> Node3D:
	for cup in get_tree().get_nodes_in_group("water_cup"):
		if not is_instance_valid(cup):
			continue
		var delta: Vector3 = nozzle.global_position - cup.global_position
		# Горизонтальное расстояние < 11 см, вертикальное от 16 до 35 см
		if Vector2(delta.x, delta.z).length() < 0.11 and delta.y > 0.16 and delta.y < 0.35:
			return cup
	return null
