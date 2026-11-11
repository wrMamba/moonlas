///|
pub(all) struct Position {
  x : Double
  y : Double
  z : Double
} derive(Debug, Eq)

///|
pub fn Position::validate(self : Position) -> Unit raise LasError {
  require(
    finite(self.x) && finite(self.y) && finite(self.z),
    "nonfinite position",
  )
}

///|
pub fn Transform::position(
  self : Transform,
  point : Point,
) -> Position raise LasError {
  self.validate()
  let p = {
    x: point.x.to_double() * self.sx + self.ox,
    y: point.y.to_double() * self.sy + self.oy,
    z: point.z.to_double() * self.sz + self.oz,
  }
  p.validate()
  p
}

///|
fn quantize_axis(
  value : Double,
  scale : Double,
  offset : Double,
) -> Int32 raise LasError {
  let raw = (value - offset) / scale
  require(finite(raw), "coordinate quantization overflow")
  let rounded = if raw >= 0.0 {
    (raw + 0.5).floor()
  } else {
    (raw - 0.5).ceil()
  }
  require(
    rounded >= -2147483648.0 && rounded <= 2147483647.0,
    "coordinate outside signed int32 range",
  )
  rounded.to_int()
}

///|
/// Nearest integer; exact half-way cases round away from zero.
pub fn Transform::quantize(
  self : Transform,
  position : Position,
  attributes : Point,
) -> Point raise LasError {
  self.validate()
  position.validate()
  {
    ..attributes,
    x: quantize_axis(position.x, self.sx, self.ox),
    y: quantize_axis(position.y, self.sy, self.oy),
    z: quantize_axis(position.z, self.sz, self.oz),
  }
}

///|
pub(all) struct Bounds {
  min : Position
  max : Position
} derive(Debug, Eq)

///|
pub fn Bounds::validate(self : Bounds) -> Unit raise LasError {
  self.min.validate()
  self.max.validate()
  require(
    self.min.x <= self.max.x &&
    self.min.y <= self.max.y &&
    self.min.z <= self.max.z,
    "reversed query bounds",
  )
}

///|
pub fn Bounds::contains(self : Bounds, p : Position) -> Bool {
  p.x >= self.min.x &&
  p.x <= self.max.x &&
  p.y >= self.min.y &&
  p.y <= self.max.y &&
  p.z >= self.min.z &&
  p.z <= self.max.z
}

///|
pub fn point_bounds(
  points : Array[Point],
  transform : Transform,
) -> Bounds? raise LasError {
  transform.validate()
  if points.is_empty() {
    return None
  }
  let first = transform.position(points[0])
  let mut low = first
  let mut high = first
  for p in points {
    let q = transform.position(p)
    low = {
      x: if q.x < low.x {
        q.x
      } else {
        low.x
      },
      y: if q.y < low.y {
        q.y
      } else {
        low.y
      },
      z: if q.z < low.z {
        q.z
      } else {
        low.z
      },
    }
    high = {
      x: if q.x > high.x {
        q.x
      } else {
        high.x
      },
      y: if q.y > high.y {
        q.y
      } else {
        high.y
      },
      z: if q.z > high.z {
        q.z
      } else {
        high.z
      },
    }
  }
  Some({ min: low, max: high, })
}

///|
pub extend Position with @debug.Debug::{to_repr}

///|
pub extend Position with Eq::{equal, not_equal}

///|
pub extend Bounds with @debug.Debug::{to_repr}

///|
pub extend Bounds with Eq::{equal, not_equal}
