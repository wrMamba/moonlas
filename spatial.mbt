///|
/// Inclusive axis-aligned crop in scaled coordinates, not raw integer units.
pub fn Document::crop(
  self : Document,
  bounds : Bounds,
  limits~ : Limits = Limits::default(),
) -> Document raise LasError {
  self.validate(limits~)
  bounds.validate()
  let points : Array[Point] = []
  for p in self.points {
    if bounds.contains(self.header.transform.position(p)) {
      points.push(p)
    }
  }
  self.with_points(points, limits~)
}

///|
/// Inclusive spherical selection; normalized distances avoid squared overflow.
pub fn Document::within_radius(
  self : Document,
  center : Position,
  radius : Double,
  limits~ : Limits = Limits::default(),
) -> Document raise LasError {
  self.validate(limits~)
  center.validate()
  require(finite(radius) && radius >= 0.0, "invalid query radius")
  let points : Array[Point] = []
  for p in self.points {
    let q = self.header.transform.position(p)
    let hit = if radius == 0.0 {
      q == center
    } else {
      let x = (q.x - center.x) / radius
      let y = (q.y - center.y) / radius
      let z = (q.z - center.z) / radius
      x * x + y * y + z * z <= 1.0
    }
    if hit {
      points.push(p)
    }
  }
  self.with_points(points, limits~)
}
