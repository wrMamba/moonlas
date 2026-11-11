///|
/// Recoverable input errors carry a byte offset where available.
pub suberror LasError {
  Truncated(Int32)
  Limit(String)
  Invalid(String)
  Unsupported(String)
} derive(Debug)

///|
fn require(ok : Bool, message : String) -> Unit raise LasError {
  if !ok {
    raise Invalid(message)
  }
}

///|
fn finite(x : Double) -> Bool {
  !x.is_nan() && !x.is_inf()
}

///|
/// Budgets apply before allocating record arrays or metadata payloads.
pub(all) struct Limits {
  max_bytes : Int32
  max_points : Int32
  max_vlrs : Int32
  max_cells : Int32
} derive(Debug, Eq)

///|
pub fn Limits::default() -> Limits {
  {
    max_bytes: 67108864,
    max_points: 1000000,
    max_vlrs: 4096,
    max_cells: 1000000,
  }
}

///|
pub fn Limits::validate(self : Limits) -> Unit raise LasError {
  require(
    self.max_bytes >= 375 && self.max_bytes <= 1073741824,
    "byte budget outside safe range",
  )
  require(
    self.max_points >= 0 && self.max_points <= 10000000,
    "invalid point budget",
  )
  require(self.max_vlrs >= 0 && self.max_vlrs <= 65535, "invalid VLR budget")
  require(
    self.max_cells > 0 && self.max_cells <= 10000000,
    "invalid cell budget",
  )
}

///|
/// XYZ scale factors and offsets. They never imply a coordinate reference system.
pub(all) struct Transform {
  sx : Double
  sy : Double
  sz : Double
  ox : Double
  oy : Double
  oz : Double
} derive(Debug, Eq)

///|
pub fn Transform::new(scale : Double) -> Transform raise LasError {
  let t = { sx: scale, sy: scale, sz: scale, ox: 0.0, oy: 0.0, oz: 0.0, }
  t.validate()
  t
}

///|
pub fn Transform::validate(self : Transform) -> Unit raise LasError {
  for s in [self.sx, self.sy, self.sz] {
    require(finite(s) && s > 0.0, "scale must be finite and positive")
  }
  for o in [self.ox, self.oy, self.oz] {
    require(finite(o), "offset must be finite")
  }
}

///|
/// Raw integer attributes retain the exact LAS record semantics.
pub(all) struct Point {
  x : Int32
  y : Int32
  z : Int32
  intensity : Int32
  return_number : Int32
  returns : Int32
  classification : Int32
  flags : Int32
  scanner_channel : Int32
  scan_direction : Bool
  edge : Bool
  scan_angle : Int32
  user_data : Int32
  source_id : Int32
  gps_time : Double?
  rgb : (Int32, Int32, Int32)?
  nir : Int32?
  extra : Bytes
} derive(Debug, Eq)

///|
pub fn Point::new(x : Int32, y : Int32, z : Int32) -> Point {
  {
    x,
    y,
    z,
    intensity: 0,
    return_number: 1,
    returns: 1,
    classification: 0,
    flags: 0,
    scanner_channel: 0,
    scan_direction: false,
    edge: false,
    scan_angle: 0,
    user_data: 0,
    source_id: 0,
    gps_time: None,
    rgb: None,
    nir: None,
    extra: b"",
  }
}

///|
pub fn record_size(format : Int32) -> Int32 raise LasError {
  match format {
    0 => 20
    1 => 28
    2 => 26
    3 => 34
    6 => 30
    7 => 36
    8 => 38
    _ => raise Unsupported("point format: \{format}")
  }
}

///|
pub fn Point::validate(self : Point, format : Int32) -> Unit raise LasError {
  ignore(record_size(format))
  let old = format <= 3
  let cap = if old { 5 } else { 15 }
  require(
    self.return_number >= 1 &&
    self.return_number <= self.returns &&
    self.returns <= cap,
    "invalid return numbering",
  )
  require(self.intensity >= 0 && self.intensity <= 65535, "invalid intensity")
  require(
    self.classification >= 0 &&
    self.classification <= (if old { 31 } else { 255 }),
    "invalid classification",
  )
  require(
    self.flags >= 0 && self.flags <= (if old { 7 } else { 15 }),
    "invalid flags",
  )
  require(
    self.scanner_channel >= 0 &&
    self.scanner_channel <= (if old { 0 } else { 3 }),
    "invalid scanner channel",
  )
  require(
    self.scan_angle >= (if old { -90 } else { -30000 }) &&
    self.scan_angle <= (if old { 90 } else { 30000 }),
    "invalid scan angle",
  )
  require(self.user_data >= 0 && self.user_data <= 255, "invalid user data")
  require(
    self.source_id >= 0 && self.source_id <= 65535,
    "invalid point source ID",
  )
  let gps = format == 1 || format == 3 || format >= 6
  require((self.gps_time is Some(_)) == gps, "GPS field disagrees with format")
  if self.gps_time is Some(t) {
    require(finite(t), "nonfinite GPS time")
  }
  let color = format == 2 || format == 3 || format == 7 || format == 8
  require((self.rgb is Some(_)) == color, "RGB field disagrees with format")
  if self.rgb is Some((r, g, b)) {
    for c in [r, g, b] {
      require(c >= 0 && c <= 65535, "invalid RGB component")
    }
  }
  require(
    (self.nir is Some(_)) == (format == 8),
    "NIR field disagrees with format",
  )
  if self.nir is Some(n) {
    require(n >= 0 && n <= 65535, "invalid NIR value")
  }
}

///|
pub extend LasError with @debug.Debug::{to_repr}

///|
pub extend Point with @debug.Debug::{to_repr}

///|
pub extend Point with Eq::{equal, not_equal}

///|
pub extend Transform with @debug.Debug::{to_repr}

///|
pub extend Transform with Eq::{equal, not_equal}

///|
pub extend Limits with @debug.Debug::{to_repr}

///|
pub extend Limits with Eq::{equal, not_equal}
