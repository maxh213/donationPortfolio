import gleam/int
import gleam/json
import gleam/list
import gleam/result
import gleam/string

pub type ApiError {
  ValidationError(message: String)
  NotFoundError(message: String)
  UnauthorizedError(message: String)
  ForbiddenError(message: String)
  InternalServerError(message: String)
  BadRequestError(message: String)
  ConflictError(message: String)
  TooManyRequestsError(message: String)
}

pub type ValidationField {
  ValidationField(field: String, message: String)
}

pub type ValidationResult(a) =
  Result(a, List(ValidationField))

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
    ConflictError(_) -> 409
    TooManyRequestsError(_) -> 429
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
    ConflictError(msg) -> msg
    TooManyRequestsError(msg) -> msg
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

pub fn validation_errors_json(errors: List(ValidationField)) -> json.Json {
  let error_objects = list.map(errors, fn(error) {
    json.object([
      #("field", json.string(error.field)),
      #("message", json.string(error.message))
    ])
  })
  
  json.object([
    #("success", json.bool(False)),
    #("error", json.object([
      #("message", json.string("Validation failed")),
      #("code", json.int(400)),
      #("details", json.array(error_objects, fn(x) { x }))
    ]))
  ])
}

pub fn validate_required_string(value: String, field: String) -> ValidationResult(String) {
  case string.trim(value) {
    "" -> Error([ValidationField(field, "This field is required")])
    trimmed -> Ok(trimmed)
  }
}

pub fn validate_email(email: String) -> ValidationResult(String) {
  let trimmed = string.trim(email)
  case string.contains(trimmed, "@") && string.contains(trimmed, ".") {
    True -> Ok(trimmed)
    False -> Error([ValidationField("email", "Please enter a valid email address")])
  }
}

pub fn validate_url(url: String, field: String) -> ValidationResult(String) {
  let trimmed = string.trim(url)
  case string.starts_with(trimmed, "http://") || string.starts_with(trimmed, "https://") {
    True -> Ok(trimmed)
    False -> Error([ValidationField(field, "Please enter a valid URL starting with http:// or https://")])
  }
}

pub fn combine_validation_results(results: List(ValidationResult(a))) -> ValidationResult(List(a)) {
  list.fold(results, Ok([]), fn(acc, result) {
    case acc, result {
      Ok(values), Ok(value) -> Ok(list.prepend(values, value))
      Ok(_), Error(errors) -> Error(errors)
      Error(acc_errors), Ok(_) -> Error(acc_errors)
      Error(acc_errors), Error(errors) -> Error(list.append(acc_errors, errors))
    }
  })
  |> result.map(list.reverse)
}

pub fn validate_string_length(value: String, field: String, min_length: Int, max_length: Int) -> ValidationResult(String) {
  let length = string.length(value)
  case length >= min_length && length <= max_length {
    True -> Ok(value)
    False -> Error([ValidationField(field, "Must be between " <> int.to_string(min_length) <> " and " <> int.to_string(max_length) <> " characters long")])
  }
}

pub fn validate_positive_integer(value: Int, field: String) -> ValidationResult(String) {
  case value > 0 {
    True -> Ok(int.to_string(value))
    False -> Error([ValidationField(field, "Must be a positive integer")])
  }
}