///|
test "all proper prefixes reject without panic" {
  let d = create(
    [sample_point(8, 0), sample_point(8, 1)],
    8,
    Transform::new(0.01),
  )
  let raw = encode(d)
  for n in 0..<raw.length() {
    let prefix = Bytes::from_array(raw.to_array()[0:n])
    assert_true(
      try {
        ignore(decode(prefix))
        false
      } catch {
        _ => true
      },
    )
  }
}

///|
test "unsigned high words reserved fields and resource limits reject" {
  let d = create([sample_point(6, 0)], 6, Transform::new(0.01))
  let raw = encode(d)
  for offset in [100, 104, 235, 243, 247, 251, 259] {
    let bad = raw.to_array()
    bad[offset] = 255
    assert_true(
      try {
        ignore(decode(bytes_of(bad)))
        false
      } catch {
        _ => true
      },
    )
  }
  assert_true(
    try {
      ignore(decode(raw, limits={ ..Limits::default(), max_points: 0, }))
      false
    } catch {
      _ => true
    },
  )
  let with_vlr = create([], 0, Transform::new(1.0), vlrs=[
    { user_id: "x", record_id: 1, description: "x", payload: b"a", },
  ])
  assert_true(
    try {
      ignore(
        decode(encode(with_vlr), limits={ ..Limits::default(), max_vlrs: 0, }),
      )
      false
    } catch {
      _ => true
    },
  )
}

///|
test "mutated modern format in legacy document fails before histogram indexing" {
  let d = create([sample_point(6, 0)], 6, Transform::new(0.01))
  let bad = { ..d, header: { ..d.header, minor: 2, }, }
  let p = { ..d.points[0], return_number: 15, returns: 15, }
  assert_true(
    try {
      ignore(bad.with_points([p]))
      false
    } catch {
      _ => true
    },
  )
}

///|
test "deterministic point property matrix covers int32 extremes and all flag bits" {
  for f in [0, 1, 2, 3, 6, 7, 8] {
    for i in 0..<256 {
      let old = f < 6
      let cap = if old { 5 } else { 15 }
      let p = {
        ..sample_point(f, i),
        x: if i % 2 == 0 {
          -2147483648
        } else {
          2147483647
        },
        intensity: i * 257,
        return_number: i % cap + 1,
        returns: cap,
        flags: i % (if old { 8 } else { 16 }),
        classification: i % (if old { 32 } else { 256 }),
        scan_direction: i % 2 == 0,
        edge: i % 3 == 0,
        scanner_channel: if old {
          0
        } else {
          i % 4
        },
        scan_angle: if old {
          i % 181 - 90
        } else {
          i * 200 - 25000
        },
      }
      assert_eq(read_point(write_point(p, f), f), p)
    }
  }
}
