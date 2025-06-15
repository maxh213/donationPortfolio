import config
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/json
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
  case request.path_segments(req) {
    [] -> handle_root(req, config, services)
    ["health"] -> handle_health(req, config, services)
    _ -> response_helpers.not_found()
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
