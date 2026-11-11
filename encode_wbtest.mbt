///|
test "complete documents preserve seven formats UUID VLRs padding and extras" {
  let vlr : Vlr = {
    user_id: "example",
    record_id: 9,
    description: "opaque",
    payload: b"\x00\xffdata",
  }
  for format in [0, 1, 2, 3, 6, 7, 8] {
    for minor in [2, 4] {
      if minor == 2 && format >= 6 {
        continue
      }
      let doc = create(
        [sample_point(format, 0), sample_point(format, 1)],
        format,
        Transform::new(0.01),
        minor~,
        vlrs=[vlr],
      )
      let doc = { ..doc, gap: b"gap", }
      let doc = doc.with_points(doc.points)
      let raw = encode(doc)
      let parsed = decode(raw)
      assert_eq(parsed.points, doc.points)
      assert_eq(parsed.vlrs, doc.vlrs)
      assert_eq(parsed.gap, b"gap")
      assert_eq(parsed.header.by_return, doc.header.by_return)
      assert_eq(encode(parsed), raw)
    }
  }
}

///|
test "encode empty documents and validate mutated metadata" {
  let doc = create([], 0, Transform::new(1.0))
  assert_eq(decode(encode(doc)).points.length(), 0)
  let bad = { ..doc, header: { ..doc.header, system: "非ASCII", }, }
  assert_true(
    try {
      ignore(encode(bad))
      false
    } catch {
      _ => true
    },
  )
}
