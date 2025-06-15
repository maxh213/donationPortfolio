import config
import gleam/dynamic/decode
import gleam/http.{Get, Post, Put, Patch, Delete}
import gleam/http/request
import gleam/http/response
import gleam/httpc
import gleam/json
import gleam/list
import gleam/option.{type Option}
import gleam/result
import gleam/string

pub type Profile {
  Profile(
    id: String,
    email: String,
    full_name: Option(String),
    profile_picture_url: Option(String),
    created_at: String,
    updated_at: String,
  )
}

pub type CauseArea {
  CauseArea(
    id: Int,
    name: String,
    description: Option(String),
    color_hex: Option(String),
    created_by: String,
    created_at: String,
    updated_at: String,
  )
}

pub type Charity {
  Charity(
    id: Int,
    name: String,
    website_url: Option(String),
    description: Option(String),
    logo_url: Option(String),
    primary_cause_area_id: Option(Int),
    created_by: String,
    created_at: String,
    updated_at: String,
  )
}

pub type Donation {
  Donation(
    id: Int,
    user_id: String,
    charity_id: Int,
    amount: String,
    currency: String,
    donation_date: String,
    notes: Option(String),
    created_at: String,
    updated_at: String,
  )
}

pub type DatabaseError {
  RequestError(String)
  ParseError(String)
  NotFound
  AuthenticationError
  PermissionError
}

pub type SupabaseClient {
  SupabaseClient(config: config.SupabaseConfig)
}

pub fn new_client(config: config.SupabaseConfig) -> SupabaseClient {
  SupabaseClient(config: config)
}

fn build_request(
  client: SupabaseClient,
  method: String,
  path: String,
  use_service_role: Bool,
) -> Result(request.Request(String), DatabaseError) {
  let url = client.config.url <> "/rest/v1" <> path
  let headers = config.get_supabase_headers(client.config, use_service_role)
  
  case request.to(url) {
    Ok(req) -> {
      let req_with_headers = list.fold(headers, req, fn(acc, header) {
        request.set_header(acc, header.0, header.1)
      })
      Ok(request.set_method(req_with_headers, case method {
        "GET" -> Get
        "POST" -> Post
        "PUT" -> Put
        "PATCH" -> Patch
        "DELETE" -> Delete
        _ -> Get
      }))
    }
    Error(_) -> Error(RequestError("Invalid URL: " <> url))
  }
}

fn send_request(
  req: request.Request(String),
) -> Result(response.Response(String), DatabaseError) {
  case httpc.send(req) {
    Ok(resp) -> {
      case resp.status {
        200 | 201 -> Ok(resp)
        204 -> Ok(resp)
        401 -> Error(AuthenticationError)
        403 -> Error(PermissionError)
        404 -> Error(NotFound)
        _ -> Error(RequestError("HTTP " <> string.inspect(resp.status) <> ": " <> resp.body))
      }
    }
    Error(_) -> Error(RequestError("Network error"))
  }
}

pub fn get_profile(
  client: SupabaseClient,
  user_id: String,
) -> Result(Profile, DatabaseError) {
  use req <- result.try(build_request(
    client,
    "GET",
    "/profiles?id=eq." <> user_id <> "&select=*",
    False,
  ))
  
  use resp <- result.try(send_request(req))
  
  case parse_profiles(resp.body) {
    [profile] -> Ok(profile)
    [] -> Error(NotFound)
    _ -> Error(ParseError("Multiple profiles found"))
  }
}

pub fn list_cause_areas(
  client: SupabaseClient,
  user_id: String,
) -> Result(List(CauseArea), DatabaseError) {
  use req <- result.try(build_request(
    client,
    "GET",
    "/cause_areas?created_by=eq." <> user_id <> "&select=*&order=name",
    False,
  ))
  
  use resp <- result.try(send_request(req))
  Ok(parse_cause_areas(resp.body))
}

pub fn list_charities(
  client: SupabaseClient,
  user_id: String,
) -> Result(List(Charity), DatabaseError) {
  use req <- result.try(build_request(
    client,
    "GET",
    "/charities?created_by=eq." <> user_id <> "&select=*&order=name",
    False,
  ))
  
  use resp <- result.try(send_request(req))
  Ok(parse_charities(resp.body))
}

pub fn list_donations(
  client: SupabaseClient,
  user_id: String,
) -> Result(List(Donation), DatabaseError) {
  use req <- result.try(build_request(
    client,
    "GET",
    "/donations?user_id=eq." <> user_id <> "&select=*&order=donation_date.desc",
    False,
  ))
  
  use resp <- result.try(send_request(req))
  Ok(parse_donations(resp.body))
}

fn parse_profiles(json_str: String) -> List(Profile) {
  let decoder = decode.list(profile_decoder())
  case json.parse(from: json_str, using: decoder) {
    Ok(profiles) -> profiles
    Error(_) -> []
  }
}

fn parse_cause_areas(json_str: String) -> List(CauseArea) {
  let decoder = decode.list(cause_area_decoder())
  case json.parse(from: json_str, using: decoder) {
    Ok(cause_areas) -> cause_areas
    Error(_) -> []
  }
}

fn parse_charities(json_str: String) -> List(Charity) {
  let decoder = decode.list(charity_decoder())
  case json.parse(from: json_str, using: decoder) {
    Ok(charities) -> charities
    Error(_) -> []
  }
}

fn parse_donations(json_str: String) -> List(Donation) {
  let decoder = decode.list(donation_decoder())
  case json.parse(from: json_str, using: decoder) {
    Ok(donations) -> donations
    Error(_) -> []
  }
}

fn profile_decoder() -> decode.Decoder(Profile) {
  use id <- decode.field("id", decode.string)
  use email <- decode.field("email", decode.string)
  use full_name <- decode.field("full_name", decode.optional(decode.string))
  use profile_picture_url <- decode.field("profile_picture_url", decode.optional(decode.string))
  use created_at <- decode.field("created_at", decode.string)
  use updated_at <- decode.field("updated_at", decode.string)
  decode.success(Profile(
    id: id,
    email: email,
    full_name: full_name,
    profile_picture_url: profile_picture_url,
    created_at: created_at,
    updated_at: updated_at,
  ))
}

fn cause_area_decoder() -> decode.Decoder(CauseArea) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use description <- decode.field("description", decode.optional(decode.string))
  use color_hex <- decode.field("color_hex", decode.optional(decode.string))
  use created_by <- decode.field("created_by", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  use updated_at <- decode.field("updated_at", decode.string)
  decode.success(CauseArea(
    id: id,
    name: name,
    description: description,
    color_hex: color_hex,
    created_by: created_by,
    created_at: created_at,
    updated_at: updated_at,
  ))
}

fn charity_decoder() -> decode.Decoder(Charity) {
  use id <- decode.field("id", decode.int)
  use name <- decode.field("name", decode.string)
  use website_url <- decode.field("website_url", decode.optional(decode.string))
  use description <- decode.field("description", decode.optional(decode.string))
  use logo_url <- decode.field("logo_url", decode.optional(decode.string))
  use primary_cause_area_id <- decode.field("primary_cause_area_id", decode.optional(decode.int))
  use created_by <- decode.field("created_by", decode.string)
  use created_at <- decode.field("created_at", decode.string)
  use updated_at <- decode.field("updated_at", decode.string)
  decode.success(Charity(
    id: id,
    name: name,
    website_url: website_url,
    description: description,
    logo_url: logo_url,
    primary_cause_area_id: primary_cause_area_id,
    created_by: created_by,
    created_at: created_at,
    updated_at: updated_at,
  ))
}

fn donation_decoder() -> decode.Decoder(Donation) {
  use id <- decode.field("id", decode.int)
  use user_id <- decode.field("user_id", decode.string)
  use charity_id <- decode.field("charity_id", decode.int)
  use amount <- decode.field("amount", decode.string)
  use currency <- decode.field("currency", decode.string)
  use donation_date <- decode.field("donation_date", decode.string)
  use notes <- decode.field("notes", decode.optional(decode.string))
  use created_at <- decode.field("created_at", decode.string)
  use updated_at <- decode.field("updated_at", decode.string)
  decode.success(Donation(
    id: id,
    user_id: user_id,
    charity_id: charity_id,
    amount: amount,
    currency: currency,
    donation_date: donation_date,
    notes: notes,
    created_at: created_at,
    updated_at: updated_at,
  ))
}