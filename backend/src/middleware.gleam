import api_types.{type ApiError}
import gleam/http.{Get, Post, Put, Delete, Patch, Head, Options, Connect, Trace, Other}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import gleam/string
import mist
import response_helpers

pub type Middleware(a) =
  fn(Request(a)) -> Result(Request(a), ApiError)

pub fn cors_middleware(req: Request(a)) -> Request(a) {
  req
}

pub fn add_cors_headers(res: Response(mist.ResponseData)) -> Response(mist.ResponseData) {
  res
  |> response.set_header("Access-Control-Allow-Origin", "*")
  |> response.set_header("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
  |> response.set_header("Access-Control-Allow-Headers", "Content-Type, Authorization")
}

pub fn logging_middleware(req: Request(a)) -> Result(Request(a), ApiError) {
  let method = case req.method {
    Get -> "GET"
    Post -> "POST"
    Put -> "PUT"
    Delete -> "DELETE"
    Patch -> "PATCH"
    Head -> "HEAD"
    Options -> "OPTIONS"
    Connect -> "CONNECT"
    Trace -> "TRACE"
    Other(method) -> method
  }
  
  let path = "/" <> string.join(request.path_segments(req), "/")
  io.println(method <> " " <> path)
  Ok(req)
}

pub fn json_content_type_middleware(req: Request(a)) -> Result(Request(a), ApiError) {
  case req.method {
    Post | Put | Patch -> {
      case request.get_header(req, "content-type") {
        Ok(content_type) -> {
          case string.contains(content_type, "application/json") {
            True -> Ok(req)
            False -> Error(api_types.BadRequestError("Content-Type must be application/json"))
          }
        }
        Error(_) -> Error(api_types.BadRequestError("Content-Type header is required"))
      }
    }
    _ -> Ok(req)
  }
}

pub fn validation_error(message: String) -> ApiError {
  api_types.ValidationError(message)
}

pub fn handle_error(error: ApiError) -> Response(mist.ResponseData) {
  case error {
    api_types.ValidationError(msg) -> {
      io.println_error("Validation error: " <> msg)
      response_helpers.error_response(error)
    }
    api_types.NotFoundError(msg) -> {
      io.println_error("Not found: " <> msg)
      response_helpers.error_response(error)
    }
    api_types.UnauthorizedError(msg) -> {
      io.println_error("Unauthorized: " <> msg)
      response_helpers.error_response(error)
    }
    api_types.ForbiddenError(msg) -> {
      io.println_error("Forbidden: " <> msg)
      response_helpers.error_response(error)
    }
    api_types.InternalServerError(msg) -> {
      io.println_error("Internal server error: " <> msg)
      response_helpers.error_response(error)
    }
    api_types.BadRequestError(msg) -> {
      io.println_error("Bad request: " <> msg)
      response_helpers.error_response(error)
    }
    api_types.ConflictError(msg) -> {
      io.println_error("Conflict: " <> msg)
      response_helpers.error_response(error)
    }
    api_types.TooManyRequestsError(msg) -> {
      io.println_error("Too many requests: " <> msg)
      response_helpers.error_response(error)
    }
  }
}