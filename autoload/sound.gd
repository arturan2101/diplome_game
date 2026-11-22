extends Node
## Sound effects and music (stage 46), registered as the autoload "Sound".
## Sounds are named by id: &"coin_pickup" plays assets/audio/sfx/coin_pickup.ogg, and an
## id with numbered variants (sword_swing_1.ogg, _2, _3) plays one of them at random.
## Gameplay data names its sounds (WeaponData.attack_sound, EnemyData.death_sound...),
## so a new weapon or enemy gets its sound in its resource, not in code.
## Music: one track at a time, looped, crossfaded when it changes. Two buses (SFX and
## Music) are made at start; the pause menu switches each on and off, and the choice is
## kept in user://settings.cfg.
## The pitch jitter uses its own generator: sounds never touch GameManager's random
## streams, so they cannot change a run.

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"
const EXTENSION: String = ".ogg"
const MAX_VARIANTS: int = 9
const SETTINGS_PATH: String = "user://settings.cfg"
const SETTINGS_SECTION: String = "audio"
const SFX_BUS: StringName = &"SFX"
const MUSIC_BUS: StringName = &"Music"
## Below this volume a fading track is stopped.
const SILENT_DB: float = -60.0

## How many sound effects can play at once; a new one takes the oldest voice.
@export var voices: int = 16
## The same sound does not start again within this many seconds (a pile of coins).
@export var repeat_gap: float = 0.06
## Random pitch change of every effect, up and down (0.06 = up to 6%).
@export var pitch_jitter: float = 0.06
## Loudness of the buses in dB (the music sits under the effects).
@export var sfx_volume_db: float = 0.0
@export var music_volume_db: float = -7.0
## Seconds of the crossfade when the music changes.
@export var music_fade: float = 0.8
## A sound played at a world position fades with its distance from the screen's centre
## and is not played beyond max_distance pixels.
@export var max_distance: float = 420.0
@export var distance_fade_db: float = 12.0
## Extra loudness of some sounds in dB (the files are normalised, a few are too loud or
## too soft in a fight).
@export var volume_offsets: Dictionary = {
	&"footstep_stone": -6.0, &"coin_pickup": -4.0, &"banner": -6.0, &"enemy_spawn": -3.0,
	&"bones_hit": -3.0, &"sword_hit": -2.0, &"arrow_hit_flesh": -2.0,
}

var sounds_on: bool = true
var music_on: bool = true
## Where the settings live (tests point it elsewhere).
var settings_path: String = SETTINGS_PATH

## id -> Array[AudioStream] (empty when there is no such sound).
var _streams: Dictionary = {}
var _last_played: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _music_players: Array[AudioStreamPlayer] = []
var _music_active: int = 0
var _music_id: StringName = &""
var _music_tween: Tween = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_make_bus(SFX_BUS, sfx_volume_db)
	_make_bus(MUSIC_BUS, music_volume_db)
	for _i in voices:
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = SFX_BUS
		add_child(player)
		_players.append(player)
	for _i in 2:
		var track: AudioStreamPlayer = AudioStreamPlayer.new()
		track.bus = MUSIC_BUS
		add_child(track)
		_music_players.append(track)
	load_settings()


## On quit: stop and let go of every stream (a track still playing at exit would leak).
func _exit_tree() -> void:
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	for player: AudioStreamPlayer in _players + _music_players:
		player.stop()
		player.stream = null
	_streams.clear()


## True if a sound with this id exists (with or without variants).
func has_sound(id: StringName) -> bool:
	return not _variants(id).is_empty()


## True if a music track with this id exists.
func has_music(id: StringName) -> bool:
	return id != &"" and ResourceLoader.exists(MUSIC_DIR + String(id) + EXTENSION)


## Plays the sound once. Returns true if it started (not muted, known, not repeated
## within repeat_gap).
func play(id: StringName, volume_db: float = 0.0) -> bool:
	if id == &"" or not sounds_on:
		return false
	var streams: Array = _variants(id)
	if streams.is_empty():
		return false
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(id, -INF)) < repeat_gap:
		return false
	_last_played[id] = now
	var player: AudioStreamPlayer = _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	player.stream = streams[_rng.randi_range(0, streams.size() - 1)]
	player.volume_db = volume_db + float(volume_offsets.get(id, 0.0))
	player.pitch_scale = 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter)
	player.play()
	return true


## Plays the sound for something at a world position: quieter the farther it is from
## the centre of the screen, not at all far away.
func play_at(id: StringName, world_position: Vector2) -> bool:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera == null:
		return play(id)
	var distance: float = camera.get_screen_center_position().distance_to(world_position)
	if distance > max_distance:
		return false
	return play(id, -distance_fade_db * distance / max_distance)


## Starts this track with a crossfade (looped; a "*_jingle" plays once); the same
## track keeps playing; &"" fades the music out.
func play_music(id: StringName) -> void:
	if id == _music_id:
		return
	_music_id = id
	var old: AudioStreamPlayer = _music_players[_music_active]
	_music_active = 1 - _music_active
	var new: AudioStreamPlayer = _music_players[_music_active]
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	if old.playing:
		_music_tween.tween_property(old, "volume_db", SILENT_DB, music_fade)
		_music_tween.chain().tween_callback(old.stop)
	var stream: AudioStream = _music_stream(id)
	if stream == null:
		return
	new.stream = stream
	new.volume_db = SILENT_DB
	new.play()
	_music_tween.tween_property(new, "volume_db", 0.0, music_fade)


## The track playing now (&"" for none).
func get_music() -> StringName:
	return _music_id


func set_sounds_on(on: bool) -> void:
	sounds_on = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index(SFX_BUS), not on)
	save_settings()


func set_music_on(on: bool) -> void:
	music_on = on
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MUSIC_BUS), not on)
	save_settings()


func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	if config.load(settings_path) == OK:
		sounds_on = bool(config.get_value(SETTINGS_SECTION, "sounds", true))
		music_on = bool(config.get_value(SETTINGS_SECTION, "music", true))
	AudioServer.set_bus_mute(AudioServer.get_bus_index(SFX_BUS), not sounds_on)
	AudioServer.set_bus_mute(AudioServer.get_bus_index(MUSIC_BUS), not music_on)


func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()
	config.load(settings_path)
	config.set_value(SETTINGS_SECTION, "sounds", sounds_on)
	config.set_value(SETTINGS_SECTION, "music", music_on)
	config.save(settings_path)


func _variants(id: StringName) -> Array:
	if _streams.has(id):
		return _streams[id]
	var found: Array = []
	var single: String = SFX_DIR + String(id) + EXTENSION
	if ResourceLoader.exists(single):
		found.append(load(single))
	else:
		for i in range(1, MAX_VARIANTS + 1):
			var variant: String = "%s%s_%d%s" % [SFX_DIR, id, i, EXTENSION]
			if not ResourceLoader.exists(variant):
				break
			found.append(load(variant))
	_streams[id] = found
	return found


func _music_stream(id: StringName) -> AudioStream:
	if id == &"":
		return null
	var path: String = MUSIC_DIR + String(id) + EXTENSION
	if not ResourceLoader.exists(path):
		return null
	var stream: AudioStream = load(path)
	var ogg: AudioStreamOggVorbis = stream as AudioStreamOggVorbis
	if ogg != null:
		ogg.loop = not String(id).ends_with("_jingle")
	return stream


func _make_bus(bus_name: StringName, volume_db: float) -> void:
	var index: int = AudioServer.get_bus_index(bus_name)
	if index < 0:
		AudioServer.add_bus()
		index = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus_name)
		AudioServer.set_bus_send(index, &"Master")
	AudioServer.set_bus_volume_db(index, volume_db)
