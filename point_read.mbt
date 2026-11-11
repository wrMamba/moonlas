///|
/// Decode exactly one point record; the caller supplies the declared record length.
pub fn read_point(data : Bytes, format : Int32) -> Point raise LasError {
  let width = record_size(format)
  require(
    data.length() >= width && data.length() <= 65535,
    "invalid point record width",
  )
  let r = Reader::new(data, 0, data.length())
  let x = r.i32()
  let y = r.i32()
  let z = r.i32()
  let intensity = r.u16()
  let returns_byte = r.u8()
  let modern = format >= 6
  let return_number = returns_byte & (if modern { 15 } else { 7 })
  let returns = (returns_byte >> (if modern { 4 } else { 3 })) &
    (if modern { 15 } else { 7 })
  let class_byte = r.u8()
  let flags = if modern { class_byte & 15 } else { class_byte >> 5 }
  let classification = if modern { r.u8() } else { class_byte & 31 }
  let scanner_channel = if modern { (class_byte >> 4) & 3 } else { 0 }
  let scan_direction = ((if modern { class_byte } else { returns_byte }) & 64) !=
    0
  let edge = ((if modern { class_byte } else { returns_byte }) & 128) != 0
  let mut scan_angle = 0
  let mut user_data = 0
  if modern {
    user_data = r.u8()
    scan_angle = r.i16()
  } else {
    let raw = r.u8()
    scan_angle = if raw >= 128 { raw - 256 } else { raw }
    user_data = r.u8()
  }
  let source_id = r.u16()
  let gps_time = if format == 1 || format == 3 || modern {
    Some(r.f64())
  } else {
    None
  }
  let rgb = if format == 2 || format == 3 || format == 7 || format == 8 {
    Some((r.u16(), r.u16(), r.u16()))
  } else {
    None
  }
  let nir = if format == 8 { Some(r.u16()) } else { None }
  let extra = r.take(r.end - r.pos)
  let point = {
    x,
    y,
    z,
    intensity,
    return_number,
    returns,
    classification,
    flags,
    scanner_channel,
    scan_direction,
    edge,
    scan_angle,
    user_data,
    source_id,
    gps_time,
    rgb,
    nir,
    extra,
  }
  point.validate(format)
  point
}
