extends Control

# Different clients for different servers with different capabilities.
@onready var client_llm: C3OpenAIClient = $C3OpenAIClientLLM
@onready var client_voice: C3OpenAIClient = $C3OpenAIClientVoice

@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer

const TTS_MODEL := "speaches-ai/Kokoro-82M-v1.0-ONNX-fp16"
const STT_MODEL := "deepdml/faster-whisper-large-v3-turbo-ct2"
const TTS_VOICE := "af_heart"


func _ready() -> void:
	# --- List models (both servers) ---
	var llm_models_res := await client_llm.get_models()
	var voice_models_res := await client_voice.get_models()

	if not llm_models_res.ok:
		push_error("Error fetching LLM models: " + str(llm_models_res.error))
		get_tree().quit()
		return
	if not voice_models_res.ok:
		push_error("Error fetching voice models: " + str(voice_models_res.error))
		get_tree().quit()
		return
	if llm_models_res.ids.is_empty():
		push_error("No LLM models found.")
		get_tree().quit()
		return
	if not voice_models_res.ids.has(TTS_MODEL):
		push_error("TTS model not found: " + TTS_MODEL)
		get_tree().quit()
		return
	if not voice_models_res.ids.has(STT_MODEL):
		push_error("STT model not found: " + STT_MODEL)
		get_tree().quit()

	print("LLM Models:")
	for model_id in llm_models_res.ids:
		print(model_id)
	print("\nVoice Models:")
	for model_id in voice_models_res.ids:
		print(model_id)
	print("\n---")

	# --- Chat (LLM server) ---
	var user_msg_str_llm := "What is the meaning of life?"
	var messages = [
		C3OpenAIClient.make_system_msg(
			"You are a funny assistant that only responds in rhymes."
		),
		C3OpenAIClient.make_user_msg(user_msg_str_llm)
	]
	var opts := C3OpenAIClient.ChatOptions.new()
	opts.model = llm_models_res.ids[0]
	var completion_res := await client_llm.chat_completion(messages, opts)
	if not completion_res.ok:
		push_error("Error generating chat completion: " + str(completion_res.error))
		get_tree().quit()
		return

	print("Chat completion:")
	print("User: " + user_msg_str_llm)
	print("Assistant: " + completion_res.content)
	print("---")

	# --- Vision (LLM server) ---
	var user_msg_str_vision := "What do you see in this image?"
	var img := (
		(load("res://examples/openai_client_demo/test-img.jpg") as Texture2D)
		. get_image()
	)
	var b64 := Marshalls.raw_to_base64(img.save_jpg_to_buffer())
	var vision_messages = [
		C3OpenAIClient.make_user_msg_with_parts([
			C3OpenAIClient.make_part_text(user_msg_str_vision),
			C3OpenAIClient.make_part_image_url("data:image/jpeg;base64," + b64),
		])
	]
	var vision_completion_res := await client_llm.chat_completion(
		vision_messages, opts
	)
	if not vision_completion_res.ok:
		push_error("Error generating image chat completion:" + str(vision_completion_res.error))
		get_tree().quit()
		return

	print("Vision chat completion:")
	print("User: " + user_msg_str_vision)
	print("Assistant: " + vision_completion_res.content)
	print("---")

	# --- Text-to-speech (voice server) ---
	var speech_opts := C3OpenAIClient.SpeechOptions.new()
	speech_opts.model = TTS_MODEL
	speech_opts.voice = TTS_VOICE
	var speech_res := await client_voice.create_speech(completion_res.content, speech_opts)
	if not speech_res.ok:
		push_error("Error generating speech: " + str(speech_res.error))
		get_tree().quit()
		return
	audio_stream_player.stream = speech_res.stream
	print("Playing speech...\n---")
	audio_stream_player.play()

	# --- Speech-to-text (voice server) ---
	var clip := load("res://examples/openai_client_demo/demo-speech.mp3")
	var transcribe_opts := C3OpenAIClient.TranscriptionOptions.new()
	transcribe_opts.model = STT_MODEL
	var transcription_res := await client_voice.create_transcription(
		clip, transcribe_opts
	)
	if not transcription_res.ok:
		push_error("Error generating transcription: " + str(transcription_res.error))
		get_tree().quit()
		return
	print("Transcription: " + transcription_res.text)
	await audio_stream_player.finished
	get_tree().quit()
