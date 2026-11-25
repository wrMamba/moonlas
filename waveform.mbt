///|
/// Waveform packet references retain all 64 offset bits, including external WDP offsets.
#derive(Debug, Eq)
pub(all) struct Waveform {
  descriptor_index : Int32
  byte_offset : UInt64
  packet_size : UInt32
  location : Float
  dx : Float
  dy : Float
  dz : Float
}

///|
fn has_waveform(format : Int32) -> Bool {
  format == 4 || format == 5 || format == 9 || format == 10
}

///|
pub fn Waveform::validate(self : Waveform) -> Unit raise LasError {
  require(
    self.descriptor_index >= 0 && self.descriptor_index <= 255,
    "invalid waveform descriptor index",
  )
}

///|
fn read_waveform(r : Reader) -> Waveform raise LasError {
  let descriptor_index = r.u8()
  let byte_offset = r.uint64()
  let packet_size = r.i32().reinterpret_as_uint()
  let location = r.float32()
  let dx = r.float32()
  let dy = r.float32()
  let dz = r.float32()
  { descriptor_index, byte_offset, packet_size, location, dx, dy, dz, }
}

///|
fn write_waveform(out : Array[Byte], w : Waveform) -> Unit raise LasError {
  w.validate()
  put8(out, w.descriptor_index)
  put_uint64(out, w.byte_offset)
  put32(out, w.packet_size.reinterpret_as_int())
  for value in [w.location, w.dx, w.dy, w.dz] {
    put_float32(out, value)
  }
}

///|
/// Descriptor VLR fields; compression codes and sample precision are retained even
/// when the optional uncompressed sample accessor cannot interpret them.
#derive(Debug, Eq)
pub(all) struct WaveformDescriptor {
  bits_per_sample : Int32
  compression : Int32
  sample_count : UInt32
  spacing_ps : UInt32
  gain : Double
  offset : Double
}

///|
pub fn waveform_descriptor(vlr : Vlr) -> WaveformDescriptor raise LasError {
  require(
    vlr.user_id == "LASF_Spec" && vlr.record_id >= 100 && vlr.record_id <= 354,
    "not a waveform descriptor VLR",
  )
  require(vlr.payload.length() == 26, "waveform descriptor must have 26 bytes")
  let r = Reader::new(vlr.payload, 0, 26)
  let bits_per_sample = r.u8()
  let compression = r.u8()
  let sample_count = r.i32().reinterpret_as_uint()
  let spacing_ps = r.i32().reinterpret_as_uint()
  let gain = r.f64()
  let offset = r.f64()
  { bits_per_sample, compression, sample_count, spacing_ps, gain, offset, }
}

///|
pub extend Waveform with @debug.Debug::{to_repr}

///|
pub extend Waveform with Eq::{equal, not_equal}

///|
pub extend WaveformDescriptor with @debug.Debug::{to_repr}

///|
pub extend WaveformDescriptor with Eq::{equal, not_equal}
