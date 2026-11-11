///|
fn main {
  try {
    let p = @las.Point::new(0, 0, 10)
    let points = Array::makei(120, i => {
      ..p,
      x: i,
      y: i % 12,
      z: 10 + i % 9,
      classification: i % 6,
      intensity: i * 500,
      flags: if i % 7 == 0 {
        4
      } else {
        0
      },
    })
    let source = @las.create(points, 0, @las.Transform::new(0.01), minor=2)
    let bytes = @las.encode(source)
    let loaded = @las.decode(bytes)
    let qc = loaded.audit()
    assert_eq(qc.count, 120)
    assert_eq(qc.issues.length(), 0)
    let selection = {
      ..@las.Selection::all(),
      include_withheld: false,
      min_intensity: 1000,
    }
    let clean = loaded.select(selection)
    let output = @las.encode(clean)
    assert_true(clean.points.length() < qc.count)
    assert_eq(@las.decode(output).audit().issues.length(), 0)
    println(
      "quality: input=120; withheld=\{qc.flags[2]}; accepted=\{clean.points.length()}; bytes=\{output.length()}",
    )
  } catch {
    _ => abort("quality workflow failed")
  }
}
