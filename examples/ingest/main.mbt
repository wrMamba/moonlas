///|
fn main {
  try {
    let base = @las.Point::new(0, 0, 0)
    let points = Array::makei(64, i => {
      ..base,
      x: i,
      y: i * 2,
      z: i * 3,
      gps_time: Some(100.0 + i.to_double()),
      rgb: Some((i * 100, 200, 300)),
      nir: Some(i * 20),
      extra: b"\x01\x02",
    })
    let doc = @las.create(points, 8, @las.Transform::new(0.01))
    let input = @las.encode(doc)
    let cursor = @las.open_records(input)
    let mut seen = 0
    while cursor.remaining() > 0 {
      let batch = cursor.batch(9)
      seen += batch.length()
      for p in batch {
        assert_true(p.rgb is Some(_))
      }
    }
    assert_eq(seen, 64)
    let normalized = doc.requantize(@las.Transform::new(0.02), 0.011)
    let result = normalized.document.within_radius(
      { x: 0.0, y: 0.0, z: 0.0, },
      1.0,
    )
    let output = @las.encode(result)
    assert_true(result.points.length() > 0)
    assert_eq(@las.decode(output).points[0].extra, b"\x01\x02")
    println(
      "ingest: batches=8; seen=\{seen}; radius_hits=\{result.points.length()}; output_bytes=\{output.length()}",
    )
  } catch {
    _ => abort("ingest workflow failed")
  }
}
