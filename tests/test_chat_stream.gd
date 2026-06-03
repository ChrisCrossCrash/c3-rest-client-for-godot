extends GutTest


## Tests for [method C3OpenAIClient.chat_completion_stream].
class TestChatCompletionStream extends GutTest:
	var client: C3TestDoubles.TestableClient

	func before_each() -> void:
		client = C3TestDoubles.TestableClient.new()
		add_child_autofree(client)

	## Chat options with a model set, to silence the empty-model warning.
	func opts_with_model(model := "gpt-4o") -> C3OpenAIClient.ChatOptions:
		var opts := C3OpenAIClient.ChatOptions.new()
		opts.model = model
		return opts

	## A streaming chunk carrying a content delta, as the server emits it.
	func content_chunk(text: String) -> String:
		return JSON.stringify(
			{"choices": [{"delta": {"content": text}, "finish_reason": null}]}
		)

	## The terminal chunk: empty delta, finish_reason, model, and usage.
	func final_chunk(finish_reason := "stop", model := "gpt-4o") -> String:
		return JSON.stringify(
			{
				"choices": [{"delta": {}, "finish_reason": finish_reason}],
				"model": model,
				"usage":
				{
					"prompt_tokens": 10,
					"completion_tokens": 5,
					"total_tokens": 15
				},
			}
		)

	## Starts a stream and returns it. The fake transport is at client.last_sse.
	func start_stream() -> C3OpenAIClient.ChatStream:
		return client.chat_completion_stream(
			[C3OpenAIClient.make_user_msg("Hello")], opts_with_model()
		)

	## Connects a capturing callback to `finished` and returns the array it
	## appends the result to. Capturing up front works because the fake drives
	## the stream synchronously, so `finished` fires during the driving emits.
	func capture_finished(stream: C3OpenAIClient.ChatStream) -> Array:
		var captured := []
		stream.finished.connect(func(r: Variant) -> void: captured.append(r))
		return captured

	## Emits a full, successful two-token stream over the fake transport.
	func drive_success(sse: C3TestDoubles.FakeSSERequest) -> void:
		sse.stream_started.emit(200, PackedStringArray())
		sse.event_received.emit(content_chunk("Hel"), "message")
		sse.event_received.emit(content_chunk("lo"), "message")
		sse.event_received.emit(final_chunk(), "message")
		sse.event_received.emit("[DONE]", "message")
		sse.finished.emit()

	func test_returns_chat_stream() -> void:
		var stream := start_stream()
		assert_is(stream, C3OpenAIClient.ChatStream)

	func test_emits_delta_per_content_chunk() -> void:
		var stream := start_stream()
		var deltas := []
		stream.delta.connect(func(t: String) -> void: deltas.append(t))
		drive_success(client.last_sse)
		assert_eq(deltas, ["Hel", "lo"])

	func test_finished_result_is_chat_completion_response() -> void:
		var stream := start_stream()
		var captured := capture_finished(stream)
		drive_success(client.last_sse)
		assert_is(captured[0], C3OpenAIClient.ChatCompletionResponse)

	func test_content_is_accumulated() -> void:
		var stream := start_stream()
		var captured := capture_finished(stream)
		drive_success(client.last_sse)
		assert_eq(captured[0].content, "Hello")

	func test_finish_reason_is_populated() -> void:
		var stream := start_stream()
		var captured := capture_finished(stream)
		drive_success(client.last_sse)
		assert_eq(captured[0].finish_reason, "stop")

	func test_model_is_populated() -> void:
		var stream := start_stream()
		var captured := capture_finished(stream)
		client.last_sse.stream_started.emit(200, PackedStringArray())
		client.last_sse.event_received.emit(
			final_chunk("stop", "llama-3.1-8b"), "message"
		)
		client.last_sse.finished.emit()
		assert_eq(captured[0].model, "llama-3.1-8b")

	func test_usage_is_populated() -> void:
		var stream := start_stream()
		var captured := capture_finished(stream)
		drive_success(client.last_sse)
		var usage: Dictionary = captured[0].usage
		assert_eq(typeof(usage["prompt_tokens"]), TYPE_INT)
		assert_eq(usage["prompt_tokens"], 10)
		assert_eq(usage["completion_tokens"], 5)
		assert_eq(usage["total_tokens"], 15)

	func test_ok_is_true_on_clean_finish() -> void:
		var stream := start_stream()
		var captured := capture_finished(stream)
		drive_success(client.last_sse)
		assert_true(captured[0].ok)

	func test_finished_emitted_once_on_success() -> void:
		var stream := start_stream()
		var captured := capture_finished(stream)
		drive_success(client.last_sse)
		assert_eq(captured.size(), 1)

	func test_done_sentinel_does_not_emit_delta() -> void:
		var stream := start_stream()
		var deltas := []
		stream.delta.connect(func(t: String) -> void: deltas.append(t))
		client.last_sse.stream_started.emit(200, PackedStringArray())
		client.last_sse.event_received.emit("[DONE]", "message")
		client.last_sse.finished.emit()
		assert_eq(deltas.size(), 0)

	func test_invalid_json_chunk_is_ignored() -> void:
		var stream := start_stream()
		var deltas := []
		stream.delta.connect(func(t: String) -> void: deltas.append(t))
		var captured := capture_finished(stream)
		client.last_sse.stream_started.emit(200, PackedStringArray())
		client.last_sse.event_received.emit("not json", "message")
		client.last_sse.finished.emit()
		assert_eq(deltas.size(), 0)
		assert_true(captured[0].ok)

	func test_empty_choices_chunk_is_ignored() -> void:
		var stream := start_stream()
		var deltas := []
		stream.delta.connect(func(t: String) -> void: deltas.append(t))
		var captured := capture_finished(stream)
		client.last_sse.stream_started.emit(200, PackedStringArray())
		client.last_sse.event_received.emit('{"choices": []}', "message")
		client.last_sse.finished.emit()
		assert_eq(deltas.size(), 0)
		assert_true(captured[0].ok)

	func test_refusal_is_accumulated() -> void:
		var stream := start_stream()
		var captured := capture_finished(stream)
		client.last_sse.stream_started.emit(200, PackedStringArray())
		client.last_sse.event_received.emit(
			JSON.stringify(
				{"choices": [{"delta": {"refusal": "I can't help "}}]}
			),
			"message"
		)
		client.last_sse.event_received.emit(
			JSON.stringify({"choices": [{"delta": {"refusal": "with that."}}]}),
			"message"
		)
		client.last_sse.finished.emit()
		assert_eq(captured[0].refusal, "I can't help with that.")

	func test_uses_correct_endpoint() -> void:
		client.base_url = "http://example.com/v1"
		start_stream()
		assert_eq(
			client.last_sse.last_url, "http://example.com/v1/chat/completions"
		)

	func test_request_body_has_stream_true() -> void:
		start_stream()
		var body: Variant = JSON.parse_string(client.last_sse.last_body)
		assert_true(body["stream"])

	func test_request_body_has_messages_and_model() -> void:
		client.chat_completion_stream(
			[C3OpenAIClient.make_user_msg("Hello")], opts_with_model("gpt-4o")
		)
		var body: Variant = JSON.parse_string(client.last_sse.last_body)
		assert_eq(body["model"], "gpt-4o")
		assert_eq(body["messages"], [{"role": "user", "content": "Hello"}])

	func test_warns_when_model_is_empty() -> void:
		client.chat_completion_stream([C3OpenAIClient.make_user_msg("Hello")])
		assert_push_warning(
			"C3OpenAIClient: opts.model is empty — using server default."
		)

	func test_non_200_resolves_failed() -> void:
		var stream := start_stream()
		var captured := capture_finished(stream)
		client.last_sse.response_error.emit(404, "")
		assert_false(captured[0].ok)

	func test_non_200_error_has_status() -> void:
		var stream := start_stream()
		var captured := capture_finished(stream)
		client.last_sse.response_error.emit(404, "")
		assert_eq(captured[0].error.status, 404)

	func test_non_200_emits_request_failed() -> void:
		start_stream()
		watch_signals(client)
		client.last_sse.response_error.emit(500, "")
		assert_signal_emitted(client, "request_failed")

	func test_non_200_error_body_parsed_as_api_error() -> void:
		var stream := start_stream()
		var captured := capture_finished(stream)
		var body := JSON.stringify(
			{"error": {"message": "Bad key.", "code": "invalid_api_key"}}
		)
		client.last_sse.response_error.emit(401, body)
		var err: C3OpenAIClient.ApiError = captured[0].error
		assert_eq(err.kind, &"api")
		assert_eq(err.status, 401)
		assert_eq(err.code, "invalid_api_key")
		assert_eq(err.message, "Bad key.")

	func test_non_200_empty_body_is_http_kind() -> void:
		var stream := start_stream()
		var captured := capture_finished(stream)
		client.last_sse.response_error.emit(503, "")
		var err: C3OpenAIClient.ApiError = captured[0].error
		assert_eq(err.kind, &"http")
		assert_eq(err.message, "Request failed with status 503.")

	func test_transport_failure_error_is_transport_kind() -> void:
		var stream := start_stream()
		var captured := capture_finished(stream)
		client.last_sse.request_failed.emit("Could not connect.")
		assert_eq(captured[0].error.kind, &"transport")

	func test_cancel_error_is_cancelled_kind() -> void:
		var stream := start_stream()
		var captured := capture_finished(stream)
		client.last_sse.stream_started.emit(200, PackedStringArray())
		stream.cancel()
		assert_eq(captured[0].error.kind, &"cancelled")

	func test_transport_failure_resolves_failed() -> void:
		var stream := start_stream()
		var captured := capture_finished(stream)
		client.last_sse.request_failed.emit("Could not connect.")
		assert_false(captured[0].ok)

	func test_transport_failure_emits_request_failed() -> void:
		start_stream()
		watch_signals(client)
		client.last_sse.request_failed.emit("Could not connect.")
		assert_signal_emitted(client, "request_failed")

	func test_request_start_error_resolves_failed() -> void:
		client.sse_request_return = ERR_BUSY
		var stream := start_stream()
		var captured := capture_finished(stream)
		await wait_process_frames(1)
		assert_eq(captured.size(), 1)
		assert_false(captured[0].ok)

	func test_request_start_error_emits_request_failed() -> void:
		client.sse_request_return = ERR_BUSY
		watch_signals(client)
		start_stream()
		await wait_process_frames(1)
		assert_signal_emitted(client, "request_failed")

	func test_cancel_resolves_failed() -> void:
		var stream := start_stream()
		var captured := capture_finished(stream)
		client.last_sse.stream_started.emit(200, PackedStringArray())
		stream.cancel()
		assert_false(captured[0].ok)

	func test_cancel_does_not_emit_request_failed() -> void:
		var stream := start_stream()
		watch_signals(client)
		client.last_sse.stream_started.emit(200, PackedStringArray())
		stream.cancel()
		assert_signal_not_emitted(client, "request_failed")

	func test_cancel_after_finish_is_noop() -> void:
		var stream := start_stream()
		var captured := capture_finished(stream)
		drive_success(client.last_sse)
		stream.cancel()
		assert_eq(captured.size(), 1)
		assert_true(captured[0].ok)
