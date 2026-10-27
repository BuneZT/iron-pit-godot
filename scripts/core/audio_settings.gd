class_name AudioSettings
extends GameSettings


func _init(initial: Dictionary = {}) -> void:
	super._init(initial)


static func deserialize(json_str: String) -> AudioSettings:
	var parsed: Variant = JSON.parse_string(json_str)
	if typeof(parsed) == TYPE_DICTIONARY:
		return AudioSettings.new(parsed as Dictionary)
	return AudioSettings.new()
