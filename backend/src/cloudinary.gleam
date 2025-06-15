import config
import gleam/bit_array
import gleam/http.{Post}
import gleam/http/request
import gleam/httpc
import gleam/json
import gleam/dynamic/decode
import gleam/string

pub type CloudinaryUploadResult {
  CloudinaryUploadResult(
    public_id: String,
    version: Int,
    signature: String,
    width: Int,
    height: Int,
    format: String,
    resource_type: String,
    created_at: String,
    tags: List(String),
    bytes: Int,
    type_: String,
    etag: String,
    placeholder: Bool,
    url: String,
    secure_url: String,
  )
}

pub type CloudinaryError {
  NetworkError(String)
  AuthenticationError(String)
  ValidationError(String)
  UnknownError(String)
}

pub fn upload_image(
  config: config.CloudinaryConfig,
  file_data: BitArray,
  upload_preset: String,
  public_id: String,
) -> Result(CloudinaryUploadResult, CloudinaryError) {
  let upload_url = "https://api.cloudinary.com/v1_1/" <> config.cloud_name <> "/image/upload"
  
  let boundary = "----WebKitFormBoundary7MA4YWxkTrZu0gW"
  let content_type = "multipart/form-data; boundary=" <> boundary
  
  let form_data = build_multipart_form_data(boundary, file_data, upload_preset, public_id)
  
  case request.to(upload_url) {
    Ok(req) -> {
      let req_with_method = request.set_method(req, Post)
      let req_with_headers = request.set_header(req_with_method, "Content-Type", content_type)
      let req_with_body = request.set_body(req_with_headers, form_data)
      
      case httpc.send(req_with_body) {
        Ok(resp) -> {
          case resp.status {
            200 -> parse_upload_response(resp.body)
            400 -> Error(ValidationError("Bad request: " <> resp.body))
            401 -> Error(AuthenticationError("Authentication failed: " <> resp.body))
            _ -> Error(UnknownError("HTTP " <> string.inspect(resp.status) <> ": " <> resp.body))
          }
        }
        Error(_) -> Error(NetworkError("Failed to connect to Cloudinary"))
      }
    }
    Error(_) -> Error(NetworkError("Invalid upload URL"))
  }
}

fn build_multipart_form_data(
  boundary: String,
  file_data: BitArray,
  upload_preset: String,
  public_id: String,
) -> String {
  let crlf = "\r\n"
  let boundary_line = "--" <> boundary
  let end_boundary = "--" <> boundary <> "--"
  
  let upload_preset_part = 
    boundary_line <> crlf <>
    "Content-Disposition: form-data; name=\"upload_preset\"" <> crlf <>
    crlf <>
    upload_preset <> crlf
  
  let public_id_part = 
    boundary_line <> crlf <>
    "Content-Disposition: form-data; name=\"public_id\"" <> crlf <>
    crlf <>
    public_id <> crlf
  
  let file_part_header = 
    boundary_line <> crlf <>
    "Content-Disposition: form-data; name=\"file\"; filename=\"image.jpg\"" <> crlf <>
    "Content-Type: image/jpeg" <> crlf <>
    crlf
  
  let file_data_string = case bit_array.to_string(file_data) {
    Ok(str) -> str
    Error(_) -> ""
  }
  
  let file_part = file_part_header <> file_data_string <> crlf
  
  upload_preset_part <> public_id_part <> file_part <> end_boundary
}

fn parse_upload_response(body: String) -> Result(CloudinaryUploadResult, CloudinaryError) {
  let decoder = {
    use public_id <- decode.field("public_id", decode.string)
    use version <- decode.field("version", decode.int)
    use signature <- decode.field("signature", decode.string)
    use width <- decode.field("width", decode.int)
    use height <- decode.field("height", decode.int)
    use format <- decode.field("format", decode.string)
    use resource_type <- decode.field("resource_type", decode.string)
    use created_at <- decode.field("created_at", decode.string)
    use tags <- decode.field("tags", decode.list(decode.string))
    use bytes <- decode.field("bytes", decode.int)
    use type_ <- decode.field("type", decode.string)
    use etag <- decode.field("etag", decode.string)
    use placeholder <- decode.field("placeholder", decode.bool)
    use url <- decode.field("url", decode.string)
    use secure_url <- decode.field("secure_url", decode.string)
    decode.success(CloudinaryUploadResult(
      public_id: public_id,
      version: version,
      signature: signature,
      width: width,
      height: height,
      format: format,
      resource_type: resource_type,
      created_at: created_at,
      tags: tags,
      bytes: bytes,
      type_: type_,
      etag: etag,
      placeholder: placeholder,
      url: url,
      secure_url: secure_url,
    ))
  }
  
  case json.parse(from: body, using: decoder) {
    Ok(result) -> Ok(result)
    Error(_) -> Error(ValidationError("Failed to parse upload response: " <> body))
  }
}