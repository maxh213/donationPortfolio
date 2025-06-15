import api_types.{type ApiError}
import auth0.{type User, type ValidationError}
import config.{type ServiceConfig}
import database.{type DatabaseError}
import gleam/http.{Get, Post, Put, Delete, Patch, Head, Options, Connect, Trace, Other}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/io
import gleam/option
import gleam/result
import gleam/string
import mist
import response_helpers

pub type Middleware(a) =
  fn(Request(a)) -> Result(Request(a), ApiError)

pub type AuthenticatedRequest(a) {
  AuthenticatedRequest(request: Request(a), user: User)
}

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

pub fn multipart_content_type_middleware(req: Request(a)) -> Result(Request(a), ApiError) {
  case req.method {
    Post | Put | Patch -> {
      case request.get_header(req, "content-type") {
        Ok(content_type) -> {
          case string.contains(content_type, "multipart/form-data") {
            True -> Ok(req)
            False -> Error(api_types.BadRequestError("Content-Type must be multipart/form-data"))
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

pub fn auth_middleware(req: Request(a), services: ServiceConfig) -> Result(AuthenticatedRequest(a), ApiError) {
  use auth_header <- result.try(
    request.get_header(req, "authorization")
    |> result.map_error(fn(_) { api_types.UnauthorizedError("Authorization header is required") })
  )
  
  use token <- result.try(
    auth0.extract_bearer_token(auth_header)
    |> result.map_error(auth_validation_error_to_api_error)
  )
  
  use user <- result.try(
    auth0.validate_token(token, services.auth0)
    |> result.map_error(auth_validation_error_to_api_error)
  )
  
  use _profile <- result.try(
    sync_user_profile(user, services)
    |> result.map_error(database_error_to_api_error)
  )
  
  Ok(AuthenticatedRequest(request: req, user: user))
}

fn auth_validation_error_to_api_error(error: ValidationError) -> ApiError {
  case error {
    auth0.InvalidToken -> api_types.UnauthorizedError("Invalid token")
    auth0.ExpiredToken -> api_types.UnauthorizedError("Token has expired")
    auth0.InvalidAudience -> api_types.UnauthorizedError("Invalid token audience")
    auth0.InvalidIssuer -> api_types.UnauthorizedError("Invalid token issuer")
    auth0.InvalidSignature -> api_types.UnauthorizedError("Invalid token signature")
    auth0.NetworkError(msg) -> api_types.InternalServerError("Authentication service error: " <> msg)
    auth0.ParseError(msg) -> api_types.UnauthorizedError("Token parsing error: " <> msg)
  }
}

pub fn database_error_to_api_error(error: DatabaseError) -> ApiError {
  case error {
    database.RequestError(msg) -> api_types.InternalServerError("Database request error: " <> msg)
    database.ParseError(msg) -> api_types.InternalServerError("Database parse error: " <> msg)
    database.NotFound -> api_types.NotFoundError("Resource not found")
    database.AuthenticationError -> api_types.UnauthorizedError("Database authentication failed")
    database.PermissionError -> api_types.ForbiddenError("Database permission denied")
  }
}

fn sync_user_profile(user: User, services: ServiceConfig) -> Result(database.Profile, DatabaseError) {
  let client = database.new_client(services.supabase)
  let full_name = case string.trim(user.name) {
    "" -> option.None
    name -> option.Some(name)
  }
  let profile_picture_url = case string.trim(user.picture) {
    "" -> option.None
    url -> option.Some(url)
  }
  
  database.get_or_create_profile(
    client,
    user.id,
    user.email,
    full_name,
    profile_picture_url,
  )
}