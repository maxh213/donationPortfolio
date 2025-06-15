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

pub fn create_profile(
  client: SupabaseClient,
  user_id: String,
  email: String,
  full_name: Option(String),
  profile_picture_url: Option(String),
) -> Result(Profile, DatabaseError) {
  let profile_data = case full_name, profile_picture_url {
    option.Some(name), option.Some(pic_url) -> 
      "{\"id\":\"" <> user_id <> "\",\"email\":\"" <> email <> "\",\"full_name\":\"" <> name <> "\",\"profile_picture_url\":\"" <> pic_url <> "\"}"
    option.Some(name), option.None -> 
      "{\"id\":\"" <> user_id <> "\",\"email\":\"" <> email <> "\",\"full_name\":\"" <> name <> "\"}"
    option.None, option.Some(pic_url) -> 
      "{\"id\":\"" <> user_id <> "\",\"email\":\"" <> email <> "\",\"profile_picture_url\":\"" <> pic_url <> "\"}"
    option.None, option.None -> 
      "{\"id\":\"" <> user_id <> "\",\"email\":\"" <> email <> "\"}"
  }
  
  use req <- result.try(build_request(client, "POST", "/profiles", False))
  let req_with_body = request.set_body(req, profile_data)
  
  use resp <- result.try(send_request(req_with_body))
  
  case parse_profiles(resp.body) {
    [profile] -> Ok(profile)
    [] -> Error(ParseError("No profile returned after creation"))
    _ -> Error(ParseError("Multiple profiles returned after creation"))
  }
}

pub fn get_or_create_profile(
  client: SupabaseClient,
  user_id: String,
  email: String,
  full_name: Option(String),
  profile_picture_url: Option(String),
) -> Result(Profile, DatabaseError) {
  case get_profile(client, user_id) {
    Ok(profile) -> Ok(profile)
    Error(NotFound) -> create_profile(client, user_id, email, full_name, profile_picture_url)
    Error(other_error) -> Error(other_error)
  }
}

pub fn update_profile(
  client: SupabaseClient,
  user_id: String,
  full_name: Option(String),
  profile_picture_url: Option(String),
) -> Result(Profile, DatabaseError) {
  let update_data = case full_name, profile_picture_url {
    option.Some(name), option.Some(pic_url) -> 
      "{\"full_name\":\"" <> name <> "\",\"profile_picture_url\":\"" <> pic_url <> "\"}"
    option.Some(name), option.None -> 
      "{\"full_name\":\"" <> name <> "\"}"
    option.None, option.Some(pic_url) -> 
      "{\"profile_picture_url\":\"" <> pic_url <> "\"}"
    option.None, option.None -> 
      "{}"
  }
  
  use req <- result.try(build_request(
    client,
    "PATCH",
    "/profiles?id=eq." <> user_id,
    False,
  ))
  let req_with_body = request.set_body(req, update_data)
  
  use resp <- result.try(send_request(req_with_body))
  
  case parse_profiles(resp.body) {
    [profile] -> Ok(profile)
    [] -> Error(NotFound)
    _ -> Error(ParseError("Multiple profiles updated"))
  }
}

pub fn delete_profile(
  client: SupabaseClient,
  user_id: String,
) -> Result(Nil, DatabaseError) {
  use req <- result.try(build_request(
    client,
    "DELETE",
    "/profiles?id=eq." <> user_id,
    False,
  ))
  
  use _resp <- result.try(send_request(req))
  Ok(Nil)
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

pub fn get_cause_area(
  client: SupabaseClient,
  cause_area_id: Int,
  user_id: String,
) -> Result(CauseArea, DatabaseError) {
  use req <- result.try(build_request(
    client,
    "GET",
    "/cause_areas?id=eq." <> string.inspect(cause_area_id) <> "&created_by=eq." <> user_id <> "&select=*",
    False,
  ))
  
  use resp <- result.try(send_request(req))
  
  case parse_cause_areas(resp.body) {
    [cause_area] -> Ok(cause_area)
    [] -> Error(NotFound)
    _ -> Error(ParseError("Multiple cause areas found"))
  }
}

pub fn create_cause_area(
  client: SupabaseClient,
  name: String,
  description: Option(String),
  color_hex: Option(String),
  user_id: String,
) -> Result(CauseArea, DatabaseError) {
  let cause_area_data = case description, color_hex {
    option.Some(desc), option.Some(color) -> 
      "{\"name\":\"" <> name <> "\",\"description\":\"" <> desc <> "\",\"color_hex\":\"" <> color <> "\",\"created_by\":\"" <> user_id <> "\"}"
    option.Some(desc), option.None -> 
      "{\"name\":\"" <> name <> "\",\"description\":\"" <> desc <> "\",\"created_by\":\"" <> user_id <> "\"}"
    option.None, option.Some(color) -> 
      "{\"name\":\"" <> name <> "\",\"color_hex\":\"" <> color <> "\",\"created_by\":\"" <> user_id <> "\"}"
    option.None, option.None -> 
      "{\"name\":\"" <> name <> "\",\"created_by\":\"" <> user_id <> "\"}"
  }
  
  use req <- result.try(build_request(client, "POST", "/cause_areas", False))
  let req_with_body = request.set_body(req, cause_area_data)
  
  use resp <- result.try(send_request(req_with_body))
  
  case parse_cause_areas(resp.body) {
    [cause_area] -> Ok(cause_area)
    [] -> Error(ParseError("No cause area returned after creation"))
    _ -> Error(ParseError("Multiple cause areas returned after creation"))
  }
}

pub fn update_cause_area(
  client: SupabaseClient,
  cause_area_id: Int,
  name: Option(String),
  description: Option(String),
  color_hex: Option(String),
  user_id: String,
) -> Result(CauseArea, DatabaseError) {
  let update_fields = []
  let update_fields = case name {
    option.Some(n) -> ["\"name\":\"" <> n <> "\"", ..update_fields]
    option.None -> update_fields
  }
  let update_fields = case description {
    option.Some(d) -> ["\"description\":\"" <> d <> "\"", ..update_fields]
    option.None -> update_fields
  }
  let update_fields = case color_hex {
    option.Some(c) -> ["\"color_hex\":\"" <> c <> "\"", ..update_fields]
    option.None -> update_fields
  }
  
  let update_data = case update_fields {
    [] -> "{}"
    fields -> "{" <> string.join(list.reverse(fields), ",") <> "}"
  }
  
  use req <- result.try(build_request(
    client,
    "PATCH",
    "/cause_areas?id=eq." <> string.inspect(cause_area_id) <> "&created_by=eq." <> user_id,
    False,
  ))
  let req_with_body = request.set_body(req, update_data)
  
  use resp <- result.try(send_request(req_with_body))
  
  case parse_cause_areas(resp.body) {
    [cause_area] -> Ok(cause_area)
    [] -> Error(NotFound)
    _ -> Error(ParseError("Multiple cause areas updated"))
  }
}

pub fn delete_cause_area(
  client: SupabaseClient,
  cause_area_id: Int,
  user_id: String,
) -> Result(Nil, DatabaseError) {
  use req <- result.try(build_request(
    client,
    "DELETE",
    "/cause_areas?id=eq." <> string.inspect(cause_area_id) <> "&created_by=eq." <> user_id,
    False,
  ))
  
  use _resp <- result.try(send_request(req))
  Ok(Nil)
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

pub fn search_charities(
  client: SupabaseClient,
  user_id: String,
  search_term: String,
) -> Result(List(Charity), DatabaseError) {
  use req <- result.try(build_request(
    client,
    "GET",
    "/charities?created_by=eq." <> user_id <> "&name=ilike.*" <> search_term <> "*&select=*&order=name",
    False,
  ))
  
  use resp <- result.try(send_request(req))
  Ok(parse_charities(resp.body))
}

pub fn get_charity(
  client: SupabaseClient,
  charity_id: Int,
  user_id: String,
) -> Result(Charity, DatabaseError) {
  use req <- result.try(build_request(
    client,
    "GET",
    "/charities?id=eq." <> string.inspect(charity_id) <> "&created_by=eq." <> user_id <> "&select=*",
    False,
  ))
  
  use resp <- result.try(send_request(req))
  
  case parse_charities(resp.body) {
    [charity] -> Ok(charity)
    [] -> Error(NotFound)
    _ -> Error(ParseError("Multiple charities found"))
  }
}

pub fn create_charity(
  client: SupabaseClient,
  name: String,
  website_url: Option(String),
  description: Option(String),
  logo_url: Option(String),
  primary_cause_area_id: Option(Int),
  user_id: String,
) -> Result(Charity, DatabaseError) {
  let charity_fields = ["\"name\":\"" <> name <> "\"", "\"created_by\":\"" <> user_id <> "\""]
  let charity_fields = case website_url {
    option.Some(url) -> ["\"website_url\":\"" <> url <> "\"", ..charity_fields]
    option.None -> charity_fields
  }
  let charity_fields = case description {
    option.Some(desc) -> ["\"description\":\"" <> desc <> "\"", ..charity_fields]
    option.None -> charity_fields
  }
  let charity_fields = case logo_url {
    option.Some(logo) -> ["\"logo_url\":\"" <> logo <> "\"", ..charity_fields]
    option.None -> charity_fields
  }
  let charity_fields = case primary_cause_area_id {
    option.Some(cause_id) -> ["\"primary_cause_area_id\":" <> string.inspect(cause_id), ..charity_fields]
    option.None -> charity_fields
  }
  
  let charity_data = "{" <> string.join(list.reverse(charity_fields), ",") <> "}"
  
  use req <- result.try(build_request(client, "POST", "/charities", False))
  let req_with_body = request.set_body(req, charity_data)
  
  use resp <- result.try(send_request(req_with_body))
  
  case parse_charities(resp.body) {
    [charity] -> Ok(charity)
    [] -> Error(ParseError("No charity returned after creation"))
    _ -> Error(ParseError("Multiple charities returned after creation"))
  }
}

pub fn update_charity(
  client: SupabaseClient,
  charity_id: Int,
  name: Option(String),
  website_url: Option(String),
  description: Option(String),
  logo_url: Option(String),
  primary_cause_area_id: Option(Int),
  user_id: String,
) -> Result(Charity, DatabaseError) {
  let update_fields = []
  let update_fields = case name {
    option.Some(n) -> ["\"name\":\"" <> n <> "\"", ..update_fields]
    option.None -> update_fields
  }
  let update_fields = case website_url {
    option.Some(url) -> ["\"website_url\":\"" <> url <> "\"", ..update_fields]
    option.None -> update_fields
  }
  let update_fields = case description {
    option.Some(desc) -> ["\"description\":\"" <> desc <> "\"", ..update_fields]
    option.None -> update_fields
  }
  let update_fields = case logo_url {
    option.Some(logo) -> ["\"logo_url\":\"" <> logo <> "\"", ..update_fields]
    option.None -> update_fields
  }
  let update_fields = case primary_cause_area_id {
    option.Some(cause_id) -> ["\"primary_cause_area_id\":" <> string.inspect(cause_id), ..update_fields]
    option.None -> update_fields
  }
  
  let update_data = case update_fields {
    [] -> "{}"
    fields -> "{" <> string.join(list.reverse(fields), ",") <> "}"
  }
  
  use req <- result.try(build_request(
    client,
    "PATCH",
    "/charities?id=eq." <> string.inspect(charity_id) <> "&created_by=eq." <> user_id,
    False,
  ))
  let req_with_body = request.set_body(req, update_data)
  
  use resp <- result.try(send_request(req_with_body))
  
  case parse_charities(resp.body) {
    [charity] -> Ok(charity)
    [] -> Error(NotFound)
    _ -> Error(ParseError("Multiple charities updated"))
  }
}

pub fn delete_charity(
  client: SupabaseClient,
  charity_id: Int,
  user_id: String,
) -> Result(Nil, DatabaseError) {
  use req <- result.try(build_request(
    client,
    "DELETE",
    "/charities?id=eq." <> string.inspect(charity_id) <> "&created_by=eq." <> user_id,
    False,
  ))
  
  use _resp <- result.try(send_request(req))
  Ok(Nil)
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

pub fn get_donation(
  client: SupabaseClient,
  donation_id: Int,
  user_id: String,
) -> Result(Donation, DatabaseError) {
  use req <- result.try(build_request(
    client,
    "GET",
    "/donations?id=eq." <> string.inspect(donation_id) <> "&user_id=eq." <> user_id <> "&select=*",
    False,
  ))
  
  use resp <- result.try(send_request(req))
  
  case parse_donations(resp.body) {
    [donation] -> Ok(donation)
    [] -> Error(NotFound)
    _ -> Error(ParseError("Multiple donations found"))
  }
}

pub fn create_donation(
  client: SupabaseClient,
  charity_id: Int,
  amount: String,
  currency: String,
  donation_date: String,
  notes: Option(String),
  user_id: String,
) -> Result(Donation, DatabaseError) {
  let donation_fields = [
    "\"user_id\":\"" <> user_id <> "\"",
    "\"charity_id\":" <> string.inspect(charity_id),
    "\"amount\":\"" <> amount <> "\"",
    "\"currency\":\"" <> currency <> "\"",
    "\"donation_date\":\"" <> donation_date <> "\""
  ]
  let donation_fields = case notes {
    option.Some(note_text) -> ["\"notes\":\"" <> note_text <> "\"", ..donation_fields]
    option.None -> donation_fields
  }
  
  let donation_data = "{" <> string.join(list.reverse(donation_fields), ",") <> "}"
  
  use req <- result.try(build_request(client, "POST", "/donations", False))
  let req_with_body = request.set_body(req, donation_data)
  
  use resp <- result.try(send_request(req_with_body))
  
  case parse_donations(resp.body) {
    [donation] -> Ok(donation)
    [] -> Error(ParseError("No donation returned after creation"))
    _ -> Error(ParseError("Multiple donations returned after creation"))
  }
}

pub fn update_donation(
  client: SupabaseClient,
  donation_id: Int,
  charity_id: Option(Int),
  amount: Option(String),
  currency: Option(String),
  donation_date: Option(String),
  notes: Option(String),
  user_id: String,
) -> Result(Donation, DatabaseError) {
  let update_fields = []
  let update_fields = case charity_id {
    option.Some(cid) -> ["\"charity_id\":" <> string.inspect(cid), ..update_fields]
    option.None -> update_fields
  }
  let update_fields = case amount {
    option.Some(amt) -> ["\"amount\":\"" <> amt <> "\"", ..update_fields]
    option.None -> update_fields
  }
  let update_fields = case currency {
    option.Some(curr) -> ["\"currency\":\"" <> curr <> "\"", ..update_fields]
    option.None -> update_fields
  }
  let update_fields = case donation_date {
    option.Some(date) -> ["\"donation_date\":\"" <> date <> "\"", ..update_fields]
    option.None -> update_fields
  }
  let update_fields = case notes {
    option.Some(note_text) -> ["\"notes\":\"" <> note_text <> "\"", ..update_fields]
    option.None -> update_fields
  }
  
  let update_data = case update_fields {
    [] -> "{}"
    fields -> "{" <> string.join(list.reverse(fields), ",") <> "}"
  }
  
  use req <- result.try(build_request(
    client,
    "PATCH",
    "/donations?id=eq." <> string.inspect(donation_id) <> "&user_id=eq." <> user_id,
    False,
  ))
  let req_with_body = request.set_body(req, update_data)
  
  use resp <- result.try(send_request(req_with_body))
  
  case parse_donations(resp.body) {
    [donation] -> Ok(donation)
    [] -> Error(NotFound)
    _ -> Error(ParseError("Multiple donations updated"))
  }
}

pub fn delete_donation(
  client: SupabaseClient,
  donation_id: Int,
  user_id: String,
) -> Result(Nil, DatabaseError) {
  use req <- result.try(build_request(
    client,
    "DELETE",
    "/donations?id=eq." <> string.inspect(donation_id) <> "&user_id=eq." <> user_id,
    False,
  ))
  
  use _resp <- result.try(send_request(req))
  Ok(Nil)
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