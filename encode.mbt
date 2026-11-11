///|
/// Canonical encoding recomputes derived counts, bounds, width and point offset.
/// Unknown VLR payloads, gap bytes and per-point extra bytes remain opaque.
pub fn encode(
  doc : Document,
  limits~ : Limits = Limits::default(),
) -> Bytes raise LasError {
  doc.validate(limits~)
  let canonical = doc.with_points(doc.points, limits~)
  let h = canonical.header
  let out : Array[Byte] = []
  append(out, b"LASF")
  put16(out, h.file_source_id)
  put16(out, h.global_encoding)
  append(out, h.project_id)
  put8(out, 1)
  put8(out, h.minor)
  put_text(out, h.system, 32)
  put_text(out, h.software, 32)
  put16(out, h.day)
  put16(out, h.year)
  put16(out, if h.minor == 2 { 227 } else { 375 })
  put32(out, h.point_offset)
  put32(out, h.vlr_count)
  put8(out, h.format)
  put16(out, h.record_length)
  put32(out, if h.minor == 2 { h.point_count } else { 0 })
  for i in 0..<5 {
    put32(out, if h.minor == 2 { h.by_return[i] } else { 0 })
  }
  let t = h.transform
  for value in [t.sx, t.sy, t.sz, t.ox, t.oy, t.oz] {
    putf64(out, value)
  }
  let (xmin, ymin, zmin, xmax, ymax, zmax) = h.bounds
  for value in [xmax, xmin, ymax, ymin, zmax, zmin] {
    putf64(out, value)
  }
  if h.minor == 4 {
    put64(out, 0)
    put64(out, 0)
    put32(out, 0)
    put64(out, h.point_count)
    for count in h.by_return {
      put64(out, count)
    }
  }
  append(out, encode_vlrs(canonical.vlrs))
  append(out, canonical.gap)
  for p in canonical.points {
    append(out, write_point(p, h.format))
  }
  bytes_of(out)
}

///|
fn validate_header_fields(h : Header) -> Unit raise LasError {
  require(
    h.file_source_id >= 0 && h.file_source_id <= 65535,
    "invalid file source ID",
  )
  require(
    h.day >= 0 && h.day <= 366 && h.year >= 0 && h.year <= 65535,
    "invalid creation date",
  )
  let allowed = if h.minor == 2 { 1 } else { 25 }
  require(
    h.global_encoding >= 0 && (h.global_encoding & allowed) == h.global_encoding,
    "unsupported global encoding bits",
  )
  require(
    h.by_return.length() == (if h.minor == 2 { 5 } else { 15 }),
    "invalid return histogram length",
  )
  for n in h.by_return {
    require(n >= 0, "negative return histogram")
  }
  let probe : Array[Byte] = []
  put_text(probe, h.system, 32)
  put_text(probe, h.software, 32)
  let (x, y, z, xx, yy, zz) = h.bounds
  for v in [x, y, z, xx, yy, zz] {
    require(finite(v), "nonfinite header bounds")
  }
  require(x <= xx && y <= yy && z <= zz, "reversed header bounds")
}
