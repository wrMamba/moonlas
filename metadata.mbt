///|
/// VLR payloads are opaque. GeoTIFF/WKT records are retained without reprojection.
#derive(Debug, Eq)
pub(all) struct Vlr {
  user_id : String
  record_id : Int32
  description : String
  payload : Bytes
  reserved : Int32
  raw_text : Bytes
}

///|
pub fn Vlr::validate(self : Vlr) -> Unit raise LasError {
  require(
    self.record_id >= 0 && self.record_id <= 65535,
    "invalid VLR record ID",
  )
  require(self.payload.length() <= 65535, "VLR payload exceeds uint16 length")
  require(
    self.reserved >= 0 && self.reserved <= 65535,
    "invalid VLR reserved word",
  )
  require(
    self.raw_text.length() == 0 || self.raw_text.length() == 48,
    "invalid raw VLR text size",
  )
  let probe : Array[Byte] = []
  put_record_text(probe, self.user_id, self.description, self.raw_text)
}

///|
pub fn read_vlrs(
  data : Bytes,
  header : Header,
  limits~ : Limits = Limits::default(),
) -> (Array[Vlr], Bytes) raise LasError {
  limits.validate()
  if data.length() > limits.max_bytes {
    raise Limit("input byte budget exceeded")
  }
  if header.vlr_count < 0 || header.vlr_count > limits.max_vlrs {
    raise Limit("VLR budget exceeded")
  }
  require(
    header.minor >= 1 && header.minor <= 4,
    "unsupported metadata header version",
  )
  let start = base_header_size(header.minor) + header.extra.length()
  let r = Reader::new(data, start, header.point_offset)
  checked_size(header.vlr_count, 54, header.point_offset - start)
  let records : Array[Vlr] = []
  for _ in 0..<header.vlr_count {
    let reserved = r.u16()
    let raw_user = slice_bytes(data, r.pos, 16)
    let user_id = r.text(16)
    let record_id = r.u16()
    let length = r.u16()
    let raw_description = slice_bytes(data, r.pos, 32)
    let description = r.text(32)
    let payload = r.take(length)
    let raw_text = record_raw_text(
      raw_user, raw_description, user_id, description,
    )
    records.push({
      user_id,
      record_id,
      description,
      payload,
      reserved,
      raw_text,
    })
  }
  (records, r.take(r.end - r.pos))
}

///|
fn encode_vlrs(records : Array[Vlr]) -> Bytes raise LasError {
  let out : Array[Byte] = []
  for record in records {
    record.validate()
    put16(out, record.reserved)
    put_preserved_text(
      out,
      record.user_id,
      16,
      raw_part(record.raw_text, 0, 16),
    )
    put16(out, record.record_id)
    put16(out, record.payload.length())
    put_preserved_text(
      out,
      record.description,
      32,
      raw_part(record.raw_text, 16, 32),
    )
    append(out, record.payload)
  }
  bytes_of(out)
}

///|
pub fn vlrs_named(
  records : Array[Vlr],
  user_id : String,
  record_id : Int32,
) -> Array[Vlr] {
  records.filter(r => r.user_id == user_id && r.record_id == record_id)
}

///|
pub extend Vlr with @debug.Debug::{to_repr}

///|
pub extend Vlr with Eq::{equal, not_equal}

///|
fn metadata_end(
  records : Array[Vlr],
  gap : Bytes,
  minor : Int32,
  extra : Bytes,
  limits : Limits,
) -> Int32 raise LasError {
  let mut size = base_header_size(minor) + extra.length()
  require(size <= 65535, "public header exceeds uint16 length")
  for v in records {
    v.validate()
    let n = 54 + v.payload.length()
    if n > limits.max_bytes - size {
      raise Limit("metadata byte budget exceeded")
    }
    size += n
  }
  if gap.length() > limits.max_bytes - size {
    raise Limit("gap byte budget exceeded")
  }
  size + gap.length()
}

///|
pub fn Vlr::new(
  user_id : String,
  record_id : Int32,
  description : String,
  payload : Bytes,
) -> Vlr {
  { user_id, record_id, description, payload, reserved: 0, raw_text: b"", }
}

///|
fn raw_part(raw : Bytes, offset : Int32, width : Int32) -> Bytes raise LasError {
  if raw.is_empty() {
    b""
  } else {
    slice_bytes(raw, offset, width)
  }
}

///|
fn put_record_text(
  out : Array[Byte],
  user_id : String,
  description : String,
  raw : Bytes,
) -> Unit raise LasError {
  put_preserved_text(out, user_id, 16, raw_part(raw, 0, 16))
  put_preserved_text(out, description, 32, raw_part(raw, 16, 32))
}

///|
fn record_raw_text(
  user : Bytes,
  description : Bytes,
  user_text : String,
  description_text : String,
) -> Bytes raise LasError {
  let actual = user.to_array()
  append(actual, description)
  let canonical : Array[Byte] = []
  put_text(canonical, user_text, 16)
  put_text(canonical, description_text, 32)
  if bytes_of(actual) == bytes_of(canonical) {
    b""
  } else {
    bytes_of(actual)
  }
}
