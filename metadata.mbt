///|
/// VLR payloads are opaque. GeoTIFF/WKT records are retained without reprojection.
pub(all) struct Vlr {
  user_id : String
  record_id : Int32
  description : String
  payload : Bytes
} derive(Debug, Eq)

///|
pub fn Vlr::validate(self : Vlr) -> Unit raise LasError {
  require(
    self.record_id >= 0 && self.record_id <= 65535,
    "invalid VLR record ID",
  )
  require(self.payload.length() <= 65535, "VLR payload exceeds uint16 length")
  let probe : Array[Byte] = []
  put_text(probe, self.user_id, 16)
  put_text(probe, self.description, 32)
}

///|
pub fn read_vlrs(
  data : Bytes,
  header : Header,
  limits~ : Limits = Limits::default(),
) -> (Array[Vlr], Bytes) raise LasError {
  limits.validate()
  if header.vlr_count < 0 || header.vlr_count > limits.max_vlrs {
    raise Limit("VLR budget exceeded")
  }
  require(
    header.minor == 2 || header.minor == 4,
    "unsupported metadata header version",
  )
  let start = if header.minor == 2 { 227 } else { 375 }
  let r = Reader::new(data, start, header.point_offset)
  checked_size(header.vlr_count, 54, header.point_offset - start)
  let records : Array[Vlr] = []
  for _ in 0..<header.vlr_count {
    require(r.u16() == 0, "nonzero VLR reserved field")
    let user_id = r.text(16)
    let record_id = r.u16()
    let length = r.u16()
    let description = r.text(32)
    let payload = r.take(length)
    records.push({ user_id, record_id, description, payload, })
  }
  (records, r.take(r.end - r.pos))
}

///|
fn encode_vlrs(records : Array[Vlr]) -> Bytes raise LasError {
  let out : Array[Byte] = []
  for record in records {
    record.validate()
    put16(out, 0)
    put_text(out, record.user_id, 16)
    put16(out, record.record_id)
    put16(out, record.payload.length())
    put_text(out, record.description, 32)
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
