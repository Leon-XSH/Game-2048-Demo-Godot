extends Node2D

class_name GameManager

enum MoveDirection { UP, DOWN, LEFT, RIGHT }

@export var num_cell_scene: PackedScene

var num_grid = [
	[0, 0, 0, 0],
	[0, 0, 0, 0],
	[0, 0, 0, 0],
	[0, 0, 0, 0]
]
var score = 0
var tmp = -Vector2.ONE
var cell_changed = false
signal score_changed(score)
signal new_game()
signal game_end(is_success)

# 获取随机一个空格子的位置
func get_rand_cell_index() -> Vector2:
	var empty_cells = []
	for x in range(4):
		for y in range(4):
			if num_grid[x][y] == 0:
				empty_cells.append(Vector2(x, y))
	# 没有空格子，返回(-1, -1)
	if empty_cells.size() == 0:
		return -Vector2.ONE
	return empty_cells[randi_range(0, empty_cells.size() - 1)]

# 获取一个随机数，10%的概率为4，90%的概率为2
func get_rand_num() -> int:
	if randf() > 0.1:
		return 2
	else:
		return 4

# 清空数字棋盘
func clear_num_grid():
	for x in range(4):
		for y in range(4):
			num_grid[x][y] = 0

# 在棋盘的空格子上生成一个随机数
func spawn_rand_num_in_grid():
	var index: Vector2 = get_rand_cell_index()
	if index == -Vector2.ONE:
		print("棋盘没有空格子")
		return
	# 空格子生成随机数字
	var rand_num = get_rand_num()
	num_grid[index.x][index.y] = rand_num
	$CellGrid.spawn_cell_by_grid_index_async(index.x, index.y, rand_num)

func print_num_grid():
	print("==== Num Grid ====")
	print("——————————————————")
	print("| %d | %d | %d | %d |" % [num_grid[0][0], num_grid[1][0], 
		num_grid[2][0], num_grid[3][0]])
	print("——————————————————")
	print("| %d | %d | %d | %d |" % [num_grid[0][1], num_grid[1][1], 
		num_grid[2][1], num_grid[3][1]])
	print("——————————————————")
	print("| %d | %d | %d | %d |" % [num_grid[0][2], num_grid[1][2], 
		num_grid[2][2], num_grid[3][2]])
	print("——————————————————")
	print("| %d | %d | %d | %d |" % [num_grid[0][3], num_grid[1][3], 
		num_grid[2][3], num_grid[3][3]])
	print("——————————————————")

# 用于判断临近棋子是否可合并
func is_cell_mergeable(x, y):
	if x > 0 and num_grid[x-1][y] == num_grid[x][y]:
		return true
	if x < 3 and num_grid[x+1][y] == num_grid[x][y]:
		return true
	if y > 0 and num_grid[x][y-1] == num_grid[x][y]:
		return true
	if y < 3 and num_grid[x][y+1] == num_grid[x][y]:
		return true 
	return false

# 判断游戏是否失败
func is_game_over():
	for x in range(4):
		for y in range(4):
			# 存在空棋子，游戏未失败
			if num_grid[x][y] == 0:
				return false
			# 存在可合并的临近棋子，游戏未失败
			elif is_cell_mergeable(x, y):
				return false
	return true

# 判断游戏是否完成
func is_game_clear():
	for x in range(4):
		for y in range(4):
			# 如果检测到2048棋子，游戏完成
			if num_grid[x][y] == 2048:
				return true
	return false

# 获取需要处理的所有行/列（按移动方向）
func get_all_lines(direction: MoveDirection) -> Array:
	var lines = []
	match direction:
		MoveDirection.UP, MoveDirection.DOWN:
			# 垂直移动，获取所有列
			for x in range(4):
				var line = []
				for y in range(4):
					# 存入值和坐标, 用于记录移动和合并信息，pos为当前棋子原坐标
					# pos2为合并的棋子坐标（没有合并就标记为-1,-1），pos3为移动后的棋子坐标
					line.append({"value": num_grid[x][y], "pos": Vector2(x,y), 
						"pos2": -Vector2.ONE, "pos3": -Vector2.ONE})
				# 方向向下，提前反转元素，等到处理时可以和向上用同样的逻辑
				if direction == MoveDirection.DOWN:
					line.reverse()
				lines.append(line)
				
		MoveDirection.LEFT, MoveDirection.RIGHT:
			# 水平移动，获取所有行
			for y in range(4):
				var line = []
				for x in range(4):
					# 存入值和坐标, 用于记录移动和合并信息，pos为当前棋子原坐标
					# pos2为合并的棋子坐标（没有合并就标记为-1,-1），pos3为移动后的棋子坐标
					line.append({"value": num_grid[x][y], "pos": Vector2(x,y), 
						"pos2": -Vector2.ONE, "pos3": -Vector2.ONE})
				# 方向向右，反转元素，等到处理时可以和向左用同样的逻辑
				if direction == MoveDirection.RIGHT:
					line.reverse()
				lines.append(line)
	return lines

# 处理单行/列的移动和合并
func process_line(line: Array):
	# 去除所有的0，相当于移动
	var non_zero = []
	for cell in line:
		if cell.value != 0:
			# 需要拷贝棋子，否则修改会影响line数组内的值
			non_zero.append(cell.duplicate())
	
	# 合并值相同的棋子
	var merged = []
	# 是否可合并，防止合并后的棋子再一次合并
	var merge_avialable = true
	for cell in non_zero:
		if merged.size() == 0:
			merged.append(cell)
			merge_avialable = true
		elif merged[-1].value == cell.value and merge_avialable:
			merged[-1].value *= 2
			merged[-1].pos2 = cell.pos
			cell_changed = true
			merge_avialable = false
			score += merged[-1].value
			score_changed.emit(score)
		else:
			merged.append(cell)
			merge_avialable = true
	
	# 补充零棋子
	while merged.size() < 4:
		merged.append({"value": 0, "pos": -Vector2.ONE, 
			"pos2": -Vector2.ONE, "pos3": -Vector2.ONE})
	
	for i in range(4):
		var origin_cell = line[i]
		var merged_cell = merged[i]
		# 记录棋子合并和移动后的目标位置，可用作棋子移动合并相关动画的参数
		merged_cell.pos3 = origin_cell.pos
		# 更新数字棋盘的值
		if origin_cell.value != merged_cell.value:
			num_grid[origin_cell.pos.x][origin_cell.pos.y] = merged_cell.value
			cell_changed = true
		# 处理棋盘上的棋子的移动和合并
		if merged_cell.value != 0:
			if merged_cell.pos2 != -Vector2.ONE:
				$CellGrid.move_cell_by_grid_index_async(merged_cell.pos, 
					merged_cell.pos3, true, merged_cell.value)
				$CellGrid.move_cell_by_grid_index_async(merged_cell.pos2, 
					merged_cell.pos3, true, merged_cell.value)
			else:
				$CellGrid.move_cell_by_grid_index_async(merged_cell.pos, 
					merged_cell.pos3, false, merged_cell.value)

func handle_move_action(direction: MoveDirection) -> bool:
	print("MoveDirection: " + str(direction))
	if not $CellGrid.is_process_state_idle():
		print("Can't Move, State is not IDLE")
		return false
	
	cell_changed = false
	var lines = get_all_lines(direction)
	for line in lines:
		process_line(line)
	
	if not cell_changed:
		print("Can't Move")
		$CellGrid.shake_cell_grid_async(direction)
		$CellGrid.start_cell_motion()
		return false
	
	spawn_rand_num_in_grid()
	$CellGrid.start_cell_motion()
	
	print("After Move And Spawn:")
	print_num_grid()
	
	return true

func start_new_game():
	score = 0
	score_changed.emit(score)
	new_game.emit()
	$CellGrid.clear_cell_grid()
	clear_num_grid()
	# 开局生成两个随机棋子
	spawn_rand_num_in_grid()
	spawn_rand_num_in_grid()
	$CellGrid.start_cell_motion()
	
	print_num_grid()
	

func _ready() -> void:
	start_new_game()

func _input(event: InputEvent) -> void:
	var move_status: int = -1
	if event.is_action_pressed("move_up"):
		move_status = handle_move_action(MoveDirection.UP)
	elif event.is_action_pressed("move_down"):
		move_status = handle_move_action(MoveDirection.DOWN)
	elif event.is_action_pressed("move_left"):
		move_status = handle_move_action(MoveDirection.LEFT)
	elif event.is_action_pressed("move_right"):
		move_status = handle_move_action(MoveDirection.RIGHT)
	# 无法移动
	if move_status == 0:
		if is_game_over():
			print("游戏失败！")
			game_end.emit(false)
	elif move_status == 1:
		if is_game_clear():
			print("游戏成功！")
			game_end.emit(true)
		elif is_game_over(): # 移动后会生成新棋子，有可能导致游戏失败
			print("游戏失败！")
			game_end.emit(false)

func _on_new_game_button_pressed() -> void:
	start_new_game()


func _on_restart_button_pressed() -> void:
	start_new_game()
