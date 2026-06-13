extends GutTest


## Unit tests for the [C3RestClient.ApiError] value type and its factories.
class TestApiError extends GutTest:
	const ApiError := C3RestClient.ApiError

	## A JSON-encoded OpenAI-style error body.
	func error_body(
		message := "Incorrect API key provided: ABC123.",
		code := "invalid_api_key",
		type := "invalid_request_error"
	) -> PackedByteArray:
		return JSON.stringify(
			{"error": {"message": message, "code": code, "type": type}}
		).to_utf8_buffer()

	func test_transport_factory() -> void:
		var e := ApiError.transport("Could not connect.")
		assert_eq(e.kind, &"transport")
		assert_eq(e.message, "Could not connect.")
		assert_eq(e.status, 0)

	func test_cancelled_factory() -> void:
		var e := ApiError.cancelled("Stream cancelled.")
		assert_eq(e.kind, &"cancelled")
		assert_eq(e.message, "Stream cancelled.")

	func test_client_error_factory() -> void:
		var e := ApiError.client_error('Unsupported HTTP method "FETCH".')
		assert_eq(e.kind, &"client")
		assert_eq(e.message, 'Unsupported HTTP method "FETCH".')

	func test_from_response_parses_api_error_body() -> void:
		var e := ApiError.from_response(401, error_body())
		assert_eq(e.kind, &"api")
		assert_eq(e.status, 401)
		assert_eq(e.code, "invalid_api_key")
		assert_eq(e.type, "invalid_request_error")
		assert_eq(e.message, "Incorrect API key provided: ABC123.")

	func test_from_response_missing_fields_default_to_empty() -> void:
		var body := (
			JSON.stringify({"error": {"message": "Oops."}}).to_utf8_buffer()
		)
		var e := ApiError.from_response(400, body)
		assert_eq(e.kind, &"api")
		assert_eq(e.message, "Oops.")
		assert_eq(e.code, "")
		assert_eq(e.type, "")

	func test_from_response_non_json_body_falls_back_to_http() -> void:
		var e := ApiError.from_response(
			500, "Internal Server Error".to_utf8_buffer()
		)
		assert_eq(e.kind, &"http")
		assert_eq(e.status, 500)
		assert_eq(e.message, "Request failed with status 500.")

	func test_from_response_json_without_error_key_falls_back_to_http() -> void:
		var e := ApiError.from_response(
			404, '{"detail": "nope"}'.to_utf8_buffer()
		)
		assert_eq(e.kind, &"http")
		assert_eq(e.message, "Request failed with status 404.")

	func test_to_string_includes_status_code_and_message() -> void:
		var s := str(ApiError.from_response(401, error_body()))
		assert_string_contains(s, "[api]")
		assert_string_contains(s, "status=401")
		assert_string_contains(s, "code=invalid_api_key")
		assert_string_contains(s, "Incorrect API key provided: ABC123.")

	func test_to_string_omits_zero_status_and_empty_code() -> void:
		assert_eq(str(ApiError.transport("Down.")), "[transport] Down.")


## Tests for the shared transport classifier used by every endpoint.
class TestProcessHttpResult extends GutTest:
	var client: C3RestClient

	func before_each() -> void:
		client = C3RestClient.new()
		add_child_autofree(client)

	## Builds an HTTPRequest.request_completed argument array:
	## [result, response_code, headers, body].
	func args(result: int, status: int, body: PackedByteArray) -> Array:
		return [result, status, PackedStringArray(), body]

	func test_2xx_is_ok_with_body() -> void:
		var body := "hello".to_utf8_buffer()
		var res := client._process_http_result(
			args(HTTPRequest.RESULT_SUCCESS, 200, body)
		)
		assert_true(res["ok"])
		assert_eq(res["body"], body)

	func test_transport_failure_is_transport_error() -> void:
		var res := client._process_http_result(
			args(HTTPRequest.RESULT_CONNECTION_ERROR, 0, PackedByteArray())
		)
		assert_false(res["ok"])
		assert_eq(res["error"].kind, &"transport")

	func test_non_2xx_with_error_body_is_api_error() -> void:
		var body := JSON.stringify(
			{"error": {"message": "Bad key.", "code": "invalid_api_key"}}
		).to_utf8_buffer()
		var res := client._process_http_result(
			args(HTTPRequest.RESULT_SUCCESS, 401, body)
		)
		assert_false(res["ok"])
		assert_eq(res["error"].kind, &"api")
		assert_eq(res["error"].status, 401)
		assert_eq(res["error"].code, "invalid_api_key")

	func test_non_2xx_without_error_body_is_http_error() -> void:
		var res := client._process_http_result(
			args(HTTPRequest.RESULT_SUCCESS, 500, "boom".to_utf8_buffer())
		)
		assert_false(res["ok"])
		assert_eq(res["error"].kind, &"http")
		assert_eq(res["error"].status, 500)

	func test_non_2xx_keeps_status_and_body() -> void:
		var body := "boom".to_utf8_buffer()
		var res := client._process_http_result(
			args(HTTPRequest.RESULT_SUCCESS, 500, body)
		)
		assert_eq(res["status"], 500)
		assert_eq(res["body"], body)
