///|
test "requantization reports bounded error and preserves non-coordinate attributes" {
  let p = sample_point(8, 1)
  let d = create([p], 8, Transform::new(0.01))
  let r = d.requantize(Transform::new(0.1), 0.051)
  assert_true(r.max_error.x <= 0.051)
  assert_eq(r.document.points[0].extra, p.extra)
  assert_eq(r.document.points[0].rgb, p.rgb)
  assert_eq(r.document.audit().issues.length(), 0)
  assert_true(
    try {
      ignore(d.requantize(Transform::new(0.1), 0.0))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(d.requantize(Transform::new(0.00000000001), 1.0))
      false
    } catch {
      _ => true
    },
  )
}
