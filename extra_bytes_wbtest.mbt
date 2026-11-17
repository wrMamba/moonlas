///|
test "all thirty Extra Bytes numeric types retain exact scalar and vector values" {
  for data_type in 1..<=30 {
    let descriptor : Array[Byte] = Array::make(192, 0)
    descriptor[2] = data_type.to_byte()
    let record = Vlr::new("LASF_Spec", 4, "layout", bytes_of(descriptor))
    let width = extra_scalar_width(data_type)
    let count = (data_type - 1) / 10 + 1
    let dim = extra_dimensions([record], width * count)[0]
    let bytes : Array[Byte] = []
    for _ in 0..<count {
      match (data_type - 1) % 10 {
        8 => put_float32(bytes, 1.0F)
        9 => putf64(bytes, 1.0)
        _ => {
          put8(bytes, 1)
          for _ in 1..<width {
            put8(bytes, 0)
          }
        }
      }
    }
    let values = extra_values(
      { ..Point::new(0, 0, 0), extra: bytes_of(bytes), },
      dim,
    )
    assert_eq(values.length(), count)
    for value in values {
      match value {
        Unsigned(n) => assert_eq(n, 1UL)
        Signed(n) => assert_eq(n, 1L)
        Real(n) => assert_eq(n, 1.0)
      }
    }
  }
}

///|
test "uint64 extra values avoid floating point loss and bad layouts are rejected" {
  let descriptor : Array[Byte] = Array::make(192, 0)
  descriptor[2] = 7
  let record = Vlr::new("LASF_Spec", 4, "uint64", bytes_of(descriptor))
  let dim = extra_dimensions([record], 8)[0]
  let p = { ..Point::new(0, 0, 0), extra: Bytes::make(8, 255), }
  assert_eq(extra_values(p, dim), [Unsigned(18446744073709551615UL)])
  assert_true(
    try {
      ignore(extra_dimensions([record], 7))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(extra_dimensions([Vlr::new("LASF_Spec", 4, "bad", b"short")], 8))
      false
    } catch {
      _ => true
    },
  )
  descriptor[2] = 0
  descriptor[3] = 8
  let dim = extra_dimensions(
      [Vlr::new("LASF_Spec", 4, "opaque", bytes_of(descriptor))],
      8,
    )[0]
  assert_eq(dim.byte_width, 8)
  assert_true(
    try {
      ignore(extra_values(p, dim))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "projection records include GeoTIFF VLRs and WKT EVLRs after filtering" {
  let base = internal_waveform_doc(10)
  let d = {
    ..base,
    vlrs: [
      waveform_test_vlr(),
      Vlr::new("LASF_Projection", 34735, "GeoKey", b"opaque-geokeys"),
    ],
  }.with_points(base.points)
  let result = decode(encode(d.with_points([])))
  let records = result.projection_records()
  assert_eq(records.length(), 2)
  assert_eq(records[0].record_id, 34735)
  assert_true(!records[0].extended)
  assert_eq(records[1].record_id, 2112)
  assert_true(records[1].extended)
}
