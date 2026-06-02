extends GutTest


class TestMessageHelpers extends GutTest:
	func test_make_user_msg() -> void:
		assert_eq(
			C3OpenAIClient.make_user_msg("hi"),
			{"role": "user", "content": "hi"}
		)

	func test_make_assistant_msg() -> void:
		assert_eq(
			C3OpenAIClient.make_assistant_msg("hi"),
			{"role": "assistant", "content": "hi"}
		)

	func test_make_system_msg() -> void:
		assert_eq(
			C3OpenAIClient.make_system_msg("hi"),
			{"role": "system", "content": "hi"}
		)

	func test_make_part_text() -> void:
		assert_eq(
			C3OpenAIClient.make_part_text("describe this"),
			{"type": "text", "text": "describe this"}
		)

	func test_make_part_image_url_default_detail() -> void:
		assert_eq(
			C3OpenAIClient.make_part_image_url("data:image/png;base64,abc"),
			{
				"type": "image_url",
				"image_url":
				{"url": "data:image/png;base64,abc", "detail": "auto"}
			}
		)

	func test_make_part_image_url_custom_detail() -> void:
		assert_eq(
			C3OpenAIClient.make_part_image_url(
				"data:image/png;base64,abc", "high"
			),
			{
				"type": "image_url",
				"image_url":
				{"url": "data:image/png;base64,abc", "detail": "high"}
			}
		)

	func test_make_user_msg_with_parts() -> void:
		var parts := [
			C3OpenAIClient.make_part_text("describe this"),
			C3OpenAIClient.make_part_image_url("data:image/png;base64,abc"),
		]
		assert_eq(
			C3OpenAIClient.make_user_msg_with_parts(parts),
			{"role": "user", "content": parts}
		)


class TestChatOptions extends GutTest:
	func test_default_model() -> void:
		assert_eq(C3OpenAIClient.ChatOptions.new().model, "")

	func test_default_temperature() -> void:
		assert_true(is_nan(C3OpenAIClient.ChatOptions.new().temperature))

	func test_default_max_tokens() -> void:
		assert_eq(C3OpenAIClient.ChatOptions.new().max_tokens, -1)
