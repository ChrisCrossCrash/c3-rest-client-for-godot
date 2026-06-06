extends Node3D

const CHAT_MODEL := "gpt-5.4-mini"
const TTS_MODEL := "gpt-4o-mini-tts"
const TTS_VOICE := "marin"
const STT_MODEL := "whisper-1"

@export var min_db_threshold := -40.0
@export_multiline var system_prompt := "You are a helpful AI assistant."

var _record_effect: AudioEffectRecord
var _recording: AudioStreamWAV
var _messages := []
var _light_colors := {
	"user": Color("4ac3ffff"),
	"assistant": Color("#29ffd8"),
	"idle": Color("#aaaaaa"),
	"processing": Color("ae00ffff")
}

@onready var visualizer: SoundVisualizer = $SoundVisualizer
@onready var audio_player_mic: AudioStreamPlayer = $MicPlayer
@onready var audio_player_playback: AudioStreamPlayer = $PlaybackPlayer
@onready var client: C3OpenAIClient = $C3OpenAIClient
@onready var ui_overlay: UIOverlay = $UIOverlay


func _ready() -> void:
	if not OS.get_environment("OPENAI_API_KEY"):
		ui_overlay.show_toast(
			"Error: OPENAI_API_KEY environment variable is not set.",
			Color("red")
		)

	client.api_key = OS.get_environment("OPENAI_API_KEY")

	var bus_idx := AudioServer.get_bus_index("Record")
	_record_effect = AudioServer.get_bus_effect(bus_idx, 0)

	visualizer.set_animation_state(SoundVisualizer.AnimationState.IDLE)
	visualizer.set_light_color(_light_colors["idle"])


func _process(_delta: float) -> void:
	_update_visualizer()

	if Input.is_action_just_pressed("ui_accept"):
		_start_recording()
	if Input.is_action_just_released("ui_accept"):
		_stop_recording()
	if Input.is_action_just_pressed("ui_cancel"):
		print("Resetting conversation.")
		ui_overlay.show_toast("Resetting conversation")
		_messages.clear()

	if Input.is_action_pressed("ui_accept"):
		var mic_idx := AudioServer.get_bus_index("Microphone")

		var db_left := AudioServer.get_bus_peak_volume_left_db(mic_idx, 0)
		var db_right := AudioServer.get_bus_peak_volume_right_db(mic_idx, 0)
		var db := maxf(db_left, db_right)

		var amplitude := remap(
			maxf(db, min_db_threshold),
			min_db_threshold,
			0.0,
			0.0,
			1.0
		)
		visualizer.set_amplitude(amplitude)


func _start_recording() -> void:
	audio_player_mic.play()
	_record_effect.set_recording_active(true)

	visualizer.set_animation_state(SoundVisualizer.AnimationState.AMPLITUDE_DRIVEN)
	visualizer.set_light_color(_light_colors["user"])


func _stop_recording() -> void:
	_record_effect.set_recording_active(false)
	_recording = _record_effect.get_recording()
	audio_player_mic.stop()

	visualizer.set_animation_state(SoundVisualizer.AnimationState.PULSING)
	visualizer.set_light_color(_light_colors["processing"])

	if _recording == null:
		return

	# STT processing
	var transcribe_opts := C3OpenAIClient.TranscriptionOptions.new()
	transcribe_opts.model = STT_MODEL
	var transcription := await client.create_transcription(
		_recording, transcribe_opts
	)
	if not transcription.ok:
		_handle_api_error(transcription.error)
		return
	print(transcription.text)

	if _messages.is_empty():
		_messages.append(
			C3OpenAIClient.make_system_msg(system_prompt)
		)

	_messages.append(C3OpenAIClient.make_user_msg(transcription.text))
	var chat_opts := C3OpenAIClient.ChatOptions.new()
	chat_opts.model = CHAT_MODEL
	var completion := await client.chat_completion(_messages, chat_opts)
	if not completion.ok:
		_handle_api_error(completion.error)
		return
	print(completion.content)
	_messages.append(C3OpenAIClient.make_assistant_msg(completion.content))

	# TTS processing
	var speech_opts := C3OpenAIClient.SpeechOptions.new()
	speech_opts.model = TTS_MODEL
	speech_opts.voice = TTS_VOICE
	var speech := await client.create_speech(
		completion.content, speech_opts
	)
	if not speech.ok:
		_handle_api_error(speech.error)
		return
	audio_player_playback.stream = speech.stream
	audio_player_playback.play()

	ui_overlay.show_toast(completion.content, Color("white"), speech.stream.get_length())

	visualizer.set_animation_state(SoundVisualizer.AnimationState.AMPLITUDE_DRIVEN)
	visualizer.set_light_color(_light_colors["assistant"])

	await audio_player_playback.finished

	visualizer.set_animation_state(SoundVisualizer.AnimationState.IDLE)
	visualizer.set_light_color(_light_colors["idle"])


func _update_visualizer() -> void:
	var master_idx := AudioServer.get_bus_index("Master")

	var db_left := AudioServer.get_bus_peak_volume_left_db(master_idx, 0)
	var db_right := AudioServer.get_bus_peak_volume_right_db(master_idx, 0)
	var db := maxf(db_left, db_right)

	var amplitude := remap(
		maxf(db, min_db_threshold),
		min_db_threshold,
		0.0,
		0.0,
		1.0
	)
	visualizer.set_amplitude(amplitude)


func _handle_api_error(error: C3OpenAIClient.ApiError) -> void:
	push_error(error)
	ui_overlay.show_toast(error.message, Color("red"))
