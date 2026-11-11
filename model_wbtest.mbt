///|
test "point and budget model" {
  Limits::default().validate()
  Transform::new(0.01).validate()
  Point::new(-1, 2, 3).validate(0)
  assert_eq(record_size(8), 38)
}

///|
test "invalid point formats and scales" {
  assert_true(
    try {
      ignore(record_size(4))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(Transform::new(0.0))
      false
    } catch {
      _ => true
    },
  )
  let p = { ..Point::new(0, 0, 0), return_number: 0, }
  assert_true(
    try {
      p.validate(0)
      false
    } catch {
      _ => true
    },
  )
}
