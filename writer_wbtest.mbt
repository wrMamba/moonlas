///|
test "integer and double writers preserve exact bits" {
  let out : Array[Byte] = []
  put32(out, -2147483648)
  putf64(out, -12345.125)
  put64(out, 789)
  put_text(out, "LAS", 4)
  let r = Reader::new(bytes_of(out), 0, out.length())
  assert_eq(r.i32(), -2147483648)
  assert_eq(r.f64(), -12345.125)
  assert_eq(r.u64(1000), 789)
  assert_eq(r.text(4), "LAS")
}

///|
test "fixed text rejects lossy truncation" {
  let out : Array[Byte] = []
  assert_true(
    try {
      put_text(out, "ABCDE", 4)
      false
    } catch {
      _ => true
    },
  )
}
