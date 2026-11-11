///|
pub(all) struct Requantized {
  document : Document
  max_error : Position
} derive(Debug)

///|
/// Coordinate rescaling only. No CRS conversion; reject errors over caller tolerance.
pub fn Document::requantize(
  self : Document,
  target : Transform,
  tolerance : Double,
  limits~ : Limits = Limits::default(),
) -> Requantized raise LasError {
  self.validate(limits~)
  target.validate()
  require(
    finite(tolerance) && tolerance >= 0.0,
    "invalid quantization tolerance",
  )
  let points : Array[Point] = []
  let mut max_error : Position = { x: 0.0, y: 0.0, z: 0.0, }
  for p in self.points {
    let original = self.header.transform.position(p)
    let converted = target.quantize(original, p)
    let rounded = target.position(converted)
    let x = (rounded.x - original.x).abs()
    let y = (rounded.y - original.y).abs()
    let z = (rounded.z - original.z).abs()
    require(
      x <= tolerance && y <= tolerance && z <= tolerance,
      "requantization exceeds tolerance",
    )
    max_error = {
      x: if x > max_error.x {
        x
      } else {
        max_error.x
      },
      y: if y > max_error.y {
        y
      } else {
        max_error.y
      },
      z: if z > max_error.z {
        z
      } else {
        max_error.z
      },
    }
    points.push(converted)
  }
  let changed = { ..self, header: { ..self.header, transform: target, }, }
  { document: changed.with_points(points, limits~), max_error, }
}

///|
pub extend Requantized with @debug.Debug::{to_repr}
