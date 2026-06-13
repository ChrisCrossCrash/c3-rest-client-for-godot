@tool
class_name C3RestClient
extends Node
## Asynchronous client for JSON REST APIs.
##
## Add the node to the scene tree, point [member base_url] at a server, and
## [code]await[/code] [method request]. Every call returns a response object
## carrying [member ApiResponse.ok] and a typed [member ApiResponse.error],
## so a single [code]if not response.ok[/code] check covers transport failures
## and non-2xx statuses alike. The body arrives raw on
## [member ApiResponse.body] and parsed (best-effort) on
## [member ApiResponse.json] — on success and failure both, since REST APIs
## conventionally return JSON-encoded error details.

## Emitted when a request fails. The [member ApiResponse.ok] field of the
## returned response object is the primary way to detect failure; this signal
## is a secondary broadcast for optional cross-cutting concerns such as global
## error logging.
signal request_failed(error: ApiError)

## HTTP method for [method request] and the per-verb convenience methods.
enum Method { GET, HEAD, POST, PUT, DELETE, OPTIONS, PATCH }

# Maps Method enum values to the HTTPClient constants taken by _http_request().
const _HTTP_METHODS: Dictionary = {
	Method.GET: HTTPClient.METHOD_GET,
	Method.HEAD: HTTPClient.METHOD_HEAD,
	Method.POST: HTTPClient.METHOD_POST,
	Method.PUT: HTTPClient.METHOD_PUT,
	Method.DELETE: HTTPClient.METHOD_DELETE,
	Method.OPTIONS: HTTPClient.METHOD_OPTIONS,
	Method.PATCH: HTTPClient.METHOD_PATCH,
}

## The base URL that every [method request] path is appended to, including any
## API version prefix — for example [code]"https://api.example.com/v1"[/code].
@export var base_url := ""
## Maximum seconds to wait for a response. [code]0.0[/code] disables the
## timeout (the default — waits indefinitely). Override per-call with the
## [param timeout_seconds] argument of [method request].
@export var timeout_seconds: float = 0.0

## Headers sent on every request, merged before any per-request headers passed
## to [method request]. Use this for node-level concerns such as authentication:
## [codeblock]
## client.base_headers = PackedStringArray([
##     "Authorization: Bearer " + OS.get_environment("MY_API_KEY"),
## ])
## [/codeblock]
var base_headers: PackedStringArray = PackedStringArray()


## Sends a [code]GET[/code] request to [param path].
## [param query] entries are URL-encoded and appended as a query string.
func http_get(
	path: String,
	query: Dictionary = {},
	headers: PackedStringArray = PackedStringArray(),
	timeout: float = -1.0
) -> ApiResponse:
	return await request(path, Method.GET, {}, query, headers, timeout)


## Sends a [code]HEAD[/code] request to [param path].
## [param query] entries are URL-encoded and appended as a query string.
func http_head(
	path: String,
	query: Dictionary = {},
	headers: PackedStringArray = PackedStringArray(),
	timeout: float = -1.0
) -> ApiResponse:
	return await request(path, Method.HEAD, {}, query, headers, timeout)


## Sends a [code]POST[/code] request to [param path] with [param body] as the
## JSON request body.
func http_post(
	path: String,
	body: Dictionary = {},
	query: Dictionary = {},
	headers: PackedStringArray = PackedStringArray(),
	timeout: float = -1.0
) -> ApiResponse:
	return await request(path, Method.POST, body, query, headers, timeout)


## Sends a [code]PUT[/code] request to [param path] with [param body] as the
## JSON request body.
func http_put(
	path: String,
	body: Dictionary = {},
	query: Dictionary = {},
	headers: PackedStringArray = PackedStringArray(),
	timeout: float = -1.0
) -> ApiResponse:
	return await request(path, Method.PUT, body, query, headers, timeout)


## Sends a [code]PATCH[/code] request to [param path] with [param body] as the
## JSON request body.
func http_patch(
	path: String,
	body: Dictionary = {},
	query: Dictionary = {},
	headers: PackedStringArray = PackedStringArray(),
	timeout: float = -1.0
) -> ApiResponse:
	return await request(path, Method.PATCH, body, query, headers, timeout)


## Sends a [code]DELETE[/code] request to [param path].
## [param query] entries are URL-encoded and appended as a query string.
func http_delete(
	path: String,
	query: Dictionary = {},
	headers: PackedStringArray = PackedStringArray(),
	timeout: float = -1.0
) -> ApiResponse:
	return await request(path, Method.DELETE, {}, query, headers, timeout)


## Sends an [code]OPTIONS[/code] request to [param path].
## [param query] entries are URL-encoded and appended as a query string.
func http_options(
	path: String,
	query: Dictionary = {},
	headers: PackedStringArray = PackedStringArray(),
	timeout: float = -1.0
) -> ApiResponse:
	return await request(path, Method.OPTIONS, {}, query, headers, timeout)


## Sends a request to [param path] — appended to [member base_url], with a
## leading [code]"/"[/code] added when missing — and returns the raw response
## body on [member ApiResponse.body] and its best-effort JSON decoding on
## [member ApiResponse.json], whether the request succeeded or failed. [br]
## [param method] is a [enum Method] value. [br]
## [param body] is sent as the JSON request body; leave empty to send no body
## (as a GET usually would). [br]
## [param query] entries are URL-encoded and appended to the URL as a query
## string; leave empty for none. [br]
## [param headers] are appended after [member base_headers]; use this for
## headers specific to a single call. [br]
## [param timeout] overrides [member timeout_seconds] for this call;
## pass [code]-1.0[/code] (the default) to use the node's value, or
## [code]0.0[/code] to disable the timeout for this specific request. [br]
## Returns a [ApiResponse] with [member ApiResponse.ok] set to
## [code]false[/code] and emits [signal request_failed] when no response was
## received or the status was not 2xx. Body content never affects
## [member ApiResponse.ok] — a 2xx response with a non-JSON body succeeds
## with [member ApiResponse.json] left [code]null[/code].
func request(
	path: String,
	method: Method,
	body: Dictionary = {},
	query: Dictionary = {},
	headers: PackedStringArray = PackedStringArray(),
	timeout: float = -1.0
) -> ApiResponse:
	var res := ApiResponse.new()
	var method_int: int = _HTTP_METHODS[method]
	if not path.begins_with("/"):
		path = "/" + path
	var url := base_url + path
	if not query.is_empty():
		url += "?" + HTTPClient.new().query_string_from_dict(query)
	var request_body := "" if body.is_empty() else JSON.stringify(body)
	var all_headers := PackedStringArray(["Content-Type: application/json"])
	all_headers.append_array(base_headers)
	all_headers.append_array(headers)
	var effective_timeout := timeout if timeout >= 0.0 else timeout_seconds
	var response := await _http_request(
		method_int, url, all_headers, request_body, effective_timeout
	)
	res.headers = response.get("headers", PackedStringArray())
	res.status = response.get("status", 0)
	var raw: PackedByteArray = response.get("body", PackedByteArray())
	res.body = raw.get_string_from_utf8()
	res.json = _parse_json(res.body)
	if not response["ok"]:
		res.ok = false
		res.error = response["error"]
		request_failed.emit(res.error)
	return res


# Isolated so tests can override it and avoid real network calls.
func _http_request(
	method: int,
	url: String,
	headers: PackedStringArray,
	body: String = "",
	timeout: float = 0.0
) -> Dictionary:
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = timeout
	var err := req.request(url, headers, method, body)
	if err != OK:
		req.queue_free()
		return {
			"ok": false,
			"error":
			ApiError.transport("Failed to start request (error %d)." % err)
		}
	var args: Array = await req.request_completed
	req.queue_free()
	return _process_http_result(args)


# Maps the HTTPRequest.request_completed arguments to the shared response shape.
# Every response carries "status", "headers", and "body" when an HTTP exchange
# happened; "ok" is false with an "error" ApiError on a transport failure or
# non-2xx status.
func _process_http_result(args: Array) -> Dictionary:
	var result: int = args[0]
	var status: int = args[1]
	var resp_headers: PackedStringArray = args[2]
	var resp_body: PackedByteArray = args[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"error":
			ApiError.transport("HTTP transport failed (result %d)." % result)
		}
	if status < 200 or status >= 300:
		return {
			"ok": false,
			"error": ApiError.from_response(status, resp_body),
			"status": status,
			"headers": resp_headers,
			"body": resp_body,
		}
	return {"ok": true, "status": status, "headers": resp_headers, "body": resp_body}


# Best-effort decode of a response body. Returns whatever the JSON parsed to,
# or null when the body is empty or not valid JSON.
static func _parse_json(body_str: String) -> Variant:
	if body_str.strip_edges().is_empty():
		return null
	var parser := JSON.new()
	if parser.parse(body_str) != OK:
		return null
	return parser.get_data()



## Structured error placed on the [code]error[/code] field of every response
## object when [code]ok[/code] is [code]false[/code], and carried by
## [signal request_failed].
class ApiError:
	## Broad category of failure.
	enum Kind {
		## No usable HTTP response (DNS, connection, TLS, or the request could
		## not be started).
		TRANSPORT,
		## A non-2xx status with no parseable API error body.
		HTTP,
		## The server returned a structured error body.
		API,
		## The request was rejected before being sent (e.g. an invalid argument).
		CLIENT,
		## The caller aborted the request.
		CANCELLED,
	}
	## Broad category of failure. One of the [enum Kind] values.
	var kind: Kind = Kind.TRANSPORT
	## Human-readable description. Never empty.
	var message := ""
	## HTTP status code, or [code]0[/code] when not applicable.
	var status := 0
	## Machine-readable API error code (e.g. [code]"invalid_api_key"[/code]), or
	## [code]""[/code] if absent.
	var code := ""
	## API error type (e.g. [code]"invalid_request_error"[/code]), or [code]""[/code].
	var type := ""

	## Builds an error for a transport-level failure with no usable HTTP response.
	static func transport(p_message: String) -> ApiError:
		var e := ApiError.new()
		e.kind = Kind.TRANSPORT
		e.message = p_message
		return e

	## Builds an error for a caller-initiated cancellation.
	static func cancelled(p_message: String) -> ApiError:
		var e := ApiError.new()
		e.kind = Kind.CANCELLED
		e.message = p_message
		return e

	## Builds an error for a request rejected before being sent (bad argument).
	static func client_error(p_message: String) -> ApiError:
		var e := ApiError.new()
		e.kind = Kind.CLIENT
		e.message = p_message
		return e

	## Builds an error from a non-2xx response, pulling the server's own message,
	## code, and type from a conventional [code]{"error": {...}}[/code] JSON body
	## (the style used by OpenAI and many other APIs) when present. Falls back to
	## a generic HTTP-status message otherwise.
	static func from_response(p_status: int, body: PackedByteArray) -> ApiError:
		var e := ApiError.new()
		e.kind = Kind.HTTP
		e.status = p_status
		e.message = "Request failed with status %d." % p_status
		var parser := JSON.new()
		var raw := body.get_string_from_utf8()
		if parser.parse(raw) == OK and parser.get_data() is Dictionary:
			var api_err: Variant = (parser.get_data() as Dictionary).get("error")
			if api_err is Dictionary:
				var d: Dictionary = api_err
				e.kind = Kind.API
				if d.get("message") is String:
					e.message = d["message"]
				if d.get("code") is String:
					e.code = d["code"]
				if d.get("type") is String:
					e.type = d["type"]
		return e

	func _to_string() -> String:
		var kind_name: String = Kind.find_key(kind)
		var parts := PackedStringArray(["[%s]" % kind_name.to_lower()])
		if status != 0:
			parts.append("status=%d" % status)
		if not code.is_empty():
			parts.append("code=%s" % code)
		parts.append(message)
		return " ".join(parts)


## The response returned by [method request].
class ApiResponse:
	## [code]true[/code] when a response was received and its status was 2xx.
	## Body content never affects this flag.
	var ok := true
	## Populated with error details when [member ok] is [code]false[/code].
	var error: ApiError = null
	## HTTP status code of the response, e.g. [code]200[/code],
	## [code]404[/code], or [code]204[/code]. [code]0[/code] when no HTTP
	## response was received (transport failure).
	var status: int = 0
	## Response headers returned by the server, as
	## [code]"Name: Value"[/code] strings. Empty when no HTTP response was
	## received (transport failure).
	var headers: PackedStringArray = PackedStringArray()
	## The raw UTF-8 response body, whenever the server sent one — on success
	## and failure both. [code]""[/code] when the body was empty or no response
	## was received.
	var body := ""
	## Best-effort JSON decoding of [member body]: whatever the JSON parsed to
	## (on any status, including errors — REST APIs conventionally return
	## JSON-encoded error details), or [code]null[/code] when the body was
	## empty or not valid JSON.
	var json: Variant = null
