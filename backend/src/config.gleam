import envoy
import gleam/int
import gleam/result
import gleam/string

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

pub type ServiceConfig {
  ServiceConfig(
    supabase: SupabaseConfig,
    auth0: Auth0Config,
    cloudinary: CloudinaryConfig,
  )
}

pub type SupabaseConfig {
  SupabaseConfig(
    url: String,
    anon_key: String,
    service_role_key: String,
  )
}

pub type Auth0Config {
  Auth0Config(
    domain: String,
    client_id: String,
    client_secret: String,
    api_audience: String,
  )
}

pub type CloudinaryConfig {
  CloudinaryConfig(
    cloud_name: String,
    api_key: String,
    api_secret: String,
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

pub fn load_services(config: Config) -> Result(ServiceConfig, String) {
  use supabase <- result.try(load_supabase_config(config))
  use auth0 <- result.try(load_auth0_config(config))
  use cloudinary <- result.try(load_cloudinary_config(config))
  
  Ok(ServiceConfig(
    supabase: supabase,
    auth0: auth0,
    cloudinary: cloudinary,
  ))
}

fn load_supabase_config(config: Config) -> Result(SupabaseConfig, String) {
  use _ <- result.try(validate_url(config.supabase_url, "SUPABASE_URL"))
  use _ <- result.try(validate_non_empty(config.supabase_anon_key, "SUPABASE_ANON_KEY"))
  use _ <- result.try(validate_non_empty(config.supabase_service_role_key, "SUPABASE_SERVICE_ROLE_KEY"))
  
  Ok(SupabaseConfig(
    url: config.supabase_url,
    anon_key: config.supabase_anon_key,
    service_role_key: config.supabase_service_role_key,
  ))
}

fn load_auth0_config(config: Config) -> Result(Auth0Config, String) {
  use _ <- result.try(validate_non_empty(config.auth0_domain, "AUTH0_DOMAIN"))
  use _ <- result.try(validate_non_empty(config.auth0_client_id, "AUTH0_CLIENT_ID"))
  use _ <- result.try(validate_non_empty(config.auth0_client_secret, "AUTH0_CLIENT_SECRET"))
  use _ <- result.try(validate_non_empty(config.auth0_api_audience, "AUTH0_API_AUDIENCE"))
  
  Ok(Auth0Config(
    domain: config.auth0_domain,
    client_id: config.auth0_client_id,
    client_secret: config.auth0_client_secret,
    api_audience: config.auth0_api_audience,
  ))
}

fn load_cloudinary_config(config: Config) -> Result(CloudinaryConfig, String) {
  use _ <- result.try(validate_non_empty(config.cloudinary_cloud_name, "CLOUDINARY_CLOUD_NAME"))
  use _ <- result.try(validate_non_empty(config.cloudinary_api_key, "CLOUDINARY_API_KEY"))
  use _ <- result.try(validate_non_empty(config.cloudinary_api_secret, "CLOUDINARY_API_SECRET"))
  
  Ok(CloudinaryConfig(
    cloud_name: config.cloudinary_cloud_name,
    api_key: config.cloudinary_api_key,
    api_secret: config.cloudinary_api_secret,
  ))
}

fn validate_url(url: String, field_name: String) -> Result(Nil, String) {
  case string.starts_with(url, "http://") || string.starts_with(url, "https://") {
    True -> Ok(Nil)
    False -> Error(field_name <> " must be a valid URL starting with http:// or https://")
  }
}

fn validate_non_empty(value: String, field_name: String) -> Result(Nil, String) {
  case string.trim(value) {
    "" -> Error(field_name <> " cannot be empty")
    _ -> Ok(Nil)
  }
}

pub fn get_supabase_headers(config: SupabaseConfig, use_service_role: Bool) -> List(#(String, String)) {
  let auth_key = case use_service_role {
    True -> config.service_role_key
    False -> config.anon_key
  }
  
  [
    #("apikey", auth_key),
    #("Authorization", "Bearer " <> auth_key),
    #("Content-Type", "application/json"),
  ]
}

pub fn get_auth0_api_url(config: Auth0Config) -> String {
  "https://" <> config.domain <> "/api/v2/"
}

pub fn get_cloudinary_upload_url(config: CloudinaryConfig) -> String {
  "https://api.cloudinary.com/v1_1/" <> config.cloud_name <> "/image/upload"
}