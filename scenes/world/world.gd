extends Node3D

enum Size { SMALL, MEDIUM, LARGE, GM_BIGCITY }

@onready var _generator = $Generator
@onready var _camera_pivot = $CameraPivot
@onready var _camera = $CameraPivot/CameraAxis/Camera3D

var _size_selected = Size.SMALL
var _rotating_left = false
var _rotating_right = false

func _process(_delta):
	if Input.is_action_just_pressed("ui_right"): _rotating_left = true
	if Input.is_action_just_released("ui_right"): _rotating_left = false
	if Input.is_action_just_pressed("ui_left"): _rotating_right = true
	if Input.is_action_just_released("ui_left"): _rotating_right = false
	
	var cam_xpos = _camera.position.x
	
	if cam_xpos < -23 && Input.is_action_pressed("ui_up"): 
		_camera.position.x += 1
	elif cam_xpos > -135 && Input.is_action_pressed("ui_down"): 
		_camera.position.x -= 1
		
	if _rotating_left: _camera_pivot.rotate_y(0.02)
	if _rotating_right: _camera_pivot.rotate_y(-0.02)

func _on_btn_generate_pressed() -> void:
	_generator.reset_city_block()
	match _size_selected:
		Size.SMALL: _generator.generate_city_block(2,3,1,1,3,2,4,2,4)
		Size.MEDIUM: _generator.generate_city_block(3,4,2,2,4,3,5,4,8)
		Size.LARGE: _generator.generate_city_block(4,5,3,3,5,4,5,5,11)
		Size.GM_BIGCITY: _generator.generate_city_block(8,6,2,10,8,6,8,6,16)

func _on_opt_size_item_selected(index: int) -> void:
	_size_selected = index as Size

func _on_btn_left_button_down() -> void: _rotating_right = true
func _on_btn_left_button_up() -> void: _rotating_right = false

func _on_btn_right_button_down() -> void: _rotating_left = true
func _on_btn_right_button_up() -> void: _rotating_left = false

func _on_btn_zoom_in_pressed() -> void:
	_camera.position.x = clamp(_camera.position.x + 20, -135, -23)
	
func _on_btn_zoom_out_pressed() -> void:
	_camera.position.x = clamp(_camera.position.x - 20, -135, -23)
