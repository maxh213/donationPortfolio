import envoy
import gleam/int
import gleam/result

pub type Config {
  Config(
    port: Int,
    supabase_url: String,
    supabase_anon_key: String,
    supabase_service_role_key: String,
    auth0_domain: String,
    auth0_client_id: String,
    auth0_client_secret: String,
    auth0_api_audience: String,
    cloudinary_cloud_name: String,
    cloudinary_api_key: String,
    cloudinary_api_secret: String,
    database_url: String,
  )
}

pub fn load() -> Result(Config, String) {
  use port <- result.try(get_port())
  use supabase_url <- result.try(get_env("SUPABASE_URL"))
  use supabase_anon_key <- result.try(get_env("SUPABASE_ANON_KEY"))
  use supabase_service_role_key <- result.try(get_env("SUPABASE_SERVICE_ROLE_KEY"))
  use auth0_domain <- result.try(get_env("AUTH0_DOMAIN"))
  use auth0_client_id <- result.try(get_env("AUTH0_CLIENT_ID"))
  use auth0_client_secret <- result.try(get_env("AUTH0_CLIENT_SECRET"))
  use auth0_api_audience <- result.try(get_env("AUTH0_API_AUDIENCE"))
  use cloudinary_cloud_name <- result.try(get_env("CLOUDINARY_CLOUD_NAME"))
  use cloudinary_api_key <- result.try(get_env("CLOUDINARY_API_KEY"))
  use cloudinary_api_secret <- result.try(get_env("CLOUDINARY_API_SECRET"))
  use database_url <- result.try(get_env("DATABASE_URL"))
  
  Ok(Config(
    port: port,
    supabase_url: supabase_url,
    supabase_anon_key: supabase_anon_key,
    supabase_service_role_key: supabase_service_role_key,
    auth0_domain: auth0_domain,
    auth0_client_id: auth0_client_id,
    auth0_client_secret: auth0_client_secret,
    auth0_api_audience: auth0_api_audience,
    cloudinary_cloud_name: cloudinary_cloud_name,
    cloudinary_api_key: cloudinary_api_key,
    cloudinary_api_secret: cloudinary_api_secret,
    database_url: database_url,
  ))
}

fn get_port() -> Result(Int, String) {
  case envoy.get("PORT") {
    Ok(port_str) -> 
      case int.parse(port_str) {
        Ok(port) -> Ok(port)
        Error(_) -> Ok(8000)
      }
    Error(_) -> Ok(8000)
  }
}

fn get_env(key: String) -> Result(String, String) {
  case envoy.get(key) {
    Ok(value) -> Ok(value)
    Error(_) -> Error("Missing required environment variable: " <> key)
  }
}