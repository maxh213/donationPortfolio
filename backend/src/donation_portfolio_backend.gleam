import config
import gleam/bytes_tree
import gleam/erlang/process
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/int
import gleam/io
import gleam/json
import mist
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
  
  let assert Ok(_) =
    fn(req) { handle_request(req, config) }
    |> mist.new
    |> mist.port(config.port)
    |> mist.start_http
  
  io.println("Server started on http://localhost:" <> int.to_string(config.port))
  process.sleep_forever()
}

fn handle_request(req: Request(mist.Connection), config: config.Config) -> Response(mist.ResponseData) {
  case request.path_segments(req) {
    [] -> {
      response.new(200)
      |> response.set_body(mist.Bytes(bytes_tree.from_string("<h1>Donation Portfolio API</h1><p>Server is running!</p>")))
      |> response.set_header("content-type", "text/html")
    }
    ["health"] -> {
      let body = json.to_string(json.object([#("status", json.string("healthy"))]))
      response.new(200)
      |> response.set_body(mist.Bytes(bytes_tree.from_string(body)))
      |> response.set_header("content-type", "application/json")
    }
    _ -> {
      response.new(404)
      |> response.set_body(mist.Bytes(bytes_tree.from_string("Not Found")))
    }
  }
}
