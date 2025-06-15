import gleam/json

pub type ApiError {
  ValidationError(message: String)
  NotFoundError(message: String)
  UnauthorizedError(message: String)
  ForbiddenError(message: String)
  InternalServerError(message: String)
  BadRequestError(message: String)
}

pub type ApiResponse(data) {
  SuccessResponse(data: data)
  ErrorResponse(error: ApiError)
}

pub fn error_to_status_code(error: ApiError) -> Int {
  case error {
    ValidationError(_) -> 400
    BadRequestError(_) -> 400
    UnauthorizedError(_) -> 401
    ForbiddenError(_) -> 403
    NotFoundError(_) -> 404
    InternalServerError(_) -> 500
  }
}

pub fn error_to_message(error: ApiError) -> String {
  case error {
    ValidationError(msg) -> msg
    NotFoundError(msg) -> msg
    UnauthorizedError(msg) -> msg
    ForbiddenError(msg) -> msg
    InternalServerError(msg) -> msg
    BadRequestError(msg) -> msg
  }
}

pub fn success_json(data: json.Json) -> json.Json {
  json.object([
    #("success", json.bool(True)),
    #("data", data)
  ])
}

pub fn error_json(error: ApiError) -> json.Json {
  json.object([
    #("success", json.bool(False)),
    #("error", json.object([
      #("message", json.string(error_to_message(error))),
      #("code", json.int(error_to_status_code(error)))
    ]))
  ])
}