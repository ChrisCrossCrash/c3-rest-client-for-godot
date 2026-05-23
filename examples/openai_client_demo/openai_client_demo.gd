extends Control

@onready var client: C3OpenAIClient = $C3OpenAIClient


func _ready() -> void:
	var ids := await client.get_models()
	print(ids)

	var messages = [
		C3OpenAIClient.make_system_msg(
			"You are a funny assistant that only responds in rhymes."
		),
		C3OpenAIClient.make_user_msg("What is the meaning of life?")
	]
	var opts := C3OpenAIClient.ChatOptions.new()
	opts.model = ids[0]
	var completion := await client.chat_completion(messages, opts)
	print(completion.content)

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

	var vision_completion := await client.chat_completion(vision_messages, opts)
	print(vision_completion.content)

	await get_tree().process_frame  # let output flush
	get_tree().quit()
