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
	# TIMING (measurement only): cost of synthesising every sound at boot.
	var t0 := Time.get_ticks_msec()
	_rng.seed = 0x5EED
	_sounds["pop"] = _synth(560.0, 190.0, 0.16, 0.18, 3.2)
	_sounds["merge"] = _synth(700.0, 240.0, 0.22, 0.14, 2.6)
	_sounds["drop"] = _synth(180.0, 70.0, 0.12, 0.42, 4.5)
	_sounds["trash"] = _synth(300.0, 60.0, 0.22, 0.55, 2.4)
	_sounds["bomb"] = _synth(240.0, 45.0, 0.55, 0.62, 1.6)
	_sounds["coin"] = _synth(880.0, 1480.0, 0.26, 0.05, 2.2)
	_sounds["over"] = _synth(420.0, 110.0, 0.75, 0.10, 1.4, true)
	_sounds["click"] = _synth(1200.0, 900.0, 0.05, 0.05, 5.0)
	# Max-tier payout: a rising major arpeggio, deliberately not another
	# single-voice sweep like "merge" so the two are never confused.
	_sounds["celebrate"] = _synth_arpeggio(392.0, 4, 0.9, 1.9)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	print("TIMING sfx_synth_ms=", Time.get_ticks_msec() - t0, " sounds=", _sounds.size())


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


## `steps` voices stacked a perfect fifth apart, each sweeping upward and
## fading in a little after the one below it, so the result reads as a rising
## arpeggio rather than a chord stab.
func _synth_arpeggio(root: float, steps: int, dur: float, decay: float) -> AudioStreamWAV:
	var n: int = int(MIX_RATE * dur)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	var phases := PackedFloat32Array()
	phases.resize(steps)
	for i in n:
		var t := float(i) / float(n)
		var env: float = pow(1.0 - t, decay)
		var v := 0.0
		for s in steps:
			var freq: float = root * pow(1.5, float(s)) * (1.0 + 0.6 * t)
			phases[s] += TAU * freq / float(MIX_RATE)
			var onset: float = clampf((t - float(s) * 0.10) / 0.30, 0.0, 1.0)
			v += sin(phases[s]) * onset
		v /= float(steps)
		bytes.encode_s16(i * 2, int(clampf(v * env, -1.0, 1.0) * 32000.0))
	return _to_stream(bytes)


func _to_stream(bytes: PackedByteArray) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = MIX_RATE
	s.stereo = false
	s.data = bytes
	return s
