///|
/// Encodes attributes without clipping or silently adding format-specific fields.
pub fn write_point(point : Point, format : Int32) -> Bytes raise LasError {
  point.validate(format)
  let width = record_size(format)
  if point.extra.length() > 65535 - width {
    raise Limit("point extension exceeds record width")
  }
  let out : Array[Byte] = []
  put32(out, point.x)
  put32(out, point.y)
  put32(out, point.z)
  put16(out, point.intensity)
  let scan = (if point.scan_direction { 64 } else { 0 }) |
    (if point.edge { 128 } else { 0 })
  if format >= 6 {
    put8(out, point.return_number | (point.returns << 4))
    put8(out, point.flags | (point.scanner_channel << 4) | scan)
    put8(out, point.classification)
    put8(out, point.user_data)
    put16(out, point.scan_angle)
  } else {
    put8(out, point.return_number | (point.returns << 3) | scan)
    put8(out, point.classification | (point.flags << 5))
    put8(out, point.scan_angle)
    put8(out, point.user_data)
  }
  put16(out, point.source_id)
  if point.gps_time is Some(gps) {
    putf64(out, gps)
  }
  if point.rgb is Some((red, green, blue)) {
    put16(out, red)
    put16(out, green)
    put16(out, blue)
  }
  if point.nir is Some(nir) {
    put16(out, nir)
  }
  append(out, point.extra)
  bytes_of(out)
}
