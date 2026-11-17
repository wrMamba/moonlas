///|
fn main {
  try {
    // Descriptor: 8-bit samples, no compression, 4 samples, 10ps interval,
    // gain=0.5 and offset=-1.0 (IEEE little endian).
    let descriptor = b"\x08\x00\x04\x00\x00\x00\x0a\x00\x00\x00\x00\x00\x00\x00\x00\x00\xe0\x3f\x00\x00\x00\x00\x00\x00\xf0\xbf"
    let point = {
      ..@las.Point::new(10, 20, 30),
      gps_time: Some(123.0),
      rgb: Some((100, 200, 300)),
      nir: Some(400),
      waveform: Some(@las.Waveform::{
        descriptor_index: 1,
        byte_offset: 60UL,
        packet_size: 4U,
        location: 0.5F,
        dx: 0.0F,
        dy: 0.0F,
        dz: 1.0F,
      }),
    }
    let base = @las.create([point, point], 10, @las.Transform::new(0.01), vlrs=[
      @las.Vlr::new("LASF_Spec", 100, "samples", descriptor),
    ])
    let doc = { ..base, header: { ..base.header, global_encoding: 16, }, }.with_evlrs([
        @las.Evlr::new(
          "LASF_Projection", 2112, "WKT", b"LOCAL_CS[\"engineering\"]\x00",
        ),
        @las.Evlr::new("LASF_Spec", 65535, "waveform", b"\x01\x02\x03\xff"),
        @las.Evlr::new("example", 7, "retained metadata", b"survey-2026"),
      ],
    )
    let filtered = doc.with_points([doc.points[0]])
    let result = @las.decode(@las.encode(filtered))
    assert_eq(result.waveform_samples(result.points[0]), [-0.5, 0.0, 0.5, 126.5])
    assert_eq(result.evlrs(), doc.evlrs())
    assert_eq(result.projection_records().length(), 1)
    assert_eq(doc.header.waveform_offset - result.header.waveform_offset, 67)
    println(
      "waveform: format=10; input=2; output=1; EVLRs=3; samples=4; metadata retained",
    )
  } catch {
    _ => abort("waveform workflow failed")
  }
}
