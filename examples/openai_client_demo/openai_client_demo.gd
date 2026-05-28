extends Control

# Different clients for different servers with different capabilities.
@onready var client_llm: C3OpenAIClient = $C3OpenAIClientLLM
@onready var client_voice: C3OpenAIClient = $C3OpenAIClientVoice

@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer


func _ready() -> void:
	var models_res := await client_llm.get_models()
	if not models_res.ok:
		print(models_res.error)
		get_tree().quit()
	print(models_res.ids)

	# --- Chat (LLM server) ---
	var messages = [
		C3OpenAIClient.make_system_msg(
			"You are a funny assistant that only responds in rhymes."
		),
		C3OpenAIClient.make_user_msg("What is the meaning of life?")
	]
	var opts := C3OpenAIClient.ChatOptions.new()
	opts.model = models_res.ids[0]
	var completion_res := await client_llm.chat_completion(messages, opts)
	if not completion_res.ok:
		print(completion_res.error)
		get_tree().quit()
	print(completion_res.content)

	# --- Vision (LLM server) ---
	var img := (
		(load("res://examples/openai_client_demo/test-img.jpg") as Texture2D)
		. get_image()
	)
	var b64 := Marshalls.raw_to_base64(img.save_jpg_to_buffer())
	var vision_messages = [
		C3OpenAIClient.make_user_msg_with_parts([
			C3OpenAIClient.make_part_text("What do you see in this image?"),
			C3OpenAIClient.make_part_image_url("data:image/jpeg;base64," + b64),
		])
	]
	var vision_completion_res := await client_llm.chat_completion(
		vision_messages, opts
	)
	if not vision_completion_res.ok:
		print(vision_completion_res.error)
		get_tree().quit()
	print(vision_completion_res.content)

	# --- Text-to-speech (voice server) ---
	var speech_opts := C3OpenAIClient.SpeechOptions.new()
	speech_opts.model = "speaches-ai/Kokoro-82M-v1.0-ONNX-fp16"
	speech_opts.voice = "af_heart"
	var speech_res := await client_voice.create_speech(completion_res.content, speech_opts)
	if not speech_res.ok:
		print(speech_res.error)
		get_tree().quit()
	audio_stream_player.stream = speech_res.stream
	audio_stream_player.play()
	await audio_stream_player.finished

	# --- Speech-to-text (voice server) ---
	var clip := load("res://examples/openai_client_demo/demo-speech.mp3")
	var transcribe_opts := C3OpenAIClient.TranscriptionOptions.new()
	transcribe_opts.model = "deepdml/faster-whisper-large-v3-turbo-ct2"
	var transcription_res := await client_voice.create_transcription(
		clip, transcribe_opts
	)
	if not transcription_res.ok:
		print(transcription_res.error)
		get_tree().quit()
	print(transcription_res.text)
	await audio_stream_player.finished
	get_tree().quit()


func _on_llm_request_failed(error: Dictionary) -> void:
	print(error)


func _on_voice_request_failed(error: Dictionary) -> void:
	print(error)
