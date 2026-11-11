///|
test "scaled positions and quantization preserve integer lattice" {
  let t = { ..Transform::new(0.125), ox: 100.0, oy: -20.0, sz: 2.0, }
  for i in -100..<100 {
    let p = Point::new(i, -i, i * 2)
    assert_eq(t.quantize(t.position(p), p), p)
  }
  let q = Transform::new(1.0).quantize(
    { x: -1.5, y: 1.5, z: 0.0, },
    Point::new(0, 0, 0),
  )
  assert_eq((q.x, q.y), (-2, 2))
}

///|
test "bounds and quantization overflow" {
  let t = Transform::new(1.0)
  let bounds = point_bounds([Point::new(-2, 1, 3), Point::new(4, -5, 0)], t).unwrap()
  assert_eq(bounds.min, { x: -2.0, y: -5.0, z: 0.0, })
  assert_true(bounds.contains({ x: 4.0, y: 1.0, z: 0.0, }))
  assert_true(
    try {
      ignore(
        t.quantize({ x: 2147483648.0, y: 0.0, z: 0.0, }, Point::new(0, 0, 0)),
      )
      false
    } catch {
      _ => true
    },
  )
}
