extends Node
## 런타임 합성 SFX (autoload "Sfx") — 에셋 0개 그레이박스.
## snap 은 pitch_scale 로 콤보 에스컬레이션("착!"이 점점 높아짐). fail/brk/drop 은 단발음.

const RATE := 22050

var _players := {}


func _ready() -> void:
	_add("snap", _synth(0.15, 210.0, 1.6, 0.05, 26.0, 0.4, true))
	_add("fail", _synth(0.13, 62.0, 1.4, 0.08, 18.0, 0.35, true))
	_add("brk", _synth(0.18, 75.0, 2.5, 0.16, 14.0, 0.25, false))
	_add("drop", _synth(0.10, 140.0, 2.1, 0.08, 22.0, 0.2, false))


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
