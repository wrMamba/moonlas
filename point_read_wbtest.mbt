///|
test "LAS12 packed return class flags and signed angle" {
  let a : Array[Byte] = []
  put32(a, -4)
  put32(a, 5)
  put32(a, 6)
  put16(a, 1234)
  put8(a, 2 | (3 << 3) | 64 | 128)
  put8(a, 2 | (5 << 5))
  put8(a, -12)
  put8(a, 7)
  put16(a, 54321)
  append(a, b"extra")
  let p = read_point(bytes_of(a), 0)
  assert_eq((p.x, p.y, p.z), (-4, 5, 6))
  assert_eq(
    (p.return_number, p.returns, p.classification, p.flags),
    (2, 3, 2, 5),
  )
  assert_eq(p.scan_angle, -12)
  assert_true(p.scan_direction && p.edge)
  assert_eq(p.extra, b"extra")
}

///|
test "LAS14 independent classification scanner and angle" {
  let a : Array[Byte] = []
  put32(a, 1)
  put32(a, 2)
  put32(a, 3)
  put16(a, 65535)
  put8(a, 9 | (12 << 4))
  put8(a, 13 | (2 << 4) | 128)
  put8(a, 200)
  put8(a, 10)
  put16(a, -1234)
  put16(a, 99)
  putf64(a, 123.5)
  let p = read_point(bytes_of(a), 6)
  assert_eq(
    (p.return_number, p.returns, p.classification, p.flags),
    (9, 12, 200, 13),
  )
  assert_eq(p.scanner_channel, 2)
  assert_eq(p.scan_angle, -1234)
  assert_eq(p.gps_time, Some(123.5))
}
