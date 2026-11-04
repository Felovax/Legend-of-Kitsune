extends Node
## Autoload "Audio": short sound effects and Resonance chords (one bell note per
## relic element). Respects the "sfx" setting. A small player pool lets sounds
## overlap. Sounds live in res://assets/audio/<name>.wav.

const POOL_SIZE := 10
## Minimum seconds between two plays of the same sound (avoids walls of noise).
const MIN_GAP := 0.05

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _last_played: Dictionary = {}
var _next: int = 0


func _ready() -> void:
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(sound: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not _enabled():
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(sound, -1.0)) < MIN_GAP:
		return
	_last_played[sound] = now
	var stream := _stream(sound)
	if stream == null or _players.is_empty():
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


## Plays the notes of the given element tags together.
func play_chord(tags: Array) -> void:
	for tag: String in tags:
		_last_played.erase("note_" + tag)
		play("note_" + tag, -6.0)


func _enabled() -> bool:
	var game := get_node_or_null("/root/Game")
	return game == null or bool(game.settings.get("sfx", true))


func _stream(sound: String) -> AudioStream:
	if not _streams.has(sound):
		var path := "res://assets/audio/%s.wav" % sound
		_streams[sound] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sound]
