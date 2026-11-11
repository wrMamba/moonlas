///|
test "opaque VLR and gap preservation" {
  let records = [
    {
      user_id: "LASF_Projection",
      record_id: 2112,
      description: "CRS",
      payload: b"abc\x00",
    },
  ]
  let meta = encode_vlrs(records)
  let out = header_fixture(2, 0).to_array()
  append(out, meta)
  append(out, b"gap")
  let h = {
    ..read_header(header_fixture(2, 0)),
    point_offset: out.length(),
    vlr_count: 1,
  }
  let (actual, gap) = read_vlrs(bytes_of(out), h)
  assert_eq(actual, records)
  assert_eq(gap, b"gap")
  assert_eq(vlrs_named(actual, "LASF_Projection", 2112).length(), 1)
}

///|
test "VLR span and field width failures" {
  let h = { ..read_header(header_fixture(2, 0)), vlr_count: 1, }
  assert_true(
    try {
      ignore(read_vlrs(header_fixture(2, 0), h))
      false
    } catch {
      _ => true
    },
  )
  let v = {
    user_id: "12345678901234567",
    record_id: 1,
    description: "",
    payload: b"",
  }
  assert_true(
    try {
      v.validate()
      false
    } catch {
      _ => true
    },
  )
}
