///|
/// Append-only byte sink, shared by records, headers and variable-length metadata.
fn put8(out : Array[Byte], value : Int32) -> Unit {
  out.push((value & 255).to_byte())
}

///|
fn put16(out : Array[Byte], value : Int32) -> Unit {
  put8(out, value)
  put8(out, value >> 8)
}

///|
fn put32(out : Array[Byte], value : Int32) -> Unit {
  put16(out, value)
  put16(out, value >> 16)
}

///|
fn put64(out : Array[Byte], value : Int32) -> Unit {
  put32(out, value)
  put32(out, 0)
}

///|
fn putf64(out : Array[Byte], value : Double) -> Unit raise LasError {
  require(finite(value), "cannot write nonfinite value")
  let bits = value.reinterpret_as_int64()
  for i in 0..<8 {
    put8(out, (bits >> (8 * i)).to_int())
  }
}

///|
fn append(out : Array[Byte], bytes : Bytes) -> Unit {
  for b in bytes {
    out.push(b)
  }
}

///|
fn put_text(
  out : Array[Byte],
  text : String,
  width : Int32,
) -> Unit raise LasError {
  let chars = text.to_array()
  require(chars.length() <= width, "metadata text exceeds field width")
  for c in chars {
    let n = c.to_int()
    require(n >= 32 && n <= 126, "metadata text must be printable ASCII")
    put8(out, n)
  }
  for _ in chars.length()..<width {
    put8(out, 0)
  }
}

///|
fn bytes_of(out : Array[Byte]) -> Bytes {
  Bytes::from_array(out[:])
}
