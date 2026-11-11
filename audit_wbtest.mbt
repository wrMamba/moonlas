///|
test "audit identifies stale header fields and recompute repairs" {
  let doc = create(
    [sample_point(6, 0), sample_point(6, 2)],
    6,
    Transform::new(0.5),
  )
  let bad = {
    ..doc,
    header: {
      ..doc.header,
      by_return: Array::make(15, 0),
      bounds: (0.0, 0.0, 0.0, 0.0, 0.0, 0.0),
    },
  }
  let report = bad.audit()
  assert_eq(report.issues.length(), 2)
  assert_eq(report.classifications[2], 2)
  assert_eq(report.flags[0], 2)
  assert_eq(report.intensity_mean, 1001.0)
  assert_eq(bad.with_points(bad.points).audit().issues.length(), 0)
  assert_eq(decode(encode(bad)).audit().issues.length(), 0)
}

///|
test "empty audit has defined zero intensity and absent bounds" {
  let a = create([], 0, Transform::new(1.0)).audit()
  assert_eq(a.bounds, None)
  assert_eq(a.intensity_min, 0)
  assert_eq(a.intensity_mean, 0.0)
}
