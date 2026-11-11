///|
test "create recomputes extents returns and exact record width" {
  let doc = create(
    [sample_point(6, 0), sample_point(6, 2)],
    6,
    Transform::new(0.5),
  )
  assert_eq(doc.header.point_count, 2)
  assert_eq(doc.header.record_length, 32)
  assert_eq(doc.header.by_return[0], 2)
  assert_eq(doc.header.bounds, (-50.0, 99.0, 0.0, -49.0, 100.0, 3.0))
  let empty = doc.with_points([])
  assert_eq(empty.header.point_count, 0)
  assert_eq(empty.header.record_length, 32)
}

///|
test "decode empty files and reject trailing bytes" {
  assert_eq(decode(header_fixture(2, 0)).points.length(), 0)
  let a = header_fixture(2, 0).to_array()
  append(a, b"x")
  assert_true(
    try {
      ignore(decode(bytes_of(a)))
      false
    } catch {
      _ => true
    },
  )
}
