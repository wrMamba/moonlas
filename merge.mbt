///|
/// Stable concatenation into the left document's scale. Opaque metadata must match.
/// Header provenance is retained from the left; right header dates/software are not merged.
pub fn Document::merge(
  self : Document,
  other : Document,
  tolerance : Double,
  limits~ : Limits = Limits::default(),
) -> Document raise LasError {
  self.validate(limits~)
  other.validate(limits~)
  let a = self.header
  let b = other.header
  require(
    a.minor == b.minor && a.format == b.format,
    "merge version/format conflict",
  )
  require(a.record_length == b.record_length, "merge extra-byte width conflict")
  require(
    a.global_encoding == b.global_encoding,
    "merge GPS/WKT encoding conflict",
  )
  require(
    a.project_id == b.project_id && a.file_source_id == b.file_source_id,
    "merge project/file identity conflict",
  )
  require(
    self.vlrs == other.vlrs &&
    self.gap == other.gap &&
    self.header.extra == other.header.extra &&
    self.tail == other.tail &&
    relative_tail_offset(self.header.waveform_offset, self.header) ==
    relative_tail_offset(other.header.waveform_offset, other.header) &&
    relative_tail_offset(self.header.evlr_offset, self.header) ==
    relative_tail_offset(other.header.evlr_offset, other.header),
    "merge opaque metadata conflict",
  )
  if other.points.length() > limits.max_points - self.points.length() {
    raise Limit("merged point budget exceeded")
  }
  let normalized = other.requantize(a.transform, tolerance, limits~).document
  let points = self.points.copy()
  for p in normalized.points {
    points.push(p)
  }
  self.with_points(points, limits~)
}

///|
fn relative_tail_offset(offset : Int32, h : Header) -> Int32 {
  if offset == 0 {
    -1
  } else {
    offset - point_end(h)
  }
}
