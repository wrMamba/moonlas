///|
/// Extra Bytes descriptors retain typed no-data/min/max unions without conversion.
#derive(Debug)
pub(all) struct ExtraDimension {
  name : String
  description : String
  data_type : Int32
  options : Int32
  byte_offset : Int32
  byte_width : Int32
  no_data : Bytes
  minimum : Bytes
  maximum : Bytes
  scale : Array[Double]
  offset : Array[Double]
}

///|
#derive(Debug, Eq)
pub(all) enum ExtraValue {
  Unsigned(UInt64)
  Signed(Int64)
  Real(Double)
}

///|
fn extra_scalar_width(data_type : Int32) -> Int32 raise LasError {
  require(data_type >= 1 && data_type <= 30, "unknown Extra Bytes data type")
  match (data_type - 1) % 10 {
    0 | 1 => 1
    2 | 3 => 2
    4 | 5 | 8 => 4
    _ => 8
  }
}

///|
/// Resolve scalar and 2/3-component descriptors in file order. Type zero is an
/// opaque byte range whose length is the options byte. Unknown VLRs remain intact.
pub fn extra_dimensions(
  records : Array[Vlr],
  extra_width : Int32,
) -> Array[ExtraDimension] raise LasError {
  require(extra_width >= 0 && extra_width <= 65535, "invalid extra byte width")
  let dimensions : Array[ExtraDimension] = []
  let mut byte_offset = 0
  for record in vlrs_named(records, "LASF_Spec", 4) {
    require(
      record.payload.length() % 192 == 0,
      "Extra Bytes descriptors must be 192 bytes each",
    )
    let r = Reader::new(record.payload, 0, record.payload.length())
    while r.pos < r.end {
      ignore(r.u16())
      let data_type = r.u8()
      let options = r.u8()
      let name = r.text(32)
      ignore(r.take(4))
      let no_data = r.take(24)
      let minimum = r.take(24)
      let maximum = r.take(24)
      let scale = Array::makei(3, _ => r.float64_raw())
      let offset = Array::makei(3, _ => r.float64_raw())
      let description = r.text(32)
      let width = if data_type == 0 {
        options
      } else {
        extra_scalar_width(data_type) * ((data_type - 1) / 10 + 1)
      }
      require(
        width > 0 && width <= extra_width - byte_offset,
        "Extra Bytes layout exceeds point extension",
      )
      dimensions.push({
        name,
        description,
        data_type,
        options,
        byte_offset,
        byte_width: width,
        no_data,
        minimum,
        maximum,
        scale,
        offset,
      })
      byte_offset += width
    }
  }
  dimensions
}

///|
/// Decode exact-width integer or floating values without converting 64-bit IDs
/// through Double. Descriptor scale/offset and no-data metadata remain explicit.
pub fn extra_values(
  point : Point,
  dimension : ExtraDimension,
) -> Array[ExtraValue] raise LasError {
  require(
    dimension.data_type != 0,
    "untyped extra bytes have no numeric interpretation",
  )
  let width = extra_scalar_width(dimension.data_type)
  let components = (dimension.data_type - 1) / 10 + 1
  require(
    dimension.byte_width == width * components,
    "inconsistent Extra Bytes width",
  )
  let start = dimension.byte_offset
  require(
    start >= 0 && start <= point.extra.length() - dimension.byte_width,
    "extra dimension outside point record",
  )
  let r = Reader::new(point.extra, start, start + dimension.byte_width)
  let scalar_type = (dimension.data_type - 1) % 10
  let values : Array[ExtraValue] = []
  for _ in 0..<components {
    let value = match scalar_type {
      0 => Unsigned(r.u8().to_uint64())
      1 => {
        let raw = r.u8()
        Signed((if raw >= 128 { raw - 256 } else { raw }).to_int64())
      }
      2 => Unsigned(r.u16().to_uint64())
      3 => Signed(r.i16().to_int64())
      4 => Unsigned(r.i32().reinterpret_as_uint().to_uint64())
      5 => Signed(r.i32().to_int64())
      6 => Unsigned(r.uint64())
      7 => Signed(r.uint64().reinterpret_as_int64())
      8 => Real(r.float32().to_double())
      _ => Real(r.float64_raw())
    }
    values.push(value)
  }
  values
}

///|
pub extend ExtraDimension with @debug.Debug::{to_repr}

///|
pub extend ExtraValue with @debug.Debug::{to_repr}

///|
pub extend ExtraValue with Eq::{equal, not_equal}
