import api_types
import cloudinary
import config
import database
import dot_env as dotenv
import gleam/erlang/process
import gleam/dynamic/decode
import gleam/http.{Get, Post, Put}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/json
import gleam/option
import gleam/bit_array
import gleam/string
import middleware
import mist
import response_helpers
import wisp

pub fn main() -> Nil {
  wisp.configure_logger()
  
  // Load environment variables from .env file
  dotenv.new()
  |> dotenv.set_path("../.env")
  |> dotenv.set_debug(False)
  |> dotenv.load
  
  let config = case config.load() {
    Ok(config) -> config
    Error(msg) -> {
      io.println_error("Configuration error: " <> msg)
      panic as "Failed to load configuration"
    }
  }
  
  let services = case config.load_services(config) {
    Ok(services) -> services
    Error(msg) -> {
      io.println_error("Service configuration error: " <> msg)
      panic as "Failed to load service configuration"
    }
  }
  
  let assert Ok(_) =
    fn(req) { handle_request(req, config, services) }
    |> mist.new
    |> mist.port(config.port)
    |> mist.start_http
  
  io.println("Server started on http://localhost:" <> int.to_string(config.port))
  io.println("Services configured: Supabase, Auth0, Cloudinary")
  process.sleep_forever()
}

fn handle_request(req: Request(mist.Connection), config: config.Config, services: config.ServiceConfig) -> Response(mist.ResponseData) {
  case middleware.logging_middleware(req) {
    Ok(logged_req) -> {
      let response = case request.path_segments(logged_req) {
        [] -> handle_root(logged_req, config, services)
        ["health"] -> handle_health(logged_req, config, services)
        ["api", "profile"] -> handle_profile(logged_req, config, services)
        ["api", "profile", "picture"] -> handle_profile_picture(logged_req, config, services)
        _ -> response_helpers.not_found()
      }
      middleware.add_cors_headers(response)
    }
    Error(error) -> middleware.handle_error(error)
  }
}

fn handle_root(_req: Request(mist.Connection), _config: config.Config, _services: config.ServiceConfig) -> Response(mist.ResponseData) {
  let data = json.object([
    #("message", json.string("Donation Portfolio API")),
    #("status", json.string("running")),
    #("version", json.string("1.0.0")),
    #("services", json.object([
      #("supabase", json.string("configured")),
      #("auth0", json.string("configured")),
      #("cloudinary", json.string("configured"))
    ]))
  ])
  response_helpers.success_response(data)
}

fn handle_health(_req: Request(mist.Connection), _config: config.Config, services: config.ServiceConfig) -> Response(mist.ResponseData) {
  let data = json.object([
    #("status", json.string("healthy")),
    #("services", json.object([
      #("supabase_url", json.string(services.supabase.url)),
      #("auth0_domain", json.string(services.auth0.domain)),
      #("cloudinary_cloud", json.string(services.cloudinary.cloud_name))
    ]))
  ])
  response_helpers.success_response(data)
}

fn handle_profile(req: Request(mist.Connection), _config: config.Config, services: config.ServiceConfig) -> Response(mist.ResponseData) {
  case req.method {
    Get -> get_profile(req, services)
    Put -> update_profile(req, services)
    _ -> response_helpers.method_not_allowed()
  }
}

fn handle_profile_picture(req: Request(mist.Connection), _config: config.Config, services: config.ServiceConfig) -> Response(mist.ResponseData) {
  case req.method {
    Post -> upload_profile_picture(req, services)
    _ -> response_helpers.method_not_allowed()
  }
}

fn get_profile(req: Request(mist.Connection), services: config.ServiceConfig) -> Response(mist.ResponseData) {
  case middleware.auth_middleware(req, services) {
    Ok(auth_req) -> {
      let client = database.new_client(services.supabase)
      case database.get_profile(client, auth_req.user.id) {
        Ok(profile) -> {
          let profile_json = json.object([
            #("id", json.string(profile.id)),
            #("email", json.string(profile.email)),
            #("full_name", case profile.full_name {
              option.Some(name) -> json.string(name)
              option.None -> json.null()
            }),
            #("profile_picture_url", case profile.profile_picture_url {
              option.Some(url) -> json.string(url)
              option.None -> json.null()
            }),
            #("created_at", json.string(profile.created_at)),
            #("updated_at", json.string(profile.updated_at))
          ])
          response_helpers.success_response(profile_json)
        }
        Error(database_error) -> {
          let api_error = middleware.database_error_to_api_error(database_error)
          middleware.handle_error(api_error)
        }
      }
    }
    Error(api_error) -> middleware.handle_error(api_error)
  }
}

pub type ProfileUpdateRequest {
  ProfileUpdateRequest(
    full_name: option.Option(String),
    email: option.Option(String),
  )
}

fn update_profile(req: Request(mist.Connection), services: config.ServiceConfig) -> Response(mist.ResponseData) {
  case middleware.auth_middleware(req, services) {
    Ok(auth_req) -> {
      case middleware.json_content_type_middleware(auth_req.request) {
        Ok(validated_req) -> {
          case mist.read_body(validated_req, 1024 * 1024) {
            Ok(body_request) -> {
              case bit_array.to_string(body_request.body) {
                Ok(body_string) -> {
                  case parse_profile_update_request(body_string) {
                Ok(update_request) -> {
                  let client = database.new_client(services.supabase)
                  
                  case update_request {
                    ProfileUpdateRequest(full_name: full_name, email: email) -> {
                      case email {
                        option.Some(_) -> {
                          middleware.handle_error(api_types.BadRequestError("Email updates are not allowed via this endpoint"))
                        }
                        option.None -> {
                          case database.update_profile(client, auth_req.user.id, full_name, option.None) {
                            Ok(profile) -> {
                              let profile_json = json.object([
                                #("id", json.string(profile.id)),
                                #("email", json.string(profile.email)),
                                #("full_name", case profile.full_name {
                                  option.Some(name) -> json.string(name)
                                  option.None -> json.null()
                                }),
                                #("profile_picture_url", case profile.profile_picture_url {
                                  option.Some(url) -> json.string(url)
                                  option.None -> json.null()
                                }),
                                #("created_at", json.string(profile.created_at)),
                                #("updated_at", json.string(profile.updated_at))
                              ])
                              response_helpers.success_response(profile_json)
                            }
                            Error(database_error) -> {
                              let api_error = middleware.database_error_to_api_error(database_error)
                              middleware.handle_error(api_error)
                            }
                          }
                        }
                      }
                    }
                  }
                    }
                    Error(api_error) -> middleware.handle_error(api_error)
                  }
                }
                Error(_) -> middleware.handle_error(api_types.BadRequestError("Failed to decode request body as UTF-8"))
              }
            }
            Error(_) -> middleware.handle_error(api_types.BadRequestError("Failed to read request body"))
          }
        }
        Error(api_error) -> middleware.handle_error(api_error)
      }
    }
    Error(api_error) -> middleware.handle_error(api_error)
  }
}

fn parse_profile_update_request(body: String) -> Result(ProfileUpdateRequest, api_types.ApiError) {
  let decoder = {
    use full_name <- decode.field("full_name", decode.optional(decode.string))
    use email <- decode.field("email", decode.optional(decode.string))
    decode.success(ProfileUpdateRequest(full_name: full_name, email: email))
  }
  
  case json.parse(from: body, using: decoder) {
    Ok(request) -> {
      case request.full_name {
        option.Some(name) -> {
          case string.trim(name) {
            "" -> Error(api_types.ValidationError("Full name cannot be empty"))
            _ -> Ok(request)
          }
        }
        option.None -> Ok(request)
      }
    }
    Error(_) -> Error(api_types.BadRequestError("Invalid JSON format"))
  }
}

fn upload_profile_picture(req: Request(mist.Connection), services: config.ServiceConfig) -> Response(mist.ResponseData) {
  case middleware.auth_middleware(req, services) {
    Ok(auth_req) -> {
      case middleware.multipart_content_type_middleware(auth_req.request) {
        Ok(validated_req) -> {
          case mist.read_body(validated_req, 10 * 1024 * 1024) {
            Ok(body_request) -> {
              let upload_preset = "profile_pictures"
              let public_id = "profile_" <> auth_req.user.id
              
              case cloudinary.upload_image(services.cloudinary, body_request.body, upload_preset, public_id) {
                Ok(upload_result) -> {
                  let client = database.new_client(services.supabase)
                  case database.update_profile(client, auth_req.user.id, option.None, option.Some(upload_result.secure_url)) {
                    Ok(profile) -> {
                      let response_data = json.object([
                        #("message", json.string("Profile picture uploaded successfully")),
                        #("profile_picture_url", json.string(upload_result.secure_url)),
                        #("profile", json.object([
                          #("id", json.string(profile.id)),
                          #("email", json.string(profile.email)),
                          #("full_name", case profile.full_name {
                            option.Some(name) -> json.string(name)
                            option.None -> json.null()
                          }),
                          #("profile_picture_url", case profile.profile_picture_url {
                            option.Some(url) -> json.string(url)
                            option.None -> json.null()
                          }),
                          #("created_at", json.string(profile.created_at)),
                          #("updated_at", json.string(profile.updated_at))
                        ]))
                      ])
                      response_helpers.success_response(response_data)
                    }
                    Error(database_error) -> {
                      let api_error = middleware.database_error_to_api_error(database_error)
                      middleware.handle_error(api_error)
                    }
                  }
                }
                Error(cloudinary_error) -> {
                  let api_error = case cloudinary_error {
                    cloudinary.NetworkError(msg) -> api_types.InternalServerError("Cloudinary network error: " <> msg)
                    cloudinary.AuthenticationError(msg) -> api_types.InternalServerError("Cloudinary authentication error: " <> msg)
                    cloudinary.ValidationError(msg) -> api_types.BadRequestError("Invalid image: " <> msg)
                    cloudinary.UnknownError(msg) -> api_types.InternalServerError("Cloudinary error: " <> msg)
                  }
                  middleware.handle_error(api_error)
                }
              }
            }
            Error(_) -> middleware.handle_error(api_types.BadRequestError("Failed to read request body"))
          }
        }
        Error(api_error) -> middleware.handle_error(api_error)
      }
    }
    Error(api_error) -> middleware.handle_error(api_error)
  }
}
