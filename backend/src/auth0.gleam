import gleam/result
import gleam/string
import gleam/json
import gleam/dynamic/decode
import gleam/httpc
import gleam/http/request
import gleam/bit_array
import birl
import config.{type Auth0Config}

pub type User {
  User(
    id: String,
    email: String,
    name: String,
    picture: String,
  )
}

pub type ValidationError {
  InvalidToken
  ExpiredToken
  InvalidAudience
  InvalidIssuer
  InvalidSignature
  NetworkError(String)
  ParseError(String)
}

pub type JWTHeader {
  JWTHeader(
    alg: String,
    typ: String,
    kid: String,
  )
}

pub type JWTPayload {
  JWTPayload(
    iss: String,
    sub: String,
    aud: String,
    exp: Int,
    iat: Int,
    email: String,
    name: String,
    picture: String,
  )
}

pub type JWT {
  JWT(
    header: JWTHeader,
    payload: JWTPayload,
    signature: String,
    raw_token: String,
  )
}

pub type JWKSKey {
  JWKSKey(
    kid: String,
    n: String,
    e: String,
    kty: String,
    key_use: String,
    alg: String,
  )
}

pub fn validate_token(token: String, config: Auth0Config) -> Result(User, ValidationError) {
  use jwt <- result.try(parse_jwt(token))
  use _ <- result.try(validate_claims(jwt, config))
  use user <- result.try(extract_user_from_jwt(jwt))
  Ok(user)
}

fn parse_jwt(token: String) -> Result(JWT, ValidationError) {
  case string.split(token, ".") {
    [header_b64, payload_b64, signature_b64] -> {
      use header <- result.try(decode_header(header_b64))
      use payload <- result.try(decode_payload(payload_b64))
      Ok(JWT(
        header: header,
        payload: payload,
        signature: signature_b64,
        raw_token: token,
      ))
    }
    _ -> Error(InvalidToken)
  }
}

fn decode_header(header_b64: String) -> Result(JWTHeader, ValidationError) {
  use json_str <- result.try(
    decode_base64url(header_b64)
    |> result.map_error(fn(_) { ParseError("Invalid header base64") })
  )
  
  let header_decoder = {
    use alg <- decode.field("alg", decode.string)
    use typ <- decode.field("typ", decode.string)
    use kid <- decode.field("kid", decode.string)
    decode.success(JWTHeader(alg:, typ:, kid:))
  }
  
  case json.parse(json_str, header_decoder) {
    Ok(header) -> Ok(header)
    Error(_) -> Error(ParseError("Invalid header format"))
  }
}

fn decode_payload(payload_b64: String) -> Result(JWTPayload, ValidationError) {
  use json_str <- result.try(
    decode_base64url(payload_b64)
    |> result.map_error(fn(_) { ParseError("Invalid payload base64") })
  )
  
  let payload_decoder = {
    use iss <- decode.field("iss", decode.string)
    use sub <- decode.field("sub", decode.string)
    use aud <- decode.field("aud", decode.string)
    use exp <- decode.field("exp", decode.int)
    use iat <- decode.field("iat", decode.int)
    use email <- decode.field("email", decode.string)
    use name <- decode.field("name", decode.string)
    use picture <- decode.field("picture", decode.string)
    decode.success(JWTPayload(iss:, exp:, iat:, sub:, aud:, email:, name:, picture:))
  }
  
  case json.parse(json_str, payload_decoder) {
    Ok(payload) -> Ok(payload)
    Error(_) -> Error(ParseError("Invalid payload format"))
  }
}

@external(erlang, "base64", "decode")
fn base64_decode(input: String) -> Result(BitArray, Nil)

fn decode_base64url(input: String) -> Result(String, Nil) {
  let padded = case string.length(input) % 4 {
    0 -> input
    2 -> input <> "=="
    3 -> input <> "="
    _ -> input
  }
  
  let base64 = string.replace(padded, "-", "+")
    |> string.replace("_", "/")
  
  case base64_decode(base64) {
    Ok(bits) -> {
      case bit_array.to_string(bits) {
        Ok(str) -> Ok(str)
        Error(_) -> Error(Nil)
      }
    }
    Error(_) -> Error(Nil)
  }
}

fn validate_claims(jwt: JWT, config: Auth0Config) -> Result(Nil, ValidationError) {
  use _ <- result.try(validate_audience(jwt.payload, config.api_audience))
  use _ <- result.try(validate_issuer(jwt.payload, config.domain))
  use _ <- result.try(validate_expiration(jwt.payload))
  Ok(Nil)
}

fn validate_audience(payload: JWTPayload, expected_audience: String) -> Result(Nil, ValidationError) {
  case payload.aud == expected_audience {
    True -> Ok(Nil)
    False -> Error(InvalidAudience)
  }
}

fn validate_issuer(payload: JWTPayload, domain: String) -> Result(Nil, ValidationError) {
  let expected_issuer = "https://" <> domain <> "/"
  case payload.iss == expected_issuer {
    True -> Ok(Nil)
    False -> Error(InvalidIssuer)
  }
}

fn validate_expiration(payload: JWTPayload) -> Result(Nil, ValidationError) {
  let now = birl.now() |> birl.to_unix()
  case payload.exp > now {
    True -> Ok(Nil)
    False -> Error(ExpiredToken)
  }
}

fn extract_user_from_jwt(jwt: JWT) -> Result(User, ValidationError) {
  Ok(User(
    id: jwt.payload.sub,
    email: jwt.payload.email,
    name: jwt.payload.name,
    picture: jwt.payload.picture,
  ))
}

pub fn extract_bearer_token(authorization_header: String) -> Result(String, ValidationError) {
  case string.starts_with(authorization_header, "Bearer ") {
    True -> {
      let token = string.drop_start(authorization_header, 7)
      case string.trim(token) {
        "" -> Error(InvalidToken)
        valid_token -> Ok(valid_token)
      }
    }
    False -> Error(InvalidToken)
  }
}

pub fn get_jwks_url(config: Auth0Config) -> String {
  "https://" <> config.domain <> "/.well-known/jwks.json"
}

pub fn fetch_jwks(config: Auth0Config) -> Result(List(JWKSKey), ValidationError) {
  let url = get_jwks_url(config)
  
  use req <- result.try(
    request.to(url)
    |> result.map_error(fn(_) { NetworkError("Invalid JWKS URL") })
  )
  
  use resp <- result.try(
    httpc.send(req)
    |> result.map_error(fn(_) { NetworkError("Failed to fetch JWKS") })
  )
  
  case resp.status {
    200 -> parse_jwks_response(resp.body)
    _ -> Error(NetworkError("JWKS endpoint returned error"))
  }
}

fn parse_jwks_response(body: String) -> Result(List(JWKSKey), ValidationError) {
  let keys_decoder = {
    use keys <- decode.field("keys", decode.list(parse_jwks_key_decoder()))
    decode.success(keys)
  }
  
  case json.parse(body, keys_decoder) {
    Ok(keys) -> Ok(keys)
    Error(_) -> Error(ParseError("Invalid JWKS format"))
  }
}

fn parse_jwks_key_decoder() -> decode.Decoder(JWKSKey) {
  use kid <- decode.field("kid", decode.string)
  use n <- decode.field("n", decode.string)
  use e <- decode.field("e", decode.string)
  use kty <- decode.field("kty", decode.string)
  use key_use <- decode.field("use", decode.string)
  use alg <- decode.field("alg", decode.string)
  decode.success(JWKSKey(kid:, n:, e:, kty:, key_use:, alg:))
}