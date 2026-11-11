///|
fn sample_point(format : Int32, i : Int32) -> Point {
  let p = Point::new(-100 + i, 200 - i, i * 3)
  {
    ..p,
    intensity: 1000 + i,
    classification: 2,
    flags: 3,
    scan_angle: -15,
    source_id: 200,
    user_data: 99,
    extra: b"\xff\x00",
    gps_time: if format == 1 || format == 3 || format >= 6 {
      Some(1234.5)
    } else {
      None
    },
    rgb: if format == 2 || format == 3 || format == 7 || format == 8 {
      Some((0, 123, 65535))
    } else {
      None
    },
    nir: if format == 8 {
      Some(12345)
    } else {
      None
    },
  }
}

///|
test "all seven formats preserve raw attributes and extra bytes" {
  for f in [0, 1, 2, 3, 6, 7, 8] {
    for i in 0..<20 {
      let p = sample_point(f, i)
      let data = write_point(p, f)
      assert_eq(data.length(), record_size(f) + 2)
      assert_eq(read_point(data, f), p)
    }
  }
}

///|
test "encoder rejects incompatible optional attributes" {
  assert_true(
    try {
      ignore(write_point(sample_point(8, 0), 0))
      false
    } catch {
      _ => true
    },
  )
}
