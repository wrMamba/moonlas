///|
fn header_fixture(minor : Int32, format : Int32) -> Bytes {
  let a : Array[Byte] = Array::make(if minor == 2 { 227 } else { 375 }, 0)
  a[0] = 76
  a[1] = 65
  a[2] = 83
  a[3] = 70
  a[24] = 1
  a[25] = minor.to_byte()
  let width = if minor == 2 { 227 } else { 375 }
  a[94] = (width & 255).to_byte()
  a[95] = (width >> 8).to_byte()
  a[96] = (width & 255).to_byte()
  a[97] = (width >> 8).to_byte()
  a[104] = format.to_byte()
  a[105] = (if format == 6 { 30 } else { 20 }).to_byte()
  for offset in [131, 139, 147] {
    a[offset + 6] = 240
    a[offset + 7] = 63
  }
  bytes_of(a)
}

///|
test "read LAS12 and LAS14 headers" {
  assert_eq(read_header(header_fixture(2, 0)).point_count, 0)
  assert_eq(read_header(header_fixture(4, 6)).format, 6)
}

///|
test "header rejects compression and truncated record spans" {
  let a = header_fixture(2, 0).to_array()
  a[104] = 128
  assert_true(
    try {
      ignore(read_header(bytes_of(a)))
      false
    } catch {
      _ => true
    },
  )
  a[104] = 0
  a[107] = 1
  assert_true(
    try {
      ignore(read_header(bytes_of(a)))
      false
    } catch {
      _ => true
    },
  )
}
