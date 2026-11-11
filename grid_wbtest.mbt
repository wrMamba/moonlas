///|
test "bounded grid bins negative positions borders and empty cells" {
  let p = Point::new(-2, -2, 10)
  let d = create(
    [{ ..p, classification: 2, }, { ..p, z: 20, }, { ..p, x: 0, y: 0, z: 50, }],
    0,
    Transform::new(0.5),
  )
  let g = d.elevation_grid(1.0)
  assert_eq((g.columns, g.rows), (2, 2))
  let c = match g.at(0, 0) {
    Some(c) => c
    None => fail("missing cell")
  }
  assert_eq(c.count, 2)
  assert_eq(c.ground_count, 1)
  assert_eq(c.mean_z, 7.5)
  assert_eq(c.min_z, 5.0)
  assert_eq(g.at(1, 0), None)
  assert_eq(g.at(-1, 0), None)
  assert_eq(g.at(2, 0), None)
  assert_true(
    try {
      ignore(
        d.elevation_grid(0.01, limits={ ..Limits::default(), max_cells: 4, }),
      )
      false
    } catch {
      _ => true
    },
  )
}

///|
test "empty grid and huge extent never allocate unbounded cells" {
  assert_eq(
    create([], 0, Transform::new(1.0)).elevation_grid(1.0).cells.length(),
    0,
  )
  let d = create(
    [Point::new(-2147483648, 0, 0), Point::new(2147483647, 0, 0)],
    0,
    Transform::new(1.0),
  )
  assert_true(
    try {
      ignore(d.elevation_grid(1.0))
      false
    } catch {
      _ => true
    },
  )
}
