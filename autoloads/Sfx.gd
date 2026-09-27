extends Node
## Procedurally synthesised sound effects — no audio files in the project.
##
## Every sound is a short waveform built at startup into an AudioStreamWAV.
## Uses its own RandomNumberGenerator so the noise here can never perturb the
## global RNG, which daily-challenge determinism depends on.

const MIX_RATE := 22050
const VOICES := 10

var muted: bool = false

var _sounds: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_voice: int = 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 0x5EED
	_sounds["pop"] = _synth(560.0, 190.0, 0.16, 0.18, 3.2)
	_sounds["merge"] = _synth(700.0, 240.0, 0.22, 0.14, 2.6)
	_sounds["drop"] = _synth(180.0, 70.0, 0.12, 0.42, 4.5)
	_sounds["trash"] = _synth(300.0, 60.0, 0.22, 0.55, 2.4)
	_sounds["bomb"] = _synth(240.0, 45.0, 0.55, 0.62, 1.6)
	_sounds["coin"] = _synth(880.0, 1480.0, 0.26, 0.05, 2.2)
	_sounds["over"] = _synth(420.0, 110.0, 0.75, 0.10, 1.4, true)
	_sounds["click"] = _synth(1200.0, 900.0, 0.05, 0.05, 5.0)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(id: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if muted or _sounds.is_empty():
		return
	var stream: AudioStream = _sounds.get(id)
	if stream == null:
		return
	var p: AudioStreamPlayer = _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.play()


func toggle_mute() -> bool:
	muted = not muted
	return muted


## Builds one mono 16-bit voice: a pitch sweep from `f0` to `f1`, mixed with
## noise, under a polynomial decay envelope.
func _synth(f0: float, f1: float, dur: float, noise: float, decay: float, saw: bool = false) -> AudioStreamWAV:
	var n: int = int(MIX_RATE * dur)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var phase := 0.0
	for i in n:
		var t := float(i) / float(n)
		var freq: float = lerpf(f0, f1, t)
		phase += TAU * freq / float(MIX_RATE)
		var tone: float = sin(phase)
		if saw:
			tone = fposmod(phase / TAU, 1.0) * 2.0 - 1.0
		var nz: float = _rng.randf_range(-1.0, 1.0)
		var mixed: float = tone * (1.0 - noise) + nz * noise
		var env: float = pow(1.0 - t, decay)
		bytes.encode_s16(i * 2, int(clampf(mixed * env, -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = MIX_RATE
	s.stereo = false
	s.data = bytes
	return s
