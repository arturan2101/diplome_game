extends TestCase
## Headless test for stage 46: every sound and music id the game names (in resources
## and in scripts) has a file, variants are found, the same sound does not stack, the
## on/off switches mute the buses and are saved, music loops (the jingle does not), and
## each floor style has its music.

const SCAN_DIRS: Array[String] = ["res://actors", "res://combat", "res://main", "res://ui", "res://level",
		"res://camp", "res://autoload", "res://generation", "res://director"]
const TEST_SETTINGS: String = "user://test_sound_settings.cfg"
const GAME_SCENE: String = "res://main/main.tscn"
## Music the game asks for by name in its scripts and data.
const MUSIC: Array[StringName] = [&"menu_camp", &"ruins_explore", &"flooded_explore", &"fire_explore",
		&"glade_merchant", &"combat", &"boss_warden", &"death_jingle"]
## sound ids in scripts and resources: Sound.play(&"x"), play_at(&"x"), xxx_sound = &"x".
var _call_regex: RegEx = RegEx.create_from_string("Sound\\.play(?:_at)?\\(&\"(\\w+)\"")
var _field_regex: RegEx = RegEx.create_from_string("\\w+_sound(?:: StringName)? = &\"(\\w+)\"")
var _music_regex: RegEx = RegEx.create_from_string("(?:play_music\\(|boss_music(?:: StringName)? = )&\"(\\w+)\"")


func run() -> void:
	_test_ids_exist()
	_test_variants_and_gap()
	_test_switches()
	_test_music()
	await _test_section_music()


func _test_ids_exist() -> void:
	var sounds: Dictionary = {}
	var music: Dictionary = {}
	for dir: String in SCAN_DIRS:
		_scan(dir, sounds, music)
	var missing: Array[String] = []
	for id: StringName in sounds:
		if not Sound.has_sound(id):
			missing.append("%s (%s)" % [id, sounds[id]])
	check(sounds.size() >= 60, "the game names many sounds (%d)" % sounds.size())
	check(missing.is_empty(), "every sound it names has a file: missing %s" % [missing])
	var missing_music: Array[String] = []
	for id: StringName in music.keys() + MUSIC:
		if not Sound.has_music(id):
			missing_music.append(String(id))
	check(missing_music.is_empty(), "every music track it names has a file: missing %s" % [missing_music])


func _scan(dir_path: String, sounds: Dictionary, music: Dictionary) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_scan(dir_path.path_join(sub), sounds, music)
	for file: String in dir.get_files():
		if not (file.ends_with(".gd") or file.ends_with(".tres") or file.ends_with(".tscn")):
			continue
		var path: String = dir_path.path_join(file)
		var text: String = FileAccess.get_file_as_string(path)
		for regex: RegEx in [_call_regex, _field_regex]:
			for found: RegExMatch in regex.search_all(text):
				sounds[StringName(found.get_string(1))] = file
		for found: RegExMatch in _music_regex.search_all(text):
			music[StringName(found.get_string(1))] = file


func _test_variants_and_gap() -> void:
	check(Sound._variants(&"sword_swing").size() == 3 and Sound._variants(&"coin_pickup").size() == 2
			and Sound._variants(&"dash").size() == 1, "an id finds its numbered variants, or its single file")
	check(not Sound.has_sound(&"no_such_sound") and not Sound.play(&"no_such_sound"), "an unknown id plays nothing")
	var was_on: bool = Sound.sounds_on
	Sound.sounds_on = true
	Sound._last_played.erase(&"dash")
	check(Sound.play(&"dash") and not Sound.play(&"dash"), "the same sound does not start twice at once")
	Sound.sounds_on = was_on


func _test_switches() -> void:
	var saved_path: String = Sound.settings_path
	var was_music: bool = Sound.music_on
	var was_sounds: bool = Sound.sounds_on
	Sound.settings_path = TEST_SETTINGS
	Sound.set_music_on(false)
	Sound.set_sounds_on(false)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(Sound.MUSIC_BUS))
			and AudioServer.is_bus_mute(AudioServer.get_bus_index(Sound.SFX_BUS)), "switched off, both buses are muted")
	check(not Sound.play(&"banner"), "and no effect starts")
	Sound.music_on = true
	Sound.sounds_on = true
	Sound.load_settings()
	check(not Sound.music_on and not Sound.sounds_on, "the choice is read back from the settings file")
	Sound.set_music_on(was_music)
	Sound.set_sounds_on(was_sounds)
	Sound.settings_path = saved_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))


func _test_music() -> void:
	Sound.play_music(&"combat")
	check(Sound.get_music() == &"combat", "the music changes to the asked track")
	var loop: AudioStreamOggVorbis = Sound._music_stream(&"combat") as AudioStreamOggVorbis
	var jingle: AudioStreamOggVorbis = Sound._music_stream(&"death_jingle") as AudioStreamOggVorbis
	check(loop != null and loop.loop and jingle != null and not jingle.loop, "tracks loop, the death jingle plays once")
	Sound.play_music(&"")
	check(Sound.get_music() == &"", "and fades out on request")


## The section's music follows its floor style (the full game).
func _test_section_music() -> void:
	GameManager.start_run(4600)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	check(game.section_music() == &"ruins_explore" and Sound.get_music() == &"ruins_explore",
			"the first floor plays the ruins' music")
	game.level.set_theme(game.floor_theme_for(2))
	check(game.section_music() == &"fungal_explore", "the fungal floors their own (%s)" % game.section_music())
	game.level.set_theme(game.floor_theme_for(4))
	check(game.section_music() == &"flooded_explore", "the flooded floors theirs (%s)" % game.section_music())
	game.level.set_theme(game.floor_theme_for(6))
	check(game.section_music() == &"fire_explore", "and the fire floors theirs")
	game.queue_free()
	await physics_frames(2)
	Sound.play_music(&"")
