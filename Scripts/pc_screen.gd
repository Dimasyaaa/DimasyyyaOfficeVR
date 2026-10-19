extends Node3D
## Простой диегетический экран: SubViewport + MeshInstance3D с ViewportTexture.
## Обход битого viewport_2d_in_3d.tscn (пустой ViewportTexture в инстансе).
## Управление мышью: GameManager вызывает bind_ui() и click_at().

@export var desktop_scene: PackedScene
@export var viewport_px: Vector2i = Vector2i(1152, 648)

var _vp: SubViewport = null
var _screen: MeshInstance3D = null
var _desktop: Control = null


func _ready() -> void:
	_vp = $ScreenViewport
	_screen = $ScreenMesh
	_vp.size = viewport_px
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if desktop_scene != null:
		_desktop = desktop_scene.instantiate() as Control
		_vp.add_child(_desktop)
	# Привязываем текстуру вьюпорта к экрану напрямую.
	var vt: ViewportTexture = _vp.get_texture()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = vt
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	_screen.set_surface_override_material(0, mat)


func get_desktop() -> Control:
	return _desktop


## Клик виртуальной мыши в координатах вьюпорта.
func click_at(p: Vector2) -> void:
	if _vp == null:
		return
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = p
	down.global_position = p
	_vp.push_input(down)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = p
	up.global_position = p
	_vp.push_input(up)


func hover_at(p: Vector2) -> void:
	if _vp == null:
		return
	var mv := InputEventMouseMotion.new()
	mv.position = p
	mv.global_position = p
	mv.relative = Vector2.ZERO
	_vp.push_input(mv)
