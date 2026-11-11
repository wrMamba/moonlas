///|
/// A seekable cursor over a bounded, complete Bytes buffer; not OS/file streaming.
/// Records are decoded on demand and a failed next() leaves the position unchanged.
pub struct PointCursor {
  data : Bytes
  header : Header
  mut index : Int32
}

///|
pub fn open_records(
  data : Bytes,
  limits~ : Limits = Limits::default(),
) -> PointCursor raise LasError {
  let header = read_header(data, limits~)
  ignore(read_vlrs(data, header, limits~))
  require(
    data.length() - header.point_offset ==
    header.point_count * header.record_length,
    "trailing bytes after point records",
  )
  { data, header, index: 0, }
}

///|
pub fn PointCursor::header(self : PointCursor) -> Header {
  self.header
}

///|
pub fn PointCursor::remaining(self : PointCursor) -> Int32 {
  self.header.point_count - self.index
}

///|
pub fn PointCursor::position(self : PointCursor) -> Int32 {
  self.index
}

///|
pub fn PointCursor::seek(
  self : PointCursor,
  index : Int32,
) -> Unit raise LasError {
  require(
    index >= 0 && index <= self.header.point_count,
    "cursor index outside records",
  )
  self.index = index
}

///|
pub fn PointCursor::next(self : PointCursor) -> Point? raise LasError {
  if self.remaining() == 0 {
    return None
  }
  let start = self.header.point_offset + self.index * self.header.record_length
  let r = Reader::new(self.data, start, start + self.header.record_length)
  let p = read_point(r.take(self.header.record_length), self.header.format)
  self.index += 1
  Some(p)
}

///|
/// At most n records, bounded by remaining input. Negative n is rejected.
pub fn PointCursor::batch(
  self : PointCursor,
  n : Int32,
) -> Array[Point] raise LasError {
  require(n >= 0, "negative batch size")
  let size = if n < self.remaining() { n } else { self.remaining() }
  let points : Array[Point] = []
  for _ in 0..<size {
    match self.next() {
      Some(p) => points.push(p)
      None => ()
    }
  }
  points
}
