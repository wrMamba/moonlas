///|
pub(all) struct Cell {
  count : Int32
  ground_count : Int32
  min_z : Double
  max_z : Double
  mean_z : Double
  mean_intensity : Double
} derive(Debug, Eq)

///|
/// Dense row-major XY grid. Empty cells are None, never fabricated elevations.
pub(all) struct Grid {
  origin_x : Double
  origin_y : Double
  cell_size : Double
  columns : Int32
  rows : Int32
  cells : Array[Cell?]
} derive(Debug)

///|
pub fn Grid::at(
  self : Grid,
  column : Int32,
  row : Int32,
) -> Cell? raise LasError {
  if column < 0 || row < 0 || column >= self.columns || row >= self.rows {
    return None
  }
  require(
    self.columns > 0 && self.rows <= 10000000 / self.columns,
    "invalid grid shape",
  )
  require(
    self.cells.length() == self.columns * self.rows,
    "grid storage disagrees with shape",
  )
  self.cells[row * self.columns + column]
}

///|
fn grid_dimension(
  low : Double,
  high : Double,
  size : Double,
  cap : Int32,
) -> Int32 raise LasError {
  let n = ((high - low) / size).floor()
  if !finite(n) || n < 0.0 || n >= cap.to_double() {
    raise Limit("grid axis budget exceeded")
  }
  n.to_int() + 1
}

///|
/// Bins are [origin+i*size, origin+(i+1)*size); the maximum endpoint gets a bin.
/// Class 2 is counted as ground without interpreting CRS or classification rules.
pub fn Document::elevation_grid(
  self : Document,
  cell_size : Double,
  limits~ : Limits = Limits::default(),
) -> Grid raise LasError {
  self.validate(limits~)
  require(finite(cell_size) && cell_size > 0.0, "invalid grid cell size")
  let bounds = point_bounds(self.points, self.header.transform)
  let b = match bounds {
    Some(b) => b
    None =>
      return {
        origin_x: 0.0,
        origin_y: 0.0,
        cell_size,
        columns: 0,
        rows: 0,
        cells: [],
      }
  }
  let columns = grid_dimension(b.min.x, b.max.x, cell_size, limits.max_cells)
  let rows = grid_dimension(b.min.y, b.max.y, cell_size, limits.max_cells)
  checked_size(rows, columns, limits.max_cells)
  let cells : Array[Cell?] = Array::make(columns * rows, None)
  for p in self.points {
    let q = self.header.transform.position(p)
    let c = ((q.x - b.min.x) / cell_size).floor().to_int()
    let r = ((q.y - b.min.y) / cell_size).floor().to_int()
    require(
      c >= 0 && c < columns && r >= 0 && r < rows,
      "point outside computed grid",
    )
    let index = r * columns + c
    let ground = if p.classification == 2 { 1 } else { 0 }
    cells[index] = Some(
      match cells[index] {
        None =>
          {
            count: 1,
            ground_count: ground,
            min_z: q.z,
            max_z: q.z,
            mean_z: q.z,
            mean_intensity: p.intensity.to_double(),
          }
        Some(old) => {
          let n = old.count + 1
          let w = 1.0 / n.to_double()
          let mean_z = old.mean_z * (1.0 - w) + q.z * w
          require(finite(mean_z), "elevation mean overflow")
          {
            count: n,
            ground_count: old.ground_count + ground,
            min_z: if q.z < old.min_z {
              q.z
            } else {
              old.min_z
            },
            max_z: if q.z > old.max_z {
              q.z
            } else {
              old.max_z
            },
            mean_z,
            mean_intensity: old.mean_intensity +
            (p.intensity.to_double() - old.mean_intensity) * w,
          }
        }
      },
    )
  }
  { origin_x: b.min.x, origin_y: b.min.y, cell_size, columns, rows, cells, }
}

///|
pub extend Cell with @debug.Debug::{to_repr}

///|
pub extend Cell with Eq::{equal, not_equal}

///|
pub extend Grid with @debug.Debug::{to_repr}
