extends Node2D

class_name CellGrid

@export var cell_scene: PackedScene
@export var cell_size: float = 80
@export var cell_interval: float = 23
@export var cell_move_speed = 1000
@export var num_textures: Dictionary = {
	"tile_2" : preload("res://assets/2 Tile.png"),
	"tile_4" : preload("res://assets/4 Tile.png"),
	"tile_8" : preload("res://assets/8 Tile.png"),
	"tile_16" : preload("res://assets/16 Tile.png"),
	"tile_32" : preload("res://assets/32 Tile.png"),
	"tile_64" : preload("res://assets/64 Tile.png"),
	"tile_128" : preload("res://assets/128 Tile.png"),
	"tile_256" : preload("res://assets/256 Tile.png"),
	"tile_512" : preload("res://assets/512 Tile.png"),
	"tile_1024" : preload("res://assets/1024 Tile.png"),
	"tile_2048" : preload("res://assets/2048 Tile.png"),
	"tile_4096" : preload("res://assets/4096 Tile.png"),
	"tile_8192" : preload("res://assets/8192 Tile.png")
}

enum ProcessState { IDLE, MOVING, CLEANUP, SPAWN }

var start_position: Vector2 = Vector2.ZERO
var cell_dict: Dictionary[Vector2, SizedSprite2D] = {}
var motion_list: Array = []
var spawn_list: Array = []

# _开头的属于私有变量，外界不应该直接访问
## 状态机流转规则：
## IDLE → MOVING → CLEANUP → SPAWN → IDLE
## 所有状态变更必须通过 start_cell_motion() 入口触发
var _current_state = ProcessState.IDLE
var _is_motion_all_finished = true
var _mutex: Mutex = Mutex.new()
var _shake_grid_flag = -1
var _current_shake_tween: Tween = null
var _origin_position = Vector2.ZERO

# 互斥访问_current_state
func get_current_state():
	_mutex.lock()
	var state = _current_state
	_mutex.unlock()
	return state

# 互斥修改_current_state
func change_current_state(new_state: ProcessState):
	_mutex.lock()
	_current_state = new_state
	_mutex.unlock()

# 清空棋盘
func clear_cell_grid():
	for key in cell_dict:
		var cell: SizedSprite2D = cell_dict[key]
		cell.hide()
		cell.queue_free()
	cell_dict.clear()
	motion_list.clear()
	spawn_list.clear()
	change_current_state(ProcessState.IDLE)

# 根据数组索引获取坐标
func get_position_by_grid_index(x: int, y: int) -> Vector2:
	var pos = start_position
	pos.x = pos.x + (cell_size + cell_interval) * x
	pos.y = pos.y + (cell_size + cell_interval) * y
	return pos

## 异步生成对应数字的棋子
## 警告：此方法必须满足以下调用约定：
## 1. 只能在 is_process_state_idle() == true 时调用
## 2. 必须与 start_cell_motion() 在同一线程同步连续调用
## 3. 调用期间不得插入 yield/await 或其他异步操作
func spawn_cell_by_grid_index_async(x: int, y: int, num: int):
	spawn_list.append([x, y, num])

# 在指定位置上生成对应数字的棋子
func spawn_cell_by_grid_index(x: int, y: int, num: int):
	var key = "tile_" + str(num)
	if not num_textures.has(key):
		print("Wrong Num: " + str(num))
		return
	var num_cell = cell_scene.instantiate() as SizedSprite2D
	num_cell.position = get_position_by_grid_index(x, y)
	num_cell.texture = num_textures[key]
	num_cell.height = cell_size
	num_cell.width = cell_size
	add_child(num_cell)
	cell_dict[Vector2(x, y)] = num_cell

## 将棋子移动到目标索引位置
## 警告：此方法必须满足以下调用约定：
## 1. 只能在 is_process_state_idle() == true 时调用
## 2. 必须与 start_cell_motion() 在同一线程同步连续调用
## 3. 调用期间不得插入 yield/await 或其他异步操作
func move_cell_by_grid_index_async(from: Vector2, to: Vector2, 
	is_merged: bool = false, cell_value: int = 2):
	
	if not cell_dict.has(from):
		print("No cell in " + str(from))
		return

	var is_moving = true
	motion_list.append([is_moving, from, to, is_merged, cell_value])

# 判断当前是否是IDLE状态
func is_process_state_idle():
	return get_current_state() == ProcessState.IDLE

## 开始进行棋子移动流程
## 警告：此方法必须满足以下调用约定：
## 1. 只能在 is_process_state_idle() == true 时调用
## 2. 必须与 XXX_async() 在同一线程同步连续调用
## 3. 调用期间不得插入 yield/await 或其他异步操作
func start_cell_motion():
	change_current_state(ProcessState.MOVING)

func process_motion(delta: float):
	for motion in motion_list:
		# 如果在移动过程中
		if motion[0]:
			_is_motion_all_finished = false
			var from: Vector2 = motion[1]
			var to: Vector2 = motion[2]
			var cell = cell_dict[from]
			var move_length = delta * cell_move_speed
			var to_pos = get_position_by_grid_index(to.x, to.y)
			var distance = cell.position.distance_to(to_pos)
			var direction = (to_pos - cell.position).normalized()
			if move_length >= distance:
				cell.position = to_pos
				motion[0] = false
			else:
				cell.position += direction * move_length

func process_clean_up():
	for motion in motion_list:
		var from: Vector2 = motion[1]
		var to: Vector2 = motion[2]
		var is_merged: bool = motion[3]
		var cell_value = motion[4]
		var cell = cell_dict[from]
		cell_dict.erase(from)
		if is_merged:
			if not cell_dict.has(to):
				spawn_cell_by_grid_index(to.x, to.y, cell_value)
			cell.hide()
			cell.queue_free()
		else:
			cell_dict[to] = cell
	motion_list.clear()

func process_spawn():
	for spawn in spawn_list:
		spawn_cell_by_grid_index(spawn[0], spawn[1], spawn[2])
	spawn_list.clear()

func process_shake():
	if _shake_grid_flag != -1:
		shake_cell_grid(_shake_grid_flag)
	_shake_grid_flag = -1

## 异步抖动棋盘，防止棋盘抖动时的位置变化影响到棋子移动
## 警告：此方法必须满足以下调用约定：
## 1. 只能在 is_process_state_idle() == true 时调用
## 2. 必须与 start_cell_motion() 在同一线程同步连续调用
## 3. 调用期间不得插入 yield/await 或其他异步操作
func shake_cell_grid_async(direction: GameManager.MoveDirection):
	_shake_grid_flag = direction

# 根据移动的方向，抖动棋盘
func shake_cell_grid(direction: GameManager.MoveDirection):
	# 连续晃动前，先停止上一个，并将位置复位
	if _current_shake_tween != null && _current_shake_tween.is_valid():
		_current_shake_tween.kill()
		position = _origin_position
	_current_shake_tween = create_tween().set_loops(2).set_trans(Tween.TRANS_SINE)
	match direction:
		GameManager.MoveDirection.UP:
			_current_shake_tween.tween_property(self, "position:y", _origin_position.y - 15, 0.05)
			_current_shake_tween.tween_property(self, "position:y", _origin_position.y + 15, 0.05)
			_current_shake_tween.tween_property(self, "position:y", _origin_position.y, 0.05)
		GameManager.MoveDirection.DOWN:
			_current_shake_tween.tween_property(self, "position:y", _origin_position.y + 15, 0.05)
			_current_shake_tween.tween_property(self, "position:y", _origin_position.y - 15, 0.05)
			_current_shake_tween.tween_property(self, "position:y", _origin_position.y, 0.05)
		GameManager.MoveDirection.LEFT:
			_current_shake_tween.tween_property(self, "position:x", _origin_position.x - 15, 0.05)
			_current_shake_tween.tween_property(self, "position:x", _origin_position.x + 15, 0.05)
			_current_shake_tween.tween_property(self, "position:x", _origin_position.x, 0.05)
		GameManager.MoveDirection.RIGHT:
			_current_shake_tween.tween_property(self, "position:x", _origin_position.x + 15, 0.05)
			_current_shake_tween.tween_property(self, "position:x", _origin_position.x - 15, 0.05)
			_current_shake_tween.tween_property(self, "position:x", _origin_position.x, 0.05)
	
	_current_shake_tween.finished.connect(func():
		self.position = _origin_position
		_current_shake_tween = null
	)

func _ready() -> void:
	start_position = $StartPosition.position
	_origin_position = position

func _process(delta: float) -> void:
	match get_current_state():
		ProcessState.MOVING:
			_is_motion_all_finished = true
			process_motion(delta)
			process_shake()
			if _is_motion_all_finished:
				change_current_state(ProcessState.CLEANUP)
		ProcessState.CLEANUP:
			process_clean_up()
			change_current_state(ProcessState.SPAWN)
		ProcessState.SPAWN:
			process_spawn()
			change_current_state(ProcessState.IDLE)
