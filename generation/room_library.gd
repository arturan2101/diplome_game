class_name RoomLibrary
extends RefCounted
## All room templates of the game, read from the text maps in res://rooms.
## Files are read in name order, so the library is the same on every run.

const ROOMS_DIR: String = "res://rooms"
const ROOM_EXTENSION: String = "txt"

var templates: Array[RoomTemplate] = []
## "file: problem" lines for templates that failed validation (they are left out).
var errors: PackedStringArray = PackedStringArray()

static var _default: RoomLibrary = null


## The library of res://rooms, loaded once and shared.
static func get_default() -> RoomLibrary:
	if _default == null:
		_default = RoomLibrary.new()
		_default.load_directory(ROOMS_DIR)
	return _default


func load_directory(directory: String) -> void:
	var file_names: PackedStringArray = DirAccess.get_files_at(directory)
	file_names.sort()
	for file_name: String in file_names:
		if file_name.get_extension() != ROOM_EXTENSION:
			continue
		var text: String = FileAccess.get_file_as_string(directory.path_join(file_name))
		var template: RoomTemplate = RoomTemplate.parse(text, file_name.get_basename())
		if template.is_valid():
			templates.append(template)
			continue
		for problem: String in template.errors:
			errors.append("%s: %s" % [file_name, problem])
			push_error("Room template %s: %s" % [file_name, problem])


func get_by_name(template_name: StringName) -> RoomTemplate:
	for template: RoomTemplate in templates:
		if template.name == template_name:
			return template
	return null


## Templates that have (wanted = true) or do not have (wanted = false) the tag.
func filter_by_tag(tag: StringName, wanted: bool = true) -> Array[RoomTemplate]:
	var result: Array[RoomTemplate] = []
	for template: RoomTemplate in templates:
		if template.has_tag(tag) == wanted:
			result.append(template)
	return result
