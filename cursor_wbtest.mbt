///|
test "cursor seeks batches and terminates without materializing all points" {
  let d = create(
    Array::makei(7, i => sample_point(6, i)),
    6,
    Transform::new(0.01),
  )
  let c = open_records(encode(d))
  assert_eq(c.header().format, 6)
  assert_eq(c.batch(3), d.points[0:3].to_owned())
  assert_eq(c.position(), 3)
  assert_eq(c.remaining(), 4)
  c.seek(6)
  assert_eq(c.next(), Some(d.points[6]))
  assert_eq(c.next(), None)
  assert_true(
    try {
      c.seek(8)
      false
    } catch {
      _ => true
    },
  )
  c.seek(0)
  assert_eq(c.batch(100), d.points)
}
