///|
test "merge normalizes scales keeps order and rejects silent metadata changes" {
  let p = sample_point(6, 0)
  let a = create([p], 6, Transform::new(0.01))
  let b = create([p], 6, Transform::new(0.02))
  let combined = a.merge(b, 0.0000001)
  assert_eq(combined.points.length(), 2)
  assert_eq(combined.points[0], p)
  assert_eq(combined.points[1].x, p.x * 2)
  assert_eq(combined.audit().issues.length(), 0)
  assert_true(
    try {
      ignore(a.merge(b, 1.0, limits={ ..Limits::default(), max_points: 1, }))
      false
    } catch {
      _ => true
    },
  )
  let conflict = { ..b, header: { ..b.header, global_encoding: 1, }, }
  assert_true(
    try {
      ignore(a.merge(conflict, 1.0))
      false
    } catch {
      _ => true
    },
  )
}
