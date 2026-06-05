extends Control

const CHAT_MODEL := "gpt-5.4-mini"
const TTS_MODEL := "tts-1"
const TTS_VOICE := "alloy"
const STT_MODEL := "whisper-1"

@onready var client: C3OpenAIClient = $C3OpenAIClient
@onready var audio_stream_player: AudioStreamPlayer = $AudioStreamPlayer
@onready var label: Label = $ScrollContainer/Label


func _ready() -> void:
	if not OS.get_environment("OPENAI_API_KEY"):
		_quit_with_error("OPENAI_API_KEY environment variable is not set.")
		return

	client.api_key = OS.get_environment("OPENAI_API_KEY")

	# --- Chat: non-streaming ---
	_render_text("Chat completion (non-streaming):")
	var user_msg_str_llm := "What is an LLM?"
	var messages := [
		C3OpenAIClient.make_system_msg(
			"You are an assistant that gives one-sentence responses."
		),
		C3OpenAIClient.make_user_msg(user_msg_str_llm)
	]
	var opts := C3OpenAIClient.ChatOptions.new()
	opts.model = CHAT_MODEL
	var completion_res := await client.chat_completion(messages, opts)
	if not completion_res.ok:
		_quit_with_error(
			"Error generating chat completion: " + str(completion_res.error)
		)
		return

	_render_text("User: " + user_msg_str_llm)
	_render_text("Assistant: " + completion_res.content)
	_render_text("---")

	# --- Streaming chat ---
	_render_text("Chat completion (streaming):")
	var streaming_messages := [C3OpenAIClient.make_user_msg("Count to ten.")]
	var streaming_opts := C3OpenAIClient.ChatOptions.new()
	streaming_opts.model = CHAT_MODEL

	var stream := client.chat_completion_stream(
		streaming_messages, streaming_opts
	)

	# Incremental updates as tokens arrive:
	stream.delta.connect(func(text: String) -> void: _render_text(text, ""))

	# Final result — same struct chat_completion() returns:
	var result: C3OpenAIClient.ChatCompletionResponse = await stream.finished
	if not result.ok:
		_quit_with_error(
			"Error streaming chat completion: " + str(result.error)
		)
		return

	_render_text("\n(full content: %d chars)\n---" % result.content.length())

	# --- Vision ---
	_render_text("Vision chat completion:")
	var user_msg_str_vision := "What do you see in this image? Describe in one sentence."
	var img := (
		(load("res://examples/openai_client_demo/test-img.jpg") as Texture2D)
		. get_image()
	)
	var b64 := Marshalls.raw_to_base64(img.save_jpg_to_buffer())
	var vision_messages := [
		C3OpenAIClient.make_user_msg_with_parts([
			C3OpenAIClient.make_part_text(user_msg_str_vision),
			C3OpenAIClient.make_part_image_url("data:image/jpeg;base64," + b64),
		])
	]
	var vision_completion_res := await client.chat_completion(
		vision_messages, opts
	)
	if not vision_completion_res.ok:
		_quit_with_error(
			"Error generating image chat completion:"
			+ str(vision_completion_res.error)
		)
		return

	_render_text("User: " + user_msg_str_vision)
	_render_text("Assistant: " + vision_completion_res.content)
	_render_text("---")

	# --- Text-to-speech ---
	var speech_opts := C3OpenAIClient.SpeechOptions.new()
	speech_opts.model = TTS_MODEL
	speech_opts.voice = TTS_VOICE
	var speech_res := await client.create_speech(
		completion_res.content, speech_opts
	)
	if not speech_res.ok:
		push_error("Error generating speech: " + str(speech_res.error))
		get_tree().quit()
		return
	audio_stream_player.stream = speech_res.stream
	_render_text("Playing speech...\n---")
	audio_stream_player.play()

	# --- Speech-to-text ---
	var clip := load("res://examples/openai_client_demo/demo-speech.mp3")
	var transcribe_opts := C3OpenAIClient.TranscriptionOptions.new()
	transcribe_opts.model = STT_MODEL
	var transcription_res := await client.create_transcription(
		clip, transcribe_opts
	)
	if not transcription_res.ok:
		_quit_with_error(
			"Error generating transcription: " + str(transcription_res.error)
		)
		return
	_render_text("Transcription: " + transcription_res.text)


func _quit_with_error(err: String) -> void:
	push_error(err)
	await get_tree().process_frame
	get_tree().quit()


func _render_text(txt: String, end: String = "\n") -> void:
	print(txt)
	label.text += txt + end
