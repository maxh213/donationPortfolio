import api_types.{type ApiError}
import gleam/bytes_tree
import gleam/http/response.{type Response}
import gleam/json
import mist

pub fn json_response(status: Int, data: json.Json) -> Response(mist.ResponseData) {
  response.new(status)
  |> response.set_body(mist.Bytes(bytes_tree.from_string(json.to_string(data))))
  |> response.set_header("content-type", "application/json")
}

pub fn success_response(data: json.Json) -> Response(mist.ResponseData) {
  json_response(200, api_types.success_json(data))
}

pub fn error_response(error: ApiError) -> Response(mist.ResponseData) {
  let status = api_types.error_to_status_code(error)
  json_response(status, api_types.error_json(error))
}

pub fn not_found() -> Response(mist.ResponseData) {
  error_response(api_types.NotFoundError("Endpoint not found"))
}

pub fn method_not_allowed() -> Response(mist.ResponseData) {
  error_response(api_types.BadRequestError("Method not allowed"))
}

pub fn internal_server_error(message: String) -> Response(mist.ResponseData) {
  error_response(api_types.InternalServerError(message))
}

pub fn validation_error_response(errors: List(api_types.ValidationField)) -> Response(mist.ResponseData) {
  json_response(400, api_types.validation_errors_json(errors))
}

pub fn conflict_error(message: String) -> Response(mist.ResponseData) {
  error_response(api_types.ConflictError(message))
}

pub fn too_many_requests(message: String) -> Response(mist.ResponseData) {
  error_response(api_types.TooManyRequestsError(message))
}

pub fn unauthorized(message: String) -> Response(mist.ResponseData) {
  error_response(api_types.UnauthorizedError(message))
}

pub fn forbidden(message: String) -> Response(mist.ResponseData) {
  error_response(api_types.ForbiddenError(message))
}

pub fn bad_request(message: String) -> Response(mist.ResponseData) {
  error_response(api_types.BadRequestError(message))
}