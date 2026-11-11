///|
/// Range-checked little-endian primitives; counts are bounded before Int conversion.
priv struct Reader {
  data : Bytes
  mut pos : Int32
  end : Int32
}

///|
fn Reader::new(
  data : Bytes,
  start : Int32,
  end : Int32,
) -> Reader raise LasError {
  require(
    start >= 0 && end >= start && end <= data.length(),
    "invalid reader range",
  )
  { data, pos: start, end, }
}

///|
fn Reader::take(self : Reader, n : Int32) -> Bytes raise LasError {
  if n < 0 || n > self.end - self.pos {
    raise Truncated(self.pos)
  }
  let start = self.pos
  self.pos += n
  Bytes::from_array(Array::makei(n, i => self.data[start + i])[:])
}

///|
fn Reader::u8(self : Reader) -> Int32 raise LasError {
  if self.pos >= self.end {
    raise Truncated(self.pos)
  }
  let n = self.data[self.pos].to_int()
  self.pos += 1
  n
}

///|
fn Reader::u16(self : Reader) -> Int32 raise LasError {
  let a = self.u8()
  a | (self.u8() << 8)
}

///|
fn Reader::i16(self : Reader) -> Int32 raise LasError {
  let n = self.u16()
  if n >= 32768 {
    n - 65536
  } else {
    n
  }
}

///|
fn Reader::i32(self : Reader) -> Int32 raise LasError {
  let a = self.u16()
  a | (self.u16() << 16)
}

///|
fn Reader::u32(self : Reader, cap : Int32) -> Int32 raise LasError {
  let n = self.i32()
  if n < 0 || n > cap {
    raise Limit("unsigned count exceeds budget")
  }
  n
}

///|
fn Reader::u64(self : Reader, cap : Int32) -> Int32 raise LasError {
  let lo = self.u32(cap)
  let hi = self.i32()
  if hi != 0 {
    raise Limit("64-bit count exceeds supported budget")
  }
  lo
}

///|
fn Reader::f64(self : Reader) -> Double raise LasError {
  let mut bits = 0L
  for i in 0..<8 {
    bits = bits | (self.u8().to_int64() << (i * 8))
  }
  let v = bits.reinterpret_as_double()
  require(finite(v), "nonfinite floating point field")
  v
}

///|
fn Reader::text(self : Reader, width : Int32) -> String raise LasError {
  let data = self.take(width)
  let chars : Array[Char] = []
  let mut ended = false
  for b in data {
    let n = b.to_int()
    if n == 0 {
      ended = true
    }
    if !ended {
      require(n >= 32 && n <= 126, "metadata text must be printable ASCII")
      chars.push(n.unsafe_to_char())
    }
  }
  String::from_array(chars[:])
}

///|
/// Validates length arithmetic using division instead of overflowing multiplication.
fn checked_size(
  count : Int32,
  width : Int32,
  available : Int32,
) -> Unit raise LasError {
  require(count >= 0 && width > 0 && available >= 0, "invalid record span")
  if count > available / width {
    raise Truncated(available)
  }
}
