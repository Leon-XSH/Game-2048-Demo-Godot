extends Control

var message_success = " 游戏通关！"
var message_fail = " 游戏失败！"

func set_score_label(score: String):
	$TopPanel/ScoreLabel.text = score


func show_message(is_success: bool):
	if is_success:
		$MessagePanel/MessageLabel.text = message_success
	else:
		$MessagePanel/MessageLabel.text = message_fail


func _ready() -> void:
	$MessagePanel.hide()


func _on_game_score_changed(score: Variant) -> void:
	set_score_label(str(score))


func _on_game_new_game() -> void:
	$MessagePanel.hide()


func _on_game_game_end(is_success: Variant) -> void:
	$MessagePanel.show()
	show_message(is_success)
