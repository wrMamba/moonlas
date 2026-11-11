///|
/// Computed from records, never copied from the public header.
pub(all) struct Audit {
  count : Int32
  classifications : Array[Int32]
  returns : Array[Int32]
  flags : Array[Int32]
  bounds : Bounds?
  intensity_min : Int32
  intensity_max : Int32
  intensity_mean : Double
  issues : Array[String]
} derive(Debug)

///|
/// Structural invalidity raises; stale derived header fields become issues.
pub fn Document::audit(
  self : Document,
  limits~ : Limits = Limits::default(),
) -> Audit raise LasError {
  self.validate(limits~)
  let classifications = Array::make(256, 0)
  let returns = Array::make(if self.header.minor == 2 { 5 } else { 15 }, 0)
  let flags = Array::make(4, 0)
  let mut low = 65535
  let mut high = 0
  let mut mean = 0.0
  for i in 0..<self.points.length() {
    let p = self.points[i]
    classifications[p.classification] += 1
    returns[p.return_number - 1] += 1
    for bit in 0..<4 {
      if (p.flags & (1 << bit)) != 0 {
        flags[bit] += 1
      }
    }
    if p.intensity < low {
      low = p.intensity
    }
    if p.intensity > high {
      high = p.intensity
    }
    mean += (p.intensity.to_double() - mean) / (i + 1).to_double()
  }
  let bounds = point_bounds(self.points, self.header.transform)
  let issues : Array[String] = []
  if returns != self.header.by_return {
    issues.push("header return histogram differs from records")
  }
  let actual = match bounds {
    None => (0.0, 0.0, 0.0, 0.0, 0.0, 0.0)
    Some(b) => (b.min.x, b.min.y, b.min.z, b.max.x, b.max.y, b.max.z)
  }
  if actual != self.header.bounds {
    issues.push("header bounds differ from scaled records")
  }
  {
    count: self.points.length(),
    classifications,
    returns,
    flags,
    bounds,
    intensity_min: if self.points.is_empty() {
      0
    } else {
      low
    },
    intensity_max: high,
    intensity_mean: mean,
    issues,
  }
}

///|
pub extend Audit with @debug.Debug::{to_repr}
