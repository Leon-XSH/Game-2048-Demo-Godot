@tool
extends Node2D

# 圆角矩形
class_name RoundedRect2D

@export var width: float = 200.0:
	set(v): width = max(0, v); queue_redraw()

@export var height: float = 100.0:
	set(v): height = max(0, v); queue_redraw()

# 圆弧半径，直径不能超过width和height
@export var corner_radius: float = 20.0:
	set(v): corner_radius = clamp(v, 0, min(width, height)/2); queue_redraw()

@export var color: Color = Color(0.3, 0.5, 0.8, 1.0):
	set(v): color = v; queue_redraw()

func _draw():
	# 1. 绘制三个无重叠矩形
	var center_rect = Rect2(corner_radius, 0, width - 2 * corner_radius, height)
	var left_rect = Rect2(0, corner_radius, corner_radius, height - 2 * corner_radius)
	var right_rect = Rect2(width - corner_radius, corner_radius, corner_radius, height - 2 * corner_radius)
	draw_rect(center_rect, color)
	draw_rect(left_rect, color)
	draw_rect(right_rect, color)

	# 2. 绘制四个圆角扇形
	var corners = [
		Vector2(corner_radius, corner_radius),
		Vector2(width - corner_radius, corner_radius),
		Vector2(width - corner_radius, height - corner_radius),
		Vector2(corner_radius, height - corner_radius)
	]
	var angle_ranges = [PI, PI * 1.5, 0, PI * 0.5]
	
	for i in range(4):
		draw_circle_arc_poly(corners[i], corner_radius, angle_ranges[i], angle_ranges[i] + PI*0.5, color)

# 实心扇形绘制
func draw_circle_arc_poly(center: Vector2, radius: float, start_angle: float, end_angle: float, color: Color):
	var points = [center]
	# 圆弧上最少取八个顶点，圆弧越大取的顶点数越多
	var segments = max(8, int(radius / 2))
	
	# 获取顶点坐标，存放到多边形顶点数组中
	for i in range(segments + 1):
		var angle = start_angle + (end_angle - start_angle) * i / segments
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	
	# Godot 4 标准颜色数组初始化
	var colors = PackedColorArray()
	colors.resize(points.size())
	colors.fill(color)
	
	# 绘制实心多边形（近似扇形），颜色都统一
	draw_polygon(PackedVector2Array(points), colors)
