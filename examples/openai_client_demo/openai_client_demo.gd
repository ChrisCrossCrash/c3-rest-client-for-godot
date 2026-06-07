extends Control

const CHAT_MODEL := "gpt-5.4-mini"
const TTS_MODEL := "gpt-4o-mini-tts"
const TTS_VOICE := "marin"
const STT_MODEL := "whisper-1"

@onready var client: C3OpenAIClient = $C3OpenAIClient
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var label: Label = $ScrollContainer/Label


func _ready() -> void:
	if not OS.get_environment("OPENAI_API_KEY"):
		push_error("OPENAI_API_KEY environment variable is not set.")
		return

	client.api_key = OS.get_environment("OPENAI_API_KEY")

	var chat_res_str := await _chat_non_streaming()
	await _chat_streaming()
	await _chat_vision()
	await _voice_tts(chat_res_str)
	await _voice_stt()


func _chat_non_streaming() -> String:
	# --- Chat: non-streaming ---
	_render_text("Chat completion (non-streaming):")
	var user_msg := "What is an LLM?"
	var messages := [
		C3OpenAIClient.make_system_msg(
			"You are an assistant that gives one-sentence responses."
		),
		C3OpenAIClient.make_user_msg(user_msg)
	]
	var opts := C3OpenAIClient.ChatOptions.new()
	opts.model = CHAT_MODEL
	var response := await client.chat_completion(messages, opts)
	if not response.ok:
		push_error(
			"Error generating chat completion: " + str(response.error)
		)
		return "There was an error generating the chat completion."

	_render_text("User: " + user_msg)
	_render_text("Assistant: " + response.content)
	_render_text("---")
	return response.content


	var completion_res := await client.chat_completion(messages, opts)
	if not completion_res.ok:
		_quit_with_error(
			"Error generating chat completion: " + str(completion_res.error)
		)
		return

	_render_text("User: " + user_msg_str_llm)
	_render_text("Assistant: " + completion_res.content)
	_render_text("---")


func _chat_streaming() -> void:
	_render_text("Chat completion (streaming):")
	var messages := [C3OpenAIClient.make_user_msg("Count to ten.")]
	var opts := C3OpenAIClient.ChatOptions.new()
	opts.model = CHAT_MODEL

	var stream := client.chat_completion_stream(messages, opts)

	# Incremental updates as tokens arrive:
	stream.delta.connect(func(text: String) -> void: _render_text(text, ""))

	# Final result — same struct chat_completion() returns:
	var result: C3OpenAIClient.ChatCompletionResponse = await stream.finished
	if not result.ok:
		push_error(
			"Error streaming chat completion: " + str(result.error)
		)
		return

	_render_text("\n(full content: %d chars)\n---" % result.content.length())


func _chat_vision() -> void:
	_render_text("Vision chat completion:")
	var user_msg := "What do you see in this image? Describe in one sentence."
	var img := (
		(load("res://examples/openai_client_demo/test-img.jpg") as Texture2D)
		. get_image()
	)
	var b64 := Marshalls.raw_to_base64(img.save_jpg_to_buffer())
	var messages := [
		C3OpenAIClient.make_user_msg_with_parts([
			C3OpenAIClient.make_part_text(user_msg),
			C3OpenAIClient.make_part_image_url("data:image/jpeg;base64," + b64),
		])
	]
	var opts := C3OpenAIClient.ChatOptions.new()
	opts.model = CHAT_MODEL
	var response := await client.chat_completion(messages, opts)
	if not response.ok:
		push_error(
			"Error generating image chat completion:" + str(response.error)
		)
		return

	_render_text("User: " + user_msg)
	_render_text("Assistant: " + response.content)
	_render_text("---")


func _voice_tts(text: String) -> void:
	var opts := C3OpenAIClient.SpeechOptions.new()
	opts.model = TTS_MODEL
	opts.voice = TTS_VOICE
	var response := await client.create_speech(text, opts)
	if not response.ok:
		push_error("Error generating speech: " + str(response.error))
		get_tree().quit()
		return
	audio_stream_player.stream = response.stream
	_render_text("Playing speech...\n---")
	audio_stream_player.play()


func _voice_stt() -> void:
	var clip := load("res://examples/openai_client_demo/demo-speech.mp3")
	var opts := C3OpenAIClient.TranscriptionOptions.new()
	opts.model = STT_MODEL
	var response := await client.create_transcription(clip, opts)
	if not response.ok:
		push_error(
			"Error generating transcription: " + str(response.error)
		)
		return
	_render_text("Transcription: " + response.text)


func _render_text(txt: String, end: String = "\n") -> void:
	print(txt)
	label.text += txt + end
