import config
import database
import gleam/erlang/process
import gleam/http.{Get}
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/json
import gleam/option
import middleware
import mist
import response_helpers
import wisp

pub fn main() -> Nil {
  wisp.configure_logger()
  
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
