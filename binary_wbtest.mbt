///|
test "signed little endian and truncated reads" {
  let r = Reader::new(b"\xff\xff\x00\x80\x00\x00\x00\x80", 0, 8)
  assert_eq(r.u16(), 65535)
  assert_eq(r.i16(), -32768)
  assert_eq(r.i32(), -2147483648)
  assert_true(
    try {
      ignore(r.u8())
      false
    } catch {
      Truncated(8) => true
      _ => false
    },
  )
}

///|
test "unsigned counts and product bounds" {
  let r = Reader::new(b"\xff\xff\xff\xff", 0, 4)
  assert_true(
    try {
      ignore(r.u32(100))
      false
    } catch {
      Limit(_) => true
      _ => false
    },
  )
  assert_true(
    try {
      checked_size(2147483647, 38, 100)
      false
    } catch {
      _ => true
    },
  )
}
