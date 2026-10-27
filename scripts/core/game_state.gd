class_name GameState
extends RefCounted

var _status: String = "MENU"
var _kills: int = 0
var _score: int = 0
var _is_curse_broken: bool = false
var _has_escaped: bool = false

var status: String:
	get:
		return _status

var kills: int:
	get:
		return _kills

var score: int:
	get:
		return _score

var is_curse_broken: bool:
	get:
		return _is_curse_broken

var has_escaped: bool:
	get:
		return _has_escaped


func start_match() -> void:
	_status = "PLAYING"
	_kills = 0
	_score = 0
	_is_curse_broken = false
	_has_escaped = false


func pause_match() -> void:
	if _status == "PLAYING":
		_status = "PAUSED"


func resume_match() -> void:
	if _status == "PAUSED":
		_status = "PLAYING"


func trigger_game_over() -> void:
	_status = "GAME_OVER"


func record_kill(points: int = 100) -> void:
	_kills += 1
	_score += points


func check_wave_milestone(wave: int) -> void:
	if wave >= 10:
		_is_curse_broken = true


func escape_pit() -> void:
	if _is_curse_broken:
		_has_escaped = true
		_status = "MENU"
