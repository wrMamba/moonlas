///|
/// In-memory LAS document. Public operations validate mutable array contents before use.
pub(all) struct Document {
  header : Header
  vlrs : Array[Vlr]
  gap : Bytes
  points : Array[Point]
} derive(Debug)

///|
pub fn decode(
  data : Bytes,
  limits~ : Limits = Limits::default(),
) -> Document raise LasError {
  let header = read_header(data, limits~)
  let (vlrs, gap) = read_vlrs(data, header, limits~)
  let expected = header.point_count * header.record_length
  require(
    data.length() - header.point_offset == expected,
    "trailing bytes after point records are unsupported",
  )
  let reader = Reader::new(data, header.point_offset, data.length())
  let points : Array[Point] = []
  for _ in 0..<header.point_count {
    points.push(read_point(reader.take(header.record_length), header.format))
  }
  { header, vlrs, gap, points, }
}

///|
pub fn Document::validate(
  self : Document,
  limits~ : Limits = Limits::default(),
) -> Unit raise LasError {
  limits.validate()
  let h = self.header
  validate_header_fields(h)
  h.transform.validate()
  ignore(record_size(h.format))
  require(h.minor == 2 || h.minor == 4, "invalid document version")
  require(h.minor == 4 || h.format <= 3, "format requires LAS 1.4")
  if self.points.length() > limits.max_points ||
    self.vlrs.length() > limits.max_vlrs {
    raise Limit("document count budget exceeded")
  }
  require(h.project_id.length() == 16, "project UUID must be 16 bytes")
  require(
    h.point_count == self.points.length(),
    "point count disagrees with array",
  )
  require(h.vlr_count == self.vlrs.length(), "VLR count disagrees with array")
  let width = record_size(h.format)
  require(
    h.record_length >= width && h.record_length <= 65535,
    "invalid record length",
  )
  for p in self.points {
    p.validate(h.format)
    require(
      p.extra.length() == h.record_length - width,
      "inconsistent extra-byte widths",
    )
    ignore(h.transform.position(p))
  }
  let mut metadata_size = if h.minor == 2 { 227 } else { 375 }
  for v in self.vlrs {
    v.validate()
    let n = 54 + v.payload.length()
    if n > limits.max_bytes - metadata_size {
      raise Limit("metadata byte budget exceeded")
    }
    metadata_size += n
  }
  if self.gap.length() > limits.max_bytes - metadata_size {
    raise Limit("gap byte budget exceeded")
  }
  metadata_size += self.gap.length()
  require(
    h.point_offset == metadata_size,
    "point offset disagrees with metadata",
  )
  if self.points.length() > (limits.max_bytes - metadata_size) / h.record_length {
    raise Limit("record byte budget exceeded")
  }
}

///|
/// Recompute counts, bounds, offset and width while retaining metadata and format.
pub fn Document::with_points(
  self : Document,
  points : Array[Point],
  limits~ : Limits = Limits::default(),
) -> Document raise LasError {
  limits.validate()
  if points.length() > limits.max_points {
    raise Limit("point budget exceeded")
  }
  let h = self.header
  require(h.minor == 2 || h.minor == 4, "invalid document version")
  if self.vlrs.length() > limits.max_vlrs {
    raise Limit("VLR budget exceeded")
  }
  let by_return = Array::make(if h.minor == 4 { 15 } else { 5 }, 0)
  for p in points {
    p.validate(h.format)
    by_return[p.return_number - 1] += 1
  }
  let bounds = match point_bounds(points, h.transform) {
    None => (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    Some(b) => (b.min.x, b.min.y, b.min.z, b.max.x, b.max.y, b.max.z)
  }
  let width = record_size(h.format) +
    (if points.is_empty() {
      h.record_length - record_size(h.format)
    } else {
      points[0].extra.length()
    })
  let offset = metadata_end(self.vlrs, self.gap, h.minor, limits)
  let header = {
    ..h,
    point_offset: offset,
    point_count: points.length(),
    vlr_count: self.vlrs.length(),
    by_return,
    bounds,
    record_length: width,
  }
  let doc = {
    header,
    vlrs: self.vlrs.copy(),
    gap: self.gap,
    points: points.copy(),
  }
  doc.validate(limits~)
  doc
}

///|
pub fn create(
  points : Array[Point],
  format : Int32,
  transform : Transform,
  minor~ : Int32 = 4,
  vlrs~ : Array[Vlr] = [],
  limits~ : Limits = Limits::default(),
) -> Document raise LasError {
  let header = {
    minor,
    file_source_id: 0,
    global_encoding: 0,
    project_id: Bytes::make(16, 0),
    system: "MoonLAS",
    software: "MoonLAS 0.1.0",
    day: 0,
    year: 0,
    point_offset: if minor == 2 {
      227
    } else {
      375
    },
    vlr_count: 0,
    format,
    record_length: record_size(format),
    point_count: 0,
    by_return: [],
    transform,
    bounds: (0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
  }
  let doc = { header, vlrs, gap: b"", points: [], }
  doc.with_points(points, limits~)
}

///|
pub extend Document with @debug.Debug::{to_repr}
