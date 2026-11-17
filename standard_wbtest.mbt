///|
fn waveform_test_point(format : Int32) -> Point {
  {
    ..sample_point(format, 0),
    waveform: Some(Waveform::{
      descriptor_index: 1,
      byte_offset: 60UL,
      packet_size: 4U,
      location: 0.5F,
      dx: 0.25F,
      dy: -0.5F,
      dz: 1.0F,
    }),
  }
}

///|
fn waveform_test_vlr() -> Vlr raise LasError {
  let bytes : Array[Byte] = [8, 0]
  put32(bytes, 4)
  put32(bytes, 10)
  putf64(bytes, 0.5)
  putf64(bytes, -1.0)
  Vlr::new("LASF_Spec", 100, "descriptor", bytes_of(bytes))
}

///|
fn internal_waveform_doc(format : Int32) -> Document raise LasError {
  let doc = create(
    [waveform_test_point(format)],
    format,
    Transform::new(0.01),
    vlrs=[waveform_test_vlr()],
  )
  doc.with_evlrs([
    Evlr::new("custom", 8, "before wave", b"prefix"),
    Evlr::new("LASF_Spec", 65535, "wave", b"\x01\x02\x03\xff"),
    Evlr::new("LASF_Projection", 2112, "WKT", b"LOCAL_CS[\"test\"]\x00"),
  ])
}

///|
test "all waveform formats resolve internal packets and calibrated amplitudes" {
  for format in [4, 5, 9, 10] {
    let d = decode(encode(internal_waveform_doc(format)))
    assert_eq(d.evlrs().length(), 3)
    assert_eq(d.waveform_packet(d.points[0]), b"\x01\x02\x03\xff")
    assert_eq(d.waveform_samples(d.points[0]), [-0.5, 0.0, 0.5, 126.5])
    assert_true((d.header.global_encoding & 2) != 0)
  }
}

///|
test "point filtering relocates EVLR and waveform pointers without changing their payloads" {
  let d = internal_waveform_doc(10)
  let duplicated = d.with_points([d.points[0], d.points[0], d.points[0]])
  let changed = duplicated.with_points([duplicated.points[0]])
  let offset_delta = 2 * d.header.record_length
  assert_eq(duplicated.header.evlr_offset, d.header.evlr_offset + offset_delta)
  assert_eq(
    duplicated.header.waveform_offset,
    d.header.waveform_offset + offset_delta,
  )
  assert_eq(changed.tail, d.tail)
  let result = decode(encode(changed))
  assert_eq(result.waveform_packet(result.points[0]), b"\x01\x02\x03\xff")
  assert_eq(result.evlrs(), d.evlrs())
  let cursor = open_records(encode(result))
  assert_eq(cursor.remaining(), 1)
}

///|
test "EVLR replacement relocates waveform after variable metadata lengths" {
  let d = internal_waveform_doc(9)
  let records = d.evlrs()
  records[0] = Evlr::new("custom", 8, "longer", Bytes::make(100, 255))
  let changed = d.with_evlrs(records)
  assert_eq(changed.header.waveform_offset, d.header.waveform_offset + 94)
  assert_eq(changed.waveform_packet(changed.points[0]), b"\x01\x02\x03\xff")
  assert_true(
    try {
      ignore(d.with_evlrs([]))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "external WDP input is explicit and offset arithmetic retains all 64 bits" {
  let p = waveform_test_point(4)
  let base = create([p], 4, Transform::new(0.01), minor=3, vlrs=[
    waveform_test_vlr(),
  ])
  let d = { ..base, header: { ..base.header, global_encoding: 4, }, }
  let wdp : Array[Byte] = []
  put_evlr(wdp, Evlr::new("LASF_Spec", 65535, "wave", b"\x01\x02\x03\xff"))
  assert_eq(d.waveform_samples(p, external=Some(bytes_of(wdp))), [
    -0.5, 0.0, 0.5, 126.5,
  ])
  assert_true(
    try {
      ignore(d.waveform_packet(p))
      false
    } catch {
      _ => true
    },
  )
  let huge = {
    ..p,
    waveform: p.waveform.map(w => {
      ..w,
      byte_offset: 18446744073709551615UL,
      packet_size: 4294967295U,
    }),
  }
  assert_eq(read_point(write_point(huge, 4), 4), huge)
  assert_true(
    try {
      ignore(d.waveform_packet(huge, external=Some(bytes_of(wdp))))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "LAS13 standalone waveform record and point count changes" {
  let p = waveform_test_point(5)
  let d = create([p], 5, Transform::new(0.01), minor=3, vlrs=[
    waveform_test_vlr(),
  ])
  let tail : Array[Byte] = [17, 18]
  put_evlr(tail, Evlr::new("LASF_Spec", 65535, "wave", b"\x01\x02\x03\xff"))
  append(tail, b"suffix")
  let d = {
    ..d,
    tail: bytes_of(tail),
    header: {
      ..d.header,
      global_encoding: 2,
      waveform_offset: point_end(d.header) + 2,
    },
  }
  let changed = d.with_points([p, p])
  let reread = decode(encode(changed))
  assert_eq(reread.header.minor, 3)
  assert_eq(reread.tail, d.tail)
  assert_eq(reread.waveform_samples(reread.points[1]), [-0.5, 0.0, 0.5, 126.5])
}

///|
test "large EVLR payload and unknown tail bytes survive full roundtrip" {
  let d = create([sample_point(8, 0)], 8, Transform::new(1.0))
  let d = { ..d, tail: b"uninterpreted-gap", }
  let d = d.with_evlrs([
    Evlr::new("unknown-vendor", 60000, "large", Bytes::make(70000, 201)),
  ])
  let d = {
    ..d,
    tail: bytes_of(
      {
        let a = d.tail.to_array()
        append(a, b"trailing")
        a
      },
    ),
  }
  let raw = encode(d)
  let result = decode(raw)
  assert_true(encode(result) == raw)
  assert_eq(result.evlrs()[0].payload.length(), 70000)
  assert_eq(result.with_points([]).tail, d.tail)
}

///|
test "extended public header and noncanonical fixed text are preserved" {
  let base = create([Point::new(1, 2, 3)], 0, Transform::new(1.0), minor=2, vlrs=[
    Vlr::new("vendor", 1, "opaque", b"x"),
  ])
  let d = { ..base, header: { ..base.header, extra: b"header-extension", }, }.with_points(
    base.points,
  )
  let raw = encode(d).to_array()
  raw[35] = 255
  raw[60] = 9
  let vlr_start = base_header_size(2) + d.header.extra.length()
  raw[vlr_start] = 0x34
  raw[vlr_start + 1] = 0x12
  raw[vlr_start + 17] = 223
  raw[vlr_start + 52] = 27
  let result = decode(bytes_of(raw))
  assert_eq(result.header.extra, b"header-extension")
  assert_eq(result.vlrs[0].reserved, 4660)
  assert_true(encode(result) == bytes_of(raw))
  let edited = {
    ..result,
    vlrs: [{ ..result.vlrs[0], description: "edited", }],
  }
  let reread = decode(encode(edited))
  assert_eq(reread.vlrs[0].description, "edited")
  assert_eq(reread.vlrs[0].reserved, 4660)
}

///|
test "negative finite coordinate scales retain valid geometry" {
  let d = create([Point::new(5, 2, 9)], 0, Transform::new(-0.5), minor=1)
  assert_eq(d.header.bounds, (-2.5, -1.0, -4.5, -2.5, -1.0, -4.5))
  assert_eq(decode(encode(d)).points, d.points)
  assert_eq(d.requantize(Transform::new(0.5), 0.0).document.points[0].x, -5)
}

///|
test "legacy count mode survives LAS14 rewrite" {
  let d = create([Point::new(1, 2, 3)], 0, Transform::new(1.0))
  let with_legacy = { ..d, header: { ..d.header, legacy_counts: true, }, }
  let reread = decode(encode(with_legacy))
  assert_true(reread.header.legacy_counts)
  assert_eq(
    decode(encode(reread.with_points([d.points[0], d.points[0]]))).header.point_count,
    2,
  )
}

///|
test "EVLR truncations counts overlaps and 64 bit lengths fail safely" {
  let d = internal_waveform_doc(10)
  let raw = encode(d)
  let first = d.header.evlr_offset
  for n in first..<raw.length() {
    assert_true(
      try {
        ignore(decode(slice_bytes(raw, 0, n)))
        false
      } catch {
        _ => true
      },
    )
  }
  for offset in [239, 247, first + 24] {
    let invalid = raw.to_array()
    invalid[offset] = 255
    assert_true(
      try {
        ignore(decode(bytes_of(invalid)))
        false
      } catch {
        _ => true
      },
    )
  }
  let invalid = raw.to_array()
  invalid[235] = 1
  invalid[236] = 0
  invalid[237] = 0
  invalid[238] = 0
  assert_true(
    try {
      ignore(decode(bytes_of(invalid)))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(decode(raw, limits={ ..Limits::default(), max_vlrs: 2, }))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "waveform sample precision and record bounds are checked" {
  let d = internal_waveform_doc(9)
  let p = d.points[0]
  let bad = {
    ..p,
    waveform: p.waveform.map(w => { ..w, byte_offset: 63UL, packet_size: 4U, }),
  }
  assert_true(
    try {
      ignore(d.waveform_packet(bad))
      false
    } catch {
      _ => true
    },
  )
  let wrong = { ..d, vlrs: [Vlr::new("LASF_Spec", 100, "bad", b"short")], }
  assert_true(
    try {
      ignore(wrong.waveform_samples(p))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "16 bit waveform calibration and EVLR reserved text survive rewriting" {
  let descriptor : Array[Byte] = [16, 0]
  put32(descriptor, 2)
  put32(descriptor, 10)
  putf64(descriptor, 2.0)
  putf64(descriptor, -1.0)
  let base = internal_waveform_doc(10)
  let record = { ..Evlr::new("custom", 77, "text", b"payload"), reserved: 99, }
  let d = {
      ..base,
      vlrs: [Vlr::new("LASF_Spec", 100, "16 bit", bytes_of(descriptor))],
    }
    .with_points(base.points)
    .with_evlrs([
      record,
      Evlr::new("LASF_Spec", 65535, "wave", b"\x01\x00\xff\xff"),
    ])
  let encoded = encode(d).to_array()
  encoded[d.header.evlr_offset + 2 + 7] = 255
  let decoded = decode(bytes_of(encoded))
  assert_eq(decoded.waveform_samples(decoded.points[0]), [1.0, 131069.0])
  assert_eq(decoded.evlrs()[0].reserved, 99)
  assert_true(encode(decoded) == bytes_of(encoded))
  encoded[6] = 6
  assert_true(
    try {
      ignore(decode(bytes_of(encoded)))
      false
    } catch {
      _ => true
    },
  )
}
