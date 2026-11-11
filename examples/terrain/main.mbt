///|
fn main {
  try {
    let p = @las.Point::new(0, 0, 0)
    let points = Array::makei(100, i => {
      ..p,
      x: i % 10,
      y: i / 10,
      z: i % 10 + i / 10,
      classification: if i % 3 == 0 {
        5
      } else {
        2
      },
    })
    let input = @las.encode(@las.create(points, 0, @las.Transform::new(1.0)))
    let ground = @las.decode(input).select({
      ..@las.Selection::all(),
      classifications: [2],
    })
    let cropped = ground.crop({
      min: { x: 0.0, y: 0.0, z: 0.0, },
      max: { x: 5.0, y: 5.0, z: 20.0, },
    })
    let grid = cropped.elevation_grid(2.0)
    assert_eq(grid.columns, 3)
    assert_eq(grid.rows, 3)
    let mut count = 0
    println("column,row,count,min_z,max_z,mean_z")
    for r in 0..<grid.rows {
      for c in 0..<grid.columns {
        if grid.at(c, r) is Some(cell) {
          count += cell.count
          println(
            "\{c},\{r},\{cell.count},\{cell.min_z},\{cell.max_z},\{cell.mean_z}",
          )
        }
      }
    }
    assert_eq(count, cropped.points.length())
    assert_true(count > 0)
  } catch {
    _ => abort("terrain workflow failed")
  }
}
