@tool
extends Sprite2D
class_name SizedSprite2D

@export var width: float = 0.0:
	set(v):
		if texture != null:
			v = max(0.001, v)
			# 跳过缩放计算如果值未变化（避免冗余操作）
			if abs(width - v) > 0.001:
				scale.x = v / texture.get_size().x
				width = v
		else:
			width = 0.0
		queue_redraw()
@export var height: float = 0.0:
	set(v):
		if texture != null:
			v = max(0.001, v)
			# 跳过缩放计算如果值未变化（避免冗余操作）
			if abs(height - v) > 0.001:
				scale.y = v / texture.get_size().y
				height = v
		else:
			height = 0.0
		queue_redraw()

# 记录scale的变化值
var _last_scale: Vector2 = Vector2.ZERO

func _process(_delta: float) -> void:
	# 检测到scale变化，同步更新长宽
	if _last_scale != scale:
		_last_scale = scale
		_sync_size_from_scale()

func _ready():
	_last_scale = scale
	if not texture_changed.is_connected(_on_texture_changed):
		texture_changed.connect(_on_texture_changed)
	_sync_size_from_scale()

# 根据scale反向计算width/height
func _sync_size_from_scale():
	if texture:
		# 跳过setter直接赋值，避免循环
		width = scale.x * texture.get_size().x
		height = scale.y * texture.get_size().y
		#print("Scale变化同步: ", width, "x", height)

# 从texture同步更新长宽
func _sync_size_from_texture():
	if texture and texture.get_size().x > 0 and texture.get_size().y > 0:
		# 跳过setter直接赋值避免递归
		width = texture.get_size().x
		height = texture.get_size().y
		scale = Vector2.ONE  # 重置缩放
	else:
		width = 0.0
		height = 0.0
	#print("纹理同步: %s → %.0f×%.0f" % [texture, width, height])

# 监听texture变化
func _on_texture_changed() -> void:
	_sync_size_from_texture()

# 编辑器友好：在属性变化时更新
func _property_can_revert(property: StringName) -> bool:
	return property in ["width", "height"]

func _property_get_revert(property: StringName):
	if texture == null:
		return null
	if property == "width":
		return texture.get_size().x
	elif property == "height":
		return texture.get_size().y
