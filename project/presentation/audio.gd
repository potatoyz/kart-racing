extends Node

const Director = preload("res://addons/a3game_playable/media_director.gd")
var api: Node
var media_director: Node
var engine: AudioStreamPlayer

func _ready() -> void:
	media_director = Director.new()
	add_child(media_director)
	for event in ["countdown","race_started","race_finished","nitro_ready","nitro_used","item_picked","item_used","hit_confirmed","shield_blocked","equipped","small_boost","double_boost","air_boost","landing_boost","mini_ready","double_ready"]:
		var frequency := 440.0
		if event in ["nitro_ready","race_finished"]: frequency = 880.0
		if event == "hit_confirmed": frequency = 150.0
		if event == "small_boost": frequency = 660.0
		if event == "double_boost": frequency = 990.0
		if event == "air_boost": frequency = 780.0
		if event == "landing_boost": frequency = 520.0
		if event == "nitro_used": frequency = 220.0
		media_director.register_audio(event,tone(frequency,0.16 if event != "race_finished" else 0.65),-15.0)
	engine = AudioStreamPlayer.new()
	var stream := tone(72.0,1.0,true)
	engine.stream = stream
	engine.volume_db = -30.0
	add_child(engine)
	api.event_emitted.connect(on_event)

func tone(frequency: float, duration: float, looped: bool = false) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var count := int(duration * 22050)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	for i in count:
		var t := float(i) / 22050.0
		var envelope := 0.45 if looped else sin(PI * float(i) / count) * 0.65
		var sample := (sin(TAU*frequency*t) + sin(TAU*frequency*2.0*t)*0.25) * envelope
		samples.encode_s16(i*2,int(sample*24000.0))
	stream.data = samples
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = count
	return stream

func on_event(key: String, data: Dictionary) -> void:
	if api.snapshot().muted: return
	if int(data.get("racer",0)) != 0: return
	if key in ["countdown","race_started","race_finished","nitro_ready","nitro_used","item_picked","item_used","hit_confirmed","shield_blocked","equipped","small_boost","double_boost","air_boost","landing_boost","mini_ready","double_ready"]:
		media_director.trigger_audio(key,"gameplay",data)

func _process(_dt: float) -> void:
	var s: Dictionary = api.snapshot()
	var active: bool = s.phase == "racing" and not s.paused and not s.muted
	if active and not engine.playing: engine.play()
	if not active and engine.playing: engine.stop()
	if not s.cars.is_empty(): engine.pitch_scale = 0.65 + absf(float(s.cars[0].speed)) / 28.0
