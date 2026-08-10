extends Node
## 런타임 합성 SFX (autoload "Sfx") — 에셋 0개 그레이박스. jigsaw-snap에서 인양.
## _synth(길이, 기준주파수, 시작배율, 스윕시간, 감쇠, 볼륨, 클릭머리) — ratio<1 이면 상승음.

const RATE := 22050

var _players := {}


func _ready() -> void:
	_add("shot", _synth(0.04, 700.0, 1.3, 0.03, 60.0, 0.08, false))
	_add("kill", _synth(0.09, 180.0, 1.8, 0.06, 30.0, 0.3, true))
	_add("hit", _synth(0.12, 55.0, 1.5, 0.08, 18.0, 0.35, true))
	_add("ui", _synth(0.08, 520.0, 0.7, 0.06, 20.0, 0.18, false))
	_add("empty", _synth(0.12, 90.0, 1.0, 0.05, 16.0, 0.25, false))
	_add("end", _synth(0.5, 440.0, 1.0, 0.1, 5.0, 0.25, false))


func play(n: String, pitch := 1.0) -> void:
	var p: AudioStreamPlayer = _players[n]
	p.pitch_scale = pitch
	p.play()


func _add(n: String, wav: AudioStreamWAV) -> void:
	var p := AudioStreamPlayer.new()
	p.stream = wav
	add_child(p)
	_players[n] = p


## 사인 스윕(f_base×ratio → f_base, sweep_t 초) + 지수 감쇠. click=앞머리 노이즈 클릭.
func _synth(dur: float, f_base: float, ratio: float, sweep_t: float, decay: float, vol: float, click: bool) -> AudioStreamWAV:
	var count := int(RATE * dur)
	var phase := 0.0
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / RATE
		var f := f_base * (ratio - (ratio - 1.0) * minf(t / sweep_t, 1.0))
		phase += TAU * f / RATE
		var v := sin(phase) * vol * exp(-t * decay)
		if click and i < 140:
			v += (randf() * 2.0 - 1.0) * 0.5 * (1.0 - float(i) / 140.0)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	return w
