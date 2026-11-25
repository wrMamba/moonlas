///|
/// Header fields are retained; counts and extents can be audited against records.
#derive(Debug)
pub(all) struct Header {
  minor : Int32
  file_source_id : Int32
  global_encoding : Int32
  project_id : Bytes
  system : String
  software : String
  day : Int32
  year : Int32
  point_offset : Int32
  vlr_count : Int32
  format : Int32
  record_length : Int32
  point_count : Int32
  by_return : Array[Int32]
  transform : Transform
  bounds : (Double, Double, Double, Double, Double, Double)
  extra : Bytes
  raw_text : Bytes
  waveform_offset : Int32
  evlr_offset : Int32
  evlr_count : Int32
  legacy_counts : Bool
}

///|
pub fn read_header(
  data : Bytes,
  limits~ : Limits = Limits::default(),
) -> Header raise LasError {
  limits.validate()
  if data.length() > limits.max_bytes {
    raise Limit("input byte budget exceeded")
  }
  let r = Reader::new(data, 0, data.length())
  require(r.take(4) == b"LASF", "missing LASF signature")
  let file_source_id = r.u16()
  let global_encoding = r.u16()
  let project_id = r.take(16)
  let major = r.u8()
  let minor = r.u8()
  if major != 1 || minor < 1 || minor > 4 {
    raise Unsupported("supported versions are LAS 1.1 through 1.4")
  }
  let raw_text = slice_bytes(data, r.pos, 64)
  let system = r.text(32)
  let software = r.text(32)
  let day = r.u16()
  let year = r.u16()
  require(day <= 366, "invalid creation day")
  let header_size = r.u16()
  require(
    header_size >= base_header_size(minor),
    "public header shorter than the version minimum",
  )
  let point_offset = r.u32(limits.max_bytes)
  let vlr_count = r.u32(limits.max_vlrs)
  let format = r.u8()
  if format >= 64 {
    raise Unsupported("compressed or reserved point format bits")
  }
  let width = record_size(format)
  validate_version_format(minor, format)
  let record_length = r.u16()
  require(record_length >= width, "point record is shorter than the format")
  let legacy_count = r.u32(limits.max_points)
  let legacy_returns = Array::makei(5, _ => r.u32(limits.max_points))
  let sx = r.f64()
  let sy = r.f64()
  let sz = r.f64()
  let ox = r.f64()
  let oy = r.f64()
  let oz = r.f64()
  let transform = { sx, sy, sz, ox, oy, oz, }
  transform.validate()
  let xmax = r.f64()
  let xmin = r.f64()
  let ymax = r.f64()
  let ymin = r.f64()
  let zmax = r.f64()
  let zmin = r.f64()
  require(
    xmax >= xmin && ymax >= ymin && zmax >= zmin,
    "reversed header bounds",
  )
  let mut point_count = legacy_count
  let mut by_return = legacy_returns
  let waveform_offset = if minor >= 3 { r.u64(limits.max_bytes) } else { 0 }
  let mut evlr_offset = 0
  let mut evlr_count = 0
  if minor == 4 {
    evlr_offset = r.u64(limits.max_bytes)
    evlr_count = r.u32(limits.max_vlrs)
    point_count = r.u64(limits.max_points)
    by_return = Array::makei(15, _ => r.u64(limits.max_points))
    if format >= 6 {
      require(
        legacy_count == 0 && legacy_returns.all(x => x == 0),
        "LAS 1.4 formats require zero legacy counts",
      )
    } else if legacy_count != 0 || !legacy_returns.all(x => x == 0) {
      require(
        legacy_count == point_count,
        "legacy and extended point counts disagree",
      )
      for i in 0..<5 {
        require(
          legacy_returns[i] == by_return[i],
          "legacy return counts disagree",
        )
      }
    }
  }
  let extra = r.take(header_size - base_header_size(minor))
  let allowed = encoding_mask(minor)
  require(
    (global_encoding & allowed) == global_encoding,
    "unsupported global encoding bits",
  )
  require(
    point_offset >= header_size && point_offset <= data.length(),
    "point offset outside input",
  )
  checked_size(point_count, record_length, data.length() - point_offset)
  {
    minor,
    file_source_id,
    global_encoding,
    project_id,
    system,
    software,
    day,
    year,
    point_offset,
    vlr_count,
    format,
    record_length,
    point_count,
    by_return,
    transform,
    bounds: (xmin, ymin, zmin, xmax, ymax, zmax),
    extra,
    raw_text,
    waveform_offset,
    evlr_offset,
    evlr_count,
    legacy_counts: minor < 4 ||
    legacy_count != 0 ||
    !legacy_returns.all(x => x == 0),
  }
}

///|
pub extend Header with @debug.Debug::{to_repr}

///|
fn base_header_size(minor : Int32) -> Int32 {
  if minor == 4 {
    375
  } else if minor == 3 {
    235
  } else {
    227
  }
}

///|
fn encoding_mask(minor : Int32) -> Int32 {
  if minor == 4 {
    31
  } else if minor == 3 {
    15
  } else if minor == 2 {
    1
  } else {
    0
  }
}

///|
fn validate_version_format(
  minor : Int32,
  format : Int32,
) -> Unit raise LasError {
  require(
    minor >= 1 && minor <= 4,
    "supported versions are LAS 1.1 through 1.4",
  )
  let max_format = if minor == 1 {
    1
  } else if minor == 2 {
    3
  } else if minor == 3 {
    5
  } else {
    10
  }
  require(
    format >= 0 && format <= max_format,
    "point format is not defined in this LAS version",
  )
}
