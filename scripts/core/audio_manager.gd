extends Node
class_name AudioManager

const AUDIO_BASE_PATH := "res://assets/placeholders/audio"

const BGM_CANDIDATES := {
	"bgm_menu": ["bgm_menu.ogg", "bgm_menu.wav"],
	"bgm_battle": ["bgm_battle.ogg", "bgm_battle.wav"],
	"bgm_boss": ["bgm_boss.ogg", "bgm_boss.wav"]
}

const SFX_CANDIDATES := {
	"sfx_card_click": ["sfx_card_click.wav", "sfx_card_click.ogg", "sfx_hit.wav"],
	"sfx_hit": ["sfx_hit.wav", "sfx_hit.ogg"],
	"sfx_heal": ["sfx_heal.wav", "sfx_heal.ogg", "sfx_hit.wav"],
	"sfx_victory": ["sfx_victory.wav", "sfx_victory.ogg", "sfx_hit.wav"],
	"sfx_lose": ["sfx_lose.wav", "sfx_lose.ogg", "sfx_hit.wav"]
}

var _bgm_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _bgm_cache: Dictionary = {}
var _sfx_cache: Dictionary = {}

func _ready() -> void:
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BgmPlayer"
	_bgm_player.volume_db = -14.0
	_bgm_player.finished.connect(_on_bgm_finished)
	add_child(_bgm_player)

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "SfxPlayer"
	_sfx_player.volume_db = -8.0
	_sfx_player.max_polyphony = 8
	add_child(_sfx_player)

func play_bgm(track_id: String) -> void:
	var stream := _get_bgm_stream(track_id)
	if stream == null:
		return
	if _bgm_player.stream == stream and _bgm_player.playing:
		return
	_bgm_player.stream = stream
	_bgm_player.play()

func _on_bgm_finished() -> void:
	if _bgm_player == null:
		return
	if _bgm_player.stream == null:
		return
	_bgm_player.play()

func stop_bgm() -> void:
	if _bgm_player != null and _bgm_player.playing:
		_bgm_player.stop()

func play_sfx(sfx_id: String) -> void:
	var stream := _get_sfx_stream(sfx_id)
	if stream == null:
		return
	_sfx_player.stream = stream
	_sfx_player.play()

func set_bgm_volume_db(value: float) -> void:
	if _bgm_player != null:
		_bgm_player.volume_db = value

func set_sfx_volume_db(value: float) -> void:
	if _sfx_player != null:
		_sfx_player.volume_db = value

func get_bgm_volume_db() -> float:
	if _bgm_player != null:
		return _bgm_player.volume_db
	return -14.0

func get_sfx_volume_db() -> float:
	if _sfx_player != null:
		return _sfx_player.volume_db
	return -8.0

func _get_bgm_stream(track_id: String) -> AudioStream:
	if _bgm_cache.has(track_id):
		return _bgm_cache[track_id] as AudioStream
	if not BGM_CANDIDATES.has(track_id):
		return null

	var candidates: Array = BGM_CANDIDATES[track_id]
	var stream := _load_first_stream(candidates)
	_bgm_cache[track_id] = stream
	return stream

func _get_sfx_stream(sfx_id: String) -> AudioStream:
	if _sfx_cache.has(sfx_id):
		return _sfx_cache[sfx_id] as AudioStream
	if not SFX_CANDIDATES.has(sfx_id):
		return null

	var candidates: Array = SFX_CANDIDATES[sfx_id]
	var stream := _load_first_stream(candidates)
	_sfx_cache[sfx_id] = stream
	return stream

func _load_first_stream(file_names: Array) -> AudioStream:
	for file_name in file_names:
		var path := "%s/%s" % [AUDIO_BASE_PATH, str(file_name)]
		if not ResourceLoader.exists(path):
			continue
		var stream := load(path)
		if stream is AudioStream:
			return stream as AudioStream
	return null
