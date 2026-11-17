///|
/// Resolve one waveform packet from the internal EVLR or the caller's external
/// WDP bytes. Offsets are relative to the 60-byte waveform record header.
pub fn Document::waveform_packet(
  self : Document,
  point : Point,
  external~ : Bytes? = None,
  limits~ : Limits = Limits::default(),
) -> Bytes raise LasError {
  self.validate(limits~)
  let w = match point.waveform {
    Some(w) => w
    None => raise Invalid("point has no waveform fields")
  }
  if w.descriptor_index == 0 {
    return b""
  }
  let source = if (self.header.global_encoding & 4) != 0 {
    match external {
      Some(data) => data
      None => raise Invalid("external WDP bytes are required")
    }
  } else {
    require(self.header.waveform_offset > 0, "internal waveform data is absent")
    let start = self.header.waveform_offset - point_end(self.header)
    slice_bytes(self.tail, start, self.tail.length() - start)
  }
  if source.length() > limits.max_bytes {
    raise Limit("waveform input byte budget exceeded")
  }
  let r = Reader::new(source, 0, source.length())
  let record = read_evlr(r, limits)
  require(
    record.user_id == "LASF_Spec" && record.record_id == 65535,
    "invalid WDP record header",
  )
  require(
    w.byte_offset >= 60UL && w.byte_offset <= r.pos.to_uint64(),
    "waveform offset outside data record",
  )
  let start = w.byte_offset.to_int()
  require(
    w.packet_size.to_uint64() <= (r.pos - start).to_uint64(),
    "waveform packet overruns data record",
  )
  slice_bytes(source, start, w.packet_size.reinterpret_as_int())
}

///|
/// Decode LAS-defined uncompressed 8/16-bit amplitudes and apply descriptor gain
/// and offset. The container reader also preserves other encodings opaquely.
pub fn Document::waveform_samples(
  self : Document,
  point : Point,
  external~ : Bytes? = None,
  limits~ : Limits = Limits::default(),
) -> Array[Double] raise LasError {
  let w = match point.waveform {
    Some(w) => w
    None => raise Invalid("point has no waveform fields")
  }
  if w.descriptor_index == 0 {
    return []
  }
  let candidates = vlrs_named(self.vlrs, "LASF_Spec", 99 + w.descriptor_index)
  require(candidates.length() == 1, "missing or duplicate waveform descriptor")
  let d = waveform_descriptor(candidates[0])
  if d.compression != 0 {
    raise Unsupported("compressed waveform amplitudes")
  }
  if d.bits_per_sample != 8 && d.bits_per_sample != 16 {
    raise Unsupported("waveform sample precision")
  }
  let packet = self.waveform_packet(point, external~, limits~)
  require(
    d.sample_count.to_uint64() <= limits.max_points.to_uint64(),
    "waveform sample count exceeds budget",
  )
  let count = d.sample_count.reinterpret_as_int()
  let width = d.bits_per_sample / 8
  checked_size(count, width, packet.length())
  require(
    packet.length() == count * width,
    "waveform packet size disagrees with descriptor",
  )
  let r = Reader::new(packet, 0, packet.length())
  let result : Array[Double] = []
  for _ in 0..<count {
    let raw = if width == 1 { r.u8() } else { r.u16() }
    let value = raw.to_double() * d.gain + d.offset
    require(finite(value), "waveform amplitude overflow")
    result.push(value)
  }
  result
}
