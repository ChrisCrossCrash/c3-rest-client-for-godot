extends Control

@onready var bg: ColorRect = $Background
@onready var mic_player: AudioStreamPlayer = $MicPlayer
@onready var playback_player: AudioStreamPlayer = $PlaybackPlayer

# Different clients for different servers with different capabilities.
@onready var client_llm: C3OpenAIClient = $C3OpenAIClientLLM
@onready var client_voice: C3OpenAIClient = $C3OpenAIClientVoice

var _record_effect: AudioEffectRecord
var _recording: AudioStreamWAV
var _messages: Array = []


func _ready() -> void:
	var bus_idx := AudioServer.get_bus_index("Record")
	_record_effect = AudioServer.get_bus_effect(bus_idx, 0)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		bg.color = Color.GREEN
		start_recording()
	if Input.is_action_just_released("ui_accept"):
		bg.color = Color.BLACK
		stop_recording()
	if Input.is_action_just_pressed("ui_cancel"):
		print("Resetting conversation.")
		_messages.clear()



func start_recording() -> void:
	mic_player.play()
	_record_effect.set_recording_active(true)


func stop_recording() -> void:
	_record_effect.set_recording_active(false)
	_recording = _record_effect.get_recording()
	mic_player.stop()

	if _recording == null:
		return

	# STT processing
	var transcribe_opts := C3OpenAIClient.TranscriptionOptions.new()
	transcribe_opts.model = "deepdml/faster-whisper-large-v3-turbo-ct2"
	var transcription := await client_voice.create_transcription(
		_recording, transcribe_opts
	)
	if not transcription.ok:
		push_error(transcription.error)
		return
	print(transcription.text)

	# LLM processing
	if _messages.is_empty():
		_messages.append(C3OpenAIClient.make_system_msg(
			"You always answer in rhymes."
		))
	_messages.append(C3OpenAIClient.make_user_msg(transcription.text))
	var completion := await client_llm.chat_completion(_messages)
	if not completion.ok:
		push_error(completion.error)
		return
	print(completion.content)
	_messages.append(C3OpenAIClient.make_assistant_msg(completion.content))

	# TTS processing
	var speech_opts := C3OpenAIClient.SpeechOptions.new()
	speech_opts.model = "speaches-ai/Kokoro-82M-v1.0-ONNX-fp16"
	speech_opts.voice = "af_bella"
	var speech := await client_voice.create_speech(completion.content, speech_opts)
	if not speech.ok:
		push_error(speech.error)
		return
	playback_player.stream = speech.stream
	playback_player.play()
	await playback_player.finished
