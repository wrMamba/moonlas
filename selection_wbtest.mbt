///|
test "intersect LAS class source return intensity withheld and GPS predicates" {
  let p = sample_point(8, 0)
  let doc = create(
    [
      p,
      { ..p, classification: 5, },
      { ..p, flags: 4, },
      { ..p, returns: 2, },
      { ..p, source_id: 2, },
    ],
    8,
    Transform::new(0.01),
  )
  let s = {
    ..Selection::all(),
    classifications: [2],
    source_ids: [200],
    include_withheld: false,
    return_mode: Single,
    gps_min: Some(1234.5),
    gps_max: Some(1234.5),
  }
  let result = doc.select(s)
  assert_eq(result.points, [p])
  assert_eq(decode(encode(result)).points, [p])
  assert_eq(result.audit().issues.length(), 0)
  assert_eq(doc.select({ ..s, min_intensity: 1001, }).points.length(), 0)
}

///|
test "GPS filtering rejects missing time and invalid ranges" {
  let d = create([Point::new(0, 0, 0)], 0, Transform::new(1.0))
  assert_eq(
    d.select({ ..Selection::all(), gps_min: Some(0.0), }).points.length(),
    0,
  )
  assert_true(
    try {
      ignore(
        d.select({ ..Selection::all(), min_intensity: 100, max_intensity: 0, }),
      )
      false
    } catch {
      _ => true
    },
  )
}
