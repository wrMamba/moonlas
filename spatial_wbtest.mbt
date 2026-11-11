///|
test "inclusive scaled bounds and spherical selection preserve point attributes" {
  let p = sample_point(8, 0)
  let d = create(
    [
      { ..p, x: 0, y: 0, z: 0, },
      { ..p, x: 3, y: 4, z: 0, },
      { ..p, x: 6, y: 8, z: 0, },
    ],
    8,
    Transform::new(0.5),
  )
  let center : Position = { x: 0.0, y: 0.0, z: 0.0, }
  assert_eq(d.within_radius(center, 2.5).points.length(), 2)
  assert_eq(d.within_radius(center, 0.0).points.length(), 1)
  let b : Bounds = { min: center, max: { x: 1.5, y: 2.0, z: 0.0, }, }
  assert_eq(d.crop(b).points, d.within_radius(center, 2.5).points)
  assert_eq(d.crop(b).audit().issues.length(), 0)
  assert_true(
    try {
      ignore(d.within_radius(center, -1.0))
      false
    } catch {
      _ => true
    },
  )
}
